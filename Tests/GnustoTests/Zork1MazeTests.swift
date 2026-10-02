import Foundation
import GnustoTestSupport
import Testing

@testable import Gnusto
@testable import GnustoMeleeCombat
@testable import GnustoScoring
@testable import Zork1

/// End-to-end playthroughs of the Phase 10.10 maze region: the fifteen twisting
/// passages and four dead ends west of the Troll Room, the skeleton's cache in
/// Maze-5 (skeleton key, bag of coins, rusty knife), the grating up into the
/// forest Clearing, and the Cyclops Room with its two ways past the giant —
/// feeding him to sleep or shouting `odysseus` to send him through the east wall
/// onto the Strange Passage home.
///
/// Seed 39: the prelude kills the troll to reach the
/// maze, and — because the thief daemon draws every turn — the seed that lands
/// the recorded three-blow kill depends on the prelude's length. Once past the
/// troll the thief stays penned in the cellar and the maze itself is draw-free,
/// so everything after arrival is deterministic. The prelude carries the lunch
/// and the water bottle so a single seed serves every test.
struct Zork1MazeTests {
    /// Gather the lunch and bottle (kitchen), sword and lit lantern (living
    /// room), descend, kill the troll, and step west into Maze-1 — then thread
    /// the known way to Maze-5 and the skeleton's cache: west, west, up.
    static let toMaze5: [String] = [
        "south", "east", "open window", "west",
        "open sack", "take lunch and bottle", "west",  // one turn for two keeps the troll's seed
        "take sword", "take lantern", "turn on lantern",
        "push rug", "open trap door", "down",
        "north",
        "attack troll", "attack troll", "attack troll",
        "west",  // into the maze (Maze-1)
        "west", "west", "up",  // Maze-4 → Maze-3 → Maze-5
    ]

