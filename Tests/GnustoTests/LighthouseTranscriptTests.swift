import Foundation
import GnustoTestSupport
import Testing

@testable import Gnusto
@testable import Lighthouse

/// End-to-end playthroughs of *The Lighthouse*, the feature-tour example. Each
/// test drives one idiom the game exists to demonstrate — the full winning
/// route, then the locked door, the container, the dark lamp room, the
/// cross-bundle fuel gate, the lamp fuse, the tide daemon, the keeper (actor +
/// custom verb + `@Global`), and save/restore.
///
/// The second half of the suite is the play-test round of 2026-07-30, pinned:
/// one test per line that used to print in a frame it wasn't true of.
struct LighthouseTranscriptTests {
    /// Off the jetty, through the locked door, and standing over an open chest.
    /// Every test past the first three gates starts here, so the route is
    /// written once — a game whose copy is under active revision should not
    /// need a fourteen-site edit to change one command.
    static let toTheOpenChest = [
        "north", "take key", "unlock door with key", "open door", "east", "open chest",
    ]

    /// And on up to the beacon, carrying a lit lamp. The `take can` is
    /// deliberately not here: half the tests that climb want the can and half
    /// are checking what happens without it.
    static let toTheLampRoomWithLamp =
        toTheOpenChest + ["take lamp", "light lamp", "west", "up"]

    /// The whole game, start to scored win: key off the shelf, through the
    /// locked door, oil and lamp from the chest, up the dark stairs, beacon
    /// relit. Seeded so the keeper's roaming is reproducible.
    @Test func winningPath() async throws {
        let transcript = try await play(
            Lighthouse(),
            Self.toTheOpenChest + ["take lamp", "take can", "light lamp", "west", "up", "light beacon"],
            seed: 0)

        expectInOrder(
            transcript,
            [
                "The keeper's boat brought you out",
                "The Lighthouse",
                "The tide is low, the planks dry underfoot.",
                "Base of the Lighthouse",
                "On the stone shelf is a brass key.",
                "Unlocked.",
                "Opened.",
                "Storeroom",
                "Opening the heavy chest reveals an oil can and an oil lamp.",
                "The oil lamp is now on.",
                "Lamp Room",
                "comes up roaring",
                "Your score is 25 of a possible 25",
            ])
    }

    /// Doors and locks: the storeroom door refuses to open, and reads as closed
    /// on a walk-through, until the brass key unlocks it.
    @Test func lockedDoorRefusesUntilUnlocked() async throws {
        let transcript = try await play(
            Lighthouse(),
            [
                "north", "open door", "east", "take key",
                "unlock door with key", "open door", "east",
            ])

        expectInOrder(
            transcript,
            [
                "> open door", "The storeroom door is locked.",
                "> east", "The storeroom door is closed.",
                "> unlock door with key", "Unlocked.",
                "> open door", "Opened.",
                "Storeroom",
            ])
    }

    /// Containers: the chest starts closed (its contents unreachable) and opening
    /// it reveals and yields the lamp and the oil.
    @Test func chestStartsClosedThenYieldsContents() async throws {
        let transcript = try await play(
            Lighthouse(),
            ["north", "take key", "unlock door with key", "open door", "east"]
                + ["look in chest", "open chest", "take lamp", "take can"])

        expectInOrder(
            transcript,
            [
                "The heavy chest is closed.",
                "Opening the heavy chest reveals an oil can and an oil lamp.",
                "Taken.",
                "Taken.",
            ])
    }

    /// Darkness: the Lamp Room has no light of its own — the beacon in it is out
    /// — so climbing the stairs without a lit lamp reaches the room and sees
    /// nothing. This is what makes the portable light load-bearing rather than
    /// scenery, per the game's mechanics contract.
    @Test func theLampRoomIsDarkWithoutTheLamp() async throws {
        let transcript = try await play(Lighthouse(), ["north", "up"])

        expectInOrder(transcript, ["> up", "It is pitch black. You can't see a thing."])
    }

