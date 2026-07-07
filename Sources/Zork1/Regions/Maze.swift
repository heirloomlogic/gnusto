import Gnusto
import GnustoMeleeCombat
import GnustoScoring

/// The great maze west of the Troll Room — fifteen near-identical twisting
/// passages and four dead ends, a deliberate tangle where every room shows the
/// same name and the same words and only the odd landmark (a skeleton, a dead
/// end, the grating, the cyclops) tells you where you are. Its canonical exit
/// graph is reproduced verbatim from `1dungeon.zil`: several one-way "diode"
/// drops and a handful of rooms whose exits loop back on themselves. Threading
/// it in the dark, lantern lit, is the whole puzzle.
///
/// Hidden in the middle (Maze-5) lie the bones of an earlier adventurer, and
/// beside them the leather bag of coins, a rusty knife, and — at last — the
/// skeleton key that unlocks the grating overhead. Follow the tangle one way
/// and it climbs to the Grating Room, a real door up into the forest Clearing;
/// follow it another and it opens on the Cyclops Room, where a one-eyed giant
/// bars the stair up to the Treasure Room until you feed him to sleep or shout
/// the name of his father's nemesis and send him crashing through the east
/// wall — opening the Strange Passage back to the Living Room.
///
/// Three seams cross into other bundles and so are host-wired in ``Zork1``: the
/// entrance west of the Troll Room, the grating up into ``ZorkAboveGround``'s
/// Clearing (and the skeleton key that locks it, placed here at last), and the
/// smashed east wall onto the Living Room. The cyclops's feeding also lives in
/// the host, since the lunch and water are ``ZorkHouse`` items. Everything
/// self-contained — the geography, the `odysseus` shout, the futile attack —
/// lives here. Thief behaviour and the Treasure Room's award arrive in the next
/// phase. See `FIDELITY.md`.
struct ZorkMaze: GameContent {
    // MARK: - The maze proper

    // Fifteen passages, all alike: one shared name and one shared description
    // (the sameness is the puzzle). Only the room *token* distinguishes them.
    // All dark — no daylight reaches this deep.
    let maze1 = Location {
        name("Maze")
        description(Prose.maze)
        dark
    }
    let maze2 = Location {
        name("Maze")
        description(Prose.maze)
        dark
    }
    let maze3 = Location {
        name("Maze")
        description(Prose.maze)
        dark
    }
    let maze4 = Location {
        name("Maze")
        description(Prose.maze)
        dark
    }
    /// Maze-5, the dead adventurer's resting place: skeleton, rusty knife, the
    /// leather bag of coins, the burned-out lantern, and the skeleton key.
    let maze5 = Location {
        name("Maze")
        description(Prose.maze5)
        dark
    }
    let maze6 = Location {
        name("Maze")
        description(Prose.maze)
        dark
    }
    let maze7 = Location {
        name("Maze")
        description(Prose.maze)
        dark
    }
    let maze8 = Location {
        name("Maze")
        description(Prose.maze)
        dark
    }
    let maze9 = Location {
        name("Maze")
        description(Prose.maze)
        dark
    }
    let maze10 = Location {
        name("Maze")
        description(Prose.maze)
        dark
    }
    let maze11 = Location {
        name("Maze")
        description(Prose.maze)
        dark
    }
    let maze12 = Location {
        name("Maze")
        description(Prose.maze)
        dark
    }
    let maze13 = Location {
        name("Maze")
        description(Prose.maze)
        dark
    }
    let maze14 = Location {
        name("Maze")
        description(Prose.maze)
        dark
    }
    let maze15 = Location {
        name("Maze")
        description(Prose.maze)
        dark
    }

    // Four dead ends, all alike.
    let deadEnd1 = Location {
        name("Dead End")
        description(Prose.deadEnd)
        dark
    }
    let deadEnd2 = Location {
        name("Dead End")
        description(Prose.deadEnd)
        dark
    }
    let deadEnd3 = Location {
        name("Dead End")
        description(Prose.deadEnd)
        dark
    }
    let deadEnd4 = Location {
        name("Dead End")
        description(Prose.deadEnd)
        dark
    }

    // MARK: - The grating, cyclops, and treasure

