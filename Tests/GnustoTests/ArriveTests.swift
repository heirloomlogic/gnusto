import GnustoTestSupport
import Testing

@testable import Gnusto

/// `arrive(at:)`: the teleport-and-look every rule that moves the player
/// without a `go` used to hand-roll as `player.location = room` followed by
/// `describeSurroundings()`.
struct ArriveTests {
    @Test func arriveMovesThePlayerAndDescribesTheRoom() async throws {
        let transcript = try await play(BlinkGame(), ["blink", "quit"])
        let blink = turnOutput(of: "blink", in: transcript)
        // The heading, the long description, and the item paragraph: a full
        // LOOK, not a bare move.
        expectInOrder(
            blink,
            ["Vault", "Cold, and quite empty.", "brass lamp"])
    }

    @Test func arrivingIsNotWalkingIn() async throws {
        // The documented caveat, and the reason it is documented: `onEnter`
        // belongs to the `go` action, so a rule that teleports into a room
        // which announces, scores or kills on arrival has to do that itself.
        let transcript = try await play(
            BlinkGame(), ["blink", "south", "north", "quit"])
        #expect(!turnOutput(of: "blink", in: transcript).contains("A bell rings"))
        // Walked into by the declared exit, the same room does ring.
        #expect(turnOutput(of: "north", in: transcript).contains("A bell rings"))
    }

    @Test func withoutTheRoomNameEverythingButTheHeadingPrints() async throws {
        let transcript = try await play(BlinkGame(), ["east", "edge", "quit"])
        // Walking in prints the heading.
        #expect(turnOutput(of: "east", in: transcript).contains("Ledge"))
        // A step taken within the room does not — the player did not arrive
        // anywhere — but the description still does.
        let edge = turnOutput(of: "edge", in: transcript)
        #expect(!edge.contains("Ledge"))
        #expect(edge.contains("A shelf of rock"))
    }

    @Test func arriveIsLegalWhereReplyIsNot() async throws {
        // From a fuse: no turn to end, and nothing that throws. This is why
        // the helper does not end the turn itself.
        let transcript = try await play(BlinkGame(), ["summon", "wait", "quit"])
        expectInOrder(
            turnOutput(of: "wait", in: transcript),
            [
                "The floor tilts, and you are somewhere else.",
                "Hall",
                "Panelled, and longer than it is wide.",
            ])
    }
}
