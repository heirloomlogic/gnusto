import Foundation
import Gnusto
import GnustoTestSupport
import Testing

@testable import CloakOfDarkness

/// Play-test comments (`//` or `#`) are filtered by the REPL before the parser:
/// they stay in the transcript as notes but never run a turn, so the game clock
/// never moves and the parser never sees them.
struct TesterCommentTests {
    @Test func slashCommentIsKeptButProducesNoOutput() async throws {
        let transcript = try await play(
            OperaHouse(), ["// note to self: check the hook", "look"])
        // The comment is echoed into the transcript, and the very next thing is
        // the next prompt — nothing was emitted for it.
        #expect(transcript.contains("> // note to self: check the hook\n> look"))
    }

    @Test func hashCommentIsAlsoIgnored() async throws {
        let transcript = try await play(OperaHouse(), ["# a hash note", "look"])
        #expect(transcript.contains("> # a hash note\n> look"))
    }

    @Test func commentNeverReachesTheParser() async throws {
        // A bare marker isn't a command; if it leaked to the parser it would
        // draw "I beg your pardon?" — it must not.
        let transcript = try await play(OperaHouse(), ["//", "#", "look"])
        #expect(!transcript.contains("I beg your pardon"))
        #expect(transcript.contains("> //\n> #\n> look"))
    }

    @Test func commentDoesNotAdvanceTheClock() async throws {
        // The quit epilogue reports the turn count, so an interposed comment
        // that advanced the clock would change it.
        let withComment = try await play(
            OperaHouse(), ["look", "// pause", "look", "quit"])
        let withoutComment = try await play(
            OperaHouse(), ["look", "look", "quit"])
        #expect(withComment.contains("in 2 turns"))
        #expect(withoutComment.contains("in 2 turns"))
    }

    @Test func commentIsIgnoredEvenWhileASavePromptIsOpen() async throws {
        // `save` opens a filename prompt; a comment typed at it is ignored and
        // the prompt stays armed for the real answer that follows.
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let transcript = try await play(
            OperaHouse(),
            ["save", "// which slot?", "autumn", "restore", "autumn", "quit"],
            saveDirectory: dir)
        #expect(transcript.contains("> // which slot?"))
        // The save still succeeded on the following line — the comment didn't
        // become the filename.
        #expect(transcript.contains("Restored."))
    }
}
