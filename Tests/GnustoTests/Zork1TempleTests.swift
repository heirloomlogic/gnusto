import Foundation
import Gnusto
import GnustoTestSupport
import Testing

@testable import Zork1

/// End-to-end playthroughs of the Phase 10.6 Temple & Hades region: the Dome
/// Room's rope descent, the ivory torch, the gold coffin and its PRAY egress,
/// the draughty cave, and the full exorcism ritual (ring bell → light candles →
/// read book) that opens the Land of the Dead.
///
/// Every route kills the troll first (the only way east to the hub). Seed 0,
/// re-pin expected in T14: grabbing the attic rope shifts the RNG stream, so
/// this suite needs its own seed to still land the three-blow kill. Past the
/// Round Room the thief stays penned in the cellar, so the temple itself draws
/// no randomness — the region's mechanics are all deterministic.
struct Zork1TempleTests {
    /// Enter the house, take the sword, lantern (lit), and the attic rope, kill
    /// the troll, and press east into the Round Room.
    private static let toRoundRoom: [String] = [
        "south", "east", "open window", "west",
        "up", "take rope", "down",
        "west",
        "take sword", "take lantern", "turn on lantern",
        "push rug", "open trap door", "down",
        "north", "west",
        "attack troll", "attack troll", "attack troll",
        "east", "east",  // → East-West Passage → Round Room
    ]

    /// From the Round Room, southeast into the Engravings Cave and east to the
    /// Dome Room — the mouth of the temple region, rope in hand.
    private static let toDomeRoom: [String] =
        toRoundRoom + ["southeast", "east"]

    /// Detour through the hub to the Dam Lobby for the matchbook, then down the
    /// rope and through the temple, gathering the bell (Temple) and the book and
    /// candles (Altar), ending at the Entrance to Hades with the full ritual kit.
    private static let toHadesWithKit: [String] =
        toRoundRoom + [
            "north", "northeast", "east", "north",  // → N-S Passage → Deep Canyon → Dam → Dam Lobby
            "take matchbook",
            "south", "south", "southwest", "south",  // → Dam → Deep Canyon → N-S Passage → Round Room
            "southeast", "east",  // → Engravings Cave → Dome Room
            "tie rope to railing", "down",  // → Torch Room
            "south", "take bell",  // Temple
            "south", "take book", "take candles",  // Altar
            "down", "down",  // → Cave → Entrance to Hades
        ]

