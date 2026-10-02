import Foundation
import GnustoTestSupport
import Testing

@testable import Gnusto
@testable import GnustoMeleeCombat
@testable import Zork1

/// End-to-end playthroughs of the Phase 10.11 thief endgame: forcing the egg
/// with a weapon or tool wrecks the canary, while the thief opens it cleanly;
/// the give-to-thief service; and the defended lair (the Treasure Room's +25
/// award, the now-snatchable silver chalice, and the thief who fights to the
/// death there). The thief roams the whole underground, so every route is seed-pinned;
/// the seeds are final (the Phase 10.14 walkthrough closed the roadmap's planned
/// one-time re-pin).
struct Zork1ThiefTests {
    static let eggToLair = [
        "north", "north", "up", "take egg", "down",
        "south", "west", "south", "east", "open window", "west", "west",
        "take sword", "take lantern", "turn on lantern", "open trophy case",
        "move rug", "open trap door", "down", "north",
        "attack troll", "attack troll", "attack troll",
        "west", "west", "west", "up", "take bag of coins", "take skeleton key",
        "southwest", "east", "south", "southeast", "odysseus", "up",
    ]

    private static let thiefID = EntityID("ZorkThief.thief")
    private static let engrossedID = EntityID("ZorkThief.engrossed")
    private static let ledgerID = EntityID("MeleeCombat.ledger")

    private static func engagedThiefWorld() async throws -> GameWorld {
        let world = try cachedWorld(Zork1(), seed: 1)
        _ = await world.begin()
        for command in eggToLair + ["wait", "wait", "wait", "wait"] {
            _ = await world.perform(command)
        }
        var state = await world.snapshot()
        // Isolate the combat daemon after the real route starts the fight.
        // Roaming and stealing have separate random draws, so retaining them
        // would not establish whether a quiet attack tick draws randomness.
        state.activeDaemons = ["thiefFights"]
        await world.restore(state, mode: .brief)
        return world
    }

    @Test func aTreasureGiftSkipsTheGiftTurnsAttackOnTheIssueRoute() async throws {
        let transcript = try await play(
            Zork1(),
            Self.eggToLair + ["wait", "wait", "wait", "wait", "give bag of coins to thief", "wait"],
            seed: 1)
        let gift = turnOutput(of: "give bag of coins to thief", in: transcript)
        #expect(gift.contains("mocking little bow"))
        #expect(!gift.contains("stiletto"))
        #expect(turnOutput(ofLast: "wait", in: transcript).contains("stiletto"))
    }

    @Test func anOrdinaryGiftDoesNotSkipTheGiftTurnsAttack() async throws {
        let transcript = try await play(
            Zork1(),
            Self.eggToLair + ["wait", "wait", "wait", "wait", "give skeleton key to thief"],
            seed: 1)
        let gift = turnOutput(of: "give skeleton key to thief", in: transcript)
        #expect(gift.contains("mocking little bow"))
        #expect(gift.contains("stiletto"))
    }

    @Test func treasureDistractionIsDrawFreeAndPreservesEngagementForOneTick() async throws {
        let world = try await Self.engagedThiefWorld()
        let before = await world.snapshot()
        let ledgerBefore = try #require(MeleeCombat.Ledger(stateValue: before.globals[Self.ledgerID]!))
        #expect(ledgerBefore.engaged.contains("thief"))
        _ = await world.perform("give bag of coins to thief")
        let quiet = await world.snapshot()
        let ledgerQuiet = try #require(MeleeCombat.Ledger(stateValue: quiet.globals[Self.ledgerID]!))
        #expect(quiet.placements[EntityID("ZorkMaze.bagOfCoins")] == .heldBy(Self.thiefID))
        #expect(quiet.rngState == before.rngState)
        #expect(ledgerQuiet.engaged == ledgerBefore.engaged)
        #expect(ledgerQuiet.playerHealth == ledgerBefore.playerHealth)
        #expect(quiet.globals[Self.engrossedID] == .bool(false))
        #expect((await world.perform("wait")).output.contains("stiletto"))
        #expect((await world.snapshot()).rngState != quiet.rngState)
    }

