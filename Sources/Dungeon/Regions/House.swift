import Gnusto

/// The white house's interior — Kitchen, Living Room, Attic — and the Cellar
/// the trap door drops into.
///
/// The Cellar lives here rather than in ``DungeonCellar`` for the same reason
/// it does in `Sources/Zork1/`: the trap door joins two rooms one bundle owns,
/// so the door needs no host wiring. The kitchen window is the other way round
/// — it joins this bundle's ``kitchen`` to ``DungeonAboveGround/behindHouse``,
/// so the host wires it.
///
/// Two mainframe facts the trilogy softened, both live here:
///
/// - the **Attic is dark**. The mainframe gives it no light bit, so the lamp
///   has to come up the stairs;
/// - the **trap door bars itself** on the first descent, with nobody in the
///   story to blame, and from below it is simply locked from above. The
///   chimney out of the Studio is the way back, and it is the only way back
///   this milestone builds.
struct DungeonHouse: GameContent {
    // MARK: - Rooms

    let kitchen = Location {
        name("Kitchen")
        description(Prose.kitchen)
    }

    let livingRoom = Location {
        name("Living Room")
        description(Prose.livingRoom)
    }

    /// Dark, as in the mainframe.
    let attic = Location {
        name("Attic")
        description(Prose.attic)
        dark
    }

    let cellar = Location {
        name("Cellar")
        description(Prose.cellar)
        dark
    }

    // MARK: - Kitchen

    /// The door between ``DungeonAboveGround/behindHouse`` and ``kitchen``.
    /// Starts closed; "slightly ajar" is flavor, not a third state.
    let window = Item {
        name("kitchen window")
        adjectives("kitchen", "small", "narrow")
        synonyms("window")
        description(Prose.kitchenWindow)
        openable
        scenery
    }

    /// The kitchen names a staircase and a chimney; both answer.
    let kitchenStaircase = Item {
        name("staircase")
        adjectives("dark")
        synonyms("stairs", "stairway", "staircase")
        description(Prose.kitchenStaircase)
        scenery
    }

    let kitchenChimney = Item {
        name("chimney")
        adjectives("dark")
        synonyms("chimney")
        description(Prose.kitchenChimney)
        scenery
    }

    let kitchenTable = Item {
        name("kitchen table")
        adjectives("kitchen", "wooden")
        synonyms("table")
        description(Prose.kitchenTable)
        surface
        scenery
    }

    let sack = Item {
        name("brown sack")
        adjectives("brown", "elongated")
        synonyms("sack", "bag")
        firstSight(Prose.sackOnTable)
        description(Prose.sack)
        container
        openable
        startsOpen
        trait(.weight, 3)
    }

    let garlic = Item {
        name("clove of garlic")
        adjectives("clove")
        synonyms("garlic")
        description(Prose.garlic)
    }

    let lunch = Item {
        name("lunch")
        adjectives("hot", "pepper")
        synonyms("sandwich", "dinner", "food")
        firstSight(Prose.lunchInPlace)
        description(Prose.lunch)
    }

    let bottle = Item {
        name("glass bottle")
        adjectives("clear", "glass")
        synonyms("bottle", "container")
        firstSight(Prose.bottleOnTable)
        description(Prose.bottle)
        container
        openable
        transparent
    }

    let water = Item {
        name("quantity of water")
        adjectives("quantity")
        synonyms("water", "liquid")
        description(Prose.water)
        trait(.weight, 4)
    }

    // MARK: - Living Room

    /// A real light source with finite fuel: three fuses (two warnings, then
    /// dark for good) that run only while it burns, so turning it off banks
    /// what is left. The mainframe's lamp is good for 350 turns of burning;
    /// the warnings sit inside that.
    let lantern = Item {
        name("brass lantern")
        adjectives("brass", "battery-powered")
        synonyms("lamp", "lantern", "light")
        firstSight(Prose.lanternOnCase)
        lightSource
        trait(.weight, 15)
    }

    /// The lamp's schedule, in turns of burning: two warnings inside the
    /// mainframe's 350. Named once, because each figure is both a fuse's
    /// declared length and its global's opening balance.
    static let lanternDimAt = 200
    static let lanternLastGaspAt = 300
    static let lanternDiesAt = 350

