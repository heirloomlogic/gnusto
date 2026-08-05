import Foundation
import GnustoTestSupport
import Testing

@testable import Gnusto

/// The `Dungeon` M0 balloon spike (#133): every beat of a vehicle that rides a
/// volcano shaft vertically on a fuel clock, played end to end against
/// ``VolcanoGame``.
///
/// The suite is the spike's evidence. What it proves is not that the fixture
/// works — it is that a vertical, player-fuelled vehicle needs **no new verb, no
/// plugin and no engine hook**: the fixture declares no `verbs` block, and every
/// command below is a stock one. See `docs/games/dungeon.md`, *The balloon
/// question, answered*.
///
/// `VolcanoGame` draws no randomness, so nothing here is seeded.
struct BalloonTests {
    /// Held, boarded, fuelled and lit — the four turns every flight opens with.
    /// The fire ticks the fuel fuse for the first time as this turn ends, so a
    /// flight's clock starts at the last of these.
    static let launch = [
        "take newspaper", "take matchbook", "enter basket",
        "put newspaper in receptacle", "burn newspaper with match",
    ]

    /// The whole mechanic in one flight: board, fuel, light, rise two levels,
    /// cross to the ledge, tie off, step out — and the pebble dropped in the
    /// hull at the bottom of the shaft is on the ledge to be picked up again.
    @Test func theFlightRunsFromTheShaftFloorToTheLedge() async throws {
        let transcript = try await play(
            VolcanoGame(),
            [
                "take pebble", "take newspaper", "take matchbook",
                "enter basket", "drop pebble",
                "put newspaper in receptacle",
                "burn newspaper with match",
                "look",
                "west",
                "tie rope to hook",
                "get out",
                "look",
                "take pebble",
                "south",
                "quit",
            ])
        expectInOrder(
            transcript,
            [
                "You are now in the wicker basket.",
                "You put the newspaper in the metal receptacle.",
                "The newspaper catches, and the bag overhead begins to fill.",
                "The balloon rises.",
                "Volcano Core, in the wicker basket",
                "The balloon rises.",
                "Volcano near small ledge, in the wicker basket",
                "Narrow Ledge, in the wicker basket",
                "You loop the braided rope through the hook and draw it tight.",
                "You get out of the wicker basket.",
                "Taken.",
                "Library",
            ])
        // The cargo rode up the shaft in the hull and is on the ledge, listed
        // under a basket the player is no longer sitting in.
        let ashore = turnOutput(of: "look", in: output(after: "get out", in: transcript))
        #expect(ashore.contains("Narrow Ledge"))
        #expect(!ashore.contains("Narrow Ledge, in the"))
        #expect(ashore.contains("In the wicker basket is a smooth pebble."))
    }

    /// The clock turns the flight around without the player touching anything:
    /// the fuse ends the fire, and the same turn's daemon starts the descent —
    /// sag then sink, in that order, because fuses tick before daemons.
    @Test func theFuelClockTurnsTheBalloonAround() async throws {
        let transcript = try await play(
            VolcanoGame(),
            Self.launch + [
                "look", "x basket", "x receptacle", "listen", "smell",
                "x rope", "x me", "x torch", "quit",
            ])
        expectInOrder(
            transcript,
            [
                "The balloon rises.",
                "Volcano Core, in the wicker basket",
                "The balloon rises.",
                "Volcano near small ledge, in the wicker basket",
                "The balloon nudges the rim and rises no further.",
                "The last of the newspaper goes to ash, and the bag sags.",
                "The balloon sinks.",
                "Volcano Core, in the wicker basket",
                "The balloon sinks.",
                "Volcano Bottom, in the wicker basket",
            ])
        // Said once, not once a turn: three turns pass at the rim.
        #expect(occurrences(of: "nudges the rim", in: transcript) == 1)
        // And the shaft floor is the bottom — it does not sink through it.
        let atRest = turnOutput(of: "x torch", in: transcript)
        #expect(atRest.contains("Pitch and rag"))
        #expect(!atRest.contains("sinks"))
    }

    /// A balloon is not steered. The terrain-gate idiom refuses the direction,
    /// and — because a refused turn still costs one — the fire goes on lifting
    /// the balloon while the player argues with it.
    @Test func theBalloonGoesWhereTheFireTakesIt() async throws {
        let transcript = try await play(
            VolcanoGame(), Self.launch + ["up", "down", "quit"])
        let up = turnOutput(of: "up", in: transcript)
        #expect(up.contains("The balloon goes where the fire takes it, not where you point."))
        #expect(up.contains("The balloon rises."))
        expectInOrder(
            transcript,
            [
                "> down",
                "The balloon goes where the fire takes it, not where you point.",
                "The balloon nudges the rim and rises no further.",
            ])
    }

