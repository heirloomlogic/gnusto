import GnustoTestSupport
import Testing

@testable import Gnusto

/// The game-level death hook, `Game.onDeath()`. The default (`.fallThrough`)
/// is exercised by the existing `DeathTests`/`MorgueGame` suite, which must
/// stay byte-identical. These cover the two custom shapes: consuming the
/// death (resurrection, play continues) and running the handler but still
/// falling through to the standard prompt.
struct DeathHookTests {
    @Test func aConsumingHandlerResurrectsAndPlayContinues() async throws {
        let transcript = try await play(
            ResurrectionGame(),
            ["provoke", "count", "look", "quit"])
        let fatal = turnOutput(of: "provoke", in: transcript)
        // The death message prints, then the handler's prose.
        expectInOrder(
            fatal,
            [
                "The lurking thing strikes you dead.",
                "A cold wind gathers you up and sets you down elsewhere.",
            ])
        // No banner, no prompt — the death was consumed.
        #expect(!fatal.contains("*** You have died ***"))
        #expect(!fatal.contains("Would you like to RESTART"))
        // Play continues: the counter bumped and normal commands still run.
        #expect(turnOutput(of: "count", in: transcript).contains("Deaths: 1."))
        // The player woke up in the clearing, not the cave.
        #expect(turnOutput(of: "look", in: transcript).contains("Sunlit Clearing"))
    }

    @Test func aConsumedDeathDocksScoreAndScattersInventory() async throws {
        let transcript = try await play(
            ResurrectionGame(),
            ["provoke", "score", "inventory", "quit"])
        // The toll was charged: 0 - 10 = -10.
        #expect(turnOutput(of: "score", in: transcript).contains("Your score is -10"))
        // The carried torch was dropped in the cave, so the resurrected
        // player is empty-handed.
        #expect(turnOutput(of: "inventory", in: transcript).contains("empty-handed"))
    }

    @Test func undoAfterAConsumedDeathRewindsTheWholeFatalTurn() async throws {
        // UNDO after a consumed death rewinds the entire fatal turn — the
        // death, the resurrection, and everything the handler did — back to
        // where the player stood before it. That coherence is the documented
        // contract.
        let transcript = try await play(
            ResurrectionGame(),
            ["provoke", "undo", "count", "look", "quit"])
        let undo = turnOutput(of: "undo", in: transcript)
        #expect(undo.contains("Previous turn undone."))
        // Back in the cave, before the death.
        #expect(undo.contains("Dark Cave"))
        // The death counter the handler bumped is rolled back too.
        #expect(turnOutput(of: "count", in: transcript).contains("Deaths: 0."))
    }

    @Test func aFallThroughHandlerStillReachesThePrompt() async throws {
        let transcript = try await play(
            StubbornDeathGame(),
            ["jump", "look"])
        let fatal = turnOutput(of: "jump", in: transcript)
        // The handler ran (its line prints) but the standard death path
        // followed: message, handler line, banner, score, prompt.
        expectInOrder(
            fatal,
            [
                "You leap, and the ground rushes up.",
                "(The mountain notes your passing.)",
                "*** You have died ***",
                "Your score is",
                "Would you like to RESTART, RESTORE a saved game, UNDO your last turn, or QUIT?",
            ])
        // Still at the prompt on the next line.
        #expect(turnOutput(of: "look", in: transcript).contains("Please type RESTART"))
    }
}
