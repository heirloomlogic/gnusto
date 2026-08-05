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
/// **Built one milestone at a time.** This is milestone 1: above ground, the
/// white house, and the cellar. Each later milestone adds region bundles to
/// ``content`` and their crossings to ``rules`` and ``map``, and raises
/// ``maxScore`` by exactly what it makes payable — see the note on that
/// property. Nothing here has to move for a region to land.
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
    /// Why the ceiling moves at all, and what may be declared ahead of its
    /// route: `docs/games/dungeon.md`, "The ceiling ratchets while the game is
    /// being built", and the matching `FIDELITY.md` entry.
    let maxScore = 66

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
        return text
    }

    let aboveGround = DungeonAboveGround()
    let house = DungeonHouse()
    let cellar = DungeonCellar()

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
    /// `LIGHT-SHAFT` belongs in this table and is not in it yet — it is an
    /// `awardOnce` register worth 10, and the coal-mine milestone adds it with
    /// the 10 points it puts on ``maxScore``. Why an event award and not a room
    /// value: `docs/games/dungeon.md`, "The ceiling ratchets".
    let scoring = Scoring(
        awards: [
            "kitchen": 10,
            "cellar": 25,
        ])

    let melee = MeleeCombat()

    /// The custom verb vocabulary and its stage-4 defaults.
    let systems = DungeonSystems()

    /// The weight system: the mainframe's `OSIZE` values against a cap of 100.
    let burden = DungeonBurden()

    /// How many times the player has died.
    @Global var deaths = 0

    var content: GameContents {
        aboveGround
        house
        cellar
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
        [aboveGround.egg, house.canary, house.bauble, cellar.painting]
    }

    var rules: Rules {
        scoring.treasures(treasureRoster, into: house.trophyCase)

        // The mainframe's room values, as event awards: getting into the
        // kitchen, and getting below the house.
        scoring.visit(house.kitchen, register: "kitchen")
        scoring.visit(house.cellar, register: "cellar")

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

        // The clockwork canary rides sealed inside the egg — one bundle's item
        // inside another's, so the host places it. Its broken twin waits
        // offstage until a forced opening trades them.
        house.canary.starts(inside: aboveGround.egg)

        player.starts(in: aboveGround.westOfHouse)
    }
}
