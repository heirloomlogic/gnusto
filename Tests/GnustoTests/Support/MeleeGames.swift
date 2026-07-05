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

/// Fixture for the `while:` aggression gate: a heckler whose counter-attack
/// only fires while `enraged` is set. `provoke`/`soothe` flip the gate. The
/// gate closes over `enraged` and is evaluated before any RNG draw, so quiet
/// turns leave the seeded stream untouched — a gate test can prove the draw
/// sequence resumes exactly where it left off.
struct GatedArenaGame: Game {
    let title = "Gated Arena"
    let intro = "A ring, a heckler, and a temper switch."

    let ring = Location {
        name("Ring")
        description("Ropes on four sides.")
    }

    let heckler = Actor {
        name("brawny heckler")
        adjectives("brawny")
        description("Spoiling for it, but only when riled.")
    }

    let club = Item {
        name("oak club")
        adjectives("oak")
        trait(.weapon, true)
    }

    @Global var enraged = false

    let melee = MeleeCombat()

    var content: GameContents {
        melee
    }

    var map: WorldMap {
        player.starts(in: ring)
        heckler.starts(in: ring)
        club.starts(in: ring)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("provoke", intent: Intent("provoke"))
        SyntaxRule("soothe", intent: Intent("soothe"))
    }

    var rules: Rules {
        melee.villain(
            heckler, key: "heckler", strength: 3,
            weapons: [club],
            prose: MeleeCombat.VillainProse(
                miss: ["Your swing whiffs."],
                wound: ["The heckler grunts."],
                knockout: "The heckler slumps against the ropes.",
                death: "The heckler goes down for good."))
        world.before(Intent("provoke")) {
            enraged = true
            try reply("You provoke the heckler.")
        }
        world.before(Intent("soothe")) {
            enraged = false
            try reply("You soothe the heckler.")
        }
    }

    var timers: [TimedEvent] {
        melee.aggression(
            of: heckler, key: "heckler", daemonName: "melee.heckler",
            while: { enraged },
            prose: MeleeCombat.AggressionProse(
                miss: ["The heckler jabs and misses."],
                wound: ["The heckler cuffs you."],
                playerDeath: "The heckler flattens you."))
    }
}
