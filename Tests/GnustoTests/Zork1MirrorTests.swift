import Foundation
import Gnusto
import GnustoTestSupport
import Testing

@testable import Zork1

/// End-to-end playthroughs of the Phase 10.7 Mirror Rooms region: the two Mirror
/// Rooms joined by touching their mirrors, the crystal trident in the drowned
/// Atlantis Room, the one-way slide down to the Cellar, and the passages that
/// finally knot the underground into a single graph — linking the Round Room
/// hub, the reservoir, and the temple's Tiny Cave.
///
/// Seed 39, re-pin expected in T14: these routes kill the troll to reach the hub
/// (the same recorded three-blow kill the Round Room and Dam suites use). Past
/// the Round Room the thief stays penned in the cellar, and the mirror region
/// itself draws no randomness — its teleport is deterministic.
struct Zork1MirrorTests {
    /// Enter the house, gear up (sword, lit lantern), kill the troll, and press
    /// east into the Round Room hub — no rope, so seed 39 lands the kill exactly
    /// as the Dam suite records it.
    private static let toRoundRoom: [String] = [
        "south", "east", "open window", "west", "west",
        "take sword", "take lantern", "turn on lantern",
        "push rug", "open trap door", "down",
        "north", "west",
        "attack troll", "attack troll", "attack troll",
        "east", "east",  // → East-West Passage → Round Room
    ]

    /// From the Round Room, south through the Narrow Passage into the northern
    /// Mirror Room — the lit one.
    private static let toMirrorRoom: [String] =
        toRoundRoom + ["south", "south"]

    /// Touching a mirror whisks you to the other Mirror Room and back. The two
    /// rooms share a name, so the round-trip is proved by the distinctive rooms
    /// each side reaches: the Atlantis Room (down past the Small Cave) lies only
    /// off the southern room, the Narrow Passage only off the northern one.
    @Test func touchingTheMirrorSwapsRoomsAndBack() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toMirrorRoom + [
                "touch mirror",  // → southern Mirror Room
                "east", "down",  // Small Cave → Atlantis Room (the south side only)
                "up", "north",  // Small Cave → southern Mirror Room
                "touch mirror",  // → northern Mirror Room
                "north",  // Narrow Passage (the north side only)
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "Narrow Passage",
                "Mirror Room",
                "rumble sounds from deep",  // the first touch
                "Atlantis Room",  // proves it landed on the south side
                "rumble sounds from deep",  // the second touch
                "Narrow Passage",  // proves it returned to the north side
            ])
    }

    /// The metal slide is a one-way chute: there is no climbing back up it, and
    /// stepping down drops you into the Cellar, deep in the house's territory.
    @Test func theSlideDropsOneWayIntoTheCellar() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toMirrorRoom + [
                "touch mirror",  // → southern Mirror Room
                "north",  // Cold Passage
                "west",  // Slide Room
                "up",  // there is no way back up the slide
                "down",  // the chute drops you into the Cellar
                "north",  // Troll Room — we really are back in the cellar region
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "Slide Room",
                "You can't go that way.",  // no up exit out of the slide
                "Cellar",
                "Troll Room",
            ])
    }

    /// The crystal trident lies in the Atlantis Room; taking it scores four on
    /// the find (the original's VALUE 4), on top of the forty already banked
    /// (kitchen 10, cellar 25, East-West Passage 5).
    @Test func theCrystalTridentScoresOnTheFind() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toMirrorRoom + [
                "touch mirror",  // → southern Mirror Room
                "east", "down",  // Small Cave → Atlantis Room
                "take trident",
                "score",
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "Atlantis Room",
                "Taken.",  // the trident comes free (+4 on the find)
                "Your score is 44 of a possible 350",
            ])
    }

    /// The region is the map's keystone: from the Round Room hub it reaches the
    /// temple's Tiny Cave one way (through the Winding Passage) and the dam's
    /// Reservoir North the other (down past Atlantis), so the underground now
    /// reads as one connected graph.
    @Test func theRegionKnotsTheUndergroundIntoOneGraph() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toMirrorRoom + [
                "west",  // Winding Passage
                "east",  // Cave — the temple's Tiny Cave, reconnected
                "north",  // back to the northern Mirror Room
                "touch mirror",  // → southern Mirror Room
                "east", "down",  // Small Cave → Atlantis Room
                "south",  // Reservoir North — into the dam region
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "Narrow Passage",
                "Mirror Room",
                "Winding Passage",
                "Cave",  // the temple's Tiny Cave — the complex reconnects here
                "Mirror Room",
                "Atlantis Room",
                "Reservoir North",  // and on into the dam region
            ])
    }
}
