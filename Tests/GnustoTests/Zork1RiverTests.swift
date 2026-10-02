import Foundation
import GnustoTestSupport
import Testing

@testable import Gnusto
@testable import Zork1

/// End-to-end playthroughs of the Phase 10.9 Frigid River region: the inflatable
/// boat and the pump that fills it, the current that carries it downstream, the
/// buoy and its emerald, the buried scarab, the falls, and the rainbow the
/// sceptre wakes.
///
/// The boat tests run at seed 39 (the same recorded troll kill the Dam suite
/// uses): the shared prelude drains the reservoir to fetch the pump, exactly as
/// `Zork1Tests` does. Everything past the Round Room is deterministic — the
/// thief stays penned in the cellar and the river's own machinery is draw-free.
/// The rainbow and canyon tests never go underground, so they need no particular
/// seed.
struct Zork1RiverTests {
    /// Kill the troll (seed 39), charge the dam panel, and end standing on the
    /// Dam with the wrench — the Dam suite's proven approach.
    static let toChargedDam: [String] = [
        "south", "east", "open window", "west", "west",
        "take sword", "take lantern", "turn on lantern",
        "push rug", "open trap door", "down",
        "north", "west",
        "attack troll", "attack troll", "attack troll",
        "east", "east",  // → East-West Passage → Round Room
        "north", "northeast", "east",  // → N-S Passage → Deep Canyon → Dam
        "north", "north",  // → Dam Lobby → Maintenance Room
        "take wrench", "push yellow button",
        "south", "south",  // → Dam Lobby → Dam
    ]

    /// Drain the reservoir, walk the bare bed to Reservoir North for the hand
    /// pump, and return to the Dam Base — one command short of inflating.
    /// Ends on Dam Base holding the pump, the wrench, the sword and
    /// the lit lantern, the pile of plastic still spread on the bank.
    ///
    /// Split out of ``toInflatedBoat`` so the inflate rule's own refusals can be
    /// driven while the pile still exists.
    static let toPumpAtDamBase: [String] =
        toChargedDam + [
            "turn bolt with wrench",  // gates open, the drain begins
            "west",  // Reservoir South
            "wait", "wait", "wait", "wait",
            "wait", "wait", "wait", "wait",  // the eight-turn drain completes
            "north", "north",  // Reservoir bed → Reservoir North
            "take pump",
            "south", "south",  // back across the bed → Reservoir South
            "southeast", "east", "down",  // Deep Canyon → Dam → Dam Base
        ]

    /// As ``toPumpAtDamBase``, then inflate the pile of plastic into a boat.
    /// Ends with the boat sitting inflated on the bank.
    static let toInflatedBoat: [String] =
        toPumpAtDamBase + [
            "inflate plastic with pump"
        ]

    /// As ``toInflatedBoat``, but set the sword down (so it can't hole the boat),
    /// board, and launch onto the river. Ends adrift on River-1.
    static let toLaunched: [String] =
        toInflatedBoat + [
            "drop sword",
            "enter boat",
            "launch boat",
        ]

