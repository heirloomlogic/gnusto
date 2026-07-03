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

    /// The sum of the slice's declared treasure values (painting 4+6, egg
    /// 5+5) — a stand-in for the real 350 until more treasures exist.
    let maxScore = 20
    let intro = """
        An adventure awaits amid a ruined empire buried underground. This
        slice covers only the White House, its immediate surroundings, and
        the first rooms below.
        """

    let aboveGround = ZorkAboveGround()
    let house = ZorkHouse()
    let cellar = ZorkCellar()

    /// The grue. Zork's prose, the plugin's stock warn-then-kill schedule.
    let dangerousDark = DangerousDark(
        warning: Prose.grueWarning,
        death: Prose.grueDeath
    )

    let scoring = Scoring()
    let melee = MeleeCombat()
    let actors = ActorBehaviors()

    var content: GameContents {
        aboveGround
        house
        cellar
        dangerousDark
        scoring
        melee
    }

    var rules: Rules {
        // The two treasures the slice can score, and where they pay out.
        // Cross-bundle wiring is the host's job, same as the exits below.
        scoring.treasures([cellar.painting, aboveGround.egg], into: house.trophyCase)

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

        player.starts(in: aboveGround.westOfHouse)
    }
}
