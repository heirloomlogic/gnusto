import GnustoTestSupport
import Testing

@testable import Gnusto

/// Live proxy reads and writes round-trip through the turn frame into
/// committed state, observed through subsequent turns.
struct ProxyFrameTests {
    @Test func proxiesReadAndWriteLiveState() async throws {
        let transcript = try await play(
            ProxyProbeGame(),
            ["take candle", "examine candle", "score", "look"])

        // Inside the take turn: reads of isLit, player.location equality,
        // and the @Global increment all see live values. `isHeld` reflects
        // `Placement.heldBy(.player)`: false before the take, true after.
        expectInOrder(
            transcript,
            [
                "lit=true here=true counter=3 heldBefore=false",
                "Taken.",
                "held=true worn=false",
            ])

        // The description override committed and is visible next turn.
        #expect(transcript.contains("Now dusted with fingerprints."))
        #expect(!transcript.contains("Plain wax."))

        // player.score += 5 committed.
        #expect(transcript.contains("Your score is 5 of a possible 10"))

        // porch.isLit = false committed: the later "look" is pitch black.
        #expect(turnOutput(of: "look", in: transcript).contains("pitch black"))
    }

    @Test func globalsPersistAcrossTurns() async throws {
        // Each refused take increments `blunders` before refusing; the
        // pre-refusal mutation must persist into committed state.
        let transcript = try await play(
            OrderProbeGame(),
            ["drop widget", "take widget", "take widget", "examine widget"])
        #expect(transcript.contains("blunders=2"))
    }
}