    /// The cross-bundle seam: the beacon belongs to the `Tower` bundle, the oil
    /// belongs to the host, and the winning rule is the host's because it checks
    /// for one while acting on the other. Reaching the beacon with a lit lamp and
    /// no oil can is refused, and the refusal names what it wants.
    @Test func theBeaconRefusesToLightWithoutTheOil() async throws {
        let transcript = try await play(
            Lighthouse(),
            Self.toTheLampRoomWithLamp + ["light beacon"])

        expectInOrder(
            transcript,
            [
                "Lamp Room",
                "the reservoir is\ndry. You'll want the oil can in hand",
            ])
        #expect(!transcript.contains("comes up roaring"))
    }

    /// A fuse: a lit lamp burns down — a warning flicker, then out — and
    /// relighting it restarts the burn from full.
    @Test func lampBurnsDownAndRelights() async throws {
        let transcript = try await play(
            Lighthouse(),
            Self.toTheOpenChest + ["take lamp", "light lamp"]
                // Burn down: flicker at 6 turns, out at 9.
                + Array(repeating: "wait", count: 9)
                // Relight, and burn again to the flicker.
                + ["light lamp"] + Array(repeating: "wait", count: 6))

        expectInOrder(
            transcript,
            [
                "The oil lamp is now on.",
                "The oil lamp's flame sinks to a sullen flicker.",
                "The oil lamp gutters, and goes out.",
                "The oil lamp is now on.",
                "The oil lamp's flame sinks to a sullen flicker.",
            ])
    }

    /// A daemon: the tide rises every turn and, on the jetty, warns and then
    /// floods — killing a player who lingers.
    @Test func risingTideWarnsThenFloods() async throws {
        let transcript = try await play(
            Lighthouse(),
            ["wait", "wait", "wait", "wait"])

        expectInOrder(
            transcript,
            [
                "Cold water sluices between the planks of the jetty.",
                "The sea is at your ankles",
                "takes you\nwith it — without malice",
                "*** You have died ***",
            ])
    }

    /// An actor, a custom verb, and `@Global` state: the keeper answers when
    /// talked to, and her one-time briefing (tracked by `keeperGreeted`) gives
    /// way to a shorter reminder.
    @Test func keeperBriefsOnceThenReminds() async throws {
        // Seeded so the keeper stays in the base across both turns (her roaming
        // could otherwise carry her off before the second question).
        let transcript = try await play(
            Lighthouse(),
            ["north", "talk to keeper", "talk to keeper"],
            seed: 3)

        expectInOrder(
            transcript,
            [
                "The old keeper is here, her weight on the good leg",
                "Storm took the light",
                "patient as tide",
            ])
    }

    /// The jetty is a three-turn room, and `.talk` is answered by a rule on the
    /// keeper and by nothing else. Talking to yourself there used to spend all
    /// three turns while insisting the parser had failed — the first play-test
    /// round's drowning. Nothing answers the command, so nothing happens: the
    /// tide does not move.
    @Test func talkingToNobodyOnTheJettyCostsNoTurn() async throws {
        let transcript = try await play(
            Lighthouse(),
            ["talk to me", "talk to me", "talk to me", "score"],
            seed: 0)

        #expect(transcript.contains("You can't do that."))
        #expect(!transcript.contains("I didn't understand that sentence."))
        // The tide never gets a turn to rise in, so it never gets to drown you.
        #expect(!transcript.contains("Cold water sluices between the planks of the jetty."))
        #expect(!transcript.contains("takes you\nwith it"))
        #expect(turnOutput(of: "score", in: transcript).contains("in 0 turns."))
    }

    /// Save and restore round-trip the whole world: the brass key, dropped after
    /// saving, is back in hand once the save is restored.
    @Test func saveAndRestoreRoundTrip() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("lighthouse-\(UUID().uuidString).sav").path
        defer { try? FileManager.default.removeItem(atPath: path) }

        let transcript = try await play(
            Lighthouse(),
            [
                "north", "take key", "save", path,
                "drop key", "inventory",
                "restore", path, "inventory",
            ])

