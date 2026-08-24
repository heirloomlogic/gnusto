import Gnusto
import GnustoActors
import GnustoDangerousDark
import GnustoMeleeCombat
import GnustoScoring

/// *Dungeon* — a reconstruction of the original MIT mainframe Zork, the
/// 196-room game Infocom later cut into the Zork I/II/III trilogy.
///
/// The charter, the mechanics contract and the prose rule live in
/// `docs/games/dungeon.md`; the room and object data in
/// `docs/games/dungeon-atlas.md`; the per-line prose decisions in
/// `docs/games/dungeon-prose-comparison.md`. Read the first before changing
/// anything here.
///
/// **Built one milestone at a time.** Milestone 1 is above ground, the white
/// house and the cellar; milestone 2 is the underground crossroads and Flood
/// Control Dam #3. Each later milestone adds region bundles to ``content`` and
/// their crossings to ``rules`` and ``map``, and raises ``maxScore`` by exactly
/// what it makes payable — see the note on that property. Nothing here has to
/// move for a region to land.
@main
struct Dungeon: Game, GameMain {
    let title = "Dungeon"
    let tagline = "The Great Underground Empire, as it stood on a PDP-10."

    /// The ceiling **for the milestones built so far**. It ratchets, and lands
    /// on the mainframe's 716 at the last one.
    ///
    /// Milestone 1's 66 is the Kitchen (10) and Cellar (25) room values plus
    /// four treasures found and cased: the egg (5+5), the canary (6+2), the
    /// painting (4+7), the bauble (1+1). Ten of those are declared before their
    /// route exists, so a perfect milestone-1 playthrough scores **56**.
    ///
    /// Milestone 2 adds 50, all of it walkable: the East-West Passage's room
    /// value (5), the platinum bar (12+10) and the trunk of jewels (15+8). A
    /// perfect playthrough of the two together scores **106**.
    ///
    /// Milestone 3 adds 149, all of it walkable too: the Land of the Living
    /// Dead's room value (30), the `LIGHT-SHAFT` award (10), and eight
    /// treasures — the ivory torch (14+6), the gold coffin (3+7), the grail
    /// (2+5), the ruby (15+8), the crystal trident (4+11), the jade figurine
    /// (5+5), the sapphire bracelet (5+3) and the huge diamond (10+6). A
    /// perfect playthrough of the three together scores **255**; the ten still
    /// missing are milestone 1's canary and bauble, which wait on the thief.
    ///
    /// Milestone 4 adds 128, and all of it is walkable: the Treasure Room's
    /// room value (25), the Strange Passage's (10), and five treasures — the
    /// large emerald (5+10), the statue (10+13), the pot of gold (10+10), the
    /// bag of coins (10+5) and the silver chalice (10+10). A perfect
    /// playthrough of the four together scores **383**; the ten still missing
    /// are still milestone 1's canary and bauble.
    ///
    /// Milestone 5 adds 106, and all of it is walkable: the Top of Well's room
    /// value (10) and six treasures — the stack of zorkmid bills (10+15), the
    /// portrait (10+5), the pearl necklace (9+5), the white crystal sphere
    /// (6+6), the tin of spices (5+5) and the Stradivarius (10+10). The violin
    /// is the one milestone 2 declared nothing for and named the reason: the
    /// steel box holding it is invisible until the triangular button stops the
    /// carousel, and that button is this milestone's. A perfect playthrough of
    /// the five together scores **489**; the ten still missing are, still,
    /// milestone 1's canary and bauble.
    ///
    /// Milestone 6 adds 61, and all of it is walkable: three treasures — the
    /// priceless zorkmid (10+12) on the Narrow Ledge, Lord Dimwit's crown
    /// (15+10) in the box the brick opens, and the Flathead stamp (4+10)
    /// pressed inside the Library's purple book. Not one room in the volcano
    /// carries an `RVAL`, so the whole of it is object values. A perfect
    /// playthrough of the six together scores **550**; the ten still missing
    /// are, still, milestone 1's canary and bauble.
    ///
    /// Milestone 7 adds 25, and all of it is walkable: the gold card (10+15)
    /// under a sandstone block in the Royal Puzzle. One treasure and no room
    /// value — `CP`, `CPANT` and `CPOUT` carry no `RVAL` between them, so the
    /// whole region is worth exactly the one object. It is also the object that
    /// moved the finished ceiling from 691 to 716 (#167): `dung.355:6324`
    /// declares it inside a `<PUT <OBJECT …> ,OROOM <GET-ROOM "CP">>` wrapper
    /// rather than at top level, and a reader scanning only top-level forms
    /// misses it. The thief landed between milestone 6 and this one and closed
    /// the last gap — milestone 1's canary and bauble, which every milestone
    /// since has had to describe as still waiting — so a perfect playthrough of
    /// everything built now scores **585 of 585**, and for the second milestone
    /// running nothing is declared ahead of its route.
    ///
    /// Milestone 8's first two pieces add 31, and all of it is walkable: the
    /// blue crystal sphere (10+5) on the table in the Dreary Room, the red one
    /// (10+5) in the Sooty Room at the foot of the coal chute, and the Don
    /// Woods stamp (0+1) affixed to the free brochure. Not one of the seven new
    /// rooms carries an `RVAL`, so the whole of it is object values and the
    /// award table does not move. A perfect playthrough now scores **616 of
    /// 616** — and 616 is `SCORE-MAX`, the whole of the main dungeon. What
    /// stands between here and the finished 716 is the endgame's hundred and
    /// nothing else.
    ///
    /// That is not a coincidence and it is not merely tidy. `SCORE-BLESS`
    /// (`rooms.394:794`) arms the endgame's herald only at `SCORE-MAX`, and the
    /// herald is what makes the Crypt's marble door open at all. A
    /// reconstruction stalled at 585 could never enter the endgame, however
    /// completely the endgame was built.
    ///
    /// Milestone 9 adds the last 100, and every point of it is a room value:
    /// the Crypt (5), the Top of Stairs (10), the Inside Mirror (15), the
    /// Dungeon Entrance (15), the Narrow Corridor (20) and the Treasury of Zork
    /// (35). Not one endgame object carries an `OFVAL` or an `OTVAL`, so the
    /// treasure roster does not move at all — the whole hundred goes into the
    /// `Scoring` award table. `716` is `SCORE-MAX` plus `EG-SCORE-MAX`, the two
    /// maxima the mainframe reports separately and this game reports as one:
    /// `docs/games/dungeon-atlas.md`, "What `Sources/Dungeon/` uses".
    ///
    /// Why the ceiling moves at all, and what may be declared ahead of its
    /// route: `docs/games/dungeon.md`, "The ceiling ratchets while the game is
    /// being built", and the matching `FIDELITY.md` entry.
    let maxScore = 716

    let intro = Prose.intro

