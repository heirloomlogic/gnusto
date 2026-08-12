import Foundation
import GnustoTestSupport
import Testing

@testable import Dungeon
@testable import Gnusto

/// The lines *Dungeon* prints that have to be true of where the player is
/// standing — the class of defect the 2026-08-11 play-test round (#233) found
/// thirteen sites of and no test in this suite could have caught.
///
/// Every other Dungeon suite asserts that a line **appears**. That is the wrong
/// question for a value that can change published through a channel that cannot
/// branch: the kitchen window's "not enough to allow entry" appears exactly as
/// it should, to a player who has just climbed through it. So the assertions
/// here are mostly **negative** — the line must *not* appear in the frame it
/// would be false in — paired with a positive control proving the line still
/// prints where it is true. A negative assertion alone passes if the feature is
/// deleted; the pairs are what make these tests mean something.
struct DungeonProseTests {
    // MARK: - Roads

    /// In at the kitchen window.
    private static let intoTheKitchen = ["south", "east", "open window", "west"]

    /// And straight on down through the trap door.
    private static let intoTheCellar = [
        "south", "east", "open window", "west", "west",
        "take lamp", "turn on lamp", "push rug", "open trap door", "down",
    ]

    /// On through the living room and down the trap door, lamp lit and sword in
    /// hand.
    private static let downTheTrapDoor = [
        "west", "take lamp", "take sword", "turn on lamp",
        "push rug", "open trap door", "down",
    ]

    /// The descent with the troll cut down at the end of it. Seed 18 throughout,
    /// as in `DungeonTests`: he falls to the first blow, so the fight is one
    /// command and the transcript is about what it is about.
    private static let pastTheTroll =
        intoTheKitchen + downTheTrapDoor + ["east", "attack troll with sword"]

    /// Troll Room to the dam, the carousel-free road.
    private static let crossroadsToTheDam = [
        "north", "down", "east", "east", "northeast", "up", "east",
    ]

    private static let toTheDam = pastTheTroll + crossroadsToTheDam

    /// Drain the reservoir, cross its bed, climb out through Atlantis — the
    /// northern Mirror Room. Seed 18.
    private static let toTheMirrors =
        pastTheTroll + ["drop sword"] + crossroadsToTheDam
        + ["north", "north", "push yellow button", "take wrench", "south", "south"]
        + ["turn bolt with wrench", "drop wrench", "south", "northwest"]
        + ["north", "north", "north", "up", "north"]

    /// Out through the mirror network to the Shaft Room, up the Wooden Tunnel
    /// and west into the Smelly Room — the Gas Room is one flight below it.
    /// Seed 18.
    private static let toTheSmellyRoom =
        toTheMirrors + ["west", "west", "north", "northeast", "north", "west"]

    /// Into the maze as far as Maze-5, then on to the Cyclops Room. Seed 18.
    private static let toTheCyclops =
        pastTheTroll + ["south", "south", "east", "up"]
        + ["southwest", "east", "south", "northeast"]

    /// The same, with the peppers and the bottle, and the giant asleep on the
    /// drugged water at the end of it — the one way to have a cyclops who is
    /// both subdued and still standing in the room. Seed 18.
    private static let toTheSleepingCyclops =
        intoTheKitchen + ["take bottle", "open sack", "take lunch"]
        + downTheTrapDoor + ["east", "attack troll with sword"]
        + ["south", "south", "east", "up", "southwest", "east", "south", "northeast"]
        + ["give water to cyclops", "give lunch to cyclops", "give water to cyclops"]

    /// Through the wall the shout opens, and up into the thief's Treasure Room.
    /// Arriving is what puts him into play. Seed 18.
    private static let toTheHoard = toTheCyclops + ["odysseus", "up"]

    /// The road to the tea party, and on to the three buttons. Seed 41
    /// throughout, as in `DungeonTests`: the carousel is a lottery until the
    /// triangular button stops it, and this is the draw that lands.
    private static let toTheButtons =
        intoTheKitchen + ["take bottle", "open bottle"] + downTheTrapDoor
        + ["east", "attack troll with sword", "drop sword", "north", "east", "north"]
        + ["southeast", "answer well", "east", "east"]
        + ["board bucket", "pour water in bucket", "get out", "east"]
        + ["northwest", "north"]

    /// Back down the well and out through a Round Room that has stopped
    /// turning, which is the only way to stand in the Winding Passage with the
    /// machinery off.
    private static let buttonsBackToTheRoundRoom = [
        "west", "northwest", "west", "board bucket", "empty bucket", "get out",
        "west", "west", "down", "north",
    ]

    // MARK: - A fuse says its line without asking where the player is standing

