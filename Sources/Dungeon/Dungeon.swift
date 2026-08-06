import Gnusto
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
    /// on the mainframe's 691 at the last one.
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
    /// Why the ceiling moves at all, and what may be declared ahead of its
    /// route: `docs/games/dungeon.md`, "The ceiling ratchets while the game is
    /// being built", and the matching `FIDELITY.md` entry.
    let maxScore = 265

    let intro = Prose.intro

    /// The stock engine lines re-voiced where Zork's own differ from Gnusto's
    /// classic register. Every line not set here already matches.
    var text: GameText {
        var text = GameText()
        text.pitchBlack = { Prose.grueWarning }
        text.nothingSpecial = { "There's nothing special about \($0)." }
        text.alreadyOpen = "It is already open."
        text.alreadyClosed = "It is already closed."
        text.alreadyHave = "You already have that!"
        text.didntUnderstand = "That sentence isn't one I recognize."
        text.nothingToTakeHere = "There's nothing here you can take."
        // The basket carrying the only light down the shaft darkens a room the
        // way turning a lamp off does, so the two say the same sentence.
        text.nowDark = Prose.itIsNowPitchBlack
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
        ])

    let melee = MeleeCombat()

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

    var content: GameContents {
        aboveGround
        house
        cellar
        crossroads
        dam
        templeQuarter
        mirrors
        mine
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
    private var treasureRoster: [Item] {
        [
            aboveGround.egg, house.canary, house.bauble, cellar.painting,
            crossroads.platinumBar, dam.trunk,
            templeQuarter.ivoryTorch, templeQuarter.coffin, templeQuarter.grail,
            templeQuarter.ruby, mirrors.crystalTrident,
            mine.jade, mine.sapphireBracelet, mine.diamond,
        ]
    }

    /// Every passage out of the Round Room this game has built, and where each
    /// of them goes once the machinery under the floor has been stopped.
    ///
    /// The source has nine. Eight of them are built, and they reach four
    /// different bundles — which is why the carousel lives here rather than in
    /// ``DungeonRoundRoom``: the map loops over this list, the draw rolls
    /// against its length, and the `before(.go)` rule guards on it. The ninth,
    /// southwest into the maze, is the last seam left in the room.
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
        ]
    }

    var rules: Rules {
        scoring.treasures(treasureRoster, into: house.trophyCase)

        // The mainframe's room values, as event awards: getting into the
        // kitchen, and getting below the house.
        scoring.visit(house.kitchen, register: "kitchen")
        scoring.visit(house.cellar, register: "cellar")
        scoring.visit(crossroads.eastWestPassage, register: "eastWestPassage")
        scoring.visit(templeQuarter.landOfTheLivingDead, register: "landOfTheLivingDead")

        // The carousel. One draw per attempt, taken at stage 3 so the exit
        // lookup that follows reads a settled answer — the mainframe's
        // `CAROUSEL-OUT`. Guarded to the built passages, so the one direction
        // whose far side is a later milestone's (southwest, into the maze) gets
        // the plain "You can't go that way" of the seam convention rather than
        // being told the room turned under it and then refused anyway.
        crossroads.roundRoom.before(.go) {
            guard crossroads.carouselSpinning, let heading = command.direction else { return }
            let exits = carouselExits
            guard exits.contains(where: { $0.0 == heading }) else { return }
            crossroads.carouselTwist = random(0...(exits.count - 1))
            say(Prose.roundRoomNoBearings)
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
            try require(
                player.location == templeQuarter.domeRoom
                    && (command.indirectObject == nil
                        || command.indirectObject == templeQuarter.railing),
                else: Prose.ropeNeedsRailing)
            try require(!templeQuarter.ropeTiedToRailing, else: Prose.ropeCarriesNothing)
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
            try reply("")
        }

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
        // fingers: prying it yourself wrecks the canary inside, swapping the
        // intact bird for the ruined one, before the built-in open completes.
        // The `isOpen` clause is redundant today and will not stay so: forcing
        // is the only thing that opens the egg here, but the thief opens it
        // with the bird still inside, and then this rule must not fire.
        aboveGround.egg.before(.open) {
            guard !aboveGround.egg.isOpen, aboveGround.egg.holds(house.canary) else { return }
            house.canary.vanish()
            house.brokenCanary.move(inside: aboveGround.egg)
            say(Prose.eggForcedRuinsCanary)
            // Falls through to the built-in open.
        }

        // Wind the intact canary among the trees and a songbird answers,
        // dropping a brass bauble — once, ever. Wound up the tree, the bauble
        // falls to the forest floor below. Canary and forest live in different
        // bundles, so the host owns the trick; the set of rooms the bird
        // answers in is ``DungeonAboveGround/isInTheWood(_:)``, which the
        // region's own ambience daemon shares.
        house.canary.before(.wind) {
            let here = player.location
            guard !house.baubleDropped, aboveGround.isInTheWood(here) else {
                try reply(Prose.canaryChirps)
            }
            house.bauble.move(to: here == aboveGround.upATree ? aboveGround.forestTree : here)
            house.baubleDropped = true
            try reply(Prose.songbirdDropsBauble)
        }
        // The ruined bird's answer is `DungeonHouse`'s own — it names nothing
        // outside that bundle, so it lives there.
    }

    var timers: [TimedEvent] {
        // The troll swings back. He is the only thing in this milestone that
        // will kill you other than the dark.
        melee.aggression(
            of: cellar.troll, key: "troll", daemonName: "melee.troll",
            prose: MeleeCombat.AggressionProse(
                miss: [Prose.trollSwipeMiss],
                wound: [Prose.trollSwipeWound],
                playerDeath: Prose.trollKillsYou))
    }

    var map: WorldMap {
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

        // The Round Room's carousel. Eight of the source's nine passages are
        // built; the ninth, southwest into the maze, is a seam. Each is a
        // *dynamic* exit rather than a plain one, because while the machinery
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

        // The Slide Room. Its chute drops one-way into the Cellar — the
        // source's slide becomes a rope-climb down the coal chute once a timber
        // has been tied at the top, and those five rooms are a later
        // milestone's — and its small opening north is the mine.
        mirrors.slideRoom.down(house.cellar)
        mirrors.slideRoom.north(mine.mineEntrance)
        mine.mineEntrance.south(mirrors.slideRoom)

        // The clockwork canary rides sealed inside the egg — one bundle's item
        // inside another's, so the host places it. Its broken twin waits
        // offstage until a forced opening trades them.
        house.canary.starts(inside: aboveGround.egg)

        player.starts(in: aboveGround.westOfHouse)
    }
}