    @Test(arguments: [
        ("ZorkAboveGround.egg", "egg", true),
        ("ZorkCoalMine.diamond", "diamond", true),
        ("ZorkAboveGround.brokenEgg", "broken egg", false),
        ("ZorkHouse.sword", "sword", false),
    ])
    func giftDistractionUsesTheItemsPositiveDepositValue(
        identity: String, noun: String, distracts: Bool
    ) async throws {
        let world = try await Self.engagedThiefWorld()
        var before = await world.snapshot()
        before.place(EntityID(identity), .heldBy(.player))
        await world.restore(before, mode: .brief)
        _ = await world.perform("give \(noun) to thief")
        let after = await world.snapshot()
        #expect(after.placements[EntityID(identity)] == .heldBy(Self.thiefID))
        #expect((after.rngState == before.rngState) == distracts)
        let ledger = try #require(MeleeCombat.Ledger(stateValue: after.globals[Self.ledgerID]!))
        #expect(ledger.engaged.contains("thief"))
    }

    @Test func anUnheldTreasureCannotArmDistraction() async throws {
        let world = try await Self.engagedThiefWorld()
        var before = await world.snapshot()
        before.place(EntityID("ZorkMaze.bagOfCoins"), .room(before.playerLocation))
        await world.restore(before, mode: .brief)
        #expect((await world.perform("give coins to thief")).output.contains("aren't holding"))
        let after = await world.snapshot()
        #expect(after.globals[Self.engrossedID] == before.globals[Self.engrossedID])
        #expect(after.placements == before.placements)
        // This ordinary refused GIVE still costs a turn and permits combat.
        #expect(after.rngState != before.rngState)
        #expect(after.moves == before.moves + 1)
    }

    @Test func undoRestoresTheTreasureGiftAndItsQuietReplay() async throws {
        let world = try await Self.engagedThiefWorld()
        let before = await world.snapshot()
        let gift = await world.perform("give bag of coins to thief")
        _ = await world.perform("undo")
        let restored = await world.snapshot()
        #expect(restored.globals == before.globals)
        #expect(restored.placements == before.placements)
        #expect(restored.rngState == before.rngState)
        #expect(restored.moves == before.moves)
        #expect((await world.perform("give bag of coins to thief")).output == gift.output)
    }

