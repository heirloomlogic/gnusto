import Foundation
import Testing

@testable import Gnusto

struct DeathTests {
    @Test func dyingPrintsMessageBannerScoreAndPrompt() async throws {
        let transcript = try await play(MorgueGame(), ["take poison", "look"])
        let fatal = turnOutput(of: "take poison", in: transcript)
        expectInOrder(
            fatal,
            [
                "Ill-advised. The world goes dark.",
                "*** You have died ***",
                "Your score is",
                "Would you like to RESTART, RESTORE a saved game, UNDO your last turn, or QUIT?",
            ])
        // The program is still alive: the next line reaches the prompt.
        let look = turnOutput(of: "look", in: transcript)
        #expect(look.contains("Please type RESTART, RESTORE, UNDO, or QUIT."))
        #expect(!look.contains("Slab Room"))
    }

    @Test func undoFromTheDeathPromptRevives() async throws {
        let transcript = try await play(
            MorgueGame(),
            ["take apple", "take poison", "undo", "take bread"])
        let undo = turnOutput(of: "undo", in: transcript)
        #expect(undo.contains("Previous turn undone."))
        #expect(undo.contains("Slab Room"))
        // Alive again: a normal command runs.
        #expect(turnOutput(of: "take bread", in: transcript).contains("Taken."))
    }

    @Test func restartFromTheDeathPromptReplaysTheOpening() async throws {
        let transcript = try await play(
            MorgueGame(),
            ["take poison", "restart", "take bread"])
        let restart = turnOutput(of: "restart", in: transcript)
        #expect(restart.contains("Cold tile, one table."))
        #expect(restart.contains("Slab Room"))
        #expect(turnOutput(of: "take bread", in: transcript).contains("Taken."))
    }

    @Test func quitFromTheDeathPromptEndsTheGame() async throws {
        let transcript = try await play(MorgueGame(), ["take poison", "quit", "look"])
        // The REPL stopped: the trailing look was never consumed.
        #expect(!transcript.contains("> look"))
    }

    @Test func restoreFromTheDeathPromptRoundTrips() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("gnusto-death-\(UUID().uuidString).sav").path
        defer { try? FileManager.default.removeItem(atPath: path) }
        let transcript = try await play(
            MorgueGame(),
            ["take bread", "save", path, "take poison", "restore", path, "inventory"])
        expectInOrder(
            transcript,
            ["*** You have died ***", "Restore from what file?", "Restored.", "Slab Room"])
        #expect(turnOutput(of: "inventory", in: transcript).contains("stale bread"))
    }

    @Test func failedRestoreReturnsToTheDeathPrompt() async throws {
        let transcript = try await play(
            MorgueGame(),
            ["take poison", "restore", "/nonexistent/nope.sav", "undo"])
        expectInOrder(
            transcript,
            [
                "*** You have died ***",
                "Restore from what file?",
                "Restore failed.",
                "Would you like to RESTART, RESTORE a saved game, UNDO your last turn, or QUIT?",
                "Previous turn undone.",
            ])
    }

    @Test func deathFromADaemonFollowsTheSameShape() async throws {
        let transcript = try await play(MorgueGame(), ["beckon"])
        let fatal = turnOutput(of: "beckon", in: transcript)
        expectInOrder(
            fatal,
            [
                "You beckon.",
                "The reaper collects.",
                "*** You have died ***",
                "Your score is",
                "Would you like to RESTART",
            ])
        // The whisper daemon sorts after the reaper and must not run on the
        // fatal turn.
        #expect(!fatal.contains("A whisper."))
    }

    @Test func deathDuringTakeAllStopsTheLoop() async throws {
        let transcript = try await play(MorgueGame(), ["take all"])
        let turn = turnOutput(of: "take all", in: transcript)
        expectInOrder(
            turn,
            [
                "crisp apple: Taken.",
                "green poison: Ill-advised. The world goes dark.",
                "*** You have died ***",
            ])
        #expect(!turn.contains("stale bread"))
    }
}
