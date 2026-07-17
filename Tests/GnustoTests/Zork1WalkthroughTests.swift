import Foundation
import Gnusto
import GnustoTestSupport
import Testing

@testable import Zork1

/// The Phase 10 acceptance test: one scripted playthrough of *Zork I* from West
/// of House to `end(won: true)` at the full 350 points, gathering all nineteen
/// treasures into the trophy case, revealing the ancient map, and stepping into
/// the Stone Barrow to win.
///
/// **The seed.** The run's only randomness lives in Phase A: the troll's death,
/// the thief's roaming and stealing, and the thief's death in his lair. The
/// thief is lethal — his stiletto can end the run on the turn you enter the
/// Treasure Room — so a winning seed is *found by brute-force scan*, not chosen.
/// Seed 32 is the lowest that survives both combats cleanly and lets the thief's
/// egg-opening service finish (the canary emerges intact). Once the thief falls,
/// **no randomness remains** — every source (troll, thief roam/steal/fight, the
/// coal-mine bat) is dead or guarded — so all of Phase B plays out identically
/// regardless of seed. A scan of seeds 0–599 finds 47 that win this exact route.
///
/// **The strategy.** *Phase A* descends, kills the troll, threads the maze,
/// routs the cyclops (which opens the Strange Passage shortcut home), arms the
/// egg service in the lair, and kills the thief — recovering his whole hoard.
/// *Phase B*, now deterministic, collects the other sixteen treasures and banks
/// all nineteen, working around three standing constraints: the carrying cap
/// (heavy treasures are banked in batches via the reopened trap door), the
/// altar-crack load limit (Hades is a light dive), and the lantern's fuel — the
/// **light handoff** to the permanent ivory torch keeps it from ever burning
/// out. The final treasure cased, the map appears and the barrow opens.
///
/// Assertions anchor on room names, score checkpoints, and a handful of key
/// event lines (the two deaths, the map whisper, the barrow epilogue) — now
/// carrying the original Zork I text; see `THIRD_PARTY_NOTICES`.
struct Zork1WalkthroughTests {
    /// The pinned seed (see the type doc): the lowest that wins this route.
    static let seed: UInt64 = 32

    @Test func theFullThreeHundredFiftyPointWalkthrough() async throws {
        let transcript = try await play(Zork1(), Walkthrough.commands, seed: Self.seed)

        // Every region checkpoint, milestone and endgame beat, in the order the
        // playthrough reaches them.
        expectInOrder(
            transcript,
            [
                // Phase A — into the underground, and the two deaths in-run.
                "Kitchen",
                "Cellar",
                "The troll takes a fatal blow",  // the troll falls
                "Treasure Room",
                "treasures reappear",  // the thief falls; his hoard spills
                "In the jewel-encrusted egg is a golden clockwork canary.",  // intact
                "Your score is 91 of a possible 350",  // Phase A complete
                // Phase B — the region checkpoints.
                "Your score is 106 of a possible 350",  // hoard banked
                "Your score is 140 of a possible 350",  // hub + dam
                "Your score is 156 of a possible 350",  // heavy treasures banked
                "The brass lantern is now off.",  // ── the light handoff ──
                "Land of the Dead",
                "Your score is 205 of a possible 350",  // temple, skull, trident
                "Machine Room",  // deep past the crack, lit only by the torch
                "Your score is 238 of a possible 350",  // coal mine
                "Your score is 258 of a possible 350",  // mine treasures banked
                "the temple dissolves around you",  // the coffin's prayer egress
                "Your score is 293 of a possible 350",  // coffin, canary, bauble
                "Your score is 319 of a possible 350",  // the pot of gold
                "Your score is 344 of a possible 350",  // river: emerald, scarab
                // Endgame — the nineteenth treasure reveals the map; the barrow wins.
                "treasures for the final secret",
                "Your score is 350 of a possible 350",
                "rank of Master Adventurer",
                "perilous adventure",  // the Stone Barrow epilogue
                "mastered ZORK: The Great Underground Empire",
            ]
        )

        // The run never dies — a death would dock ten points and scatter the
        // hoard, putting 350 out of reach.
        #expect(!transcript.contains("deserve another chance"))
        // The light handoff proves the fuel economy end-to-end: the lantern is
        // switched off for the torch and never once burns low or dies.
        #expect(!transcript.contains("The lamp appears a bit dimmer"))
        #expect(!transcript.contains("better have more light than from the brass lantern"))
        #expect(!transcript.contains("burned-out lamp won't light"))
        // And the underground was never dark underfoot.
        #expect(!transcript.contains("pitch black"))
    }
}

