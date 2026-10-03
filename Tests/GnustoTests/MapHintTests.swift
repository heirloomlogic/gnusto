import Testing

@testable import Gnusto
@testable import Zork1

struct MapHintTests {
    @Test func roomsSharingARegionCarryItsLabel() throws {
        let (definition, _) = try Bootstrap.build(MapHintGame())
        #expect(definition.locations[EntityID("mazeA")]?.mapRegion == "Maze")
        #expect(definition.locations[EntityID("mazeB")]?.mapRegion == "Maze")
        #expect(definition.locations[EntityID("hall")]?.mapRegion == nil)
    }

    @Test func aSecretExitIsRecordedAndAnOrdinaryOneIsNot() throws {
        let (definition, _) = try Bootstrap.build(MapHintGame())
        #expect(definition.secretExits[EntityID("hall")] == [.up])
        #expect(definition.secretExits[EntityID("attic")] == nil)
        // `.secret` changes what a map draws, never where the exit goes.
        guard case .to(let destination)? = definition.exits[EntityID("hall")]?[.up] else {
            Issue.record("the secret exit is not an ordinary exit to the attic")
            return
        }
        #expect(destination == EntityID("attic"))
    }

    @Test func aSecretBlockedExitIsFatal() {
        expectDiagnostic(
            SecretBlockedExitGame(),
            "\"hall\"'s west exit is blocked and declared .secret; a blocked exit is never walked, so it would never be drawn."
        )
    }

    @Test func secretAfterAnEntryThatIsNotAnExitIsFatal() {
        expectDiagnostic(
            SecretPlacementGame(),
            "the placement of \"coin\" is declared .secret; only an exit can be secret.")
    }

    @Test func aDuplicateOrBlankRegionIsFatal() {
        expectDiagnostic(BadRegionGame(), "location \"hall\" declares mapRegion(…) more than once.")
        expectDiagnostic(BadRegionGame(), "location \"cellar\" declares a whitespace-only mapRegion(…) trait.")
        expectDiagnostic(BadRegionGame(), "location \"empty\" declares an empty mapRegion(…) trait.")
    }

    @Test func secretHintsCoverEveryPassableExitFamilyWithoutChangingTargets() throws {
        let (definition, _) = try Bootstrap.build(SecretExitKindsGame())
        let exits = definition.exits[EntityID("hall")]
        #expect(definition.secretExits[EntityID("hall")] == [.north, .south, .east])
        #expect(definition.secretExits[EntityID("attic")] == nil)
        guard case .door(let doorDestination, let door)? = exits?[.north] else {
            Issue.record("the secret door exit lost its door target")
            return
        }
        #expect(doorDestination == EntityID("attic"))
        #expect(door == EntityID("hatch"))
        guard case .conditional(let conditionalDestination, let condition, let blocked)? = exits?[.south] else {
            Issue.record("the secret conditional exit lost its condition")
            return
        }
        #expect(conditionalDestination == EntityID("attic"))
        #expect(condition())
        #expect(blocked == "The way is shut.")
        guard case .dynamic? = exits?[.east] else {
            Issue.record("the secret dynamic exit lost its runtime destination")
            return
        }
        guard case .to(let ordinaryDestination)? = exits?[.west] else {
            Issue.record("the ordinary exit lost its target")
            return
        }
        #expect(ordinaryDestination == EntityID("attic"))
    }

    @Test func secretPlayerStartsAndLockEntriesAreFatal() {
        expectDiagnostic(
            SecretStartAndLockGame(),
            "player.starts(in:) is declared .secret; only an exit can be secret.")
        expectDiagnostic(
            SecretStartAndLockGame(),
            "the lockedBy entry for \"box\" is declared .secret; only an exit can be secret.")
    }

    @Test func zorkOnesMazeIsOneRegion() throws {
        let (definition, _) = try Bootstrap.build(Zork1())
        let maze = definition.locations.filter { $0.value.mapRegion == "Maze" }.keys
        #expect(maze.count == 19)
        #expect(maze.contains(EntityID("ZorkMaze.maze1")))
        #expect(maze.contains(EntityID("ZorkMaze.deadEnd4")))
        #expect(!maze.contains(EntityID("ZorkMaze.gratingRoom")))
        #expect(
            Set(maze)
                == Set(
                    [
                        "ZorkMaze.maze1", "ZorkMaze.maze2", "ZorkMaze.maze3", "ZorkMaze.maze4",
                        "ZorkMaze.maze5", "ZorkMaze.maze6", "ZorkMaze.maze7", "ZorkMaze.maze8",
                        "ZorkMaze.maze9", "ZorkMaze.maze10", "ZorkMaze.maze11", "ZorkMaze.maze12",
                        "ZorkMaze.maze13", "ZorkMaze.maze14", "ZorkMaze.maze15",
                        "ZorkMaze.deadEnd1", "ZorkMaze.deadEnd2", "ZorkMaze.deadEnd3", "ZorkMaze.deadEnd4",
                    ].map(EntityID.init)))
    }

    /// Bootstrapping `game` fails, and its diagnostics include `expected`.
    private func expectDiagnostic(
        _ game: some Game, _ expected: String, sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(sourceLocation: sourceLocation) {
            try Bootstrap.build(game)
        } throws: { error in
            (error as? BootstrapError)?.diagnostics.contains(expected) == true
        }
    }
}
