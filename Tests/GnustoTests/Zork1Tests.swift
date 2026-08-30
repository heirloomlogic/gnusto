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

    /// `KITCHEN-WINDOW-F` answers `WALK BOARD THROUGH` by walking you east or
    /// west depending on which side you are standing on
    /// (`1actions.zil:246-266`), and until the engine learned that a door is a
    /// way through, `enter window` at this house answered "You can't get into
    /// that." while `west` walked you in. (#233)
    @Test func theWindowIsAWayThroughAndNotJustADirection() async throws {
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "enter window", "open window",
                "enter window", "go through window",
            ])

        // Shut, the window says what the direction says.
        #expect(
            turnOutput(of: "enter window", in: transcript)
                .contains("The kitchen window is closed."))
        expectInOrder(
            transcript,
            [
                "> open window", "Opened.",
                "> enter window", "Kitchen",
                "> go through window", "Behind House",
            ])
    }

    /// Both rooms end their paragraph on the window, as both `EAST-HOUSE` and
    /// `KITCHEN-FCN` do, and the reproduction had frozen the shut half of each.
    /// (#233)
    @Test func theHouseSaysWhetherTheWindowIsOpen() async throws {
        let transcript = try await play(
            Zork1(),
            ["south", "east", "look", "open window", "l", "west", "x window"])

        let outsideShut = turnOutput(of: "look", in: transcript)
        #expect(outsideShut.contains("which is slightly ajar"))
        let outsideOpen = turnOutput(of: "l", in: transcript)
        #expect(outsideOpen.contains("which is open"))
        #expect(!outsideOpen.contains("ajar"))

        // And inside, the frame the window's own examine text was false in.
        let inside = turnOutput(of: "west", in: transcript)
        #expect(inside.contains("which is open"))
        #expect(!inside.contains("slightly ajar"))
        #expect(!turnOutput(of: "x window", in: transcript).contains("not enough to allow entry"))
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
            ],
            // Seed 1, recorded: the thief never crosses your path. Taking the
            // painting summons him, and the lantern is as much his to take — one
            // theft and these lit rooms go pitch black. 20 seeds in 5,000.
            seed: 1)

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

    /// All three rungs are sentences about how a flame looks, and a fuse lands
    /// them wherever the player happens to be standing. Left burning in the
    /// Living Room, the lamp runs itself dry with nobody watching and says
    /// nothing about it in the kitchen next door.
    ///
    /// The fuel still runs out — the half of this that is easy to break — so
    /// the burn-out is asserted through the one thing that survives the
    /// silence: the lamp is spent when the player walks back in on it.
    @Test func theLanternBurnsDownSilentlyWhereThePlayerCannotSeeIt() async throws {
        let transcript = try await play(
            Zork1(),
            ["south", "east", "open window", "west", "west"]
                + ["take lantern", "turn on lantern", "drop lantern", "east"]
                + Array(repeating: "wait", count: 232)
                + ["west", "turn on lantern"])

        #expect(!transcript.contains("a bit dimmer"))
        #expect(!transcript.contains("The lamp is nearly out."))
        #expect(!transcript.contains("more light than from the brass lantern"))
        let relights = transcript.components(separatedBy: "> turn on lantern")
        #expect(relights[2].contains("burned-out lamp"))
    }

    /// Darkness is lethal, but not final: a warning on the first dark turn,
    /// one silent turn of grace, the grue on the third — and then Zork's
    /// canonical resurrection, which sets you back on your feet in the forest
    /// rather than reaching for the death prompt. UNDO still revives on the
    /// brink, and the next grue does the same thing all over again.
    @Test func lingeringInTheDarkResurrectsYou() async throws {
        // Seed 0: the grue now rolls the dice each dark turn, so the death turn
        // is seed-dependent — here the first dice turn (the second look) lands
        // it. UNDO restores the RNG state along with everything else, so the
        // re-rolled dark turn is fatal again, deterministically.
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west", "west",
                "push rug", "open trap door", "down",
                "look", "look",
                "undo", "look", "quit",
            ],
            seed: 0)
        // The descent turn: slam, then the grue sentence — once. Zork points
        // both `text.pitchBlack` and the grue's warning at that one line, so the
        // room describer and the daemon each have a claim on it and the turn
        // prints it a single time.
        let descent = turnOutput(of: "down", in: transcript)
        let grue = "It is pitch black. You are likely to be eaten by a grue."
        expectInOrder(
            descent,
            [
                "The trap door crashes shut, and you hear someone barring it.",
                grue,
            ])
        #expect(occurrences(of: grue, in: descent) == 1)
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
                "down", "look", "look", "look", "look", "look",
                "restore", path, "down",
            ],
            seed: 0)
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
                // The nest's `FDESC` and the egg's, in that order, in place of
                // two stock listing lines — one of which never printed at all,
                // because the nest is `scenery`.
                "Beside you on the branch is a small bird's nest.",
                "In the bird's nest is a large egg encrusted with precious jewels,",
                "Taken.",
                "Forest Path",
                "Living Room",
                "Opened.",
                "You put the jewel-encrusted egg in the trophy case.",
                "A glass-fronted trophy case, holding a jewel-encrusted egg.",
            ])
    }

    @Test func depositPaintingScoresPoints() async throws {
        // The painting pays 4 on first take and 6 on first deposit; taking it
        // back out of the case revokes the 6 (the original's in-case
        // accounting) and re-depositing restores it. The route also banks two
        // visit awards on the way down — the kitchen (10) and the cellar (25)
        // — so the totals run 39, 45, back to 39, then 45. The interleaved
        // `score`s are meta (no turn passes), so the thief's stream is
        // unchanged from the recorded seed-1 route, on which he keeps his
        // fingers to himself.
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west", "west",
                "take lantern", "turn on lantern",
                "push rug", "open trap door", "down",
                "south", "east", "take painting", "score",
                "north", "up", "west",
                "open trophy case", "put painting in trophy case", "score",
                "take painting", "score",
                "put painting in trophy case", "score",
            ],
            seed: 1)

        expectInOrder(
            transcript,
            [
                "Your score is 39 of a possible 350",
                "You put the painting in the trophy case.",
                "Your score is 45 of a possible 350",
                "Your score is 39 of a possible 350",  // withdrawn → deposit revoked
                "Your score is 45 of a possible 350",  // re-deposited → restored
            ])
        let scores = transcript.components(separatedBy: "Your score is ")
        #expect(scores.count == 5)
        #expect(scores[4].hasPrefix("45 of a possible 350"))
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
        // Seed 39, recorded (thief daemons on the clock): he never opens a
        // fight of his own here, so the three blows go in uncontested and the
        // last one lands. Before #237 the seed was picked for a run of swings
        // that grazed and never landed; now it is picked for the two turns in
        // three he spends blocking instead — which is what the room's own
        // listing line has always claimed he does.
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
                // `VILLAIN-RESULT` (`1actions.zil:3568`) prints the disposal
                // between the blow and `REMOVE-CAREFULLY`, for every villain.
                // Without it the room emptied and the prose did not say so.
                "when the fog lifts, the carcass has disappeared",
                "Maze",  // west now drops into the maze
            ])
        // Defeat is permanent and the room empties.
        let afterDeath = transcript.components(
            separatedBy: "troll takes a fatal blow")[1]
        #expect(!afterDeath.contains("A nasty-looking troll"))
    }

    @Test func theTrollCanKillYou() async throws {
        // The fight is picked rather than walked into, since #237: unprovoked he
        // starts one on a third of turns, so a death on arrival is a one-in-ten
        // seed and pinning for it would be testing the rare path. What is being
        // measured is the same — the kill resurrects you in the forest at a cost
        // of ten points, and UNDO still rewinds the whole fatal turn to the
        // brink. Seed 0, recorded: he outlasts four blows and the last word is
        // his.
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west", "west",
                "take sword", "take lantern", "turn on lantern",
                "push rug", "open trap door", "down",
                "north", "attack troll", "attack troll", "attack troll",
                "attack troll",
                "score",
                "undo", "south",
            ],
            seed: 0)
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
        // Seed 0, recorded: the troll outlasts four blows and wins. The fight is
        // picked rather than walked into — see theTrollCanKillYou for why. The
        // belongings strew at random across the grounds; on this seed the sword
        // lands on the Forest Path. The lamp is the exception — it always returns
        // to the Living Room so light survives a death — asserted in
        // theLampAlwaysComesHomeAfterDeath below.
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west", "west",
                "take sword", "take lantern", "turn on lantern",
                "push rug", "open trap door", "down",
                "north", "attack troll", "attack troll", "attack troll",
                "attack troll",
                // Resurrected in the forest, empty-handed. Fetch the sword from
                // where the death flung it.
                "north", "take sword",  // → Forest Path
            ],
            seed: 0)
        expectInOrder(
            transcript,
            [
                "neatly removes your head",
                "deserve another",
                "Forest",
                "Forest Path",
                "Taken.",
            ])
    }

    @Test func theLampAlwaysComesHomeAfterDeath() async throws {
        // The one exception to the random strew: however the rest of your kit
        // scatters, the lamp always turns up back in the Living Room, so a death
        // in the dark can never strand you without a light (the kept
        // anti-softlock). Seed 0, the same lost fight; walk back in through the
        // window and the lit lamp is waiting on the floor.
        let transcript = try await play(
            Zork1(),
            [
                "south", "east", "open window", "west", "west",
                "take sword", "take lantern", "turn on lantern",
                "push rug", "open trap door", "down",
                "north", "attack troll", "attack troll", "attack troll",
                "attack troll",
                // Resurrected in the forest; return to the Living Room for the lamp.
                "east", "south", "east", "west", "west",  // → Kitchen → Living Room
                "take lantern",
            ],
            seed: 0)
        expectInOrder(
            transcript,
            [
                "deserve another",  // the resurrection
                "Living Room",
                "brass lantern",  // waiting on the floor, right where a death always leaves it
                "Taken.",
            ])
    }

    /// The third death is the last one: after two resurrections the toll comes
    /// due, and the grue's third meal reaches the engine's banner and prompt.
    @Test func theThirdDeathIsFinal() async throws {
        // Seed 1: the player carries nothing (so nothing but the grue is in
        // play), and only the needles below are asserted, so the roaming
        // thief's comings and goings don't matter. The grue now rolls the dice
        // each dark turn, so we linger long enough for it to land every descent;
        // once dead you wake in the lit forest, where the extra waits are idle.
        let descend = ["open trap door", "down"] + Array(repeating: "wait", count: 6)
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
        // Seed 474: now that the thief roams the whole underground and lifts
        // treasures from the floor as well as your hands, a seed where he
        // lingers in the Gallery to pick your pocket and stand for the fight is
        // rarer — this one has him lift the painting during the loiter, then
        // fall to the sword, dropping the loot (and his stiletto) and unbarring
        // the trap door so the route home works.
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
            seed: 474)
        expectInOrder(
            transcript,
            [
                "the painting vanished",
                "The thief takes a fatal blow",
                "when the fog lifts, the carcass has disappeared",
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
    /// pronoun "it" through a container, and the reach/see distinction — the
    /// water is visible through the closed glass bottle and so nameable, but
    /// out of reach, so "all" never offers it (#267).
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
                // window is skipped, and so is the water — behind the shut
                // bottle's glass, it is in view and out of arm's reach.
                "brown sack: Taken.",
                "clove of garlic: Taken.",
                "glass bottle: Taken.",
                "lunch: Taken.",
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
                "You are carrying a glass bottle, a brass lantern, and an elvish sword.",
            ])
        #expect(!transcript.contains("window: "))
        #expect(!transcript.contains("trap door: "))
        #expect(!transcript.contains("trophy case: Taken."))
        // Never offered, so never refused: the water's own line stays for the
        // player who names it directly.
        #expect(!transcript.contains("quantity of water: "))
        // And it is still perfectly nameable — the shut bottle is glass.
        #expect(transcript.contains("In the glass bottle is a quantity of water."))
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

    /// The Loud Room echoes your words and holds the sacred platinum bar fast
    /// until you say `echo`; only then does the bar come free, worth ten points
    /// on the find.
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
                "take platinum bar",  // the bar is sacred while the room roars
                "smell",  // any other command just echoes back
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
                "cannot get hold of it",  // the bar's SACREDBIT take-lock
                "echo: \u{201C}smell... smell... smell...\u{201D}",  // the read-loop
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
    ///
    /// Not private: `Zork1SystemsTests` reuses it to reach the bolt too.
    static let approachTheChargedDam: [String] = [
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

    /// The drain runs on a count, and its line is something you watch happen to
    /// a body of water: mud laid bare. Turn the bolt and walk back into the
    /// Maintenance Room and the reservoir empties on schedule and says nothing
    /// about it — the player finds it drained when they come back for the
    /// trunk.
    @Test func theReservoirDrainsSilentlyWhereThePlayerCannotSeeIt() async throws {
        let transcript = try await play(
            Zork1(),
            Self.approachTheChargedDam
                + ["turn bolt with wrench", "north", "north"]  // → Dam Lobby → Maintenance Room
                + Array(repeating: "wait", count: 8)  // the drain completes out of sight
                + ["south", "south", "west", "north"],  // → Dam → Reservoir South → the bed
            seed: 39)

        #expect(!transcript.contains("a bed of slick"))
        // But it drained: the lake is a mud pile and can be walked across.
        #expect(transcript.contains("large mud pile"))
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

    /// The blue button springs a leak; standing in the Maintenance Room, the
    /// water climbs one body-part step every turn — ankles, shins, knees, hips,
    /// waist, chest, neck — and once it tops the neck the room is full and you
    /// drown. This being a survivable death, you resurrect in the forest.
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
                "push blue button",  // the leak begins (ankles this turn)
                "wait", "wait", "wait", "wait",
                "wait", "wait", "wait",  // shins → neck, then the water closes over you
            ],
            seed: 39)
        expectInOrder(
            transcript,
            [
                // The level rises continuously, one step a turn.
                "up to your ankles",
                "up to your shins",
                "up to your knees",
                "up to your hips",
                "up to your waist",
                "up to your chest",
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
            // Seed 0: taking the bottle in the kitchen shifts the RNG stream,
            // so this walkthrough needs its own seed to still land the troll
            // inside the blows it budgets.
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
