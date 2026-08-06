import Gnusto
import GnustoScoring

extension Intent {
    /// The name of the cyclops's father's deadly nemesis. One room answers it;
    /// everywhere else it is a shrug. Declared here rather than in
    /// ``DungeonSystems`` because a verb lives with the region that answers it.
    #verb("odysseus", ["odysseus"], ["ulysses"])
}

/// The great maze south of the Troll Room — twenty-three rooms, forked from
/// `Sources/Zork1/Regions/Maze.swift` and re-topologized against `dung.355`:
/// fifteen identical twisting passages, four dead ends, the Grating Room under
/// the forest Clearing, the Cyclops Room, the Treasure Room above it, and the
/// Strange Passage the cyclops opens on his way out.
///
/// **The maze is entered from the south, not the west.** Zork I hangs it west
/// of the Troll Room; here the troll's *south* passage is its front door, and
/// Maze-1 comes back *west*. Five more edges differ from the trilogy's, and
/// every one of them is a bearing rather than a room:
///
/// | | mainframe | Zork I |
/// |---|---|---|
/// | Maze-2 to Maze-4 | north | down |
/// | Maze-7 to Dead End-1 | northeast | down |
/// | Maze-9 to Maze-11 / Maze-10 | east / down | down / east |
/// | Maze-12 to Maze-5 | west | down |
/// | Maze-15 to the Cyclops | northeast | southeast |
/// | The cyclops's wall | **north**, onto the Strange Passage | east |
///
/// Two rooms here carry a value the trilogy does not: the Treasure Room is
/// worth **25** for arriving and the Strange Passage **10**, both room `RVAL`s
/// in the source and both `awardOnce` registers here. And the Treasure Room has
/// a second door — **east**, into the Royal Puzzle's antechamber — which is a
/// seam this milestone leaves open.
///
/// Seams host-wired in ``Dungeon``, because each names another bundle: the
/// troll's south passage into Maze-1; the grating up into the Clearing (and the
/// skeleton keys that unlock it, placed here at last); the smashed north wall's
/// passage east to the Living Room; the cyclops's feeding, which needs the
/// house's lunch and water; the skeleton's curse, which banishes your valuables
/// to the temple quarter's Land of the Living Dead; and the granite wall that
/// the Temple and the Treasure Room share. See `FIDELITY.md`.
struct DungeonMaze: GameContent {
    // MARK: - The maze proper

    /// One twisting passage. Fifteen of them, all alike, all dark — which is
    /// the whole puzzle, and why they are built from one factory rather than
    /// written out fifteen times. The bootstrap still names each after its own
    /// property, so `maze7` is `DungeonMaze.maze7`.
    private static func twistyPassage() -> Location {
        Location {
            name("Maze")
            description(Prose.maze)
            dark
        }
    }

    /// One dead end. Four of them, and they are the only landmarks the maze
    /// has apart from Maze-5's skeleton.
    private static func deadEnd() -> Location {
        Location {
            name("Dead End")
            description(Prose.deadEnd)
            dark
        }
    }

    let maze1 = twistyPassage()
    let maze2 = twistyPassage()
    let maze3 = twistyPassage()
    let maze4 = twistyPassage()

    /// The one passage that is not like the others: the dead adventurer's
    /// bones, his rusty knife, his burned-out lantern, the leather bag of
    /// coins, and the skeleton keys that open the grating.
    let maze5 = Location {
        name("Maze")
        description(Prose.maze5)
        dark
    }

    let maze6 = twistyPassage()
    let maze7 = twistyPassage()
    let maze8 = twistyPassage()
    let maze9 = twistyPassage()
    let maze10 = twistyPassage()
    let maze11 = twistyPassage()
    let maze12 = twistyPassage()
    let maze13 = twistyPassage()
    let maze14 = twistyPassage()
    let maze15 = twistyPassage()

    let deadEnd1 = deadEnd()
    let deadEnd2 = deadEnd()
    let deadEnd3 = deadEnd()
    let deadEnd4 = deadEnd()

    // MARK: - The way out, and the way up