    /// Stepping over the side with nothing under you is exactly as fatal as it
    /// sounds. The gate is on `world`, not on the basket: bare `get out` carries
    /// no direct object, so an item rule would never see it.
    @Test func steppingOutInMidAirIsFatal() async throws {
        let transcript = try await play(
            VolcanoGame(), Self.launch + ["get out", "quit"])
        expectInOrder(
            transcript,
            [
                "Volcano Core, in the wicker basket",
                "You step over the side of the basket into a great deal of nothing at all.",
                "*** You have died ***",
            ])
    }

    /// The same command spelled with the object still can't get around it.
    @Test func namingTheBasketDoesNotSoftenTheFall() async throws {
        let transcript = try await play(
            VolcanoGame(), Self.launch + ["get out of basket", "quit"])
        expectInOrder(transcript, ["The floor of the volcano arrives shortly afterward."])
    }

    /// Why the hook is there: an untied balloon with a fire still in it would
    /// leave the moment the player's weight came out of the basket, so the
    /// engine's own DISEMBARK never gets the chance.
    @Test func anUntiedBalloonRefusesToBeLeftOnTheLedge() async throws {
        let transcript = try await play(
            VolcanoGame(), Self.launch + ["look", "west", "get out", "quit"])
        expectInOrder(
            transcript,
            [
                "Narrow Ledge, in the wicker basket",
                "The bag strains upward. Only your weight is holding it down.",
                "The balloon would lift off the moment your weight left the basket.",
                "Tie it to the hook first.",
            ])
        #expect(!transcript.contains("You get out of the wicker basket."))
    }

    /// And the hazard the hook exists to prevent is real, not theoretical: untie
    /// a still-burning balloon from the ledge and it goes without you. This is
    /// the softlock #139 warns about, reproduced in seven turns so M6 can decide
    /// deliberately whether to keep it.
    @Test func untyingAStillBurningBalloonStrandsYouOnTheLedge() async throws {
        let transcript = try await play(
            VolcanoGame(),
            Self.launch + [
                "look", "west", "tie rope to hook", "get out",
                "untie rope from hook", "look", "quit",
            ])
        expectInOrder(
            transcript,
            [
                "You get out of the wicker basket.",
                "You lift the rope clear of the hook.",
                "The balloon lifts off the ledge and drifts out over the shaft.",
            ])
        let stranded = turnOutput(of: "look", in: output(after: "untie", in: transcript))
        #expect(stranded.contains("Narrow Ledge"))
        #expect(!stranded.contains("wicker basket"))
    }

    /// The receptacle takes fuel and only fuel, and the torch is not fuel.
    @Test func theWrongThingInTheReceptacleEndsTheFlight() async throws {
        let transcript = try await play(
            VolcanoGame(),
            ["take torch", "enter basket", "put torch in receptacle", "quit"])
        expectInOrder(
            transcript,
            [
                "The torch takes the cloth of the bag before it takes anything else",
                "*** You have died ***",
            ])
    }

    @Test func aPebbleIsNotFuel() async throws {
        let transcript = try await play(
            VolcanoGame(),
            ["take pebble", "enter basket", "put pebble in receptacle", "quit"])
        expectInOrder(transcript, ["That would not burn long enough to matter."])
        #expect(!transcript.contains("You put the smooth pebble in"))
    }

    /// The promoted `.burn` stub in both of its rows. `burn newspaper` and
    /// `burn newspaper with match` are one intent and one rule, and the second
    /// row is what carries the match through as an indirect object. That row
    /// now ships in the stub table for parity with `attack`, `dig` and `fill` —
    /// a game could equally have declared it, since overriding a stub warns
    /// nothing. See `docs/games/dungeon.md`.
    @Test func burningNeedsBothTheReceptacleAndTheMatch() async throws {
        let transcript = try await play(
            VolcanoGame(),
            [
                "take newspaper", "take matchbook", "enter basket",
                "burn newspaper with match",
                "put newspaper in receptacle",
                "burn newspaper",
                "burn newspaper with match",
                "quit",
            ])
        expectInOrder(
            transcript,
            [
                "> burn newspaper with match",
                "Burning it in your hands would cost you the newspaper and nothing else.",
                "> burn newspaper",
                "You have nothing to set it alight with.",
                "> burn newspaper with match",
                "The newspaper catches, and the bag overhead begins to fill.",
            ])
    }

    /// The mooring verbs are the engine's stubs, promoted. Nothing about
    /// `tie <thing> to <thing>` had to be declared — the row was already there.
    @Test func theMooringVerbsAreStubsPromotedInPlace() async throws {
        let transcript = try await play(
            VolcanoGame(),
            Self.launch + [
                "look", "west", "untie rope", "tie rope to basket",
                "tie rope to hook", "quit",
            ])
        expectInOrder(
            transcript,
            [
                "> untie rope",
                "The rope isn't tied to anything.",
                "> tie rope to basket",
                "There is nothing here to tie the rope to.",
                "> tie rope to hook",
                "You loop the braided rope through the hook and draw it tight.",
            ])
    }
}
