import Gnusto
import GnustoActors
import GnustoDangerousDark
import GnustoMeleeCombat
import GnustoScoring

extension TraitKey<Bool> {
    /// A source `TOOLBIT` item that can force the egg's mechanism.
    static let opensEggDestructively = Self("opensEggDestructively", default: false)
}

/// *Zork I: The Great Underground Empire* — the complete game. Composes every
/// region — the above-ground grounds (``ZorkAboveGround``), the house
/// (``ZorkHouse``), the cellar (``ZorkCellar``), the Round Room hub
/// (``ZorkRoundRoom``), the dam (``ZorkDam``), the temple and Hades
/// (``ZorkTemple``), the mirror rooms (``ZorkMirror``), the coal mine
/// (``ZorkCoalMine``), the Frigid River (``ZorkRiver``), and the maze
/// (``ZorkMaze``), with the thief (``ZorkThief``) at large below — and wires the
/// exits and puzzles that cross between them. Everything else about each region
/// is that region's own concern; the host only owns what genuinely spans two.
/// A full 350-point playthrough is exercised end-to-end by `Zork1WalkthroughTests`.
@main
struct Zork1: Game, GameMain {
    let title = "Zork I: The Great Underground Empire"
    let tagline = "Nineteen treasures wait in the dark beneath a white house."

    /// The game's ceiling: 350 points, as in the original — all of it reachable,
    /// across the nineteen treasures (found and cased) and the five event awards.
    /// Depositing the last treasure reveals the map to the Stone Barrow, and
    /// entering it wins.
    let maxScore = 350
    let intro = """
        An adventure awaits amid a ruined empire buried underground. A white
        house stands on a forgotten lawn; below it lie caverns, a dam, a
        temple, a coal mine, a river, and a maze — and treasures enough to
        fill a barrow, if you can carry them home past the thief.
        """

    /// The stock engine lines re-skinned to Zork's own originals, for the
    /// handful that differ from Gnusto's classic voice. Each is the verbatim
    /// text from the original Zork I source (see `THIRD_PARTY_NOTICES`); every
    /// line not set here keeps the engine default, which already matches Zork.
    var text: GameText {
        var text = GameText()
        // The famous dark-room line (gverbs.zil V-LOOK / the grue clause).
        text.pitchBlack = "It is pitch black. You are likely to be eaten by a grue."
        // Examining an ordinary thing (gverbs.zil V-EXAMINE).
        text.nothingSpecial = .naming { "There's nothing special about \($0)." }
        // Open/close and possession refusals (gverbs.zil).
        text.alreadyOpen = "It is already open."
        text.alreadyClosed = "It is already closed."
        text.alreadyHave = "You already have that!"
        // `V-SUPER-BRIEF` (gverbs.zil:23) hyphenates where the engine's stock
        // line, following the modern ZIL library, writes the word closed up.
        // `V-VERBOSE` and `V-BRIEF` need no line: the engine already matches.
        text.superbriefDescriptions = "Super-brief descriptions."
        // Parser: an unrecognized sentence (gparser.zil).
        text.didntUnderstand = "That sentence isn't one I recognize."
        // "take all" with nothing to take (gmain.zil).
        text.nothingToTakeHere = "There's nothing here you can take."
        // The carrying cap's refusal, for ``burden``.
        text.handsFull = .init(Prose.handsFull)
        // ENTER / GO THROUGH something that is neither doorway nor vehicle
        // (gverbs.zil V-THROUGH's last clause).
        text.cantEnterThat = .naming {
            "You hit your head against \($0) as you attempt this feat."
        }
        // `V-HELLO` (`gverbs.zil:724`), all three branches. `hello` used to be a
        // verb of this game's own, answering from a row that could not see the
        // room — so the troll, the thief and the cyclops were greeted with
        // "Nobody here returns your greeting." The engine's `.greet` reads the
        // frame, and ``ZorkSystems`` now hands it the bare words. (#325)
        //
        // The source's actor branch writes "The " D ,PRSO; the engine hands
        // every named line the definite phrase already, so the article is the
        // engine's here as it is for `knock`.
        text.greets = .naming { "\($0.sentenceCased) bows his head to you in greeting." }
        // The non-actor branch (`:731`) writes an *indefinite* article, which no
        // named line in the engine deals in. One word, recorded in `FIDELITY.md`
        // beside `knock`'s.
        text.cantGreetThat = .naming {
            "It's a well known fact that only schizophrenics say \"Hello\" to \($0)."
        }
        // Objectless `hello` draws one of four (`HELLOS`, `:2198`) and a stock
        // line cannot draw, so these take two of the four; the draw is recorded
        // in `FIDELITY.md` beside `jump`'s and `touch`'s. The split is between
        // *empty* and *crowded*, not empty and occupied: the engine fills a bare
        // greeting in with the sole visible actor, so `greetsTheRoom` needs two
        // of the cast at once — which here means the roaming thief arriving on
        // the troll or the cyclops.
        text.nobodyToGreet = "Hello."
        text.greetsTheRoom = "Good day."
        // The stub floor — every verb the parser knows and no mechanic answers.
        text.stubs = Prose.stubFloor
        return text
    }

    let aboveGround = ZorkAboveGround()
    let house = ZorkHouse()
    let cellar = ZorkCellar()
    let roundRoom = ZorkRoundRoom()
    let dam = ZorkDam()
    let temple = ZorkTemple()
    let mirror = ZorkMirror()
    let coalMine = ZorkCoalMine()
    let river = ZorkRiver()
    let maze = ZorkMaze()
    let thief = ZorkThief()

    /// The grue. Zork's prose, the plugin's stock warn-then-kill schedule.
    let dangerousDark = DangerousDark(text: Prose.grueText)

    /// The five event awards, declared where the bootstrap can total them. With
    /// the nineteen treasures' `.takeValue` (143) and `.depositValue` (129) this
    /// comes to exactly ``maxScore`` — the original's 350, now checked at
    /// bootstrap rather than trusted.
    let scoring = Scoring(
        awards: [
            "kitchen": 10,
            "cellar": 25,
            "eastWestPassage": 5,
            "draftyRoom": 13,
            "treasureRoom": 25,
        ])
    /// The melee plugin claims `.attack` outright, so its four system-voice
    /// lines — not ``Prose/stubFloor``'s `attack` — are what a player who swings
    /// at the scenery actually reads. They were the plugin's stock modern ones.
    /// All four are `V-ATTACK` (`gverbs.zil:176-193`). (#242)
    let melee = MeleeCombat(text: Prose.combatText)
    let actors = ActorBehaviors()