    /// The far corner of the maze, directly beneath the forest Clearing. The
    /// grating overhead (a ``ZorkAboveGround`` item) is host-wired as a real
    /// door up; opening it from below is the way out to daylight.
    let gratingRoom = Location {
        name("Grating Room")
        description(Prose.gratingRoom)
        dark
    }

    /// Home of the cyclops, who bars the stair up to the Treasure Room.
    let cyclopsRoom = Location {
        name("Cyclops Room")
        description(Prose.cyclopsRoom)
        dark
    }

    /// The thief's hoard, above the Cyclops Room. (The thief himself, the
    /// Treasure Room's award, and the silver chalice arrive next phase.)
    let treasureRoom = Location {
        name("Treasure Room")
        description(Prose.treasureRoom)
        dark
    }

    /// The passage the fleeing cyclops smashes open, running east to the Living
    /// Room (host-wired) — the great shortcut home.
    let strangePassage = Location {
        name("Strange Passage")
        description(Prose.strangePassage)
        dark
    }

    // MARK: - The cyclops

    /// The one-eyed giant. Blocks the stair up; feed him to sleep, or shout
    /// `odysseus` to rout him. He does not fight back (see `FIDELITY.md`).
    let cyclops = Actor {
        name("cyclops")
        synonyms("cyclops", "monster", "eye", "giant")
        adjectives("hungry", "giant", "one-eyed")
        description(Prose.cyclops)
        firstSight(Prose.cyclopsPresence)
    }

    // MARK: - Items

    /// The leather bag of coins — ten on the find, five in the case (the
    /// original's VALUE 10 / TVALUE 5).
    let bagOfCoins = Item {
        name("bag of coins")
        adjectives("old", "leather")
        synonyms("bag", "coins")
        firstSight(Prose.bagOfCoinsFirstSight)
        description(Prose.bagOfCoins)
        trait(.weight, 15)
        trait(.takeValue, 10)  // find
        trait(.depositValue, 5)  // case
    }

    /// The rusty knife beside the skeleton — a weapon and a tool, and (like the
    /// sword, nasty knife, and sceptre) sharp enough to hole the inflatable
    /// boat. Not a treasure.
    let rustyKnife = Item {
        name("rusty knife")
        adjectives("rusty")
        synonyms("knife", "blade")
        firstSight(Prose.rustyKnifeFirstSight)
        description(Prose.rustyKnife)
        trait(.weight, 20)
        trait(.sharp, true)
    }

    /// The bones of a luckless adventurer — scenery, and best left undisturbed.
    /// (The original's disturb-the-remains curse is skipped — see `FIDELITY.md`.)
    let skeleton = Item {
        name("skeleton")
        adjectives("bones")
        synonyms("skeleton", "bones", "body")
        description(Prose.skeleton)
        scenery
    }

    /// The dead adventurer's own lantern, long since burned out — takeable
    /// junk, no light left in it.
    let burnedOutLantern = Item {
        name("burned-out lantern")
        adjectives("burned-out", "rusty", "dead", "useless")
        synonyms("lantern", "lamp")
        firstSight(Prose.burnedOutLanternFirstSight)
        description(Prose.burnedOutLantern)
        trait(.weight, 20)
    }

    // MARK: - State

    /// Whether the cyclops is past caring — asleep (fed) or fled (routed). The
    /// original's `CYCLOPS-FLAG`. Gates the stair up to the Treasure Room.
    @Global var cyclopsSubdued = false

    /// Whether the cyclops has smashed the east wall open on his way out. The
    /// original's `MAGIC-FLAG`. Gates the shortcut east to the Strange Passage
    /// and Living Room — set only by `odysseus`, never by feeding.
    @Global var eastWallOpen = false

    /// Whether the cyclops has eaten the lunch and now wants a drink. The water
    /// only puts him to sleep while this is true.
    @Global var cyclopsThirsty = false

    /// Whether the grating has been opened from below — the one-time leaf-shower
    /// latch (the original's `GRATE-REVEALED`). Set by the host's grating rule.
    @Global var gratingOpenedFromBelow = false

    // MARK: - Map

