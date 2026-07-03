import Gnusto
import GnustoMeleeCombat

/// Fixture for `GnustoMeleeCombat`: one arena, a sparring dummy villain
/// (strength 3) that hits back, a real sword, and a feather that is very
/// much not a weapon. `defeated` records the onDefeat callback firing.
struct ArenaGame: Game {
    let title = "Arena"
    let intro = "Sand, chalk lines, and poor decisions."

    let arena = Location {
        name("Arena")
        description("Sand raked into chalk lines.")
    }

    let dummy = Actor {
        name("sparring dummy")
        adjectives("sparring")
        description("Sand-filled and strangely confident.")
    }

    let sword = Item {
        name("dull sword")
        adjectives("dull")
        trait(.weapon, true)
    }

    let feather = Item {
        name("goose feather")
        adjectives("goose")
    }

    @Global var defeated = false

    let melee = MeleeCombat()

    var content: GameContents {
        melee
    }

    var map: WorldMap {
        player.starts(in: arena)
        dummy.starts(in: arena)
        sword.starts(in: arena)
        feather.starts(in: arena)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("gloat", intent: Intent("gloat"))
    }

    var rules: Rules {
        melee.villain(
            dummy, key: "dummy", strength: 3,
            weapons: [sword],
            prose: MeleeCombat.VillainProse(
                miss: ["Your swing kicks up sand."],
                wound: ["Burlap tears."],
                knockout: "The dummy wobbles, out on its feet.",
                death: "The dummy bursts in a spray of sand."),
            onDefeat: { defeated = true })
        world.before(Intent("gloat")) {
            try reply("Defeated: \(defeated).")
        }
    }

    var timers: [TimedEvent] {
        melee.aggression(
            of: dummy, key: "dummy", daemonName: "melee.dummy",
            prose: MeleeCombat.AggressionProse(
                miss: ["The dummy swings wide."],
                wound: ["The dummy clips your ear."],
                playerDeath: "The dummy lands one square on your temple."))
    }
}