    /// The rope must be tied before the dome will let you down; the ivory torch
    /// waits below; the gold coffin is too heavy to squeeze down the altar
    /// crack, so it can only leave by praying — which drops you in the forest.
    @Test func ropeDescentCoffinAndPrayEgress() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toDomeRoom + [
                "down",  // refused — the rope isn't tied
                "tie rope to railing",
                "down",  // now the drop to the Torch Room works
                "take torch",
                "south",  // Temple
                "east",  // Egyptian Room
                "open coffin",  // reveals the sceptre
                "take coffin",
                "west", "south",  // → Temple → Altar
                "down",  // refused — too heavy a load for the crack
                "pray",  // the coffin egress: away to the forest
            ],
            seed: 0)
        expectInOrder(
            transcript,
            [
                "Dome Room",
                "climb without a rope",  // domeNoRope
                "fast to the stone railing",  // ropeTied
                "Torch Room",
                "Egyptian Room",
                "Opening the gold coffin reveals a sceptre.",
                "Altar",
                "haven't a prayer of getting it down there",  // coffinTooHeavy
                "the temple dissolves around you",  // prayerAnswered
                "Forest",
            ])
    }

    /// The temple's internal graph, down to the very gate of Hades (barred until
    /// the exorcism). The drop through the altar crack is one-way — the way back
    /// out of the complex is onward through the Tiny Cave into the mirror region
    /// (covered by `Zork1MirrorTests`), so this walk ends at the gate.
    @Test func templeDescendsToTheGateOfHades() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toDomeRoom + [
                "tie rope to railing", "down",  // Torch Room
                "south",  // Temple
                "east",  // Egyptian Room
                "west",  // Temple
                "south",  // Altar
                "down",  // Cave (the Tiny Cave)
                "down",  // Entrance to Hades
                "south",  // barred — the spirits hold you back
            ],
            seed: 0)
        expectInOrder(
            transcript,
            [
                "Torch Room",
                "Temple",
                "Egyptian Room",
                "Temple",
                "Altar",
                "Cave",
                "Entrance to Hades",
                "some cold force at the gate",  // hadesGateBlocked
            ])
    }

    /// The full exorcism: ring the bell (it goes red hot and the spirits
    /// freeze), light a match and the candles to hold them, then read the
    /// prayer to banish them — and the way to the crystal skull opens.
    @Test func theExorcismOpensTheLandOfTheDead() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toHadesWithKit + [
                "ring bell",
                "light matches",
                "light candles",
                "read book",
                "south",  // the gate is open now
                "take skull",
            ],
            seed: 0)
        expectInOrder(
            transcript,
            [
                "Entrance to Hades",
                "drops from your hand",  // bellRingRedHot
                "flares alight in your hand",  // matchStrikes
                "hold the frozen",  // candlesLitForRitual
                "whole host of them is gone",  // spiritsBanished
                "Land of the Dead",
                "Taken.",  // the crystal skull
            ])
    }

    /// The ritual has a window: ring the bell and then dawdle, and the spirits
    /// shake off their stillness and the sequence must be started over.
    @Test func theExorcismWindowLapses() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toHadesWithKit + [
                "ring bell",
                "wait", "wait", "wait", "wait",  // too long — the moment passes
            ],
            seed: 0)
        expectInOrder(
            transcript,
            [
                "drops from your hand",  // the bell rung
                "take up their jeering at the gate once more",  // exorcismLapses
            ])
    }

    /// The rung bell is left red hot: too hot to pick up until it cools, twenty
    /// turns on — a deliberate anti-softlock so a fumbled ritual never traps it.
    @Test func theRungBellIsTooHotUntilItCools() async throws {
        let waits = Array(repeating: "wait", count: 20)
        let transcript = try await play(
            Zork1(),
            Self.toHadesWithKit + ["ring bell", "take bell"] + waits + ["take bell"],
            seed: 0)
        expectInOrder(
            transcript,
            [
                "drops from your hand",  // rung
                "burn your hand to the bone",  // bellTooHotToTake
                "cooled enough to handle again",  // bellCools
                "Taken.",  // now it can be picked up
            ])
    }

    /// A cold draught in the cave snuffs lit candles — the reason the ritual's
    /// candles must be lit at the gate below, not carried down alight.
    @Test func theDraughtSnuffsLitCandles() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toRoundRoom + [
                "north", "northeast", "east", "north",  // → Dam Lobby
                "take matchbook",
                "south", "south", "southwest", "south",  // → Round Room
                "southeast", "east",  // → Engravings Cave → Dome Room
                "tie rope to railing", "down",  // Torch Room
                "south", "south",  // → Temple → Altar
                "take candles", "light matches", "light candles",  // candles burning
                "down",  // into the cave — the draught takes them
            ],
            seed: 0)
        expectInOrder(
            transcript,
            [
                "candles catch and burn",  // candlesLit
                "draught in the cave snuffs your candles out",  // candlesSnuffedByDraft
                "Cave",
            ])
    }

    /// The matchbook is finite: five matches, and then none.
    @Test func theMatchbookRunsOut() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toRoundRoom + [
                "north", "northeast", "east", "north",  // → Dam Lobby
                "take matchbook",
                "light matches", "light matches", "light matches",
                "light matches", "light matches",  // the fifth is the last
                "light matches",  // empty now
            ],
            seed: 0)
        // Five matches flare; the sixth strike finds the book empty.
        let strikes = transcript.components(separatedBy: "flares alight")
        #expect(strikes.count == 6)
        #expect(transcript.contains("not a single match is left"))
    }
}
