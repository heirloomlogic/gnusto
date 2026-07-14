import Foundation
import Gnusto
import GnustoTestSupport
import Testing

@testable import Zork1

/// Winding the clockwork canary — the songbird that drops the brass bauble
/// (canary find 6 / case 4, bauble find 1 / case 1). The intact bird is gated
/// behind the thief's clean-open service, which is impractical to pin against a
/// roaming thief, so the full intact `wind canary` → bauble → case run is
/// exercised by the walkthrough in ``Zork1WalkthroughTests``. What is
/// deterministic — the ruined bird, and the forest gate — is pinned here.
struct Zork1BaubleTests {
    /// Force the egg open by hand and you wreck the bird; winding the ruin only
    /// grinds — no song, no songbird, no bauble — even standing in the forest
    /// where an intact canary would have summoned one.
    @Test func windingTheRuinedCanaryOnlyGrinds() async throws {
        let transcript = try await play(
            Zork1(),
            [
                "north", "north", "up",  // West of House → Forest Path → Up a Tree
                "take egg",  // the egg pays 5 on the find
                "open egg",  // forced open by hand: wrecks the canary
                "take canary",  // the broken bird
                "down",  // back down to the Forest Path
                "wind canary",
            ])

        expectInOrder(
            transcript,
            [
                "grinding"  // Prose.brokenCanaryWinds
            ])
        // No songbird, and no bauble ever falls from a ruined bird.
        #expect(!transcript.contains("songbird"))
        #expect(!transcript.contains("bauble"))
    }

    /// The ruined bird carries no value: casing it pays nothing, where the
    /// intact canary would have paid four. (The original grudgingly awards a
    /// single point; here forcing the egg simply forfeits the score — see
    /// `FIDELITY.md`.) The score is identical on both sides of the deposit.
    @Test func theRuinedCanaryIsWorthlessInTheCase() async throws {
        let transcript = try await play(
            Zork1(),
            [
                "north", "north", "up", "take egg", "open egg", "take canary",
                "down", "south", "west",  // back to West of House
                "south", "east", "open window", "west",  // into the Kitchen
                "west",  // Living Room
                "open trophy case", "score",  // score before the deposit
                "put canary in trophy case", "score",  // score after — unchanged
            ])

        expectInOrder(transcript, ["You put the broken clockwork canary in the trophy case."])
        let scores = transcript.components(separatedBy: "Your score is ")
        #expect(scores.count == 3)
        let before = scores[1].prefix(while: { $0 != " " })
        let after = scores[2].prefix(while: { $0 != " " })
        #expect(before == after)
    }
}
