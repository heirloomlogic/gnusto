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

    /// The descent with the troll cut down at the end of it. Seed 11 throughout,
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
    /// northern Mirror Room. Seed 11.
    private static let toTheMirrors =
        pastTheTroll + ["drop sword"] + crossroadsToTheDam
        + ["north", "north", "push yellow button", "take wrench", "south", "south"]
        + ["turn bolt with wrench", "drop wrench", "south", "northwest"]
        + ["north", "north", "north", "up", "north"]

    /// The road to the tea party, and on to the three buttons. Seed 10
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
            seed: 11)

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
            seed: 11)

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
            seed: 11)

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
            seed: 11)

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
            seed: 11)

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
            seed: 10)

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
            seed: 11)

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
            seed: 11)

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
            seed: 11)

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
            seed: 10)

        #expect(transcript.contains("Safety Depository"))
        let inDepository = turnOutput(of: "x curtain", in: transcript)
        #expect(inDepository.contains("hanging where the north wall ought to be"))
        let inViewingRoom = turnOutput(of: "examine curtain", in: transcript)
        #expect(inViewingRoom.contains("hanging across one side of the room"))
        #expect(!inViewingRoom.contains("where the north wall ought to be"))
    }
}