    /// The stock engine lines re-voiced where Zork's own differ from Gnusto's
    /// classic register. Every line not set here already matches.
    var text: GameText {
        var text = GameText()
        text.pitchBlack = .init(Prose.grueWarning)
        text.nothingSpecial = .naming { "There's nothing special about \($0)." }
        text.alreadyOpen = "It is already open."
        text.alreadyClosed = "It is already closed."
        // The same pair one verb over. The mainframe has no counterpart to
        // borrow — `V-LOCK` (`gverbs.zil:855`) answers "It doesn't seem to
        // work." and `V-UNLOCK` calls it — so these are Dungeon's own prose,
        // written to the shape of the two lines above. (#260)
        text.alreadyUnlocked = "It is already unlocked."
        text.alreadyLocked = "It is already locked."
        // A wrong key, which the oak door and the grating both refuse by
        // reading this rather than each writing a line of its own. It names
        // neither direction, because the slot answers `lock` as well as
        // `unlock`. (#263)
        text.wrongKey = "That will not turn the lock."
        // Its two confirmations. Both of the game's locks say something of
        // their own instead — these are the register the *next* lockable
        // inherits, and the reason they stay subject-free is that the family
        // they belong to is `opened`/`closed`: a lock with a sentence about
        // itself has a rule to say it from.
        text.lockedMessage = "It is now locked."
        text.unlockedMessage = "It is now unlocked."
        text.alreadyHave = "You already have that!"
        text.didntUnderstand = "That sentence isn't one I recognize."
        text.nothingToTakeHere = "There's nothing here you can take."
        // The basket carrying the only light down the shaft darkens a room the
        // way turning a lamp off does, so the two say the same sentence.
        text.nowDark = .init(Prose.itIsNowPitchBlack)
        // `enter`/`go through` on a thing that is neither doorway nor vehicle.
        // The Bank's walls and the curtain answer for themselves at stage 2.
        text.cantEnterThat = .naming(Prose.cantEnterThat)

        // The six stock lines that take a person as their subject. The engine's
        // doc comment says a game re-skinning one usually wants the family, and
        // this game had none of them: #236 gave all four actors their own
        // greetings as rules, and every verb that falls *past* a rule still
        // reached a modern narrator. `V-COMMAND` (`gverbs.zil:359`) is the
        // source for the order refusal. (#233)
        text.cantTakeActor = .naming { "\($0.sentenceCased) \($0.verb("has", "have")) other plans." }
        text.cantSearchActor = .naming { "\($0.sentenceCased) would not stand for it." }
        text.notTakingOrders = .naming { "\($0.sentenceCased) \($0.verb("pays", "pay")) no attention." }
        text.doesNotKnowHow = .naming {
            "\($0.sentenceCased) \($0.verb("has", "have")) no idea how to do that."
        }
        text.greets = .naming { "\($0.sentenceCased) \($0.verb("says", "say")) nothing in reply." }

        // The stub floor — every verb the parser knows and no mechanic answers.
        text.stubs = Prose.stubFloor
        return text
    }

    let aboveGround = DungeonAboveGround()
    let house = DungeonHouse()
    let cellar = DungeonCellar()
    let crossroads = DungeonRoundRoom()
    let dam = DungeonDam()
    let templeQuarter = DungeonTemple()
    let mirrors = DungeonMirror()
    let mine = DungeonCoalMine()
    let river = DungeonRiver()
    let maze = DungeonMaze()
    let riddle = DungeonRiddle()
    let alice = DungeonAlice()
    let bank = DungeonBank()
    let volcano = DungeonVolcano()
    let thief = DungeonThief()
    let royalPuzzle = DungeonRoyalPuzzle()
    let palantirWing = DungeonPalantir()
    let endgame = DungeonEndgame()

    /// The grue: this game's prose, the plugin's stock warn-then-kill schedule.
    let dangerousDark = DangerousDark(
        warning: Prose.grueWarning,
        death: Prose.grueDeath
    )

    /// The award-once registers this milestone can pay: the mainframe's room
    /// values (`RVAL`) for getting into the house and for getting below it.
    /// Treasure values are declared on the items instead, as
    /// `.takeValue`/`.depositValue`, and summed from the world.
    ///
    /// `LIGHT-SHAFT` lands here with the coal mine. It is an event award and
    /// not a room value, because a room value would pay out to anybody who
    /// stumbled into the Lower Shaft in the dark, which is the opposite of the
    /// puzzle: `docs/games/dungeon.md`, "The ceiling ratchets".
    let scoring = Scoring(
        awards: [
            "kitchen": 10,
            "cellar": 25,
            "eastWestPassage": 5,
            "landOfTheLivingDead": 30,
            "lightShaft": 10,
            "treasureRoom": 25,
            "strangePassage": 10,
            "topOfWell": 10,
            // The endgame's hundred, which is `EG-SCORE-MAX` entire: every
            // point of it is a room value and no endgame object carries one.
            "crypt": 5,
            "topOfStairs": 10,
            "insideMirror": 15,
            "dungeonEntrance": 15,
            "narrowCorridor": 20,
            "treasuryOfZork": 35,
        ])

    /// The melee plugin claims `.attack` outright, so its four system-voice
    /// lines — not ``Prose/stubFloor``'s `attack` — are what a player who
    /// swings at the scenery actually reads. They were the plugin's stock
    /// modern ones, which is box 12's complaint at the one verb the box did not
    /// think to look at. All four are `V-ATTACK` (`gverbs.zil:176`), turned into
    /// the second person this game narrates in. (#233)
    let melee = MeleeCombat(text: Prose.combatText)

    /// Roaming and theft, for the one actor who does both. Logic only — the
    /// plugin owns no entities, so it is a stored property and not `content`.
    let actors = ActorBehaviors()

    /// The custom verb vocabulary and its stage-4 defaults.
    let systems = DungeonSystems()

    /// The weight system: the mainframe's `OSIZE` values against a cap of 100.
    let burden = DungeonBurden()

    /// How many times the player has died.
    @Global var deaths = 0

    /// Whether the Lower Shaft has paid its ten points yet. `awardOnce` is
    /// idempotent, but it reads its claimed-register set through a JSON box,
    /// and the rule that calls it runs every turn the player stands down
    /// there — so a plain `Bool` guards it.
    @Global var lightShaftPaid = false

    /// The same guard for the Top of Well's ten, for the same reason. Two
    /// `Bool`s rather than one `Set<String>`: a set would need a `GlobalValue`
    /// wrapper, and a wrapper is the JSON box these two exist to avoid.
    @Global var topOfWellPaid = false

    var content: GameContents {
        aboveGround
        house
        cellar
        crossroads
        dam
        templeQuarter
        mirrors
        mine
        river
        maze
        riddle
        alice
        bank
        volcano
        thief
        royalPuzzle
        palantirWing
        endgame
        dangerousDark
        scoring
        melee
        systems
        burden
    }

    /// `diagnose` reports the death toll and how many resurrections are left.
    /// The verb is taught by ``DungeonSystems``; the report lives here because
    /// it reads the host's ``deaths`` counter.
    var actions: [IntentAction] {
        action(.diagnose) {
            guard deaths > 0 else { try reply(Prose.diagnoseUnscathed) }
            try reply(Prose.diagnoseDeaths(deaths, resurrectionsLeft: max(0, 2 - deaths)))
        }
    }

    /// The mainframe's resurrection: the first two deaths cost ten points and
    /// everything in your hands, and put you back among the trees. The third
    /// is final and falls through to the engine's banner.
    func onDeath() -> DeathOutcome {
        // Death in the endgame is final, whatever the death count. There is
        // nowhere above ground to be put back to and nothing left to forfeit.
        guard !endgame.pastTheCrypt else { return .fallThrough }
        deaths += 1
        guard deaths < 3 else { return .fallThrough }
        scoring.penalize(10)

        // Belongings strew across the grounds above, one draw per item. The
        // lamp is the kept exception — it always turns up in the living room,
        // so light is never lost to a death.
        let scatter = [
            aboveGround.westOfHouse, aboveGround.northOfHouse,
            aboveGround.southOfHouse, aboveGround.behindHouse,
            aboveGround.forestTree, aboveGround.clearing,
        ]
        for item in player.inventory {
            if item == house.lantern {
                item.move(to: house.livingRoom)
            } else {
                item.move(to: scatter[random(0...(scatter.count - 1))])
            }
        }

        player.location = aboveGround.forestDeep
        say(Prose.resurrection)
        describeSurroundings()
        return .consumed
    }