/// The scripted 350-point route, split into narrated stages. Phase A is the
/// seed-sensitive core (two combats and the egg service); Phase B, run after the
/// thief's death, is deterministic. See ``Zork1WalkthroughTests``.
private enum Walkthrough {
    static let commands: [String] = phaseA + phaseB

    // ── PHASE A (seed-sensitive) ───────────────────────────────────────────

    static let phaseA: [String] =
        prep + descendAndTroll + mazeToLair + giveEggAndFlee + returnAndKill

    /// Fetch the egg (Up a Tree), gear up (sword, lit lantern), open the trophy
    /// case, and drop into the cellar (kitchen +10, cellar +25).
    static let prep: [String] = [
        "north", "north", "up", "take egg", "down",
        "south", "west",  // → West of House
        "south", "east", "open window", "west",  // → Kitchen (+10)
        "west",  // Living Room
        "take sword", "take lantern", "turn on lantern", "open trophy case",
        "move rug", "open trap door", "down",  // Cellar (+25)
    ]

    /// North to the Troll Room; cut the troll down (seed 32: two blows land it).
    static let descendAndTroll: [String] = [
        "north",  // Troll Room
        "attack troll", "attack troll", "attack troll",
    ]

    /// West into the maze to Maze-5 for the bag of coins (+10), on to the
    /// Cyclops Room, rout him with `odysseus` (smashing the east wall open onto
    /// the Strange Passage), and climb to the Treasure Room (+25).
    static let mazeToLair: [String] = [
        "west",  // Maze-1
        "west", "west", "up",  // Maze-4 → Maze-3 → Maze-5
        "take bag of coins",  // +10
        "take skeleton key",
        "southwest", "east", "south", "southeast",  // → Cyclops Room
        "odysseus",  // routs the cyclops
        "up",  // Treasure Room (+25); the thief is summoned to defend it
    ]

    /// Hand the thief the egg — his careful hands open it cleanly (a 4-turn
    /// service), where yours would wreck the canary — then drop to the Cyclops
    /// Room, out of his lair-scoped reach, and wait the service out.
    static let giveEggAndFlee: [String] = [
        "give egg to thief",
        "down",  // Cyclops Room (safe: his aggression is gated to the lair)
        "wait", "wait", "wait", "wait", "wait",  // the egg service completes
        "score",
    ]

    /// Back up into the lair; the thief is re-summoned. Cut him down (seed 32
    /// lands it in one) — his satchel bursts, scattering the whole hoard: the
    /// opened egg and its intact canary, the silver chalice, and his stiletto.
    static let returnAndKill: [String] = [
        "up",  // Treasure Room — thief re-summoned
        "attack thief", "attack thief", "attack thief",
        "take chalice",  // the guard lifts once he is dead (+10)
        "look in egg",  // the egg holds the intact canary — the clean service worked
        "take all",  // sweep up the hoard
        "score",
    ]

    // ── PHASE B (deterministic — the thief is dead, no randomness remains) ──

    static let phaseB: [String] =
        b1ExitLairAndBank + b2HubBarDam + b3BankHeavy + b4Temple + b5CoalMine
        + b6ExitMineBank + b7CoffinPrayAndCanary + b8Pot + b9River + b10Endgame

