import Gnusto
import GnustoActors
import GnustoMeleeCombat

/// The thief's seams. He lives in ``DungeonThief``, but every behaviour he has
/// reaches across bundles — the weapons that fell him are ``DungeonHouse``'s,
/// the treasures he covets are every region's, his lair is ``DungeonMaze``'s,
/// the egg is ``DungeonAboveGround``'s and the bird inside it is
/// ``DungeonHouse``'s — so all of it is the host's, which is the codebase rule.
///
/// Its own file rather than more of `Dungeon.swift`, which is nine hundred
/// lines before this arrives. `Dungeon.swift` keeps the five wiring lines that
/// name these members; the members themselves are here.
extension Dungeon {
    /// Every room the thief prowls: the built main dungeon, less four kinds of
    /// room a *teleporting* thief must not reach.
    ///
    /// The `roams` daemon moves him without regard for the exit graph, so the
    /// set has to do the work a walk would have done. Each exclusion below is a
    /// place he could not have walked to, or one he could not have walked out
    /// of with your emerald in his bag:
    ///
    /// - **The Land of the Living Dead.** Sacred ground; the bell, book and
    ///   candle are the way in, and treasure carried past them is treasure
    ///   behind a ritual.
    /// - **The water, and the air.** Everything past the Dam Base — the five
    ///   river stretches, the stream, both White Cliffs beaches, the Sandy
    ///   Beach, the Shore, the Rocky Shore, the falls and the rainbow — is
    ///   reached by boat, and the volcano's four air rooms, its two ledges, the
    ///   Library and the Dusty Room are reached by balloon. He walks. What he
    ///   does walk to in milestone 6 is the Volcano Bottom and the Lava Room,
    ///   which the Ruby Room opens onto, and Volcano View, which is a step east
    ///   of the Egyptian Room.
    /// - **The Small Room and the Vault.** `docs/games/dungeon-atlas.md` records
    ///   both with **zero** exits: the curtain of light is the only way in or
    ///   out, so a thief dropped in there would be sealed in with the hoard.
    /// - **The shrunken world.** The Posts Room, the Pool Room, the Low Room,
    ///   the Machine Room, the Dingy Closet and the Cage are reached only by
    ///   eating your way down to the size of the tea table.
    /// - **Six of the palantir wing's seven rooms.** The source marks
    ///   `RSACREDBIT` on the Dreary Room, the three chute stretches, the Slide
    ///   Ledge and the Sooty Room, and every one of them earns it: five are
    ///   reached only by hanging on a rope, and the sixth is behind a locked
    ///   oak door whose key starts on the wrong side of it. `PRM`, the Tiny
    ///   Room, carries no such bit and is in the set — it is a plain step west
    ///   of the Torch Room, and a player solving the door there with a
    ///   screwdriver in one hand is exactly the kind of person he visits.
    /// - **The Royal Puzzle itself**, for the Small Room's reason exactly. The
    ///   drop into `CP` is one-way — the sand runs shut — and both ways out are
    ///   earned: a sliding-block problem, or a steel door that eats the only
    ///   treasure in the region. A teleporting thief dropped onto that floor is
    ///   sealed in with it. The two rooms *above* it are a different matter and
    ///   are in the set: the Small Square Room is a plain two-way passage east
    ///   of his own lair, and the Side Room a plain two-way passage south of
    ///   that, so he can walk to both and out of both — and the gold card, once
    ///   you have carried it up, is exactly the kind of thing he takes.
    ///
    /// Above ground is not an exclusion so much as a boundary: he is the
    /// dungeon's, and the mainframe never lets him out of it.
    ///
    /// His own lair **is** in the set, and has to be. It is the only room the
    /// stash daemon unloads in, so a thief who could not wander home would
    /// carry your emerald around the dungeon for the rest of the game and the
    /// hoard would never grow. Arriving in the Treasure Room summons him back
    /// regardless, so nothing is lost by letting him already be there.
    var thiefProwl: [Location] {
        thiefProwlUpper + thiefProwlTemple + thiefProwlMine + thiefProwlMaze
    }

