import Foundation
import Gnusto
import GnustoTestSupport
import Testing

@testable import Zork1

/// End-to-end playthroughs of the Phase 10.8 Coal Mine region: the vampire bat
/// and the garlic that wards it, the coal-gas explosion, the four-room coal
/// maze, the basket on its chain, and the crack that guards the machine which
/// turns coal to a diamond.
///
/// Seed 2: the routes kill the troll to reach the hub,
/// and — because the thief daemon draws every turn — the exact seed that lands
/// the recorded three-blow kill depends on the prelude's length, which differs
/// from the other region suites (this one gathers the garlic and the rope on
/// the way down). Past the Round Room the thief stays penned in the cellar and
/// the mine itself is deterministic: the bat's one random draw is guarded by
/// the garlic, so an armed descent never touches the random stream.
struct Zork1CoalMineTests {
    /// Full-gear prelude: garlic (kitchen), sword and lit lantern (living room),
    /// rope (attic); down, kill the troll, into the Round Room.
    static let toRoundRoom: [String] = [
        "south", "east", "open window", "west",
        "take garlic", "west",
        "take sword", "take lantern", "turn on lantern",
        "east", "up", "take rope", "down", "west",
        "push rug", "open trap door", "down",
        "north", "west",
        "attack troll", "attack troll", "attack troll",
        "east", "east",
    ]

    /// Round Room → the mirror chain → the Slide Room → the Mine Entrance.
    static let toMineEntrance: [String] =
        toRoundRoom + [
            "south", "south",  // Narrow Passage → northern Mirror Room
            "touch mirror",  // → southern Mirror Room
            "north", "west", "north",  // Cold Passage → Slide Room → Mine Entrance
        ]

    /// Round Room → the temple, where the rope is tied and the ivory torch
    /// taken → back through the mirror chain to the Mine Entrance, torch in hand.
    static let toMineEntranceWithTorch: [String] =
        toRoundRoom + [
            "southeast", "east",  // Engravings Cave → Dome Room
            "tie rope to railing", "down", "take torch",  // Torch Room
            "south", "south", "down",  // Temple → Altar → Cave
            "north", "touch mirror", "north", "west", "north",  // → Mine Entrance
        ]

    /// As ``toMineEntranceWithTorch``, but by way of the dam's Maintenance Room
    /// to collect the screwdriver first — the tool the machine's switch needs.
    static let toMineWithTorchAndScrewdriver: [String] =
        toRoundRoom + [
            "north", "northeast", "east",  // NS Passage → Deep Canyon → Dam
            "north", "north", "take screwdriver",  // Dam Lobby → Maintenance Room
            "south", "south",  // → Dam
            "south", "southwest", "south",  // Deep Canyon → NS Passage → Round Room
            "southeast", "east",  // Engravings Cave → Dome Room
            "tie rope to railing", "down", "take torch",  // Torch Room
            "south", "south", "down",  // Temple → Altar → Cave
            "north", "touch mirror", "north", "west", "north",  // → Mine Entrance
        ]

