import Foundation
import Gnusto
import Synchronization
import Testing

@testable import Dungeon
@testable import Zork1

/// ``DeclaredMap`` through the public API only: `Gnusto` is imported without
/// `@testable`, so everything here is what an external package can reach.
struct DeclaredMapTests {
    private func room(_ id: String, in map: DeclaredMap) throws -> DeclaredMap.Room {
        try #require(map.rooms.first { $0.id.raw == id })
    }

    @Test func everyRoomIsListedInIDOrder() throws {
        let map = try PreparedGame(CartographyGame()).declaredMap
        #expect(
            map.rooms.map(\.id.raw) == [
                "cellar", "garden", "hall", "kitchen", "loft", "mazeA", "mazeB",
            ])
    }

    @Test func eachExitKindReportsWhatWasDeclared() throws {
        let map = try PreparedGame(CartographyGame()).declaredMap
        let hall = try room("hall", in: map)
        #expect(hall.name == "Hall")
        #expect(hall.region == nil)
        // Direction order is `Direction.allCases`, not the order of the map block.
        #expect(
            hall.exits.map(\.summary) == [
                "north open kitchen",
                "east conditional garden",
                "west blocked",
                "down door cellar via trapDoor",
            ])

        let kitchen = try room("kitchen", in: map)
        #expect(
            kitchen.exits.map(\.summary) == [
                "south open hall",
                "east dynamic",
                "up open loft secret",
            ])
    }

    @Test func aRegionIsCarriedAndTwoRoomsMayShareAName() throws {
        let map = try PreparedGame(CartographyGame()).declaredMap
        let mazeA = try room("mazeA", in: map)
        let mazeB = try room("mazeB", in: map)
        #expect(mazeA.region == "Maze")
        #expect(mazeB.region == "Maze")
        #expect(mazeA.name == mazeB.name)
        #expect(mazeA.exits.map(\.summary) == ["north open mazeB"])
    }

    @Test func readingTheMapRunsNoExitClosure() async throws {
        let calls = Mutex(0)
        var game = ExitTrapGame()
        game.onCall = { calls.withLock { $0 += 1 } }
        let prepared = try PreparedGame(game)
        let map = prepared.declaredMap
        _ = try JSONEncoder().encode(map)
        #expect(calls.withLock { $0 } == 0)
        let hall = try room("hall", in: map)
        #expect(hall.exits.map(\.kind) == [.conditional, .dynamic])

        // The closures are live: walking the dynamic exit calls one.
        let world = GameWorld(prepared: prepared, seed: 0)
        _ = await world.begin()
        _ = await world.perform("east")
        #expect(calls.withLock { $0 } > 0)
    }

    @Test func encodingIsByteIdenticalAcrossPreparations() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let map = try PreparedGame(Dungeon()).declaredMap
        let first = try encoder.encode(map)
        let second = try encoder.encode(PreparedGame(Dungeon()).declaredMap)
        #expect(first == second)
        #expect(try JSONDecoder().decode(DeclaredMap.self, from: first) == map)
    }

    /// IDs are bare strings in the JSON, a `nil` field is left out, and the
    /// JSON, regions included, decodes back to the same map.
    @Test func idsEncodeAsPlainStrings() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let map = try PreparedGame(CartographyGame()).declaredMap
        let json = String(decoding: try encoder.encode(map), as: UTF8.self)
        #expect(
            json.contains(
                #"{"exits":[{"destination":"hall","direction":"south","isSecret":false,"kind":"open"},"#
                    + #"{"direction":"east","isSecret":false,"kind":"dynamic"},"#
                    + #"{"destination":"loft","direction":"up","isSecret":true,"kind":"open"}],"#
                    + #""id":"kitchen","name":"Kitchen"}"#))
        #expect(
            json.contains(
                #"{"destination":"cellar","direction":"down","door":"trapDoor","isSecret":false,"kind":"door"}"#))
        #expect(json.contains(#""region":"Maze""#))
        #expect(!json.contains("raw"))
        #expect(try JSONDecoder().decode(DeclaredMap.self, from: Data(json.utf8)) == map)
    }

    @Test func aPackagedGameReachesTheSameMap() throws {
        let packaged = PackagedGame { CartographyGame() }
        let packagedMap = try PreparedGame(packaged.makeGame()).declaredMap
        let directMap = try PreparedGame(CartographyGame()).declaredMap
        #expect(packagedMap == directMap)
    }

    /// The join key: the ID a walk reports is the ID the export lists, with the
    /// same name and region, and the exit walked is one the export lists.
    @Test func aZorkWalkLandsOnRoomsTheExportLists() async throws {
        let prepared = try PreparedGame(Zork1())
        let rooms = Dictionary(
            uniqueKeysWithValues: prepared.declaredMap.rooms.map { ($0.id, $0) })
        let world = GameWorld(prepared: prepared, seed: 0)
        _ = await world.begin()
        var visited: [EntityID] = []
        var walks = 0
        for command in ["look", "north", "east", "open window", "west", "west", "east", "up"] {
            let result = await world.perform(command)
            let view = await world.mapView()
            if case .walked(let from, let to, let direction)? = result.report.movement {
                #expect(to == view.id)
                let exit = try #require(
                    rooms[from]?.exits.first { $0.direction == direction },
                    "\(from) has no \(direction) exit in the export")
                if exit.kind != .blocked, exit.kind != .dynamic {
                    #expect(exit.destination == to)
                }
                walks += 1
            }
            let room = try #require(rooms[view.id], "\(view.id) is not in the export")
            #expect(room.name == view.name)
            #expect(room.region == view.region)
            visited.append(view.id)
        }
        // The route really moved: six distinct rooms from West of House to the attic.
        #expect(Set(visited).count == 6)
        #expect(walks > 0)
    }
}

extension DeclaredMap.Exit {
    /// Every field on one line: `"down door cellar via trapDoor"`.
    fileprivate var summary: String {
        var words = [direction.rawValue, kind.rawValue]
        if let destination { words.append(destination.raw) }
        if let door { words += ["via", door.raw] }
        if isSecret { words.append("secret") }
        return words.joined(separator: " ")
    }
}

/// One conditional and one dynamic exit, both reporting every call.
private struct ExitTrapGame: Game {
    let title = "Exit Trap"
    let intro = "A trap for a map reader."
    var onCall: @Sendable () -> Void = {}

    let hall = Location {
        name("Hall")
        description("A hall.")
    }
    let garden = Location {
        name("Garden")
        description("A garden.")
    }

    var map: WorldMap {
        player.starts(in: hall)
        hall.north(
            garden,
            when: {
                onCall()
                return true
            }, otherwise: "Shut.")
        hall.east {
            onCall()
            return garden
        }
    }
}