    /// The cellar, the crossroads and the dam.
    private var thiefProwlUpper: [Location] {
        [
            house.cellar,
            cellar.trollRoom, cellar.crawlway, cellar.westOfChasm, cellar.gallery,
            cellar.studio,
            crossroads.eastWestPassage, crossroads.roundRoom, crossroads.nsPassage,
            crossroads.deepRavine, crossroads.chasmRoom, crossroads.deepCanyon,
            crossroads.loudRoom, crossroads.dampCave,
            dam.damRoom, dam.damLobby, dam.maintenanceRoom, dam.damBase,
            dam.reservoirSouth, dam.reservoir, dam.reservoirNorth, dam.streamView,
        ]
    }

    /// The temple quarter, the three volcano rooms on the walking network, the
    /// mirror network, and the dry road to the chasm.
    private var thiefProwlTemple: [Location] {
        [
            templeQuarter.rockyCrawl, templeQuarter.domeRoom, templeQuarter.torchRoom,
            templeQuarter.grailRoom, templeQuarter.temple, templeQuarter.altar,
            templeQuarter.egyptianRoom, templeQuarter.glacierRoom, templeQuarter.rubyRoom,
            templeQuarter.engravingsCave, templeQuarter.entranceToHades,
            volcano.volcanoBottom, volcano.lavaRoom, volcano.volcanoView,
            palantirWing.tinyRoom,
            mirrors.mirrorRoomNorth, mirrors.mirrorRoomSouth, mirrors.caveNorth,
            mirrors.caveSouth, mirrors.steepCrawlway, mirrors.narrowCrawlway,
            mirrors.coldPassage, mirrors.windingPassage, mirrors.atlantisRoom,
            mirrors.slideRoom,
            river.smallCave, river.ancientChasm, river.chasmDeadEndNorth,
            river.chasmDeadEndWest,
        ]
    }

    /// The coal mine, top to bottom.
    private var thiefProwlMine: [Location] {
        [
            mine.mineEntrance, mine.squeakyRoom, mine.batRoom, mine.shaftRoom,
            mine.woodenTunnel, mine.smellyRoom, mine.gasRoom, mine.mine1, mine.mine2,
            mine.mine3, mine.mine4, mine.mine5, mine.mine6, mine.mine7, mine.ladderTop,
            mine.ladderBottom, mine.coalDeadEnd, mine.timberRoom, mine.lowerShaft,
            mine.machineRoom,
        ]
    }

    /// The maze he lives at the top of, the riddle's corridor, the top of the
    /// well, and the Bank of Zork.
    private var thiefProwlMaze: [Location] {
        [
            maze.maze1, maze.maze2, maze.maze3, maze.maze4, maze.maze5, maze.maze6,
            maze.maze7, maze.maze8, maze.maze9, maze.maze10, maze.maze11, maze.maze12,
            maze.maze13, maze.maze14, maze.maze15, maze.deadEnd1, maze.deadEnd2,
            maze.deadEnd3, maze.deadEnd4, maze.gratingRoom, maze.cyclopsRoom,
            maze.strangePassage, maze.treasureRoom,
            royalPuzzle.anteroom, royalPuzzle.sideRoom,
            riddle.riddleRoom, riddle.pearlRoom,
            alice.circularRoom, alice.topOfWell, alice.teaRoom,
            bank.bankEntrance, bank.westTellersRoom, bank.eastTellersRoom,
            bank.westViewingRoom, bank.eastViewingRoom, bank.safetyDepository,
            bank.chairmansOffice,
        ]
    }

