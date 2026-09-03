import Foundation
import Testing

@testable import Gnusto

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// The physical layer of the play-test server: `LineBuffer`'s reassembly under
/// load, the pending-frame cap, and `StdioReader`/`StdioWriter` driven over a
/// real pipe.
///
/// `MCPProtocolTests` drives `MCPServer.handle(line:)` and keeps the framing
/// tests there deliberately pipe-free. This file is the counterpart: the
/// claims here are about bytes and file descriptors, so the tests make bytes
/// and file descriptors real. Nothing spawns a process — `serve` rewrites its
/// own process's stdout and exits on end of input, which is not survivable
/// from inside a test — so the live handshake stays with
/// `bin/playtest-preflight`, which CI runs. A pipe pair exercises the same
/// `read(2)`/`write(2)` paths the spawned binary would.
struct StdioTransportTests {
    /// A pipe pair, with each end closed exactly once.
    private struct Pipe {
        let readEnd: Int32
        let writeEnd: Int32
        private var writeClosed = false

        init() {
            var fds: [Int32] = [0, 0]
            #expect(pipe(&fds) == 0)
            readEnd = fds[0]
            writeEnd = fds[1]
        }

        /// Ends the stream: the reader sees end of input here.
        func closeWrite() {
            _ = Self.close(writeEnd)
        }

        func close() {
            _ = Self.close(readEnd)
            if !writeClosed {
                _ = Self.close(writeEnd)
            }
        }

        // Named once so the platform choice stays out of the tests.
        private static func close(_ descriptor: Int32) -> Int32 {
            #if canImport(Darwin)
            return Darwin.close(descriptor)
            #else
            return Glibc.close(descriptor)
            #endif
        }
    }

    // MARK: - Reassembly at scale

    /// The reassembly is linear, not quadratic. An 8 MB frame arriving in the
    /// 64 KiB chunks `read(2)` produces is one frame, and answering it does
    /// not stall the session: the buffer scans each chunk once from where the
    /// last scan stopped. The ceiling is generous enough to pass on slow CI
    /// many times over — the point is that the quadratic buffer, measured at
    /// 42 seconds on this same frame, cannot.
    @Test func aMegabyteFrameReassemblesInLinearTime() throws {
        let padding = String(repeating: "x", count: 8 * 1024 * 1024)
        let frame = #"{"jsonrpc":"2.0","id":1,"method":"ping","padding":"\#(padding)"}"#
        let bytes = Array("\(frame)\n".utf8)

        var buffer = LineBuffer()
        var seen: [String] = []
        let clock = ContinuousClock()
        let started = clock.now
        for chunk in stride(from: 0, to: bytes.count, by: StdioReader.readChunkSize) {
            let piece = bytes[chunk..<min(chunk + StdioReader.readChunkSize, bytes.count)]
            seen += try buffer.frames(in: piece)
        }
        let elapsed = clock.now - started

        #expect(seen == [frame])
        #expect(elapsed < .seconds(15), "reassembly took \(elapsed); the scan is quadratic again")
    }

    /// Every chunk boundary, not just the power-of-two ones: a frame cut at
    /// every single offset reassembles to the same line. Cheap to exhaust at
    /// this size, and it is the boundary arithmetic that goes wrong, not the
    /// bulk copy.
    @Test func aFrameSplitAtEveryOffsetReassembles() throws {
        let frame = #"{"jsonrpc":"2.0","id":9,"method":"tools/call"}"#
        let bytes = Array("\(frame)\n".utf8)
        for cut in 1..<bytes.count {
            var buffer = LineBuffer()
            var seen = try buffer.frames(in: Array(bytes[0..<cut]))
            seen += try buffer.frames(in: Array(bytes[cut...]))
            #expect(seen == [frame], "cut after byte \(cut)")
        }
    }

    // MARK: - The pending-frame cap