    /// Directly under the forest Clearing. Always described, because what the
    /// room says about the grating overhead is the only report of the lock, of
    /// the key, and of the daylight — and a brief re-entry would print a bare
    /// room name over an open sky. The description itself is the host's, since
    /// the grating is a ``DungeonAboveGround`` item.
    ///
    /// Not declared `dark`: the source keeps this room unlit and turns its
    /// light bit *on* when the grating opens, which is a runtime write to
    /// ``Location/isLit`` rather than a static trait. The host's opening rule
    /// does it; the bootstrap starts it dark by the same call.
    let gratingRoom = Location {
        name("Grating Room")
        alwaysDescribed
        dark
    }

    /// Always described: the hole in the north wall is the only sign the
    /// cyclops ever left, and a walk back in would otherwise show nothing.
    let cyclopsRoom = Location {
        name("Cyclops Room")
        alwaysDescribed
        dark
    }

    /// Twenty-five points for arriving, which is the second-largest room value
    /// in the game. The award is the host's, because the register table is.
    let treasureRoom = Location {
        name("Treasure Room")
        description(Prose.treasureRoom)
        dark
    }

    /// Ten points for arriving, and the great shortcut home — but only once the
    /// cyclops has knocked the north wall down on his way out.
    let strangePassage = Location {
        name("Strange Passage")
        description(Prose.strangePassage)
        dark
    }

    // MARK: - The cyclops

    /// The one-eyed giant on the stairs. He does not fight — steel does not
    /// touch him — but he does get hungry, and once you have roused him the
    /// clock in ``cyclopsRoom`` counts down to lunch.
    let cyclops = Actor {
        name("cyclops")
        synonyms("cyclops", "monster", "giant", "eye")
        adjectives("hungry", "one-eyed")
    }

    // MARK: - Items

    /// Ten on the find and five in the case, as in both sources.
    let bagOfCoins = Item {
        name("bag of coins")
        adjectives("old", "leather")
        synonyms("bag", "coins", "coin")
        firstSight(Prose.bagOfCoinsInPlace)
        description(Prose.bagOfCoins)
        trait(.weight, 15)
        trait(.takeValue, 10)
        trait(.depositValue, 5)
    }

    /// Ten and **ten** — the mainframe pays twice what the trilogy does for
    /// casing it. Unguarded here: the thief who defends this room in the source
    /// belongs to no milestone yet.
    let chalice = Item {
        name("silver chalice")
        adjectives("silver", "engraved")
        synonyms("chalice", "cup", "goblet")
        firstSight(Prose.chaliceInPlace)
        description(Prose.chalice)
        container
        capacity(5)
        trait(.weight, 10)
        trait(.takeValue, 10)
        trait(.depositValue, 10)
    }

    /// Haunted. Picking it up in front of the elvish sword makes the sword
    /// flare; attacking anything with it kills the person holding it.
    let rustyKnife = Item {
        name("rusty knife")
        adjectives("rusty")
        synonyms("knife", "blade")
        firstSight(Prose.rustyKnifeInPlace)
        description(Prose.rustyKnife)
        trait(.weight, 20)
    }

    /// Scenery, and best left alone: the ghost who owns these bones takes a
    /// dim view of being handled. The curse is host-wired, since it banishes
    /// your valuables to a ``DungeonTemple`` room.
    let skeleton = Item {
        name("skeleton")
        synonyms("skeleton", "bones", "body", "remains", "adventurer")
        description(Prose.skeleton)
        scenery
    }

    let burnedOutLantern = Item {
        name("burned-out lantern")
        adjectives("burned-out", "useless", "dead")
        synonyms("lantern", "lamp")
        firstSight(Prose.burnedOutLantern)
        description(Prose.burnedOutLantern)
        trait(.weight, 20)
    }

    /// The Treasure Room's half of the granite wall the Temple and this room
    /// share, which is the only hint the game gives that the two rooms are one
    /// word apart. The Temple's half is ``DungeonTemple``'s, declared with the
    /// rest of that room in milestone 3.
    let graniteWall = Item {
        name("granite wall")
        adjectives("granite", "solid", "north")
        synonyms("wall", "granite")
        description(Prose.graniteWall)
        scenery
    }