    /// Everything the thief does that reaches outside ``DungeonThief``, which is
    /// everything he does.
    @RuleBuilder
    var thiefRules: Rules {
        moreThiefRules
        // Into play. He is placed by code, which is what the atlas records for
        // him, and the code is this: he comes out when you give him a reason
        // to. The first treasure you lift off the dungeon floor is the reason,
        // and where he comes out is the Treasure Room, standing over everything
        // he has already taken from everybody else.
        //
        // Three things fall out of that, and all three are the point of it. The
        // trigger is a *treasure*, so the lamp and the sword and the rope do not
        // wake him. The two treasures that are not his business are named:
        // the egg on its nest, which is what you will be bringing him, and the
        // bauble, which does not exist until he has opened the egg. And he
        // starts at home rather than at your elbow, so his first act is never to
        // relieve a first-time visitor of the painting they walked in for.
        //
        // Not a placement in `map`, and the difference is not cosmetic. `roams`
        // draws no randomness while its actor is outside the room set, so a
        // thief who is nowhere costs the seeded stream nothing — which is what
        // lets the descent, the troll and every pinned transcript taken before
        // the first treasure stay exactly what they were.
        //
        // The roster is bound out here rather than read inside the closure:
        // `rules` is evaluated once at bootstrap, so this captures one copy of
        // it instead of rebuilding twenty-five treasures on every `take`.
        let coveted = treasureRoster
        world.after(.take) {
            guard thief.thief.location == nil, !thief.thiefDefeated,
                let taken = command.directObject, coveted.contains(taken),
                taken != aboveGround.egg, taken != house.bauble
            else { return }
            summonThief()
        }

        // Hand him anything and he pockets it, weighing you the whole time.
        // Hand him the egg and he does the one thing you cannot: he opens it,
        // over the next four turns, with the bird inside still singing. `give X
        // to thief` fires this rule with the thief as the *indirect* object and
        // the offering as the direct one.
        thief.thief.before(.give) {
            // Held, and not merely named: he steals off the floor and out of
            // your hands, so the thing you are offering him is quite often
            // already in his bag, and the mocking little bow reads as a lie
            // when it is. The refusal is spelled out here rather than left to
            // stage 4, whose answer to an unheld gift is that nobody here wants
            // it — which, with the thief standing over the hoard, is the one
            // thing that is certainly untrue.
            guard let offered = command.directObject else { return }
            guard offered.isHeld else { try refuse(text.notHolding) }
            offered.move(heldBy: thief.thief)
            thief.thiefAdmiring = true
            startFuse("thief.admires")
            if offered == aboveGround.egg {
                startFuse("thief.opensEgg")
                try reply(Prose.thiefTakesEgg)
            }
            try reply(Prose.thiefTakesGift)
        }
    }

    /// The second half of the same list, split for hazard #174's reason: peak
    /// bootstrap stack depth scales with the largest single declaration body,
    /// and milestone 8's seventeenth bundle put the suite over the edge again.
    @RuleBuilder private var moreThiefRules: Rules {
        // The fight. He carries two hits, like the troll, and dies to the same
        // two blades. When he falls, everything in his bag falls with him —
        // and that is all that happens. Zork I's thief unbars the trap door on
        // his way out; this game's trap door was never his, and stays shut.
        melee.villain(
            thief.thief, key: "thief", strength: 2,
            weapons: [house.sword, house.knife],
            prose: MeleeCombat.VillainProse(
                miss: [Prose.thiefMiss1, Prose.thiefMiss2],
                wound: [Prose.thiefWound1, Prose.thiefWound2],
                knockout: Prose.thiefKnockout,
                death: Prose.thiefDeath),
            onDefeat: {
                thief.thiefDefeated = true
                stopDaemon("thief.roams")
                stopDaemon("thief.steals")
                stopDaemon("thief.stashes")
                // Not `thief.fights`: `melee.aggression` returns on a villain
                // at zero health before it does anything else.

                // The hoard, the stiletto and anything he was still holding —
                // the opened egg among it, if you paid him for the service.
                // Named before it is dropped, because the line says what fell.
                let spoils = thief.thief.inventory
                    .filter { $0 != thief.stiletto }
                    .map(\.definiteName)
                thief.thief.dropAll()
                say(Prose.thiefLootScatters(spoils))
            })

        // Walk into his lair and he comes home to it, from wherever on the
        // prowl he happens to be. Both roads in are covered: up past the
        // cyclops, and the granite wall's magic word out of the Temple.
        //
        // He then stays, because the roam daemon's gate is shut for as long as
        // you are standing in the Treasure Room — see ``Dungeon/thiefTimers``.
        // That gate is not a nicety. Without it he is summoned home during the
        // command stage and teleported straight out again by his own daemon at
        // the end of the same turn: the room listing announcing a
        // suspicious-looking individual and the next line reporting the shadowy
        // figure melting away, with nothing in between and nobody left to fight.
        maze.treasureRoom.onEnter {
            summonThief()
        }
    }