    var map: WorldMap {
        // The maze's canonical exit graph, verbatim from `1dungeon.zil` — the
        // `PER MAZE-DIODES` one-way drops resolved from that file's inline
        // `;"to X"` comments, and the self-loops (a passage back to itself)
        // declared literally.
        maze1.north(maze1)
        maze1.south(maze2)
        maze1.west(maze4)

        maze2.south(maze1)
        maze2.down(maze4)
        maze2.east(maze3)

        maze3.west(maze2)
        maze3.north(maze4)
        maze3.up(maze5)

        maze4.west(maze3)
        maze4.north(maze1)
        maze4.east(deadEnd1)

        deadEnd1.south(maze4)

        maze5.east(deadEnd2)
        maze5.north(maze3)
        maze5.southwest(maze6)

        deadEnd2.west(maze5)

        maze6.down(maze5)
        maze6.east(maze7)
        maze6.west(maze6)
        maze6.up(maze9)

        maze7.up(maze14)
        maze7.west(maze6)
        maze7.down(deadEnd1)
        maze7.east(maze8)
        maze7.south(maze15)

        maze8.northeast(maze7)
        maze8.west(maze8)
        maze8.southeast(deadEnd3)

        deadEnd3.north(maze8)

        maze9.north(maze6)
        maze9.down(maze11)
        maze9.east(maze10)
        maze9.south(maze13)
        maze9.west(maze12)
        maze9.northwest(maze9)

        maze10.east(maze9)
        maze10.west(maze13)
        maze10.up(maze11)

        maze11.northeast(gratingRoom)
        maze11.down(maze10)
        maze11.northwest(maze13)
        maze11.southwest(maze12)

        maze12.down(maze5)
        maze12.southwest(maze11)
        maze12.east(maze13)
        maze12.up(maze9)
        maze12.north(deadEnd4)

        deadEnd4.south(maze12)

        maze13.east(maze9)
        maze13.down(maze12)
        maze13.south(maze10)
        maze13.west(maze11)

        maze14.west(maze15)
        maze14.northwest(maze14)
        maze14.northeast(maze7)
        maze14.south(maze7)

        maze15.west(maze14)
        maze15.south(maze7)
        maze15.southeast(cyclopsRoom)

        // The Grating Room. Southwest back into the maze; up through the
        // grating into the Clearing is host-wired (the grating is an
        // above-ground door).
        gratingRoom.southwest(maze11)

        // The Cyclops Room. Northwest back into the maze. The stair up opens
        // once he's subdued; the east wall opens only once he's smashed it.
        cyclopsRoom.northwest(maze15)
        cyclopsRoom.exit(.up, to: treasureRoom, when: { cyclopsSubdued }, otherwise: Prose.cyclopsBlocksStairs)
        cyclopsRoom.exit(.east, to: strangePassage, when: { eastWallOpen }, otherwise: Prose.eastWallSolid)

        // The Strange Passage. West and in return to the Cyclops Room; east to
        // the Living Room is host-wired.
        strangePassage.west(cyclopsRoom)
        strangePassage.in(cyclopsRoom)

        treasureRoom.down(cyclopsRoom)

        // Entities. The skeleton key is a ``ZorkAboveGround`` item (it locks the
        // grating), so the host places it here in Maze-5.
        skeleton.starts(in: maze5)
        rustyKnife.starts(in: maze5)
        bagOfCoins.starts(in: maze5)
        burnedOutLantern.starts(in: maze5)
        cyclops.starts(in: cyclopsRoom)
    }

    // MARK: - Rules

    var rules: Rules {
        // Shout the name of the cyclops's father's nemesis and he bolts,
        // smashing through the east wall. This opens both the stair up (he's
        // gone) and the shortcut east to the Living Room. A location rule, so it
        // fires ahead of ``ZorkSystems``'s inert `odysseus` default.
        cyclopsRoom.before(.odysseus) {
            guard !cyclopsSubdued else { try reply(Prose.cyclopsAlreadyGone) }
            cyclopsSubdued = true
            eastWallOpen = true
            cyclops.vanish()
            try reply(Prose.cyclopsFlees)
        }

        // He shrugs off any attack — he doesn't fight, and there's no beating
        // him with steel (see `FIDELITY.md`). A canned reply, so combat never
        // starts.
        cyclops.before(.attack) {
            try reply(Prose.cyclopsShrugsOffAttack)
        }

        // The bones stay put.
        skeleton.before(.take) {
            try refuse(Prose.skeletonLeaveItBe)
        }
    }
}
