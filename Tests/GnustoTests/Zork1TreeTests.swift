import GnustoTestSupport
import Testing

@testable import Gnusto
@testable import Zork1

struct Zork1TreeTests {
    private static let swordToTree = [
        "south", "east", "open window", "west", "west", "take sword",
        "east", "east", "north", "north", "up",
    ]
    private static let egg = EntityID("ZorkAboveGround.egg")
    private static let brokenEgg = EntityID("ZorkAboveGround.brokenEgg")
    private static let nest = EntityID("ZorkAboveGround.nest")
    private static let canary = EntityID("ZorkHouse.canary")
    private static let brokenCanary = EntityID("ZorkHouse.brokenCanary")
    private static let sword = EntityID("ZorkHouse.sword")
    private static let path = EntityID("ZorkAboveGround.forestPath")

    @Test func thePortableNestCarriesItsClosedEgg() async throws {
        let world = try GameWorld(game: Zork1(), seed: 39)
        _ = await world.begin()
        for command in ["north", "north", "up"] { _ = await world.perform(command) }
        let take = await world.perform("take bird's nest")
        #expect(take.output.contains("Taken."))
        let state = await world.snapshot()
        #expect(state.placements[Self.nest] == .heldBy(.player))
        #expect(state.placements[Self.egg] == .inside(Self.nest))
        #expect(state.placements[Self.canary] == .inside(Self.egg))
        let inventory = await world.perform("inventory")
        #expect(inventory.output.contains("bird's nest (containing a jewel-encrusted egg)"))
        #expect(!inventory.output.contains("canary"))
        let upstairs = await world.perform("look")
        #expect(!upstairs.output.contains("Beside you on the branch"))
        _ = await world.perform("down")
        let contents = await world.perform("look in nest")
        #expect(contents.output.contains("In the bird's nest is a jewel-encrusted egg."))
        let recovered = await world.perform("take egg from nest")
        #expect(recovered.output.contains("Taken."))
        #expect(recovered.status.score == 5)
    }

    @Test func ordinaryDropsLandOnThePath() async throws {
        let world = try GameWorld(game: Zork1(), seed: 39)
        _ = await world.begin()
        for command in Self.swordToTree { _ = await world.perform(command) }
        #expect((await world.snapshot()).placements[Self.sword] == .heldBy(.player))
        let dropped = await world.perform("drop sword")
        #expect(dropped.output.contains("The elvish sword falls to the ground."))
        #expect((await world.snapshot()).placements[Self.sword] == .room(Self.path))
        let upstairs = await world.perform("look")
        #expect(!upstairs.output.contains("elvish sword"))
        _ = await world.perform("down")
        #expect((await world.perform("look")).output.contains("elvish sword"))
        #expect((await world.perform("take sword")).output.contains("Taken."))
    }