    /// The treasures this milestone can score, shared by the trophy-case
    /// wiring below. Later milestones append their own.
    ///
    /// Internal rather than private because the thief covets exactly what the
    /// trophy case scores, and one list in one place is what stops the two from
    /// drifting apart. ``Dungeon/thiefTimers`` is the other reader.
    var treasureRoster: [Item] {
        [
            aboveGround.egg, house.canary, house.bauble, cellar.painting,
            crossroads.platinumBar, dam.trunk,
            templeQuarter.ivoryTorch, templeQuarter.coffin, templeQuarter.grail,
            templeQuarter.ruby, mirrors.crystalTrident,
            mine.jade, mine.sapphireBracelet, mine.diamond,
            river.emerald, river.statue, river.potOfGold,
            maze.bagOfCoins, maze.chalice,
            riddle.pearlNecklace,
            alice.sphere, alice.spices,
            crossroads.violin,
            bank.bills, bank.portrait,
            volcano.zorkmid, volcano.crown, volcano.stamp,
            royalPuzzle.goldCard,
            palantirWing.blueSphere, palantirWing.redSphere,
            aboveGround.donWoodsStamp,
        ]
    }

    /// Every passage out of the Round Room this game has built, and where each
    /// of them goes once the machinery under the floor has been stopped.
    ///
    /// The source has nine, and as of milestone 4 all nine are built. They
    /// reach five different bundles — which is why the carousel lives here
    /// rather than in ``DungeonRoundRoom``: the map loops over this list, the
    /// draw rolls against its length, and the `before(.go)` rule guards on it.
    private var carouselExits: [(Direction, Location)] {
        [
            (.west, crossroads.eastWestPassage),
            (.northwest, crossroads.deepCanyon),
            (.northeast, crossroads.nsPassage),
            (.north, templeQuarter.engravingsCave),
            (.south, templeQuarter.engravingsCave),
            (.east, templeQuarter.grailRoom),
            (.southeast, mirrors.windingPassage),
            (.out, mirrors.coldPassage),
            (.southwest, maze.maze1),
        ]
    }

    /// Every mooring in the game: ``DungeonRiver``'s five, plus the Dam Base,
    /// which is a ``DungeonDam`` room and so the one the river cannot name.
    /// `launch` is the forward lookup and `land` the inverse.
    private var moorings: [(shore: Location, water: Location)] {
        river.moorings + [(dam.damBase, river.river1)]
    }

    var rules: Rules {
        coreRules
        boatRules
        gratingRules
        cyclopsRules
        mazeFindRules
        graniteRules
        bucketRules
        buttonRules
        whirringRules
        balloonRules
        blastRules
        thiefRules
        palantirRules
        endgameRules
    }

    /// Milestones 1 to 3, and everything that belongs to no one milestone.
    @RuleBuilder private var coreRules: Rules {
        scoring.treasures(treasureRoster, into: house.trophyCase)

        // `V-KNOCK` (`gverbs.zil:766`) branches on `DOORBIT`: one answer at a
        // door, another at anything else. The stub floor carries the second
        // branch, because it is the one a line can word; this carries the
        // first, because being a door is a fact about the map and no stub line
        // can see it. Game-wide rather than one rule per door — this game has
        // fifteen of them and grows one per milestone, and the source asks the
        // flag, not the object.
        //
        // The endgame's wooden door is the one door that answers for itself, and
        // `before` rules run outside-in, so this one would speak over it. Naming
        // it here is the honest spelling: the exception belongs to the game that
        // owns both halves, not to a guard in the engine. See
        // ``DungeonEndgame/quizRules``.
        world.before(.knock) {
            guard let object = command.directObject,
                object.isDoor,
                object != endgame.woodenDoor
            else { return }
            try reply(Prose.verbKnockDoor)
        }

        // Behind House ends its paragraph on the state of the kitchen window,
        // as `EAST-HOUSE` does in both sources. The room is
        // ``DungeonAboveGround``'s and the window is ``DungeonHouse``'s, so the
        // sentence that reads both is the host's. The Kitchen's twin of this
        // rule stays in ``DungeonHouse``, where both halves are local. (#233)
        aboveGround.behindHouse.describe {
            Prose.behindHouse(windowOpen: house.window.isOpen)
        }

        // And `enter house` answers for the same pair. The window is a `via:`
        // door, so `enter window` walks; the house is neither doorway nor
        // vehicle, so `enter house` fell to `cantEnterThat` and answered "You
        // hit your head against the white house" — `V-THROUGH`'s generic line,
        // given to a player standing in front of a paragraph that had just
        // pointed at the window.
        //
        // `WHITE-HOUSE-F` answers `THROUGH` itself and this is its branch: from
        // the room behind the house, an open window walks you into the Kitchen
        // and a shut one says so; from any other side, there is no way in and
        // the house says that rather than butting your head. The rule lives
        // here because the house is ``DungeonAboveGround``'s and the window is
        // ``DungeonHouse``'s.
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

        // The mainframe's room values, as event awards: getting into the
        // kitchen, and getting below the house.
        scoring.visit(house.kitchen, register: "kitchen")
        scoring.visit(house.cellar, register: "cellar")
        scoring.visit(crossroads.eastWestPassage, register: "eastWestPassage")
        scoring.visit(templeQuarter.landOfTheLivingDead, register: "landOfTheLivingDead")
        scoring.visit(maze.treasureRoom, register: "treasureRoom")
        scoring.visit(maze.strangePassage, register: "strangePassage")

        // The carousel. One draw per attempt, taken at stage 3 so the exit
        // lookup that follows reads a settled answer — the mainframe's
        // `CAROUSEL-OUT`. Guarded to `carouselExits`, so a direction the
        // carousel does not serve is refused with the plain "You can't go that
        // way" rather than being told the room turned under it and then refused
        // anyway. All nine of the source's passages have been built since
        // milestone 4 closed the southwest one into the maze.
        crossroads.roundRoom.before(.go) {
            guard crossroads.carouselSpinning, let heading = command.direction else { return }
            let exits = carouselExits
            guard exits.contains(where: { $0.0 == heading }) else { return }
            crossroads.carouselTwist = random(0...(exits.count - 1))
            say(Prose.roundRoomNoBearings)
        }

        // The Top of Well's ten points, paid the same way `LIGHT-SHAFT` is
        // rather than by `scoring.visit`. A room value is an `onEnter` award,
        // and the usual way into this room is riding the bucket up — which
        // moves the *vehicle* and carries the player along, so no `onEnter`
        // fires. That is the hole the Bank of Zork spike recorded (#132) and
        // this is the first room in the game to fall into it.
        alice.topOfWell.afterEachTurn {
            guard !topOfWellPaid else { return }
            topOfWellPaid = true
            scoring.awardOnce("topOfWell")
        }

        // `LIGHT-SHAFT`: ten points, once, for standing at the bottom of the
        // shaft with light. The source pays it from `NO-OBJS`, which runs on
        // every action taken in the room rather than on arrival — because the
        // usual way to earn it is to arrive in the dark and then raise the
        // basket you sent down ahead of you with the torch in it.
        mine.lowerShaft.afterEachTurn {
            guard !lightShaftPaid, player.location.isLit else { return }
            lightShaftPaid = true
            scoring.awardOnce("lightShaft")
        }

        // The rope over the dome's railing. The rope is a ``DungeonHouse``
        // item and the railing a ``DungeonTemple`` fixture, so the host owns
        // the knot.
        house.rope.before(.tie) {
            guard command.directObject == house.rope else { return }
            // Milestone 8 gives the rope a second knot: the head of the coal
            // chute, where it is tied to the broken timber or the gold coffin
            // rather than to a railing. `Dungeon+Palantir.swift` answers that
            // one, and this rule stands aside for it — the two run in
            // declaration order and `coreRules` is first.
            guard player.location != mirrors.slideRoom else { return }
            try require(
                player.location == templeQuarter.domeRoom
                    && (command.indirectObject == nil
                        || command.indirectObject == templeQuarter.railing),
                else: Prose.ropeNeedsRailing)
            try require(!templeQuarter.ropeTiedToRailing, else: Prose.ropeCarriesNothing)
            // One rope, one knot: milestone 8 gave it a second place to be
            // tied, and it may not be tied in both at once.
            try require(!palantirWing.chuteRopeRigged, else: Prose.ropeAlreadyTied)
            templeQuarter.ropeTiedToRailing = true
            try reply(Prose.ropeTiedToRailing)
        }
        house.rope.before(.untie) {
            guard templeQuarter.ropeTiedToRailing else { return }
            templeQuarter.ropeTiedToRailing = false
            try reply(Prose.ropeUntiedFromRailing)
        }
        house.rope.before(.take) {
            guard templeQuarter.ropeTiedToRailing else { return }
            templeQuarter.ropeTiedToRailing = false
            say(Prose.ropeUntiedFromRailing)
        }
        templeQuarter.railing.before(.tie) {
            try require(
                command.indirectObject == house.rope || command.directObject == house.rope,
                else: Prose.ropeCarriesNothing)
        }

        // Praying at the altar. The mainframe answers a prayer said in the
        // Altar and nowhere else, and the answer is the forest above ground —
        // a ``DungeonAboveGround`` room, so the host owns it. It is also the
        // one way the gold coffin leaves the dungeon without a climb. Anywhere
        // else the stub's own line stands; ``DungeonSystems`` owns that.
        templeQuarter.altar.before(.pray) {
            player.location = aboveGround.forestDeep
            say(Prose.prayerAnswered)
            describeSurroundings()
            try handled()
        }

        mainframeRules
    }

