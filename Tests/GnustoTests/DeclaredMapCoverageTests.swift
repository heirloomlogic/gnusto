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
