import Gnusto
import GnustoActors
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

/// Fixture for the seam between `GnustoMeleeCombat` and `GnustoActors`: one
/// cutpurse run through both plugins, the pair that could not see each other
/// until `Actor.isUnconscious` gave them something to agree on. He steals with
/// certainty (`chancePerTurn: 100`) so a turn with no theft line in it means
/// the guard held and not that a roll went the other way, and there are four
/// baubles so he never runs out of things to lift. His counter-attack is gated
/// on `truce`, which lets a test shut the gate and prove he still wakes up.
struct CutpurseGame: Game {
    let title = "Cutpurse"
    let intro = "A vault, a bully, and four things worth taking."

    let vault = Location {
        name("Vault")
        description("Brick, and one lamp.")
    }

    let cutpurse = Actor {
        name("scarred cutpurse")
        adjectives("scarred")
        description("Broad hands, no manners.")
    }

    let cudgel = Item {
        name("ash cudgel")
        adjectives("ash")
        trait(.weapon, true)
    }

    let chalice = Item {
        name("silver chalice")
        adjectives("silver")
    }

    let pearl = Item {
        name("black pearl")
        adjectives("black")
    }

    let comb = Item {
        name("ivory comb")
        adjectives("ivory")
    }

    let seal = Item {
        name("wax seal")
        adjectives("wax")
    }

    @Global var truce = false

    let melee = MeleeCombat()
    let behaviors = ActorBehaviors()

    var content: GameContents {
        melee
    }

    var map: WorldMap {
        player.starts(in: vault)
        cutpurse.starts(in: vault)
        cudgel.startsHeld
        chalice.startsHeld
        pearl.startsHeld
        comb.startsHeld
        seal.startsHeld
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("parley", intent: Intent("parley"))
        SyntaxRule("check", intent: Intent("check"))
    }

    var rules: Rules {
        melee.villain(
            cutpurse, key: "cutpurse", strength: 4,
            weapons: [cudgel],
            prose: MeleeCombat.VillainProse(
                miss: ["The cudgel whistles past his ear."],
                wound: ["He takes it across the shoulder."],
                knockout: "The cutpurse folds up and lies still.",
                death: "The cutpurse goes down and stays down."))
        // Shuts the counter-attack gate, so a test can prove that coming round
        // is not gated along with it.
        world.before(Intent("parley")) {
            truce = true
            try reply("You call a truce.")
        }
        world.before(Intent("check")) {
            try reply("Out cold: \(cutpurse.isUnconscious).")
        }
    }

    var timers: [TimedEvent] {
        melee.aggression(
            of: cutpurse, key: "cutpurse", daemonName: "melee.cutpurse",
            playerStrength: 20,
            while: { !truce },
            prose: MeleeCombat.AggressionProse(
                miss: ["He jabs and misses."],
                wound: ["He catches you a glancing one."],
                playerDeath: "He finishes what he started."))
        behaviors.steals(
            cutpurse,
            daemonName: "melee.cutpurse.steals",
            candidates: [chalice, pearl, comb, seal],
            chancePerTurn: 100,
            announcement: { "He lifts the \($0) clean out of your hand." })
    }
}
