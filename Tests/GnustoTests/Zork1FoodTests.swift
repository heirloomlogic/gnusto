import GnustoTestSupport
import Testing

@testable import Gnusto
@testable import Zork1

struct Zork1FoodTests {
    private static let kitchen = ["south", "east", "open window", "west", "open sack"]
    private static let lunch = EntityID("ZorkHouse.lunch")
    private static let garlic = EntityID("ZorkHouse.garlic")
    private static let sack = EntityID("ZorkHouse.sack")
    private static let bottle = EntityID("ZorkHouse.bottle")

    @Test(arguments: [false, true])
    func lunchIsEatenWhenHeldOrDirectlyInsideACarriedContainer(inSack: Bool) async throws {
        let world = try GameWorld(game: Zork1(), seed: 39)
        _ = await world.begin()
        for command in Self.kitchen + [inSack ? "take sack" : "take lunch"] {
            _ = await world.perform(command)
        }
        #expect((await world.snapshot()).placements[Self.lunch] == (inSack ? .inside(Self.sack) : .heldBy(.player)))
        if inSack { #expect((await world.snapshot()).placements[Self.sack] == .heldBy(.player)) }
        let eaten = await world.perform("eat lunch")
        #expect(eaten.output.contains("Thank you very much. It really hit the spot."))
        #expect((await world.snapshot()).placements[Self.lunch] == .nowhere)
        #expect(!(await world.perform("inventory")).output.contains("lunch"))
        let repeated = await world.perform("eat lunch")
        #expect(repeated.output.contains("can't see"))
        #expect(!repeated.output.contains("hit the spot"))
        #expect((await world.snapshot()).placements[Self.lunch] == .nowhere)
    }

    @Test(arguments: [false, true])
    func lunchRequiresPossessionOnTheFloorOrInsideAnUncarriedSack(onFloor: Bool) async throws {
        let world = try GameWorld(game: Zork1(), seed: 39)
        _ = await world.begin()
        for command in Self.kitchen + (onFloor ? ["take lunch", "drop lunch"] : []) {
            _ = await world.perform(command)
        }
        let before = await world.snapshot()
        #expect(before.placements[Self.lunch] == (onFloor ? .room(before.playerLocation) : .inside(Self.sack)))
        let refused = await world.perform("eat lunch")
        #expect(refused.output.contains("You're not holding that."))
        let after = await world.snapshot()
        #expect(after.placements[Self.lunch] == before.placements[Self.lunch])
        #expect(after.touched == before.touched)
        #expect(after.openItems == before.openItems)
    }

    @Test func lunchInATwoLevelCarriedContainerIsNotDirectlyPossessed() async throws {
        let world = try GameWorld(game: Zork1(), seed: 39)
        _ = await world.begin()
        for command in Self.kitchen + [
            "take sack", "take bottle", "open bottle", "take lunch", "put lunch in bottle", "put bottle in sack",
        ] { _ = await world.perform(command) }
        let before = await world.snapshot()
        #expect(before.placements[Self.lunch] == .inside(Self.bottle))
        #expect(before.placements[Self.bottle] == .inside(Self.sack))
        #expect(before.placements[Self.sack] == .heldBy(.player))
        #expect((await world.perform("eat lunch")).output.contains("You're not holding that."))
        #expect((await world.snapshot()).placements[Self.lunch] == before.placements[Self.lunch])
        #expect((await world.perform("take lunch")).output.contains("Taken."))
        #expect((await world.perform("eat lunch")).output.contains("It really hit the spot."))
        #expect((await world.snapshot()).placements[Self.lunch] == .nowhere)
    }

    @Test(arguments: ["floor", "held", "nested"])
    func garlicUsesItsOwnAccessibleFoodRule(placement: String) async throws {
        let world = try GameWorld(game: Zork1(), seed: 39)
        _ = await world.begin()
        let extra =
            placement == "nested"
            ? ["take sack", "take bottle", "open bottle", "take garlic", "put garlic in bottle", "put bottle in sack"]
            : ["take garlic"] + (placement == "floor" ? ["drop garlic"] : [])
        for command in Self.kitchen + extra { _ = await world.perform(command) }
        let before = await world.snapshot()
        let expected: Placement =
            placement == "nested"
            ? .inside(Self.bottle) : placement == "held" ? .heldBy(.player) : .room(before.playerLocation)
        #expect(before.placements[Self.garlic] == expected)
        let eaten = await world.perform("eat garlic")
        let output = eaten.output.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        #expect(
            output.contains(
                "What the heck! You won't make friends this way, but nobody around here is too friendly anyhow. Gulp!"))
        #expect(!output.contains("hit the spot"))
        #expect((await world.snapshot()).placements[Self.garlic] == .nowhere)
        #expect((await world.perform("eat garlic")).output.contains("can't see"))
        #expect((await world.snapshot()).placements[Self.garlic] == .nowhere)
    }

    @Test(arguments: ["lunch", "garlic"])
    func foodInAClosedTransparentCarriedHolderRefusesBeforeConsumption(food: String) async throws {
        let world = try GameWorld(game: Zork1(), seed: 39)
        _ = await world.begin()
        for command in Self.kitchen + [
            "take bottle", "open bottle", "take \(food)", "put \(food) in bottle", "close bottle",
        ] {
            _ = await world.perform(command)
        }
        let item = food == "lunch" ? Self.lunch : Self.garlic
        let before = await world.snapshot()
        #expect(before.placements[item] == .inside(Self.bottle))
        #expect(before.placements[Self.bottle] == .heldBy(.player))
        #expect(!before.openItems.contains(Self.bottle))
        #expect((await world.perform("eat \(food)")).output.contains("can't reach"))
        let after = await world.snapshot()
        #expect(after.placements[item] == before.placements[item])
        #expect(after.openItems == before.openItems)
        #expect(after.touched == before.touched)
    }

    @Test func lunchGivenToTheThiefCannotBeEatenFromHisHands() async throws {
        let world = try GameWorld(game: Zork1(), seed: 39)
        _ = await world.begin()
        for command in Zork1MazeTests.toMaze5 { _ = await world.perform(command) }
        #expect((await world.perform("give lunch to thief")).output.contains("mocking little bow"))
        let before = await world.snapshot()
        #expect(before.placements[Self.lunch] == .heldBy(EntityID("ZorkThief.thief")))
        let refused = await world.perform("eat lunch")
        #expect(refused.output.contains("can't see") || refused.output.contains("can't reach"))
        #expect((await world.snapshot()).placements[Self.lunch] == before.placements[Self.lunch])
    }

    @Test func inedibleObjectsKeepTheExistingRefusal() async throws {
        let world = try GameWorld(game: Zork1(), seed: 39)
        _ = await world.begin()
        for command in Self.kitchen { _ = await world.perform(command) }
        let before = await world.snapshot()
        #expect(
            (await world.perform("eat sack")).output.contains("I don't think that the brown sack would agree with you.")
        )
        #expect((await world.snapshot()).placements[Self.sack] == before.placements[Self.sack])
    }
}