    @Test func saveRestoresAPendingDistractionAndConsumesItOnce() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("gnusto-thief-distraction-\(UUID().uuidString).sav").path
        defer { try? FileManager.default.removeItem(atPath: path) }
        let world = try await Self.engagedThiefWorld()
        var pending = await world.snapshot()
        // A suspended aggression daemon leaves the gift state pending. This
        // fixture exercises persistence independently of same-turn consumption.
        pending.activeDaemons.remove("thiefFights")
        await world.restore(pending, mode: .brief)
        _ = await world.perform("give bag of coins to thief")
        pending = await world.snapshot()
        #expect(pending.globals[Self.engrossedID] == .bool(true))
        pending.activeDaemons.insert("thiefFights")
        await world.restore(pending, mode: .brief)
        _ = await world.perform("save")
        #expect((await world.perform(path)).output.contains("Saved."))
        #expect(!(await world.perform("wait")).output.contains("stiletto"))
        #expect((await world.perform("wait")).output.contains("stiletto"))
        _ = await world.perform("restore")
        #expect((await world.perform(path)).output.contains("Restored."))
        #expect((await world.snapshot()).globals[Self.engrossedID] == .bool(true))
        #expect(!(await world.perform("wait")).output.contains("stiletto"))
        #expect((await world.snapshot()).globals[Self.engrossedID] == .bool(false))
        #expect((await world.perform("wait")).output.contains("stiletto"))
    }

    @Test func theTrollsAxeIsAWeaponAgainstTheThief() async throws {
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west", "west",
                "take sword", "take lantern", "turn on lantern",
                "push rug", "open trap door", "down", "north",
                "west", "attack troll", "attack troll", "attack troll", "take axe",
                "west", "west", "west", "up", "southwest", "east", "south", "southeast",
                "odysseus", "up", "attack thief with axe",
            ],
            seed: 39)

        let attack = turnOutput(of: "attack thief with axe", in: transcript)
        #expect(!attack.contains("is no weapon"))
        #expect(attack.contains("thief"))
    }

    @Test func bareAndExplicitHandOpeningLeaveTheEggClosed() async throws {
        let transcript = try await play(
            Zork1(),
            [
                "north", "north", "up", "take egg",
                "open egg", "look in egg",
                "open egg with hands", "look in egg",
            ])

        let bare = turnOutput(of: "open egg", in: transcript)
        #expect(bare.contains("neither the tools nor the expertise"))
        #expect(!bare.contains("clumsiness of your attempt"))
        let hands = turnOutput(of: "open egg with hands", in: transcript)
        #expect(hands.contains("without damaging it"))
        #expect(!hands.contains("sentence isn't one I recognize"))
        #expect(turnOutput(of: "look in egg", in: transcript).contains("The jewel-encrusted egg is closed."))
        #expect(turnOutput(ofLast: "look in egg", in: transcript).contains("The jewel-encrusted egg is closed."))
        #expect(!transcript.contains("broken clockwork canary"))
    }

    @Test func forcingTheEggOpenWithAWeaponRuinsTheCanaryOnce() async throws {
        // The sword is a source WEAPONBIT item. Fetching it before the egg
        // proves the destructive branch receives the named instrument.
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west", "west", "take sword",
                "east", "east", "north", "north", "up", "take egg",
                "open egg with sword", "open egg",
                "look in egg", "down", "drop egg", "look", "examine canary", "score",
            ])
        expectInOrder(
            transcript,
            [
                "clumsiness of your attempt",  // ruined on force
                "recently had a bad experience",  // the damage helper describes the ruin
                "It is already open.",  // the second OPEN does not damage it again
                "In the broken jewel-encrusted egg is a broken clockwork canary.",
                "recently had a bad experience",  // the broken canary's own description
                "Your score is 15 of a possible 350",  // kitchen 10 + shell 5; canary nothing
            ])
        #expect(transcript.components(separatedBy: "clumsiness of your attempt").count == 2)

        // The ruined bird's `FDESC` is its listing line, printed while it sits
        // untouched in the dropped egg. EXAMINE is the same paragraph without
        // the clause that says where it is. (#617)
        #expect(
            turnOutput(of: "look", in: transcript)
                .contains("There is a golden clockwork canary nestled in the egg. It seems to"))
        let examined = turnOutput(of: "examine canary", in: transcript)
        #expect(examined.contains("A golden clockwork canary. It seems to have recently had a bad"))
        #expect(!examined.contains("nestled in the egg"))
    }

    @Test func unheldQualifyingToolsLeaveTheEggAndCanaryUnchanged() async throws {
        let world = try cachedWorld(Zork1(), seed: 0)
        _ = await world.begin()
        for command in ["north", "north", "up", "take egg"] {
            _ = await world.perform(command)
        }

        let egg = EntityID("ZorkAboveGround.egg")
        let canary = EntityID("ZorkHouse.canary")
        let brokenCanary = EntityID("ZorkHouse.brokenCanary")
        let sword = EntityID("ZorkHouse.sword")
        let thief = EntityID("ZorkThief.thief")
        var baseline = await world.snapshot()
        baseline.place(sword, .room(baseline.playerLocation))

        await world.restore(baseline, mode: .brief)
        let groundRefusal = await world.perform("open egg with sword")
        let afterGroundRefusal = await world.snapshot()

        #expect(groundRefusal.output.contains("aren't holding"))
        #expect(afterGroundRefusal.placements[egg] == baseline.placements[egg])
        #expect(afterGroundRefusal.placements[canary] == baseline.placements[canary])
        #expect(afterGroundRefusal.placements[brokenCanary] == baseline.placements[brokenCanary])
        #expect(afterGroundRefusal.placements[sword] == baseline.placements[sword])
        #expect(!afterGroundRefusal.openItems.contains(egg))

        var actorHeld = baseline
        actorHeld.place(thief, .room(actorHeld.playerLocation))
        actorHeld.place(sword, .heldBy(thief))
        actorHeld.unconsciousActors.insert(thief)
        await world.restore(actorHeld, mode: .brief)
        let actorRefusal = await world.perform("open egg with sword")
        let afterActorRefusal = await world.snapshot()

        #expect(actorRefusal.output.contains("aren't holding"))
        #expect(afterActorRefusal.placements[egg] == actorHeld.placements[egg])
        #expect(afterActorRefusal.placements[canary] == actorHeld.placements[canary])
        #expect(afterActorRefusal.placements[brokenCanary] == actorHeld.placements[brokenCanary])
        #expect(afterActorRefusal.placements[sword] == actorHeld.placements[sword])
        #expect(!afterActorRefusal.openItems.contains(egg))
    }

    @Test func theThiefOpensAStolenEggWhenHeStashesIt() async throws {
        // Seed 1 makes the thief steal the egg when the player first returns
        // to the lair. Leaving again gives the stash daemon its off-screen turn.
        let transcript = try await play(
            Zork1(),
            Self.eggToLair + ["wait", "wait", "wait", "down", "up", "down", "up"],
            seed: 1)

        #expect(transcript.contains("jewel-encrusted egg vanished"))
        #expect(
            turnOutput(ofLast: "up", in: transcript)
                .contains("In the jewel-encrusted egg is a golden clockwork canary."))
    }

    @Test func theThiefOpensAStolenEggWhenHeDies() async throws {
        // This is the issue route: theft on move 38 and death before any
        // player-run opening. The recovered canary must still make the bauble.
        let transcript = try await play(
            Zork1(),
            Self.eggToLair + [
                "wait", "wait", "wait", "wait",
                "attack thief", "attack thief", "attack thief", "attack thief",
                "take egg", "look in egg", "take canary",
                "down", "east", "east", "east", "east", "east",
                "wind canary", "take bauble",
            ],
            seed: 1)

        #expect(transcript.contains("jewel-encrusted egg vanished"))
        #expect(transcript.contains("The thief takes a fatal blow"))
        #expect(
            turnOutput(of: "look in egg", in: transcript)
                .contains("In the jewel-encrusted egg is a golden clockwork canary."))
        #expect(turnOutput(of: "wind canary", in: transcript).contains("lovely songbird"))
        #expect(turnOutput(of: "take bauble", in: transcript).contains("Taken."))
    }

    @Test func theThiefOpensAGiftedEggWhenHeDiesBeforeTheFuse() async throws {
        // Put the thief down after the gift so the next ordinary attack is a
        // guaranteed finishing blow. Death therefore precedes the four-turn
        // GIVE fuse without making the regression depend on a combat roll.
        let world = try cachedWorld(Zork1(), seed: 0)
        _ = await world.begin()
        for command in Self.eggToLair {
            _ = await world.perform(command)
        }

        let refused = await world.perform("open egg")
        let beforeGift = await world.snapshot()
        let gift = await world.perform("give egg to thief")
        var beforeDeath = await world.snapshot()
        let recipients = Set(
            beforeDeath.placements.compactMap { id, placement -> EntityID? in
                guard beforeGift.placements[id] == .heldBy(.player),
                    case .heldBy(let holder) = placement,
                    holder != .player
                else { return nil }
                return holder
            })
        let thiefID = try #require(recipients.count == 1 ? recipients.first : nil)
        beforeDeath.unconsciousActors.insert(thiefID)
        await world.restore(beforeDeath, mode: .brief)
        let attack = await world.perform("attack thief")
        let egg = await world.perform("look in egg")

        #expect(refused.output.contains("neither the tools nor the expertise"))
        #expect(gift.output.contains("unexpected generosity"))
        #expect(attack.output.contains("The thief takes a fatal blow"))
        #expect(egg.output.contains("In the jewel-encrusted egg is a golden clockwork canary."))
    }

    @Test func theThiefTakesTheEggYouOffer() async throws {
        // Hand the thief the egg where you meet him in the Gallery and he
        // pockets it with a knowing smile — the setup for his off-screen
        // egg-opening service (where, unlike forcing it with a tool, he keeps
        // the canary intact). The egg leaves your possession with him. Seed 5 keeps
        // the thief loitering in the Gallery when you arrive with the egg.
        let transcript = try await play(
            Zork1(),
            [
                "north", "north", "up", "take egg", "down",
                "south", "west", "south",
                "south", "east", "open window", "west", "west",
                "take lantern", "turn on lantern",
                "push rug", "open trap door", "down",
                "south", "east",  // East of Chasm → Gallery, where the thief starts
                "give egg to thief", "examine egg", "inventory",
            ],
            seed: 5)
        expectInOrder(
            transcript,
            [
                "unexpected generosity",
                "stops to admire its beauty.",  // he takes it (the service is armed)
                "You can't see any such thing.",  // examine egg — it's gone with him
                "You are carrying a brass lantern",  // …and only the lantern; the egg is his now
            ])
        // The egg really did leave your hands — the inventory names only the
        // lantern.
        let carried = turnOutput(of: "inventory", in: transcript)
        #expect(!carried.contains("egg"))
    }

    @Test func theThiefRefusesGiftsThePlayerDoesNotHold() async throws {
        // Seed 5 keeps the thief in the Gallery. The player can name the thief,
        // his stiletto, and the Gallery's vandals there, but none is in the
        // player's hands. Each route starts fresh so the thief cannot roam away
        // before the next offer is parsed.
        let route = [
            "north", "north", "up", "take egg", "down",
            "south", "west", "south",
            "south", "east", "open window", "west", "west",
            "take lantern", "turn on lantern",
            "push rug", "open trap door", "down",
            "south", "east",
        ]

        for command in ["give thief to thief", "give stiletto to thief", "give vandals to thief"] {
            let transcript = try await play(Zork1(), route + [command, "inventory"], seed: 5)
            #expect(turnOutput(of: command, in: transcript).contains("aren't holding that"))
            #expect(turnOutput(of: "inventory", in: transcript).contains("brass lantern"))
        }
        let gift = try await play(Zork1(), route + ["give lantern to thief", "inventory"], seed: 5)
        #expect(turnOutput(of: "give lantern to thief", in: gift).contains("mocking little bow"))
        #expect(!turnOutput(of: "inventory", in: gift).contains("brass lantern"))
    }

    @Test func theThiefSnatchesTheChaliceBack() async throws {
        // The Treasure Room is the thief's, and he guards the silver chalice.
        // Reaching it pays 25; entering summons him home. The chalice can now be
        // snatched straight from the hoard (the original's grab — no guard, +10
        // on the find), but the thief lifts treasures back from your very hands:
        // a turn later the chalice vanishes into his bag again, the original's
        // snatch-and-resteal. Seed 39 (the prelude's three-blow troll kill lands
        // on this seed): kitchen 10 + cellar 25 + Treasure Room 25 + chalice
        // take 10 = 70; the take award stays even after he steals it back.
        let transcript = try await play(
            Zork1(),
            Zork1MazeTests.toMaze5 + [
                "southwest", "east", "south", "southeast",  // → Cyclops Room
                "odysseus",  // rout the cyclops, opening the stair up
                "up",  // Treasure Room
                "take chalice",  // snatched (+10); the thief lifts it right back
                "score",
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "Treasure Room",
                "silver chalice, intricately engraved",  // the hoard's prize
                "suspicious-looking individual",  // the thief, summoned to defend it
                "Taken.",  // the chalice is snatchable now
                "silver chalice vanished",  // the resteal — back into his bag
                "Your score is 70 of a possible 350",  // +25 lair, +10 chalice (kept)
            ])
    }
}
