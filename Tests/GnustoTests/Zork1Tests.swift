import Foundation
import Gnusto
import Testing

@testable import Zork1

/// End-to-end playthroughs of the Task 8 White House slice: the mailbox,
/// the kitchen window, the rug/trap-door pair, the tree/egg/trophy-case
/// chain, and the leaves/grating pair, plus a full-slice smoke walk.
struct Zork1Tests {
    @Test func openingTheMailboxRevealsAndReadsTheLeaflet() async throws {
        let transcript = try await play(
            Zork1(),
            ["open mailbox", "read leaflet", "close mailbox"])

        expectInOrder(
            transcript,
            [
                "Opening the small mailbox reveals a leaflet.",
                "A leaflet sits inside, waiting to be read.",
                "A single typed page",
                "Closed.",
            ])
    }

    @Test func kitchenWindowOpensIntoTheHouseButTheFrontDoorRefuses() async throws {
        let transcript = try await play(
            Zork1(),
            ["open front door", "south", "east", "open window", "west"])

        expectInOrder(
            transcript,
            [
                "The door is boarded shut and won't budge.",
                "South of House",
                "Behind House",
                "Opened.",
                "Kitchen",
            ])
    }

    /// The Phase-5 dark-cellar soft-lock is closed: with the brass lantern
    /// lit, the trap door's slam is an inconvenience, not a prison. The full
    /// loop — Cellar → East of Chasm → Gallery (painting) → Studio → up the
    /// chimney into the Kitchen — runs by lantern light, exercising the
    /// reveal-on-descent, the lit `dark`-trait rooms, and the one-way
    /// chimney in a single walk.
    @Test func cellarLoopByLanternLight() async throws {
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west", "west",
                "take lantern", "turn on lantern",
                "push rug", "open trap door", "down",
                "south", "east", "take painting", "north", "up",
            ])

        expectInOrder(
            transcript,
            [
                "Living Room",
                "Taken.",
                "The brass lantern is now on.",
                "Dragging the rug aside reveals a trap door beneath it.",
                "Opened.",
                "The trap door swings shut, and you hear a bolt slide home above you.",
                "Cellar",
                "East of Chasm",
                "Gallery",
                "Taken.",
                "Studio",
                "Kitchen",
            ])
        // The lit cellar is a described room now, never pitch black.
        #expect(!transcript.contains("It is pitch black."))
    }

    /// The other way out of the sealed cellar: a lightless dash to the lit
    /// Gallery and up the chimney. The dark rooms stay pitch black; the
    /// exits still work.
    @Test func chimneyEscapeInTheDark() async throws {
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west", "west",
                "push rug", "open trap door", "down",
                "south", "east", "north", "up",
            ])

        expectInOrder(
            transcript,
            [
                "The trap door swings shut, and you hear a bolt slide home above you.",
                "It is pitch black. You can't see a thing.",
                "Gallery",
                "Kitchen",
            ])
    }

    /// The lantern's fuel is a pair of fuses: a dim warning, then darkness —
    /// and turning the lantern off pauses the clock (no fuel burns while
    /// it's off).
    @Test func lanternBurnsOut() async throws {
        let fillers = Array(repeating: "look", count: 18)
        let transcript = try await play(
            Zork1(),
            ["south", "east", "open window", "west", "west", "take lantern", "turn on lantern"]
                + fillers
                + ["look", "look", "look", "look", "look", "look", "turn on lantern"])
        // The turn-on turn ticks 20→19; the 19th look reaches zero.
        let looks = transcript.components(separatedBy: "> look")
        #expect(!looks[18].contains("flame inside the lantern shrinks"))
        #expect(looks[19].contains("flame inside the lantern shrinks"))
        // Five looks later the lantern dies for good.
        #expect(looks[24].contains("The brass lantern flickers and goes out"))
        // Spent is spent.
        let relights = transcript.components(separatedBy: "> turn on lantern")
        #expect(relights[2].contains("burned out"))
    }

    @Test func turningTheLanternOffPausesTheFuel() async throws {
        let burn18 = Array(repeating: "look", count: 18)
        let transcript = try await play(
            Zork1(),
            ["south", "east", "open window", "west", "west", "take lantern", "turn on lantern"]
                + burn18
                + ["turn off lantern", "look", "look", "look", "turn on lantern"])
        // 18 looks burned the dim fuse to 1; three dark-lantern turns cost
        // nothing; relighting restarts it at 1, so it fires at the end of
        // the relight turn itself.
        let off = turnOutput(of: "turn off lantern", in: transcript)
        #expect(!off.contains("flame inside the lantern shrinks"))
        let looks = transcript.components(separatedBy: "> look")
        #expect(!looks[19].contains("flame inside the lantern shrinks"))
        let lastDarkLook = looks[21].prefix(while: { $0 != ">" })
        #expect(!lastDarkLook.contains("flame inside the lantern shrinks"))
        let relight = transcript.components(separatedBy: "> turn on lantern")[2]
        #expect(relight.contains("The brass lantern is now on."))
        #expect(relight.contains("flame inside the lantern shrinks"))
    }

    @Test func treeEggAndTrophyCase() async throws {
        // West of House → North of House → Forest Path → Up a Tree, takes
        // the egg, climbs back down, crosses to the Living Room via the
        // kitchen window, and stows the egg in the (now open) trophy case —
        // whose closure description reflects the change live.
        let transcript = try await play(
            Zork1(),
            [
                "north", "north", "up", "take egg", "down",
                "south", "west", "south", "east", "open window", "west", "west",
                "open trophy case", "put egg in trophy case", "examine trophy case",
            ])

        expectInOrder(
            transcript,
            [
                "Up a Tree",
                "On the nest is a jewel-encrusted egg.",
                "Taken.",
                "Forest Path",
                "Living Room",
                "Opened.",
                "You put the jewel-encrusted egg in the trophy case.",
                "A glass-fronted trophy case, holding a jewel-encrusted egg.",
            ])
    }

    @Test func leavesRevealTheLockedGrating() async throws {
        let transcript = try await play(
            Zork1(),
            ["north", "north", "north", "move leaves", "open grating"])

        expectInOrder(
            transcript,
            [
                "Clearing",
                "Underneath the leaves, a metal grating is revealed.",
                "The iron grating is locked.",
            ])
    }

    /// Touches every room in the slice exactly once each (some legs revisit
    /// a room in transit — this only asserts each name appears at least once
    /// in the expected order), confirming the whole map hangs together end
    /// to end: the house exterior ring, the forest and clearings, the
    /// (now two-way, see FIDELITY.md) canyon, the tree, and the house
    /// interior down to the cellar.
    @Test func fullSliceSmokeWalk() async throws {
        let transcript = try await play(
            Zork1(),
            [
                "north", "east", "south", "west", "west", "north", "north",
                "east", "south", "east", "south", "southeast", "down", "down",
                "north", "south", "up", "up", "northwest", "west", "north",
                "north", "up", "down", "south", "east", "open window", "west",
                "up", "down", "west", "push rug", "open trap door", "down",
            ])

        expectInOrder(
            transcript,
            [
                "West of House",
                "North of House",
                "Behind House",
                "South of House",
                "Forest",
                "Forest Path",
                "Clearing",
                "Clearing",
                "Forest",
                "Forest",
                "Canyon View",
                "Rocky Ledge",
                "Canyon Bottom",
                "End of Rainbow",
                "Canyon Bottom",
                "Rocky Ledge",
                "Canyon View",
                "Forest",
                "Behind House",
                "North of House",
                "Forest Path",
                "Up a Tree",
                "Forest Path",
                "North of House",
                "Behind House",
                "Opened.",
                "Kitchen",
                "Attic",
                "Kitchen",
                "Living Room",
                "Dragging the rug aside reveals a trap door beneath it.",
                "Opened.",
                "The trap door swings shut, and you hear a bolt slide home above you.",
                "It is pitch black. You can't see a thing.",
            ])
    }

    /// Phase 6 on the slice: "take all"/"drop all" with labeled lines, the
    /// pronoun "it" through a container, and the reach/see distinction —
    /// water is visible through the closed glass bottle but not takable.
    @Test func kitchenSweepWithAllAndPronouns() async throws {
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west",
                "take all",
                "drop all",
                "take bottle", "open it", "look in it",
                "west",
                "take all",
                "inventory",
            ])
        expectInOrder(
            transcript,
            [
                "Kitchen",
                // take all: name-sorted, per-object results; the scenery
                // window is skipped, and the water — visible through the
                // shut glass — refuses with "can't reach", not "can't see".
                "brown sack: Taken.",
                "clove of garlic: Taken.",
                "glass bottle: Taken.",
                "lunch: Taken.",
                "quantity of water: You can't reach the quantity of water.",
                // drop all: everything just taken goes back down.
                "brown sack: Dropped.",
                "clove of garlic: Dropped.",
                "glass bottle: Dropped.",
                "lunch: Dropped.",
                // "it" rides along from "take bottle".
                "Opening the glass bottle reveals a quantity of water.",
                "In the glass bottle is a quantity of water.",
                // Living room: the scenery rug, trophy case, and the still
                // hidden trap door are all skipped by "all".
                "Living Room",
                "brass lantern: Taken.",
                "elvish sword: Taken.",
                "You are carrying:",
                "brass lantern",
                "elvish sword",
            ])
        #expect(!transcript.contains("window: "))
        #expect(!transcript.contains("trap door: "))
        #expect(!transcript.contains("trophy case: Taken."))
    }
}
