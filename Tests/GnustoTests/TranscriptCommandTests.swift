import Foundation
import Gnusto
import GnustoTestSupport
import Testing

@testable import CloakOfDarkness

/// The `script` / `unscript` commands record the interleaved session to a
/// plain-text file, and `GNUSTO_TRANSCRIPT` (a `transcriptURL` passed to the
/// REPL) records a whole session from launch.
struct TranscriptCommandTests {
    /// A fresh, isolated temp file path for a test's transcript.
    private func tempTranscript() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("session.txt")
    }

    @Test func scriptRecordsTurnsUntilUnscript() async throws {
        let file = tempTranscript()
        let transcript = try await play(
            OperaHouse(), ["script \(file.path)", "look", "unscript", "look"])

        // The player sees the start/stop confirmations.
        #expect(transcript.contains("[Recording transcript to \(file.path)]"))
        #expect(transcript.contains("[Transcript recording ended: \(file.path)]"))

        let recorded = try String(contentsOf: file, encoding: .utf8)
        // The turn between script and unscript is captured…
        #expect(recorded.contains("> look"))
        #expect(recorded.contains("Foyer of the Opera House"))
        // …but nothing after `unscript` (the second look) is.
        #expect(recorded.components(separatedBy: "> look").count == 2)
    }

    @Test func recordedTranscriptKeepsComments() async throws {
        let file = tempTranscript()
        _ = try await play(
            OperaHouse(), ["script \(file.path)", "// a tester note", "look", "unscript"])

        let recorded = try String(contentsOf: file, encoding: .utf8)
        #expect(recorded.contains("> // a tester note"))
    }

    @Test func unscriptWithoutRecordingIsReported() async throws {
        let transcript = try await play(OperaHouse(), ["unscript", "look"])
        #expect(transcript.contains("[No transcript is being recorded.]"))
    }

    @Test func preArmedTranscriptCapturesTheOpening() async throws {
        // The `GNUSTO_TRANSCRIPT` path arrives as `transcriptURL`; recording
        // starts before the loop, so the intro and first look are captured.
        let file = tempTranscript()
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let world = try GameWorld(game: OperaHouse(), seed: 1, saveDirectory: dir)
        let io = ScriptedIOHandler(lines: ["look", "quit"])
        await REPL(world: world, io: io, transcriptURL: file).run()

        let recorded = try String(contentsOf: file, encoding: .utf8)
        #expect(recorded.contains("Hurrying through the rainswept November night"))
        #expect(recorded.contains("> look"))
        #expect(recorded.contains("> quit"))
    }
}
