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
/// Every route kills the troll first (the only way east to the hub). Seed 0:
/// grabbing the attic rope shifts the RNG stream, so this suite needs its own
/// seed to still land the three-blow kill. Past the
/// Round Room the thief stays penned in the cellar, so the temple itself draws
/// no randomness — the region's mechanics are all deterministic.
struct Zork1TempleTests {
    /// Enter the house, take the sword, lantern (lit), and the attic rope, kill
    /// the troll, and press east into the Round Room.
    static let toRoundRoom: [String] = [
        "south", "east", "open window", "west",
        "west",
        "take sword", "take lantern", "turn on lantern",
        "east", "up", "take rope", "down",
        "west",
        "push rug", "open trap door", "down",
        "north", "west",
        "attack troll", "attack troll", "attack troll",
        "east", "east",  // → East-West Passage → Round Room
    ]

    /// From the Round Room, southeast into the Engravings Cave and east to the
    /// Dome Room — the mouth of the temple region, rope in hand.
    static let toDomeRoom: [String] =
        toRoundRoom + ["southeast", "east"]

    /// Down the rope and through the Temple to the Altar, touching nothing on
    /// the way.
    private static let toAltar: [String] =
        toDomeRoom + [
            "tie rope to railing", "down",  // → Torch Room
            "south", "south",  // → Temple → Altar
        ]

    /// Detour through the hub to the Dam Lobby for the matchbook, then down the
    /// rope to the Torch Room.
    private static let toTorchRoomWithMatchbook: [String] =
        toRoundRoom + [
            "north", "northeast", "east", "north",  // → N-S Passage → Deep Canyon → Dam → Dam Lobby
            "take matchbook",
            "south", "south", "southwest", "south",  // → Dam → Deep Canyon → N-S Passage → Round Room
            "southeast", "east",  // → Engravings Cave → Dome Room
            "tie rope to railing", "down",  // → Torch Room
        ]

