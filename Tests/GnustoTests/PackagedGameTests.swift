import Gnusto
import Testing

struct PackagedGameTests {
    @Test func factoryBootsIndependentWorlds() async throws {
        let packaged = PackagedGame { DialRoomGame() }
        #expect(packaged.title == "The Dial Room")
        let first = try GameWorld(game: packaged.makeGame(), seed: 0)
        let second = try GameWorld(game: packaged.makeGame(), seed: 0)
        _ = await first.begin()
        _ = await second.begin()
        _ = await first.perform("north")
        let changed = await first.perform("notch")
        let unchanged = await second.perform("north")
        #expect(changed.status.moves == 2)
        #expect(unchanged.status.moves == 1)
        #expect(changed.output.contains("standing at notch 1"))
        #expect(unchanged.output.contains("standing at notch 0"))
    }

    @Test func anUnseededPreparedWorldRestartsItsOwnState() async throws {
        let packaged = PackagedGame { DialRoomGame() }
        let prepared = try PreparedGame(packaged.makeGame())
        let world = GameWorld(prepared: prepared)
        _ = await world.begin()
        _ = await world.perform("north")
        _ = await world.perform("notch")
        _ = await world.perform("restart")
        let replayed = await world.perform("north")
        #expect(replayed.output.contains("standing at notch 0"))
        #expect(replayed.status.moves == 1)
    }
}