    /// Drop the junk, carry the hoard out through the Strange Passage to the
    /// Living Room, and bank the three treasures that need no forest errand.
    static let b1ExitLairAndBank: [String] = [
        "drop stiletto", "drop skeleton key",
        "down",  // Cyclops Room
        "east", "east",  // Strange Passage → Living Room
        "put chalice in trophy case",  // +5
        "put bag of coins in trophy case",  // +5
        "put egg in trophy case",  // +5
        "score",
    ]

    /// Resupply (garlic for the bat, rope for the dome), then sweep the hub —
    /// East-West Passage (+5), the Loud Room's platinum bar (+10) — and the Dam:
    /// charge the panel, take the wrench/screwdriver/matchbook, drain the
    /// reservoir for the trunk (+15), and lift the hand pump.
    static let b2HubBarDam: [String] = [
        "east",  // Kitchen
        "take garlic",
        "up", "take rope", "down",  // attic rope
        "west",  // Living Room
        "open trap door", "down",  // Cellar (thief dead → the trap door reopens)
        "south", "east", "take painting", "west", "north",  // Gallery painting (+4)
        "north",  // Troll Room
        "east",  // East-West Passage (+5)
        "east",  // Round Room
        "east", "echo", "take platinum bar",  // Loud Room (+10)
        "west",  // Round Room
        "north", "northeast", "east",  // N-S Passage → Deep Canyon → Dam
        "north", "north",  // Dam Lobby → Maintenance Room
        "take wrench", "take screwdriver", "push yellow button",
        "south", "take matchbook",  // Dam Lobby
        "south",  // Dam
        "turn bolt with wrench",  // drain begins
        "west",  // Reservoir South
        "drop sword", "drop wrench",  // spent: no combat left, the gates are open
        "wait", "wait", "wait", "wait", "wait", "wait", "wait", "wait",
        "north", "take trunk",  // Reservoir bed (+15)
        "north", "take pump",  // Reservoir North
        "score",
    ]

    /// Bank the heavy treasures (painting, bar, trunk) via the reopened trap
    /// door, and stash the tools the temple's altar-crack won't admit.
    static let b3BankHeavy: [String] = [
        "south", "south",  // Reservoir North → bed → Reservoir South
        "southeast",  // Deep Canyon
        "southwest",  // N-S Passage
        "south",  // Round Room
        "west", "west",  // East-West Passage → Troll Room
        "south",  // Cellar
        "open trap door", "up",  // Living Room
        "put painting in trophy case",  // +6
        "put platinum bar in trophy case",  // +5
        "put trunk in trophy case",  // +5
        "drop garlic", "drop screwdriver", "drop pump", "drop canary",
        "score",
    ]

    /// The Temple skull light-dive — carry only the lantern, rope and matchbook,
    /// as the altar crack down to Hades caps the load near fifty. Tie the rope,
    /// take the ivory torch (+14) and TURN OFF THE LANTERN (the fuel handoff),
    /// gather the exorcism kit, run the ritual at the gate and lift the crystal
    /// skull (+10). Out through the mirror region for the crystal trident (+4),
    /// down the one-way slide to bank skull and trident.
    static let b4Temple: [String] = [
        "open trap door", "down",  // Cellar
        "north",  // Troll Room
        "east", "east",  // East-West Passage → Round Room
        "southeast", "east",  // Engravings Cave → Dome Room
        "tie rope to railing", "down",  // Torch Room
        "take torch", "turn off lantern",  // ── LIGHT HANDOFF ──
        "south", "take bell",  // Temple
        "south", "take book", "take candles",  // Altar
        "down", "down",  // Cave → Entrance to Hades
        "ring bell", "light matches", "light candles", "read book",  // exorcism
        "south", "take skull",  // Land of the Dead (+10)
        "drop bell", "drop book", "drop candles", "drop matchbook",  // spent kit
        "north",  // Entrance to Hades
        "up",  // Cave (the Tiny Cave)
        "north",  // Mirror Room North
        "touch mirror",  // → Mirror Room South
        "east", "down", "take trident",  // Small Cave → Atlantis (+4)
        "up", "north",  // Small Cave → Mirror Room South
        "north", "west",  // Cold Passage → Slide Room
        "down",  // one-way slide → Cellar
        "open trap door", "up",  // Living Room
        "put crystal skull in trophy case",  // +10
        "put crystal trident in trophy case",  // +11
        "score",
    ]

