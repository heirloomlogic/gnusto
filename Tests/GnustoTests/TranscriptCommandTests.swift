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

    /// A fresh, isolated save directory, so a test's `save` slots can't be seen
    /// by another test or by the developer's real ones.
    private func tempDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
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

    /// The whole play-test harness rests on one claim, stated in
    /// `bin/playtest-replay` and `docs/playtesting.md`: a `GNUSTO_TRANSCRIPT`
    /// recording is "byte-for-byte what `ScriptedIOHandler` produces in the test
    /// suite," so a tester's command list *is* a regression test. Two different
    /// pieces of code produce that format — `TranscriptRecorder` for the file and
    /// `REPL` + `ScriptedIOHandler` for the string — so the claim needs a test or
    /// it is only a comment.
    ///
    /// Driving one REPL with both at once compares them on the same run, which is
    /// stricter than replaying twice and cannot drift on scheduling.
    ///
    /// Note the two shapes deliberately excluded: `script`/`unscript`
    /// confirmations reach `io.write` but not the recorder (the recorder does not
    /// exist yet when the first one prints), and a front-end `Input.quit` echoes a
    /// bare prompt to the handler while the recorder writes `> quit`. Neither can
    /// occur in a `playtest-replay` session, which is what this contract covers.
    @Test func recordedTranscriptMatchesTheScriptedOneByteForByte() async throws {
        let world = try GameWorld(game: OperaHouse(), seed: 1, saveDirectory: tempDirectory())
        let file = tempTranscript()
        let io = ScriptedIOHandler(lines: ["look", "// a tester note", "south", "quit"])
        await REPL(world: world, io: io, transcriptURL: file).run()

        let recorded = try String(contentsOf: file, encoding: .utf8)
        #expect(recorded == io.transcript)
    }

    /// The same contract across an *empty* turn output, which is the one place the
    /// two producers disagreed: `QUIT` at the death prompt sets the status and
    /// returns `freeReply("")`, so the turn prints nothing at all.
    @Test func byteIdentityHoldsForAnEmptyTurnOutput() async throws {
        let world = try GameWorld(game: MorgueGame(), seed: 1, saveDirectory: tempDirectory())
        let file = tempTranscript()
        // `take poison` dies and arms the death prompt; `quit` there is answered
        // by `freeReply("")` — an empty output, and the whole point of this test.
        let io = ScriptedIOHandler(lines: ["take poison", "quit"])
        await REPL(world: world, io: io, transcriptURL: file).run()

        let recorded = try String(contentsOf: file, encoding: .utf8)
        #expect(recorded == io.transcript)
    }

    /// Byte-identity has to survive the status footer, because the footer is
    /// appended on the way to *two* sinks — `io.write` and the recorder — and a
    /// second producer of a format is a second place for it to drift. `REPL.run`
    /// computes the annotated output once and hands the same string to both; this
    /// is what pins that down, so a later refactor that annotates each sink
    /// separately fails here rather than in a play-test round six months on.
    ///
    /// Worth a test of its own rather than a parameter on the case above: with
    /// `GNUSTO_STATUS` in force, a session's transcript is what the export path
    /// will assert against, so the contract matters most in exactly the
    /// configuration the harness runs in.
    @Test func byteIdentityHoldsWithTheStatusFooterInForce() async throws {
        let world = try GameWorld(game: OperaHouse(), seed: 1, saveDirectory: tempDirectory())
        let file = tempTranscript()
        // `score` is a meta intent and costs no turn, so this run also covers a
        // `turn=free` footer sitting between two `turn=cost` ones.
        let io = ScriptedIOHandler(lines: ["look", "score", "south", "quit"])
        let footer = StatusFooter(environment: ["GNUSTO_STATUS": "1"])
        await REPL(world: world, io: io, transcriptURL: file, status: footer.inForce).run()

        let recorded = try String(contentsOf: file, encoding: .utf8)
        #expect(recorded == io.transcript)
        // Guard against the assertion passing because no footer was rendered at
        // all: two identical empty-of-footer transcripts would also be equal.
        #expect(recorded.contains("[status] room="))
        #expect(recorded.contains("turn=free"))
        #expect(recorded.contains("turn=cost"))
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
