import Synchronization
import Testing

@testable import Gnusto

struct MapViewTests {
    private let open = MapExit(kind: .open, isSecret: false)
    private let blocked = MapExit(kind: .blocked, isSecret: false)

    /// A fresh ``CartographyGame`` with its opening already printed.
    private func world() async throws -> GameWorld {
        let world = try GameWorld(game: CartographyGame(), seed: 0)
        _ = await world.begin()
        return world
    }

    @Test func theHallShowsOnlyWhatThePlayerCouldFind() async throws {
        let view = try await world().mapView()
        #expect(view.id == EntityID("hall"))
        #expect(view.name == "Hall")
        #expect(view.region == nil)
        // The trap door is hidden and the gate is latched: neither is drawn yet.
        #expect(view.exits == [.north: open, .west: blocked])
    }

    @Test func aRevealedDoorAndAnOpenedGateAppear() async throws {
        let world = try await world()
        _ = await world.perform("push rug")
        #expect(await world.mapView().exits[.down] == open)
        #expect(await world.mapView().exits[.east] == nil)
        _ = await world.perform("unlatch")
        #expect(await world.mapView().exits[.east] == open)
    }

    @Test func theKitchenFlagsItsSecretAndItsDynamicExit() async throws {
        let world = try await world()
        _ = await world.perform("north")
        #expect(
            await world.mapView().exits == [
                .south: open,
                .up: MapExit(kind: .open, isSecret: true),
                .east: MapExit(kind: .unknownDestination, isSecret: false),
            ])
    }

    @Test func aDarkRoomShowsNoExits() async throws {
        let world = try await world()
        _ = await world.perform("push rug")
        _ = await world.perform("open trap door")
        let arrival = await world.perform("down")
        let view = await world.mapView()
        #expect(view.id == EntityID("cellar"))
        #expect(view.name == "Cellar")
        #expect(view.name == arrival.status.locationName)
        #expect(view.exits.isEmpty)
    }

    @Test func aMazeRoomCarriesItsRegion() async throws {
        let world = try await world()
        _ = await world.perform("north")
        _ = await world.perform("east")
        let view = await world.mapView()
        #expect(view.region == "Maze")
        #expect(view.exits == [.north: open])
    }

    @Test func askingCostsNoTurnAndNoRandomness() async throws {
        let world = try await world()
        _ = await world.perform("unlatch")
        let before = await world.snapshot()
        for _ in 0..<5 { _ = await world.mapView() }
        let after = await world.snapshot()
        #expect(after.moves == before.moves)
        #expect(after.rngState == before.rngState)
        #expect(after.globals == before.globals)
    }

    @Test func exitConditionsCannotCommitOrShareTheirWritesThroughAQuery() async throws {
        let world = try GameWorld(game: QueryMutationGame(), seed: 0)
        _ = await world.begin()
        let before = await world.snapshot()
        for _ in 0..<5 {
            let view = await world.mapView()
            // Each condition opens the same item and increments the same global.
            // A shared frame would expose exactly one of these two exits, in any order.
            #expect(view.exits[.east] == open)
            #expect(view.exits[.north] == open)
        }
        let after = await world.snapshot()
        #expect(after.globals == before.globals)
        #expect(after.moves == before.moves)
        #expect(after.rngState == before.rngState)
        #expect(after.openItems == before.openItems)
        #expect(after.playerLocation == before.playerLocation)
        #expect(after.placements == before.placements)
    }

    @Test func aDynamicExitIsNotResolvedUntilItIsWalked() async throws {
        let destinationReads = Mutex(0)
        let game = QueryMutationGame(destinationRead: { destinationReads.withLock { $0 += 1 } })
        let world = try GameWorld(game: game, seed: 0)
        _ = await world.begin()
        for _ in 0..<5 {
            #expect(
                await world.mapView().exits[.west]
                    == MapExit(kind: .unknownDestination, isSecret: false))
        }
        #expect(destinationReads.withLock { $0 } == 0)
        _ = await world.perform("west")
        #expect(destinationReads.withLock { $0 } == 1)
    }
}
