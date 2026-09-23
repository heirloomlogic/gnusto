import GnustoTestSupport
import Testing

@testable import Gnusto

/// A worn item that a rule moves off the player stops being worn, whichever
/// mover the rule uses (issue #604).
struct WornMoveTests {
    /// The issue's case: `scatterInventory` (what a death runs in Dungeon)
    /// drops a worn hat, the player picks it up, and it comes back held rather
    /// than worn.
    @Test func aScatteredHatIsPickedUpHeldAndWearsAgain() async throws {
        let transcript = try await play(
            WardrobeGame(), ["scatter", "take hat", "inventory", "wear hat"])
        let inventory = turnOutput(of: "inventory", in: transcript)
        #expect(inventory.contains("straw hat"))
        #expect(!inventory.contains("(being worn)"))
        #expect(turnOutput(of: "wear hat", in: transcript).contains("You put on the straw hat."))
    }

    /// Kept apart from the WEAR check above: on a hat still marked worn, TAKE
    /// OFF would clear the mark and let a WEAR after it pass.
    @Test func aScatteredHatIsNotTakenOffAgain() async throws {
        let transcript = try await play(WardrobeGame(), ["scatter", "take hat", "take off hat"])
        #expect(turnOutput(of: "take off hat", in: transcript).contains("You're not wearing that."))
    }

    /// A rule that moves the hat off the player with `move(to:)`,
    /// `move(inside:)`, `move(onto:)` or `move(heldBy:)`.
    @Test(arguments: ["fling", "stow", "perch", "steal"])
    func aRuleThatMovesTheHatOffThePlayerUnwearsIt(verb: String) async throws {
        let transcript = try await play(WardrobeGame(), ["check", verb, "check"])
        #expect(turnOutput(of: "check", in: transcript).contains("worn=true"))
        #expect(turnOutput(ofLast: "check", in: transcript).contains("worn=false"))
    }

    /// The `\.isWorn` description branch follows the flag.
    @Test func theWornDescriptionStopsOnceTheHatIsOnTheFloor() async throws {
        let transcript = try await play(WardrobeGame(), ["x hat", "fling", "x hat"])
        #expect(turnOutput(of: "x hat", in: transcript).contains("The hat sits on your head."))
        #expect(turnOutput(ofLast: "x hat", in: transcript).contains("A plain straw hat."))
    }

    /// A move that leaves the hat in the player's hands does not take it off.
    @Test func aMoveIntoThePlayersOwnHandsKeepsTheHatWorn() async throws {
        let transcript = try await play(WardrobeGame(), ["regrip", "check"])
        #expect(turnOutput(of: "check", in: transcript).contains("worn=true"))
    }
}