    /// The custom verb vocabulary (dig, wave, ring, xyzzy, drink/fill/pour …)
    /// and its stage-4 defaults.
    let systems = ZorkSystems()

    /// The weight/burden system: takeable items have weight and the player
    /// can only carry so much.
    /// The carrying cap. The original's is 100; at the default item weight of
    /// 5 that's twenty small things — ample, and tight enough that the
    /// loaded-down cases (and the chimney's stricter count gate) can be
    /// exercised. The heavy items declare their own `.weight`.
    let burden = Burden(carryCap: 100)

    /// How many times the player has died. Deaths one and two are survivable
    /// (see ``onDeath()``); the third is final.
    @Global var deaths = 0

    /// Matches left in the Dam Lobby matchbook. The matchbook is a ``ZorkDam``
    /// item and the candles it lights are ``ZorkTemple`` items, so the striking
    /// mechanic — finite matches, a short-lived burning match — is the host's,
    /// like every other seam that spans two bundles.
    @Global var matchesLeft = 5

    var content: GameContents {
        aboveGround
        house
        cellar
        roundRoom
        dam
        temple
        mirror
        coalMine
        river
        maze
        thief
        dangerousDark
        scoring
        melee
        systems
        burden
    }

    /// Replace the engine's plain score line with one that also names the
    /// rank the score earns. `score` is a meta intent (it skips all rules),
    /// so this can't be an `after(.score)` rule — the override is the only
    /// seam. The first line reproduces the engine's `scoreLine` verbatim so
    /// existing "Your score is N of a possible 350" assertions still hold.
    /// `overriding: true` says the shadowing is deliberate, which keeps the
    /// bootstrap's built-in-override warning off every player's screen.
    var actions: [IntentAction] {
        let possibleScore = maxScore
        action(.score, overriding: true) {
            let moves = player.moves
            say(
                """
                Your score is \(player.score) of a possible \(possibleScore),
                in \(moves) \(moves == 1 ? "turn" : "turns").
                """)
            say(Prose.rankLine(ZorkRank.name(for: player.score)))
        }
        // `diagnose` reports the death toll and how many resurrections remain
        // (the first two deaths are survivable — see ``onDeath()``). The verb is
        // taught by ``ZorkSystems``; the report lives here because it reads the
        // host's ``deaths`` counter.
        action(.diagnose) {
            guard deaths > 0 else { try reply(Prose.diagnoseUnscathed) }
            try reply(Prose.diagnoseDeaths(deaths, resurrectionsLeft: max(0, 2 - deaths)))
        }
    }

    /// Zork's canonical resurrection. The first two deaths are survivable: the
    /// player loses ten points, their belongings scatter across the grounds
    /// above, and they wake in the forest. The third death is final — it falls
    /// through to the engine's banner and RESTART / RESTORE / UNDO / QUIT
    /// prompt. Runs inside the live turn, after the death message has printed,
    /// so it can teleport, dock the score, and move items just as a rule would.
    func onDeath() -> DeathOutcome {
        deaths += 1
        guard deaths < 3 else { return .fallThrough }
        scoring.penalize(10)

        // Belongings strew unpredictably across the grounds — the original's
        // random scatter, one draw per item. The lamp is the kept exception: it
        // always turns up in the living room, so light is never lost to a death
        // (a deliberate anti-softlock).
        player.scatterInventory(
            across: [
                aboveGround.westOfHouse, aboveGround.northOfHouse,
                aboveGround.southOfHouse, aboveGround.behindHouse,
                aboveGround.forestPath, aboveGround.clearingEast,
            ],
            except: [house.lantern: house.livingRoom])

        player.location = aboveGround.forestWest
        say(Prose.resurrection)
        describeSurroundings()
        return .consumed
    }

    /// The full nineteen scored treasures — the seventeen from earlier tasks
    /// plus the golden canary and the brass bauble it summons. Shared by the
    /// trophy-case scoring and the thief's steal list, so the two never drift
    /// apart (the thief covets everything, canonically).
    private var treasureRoster: [Item] {
        [
            cellar.painting, aboveGround.egg, roundRoom.platinumBar, dam.trunk,
            temple.torch, temple.coffin, temple.sceptre, temple.crystalSkull,
            mirror.crystalTrident, coalMine.jade, coalMine.sapphireBracelet,
            coalMine.diamond, river.emerald, river.scarab, river.potOfGold,
            maze.bagOfCoins, maze.silverChalice, house.canary, house.bauble,
        ]
    }

    /// The forest rooms the songbird answers in — the three Forest rooms, the
    /// Forest Path, and the perch Up a Tree (canonical `FOREST-ROOM?`). Winding
    /// the canary here summons the bird that drops the ``ZorkHouse/bauble``.
    private var forestRooms: [Location] {
        [
            aboveGround.forestWest, aboveGround.forestEast,
            aboveGround.forestNortheast, aboveGround.forestPath,
            aboveGround.upATree,
        ]
    }

    /// Every underground room the thief may teleport-roam through — the whole
    /// dungeon below the trap door, save his own lair (the Treasure Room, which
    /// he's summoned to defend rather than wanders into) and the Land of the
    /// Dead. Used only by the roam daemon.
    private var undergroundRooms: [Location] {
        [
            house.cellar,
            cellar.eastOfChasm, cellar.gallery, cellar.studio, cellar.trollRoom,
            roundRoom.eastWestPassage, roundRoom.roundRoom, roundRoom.nsPassage,
            roundRoom.chasmRoom, roundRoom.deepCanyon, roundRoom.dampCave, roundRoom.loudRoom,
            dam.damRoom, dam.damLobby, dam.maintenanceRoom, dam.damBase, dam.reservoirSouth,
            dam.reservoir, dam.reservoirNorth, dam.streamView, dam.stream,
            temple.engravingsCave, temple.domeRoom, temple.torchRoom, temple.temple,
            temple.egyptRoom, temple.altar, temple.cave, temple.entranceToHades,
            mirror.narrowPassage, mirror.mirrorRoomNorth, mirror.windingPassage,
            mirror.mirrorRoomSouth, mirror.coldPassage, mirror.twistingPassage,
            mirror.smallCave, mirror.atlantisRoom, mirror.slideRoom,
            coalMine.mineEntrance, coalMine.squeakyRoom, coalMine.batRoom, coalMine.shaftRoom,
            coalMine.smellyRoom, coalMine.gasRoom, coalMine.mine1, coalMine.mine2,
            coalMine.mine3, coalMine.mine4, coalMine.ladderTop, coalMine.ladderBottom,
            coalMine.deadEnd, coalMine.timberRoom, coalMine.draftyRoom, coalMine.machineRoom,
            river.river1, river.river2, river.river3, river.river4, river.river5,
            river.whiteCliffsNorth, river.whiteCliffsSouth, river.shore, river.sandyBeach,
            river.sandyCave, river.aragainFalls, river.onRainbow,
            maze.maze1, maze.maze2, maze.maze3, maze.maze4, maze.maze5, maze.maze6,
            maze.maze7, maze.maze8, maze.maze9, maze.maze10, maze.maze11, maze.maze12,
            maze.maze13, maze.maze14, maze.maze15, maze.deadEnd1, maze.deadEnd2,
            maze.deadEnd3, maze.deadEnd4, maze.gratingRoom, maze.cyclopsRoom, maze.strangePassage,
        ]
    }