    /// The second half of the same list, and the canonical note on why this
    /// game is full of sub-builders.
    ///
    /// From M5 to M9 the whole test suite died with an unattributed `signal 10`
    /// whenever Dungeon grew, and the diagnosis of the day was that peak
    /// bootstrap stack depth tracked the largest single declaration body. It did
    /// not: M8 halved ten bodies and still died, and what settled it was deleting
    /// four scenery objects. The budget was over the whole declaration surface,
    /// and splitting worked by lowering the peak rather than raising the roof.
    ///
    /// **Issue #174 is fixed** — `Bootstrap.build` runs on a 16 MB thread the
    /// engine sizes, against a measured Dungeon peak of 355 KB — so none of these
    /// splits is required any more. They stay because a hundred-line rule list
    /// reads worse than two fifty-line ones, which was always the better reason.
    @RuleBuilder private var mainframeRules: Rules {
        // Lighting the candles. They need a live flame named, and the two the
        // game has are a struck match — which lights them — and the ivory
        // torch, which does not: it vaporises them.
        templeQuarter.candles.before(.burn, .turnOn) {
            guard command.directObject == templeQuarter.candles else { return }
            try require(!templeQuarter.candlesBurnedOut, else: Prose.candlesSpent)
            let flame = command.indirectObject
            if flame == templeQuarter.ivoryTorch, !templeQuarter.torchBurnedOut {
                try require(
                    !templeQuarter.candles.isLit, else: Prose.candlesAlreadyLitNearTorch)
                templeQuarter.candles.vanish()
                try reply(Prose.candlesVaporised)
            }
            guard !templeQuarter.candles.isLit else { try reply(Prose.candlesAlreadyLit) }
            let match = dam.matchbook
            try require(
                flame == nil ? match.isLit : flame == match && match.isLit,
                else: Prose.candlesNeedFlame)
            templeQuarter.lightCandles()
            try reply(Prose.candlesLit)
        }

        // The glacier. Throwing the burning torch at it brings the ice down and
        // the flood carries the torch away to Stream View — a ``DungeonDam``
        // room, which is why this one rule is not in the temple bundle with the
        // rest of the glacier.
        templeQuarter.glacier.before(.throwAt) {
            guard command.directObject == templeQuarter.ivoryTorch else { return }
            try require(!templeQuarter.torchBurnedOut, else: Prose.glacierUnmoved)
            templeQuarter.glacierMelted = true
            templeQuarter.torchBurnedOut = true
            templeQuarter.ivoryTorch.isLit = false
            templeQuarter.ivoryTorch.move(to: dam.streamView)
            try reply(Prose.glacierMeltsAwayTheTorch)
        }

        undergroundRules
    }

    /// And the third slice of the same list, for the reason
    /// ``Dungeon/mainframeRules`` states.
    @RuleBuilder private var undergroundRules: Rules {
        // The bat. It reads the garlic, which is a ``DungeonHouse`` item, and
        // drops you anywhere in the coal maze — the source's `BAT-DROPS`, all
        // seven mine rooms and both ends of the ladder.
        mine.batRoom.onEnter {
            guard !player.inventory.contains(house.garlic) else {
                mine.bat.reveal()
                return
            }
            // No `describeSurroundings()` here: `onEnter` runs *before* the
            // arrival description, so moving the player is enough — the engine
            // then describes wherever the bat put them, in full, once.
            let drops = mine.batDrops
            say(Prose.batGrabsYou)
            player.location = drops[random(0...(drops.count - 1))]
        }

        // The machine's switch, thrown with the screwdriver — a ``DungeonDam``
        // item. Coal shut in the machine becomes a diamond; anything else
        // becomes slag, and an open lid does nothing at all.
        mine.machineSwitch.before(.turnWith) {
            try require(command.indirectObject == dam.screwdriver, else: Prose.switchWrongTool)
            try require(!mine.machine.isOpen, else: Prose.machineDoesNothing)
            let load = mine.machine.contents
            guard !load.isEmpty else { try reply(Prose.machineRuns) }
            for item in load { item.vanish() }
            if load.contains(mine.coal) {
                mine.diamond.move(inside: mine.machine)
            } else {
                mine.slag.move(inside: mine.machine)
            }
            try reply(Prose.machineRuns)
        }

        // The chimney. The mainframe lets you up it with the lamp and at most
        // one other thing, and refuses the climb empty-handed outright. The
        // Studio is a ``DungeonCellar`` room and the lamp a ``DungeonHouse``
        // item, so the host owns the gate.
        cellar.studio.before(.go) {
            guard command.direction == .up else { return }
            let hands = player.inventory
            try require(!hands.isEmpty, else: Prose.chimneyEmptyHanded)
            // At most two things, and one of them the lamp — climbing into the
            // dark without it is the softlock the mainframe declines to allow.
            // This gate **counts** rather than weighing, deliberately: it is
            // the one load rule in the game that ignores `burdenWeight(of:)`,
            // because the mainframe's is a count (`FIDELITY.md`).
            try require(
                hands.count <= 2 && hands.contains(house.lantern),
                else: Prose.chimneyTooBurdened)
        }

        // The troll, fought with the house's blades. Strength 2 is the
        // mainframe's `OSTRENGTH`.
        melee.villain(
            cellar.troll, key: "troll", strength: 2,
            weapons: [house.sword, house.knife],
            prose: MeleeCombat.VillainProse(
                miss: [Prose.trollMiss1, Prose.trollMiss2],
                wound: [Prose.trollWound1, Prose.trollWound2],
                knockout: Prose.trollKnockout,
                death: Prose.trollDeath),
            onDefeat: {
                cellar.trollDefeated = true
                cellar.axe.move(to: cellar.trollRoom)
            })

        // Forcing the egg open by hand. The mechanism is too fine for brute
        // fingers, and what your thumbs cost you is both objects, not one: the
        // mainframe swaps `EGG` and `GCANA` out of the game together and hands
        // you `BEGG` with `BCANA` already inside it, neither of which is worth
        // a point. `docs/games/dungeon.md` totals the forfeit; the thief is the
        // only one who opens the egg without charging it.
        //
        // Both clauses of the guard are the thief's doing and neither is
        // redundant. He opens the egg with the bird still whole, so `isOpen`
        // stops a second `open` wrecking what he saved; and once you have
        // lifted the canary out, `holds` stops a *closed* egg being forced
        // onto a bird that is no longer in it.
        aboveGround.egg.before(.open) {
            guard !aboveGround.egg.isOpen, aboveGround.egg.holds(house.canary) else { return }
            // The bird needs its own `vanish()`: `replace` swaps the shell for
            // the ruined one without carrying contents across, so nothing else
            // takes the canary out of play.
            house.canary.vanish()
            aboveGround.egg.replace(with: aboveGround.brokenEgg)
            say(Prose.eggForcedRuinsCanary)
            // The built-in open is not reached: the egg it would have opened
            // has left the game, so the reveal is this rule's to print.
            try reply(Prose.eggForcedRevealsRuin)
        }

        // Wind the intact canary among the trees and a songbird answers,
        // dropping a brass bauble — once, ever. Wound up the tree, the bauble
        // falls to the forest floor below. Canary and forest live in different
        // bundles, so the host owns the trick; the set of rooms the bird
        // answers in is ``DungeonAboveGround/theWood``, which the region's own
        // ambience daemon shares.
        house.canary.before(.wind) {
            let here = player.location
            guard !house.baubleDropped, aboveGround.theWood.contains(here) else {
                try reply(Prose.canaryChirps)
            }
            house.bauble.move(to: here == aboveGround.upATree ? aboveGround.forestTree : here)
            house.baubleDropped = true
            try reply(Prose.songbirdDropsBauble)
        }
        // The ruined bird's answer is `DungeonHouse`'s own — it names nothing
        // outside that bundle, so it lives there.
    }