    /// Fuel left on the dim-warning fuse while the lamp is off.
    @Global var lanternDimIn = Self.lanternDimAt
    /// Fuel left on the last-gasp fuse.
    @Global var lanternLastGaspIn = Self.lanternLastGaspAt
    /// Fuel left on the burn-out fuse.
    @Global var lanternDiesIn = Self.lanternDiesAt
    @Global var lanternBurnedOut = false

    let sword = Item {
        name("elvish sword")
        adjectives("elvish")
        synonyms("sword", "blade", "orcrist", "glamdring")
        firstSight(Prose.swordOnHooks)
        description(Prose.sword)
        trait(.weapon, true)
        trait(.weaponStrength, 3)
        trait(.weight, 30)
    }

    let mantelpiece = Item {
        name("mantelpiece")
        adjectives("stone")
        synonyms("mantel", "hooks", "hook", "fireplace")
        description(Prose.mantelpiece)
        scenery
    }

    /// Pushing it reveals the trap door.
    let rug = Item {
        name("oriental rug")
        adjectives("oriental", "large")
        synonyms("rug", "carpet")
        description(Prose.rug)
        scenery
    }

    /// The gothic door west, nailed shut. It opens only when the cyclops
    /// smashes his way through from the maze — a later milestone — so this
    /// bundle declares the door and the host will declare the exit.
    let woodenDoor = Item {
        name("wooden door")
        adjectives("wooden", "west", "western", "gothic")
        synonyms("door", "lettering", "letters")
        description(Prose.woodenDoor)
        scenery
    }

    /// Shared between ``livingRoom`` and ``cellar``, so the slam is felt from
    /// both sides.
    let trapDoor = Item {
        name("trap door")
        adjectives("trap", "dusty")
        synonyms("trapdoor", "door")
        description(Prose.trapDoor)
        openable
        scenery
        hidden
    }

    /// True once the descent has thrown the bar. Unlike Zork I's, this one is
    /// nobody's doing and never comes off in this milestone.
    @Global var trapDoorBarred = false

    let trophyCase = Item {
        name("trophy case")
        adjectives("trophy")
        synonyms("case")
        container
        openable
        transparent
        scenery
    }

    /// The clockwork canary, sealed inside the egg. The mainframe's values are
    /// 6 to find and **2** to case, where Zork I pays 4 for the case.
    let canary = Item {
        name("golden clockwork canary")
        adjectives("golden", "gold", "clockwork", "mechanical")
        synonyms("canary", "bird")
        description(Prose.canary)
        trait(.takeValue, 6)
        trait(.depositValue, 2)
    }

    /// The ruined bird a forced egg leaves behind. Worth nothing, in this game
    /// as in the mainframe.
    let brokenCanary = Item {
        name("broken clockwork canary")
        adjectives("broken", "golden", "gold", "clockwork", "mechanical")
        synonyms("canary", "bird")
        description(Prose.brokenCanary)
    }

    /// The bauble the songbird drops when the intact canary is wound among the
    /// trees — one to find, one to case. Starts offstage; only the trick puts
    /// it in the world.
    let bauble = Item {
        name("beautiful brass bauble")
        adjectives("brass", "beautiful")
        synonyms("bauble")
        description(Prose.bauble)
        trait(.takeValue, 1)
        trait(.depositValue, 1)
    }

    /// The songbird answers exactly once.
    @Global var baubleDropped = false

    /// Mainframe-only: the last edition of the Great Underground Empire's
    /// paper of record, lying in the living room.
    let newspaper = Item {
        name("newspaper")
        adjectives("dated")
        synonyms("paper", "issue", "report", "magazine", "news")
        firstSight(Prose.newspaperInPlace)
        description(Prose.newspaper)
        trait(.weight, 2)
        trait(.burnable, true)
    }

    // MARK: - Attic

    let rope = Item {
        name("coil of rope")
        adjectives("large", "coil")
        synonyms("rope", "hemp", "coil")
        firstSight(Prose.ropeInCorner)
        description(Prose.rope)
        trait(.weight, 10)
    }