    /// The mine threads from its entrance down through the bat's room, the shaft,
    /// the gas room (safe with only the electric lantern), the coal maze, and the
    /// ladder to the Timber Room — gathering the jade, the bracelet, and the coal
    /// on the way. The score banks the kitchen (10), cellar (25), and East-West
    /// Passage (5) already, plus the jade (5) and bracelet (5): fifty in all.
    @Test func theMineThreadsDownToTheTimberRoom() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toMineEntrance + [
                "west",  // Squeaky Room
                "north",  // Bat Room — garlic keeps the bat off
                "take figurine",
                "east",  // Shaft Room
                "north",  // Smelly Room
                "down",  // Gas Room — the lantern is no naked flame, so it's safe
                "take bracelet",
                "east", "northeast", "southeast", "southwest", "down",  // maze → Ladder Top
                "down",  // Ladder Bottom
                "south", "take coal", "north",  // Dead End and back
                "west",  // Timber Room
                "score",
            ],
            seed: 2)
        expectInOrder(
            transcript,
            [
                "Mine Entrance",
                "Squeaky Room",
                "Bat Room",
                "Shaft Room",
                "Smelly Room",
                "Gas Room",
                "Coal Mine",  // the maze
                "Ladder Top",
                "Ladder Bottom",
                "Dead End",
                "Timber Room",
                "Your score is 50 of a possible 350",
            ])
        // The lantern carried the player through the gas room unharmed.
        #expect(!transcript.contains("white roar"))
    }

    /// The vampire bat holds its nose while the garlic is in hand: the Bat Room
    /// is passed through to the Shaft Room ungrabbed. The basket there is
    /// fastened to its chain and can't be taken.
    @Test func garlicWardsOffTheBat() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toMineEntrance + [
                "west",  // Squeaky Room
                "north",  // Bat Room
                "east",  // Shaft Room — reached, so the bat never grabbed us
                "take basket",
            ],
            seed: 2)
        expectInOrder(transcript, ["Bat Room", "Shaft Room", "securely fastened"])
        #expect(!transcript.contains("Fweep"))
    }

    /// Without the garlic, stepping into the Bat Room gets you seized and carried
    /// off to a random corner of the mine — here, the Mine Entrance (seed 2).
    @Test func withoutGarlicTheBatCarriesYouOff() async throws {
        // The no-garlic prelude: everything but the clove.
        let noGarlic: [String] = [
            "south", "east", "open window", "west", "west",
            "take sword", "take lantern", "turn on lantern",
            "push rug", "open trap door", "down",
            "north", "west",
            "attack troll", "attack troll", "attack troll",
            "east", "east",
        ]
        let transcript = try await play(
            Zork1(),
            noGarlic + [
                "south", "south", "touch mirror", "north", "west", "north",  // → Mine Entrance
                "west",  // Squeaky Room
                "north",  // Bat Room — no garlic
            ],
            seed: 2)
        // The bat seizes you on entry, so the Bat Room never gets to describe
        // itself — the grab-and-lift replaces the room, and seed 2 drops you at
        // the Mine Entrance.
        expectInOrder(
            transcript,
            [
                "Squeaky Room",
                "grabs you by the scruff",
                "lifts you away",
                "Mine Entrance",
            ])
    }

    /// The crack out of the Timber Room is too narrow to pass carrying anything;
    /// only after the whole load is set down does it let you through to the
    /// Drafty Room.
    @Test func theCrackRefusesAnyLoad() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toMineEntrance + [
                "west", "north", "east",  // Squeaky → Bat → Shaft
                "north", "down",  // Smelly → Gas
                "east", "northeast", "southeast", "southwest", "down", "down",  // maze → Ladder Bottom
                "west",  // Timber Room
                "west",  // refused — hands full
                "drop all",
                "west",  // now the crack lets you through
            ],
            seed: 2)
        expectInOrder(
            transcript,
            [
                "Timber Room",
                "cannot fit through this passage",  // the refusal
                "Dropped",  // the load goes down
                "It is pitch black",  // and the crack opens — into the dark Drafty Room
            ])
    }

    /// The set piece: the coal becomes a diamond. The lit torch is lowered in the
    /// basket to light the Drafty Room past the crack; the coal and screwdriver
    /// ride down with it; the coal is fed to the machine, the lid shut, and the
    /// switch thrown with the screwdriver — and a huge diamond is left behind. The
    /// machine can't be carried, and the wrong tool won't throw the switch. The
    /// diamond rides the basket back up and scores ten on the find; the Drafty
    /// Room's visit award (13) and the torch's find (14) bring the total to 77.
    @Test func theMachineTurnsCoalIntoADiamond() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toMineWithTorchAndScrewdriver + [
                "west", "north", "east",  // Squeaky → Bat (garlic) → Shaft
                "put torch in basket", "put screwdriver in basket",
                // Fetch the coal, carrying only the safe lantern through the gas.
                "north", "down",  // Smelly → Gas
                "east", "northeast", "southeast", "southwest", "down", "down",  // maze → Ladder Bottom
                "south", "take coal", "north",  // Dead End and back
                "up", "up", "north", "east", "south",  // Ladder Top → maze → Coal Mine 1
                "north", "up", "south",  // Gas → Smelly → Shaft Room
                "put coal in basket",
                "lower basket",
                // Down the shaft's long way round, empty-handed through the crack.
                "north", "down",  // Smelly → Gas
                "east", "northeast", "southeast", "southwest", "down", "down",  // maze → Ladder Bottom
                "west",  // Timber Room
                "drop all",
                "west",  // Drafty Room, lit by the torch in the basket
                "take torch", "take coal", "take screwdriver",
                "south",  // Machine Room
                "take machine",  // refused
                "open machine", "put coal in machine", "close machine",
                "turn switch with torch",  // wrong tool
                "turn switch with screwdriver",  // the diamond is made
                "open machine", "take diamond",
                "north",  // Drafty Room
                "put all in basket",
                "east", "take all",  // Timber Room, reclaim the lantern
                "east",  // Ladder Bottom
                "up", "up", "north", "east", "south",  // Ladder Top → maze → Coal Mine 1
                "north", "up", "south",  // Gas → Smelly → Shaft Room
                "raise basket",
                "take diamond",
                "score",
            ],
            seed: 2)
        expectInOrder(
            transcript,
            [
                "lowered to the bottom of the shaft",
                "Drafty Room",  // lit past the crack — the torch in the basket
                "In the basket is a small pile of coal",  // visible, so the room is lit
                "Machine Room",
                "far too large",  // the machine can't be carried
                "turn it on with your bare hands",  // the torch won't throw the switch
                "colored lights and bizarre noises",  // the transmutation
                "reveals a huge diamond",
                "raised to the top of the shaft",
                "Your score is 77 of a possible 350",
            ])
    }

    /// The machine grinds anything that isn't coal to a worthless slag and loses
    /// it (FIDELITY.md — the original's non-coal destruction, earlier left as a
    /// no-op). Same seed-2 route to the diamond, then the diamond itself is fed
    /// back into the machine to prove a non-coal load is destroyed. The held torch
    /// keeps the room lit throughout.
    @Test func theMachineGrindsNonCoalToWorthlessSlag() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toMineWithTorchAndScrewdriver + [
                "west", "north", "east",  // Squeaky → Bat (garlic) → Shaft
                "put torch in basket", "put screwdriver in basket",
                "north", "down",  // Smelly → Gas
                "east", "northeast", "southeast", "southwest", "down", "down",  // maze → Ladder Bottom
                "south", "take coal", "north",  // Dead End and back
                "up", "up", "north", "east", "south",  // Ladder Top → maze → Coal Mine 1
                "north", "up", "south",  // Gas → Smelly → Shaft Room
                "put coal in basket",
                "lower basket",
                "north", "down",  // Smelly → Gas
                "east", "northeast", "southeast", "southwest", "down", "down",  // maze → Ladder Bottom
                "west",  // Timber Room
                "drop all",
                "west",  // Drafty Room, lit by the torch in the basket
                "take torch", "take coal", "take screwdriver",
                "south",  // Machine Room
                "open machine", "put coal in machine", "close machine",
                "turn switch with screwdriver",  // the diamond is made
                "open machine", "take diamond",
                // Feed the diamond — a non-coal load — back in and throw the switch:
                // the machine grinds it to nothing.
                "put diamond in machine", "close machine",
                "turn switch with screwdriver",
                "open machine", "take diamond",  // gone
            ],
            seed: 2)
        expectInOrder(
            transcript,
            [
                "reveals a huge diamond",  // first, the coal becomes a diamond
                "put the huge diamond in the machine",  // the non-coal load, fed back in
                "can't see any such thing",  // then it is destroyed — nothing left to take
            ])
    }

    /// A naked flame in the coal gas is fatal: carrying the lit ivory torch down
    /// into the Gas Room sets the air alight. It is the player's first death, so
    /// it is survivable — Zork's mercy sets them back in the forest.
    @Test func aNakedFlameInTheGasRoomIsFatal() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toMineEntranceWithTorch + [
                "west", "north", "east",  // Squeaky → Bat (garlic) → Shaft
                "north",  // Smelly Room
                "down",  // Gas Room — the lit torch meets the gas
            ],
            seed: 2)
        expectInOrder(
            transcript,
            [
                "Gas Room",
                "carrying flaming objects",  // the explosion
                "deserve another",  // the resurrection
                "Forest",
            ])
        #expect(!transcript.contains("Would you like to RESTART"))
    }
}
