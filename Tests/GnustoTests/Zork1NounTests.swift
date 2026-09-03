import Foundation
import Gnusto
import GnustoTestSupport
import Testing

@testable import Zork1

/// The #407 sweep: every noun a room description prints must answer an `x`.
///
/// Two plays. The first walks the forest-and-house ring with no combat in the
/// way; the second runs the 350-point walkthrough's seed-sensitive phase A
/// exactly as ``Zork1WalkthroughTests`` pins it — the extra turns of inserted
/// `x` lines would shift the thief's dice — and interleaves the sweep's `x`
/// lines into the deterministic phase B that follows. Neither transcript may
/// print "You can't see any such thing." beyond the walkthrough's own third
/// blows landing on bodies the first two killed.
struct Zork1NounTests {
    /// The walkthrough's own pinned seed.
    static let seed: UInt64 = 0

    @Test func everyPrintedNounAnswersExamine() async throws {
        let ring = try await play(Zork1(), Self.ring, seed: Self.seed)
        let sweep = try await play(Zork1(), Self.sweep, seed: Self.seed)
        // A clean sweep never prints the refusal. The sweep play permits
        // exactly two: the walkthrough's third blows, landing on bodies the
        // first two already killed. The ring has no combat at all.
        #expect(ring.components(separatedBy: "You can't see any such thing.").count == 1)
        #expect(
            sweep.components(separatedBy: "You can't see any such thing.").count == 3)
        #expect(!ring.contains("don't know the word"))
        #expect(!sweep.contains("don't know the word"))
        #expect(sweep.contains("Land of the Dead"))
        #expect(sweep.contains("Aragain Falls"))
        // The full 350-point win: nothing the route needed was left behind.
        #expect(sweep.contains("You have mastered ZORK"))
    }

    // MARK: - Play one: the forest-and-house ring, no combat

    static let ring: [String] = [
        "west",  // Forest (west)
        "x trees", "x sunlight",
        "east",  // West of House
        "x field", "x house", "x door", "x mailbox",
        "north",  // North of House
        "x trees", "x windows", "x path",
        "north",  // Forest Path
        "x branches", "x tree",
        "up",  // Up a Tree
        "x branches", "x nest",
        "down", "south", "west",  // → West of House
        "south", "east", "open window", "west",  // → Kitchen
        "x table", "x staircase", "x passage", "x chimney", "x peppers",
        "x window", "x sack", "x bottle",
        "west",  // Living Room
        "x doorway", "x wooden door", "x lettering",
        "take lantern", "turn on lantern",
        "move rug", "open trap door", "down",  // Cellar
        "x passageway", "x crawlway", "x ramp",
        "south",  // East of Chasm
        "x chasm", "x passage",
        "east",  // Gallery
        "x paintings", "x vandals", "x painting",
        "north",  // Studio
        "x fireplace", "x paints",
        "south", "west", "north",  // Gallery → East of Chasm → Cellar
    ]

    // MARK: - Play two: the walkthrough's phase A, the sweep's phase B

    static let sweep: [String] =
        phaseA + b1 + b2 + b3 + b4 + b5 + b6 + b7 + b8 + b9 + b10

    /// Phase A, verbatim from ``Zork1WalkthroughTests`` — pinned dice, no
    /// inserted turns.
    static let phaseA: [String] = [
        "north", "north", "up", "take egg", "down",
        "south", "west",  // → West of House
        "south", "east", "open window", "west",  // → Kitchen
        "west",  // Living Room
        "take sword", "take lantern", "turn on lantern", "open trophy case",
        "move rug", "open trap door", "down",  // Cellar
        "north",  // Troll Room
        "attack troll", "attack troll", "attack troll",
        "west",  // Maze-1
        "west", "west", "up",  // → Maze-5
        "take bag of coins",
        "take skeleton key",
        "southwest", "east", "south", "southeast",  // → Cyclops Room
        "odysseus",
        "up",  // Treasure Room
        "give egg to thief",
        "down",  // Cyclops Room
        "wait", "wait", "wait", "wait", "wait",
        "up",  // Treasure Room — thief re-summoned
        "attack thief", "attack thief", "attack thief",
        "look in egg",
        "take all",
    ]

    static let b1: [String] = [
        "drop stiletto", "drop skeleton key",
        "down",  // Cyclops Room
        "east",  // Strange Passage
        "x wooden door", "x opening",
        "east",  // → Living Room
        "put chalice in trophy case",
        "put bag of coins in trophy case",
        "put egg in trophy case",
    ]

    /// Resupply, sweep the hub (with the Loud Room and the White Cliffs
    /// beaches), and drain the reservoir — plus the Gallery and Studio nouns.
    static let b2: [String] = [
        "east",  // Kitchen
        "take garlic",
        "up",  // Attic
        "x stairway",
        "take rope", "down",
        "west",  // Living Room
        "open trap door", "down",  // Cellar
        "south", "east", "take painting",  // Gallery
        "x paintings", "x vandals",
        "north",  // Studio
        "x fireplace", "x paints",
        "south", "west", "north", "north",  // Gallery → East of Chasm → Cellar → Troll Room
        "east",  // East-West Passage
        "x stairway",
        "east",  // Round Room
        "x cave-ins",
        "east", "echo", "take platinum bar",  // Loud Room
        "east",  // Damp Cave
        "x crack",
        "east",  // White Cliffs Beach (north)
        "x passage",
        "south",  // White Cliffs Beach (south)
        "north", "west", "west", "west",  // back: Beach → Damp → Loud → Round
        "north", "northeast",  // N-S Passage → Deep Canyon
        "east",  // Dam
        "x bolt", "x panel",
        "north",  // Dam Lobby
        "x doorways", "x desk", "x guidebook",
        "north",  // Maintenance Room
        "x doorways", "x wall", "x equipment",
        "take wrench", "take screwdriver", "push yellow button",
        "south", "take matchbook",  // Dam Lobby
        "south",  // Dam
        "turn bolt with wrench",
        "west",  // Reservoir South
        "x lake",
        "drop sword", "drop wrench",
        "wait", "wait", "wait", "wait", "wait", "wait", "wait", "wait",
        "north", "take trunk",  // Reservoir bed
        "x mud", "x shores",
        "up",  // Stream
        "x beach",
        "down", "north", "take pump",  // Reservoir North
        "x stairway",
    ]

    static let b3: [String] = [
        "south", "south",  // Reservoir North → bed → Reservoir South
        "southeast",  // Deep Canyon
        "southwest",  // N-S Passage
        "south",  // Round Room
        "west", "west",  // East-West Passage → Troll Room
        "south",  // Cellar
        "open trap door", "up",  // Living Room
        "put painting in trophy case",
        "put platinum bar in trophy case",
        "put trunk in trophy case",
        "drop garlic", "drop screwdriver", "drop pump", "drop canary",
    ]

    /// The Temple skull light-dive, with the Dome, Temple, Altar, Hades and
    /// mirror-region nouns examined on the way through.
    static let b4: [String] = [
        "open trap door", "down",  // Cellar
        "north",  // Troll Room
        "east", "east",  // → Round Room
        "southeast", "east",  // Engravings Cave → Dome Room
        "x dome", "x railing",
        "tie rope to railing", "down",  // Torch Room
        "x pedestal",
        "take torch", "turn off lantern",
        "south", "take bell",  // Temple
        "x inscription", "x prayer", "x staircase", "x pillars", "x granite",
        "south", "take book", "take candles",  // Altar
        "x altar", "x hole",
        "down",  // Cave
        "down",  // Entrance to Hades
        "x gateway", "x inscription", "x bodies", "x voices",
        "ring bell", "light matches", "light candles", "read book",
        "south", "take skull",  // Land of the Dead
        "x souls", "x remains",
        "drop book", "drop candles", "drop matchbook",
        "north",  // Entrance to Hades
        "up",  // Cave
        "north",  // Mirror Room North
        "x wall", "x ceiling", "x mirror",
        "touch mirror",  // → Mirror Room South
        "x wall", "x ceiling",
        "east", "down", "take trident",  // Small Cave → Atlantis
        "x staircase",
        "up", "north",  // → Mirror Room South
        "north", "west",  // Cold Passage → Slide Room
        "x letters", "x slide", "x rock", "x opening",
        "down",  // one-way slide → Cellar
        "open trap door", "up",  // Living Room
        "put crystal skull in trophy case",
        "put crystal trident in trophy case",
    ]

    /// The Coal Mine, with every mine noun examined in place.
    static let b5: [String] = [
        "take garlic", "take screwdriver",
        "open trap door", "down",  // Cellar
        "north",  // Troll Room
        "east", "east",  // → Round Room
        "south", "south",  // Narrow Passage → Mirror Room North
        "touch mirror", "north", "west", "north",  // → Slide Room → Mine Entrance
        "x shaft",
        "west",  // Squeaky Room
        "x passage",
        "north",  // Bat Room
        "x doors",
        "take figurine",
        "east",  // Shaft Room
        "x shaft", "x framework", "x chain",
        "put torch in basket", "put screwdriver in basket",
        "turn on lantern",
        "north",  // Smelly Room
        "x staircase", "x odor", "x tunnel",
        "down",  // Gas Room
        "x stairs", "x tunnel", "x gas",
        "take bracelet",
        "east", "northeast", "southeast", "southwest", "down", "down",  // → Ladder Bottom
        "x ladder",
        "south", "take coal", "north",  // Dead End and back
        "up", "up", "north", "east", "south",  // → Coal Mine 1
        "north", "up", "south",  // Gas → Smelly → Shaft Room
        "put coal in basket",
        "lower basket",
        "north", "down",  // Smelly → Gas
        "east", "northeast", "southeast", "southwest", "down", "down",  // → Ladder Bottom
        "west",  // Timber Room
        "x timbers",
        "drop all",
        "west",  // Drafty Room
        "x shaft", "x chain",
        "take torch", "take coal", "take screwdriver",
        "south",  // Machine Room
        "open machine", "put coal in machine", "close machine",
        "turn switch with screwdriver",
        "open machine", "take diamond",
        "north",  // Drafty Room
        "put all in basket",
        "east", "take all",  // Timber Room
        "east",  // Ladder Bottom
        "up", "up", "north", "east", "south",  // → Coal Mine 1
        "north", "up", "south",  // Gas → Smelly → Shaft Room
        "raise basket",
        "take diamond", "take torch",
    ]

    static let b6: [String] = [
        "turn off lantern",
        "west",  // Bat Room
        "south",  // Squeaky Room
        "east",  // Mine Entrance
        "south",  // Slide Room
        "down",  // Cellar
        "drop garlic",
        "open trap door", "up",  // Living Room
        "put figurine in trophy case",
        "put bracelet in trophy case",
        "put diamond in trophy case",
    ]

    static let b7: [String] = [
        "take canary",
        "open trap door", "down",  // Cellar
        "north",  // Troll Room
        "east", "east",  // → Round Room
        "southeast", "east",  // → Dome
        "down",  // Torch Room (rope still tied)
        "south",  // Temple
        "east",  // Egyptian Room
        "x tomb", "x staircase",
        "open coffin", "take sceptre", "take coffin",
        "west", "south",  // Temple → Altar
        "pray",  // → Forest
        "wind canary",
        "take bauble",
        "east",  // West of House
        "x field",
        "south",  // South of House
        "x windows",
        "east",  // Behind House
        "x path", "x window",
        "west",  // Kitchen
        "west",  // Living Room
        "put coffin in trophy case",
        "put canary in trophy case",
        "put bauble in trophy case",
    ]

    /// The pot of gold: the canyon's nouns are examined on the walk down.
    static let b8: [String] = [
        "east", "east",  // Kitchen → Behind House
        "east",  // Forest East
        "x trees",
        "southeast",  // Canyon View
        "x canyon", "x river", "x cliffs", "x mountains",
        "x rainbow", "x cavern", "x ramparts",
        "down",  // Rocky Ledge
        "x cliff",
        "down", "north",  // → End of Rainbow
        "x rainbow",
        "wave sceptre",
        "take pot",
        "south", "up", "up", "northwest",  // canyon back → Forest East
        "west", "west", "west",  // → Living Room
        "put pot in trophy case",
        "put sceptre in trophy case",
    ]

    /// The Frigid River. The current carries the boat downstream when it
    /// lingers, so the river's nouns are examined in the two quiet reaches —
    /// dam, shore, cliffs, rocks, valley — and the ride then follows the
    /// walkthrough's timing exactly. Sandy Beach, Shore and Aragain Falls are
    /// examined on foot.
    static let b9: [String] = [
        "take pump",
        "open trap door", "down",  // Cellar
        "north",  // Troll Room
        "east", "east",  // → Round Room
        "north", "northeast", "east",  // → Dam
        "down",  // Dam Base
        "x cliffs", "x river", "x shores",
        "inflate plastic with pump",
        "enter boat", "launch boat",  // → River-1
        "x dam", "x shore", "x landing",
        "down",  // River-2
        "x cliffs", "x rocks",
        "down",  // River-3
        "x valley",
        "down",  // River-4
        "take buoy",
        "east",  // Sandy Beach
        "disembark",
        "x path", "x passage", "x sand",
        "open buoy", "take emerald",
        "take shovel",
        "northeast",  // Sandy Cave
        "x sand",
        "dig sand with shovel", "dig sand with shovel", "dig sand with shovel",
        "take scarab",
        "southwest",  // Sandy Beach
        "south",  // Shore
        "x shore", "x path", "x corner",
        "south",  // Aragain Falls
        "x falls", "x waterfall",
        "west", "west",  // On Rainbow → End of Rainbow (rainbow still solid)
        "south", "up", "up", "northwest",  // canyon → Forest East
        "west", "west", "west",  // → Living Room
        "put emerald in trophy case",
        "put scarab in trophy case",
    ]

    /// The endgame, with the barrow's nouns examined before stepping inside.
    static let b10: [String] = [
        "turn on lantern",
        "put torch in trophy case",
        "east", "east",  // Kitchen → Behind House
        "south", "west",  // South of House → West of House
        "southwest",  // the map's path → Stone Barrow
        "x barrow", "x door", "x tomb",
        "west",  // step inside the barrow → the game is won
    ]
}