    /// A frame that never ends is a client that has stopped speaking the
    /// framing. Past the cap the buffer throws rather than growing forever.
    @Test func aFramePastTheCapIsRefused() {
        var buffer = LineBuffer(maxPendingBytes: 16)
        #expect(throws: LineBuffer.FrameLimitError(maxPendingBytes: 16)) {
            _ = try buffer.frames(in: Array(repeating: UInt8(ascii: "{"), count: 17))
        }
    }

    /// Exactly at the cap is not past it — the limit is a cap, not a hint.
    @Test func aFrameAtTheCapIsStillBuffered() throws {
        var buffer = LineBuffer(maxPendingBytes: 16)
        #expect(try buffer.frames(in: Array(repeating: UInt8(ascii: "{"), count: 16)).isEmpty)
    }

    /// The cap watches the frame still being assembled, not the traffic that
    /// was fine: a frame completed before the overflow was handed back by its
    /// own call, and the overflow is a later, separate one.
    @Test func theCapWatchesTheUnfinishedFrameOnly() throws {
        var buffer = LineBuffer(maxPendingBytes: 16)
        #expect(try buffer.frames(in: Array("{\"a\":1}\n".utf8)) == [#"{"a":1}"#])
        #expect(throws: LineBuffer.FrameLimitError(maxPendingBytes: 16)) {
            _ = try buffer.frames(in: Array(repeating: UInt8(ascii: "{"), count: 32))
        }
    }

    /// Gathers every frame a reader yields from one descriptor, until end of
    /// input — the same handful of lines three of the pipe tests need.
    private func collect(from descriptor: Int32) -> Task<[String], Never> {
        Task { () -> [String] in
            var out: [String] = []
            for await frame in StdioReader.frames(from: descriptor) {
                out.append(frame)
            }
            return out
        }
    }

    // MARK: - The reader, over a real pipe

    /// `StdioReader` on a pipe: frames written in pieces — some below, some
    /// above, one straddling the pipe buffer — come out whole and in order,
    /// and end of input finishes the stream. The total stays under the pipe
    /// buffer so the test cannot deadlock on a write before the reader starts.
    @Test func theReaderReassemblesFramesFromAPipe() async throws {
        let pipe = Pipe()
        defer { pipe.close() }

        let frames = [
            #"{"jsonrpc":"2.0","id":1,"method":"ping"}"#,
            String(repeating: "y", count: 30_000),
            #"{"jsonrpc":"2.0","id":2,"method":"ping"}"#,
        ]
        var bytes: [UInt8] = []
        for frame in frames {
            bytes += Array("\(frame)\n".utf8)
        }

        // Pieces written at a prime size, so no write lands on a frame
        // boundary and every frame straddles a read.
        let collected = collect(from: pipe.readEnd)

        var offset = 0
        while offset < bytes.count {
            let end = min(offset + 7919, bytes.count)
            writeAllBytes(pipe.writeEnd, Array(bytes[offset..<end]))
            offset = end
        }
        pipe.closeWrite()

        #expect(await collected.value == frames)
    }

    /// A frame past the cap ends the reader's stream, with the frames that
    /// were already complete delivered first.
    @Test func theReaderStopsAtAFramePastTheCap() async throws {
        let pipe = Pipe()
        defer { pipe.close() }

        let collected = collect(from: pipe.readEnd)

        writeAllBytes(pipe.writeEnd, Array("{\"a\":1}\n".utf8))
        writeAllBytes(pipe.writeEnd, Array(repeating: UInt8(ascii: "{"), count: 100_000))
        pipe.closeWrite()

        #expect(await collected.value == [#"{"a":1}"#])
    }

    // MARK: - The writer, over a real pipe

    /// `StdioWriter` on a pipe: frames larger than the pipe buffer, written
    /// back to back through the actor, arrive whole and in order. The reader
    /// on the far end is what forces the short writes the writer exists to
    /// resume — a pipe this small cannot take a megabyte in one `write(2)`.
    @Test func theWriterDeliversLargeFramesThroughAPipe() async throws {
        let pipe = Pipe()
        defer { pipe.close() }

        let frames = [
            String(repeating: "a", count: 1024 * 1024),
            #"{"jsonrpc":"2.0","id":3,"method":"ping"}"#,
            String(repeating: "b", count: 1024 * 1024),
        ]

        let collected = collect(from: pipe.readEnd)

        let writer = StdioWriter(descriptor: pipe.writeEnd)
        for frame in frames {
            await writer.write(frame)
        }
        pipe.closeWrite()

        #expect(await collected.value == frames)
    }
}