    @Test(arguments: [false, true])
    func fallingEggsReplaceTheShellAndRuinTheContainedBird(inNest: Bool) async throws {
        let world = try GameWorld(game: Zork1(), seed: 39)
        _ = await world.begin()
        for command in Self.swordToTree { _ = await world.perform(command) }
        let taken = await world.perform(inNest ? "take nest" : "take egg")
        #expect(taken.output.contains("Taken."))
        let dropped = await world.perform(inNest ? "drop nest" : "drop egg")
        #expect(dropped.output.contains(inNest ? "The nest falls to the ground" : "The egg falls to the ground"))
        let state = await world.snapshot()
        #expect(state.placements[Self.egg] == .nowhere)
        #expect(state.placements[Self.canary] == .nowhere)
        #expect(state.placements[Self.brokenEgg] == .room(Self.path))
        #expect(state.placements[Self.brokenCanary] == .inside(Self.brokenEgg))
        #expect(state.placements[Self.nest] == .room(inNest ? Self.path : state.playerLocation))
        #expect(!(await world.perform("inventory")).output.contains("egg"))
        #expect(!(await world.perform("look")).output.contains("ruined egg"))
        _ = await world.perform("down")
        let below = await world.perform("look")
        #expect(below.output.contains("There is a somewhat ruined egg here."))
        #expect(!below.output.contains("apparently scavenged"))
        #expect(
            (await world.perform("look in egg")).output
                .contains("In the broken jewel-encrusted egg is a broken clockwork canary."))
        #expect((await world.perform("take egg")).output.contains("Taken."))
        #expect((await world.perform("inventory")).output.contains("broken jewel-encrusted egg"))
        for command in ["south", "west", "south", "east", "open window", "west", "west", "open case"] {
            _ = await world.perform(command)
        }
        let beforeDeposit = await world.perform("score")
        _ = await world.perform("put egg in case")
        _ = await world.perform("take canary from egg")
        let depositedBird = await world.perform("put canary in case")
        #expect(depositedBird.output.contains("broken clockwork canary"))
        #expect(depositedBird.status.score == beforeDeposit.status.score)
        let caseContents = await world.perform("examine case")
        #expect(caseContents.output.contains("broken jewel-encrusted egg"))
        #expect(caseContents.output.contains("broken clockwork canary"))
        #expect(!(await world.snapshot()).revealedItems.contains(EntityID("ZorkAboveGround.ancientMap")))
    }

    @Test func unheldDropsLeaveNestEggAndBirdsUnchanged() async throws {
        let world = try GameWorld(game: Zork1(), seed: 39)
        _ = await world.begin()
        for command in Self.swordToTree { _ = await world.perform(command) }
        // The egg and nest are reachable, but neither is directly carried.
        for command in ["drop egg", "drop nest"] {
            let before = await world.snapshot()
            let result = await world.perform(command)
            let after = await world.snapshot()
            #expect(result.output.contains("aren't carrying"))
            // A refused physical action still ticks unrelated roaming actors.
            for item in [Self.nest, Self.egg, Self.brokenEgg, Self.canary, Self.brokenCanary, Self.sword] {
                #expect(after.placements[item] == before.placements[item])
            }
            #expect(after.openItems == before.openItems)
            #expect(after.touched == before.touched)
        }
    }

    @Test func forcedOpeningReplacesTheShellAndRepeatedFallsDoNotRecreateIt() async throws {
        let world = try GameWorld(game: Zork1(), seed: 39)
        _ = await world.begin()
        for command in Self.swordToTree + ["take egg"] { _ = await world.perform(command) }
        let opened = await world.perform("open egg with sword")
        #expect(opened.output.contains("clumsiness of your attempt"))
        var state = await world.snapshot()
        #expect(state.placements[Self.egg] == .nowhere)
        #expect(state.placements[Self.brokenEgg] == .heldBy(.player))
        #expect(state.placements[Self.brokenCanary] == .inside(Self.brokenEgg))
        #expect((await world.perform("examine egg")).output.contains("broken jewel-encrusted egg"))
        #expect((await world.perform("open egg")).output.contains("already open"))
        _ = await world.perform("take canary")
        for _ in 0..<2 {
            let fall = await world.perform("drop egg")
            #expect(!fall.output.contains("seriously damaged"))
            #expect((await world.snapshot()).placements[Self.brokenEgg] == .room(Self.path))
            _ = await world.perform("down")
            #expect((await world.perform("look in egg")).output.contains("is empty"))
            #expect((await world.perform("take egg")).output.contains("Taken."))
            _ = await world.perform("up")
        }
        state = await world.snapshot()
        #expect(state.placements[Self.brokenCanary] == .heldBy(.player))
        #expect(state.placements[Self.canary] == .nowhere)
        #expect(state.placements[Self.egg] == .nowhere)
    }

    @Test(arguments: [false, true], [false, true])
    func droppingACleanlyOpenedEggRespectsItsCurrentContents(removeCanary: Bool, inNest: Bool) async throws {
        let world = try GameWorld(game: Zork1(), seed: 1)
        _ = await world.begin()
        // Seed 1: theft on move 38, then a fatal blow before any player OPEN.
        for command in Zork1ThiefTests.eggToLair + Array(repeating: "wait", count: 4)
            + Array(repeating: "attack thief", count: 4) + ["take egg"]
        {
            _ = await world.perform(command)
        }
        let intact = await world.perform("look in egg")
        #expect(intact.output.contains("golden clockwork canary"))
        if removeCanary { #expect((await world.perform("take canary")).output.contains("Taken.")) }
        for command in ["down", "east", "east", "east", "east", "north", "north", "up"] {
            _ = await world.perform(command)
        }
        #expect((await world.snapshot()).playerLocation == EntityID("ZorkAboveGround.upATree"))
        _ = await world.perform("put sword in egg")
        #expect((await world.snapshot()).placements[Self.sword] == .inside(Self.egg))
        if inNest {
            #expect((await world.perform("put egg in nest")).output.contains("You put"))
            #expect((await world.perform("take nest")).output.contains("Taken."))
        }
        let dropped = await world.perform(inNest ? "drop nest" : "drop egg")
        #expect(
            dropped.output.split(whereSeparator: \.isWhitespace).joined(separator: " ").contains("seriously damaged"))
        let state = await world.snapshot()
        #expect(state.placements[Self.brokenEgg] == .room(Self.path))
        #expect(state.placements[Self.sword] == .inside(Self.brokenEgg))
        #expect(state.placements[Self.canary] == (removeCanary ? .heldBy(.player) : .nowhere))
        #expect(state.placements[Self.brokenCanary] == (removeCanary ? .nowhere : .inside(Self.brokenEgg)))
        _ = await world.perform("down")
        let below = await world.perform("look in egg")
        #expect(below.output.contains("elvish sword"))
        #expect(below.output.contains("broken clockwork canary") == !removeCanary)
        if removeCanary {
            #expect((await world.perform("wind canary")).output.contains("lovely songbird"))
        }
    }

    @Test(arguments: [false, true])
    func forcedOpeningRetainsTheShellsRoomOrContainerPlacement(inNest: Bool) async throws {
        let world = try GameWorld(game: Zork1(), seed: 39)
        _ = await world.begin()
        for command in Self.swordToTree { _ = await world.perform(command) }
        if !inNest {
            #expect((await world.perform("take egg")).output.contains("Taken."))
            _ = await world.perform("down")
            #expect((await world.perform("drop egg")).output.contains("Dropped."))
        }
        let before = await world.snapshot()
        _ = await world.perform("open egg with sword")
        let after = await world.snapshot()
        #expect(after.placements[Self.brokenEgg] == before.placements[Self.egg])
        #expect(after.placements[Self.egg] == .nowhere)
        #expect(after.placements[Self.canary] == .nowhere)
        #expect(after.placements[Self.brokenCanary] == .inside(Self.brokenEgg))
        if inNest {
            let looked = await world.perform("look in nest")
            #expect(looked.output.contains("In the bird's nest is a broken jewel-encrusted egg."))
            #expect((await world.perform("take egg from nest")).output.contains("Taken."))
        }
    }

    @Test func anEmptyNestFallsWithoutDamagingTheCarriedEgg() async throws {
        let world = try GameWorld(game: Zork1(), seed: 39)
        _ = await world.begin()
        for command in ["north", "north", "up", "take egg", "take nest"] {
            _ = await world.perform(command)
        }
        for _ in 0..<2 {
            let fall = await world.perform("drop nest")
            #expect(fall.output.contains("The bird's nest falls to the ground."))
            #expect(!fall.output.contains("damaged"))
            let state = await world.snapshot()
            #expect(state.placements[Self.nest] == .room(Self.path))
            #expect(state.placements[Self.egg] == .heldBy(.player))
            #expect(state.placements[Self.canary] == .inside(Self.egg))
            #expect(state.placements[Self.brokenEgg] == .nowhere)
            _ = await world.perform("down")
            #expect((await world.perform("look in nest")).output.contains("is empty"))
            #expect(!(await world.perform("look")).output.contains("Beside you on the branch"))
            #expect((await world.perform("take nest")).output.contains("Taken."))
            _ = await world.perform("up")
        }
    }
}