    /// The lantern's three rungs fire against a clock, not against the player's
    /// position, so all three used to announce themselves about a lamp two
    /// hundred feet away. The round caught "The lamp appears a bit dimmer." in a
    /// sunlit forest, about a lantern the player had dropped underground and
    /// then died away from.
    ///
    /// The fuel still runs out — that is the half of the fix that is easy to
    /// break — so the burn-out is asserted through the one thing that survives
    /// the silence: the lamp is spent when the player comes back to it.
    @Test func theLanternBurnsDownSilentlyWhereThePlayerCannotSeeIt() async throws {
        let transcript = try await play(
            Dungeon(),
            ["south", "east", "open window", "west", "west"]
                + ["take lamp", "turn on lamp", "drop lamp", "east"]
                + Array(repeating: "wait", count: 360)
                // *lantern*, not *lamp*: `turnOutput` matches the first
                // occurrence, and the route already spent "turn on lamp".
                + ["west", "turn on lantern"],
            seed: 18)

        #expect(!transcript.contains("The lamp appears a bit dimmer"))
        #expect(!transcript.contains("The lamp is nearly out"))
        #expect(!transcript.contains("better have more light than from the brass lantern"))
        // But it did burn out: the lamp is spent when they walk back in on it.
        #expect(turnOutput(of: "turn on lantern", in: transcript).contains("burned-out lamp"))
    }

    /// The control. Held, all three rungs are about something the player is
    /// carrying, and all three still print.
    @Test func theLanternAnnouncesEveryRungToAPlayerHoldingIt() async throws {
        let transcript = try await play(
            Dungeon(),
            ["south", "east", "open window", "west", "west", "take lamp", "turn on lamp"]
                + Array(repeating: "wait", count: 360),
            seed: 18)

        expectInOrder(
            transcript,
            [
                "The lamp appears a bit dimmer.",
                "The lamp is nearly out.",
                "You'd better have more light than from the brass lantern.",
            ])
    }