    /// Milestone 4 — the boat
    @RuleBuilder private var boatRules: Rules {
        // Inflating the pile of plastic. The pump is a ``DungeonDam`` item and
        // the pile a ``DungeonRiver`` one, so the host owns the valve. The
        // mainframe grades the refusal by what you offer it.
        river.pileOfPlastic.before(.inflate) {
            let here = player.location
            try require(here.contains(river.pileOfPlastic), else: Prose.inflateNotOnGround)
            guard let tool = command.indirectObject else {
                try reply(Prose.inflateNeedsPump)
            }
            try require(tool == dam.handPump, else: Prose.inflateWithWrongThing(tool.indefiniteName))
            river.pileOfPlastic.replace(with: river.magicBoat)
            try reply(Prose.boatInflates)
        }

        // Patching the wreck. The gunk in the tube is the only thing that
        // closes a hole in plastic, and `plug` is milestone 2's verb.
        river.puncturedBoat.before(.plug) {
            try require(command.indirectObject == dam.putty, else: Prose.boatNeedsPutty)
            dam.putty.vanish()
            river.puncturedBoat.replace(with: river.pileOfPlastic)
            try reply(Prose.boatPatched)
        }

        // Launching. Six shores can do it and one of them is the Dam Base, so
        // the table is the host's. Moving the boat rather than the player is
        // what carries the hull's cargo along — the same move `land` makes.
        world.before(.launch) {
            // `LAUNC` is a pseudo-direction out of either volcano ledge as well
            // as a word for the boat, so the vehicle decides which table gets
            // read. Milestone 6.
            if player.vehicle == volcano.balloon { try volcano.launchBalloon() }
            try require(player.vehicle == river.magicBoat, else: Prose.launchNotAboard)
            let here = player.location
            try require(here != river.endOfRainbow, else: Prose.launchRocksTooSharp)
            guard let water = moorings.first(where: { $0.shore == here })?.water else {
                try reply(Prose.launchNoWater)
            }
            river.magicBoat.move(to: water)
            say(Prose.boatLaunches)
            describeSurroundings()
            try handled()
        }

        // Landing: the same table read the other way. A stretch with one
        // mooring puts you on it, a stretch with two makes you say which, and
        // River-2 — rocks one side and the White Cliffs the other — has none.
        world.before(.land) {
            if player.vehicle == volcano.balloon { try volcano.landBalloon() }
            try require(player.vehicle == river.magicBoat, else: Prose.landNoBoat)
            let here = player.location
            let banks = moorings.filter { $0.water == here }.map(\.shore)
            guard banks.count == 1, let bank = banks.first else {
                try reply(banks.isEmpty ? Prose.landNowhereHere : Prose.landWhichWay)
            }
            river.magicBoat.move(to: bank)
            describeSurroundings()
            try handled()
        }
    }

    /// Milestone 4 — the grating
    @RuleBuilder private var gratingRules: Rules {
        // What the Grating Room says about the sky over it. The grating is a
        // ``DungeonAboveGround`` item and the room a ``DungeonMaze`` one, so
        // the description is the host's.
        maze.gratingRoom.describe {
            let overhead =
                if aboveGround.grating.isOpen {
                    Prose.gratingAboveOpen
                } else if aboveGround.grating.isLocked {
                    Prose.gratingAboveLocked
                } else {
                    Prose.gratingAboveUnlocked
                }
            return "\(Prose.gratingRoom)\n\n\(overhead)"
        }

        // The grating is perceivable from below the moment you stand under it,
        // whichever side revealed it.
        maze.gratingRoom.onEnter { aboveGround.grating.reveal() }

        // The grating reads differently from the two sides of it, because from
        // one of them you are the thing underneath.
        aboveGround.grating.describe {
            player.location == maze.gratingRoom ? Prose.gratingFromBelow : Prose.grating
        }

        // Both turns of the lock, which `GRATE-FUNCTION` answers itself for the
        // same reason this does: the lock is on the underside, so which side
        // the player is standing on decides the answer, and the two directions
        // refuse from above in different words. Everything the engine's own
        // handler would have said is read back out of the game's register
        // rather than written again here, so a key that does not fit this lock
        // and one that does not fit the oak door get the same sentence. (#263)
        aboveGround.grating.before(.unlock) {
            try turnTheGratingsLock(to: false, wrongSide: Prose.gratingLockNotReachable)
        }
        aboveGround.grating.before(.lock) {
            try turnTheGratingsLock(to: true, wrongSide: Prose.gratingCannotLockFromAbove)
        }

        // Opening it lights the room below — the source's own light bit,
        // written at runtime — and says which side of it you are standing on,
        // which is why this replaces the default rather than embellishing it.
        aboveGround.grating.before(.open) {
            try require(!aboveGround.grating.isLocked, else: Prose.gratingLockedShut)
            try require(!aboveGround.grating.isOpen, else: gameText.alreadyOpen())
            aboveGround.grating.isOpen = true
            maze.gratingRoom.isLit = true
            try reply(
                player.location == maze.gratingRoom
                    ? Prose.gratingOpensFromBelow : Prose.gratingOpensFromAbove)
        }
        aboveGround.grating.before(.close) {
            try require(aboveGround.grating.isOpen, else: gameText.alreadyClosed())
            aboveGround.grating.isOpen = false
            maze.gratingRoom.isLit = false
            try reply(Prose.gratingCloses)
        }
    }