    // MARK: - Scenery

    /// One per room, because presence is room-granular and every one of the
    /// nineteen passages and dead ends prints the same two nouns. Built from a
    /// factory for the same reason the rooms are.
    private static func twistyScenery() -> Item {
        Item {
            name("passages")
            adjectives("twisty", "little")
            synonyms("maze", "passage", "walls", "wall")
            description(Prose.mazeWalls)
            scenery
            plural
        }
    }

    private static func deadEndScenery() -> Item {
        Item {
            name("dead end")
            adjectives("dead")
            synonyms("end", "maze", "wall", "walls", "rock", "passage")
            description(Prose.deadEndWalls)
            scenery
        }
    }

    let mazeWalls1 = twistyScenery()
    let mazeWalls2 = twistyScenery()
    let mazeWalls3 = twistyScenery()
    let mazeWalls4 = twistyScenery()
    let mazeWalls5 = twistyScenery()
    let mazeWalls6 = twistyScenery()
    let mazeWalls7 = twistyScenery()
    let mazeWalls8 = twistyScenery()
    let mazeWalls9 = twistyScenery()
    let mazeWalls10 = twistyScenery()
    let mazeWalls11 = twistyScenery()
    let mazeWalls12 = twistyScenery()
    let mazeWalls13 = twistyScenery()
    let mazeWalls14 = twistyScenery()
    let mazeWalls15 = twistyScenery()
    let mazeWallsAtGrating = twistyScenery()

    let deadEndWalls1 = deadEndScenery()
    let deadEndWalls2 = deadEndScenery()
    let deadEndWalls3 = deadEndScenery()
    let deadEndWalls4 = deadEndScenery()

    let treasureRoomBags = Item {
        name("discarded bags")
        adjectives("discarded")
        synonyms("bags", "bag", "floor", "exit", "passage")
        description(Prose.treasureRoomBags)
        scenery
        plural
    }

    let strangePassageWalls = Item {
        name("passage")
        adjectives("long")
        synonyms("passage", "entrance", "walls", "wall")
        description(Prose.strangePassageWalls)
        scenery
    }

    let cyclopsSizedHole = Item {
        name("hole")
        adjectives("large", "cyclops-sized")
        synonyms("hole", "door", "opening")
        description(Prose.cyclopsSizedHole)
        scenery
    }

    let cyclopsStaircase = Item {
        name("staircase")
        synonyms("staircase", "stairs", "stair", "exit")
        description(Prose.cyclopsStaircase)
        scenery
    }

    /// The wall he goes through, which is the room's only piece of state and
    /// so has to answer differently on either side of the event.
    let cyclopsNorthWall = Item {
        name("north wall")
        adjectives("north", "solid")
        synonyms("wall", "walls", "opening", "hole", "rock")
        scenery
    }

    /// The marks on the walls that the cyclops's own line points at, and that
    /// stay there after he has gone.
    let cyclopsBloodstains = Item {
        name("bloodstains")
        adjectives("dried", "dark")
        synonyms("bloodstains", "blood", "stains")
        description(Prose.cyclopsBloodstains)
        scenery
        plural
    }

    // MARK: - State

    /// Whether the cyclops is past caring — asleep on the drugged water, or
    /// gone through the wall. The source's `CYCLOPS-FLAG`, and what opens the
    /// stair up to the Treasure Room.
    @Global var cyclopsSubdued = false

    /// Whether the north wall has a cyclops-sized hole in it. The source's
    /// `MAGIC-FLAG`, set only by the shout — feeding him never opens it.
    @Global var northWallOpen = false

    /// His hunger, which the source keeps as a **signed** count: positive once
    /// you have provoked him, negative once he has eaten the hot peppers and
    /// wants a drink. Either way the magnitude climbs a turn at a time while
    /// you stay, and past six he eats you.
    @Global var cyclopsWrath = 0

    /// Whether the count is running at all. The source enables its interrupt
    /// when you attack him or feed him and disables it when you leave the room;
    /// here the rule lives on the room, so leaving pauses it by itself and this
    /// flag carries only the first half.
    @Global var cyclopsProvoked = false