    /// Moves the thief's carried treasure into a room. The source's
    /// `DEPOSIT-BOOTY` also opens the egg during every deposit, whether the
    /// normal stash daemon or the thief's death requested it.
    private func depositThiefBooty(in room: Location) {
        for loot in thief.thief.inventory where loot != thief.stiletto {
            loot.move(to: room)
            if loot == aboveGround.egg {
                aboveGround.egg.isOpen = true
                stopFuse("thiefOpensEgg")
            }
        }
    }

    /// Replaces the shell at its current placement and transfers its cargo.
    /// Only a canary still inside is ruined; a removed bird stays intact.
    private func damageEgg() {
        let ruinsCanary = aboveGround.egg.holds(house.canary)
        if ruinsCanary { house.canary.replace(with: house.brokenCanary) }
        for content in aboveGround.egg.contents {
            content.move(inside: aboveGround.brokenEgg)
        }
        aboveGround.egg.replace(with: aboveGround.brokenEgg)
        if ruinsCanary { say(Prose.brokenCanaryFirstSight) }
    }

    var rules: Rules {
        // The treasures the slice can score, and where they pay out.
        // Cross-bundle wiring is the host's job, same as the exits below.
        scoring.treasures(treasureRoster, into: house.trophyCase)

        // `V-KNOCK` (`gverbs.zil:765`) branches on `DOORBIT`: "Nobody's home."
        // at a door, and names the thing knocked on at anything else. The stub
        // floor carries the second branch, because it is the one a line can
        // word; this carries the first, because being a door is a fact about
        // the map and no stub line can see it. Game-wide rather than one rule
        // per door: the source asks the flag, not the object, and a door the
        // game grows later is covered the day the map hangs it.
        world.before(.knock) {
            guard let object = command.directObject, object.isDoor else { return }
            try reply(Prose.verbKnockDoor)
        }

        // Behind House ends its paragraph on the state of the kitchen window,
        // as `EAST-HOUSE` does. The room is `ZorkAboveGround`'s and the window
        // is `ZorkHouse`'s, so the sentence that reads both is the host's.
        aboveGround.behindHouse.describe {
            Prose.behindHouse(windowOpen: house.window.isOpen)
        }

        // The shortcut is the maze's state; the revealed trap door records the moved rug in the house.
        house.livingRoom.describe {
            Prose.livingRoom(
                shortcutOpen: maze.eastWallOpen,
                rugMoved: house.trapDoor.isRevealed,
                trapDoorOpen: house.trapDoor.isOpen)
        }
        house.livingRoom.onEnter {
            if maze.eastWallOpen { house.cyclopsOpening.reveal() }
        }

        // `enter house` is `WHITE-HOUSE-F`'s `THROUGH` branch, and it answers
        // for the same pair: from behind the house an open window walks you
        // into the Kitchen and a shut one says so, and from any other side
        // there is no way in. Without it `enter house` fell through to
        // `V-THROUGH`'s generic head-butt from every side alike.
        aboveGround.whiteHouseAtBehind.before(.board) {
            try require(house.window.isOpen, else: Prose.enterHouseWindowShut)
            try enter(house.kitchen)
            try handled()
        }
        for side in [
            aboveGround.whiteHouseAtWest,
            aboveGround.whiteHouseAtNorth,
            aboveGround.whiteHouseAtSouth,
        ] {
            side.before(.board) {
                try refuse(Prose.enterHouseNoWayIn)
            }
        }

        // Event scoring: the original pays for reaching the kitchen (first
        // way into the house), for descending into the cellar, and for
        // pressing east past the troll into the East-West Passage. All are
        // rooms the host owns the wiring for.
        scoring.visit(house.kitchen, register: "kitchen")
        scoring.visit(house.cellar, register: "cellar")
        scoring.visit(roundRoom.eastWestPassage, register: "eastWestPassage")
        scoring.visit(coalMine.draftyRoom, register: "draftyRoom")

        // The chimney is climbable only lightly loaded: the original lets you
        // carry at most one item plus the lamp up it. The lamp rides free; any
        // more than one other thing in hand and the climb is refused. Studio
        // lives in ZorkCellar and the rule is a burden concern, so the host
        // owns it.
        cellar.studio.before(.go) {
            guard command.direction == .up else { return }
            let besidesLamp = player.inventory.filter { $0 != house.lantern }.count
            try require(besidesLamp <= 1, else: Prose.chimneyTooBurdened)
        }

        // The dam bolt. Turning it works the sluice gates, but only with the
        // wrench and only while the panel is charged (the yellow button's green
        // bubble). Opening the gates drains the reservoir; closing them fills it
        // — an eight-turn passage in either case, during which water is moving
        // through the depths and the Loud Room becomes unbearable. The bolt is a
        // dam entity but its effect reaches into ``ZorkRoundRoom``'s
        // ``waterMoving`` and arms the host fuses below, so it's the host's to
        // wire — same as the troll's east exit and the chimney gate above.
        dam.bolt.before(.turnWith) {
            try require(command.indirectObject == dam.wrench, else: Prose.boltNeedsWrench)
            try require(dam.bubbleGlowing, else: Prose.boltWontTurn)
            dam.gatesOpen.toggle()
            roundRoom.waterMoving = true
            if dam.gatesOpen {
                stopFuse("damRefill")
                startFuse("damDrain", after: 8)
                try reply(Prose.gatesOpen)
            } else {
                stopFuse("damDrain")
                startFuse("damRefill", after: 8)
                try reply(Prose.gatesClose)
            }
        }

        // The attic rope tied to the dome railing — the rope is a ``ZorkHouse``
        // item and the railing a ``ZorkTemple`` one, so the host owns the knot.
        // Tying it sets the temple's ``ropeTiedToRailing`` (which gates the drop
        // to the Torch Room) and leaves the rope hanging in the Dome Room;
        // untying — or simply taking it back — undoes the descent.
        house.rope.before(.tie) {
            guard player.location == temple.domeRoom else {
                try refuse(Prose.ropeNothingToTie)
            }
            try require(command.indirectObject == temple.railing, else: Prose.ropeNeedsRailing)
            temple.ropeTiedToRailing = true
            house.rope.move(to: temple.domeRoom)
            try reply(Prose.ropeTied)
        }
        house.rope.before(.untie) {
            guard temple.ropeTiedToRailing else { return }
            temple.ropeTiedToRailing = false
            try reply(Prose.ropeUntied)
        }
        house.rope.before(.take) {
            guard temple.ropeTiedToRailing else { return }
            temple.ropeTiedToRailing = false
            say(Prose.ropeTakeUnties)
            // Falls through to the default take, which picks the rope up.
        }

        // Praying at the altar. The altar is a ``ZorkTemple`` room but the
        // prayer lands the player in ``ZorkAboveGround``'s forest, so the host
        // wires it. This is the only way to carry the gold coffin out of the
        // temple — it can't be squeezed down the altar crack. Held items ride
        // along (they stay in hand), the coffin included.
        temple.altar.before(.pray) {
            say(Prose.prayerAnswered)
            arrive(at: aboveGround.forestWest)
            try handled()
        }

        // Striking a match. The matchbook is a ``ZorkDam`` item (the Dam Lobby),
        // but the burning match it produces is a ``ZorkTemple`` item and its
        // only use is lighting the temple candles, so the host bridges them:
        // finite matches, and a burning match that lasts two turns (the fuse
        // below) before it goes out.
        dam.matchbook.before(.turnOn) {
            try require(matchesLeft > 0, else: Prose.matchesGone)
            matchesLeft -= 1
            temple.burningMatch.moveToPlayer()
            temple.burningMatch.isLit = true
            startFuse("matchBurns", after: 2)
            try reply(Prose.matchStrikes)
        }

        // The vampire bat in the Coal Mine's Bat Room. Enter without the garlic
        // in hand and it carries you off to a random room in the mine; hold the
        // garlic and it keeps its distance. The bat is a ``ZorkCoalMine`` fixture
        // but the garlic is a ``ZorkHouse`` item, so the host owns the check. The
        // garlic guard comes before the draw, so an armed entry never touches the
        // random stream — this is the region's one source of randomness.
        coalMine.batRoom.onEnter {
            guard !player.inventory.contains(house.garlic) else { return }
            let drops = [
                coalMine.mine1, coalMine.mine2, coalMine.mine3, coalMine.mine4,
                coalMine.ladderTop, coalMine.ladderBottom, coalMine.squeakyRoom,
                coalMine.mineEntrance,
            ]
            say(Prose.batGrabsYou)
            arrive(at: drops[random(0...(drops.count - 1))])
        }

        // The machine that makes a diamond. Throw its switch with the screwdriver
        // (a ``ZorkDam`` tool) while the lid is shut on a load of coal and the
        // coal is transmuted; any other tool, an open lid, or no coal and nothing
        // comes of it. The switch and machine are mine fixtures, the screwdriver a
        // dam item, so the host wires the crossing — like the dam bolt above.
        coalMine.machineSwitch.before(.turnWith) {
            try require(command.indirectObject == dam.screwdriver, else: Prose.switchNeedsTool)
            guard !coalMine.machine.isOpen else { try reply(Prose.machineLidOpen) }
            guard coalMine.machine.holds(coalMine.coal) else {
                // No coal to transmute. Anything else inside is ground to a
                // worthless slag and lost (the original's non-coal grind); an
                // empty machine simply whirs (FIDELITY.md).
                let contents = coalMine.machine.contents
                guard contents.isEmpty else {
                    for junk in contents { junk.vanish() }
                    try reply(Prose.machineGrindsToGunk)
                }
                try reply(Prose.machineWhirsToNoEffect)
            }
            coalMine.coal.replace(with: coalMine.diamond)
            try reply(Prose.machineMakesDiamond)
        }

        // Inflating the boat. The pile of plastic is a ``ZorkRiver`` item, the
        // hand pump a ``ZorkDam`` one, so the host bridges them — like the match
        // and the machine. `IBOAT-FUNCTION` grades the refusal in this order:
        // the pile must be lying on the ground before anything else is asked,
        // then only the pump will do it. Naming no tool is the breath case
        // (`V-BREATHE` performs INFLATE with `LUNGS`); naming the wrong one gets
        // the jest. Inflating trades the pile for the seaworthy boat — and names
        // the tan label folded inside it, until the player has handled the label
        // (the ZIL's `<NOT <FSET? ,BOAT-LABEL ,TOUCHBIT>>`, which that branch
        // reads but never sets, so a deflate-and-pump cycle says it again).
        river.pileOfPlastic.before(.inflate) {
            try require(river.pileOfPlastic.isIn(player.location), else: Prose.inflateNotOnGround)
            guard let tool = command.indirectObject else {
                try reply(Prose.inflateNeedsPump)
            }
            try require(
                tool == dam.handPump, else: Prose.inflateWithWrongThing(tool.indefiniteName))
            river.pileOfPlastic.replace(with: river.magicBoat)
            say(Prose.boatInflates)
            if !river.tanLabel.isTouched {
                say(Prose.tanLabelInBoat)
            }
            try handled()
        }

        // Patching the punctured boat. The tube of Frobozz Magic Gunk (a
        // ``ZorkDam`` item) seals the ruined hull; the boat is a ``ZorkRiver``
        // one, so the host bridges them — like inflating with the dam's pump.
        // A puncture afloat is always fatal, so the wreck is only ever ashore;
        // sealing it trades the ruin back for the seaworthy boat and spends the
        // gunk (FIDELITY.md: the boat repair the earlier slice left unmodeled).
        river.puncturedBoat.before(.fix) {
            try require(command.indirectObject == dam.tube, else: Prose.fixNeedsGunk)
            dam.tube.vanish()
            river.puncturedBoat.replace(with: river.magicBoat)
            try reply(Prose.boatPatched)
        }

        // Launching the boat. Its first launch point is the dam's Dam Base, so
        // the host owns the rule; the White Cliffs, Sandy Beach and Shore
        // re-launch onto the river too, each onto its canonical stretch. You must
        // be aboard, and there has to be water under you. Launching arms the
        // current (the `riverCurrent` daemon ``ZorkRiver`` declares).
        river.magicBoat.before(.launch) {
            try require(player.vehicle == river.magicBoat, else: Prose.launchNotAboard)
            let here = player.location
            // The delay is the stretch's canonical dwell plus one — the daemon
            // decrements it this same turn (see ``ZorkRiver.driftDelay``).
            let target: Location
            let delay: Int
            if here == dam.damBase {
                (target, delay) = (river.river1, 5)
            } else if here == river.whiteCliffsNorth {
                (target, delay) = (river.river3, 4)
            } else if here == river.whiteCliffsSouth || here == river.sandyBeach {
                (target, delay) = (river.river4, 3)
            } else if here == river.shore {
                (target, delay) = (river.river5, 2)
            } else {
                try reply(Prose.launchNotHere)
            }
            river.magicBoat.move(to: target)
            say(Prose.boatLaunches)
            describeSurroundings()
            river.armCurrent(delay)
            try handled()  // handled — don't fall through to the stage-4 default
        }

        // Waving the sceptre wakes the rainbow. The sceptre is a ``ZorkTemple``
        // treasure, but the rainbow spans a ``ZorkRiver`` room (Aragain Falls) and
        // a ``ZorkAboveGround`` one (the End of Rainbow), and the pot of gold sits
        // at the latter — so the host owns the wave. At either end it turns the
        // rainbow solid (and reveals the pot); on the rainbow itself, it drops you
        // into the falls.
        temple.sceptre.before(.wave) {
            let here = player.location
            if here == river.onRainbow {
                try die(Prose.rainbowWaveFatal)
            }
            guard here == river.aragainFalls || here == aboveGround.endOfRainbow else {
                try reply(Prose.sceptreSparkles)
            }
            river.rainbowSolid.toggle()
            guard river.rainbowSolid else { try reply(Prose.rainbowFades) }
            river.potOfGold.reveal()
            say(Prose.rainbowSolidifies)
            if here == aboveGround.endOfRainbow {
                say(Prose.potAppears)
            }
            try handled()
        }

        // MAZE-11-FCN exposes the grating from below without setting the
        // permanent topside discovery latch. CLEARING-FCN restores concealment.
        maze.gratingRoom.onEnter {
            aboveGround.grating.reveal()
        }
        aboveGround.grating.after(.open) {
            guard player.location == maze.gratingRoom else { return }
            guard aboveGround.$gratingDiscovered.trips() else { return }
            aboveGround.leaves.move(to: maze.gratingRoom)
            say(Prose.gratingOpensFromBelow)
        }

        maze.rustyKnife.after(.take) {
            guard house.sword.isHeld else { return }
            say(Prose.rustyKnifeBluePulse)
        }

        // Feeding the cyclops. The lunch, bottle and water are ``ZorkHouse``
        // items and the cyclops a ``ZorkMaze`` one, so the host bridges them —
        // like the match and the machine. Give him the lunch and he turns
        // thirsty; give him the water (the bottle full) and he drinks himself to
        // sleep, clearing the stair. (Fed asleep he never smashes the east wall
        // — only ``odysseus`` does that; see ``ZorkMaze``.)
        maze.cyclops.before(.give) {
            guard let offered = command.directObject else { return }
            guard !maze.cyclopsSubdued else { try reply(Prose.cyclopsAlreadyGone) }
            if offered == house.lunch {
                house.lunch.vanish()
                maze.$cyclopsThirsty.trips()
                // The peppers leave him desperate for a drink: his hunger is
                // roused now, so the wrath timer starts counting. Give him the
                // water soon or become the drink yourself (see ``ZorkMaze``).
                maze.$cyclopsProvoked.trips()
                try reply(Prose.cyclopsEatsLunch)
            }
            let givingWater =
                offered == house.water
                || (offered == house.bottle && house.bottle.isOpen && house.bottle.holds(house.water))
            if givingWater {
                guard maze.cyclopsThirsty else { try reply(Prose.cyclopsNotThirsty) }
                house.water.vanish()
                maze.cyclopsSubdued = true
                try reply(Prose.cyclopsDrinksAndSleeps)
            }
            try refuse(Prose.cyclopsWontEatThat)
        }

        // SKELETON calls ROB on HERE and ADVENTURER: direct, revealed objects
        // with positive TVALUE, excluding SACREDBIT. The coffin stays sacred;
        // ECHO clears the bar's sacred state. Other equipment has no TVALUE.
        // The destination crosses into ZorkTemple, so the host owns the rule.
        let banishForDisturbingTheBones: @Sendable () -> Void = {
            for item in player.location.contents + player.inventory {
                guard item.isRevealed, (item[.depositValue] ?? 0) > 0 else { continue }
                guard item != temple.coffin else { continue }
                guard item != roundRoom.platinumBar || roundRoom.loudRoomAcousticsFixed else { continue }
                item.move(to: temple.landOfDead)
            }
        }
        maze.skeleton.before(.take) {
            banishForDisturbingTheBones()
            try refuse(Prose.skeletonLeaveItBe)
        }
        maze.skeleton.before(.lookIn) {
            banishForDisturbingTheBones()
            try refuse(Prose.skeletonLeaveItBe)
        }
        maze.skeleton.before(.push) {
            banishForDisturbingTheBones()
            try refuse(Prose.skeletonLeaveItBe)
        }

        // The troll, fought with anything marked as a weapon. Strength 2 is
        // the original's.
        melee.villain(
            cellar.troll, key: "troll", strength: 2,
            prose: MeleeCombat.VillainProse(
                miss: [Prose.trollMiss1, Prose.trollMiss2],
                wound: [Prose.trollWound1, Prose.trollWound2],
                knockout: Prose.trollKnockout,
                death: Prose.trollDeath),
            onKnockout: {
                if cellar.troll.holds(cellar.axe) {
                    cellar.axe.move(to: cellar.trollRoom)
                }
            },
            onDefeat: {
                cellar.$trollDefeated.trips()
                if cellar.troll.holds(cellar.axe) {
                    cellar.axe.move(to: cellar.trollRoom)
                }
            })

        // The bar. Descending while the thief is at large throws the bolt
        // above — the slam prose's "you hear a bolt slide home" has been
        // telling the truth-to-be since Phase 5. One-sided: the living
        // room side is never barred.
        house.cellar.onEnter {
            if !thief.thiefDefeated {
                house.trapDoorBarred = true
            }
        }
        house.trapDoor.before(.open) {
            if player.location == house.cellar && house.trapDoorBarred {
                try refuse(Prose.trapDoorBarred)
            }
        }

        // The silver chalice is snatchable straight from the thief's hoard —
        // but he steals treasures back from your hands (and off the floor),
        // so lifting it while he lives is only a loan: his steal daemon takes
        // it back on a later turn, the original's snatch-and-resteal. No guard
        // rule; the chalice is an ordinary treasure the thief happens to covet.

        // The endgame trigger. When the last of the nineteen treasures settles
        // into the case, the ancient map to the Stone Barrow appears among them.
        // An `after(.putIn)` fires for the container (the indirect object), so
        // this rule sits on the trophy case; it runs after the deposited
        // treasure's own scoring rule, so the score already reads 350 here. The
        // map and case span two bundles, so the host owns the wiring.
        house.trophyCase.after(.putIn) {
            guard !aboveGround.ancientMap.isRevealed,
                treasureRoster.allSatisfy({ house.trophyCase.holds($0) })
            else { return }
            aboveGround.ancientMap.reveal()
            say(Prose.ancientMapAppears)
        }

        // Crossing into the barrow wins the game. You first arrive at the Stone
        // Barrow (seeing the open door in its east face), then step west/`in` to
        // this final room — the original's two-step entry. `end(won:)` throws
        // before the room is auto-described, so the epilogue stands in for the
        // room text; the engine appends the final score line after the turn.
        aboveGround.insideBarrow.onEnter {
            say(Prose.stoneBarrowEpilogue)
            try end(won: true)
        }

        // After DROP's possession gate succeeds, cargo falls to the path.
        // Move the nest too: TREE-ROOM's prose says it falls, although that
        // source branch leaves the nest upstairs. FIDELITY.md records the fix.
        aboveGround.upATree.after(.drop) {
            guard let item = command.directObject else { return }
            item.move(to: aboveGround.forestPath)
            if item == aboveGround.nest && aboveGround.nest.holds(aboveGround.egg) {
                say(Prose.nestFalls)
                damageEgg()
                aboveGround.brokenEgg.move(to: aboveGround.forestPath)
            } else if item == aboveGround.egg {
                say(Prose.eggFalls)
                damageEgg()
            } else {
                say(Prose.treeObjectFalls(item.name))
            }
        }

        // EGG-OBJECT's qualifying OPEN replaces the shell through the same
        // damage lifecycle as a fall. The thief opens the intact egg directly.
        aboveGround.egg.before(.open) {
            guard aboveGround.egg.isReachable else {
                try refuse(gameText.cantReach(aboveGround.egg.definiteNoun))
            }
            guard !aboveGround.egg.isOpen else { return }
            guard let tool = command.indirectObject else {
                let words = command.rawInput.lowercased().split(whereSeparator: { !$0.isLetter })
                if words.last == "hands" {
                    try refuse(Prose.eggHandsRiskDamage)
                }
                try refuse(Prose.eggNeedsTool)
            }
            guard tool.isHeld else { try refuse(gameText.notHolding()) }
            guard tool[default: .sharp] || tool[default: .opensEggDestructively] else {
                try refuse(Prose.eggWrongTool(tool.indefiniteName))
            }
            say(Prose.eggForcedRuinsCanary)
            damageEgg()
            try handled()
        }

        // Wind the intact canary out among the trees and a songbird answers,
        // dropping a brass bauble at your feet — once ever. Anywhere else, or
        // after the bird has already come, it just chirps a tinny tune. Wound
        // up in the tree, the bauble falls to the path below. The canary is a
        // ``ZorkHouse`` item and the forest rooms are ``ZorkAboveGround``, so
        // the host owns this cross-bundle trick.
        house.canary.before(.wind) {
            guard forestRooms.contains(where: { player.location == $0 }),
                house.$baubleDropped.trips()
            else {
                try reply(Prose.canaryChirps)
            }
            if player.location == aboveGround.upATree {
                house.bauble.move(to: aboveGround.forestPath)
            } else {
                house.bauble.move(to: player.location)
            }
            try reply(Prose.songbirdDropsBauble)
        }

        // The ruined bird only grinds its stripped gears — no song, no bird.
        house.brokenCanary.before(.wind) {
            try reply(Prose.brokenCanaryWinds)
        }

        // Hand the thief anything and he pockets it, weighing you the whole
        // time. Give him the jewel-encrusted egg and — where your own clumsy
        // fingers would wreck it — he opens it cleanly, a four-turn service (the
        // `thiefOpensEgg` fuse below). `give X to thief` fires this item-before
        // for the thief as the *indirect* object; the offered item is the
        // direct object. Weapons and treasures span other bundles, so the host
        // wires the thief's every seam.
        thief.thief.before(.give) {
            guard let offered = command.directObject else { return }
            guard !thief.thiefDefeated else { return }
            guard offered.isHeld else { try refuse(gameText.notHolding()) }
            offered.move(heldBy: thief.thief)
            if offered == aboveGround.egg {
                startFuse("thiefOpensEgg", after: 4)
                try reply(Prose.thiefTakesEgg)
            }
            try reply(Prose.thiefTakesGift)
        }

        // The thief fights to the death in his lair (the aggression daemon
        // below is gated to the Treasure Room) and, when he falls, drops
        // everything he carried — the whole hoard and his own stiletto — and
        // the trap door he bolted from below swings free.
        melee.villain(
            thief.thief, key: "thief", strength: 2,
            prose: MeleeCombat.VillainProse(
                miss: [Prose.thiefMiss1, Prose.thiefMiss2],
                wound: [Prose.thiefWound1, Prose.thiefWound2],
                knockout: Prose.thiefKnockout,
                death: Prose.thiefDeath),
            onDefeat: {
                thief.$thiefDefeated.trips()
                house.trapDoorBarred = false
                stopDaemon("thiefRoams")
                stopDaemon("thiefSteals")
                stopDaemon("thiefStash")
                stopDaemon("thiefFights")
                // Deposit the hoard first so the egg gets the same careful
                // opening as an ordinary stash. The stiletto then follows.
                depositThiefBooty(in: player.location)
                thief.thief.dropAll()
                say(Prose.thiefLootScatters)
            })

        // The lair pays 25 on first entry, and entering it summons the thief
        // (off prowling elsewhere) home to defend his hoard.
        scoring.visit(maze.treasureRoom, register: "treasureRoom")
        maze.treasureRoom.onEnter {
            guard !thief.thiefDefeated else { return }
            thief.thief.move(to: maze.treasureRoom)
        }
    }

