import Foundation
import Gnusto
import GnustoTestSupport
import Testing

@testable import Zork1

/// The endgame wiring: all nineteen treasures in the trophy case reveal the
/// ancient map, the map opens the way southwest from West of House to the Stone
/// Barrow, and entering the barrow wins the game at 350 points.
///
/// The full nineteen-treasure collection is a several-hundred-command run and is
/// exercised end-to-end by the walkthrough in ``Zork1WalkthroughTests``. What is
/// deterministic without it — the southwest gate, and that a partial hoard does
/// *not* open the barrow — is pinned here. Both tests are seedless: they stay
/// above ground, clear of the roaming thief's random stream.
struct Zork1EndgameTests {
    /// Before the map appears there is no path southwest — the barrow stays
    /// hidden, and the refusal names the only ways out of West of House.
    @Test func southwestIsRefusedBeforeTheMapAppears() async throws {
        let transcript = try await play(Zork1(), ["southwest"])

        expectInOrder(transcript, ["no path southwest"])
        // The barrow is unreachable, and the game is nowhere near won.
        #expect(!transcript.contains("Stone Barrow"))
        #expect(!transcript.contains("Master Adventurers"))
    }

    /// One treasure is not nineteen. Casing the jeweled egg alone reveals no
    /// map, and the way southwest stays shut — proof the gate wants the whole
    /// hoard, not any single deposit.
    @Test func aLoneTreasureDoesNotOpenTheBarrow() async throws {
        let transcript = try await play(
            Zork1(),
            [
                "north", "north", "up", "take egg",  // fetch the jeweled egg
                "down", "south", "west",  // back to West of House
                "south", "east", "open window", "west",  // into the Kitchen
                "west",  // Living Room
                "open trophy case", "put egg in trophy case",
                "east", "east", "north", "west",  // back to West of House
                "southwest",  // still no barrow
            ])

        expectInOrder(
            transcript,
            [
                "You put the jewel-encrusted egg in the trophy case.",
                "no path southwest",
            ])
        // The map materialises only on the nineteenth treasure, never the first.
        #expect(!transcript.contains("ancient map lies among"))
    }
}