    /// How far the wrath ladder may climb before he stops waiting.
    static let cyclopsPatience = 5

    /// What the cyclops looks like right now. The source keeps one line per
    /// state and prints it as part of the room, so a look at the room and a
    /// look at him give the same answer — which is right: his mood *is* what
    /// the room is about.
    private var cyclopsMood: String {
        if cyclopsSubdued { return Prose.cyclopsAsleep }
        let wrath = cyclopsWrath
        if wrath > 0 { return Prose.cyclopsEyeingYou }
        if wrath < 0 { return Prose.cyclopsGasping }
        return Prose.cyclopsBlocksStairs
    }

    var verbs: [SyntaxRule] { [.odysseus] }

    /// The shout, anywhere the cyclops is not.
    var actions: [IntentAction] {
        action(.odysseus) { try reply(Prose.odysseusElsewhere) }
    }

    // MARK: - Map

    var map: WorldMap {
        // The mainframe's maze, edge for edge, in the order `dung.355`
        // declares them. Six of these bearings are not Zork I's; each has a
        // test that says so.
        maze1.north(maze1)
        maze1.south(maze2)
        maze1.east(maze4)
        // West is the Troll Room: host-wired.

        maze2.south(maze1)
        maze2.north(maze4)
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
        maze7.northeast(deadEnd1)
        maze7.east(maze8)
        maze7.south(maze15)

        maze8.northeast(maze7)
        maze8.west(maze8)
        maze8.southeast(deadEnd3)
        deadEnd3.north(maze8)

        maze9.north(maze6)
        maze9.east(maze11)
        maze9.down(maze10)
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

        maze12.west(maze5)
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
        maze15.northeast(cyclopsRoom)

        // The Grating Room. Southwest back into the tangle; up through the
        // grating into the Clearing is host-wired, because the grating is a
        // ``DungeonAboveGround`` item.
        gratingRoom.southwest(maze11)

        // The Cyclops Room. West back into the maze; the stair up opens once
        // he is past caring, and the north wall only once he has been through
        // it.
        cyclopsRoom.west(maze15)
        cyclopsRoom.exit(
            .up, to: treasureRoom, when: { cyclopsSubdued },
            otherwise: Prose.cyclopsWontLetYouPast)
        cyclopsRoom.exit(
            .north, to: strangePassage, when: { northWallOpen },
            otherwise: Prose.northWallSolid)

        // The Strange Passage, south back to him and east to the Living Room
        // (host-wired). The Treasure Room's own east door is the Royal
        // Puzzle's antechamber, which is a later milestone's — a seam the
        // source leaves open, so it stays undeclared.
        strangePassage.south(cyclopsRoom)
        treasureRoom.down(cyclopsRoom)

        // Entities. The skeleton keys are a ``DungeonAboveGround`` item — they
        // lock the grating — so the host places them here in Maze-5, and the
        // Temple's granite wall likewise.
        skeleton.starts(in: maze5)
        rustyKnife.starts(in: maze5)
        bagOfCoins.starts(in: maze5)
        burnedOutLantern.starts(in: maze5)
        cyclops.starts(in: cyclopsRoom)
        chalice.starts(in: treasureRoom)
        graniteWall.starts(in: treasureRoom)

        mazeWalls1.starts(in: maze1)
        mazeWalls2.starts(in: maze2)
        mazeWalls3.starts(in: maze3)
        mazeWalls4.starts(in: maze4)
        mazeWalls5.starts(in: maze5)
        mazeWalls6.starts(in: maze6)
        mazeWalls7.starts(in: maze7)
        mazeWalls8.starts(in: maze8)
        mazeWalls9.starts(in: maze9)
        mazeWalls10.starts(in: maze10)
        mazeWalls11.starts(in: maze11)
        mazeWalls12.starts(in: maze12)
        mazeWalls13.starts(in: maze13)
        mazeWalls14.starts(in: maze14)
        mazeWalls15.starts(in: maze15)
        mazeWallsAtGrating.starts(in: gratingRoom)
        deadEndWalls1.starts(in: deadEnd1)
        deadEndWalls2.starts(in: deadEnd2)
        deadEndWalls3.starts(in: deadEnd3)
        deadEndWalls4.starts(in: deadEnd4)
        cyclopsNorthWall.starts(in: cyclopsRoom)
        cyclopsBloodstains.starts(in: cyclopsRoom)
        treasureRoomBags.starts(in: treasureRoom)
        strangePassageWalls.starts(in: strangePassage)
        cyclopsSizedHole.starts(in: strangePassage)
        cyclopsStaircase.starts(in: cyclopsRoom)
    }