        expectInOrder(
            transcript,
            [
                "Save to what file?", "Saved.",
                "Dropped.", "You are empty-handed.",
                "Restore from what file?", "Restored.",
                "You are carrying a brass key",
            ])
    }

    // MARK: - Lines that used to print in a frame they weren't true of (#91)

    /// The shelf used to carry a `firstSight` announcing the key, and a listing
    /// line runs until its own item is touched — nothing ever touches a shelf.
    /// So the base went on saying a key lay there after it was pocketed, and
    /// said it twice on the first visit, once over the engine's own surface
    /// listing. The engine's line is the only one now, and it stops with the key.
    @Test func theShelfStopsAnnouncingTheKeyOnceItIsTaken() async throws {
        let transcript = try await play(Lighthouse(), ["north", "take key", "look"])

        #expect(turnOutput(of: "north", in: transcript).contains("On the stone shelf is a brass key."))
        #expect(!turnOutput(of: "look", in: transcript).contains("brass key"))
        // And it was announced exactly once on the way in, not twice.
        #expect(!transcript.contains("A brass key lies on the stone shelf"))
    }

    /// `ActorBehaviors.roams` prints one departure line for the whole room set,
    /// and the keeper's set is two rooms stacked one above the other. The old
    /// line said she limped away *up* the stairs — printed at the top of the
    /// tower, whose only exit is down. Both lines name the stairs now and
    /// neither names a direction.
    @Test func theKeepersStairLinesNameNoDirection() async throws {
        let transcript = try await play(
            Lighthouse(),
            Self.toTheLampRoomWithLamp + ["wait", "wait", "wait"],
            seed: 0)

        // She is watched leaving the top of the tower, where "up the stairs"
        // would have been a lie.
        expectInOrder(
            transcript,
            ["Lamp Room", "The keeper takes to the stairs, both hands to the rail"])
        #expect(!transcript.contains("up the stairs"))
        // Not a direction, but the other half of the old pair — pinned so a
        // revert of either string fails here rather than in a play-test round.
        #expect(!transcript.contains("climbs stiffly"))
    }

    /// Both lamp fuses used to narrate a flame nobody could see. The state
    /// change stays unconditional — the lamp really does go out on turn nine,
    /// wherever it is — but the prose now checks that the player could watch it.
    @Test func theLampBurnsDownQuietlyWhenYouCannotSeeIt() async throws {
        let transcript = try await play(
            Lighthouse(),
            Self.toTheOpenChest
                + ["take lamp", "light lamp", "drop lamp", "west", "close door"]
                // Both fuses fire while the lamp is behind a shut door.
                + Array(repeating: "wait", count: 9)
                // And it really did go out: it takes a light to say so.
                + ["open door", "east", "take lamp", "light lamp"])

        #expect(!transcript.contains("sinks to a sullen flicker"))
        #expect(!transcript.contains("gutters, and goes out"))
        #expect(turnOutput(of: "light lamp", in: transcript).contains("The oil lamp is now on."))
    }

    /// The other half of the same guard, and the half that is easy to get wrong:
    /// `turn on` needs reach and not possession, so `open chest` / `light lamp`
    /// leaves the lamp burning in the chest with the player standing over it.
    /// Both lines are true of that frame and both have to print.
    @Test func theLampBurnsDownAloudWhenItIsLitWhereItLies() async throws {
        let transcript = try await play(
            Lighthouse(),
            Self.toTheOpenChest + ["light lamp"] + Array(repeating: "wait", count: 9))

        expectInOrder(
            transcript,
            [
                "The oil lamp is now on.",
                "The oil lamp's flame sinks to a sullen flicker.",
                "The oil lamp gutters, and goes out.",
            ])
    }

    /// A lamp put down on the shelf is as watchable as a lamp in the chest. The
    /// guard used to be hand-rolled as `isOpen && holds(_:)` over the room's
    /// contents, and a `surface` is not a `container` and so is never open — so
    /// the lamp on the shelf burned down in silence (#118).
    @Test func theLampBurnsDownAloudWhereItRestsOnTheShelf() async throws {
        let transcript = try await play(
            Lighthouse(),
            Self.toTheOpenChest
                + ["take lamp", "light lamp", "west", "put lamp on shelf"]
                + Array(repeating: "wait", count: 9),
            seed: 0)

        expectInOrder(
            transcript,
            [
                "The oil lamp's flame sinks to a sullen flicker.",
                "The oil lamp gutters, and goes out.",
            ])
    }

    /// The one line the player most needs is the one that puts out the light
    /// that would let them read it. `lampDies` asks whether the lamp is in sight
    /// *before* it extinguishes it, so going out in the dark lamp room still
    /// says so instead of dropping the player into an unexplained blackout.
    @Test func theLampSaysItWentOutEvenAsThatLeavesYouInTheDark() async throws {
        let transcript = try await play(
            Lighthouse(),
            Self.toTheLampRoomWithLamp + ["drop lamp"]
                + Array(repeating: "wait", count: 9) + ["look"],
            seed: 0)

        expectInOrder(
            transcript,
            [
                "The oil lamp gutters, and goes out.",
                // And it really was the only light in the room, so asking after
                // the fact is the only way the player would ever have found out.
                "It is pitch black. You can't see a thing.",
            ])
    }

    /// The storeroom's description says the sea chest sits against the far wall.
    /// A takeable chest let the player carry that sentence out of the room — and
    /// a chest with a floor listing on top of the description announced itself
    /// twice, the way the shelf used to announce the key twice.
    @Test func theChestWillNotBeCarriedOut() async throws {
        let transcript = try await play(
            Lighthouse(),
            ["north", "take key", "unlock door with key", "open door", "east"]
                + ["take chest", "open chest"])

        #expect(turnOutput(of: "take chest", in: transcript).contains("going nowhere"))
        #expect(!transcript.contains("> take chest\nTaken."))

        let arrival = turnOutput(of: "east", in: transcript)
        #expect(arrival.contains("the sea chest sits against the far wall"))
        #expect(!arrival.contains("There is a heavy chest here."))
        // Opening it still lists what is inside.
        #expect(
            turnOutput(of: "open chest", in: transcript)
                .contains("Opening the heavy chest reveals an oil can and an oil lamp."))
    }

    // MARK: - The fuel gate and the lit beacon (#94, #95)

    /// The gate is "the can is in your hands", and the refusal used to send the
    /// player to the storeroom for a can they had just set down at their feet.
    @Test func theFuelGateNamesYourHandsNotTheStoreroom() async throws {
        let transcript = try await play(
            Lighthouse(),
            Self.toTheOpenChest
                + ["take lamp", "take can", "light lamp", "west", "up"]
                + ["drop can", "light beacon"],
            seed: 0)

        let refusal = turnOutput(of: "light beacon", in: transcript)
        #expect(refusal.contains("You'll want the oil can in hand"))
        #expect(!refusal.contains("storeroom"))
        #expect(!refusal.contains("downstairs"))
    }

    /// The winning rule used to end the game without ever setting `isLit`, so
    /// the lit half of the beacon's `describe` was prose nothing could reach and
    /// a save taken on the winning move restored a dark lighthouse. Not
    /// observable from a transcript — the game is over — so this drives the
    /// world directly, the way `TestingYourGame.md` says to.
    @Test func theBeaconIsLitWhenTheGameEnds() async throws {
        let world = try cachedWorld(Lighthouse(), seed: 0)
        let io = ScriptedIOHandler(
            lines: Self.toTheOpenChest
                + ["take lamp", "take can", "light lamp", "west", "up", "light beacon"])
        await REPL(world: world, io: io).run()

        #expect(io.transcript.contains("comes up roaring"))
        #expect(await world.state.litItems.contains(EntityID("Tower.beacon")))
    }

    // MARK: - Every noun the rooms print (#92)

    /// The jetty names a boat, a mooring, planks and the sea, and used to know
    /// none of them. Four short visits rather than one walk, because the tide
    /// allows three turns and no more.
    @Test func theJettyAnswersToItsOwnDescription() async throws {
        for probe in [
            ["x boat", "x mooring", "x sea"],
            ["x water", "x tide", "x planks"],
            ["x boards", "x footings", "x jetty"],
            ["x lighthouse", "x tower", "x ebb"],
        ] {
            let transcript = try await play(Lighthouse(), probe, seed: 0)
            expectEveryNounAnswered(transcript, "\(probe)")
        }
    }

    /// The base and the storeroom, and the parts the items' own descriptions
    /// name — the key's teeth, the lamp's wick, the chest's mended clasp.
    @Test func theBaseAndStoreroomAnswerToTheirOwnDescriptions() async throws {
        let transcript = try await play(
            Lighthouse(),
            [
                "north",
                "x stairs", "x treads", "x rail", "x wall", "x stone",
                "x lighthouse", "x tower", "x shelf", "x storeroom", "x door",
                "take key", "x key", "x teeth",
                "unlock door with key", "open door", "east",
                "x rope", "x coils", "x pegs", "x tar", "x brine", "x stores",
                "x chest", "x clasp", "x wire",
                "open chest", "x lamp", "x wick", "x can", "x oil", "x handle",
            ],
            seed: 0)

        expectEveryNounAnswered(transcript)
    }

    /// And the Lamp Room, which needs a light before it can be asked anything.
    /// Two visits, because the lamp holds nine turns at a time.
    @Test func theLampRoomAnswersToItsOwnDescription() async throws {
        let route = Self.toTheOpenChest + ["take lamp", "west", "up", "light lamp"]
        for probe in [
            ["x glass", "x panes", "x window", "x night", "x sky"],
            ["x stairs", "x beacon", "x carriage", "x reservoir", "x ring", "x beam"],
        ] {
            let transcript = try await play(Lighthouse(), route + probe, seed: 0)
            expectEveryNounAnswered(transcript, "\(probe)")
        }
    }

    /// The keeper's own lines name her leg, and she is the only person here.
    ///
    /// Seeded, and this is the one noun walk that has to be: she is a roaming
    /// actor, so three questions in a row need three turns of her staying put.
    /// At seed 3 — the seed the briefing test uses — she takes the stairs before
    /// the last one, and the answer is a truthful *You can't see any such thing*
    /// rather than a vocabulary gap.
    @Test func theKeeperAnswersToHerselfAndHerLeg() async throws {
        let transcript = try await play(
            Lighthouse(), ["north", "x keeper", "x leg", "x woman"], seed: 22)

        expectEveryNounAnswered(transcript)
        #expect(turnOutput(of: "x keeper", in: transcript).contains("Small, weathered"))
        #expect(turnOutput(of: "x leg", in: transcript).contains("Small, weathered"))
    }

    // MARK: - Stub verbs this game contradicts (#93)

    /// `pour` and `empty` assert the can is empty; the can's own description
    /// calls it heavy with lamp oil and the winning move pours it out.
    @Test func pouringTheCanTheGameCallsFull() async throws {
        let transcript = try await play(
            Lighthouse(),
            Self.toTheOpenChest + ["x can", "pour can", "empty can"])

        #expect(turnOutput(of: "x can", in: transcript).contains("heavy with lamp oil"))
        #expect(!transcript.contains("There's nothing in the oil can to pour."))
        #expect(!transcript.contains("There's nothing in the oil can to empty out."))
        #expect(turnOutput(of: "pour can", in: transcript).contains("one place to go tonight"))
    }

    /// `burn lamp` denied a capability `light lamp` grants on the next turn, and
    /// `burn beacon` is the winning move spelled with the other verb.
    @Test func burnAndLightAgreeAboutTheLampAndTheBeacon() async throws {
        let transcript = try await play(
            Lighthouse(),
            Self.toTheOpenChest
                + ["take lamp", "burn lamp", "light lamp", "west", "up", "burn beacon"],
            seed: 0)

        #expect(!transcript.contains("You have no way to set fire to"))
        expectInOrder(
            transcript,
            [
                "> burn lamp", "That is what it is for. Light it.",
                "> light lamp", "The oil lamp is now on.",
                "> burn beacon", "That is the whole idea. Light it.",
            ])
    }

    /// `swim` and `dive` denied the sea in the one room whose describe rule and
    /// whose daemon are both narrating it rising.
    @Test func theSeaIsThereWhenYouTryToSwimInIt() async throws {
        let transcript = try await play(Lighthouse(), ["swim", "dive"])

        #expect(!transcript.contains("There's nothing here to swim in."))
        #expect(!transcript.contains("There's nothing here to dive into."))
        #expect(turnOutput(of: "swim", in: transcript).contains("The sea is right there"))
    }
}