    @Test func theSkeletonInMazeFiveGivesUpItsCache() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toMaze5 + [
                "take skeleton key",
                "take bag of coins",  // +10 on the find
                "take rusty knife",
                "x rusty knife",
                "take burned-out lantern",
                "x burned-out lantern",
                "score",
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "slumps to the floor dead",  // the troll falls, opening the west way
                "remains of a luckless adventurer",  // Maze-5's landmark
                "There is a skeleton key here.",  // the key, placed at last
                "bulging with coins",
                "Beside the skeleton is a rusty knife.",
                "Taken.",
                // Both listing lines are listing lines only. Neither object has
                // a `TEXT` in the source, so EXAMINE answers with the shrug
                // `V-EXAMINE` gives them (`gverbs.zil:623`) rather than with a
                // sentence about where they are lying. (#350)
                "There's nothing special about the rusty knife.",
                "There's nothing special about the burned-out lantern.",
                // Kitchen (10) + cellar (25) + the bag of coins (10) = 45.
                "Your score is 45 of a possible 350",
            ])
    }

    @Test func theGratingIsARealDoorUpIntoTheClearing() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toMaze5 + [
                "take skeleton key",
                "southwest", "up", "down", "northeast",  // Maze-6 → Maze-9 → Maze-11 → Grating Room
                "unlock grating with skeleton key",
                "open grating",
                "up",  // out into the forest Clearing
                "down",  // and back down again — the door works both ways now
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "Grating Room",
                "Unlocked.",
                "pile of leaves falls onto",  // opening it from below showers the forest's leaves
                "Clearing",  // up into daylight
                "Grating Room",  // and back down through the open grate
            ])
    }

    @Test func theCyclopsBarsTheWayUntilOdysseusRoutsHim() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toMaze5 + [
                "southwest", "east", "south", "southeast",  // Maze-6 → Maze-7 → Maze-15 → Cyclops Room
                "up",  // barred — he blocks the stairs
                "east",  // barred — the wall is solid
                "odysseus",  // he flees, smashing the east wall
                "east",  // Strange Passage, now open
                "east",  // the great shortcut: the Living Room
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "Cyclops Room",
                "prepared to eat horses",
                "The cyclops doesn't look like he'll let you past.",  // up barred
                "The east wall is solid rock.",  // east barred
                "knocking down the wall",  // odysseus routs him
                "Strange Passage",
                "Living Room",
            ])
    }

    @Test func feedingTheCyclopsPutsHimToSleepAndOpensTheStairs() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toMaze5 + [
                "southwest", "east", "south", "southeast",  // → Cyclops Room
                "give lunch to cyclops",  // he eats, turns thirsty
                "open bottle",
                "give bottle to cyclops",  // he drinks himself to sleep
                "up",  // the stairs are clear now
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "I love hot peppers",
                "drinks the water",
                "fast asleep",
                "Treasure Room",  // the stair is clear
            ])
        // Feeding him to sleep never smashes the east wall — no shortcut home.
        #expect(!transcript.contains("Strange Passage"))
    }

    @Test func attackingTheSleepingCyclopsWakesHim() async throws {
        // Fed to sleep, the cyclops is harmless — examine him and he's out cold.
        // But a blow wakes him (the original's yawn-and-stare): his calm breaks,
        // and examining him again shows the hungry giant back on his feet.
        let transcript = try await play(
            Zork1(),
            Self.toMaze5 + [
                "southwest", "east", "south", "southeast",  // → Cyclops Room
                "give lunch to cyclops",
                "open bottle",
                "give bottle to cyclops",  // he drinks himself to sleep
                "examine cyclops",  // sleeping like a baby
                "attack cyclops",  // the blow wakes him
                "examine cyclops",  // the hungry giant, awake again
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "fast asleep",
                "sleeping like a baby",  // examine while subdued
                "the thing that woke him up",  // wake-on-attack
                "hungry cyclops is standing",  // examine, awake again
            ])
    }

    /// `V-ALARM`'s actor branch (`gverbs.zil:157-166`), which the stub floor
    /// could not reach. Both frames, one transcript: `wake cyclops` at a giant
    /// who is upright answers that he is wide awake, and at the drugged sleeper
    /// it rouses him — where the old line said "The cyclops isn't sleeping." to
    /// a man watching him snore. Bare `wake` in the same room said "Nothing here
    /// is asleep." for the same reason, and is asserted against here. (#325)
    @Test func wakingTheCyclopsReadsWhetherHeIsAsleep() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toMaze5 + [
                "southwest", "east", "south", "southeast",  // → Cyclops Room
                "wake cyclops",  // named, upright: wide awake
                "wake",  // bare, upright: the same answer, from the room
                "give lunch to cyclops",
                "open bottle",
                "give bottle to cyclops",  // he drinks himself to sleep
                "wake",  // bare, and asleep: rudely awakened all the same
                "examine cyclops",  // and back on his feet
                "wake cyclops",  // named, upright again
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "He's wide awake, or haven't you noticed...",
                "He's wide awake, or haven't you noticed...",
                "fast asleep",
                "The cyclops is rudely awakened.",
                "hungry cyclops is standing",
                "He's wide awake, or haven't you noticed...",
            ])
        #expect(!transcript.contains("The cyclops isn't sleeping."))
        #expect(!transcript.contains("Nothing here is asleep."))
    }

    @Test func theMazeThreadsPastItsDeadEnds() async throws {
        // A short draw-free walk from Maze-5: east into a dead end, back, and
        // southwest onward — proving the tangle's landmarks by name (every maze
        // passage shares the title "Maze", so a dead end and the Cyclops Room
        // are the only landmarks that distinguish where you are).
        let transcript = try await play(
            Zork1(),
            Self.toMaze5 + [
                "east",  // Maze-5 → Dead End (Dead-End-2)
                "west",  // back to Maze-5
                "southwest", "east", "south", "southeast",  // → Cyclops Room
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "remains of a luckless adventurer",  // Maze-5
                "Dead End",
                "dead end in the maze",
                "Cyclops Room",  // the far landmark
            ])
    }

    @Test func attackingTheCyclopsWakesHisHungerAndGetsYouEaten() async throws {
        // Steel can't beat him, but attacking rouses his hunger: from there the
        // wrath ladder climbs one rung a turn until, on the seventh, he eats you
        // (the original's `CYCLOWRATH` / `I-CYCLOPS`). Death is survivable, so
        // the run resurrects rather than ending.
        let transcript = try await play(
            Zork1(),
            Self.toMaze5 + [
                "southwest", "east", "south", "southeast",  // → Cyclops Room
                "attack cyclops", "attack cyclops", "attack cyclops",
                "attack cyclops", "attack cyclops", "attack cyclops",
                "attack cyclops",  // the seventh — he's had enough of you
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "Cyclops Room",
                "shrugs but otherwise ignores your pitiful attempt",  // steel is futile
                "The cyclops seems somewhat agitated.",  // cyclomad[0], the first rung
                "You have two choices: 1. Leave  2. Become dinner.",  // cyclomad[5], the last
                "Just like Mom used to make",  // he eats you
                "you probably deserve another",  // …and you're resurrected
            ])
    }

    @Test func disturbingTheSkeletonBanishesYourLoot() async throws {
        // Taking the bones wakes the ghost, who curses your valuables to the
        // Land of the Dead. Equipment has no treasure deposit value.
        let transcript = try await play(
            Zork1(),
            Self.toMaze5 + [
                "take bag of coins",  // something worth cursing
                "take bones",  // desecration — the ghost appears
                "inventory",
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "bulging with coins",  // the bag is in hand…
                "banishes them to the Land of the Living Dead",  // …then the curse takes it
            ])
        let carried = turnOutput(of: "inventory", in: transcript)
        #expect(carried.contains("lantern"))  // the lamp is spared
        #expect(!carried.contains("coins"))  // the bag was banished
    }

    @Test func searchingOrMovingTheBonesAlsoCursesYou() async throws {
        // The curse fires on `search` (`.lookIn`) and `move` (`.push`) too, not
        // just `take` — so the ghost appears twice here.
        let transcript = try await play(
            Zork1(),
            Self.toMaze5 + [
                "take bag of coins",
                "search bones",  // .lookIn — banishes the bag
                "move bones",  // .push — nothing left to take, but he's still appalled
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "casts a curse on your valuables",  // search bones
                "casts a curse on your valuables",  // move bones
            ])
    }

    private static let rustyKnife = EntityID("ZorkMaze.rustyKnife")
    private static let sword = EntityID("ZorkHouse.sword")
    private static let bottle = EntityID("ZorkHouse.bottle")
    private static let lunch = EntityID("ZorkHouse.lunch")
    private static let warning = "As you touch the rusty knife, your sword gives a single pulse of blinding blue light."
    private static let knifeDeath =
        "As the knife approaches its victim, your mind is submerged by an overmastering will. Slowly, your hand turns, until the rusty blade is an inch from your neck. The knife seems to sing as it savagely slits your throat."

    private static func mazeWorld(_ extra: [String] = []) async throws -> GameWorld {
        let world = try GameWorld(game: Zork1(), seed: 39)
        _ = await world.begin()
        for command in toMaze5 + extra { _ = await world.perform(command) }
        #expect((await world.snapshot()).playerLocation == EntityID("ZorkMaze.maze5"))
        #expect((await world.snapshot()).placements[sword] == .heldBy(.player))
        return world
    }

    private static func singleLine(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static let sleepCyclops = [
        "southwest", "east", "south", "southeast", "give lunch to cyclops", "open bottle", "give bottle to cyclops",
    ]

    // Fresh worlds can encode equal dictionaries and sets in different orders.
    // Decode the two plugin ledgers before comparing their complete values.
    private static func globalsMatch(_ left: [EntityID: StateValue], _ right: [EntityID: StateValue]) -> Bool {
        guard Set(left.keys) == Set(right.keys) else { return false }
        for (id, value) in left {
            guard let other = right[id] else { return false }
            switch id {
            case EntityID("MeleeCombat.ledger"):
                guard let lhs = MeleeCombat.Ledger(stateValue: value), let rhs = MeleeCombat.Ledger(stateValue: other),
                    lhs.health == rhs.health, lhs.stunned == rhs.stunned, lhs.engaged == rhs.engaged,
                    lhs.playerHealth == rhs.playerHealth
                else { return false }
            case EntityID("Scoring.claimed"):
                guard let lhs = Scoring.Claimed(stateValue: value), let rhs = Scoring.Claimed(stateValue: other),
                    lhs.names == rhs.names
                else { return false }
            default:
                guard value == other else { return false }
            }
        }
        return true
    }

    @Test(arguments: ["swing sword at cyclops", "thrust sword at cyclops"])
    func targetedSwingsWakeTheSleepingCyclopsLikeAttack(command: String) async throws {
        let swing = try await Self.mazeWorld()
        let attack = try await Self.mazeWorld()
        for word in Self.sleepCyclops {
            _ = await swing.perform(word)
            _ = await attack.perform(word)
        }
        let before = await swing.snapshot()
        let actual = await swing.perform(command)
        let expected = await attack.perform("attack cyclops with sword")
        #expect(actual.output == expected.output)
        #expect(actual.output.contains("the thing that woke him up"))
        let after = await swing.snapshot()
        let attacked = await attack.snapshot()
        #expect(Self.globalsMatch(after.globals, attacked.globals))
        #expect(after.placements == attacked.placements)
        #expect(after.activeDaemons == attacked.activeDaemons)
        #expect(after.rngState == attacked.rngState)
        #expect(after.moves == before.moves + 1)
        #expect(after.moves == attacked.moves)
        #expect(after.pronounIt == attacked.pronounIt)
        _ = await swing.perform("undo")
        let restored = await swing.snapshot()
        #expect(restored.globals == before.globals)
        #expect(restored.placements == before.placements)
        #expect(restored.activeDaemons == before.activeDaemons)
        #expect(restored.moves == before.moves)
        #expect(restored.rngState == before.rngState)
        #expect(restored.pronounIt == before.pronounIt)
        #expect((await swing.perform(command)).output == expected.output)
    }

    @Test(arguments: ["swing", "thrust"])
    func targetedSwingsMatchSeededTrollMeleeAndAgain(verb: String) async throws {
        let route = Array(Self.toMaze5.prefix(while: { $0 != "attack troll" }))
        let swing = try GameWorld(game: Zork1(), seed: 39)
        let attack = try GameWorld(game: Zork1(), seed: 39)
        _ = await swing.begin()
        _ = await attack.begin()
        for command in route {
            _ = await swing.perform(command)
            _ = await attack.perform(command)
        }
        for command in ["\(verb) sword at troll", "again", "again"] {
            let actual = await swing.perform(command)
            let expected = await attack.perform("attack troll with sword")
            #expect(actual.output == expected.output)
            let swung = await swing.snapshot()
            let attacked = await attack.snapshot()
            #expect(Self.globalsMatch(swung.globals, attacked.globals))
            #expect(swung.placements == attacked.placements)
            #expect(swung.activeDaemons == attacked.activeDaemons)
            #expect(swung.rngState == attacked.rngState)
            #expect(swung.moves == attacked.moves)
            #expect(swung.pronounIt == attacked.pronounIt)
        }
    }

    @Test(arguments: ["swing sword at cyclops", "thrust sword at cyclops"])
    func anUnheldSwingWeaponCannotWakeTheCyclops(command: String) async throws {
        let world = try await Self.mazeWorld()
        for word in Self.sleepCyclops + ["drop sword"] { _ = await world.perform(word) }
        let before = await world.snapshot()
        let result = await world.perform(command)
        #expect(result.output.contains("holding"))
        #expect(!result.output.contains("the thing that woke him up"))
        #expect((await world.snapshot()).globals[EntityID("ZorkMaze.cyclopsSubdued")] == .bool(true))
        #expect((await world.snapshot()).placements == before.placements)
        #expect((await world.perform("examine cyclops")).output.contains("sleeping like a baby"))
    }

    private static let boneCommands = ["take bones", "search bones", "move bones"]
    private static let mazeFive = EntityID("ZorkMaze.maze5")
    private static let curseDestination = EntityID("ZorkTemple.landOfDead")
    private static let coins = EntityID("ZorkMaze.bagOfCoins")
    private static let bar = EntityID("ZorkRoundRoom.platinumBar")
    private static let coffin = EntityID("ZorkTemple.coffin")
    private static let hiddenTreasures = [
        EntityID("ZorkDam.trunk"), EntityID("ZorkRiver.scarab"), EntityID("ZorkRiver.potOfGold"),
    ]
    private static let scoredTreasures = [
        EntityID("ZorkCellar.painting"), EntityID("ZorkAboveGround.egg"), bar,
        EntityID("ZorkDam.trunk"), EntityID("ZorkTemple.torch"), coffin,
        EntityID("ZorkTemple.sceptre"), EntityID("ZorkTemple.crystalSkull"),
        EntityID("ZorkMirror.crystalTrident"), EntityID("ZorkCoalMine.jade"),
        EntityID("ZorkCoalMine.sapphireBracelet"), EntityID("ZorkCoalMine.diamond"),
        EntityID("ZorkRiver.emerald"), EntityID("ZorkRiver.scarab"), EntityID("ZorkRiver.potOfGold"),
        coins, EntityID("ZorkMaze.silverChalice"), EntityID("ZorkHouse.canary"), EntityID("ZorkHouse.bauble"),
    ]

    @Test(arguments: boneCommands)
    func skeletonCurseSelectsHeldAndFloorTreasureAndLeavesEquipment(command: String) async throws {
        let world = try await Self.mazeWorld(["take skeleton key", "take bag of coins"])
        let bauble = EntityID("ZorkHouse.bauble")
        await world.placeSkeletonTestItem(bauble, .room(Self.mazeFive))
        for item in [
            EntityID("ZorkTemple.bell"), EntityID("ZorkTemple.book"), EntityID("ZorkTemple.candles"),
            EntityID("ZorkDam.matchbook"),
        ] {
            await world.placeSkeletonTestItem(item, .heldBy(.player))
        }
        let before = await world.snapshot()
        #expect(Self.singleLine((await world.perform(command)).output).contains("casts a curse on your valuables"))
        let after = await world.snapshot()
        for item in [Self.coins, bauble] {
            #expect(after.placements[item] == .room(Self.curseDestination))
        }
        let equipment = before.placements.filter {
            ($0.value == .heldBy(.player) || $0.value == .room(Self.mazeFive)) && $0.key != Self.coins
                && $0.key != bauble
        }
        for (item, placement) in equipment {
            #expect(after.placements[item] == placement)
        }
        let inventory = (await world.perform("inventory")).output
        for name in [
            "sword", "lantern", "bottle", "lunch", "skeleton key", "bell", "black book", "candles", "matchbook",
        ] {
            #expect(inventory.contains(name))
        }
        #expect(!inventory.contains("coins"))
        #expect(!(await world.perform("look")).output.contains("bauble"))
        #expect(Self.singleLine((await world.perform(command)).output).contains("casts a curse on your valuables"))
        let repeated = await world.snapshot()
        for item in Array(equipment.keys) + [Self.coins, bauble] {
            #expect(repeated.placements[item] == after.placements[item])
        }
    }

    @Test(arguments: ["held", "floor"])
    func skeletonCurseUsesDepositValuesAcrossTheTreasureRoster(placement: String) async throws {
        let world = try await Self.mazeWorld()
        let origin: Placement = placement == "held" ? .heldBy(.player) : .room(Self.mazeFive)
        for item in Self.scoredTreasures { await world.placeSkeletonTestItem(item, origin) }
        for item in Self.hiddenTreasures { await world.revealSkeletonTestItem(item) }
        await world.setSkeletonTestBarAcousticsFixed()
        let before = await world.snapshot()
        _ = await world.perform("take bones")
        let after = await world.snapshot()
        for item in Self.scoredTreasures {
            #expect(after.placements[item] == (item == Self.coffin ? origin : .room(Self.curseDestination)))
        }
        #expect(after.score == before.score)
        #expect(after.playerLocation == before.playerLocation)
    }

    @Test(arguments: hiddenTreasures, [false, true])
    func skeletonCurseRespectsTheHiddenFlagInBothDirectScopes(item: EntityID, revealed: Bool) async throws {
        for origin in [Placement.heldBy(.player), .room(Self.mazeFive)] {
            let world = try await Self.mazeWorld()
            await world.placeSkeletonTestItem(item, origin)
            if revealed { await world.revealSkeletonTestItem(item) }
            _ = await world.perform("search bones")
            #expect((await world.snapshot()).placements[item] == (revealed ? .room(Self.curseDestination) : origin))
        }
    }

    @Test(arguments: [false, true], ["held", "floor"])
    func echoMakesThePreviouslySacredBarEligibleForTheSkeletonCurse(quieted: Bool, placement: String) async throws {
        let world = try GameWorld(game: Zork1(), seed: 39)
        _ = await world.begin()
        for command in Array(Self.toMaze5.dropLast(4)) + ["east", "east", "east"] {
            _ = await world.perform(command)
        }
        #expect((await world.snapshot()).playerLocation == EntityID("ZorkRoundRoom.loudRoom"))
        if quieted {
            #expect((await world.perform("echo")).output.contains("acoustics of the room change"))
        }
        for command in ["west", "west", "west", "west", "west", "west", "up"] {
            _ = await world.perform(command)
        }
        #expect((await world.snapshot()).playerLocation == Self.mazeFive)
        let origin: Placement = placement == "held" ? .heldBy(.player) : .room(Self.mazeFive)
        await world.placeSkeletonTestItem(Self.bar, origin)
        _ = await world.perform("move bones")
        let destination: Placement = quieted ? .room(Self.curseDestination) : origin
        #expect((await world.snapshot()).placements[Self.bar] == destination)
    }

    @Test(arguments: ["held", "floor"])
    func skeletonCurseDoesNotSearchInsideOrdinaryHolders(placement: String) async throws {
        let world = try await Self.mazeWorld(["open bottle"])
        let emerald = EntityID("ZorkRiver.emerald")
        let origin: Placement = placement == "held" ? .heldBy(.player) : .room(Self.mazeFive)
        await world.placeSkeletonTestItem(Self.bottle, origin)
        await world.placeSkeletonTestItem(emerald, .inside(Self.bottle))
        _ = await world.perform("search bones")
        let after = await world.snapshot()
        #expect(after.placements[Self.bottle] == origin)
        #expect(after.placements[emerald] == .inside(Self.bottle))
        #expect(after.placements[Self.coins] == .room(Self.curseDestination))
    }

    @Test func skeletonCurseMovesATreasureContainerWithItsContentsStillInside() async throws {
        let world = try await Self.mazeWorld()
        let egg = EntityID("ZorkAboveGround.egg")
        let canary = EntityID("ZorkHouse.canary")
        await world.placeSkeletonTestItem(egg, .heldBy(.player))
        await world.placeSkeletonTestItem(canary, .inside(egg))
        _ = await world.perform("take bones")
        let after = await world.snapshot()
        #expect(after.placements[egg] == .room(Self.curseDestination))
        #expect(after.placements[canary] == .inside(egg))
    }

    @Test(arguments: boneCommands)
    func undoRestoresBothTreasureScopesAndEquipmentAfterTheSkeletonCurse(command: String) async throws {
        let world = try await Self.mazeWorld()
        let bauble = EntityID("ZorkHouse.bauble")
        await world.placeSkeletonTestItem(bauble, .heldBy(.player))
        let before = await world.snapshot()
        _ = await world.perform(command)
        #expect((await world.snapshot()).placements[Self.coins] == .room(Self.curseDestination))
        #expect((await world.snapshot()).placements[bauble] == .room(Self.curseDestination))
        _ = await world.perform("undo")
        let restored = await world.snapshot()
        #expect(restored.placements == before.placements)
        #expect(restored.globals == before.globals)
        #expect(restored.score == before.score)
        #expect(restored.playerLocation == before.playerLocation)
        #expect(restored.revealedItems == before.revealedItems)
    }

    @Test(arguments: ["held", "floor", "nested", "absent"])
    func rustyKnifeTakeWarnsOnlyWithTheSwordDirectlyHeld(swordPlacement: String) async throws {
        let world = try await Self.mazeWorld()
        if swordPlacement == "floor" { _ = await world.perform("drop sword") }
        if swordPlacement == "nested" {
            _ = await world.perform("open bottle")
            _ = await world.perform("put sword in bottle")
        }
        if swordPlacement == "absent" {
            _ = await world.perform("take rusty knife")
            _ = await world.perform("drop sword")
            _ = await world.perform("southwest")
            _ = await world.perform("drop rusty knife")
        }
        let before = await world.snapshot()
        if swordPlacement == "held" { #expect(before.placements[Self.sword] == .heldBy(.player)) }
        if swordPlacement == "floor" { #expect(before.placements[Self.sword] == .room(before.playerLocation)) }
        if swordPlacement == "nested" { #expect(before.placements[Self.sword] == .inside(Self.bottle)) }
        if swordPlacement == "absent" { #expect(before.placements[Self.sword] != .heldBy(.player)) }
        #expect(before.playerLocation == EntityID(swordPlacement == "absent" ? "ZorkMaze.maze6" : "ZorkMaze.maze5"))
        #expect(before.placements[Self.rustyKnife] == .room(before.playerLocation))
        let taken = await world.perform("take rusty knife")
        #expect(taken.output.contains("Taken."))
        #expect(Self.singleLine(taken.output).contains(Self.warning) == (swordPlacement == "held"))
        #expect((await world.snapshot()).placements[Self.rustyKnife] == .heldBy(.player))
        let repeated = await world.perform("take rusty knife")
        #expect(!Self.singleLine(repeated.output).contains(Self.warning))
        #expect((await world.snapshot()).placements[Self.rustyKnife] == .heldBy(.player))
    }

    @Test(arguments: ["take rusty knife from me", "take rusty knife from bottle"])
    func refusedRustyKnifeTakeDoesNotWarn(command: String) async throws {
        let world = try await Self.mazeWorld()
        let before = await world.snapshot()
        let refused = await world.perform(command)
        #expect(!refused.output.contains("Taken."))
        #expect(!Self.singleLine(refused.output).contains(Self.warning))
        #expect((await world.snapshot()).placements[Self.rustyKnife] == before.placements[Self.rustyKnife])
        #expect((await world.snapshot()).touched == before.touched)
    }

    @Test(arguments: [
        "attack skeleton with rusty knife", "swing rusty knife at skeleton", "thrust rusty knife at skeleton",
    ])
    func rustyKnifeWeaponUseRemovesItBeforeResurrection(command: String) async throws {
        let world = try await Self.mazeWorld(["take rusty knife"])
        let before = await world.snapshot()
        #expect(before.placements[Self.rustyKnife] == .heldBy(.player))
        let cursed = await world.perform(command)
        #expect(Self.singleLine(cursed.output).contains(Self.knifeDeath))
        #expect(cursed.output.contains("you probably deserve another"))
        let after = await world.snapshot()
        #expect(after.placements[Self.rustyKnife] == .nowhere)
        #expect(after.playerLocation == EntityID("ZorkAboveGround.forestWest"))
        #expect(!cursed.isFinished)
        #expect((await world.perform("diagnose")).output.contains("You have been killed once."))
        #expect((await world.perform("x rusty knife")).output.contains("can't see"))
        #expect((await world.snapshot()).placements[Self.rustyKnife] == .nowhere)
    }

    @Test(arguments: [
        "attack cyclops with rusty knife", "swing rusty knife at cyclops", "thrust rusty knife at cyclops",
    ])
    func rustyKnifeCursePrecedesTheSleepingCyclopsTargetRule(command: String) async throws {
        let world = try await Self.mazeWorld(["take rusty knife"])
        for command in [
            "southwest", "east", "south", "southeast", "give lunch to cyclops", "open bottle", "give bottle to cyclops",
        ] {
            _ = await world.perform(command)
        }
        #expect((await world.perform("examine cyclops")).output.contains("sleeping like a baby"))
        let cursed = await world.perform(command)
        #expect(Self.singleLine(cursed.output).contains(Self.knifeDeath))
        #expect(cursed.output.contains("you probably deserve another"))
        #expect(!cursed.output.contains("the thing that woke him up"))
        #expect((await world.snapshot()).placements[Self.rustyKnife] == .nowhere)
    }

    @Test(arguments: [
        "attack skeleton with rusty knife", "swing rusty knife at skeleton", "thrust rusty knife at skeleton",
    ])
    func anUnheldOrUnreachableRustyKnifeCannotCurse(command: String) async throws {
        let world = try await Self.mazeWorld()
        let floor = await world.snapshot()
        let unheld = await world.perform(command)
        #expect(!Self.singleLine(unheld.output).contains(Self.knifeDeath))
        #expect(unheld.output.contains("holding"))
        #expect((await world.snapshot()).placements[Self.rustyKnife] == floor.placements[Self.rustyKnife])
        _ = await world.perform("take rusty knife")
        _ = await world.perform("open bottle")
        _ = await world.perform("put rusty knife in bottle")
        _ = await world.perform("close bottle")
        let closed = await world.snapshot()
        #expect(closed.placements[Self.rustyKnife] == .inside(Self.bottle))
        #expect(!closed.openItems.contains(Self.bottle))
        let unreachable = await world.perform(command)
        #expect(unreachable.output.contains("can't reach"))
        #expect(!Self.singleLine(unreachable.output).contains(Self.knifeDeath))
        #expect((await world.snapshot()).placements[Self.rustyKnife] == closed.placements[Self.rustyKnife])
        #expect((await world.snapshot()).playerLocation == closed.playerLocation)
        #expect((await world.perform("diagnose")).output.contains("perfect health"))
    }

    @Test(arguments: ["attack lunch with rusty knife", "swing rusty knife at lunch", "thrust rusty knife at lunch"])
    func anUnreachableKnifeTargetCannotTriggerTheCurse(command: String) async throws {
        let world = try await Self.mazeWorld(["take rusty knife", "open bottle", "put lunch in bottle", "close bottle"])
        let before = await world.snapshot()
        #expect(before.placements[Self.lunch] == .inside(Self.bottle))
        #expect(!before.openItems.contains(Self.bottle))
        let refused = await world.perform(command)
        #expect(refused.output.contains("can't reach"))
        #expect(!Self.singleLine(refused.output).contains(Self.knifeDeath))
        let after = await world.snapshot()
        #expect(after.placements[Self.rustyKnife] == .heldBy(.player))
        #expect(after.placements[Self.lunch] == before.placements[Self.lunch])
        #expect(after.playerLocation == before.playerLocation)
        #expect((await world.perform("diagnose")).output.contains("perfect health"))
    }

    @Test(arguments: ["swing rusty knife", "thrust rusty knife", "attack rusty knife", "throw rusty knife at skeleton"])
    func nonTargetedWeaponUseAndThrowingTheRustyKnifeAreNotCursed(command: String) async throws {
        let world = try await Self.mazeWorld(["take rusty knife"])
        let response = await world.perform(command)
        #expect(!Self.singleLine(response.output).contains(Self.knifeDeath))
        #expect((await world.perform("diagnose")).output.contains("perfect health"))
        let after = await world.snapshot()
        #expect(after.placements[Self.rustyKnife] != .nowhere)
        #expect(after.playerLocation == EntityID("ZorkMaze.maze5"))
        if command.hasPrefix("swing") || command.hasPrefix("thrust") {
            #expect(response.output.contains("Whoosh!"))
            #expect(after.placements[Self.rustyKnife] == .heldBy(.player))
        }
    }

    @Test func undoRestoresTheKnifeAndDeathStateAfterItsCurse() async throws {
        let world = try await Self.mazeWorld(["take rusty knife"])
        let before = await world.snapshot()
        #expect(
            Self.singleLine((await world.perform("attack skeleton with rusty knife")).output).contains(Self.knifeDeath))
        #expect((await world.snapshot()).placements[Self.rustyKnife] == .nowhere)
        _ = await world.perform("undo")
        let restored = await world.snapshot()
        #expect(restored.placements == before.placements)
        #expect(restored.playerLocation == before.playerLocation)
        #expect((await world.perform("diagnose")).output.contains("perfect health"))
    }

    @Test func aClosedHolderRefusesTheRustyKnifeTakeWithoutAWarning() async throws {
        let world = try await Self.mazeWorld([
            "take rusty knife", "open bottle", "put rusty knife in bottle", "close bottle",
        ])
        let before = await world.snapshot()
        #expect(before.placements[Self.rustyKnife] == .inside(Self.bottle))
        #expect(!before.openItems.contains(Self.bottle))
        let refused = await world.perform("take rusty knife")
        #expect(refused.output.contains("can't reach"))
        #expect(!Self.singleLine(refused.output).contains(Self.warning))
        #expect((await world.snapshot()).placements[Self.rustyKnife] == before.placements[Self.rustyKnife])
    }
}

// These seams arrange selector edge cases after reaching the maze through normal commands.
extension GameWorld {
    fileprivate func placeSkeletonTestItem(_ item: EntityID, _ placement: Placement) {
        precondition(definition.items[item] != nil)
        state.place(item, placement)
    }

    fileprivate func revealSkeletonTestItem(_ item: EntityID) {
        precondition(definition.items[item]?.isHidden == true)
        state.revealedItems.insert(item)
    }

    fileprivate func setSkeletonTestBarAcousticsFixed() {
        let key = EntityID("ZorkRoundRoom.loudRoomAcousticsFixed")
        precondition(definition.globals[key]?.defaultValue == .bool(false))
        state.globals[key] = .bool(true)
    }
}
