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

    /// Troll Room to the North-South Passage and northeast into the din.
    private static let crossroadsToTheLoudRoom = [
        "north", "down", "east", "east", "northeast",
    ]

    /// Troll Room to the dam, the carousel-free road.
    private static let crossroadsToTheDam = crossroadsToTheLoudRoom + ["up", "east"]

    private static let toTheLoudRoom = pastTheTroll + crossroadsToTheLoudRoom

    private static let toTheDam = pastTheTroll + crossroadsToTheDam

    /// Open the sluice gates and come back to Reservoir South, at the edge of a
    /// bed that is standable only while they are open — both ways onto it are
    /// gated on `gatesOpen`. Seed 18.
    private static let toTheReservoirShore =
        pastTheTroll + ["drop sword"] + crossroadsToTheDam + drainTheReservoir

    /// On across the bed and out through Atlantis — the northern Mirror Room.
    /// Seed 18.
    private static let toTheMirrors =
        toTheReservoirShore + ["north", "north", "north", "up", "north"]

    /// From the top of the dam: charge the panel, open the gates, and come back
    /// down to the drained bed. The one leg two roads in this file share.
    private static let drainTheReservoir =
        ["north", "north", "push yellow button", "take wrench", "south", "south"]
        + ["turn bolt with wrench", "drop wrench", "south", "northwest"]

    /// Out through the mirror network to the Shaft Room, up the Wooden Tunnel
    /// and west into the Smelly Room — the Gas Room is one flight below it.
    /// Seed 18.
    private static let toTheSmellyRoom =
        toTheMirrors + ["west", "west", "north", "northeast", "north", "west"]

    /// Into the maze as far as Maze-5, where the skeleton's keys are. Seed 18.
    private static let toMazeFive = pastTheTroll + ["south", "south", "east", "up"]

    /// And on from Maze-5 to the Cyclops Room. Seed 18.
    private static let toTheCyclops = toMazeFive + ["southwest", "east", "south", "northeast"]

    /// Maze-5 to the Grating Room with the keys that turn its lock. Seed 18.
    private static let toTheGratingRoom =
        toMazeFive + ["take keys"] + DungeonTests.mazeFiveToTheGrating

    /// The same, with the peppers and the bottle, and the giant asleep on the
    /// drugged water at the end of it — the one way to have a cyclops who is
    /// both subdued and still standing in the room. Seed 18.
    private static let toTheSleepingCyclops =
        intoTheKitchen + ["take bottle", "open sack", "take lunch"]
        + downTheTrapDoor + ["east", "attack troll with sword"]
        + ["south", "south", "east", "up", "southwest", "east", "south", "northeast"]
        + ["give water to cyclops", "give lunch to cyclops", "give water to cyclops"]

    /// The Wide Ledge with the basket gone: stepping out of an untied balloon
    /// strands the player and lets it climb away, which is what starts the
    /// gnome's ten-turn clock and what makes the wreck something this room
    /// watches rather than hears. Seed 18.
    private static let strandedOnTheWideLedge = DungeonTests.toTheWideLedge + ["get out"]

    /// Through the wall the shout opens, and up into the thief's Treasure Room.
    /// Arriving is what puts him into play. Seed 18.
    private static let toTheHoard = toTheCyclops + ["odysseus", "up"]

    /// The same road from the Troll Room on, for a test that has to reach him
    /// with a different prefix — the troll takes three blows at seed 1.
    private static let trollRoomToTheHoard = Array(toTheHoard.dropFirst(pastTheTroll.count))

    /// The road up the well, stopping on the lip of it. Seed 41 throughout, as
    /// in `DungeonTests`: the carousel is a lottery until the triangular button
    /// stops it, and this is the draw that lands.
    private static let toTheTopOfWell =
        intoTheKitchen + ["take bottle", "open bottle"] + downTheTrapDoor
        + ["east", "attack troll with sword", "drop sword", "north", "east", "north"]
        + ["southeast", "answer well", "east", "east"]
        + ["board bucket", "pour water in bucket", "get out"]

    /// And on east into the tea party. Seed 41.
    private static let toTheTeaRoom = toTheTopOfWell + ["east"]

    /// And on to the three buttons. Seed 41.
    private static let toTheButtons = toTheTeaRoom + ["northwest", "north"]

    /// Out to Rocky Shore on foot, by the Loud Room's east door. Seed 18.
    private static let toRockyShore = toTheLoudRoom + ["east", "east", "south"]

    /// Above ground, out to the lip of the Great Canyon. The forest west and
    /// south of this square is the wood the player has just walked out of.
    private static let toCanyonView = ["south", "east", "east", "southeast", "southeast"]

    /// And down the canyon and north along the water to the far end of the
    /// rainbow, which is the one room the rainbow was answering for everything
    /// in.
    private static let toEndOfRainbow = toCanyonView + ["down", "down", "north"]

    /// The whole road to the water with the shovel in hand: past the troll, out
    /// to the Small Cave and back, over the dam, and off the bank in the magic
    /// boat. Seed 18.
    private static let afloatWithTheShovel =
        pastTheTroll + ["drop sword"] + crossroadsToTheLoudRoom
        + ["east", "east", "take shovel", "northwest", "south", "up", "east"]
        + drainTheReservoir
        + ["north", "north", "take pump", "south", "south", "up", "east", "down"]
        + ["inflate plastic with pump", "board boat", "launch"]

    /// East off the third stretch onto the northern White Cliffs beach.
    private static let toTheWhiteCliffs = afloatWithTheShovel + ["down", "down", "east"]

    /// West off the fourth onto the sand, which is the only beach in the game
    /// worth digging.
    private static let toTheSandyBeach = afloatWithTheShovel + ["down", "down", "down", "west"]

    /// And south along the west bank to the lip of the falls, out of the boat.
    private static let toAragainFalls = toTheSandyBeach + ["south", "south", "get out"]

    /// Back down the well and out through a Round Room that has stopped
    /// turning, which is the only way to stand in the Winding Passage with the
    /// machinery off.
    private static let buttonsBackToTheRoundRoom = [
        "west", "northwest", "west", "board bucket", "empty bucket", "get out",
        "west", "west", "down", "north",
    ]

    /// Into the Bank on the crawlway road and through to the Safety
    /// Depository, the room whose `wall` and `walls` are two answers. Seed 41.
    private static let toTheDepository =
        intoTheCellar + ["south", "south", "west", "northwest", "west"]

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

    /// Behind House ends its paragraph on the window, as `EAST-HOUSE` does in
    /// both sources, and the game had only the shut half of that sentence. (#233)
    @Test func behindHouseSaysWhetherTheWindowIsOpen() async throws {
        let transcript = try await play(
            Dungeon(),
            ["south", "east", "look", "open window", "l"],
            seed: 18)

        let shut = turnOutput(of: "look", in: transcript)
        #expect(shut.contains("small window"))
        #expect(shut.contains("which is slightly ajar"))
        #expect(!shut.contains("which is open"))
        let open = turnOutput(of: "l", in: transcript)
        #expect(open.contains("which is open"))
        #expect(!open.contains("slightly ajar"))
    }

    /// And the Kitchen's, which is the frame the round caught: standing inside,
    /// having climbed through, being told the window is not open enough to
    /// climb through. (#233)
    @Test func theKitchenSaysWhetherTheWindowIsOpen() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.intoTheKitchen + ["look", "close window", "l"],
            seed: 18)

        let open = turnOutput(of: "look", in: transcript)
        #expect(open.contains("a small window"))
        #expect(open.contains("which is open"))
        #expect(!open.contains("slightly ajar"))
        let shut = turnOutput(of: "l", in: transcript)
        #expect(shut.contains("which is slightly ajar"))
        #expect(!shut.contains("which is open"))
    }

    // MARK: - A way through that answers as one

    /// The front entrance of the whole game. `enter window` answered the
    /// engine's "You can't get into that." one turn after the window's own
    /// examine text promised a gap wide enough to climb through, because
    /// `.board` knew about vehicles and not about doors. (#233)
    @Test func theKitchenWindowIsAWayThroughInEverySpelling() async throws {
        let transcript = try await play(
            Dungeon(),
            [
                "south", "east", "enter window", "west", "open window",
                "enter window", "go through window", "climb through window",
            ],
            seed: 18)

        // Shut, the window answers the sentence the direction answers.
        let refused = turnOutput(of: "enter window", in: transcript)
        #expect(refused.contains("The kitchen window is closed."))
        #expect(!refused.contains("You can't get into"))
        #expect(turnOutput(of: "west", in: transcript).contains("The kitchen window is closed."))

        // Open, every spelling of the walk is the walk.
        expectInOrder(
            transcript,
            [
                "> open window", "Opened.",
                "> enter window", "Kitchen",
                "> go through window", "Behind House",
                "> climb through window", "Kitchen",
            ])
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
        #expect(transcript.contains("there is no way into it from this side"))
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

    /// The same defect twice more, on one branch. `NEST`'s `FDESC` — "Beside
    /// you on the branch is a small bird's nest." — and `EGG`'s long paragraph
    /// are both **listing** lines in `1dungeon.zil`, and both were declared as
    /// the examine text. So Up a Tree named no nest at all, and then a stock
    /// "On the birds nest is a jewel-encrusted egg." spoke about a thing the
    /// room had never mentioned; and `x egg` told a player holding the egg that
    /// it was still in the nest they had just emptied.
    @Test func upATreeListsTheNestAndTheEggAndExamineAnswersAboutThem() async throws {
        let transcript = try await play(
            Dungeon(),
            ["north", "north", "up", "x egg", "take egg", "examine egg", "look", "x nest"])

        // Both listing lines print, in the order the containment gives them.
        let perch = turnOutput(of: "up", in: transcript)
        #expect(perch.contains("Beside you on the branch is a small bird's nest."))
        #expect(perch.contains("In the bird's nest is a large egg encrusted"))
        // And the stock sentence they replace never prints.
        #expect(!transcript.contains("On the birds nest is"))

        // In the nest, `x egg` may still say so; in the hand it must not.
        #expect(turnOutput(of: "x egg", in: transcript).contains("large egg encrusted"))
        let inHand = turnOutput(of: "examine egg", in: transcript)
        #expect(inHand.contains("A large egg encrusted with precious jewels"))
        #expect(!inHand.contains("In the bird's nest is"))

        // The egg's line is an `FDESC` and stops once the egg is touched. The
        // nest's has nothing to touch it, so it goes on printing — and the nest
        // is still `scenery`, so this is the author's line, not the engine's.
        let after = turnOutput(of: "look", in: transcript)
        #expect(after.contains("Beside you on the branch is a small bird's nest."))
        #expect(!after.contains("large egg encrusted"))

        // Examining the nest answers about the nest.
        #expect(turnOutput(of: "x nest", in: transcript).contains("shallow cup of twigs"))
    }

    // MARK: - Nouns the prose names and the parser did not know

    /// The egg's paragraph names a clasp; the grating's names a heavy lock, and
    /// so does its twin from below and so does ``Prose/gratingLockNotReachable``.
    /// None of the four sentences had a noun behind it, so `x clasp` answered "I
    /// don't know the word" and `x lock` "You can't see any such thing" — which
    /// is the answer reserved for a noun that is not in scope, and reads as a
    /// bug when the game has just printed it.
    @Test func theClaspAndTheLockAnswerToTheNamesTheProseUses() async throws {
        let transcript = try await play(
            Dungeon(),
            [
                "north", "north", "up", "take egg", "x clasp",
                "down", "north", "east", "examine lock", "push leaves", "x lock", "x grate",
            ])

        // The clasp is the egg's, and answers with it.
        #expect(turnOutput(of: "x clasp", in: transcript).contains("delicate looking clasp"))
        #expect(!transcript.contains("I don't know the word \"clasp\""))

        // The lock is the grating's — and stays out of scope until the leaves
        // come off, because so does the grating.
        #expect(
            turnOutput(of: "examine lock", in: transcript)
                .contains("You can't see any such thing"))
        // (Short of "lock": `TextWrap` re-wraps the paragraph to the
        // transcript's width, and this is one of the fragments that survives
        // wherever the break lands.)
        #expect(turnOutput(of: "x lock", in: transcript).contains("fastened with a heavy"))
        #expect(turnOutput(of: "x grate", in: transcript).contains("A sturdy iron grating"))
    }

    // MARK: - A way in the room points at

    /// Behind House ends its paragraph on the window, and `enter window` walks
    /// through it — but `enter house` fell past `.board`'s door branch to
    /// `cantEnterThat` and answered with `V-THROUGH`'s generic head-butt.
    /// `WHITE-HOUSE-F` answers `THROUGH` itself: from this side an open window
    /// walks you in and a shut one says so, and from every other side the house
    /// says there is no way in rather than butting your head.
    @Test func enterHouseFindsTheWindowOrSaysThereIsNoWayIn() async throws {
        let transcript = try await play(
            Dungeon(),
            [
                "enter house",  // West of House: no way in from this side
                "south", "east",  // round to Behind House
                "go through house",  // still shut
                "open window",
                "enter house",  // and now it walks
                "x bottle",
            ])

        expectInOrder(
            transcript,
            [
                "You can't see how to get in from here.",
                "Behind House",
                "The window is the only way in",
                "Opened.",
                "Kitchen",
            ])
        // Really in the kitchen, not merely told about it.
        #expect(turnOutput(of: "x bottle", in: transcript).contains("clear glass bottle"))
        // And the generic refusal never appears on any of the three turns.
        #expect(!transcript.contains("hit your head against the white house"))
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
    ///
    /// It was re-voiced a second time for #286's D9, and the subject moved: the
    /// old line said "Nothing **here** smells of anything in particular", which
    /// is a claim about the room printed unchanged in ~194 of them. A bare
    /// command has no object to be about, so it reports on the player.
    @Test func aRoomWithNothingToSmellAnswersInTheGamesOwnVoice() async throws {
        let transcript = try await play(
            Dungeon(), Self.toTheSmellyRoom.dropLast() + ["smell"], seed: 18)

        #expect(transcript.contains("Wooden Tunnel"))
        let here = turnOutput(of: "smell", in: transcript)
        #expect(here.contains("You smell nothing worth reporting."))
        #expect(!here.contains("nothing out of the ordinary"))
        #expect(!here.contains("Nothing here smells"))
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
        #expect(stopped.contains("standing still at last long enough to be counted"))
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

    /// **Stream View stands you on a path beside the stream, and `x path`
    /// answered with the stream.** The round filed this one under the noun it
    /// could not answer at all — `bank`, which is where the wire is lying — and
    /// the two are one repair: the ground gets an item, and the water gives up
    /// a synonym that was never about it. (#233)
    @Test func theStreamViewPathIsTheBankNotTheWater() async throws {
        let transcript = try await play(
            Dungeon(),
            // Stream View is west of Reservoir South and wants no wrench: the
            // reservoir has to be drained to cross it, not to stand beside it.
            Self.toTheDam + ["south", "northwest", "west"]
                + ["x path", "x bank", "x stream"],
            seed: 18)

        #expect(transcript.contains("Stream View"))
        for ground in ["x path", "x bank"] {
            let answer = turnOutput(of: ground, in: transcript)
            #expect(answer.contains("A strip of wet stone between the water and the wall"))
            #expect(!answer.contains("going quietly about its business"))
        }
        // The control: the water is still the water.
        #expect(
            turnOutput(of: "x stream", in: transcript)
                .contains("going quietly about its business"))
    }

    /// **The Safety Depository's `wall` answered and its `walls` did not**, and
    /// the two are different questions. The singular is the curtain of light
    /// standing where the north wall ought to be; the plural is the east and
    /// west walls the deposit boxes came out of, which is what the room's own
    /// second sentence is about. Keeping both is the fix. (#233)
    @Test func theDepositorysSideWallsAreNotItsMissingNorthOne() async throws {
        let transcript = try await play(
            Dungeon(), Self.toTheDepository + ["x walls", "x boxes", "x wall"], seed: 41)

        #expect(transcript.contains("Safety Depository"))
        for plural in ["x walls", "x boxes"] {
            let answer = turnOutput(of: plural, in: transcript)
            #expect(answer.contains("Bare from floor to ceiling on both sides"))
            #expect(!answer.contains("north wall ought to be"))
        }
        // The control: the singular still finds the curtain, which is the whole
        // reason the plural could not have it.
        let singular = turnOutput(of: "x wall", in: transcript)
        #expect(singular.contains("north wall ought to be"))
        #expect(!singular.contains("Bare from floor to ceiling"))
    }

    /// **The Small Square Room names sand three times and could not answer for
    /// it.** The game's `sand` stands in the cell *below* the hole, which is the
    /// far-thing-near-thing split this round is about seen through ten feet of
    /// floor. The new item takes the room's own two states, because its
    /// paragraph has branched on them from the day it was written. (#233)
    @Test func theAnteroomsSandChangesWhenTheHoleIsBlocked() async throws {
        let transcript = try await play(
            Dungeon(),
            DungeonTests.toTheCardSquare + ["take card"]
                + ["north", "north", "northwest", "push west", "south"]
                + ["southeast", "southeast", "push south", "push west", "south"]
                + ["put card in slit", "west", "north", "examine sand"],
            seed: 18)

        #expect(transcript.contains("Small Square Room"))
        let blocked = turnOutput(of: "examine sand", in: transcript)
        #expect(blocked.contains("A face of smooth sandstone, come up flush"))
        #expect(!blocked.contains("ten feet down through the hole"))
    }

    /// The control, on the way in: with the hole still open the sand is ten feet
    /// down and there is not much to be made of it from up there.
    @Test func theAnteroomsSandIsTenFeetDownWhileTheHoleIsOpen() async throws {
        let transcript = try await play(
            Dungeon(), DungeonTests.toTheRoyalPuzzle + ["examine sand"], seed: 18)

        #expect(transcript.contains("Small Square Room"))
        let open = turnOutput(of: "examine sand", in: transcript)
        #expect(open.contains("ten feet down through the hole"))
        #expect(!open.contains("come up flush"))
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
            DungeonTests.toVolcanoView + ["x ledge", "x ledges", "x rim", "x bottom"],
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

    // MARK: - Three facts about one machine, in one paragraph

    /// **The balloon's listing line and its examine text are each one
    /// paragraph, not three.** The basket, the bag over it and the wire off its
    /// side are three facts about three parts of one machine, and a listing
    /// line is the sentence that tells a player *one thing stands here*: this
    /// room already lists a hook and a zorkmid, so broken three ways one
    /// balloon reads as three more items. The source says the same twice —
    /// `ODESC1` (`dung.355:4339`) is a single string printed by one `TELL`, and
    /// `LEDGE-FUNCTION` (`act2.92:745`) splices the Wide Ledge's state clause
    /// on with a leading space rather than a break. (#302)
    ///
    /// The refusals pin the same seam one level down. The wire is the only part
    /// with a verb of its own (`WIRE-FUNCTION`, `act2.92:587`), so it is the
    /// only one whose refusal carries a second sentence — and the other two
    /// must not pick it up, which is what the old `+`-spliced spelling made
    /// possible and nothing tested.
    @Test func theBalloonsThreeFactsArriveAsOneParagraph() async throws {
        let transcript = try await play(
            Dungeon(),
            DungeonTests.toTheVolcano
                + ["look", "examine basket"]
                + ["take cloth bag", "take receptacle", "take braided wire"]
                + ["pull receptacle"],
            seed: 18)

        // Blocks, not fragments: whatever width the transcript wraps to, the
        // paragraph that opens on the basket is the one that ends on the wire.
        func paragraph(naming noun: String, of command: String) -> String? {
            turnOutput(of: command, in: transcript)
                .components(separatedBy: "\n\n")
                .first { $0.contains(noun) }
        }

        let listed = try #require(paragraph(naming: "wicker basket", of: "look"))
        #expect(listed.contains("The cloth bag is draped over the side"))
        #expect(listed.contains("Dangling from the basket is a piece of braided wire."))

        let examined = try #require(paragraph(naming: "cloth bag", of: "examine basket"))
        #expect(examined.contains("Directly in the middle of it is a metal receptacle."))
        #expect(examined.contains("A braided wire is dangling over the side of the basket."))

        // The wire's hint is the wire's, and the wire's alone.
        for part in ["take cloth bag", "take receptacle", "pull receptacle"] {
            let refusal = turnOutput(of: part, in: transcript)
            #expect(refusal.contains("is an integral part of the basket"))
            #expect(!refusal.contains("might possibly be tied"))
        }
        let wire = turnOutput(of: "take braided wire", in: transcript)
        #expect(wire.contains("The braided wire is an integral part of the basket"))
        #expect(wire.contains("The wire might possibly be tied, though."))
    }

    // MARK: - The floor speaks in the game's voice (#233, box 12)

    /// **The sweep, and the only assertion here that cannot go stale.** Every
    /// other test in this section names one verb; a forty-eighth stub arriving
    /// in the engine tomorrow would slip past all of them. The shared helper
    /// derives its own completeness from ``GameText/StubReplies`` rather than
    /// from a list here that would have to be kept up.
    ///
    /// Deriving rather than restating is the whole point of the box: the round
    /// that filed it counted `smell` as re-skinned because a human had said so,
    /// while the constant behind it was the engine's line character for
    /// character.
    @Test func noEngineStubLineSurvivesInDungeon() {
        expectNoEngineStubLineSurvives(in: Dungeon().text.stubs, game: "Dungeon")
    }

    @Test func theLoudRoomStopsRoaringOnceTheEchoSettlesIt() async throws {
        let transcript = try await play(
            Dungeon(), Self.toTheLoudRoom + ["echo", "look", "listen"], seed: 18)

        // Roaring on arrival, which is where the platinum bar's lock comes from.
        #expect(transcript.contains("The noise in here is past bearing"))

        let after = turnOutput(of: "look", in: transcript)
        #expect(!after.contains("past bearing"))
        #expect(after.contains("The room is quiet now"))

        // And only then does the floor's line become true here.
        let heard = turnOutput(of: "listen", in: transcript)
        #expect(heard.contains("learn nothing you did not already know"))
        #expect(!heard.contains("nothing out of the ordinary"))
    }

    /// The control: while the room still roars it answers `listen` with the
    /// roar, not with the floor — the read-loop rule claims the verb at stage 2
    /// and this pass must not have quietly taken it away.
    @Test func theRoaringLoudRoomStillFlingsListenBack() async throws {
        let transcript = try await play(
            Dungeon(), Self.toTheLoudRoom + ["listen"], seed: 18)

        let here = turnOutput(of: "listen", in: transcript)
        #expect(here.contains("cause your words to echo"))
        #expect(!here.contains("nothing out of the ordinary"))
        #expect(!here.contains("learn nothing you did not already know"))
    }

    /// And a room with nothing to hear and no rule of its own: the floor
    /// answers, and reports on the listener rather than on the room.
    @Test func aQuietRoomAnswersListenInTheGamesVoice() async throws {
        let transcript = try await play(
            Dungeon(), Self.toTheLoudRoom.dropLast() + ["listen"], seed: 18)

        #expect(transcript.contains("North-South Passage"))
        let here = turnOutput(of: "listen", in: transcript)
        #expect(here.contains("learn nothing you did not already know"))
        #expect(!here.contains("nothing out of the ordinary"))
    }

    /// **D9's `smell guano`.** The floor answered "Nothing here smells of
    /// anything in particular." while the player stood over a hunk of bat
    /// guano. The fifth pass left the line alone on the ground that `smell` was
    /// a channel the engine could not hand an object to; `SyntaxRule.stubTable`
    /// hands it one, and `Sources/Zork1/` had already written the naming half.
    ///
    /// Both halves, in one room — and the bare half moved with the naming one.
    /// "Nothing here smells of anything in particular." would have been the
    /// same defect one command shallower: `smell` and `smell guano`, typed in
    /// the same room one turn apart, cannot disagree about whether anything in
    /// it has a smell.
    @Test func smellNamesWhatItWasPointedAt() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheLoudRoom + ["east", "east", "smell guano", "smell"],
            seed: 18)

        #expect(transcript.contains("Small Cave"))
        let named = turnOutput(of: "smell guano", in: transcript)
        #expect(named.contains("The hunk of bat guano smells of exactly what it is."))
        #expect(!named.contains("Nothing here smells of anything in particular."))
        // And the bare half, in the same room, reports on the player instead of
        // contradicting the line above it.
        let bare = turnOutput(of: "smell", in: transcript)
        #expect(bare.contains("You smell nothing worth reporting."))
        #expect(!bare.contains("Nothing here smells"))
    }

    /// **`give sword to troll` answered "There is nobody here who wants it."**
    /// — standing in front of somebody who very much wanted it. The old line
    /// was a claim about the room installed as a game-wide default, which is
    /// the same defect one register up; the engine's own template names the
    /// recipient, and an `action(…)` row is the reason this game could not.
    /// (#233)
    @Test func offeringSomethingToSomebodyStandingThereNamesThem() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.intoTheKitchen + Self.downTheTrapDoor + ["east", "give sword to troll"],
            seed: 18)

        #expect(transcript.contains("Troll Room"))
        let offer = turnOutput(of: "give sword to troll", in: transcript)
        #expect(!offer.contains("nobody here"))
        #expect(offer.contains("troll"))
    }

    /// **The six stock lines that take a person as their subject were all still
    /// the engine's**, under four actors the game had already given voices to.
    /// #236 wrote their *greetings* as rules; this is the floor underneath,
    /// which every verb that has to reach a person falls through.
    ///
    /// `V-COMMAND` (`gverbs.zil:359`) is the source for the order refusal and
    /// `V-SQUEEZE` (`:1287`) for the reach one. (#233)
    @Test func theStockLinesAboutAPersonAnswerInTheGamesVoice() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.intoTheKitchen + Self.downTheTrapDoor
                + ["east", "take troll", "search troll", "troll, go north", "squeeze troll"],
            seed: 18)

        #expect(transcript.contains("Troll Room"))
        #expect(!transcript.contains("would take exception to that"))
        #expect(!transcript.contains("would have something to say about that"))
        #expect(!transcript.contains("no intention of taking orders"))
        #expect(!transcript.contains("would rather you didn't"))
        // The source's own answer to ordering a creature about.
        #expect(turnOutput(of: "troll, go north", in: transcript).contains("pays no attention"))
        // And its answer to laying hands on one.
        #expect(
            turnOutput(of: "squeeze troll", in: transcript).contains("does not understand this"))
    }

    /// The floor a player actually meets: four of the thirty verbs that had no
    /// Dungeon line at all, answered in a room where each is plainly idle.
    /// Positive controls for the sweep above, which only proves the lines
    /// *differ* from the engine's — not that they read as this game.
    @Test func theIdleVerbsAnswerInTheGamesVoice() async throws {
        let transcript = try await play(
            Dungeon(), Self.intoTheKitchen + ["jump", "sing", "wish", "swear"], seed: 18)

        #expect(turnOutput(of: "jump", in: transcript).contains("Wheeeeeeeeee!!!!!"))
        #expect(turnOutput(of: "sing", in: transcript).contains("unmoved by your singing"))
        #expect(turnOutput(of: "wish", in: transcript).contains("your wish will come true"))
        #expect(
            turnOutput(of: "swear", in: transcript)
                .contains("Such language in a high-class establishment"))
    }

    /// **`.attack` is the one verb in the floor the box did not think to look
    /// at**, because it is not the engine that answers it: `GnustoMeleeCombat`
    /// claims the intent for the whole game, and shipped its four refusals in
    /// the plain modern voice this pass is removing everywhere else. Swinging
    /// at the scenery was the most reachable stock line left in the game.
    /// (#233)
    @Test func swingingAtTheSceneryIsRefusedInTheGamesVoice() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.intoTheKitchen + ["take sack"] + Self.downTheTrapDoor
                + ["east", "attack sack", "attack troll with sack"],
            seed: 18)

        // Something that is no villain at all: the plugin's `attackFutile`.
        let swing = turnOutput(of: "attack sack", in: transcript)
        #expect(!swing.contains("isn't the answer"))
        #expect(swing.contains("I've known strange people, but fighting a brown sack?"))

        // And one that is, swung at with something that is no weapon.
        let withIt = turnOutput(of: "attack troll with sack", in: transcript)
        #expect(!withIt.contains("is no weapon"))
        #expect(withIt.contains("would be suicidal"))
    }

    /// A stub the engine guards and this game had stopped guarding. Moving the
    /// floor off `action(…)` rows and onto `text.stubs` gives the reach check
    /// back: `DefaultActions.run` returns from an action override *before*
    /// `requireReach`, so every verb Dungeon claimed was answering about things
    /// the player could not touch.
    @Test func theFloorRefusesWhatThePlayerCannotReach() async throws {
        let transcript = try await play(
            Dungeon(), Self.intoTheKitchen + ["west", "east", "squeeze window"], seed: 18)

        // The kitchen window is a door on the exit behind us, not a thing in
        // the living room — so the answer is about reach, not about squeezing.
        let squeeze = turnOutput(of: "squeeze window", in: transcript)
        #expect(!squeeze.contains("accomplishes nothing"))
    }

    // MARK: - A room's paragraph names things the declarations do not model

    /// **Rocky Shore's cave mouth answered with the Frigid River.** The river
    /// scenery carried `cave`, `mouth` and `entrance`, so the one exit off this
    /// square — the room's last clause, and the way back to the Small Cave —
    /// was described as fast-moving water. (#286, D3)
    @Test func rockyShoresCaveMouthIsNotTheRiverBesideIt() async throws {
        let transcript = try await play(
            Dungeon(), Self.toRockyShore + ["x cave", "x mouth", "x river"], seed: 18)

        #expect(transcript.contains("Rocky Shore"))
        for way in ["x cave", "x mouth"] {
            let answer = turnOutput(of: way, in: transcript)
            #expect(answer.contains("A low opening at the top of the rocks"))
            #expect(!answer.contains("lives up to its name"))
        }
        // The control: the water is still the water.
        #expect(turnOutput(of: "x river", in: transcript).contains("lives up to its name"))
    }

    /// **The White Cliffs beach has one path off it and the cliffs answered for
    /// the word** — with "there is no climbing them from here", about the one
    /// route the room offers. Six bank rooms print a path; none of them
    /// modelled one. (#286, D3)
    @Test func theWhiteCliffsPathIsTheWayOutAndNotTheWallAboveIt() async throws {
        let transcript = try await play(
            Dungeon(), Self.toTheWhiteCliffs + ["x path", "x cliffs"], seed: 18)

        #expect(transcript.contains("White Cliffs Beach"))
        let path = turnOutput(of: "x path", in: transcript)
        #expect(path.contains("A single narrow track along the foot of the cliffs"))
        #expect(!path.contains("no climbing them from here"))
        // The control: the cliffs are still unclimbable.
        #expect(turnOutput(of: "x cliffs", in: transcript).contains("no climbing them from here"))
    }

    /// **Aragain Falls has a path on its north end and the waterfall answered
    /// for it**, which put a 450-foot drop on the one way off the ledge that is
    /// not one. (#286, D3)
    @Test func theFallsPathIsTheWayOffTheLedgeAndNotTheDrop() async throws {
        let transcript = try await play(
            Dungeon(), Self.toAragainFalls + ["x path", "x falls"], seed: 18)

        #expect(transcript.contains("Aragain Falls"))
        let path = turnOutput(of: "x path", in: transcript)
        #expect(path.contains("A track leaving by the north end of the ledge"))
        #expect(!path.contains("Four hundred and fifty feet"))
        // The control: the falls are still four hundred and fifty feet of it.
        #expect(turnOutput(of: "x falls", in: transcript).contains("Four hundred and fifty feet"))
    }

    /// **The End of Rainbow is a beach, and `x beach` described the rainbow
    /// overhead.** One item carried the ground, the cliffs, the falls and the
    /// path as well as the rainbow; all four now answer for themselves.
    /// (#286, D3)
    @Test func theEndOfRainbowsGroundIsNotTheRainbowOverIt() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toEndOfRainbow + ["x beach", "x cliffs", "x falls", "x path", "x rainbow"],
            seed: 18)

        #expect(transcript.contains("End of Rainbow"))
        let beach = turnOutput(of: "x beach", in: transcript)
        #expect(beach.contains("A rind of wet shingle"))
        #expect(!beach.contains("A rainbow over the falls"))
        #expect(turnOutput(of: "x cliffs", in: transcript).contains("no climbing them from here"))
        #expect(turnOutput(of: "x falls", in: transcript).contains("Four hundred and fifty feet"))
        #expect(turnOutput(of: "x path", in: transcript).contains("leaving the shingle to the southeast"))
        // The control: the rainbow is still the rainbow, and only that.
        #expect(turnOutput(of: "x rainbow", in: transcript).contains("A rainbow over the falls"))
    }

    /// **Canyon View's forest is an exit, not a view.** The room's distant-view
    /// item answered for the White Cliffs, the falls, the rainbow and the dam —
    /// all of them miles off — and carried `forest` too, so the wood the player
    /// walked out of one turn earlier was "too far off to make out more than
    /// the shape". (#286, D3)
    @Test func canyonViewsForestIsTheWoodUnderfootAndNotTheDistance() async throws {
        let transcript = try await play(
            Dungeon(), Self.toCanyonView + ["x forest", "x trees", "x cliffs"], seed: 18)

        #expect(transcript.contains("Canyon View"))
        for near in ["x forest", "x trees"] {
            let answer = turnOutput(of: near, in: transcript)
            #expect(answer.contains("Tall trees, close-grown"))
            #expect(!answer.contains("too far off to make out"))
        }
        // The control: the cliffs across the canyon really are miles away.
        #expect(turnOutput(of: "x cliffs", in: transcript).contains("too far off to make out"))
    }

    /// **The Top of Well's crack answered with the ring of letters round the
    /// shaft.** The room's last sentence puts the crack across the floor at the
    /// east doorway; the etchings carried both `crack` and `floor`. (#286, D3)
    @Test func theTopOfWellsCrackIsInTheFloorAndNotInTheEtchings() async throws {
        let transcript = try await play(
            Dungeon(), Self.toTheTopOfWell + ["x crack", "x floor", "x etchings"], seed: 41)

        #expect(transcript.contains("Top of Well"))
        for ground in ["x crack", "x floor"] {
            let answer = turnOutput(of: ground, in: transcript)
            #expect(answer.contains("A hairline in the stone"))
            #expect(!answer.contains("f r o b o z z i c a"))
        }
        // The control: the ring of letters is still on the wall.
        #expect(turnOutput(of: "x etchings", in: transcript).contains("f r o b o z z i c a"))
    }

    /// **The Machine Room names three things and only the buttons were
    /// declared**, so `x machinery` and `x controls` could be answered only by
    /// asking which of the three buttons you meant — and the room says the
    /// machinery is *behind* them, so none of the three was the answer.
    /// (#286, D3)
    @Test func theMachineRoomsMachineryIsNotOneOfItsButtons() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheButtons + ["x machinery", "x controls", "x bank", "x round button"],
            seed: 41)

        #expect(transcript.contains("Machine Room"))
        expectNoAmbiguity(transcript, "The Machine Room's three nouns are three things.")
        #expect(
            turnOutput(of: "x machinery", in: transcript)
                .contains("Behind the plate, and going on with it"))
        for panel in ["x controls", "x bank"] {
            #expect(
                turnOutput(of: panel, in: transcript)
                    .contains("A plate of dull metal let into the wall"))
        }
        // The control: a button is still a button, and still asks nothing.
        #expect(turnOutput(of: "x round button", in: transcript).contains("worn smooth in the middle"))
    }

    /// **The gas that starts the six-turn clock names two things the parser
    /// denied.** `x gas` answered "You can't see any such thing" and `x vent`
    /// did not get as far as a refusal — it answered *"I don't know the word"* —
    /// on the turn the game had just printed both. (#286, D5)
    @Test func theCagesGasAndVentAnswerOnTheTurnTheyArePrinted() async throws {
        let transcript = try await play(
            Dungeon(), Self.toTheButtons + ["south", "take sphere", "x gas", "x vent"], seed: 41)

        expectInOrder(transcript, ["Cage", "A colorless gas begins to enter the cage"])
        #expect(turnOutput(of: "x gas", in: transcript).contains("There is nothing to look at."))
        #expect(turnOutput(of: "x vent", in: transcript).contains("A slot in the floor plate"))
        expectEveryNounAnswered(transcript, "The cage's gas and vent.")
    }

    /// **The beach's dig progression prints a hole from the first turn of
    /// digging and nothing backed the word.** The item is hidden until there is
    /// one, and reads off the count the progression already keeps, because how
    /// deep it has got is the thing an examine is asking. (#286, D5)
    @Test func theSandyBeachesHoleAnswersOnceThereIsOne() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheSandyBeach
                + ["x hole", "dig sand with shovel", "x pit"]
                + ["dig sand with shovel", "dig sand with shovel", "examine hole"],
            seed: 18)

        #expect(transcript.contains("Sandy Beach"))
        // Before the first dig there is no hole, and the game has not claimed one.
        #expect(turnOutput(of: "x hole", in: transcript).contains("can't see any such thing"))
        #expect(turnOutput(of: "x pit", in: transcript).contains("A scoop out of the wet sand"))
        #expect(turnOutput(of: "examine hole", in: transcript).contains("sand stands over your head"))
    }

    /// **The Round Room's turning line named a compass and a needle, and there
    /// is no compass in this game.** Both halves of the "every printed noun
    /// answers" rule failed in one sentence, and the repair is the sentence:
    /// nothing can be declared for a compass the player does not have.
    /// (#286, D5)
    @Test func theRoundRoomSaysTheFloorTurnsWithoutHandingThePlayerACompass() async throws {
        let transcript = try await play(
            Dungeon(), Self.pastTheTroll + ["north", "east", "x floor"], seed: 18)

        #expect(transcript.contains("Round Room"))
        #expect(transcript.contains("the floor has carried it somewhere else"))
        #expect(!transcript.lowercased().contains("compass"))
        // The control: the floor the line is about still answers.
        #expect(turnOutput(of: "x floor", in: transcript).contains("bedded too deep to see"))
    }

    // MARK: - A description is a constant and the state behind it moved

    /// `OPEN BOTTLE` answers "reveals a quantity of water" and `X BOTTLE`
    /// answered "stoppered" on the line under it. The stopper is the
    /// `openable` trait; only the glass is a constant. (#286 D2)
    @Test func theBottleSaysWhetherItIsStoppered() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.intoTheKitchen + ["take bottle", "x bottle", "open bottle", "examine glass bottle"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "A clear glass bottle, stoppered and quite ordinary.",
                "Opening the glass bottle reveals a quantity of water.",
                "A clear glass bottle, unstoppered and quite ordinary.",
            ])
    }

    /// "resting on a low pedestal" is where the sphere was, not what it is, and
    /// the player reads it standing inside a steel cage with the sphere in
    /// hand. `cageSprung` is the pedestal having been emptied. (#286 D2)
    @Test func theSphereStopsRestingOnAPedestalItIsNoLongerOn() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheButtons + ["south", "examine sphere", "take sphere", "x sphere"],
            seed: 41)

        #expect(turnOutput(of: "examine sphere", in: transcript).contains("resting on a low pedestal"))

        let held = turnOutput(of: "x sphere", in: transcript)
        #expect(held.contains("lighter in the hand"))
        #expect(!held.contains("resting on a low pedestal"))
    }

    /// The Pool Room's own paragraph already knows the steam took the leak with
    /// it. The leak under it went on dripping "and never quite stopping" into a
    /// depression the same paragraph calls bare and cracked and empty.
    /// (#286 D2)
    @Test func theLeakStopsDrippingWhenTheSteamHasTakenIt() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheTeaRoom
                + ["take eat-me cake", "take red cake", "eat eat-me cake", "east"]
                + ["examine leak", "throw red cake in pool", "x leak"],
            seed: 41)

        #expect(turnOutput(of: "examine leak", in: transcript).contains("never quite stopping"))

        let after = turnOutput(of: "x leak", in: transcript)
        #expect(after.contains("dry now"))
        #expect(!after.contains("never quite stopping"))
    }

    /// The reservoir bed is standable only with the gates open — both ways in
    /// are gated on it — so "a billion and a half cubic feet of it … between
    /// you and the north shore" was the *only* answer `x water` ever gave, to a
    /// player walking across the mud. The two shores already had the
    /// state-aware line; the item on the bed did not. (#286 D2)
    @Test func theReservoirsWaterIsTheMudThePlayerIsStandingOn() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheReservoirShore + ["examine water", "north", "examine reservoir"],
            seed: 18)

        // The control: the shore's own water line, which reads the bolt rather
        // than the water and is true either way.
        #expect(turnOutput(of: "examine water", in: transcript).contains("depends entirely on what the bolt"))

        let onTheBed = turnOutput(of: "examine reservoir", in: transcript)
        #expect(onTheBed.contains("Mud, and a great deal of it"))
        #expect(!transcript.contains("A billion and a half cubic feet"))
    }

    /// The grating's two descriptions each fastened it with a heavy lock, from
    /// both sides, for every turn of that lock and after it had been swung
    /// open. Four frames, one transcript. (#286 D2)
    @Test func theGratingReadsBothItsSidesAndBothTurnsOfItsLock() async throws {
        // Four spellings of one command, because `turnOutput` matches the first
        // occurrence of a prompt and this test needs four separate turns of it.
        let transcript = try await play(
            Dungeon(),
            Self.toTheGratingRoom
                + ["examine grating", "unlock grating with keys", "x grating"]
                + ["open grating", "look at grating", "up", "examine iron grating"],
            seed: 18)

        #expect(turnOutput(of: "examine grating", in: transcript).contains("fastened on this side with a heavy lock"))
        #expect(turnOutput(of: "x grating", in: transcript).contains("the heavy lock on this side of it standing open"))
        #expect(turnOutput(of: "look at grating", in: transcript).contains("daylight coming down through the hole"))
        #expect(turnOutput(of: "examine iron grating", in: transcript).contains("swung up out of the ground"))
    }

    /// The gate's paragraph branched on the end of the ceremony and on nothing
    /// in between, so "evil spirits, who jeer at your attempts to pass" printed
    /// through the whole of it — including the turns after the bell has stopped
    /// their jeering and the candles have them cowering. The spirits' own
    /// description had them enjoying this after they had gone through the
    /// walls. (#286 D2)
    @Test func theGateOfHadesReadsTheCeremonyAndNotOnlyItsEnd() async throws {
        let transcript = try await play(
            Dungeon(),
            DungeonTests.toTheGateOfHades
                + ["examine spirits", "ring bell", "look", "take candles"]
                + ["light match", "burn candles with match", "l", "read book"]
                + ["look", "x ghosts"],
            seed: 18)

        expectInOrder(
            transcript,
            [
                "who jeer at your attempts to pass",
                "every one of them enjoying this",
                "The bell suddenly becomes red hot",
                "silent now, every one of them turned to face you",
                "The candles are lighted.",
                "who cower from the candle flames while they bar it",
                "Begone, fiends!",
            ])

        // And once they are gone the gate stops reporting them at all.
        let afterBanishing = output(after: "Begone, fiends!", in: transcript)
        #expect(afterBanishing.contains("Entrance to Hades"))
        #expect(!afterBanishing.contains("barred by evil spirits"))
        #expect(turnOutput(of: "x ghosts", in: transcript).contains("Nothing of them is left to look at"))
    }

    // MARK: - #286's D10 — two one-off frame contradictions

    /// **The black book's read fallback.** `blackBook.before(.read)` guards on
    /// the ceremony — at the gate of Hades, with the bell rung and the candles
    /// alight — and *returned* otherwise, so `read book` anywhere else fell
    /// through to the default action and printed the item's `description`. That
    /// description is the cover of a book the same sentence advertises as *open
    /// at a page somebody has marked*, so the one command in the game that asks
    /// what the page says answered with what the book looks like.
    ///
    /// Both source families give this book a read text, so having one at all is
    /// fidelity-supported. Its **words** are not: in both sources that text is
    /// the commandment, and this game prints the commandment on the Temple's
    /// own wall instead. So the page is written fresh, and the assertion at the
    /// end that #12592 never appears is what keeps the two from converging.
    @Test func readingTheBlackBookAnswersWithThePageRatherThanTheCover() async throws {
        let transcript = try await play(
            Dungeon(),
            DungeonTests.toTheGateOfHades
                + [
                    "read book", "x book", "up", "read the black book", "down",
                    "ring bell", "take candles", "light match",
                    "burn candles with match", "read book",
                ],
            seed: 18)

        // The page, at the gate.
        let page = turnOutput(of: "read book", in: transcript)
        #expect(page.contains("The marked page carries one passage"))
        #expect(page.contains("Commandment #12593"))
        #expect(page.contains("Ye who are dead and will not lie down,"))
        #expect(page.contains("The rest of the book is a great deal less specific."))
        // The page is the words the ceremony reads aloud, not a recipe for it:
        // nothing else in this game states the ritual, and a page that listed
        // the bell, the candles and the gate in order would answer the box by
        // turning the hardest puzzle in the game into a set of instructions.
        #expect(!page.contains("bell"))
        #expect(!page.contains("candle"))
        // Not the cover, which is what it used to answer with.
        #expect(!page.contains("bound in something that was once an animal"))

        // The cover is still the cover, and EXAMINE is still what asks for it.
        let cover = turnOutput(of: "x book", in: transcript)
        #expect(cover.contains("A black book, bound in something that was once an animal"))
        #expect(!cover.contains("Commandment"))

        // The page is the book's, not the room's: one room up the stairs it
        // reads the same.
        let elsewhere = turnOutput(of: "read the black book", in: transcript)
        #expect(elsewhere.contains("Commandment #12593"))

        // And the ceremony branch is untouched — the marked prayer read at the
        // gate with the candles alight still banishes the spirits.
        expectInOrder(
            transcript,
            [
                "The bell suddenly becomes red hot",
                "The candles are lighted.",
                "Each word of the prayer reverberates",
                "Begone, fiends!",
            ])
        // The Temple's wall keeps #12592, which is the trilogy's and MIT-
        // licensed. The book's page must never become a copy of it.
        #expect(!transcript.contains("Commandment #12592"))
    }

    /// **The barrel's closed view.** Aragain Falls' `describe` branch says
    /// *"From where you are sitting you cannot see the falls at all"* to a
    /// player in the barrel — and the falls, the rainbow over them and the path
    /// off the north end were plain `scenery` with no guard of any kind, so
    /// `x falls` answered in full on the very next turn.
    ///
    /// Two rules apiece close it, because one cannot: `reach { }` runs at stage
    /// 0 and covers every verb that has to touch the thing, but EXAMINE is
    /// `reach: .notNeeded` in `CoreVerbs` and would have walked straight past
    /// it. What the barrel does **not** block is itself, or a noise: `listen`
    /// still answers with the falls, because a man in a barrel can hear them
    /// perfectly well.
    @Test func theBarrelSilencesTheViewItSaysYouCannotSee() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toAragainFalls
                + [
                    "x falls", "x rainbow", "x path", "board barrel", "look",
                    "examine falls", "examine rainbow", "examine path",
                    "x barrel", "listen", "get out", "look at falls",
                ],
            seed: 18)

        // Standing on the ledge, all three answer.
        #expect(turnOutput(of: "x falls", in: transcript).contains("Four hundred and fifty feet of the Frigid River"))
        #expect(turnOutput(of: "x rainbow", in: transcript).contains("A rainbow over the falls"))
        #expect(turnOutput(of: "x path", in: transcript).contains("A track leaving by the north end"))

        // In the barrel, the room says the view is gone.
        let inside = turnOutput(of: "look", in: transcript)
        #expect(inside.contains("You are inside a barrel. Congratulations."))
        #expect(inside.contains("From where you are sitting you cannot see the falls at all."))

        // And now the view agrees with it, in one voice.
        let refusal = "Not from in here. There is a good deal of barrel between you"
        #expect(turnOutput(of: "examine falls", in: transcript).contains(refusal))
        #expect(turnOutput(of: "examine rainbow", in: transcript).contains(refusal))
        #expect(turnOutput(of: "examine path", in: transcript).contains(refusal))
        // Not by unanswering the nouns: this is a refusal, not a denial.
        expectEveryNounAnswered(transcript, "Aragain Falls, from inside the barrel")

        // The barrel is still there to be looked at, and the falls are still
        // there to be heard.
        #expect(turnOutput(of: "x barrel", in: transcript).contains("cut a word into the staves"))
        #expect(
            turnOutput(of: "listen", in: transcript).contains(
                "Four hundred and fifty feet of water arriving at the bottom"))

        // Climb out and the view comes back, which is what makes the three
        // refusals above mean something.
        #expect(
            turnOutput(of: "look at falls", in: transcript).contains("Four hundred and fifty feet of the Frigid River"))
    }

    // MARK: - Forms

    /// Three of this game's set pieces are *forms* rather than paragraphs, and
    /// the full-screen renderer used to fold and re-pack all of them: the ring
    /// of letters became a run of words, the inscription over Hades became one
    /// line, and the riddle's verse lost its line endings. Each is written
    /// indented inside its literal, which is what `TextWrap` now reads as a
    /// literal block.
    ///
    // MARK: - Rule 1 again, in six regions no charter had ever worked

    /// **The Living Room, four moves from the front door.** Its paragraph is a
    /// claim about two things that move — the rug PUSH RUG rolls aside, and
    /// the west door the cyclops breaks through from the far side — and it
    /// reported neither. One flag is `DungeonHouse`'s and the other
    /// `DungeonMaze`'s, which is why the sentence is the host's. (#329)
    @Test func theLivingRoomReadsTheRugAndTheDoorBesideIt() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.intoTheKitchen + ["west", "look", "push rug", "look"],
            seed: 18)

        let before = turnOutput(of: "look", in: transcript)
        #expect(before.contains("a large oriental rug in the center of the room"))
        #expect(before.contains("which appears to be nailed shut"))

        // The rug half, which is seven moves from a cold start.
        let after = transcript.components(separatedBy: "> look").last ?? ""
        #expect(after.contains("rolled back off the dusty cover of a trap door"))
        #expect(!after.contains("rug in the center of the room"))
    }

    /// And the west half, which needs the cyclops to have been through it. The
    /// Strange Passage on the far side has described the same door as holed
    /// since milestone 4, so the two sides of one door disagreed. (#329)
    @Test func theWoodenDoorReadsTheSameFromBothSidesOfIt() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.intoTheKitchen + ["west", "x wooden door", "east"]
                + Self.toTheCyclops.dropFirst(Self.intoTheKitchen.count)
                + ["odysseus", "north", "east", "look", "examine wooden door", "open wooden door"],
            seed: 18)

        // The far side's paragraph, which is the control: it has said this all
        // along, and it is what the near side was contradicting.
        #expect(transcript.contains("with a large hole in it (about cyclops sized)"))

        #expect(turnOutput(of: "x wooden door", in: transcript).contains("nailed fast"))

        let door = turnOutput(of: "examine wooden door", in: transcript)
        #expect(door.contains("most of the door gone from around them"))
        #expect(!door.contains("nailed fast"))

        let room = turnOutput(of: "look", in: transcript)
        #expect(room.contains("with a hole broken clean through it"))
        #expect(!room.contains("appears to be nailed shut"))

        #expect(
            turnOutput(of: "open wooden door", in: transcript)
                .contains("There is no door left to open"))
    }

    /// **The stair the cyclops was standing in front of.** Read one turn after
    /// he fled through the wall, with the parser already denying that he
    /// exists, the description was the room insisting on him. It reads the
    /// flag the `up` exit reads, so the two cannot disagree. (#329)
    @Test func theCyclopsStaircaseStopsAdvertisingHim() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheCyclops + ["x staircase", "odysseus", "examine stairs"],
            seed: 18)

        #expect(
            turnOutput(of: "x staircase", in: transcript)
                .contains("a cyclops in front of it more often than not"))

        let cleared = turnOutput(of: "examine stairs", in: transcript)
        #expect(cleared.contains("nothing on it now to argue the point"))
        #expect(!cleared.contains("more often than not"))
    }

    /// **The egg's clasp.** Only the thief ever gets it undone, which is why
    /// the constant outlived every test: the frame that falsifies it is a
    /// treasure handed to a man and taken back, with the listing beside it
    /// already printing what is inside. Both channels carried the clause and
    /// both are rules now. (#329)
    @Test func theEggSaysWhetherItsClaspIsStillDone() async throws {
        let transcript = try await play(
            Dungeon(),
            // The egg out of the tree, in at the window, and down to his lair.
            ["north", "north", "up", "take egg", "x egg", "down"]
                + ["east", "southwest", "open window", "west"] + Self.downTheTrapDoor
                + ["east"] + Array(repeating: "attack troll with sword", count: 3)
                + Self.trollRoomToTheHoard
                // Hand it over, step out of his reach, and let him work.
                + ["give egg to thief", "down"] + Array(repeating: "wait", count: 4)
                + ["up"] + Array(repeating: "attack thief with sword", count: 6)
                + ["take egg", "examine egg"],
            seed: 1)

        #expect(turnOutput(of: "x egg", in: transcript).contains("closed with a delicate looking clasp"))

        let opened = turnOutput(of: "examine egg", in: transcript)
        #expect(opened.contains("Its hinged lid stands open"))
        #expect(!opened.contains("closed with a delicate looking clasp"))
    }

    /// **The reservoir, read from the room that holds the bolt.** Its four
    /// neighbours have branched on `gatesOpen` since the sixth pass; the one
    /// item a player reads while standing at the control panel did not, so
    /// turning the bolt changed everything about the water except the sentence
    /// the turner was looking at. (#329)
    @Test func theReservoirSeenFromTheDamReadsTheBolt() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheDam
                + ["x reservoir"] + Array(Self.drainTheReservoir.dropLast(3))
                + ["examine reservoir"],
            seed: 18)

        #expect(turnOutput(of: "x reservoir", in: transcript).contains("a grey sheet reaching back"))

        let drained = turnOutput(of: "examine reservoir", in: transcript)
        #expect(drained.contains("a long streak of mud"))
        #expect(!drained.contains("grey sheet"))
    }

    /// **The Maintenance Room and the water in it.** The daemon calls each
    /// rung as the water reaches it and then stops; after it stops the room's
    /// own paragraph is the only channel left speaking, and it described a dry
    /// room to a player standing in it up to the hips — which is also the state
    /// that jams the button. And the water itself, which the room prints every
    /// turn and nothing answered to. (#329)
    @Test func theMaintenanceRoomStandsInTheWaterItLetIn() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheDam
                + ["north", "north", "push red button", "look", "push blue button"]
                + ["wait", "wait", "look", "x water"],
            seed: 18)

        // The control: dry, and no water paragraph at all.
        let dry = turnOutput(of: "look", in: transcript)
        #expect(dry.contains("this room has been ransacked recently"))
        #expect(!dry.contains("split pipe in the east wall"))

        let flooded = transcript.components(separatedBy: "> look").last ?? ""
        #expect(flooded.contains("Water bursts from the split pipe in the east wall"))
        #expect(flooded.contains("it stands up to your"))

        let water = turnOutput(of: "x water", in: transcript)
        #expect(water.contains("Cold, and still coming."))
        #expect(!water.contains("can't see any such thing"))
    }

    /// **The rusty box after the charge.** The Dusty Room's own paragraph has
    /// branched on the box's `isOpen` since milestone 6, twelve lines from the
    /// constant that did not: `x safe` called it intact and stronger than
    /// anything you carry while the listing beside it described the hole in it.
    /// (#329)
    @Test func theRustyBoxStopsBeingIntactAfterTheCharge() async throws {
        let transcript = try await play(
            Dungeon(),
            DungeonTests.toTheWideLedge + ["south", "x safe", "north"]
                + DungeonTests.lightTheCharge + ["south", "examine box"],
            seed: 18)

        #expect(turnOutput(of: "x safe", in: transcript).contains("still a great deal stronger"))

        let blown = turnOutput(of: "examine box", in: transcript)
        #expect(blown.contains("front peeled back off the stonework"))
        #expect(!blown.contains("still a great deal stronger"))
    }

    // MARK: - A listing line that prints on every look, forever

    /// **The thief, read for the first time.** `firstSight` is a static trait
    /// on an actor, and an actor's listing line prints on every look forever —
    /// so the turn after "The thief is battered into unconsciousness" the room
    /// went on standing him against a wall with his blade out, while the
    /// greeting rule two lines away already knew he could not hear. One reader
    /// of `isUnconscious` where two channels needed it. Seed 9: the second
    /// blow puts him down without killing him. (#329)
    @Test func theThiefsListingLineReadsWhetherHeIsStanding() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheHoard
                + ["attack thief with sword", "attack thief with sword"]
                + ["look", "thief, hello"],
            seed: 9)

        // On his feet — arriving in the lair lists him, and that line is the
        // trilogy's and is untouched.
        #expect(
            transcript.contains("There is a suspicious-looking individual, holding a large bag"))

        // Everything after the blow that put him down.
        let down = output(after: "battered into unconsciousness", in: transcript)
        #expect(down.contains("face down against the wall he was leaning on"))
        #expect(!down.contains("leaning against one wall. He is armed"))

        // The channel that always knew, printing beside the one that now does.
        #expect(
            turnOutput(of: "thief, hello", in: transcript)
                .contains("temporarily unable to hear anything at all"))
    }

    /// The troll had the identical fault and is not in the round's list — the
    /// charter met him standing up. His one constant served both channels and
    /// it claims he *blocks all passages*, which is not what a man face down in
    /// the dirt is doing, as his own greeting branch has known since #237.
    /// Seed 8: the first blow knocks him down instead of killing him. (#329)
    @Test func theTrollsListingLineReadsWhetherHeIsStanding() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.intoTheKitchen + Self.downTheTrapDoor
                + ["east", "attack troll with sword", "look", "x troll"],
            seed: 8)

        let down = output(after: "battered into unconsciousness", in: transcript)
        #expect(down.contains("face down in the dirt"))
        #expect(!down.contains("blocks all passages"))
        #expect(turnOutput(of: "x troll", in: transcript).contains("every way out of the room clear"))

        // The control, from a run in which he stays on his feet: the listing
        // line is the one both sources print, and it is unchanged.
        let standing = try await play(
            Dungeon(), Self.intoTheKitchen + Self.downTheTrapDoor + ["east"], seed: 18)
        #expect(standing.contains("brandishing a bloody axe, blocks all passages"))
    }

    /// **The balloon's paragraph is its state**, and `board` marks it touched —
    /// so from the first time anybody climbed in, an inflated burning balloon
    /// and a cold deflated one printed the same stock sentence. The rule was
    /// right all along; the channel was gated. `alwaysListed` is the opt-out,
    /// and it is the item-side twin of `alwaysDescribed`. (#329)
    @Test func theBalloonKeepsReportingItsBagAndItsFire() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.strandedOnTheWideLedge + ["look"],
            seed: 18)

        // The basket has been boarded and left, so `touched` is set and the
        // stock sentence is what the room used to fall back to. The last
        // heading in the transcript is the LOOK after stepping out.
        let listing = try #require(transcript.components(separatedBy: "Wide Ledge").last)
        #expect(listing.contains("The cloth bag over it is inflated"))
        #expect(listing.contains("is burning"))
        #expect(!listing.contains("There is a wicker basket here."))
    }

    /// **The bag says it is empty while it is holding the balloon up.** Both
    /// its examine text and its `search` reply were constants: *"big enough to
    /// swallow the basket twice over when there is anything in it"* and *"It
    /// doesn't appear that there's anything inside."* — printed with the bag
    /// swollen taut and a burning fuel in the receptacle beneath it. The flag
    /// was already there, and the two rules next door already read it. (#332)
    ///
    /// Neither line is the source's: `CBAG` carries no description at all and
    /// `BCONTENTS` (`act2.92:574`) answers TAKE, FIND and EXAMINE alike with
    /// *"part of the basket"*, so both sentences are this project's own.
    @Test func theClothBagStopsCallingItselfEmptyWhileItIsInflated() async throws {
        // Aboard, on the way up: the bag is holding the basket in the air.
        let inflated = try await play(
            Dungeon(),
            DungeonTests.toTheWideLedge + ["examine cloth bag", "search cloth bag"],
            seed: 18)

        let examined = turnOutput(of: "examine cloth bag", in: inflated)
        #expect(!examined.contains("when there is anything in it"))
        #expect(examined.contains("swollen taut with hot air"))

        let searched = turnOutput(of: "search cloth bag", in: inflated)
        #expect(!searched.contains("doesn't appear that there's anything inside"))
        #expect(searched.contains("Hot air"))

        // The positive control: on the ground with no fire lit, both lines
        // still say what they always said.
        let slack = try await play(
            Dungeon(),
            DungeonTests.toTheVolcano + ["examine cloth bag", "search cloth bag"],
            seed: 18)
        #expect(turnOutput(of: "examine cloth bag", in: slack).contains("slack over the side"))
        #expect(
            turnOutput(of: "search cloth bag", in: slack)
                .contains("doesn't appear that there's anything inside"))
    }

    /// **The stub floor told the player that food is not food.** `eat garlic`
    /// answered *"The clove of garlic is not something you could eat"* — of the
    /// clove that answers the bat — and `eat lunch` said the same of the hot
    /// pepper sandwich that puts the cyclops to sleep. Both carry `FOODBIT` in
    /// the source (`dung.355:4289`, `:4655`).
    ///
    /// Two repairs, and the file's own rule (`Prose+Stubs.swift`) picks them:
    /// a game-wide line may be a claim about the player but not about the
    /// thing named, so the floor line stops ruling on the object; and the two
    /// items that really are food answer for themselves. (#332)
    @Test func theFoodStopsBeingToldThatItIsNotFood() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.intoTheKitchen
                + ["open sack", "take garlic", "take lunch"]
                + ["eat garlic", "eat lunch", "eat bottle"],
            seed: 41)

        for command in ["eat garlic", "eat lunch", "eat bottle"] {
            #expect(!turnOutput(of: command, in: transcript).contains("not something you could eat"))
        }
        #expect(turnOutput(of: "eat garlic", in: transcript).contains("not that hungry"))
        #expect(turnOutput(of: "eat lunch", in: transcript).contains("Hot peppers"))
        // The positive control: something that genuinely is not food still
        // gets an answer, and it is about the player rather than the bottle.
        #expect(turnOutput(of: "eat bottle", in: transcript).contains("no appetite"))
    }

    // MARK: - Nouns the prose prints and the parser denied

    /// **The Gallery says "vandals" twice in three sentences** and the
    /// painting's own listing line says it a third time, and the parser did not
    /// know the word — the round's one game-printed *"I don't know the word"*,
    /// which is the harsher of the two failures. Not a synonym on the painting:
    /// the vandals are the people who took the others. (#329)
    @Test func theGallerysVandalsAndItsExitsAnswer() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.intoTheKitchen + Self.downTheTrapDoor
                + ["south", "south", "x vandals", "x exits", "x painting"],
            seed: 18)

        #expect(transcript.contains("stolen by vandals with exceptional taste"))
        #expect(turnOutput(of: "x vandals", in: transcript).contains("Long gone, and thorough"))
        #expect(turnOutput(of: "x exits", in: transcript).contains("Three ways out"))
        // The control: the painting still answers to its own nouns.
        #expect(turnOutput(of: "x painting", in: transcript).contains("A masterpiece"))
        expectEveryNounAnswered(transcript, "The Gallery's vandals and exits.")
    }

    /// **The shaft is the hole the chain hangs in**, and both chains carried
    /// `shaft` as a synonym — so `x shaft`, in the room whose name is the word,
    /// answered with a sentence about the ironmongery over it. #233 taught that
    /// one object seen from two ends is two items; this is two objects wearing
    /// one noun, which is the other half of it. (#329)
    @Test func theShaftIsNotTheChainHangingInIt() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheSmellyRoom.dropLast(2) + ["x shaft", "x chain", "x framework"],
            seed: 18)

        let shaft = turnOutput(of: "x shaft", in: transcript)
        #expect(shaft.contains("wide enough for the basket"))
        #expect(!shaft.contains("with a basket made fast to the end of it"))

        // The controls: the chain still answers to both its own words.
        #expect(turnOutput(of: "x chain", in: transcript).contains("running over the framework"))
        #expect(turnOutput(of: "x framework", in: transcript).contains("running over the framework"))
    }

    /// **Reservoir South's third sentence names a steep path climbing along
    /// the edge of a cliff**, and both nouns went to the reservoir — a sentence
    /// about the water, which is in the other direction. The path is also the
    /// `up` exit to Deep Canyon, so it is a way through as well as a noun.
    /// (#329)
    @Test func theCliffAtReservoirSouthIsNotTheReservoir() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheDam + ["south", "northwest", "x cliff", "x path", "x reservoir"],
            seed: 18)

        #expect(transcript.contains("a steep path climbing up along the edge of a cliff"))

        let cliff = turnOutput(of: "x cliff", in: transcript)
        #expect(cliff.contains("climbs the cliff at the room's south edge"))
        #expect(!cliff.contains("depends entirely on what the bolt"))

        #expect(turnOutput(of: "x path", in: transcript).contains("out of sight"))
        // The control: the water still answers about the water.
        #expect(
            turnOutput(of: "x reservoir", in: transcript)
                .contains("depends entirely on what the bolt"))
    }

    // MARK: - Stock lines in frames the game could not re-skin them out of

    /// **`launch` beside the balloon named a boat.** LAUNCH is a word for the
    /// balloon as well as for the magic boat, and standing on the ledge with
    /// the basket in front of you the refusal was "You're not in the boat!" —
    /// about a boat several hundred moves and one river away, which the player
    /// may never have found. `landNoBoat` one rule below has always been
    /// vehicle-neutral and is the model this line should have followed. (#329)
    @Test func launchBesideTheBalloonDoesNotNameABoat() async throws {
        let transcript = try await play(
            Dungeon(), Self.strandedOnTheWideLedge + ["launch"], seed: 18)

        let refusal = turnOutput(of: "launch", in: transcript)
        #expect(refusal.contains("standing beside the basket and not in it"))
        #expect(!refusal.contains("You're not in the boat!"))
    }

    /// And the third branch, which was declared and wired to nothing: away
    /// from both vehicles, LAUNCH has nothing to be about.
    @Test func launchWithNothingToLaunchSaysSo() async throws {
        let transcript = try await play(Dungeon(), ["launch"], seed: 18)

        let refusal = turnOutput(of: "launch", in: transcript)
        #expect(refusal.contains("You have nothing here that floats."))
        #expect(!refusal.contains("You're not in the boat!"))
    }

    /// **A second `light match` fell through to the engine's switch language**
    /// — "It's already on.", about a matchbook. The rule *returned* instead of
    /// refusing, so the turn reached `turnOn`'s own complaint. `alreadyOn`
    /// takes no subject, so no re-skinning could have fixed it here without
    /// lying about the lantern, the candles and the torch. (#329)
    @Test func aSecondMatchIsRefusedInTheGamesVoice() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.toTheDam + ["north", "take matchbook", "light match", "light match"],
            seed: 18)

        #expect(turnOutput(of: "light match", in: transcript).contains("One of the matches starts to burn."))

        let second = output(after: "One of the matches starts to burn.", in: transcript)
        #expect(second.contains("You already have a match burning."))
        #expect(!second.contains("It's already on."))
    }

    /// **`search trunk` found nothing of interest in a trunk bulging with
    /// jewels.** That is the documented stock `.lookIn` path for anything not
    /// declared a `container`, and the trait is not the answer here: a
    /// container trunk could be neither opened nor closed, `put` would make it
    /// a bottomless sack with a treasure value on it, and an empty one would
    /// answer that it was empty. The trunk answers for itself instead. (#329)
    @Test func searchingTheTrunkFindsTheJewelsItIsBulgingWith() async throws {
        let transcript = try await play(
            Dungeon(), Self.toTheReservoirShore + ["north", "search trunk"], seed: 18)

        #expect(transcript.contains("bulging with jewels"))

        let searched = turnOutput(of: "search trunk", in: transcript)
        #expect(searched.contains("Under them are more jewels"))
        #expect(!searched.contains("nothing of interest"))
    }

    /// **Turning the lamp off printed the darkness twice.**
    /// `sayOnceThisTurn` dedupes on the exact text and on nothing else, and
    /// this game pointed `nowDark` at one sentence while `pitchBlack` and the
    /// grue's own warning said another — so *walking into* a dark room printed
    /// one line and *dousing the lamp* printed two, back to back, saying the
    /// same thing. The dark is the same dark either way. (#329)
    @Test func theDoubledDarknessSentenceIsOneSentence() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.intoTheKitchen + Self.downTheTrapDoor + ["turn off lamp"],
            seed: 18)

        let doused = turnOutput(of: "turn off lamp", in: transcript)
        #expect(doused.contains("It is pitch black. You are likely to be eaten by a grue."))
        #expect(!doused.contains("It is now pitch black."))

        // Said once, not twice: the count is the whole assertion.
        #expect(occurrences(of: "It is pitch black", in: doused) == 1)
    }

    /// And the control, one door along: walking into the dark says the same
    /// sentence, once, exactly as it always did.
    @Test func walkingIntoTheDarkSaysTheSameSentenceOnce() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.intoTheKitchen + ["west", "push rug", "open trap door", "down"],
            seed: 18)

        let arrived = turnOutput(of: "down", in: transcript)
        #expect(arrived.contains("It is pitch black. You are likely to be eaten by a grue."))
        #expect(occurrences(of: "It is pitch black", in: arrived) == 1)
    }

    // MARK: - The volcano's air half, and the chute

    /// **Paying the gnome opens a west door out of whichever ledge he was paid
    /// on, and the Wide Ledge's paragraph named only the door to the south.**
    /// The Narrow Ledge got this repair in the first round; this ledge had
    /// never been stood on by a charter. Paying him is the whole of how a
    /// stranded player gets down, and the room unsaid it. (#329)
    @Test func theWideLedgeCountsTheDoorTheGnomePaidFor() async throws {
        let transcript = try await play(
            Dungeon(),
            // Stepping out of an untied basket strands the player, which is
            // what starts his clock; the charge buys the one treasure on this
            // ledge to pay him with, and the two races — his ten turns and the
            // ledge's thirteen — leave exactly enough room.
            Self.strandedOnTheWideLedge + Array(DungeonTests.lightTheCharge.dropFirst())
                + ["south", "take crown", "north", "wait", "give crown to gnome", "look"],
            seed: 18)

        // The control: before the fee, one exit and it is the south door.
        #expect(transcript.contains("There is a small door to the south."))
        #expect(transcript.contains("a door appears on the west end of the ledge"))

        let paid = output(after: "The gnome moves quickly", in: transcript)
        #expect(paid.contains("A door stands open at the west end of the ledge"))
        #expect(paid.contains("narrow chimney beyond it sloping steeply down"))
    }

    /// **The rope in the chute, which is the one thing holding the player up.**
    /// `rigTheChute()` set a flag and never moved the coil, so the rope was in
    /// the Slide Room and the player was three rooms below it: `x rope`
    /// answered "You can't see any such thing." under a paragraph beginning
    /// "You are hanging on a rope." Five fittings now, one per room the rope is
    /// in — the `ropeOnTheRailing` shape at the other knot. (#329)
    @Test func theRopeInTheChuteAnswersToTheWordTheRoomPrints() async throws {
        let transcript = try await play(
            Dungeon(),
            DungeonTests.toTheChuteWithTheTimber
                + ["drop timber", "tie rope to timber", "x rope", "down", "x rope", "x chute"],
            seed: 18)

        #expect(transcript.contains("You are hanging on a rope in a chute of sheet metal"))

        // At the head of the chute, where the knot is.
        #expect(turnOutput(of: "x rope", in: transcript).contains("made fast here"))

        // And in the chute, where it is load-bearing.
        let below = output(after: "You are hanging on a rope", in: transcript)
        #expect(below.contains("Stout hemp, taut under your weight"))
        #expect(!below.contains("can\u{27}t see any such thing"))

        // The control: the chute's own scenery still answers, as it always did.
        #expect(turnOutput(of: "x chute", in: transcript).contains("Sheet metal"))
    }

    /// **The Wide Ledge watched the balloon climb away over its head, and was
    /// then told about the tear as a sound in the distance.** `rise(_:…)` is
    /// handed a `watched` flag and re-derived a narrower answer —
    /// `player.location == volcanoBottom` — which is true in one of the four
    /// rooms that can see the shaft. It is three-way now, because the wreck
    /// lands on the volcano floor and "by your feet" is a claim about a place.
    /// (#329)
    @Test func theBalloonWreckIsReadFromWhereItIsWatched() async throws {
        let transcript = try await play(
            Dungeon(),
            Self.strandedOnTheWideLedge + Array(repeating: "wait", count: 10),
            seed: 18)

        expectInOrder(
            transcript,
            [
                "You watch as the balloon slowly floats away",
                "what is left of it falls past the ledge",
            ])
        // Not heard at a distance, by a room that had just watched it go.
        #expect(!transcript.contains("You hear a distant tearing sound"))
        // And not the floor's line, which is true only on the floor.
        #expect(!transcript.contains("lands on the ground by your feet"))
    }

    /// And the control, from the one room where "by your feet" is true.
    @Test func theBalloonWreckLandsAtTheFeetOfSomebodyOnTheFloor() async throws {
        let transcript = try await play(
            Dungeon(),
            // Light it, step straight back out on the volcano floor, and
            // watch the whole flight from under it.
            DungeonTests.toTheVolcano
                + Array(DungeonTests.liftOff.prefix(4)) + ["get out"]
                + Array(repeating: "wait", count: 16),
            seed: 18)

        #expect(transcript.contains("lands on the ground by your feet"))
        #expect(!transcript.contains("falls past the ledge"))
    }

    /// **"The torch is burning." on the turn after "The water level here is
    /// now high in your lungs."** Two consecutive lines, one of which is a
    /// flame and the other of which is a drowning.
    ///
    /// The **mechanic** does not move here, and that is a decision rather than
    /// an oversight: dousing the torch would take a fourteen-point treasure out
    /// of a game with no way to relight it, which is a scoring change, and the
    /// room kills the reader either way one turn later. What the sentence stops
    /// doing is reporting an ordinary flame in a frame where a flame is not
    /// ordinary — and the mainframe's torch is a supernatural object, the one
    /// light in the game that needs no tending, so naming that is fidelity
    /// rather than a dodge.
    ///
    /// The state it reads is `DungeonDam`'s flood level and the torch is a
    /// `DungeonTemple` item, so both of its channels are the host's. (#329)
    @Test func theTorchSaysWhereItIsBurning() async throws {
        let transcript = try await play(
            Dungeon(),
            DungeonTests.fetchTheTorch + ["x torch"]
                // The Troll Room, the crossroads, the dam, and down into the
                // Maintenance Room to break the pipe.
                + ["east"] + Self.crossroadsToTheDam
                + ["north", "north", "push blue button"]
                + Array(repeating: "wait", count: 7)
                + ["examine torch"],
            seed: 18)

        // The control, in the room it was made for.
        #expect(turnOutput(of: "x torch", in: transcript).contains("The torch is burning."))

        expectInOrder(
            transcript,
            [
                "The water level here is now over your head.",
                "burning under water, which it has no business doing",
            ])
        let drowning = turnOutput(of: "examine torch", in: transcript)
        #expect(!drowning.hasPrefix("The torch is burning."))
    }

    /// Pinned against the real prose rather than a fixture, because the defect
    /// was that the engine and the game disagreed about which of the two this
    /// text is.
    @Test func theGamesFormsKeepTheirShapeInTheFullScreenRenderer() {
        let ring = TextWrap.wrap(Prose.etchingsAbove, width: 80)
        #expect(ring.contains("    f r o b o z z i c a"))
        #expect(ring.contains("    l    M A G I C    d"))

        let verse = TextWrap.wrap(Prose.riddleInscription, width: 80)
        #expect(verse.contains("    No one passes who cannot say"))
        #expect(verse.contains("    and cannot be drawn up"))

        let gate = TextWrap.wrap(Prose.entranceToHades, width: 80)
        #expect(gate.contains("  Abandon every hope"))
        #expect(gate.contains("  all ye who enter here!"))

        // The prose around a form is still prose: the sentence introducing the
        // gate is folded and re-packed the way every other paragraph is.
        #expect(gate.contains("You are outside a large gateway, on which is inscribed"))

        // The black book's marked page is the fourth, added with the page
        // itself (#286): the commandment on it is verse and keeps its line
        // endings, and the two sentences around it are packed.
        let page = TextWrap.wrap(Prose.blackBookPage, width: 80)
        #expect(page.contains("  Commandment #12593"))
        #expect(page.contains("  Ye who are dead and will not lie down,"))
        #expect(page.contains("  And thou art not the keeper of it."))
        #expect(page.contains("The rest of the book is a great deal less specific."))
    }
}