    /// One turn of the grating's lock, in whichever direction. The two differ
    /// only in the state they turn the lock to and in what the wrong side of
    /// it says, so they are written once — a guard on one direction and not
    /// the other being the hole this replaces. Nothing guarded `lock` at all
    /// before #263, so the grating could be locked from the Clearing, which is
    /// the wrong side of its own lock.
    ///
    /// Everything the engine's own `setLocked` would have said is read back
    /// out of the game's register, in the order it says it, so this lock and
    /// the oak door refuse a wrong key in one voice.
    ///
    /// - Parameters:
    ///   - locked: the state the lock is being turned to.
    ///   - refusal: what to say to somebody standing over the grating rather
    ///     than under it, which is not the same sentence in both directions.
    /// - Throws: always — every path here refuses or replies.
    private func turnTheGratingsLock(to locked: Bool, wrongSide refusal: String) throws -> Never {
        try require(player.location == maze.gratingRoom, else: refusal)
        try require(
            aboveGround.grating.isLocked != locked,
            else: locked ? gameText.alreadyLocked() : gameText.alreadyUnlocked())
        guard let key = command.indirectObject else { try refuse(gameText.didntUnderstand()) }
        try require(key.isHeld, else: gameText.keyNotHeld(key.definiteNoun))
        try require(key == aboveGround.skeletonKeys, else: gameText.wrongKey())
        aboveGround.grating.isLocked = locked
        try reply(locked ? Prose.gratingLocked : Prose.gratingUnlocked)
    }

    /// Milestone 4 — the cyclops
    @RuleBuilder private var cyclopsRules: Rules {
        // Feeding him. The lunch, the bottle and the water are ``DungeonHouse``
        // items and the cyclops a ``DungeonMaze`` one, so the host bridges
        // them. The hot peppers make him thirsty — which the source records by
        // flipping his hunger negative — and the water then puts him out.
        maze.cyclops.before(.give) {
            guard !maze.cyclopsSubdued else { try reply(Prose.cyclopsAsleep) }
            switch command.directObject {
            case house.lunch:
                house.lunch.vanish()
                maze.cyclopsWrath = min(-1, -maze.cyclopsWrath)
                maze.cyclopsProvoked = true
                try reply(Prose.cyclopsEatsLunch)
            case house.water:
                try require(maze.cyclopsWrath < 0, else: Prose.cyclopsNotThirsty)
                house.water.vanish()
                maze.cyclopsSubdued = true
                try reply(Prose.cyclopsDrinksAndSleeps)
            case house.garlic:
                try reply(Prose.cyclopsWontEatGarlic)
            default:
                try reply(Prose.cyclopsWontEatThat)
            }
        }
    }

    /// Milestone 4 — the maze's finds
    @RuleBuilder private var mazeFindRules: Rules {
        // Disturbing the dead adventurer. The ghost banishes everything loose
        // in the room and everything in your hands to the Land of the Living
        // Dead, which is a ``DungeonTemple`` room.
        maze.skeleton.before(.take, .push, .attack, .lookIn) {
            let dead = templeQuarter.landOfTheLivingDead
            for item in player.inventory {
                item.move(to: dead)
            }
            for item in maze.maze5.contents where item.isTakable {
                item.move(to: dead)
            }
            try reply(Prose.skeletonCurse)
        }

        // The elvish sword answers the haunted knife. A ``DungeonHouse`` item
        // and a ``DungeonMaze`` one, so the host says so.
        maze.rustyKnife.after(.take) {
            guard house.sword.isHeld else { return }
            say(Prose.rustyKnifeBluePulse)
        }
    }

    /// Milestone 4 — the granite wall
    @RuleBuilder private var graniteRules: Rules {
        // The two words that use it. Each works in exactly one room and takes
        // you to the other; the Temple is a ``DungeonTemple`` room and the
        // Treasure Room a ``DungeonMaze`` one, so the pair lives here.
        let acrossTheGranite: [(Location, Intent, Location)] = [
            (templeQuarter.temple, .treasure, maze.treasureRoom),
            (maze.treasureRoom, .temple, templeQuarter.temple),
        ]
        for (here, word, there) in acrossTheGranite {
            here.before(word) {
                player.location = there
                say(Prose.graniteWallCarriesYou)
                describeSurroundings()
                try handled()
            }
        }
    }

    /// Milestone 5 — the bucket
    @RuleBuilder private var bucketRules: Rules {
        // The lift at the bottom of the well. The bucket is a ``DungeonAlice``
        // vehicle and the water a ``DungeonHouse`` liquid, so the host owns
        // both halves of the trip. Location rules rather than item ones,
        // because `before` runs world, then location, then item — and the
        // bottle's own pour rule would otherwise answer first and empty it on
        // the floor.
        alice.circularRoom.before(.pour, .putIn) {
            guard command.directObject == house.water else { return }
            guard
                command.indirectObject == nil || command.indirectObject == alice.bucket
            else { return }
            try require(player.vehicle == alice.bucket, else: Prose.bucketBoardFirst)
            try require(house.bottle.holds(house.water), else: Prose.nothingToPour)
            try require(house.bottle.isOpen, else: Prose.bottleNeedsToBeOpen)
            house.water.move(inside: alice.bucket)
            try alice.raiseBucket()
        }

        // And the way back down: take the water out of it, by any of the three
        // sentences that mean that, and the bucket follows the water.
        alice.topOfWell.before(.pour, .empty, .take) {
            let named = command.directObject
            guard named == house.water || named == alice.bucket else { return }
            try require(player.vehicle == alice.bucket, else: Prose.bucketBoardFirst)
            try require(alice.bucket.holds(house.water), else: Prose.bucketNeedsWater)
            house.water.vanish()
            try alice.lowerBucket()
        }
    }

    /// Milestone 5 — the three buttons
    @RuleBuilder private var buttonRules: Rules {
        // The triangular one stops the machinery under the Round Room, which
        // is a ``DungeonRoundRoom`` room a very long way from the switch — so
        // the host presses it. What the stopped floor stops hiding is the
        // dented steel box, which has stood there since turn one.
        alice.triangularButton.before(.push, .turnOn) {
            guard crossroads.carouselSpinning else {
                try reply(Prose.triangularButtonAgain)
            }
            crossroads.carouselSpinning = false
            crossroads.steelBox.reveal()
            try reply(Prose.triangularButtonStopsTheCarousel)
        }
    }

    /// Milestone 5 — what the Winding Passage says about the Round Room
    ///
    /// The passage is a ``DungeonMirror`` room reporting a ``DungeonRoundRoom``
    /// fact in three places, so the host supplies all three, the way
    /// ``palantirRules`` supplies the Slide Room's rope paragraph. The Round
    /// Room itself was given a `describe { }` for exactly this reason —
    /// ``Prose/roundRoomStilled`` says a room that went on whirring "would be
    /// telling the player their own solution had not worked" — and the room
    /// next door never got the same treatment.
    @RuleBuilder private var whirringRules: Rules {
        mirrors.windingPassage.describe {
            crossroads.carouselSpinning ? Prose.windingPassage : Prose.windingPassageStilled
        }

        mirrors.whirring.describe {
            crossroads.carouselSpinning
                ? Prose.windingPassageWhirring
                : Prose.windingPassageWhirringStopped
        }

        // The third place: the north wall's refusal. A `blocked:` exit carries
        // one constant, so the stilled half has to be a rule — and it is a
        // `before(.go)` rather than a conditional exit because there is nothing
        // through the wall either way, only two different true things to say
        // about it.
        mirrors.windingPassage.before(.go) {
            guard command.direction == .north, !crossroads.carouselSpinning else { return }
            try refuse(Prose.noEntranceToTheRoundRoomStilled)
        }
    }

