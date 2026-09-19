import GnustoTestSupport
import Testing

@testable import Gnusto

/// ``end(won:)`` — issue #511. Pins the two endings `die(_:)` never reaches
/// (nobody died). The third worked example the issue asks for — death
/// followed by reincarnation — is already covered by
/// `DeathHookTests.aConsumingHandlerResurrectsAndPlayContinues`.
struct EndingTests {
    @Test func winningPrintsTheAuthorsLineThenTheScoreEpilogue() async throws {
        let transcript = try await play(VictoryGame(), ["escape"])
        let turn = turnOutput(of: "escape", in: transcript)
        expectInOrder(
            turn,
            [
                "The door swings open onto open sky. You have won!",
                "Your score is 1 of a possible 1, in 1 turn.",
            ])
    }

    @Test func losingWithoutDyingPrintsTheAuthorsLineThenTheScoreEpilogue() async throws {
        let transcript = try await play(DefeatGame(), ["surrender"])
        let turn = turnOutput(of: "surrender", in: transcript)
        expectInOrder(
            turn,
            [
                "You set down your tools. The vault seals. You have lost.",
                "Your score is 0, in 1 turn.",
            ])
        // No death banner or prompt — this is not `die(_:)`.
        #expect(!turn.contains("*** You have died ***"))
        #expect(!turn.contains("Would you like to RESTART"))
    }

    @Test func winningEndsPlayImmediatelyUnlikeDeath() async throws {
        let world = try cachedWorld(VictoryGame(), seed: 1)
        _ = await world.begin()
        let result = await world.perform("escape")
        #expect(result.isFinished)
    }

    @Test func losingEndsPlayImmediatelyUnlikeDeath() async throws {
        let world = try cachedWorld(DefeatGame(), seed: 1)
        _ = await world.begin()
        let result = await world.perform("surrender")
        #expect(result.isFinished)
    }
}
