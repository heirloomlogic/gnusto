import Gnusto
import GnustoActors
import GnustoDangerousDark
import GnustoMeleeCombat
import GnustoScoring

/// *Zork I: The Great Underground Empire* — the White House slice. Composes
/// the above-ground region (``ZorkAboveGround``), the house interior
/// (``ZorkHouse``), and the cellar region (``ZorkCellar``), and wires the
/// exits that cross between them: the kitchen window, the cellar's south
/// crawlway, and the studio's chimney. Everything else about each region is
/// that region's own concern; the host only owns what genuinely spans two.
@main
struct Zork1: Game, GameMain {
    let title = "Zork I: The Great Underground Empire"
    let tagline = "A placeholder slice: the White House, its grounds, and the cellar."

    /// The full game's ceiling: 350 points, as in the original. Only a
    /// fraction is reachable in the current slice (the painting 4+6 and egg
    /// 5+5 treasures, plus the kitchen/cellar visit awards), but the score
    /// line and rank ladder read against the real target from here on.
    let maxScore = 350
    let intro = """
        An adventure awaits amid a ruined empire buried underground. This
        slice covers only the White House, its immediate surroundings, and
        the first rooms below.
        """

    let aboveGround = ZorkAboveGround()
    let house = ZorkHouse()
    let cellar = ZorkCellar()
    let roundRoom = ZorkRoundRoom()
    let dam = ZorkDam()
    let temple = ZorkTemple()

    /// The grue. Zork's prose, the plugin's stock warn-then-kill schedule.
    let dangerousDark = DangerousDark(
        warning: Prose.grueWarning,
        death: Prose.grueDeath
    )

    let scoring = Scoring()
    let melee = MeleeCombat()
    let actors = ActorBehaviors()

    /// The custom verb vocabulary (dig, wave, ring, xyzzy, drink/fill/pour …)
    /// and its stage-4 defaults.
    let systems = ZorkSystems()

    /// The weight/burden system: takeable items have weight and the player
    /// can only carry so much.
    let burden = ZorkBurden()

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
    var actions: [IntentAction] {
        let possibleScore = maxScore
        action(.score) {
            let moves = player.moves
            say(
                "Your score is \(player.score) of a possible \(possibleScore), "
                    + "in \(moves) \(moves == 1 ? "turn" : "turns").")
            say(Prose.rankLine(ZorkRank.name(for: player.score)))
        }
    }

    /// Zork's canonical resurrection. The first two deaths are survivable: the
    /// player loses ten points, their belongings scatter across the grounds
    /// above (the lamp always turns up in the living room), and they wake in
    /// the forest. The third death is final — it falls through to the engine's
    /// banner and RESTART / RESTORE / UNDO / QUIT prompt. Runs inside the live
    /// turn, after the death message has printed, so it can teleport, dock the
    /// score, and move items just as a rule would (FIDELITY.md: the original's
    /// randomized scatter is modeled as a deterministic round-robin here).
    func onDeath() -> DeathOutcome {
        deaths += 1
        guard deaths < 3 else { return .fallThrough }
        scoring.penalize(10)

        // The lamp finds its way back to the living room; everything else
        // scatters, one item per above-ground room, cycling if you were
        // carrying more than the grounds have rooms.
        let scatter = [
            aboveGround.westOfHouse, aboveGround.northOfHouse,
            aboveGround.southOfHouse, aboveGround.behindHouse,
            aboveGround.forestPath, aboveGround.clearingEast,
        ]
        var next = 0
        for item in player.inventory {
            if item == house.lantern {
                item.move(to: house.livingRoom)
            } else {
                item.move(to: scatter[next % scatter.count])
                next += 1
            }
        }

        player.location = aboveGround.forestWest
        say(Prose.resurrection)
        describeSurroundings()
        return .consumed
    }

