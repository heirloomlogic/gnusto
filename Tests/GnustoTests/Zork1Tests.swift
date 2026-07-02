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

    /// Documented Phase 7 seam, not a bug: a solo player who descends the
    /// trap door without a light source is genuinely stuck in the cellar,
    /// full stop, until Phase 7 lands light sources (a lit lantern) and the
    /// grue. See the "Known soft-lock" entry in `FIDELITY.md` for the full
    /// causal explanation — in short, `cellar.onEnter`
    /// (`Sources/Zork1/House.swift`) slams the trap door shut on entry, the
    /// cellar is `dark`, and the single early-return dark guard in
    /// `Visibility.collect` (`Sources/Gnusto/Engine/Visibility.swift`) skips
    /// both the room-contents walk and the door-folding loop, so the trap
    /// door never becomes a resolvable noun from inside. Nothing in this
    /// slice can reopen it from below.
    ///
    /// This test pins that current behavior end to end so a future engine
    /// change (Phase 7) has to touch this assertion deliberately rather
    /// than silently regress it: the slam, `up` refusing while the door is
    /// closed, `open trap door` failing to resolve at all, and a further
    /// `look` still reporting pitch black rather than a room — i.e. no
    /// other command escapes either.
    @Test func darkCellarSoftLockIsThePhase7Seam() async throws {
        // Reaches the Living Room via the kitchen window, then exercises the
        // Task 4 push-to-reveal pattern on the rug, opens the newly revealed
        // trap door, and descends into the (dark, stubbed) cellar — where
        // the trap door slams shut behind the player, the classic moment.
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west", "west",
                "push rug", "open trap door", "down", "up", "open trap door", "look",
            ])

        expectInOrder(
            transcript,
            [
                "Living Room",
                "Dragging the rug aside reveals a trap door beneath it.",
                "Opened.",
                "The trap door swings shut, and you hear a bolt slide home above you.",
                "It is pitch black. You can't see a thing.",
                // `up` while the door is still closed: refused.
                "The trap door is closed.",
            ])

        // `open trap door`, attempted from inside the dark cellar: a dark
        // room's scope collapses entirely (one early-return guard in
        // `Visibility.collect` skips both the room-contents walk and the
        // door-folding loop), so the door isn't even resolvable as a noun
        // from in here — a real engine/content interaction, documented in
        // FIDELITY.md, not an oversight in this test. The parser reports it
        // can't see the door at all, rather than a `refuse`-level "it's
        // locked"/"it's dark" message.
        expectInOrder(transcript, ["You can't see any such thing."])

        // No further escape: `look` from inside the sealed, dark cellar
        // still reports pitch black rather than a room description — the
        // soft-lock holds under repeated attempts, not just the first one.
        #expect(transcript.hasSuffix("It is pitch black. You can't see a thing.\n\n"))
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
}