    /// The Coal Mine. Reclaim garlic and screwdriver; garlic wards the bat
    /// (jade, +5). Stash torch and screwdriver in the basket, light the lantern
    /// for the flameless gas room (bracelet, +5), fetch the coal, lower the
    /// basket, squeeze the empty-handed crack to the Drafty Room (+13), work the
    /// machine to make the diamond (+10), and raise it back up.
    static let b5CoalMine: [String] = [
        "take garlic", "take screwdriver",  // reclaim from the Living Room floor
        "open trap door", "down",  // Cellar
        "north",  // Troll Room
        "east", "east",  // East-West Passage → Round Room
        "south", "south",  // Narrow Passage → Mirror Room North
        "touch mirror", "north", "west", "north",  // → Slide Room → Mine Entrance
        "west",  // Squeaky Room
        "north",  // Bat Room (garlic keeps the bat off)
        "take figurine",  // jade (+5)
        "east",  // Shaft Room
        "put torch in basket", "put screwdriver in basket",
        "turn on lantern",  // the gas room needs the flameless lantern
        "north", "down",  // Smelly Room → Gas Room
        "take bracelet",  // +5
        "east", "northeast", "southeast", "southwest", "down", "down",  // maze → Ladder Bottom
        "south", "take coal", "north",  // Dead End and back
        "up", "up", "north", "east", "south",  // Ladder Top → maze → Coal Mine 1
        "north", "up", "south",  // Gas → Smelly → Shaft Room
        "put coal in basket",
        "lower basket",
        "north", "down",  // Smelly → Gas
        "east", "northeast", "southeast", "southwest", "down", "down",  // maze → Ladder Bottom
        "west",  // Timber Room
        "drop all",  // the crack admits only empty hands
        "west",  // Drafty Room (+13), lit by the torch in the basket
        "take torch", "take coal", "take screwdriver",
        "south",  // Machine Room
        "open machine", "put coal in machine", "close machine",
        "turn switch with screwdriver",  // the diamond is made
        "open machine", "take diamond",  // +10
        "north",  // Drafty Room
        "put all in basket",
        "east", "take all",  // Timber Room, reclaim jade/bracelet/lantern
        "east",  // Ladder Bottom
        "up", "up", "north", "east", "south",  // Ladder Top → maze → Coal Mine 1
        "north", "up", "south",  // Gas → Smelly → Shaft Room
        "raise basket",
        "take diamond", "take torch",
        "score",
    ]

    /// Turn the lantern off (the torch carries the light again) and climb out of
    /// the mine, down the slide to the Cellar, up to bank jade, bracelet, diamond.
    static let b6ExitMineBank: [String] = [
        "turn off lantern",
        "west",  // Bat Room
        "south",  // Squeaky Room
        "east",  // Mine Entrance
        "south",  // Slide Room
        "down",  // Cellar
        "drop garlic", "drop screwdriver",  // spent
        "open trap door", "up",  // Living Room
        "put figurine in trophy case",  // +5
        "put bracelet in trophy case",  // +5
        "put diamond in trophy case",  // +10
        "score",
    ]