    let knife = Item {
        name("nasty knife")
        adjectives("nasty", "plain", "unrusty")
        synonyms("knife", "blade")
        firstSight(Prose.knifeOnTable)
        description(Prose.knife)
        trait(.weapon, true)
    }

    let atticTable = Item {
        name("dusty table")
        adjectives("dusty", "rickety")
        synonyms("table")
        description(Prose.atticTable)
        surface
        scenery
    }

    /// Mainframe-only, and inert until the milestone that gives it a fuse.
    let brick = Item {
        name("brick")
        adjectives("square", "clay")
        synonyms("brick")
        firstSight(Prose.brickInPlace)
        description(Prose.brick)
        container
        startsOpen
        trait(.weight, 9)
        trait(.burnable, true)
    }

    // MARK: - Cellar

    let cellarRamp = Item {
        name("metal ramp")
        adjectives("steep", "metal")
        synonyms("ramp")
        description(Prose.cellarRamp)
        scenery
    }

    // MARK: - Map

    var map: WorldMap {
        livingRoom.east(kitchen)
        kitchen.west(livingRoom)
        kitchen.up(attic)
        kitchen.down(blocked: Prose.chimneyDownRefusal)
        attic.down(kitchen)

        // The gothic door west opens onto the Strange Passage, which milestone
        // 4 built — so its exit is the host's conditional one now, not the
        // `blocked:` seam milestone 1 declared here. The door itself, and the
        // lettering on it, stay.

        livingRoom.down(cellar, via: trapDoor)
        cellar.up(livingRoom, via: trapDoor)
        cellar.west(blocked: Prose.cellarRampRefusal)
        // The Cellar's east passage to the Troll Room and its crawlway south to
        // West of Chasm cross into ``DungeonCellar``, so the host wires them.

        window.starts(in: kitchen)
        kitchenStaircase.starts(in: kitchen)
        kitchenChimney.starts(in: kitchen)
        kitchenTable.starts(in: kitchen)
        sack.starts(on: kitchenTable)
        garlic.starts(inside: sack)
        lunch.starts(inside: sack)
        bottle.starts(on: kitchenTable)
        water.starts(inside: bottle)

        lantern.starts(in: livingRoom)
        mantelpiece.starts(in: livingRoom)
        sword.starts(in: livingRoom)
        rug.starts(in: livingRoom)
        woodenDoor.starts(in: livingRoom)
        trapDoor.starts(in: livingRoom)
        trophyCase.starts(in: livingRoom)
        newspaper.starts(in: livingRoom)

        atticTable.starts(in: attic)
        rope.starts(in: attic)
        knife.starts(on: atticTable)
        brick.starts(in: attic)

        cellarRamp.starts(in: cellar)

        // The canary rides sealed inside the egg, which lives in
        // ``DungeonAboveGround`` — so the host places it.
    }

    // MARK: - Rules

    var rules: Rules {
        houseRules
        moreHouseRules
    }

    @RuleBuilder private var houseRules: Rules {
        rug.before(.push) {
            guard !trapDoor.isRevealed else { try reply(Prose.rugAlreadyMoved) }
            trapDoor.reveal()
            try reply(Prose.rugMoveEmbellishment)
        }
        rug.before(.take) {
            try refuse(Prose.rugTooHeavy)
        }

        trophyCase.before(.take) {
            try refuse(Prose.trophyCaseFastened)
        }

        // The case describes itself by what is in it. Written over `contents`
        // rather than against a named treasure, because by the last milestone
        // this case holds thirty-one of them; `indefiniteName` is the engine's
        // article, so the line never says "a a".
        trophyCase.describe {
            let held = trophyCase.contents
            return held.isEmpty
                ? Prose.trophyCaseEmpty
                : Prose.trophyCaseHolding(GameText.list(held.map(\.indefiniteName)))
        }

        // The ruined bird only grinds its stripped gears. (The *intact*
        // canary's trick reaches into the forest, so the host owns that one.)
        brokenCanary.before(.wind) {
            try reply(Prose.brokenCanaryWinds)
        }

        // Nailed shut until the cyclops comes through the wall beside it, and
        // then permanently a hole rather than a door.
        woodenDoor.before(.open) {
            try refuse(Prose.woodenDoorNailedShut)
        }
        // Reading the gothic lettering is the joke, so it gets its own answer
        // rather than the door's description.
        woodenDoor.before(.read) {
            try reply(Prose.woodenDoorLettering)
        }

        newspaper.before(.read) {
            try reply(Prose.newspaperText)
        }

        // Opening the trap door. From below, once the bar is across, it does
        // not open at all; from above it opens onto the stair, in place of the
        // engine's bare "Opened."
        trapDoor.before(.open) {
            if player.location == cellar, trapDoorBarred {
                try refuse(Prose.trapDoorBarred)
            }
            guard !trapDoor.isOpen else { return }
            trapDoor.isOpen = true
            try reply(Prose.trapDoorOpens)
        }
    }

