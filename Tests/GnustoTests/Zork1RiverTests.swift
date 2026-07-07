import Foundation
import Gnusto
import GnustoTestSupport
import Testing

@testable import Zork1

/// End-to-end playthroughs of the Phase 10.9 Frigid River region: the inflatable
/// boat and the pump that fills it, the current that carries it downstream, the
/// buoy and its emerald, the buried scarab, the falls, and the rainbow the
/// sceptre wakes.
///
/// The boat tests run at seed 39 (the same recorded troll kill the Dam suite
/// uses): the shared prelude drains the reservoir to fetch the pump, exactly as
/// `Zork1Tests` does. Everything past the Round Room is deterministic — the
/// thief stays penned in the cellar and the river's own machinery is draw-free.
/// The rainbow and canyon tests never go underground, so they need no particular
/// seed. All seeds are pinned only until the T14 re-pin.
struct Zork1RiverTests {
    /// Kill the troll (seed 39), charge the dam panel, and end standing on the
    /// Dam with the wrench — the Dam suite's proven approach.
    static let toChargedDam: [String] = [
        "south", "east", "open window", "west", "west",
        "take sword", "take lantern", "turn on lantern",
        "push rug", "open trap door", "down",
        "north", "west",
        "attack troll", "attack troll", "attack troll",
        "east", "east",  // → East-West Passage → Round Room
        "north", "northeast", "east",  // → N-S Passage → Deep Canyon → Dam
        "north", "north",  // → Dam Lobby → Maintenance Room
        "take wrench", "push yellow button",
        "south", "south",  // → Dam Lobby → Dam
    ]

    /// Drain the reservoir, walk the bare bed to Reservoir North for the hand
    /// pump, return to the Dam Base, and inflate the pile of plastic into a boat.
    /// Ends on the (dark) Dam Base holding the pump, the sword, and the lit
    /// lantern, the boat sitting inflated on the bank.
    static let toInflatedBoat: [String] =
        toChargedDam + [
            "turn bolt with wrench",  // gates open, the drain begins
            "west",  // Reservoir South
            "wait", "wait", "wait", "wait",
            "wait", "wait", "wait", "wait",  // the eight-turn drain completes
            "north", "north",  // Reservoir bed → Reservoir North
            "take pump",
            "south", "south",  // back across the bed → Reservoir South
            "southeast", "east", "down",  // Deep Canyon → Dam → Dam Base
            "inflate plastic with pump",
        ]

    /// As ``toInflatedBoat``, but set the sword down (so it can't hole the boat),
    /// board, and launch onto the river. Ends adrift on River-1.
    static let toLaunched: [String] =
        toInflatedBoat + [
            "drop sword",
            "enter boat",
            "launch boat",
        ]

