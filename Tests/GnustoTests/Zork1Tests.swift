import Foundation
import Gnusto
import GnustoTestSupport
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
                "WELCOME TO ZORK",
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
                "The door cannot be opened.",
                "South of House",
                "Behind House",
                "Opened.",
                "Kitchen",
            ])
    }

    /// The Phase-5 dark-cellar soft-lock is closed: with the brass lantern
    /// lit, the trap door's slam is an inconvenience, not a prison. The full
    /// loop — Cellar → East of Chasm → Gallery (painting) → Studio → up the
    /// chimney into the Kitchen — runs by lantern light, exercising the
    /// reveal-on-descent, the lit `dark`-trait rooms, and the one-way
    /// chimney in a single walk.
    @Test func cellarLoopByLanternLight() async throws {
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west", "west",
                "take lantern", "turn on lantern",
                "push rug", "open trap door", "down",
                "south", "east", "take painting", "north", "up",
            ])

        expectInOrder(
            transcript,
            [
                "Living Room",
                "Taken.",
                "The brass lantern is now on.",
                "the rug is moved to one side of the room",
                "Opened.",
                "The trap door crashes shut, and you hear someone barring it.",
                "Cellar",
                "East of Chasm",
                "Gallery",
                "Taken.",
                "Studio",
                "Kitchen",
            ])
        // The lit cellar is a described room now, never pitch black.
        #expect(!transcript.contains("It is pitch black."))
    }

    /// The other way out of the sealed cellar: a lightless dash to the lit
    /// Gallery and up the chimney. The dark rooms stay pitch black; the
    /// exits still work.
    @Test func chimneyEscapeInTheDark() async throws {
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west", "west",
                "push rug", "open trap door", "down",
                "south", "east", "north", "up",
            ])

        expectInOrder(
            transcript,
            [
                "The trap door crashes shut, and you hear someone barring it.",
                "It is pitch black. You are likely to be eaten by a grue.",
                "Gallery",
                "Kitchen",
            ])
    }

    /// The lantern's fuel is three fuses now: a dim warning at 200 turns, a
    /// last-gasp warning at 225, and darkness for good at 230. `wait` fillers
    /// drive the long burn (the numbers are scaled toward the original since
    /// the game is playable end to end — see `FIDELITY.md`).
    @Test func lanternBurnsOut() async throws {
        let waits = Array(repeating: "wait", count: 230)
        let transcript = try await play(
            Zork1(),
            ["south", "east", "open window", "west", "west", "take lantern", "turn on lantern"]
                + waits
                + ["turn on lantern"])
        // The turn-on turn ticks once, so warning K fires on wait #(K−1):
        // dim at 200, last-gasp at 225, dark at 230.
        let turns = transcript.components(separatedBy: "> wait")
        #expect(!turns[198].contains("a bit dimmer"))
        #expect(turns[199].contains("a bit dimmer"))
        #expect(turns[224].contains("nearly out"))
        #expect(turns[229].contains("more light than from the brass lantern"))
        // Spent is spent: relighting a burned-out lantern refuses.
        let relights = transcript.components(separatedBy: "> turn on lantern")
        #expect(relights[2].contains("burned-out lamp"))
    }

    /// Darkness is lethal, but not final: a warning on the first dark turn,
    /// one silent turn of grace, the grue on the third — and then Zork's
    /// canonical resurrection, which sets you back on your feet in the forest
    /// rather than reaching for the death prompt. UNDO still revives on the
    /// brink, and the next grue does the same thing all over again.
    @Test func lingeringInTheDarkResurrectsYou() async throws {
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west", "west",
                "push rug", "open trap door", "down",
                "look", "look",
                "undo", "look", "quit",
            ])
        // The descent turn: slam, pitch black, then the warning — in order.
        let descent = turnOutput(of: "down", in: transcript)
        expectInOrder(
            descent,
            [
                "The trap door crashes shut, and you hear someone barring it.",
                "It is pitch black. You are likely to be eaten by a grue.",
                "It is pitch black. You are likely to be eaten by a grue.",
            ])
        let looks = transcript.components(separatedBy: "> look")
        // The grace turn is a reprieve — no grue yet; the third dark turn is the
        // end — but the grue's meal doesn't stick. The death message prints, then
        // you wake in the forest, unstuck and above ground. No banner, no prompt.
        // (The dark-room line and the grue's warning are the same text in Zork,
        // so the grace turn is anchored on the absence of the kill, not the warning.)
        #expect(!looks[1].contains("lurking grue"))
        expectInOrder(
            looks[2],
            [
                "lurking grue",
                "deserve another",
                "Forest",
            ])
        // Two deaths, both survived: the prompt never appears.
        #expect(!transcript.contains("*** You have died ***"))
        #expect(!transcript.contains("Would you like to RESTART"))
        // UNDO revives on the brink (the restored count is 2 — grues are
        // unforgiving); the next dark turn is fatal again, and the second
        // death resurrects just like the first.
        let undo = turnOutput(of: "undo", in: transcript)
        expectInOrder(undo, ["Previous turn undone.", "It is pitch black."])
        expectInOrder(looks[3], ["lurking grue", "deserve another", "Forest"])
    }

    /// Carried light holds the grue off completely: the lantern-lit cellar
    /// loop with extra loitering never draws the warning.
    @Test func theLanternKeepsTheGrueAway() async throws {
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west", "west",
                "take lantern", "turn on lantern",
                "push rug", "open trap door", "down",
                "look", "look", "south", "look", "look", "east", "north",
                "look", "look", "up",
            ])
        expectInOrder(transcript, ["Cellar", "East of Chasm", "Studio", "Kitchen"])
        #expect(!transcript.contains("It is pitch black. You are likely to be eaten by a grue."))
        #expect(!transcript.contains("lurking grue"))
    }

    /// The Phase-7 integration walk: light, timers, death, and a save file
    /// in one transcript — save at the trap door, die to the grue (and be
    /// resurrected in the forest), then RESTORE the save and come back alive
    /// at the save point to start the descent over. (Restoring *from the
    /// death prompt* is exercised at the engine level in `DeathTests`; here
    /// the first death no longer reaches a prompt.)
    @Test func saveSurvivesAGrueResurrectionAndRestores() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("gnusto-zork-\(UUID().uuidString).sav").path
        defer { try? FileManager.default.removeItem(atPath: path) }
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west", "west",
                "push rug", "open trap door", "save", path,
                "down", "look", "look",
                "restore", path, "down",
            ])
        expectInOrder(
            transcript,
            [
                "Saved.",
                "lurking grue",
                // The grue kills, then the resurrection catches you — no
                // banner, just the forest.
                "deserve another",
                "Forest",
                "Restore from what file?",
                "Restored.",
                "Living Room",
                // Alive at the save point: the trap door is still open, and
                // descending starts the whole dance again.
                "The trap door crashes shut, and you hear someone barring it.",
                "It is pitch black. You are likely to be eaten by a grue.",
            ])
        #expect(!transcript.contains("*** You have died ***"))
    }

    @Test func turningTheLanternOffPausesTheFuel() async throws {
        // 198 lit turns burn the dim fuse down to 1 (not yet fired); turning
        // the lantern off banks that 1, so three dark idle turns cost nothing;
        // relighting restarts the fuse at 1, so the dim warning fires at the
        // end of the relight turn itself.
        let burn = Array(repeating: "wait", count: 198)
        let transcript = try await play(
            Zork1(),
            ["south", "east", "open window", "west", "west", "take lantern", "turn on lantern"]
                + burn
                + ["turn off lantern", "wait", "wait", "wait", "turn on lantern"])
        let off = turnOutput(of: "turn off lantern", in: transcript)
        #expect(!off.contains("a bit dimmer"))
        // The dark idle turns never burn the fuse (waits[201], the final
        // split, bleeds into the relight turn where the banked fuse fires, so
        // it's the two cleanly-bounded idle turns that must stay silent).
        let waits = transcript.components(separatedBy: "> wait")
        #expect(!waits[199].contains("a bit dimmer"))
        #expect(!waits[200].contains("a bit dimmer"))
        let relight = transcript.components(separatedBy: "> turn on lantern")[2]
        #expect(relight.contains("The brass lantern is now on."))
        #expect(relight.contains("a bit dimmer"))
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

    @Test func depositPaintingScoresPoints() async throws {
        // The painting pays 4 on first take and 6 on first deposit; taking
        // it back out and re-depositing pays nothing more. The route also
        // banks two visit awards on the way down — the kitchen (10) and the
        // cellar (25) — so the running totals are 39 then 45. Seed 1,
        // recorded: the thief keeps his fingers to himself on this route.
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west", "west",
                "take lantern", "turn on lantern",
                "push rug", "open trap door", "down",
                "south", "east", "take painting", "score",
                "north", "up", "west",
                "open trophy case", "put painting in trophy case", "score",
                "take painting", "put painting in trophy case", "score",
            ],
            seed: 1)

        expectInOrder(
            transcript,
            [
                "Your score is 39 of a possible 350",
                "You put the painting in the trophy case.",
                "Your score is 45 of a possible 350",
            ])
        let scores = transcript.components(separatedBy: "Your score is ")
        #expect(scores.count == 4)
        #expect(scores[3].hasPrefix("45 of a possible 350"))
    }

    @Test func eggScoresOnTheWayIn() async throws {
        let transcript = try await play(
            Zork1(),
            [
                "north", "north", "up", "take egg", "score", "down",
                "south", "west", "south", "east", "open window", "west", "west",
                "open trophy case", "put egg in trophy case", "score",
            ])

        // The egg pays 5 on the way up the tree; crossing into the kitchen
        // through the window pays another 10 (a visit award), and the deposit
        // pays a final 5 — 20 by the time it's cased.
        expectInOrder(
            transcript,
            [
                "Your score is 5 of a possible 350",
                "You put the jewel-encrusted egg in the trophy case.",
                "Your score is 20 of a possible 350",
            ])
    }

    @Test func theTrollDropsHisBloodyAxeToLoot() async throws {
        // The troll kept his axe between you and every exit; felled, he drops
        // it to the Troll Room floor, there for the taking (FIDELITY.md — the
        // bodiless-vanish earlier left nothing to loot). Same recorded seed-39
        // kill as the block test below.
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west", "west",
                "take sword", "take lantern", "turn on lantern",
                "push rug", "open trap door", "down",
                "north", "west",
                "attack troll", "attack troll", "attack troll",
                "take axe",
                "examine axe",
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "The troll takes a fatal blow",  // the death, now with the axe
                "Taken.",  // the axe is looted
                "A heavy war axe",  // and it's the axe in hand
            ])
    }

    @Test func trollBlocksThePassagesUntilDefeated() async throws {
        // Seed 39, recorded (thief daemons on the clock): the troll's
        // swings graze once but never land; the sword goes miss, wound,
        // then the killing blow on the third attack (strength 2).
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west", "west",
                "take sword", "take lantern", "turn on lantern",
                "push rug", "open trap door", "down",
                "north", "west",
                "attack troll", "attack troll", "attack troll",
                "west",
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "Troll Room",
                "A nasty-looking troll, brandishing a bloody axe",
                "The troll fends you off",  // west barred while he lives
                "The troll takes a fatal blow",
                "Maze",  // west now drops into the maze
            ])
        // Defeat is permanent and the room empties.
        let afterDeath = transcript.components(
            separatedBy: "troll takes a fatal blow")[1]
        #expect(!afterDeath.contains("A nasty-looking troll"))
    }

    @Test func theTrollCanKillYou() async throws {
        // Seed 1, recorded: the troll's first swing is the last word — but not
        // a final one. The kill resurrects you in the forest at a cost of ten
        // points, and UNDO still rewinds the whole fatal turn to the brink.
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west", "west",
                "take sword", "take lantern", "turn on lantern",
                "push rug", "open trap door", "down",
                "north",
                "score",
                "undo", "south",
            ],
            seed: 1)
        expectInOrder(
            transcript,
            [
                "neatly removes your head",
                // The kill lands, then the resurrection: forest, no banner.
                "deserve another",
                "Forest",
                // The kitchen (10) and cellar (25) visit awards banked on the
                // way down leave 35; the death docks 10, so the score reads 25.
                "Your score is 25 of a possible 350",
                "Previous turn undone.",
                "East of Chasm",
            ])
        #expect(!transcript.contains("*** You have died ***"))
        #expect(!transcript.contains("Would you like to RESTART"))
    }

    /// Death scatters what you were carrying: the lamp always turns up in the
    /// living room, and everything else lands out among the grounds above.
    /// Here the troll's victim was holding the sword and the (lit) lantern;
    /// after the resurrection the sword is waiting at West of House.
    @Test func deathScattersYourBelongings() async throws {
        // Seed 1, recorded: the troll kills on the first turn in his room.
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west", "west",
                "take sword", "take lantern", "turn on lantern",
                "push rug", "open trap door", "down",
                "north",
                // Resurrected in the forest, empty-handed. The sword scattered
                // to West of House (the first above-ground room in the ring).
                "east", "take sword",
            ],
            seed: 1)
        expectInOrder(
            transcript,
            [
                "neatly removes your head",
                "deserve another",
                "Forest",
                "West of House",
                "Taken.",
            ])
    }

    /// The third death is the last one: after two resurrections the toll comes
    /// due, and the grue's third meal reaches the engine's banner and prompt.
    @Test func theThirdDeathIsFinal() async throws {
        // Seed 1: the player carries nothing (so the grue always finds them in
        // the dark), and only the needles below are asserted, so the roaming
        // thief's comings and goings don't matter.
        let descend = ["open trap door", "down", "wait", "wait"]
        let returnToTrapDoor = ["east", "south", "east", "west", "west"]
        let transcript = try await play(
            Zork1(),
            // First descent and death …
            ["south", "east", "open window", "west", "west", "push rug"]
                + descend
                // … resurrected in the forest; walk back and die again …
                + returnToTrapDoor + descend
                // … and once more, for the final death, then try to UNDO out.
                + returnToTrapDoor + descend
                + ["undo"],
            seed: 1)
        // The first two grue deaths resurrect; the third is final.
        let deaths = transcript.components(separatedBy: "lurking grue")
        #expect(deaths.count == 4)  // three deaths split the transcript into four
        // Deaths one and two are survived — the banner shows up only once, at
        // the very end.
        expectInOrder(
            transcript,
            [
                "lurking grue",  // death 1
                "deserve another",
                "lurking grue",  // death 2
                "deserve another",
                "lurking grue",  // death 3 — final
                "*** You have died ***",
                // 35 banked, then two 10-point tolls: 15 by the final death.
                "Your score is 15 of a possible 350",
                "Would you like to RESTART, RESTORE a saved game, UNDO your last turn, or QUIT?",
                // UNDO from the final prompt still revives on the brink.
                "Previous turn undone.",
            ])
    }

    @Test func theThiefBarsTheTrapDoorFromBelow() async throws {
        // While the thief lives, every descent throws the bolt above: the
        // trap door won't open from the cellar side, but the living-room
        // side is never barred. No seed pin needed — nothing on this route
        // depends on a roll (thief movement lines are extra, tolerated).
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west", "west",
                "take lantern", "turn on lantern",
                "push rug", "open trap door", "down",
                "open trap door",
                "south", "east", "north", "up", "west",
                "open trap door", "down",
                "open trap door",
            ])
        expectInOrder(
            transcript,
            [
                "The trap door crashes shut, and you hear someone barring it.",
                "The trap door crashes shut, and you hear someone barring it.",
                "Gallery",
                "Studio",
                "Kitchen",
                "Living Room",
                "Opened.",
                "The trap door crashes shut, and you hear someone barring it.",
                "The trap door crashes shut, and you hear someone barring it.",
            ])
    }

    @Test func theThiefStealsAndTheSwordGetsItBack() async throws {
        // Seed 247: now that the thief roams the whole
        // underground, a seed where he lingers in the Gallery to pick your
        // pocket and stand for the fight is rarer — this one has him lift the
        // painting during the loiter, then fall to the sword, dropping the loot
        // (and his stiletto) and unbarring the trap door so the route home works.
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west", "west",
                "take sword", "take lantern", "turn on lantern",
                "push rug", "open trap door", "down",
                "south", "east", "take painting",
                "look", "look", "look", "look",
                "attack thief", "attack thief", "attack thief",
                "attack thief", "attack thief", "attack thief",
                "look", "look", "look",
                "take painting", "west", "north", "open trap door", "up",
            ],
            seed: 247)
        expectInOrder(
            transcript,
            [
                "the painting vanished",
                "The thief takes a fatal blow",
                "treasures reappear",
                "Taken.",
                "Opened.",
                "Living Room",
            ])
        // His daemons die with him: no prowling or pickpocketing after.
        let afterDeath = transcript.components(
            separatedBy: "thief takes a fatal blow")[1]
        #expect(!afterDeath.contains("slips into the room"))
        #expect(!afterDeath.contains("melts away"))
        #expect(!afterDeath.contains("vanished."))
    }

    @Test func leavesRevealTheLockedGrating() async throws {
        let transcript = try await play(
            Zork1(),
            ["north", "north", "north", "move leaves", "open grating"])

        expectInOrder(
            transcript,
            [
                "Clearing",
                "In disturbing the pile of leaves, a grating is revealed.",
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
                "the rug is moved to one side of the room",
                "Opened.",
                "The trap door crashes shut, and you hear someone barring it.",
                "It is pitch black. You are likely to be eaten by a grue.",
            ])
    }

    /// Phase 6 on the slice: "take all"/"drop all" with labeled lines, the
    /// pronoun "it" through a container, and the reach/see distinction —
    /// water is visible through the closed glass bottle but not takable.
    @Test func kitchenSweepWithAllAndPronouns() async throws {
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west",
                "take all",
                "drop all",
                "take bottle", "open it", "look in it",
                "west",
                "take all",
                "inventory",
            ])
        expectInOrder(
            transcript,
            [
                "Kitchen",
                // take all: name-sorted, per-object results; the scenery
                // window is skipped, and the water refuses because loose
                // water can't be carried — it slips through your fingers.
                "brown sack: Taken.",
                "clove of garlic: Taken.",
                "glass bottle: Taken.",
                "lunch: Taken.",
                "quantity of water: The water slips through your fingers.",
                // drop all: everything just taken goes back down.
                "brown sack: Dropped.",
                "clove of garlic: Dropped.",
                "glass bottle: Dropped.",
                "lunch: Dropped.",
                // "it" rides along from "take bottle".
                "Opening the glass bottle reveals a quantity of water.",
                "In the glass bottle is a quantity of water.",
                // Living room: the scenery rug, trophy case, and the still
                // hidden trap door are all skipped by "all".
                "Living Room",
                "brass lantern: Taken.",
                "elvish sword: Taken.",
                "You are carrying:",
                "brass lantern",
                "elvish sword",
            ])
        #expect(!transcript.contains("window: "))
        #expect(!transcript.contains("trap door: "))
        #expect(!transcript.contains("trophy case: Taken."))
    }

    // MARK: - Round Room hub

    /// With the troll down, his east passage opens: the East-West Passage pays
    /// its five points on first arrival, and the Round Room lies beyond.
    @Test func theTrollsFallOpensTheRoadEastToTheRoundRoom() async throws {
        // Seed 39: the approach and kill match the
        // `trollBlocksThePassagesUntilDefeated` recording exactly (identical
        // prefix), so the third attack still lands the killing blow. Only the
        // steps after the kill are new, and they don't touch combat.
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west", "west",
                "take sword", "take lantern", "turn on lantern",
                "push rug", "open trap door", "down",
                "north", "west",
                "attack troll", "attack troll", "attack troll",
                // The road east is open now: East-West Passage (+5), Round Room.
                "east", "score", "east",
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "Troll Room",
                "The troll takes a fatal blow",
                "East-West Passage",
                // 35 banked below (kitchen 10, cellar 25); the passage adds 5.
                "Your score is 40 of a possible 350",
                "Round Room",
            ])
    }

    /// The Loud Room garbles every command until you say `echo`; only then does
    /// the platinum bar come free, worth ten points on the find.
    @Test func echoQuietsTheLoudRoomSoTheBarCanBeTaken() async throws {
        // Seed 39: same recorded troll kill; the Loud
        // Room itself draws no randomness on still water, so only the roaming
        // thief's stray lines depend on the seed, and none are asserted here.
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west", "west",
                "take sword", "take lantern", "turn on lantern",
                "push rug", "open trap door", "down",
                "north", "west",
                "attack troll", "attack troll", "attack troll",
                "east", "east", "east",  // → East-West Passage → Round Room → Loud Room
                "take platinum bar",  // garbled — the room is too loud
                "look",  // looking still works
                "echo",  // the acoustics settle
                "take platinum bar",  // now it comes free (+10)
                "score",
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "The troll takes a fatal blow",
                "Loud Room",
                "lost in the noise",  // the garble refusal
                "acoustics of the room change",  // acoustics fixed
                "Taken.",
                // 40 on arrival at the Loud Room; the bar's find pays 10 more.
                "Your score is 50 of a possible 350",
            ])
    }

    /// The hub's interior forms one connected graph — a light walk out from the
    /// Round Room and back proves the exits all agree with each other.
    @Test func theRoundRoomHubIsOneConnectedGraph() async throws {
        // Seed 39: reused troll kill; the walk itself
        // is RNG-free (no ejection on still water), only thief lines vary.
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west", "west",
                "take sword", "take lantern", "turn on lantern",
                "push rug", "open trap door", "down",
                "north", "west",
                "attack troll", "attack troll", "attack troll",
                "east", "east",  // → East-West Passage → Round Room
                "north",  // North-South Passage
                "north",  // Chasm
                "south",  // back to North-South Passage
                "northeast",  // Deep Canyon
                "down",  // Loud Room
                "up",  // back to Deep Canyon
                "southwest",  // North-South Passage
                "south",  // Round Room
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "Round Room",
                "North-South Passage",
                "Chasm",
                "North-South Passage",
                "Deep Canyon",
                "Loud Room",
                "Deep Canyon",
                "North-South Passage",
                "Round Room",
            ])
    }

    // MARK: - Dam & Reservoir (Phase 10.5)

    /// The route the dam tests share: kill the troll (seed 39, same recorded
    /// kill as the Round Room tests), press east into the hub, then in the
    /// Maintenance Room take the wrench and charge the panel with the yellow
    /// button, and end standing on the Dam with the bolt in reach.
    private static let approachTheChargedDam: [String] = [
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

    /// Turning the bolt with the wrench opens the gates; eight turns later the
    /// reservoir has drained, the trunk of jewels lies revealed on the bed, and
    /// taking it scores fifteen.
    @Test func turningTheBoltDrainsTheReservoirAndRevealsTheTrunk() async throws {
        let transcript = try await play(
            Zork1(),
            Self.approachTheChargedDam + [
                "turn bolt with wrench",  // gates open, the reservoir starts to fall
                "west",  // Reservoir South
                "wait", "wait", "wait", "wait",
                "wait", "wait", "wait", "wait",  // the eight-turn drain completes
                "north",  // onto the drained bed
                "take trunk",  // +15 on the find
                "score",
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "Maintenance Room",
                "Click.",  // the yellow button charges the panel
                "Dam",
                "sluice gates open",
                "Reservoir South",
                "a bed of slick",  // the drain fuse fires
                "Taken.",  // the trunk comes free
                // 40 banked (kitchen 10, cellar 25, E-W passage 5); the trunk adds 15.
                "Your score is 55 of a possible 350",
            ])
    }

    /// The bolt will not turn until the panel is charged: without the yellow
    /// button first, the wrench does nothing and the reservoir stays full.
    @Test func theBoltWillNotTurnUntilThePanelIsCharged() async throws {
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west", "west",
                "take sword", "take lantern", "turn on lantern",
                "push rug", "open trap door", "down",
                "north", "west",
                "attack troll", "attack troll", "attack troll",
                "east", "east",
                "north", "northeast", "east",  // → Dam
                "north", "north",  // → Maintenance Room
                "take wrench",  // but no yellow button this time
                "south", "south",  // → Dam
                "turn bolt with wrench",  // refused — nothing is live
                "west",  // Reservoir South
                "north",  // still barred — the reservoir is full
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "Dam",
                "won't turn",  // the bolt refusal
                "Reservoir South",
                "would drown",  // the full-reservoir crossing refusal
            ])
    }

    /// The blue button springs a leak; standing in the Maintenance Room as the
    /// water climbs past ankle, waist, and neck ends in drowning — and, this
    /// being a survivable death, resurrection in the forest.
    @Test func theBlueButtonFloodsTheRoomAndDrownsYou() async throws {
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west", "west",
                "take sword", "take lantern", "turn on lantern",
                "push rug", "open trap door", "down",
                "north", "west",
                "attack troll", "attack troll", "attack troll",
                "east", "east",
                "north", "northeast", "east",  // → Dam
                "north", "north",  // → Maintenance Room
                "push blue button",  // the leak begins
                "wait", "wait", "wait", "wait", "wait", "wait",
                "wait", "wait", "wait", "wait", "wait", "wait",  // the water rises and closes over you
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "up to your ankles",
                "up to your waist",
                "up to your neck",
                "drowned yourself",
                "Forest",  // resurrection sets you down above ground
            ])
    }

    /// Draining the reservoir, walking onto the bed, then closing the gates
    /// again floods it back — and anyone still standing on the bed when it
    /// fills drowns.
    @Test func closingTheGatesWhileOnTheBedDrownsYou() async throws {
        let transcript = try await play(
            Zork1(),
            Self.approachTheChargedDam + [
                "turn bolt with wrench",  // open — drain armed
                "wait", "wait", "wait", "wait",
                "wait", "wait", "wait", "wait",  // drain completes
                "turn bolt with wrench",  // close — refill armed, bed still crossable
                "west",  // Reservoir South
                "north",  // onto the bed
                "wait", "wait", "wait", "wait", "wait", "wait",  // the water climbs back over you
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "sluice gates open",
                "a bed of slick",
                "sluice gates close",
                "the rising river",  // the refill drowning
                "Forest",
            ])
    }

    /// While the gates are driving water through the depths, the Loud Room is
    /// unbearable: entering it throws the player straight back out. (This is the
    /// first time the Loud Room's water-moving path — dormant since Phase 10.4 —
    /// is actually exercised.)
    @Test func movingWaterMakesTheLoudRoomEjectYou() async throws {
        let transcript = try await play(
            Zork1(),
            Self.approachTheChargedDam + [
                "turn bolt with wrench",  // open the gates: water is now moving
                "south",  // Deep Canyon
                "down",  // Loud Room
                "look",  // the roar is past bearing — it throws you back out
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "sluice gates open",
                "scramble out of the room",  // the Loud Room ejection
            ])
    }

    /// The reservoir shore is a water source: an emptied bottle fills there,
    /// where before the slice had nowhere to fill it.
    @Test func theBottleFillsAtTheReservoir() async throws {
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west",
                "take bottle",  // carried up from the kitchen
                "west",
                "take sword", "take lantern", "turn on lantern",
                "push rug", "open trap door", "down",
                "north", "west",
                "attack troll", "attack troll", "attack troll",
                "east", "east",
                "north", "northeast", "east",  // → Dam
                "west",  // Reservoir South (a water source)
                "open bottle", "pour water",  // empty it out
                "fill bottle",  // now it fills from the reservoir
            ],
            // Seed 0: taking the bottle in the kitchen
            // shifts the RNG stream, so this walkthrough needs its own seed to
            // still land the three-blow troll kill.
            seed: 0)
        expectInOrder(
            transcript,
            [
                "Reservoir South",
                "spills out",  // the bottle emptied
                "now full of water",  // filled from the shore
            ])
    }

    /// A walk through the dam's dry rooms and, once drained, the reservoir bed,
    /// its far shore, and the stream — proving every exit in the region agrees
    /// with its neighbour.
    @Test func theDamRegionExitsFormOneConnectedGraph() async throws {
        let transcript = try await play(
            Zork1(),
            Self.approachTheChargedDam + [
                // Dry loop first: Dam → Base → Dam → Lobby → Maintenance → Lobby.
                "down", "up",  // Dam Base and back
                "north", "east", "west", "south",  // Lobby ↔ Maintenance ↔ Lobby ↔ Dam
                // Shore and stream mouth, then back to the Dam.
                "west", "west", "east",  // Reservoir South ↔ Stream View ↔ Reservoir South
                "east",  // back to the Dam
                // Drain, then cross the bed to the north shore and the stream.
                "turn bolt with wrench",
                "wait", "wait", "wait", "wait",
                "wait", "wait", "wait", "wait",  // drain completes
                "west",  // Reservoir South
                "north",  // Reservoir (the bed)
                "north",  // Reservoir North
                "south",  // Reservoir
                "up",  // Stream
                "east",  // Reservoir
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                "Dam Base",
                "Dam Lobby",
                "Maintenance Room",
                "Stream View",
                "Reservoir South",
                "Reservoir",
                "Reservoir North",
                "Stream",
                "Reservoir",
            ])
    }
}