    /// The second half of the same list, split for hazard #174's reason: peak
    /// bootstrap stack depth scales with the largest single declaration body,
    /// and milestone 8's seventeenth bundle put the suite over the edge again.
    @RuleBuilder private var moreHouseRules: Rules {
        // The classic moment, and in this game it is permanent: the first
        // descent throws the bar, and nothing in this milestone lifts it. The
        // Studio chimney is the way back up.
        cellar.onEnter {
            guard trapDoor.isOpen else { return }
            trapDoor.isOpen = false
            trapDoorBarred = true
            say(Prose.trapDoorSlam)
        }

        lantern.describe {
            lantern.isLit ? Prose.lanternOn : Prose.lanternOff
        }

        // The lamp's fuel economy: the fuses run only while it burns.
        lantern.before(.turnOn) {
            try require(!lanternBurnedOut, else: Prose.lanternSpent)
        }
        lantern.after(.turnOn) {
            if lanternDimIn > 0 {
                startFuse("lanternDim", after: lanternDimIn)
            }
            if lanternLastGaspIn > 0 {
                startFuse("lanternLastGasp", after: lanternLastGaspIn)
            }
            startFuse("lanternDies", after: lanternDiesIn)
        }
        lantern.after(.turnOff) {
            lanternDimIn = fuseRemaining("lanternDim") ?? 0
            lanternLastGaspIn = fuseRemaining("lanternLastGasp") ?? 0
            lanternDiesIn = fuseRemaining("lanternDies") ?? 0
            stopFuse("lanternDim")
            stopFuse("lanternLastGasp")
            stopFuse("lanternDies")
        }

        // Liquids. Water lives in the bottle and slips through loose fingers;
        // this milestone has no water source to refill from.
        water.before(.take) {
            try refuse(Prose.waterSlipsAway)
        }
        water.before(.drink) {
            try require(bottle.holds(water), else: Prose.nothingToDrink)
            try require(bottle.isOpen, else: Prose.bottleNeedsToBeOpen)
            water.vanish()
            try reply(Prose.drinkWater)
        }
        water.before(.pour) {
            try require(bottle.holds(water), else: Prose.nothingToPour)
            try require(bottle.isOpen, else: Prose.bottleNeedsToBeOpen)
            water.vanish()
            try reply(Prose.bottleEmptied)
        }
        bottle.before(.fill) {
            guard !bottle.holds(water) else { try reply(Prose.bottleAlreadyFull) }
            // The mainframe marks its watery rooms with the `RGWATER` global.
            // There were none of them until the dam milestone, which is why
            // this line used to be an unconditional refusal.
            try require(player.location[default: .waterSource], else: Prose.noWaterSource)
            water.move(inside: bottle)
            try reply(Prose.bottleFilled)
        }
    }

    var timers: [TimedEvent] {
        fuse("lanternDim", after: Self.lanternDimAt) {
            say(Prose.lanternDim)
        }
        fuse("lanternLastGasp", after: Self.lanternLastGaspAt) {
            say(Prose.lanternLastGasp)
        }
        fuse("lanternDies", after: Self.lanternDiesAt) {
            lanternBurnedOut = true
            lantern.isLit = false
            say(Prose.lanternDies)
        }
    }
}