    /// Puts the thief in the Treasure Room, unless he is dead. Both the rule
    /// that brings him into play and the lair's own `onEnter` go through it, so
    /// arriving at the hoard produces him whether he was already at large or
    /// had never been seen.
    func summonThief() {
        guard !thief.thiefDefeated else { return }
        thief.thief.move(to: maze.treasureRoom)
    }

    /// His three daemons, his counter-attack, and his two fuses.
    ///
    /// Every one of them guards before it draws, so the turns he is not on
    /// screen cost the seeded stream nothing: the roam daemon idles while he is
    /// offstage, the theft daemon while he is not in your room, the stash
    /// daemon draws no randomness at all, and the aggression daemon's `while:`
    /// gate is shut everywhere but the lair.
    @TimerBuilder
    var thiefTimers: [TimedEvent] {
        // He holds still while you are standing in the hoard. `Sources/Zork1/`
        // gets this for nothing by keeping the Treasure Room out of its roam
        // set, which is not open to us — the lair has to be in the set or the
        // stash daemon never fires — so the gate does the job instead, and the
        // shut gate draws no randomness, exactly as `melee.aggression`'s does.
        actors.roams(
            thief.thief, daemonName: "thief.roams",
            rooms: thiefProwl,
            chancePerTurn: 50,
            while: { player.location != maze.treasureRoom },
            arrival: Prose.thiefArrives,
            departure: Prose.thiefLeaves)

        actors.steals(
            thief.thief, daemonName: "thief.steals",
            candidates: treasureRoster,
            chancePerTurn: 30,
            announcement: { Prose.thiefSteals($0) })

        // In the lair he unloads: everything he is carrying goes onto the floor
        // of the Treasure Room, bar the blade he keeps to hand. No draw — the
        // guard is the whole of it.
        //
        // Not while you are standing there, though. He does not tidy up in
        // front of a drawn sword, and the pair of daemons would otherwise
        // contradict each other inside one turn. Daemons fire in name order, so
        // `thief.stashes` runs before `thief.steals`: he would put the chalice
        // silently back on the floor and then announce having taken it. What he
        // takes during a fight stays in the bag until the bag falls.
        daemon("thief.stashes", autostart: true) {
            guard thief.thief.isIn(maze.treasureRoom),
                player.location != maze.treasureRoom
            else { return }
            for loot in thief.thief.inventory where loot != thief.stiletto {
                loot.move(to: maze.treasureRoom)
            }
        }

        // He fights back only where he has something to lose. Everywhere else
        // he is evasive, which is what makes the roaming half of him a nuisance
        // rather than a death sentence.
        melee.aggression(
            of: thief.thief, key: "thief", daemonName: "thief.fights",
            while: { thief.thief.isIn(maze.treasureRoom) && !thief.thiefAdmiring },
            prose: MeleeCombat.AggressionProse(
                miss: [Prose.thiefSwipeMiss],
                wound: [Prose.thiefSwipeWound],
                playerDeath: Prose.thiefKillsYou))

        // The service you paid him for. Four turns after the egg leaves your
        // hands its mechanism gives, and the canary is still whole. Silent —
        // you are not there to watch — and cancelled if you kill him first, in
        // which case the egg comes back shut and your own fingers are all you
        // have left.
        fuse("thief.opensEgg", after: 4) {
            guard !thief.thiefDefeated else { return }
            aboveGround.egg.isOpen = true
        }

        // The end of the appraisal. Two turns of a gift held up to the lamp is
        // two turns he is not stabbing anybody, which is what buys you the room
        // to hand him the egg and get back down the stairs. Silent: he could be
        // anywhere by now, and a line saying he has looked up would print in a
        // room the player is not standing in.
        fuse("thief.admires", after: 2) {
            thief.thiefAdmiring = false
        }
    }
}