    var timers: [TimedEvent] {
        // The gates' eight-turn passage, armed by the bolt rule above. Draining
        // lays the reservoir bare and reveals the trunk; filling submerges the
        // bed again and drowns anyone still standing on it. Both settle the
        // water — the Loud Room falls quiet — when they fire. Declared here
        // because they touch entities from two bundles (``dam`` and
        // ``roundRoom``) that neither can reach from its own timers.
        //
        // Both lines are things you watch happen to a body of water — mud laid
        // bare, a surface settling flat and grey — so both are said from the
        // four rooms that body of water can be seen from: the top of the dam
        // holding it, either shore, and the bed between them. The gates work
        // their eight-turn count regardless; a player who turned the bolt and
        // then climbed out to the lawn is simply not told, and finds a drained
        // reservoir when he comes back down. The Loud Room hears the same news
        // from its own description, which `waterMoving` rewrites.
        fuse("damDrain", after: 8) {
            dam.reservoirDrained = true
            dam.trunk.reveal()
            roundRoom.waterMoving = false
            say(
                Prose.reservoirEmpties,
                from: dam.damRoom, dam.reservoirSouth, dam.reservoir, dam.reservoirNorth)
        }
        fuse("damRefill", after: 8) {
            dam.reservoirDrained = false
            roundRoom.waterMoving = false
            if player.location == dam.reservoir {
                try die(Prose.reservoirRefillDrowns)
            }
            say(
                Prose.reservoirRefills,
                from: dam.damRoom, dam.reservoirSouth, dam.reservoir, dam.reservoirNorth)
        }

        // The struck match's short life: two turns after it's lit, the burning
        // match goes out and vanishes. Armed by the striking rule above; here
        // because the match is a ``ZorkTemple`` item lit from a ``ZorkDam`` one.
        fuse("matchBurns", after: 2) {
            // Asked while the flame is still on it and still in the world:
            // a match that has already vanished is nowhere the player can see.
            say(Prose.matchBurnsOut, from: temple.burningMatch)
            temple.burningMatch.isLit = false
            temple.burningMatch.vanish()
        }

        // He swings back at someone who has swung at him, and otherwise starts
        // one turn in three of his own accord — `F-FIRST?` (`1actions.zil:702`)
        // is `<PROB 33>`. The rest of the time he blocks, which is what his
        // listing line has always said he does.
        melee.aggression(
            of: cellar.troll, key: "troll", named: "melee.troll",
            strikesFirst: 33,
            prose: MeleeCombat.AggressionProse(
                miss: [Prose.trollSwipeMiss],
                wound: [Prose.trollSwipeWound],
                playerDeath: Prose.trollKillsYou),
            onRecovery: {
                if cellar.axe.isIn(cellar.trollRoom) {
                    cellar.axe.move(heldBy: cellar.troll)
                }
            })

        // The thief now prowls the whole underground, teleport-roaming every
        // room below (bar his own lair, which he's summoned to defend, and the
        // Land of the Dead), and will lift any treasure you carry. The roam and
        // steal daemons guard before they draw, so quiet turns — the actor out
        // of the set, or your hands empty of treasure — burn no randomness.
        actors.roams(
            thief.thief, named: "thiefRoams",
            rooms: undergroundRooms,
            chancePerTurn: 50,
            arrival: Prose.thiefArrives,
            departure: Prose.thiefLeaves)
        actors.steals(
            thief.thief, named: "thiefSteals",
            candidates: treasureRoster,
            chancePerTurn: 30,
            announcement: Prose.thiefSteals)

        // Alone in his lair he ferries his takings into the hoard: a draw-free
        // deposit of everything he carries (bar the stiletto he keeps to hand)
        // onto the Treasure Room floor. In company he keeps hold of the bag,
        // as `I-THIEF` does before its off-screen `DEPOSIT-BOOTY` call.
        daemon("thiefStash", autostart: true) {
            guard thief.thief.isIn(maze.treasureRoom), player.location != maze.treasureRoom else {
                return
            }
            depositThiefBooty(in: maze.treasureRoom)
        }

        // He fights back only in his lair — the `when:` gate closes everywhere
        // else, keeping him evasive on the prowl and burning no randomness on
        // the turns he isn't defending the hoard. Even there he waits to be
        // swung at four times in five: `F-FIRST?` (`1actions.zil:2064`) is
        // `<PROB 20>`.
        melee.aggression(
            of: thief.thief, key: "thief", named: "thiefFights",
            strikesFirst: 20,
            when: { thief.thief.isIn(maze.treasureRoom) },
            prose: MeleeCombat.AggressionProse(
                miss: [Prose.thiefSwipeMiss],
                wound: [Prose.thiefSwipeWound],
                playerDeath: Prose.thiefKillsYou))

        // The egg-opening service: four turns after you hand him the egg, the
        // thief works its mechanism open — the canary intact, where your own
        // forcing it with a weapon or tool would have wrecked it. Silent (you're not there to watch); you
        // find the opened egg among his effects when he falls. An earlier
        // stash or death deposits and opens the egg immediately instead.
        fuse("thiefOpensEgg", after: 4) {
            guard !thief.thiefDefeated else { return }
            aboveGround.egg.isOpen = true
        }
    }