    // MARK: - Rules

    var rules: Rules {
        // The Cyclops Room reports the hole he left; the cyclops himself
        // reports his mood, every look, for as long as he is standing there.
        // Splitting them that way is what keeps the room from describing a
        // giant who has already gone.
        cyclopsRoom.describe {
            guard northWallOpen else { return Prose.cyclopsRoom }
            return "\(Prose.cyclopsRoom)\n\n\(Prose.cyclopsHoleInWall)"
        }
        cyclops.presence { cyclopsMood }
        cyclops.describe { cyclopsMood }
        cyclopsNorthWall.describe {
            northWallOpen ? Prose.northWallBroken : Prose.northWallExamined
        }

        // Shout the name of his father's nemesis and he goes through the north
        // wall, opening both the stair he was blocking and the shortcut home.
        // A location rule, so it fires ahead of ``DungeonSystems``'s inert
        // default. It works on a *sleeping* cyclops too — the source asks only
        // whether he is still standing in the room, and the drugged water
        // leaves him there.
        cyclopsRoom.before(.odysseus) {
            guard !northWallOpen else { try reply(Prose.odysseusElsewhere) }
            cyclopsSubdued = true
            northWallOpen = true
            cyclops.vanish()
            try reply(Prose.cyclopsFlees)
        }

        // Steel does not touch him, and the attempt starts the clock. Striking
        // the sleeper wakes him instead: the stair shuts again and the hunger
        // he had banked picks up where it left off.
        cyclops.before(.attack, .throwAt, .burn, .wake) {
            cyclopsProvoked = true
            guard cyclopsSubdued else { try reply(Prose.cyclopsShrugsOffAttack) }
            cyclopsSubdued = false
            cyclopsWrath = abs(cyclopsWrath)
            try reply(Prose.cyclopsWakes)
        }

        cyclops.before(.take) { try reply(Prose.cyclopsGrabbed) }
        cyclops.before(.tie) { try reply(Prose.cyclopsTied) }
        cyclops.before(.listen) { try reply(Prose.cyclopsStomach) }

        // The mounting hunger — the source's `CYCLOWRATH` and its interrupt.
        // Signed, because a cyclops who has eaten the peppers is counting down
        // to a drink rather than to a meal, and the source tracks the two with
        // one number. Leaving the room pauses the count without clearing it.
        cyclopsRoom.afterEachTurn {
            guard !cyclopsSubdued, cyclopsProvoked else { return }
            let wrath = cyclopsWrath
            if abs(wrath) > Self.cyclopsPatience {
                try die(Prose.cyclopsEatsYou)
            }
            let mounted = wrath < 0 ? wrath - 1 : wrath + 1
            cyclopsWrath = mounted
            say(Prose.cyclomad[abs(mounted) - 1])
        }

        // The haunted knife. Swung at anything, it turns on whoever swung it —
        // as the indirect object of an attack, or as the thing thrown. (An
        // item rule fires for the indirect object too, which is what lets one
        // rule cover both.) Attacking the knife itself is merely eccentric.
        rustyKnife.before(.attack) {
            guard command.indirectObject == rustyKnife else { return }
            rustyKnife.vanish()
            try die(Prose.rustyKnifeTurns)
        }
        rustyKnife.before(.throwAt) {
            guard command.directObject == rustyKnife, command.indirectObject != nil
            else { return }
            rustyKnife.vanish()
            try die(Prose.rustyKnifeTurns)
        }
    }
}
