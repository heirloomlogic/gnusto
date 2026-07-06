import GnustoTestSupport
import Testing

@testable import Gnusto

/// The additive entity-collection helpers: `Player.inventory`,
/// `Item.contents`, and `Item.moveToPlayer()`.
struct EntityHelperTests {
    @Test func playerInventoryListsHeldItemsSortedById() async throws {
        let transcript = try await play(
            LarderGame(),
            [
                "tally",
                "open chest", "take jam", "take flour",
                "tally",
                "quit",
            ])
        // Empty-handed at the start.
        #expect(turnOutput(of: "tally", in: transcript).contains("Carrying: ."))
        // After taking two items, both appear. Order is by entity ID (the
        // stored-property name), which for these is flour before jam.
        let secondTally = transcript.components(separatedBy: "Carrying:")
        #expect(secondTally.last?.contains("bag of flour") == true)
        #expect(secondTally.last?.contains("jar of jam") == true)
    }

    @Test func itemContentsListsChildrenOnAndInside() async throws {
        let transcript = try await play(LarderGame(), ["peek", "quit"])
        let peek = turnOutput(of: "peek", in: transcript)
        // The chest's inside-children and the shelf's on-children both show.
        #expect(peek.contains("jar of jam"))
        #expect(peek.contains("bag of flour"))
        #expect(peek.contains("wax candle"))
        // The candle is on the shelf, not in the chest.
        let chestPart = peek.components(separatedBy: "Shelf:").first ?? ""
        #expect(!chestPart.contains("wax candle"))
    }

    @Test func moveToPlayerPutsTheItemInHand() async throws {
        let transcript = try await play(
            LarderGame(),
            ["conjure", "inventory", "quit"])
        #expect(turnOutput(of: "conjure", in: transcript).contains("A coin appears in your hand."))
        #expect(turnOutput(of: "inventory", in: transcript).contains("gold coin"))
    }
}