    var rules: Rules {
        // The treasures the slice can score, and where they pay out.
        // Cross-bundle wiring is the host's job, same as the exits below.
        scoring.treasures(
            [
                cellar.painting, aboveGround.egg, roundRoom.platinumBar, dam.trunk,
                temple.torch, temple.coffin, temple.sceptre, temple.crystalSkull,
            ],
            into: house.trophyCase)

        // Event scoring: the original pays for reaching the kitchen (first
        // way into the house), for descending into the cellar, and for
        // pressing east past the troll into the East-West Passage. All are
        // rooms the host owns the wiring for.
        scoring.visit(house.kitchen, register: "kitchen", points: 10)
        scoring.visit(house.cellar, register: "cellar", points: 25)
        scoring.visit(roundRoom.eastWestPassage, register: "eastWestPassage", points: 5)

        // The chimney is climbable only lightly loaded: the original caps it
        // at one item plus the lamp, which this slice simplifies to "no more
        // than two things in hand" (FIDELITY.md). Studio lives in ZorkCellar
        // and the rule is a burden concern, so the host owns it.
        cellar.studio.before(.go) {
            guard command.direction == .up else { return }
            try require(player.inventory.count <= 2, else: Prose.chimneyTooBurdened)
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
            player.location = aboveGround.forestWest
            describeSurroundings()
            try reply("")
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

        // The troll, fought with the house's blades — entities from two
        // bundles, so the host wires them. Strength 2 is the original's.
        melee.villain(
            cellar.troll, key: "troll", strength: 2,
            weapons: [house.sword, house.knife],
            prose: MeleeCombat.VillainProse(
                miss: [Prose.trollMiss1, Prose.trollMiss2],
                wound: [Prose.trollWound1, Prose.trollWound2],
                knockout: Prose.trollKnockout,
                death: Prose.trollDeath),
            onDefeat: { cellar.trollDefeated = true })

        // The bar. Descending while the thief is at large throws the bolt
        // above — the slam prose's "you hear a bolt slide home" has been
        // telling the truth-to-be since Phase 5. One-sided: the living
        // room side is never barred.
        house.cellar.onEnter {
            if !cellar.thiefDefeated {
                house.trapDoorBarred = true
            }
        }
        house.trapDoor.before(.open) {
            if player.location == house.cellar && house.trapDoorBarred {
                try refuse(Prose.trapDoorBarred)
            }
        }

        // The thief dies like a villain but doesn't fight back — in this
        // reduced form he is evasive, not aggressive (FIDELITY.md).
        melee.villain(
            cellar.thief, key: "thief", strength: 2,
            weapons: [house.sword, house.knife],
            prose: MeleeCombat.VillainProse(
                miss: [Prose.thiefMiss1, Prose.thiefMiss2],
                wound: [Prose.thiefWound1, Prose.thiefWound2],
                knockout: Prose.thiefKnockout,
                death: Prose.thiefDeath),
            onDefeat: {
                cellar.thiefDefeated = true
                house.trapDoorBarred = false
                stopDaemon("thiefRoams")
                stopDaemon("thiefSteals")
                var scattered = false
                for loot in [cellar.painting, aboveGround.egg]
                where cellar.thief.holds(loot) {
                    loot.move(to: player.location)
                    scattered = true
                }
                if scattered {
                    say(Prose.thiefLootScatters)
                }
            })
    }

    var timers: [TimedEvent] {
        // The gates' eight-turn passage, armed by the bolt rule above. Draining
        // lays the reservoir bare and reveals the trunk; filling submerges the
        // bed again and drowns anyone still standing on it. Both settle the
        // water — the Loud Room falls quiet — when they fire. Declared here
        // because they touch entities from two bundles (``dam`` and
        // ``roundRoom``) that neither can reach from its own timers.
        fuse("damDrain", after: 8) {
            dam.reservoirDrained = true
            dam.trunk.reveal()
            roundRoom.waterMoving = false
            say(Prose.reservoirEmpties)
        }
        fuse("damRefill", after: 8) {
            dam.reservoirDrained = false
            roundRoom.waterMoving = false
            if player.location == dam.reservoir {
                try die(Prose.reservoirRefillDrowns)
            }
            say(Prose.reservoirRefills)
        }

        // The struck match's short life: two turns after it's lit, the burning
        // match goes out and vanishes. Armed by the striking rule above; here
        // because the match is a ``ZorkTemple`` item lit from a ``ZorkDam`` one.
        fuse("matchBurns", after: 2) {
            temple.burningMatch.isLit = false
            temple.burningMatch.vanish()
            say(Prose.matchBurnsOut)
        }

        melee.aggression(
            of: cellar.troll, key: "troll", daemonName: "melee.troll",
            prose: MeleeCombat.AggressionProse(
                miss: [Prose.trollSwipeMiss],
                wound: [Prose.trollSwipeWound],
                playerDeath: Prose.trollKillsYou))

        // The thief works the cellar region: teleport-roaming its four
        // rooms, lifting only the two treasures (never the lantern or
        // sword — FIDELITY.md).
        actors.roams(
            cellar.thief, daemonName: "thiefRoams",
            rooms: [house.cellar, cellar.eastOfChasm, cellar.gallery, cellar.studio],
            chancePerTurn: 50,
            arrival: Prose.thiefArrives,
            departure: Prose.thiefLeaves)
        actors.steals(
            cellar.thief, daemonName: "thiefSteals",
            candidates: [cellar.painting, aboveGround.egg],
            chancePerTurn: 30,
            announcement: { Prose.thiefSteals($0) })
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
        house.cellar.south(cellar.eastOfChasm)
        cellar.eastOfChasm.north(house.cellar)
        house.cellar.north(cellar.trollRoom)
        cellar.trollRoom.south(house.cellar)
        cellar.studio.up(house.kitchen)

        // Where ZorkCellar meets ZorkRoundRoom: the troll's east passage,
        // sealed while he lives and opening onto the East-West Passage once he
        // falls. (His west passage, toward the maze, stays a stub — see
        // ``ZorkCellar``.)
        cellar.trollRoom.exit(
            .east, to: roundRoom.eastWestPassage,
            when: { cellar.trollDefeated }, otherwise: Prose.trollBlocksTheWay)
        roundRoom.eastWestPassage.west(cellar.trollRoom)

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

        player.starts(in: aboveGround.westOfHouse)
    }
}