    /// `V-STAND` (`gverbs.zil:1305`) branches on the vehicle before it says
    /// anything, and the stub floor's line is only its second branch. Both
    /// frames: on the bank a man is already standing, and in the boat he is not.
    /// The old transcript told a man adrift on the Frigid River that he was
    /// already standing, "I think". (#325)
    @Test func standReadsWhetherYouAreSittingInTheBoat() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toInflatedBoat + [
                "stand",  // on the Dam Base: already standing
                "drop sword",
                "enter boat",
                "stand",  // aboard: not standing at all
                "get out",
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "You are already standing, I think.",
                "You are sitting in the magic boat. Get out of it first.",
            ])
        // And the stock line is not printed twice — the second `stand` is the
        // boat's, not the floor's.
        #expect(occurrences(of: "You are already standing", in: transcript) == 1)
    }

    /// The boat carries the player down the river to the sandy east bank: paddle
    /// to River-4, lift the buoy (and the emerald inside it), land, and dig the
    /// scarab out of the Sandy Cave. Kitchen (10), cellar (25) and East-West
    /// Passage (5) are already banked; the emerald (5) and scarab (5) bring the
    /// total to fifty.
    @Test func theBoatCarriesYouDownToTheSandyBeachAndTheScarab() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toLaunched + [
                "down", "down", "down",  // River-2 → River-3 → River-4
                "take buoy",
                "east",  // land the boat on the Sandy Beach
                "disembark",
                "open buoy", "take emerald",  // +5 on the find
                "take shovel",
                "northeast",  // Sandy Cave
                "dig sand with shovel",  // first dig
                "dig sand with shovel",  // second dig
                "dig sand with shovel",  // third dig bares the scarab
                "take scarab",  // +5 on the find
                "score",
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "slips off the bank",  // the launch
                "Frigid River",
                "Sandy Beach",
                "Sandy Cave",
                "scarab here in the sand",  // the third dig reveals it
                "Your score is 50 of a possible 350",
            ])
        // A successful launch must not fall through to the stage-4 default.
        #expect(!transcript.contains("You can't launch that"))
    }

    /// Boarding the boat with a blade still in hand punctures it: the sword's
    /// point opens the hull the moment you climb in, and you are left standing —
    /// dry, at least — on the bank beside a useless wreck.
    @Test func boardingWithABladePuncturesTheBoat() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toInflatedBoat + [
                "enter boat",  // still carrying the sword
                "look",
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "punctured the boat",  // the puncture
                "Dam Base",  // still ashore, not adrift
                "punctured boat",  // the wreck is what's left
            ])
    }

    /// A blade holes the boat on boarding; the tube of Frobozz Magic Gunk —
    /// carried up from the Maintenance Room — seals the wreck good as new, and a
    /// second, blade-free boarding holds (FIDELITY.md — the repair the earlier
    /// slice left unmodeled). The route mirrors ``toInflatedBoat``, grabbing the
    /// tube on the way past the Maintenance Room; seed 39, the recorded troll kill.
    @Test func theTubesGunkPatchesThePuncturedBoat() async throws {
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west", "west",
                "take sword", "take lantern", "turn on lantern",
                "push rug", "open trap door", "down",
                "north", "west",
                "attack troll", "attack troll", "attack troll",
                "east", "east",  // → East-West Passage → Round Room
                "north", "northeast", "east",  // → N-S Passage → Deep Canyon → Dam
                "north", "north",  // → Dam Lobby → Maintenance Room
                "take wrench", "take tube", "push yellow button",
                "south", "south",  // → Dam Lobby → Dam
                "turn bolt with wrench",  // gates open, the drain begins
                "west",  // Reservoir South
                "wait", "wait", "wait", "wait",
                "wait", "wait", "wait", "wait",  // the eight-turn drain completes
                "north", "north",  // Reservoir bed → Reservoir North
                "take pump",
                "south", "south",  // back across the bed → Reservoir South
                "southeast", "east", "down",  // Deep Canyon → Dam → Dam Base
                "inflate plastic with pump",
                "enter boat",  // the sword is still in hand — the hull tears
                "look",
                "fix boat with gunk",  // the tube's gunk seals it
                "drop sword",  // set the blade down this time
                "enter boat",  // now the boarding holds
                "look",
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "punctured the boat",  // the puncture
                "punctured boat",  // the wreck
                "boat is repaired",  // the patch
                "magic boat",  // repaired; the blade-free boarding holds
            ])
    }

    private static let boat = EntityID("ZorkRiver.magicBoat")
    private static let wreck = EntityID("ZorkRiver.puncturedBoat")
    private static let sword = EntityID("ZorkHouse.sword")
    private static let label = EntityID("ZorkRiver.tanLabel")
    private static let bank = EntityID("ZorkDam.damBase")
    private static let river1 = EntityID("ZorkRiver.river1")
    private static let punctureLine = "didn't agree with the boat"
    private static let riverDeath = "fighting the fierce currents of the Frigid River"

    private static func boardedBoatWorld(_ extra: [String] = []) async throws -> GameWorld {
        let world = try GameWorld(game: Zork1(), seed: 39)
        _ = await world.begin()
        for command in toInflatedBoat + ["drop sword", "enter boat"] {
            _ = await world.perform(command)
        }
        #expect((await world.snapshot()).playerLocation == bank)
        #expect((await world.snapshot()).playerVehicle == boat)
        for command in extra { _ = await world.perform(command) }
        return world
    }

    private static let groupedSharpPutCommands = [
        "put sword and axe in boat", "put axe and sword in boat",
        "put pump and sword and axe in boat", "put sword and pump and axe in boat",
        "put sword and axe and pump in boat",
    ]
    private static let axe = EntityID("ZorkCellar.axe")
    private static let pump = EntityID("ZorkDam.handPump")
    private static let wrench = EntityID("ZorkDam.wrench")
    @Test func theLeakRepairLeavesGunkForTheIndependentBoatPatch() async throws {
        var route = Self.toInflatedBoat
        route.insert(
            contentsOf: ["take tube", "push blue button", "plug leak with putty"],
            at: try #require(route.firstIndex(of: "take wrench")) + 1)
        let world = try GameWorld(game: Zork1(), seed: 39)
        _ = await world.begin()
        for command in route { _ = await world.perform(command) }
        #expect((await world.snapshot()).globals[EntityID("ZorkDam.floodLevel")] == .int(-1))
        #expect((await world.snapshot()).placements[Self.tube] == .heldBy(.player))
        #expect((await world.perform("enter boat")).output.contains("punctured the boat"))
        #expect((await world.perform("fix boat with gunk")).output.contains("boat is repaired"))
        #expect((await world.snapshot()).placements[Self.tube] == .nowhere)
        #expect((await world.snapshot()).globals[EntityID("ZorkDam.floodLevel")] == .int(-1))
        _ = await world.perform("drop sword")
        _ = await world.perform("enter boat")
        #expect((await world.perform("launch boat")).output.contains("Frigid River"))
    }

    private static let tube = EntityID("ZorkDam.tube")

    private static func groupedPutBoatWorld(aboard: Bool) async throws -> GameWorld {
        let world = try GameWorld(game: Zork1(), seed: 39)
        _ = await world.begin()
        var route = toInflatedBoat
        route.insert("take axe", at: try #require(route.lastIndex(of: "attack troll")) + 1)
        route.insert("take tube", at: try #require(route.firstIndex(of: "take wrench")) + 1)
        for command in route + ["put wrench in boat"] { _ = await world.perform(command) }
        if aboard {
            for command in ["drop sword", "drop axe", "enter boat", "take sword", "take axe"] {
                _ = await world.perform(command)
            }
        }
        let ready = await world.snapshot()
        #expect(ready.playerLocation == bank)
        #expect(ready.playerVehicle == (aboard ? boat : nil))
        #expect(ready.placements[sword] == .heldBy(.player))
        #expect(ready.placements[axe] == .heldBy(.player))
        #expect(ready.placements[tube] == .heldBy(.player))
        #expect(ready.placements[pump] == .heldBy(.player))
        #expect(ready.placements[wrench] == .inside(boat))
        #expect(ready.placements[label] == .inside(boat))
        return world
    }

    private static func punctureCount(in output: String) -> Int {
        occurrences(of: punctureLine, in: output) + occurrences(of: "punctured the boat", in: output)
    }

    @Test(arguments: [false, true], groupedSharpPutCommands)
    func groupedSharpPutLeavesOneWreckAndRefusesObsoleteHullMembers(aboard: Bool, command: String) async throws {
        let world = try await Self.groupedPutBoatWorld(aboard: aboard)
        let response = await world.perform(command)
        #expect(Self.punctureCount(in: response.output) == 1)
        #expect(response.output.contains("can't reach"))
        let after = await world.snapshot()
        #expect(after.playerLocation == Self.bank)
        #expect(after.playerVehicle == nil)
        #expect(after.placements[Self.boat] == .nowhere)
        #expect(after.placements[Self.wreck] == .room(Self.bank))
        #expect(after.placements[Self.label] == .room(Self.bank))
        #expect(after.placements[Self.wrench] == .room(Self.bank))
        #expect(after.placements[Self.sword] == .heldBy(.player))
        #expect(after.placements[Self.axe] == .heldBy(.player))
        #expect(after.placements[Self.tube] == .heldBy(.player))
        let expectedPump: Placement = command.hasPrefix("put pump") ? .room(Self.bank) : .heldBy(.player)
        #expect(after.placements[Self.pump] == expectedPump)
        let look = (await world.perform("look")).output
        #expect(look.contains("punctured boat"))
        #expect(look.contains("label"))
        #expect(look.contains("wrench"))
        // A later command names the wreck rather than reviving the obsolete hull.
        let refused = await world.perform("put sword and axe in boat")
        #expect(Self.punctureCount(in: refused.output) == 0)
        #expect((await world.snapshot()).placements[Self.wreck] == .room(Self.bank))
        #expect((await world.snapshot()).placements[Self.boat] == .nowhere)
    }

    @Test(arguments: [false, true], groupedSharpPutCommands)
    func undoRestoresTheWholeGroupedPutIncludingCargoAndBoarding(aboard: Bool, command: String) async throws {
        let world = try await Self.groupedPutBoatWorld(aboard: aboard)
        let before = await world.snapshot()
        _ = await world.perform(command)
        #expect((await world.snapshot()).placements[Self.wreck] == .room(Self.bank))
        _ = await world.perform("undo")
        let restored = await world.snapshot()
        #expect(restored.placements == before.placements)
        #expect(restored.playerVehicle == before.playerVehicle)
        #expect(restored.playerLocation == before.playerLocation)
        #expect(restored.globals == before.globals)
        #expect(restored.activeDaemons == before.activeDaemons)
        #expect(restored.touched == before.touched)
        #expect(restored.moves == before.moves)
        #expect(restored.rngState == before.rngState)
        #expect(restored.pronounIt == before.pronounIt)
        #expect(Self.punctureCount(in: (await world.perform(command)).output) == 1)
        #expect((await world.snapshot()).placements[Self.wreck] == .room(Self.bank))
    }

    @Test(arguments: [false, true], ["put sword and axe in boat", "put axe and sword in boat"])
    func groupedPutWreckCanBeRepairedAndRepairUndoneBeforeReboarding(aboard: Bool, command: String) async throws {
        let world = try await Self.groupedPutBoatWorld(aboard: aboard)
        _ = await world.perform(command)
        let beforeRepair = await world.snapshot()
        #expect(beforeRepair.placements[Self.wreck] == .room(Self.bank))
        #expect((await world.perform("fix boat with tube")).output.contains("boat is repaired"))
        let repaired = await world.snapshot()
        #expect(repaired.placements[Self.boat] == .room(Self.bank))
        #expect(repaired.placements[Self.wreck] == .nowhere)
        #expect(repaired.placements[Self.tube] == .nowhere)
        #expect(repaired.placements[Self.label] == .room(Self.bank))
        #expect(repaired.placements[Self.wrench] == .room(Self.bank))
        _ = await world.perform("undo")
        let restored = await world.snapshot()
        #expect(restored.placements == beforeRepair.placements)
        #expect(restored.playerVehicle == beforeRepair.playerVehicle)
        #expect(restored.globals == beforeRepair.globals)
        #expect((await world.perform("fix boat with tube")).output.contains("boat is repaired"))
        for next in ["drop sword", "drop axe", "enter boat", "launch boat"] { _ = await world.perform(next) }
        let afloat = await world.snapshot()
        #expect(afloat.playerVehicle == Self.boat)
        #expect(afloat.playerLocation == Self.river1)
        #expect(afloat.placements[Self.boat] == .room(Self.river1))
    }

    @Test(
        arguments: [false, true],
        [
            ("ZorkHouse.knife", "knife"), ("ZorkTemple.sceptre", "sceptre"),
            ("ZorkMaze.rustyKnife", "rusty knife"), ("ZorkThief.stiletto", "stiletto"),
        ])
    func laterSourceWeaponsCannotPunctureAnAlreadyReplacedHull(aboard: Bool, weapon: (String, String)) async throws {
        let world = try await Self.groupedPutBoatWorld(aboard: aboard)
        let id = EntityID(weapon.0)
        await world.placeBoatTestItem(id, .heldBy(.player))
        let response = await world.perform("put sword and \(weapon.1) in boat")
        #expect(Self.punctureCount(in: response.output) == 1)
        #expect(response.output.contains("can't reach"))
        let after = await world.snapshot()
        #expect(after.placements[Self.wreck] == .room(Self.bank))
        #expect(after.placements[id] == .heldBy(.player))
        #expect(after.placements[Self.label] == .room(Self.bank))
        #expect(after.placements[Self.wrench] == .room(Self.bank))
    }

    @Test(arguments: [
        "drop sword", "put sword in boat", "attack label with sword",
        "smash label with sword", "destroy label with sword", "break label with sword",
    ])
    func aboardWeaponActionsWreckTheBoatAshore(command: String) async throws {
        let world = try await Self.boardedBoatWorld(["take sword", "drop wrench"])
        let before = await world.snapshot()
        #expect(before.placements[Self.label] == .inside(Self.boat))
        #expect(before.placements[EntityID("ZorkDam.wrench")] == .inside(Self.boat))
        let response = await world.perform(command)
        #expect(response.output.contains(Self.punctureLine))
        #expect(!response.output.contains(Self.riverDeath))
        let after = await world.snapshot()
        #expect(after.playerLocation == Self.bank)
        #expect(after.playerVehicle == nil)
        #expect(after.placements[Self.boat] == .nowhere)
        #expect(after.placements[Self.wreck] == .room(Self.bank))
        #expect(after.placements[Self.label] == .room(Self.bank))
        #expect(after.placements[EntityID("ZorkDam.wrench")] == .room(Self.bank))
        #expect(after.placements[Self.sword] == .heldBy(.player))
        #expect((await world.perform("diagnose")).output.contains("perfect health"))
    }

    @Test(arguments: [
        "drop sword", "put sword in boat", "attack label with sword", "smash label with sword",
    ])
    func aboardWeaponActionsDrownOnTheRiverAndUndoRestoresTheBoat(command: String) async throws {
        let world = try await Self.boardedBoatWorld(["take sword", "launch boat"])
        let before = await world.snapshot()
        #expect(before.playerLocation == Self.river1)
        let response = await world.perform(command)
        #expect(response.output.contains(Self.punctureLine))
        #expect(response.output.contains(Self.riverDeath))
        #expect(response.output.contains("you probably deserve another"))
        let after = await world.snapshot()
        #expect(after.playerVehicle == nil)
        #expect(after.placements[Self.boat] == .nowhere)
        #expect(after.placements[Self.wreck] == .room(Self.river1))
        #expect(after.placements[Self.label] == .room(Self.river1))
        _ = await world.perform("undo")
        let restored = await world.snapshot()
        #expect(restored.playerLocation == before.playerLocation)
        #expect(restored.playerVehicle == before.playerVehicle)
        #expect(restored.placements == before.placements)
        #expect(restored.globals == before.globals)
        #expect(restored.activeDaemons == before.activeDaemons)
        #expect((await world.perform("diagnose")).output.contains("perfect health"))
    }

    @Test func aDroppedWeaponWreckCanBeRepairedAndBoardedAgain() async throws {
        let world = try GameWorld(game: Zork1(), seed: 39)
        _ = await world.begin()
        var route = Self.toInflatedBoat
        route.insert("take tube", at: try #require(route.firstIndex(of: "take wrench")) + 1)
        for command in route + ["drop sword", "enter boat", "take sword", "drop sword"] {
            _ = await world.perform(command)
        }
        #expect((await world.snapshot()).playerVehicle == nil)
        #expect((await world.snapshot()).placements[Self.wreck] == .room(Self.bank))
        #expect((await world.perform("fix boat with tube")).output.contains("boat is repaired"))
        for command in ["drop sword", "enter boat", "launch boat"] { _ = await world.perform(command) }
        let repaired = await world.snapshot()
        #expect(repaired.playerVehicle == Self.boat)
        #expect(repaired.playerLocation == Self.river1)
        #expect(repaired.placements[Self.wreck] == .nowhere)
        #expect(repaired.placements[EntityID("ZorkDam.tube")] == .nowhere)
    }

    @Test(arguments: [
        ("ZorkHouse.sword", "sword"), ("ZorkHouse.knife", "knife"),
        ("ZorkTemple.sceptre", "sceptre"), ("ZorkMaze.rustyKnife", "rusty knife"),
        ("ZorkThief.stiletto", "stiletto"), ("ZorkCellar.axe", "bloody axe"),
    ])
    func everySourceWeaponUsesTheBoatInterceptionBeforeItsOwnRules(id: String, noun: String) async throws {
        for command in ["drop \(noun)", "attack label with \(noun)", "smash label with \(noun)"] {
            let world = try await Self.boardedBoatWorld()
            await world.placeBoatTestItem(EntityID(id), .heldBy(.player))
            let response = await world.perform(command)
            #expect(response.output.contains(Self.punctureLine), "\(command): \(response.output)")
            #expect(!response.output.contains("slits your throat"))
            let after = await world.snapshot()
            #expect(after.playerVehicle == nil)
            #expect(after.placements[Self.wreck] == .room(Self.bank))
            #expect(after.placements[EntityID(id)] == .heldBy(.player))
        }
    }

    @Test(arguments: [
        "drop sword", "put sword in boat", "attack label with sword", "smash label with sword",
    ])
    func unheldWeaponsRefuseWithoutWreckingTheBoat(command: String) async throws {
        let world = try await Self.boardedBoatWorld()
        let response = await world.perform(command)
        #expect(response.output.contains("holding") || response.output.contains("carrying"))
        #expect(!response.output.contains(Self.punctureLine))
        let after = await world.snapshot()
        #expect(after.playerVehicle == Self.boat)
        #expect(after.placements[Self.wreck] == .nowhere)
        #expect(after.placements[Self.sword] == .room(Self.bank))
    }

    @Test(arguments: ["swing rusty knife at label", "thrust rusty knife at label"])
    func aboardTargetedRustyKnifeSwingsStillCurseBeforeAnyAttackRedirect(command: String) async throws {
        let world = try await Self.boardedBoatWorld()
        let knife = EntityID("ZorkMaze.rustyKnife")
        await world.placeBoatTestItem(knife, .heldBy(.player))
        let response = await world.perform(command)
        #expect(response.output.contains("slits your throat"))
        #expect(!response.output.contains(Self.punctureLine))
        let after = await world.snapshot()
        #expect(after.placements[knife] == .nowhere)
        #expect(after.placements[Self.boat] == .room(Self.bank))
        #expect(after.placements[Self.wreck] == .nowhere)
    }

    @Test(arguments: ["swing sword at label", "thrust sword at label"], [false, true])
    func targetedSwordSwingsReachTheBoatAttackInterceptionAndUndo(command: String, afloat: Bool) async throws {
        let world = try await Self.boardedBoatWorld(["take sword"])
        if afloat { _ = await world.perform("launch boat") }
        let before = await world.snapshot()
        let result = await world.perform(command)
        #expect(result.output.contains(Self.punctureLine))
        let after = await world.snapshot()
        #expect(after.playerVehicle == nil)
        #expect(after.placements[Self.boat] == .nowhere)
        #expect(after.placements[Self.wreck] == .room(before.playerLocation))
        #expect(after.moves == before.moves + 1)
        #expect(result.output.contains(Self.riverDeath) == afloat)
        _ = await world.perform("undo")
        let restored = await world.snapshot()
        #expect(restored.placements == before.placements)
        #expect(restored.playerVehicle == before.playerVehicle)
        #expect(restored.playerLocation == before.playerLocation)
        #expect(restored.globals == before.globals)
        #expect(restored.activeDaemons == before.activeDaemons)
        #expect(restored.moves == before.moves)
        #expect(restored.rngState == before.rngState)
    }

    @Test(arguments: ["weapon", "target"])
    func unreachableWeaponOrTargetRefusesBeforePuncturing(blocked: String) async throws {
        for command in [
            "attack label with sword", "smash label with sword", "swing sword at label", "thrust sword at label",
        ] {
            let world = try await Self.boardedBoatWorld(["take sword"])
            let bottle = EntityID("ZorkHouse.bottle")
            await world.placeBoatTestItem(bottle, .heldBy(.player))
            await world.placeBoatTestItem(blocked == "weapon" ? Self.sword : Self.label, .inside(bottle))
            let response = await world.perform(command)
            #expect(response.output.contains("can't reach"), "\(command): \(response.output)")
            #expect(!response.output.contains(Self.punctureLine))
            #expect((await world.snapshot()).playerVehicle == Self.boat)
            #expect((await world.snapshot()).placements[Self.wreck] == .nowhere)
        }
    }

    @Test func harmlessCargoAndNonWeaponActionsLeaveTheBoatIntact() async throws {
        let world = try await Self.boardedBoatWorld()
        for command in [
            "drop wrench", "take wrench", "put wrench in boat", "take wrench",
            "attack label with wrench", "smash label with wrench", "attack label", "smash label",
            "swing wrench at label", "swing wrench",
        ] {
            let response = await world.perform(command)
            #expect(!response.output.contains(Self.punctureLine))
            #expect((await world.snapshot()).playerVehicle == Self.boat)
            #expect((await world.snapshot()).placements[Self.wreck] == .nowhere)
        }
        #expect((await world.perform("drop wrench")).output.contains("Dropped."))
        #expect((await world.snapshot()).placements[EntityID("ZorkDam.wrench")] == .inside(Self.boat))
    }

    @Test(arguments: [true, false])
    func puttingASharpWeaponIntoTheBoatFromTheBankRequiresHoldingIt(held: Bool) async throws {
        let world = try GameWorld(game: Zork1(), seed: 39)
        _ = await world.begin()
        for command in Self.toInflatedBoat { _ = await world.perform(command) }
        if !held { _ = await world.perform("drop sword") }
        let response = await world.perform("put sword in boat")
        let after = await world.snapshot()
        #expect(after.playerLocation == Self.bank)
        #expect(after.playerVehicle == nil)
        if held {
            #expect(response.output.contains("punctured the boat"))
            #expect(after.placements[Self.wreck] == .room(Self.bank))
            #expect(after.placements[Self.label] == .room(Self.bank))
        } else {
            #expect(response.output.contains("holding"))
            #expect(after.placements[Self.boat] == .room(Self.bank))
            #expect(after.placements[Self.wreck] == .nowhere)
            #expect(after.placements[Self.label] == .inside(Self.boat))
        }
    }

    @Test func weaponDropOutsideTheBoatRemainsAnOrdinaryDrop() async throws {
        let transcript = try await play(Zork1(), Self.toInflatedBoat + ["drop sword", "look"], seed: 39)
        #expect(turnOutput(of: "drop sword", in: transcript).contains("Dropped."))
        #expect(!transcript.contains(Self.punctureLine))
        #expect(!transcript.contains("punctured the boat"))
    }

    // MARK: - The boat's two valves
    //
    // `1actions.zil` gates both of them on the boat lying *directly in the room*
    // — `<NOT <IN? ,INFLATED-BOAT ,HERE>>` for DEFLATE (line 2803) and
    // `<NOT <IN? ,INFLATABLE-BOAT ,HERE>>` for INFLATE (line 2820) — and checks
    // that ground condition before it looks at anything else. The cases below
    // pin both orders (#197).

    /// You cannot let the air out of a boat you are carrying. The original
    /// checks `<IN? ,INFLATED-BOAT ,HERE>`, so holding it fails the test and
    /// `Prose.deflateNotOnGround` answers — the constant that sat declared and
    /// uncalled until #197.
    @Test func deflatingABoatYouAreHoldingIsRefused() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toInflatedBoat + ["take boat", "deflate boat", "inventory"],
            seed: 39)

        #expect(
            turnOutput(of: "deflate boat", in: transcript)
                .contains("must be on the ground to be deflated"))
        // The refusal is total: still a boat, and no pile of plastic anywhere.
        let inventory = turnOutput(of: "inventory", in: transcript)
        #expect(inventory.contains("magic boat"))
        #expect(!inventory.contains("pile of plastic"))
    }

    /// Set it down first and the valve opens, trading the boat for the pile of
    /// plastic where it lay.
    @Test func deflatingTheBoatOnTheGroundTradesItForThePile() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toInflatedBoat + ["deflate boat", "look", "inventory"],
            seed: 39)

        #expect(turnOutput(of: "deflate boat", in: transcript).contains("The boat deflates."))
        #expect(turnOutput(of: "look", in: transcript).contains("pile of plastic"))
        #expect(!turnOutput(of: "inventory", in: transcript).contains("pile of plastic"))
    }

    /// Sitting in the boat is the *first* thing the original rules out, ahead of
    /// the ground check — and the one refusal this rule has always had, which
    /// nothing pinned until now.
    @Test func deflatingWhileAboardIsRefused() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toInflatedBoat + ["drop sword", "enter boat", "deflate boat"],
            seed: 39)

        #expect(
            turnOutput(of: "deflate boat", in: transcript)
                .contains("can't deflate the boat while you're in it"))
    }

    /// The two valves compose: what you deflate you can pump back up, because
    /// both now agree on where the thing has to be lying. The asymmetry #197
    /// named — deflate permitting a held boat that inflate would then refuse to
    /// re-inflate — has no unmatched pair left to produce.
    @Test func deflatingThenReInflatingRestoresTheBoat() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toInflatedBoat + ["deflate boat", "inflate plastic with pump", "look"],
            seed: 39)

        expectInOrder(
            transcript,
            [
                "The boat deflates.",
                "The boat inflates and appears seaworthy.",
            ])
        #expect(turnOutput(of: "look", in: transcript).contains("magic boat"))
    }

    // MARK: - The tan label
    //
    // `IBOAT-FUNCTION` prints *two* lines on a successful inflate — the boat's,
    // then the label's — and `Sources/Zork1/Zork1.swift` carries the note on why
    // the second one can come round again (#203).

    /// The pump hands you the boat *and* tells you what came folded inside it,
    /// and the label reads as the Frobozz Magic Boat Company's own fine print —
    /// which is `read label` answering at all, where before #203 it could not.
    /// Until then it is nowhere, riding the boat that is itself nowhere.
    @Test func inflatingTheBoatTheFirstTimeRevealsTheTanLabel() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toPumpAtDamBase + ["read label", "inflate plastic with pump", "read tan label"],
            seed: 39)

        #expect(turnOutput(of: "read label", in: transcript).contains("can't see any such thing"))
        expectInOrder(
            transcript,
            [
                "The boat inflates and appears seaworthy.",
                "A tan label is lying inside the boat.",
                "FROBOZZ MAGIC BOAT COMPANY",
                "Hello, Sailor!",
                "76",  // the warranty's milliseconds
            ])
    }

    /// The announcement is gated on the label having been handled, not on the
    /// boat having been pumped before: deflate and pump again without ever
    /// touching the label and you are told about it a second time, because the
    /// original reads that flag and never sets it. Take it once — the flag the
    /// line itself never set — and the pump goes quiet. Through all of it the
    /// label rides the deflate out of play inside the boat and comes back.
    @Test func theLabelIsAnnouncedUntilThePlayerHandlesIt() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toInflatedBoat + [
                "deflate boat", "inflate plastic with pump",  // untouched: announced again
                "take label",
                "deflate boat", "inflate plastic with pump",  // handled: silent
                "inventory",
            ],
            seed: 39)

        #expect(occurrences(of: "A tan label is lying inside the boat.", in: transcript) == 2)
        #expect(turnOutput(of: "inventory", in: transcript).contains("tan label"))
    }

    /// A blade holes the hull and `puncture()` tips the cargo onto the bank, so
    /// the label ends up underfoot — listed with the engine's stock line, which
    /// is verbatim what the original's `FDESC`-less object gets, and still the
    /// same readable object.
    @Test func aPuncturedBoatTipsTheLabelOntoTheBank() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toInflatedBoat + ["enter boat", "look", "read label"],
            seed: 39)

        expectInOrder(
            transcript,
            [
                "punctured the boat",
                "There is a tan label here.",
                "FROBOZZ MAGIC BOAT COMPANY",
            ])
    }

    /// The mirror of ``deflatingABoatYouAreHoldingIsRefused``: the pile must be
    /// spread on the ground before the pump will do anything with it.
    @Test func inflatingAPileYouAreHoldingIsRefused() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toPumpAtDamBase + ["take plastic", "inflate plastic with pump"],
            seed: 39)

        #expect(
            turnOutput(of: "inflate plastic with pump", in: transcript)
                .contains("must be on the ground to be inflated"))
    }

    /// Offering something that is not the pump gets the original's jest rather
    /// than the lung-power line, which the ZIL reserves for breath (`V-BREATHE`
    /// performs INFLATE with `LUNGS`).
    @Test func inflatingWithTheWrongToolIsRefused() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toPumpAtDamBase + ["inflate plastic with sword"],
            seed: 39)

        #expect(
            turnOutput(of: "inflate plastic with sword", in: transcript)
                .contains("Surely you jest!"))
    }

    /// Naming no tool at all is the breath case, and keeps the lung-power line.
    @Test func inflatingWithNothingComplainsOfLungPower() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toPumpAtDamBase + ["inflate plastic"],
            seed: 39)

        #expect(
            turnOutput(of: "inflate plastic", in: transcript)
                .contains("don't have enough lung power"))
    }

    /// The ordering, pinned. `IBOAT-FUNCTION` asks "is it on the ground?" before
    /// it asks what you are holding, so a held pile plus a wrong tool answers
    /// with the ground line. Reverse the two guards and this says
    /// "Surely you jest!" instead.
    @Test func theGroundGuardOutranksTheWrongTool() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toPumpAtDamBase + ["take plastic", "inflate plastic with wrench"],
            seed: 39)

        let refusal = turnOutput(of: "inflate plastic with wrench", in: transcript)
        #expect(refusal.contains("must be on the ground to be inflated"))
        #expect(!refusal.contains("Surely you jest!"))
    }

    /// Sit still on the river and the current does the steering — right over
    /// Aragain Falls. Drifting off the last stretch is fatal, though as a first
    /// death it is survivable: Zork sets the drowned adventurer back in the forest.
    @Test func driftingPastTheLastStretchGoesOverTheFalls() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toLaunched + [
                "down", "down", "down", "down",  // River-2 → … → River-5
                "wait",  // the current carries you over the falls
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "Frigid River",
                "bottom of waterfalls",  // the drowning — over Aragain Falls
                "Forest",  // the resurrection
            ])
        #expect(!transcript.contains("Would you like to RESTART"))
    }

    /// The current is a continuous interrupt: never touching a paddle, just
    /// waiting, the river carries the boat one stretch at a time — River-1 → 2 →
    /// 3 → 4 → 5 — and finally over the falls. Fourteen idle turns from the
    /// launch does the whole run (dwell 4+4+3+2, then one more off River-5),
    /// proving the drift re-arms itself down the length of the river.
    @Test func theCurrentDriftsYouStretchByStretchToTheFalls() async throws {
        let waits = Array(repeating: "wait", count: 14)
        let transcript = try await play(
            Zork1(),
            Self.toLaunched + waits,
            seed: 39)
        // Four hand-off lines (River-1→2→3→4→5), then the plunge.
        let carries = transcript.components(separatedBy: "carries you downstream").count - 1
        #expect(carries == 4)
        expectInOrder(
            transcript,
            [
                "bottom of waterfalls",  // drifted off River-5, over the falls
                "Forest",  // the resurrection
            ])
        #expect(!transcript.contains("Would you like to RESTART"))
    }

    /// You cannot launch a boat you are not sitting in — waving it at the water
    /// from the bank gets you nowhere.
    @Test func launchingWithoutBoardingIsRefused() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toInflatedBoat + [
                "drop sword",  // set the blade down so nothing else is in play
                "launch boat",  // but never board
            ],
            seed: 39)
        expectInOrder(transcript, ["Dam Base", "not in the boat"])
    }

    /// The sceptre wakes the rainbow. Carrying it out of the temple by prayer and
    /// down the canyon to the End of Rainbow, a wave turns the rainbow solid and a
    /// pot of gold appears; the rainbow can then be crossed to Aragain Falls and
    /// back. Banked visits (40) plus the sceptre (4) and the pot (10) make 54.
    @Test func theSceptreWakesTheRainbow() async throws {
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west",
                "west",
                "take sword", "take lantern", "turn on lantern",
                "east", "up", "take rope", "down",
                "west",
                "push rug", "open trap door", "down",
                "north", "west",
                "attack troll", "attack troll", "attack troll",
                "east", "east",  // → East-West Passage → Round Room
                "southeast", "east",  // → Engravings Cave → Dome Room
                "tie rope to railing", "down",  // → Torch Room
                "south", "east",  // Temple → Egyptian Room
                "open coffin", "take sceptre",
                "west", "south",  // Temple → Altar
                "pray",  // the coffin egress drops you in the forest, sceptre in hand
                "east", "south", "east", "east",  // Forest West → … → Forest East
                "southeast", "down", "down", "north",  // canyon down to the End of Rainbow
                "up",  // refused — the rainbow is only light
                "wave sceptre",  // it turns solid; the pot appears
                "take pot",  // +10 on the find
                "up",  // On the Rainbow
                "east",  // Aragain Falls
                "west", "west",  // On the Rainbow → back to the End of Rainbow
                "score",
            ],
            seed: 0)
        expectInOrder(
            transcript,
            [
                "End of Rainbow",
                "walk on water vapor",  // the crossing refused while the rainbow is ordinary
                "become solid",  // the sceptre wakes it
                "shimmering pot of gold",  // the pot of gold
                "On the Rainbow",
                "Aragain Falls",
                "Your score is 54 of a possible 350",
            ])
    }

    /// The canyon climbs both ways (the original's `CLIMBABLE-CLIFF`): a smoke
    /// walk down from Forest East to the End of Rainbow and back up again, with
    /// no boat, no underground, and no randomness. It also proves the rainbow
    /// refuses a crossing until the sceptre has woken it.
    @Test func theCanyonClimbsBothWays() async throws {
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "east",  // West of House → … → Forest East
                "southeast", "down", "down", "north",  // Canyon View → Rocky Ledge → Bottom → End
                "up",  // refused — the rainbow isn't solid
                "south", "up", "up", "northwest",  // climb back: Bottom → Ledge → View → Forest East
            ],
            seed: 0)
        expectInOrder(
            transcript,
            [
                "Canyon View",
                "Rocky Ledge",
                "Canyon Bottom",
                "End of Rainbow",
                "walk on water vapor",  // the un-woken rainbow
                "Canyon Bottom",  // and the climb back up
                "Rocky Ledge",
                "Canyon View",
            ])
    }
}

// Placement seams exercise all six weapons and transparent-holder reach without replacing the river route.
extension GameWorld {
    fileprivate func placeBoatTestItem(_ item: EntityID, _ placement: Placement) {
        state.place(item, placement)
    }
}
