import GnustoTestSupport
import Testing

@testable import MyGame

struct MyGameTests {
    @Test func ringingTheBellWinsTheGame() async throws {
        let transcript = try await play(
            MyGame(),
            ["take rope", "north", "ring bell"])

        expectInOrder(
            transcript,
            [
                "Village Garden",
                "Taken.",
                "Bell Tower",
                "The great bronze bell peals",
                "Your score is 1 of a possible 1",
            ])
    }

    @Test func bellRefusesWithoutTheRope() async throws {
        let transcript = try await play(MyGame(), ["north", "ring bell"])

        expectInOrder(transcript, ["You need something to swing the clapper with."])
    }

    @Test func theVillageExitIsBlocked() async throws {
        let transcript = try await play(MyGame(), ["south"])

        expectInOrder(transcript, ["your business is the bell"])
    }
}