    /// The same shape in another bundle: `matchBurnsOut` was seen printing "The
    /// match has gone out." in the Forest, two turns after the match that
    /// printed it had blown up the Gas Room and killed the player.
    @Test func aMatchGoesOutSilentlyWhereThePlayerCannotSeeIt() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheDam
                // Dropped before it is struck, and left behind on the very next
                // turn: the flame lasts two, so it dies with a room between
                // them.
                + ["north", "take matchbook", "drop matchbook", "light match", "south"]
                + ["wait", "wait"],
            seed: 18)

        #expect(transcript.contains("Dam Lobby"))
        #expect(transcript.contains("One of the matches starts to burn."))
        #expect(!transcript.contains("The match has gone out."))
    }

    /// The control, one room over: struck and held, the match still reports its
    /// own end.
    @Test func aMatchHeldReportsItsOwnEnd() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheDam + ["north", "take matchbook", "light match", "wait", "wait"],
            seed: 18)

        #expect(transcript.contains("The match has gone out."))
    }

    // MARK: - A static trait asserting a fact that has a state behind it

    /// The kitchen window's description is a claim about `isOpen` — it is the
    /// `via:` door on four exits — so "not enough to allow entry" was being read
    /// to a player standing in the kitchen having just climbed through it.
    @Test func theKitchenWindowDescribesTheStateItIsIn() async throws {
        let transcript = try await play(
            Dungeon(),
            ["south", "east", "x window", "open window", "west", "examine window"],
            seed: 18)

        #expect(
            turnOutput(of: "x window", in: transcript)
                .contains("slightly ajar, but not enough to allow entry"))
        let fromInside = turnOutput(of: "examine window", in: transcript)
        #expect(fromInside.contains("Kitchen") || transcript.contains("Kitchen"))
        #expect(fromInside.contains("stands open, wide enough to climb through"))
        #expect(!fromInside.contains("not enough to allow entry"))
    }

    /// The Winding Passage reports the Round Room's machinery in three places —
    /// its own paragraph, the whirring's examine text, and the refusal on the
    /// north wall — and all three were constants. The triangular button stops
    /// the machinery, and a room that went on whirring afterwards would be
    /// telling the player their own solution had not worked.
    @Test func theWindingPassageStopsReportingAMachineThatHasStopped() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheButtons + ["push triangular button"]
                + Self.buttonsBackToTheRoundRoom
                + ["southeast", "x whirring", "north"],
            seed: 41)

        #expect(transcript.contains("Winding Passage"))
        // The paragraph, the noun and the wall, none of them still whirring.
        #expect(transcript.contains("The rock to the north is quiet now"))
        #expect(
            turnOutput(of: "x whirring", in: transcript)
                .contains("Silence, out of a wall that had a great deal of machinery"))
        #expect(!transcript.contains("a faint whirring — the round room"))
        #expect(!transcript.contains("You hear the whir from the round room"))
        #expect(transcript.contains("there is no way into\nit from this side"))
    }

    /// The control, by the other road in: with the machinery still running all
    /// three lines are true, and all three still print.
    @Test func theWindingPassageStillReportsAMachineThatIsRunning() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheMirrors + ["rub mirror", "west", "x whirring", "north"],
            seed: 18)

        #expect(transcript.contains("Winding Passage"))
        #expect(transcript.contains("a faint whirring — the round room"))
        #expect(
            turnOutput(of: "x whirring", in: transcript)
                .contains("Machinery, by the sound of it"))
        #expect(transcript.contains("You hear the whir from the round room"))
    }

    // MARK: - Examine answering about the wrong place

    /// From the perch, `x tree` used to answer with the view from the ground:
    /// branches "low enough to reach" and "something pale … tucked into a nest
    /// high up among the leaves" — which is the egg, listed beside the player
    /// two lines earlier. Same tree, other end, and now its own line.
    @Test func theTreeFromThePerchIsNotTheTreeFromTheGround() async throws {
        let transcript = try await play(
            Dungeon(),
            ["north", "north", "up", "x tree", "down", "examine tree"],
            seed: 18)

        let aloft = turnOutput(of: "x tree", in: transcript)
        #expect(aloft.contains("The trunk is broad enough up here to lean against"))
        #expect(!aloft.contains("branches low enough to reach"))
        #expect(!aloft.contains("Something pale"))
        // And from the ground it is still the climb and the thing in the nest.
        let below = turnOutput(of: "examine tree", in: transcript)
        #expect(below.contains("branches low enough to reach"))
        #expect(below.contains("Something pale"))
    }

    /// The Rocky Ledge places a passage directly below the player — the main
    /// flow of the falls goes into it and nobody follows — and *passage* was a
    /// synonym on the distant view, which is about the miles of country beyond.
    /// The noun stays answerable; it answers about the right place.
    @Test func theRockyLedgesPassageIsTheOneBelowNotTheOneMilesOff() async throws {
        let transcript = try await play(
            Dungeon(),
            ["south", "east", "east", "southeast", "southeast", "down"]
                + ["x passage", "x falls"],
            seed: 18)

        #expect(transcript.contains("Rocky Ledge"))
        let passage = turnOutput(of: "x passage", in: transcript)
        #expect(passage.contains("It takes the main flow of the falls a little below you"))
        #expect(!passage.contains("Miles of it"))
        // The distant view keeps everything that really is distant.
        #expect(turnOutput(of: "x falls", in: transcript).contains("Miles of it"))
    }

    /// The curtain of light hangs where the Safety Depository's north wall
    /// ought to be — and then follows the player into four rooms that have
    /// north walls of their own, which this bundle maps one by one. It went on
    /// describing a missing north wall in every one of them.
    @Test func theCurtainStopsNamingANorthWallInRoomsThatHaveOne() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.intoTheCellar + ["south", "south", "west"]
                + ["northwest", "west", "x curtain", "walk through curtain", "examine curtain"],
            seed: 41)

        #expect(transcript.contains("Safety Depository"))
        let inDepository = turnOutput(of: "x curtain", in: transcript)
        #expect(inDepository.contains("hanging where the north wall ought to be"))
        let inViewingRoom = turnOutput(of: "examine curtain", in: transcript)
        #expect(inViewingRoom.contains("hanging across one side of the room"))
        #expect(!inViewingRoom.contains("where the north wall ought to be"))
    }

    // MARK: - A listing sentence standing in for an examine text

    /// **"On the ground is a pile of leaves." is the trilogy's `LDESC`** — the
    /// room-listing sentence, and the only thing that tells a player there is
    /// anything here to push — and it was declared as the *examine* text. So
    /// the Clearing listed nothing, and `x leaves` answered a question nobody
    /// asked. `scenery` is kept, so the pile is still unliftable: `scenery`
    /// withholds the engine's stock sentence and never the author's. (#233)
    @Test func theClearingListsItsLeavesAndExamineAnswersAboutThem() async throws {
        let transcript = try await play(
            Dungeon(),
            ["south", "east", "east", "x leaves", "take leaves", "push leaves", "look"],
            seed: 18)

        #expect(transcript.contains("Clearing"))
        // The listing line prints, and goes on printing: nothing in this game
        // touches the leaves, and they are still lying there after the push.
        #expect(transcript.contains("On the ground is a pile of leaves."))
        #expect(
            turnOutput(of: "look", in: transcript)
                .contains("On the ground is a pile of leaves."))
        // Examining answers about the pile instead of repeating where it is.
        let examined = turnOutput(of: "x leaves", in: transcript)
        #expect(examined.contains("Dead leaves, drifted deep"))
        #expect(!examined.contains("On the ground is a pile of leaves."))
        // And the grating puzzle is exactly where it was, pile included.
        #expect(
            turnOutput(of: "push leaves", in: transcript)
                .contains("a grating is revealed"))
        #expect(!turnOutput(of: "take leaves", in: transcript).contains("Taken."))
    }

    /// **The rusty knife called itself "older than anything else you are
    /// carrying"** — false against the elvish sword, and the game stages
    /// exactly that frame: taking the knife with the sword in hand is what
    /// fires the blue pulse. It is false against the coffin, the trident and
    /// the egg too, so the line stopped comparing rather than branching on one
    /// of them. (#233)
    @Test func theRustyKnifeMakesNoClaimAboutWhatElseYouCarry() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.pastTheTroll + ["south", "south", "east", "up"]
                + ["take knife", "x knife", "examine sword"],
            seed: 18)

        // The control: the pairing the game really does have is a mechanic.
        #expect(transcript.contains("your sword gives a single pulse of"))
        let knife = turnOutput(of: "x knife", in: transcript)
        #expect(knife.contains("old past guessing"))
        #expect(!knife.contains("older than anything else you are carrying"))
        // And the sword is still the older thing, and still says so.
        #expect(
            turnOutput(of: "examine sword", in: transcript)
                .contains("old enough to have opinions"))
    }

    // MARK: - A game-wide refusal that is false in the room it prints in

    /// **`fill bottle` succeeded on top of the dam in the same frame that
    /// `drink water` answered "There is nothing here to drink."** The bottle
    /// reads `.waterSource` and the three game-wide defaults did not. Twenty
    /// rooms carry the trait now; there were seven when the round found this.
    /// (#233)
    @Test func theWaterRoomsAnswerTheVerbsThatAreAboutWater() async throws {
        let transcript = try await play(
            Dungeon(), Self.toTheDam + ["drink water", "fill lamp", "dive"], seed: 18)

        #expect(transcript.contains("Flood Control Dam #3"))
        let drank = turnOutput(of: "drink water", in: transcript)
        #expect(drank.contains("It really hit the spot"))
        #expect(!drank.contains("nothing here to drink"))
        // The refusals that are left are about the thing named, not the room —
        // which is what lets one line stand in all 196 of them.
        let filled = turnOutput(of: "fill lamp", in: transcript)
        #expect(filled.contains("not something you could fill"))
        #expect(!filled.contains("no water here to fill it from"))
        let dived = turnOutput(of: "dive", in: transcript)
        #expect(dived.contains("end the expedition rather than advance it"))
        #expect(!dived.contains("nothing here to dive into"))
    }

    /// The control, above ground and dry: all three still refuse, and each is
    /// now a claim its own room cannot make false.
    @Test func aDryRoomStillRefusesTheVerbsThatAreAboutWater() async throws {
        let transcript = try await play(
            Dungeon(),
            ["drink mailbox", "fill mailbox", "pour mailbox", "dive", "swim"],
            seed: 18)

        #expect(
            turnOutput(of: "drink mailbox", in: transcript)
                .contains("not something you could drink"))
        #expect(
            turnOutput(of: "fill mailbox", in: transcript)
                .contains("not something you could fill"))
        #expect(
            turnOutput(of: "pour mailbox", in: transcript)
                .contains("not something you could pour"))
        // `.dive` is `.swim`'s twin and was the one left on the engine's stub.
        // Both are claims about the player now, so both hold here too.
        #expect(
            turnOutput(of: "dive", in: transcript)
                .contains("end the expedition rather than advance it"))
        #expect(
            turnOutput(of: "swim", in: transcript)
                .contains("brief and unrewarding career"))
    }

    /// **And the mechanic the whole shape of that fix was chosen to protect.**
    /// `bottle.before(.fill)` is an *item* rule, so it runs at stage 3 and the
    /// stage-4 action table cannot reach past it — which is why the branch went
    /// into `DungeonSystems.actions` and not into a `world.before`, where it
    /// would have answered first and broken the fill the walkthrough needs.
    @Test func theBottleStillFillsAndStillReportsADryRoom() async throws {
        let transcript = try await play(
            Dungeon(),
            // The bottle starts full, so it has to be emptied before a fill
            // means anything.
            Self.intoTheKitchen + ["take bottle", "open bottle", "pour water"]
                + Self.downTheTrapDoor + ["east", "attack troll with sword"]
                + Self.crossroadsToTheDam
                + ["fill bottle", "north", "pour water", "fill bottle"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "Flood Control Dam #3",
                "The bottle is now full of water.",
                "Dam Lobby",
                "There is no water here to fill it from.",
            ])
    }

    /// **The two rooms in the game named for what they smell of answered
    /// `smell` with "You smell nothing out of the ordinary."** — a
    /// contradiction two lines from the room's own description. The game-wide
    /// default belongs to `DungeonSystems`, so the two rooms take it back at
    /// stage 2 rather than the one line being rewritten for the whole map.
    /// (#233)
    @Test func theTwoRoomsNamedForTheirSmellAnswerSmell() async throws {
        let transcript = try await play(
            Dungeon(), Self.toTheSmellyRoom + ["smell", "down", "sniff"], seed: 18)

        expectInOrder(transcript, ["Smelly Room", "Gas Room"])
        let upstairs = turnOutput(of: "smell", in: transcript)
        #expect(upstairs.contains("comes up the staircase in slow waves"))
        #expect(!upstairs.contains("nothing out of the ordinary"))
        let downstairs = turnOutput(of: "sniff", in: transcript)
        #expect(downstairs.contains("Coal gas, and a great deal of it"))
        #expect(!downstairs.contains("nothing out of the ordinary"))
    }

    /// The control, one room away: somewhere with nothing to smell still says
    /// so — and says it in the game's own voice, which the old line did not.
    /// `Prose.verbSmell` was the engine's stub character for character, so the
    /// row installing it re-voiced nothing while the survey counted it done.
    @Test func aRoomWithNothingToSmellAnswersInTheGamesOwnVoice() async throws {
        let transcript = try await play(
            Dungeon(), Self.toTheSmellyRoom.dropLast() + ["smell"], seed: 18)

        #expect(transcript.contains("Wooden Tunnel"))
        let here = turnOutput(of: "smell", in: transcript)
        #expect(here.contains("Nothing here smells of anything in particular"))
        #expect(!here.contains("nothing out of the ordinary"))
    }

    /// **`x stairs` in the Gas Room — a noun the room's own description prints
    /// — answered with the coal gas's description**, because `coalGas` carried
    /// the synonym. One staircase, two ends, two items: the Rocky Ledge's
    /// repair applied again, and the noun goes to whichever item is about the
    /// right place. (#233)
    @Test func theStaircaseAnswersFromBothOfItsEnds() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheSmellyRoom
                + ["x staircase", "x odor", "down", "examine stairs", "x gas"],
            seed: 18)

        let above = turnOutput(of: "x staircase", in: transcript)
        #expect(above.contains("Narrow steps cut into the rock"))
        #expect(!above.contains("a coal mine ought to know better"))
        // The odor keeps its own noun and its own line.
        #expect(
            turnOutput(of: "x odor", in: transcript)
                .contains("a coal mine ought to know better"))

        let below = turnOutput(of: "examine stairs", in: transcript)
        #expect(below.contains("back up to the room above"))
        #expect(!below.contains("thick enough to lean on"))
        // And so does the gas.
        #expect(turnOutput(of: "x gas", in: transcript).contains("thick enough to lean on"))
        expectEveryNounAnswered(transcript, "the Smelly Room and the Gas Room")
    }

    // MARK: - A stock engine line asserted from somebody who would not say it

    /// **The troll answers for himself.** `greet troll` reached
    /// `GameText.greets` — "The troll nods, and says nothing." — which the
    /// engine documents as a placeholder an actor's own rules are expected to
    /// answer over, and he had none. What replaces it is courteous, because
    /// `V-HELLO` has every villain *bow* and both sources carry it; what the
    /// round (#233) actually filed was the flatness, not the courtesy.
    ///
    /// #236 read it the other way and answered with hostility, on the ground
    /// that a bow is incongruous from something that swings at you every turn.
    /// That was true of this game's troll and not the source's, and #237 made
    /// the two agree — he blocks now, two turns in three, exactly as his listing
    /// line always claimed. So the line names the blocking and keeps the bow.
    /// (#233, #236, #237)
    @Test func theTrollAnswersAGreetingInHisOwnWords() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.intoTheKitchen + Self.downTheTrapDoor + ["east", "greet troll"],
            seed: 18)

        #expect(transcript.contains("Troll Room"))
        let greeting = turnOutput(of: "greet troll", in: transcript)
        #expect(greeting.contains("The troll inclines his head to you"))
        #expect(!greeting.contains("nods, and says nothing"))
    }

    /// And the second state, which is why this is a rule rather than a re-voiced
    /// `GameText` key: a troll battered unconscious cannot answer anybody.
    /// `TROLL-FUNCTION` gates its own `HELLO` branch the same way. Seed 8: the
    /// first blow knocks him down instead of killing him.
    @Test func aTrollOnTheFloorCannotHearAGreeting() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.intoTheKitchen + Self.downTheTrapDoor
                + ["east", "attack troll with sword", "hello troll"],
            seed: 8)

        expectInOrder(
            transcript,
            [
                "The troll is battered into unconsciousness.",
                "The troll is face down in the dirt",
            ])
        #expect(!transcript.contains("The troll inclines his head to you"))
    }

    /// The cyclops had the same gap, and no `HELLO` branch in the source at all
    /// — he falls straight to the villain bow. He has no strike-first branch
    /// either, so of the four he is the one with least claim to a hostile
    /// answer: he never starts anything. Courteous and in no hurry, which from
    /// something waiting to be fed is the worse of the two readings.
    @Test func theCyclopsAnswersAGreetingInHisOwnWords() async throws {
        let transcript = try await play(
            Dungeon(), Self.toTheCyclops + ["greet cyclops"], seed: 18)

        #expect(transcript.contains("Cyclops Room"))
        let greeting = turnOutput(of: "greet cyclops", in: transcript)
        #expect(greeting.contains("The cyclops lowers his head to you"))
        #expect(!greeting.contains("nods, and says nothing"))
    }

    /// His second state: the drugged water leaves him asleep and still in the
    /// room, which is the only frame where a subdued cyclops can be greeted at
    /// all — the shout sends him through the wall and out of scope.
    @Test func theSleepingCyclopsIsLeftAsleep() async throws {
        let transcript = try await play(
            Dungeon(), Self.toTheSleepingCyclops + ["hello cyclops"], seed: 18)

        expectInOrder(
            transcript,
            [
                "falls fast asleep",
                "The cyclops sleeps on.",
            ])
        #expect(!transcript.contains("The cyclops lowers his head to you"))
    }

    /// The thief is the one villain in the game whose courtesy is the point of
    /// him, so his answer keeps it — and keeps the stiletto where his own
    /// description says it is pointing. What it does not keep is the engine's
    /// flat placeholder.
    @Test func theThiefAnswersAGreetingInHisOwnWords() async throws {
        let transcript = try await play(
            Dungeon(), Self.toTheHoard + ["greet thief"], seed: 18)

        #expect(transcript.contains("Treasure Room"))
        let greeting = turnOutput(of: "greet thief", in: transcript)
        #expect(greeting.contains("inclines his head a fraction"))
        #expect(!greeting.contains("nods, and says nothing"))
    }

    /// And the robot, which is the one of the four that is not hostile and still
    /// should not be nodding: it is a machine, and the engine's placeholder had
    /// it nod. It takes orders and it does not converse.
    @Test func theRobotDoesNotNod() async throws {
        let transcript = try await play(
            Dungeon(), Self.toTheButtons.dropLast() + ["greet robot"], seed: 41)

        #expect(transcript.contains("Low Room"))
        let greeting = turnOutput(of: "greet robot", in: transcript)
        #expect(greeting.contains("It was not built to be talked to"))
        #expect(!greeting.contains("nods, and says nothing"))
    }

    // MARK: - A paragraph that names an exit the table does not have

    /// **The wide ledge is east of the shaft, and the paragraph sent the
    /// aviator west.** Inherited rather than introduced: `dung.355` says west in
    /// the prose and files `VAIR4 EAST -> LEDG4` in the exit table, and Zork II
    /// copied the paragraph without the table. The mechanics contract's rule is
    /// that where a description names its exits, the description yields. (#233)
    @Test func theShaftNamesTheSideTheWideLedgeIsActuallyOn() async throws {
        let transcript = try await play(
            Dungeon(), DungeonTests.toTheWideLedge, seed: 18)

        expectInOrder(
            transcript,
            [
                "Volcano Near Wide Ledge",
                // Short of the full sentence: the transcript hard-wraps at
                // seventy columns and "to land on a wide ledge" is on the next
                // line. *east* and *west* are the same width, so the negative
                // below wraps identically and really would fire.
                "To the east, there is a place",
                // The control the negative needs: east is the direction that
                // works, so the corrected line is the true one.
                "Wide Ledge",
            ])
        #expect(!transcript.contains("To the west, there is a place"))
    }

    /// And the control one level down, which is why this is a correction and not
    /// a sweep: `VAIR2` is `identical`, its paragraph says west, and west is
    /// where its ledge is. That one is untouched.
    @Test func theShaftStillNamesTheNarrowLedgeToTheWest() async throws {
        let transcript = try await play(
            Dungeon(), DungeonTests.toTheNarrowLedge, seed: 18)

        expectInOrder(
            transcript,
            [
                "There is a small ledge on the west side.",
                "Narrow Ledge",
            ])
    }

    // MARK: - A noun the prose prints with nothing to answer it

    /// **The Round Room's description is entirely about its passages, and the
    /// parser did not know the word.** Which makes the fix a rule and not a
    /// constant: while the carousel turns, which of the eight goes where is
    /// exactly the thing that will not hold still, and this room was already
    /// repaired once for saying otherwise. (#233)
    @Test func theRoundRoomsPassagesStopBeingALotteryWhenTheFloorDoes() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheButtons + ["push triangular button"]
                + Self.buttonsBackToTheRoundRoom + ["x passages"],
            seed: 41)

        #expect(transcript.contains("Round Room"))
        let stopped = turnOutput(of: "x passages", in: transcript)
        #expect(stopped.contains("standing still\nat last long enough to be counted"))
        #expect(!stopped.contains("no way to tell"))
    }

    /// The control, with the machinery still under the floor: the same eight
    /// mouths of stone, and no telling them apart.
    @Test func theRoundRoomsPassagesAreALotteryWhileTheFloorTurns() async throws {
        let transcript = try await play(
            Dungeon(), Self.pastTheTroll + ["north", "east", "x passages"], seed: 18)

        #expect(transcript.contains("Round Room"))
        let turning = turnOutput(of: "x passages", in: transcript)
        #expect(turning.contains("no way to tell"))
        #expect(!turning.contains("long enough to be counted"))
    }

    // MARK: - A synonym list answering about somewhere else

    /// **The volcano's floor answered with a description of its sky.**
    /// `coneAtBottom` is a line about the shaft "a long way overhead", and it
    /// carried `floor`, `ash`, `walls` and `bottom` — so a player standing in
    /// the ash, on the floor, at the bottom, got told about the daylight four
    /// hundred feet up. The inverse of the defect the round filed, in the same
    /// factory. (#233)
    @Test func theVolcanoFloorIsNotTheShaftOverhead() async throws {
        let transcript = try await play(
            Dungeon(), DungeonTests.toTheVolcano + ["x floor", "x ash", "x cone"], seed: 18)

        #expect(transcript.contains("Volcano Bottom"))
        for near in ["x floor", "x ash"] {
            let answer = turnOutput(of: near, in: transcript)
            #expect(answer.contains("Grey ash, cold and deep enough"))
            #expect(!answer.contains("opens a long way overhead"))
        }
        // The control: the cone really is overhead, and still says so.
        #expect(turnOutput(of: "x cone", in: transcript).contains("opens a long way overhead"))
    }

    /// **From the basket, everything the paragraph pointed at answered "close
    /// enough to touch".** `VAIR2` names the rim looming above, the floor two
    /// hundred feet below and a ledge on the west side, and all three were
    /// synonyms on the bare rock beside the basket. One test for the pattern;
    /// the other three levels are the sweeps' job. (#233)
    @Test func theRockBesideTheBasketIsNotTheRimAboveIt() async throws {
        let transcript = try await play(
            Dungeon(),
            // Three commands and no more: the balloon ascends every third turn
            // and a fourth would be answered from the level above.
            DungeonTests.toTheNarrowLedge.dropLast() + ["x rim", "x ledge", "x walls"],
            seed: 18)

        #expect(transcript.contains("Volcano Near Small Ledge"))
        for far in ["x rim", "x ledge"] {
            let answer = turnOutput(of: far, in: transcript)
            #expect(answer.contains("Two hundred feet of nothing below the basket"))
            #expect(!answer.contains("close enough to touch"))
        }
        // The control: the rock really is close enough to touch.
        #expect(turnOutput(of: "x walls", in: transcript).contains("close enough to touch"))
    }

    /// **The Narrow Ledge is "halfway between the floor below and the rim
    /// above", and both of those answered with the shelf underfoot.** The
    /// ledger's `x rim a shelf of old rock wide enough …` row, which is the one
    /// site of this class the round actually typed. (#233)
    @Test func theNarrowLedgeAnswersForTheFloorBelowAndTheRimAbove() async throws {
        let transcript = try await play(
            Dungeon(),
            // Out of the basket first, or the balloon carries the questioner
            // back into the air two turns later.
            DungeonTests.toTheNarrowLedge + ["get out", "x rim", "x floor", "x ledge"],
            seed: 18)

        #expect(transcript.contains("Narrow Ledge"))
        for far in ["x rim", "x floor"] {
            let answer = turnOutput(of: far, in: transcript)
            #expect(answer.contains("a couple of hundred feet down"))
            #expect(!answer.contains("A shelf of old rock"))
        }
        // The control: the ledge itself is still the shelf you are standing on.
        #expect(turnOutput(of: "x ledge", in: transcript).contains("A shelf of old rock"))
    }

    /// **Volcano View had one scenery item, and it was about the wrong ledges.**
    /// The room names the two shelves across the shaft, the bottom below, the
    /// rim above and "this ledge" underfoot; `volcanoViewLedges` answered for
    /// the first four and nothing answered for the fifth. This one needs the
    /// pair in both directions, because the near thing had no item at all. (#233)
    @Test func volcanoViewAnswersForTheLedgeYouAreOnAndTheOnesAcross() async throws {
        let transcript = try await play(
            Dungeon(),
            // On foot, south out of the Egyptian Room: the one ledge no balloon
            // can land on.
            Self.pastTheTroll + ["north", "down", "west", "northwest", "south", "down"]
                + ["x ledge", "x ledges", "x rim", "x bottom"],
            seed: 18)

        #expect(transcript.contains("Volcano View"))
        // Near: the shelf under your boots, which nothing used to answer for.
        let here = turnOutput(of: "x ledge", in: transcript)
        #expect(here.contains("A shelf of stone about halfway up"))
        #expect(!here.contains("Two shelves of rock stand out"))
        // Far: the pair across the shaft, and the rim and floor beyond them.
        for far in ["x ledges", "x rim", "x bottom"] {
            let answer = turnOutput(of: far, in: transcript)
            #expect(answer.contains("Two shelves of rock stand out"))
            #expect(!answer.contains("A shelf of stone about halfway up"))
        }
    }

    /// **The Wide Ledge's rim is two hundred feet up and its drop goes further
    /// than that down, and both answered with the apron underfoot.** The issue's
    /// named site: `synonyms("ledge", "rock", "volcano", "rim", "drop",
    /// "bottom", "door")` against one description of the rock. (#233)
    @Test func theWideLedgesRimAndDropAreNotTheRockUnderfoot() async throws {
        let transcript = try await play(
            Dungeon(),
            DungeonTests.toTheWideLedge + ["get out", "x rim", "x drop", "x bottom", "x ledge"],
            seed: 18)

        #expect(transcript.contains("Wide Ledge"))
        for far in ["x rim", "x drop", "x bottom"] {
            let answer = turnOutput(of: far, in: transcript)
            #expect(answer.contains("Two hundred feet of rock stand between"))
            #expect(!answer.contains("A broad apron of rock"))
        }
        // The control: the apron is still the apron — and no longer claims a
        // doorway it cannot check.
        let near = turnOutput(of: "x ledge", in: transcript)
        #expect(near.contains("A broad apron of rock"))
        #expect(!near.contains("doorway cut into the wall"))
    }

    /// **The small door went on being a door after the blast buried it.** It was
    /// a clause inside the description of the rock underfoot, which is a
    /// constant, while the room's own paragraph next to it branched on
    /// `dustyRoomWrecked` from the day it was written. Rule 3 dissolving a rule
    /// 1 problem: the doorway is the state, so the doorway became the item. (#233)
    @Test func theSmallDoorBecomesRubbleWhenTheRoomComesDown() async throws {
        let transcript = try await play(
            Dungeon(),
            DungeonTests.toTheWideLedge + ["x door"] + DungeonTests.lightTheCharge
                // Five turns after the blast the Dusty Room comes down, and the
                // ledge follows it eight after that. Ask in the window between.
                + ["south", "take crown", "take card", "north", "read card", "look"]
                + ["examine door"],
            seed: 18)

        let before = turnOutput(of: "x door", in: transcript)
        #expect(before.contains("A low door cut square into the south wall"))
        #expect(!before.contains("only the rubble the blast brought down"))

        let after = turnOutput(of: "examine door", in: transcript)
        #expect(after.contains("only the rubble the blast brought down"))
        #expect(!after.contains("A low door cut square into the south wall"))
        // The control the two halves hang on: the room's paragraph agrees, and
        // always did.
        expectInOrder(
            transcript,
            ["There is a small door to the south.", "The way to the south is blocked by rubble."])
    }

    /// **Paid on the Wide Ledge, the gnome's door and the small door are two
    /// doors, and the parser is allowed to ask which.** Not a defect to be
    /// tidied away by deleting a synonym: ``Prose/gnomePaid(_:)`` is
    /// trilogy-verbatim and hands the player the word *door* for the chimney,
    /// and the room's own paragraph hands them the word for the one south. The
    /// question costs no turn, and both are resolvable by adjective. (#233)
    @Test func theTwoDoorsOnTheWideLedgeAreTwoDoors() async throws {
        let transcript = try await play(
            Dungeon(),
            // Moor at the Narrow Ledge for the zorkmid, then carry it up: the
            // gnome comes to whichever ledge you are standing on, and the
            // Wide Ledge is the only one with a door of its own.
            DungeonTests.toTheNarrowLedge
                + ["tie braided wire to hook", "get out", "take coin", "board basket"]
                + ["untie braided wire"] + Array(repeating: "wait", count: 8)
                + ["east", "get out"] + Array(repeating: "wait", count: 16)
                + ["give coin to gnome", "x door", "x south door", "x west door"],
            seed: 18)

        #expect(transcript.contains("a door appears"))
        // The bare noun asks, because there really are two.
        #expect(turnOutput(of: "x door", in: transcript).contains("Which do you mean"))
        // And both halves of the question answer for themselves.
        #expect(
            turnOutput(of: "x south door", in: transcript)
                .contains("A low door cut square into the south wall"))
        #expect(
            turnOutput(of: "x west door", in: transcript)
                .contains("A chimney of rock, barely wide enough for one"))
    }
}