    /// Milestone 6 — the balloon's fire and the gnome's fee
    ///
    /// Both are volcano mechanisms and both are here, because each has exactly
    /// one clause that names another bundle: the brick answers `burn` with an
    /// obituary wherever it is standing, and the gnome refuses it. Everything
    /// after that clause is ``DungeonVolcano``'s and is delegated to it, so the
    /// host never writes the bundle's state or names its fuses.
    @RuleBuilder private var balloonRules: Rules {
        world.before(.burn) {
            guard let fuel = command.directObject else { return }
            if fuel == house.brick {
                try require(
                    player.heldFlame(named: command.indirectObject) != nil,
                    else: Prose.nothingToBurnWith)
                house.brick.vanish()
                try die(Prose.brickBoom)
            }
            guard volcano.receptacle.holds(fuel) else { return }
            try volcano.lightTheBurner(fuel)
        }

        volcano.gnome.before(.give, .throwAt) {
            guard let offered = command.directObject else {
                try reply(Prose.gnomeIsNervous)
            }
            guard offered != house.brick else { try volcano.gnomeRefusesTheCharge(offered) }
            try volcano.offerTheGnome(offered)
        }
    }

    /// Milestone 6 — the brick, the wire and what they do to a room
    @RuleBuilder private var blastRules: Rules {
        // The wire coil is milestone 2's and the brick milestone 1's, so the
        // host holds the match; what the blast reaches is the volcano's.
        dam.wireCoil.before(.burn) {
            try require(
                player.heldFlame(named: command.indirectObject) != nil,
                else: Prose.nothingToBurnWith)
            startFuse("brickBlast")
            try reply(Prose.wireStartsToBurn)
        }
    }

    var timers: [TimedEvent] {
        // The wire burns for two turns, and then the clay in the brick turns
        // out to have been more than clay. Milestone 6; the brick and the wire
        // belong to two other bundles, so the fuse is the host's.
        fuse("brickBlast", after: 2) {
            let wire = dam.wireCoil
            guard house.brick.holds(wire) else {
                if wire.isReachable { say(Prose.wireBurnsToNothing) }
                wire.vanish()
                return
            }
            wire.vanish()
            try volcano.detonate(house.brick)
        }

        // The troll swings back — but only at someone who has swung at him, or
        // one turn in three of his own accord: `F-FIRST?` (`1actions.zil:702`,
        // and `act1.254`'s troll before it) is `<PROB 33>`. The other two turns
        // he does what his listing line says he does, which is block. He is
        // still the only thing in this milestone that will kill you other than
        // the dark.
        melee.aggression(
            of: cellar.troll, key: "troll", daemonName: "melee.troll",
            strikesFirst: 33,
            prose: MeleeCombat.AggressionProse(
                miss: [Prose.trollSwipeMiss],
                wound: [Prose.trollSwipeWound],
                playerDeath: Prose.trollKillsYou))

        thiefTimers
        palantirTimers
        endgameTimers
    }

    var map: WorldMap {
        coreMap
        mazeMap
        riverMap
        milestoneFiveMap
        milestoneSixMap
        milestoneSevenMap
        milestoneEightMap
        milestoneNineMap
    }

    /// Milestones 1 to 3, and the placements that belong to no one milestone.
    @MapBuilder private var coreMap: WorldMap {
        moreCoreMap
        // The kitchen window: the one door between ``DungeonAboveGround`` and
        // ``DungeonHouse``. Starts closed.
        aboveGround.behindHouse.west(house.kitchen, via: house.window)
        aboveGround.behindHouse.in(house.kitchen, via: house.window)
        house.kitchen.east(aboveGround.behindHouse, via: house.window)
        house.kitchen.out(aboveGround.behindHouse, via: house.window)

        // Where ``DungeonHouse`` meets ``DungeonCellar``. The Cellar's east
        // passage is the troll's front door; its crawlway south reaches West of
        // Chasm — and that is the route to the Gallery and the Studio that does
        // *not* go through the troll.
        house.cellar.east(cellar.trollRoom)
        cellar.trollRoom.west(house.cellar)
        house.cellar.south(cellar.westOfChasm)
        cellar.westOfChasm.west(house.cellar)

        // The chimney, one-way up into the Kitchen. The load gate is the
        // host's `before(.go)` rule above rather than a conditional exit,
        // because it has two different refusals to choose between.
        cellar.studio.up(house.kitchen)

        // The troll's north passage, which milestone 1 left as a seam: it is
        // the front door of the underground crossroads, and he holds it the
        // same way he holds the crawlway east.
        cellar.trollRoom.north(
            crossroads.eastWestPassage, when: { cellar.trollDefeated },
            otherwise: Prose.trollBlocksTheWay)
        crossroads.eastWestPassage.west(cellar.trollRoom)

        // Where ``DungeonRoundRoom`` meets ``DungeonDam``. Three crossings, and
        // not one of them is the west door Zork I hangs off the Dam: the
        // mainframe has no exit at all between the dam and the reservoir's
        // south shore.
        crossroads.deepCanyon.east(dam.damRoom)
        dam.damRoom.south(crossroads.deepCanyon)
        crossroads.dampCave.east(dam.damRoom)
        dam.damRoom.east(crossroads.dampCave)

        // The four narrow ways in and out of the reservoir's south shore, each
        // of them shut while the gold coffin is in your hands. The source's
        // `COFFIN-CURE`, and milestone 2 declared them plain because the
        // Egyptian Room the coffin starts in had not been built yet — so the
        // gate was vacuously open. It is not any more.
        crossroads.deepCanyon.northwest(
            dam.reservoirSouth, when: { templeQuarter.coffinIsStowed },
            otherwise: Prose.coffinTooHeavyForPassage)
        dam.reservoirSouth.up(
            crossroads.deepCanyon, when: { templeQuarter.coffinIsStowed },
            otherwise: Prose.coffinTooHeavyForStairs)
        crossroads.deepRavine.down(
            dam.reservoirSouth, when: { templeQuarter.coffinIsStowed },
            otherwise: Prose.coffinTooHeavyForStairs)
        dam.reservoirSouth.south(
            crossroads.deepRavine, when: { templeQuarter.coffinIsStowed },
            otherwise: Prose.coffinTooWideForRavine)

        // The Round Room's carousel. All nine of the source's passages are
        // built — the ninth, southwest into the maze, since milestone 4. Each
        // is a *dynamic* exit rather than a plain one, because while the machinery
        // turns the direction you take has nothing to do with where you come
        // out. Travelling through the exit rather than assigning
        // `player.location` is what keeps the East-West Passage's five points
        // payable: they are an `onEnter` award, and only `enter()` runs those.
        let exits = carouselExits
        for (heading, destination) in exits {
            crossroads.roundRoom.exit(
                heading,
                toward: {
                    // A read, not a roll: a dynamic exit's closure may be asked
                    // more than once in a turn, and `FOLLOW` asks all eight.
                    crossroads.carouselSpinning
                        ? exits[crossroads.carouselTwist % exits.count].1 : destination
                })
        }

        // The Deep Ravine's west crawl, which milestone 2 left as a seam: it
        // is the way into the temple quarter, and it runs **west from both
        // ends** — the mainframe's own doubling, not a transcription slip.
        crossroads.deepRavine.west(templeQuarter.rockyCrawl)
        templeQuarter.rockyCrawl.west(crossroads.deepRavine)

        // The Torch Room's staircase down into the North-South Crawlway. One
        // way only: that crawlway's own `up` is already blocked, so the drop
        // out of the dome is a drop out of the whole quarter.
        templeQuarter.torchRoom.down(cellar.crawlway)

        // The Grail Room's two passages, and the Engravings Cave's one. All
        // three cross a bundle, and two of them are Round Room passages the
        // carousel above has already claimed.
        templeQuarter.grailRoom.west(crossroads.roundRoom)
        templeQuarter.grailRoom.east(mirrors.narrowCrawlway)
        mirrors.narrowCrawlway.north(templeQuarter.grailRoom)
        templeQuarter.engravingsCave.north(crossroads.roundRoom)

        // Stream View's path north to the Glacier Room, milestone 2's other
        // seam — and the way the gold coffin leaves the Egyptian Room, since
        // every other passage out of that quarter is too narrow for it.
        templeQuarter.glacierRoom.north(dam.streamView)
        dam.streamView.north(templeQuarter.glacierRoom)

        // The southern Cave's dark, forbidding staircase down to the gate of
        // Hades, and the climb back.
        mirrors.caveSouth.down(templeQuarter.entranceToHades)
        templeQuarter.entranceToHades.up(mirrors.caveSouth)

        // Reservoir North's tunnel to the Atlantis Room — milestone 2's third
        // seam, and the only way into the mirror network on foot.
        mirrors.atlantisRoom.southeast(dam.reservoirNorth)
        dam.reservoirNorth.north(mirrors.atlantisRoom)
    }

