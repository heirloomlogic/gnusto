import GnustoTestSupport
import Testing

@testable import Gnusto
@testable import Zork1

struct Zork1LeavesTests {
    private static let leaves = EntityID("ZorkAboveGround.leaves")
    private static let grating = EntityID("ZorkAboveGround.grating")
    private static let clearing = EntityID("ZorkAboveGround.clearingGrating")
    private static let below = EntityID("ZorkMaze.gratingRoom")
    private static let toBelow =
        Zork1MazeTests.toMaze5 + [
            "take skeleton key", "southwest", "up", "down", "northeast",
        ]
    private static let belowToClearing = [
        "southwest", "down", "west", "east", "north", "east", "south", "southeast",
        "odysseus", "east", "east", "east", "east", "north", "north", "north",
    ]

    @Test(arguments: ["me", "leaves"])
    func takingLeavesFromAnInvalidHolderDoesNotDiscoverTheGrating(holder: String) async throws {
        let world = try GameWorld(game: Zork1(), seed: 39)
        _ = await world.begin()
        for command in ["north", "north", "north"] { _ = await world.perform(command) }
        let before = await world.snapshot()
        #expect(before.placements[Self.leaves] == .room(Self.clearing))
        #expect(!before.revealedItems.contains(Self.grating))
        let refused = await world.perform("take leaves from \(holder)")
        #expect(refused.output.contains("You don't find the pile of leaves there."))
        #expect(!refused.output.contains("revealed"))
        let after = await world.snapshot()
        #expect(after.placements[Self.leaves] == before.placements[Self.leaves])
        #expect(after.revealedItems == before.revealedItems)
        #expect(
            after.globals[EntityID("ZorkAboveGround.gratingDiscovered")]
                == before.globals[EntityID("ZorkAboveGround.gratingDiscovered")])
        #expect(after.touched == before.touched)
        #expect((await world.perform("inventory")).output.contains("empty-handed"))
        #expect((await world.perform("examine grating")).output.contains("can't see"))
        let taken = await world.perform("take leaves")
        expectInOrder(taken.output, ["In disturbing the pile of leaves, a grating is revealed.", "Taken."])
        #expect((await world.snapshot()).placements[Self.leaves] == .heldBy(.player))
        #expect((await world.snapshot()).revealedItems.contains(Self.grating))
    }

    @Test func takingLeavesCarriesThemAndRevealsTheClosedGrating() async throws {
        let world = try GameWorld(game: Zork1(), seed: 39)
        _ = await world.begin()
        for command in ["north", "north", "north"] { _ = await world.perform(command) }
        let taken = await world.perform("take leaves")
        expectInOrder(taken.output, ["In disturbing the pile of leaves, a grating is revealed.", "Taken."])
        let state = await world.snapshot()
        #expect(state.placements[Self.leaves] == .heldBy(.player))
        #expect(state.revealedItems.contains(Self.grating))
        #expect((await world.perform("inventory")).output.contains("pile of leaves"))
        let look = await world.perform("look")
        #expect(!look.output.contains("On the ground is a pile of leaves."))
        #expect(look.output.contains("securely fastened into the ground"))
        #expect((await world.perform("take leaves")).output.contains("already have"))
        _ = await world.perform("south")
        let moved = await world.perform("move leaves")
        #expect(moved.output.contains("Done."))
        #expect(!moved.output.contains("revealed"))
        _ = await world.perform("drop leaves")
        #expect((await world.perform("look")).output.contains("pile of leaves"))
    }

    @Test func lookingUnderLeavesGivesOnlyTheConcealedGratingHint() async throws {
        let world = try GameWorld(game: Zork1(), seed: 39)
        _ = await world.begin()
        for command in ["north", "north", "north"] { _ = await world.perform(command) }
        for _ in 0..<2 {
            let hint = await world.perform("look under leaves")
            #expect(hint.output.contains("Underneath the pile of leaves is a grating."))
            #expect(hint.output.contains("once again concealed from view"))
            #expect(!(await world.snapshot()).revealedItems.contains(Self.grating))
            #expect((await world.perform("examine grating")).output.contains("can't see"))
            #expect((await world.perform("down")).output.contains("can't go"))
        }
        _ = await world.perform("move leaves")
        #expect((await world.perform("look under leaves")).output.contains("dust"))
    }

    @Test(arguments: ["move leaves", "push leaves", "cut leaves"])
    func disturbingLeavesUsesSourceResponsesOnce(command: String) async throws {
        let world = try GameWorld(game: Zork1(), seed: 39)
        _ = await world.begin()
        for step in ["north", "north", "north"] { _ = await world.perform(step) }
        let disturbed = await world.perform(command)
        let cutting = command.hasPrefix("cut")
        expectInOrder(
            disturbed.output,
            cutting
                ? [
                    "You rustle the leaves around, making quite a mess.",
                    "With the leaves moved, a grating is revealed.",
                ]
                : ["Done.", "In disturbing the pile of leaves, a grating is revealed."])
        #expect((await world.snapshot()).placements[Self.leaves] == .room(Self.clearing))
        #expect((await world.snapshot()).revealedItems.contains(Self.grating))
        let repeated = await world.perform(command)
        #expect(repeated.output.contains(cutting ? "You rustle the leaves" : "Done."))
        #expect(!repeated.output.contains("revealed"))
        #expect((await world.perform("open grating")).output.contains("locked"))
    }

    @Test func enteringBelowDoesNotPermanentlyDiscoverTheTopsideGrating() async throws {
        let world = try GameWorld(game: Zork1(), seed: 39)
        _ = await world.begin()
        for command in Self.toBelow { _ = await world.perform(command) }
        #expect((await world.snapshot()).playerLocation == Self.below)
        #expect((await world.perform("unlock grating with skeleton key")).output.contains("Unlocked."))
        for command in Self.belowToClearing { _ = await world.perform(command) }
        #expect((await world.snapshot()).playerLocation == Self.clearing)
        #expect(!(await world.snapshot()).revealedItems.contains(Self.grating))
        #expect((await world.perform("examine grating")).output.contains("can't see"))
        #expect((await world.perform("look under leaves")).output.contains("concealed from view"))
        #expect((await world.perform("move leaves")).output.contains("grating is revealed"))
        #expect((await world.perform("open grating")).output.contains("Opened."))
    }

    @Test func concealedOpeningBelowActuallyTransfersLeavesOnlyOnce() async throws {
        let world = try GameWorld(game: Zork1(), seed: 39)
        _ = await world.begin()
        for command in Self.toBelow + ["unlock grating with skeleton key"] {
            _ = await world.perform(command)
        }
        #expect((await world.snapshot()).playerLocation == Self.below)
        #expect((await world.snapshot()).placements[Self.leaves] == .room(Self.clearing))
        let opened = await world.perform("open grating")
        #expect(opened.output.contains("A pile of leaves falls onto"))
        #expect(opened.output.contains("your head and to the ground."))
        #expect((await world.snapshot()).placements[Self.leaves] == .room(Self.below))
        _ = await world.perform("undo")
        #expect((await world.snapshot()).placements[Self.leaves] == .room(Self.clearing))
        #expect(!(await world.snapshot()).openItems.contains(Self.grating))
        #expect((await world.perform("open grating")).output.contains("pile of leaves falls"))
        #expect((await world.perform("look")).output.contains("pile of leaves"))
        #expect((await world.perform("take leaves")).output.contains("Taken."))
        for command in ["close grating", "open grating"] {
            #expect(!(await world.perform(command)).output.contains("pile of leaves falls"))
        }
        #expect((await world.snapshot()).placements[Self.leaves] == .heldBy(.player))
        _ = await world.perform("up")
        let look = await world.perform("look")
        #expect(look.output.contains("There is an open grating, descending into darkness."))
        #expect(!look.output.contains("On the ground is a pile of leaves."))
        _ = await world.perform("drop leaves")
        _ = await world.perform("down")
        _ = await world.perform("close grating")
        #expect(!(await world.perform("open grating")).output.contains("pile of leaves falls"))
        #expect((await world.snapshot()).placements[Self.leaves] == .room(Self.clearing))
    }

    @Test func alreadyDiscoveredLeavesAreNotTeleportedByOpeningBelow() async throws {
        let world = try GameWorld(game: Zork1(), seed: 39)
        _ = await world.begin()
        for command in Self.toBelow + ["unlock grating with skeleton key"] + Self.belowToClearing {
            _ = await world.perform(command)
        }
        #expect((await world.snapshot()).playerLocation == Self.clearing)
        for command in ["move leaves", "open grating", "down", "close grating"] {
            _ = await world.perform(command)
        }
        #expect((await world.snapshot()).playerLocation == Self.below)
        let opened = await world.perform("open grating")
        #expect(!opened.output.contains("pile of leaves falls"))
        #expect((await world.snapshot()).placements[Self.leaves] == .room(Self.clearing))
    }

    @Test(arguments: ["move leaves", "cut leaves", "look under leaves", "take leaves"])
    func inaccessibleLeavesKeepTheirPlacementAndGratingState(command: String) async throws {
        let world = try GameWorld(game: Zork1(), seed: 39)
        _ = await world.begin()
        for step in [
            "north", "north", "north", "take leaves", "south", "south", "south", "east",
            "open window", "west", "west", "open case", "put leaves in case", "close case",
        ] { _ = await world.perform(step) }
        let before = await world.snapshot()
        #expect(before.placements[Self.leaves] == .inside(EntityID("ZorkHouse.trophyCase")))
        #expect((await world.perform(command)).output.contains("can't reach"))
        let after = await world.snapshot()
        #expect(after.placements[Self.leaves] == before.placements[Self.leaves])
        #expect(after.revealedItems == before.revealedItems)
        #expect(after.openItems == before.openItems)
    }
}