    /// The coffin can leave the temple only by prayer, which drops the player in
    /// the forest — so this trip doubles as the canary's forest errand. Take the
    /// sceptre (+4) and gold coffin (+10), pray to the forest, wind the canary
    /// for the brass bauble (+1), and bank coffin, canary and bauble (the
    /// sceptre stays back for the rainbow).
    static let b7CoffinPrayAndCanary: [String] = [
        "take canary",  // reclaim from the Living Room floor
        "open trap door", "down",  // Cellar
        "north",  // Troll Room
        "east", "east",  // East-West Passage → Round Room
        "southeast", "east",  // Engravings → Dome
        "down",  // Torch Room (rope still tied)
        "south",  // Temple
        "east",  // Egyptian Room
        "open coffin", "take sceptre", "take coffin",  // +4 sceptre
        "west", "south",  // Temple → Altar
        "pray",  // → Forest, coffin + sceptre in hand
        "wind canary",  // a songbird drops the brass bauble
        "take bauble",  // +1
        "east",  // West of House
        "south", "east", "west",  // South of House → Behind House → Kitchen
        "west",  // Living Room
        "put coffin in trophy case",  // +15
        "put canary in trophy case",  // +4
        "put bauble in trophy case",  // +1
        "score",
    ]

    /// The pot of gold — an above-ground errand, since the sceptre's sharp point
    /// would hole the river boat (a FIDELITY divergence). Walk the canyon to the
    /// End of Rainbow, wave the sceptre to turn the rainbow solid (it stays
    /// solid — the river dive's return route), take the pot (+10), bank pot and
    /// sceptre.
    static let b8Pot: [String] = [
        "east", "east",  // Kitchen → Behind House
        "east",  // Forest East
        "southeast", "down", "down", "north",  // canyon → End of Rainbow
        "wave sceptre",  // the rainbow solidifies; the pot appears
        "take pot",  // +10
        "south", "up", "up", "northwest",  // canyon back → Forest East
        "west", "west", "west",  // Behind House → Kitchen → Living Room
        "put pot in trophy case",  // +10
        "put sceptre in trophy case",  // +6
        "score",
    ]

    /// The Frigid River, sceptre safely banked. Reclaim the pump, launch from
    /// the Dam Base, drift to River-4 for the buoy's emerald (+5), land and dig
    /// out the scarab (+5), then cross the now-solid rainbow and canyon home to
    /// bank emerald and scarab.
    static let b9River: [String] = [
        "take pump",  // reclaim from the Living Room floor
        "open trap door", "down",  // Cellar
        "north",  // Troll Room
        "east", "east",  // East-West Passage → Round Room
        "north", "northeast", "east",  // N-S Passage → Deep Canyon → Dam
        "down",  // Dam Base
        "inflate plastic with pump",
        "enter boat", "launch boat",  // → River-1 (nothing sharp aboard now)
        "down", "down", "down",  // → River-4
        "take buoy",
        "east",  // Sandy Beach
        "disembark",
        "open buoy", "take emerald",  // +5
        "take shovel",
        "northeast",  // Sandy Cave
        "dig sand with shovel", "dig sand with shovel", "dig sand with shovel",
        "take scarab",  // +5
        "southwest",  // Sandy Beach
        "south", "south",  // Shore → Aragain Falls
        "west", "west",  // On Rainbow → End of Rainbow (rainbow still solid)
        "south", "up", "up", "northwest",  // canyon → Forest East
        "west", "west", "west",  // Behind House → Kitchen → Living Room
        "put emerald in trophy case",  // +10
        "put scarab in trophy case",  // +5
        "score",
    ]

    /// The endgame. Banking the ivory torch — the nineteenth treasure — reveals
    /// the ancient map. Walk to West of House and take the path it opens,
    /// southwest to the Stone Barrow, and step inside to win at 350.
    static let b10Endgame: [String] = [
        "turn on lantern",  // a light in hand once the torch is cased
        "put torch in trophy case",  // +6 → nineteenth treasure → the map appears
        "score",  // 350 — the rank of Master of the Underground
        "east", "east",  // Kitchen → Behind House
        "south", "west",  // South of House → West of House
        "southwest",  // the map's path → Stone Barrow → the game is won
    ]
}