    var map: WorldMap {
        // The one exit that crosses the ZorkAboveGround/ZorkHouse boundary:
        // the kitchen window. Starts closed — the "open window, enter west"
        // transcript exercises exactly this door.
        aboveGround.behindHouse.west(house.kitchen, via: house.window)
        house.kitchen.east(aboveGround.behindHouse, via: house.window)

        // Where ZorkHouse meets ZorkCellar: the crawlway south of the
        // cellar, the troll's passage north of it, and the chimney —
        // climbable only from below, so no matching `kitchen.down`
        // (FIDELITY.md).
        // The thief lives in ``ZorkThief`` but starts in the Gallery, a
        // ``ZorkCellar`` room, so the host places him — cross-bundle, like his
        // every other seam.
        thief.thief.starts(in: cellar.gallery)
        cellar.axe.starts(heldBy: cellar.troll)

        house.cellar.south(cellar.eastOfChasm)
        cellar.eastOfChasm.north(house.cellar)
        house.cellar.north(cellar.trollRoom)
        cellar.trollRoom.south(house.cellar)
        cellar.studio.up(house.kitchen)

        // Where ZorkCellar meets ZorkRoundRoom and ZorkMaze: the troll gates
        // both his passages, and each opens while he is down. East runs onto the
        // East-West Passage; west drops into the maze — one-way, canonical
        // (Maze-1 has no exit back to the Troll Room), so there's no matching
        // back-edge.
        cellar.trollRoom.exit(
            .east, to: roundRoom.eastWestPassage,
            when: { cellar.trollDefeated || cellar.troll.isUnconscious },
            otherwise: Prose.trollBlocksTheWay)
        roundRoom.eastWestPassage.west(cellar.trollRoom)
        cellar.trollRoom.exit(
            .west, to: maze.maze1,
            when: { cellar.trollDefeated || cellar.troll.isUnconscious },
            otherwise: Prose.trollBlocksTheWay)

        // Where ZorkRoundRoom meets ZorkDam: Deep Canyon opens east onto the
        // dam and northwest onto the reservoir's south shore, and the Chasm's
        // northeast edge joins the same shore. These are the exits the Round
        // Room region left absent for "their region"; the dam owns the shore
        // side of each, the host owns the crossing.
        roundRoom.deepCanyon.east(dam.damRoom)
        dam.damRoom.south(roundRoom.deepCanyon)
        roundRoom.deepCanyon.northwest(dam.reservoirSouth)
        dam.reservoirSouth.southeast(roundRoom.deepCanyon)
        roundRoom.chasmRoom.northeast(dam.reservoirSouth)
        dam.reservoirSouth.southwest(roundRoom.chasmRoom)

        // Where ZorkRoundRoom meets ZorkTemple: the Round Room's southeast
        // passage runs to the Engravings Cave, the mouth of the temple region.
        // (The Round Room left this exit absent "for its region"; the temple
        // owns the cave, the host owns the crossing.)
        roundRoom.roundRoom.southeast(temple.engravingsCave)
        temple.engravingsCave.west(roundRoom.roundRoom)

        // Where the map's halves finally knot together, through ``ZorkMirror``.
        // Each of these edges the mirror region left absent "for its neighbour",
        // and each crosses a bundle boundary, so the host owns the crossing.
        //
        // The Round Room hub's south passage runs to the Narrow Passage (the
        // exit ZorkRoundRoom left absent since Phase 10.4).
        roundRoom.roundRoom.south(mirror.narrowPassage)
        mirror.narrowPassage.north(roundRoom.roundRoom)

        // The drowned Atlantis Room opens south onto Reservoir North (the exit
        // ZorkDam left absent since Phase 10.5).
        mirror.atlantisRoom.south(dam.reservoirNorth)
        dam.reservoirNorth.north(mirror.atlantisRoom)

        // The Slide Room's steep chute drops one-way into the Cellar — no way
        // back up it, so there's no matching `cellar.up` (FIDELITY.md).
        mirror.slideRoom.down(house.cellar)

        // The Slide Room's north opening onto the Mine Entrance — the way into
        // the Coal Mine (the exit ZorkMirror left absent since Phase 10.7).
        mirror.slideRoom.north(coalMine.mineEntrance)
        coalMine.mineEntrance.south(mirror.slideRoom)

        // The Tiny Cave (``ZorkTemple``'s ``cave``) opens north to the northern
        // Mirror Room and west to the Winding Passage — the canonical onward
        // path that reconnects the temple complex to the rest of the map, and
        // that Phase 10.6 left absent behind a temporary altar climb (now
        // removed). See `FIDELITY.md`.
        temple.cave.north(mirror.mirrorRoomNorth)
        mirror.mirrorRoomNorth.east(temple.cave)
        temple.cave.west(mirror.windingPassage)
        mirror.windingPassage.east(temple.cave)

        // Where ``ZorkRiver`` meets the rest of the map. River-1 lands back onto
        // the dam's Dam Base (the boat launches from there — the launch rule
        // above owns the outbound leg). The White Cliffs squeeze west into the
        // Damp Cave (a ``ZorkRoundRoom`` room; on-foot only — ``ZorkRiver`` gates
        // the boat out). And the rainbow's far end opens onto the End of Rainbow
        // (a ``ZorkAboveGround`` room) at the foot of the canyon — walkable only
        // while the sceptre holds it solid.
        river.river1.west(dam.damBase)

        river.whiteCliffsNorth.west(roundRoom.dampCave)
        roundRoom.dampCave.east(river.whiteCliffsNorth)

        river.onRainbow.west(aboveGround.endOfRainbow)
        aboveGround.endOfRainbow.exit(
            .up, to: river.onRainbow,
            when: { river.rainbowSolid }, otherwise: Prose.rainbowNotSolid)
        aboveGround.endOfRainbow.exit(
            .east, to: river.onRainbow,
            when: { river.rainbowSolid }, otherwise: Prose.rainbowNotSolid)

        // The boat pile starts at Dam Base and the pot of gold at the End of
        // Rainbow — both rooms belong to other bundles, so the host places them.
        river.pileOfPlastic.starts(in: dam.damBase)
        river.potOfGold.starts(in: aboveGround.endOfRainbow)

        // Where ``ZorkMaze`` meets ``ZorkAboveGround``: the grating is a real
        // door between the maze's Grating Room and the forest Clearing. The
        // grating Item and the skeleton key that locks it are above-ground
        // entities; the key is finally placed here in the maze (Maze-5),
        // closing the Phase-5 ``.nowhere`` seam.
        aboveGround.clearingGrating.down(maze.gratingRoom, via: aboveGround.grating)
        maze.gratingRoom.up(aboveGround.clearingGrating, via: aboveGround.grating)
        aboveGround.skeletonKey.starts(in: maze.maze5)

        // Where ``ZorkMaze`` meets ``ZorkHouse``: the Strange Passage the fleeing
        // cyclops smashes open runs east to the Living Room. The Living Room's
        // west door stays nailed shut until he does (the original's MAGIC-FLAG).
        maze.strangePassage.east(house.livingRoom)
        house.livingRoom.exit(
            .west, to: maze.strangePassage,
            when: { maze.eastWallOpen }, otherwise: Prose.doorNailedShut)

        // The clockwork canary rides sealed inside the egg. The canary is a
        // ``ZorkHouse`` entity and the egg a ``ZorkAboveGround`` one, so the
        // host places one inside the other. The broken twin waits offstage
        // until a forced opening trades it in.
        house.canary.starts(inside: aboveGround.egg)

        // The endgame. The ancient map waits hidden inside the trophy case (a
        // ``ZorkHouse`` entity) until all nineteen treasures reveal it; once it
        // has, the way southwest from West of House opens onto the Stone Barrow.
        // Map, case, and barrow span two bundles, so the host owns the wiring.
        aboveGround.ancientMap.starts(inside: house.trophyCase)
        aboveGround.westOfHouse.southwest(
            aboveGround.stoneBarrow,
            when: { aboveGround.ancientMap.isRevealed },
            otherwise: Prose.barrowPathBlocked)

        player.starts(in: aboveGround.westOfHouse)
    }
}
