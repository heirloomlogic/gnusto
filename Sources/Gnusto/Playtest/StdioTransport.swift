import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// The wire under the play-test server: newline-delimited JSON on stdio.
///
/// One UTF-8 JSON object per line, in each direction. This is **not** the LSP
/// framing — there are no `Content-Length` headers — and getting that wrong is
/// the single most common way a hand-rolled MCP server fails to connect at all.
///
/// Two properties are load-bearing and neither is free:
///
/// - **A frame can arrive split.** `read(2)` returns whatever the pipe has,
///   which may be half a line, or three lines and a bit. ``LineBuffer`` holds
///   the remainder between reads, and holds it as *bytes* — a multi-byte
///   character split across two reads would be two invalid fragments if the
///   buffer decoded eagerly.
/// - **A frame can leave split.** A large result exceeds `PIPE_BUF`, so a
///   single `write(2)` may write a prefix and report how much; a writer that
///   ignores the count truncates the frame and the client sees a parse error
///   naming nothing. ``StdioWriter`` loops until the whole buffer is gone, and
///   is an actor so that concurrent tool calls — subagents share one client
///   connection — cannot interleave two half-written frames.

// MARK: - Reassembling frames

/// Turns a stream of arbitrary byte chunks into whole lines.
///
/// Split out from the read loop, and a value type, because "a frame split
/// across two reads is reassembled" is the kind of claim that should be
/// testable without a pipe, a subprocess or a thread.
struct LineBuffer {
    /// Bytes seen since the last newline.
    private var pending: [UInt8] = []

    /// An empty buffer.
    init() {}

    /// Adds bytes and hands back every line they completed.
    ///
    /// Blank lines are dropped rather than reported as empty frames: a client
    /// that pads with newlines is being polite, not sending garbage. Bytes
    /// that aren't valid UTF-8 become replacement characters, which the JSON
    /// parser will reject as a `-32700` — the same answer as any other
    /// malformed frame, and better than a trap.
    ///
    /// - Parameter bytes: the bytes just read.
    /// - Returns: the complete lines now available, in order, without their
    ///   newlines.
    mutating func frames(in bytes: [UInt8]) -> [String] {
        pending.append(contentsOf: bytes)
        var frames: [String] = []
        while let newline = pending.firstIndex(of: UInt8(ascii: "\n")) {
            let line = Array(pending[..<newline])
            pending.removeSubrange(...newline)
            let text = String(decoding: line, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                frames.append(text)
            }
        }
        return frames
    }
}

// MARK: - Reading

/// The incoming half of the transport.
enum StdioReader {
    /// Every frame the client sends, until end of input.
    ///
    /// The read is blocking and runs on a `Thread` of its own rather than on
    /// the cooperative pool: a blocking call there occupies a thread the
    /// runtime is counting on, and this one is blocked for as long as the
    /// client is thinking — which is most of a play-test round.
    ///
    /// The stream finishes on end of input, which is how the server learns the
    /// client has gone and how the process exits cleanly.
    ///
    /// - Parameter descriptor: the file descriptor to read, standard input in
    ///   production.
    /// - Returns: the frames, one per element, without their newlines.
    static func frames(from descriptor: Int32) -> AsyncStream<String> {
        AsyncStream { continuation in
            let thread = Thread {
                var buffer = LineBuffer()
                var chunk = [UInt8](repeating: 0, count: 64 * 1024)
                while true {
                    let count = chunk.withUnsafeMutableBytes { raw -> Int in
                        guard let base = raw.baseAddress else { return 0 }
                        return readBytes(descriptor, base, raw.count)
                    }
                    if count > 0 {
                        for frame in buffer.frames(in: Array(chunk[0..<count])) {
                            continuation.yield(frame)
                        }
                        continue
                    }
                    // A signal interrupts the read without ending it; anything
                    // else — end of input, or a broken pipe — is the end.
                    if count < 0 && errno == EINTR { continue }
                    break
                }
                continuation.finish()
            }
            thread.name = "gnusto-mcp-stdin"
            thread.start()
        }
    }
}

// MARK: - Writing

/// The outgoing half of the transport: the one thing in the process allowed to
/// touch the protocol descriptor.
///
/// An actor, so that two tool calls finishing at once produce two frames
/// rather than one interleaved mess. JSON-RPC lets responses come back in any
/// order, so serialising the writes costs nothing but the ordering nobody is
/// entitled to.
actor StdioWriter {
    /// The descriptor the protocol goes out on. Not `STDOUT_FILENO`: the
    /// server dups the real stdout aside and points fd 1 at stderr, so this is
    /// the only handle on the channel. See `PlaytestServer.serve`.
    private let descriptor: Int32

    /// Creates a writer over one descriptor.
    ///
    /// - Parameter descriptor: the descriptor to write frames to.
    init(descriptor: Int32) {
        self.descriptor = descriptor
    }

    /// Writes one frame and its newline, in full.
    ///
    /// A short write is resumed rather than reported: the caller has no
    /// recourse — the channel it would complain on is the one that just
    /// failed — and half a frame is worse than none. A dead pipe ends the
    /// attempt silently for the same reason; end of input will shut the server
    /// down a moment later anyway.
    ///
    /// - Parameter frame: one JSON document, without its newline.
    func write(_ frame: String) {
        let bytes = Array("\(frame)\n".utf8)
        bytes.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            var offset = 0
            while offset < raw.count {
                let written = writeBytes(descriptor, base + offset, raw.count - offset)
                if written > 0 {
                    offset += written
                } else if written < 0 && (errno == EINTR || errno == EAGAIN) {
                    continue
                } else {
                    return
                }
            }
        }
    }
}

// MARK: - libc, named once

/// `read(2)`, wrapped so the platform choice is made in one place and so the
/// name doesn't collide with a method called `read`.
///
/// - Parameters:
///   - descriptor: the descriptor to read.
///   - buffer: where to put the bytes.
///   - count: how many bytes there is room for.
/// - Returns: bytes read, `0` at end of input, or `-1` with `errno` set.
private func readBytes(_ descriptor: Int32, _ buffer: UnsafeMutableRawPointer, _ count: Int) -> Int {
    #if canImport(Darwin)
    Darwin.read(descriptor, buffer, count)
    #elseif canImport(Glibc)
    Glibc.read(descriptor, buffer, count)
    #endif
}

/// `write(2)`, wrapped for the same two reasons as ``readBytes(_:_:_:)``.
///
/// - Parameters:
///   - descriptor: the descriptor to write to.
///   - buffer: the bytes to write.
///   - count: how many of them.
/// - Returns: bytes written — possibly fewer than asked — or `-1` with
///   `errno` set.
private func writeBytes(_ descriptor: Int32, _ buffer: UnsafeRawPointer, _ count: Int) -> Int {
    #if canImport(Darwin)
    Darwin.write(descriptor, buffer, count)
    #elseif canImport(Glibc)
    Glibc.write(descriptor, buffer, count)
    #endif
}