    /// From the Torch Room with the matchbook, through the temple, gathering the
    /// bell (Temple) and the book and candles (Altar), ending at the Entrance to
    /// Hades with the full ritual kit.
    private static let toHadesWithKit: [String] =
        toTorchRoomWithMatchbook + [
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
                "fracturing many bones",  // domeNoRope
                "comes within ten feet of the floor",  // ropeTied
                "Torch Room",
                "Egyptian Room",
                "Opening the gold coffin reveals a sceptre.",
                "Altar",
                "haven't a prayer of getting the coffin down there",  // coffinTooHeavy
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
                "invisible force prevents you from passing",  // hadesGateBlocked
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
                "becomes red hot and falls to the ground",  // bellRingRedHot
                "matches starts to burn",  // matchStrikes
                "flames flicker wildly and appear to dance",  // candlesLitForRitual
                "flee through the walls",  // spiritsBanished
                "Land of the Dead",
                "Taken.",  // the crystal skull
            ])
    }

    /// The bell puts out only candles in hand, so candles left burning on the
    /// ground stay lit. Picking them up after the bell is the ritual's second
    /// step, as `LLD-ROOM`'s end-of-turn check (`1actions.zil:1115`) asks only
    /// that burning candles be in hand.
    @Test func burningCandlesTakenUpAfterTheBellCompleteTheRitual() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toHadesWithKit + [
                "light matches", "light candles", "drop candles",
                "ring bell",
                "take candles",
                "read book",
            ],
            seed: 0)
        expectInOrder(
            transcript,
            [
                "becomes red hot and falls to the ground",
                "flames flicker wildly and appear to dance",
                "flee through the walls",
            ])
    }

    /// `CANDLES-FCN` answers the torch before it asks whether the torch is
    /// burning (`1actions.zil:2372`).
    @Test func burningCandlesRefuseTheTorchInTheSourcesWords() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toAltar + ["north", "north", "take torch", "south", "south", "light candles with torch"],
            seed: 0)
        #expect(
            turnOutput(of: "light candles with torch", in: transcript)
                .contains("You realize, just in time, that the candles are already lighted."))
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
                "becomes red hot and falls to the ground",  // the bell rung
                "resume their hideous jeering",  // exorcismLapses
            ])
    }

    /// The window and the bell are both on counts rather than on places, so
    /// both fuses ask where the player is standing before they say anything.
    /// Ring and climb out: the ritual still resets and the bell still cools,
    /// and the player is told about neither, because both are happening in a
    /// room a staircase below them.
    @Test func theGateFusesSayNothingToAPlayerWhoHasClimbedOut() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toHadesWithKit
                + ["ring bell", "up"] + Array(repeating: "wait", count: 22)
                + ["down", "examine bell"],
            seed: 0)

        #expect(!transcript.contains("resume their hideous jeering"))
        #expect(!transcript.contains("appears to have cooled down"))
        // Both fuses ran regardless: the bell is cold when they come back down.
        #expect(
            turnOutput(of: "examine bell", in: transcript).contains("once rung to call the faithful"))
    }

    /// The candles burn on a count too, and their two rungs are things you
    /// watch happen to a flame. Light them, leave them at the gate, and the
    /// wick still runs out — announced to nobody.
    @Test func theCandlesBurnDownSilentlyWhereThePlayerCannotSeeThem() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toHadesWithKit
                + ["light matches", "light candles", "drop candles", "up"]
                + Array(repeating: "wait", count: 26),
            seed: 0)

        #expect(transcript.contains("The candles are lit."))
        #expect(!transcript.contains("The candles won't last long now."))
        #expect(!transcript.contains("The flame is extinguished."))
    }

    /// **`light candles with match` is a sentence this game invites and could
    /// not read.** Its own refusal is *"You have to light them with something
    /// that's burning, you know."*, and typing that back answered "You can't
    /// see any such thing" about a match in the player's hand: `.turnOn`
    /// carried only `["light", .directObject]`, so the object slot ended the
    /// pattern and swallowed `candles with match` whole. The row is on
    /// ``Intent/burn`` now, because `gsyntax.zil:288` sends `LIGHT X WITH Y` to
    /// `V-BURN`, and `CANDLES-FCN` answers both verbs as one case. (#332)
    @Test func theCandlesLightWithANamedFlameAndRefuseAColdOne() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toHadesWithKit + [
                "light candles with bell", "light matches", "light candles with match",
            ],
            seed: 0)

        let cold = turnOutput(of: "light candles with bell", in: transcript)
        #expect(cold.contains("You have to light them with something that's burning, you know."))
        #expect(!cold.contains("You can't see any such thing."))

        let lit = turnOutput(of: "light candles with match", in: transcript)
        #expect(lit.contains("The candles are lit."))
        #expect(!lit.contains("You can't see any such thing."))
    }

    /// The control: carried, the candles report both rungs.
    @Test func theCandlesAnnounceEveryRungToAPlayerHoldingThem() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toHadesWithKit + ["light matches", "light candles"]
                + Array(repeating: "wait", count: 26),
            seed: 0)

        expectInOrder(
            transcript,
            [
                "The candles won't last long now.",
                "The flame is extinguished.",
            ])
    }

    /// The rung bell is left red hot: too hot to pick up until it cools, twenty
    /// turns on — a deliberate anti-softlock so a fumbled ritual never traps it.
    /// Its examine text tracks the heat — glowing red while hot, an ordinary
    /// hand-bell once cooled (the original's distinct red-hot bell).
    @Test func theRungBellIsTooHotUntilItCools() async throws {
        let waits = Array(repeating: "wait", count: 20)
        let transcript = try await play(
            Zork1(),
            Self.toHadesWithKit
                + ["ring bell", "examine bell", "take bell"] + waits
                + ["examine bell", "take bell"],
            seed: 0)
        expectInOrder(
            transcript,
            [
                "becomes red hot and falls to the ground",  // rung
                "glows a dull, angry red",  // examine while hot → redHotBell
                "very hot and cannot be taken",  // bellTooHotToTake
                "appears to have cooled down",  // bellCools
                "once rung to call the faithful",  // examine once cooled → bell
                "Taken.",  // now it can be picked up
            ])
    }

    /// A cold draught in the cave snuffs lit candles — the reason the ritual's
    /// candles must be lit at the gate below, not carried down alight. They
    /// start burning (`ONBIT`), so lighting them at the altar is
    /// `CANDLES-FCN`'s "already lit" (`1actions.zil:2364`).
    @Test func theDraughtSnuffsLitCandles() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toTorchRoomWithMatchbook + [
                "south", "south",  // → Temple → Altar
                "take candles", "light matches", "light candles",  // burning since the start
                "down",  // into the cave — the draught takes them
            ],
            seed: 0)
        expectInOrder(
            transcript,
            [
                "The candles are already lit.",
                "gust of wind blows out your candles",  // candlesSnuffedByDraft
                "Cave",
            ])
        #expect(!transcript.contains("The candles are lit."))
    }

    /// `CANDLES-FCN` enables `I-CANDLES` on the first command that names the
    /// untouched candles (`1actions.zil:2344`), so they burn down from there
    /// and not from the start of the game.
    @Test func theCandlesBurnFromTheFirstCommandThatNamesThem() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toAltar + ["take candles", "north"]  // → Temple, clear of the draught
                + Array(repeating: "wait", count: 25),
            seed: 0)
        expectInOrder(
            transcript,
            [
                "The candles won't last long now.",
                "The flame is extinguished.",
            ])
    }

    /// Until something names them, they burn without burning down, and
    /// leaving them behind keeps them out of the cave's draught, which blows
    /// out only candles in the player's hands (`CAVE2-ROOM`,
    /// `1actions.zil:2418`).
    @Test func untouchedCandlesStayLitAndOutOfTheDraught() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toAltar + Array(repeating: "wait", count: 21) + [
                "look", "down",  // → Cave, candles left on the altar
            ],
            seed: 0)
        #expect(
            turnOutput(of: "look", in: transcript)
                .contains("On the two ends of the altar are burning candles."))
        #expect(!transcript.contains("The candles won't last long now."))
        #expect(!transcript.contains("gust of wind"))
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
        let strikes = transcript.components(separatedBy: "matches starts to burn")
        #expect(strikes.count == 6)
        #expect(transcript.contains("run out of matches"))
    }
}
