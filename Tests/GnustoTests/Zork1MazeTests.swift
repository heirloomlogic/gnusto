import Foundation
import Gnusto
import GnustoTestSupport
import Testing

@testable import Zork1

/// End-to-end playthroughs of the Phase 10.10 maze region: the fifteen twisting
/// passages and four dead ends west of the Troll Room, the skeleton's cache in
/// Maze-5 (skeleton key, bag of coins, rusty knife), the grating up into the
/// forest Clearing, and the Cyclops Room with its two ways past the giant —
/// feeding him to sleep or shouting `odysseus` to send him through the east wall
/// onto the Strange Passage home.
///
/// Seed 39: the prelude kills the troll to reach the
/// maze, and — because the thief daemon draws every turn — the seed that lands
/// the recorded three-blow kill depends on the prelude's length. Once past the
/// troll the thief stays penned in the cellar and the maze itself is draw-free,
/// so everything after arrival is deterministic. The prelude carries the lunch
/// and the water bottle so a single seed serves every test.
struct Zork1MazeTests {
    /// Gather the lunch and bottle (kitchen), sword and lit lantern (living
    /// room), descend, kill the troll, and step west into Maze-1 — then thread
    /// the known way to Maze-5 and the skeleton's cache: west, west, up.
    static let toMaze5: [String] = [
        "south", "east", "open window", "west",
        "take lunch", "take bottle", "west",
        "take sword", "take lantern", "turn on lantern",
        "push rug", "open trap door", "down",
        "north",
        "attack troll", "attack troll", "attack troll",
        "west",  // into the maze (Maze-1)
        "west", "west", "up",  // Maze-4 → Maze-3 → Maze-5
    ]

    @Test func theSkeletonInMazeFiveGivesUpItsCache() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toMaze5 + [
                "take skeleton key",
                "take bag of coins",  // +10 on the find
                "take rusty knife",
                "score",
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "slumps to the floor dead",  // the troll falls, opening the west way
                "remains of a luckless adventurer",  // Maze-5's landmark
                "There is a skeleton key here.",  // the key, placed at last
                "bulging with coins",
                "Beside the skeleton is a rusty knife.",
                "Taken.",
                // Kitchen (10) + cellar (25) + the bag of coins (10) = 45.
                "Your score is 45 of a possible 350",
            ])
    }

    @Test func theGratingIsARealDoorUpIntoTheClearing() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toMaze5 + [
                "take skeleton key",
                "southwest", "up", "down", "northeast",  // Maze-6 → Maze-9 → Maze-11 → Grating Room
                "unlock grating with skeleton key",
                "open grating",
                "up",  // out into the forest Clearing
                "down",  // and back down again — the door works both ways now
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "Grating Room",
                "Unlocked.",
                "pile of leaves falls onto",  // opening it from below showers the forest's leaves
                "Clearing",  // up into daylight
                "Grating Room",  // and back down through the open grate
            ])
    }

    @Test func theCyclopsBarsTheWayUntilOdysseusRoutsHim() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toMaze5 + [
                "southwest", "east", "south", "southeast",  // Maze-6 → Maze-7 → Maze-15 → Cyclops Room
                "up",  // barred — he blocks the stairs
                "east",  // barred — the wall is solid
                "odysseus",  // he flees, smashing the east wall
                "east",  // Strange Passage, now open
                "east",  // the great shortcut: the Living Room
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "Cyclops Room",
                "prepared to eat horses",
                "The cyclops doesn't look like he'll let you past.",  // up barred
                "The east wall is solid rock.",  // east barred
                "knocking down the wall",  // odysseus routs him
                "Strange Passage",
                "Living Room",
            ])
    }

    @Test func feedingTheCyclopsPutsHimToSleepAndOpensTheStairs() async throws {
        let transcript = try await play(
            Zork1(),
            Self.toMaze5 + [
                "southwest", "east", "south", "southeast",  // → Cyclops Room
                "give lunch to cyclops",  // he eats, turns thirsty
                "open bottle",
                "give bottle to cyclops",  // he drinks himself to sleep
                "up",  // the stairs are clear now
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "I love hot peppers",
                "drinks the water",
                "fast asleep",
                "Treasure Room",  // the stair is clear
            ])
        // Feeding him to sleep never smashes the east wall — no shortcut home.
        #expect(!transcript.contains("Strange Passage"))
    }

    @Test func theMazeThreadsPastItsDeadEnds() async throws {
        // A short draw-free walk from Maze-5: east into a dead end, back, and
        // southwest onward — proving the tangle's landmarks by name (every maze
        // passage shares the title "Maze", so a dead end and the Cyclops Room
        // are the only landmarks that distinguish where you are).
        let transcript = try await play(
            Zork1(),
            Self.toMaze5 + [
                "east",  // Maze-5 → Dead End (Dead-End-2)
                "west",  // back to Maze-5
                "southwest", "east", "south", "southeast",  // → Cyclops Room
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "remains of a luckless adventurer",  // Maze-5
                "Dead End",
                "dead end in the maze",
                "Cyclops Room",  // the far landmark
            ])
    }

    @Test func attackingTheCyclopsWakesHisHungerAndGetsYouEaten() async throws {
        // Steel can't beat him, but attacking rouses his hunger: from there the
        // wrath ladder climbs one rung a turn until, on the seventh, he eats you
        // (the original's `CYCLOWRATH` / `I-CYCLOPS`). Death is survivable, so
        // the run resurrects rather than ending.
        let transcript = try await play(
            Zork1(),
            Self.toMaze5 + [
                "southwest", "east", "south", "southeast",  // → Cyclops Room
                "attack cyclops", "attack cyclops", "attack cyclops",
                "attack cyclops", "attack cyclops", "attack cyclops",
                "attack cyclops",  // the seventh — he's had enough of you
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "Cyclops Room",
                "shrugs but otherwise ignores your pitiful attempt",  // steel is futile
                "The cyclops seems somewhat agitated.",  // cyclomad[0], the first rung
                "You have two choices: 1. Leave  2. Become dinner.",  // cyclomad[5], the last
                "Just like Mom used to make",  // he eats you
                "you probably deserve another",  // …and you're resurrected
            ])
    }

    @Test func disturbingTheSkeletonBanishesYourLoot() async throws {
        // Taking the bones wakes the ghost, who curses your valuables to the
        // Land of the Dead — all but the lamp, which is spared so light is never
        // lost (as the death scatter spares it).
        let transcript = try await play(
            Zork1(),
            Self.toMaze5 + [
                "take bag of coins",  // something worth cursing
                "take bones",  // desecration — the ghost appears
                "inventory",
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "bulging with coins",  // the bag is in hand…
                "banishes them to the Land of the Living Dead",  // …then the curse takes it
            ])
        let carried = turnOutput(of: "inventory", in: transcript)
        #expect(carried.contains("lantern"))  // the lamp is spared
        #expect(!carried.contains("coins"))  // the bag was banished
    }

    @Test func searchingOrMovingTheBonesAlsoCursesYou() async throws {
        // The curse fires on `search` (`.lookIn`) and `move` (`.push`) too, not
        // just `take` — so the ghost appears twice here.
        let transcript = try await play(
            Zork1(),
            Self.toMaze5 + [
                "take bag of coins",
                "search bones",  // .lookIn — banishes the bag
                "move bones",  // .push — nothing left to take, but he's still appalled
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "casts a curse on your valuables",  // search bones
                "casts a curse on your valuables",  // move bones
            ])
    }
}