    /// The boat carries the player down the river to the sandy east bank: paddle
    /// to River-4, lift the buoy (and the emerald inside it), land, and dig the
    /// scarab out of the Sandy Cave. Kitchen (10), cellar (25) and East-West
    /// Passage (5) are already banked; the emerald (5) and scarab (5) bring the
    /// total to fifty.
    @Test func theBoatCarriesYouDownToTheSandyBeachAndTheScarab() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toLaunched + [
                "down", "down", "down",  // River-2 → River-3 → River-4
                "take buoy",
                "east",  // land the boat on the Sandy Beach
                "disembark",
                "open buoy", "take emerald",  // +5 on the find
                "take shovel",
                "northeast",  // Sandy Cave
                "dig sand with shovel",  // first dig
                "dig sand with shovel",  // second dig
                "dig sand with shovel",  // third dig bares the scarab
                "take scarab",  // +5 on the find
                "score",
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "slips off the bank",  // the launch
                "Frigid River",
                "Sandy Beach",
                "Sandy Cave",
                "jewelled scarab",  // the third dig reveals it
                "Your score is 50 of a possible 350",
            ])
        // A successful launch must not fall through to the stage-4 default.
        #expect(!transcript.contains("You can't launch that"))
    }

    /// Boarding the boat with a blade still in hand punctures it: the sword's
    /// point opens the hull the moment you climb in, and you are left standing —
    /// dry, at least — on the bank beside a useless wreck.
    @Test func boardingWithABladePuncturesTheBoat() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toInflatedBoat + [
                "enter boat",  // still carrying the sword
                "look",
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "deflates around you",  // the puncture
                "Dam Base",  // still ashore, not adrift
                "punctured boat",  // the wreck is what's left
            ])
    }

    /// Sit still on the river and the current does the steering — right over
    /// Aragain Falls. Drifting off the last stretch is fatal, though as a first
    /// death it is survivable: Zork sets the drowned adventurer back in the forest.
    @Test func driftingPastTheLastStretchGoesOverTheFalls() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toLaunched + [
                "down", "down", "down", "down",  // River-2 → … → River-5
                "wait",  // the current carries you over the falls
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "Frigid River",
                "sweeps over the lip",  // the drowning (text wraps after "lip of")
                "Forest",  // the resurrection
            ])
        #expect(!transcript.contains("Would you like to RESTART"))
    }

    /// You cannot launch a boat you are not sitting in — waving it at the water
    /// from the bank gets you nowhere.
    @Test func launchingWithoutBoardingIsRefused() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toInflatedBoat + [
                "drop sword",  // set the blade down so nothing else is in play
                "launch boat",  // but never board
            ],
            seed: 39)
        expectInOrder(transcript, ["Dam Base", "not in the boat"])
    }

    /// The sceptre wakes the rainbow. Carrying it out of the temple by prayer and
    /// down the canyon to the End of Rainbow, a wave turns the rainbow solid and a
    /// pot of gold appears; the rainbow can then be crossed to Aragain Falls and
    /// back. Banked visits (40) plus the sceptre (4) and the pot (10) make 54.
    @Test func theSceptreWakesTheRainbow() async throws {
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west",
                "up", "take rope", "down",
                "west",
                "take sword", "take lantern", "turn on lantern",
                "push rug", "open trap door", "down",
                "north", "west",
                "attack troll", "attack troll", "attack troll",
                "east", "east",  // → East-West Passage → Round Room
                "southeast", "east",  // → Engravings Cave → Dome Room
                "tie rope to railing", "down",  // → Torch Room
                "south", "east",  // Temple → Egyptian Room
                "open coffin", "take sceptre",
                "west", "south",  // Temple → Altar
                "pray",  // the coffin egress drops you in the forest, sceptre in hand
                "east", "south", "east", "east",  // Forest West → … → Forest East
                "southeast", "down", "down", "north",  // canyon down to the End of Rainbow
                "up",  // refused — the rainbow is only light
                "wave sceptre",  // it turns solid; the pot appears
                "take pot",  // +10 on the find
                "up",  // On the Rainbow
                "east",  // Aragain Falls
                "west", "west",  // On the Rainbow → back to the End of Rainbow
                "score",
            ],
            seed: 0)
        expectInOrder(
            transcript,
            [
                "End of Rainbow",
                "walk on light",  // the crossing refused while the rainbow is ordinary
                "turns solid",  // the sceptre wakes it
                "winks into being",  // the pot of gold
                "On the Rainbow",
                "Aragain Falls",
                "Your score is 54 of a possible 350",
            ])
    }

    /// The canyon climbs both ways (the original's `CLIMBABLE-CLIFF`): a smoke
    /// walk down from Forest East to the End of Rainbow and back up again, with
    /// no boat, no underground, and no randomness. It also proves the rainbow
    /// refuses a crossing until the sceptre has woken it.
    @Test func theCanyonClimbsBothWays() async throws {
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "east",  // West of House → … → Forest East
                "southeast", "down", "down", "north",  // Canyon View → Rocky Ledge → Bottom → End
                "up",  // refused — the rainbow isn't solid
                "south", "up", "up", "northwest",  // climb back: Bottom → Ledge → View → Forest East
            ],
            seed: 0)
        expectInOrder(
            transcript,
            [
                "Canyon View",
                "Rocky Ledge",
                "Canyon Bottom",
                "End of Rainbow",
                "walk on light",  // the un-woken rainbow
                "Canyon Bottom",  // and the climb back up
                "Rocky Ledge",
                "Canyon View",
            ])
    }
}
