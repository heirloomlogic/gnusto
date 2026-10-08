import Testing

@testable import Dungeon
@testable import Gnusto
@testable import Zork1

/// ``DeclaredMap`` against the definition it was read from, for the two
/// largest maps: no room dropped, no exit dropped, every region carried.
/// `@testable`, unlike `DeclaredMapTests`, because the definition is internal.
struct DeclaredMapCoverageTests {
    @discardableResult
    private func expectComplete(_ game: some Game) throws -> DeclaredMap {
        let prepared = try PreparedGame(game)
        let map = prepared.declaredMap
        let definition = prepared.definition
        #expect(map.rooms.map(\.id) == definition.locations.keys.sorted())
        for room in map.rooms {
            let declared = definition.exits[room.id] ?? [:]
            #expect(Set(room.exits.map(\.direction)) == Set(declared.keys), "\(room.id)")
            #expect(room.region == definition.locations[room.id]?.mapRegion, "\(room.id)")
            let secret = definition.secretExits[room.id] ?? []
            #expect(Set(room.exits.filter(\.isSecret).map(\.direction)) == secret, "\(room.id)")
        }
        return map
    }

    @Test func zorkListsEveryRoomExitAndRegion() throws {
        let map = try expectComplete(Zork1())
        #expect(map.rooms.contains { $0.region == "Maze" })
    }

    @Test func dungeonListsEveryRoomAndExit() throws {
        try expectComplete(Dungeon())
    }

    /// Every dynamic exit in Dungeon names a room for a map, and that room is
    /// one the map lists. The survey describes play, so it still reports no
    /// destination for any of them.
    @Test func everyDungeonDynamicExitHasAMapDestination() throws {
        let prepared = try PreparedGame(Dungeon())
        let rooms = Dictionary(uniqueKeysWithValues: prepared.declaredMap.rooms.map { ($0.id, $0) })
        let dynamic = rooms.values.flatMap { room in
            room.exits.filter { $0.kind == .dynamic }.map { (room.id, $0) }
        }
        #expect(!dynamic.isEmpty)
        for (roomID, exit) in dynamic {
            let destination = try #require(exit.destination, "\(roomID) \(exit.direction)")
            #expect(rooms[destination] != nil, "\(roomID) \(exit.direction)")
        }
        func destination(_ room: String, _ direction: Direction) -> EntityID? {
            rooms[EntityID(room)]?.exits.first { $0.direction == direction }?.destination
        }
        #expect(destination("DungeonRoundRoom.roundRoom", .north) == EntityID("DungeonTemple.engravingsCave"))
        #expect(destination("DungeonMirror.slideRoom", .down) == EntityID("DungeonPalantir.slideOne"))

        let survey = PlaytestSurvey(prepared.definition).json
        let surveyed = try #require(survey["rooms"]?.arrayValue).flatMap { $0["exits"]?.arrayValue ?? [] }
        let surveyedDynamic = surveyed.filter { $0["kind"]?.stringValue == "dynamic" }
        #expect(surveyedDynamic.count == dynamic.count)
        #expect(surveyedDynamic.allSatisfy { $0["destination"] == nil })
    }

    /// The survey reads its exits through the export but keeps listing them in
    /// alphabetical order of direction, as it did before the export existed.
    @Test func theSurveyListsExitsAlphabetically() throws {
        let definition = try PreparedGame(Zork1()).definition
        let survey = PlaytestSurvey(definition)
        for room in survey.rooms {
            let directions = room.exits.map(\.direction.rawValue)
            #expect(directions == directions.sorted(), "\(room.id)")
        }
    }
}