    /// The second half of the same list, for the reason
    /// ``Dungeon/mainframeRules`` states.
    @MapBuilder private var moreCoreMap: WorldMap {
        // The Slide Room's small opening north is the mine. Its chute down is
        // milestone 8's — `SLIDE-EXIT`, which reads the rope — and lives in
        // ``Dungeon/milestoneEightMap`` with the rest of the palantir wing.
        mirrors.slideRoom.north(mine.mineEntrance)
        mine.mineEntrance.south(mirrors.slideRoom)
    }

    /// Milestone 4 — the maze
    @MapBuilder private var mazeMap: WorldMap {
        // The troll's south passage, which milestone 1 left as a seam: it is
        // the mouth of the maze, and he holds it the way he holds the other
        // two. Maze-1 comes back **west** — the mainframe's own asymmetry, and
        // the first thing the maze does to you.
        cellar.trollRoom.south(
            maze.maze1, when: { cellar.trollDefeated },
            otherwise: Prose.trollBlocksTheWay)
        maze.maze1.west(cellar.trollRoom)

        // The grating, a real door between the forest Clearing and the room
        // under it. Locked from both sides until the skeleton keys turn up in
        // Maze-5.
        aboveGround.clearing.down(maze.gratingRoom, via: aboveGround.grating)
        maze.gratingRoom.up(aboveGround.clearing, via: aboveGround.grating)

        // The Living Room's west door, which milestone 1 nailed shut and
        // declared as the seam it was. The cyclops opens it from the far side
        // by going through the wall next to it.
        house.livingRoom.west(
            maze.strangePassage, when: { maze.northWallOpen },
            otherwise: Prose.woodenDoorNailedShut)
        maze.strangePassage.east(house.livingRoom)
    }

    /// Milestone 4 — the river
    @MapBuilder private var riverMap: WorldMap {
        // The Dam Base is the boat's first launching point, and River-1's only
        // bank. `launch` and `land` are rules; the compass exit is here.
        river.river1.west(dam.damBase)

        // The Loud Room's east door onto the Ancient Chasm — milestone 2's
        // last seam, and the whole reason the river can be reached on foot.
        crossroads.loudRoom.east(river.ancientChasm)
        river.ancientChasm.south(crossroads.loudRoom)

        // Canyon Bottom's path north to the End of Rainbow, which milestone 1
        // left as a seam. It is also how the pot of gold is carried home
        // without ever setting foot in a boat.
        aboveGround.canyonBottom.north(river.endOfRainbow)
        river.endOfRainbow.southeast(aboveGround.canyonBottom)
    }

    /// Milestone 5 — the road to the well
    @MapBuilder private var milestoneFiveMap: WorldMap {
        // The Engravings Cave's southeast passage, which milestone 2 left as a
        // seam and milestone 3 built the room around: it is the only way into
        // the Riddle Room, and through it the only way to the well, the Bank
        // and everything above them. One-way in the source, and one-way here —
        // the Riddle Room's own way back is down.
        templeQuarter.engravingsCave.southeast(riddle.riddleRoom)
        riddle.riddleRoom.down(templeQuarter.engravingsCave)

        // The Pearl Room's east door onto the bottom of the well. The two ends
        // are in different bundles, so the host joins them.
        riddle.pearlRoom.east(alice.circularRoom)
        alice.circularRoom.west(riddle.pearlRoom)

        // The Gallery's west door into the Bank of Zork, which milestone 1
        // left undeclared. The Gallery is a ``DungeonCellar`` room, and this is
        // the whole of the Bank's frontage: nine rooms hang off one doorway.
        cellar.gallery.west(bank.bankEntrance)
        bank.bankEntrance.south(cellar.gallery)

        // The clockwork canary rides sealed inside the egg — one bundle's item
        // inside another's, so the host places it. The ruined pair wait
        // offstage in the same arrangement, `BCANA` inside `BEGG` exactly as
        // `docs/games/dungeon-atlas.md` has them, until a forced opening
        // trades one pair for the other.
        house.canary.starts(inside: aboveGround.egg)
        house.brokenCanary.starts(inside: aboveGround.brokenEgg)

        // Milestone 4's cross-bundle placements: the boat and the stick wait
        // at the Dam Base, and the grating's keys in Maze-5.
        river.pileOfPlastic.starts(in: dam.damBase)
        river.sharpStick.starts(in: dam.damBase)
        aboveGround.skeletonKeys.starts(in: maze.maze5)

        player.starts(in: aboveGround.westOfHouse)
    }

    /// Milestone 6 — the two doors into the volcano
    @MapBuilder private var milestoneSixMap: WorldMap {
        // The Ruby Room's west passage, which milestone 3 left as a seam. It
        // runs **west from both ends** — the mainframe's own doubling, the same
        // one the Deep Ravine's crawl has, and not a transcription slip.
        templeQuarter.rubyRoom.west(volcano.lavaRoom)
        volcano.lavaRoom.west(templeQuarter.rubyRoom)

        // And the Egyptian Room's south door, which milestone 3 left with the
        // room's description still naming it. Volcano View is on the far wall
        // of the shaft: you can see both flyable ledges from it and reach
        // neither, which is the whole of what that room is for.
        templeQuarter.egyptianRoom.south(volcano.volcanoView)
        volcano.volcanoView.east(templeQuarter.egyptianRoom)
    }

    /// The one seam milestone 4 left open: the Treasure Room's east passage,
    /// which its description has been naming ever since ("what appears to be a
    /// newly created passage to the east"). The Treasure Room is a
    /// ``DungeonMaze`` room and the antechamber a ``DungeonRoyalPuzzle`` one, so
    /// the pair lives here.
    @MapBuilder private var milestoneSevenMap: WorldMap {
        maze.treasureRoom.east(royalPuzzle.anteroom)
        royalPuzzle.anteroom.west(maze.treasureRoom)
    }
}
