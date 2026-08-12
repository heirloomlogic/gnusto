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

/// Fixture for engagement — the source's `FIGHTBIT`. The bandit's
/// `strikesFirst` is 0, so he never starts anything of his own accord: an
/// aggression line in the transcript means the player engaged him, and never
/// that a roll went his way. That is `CutpurseGame`'s `chancePerTurn: 100`
/// trick from the other end.
///
/// Two rooms, because a fight is cleared by the two of them no longer sharing
/// one, and there is no way to test that in an arena. `playerStrength: 20` so
/// the player survives long enough to watch a fight run; the outright-kill
/// branch can still end a run early, which is what the pinned seeds buy.
///
/// He also carries a `while:` gate on `truce`, which `parley` shuts and
/// `resume` reopens. It is open unless a test flips it, and an open gate draws
/// nothing, so it costs the other tests here nothing. What it buys is the one
/// claim only a `strikesFirst: 0` villain can make: that a shut gate suspends a
/// fight without ending it.
struct AmbushGame: Game {
    let title = "Ambush"
    let intro = "A clearing, a thicket, and someone waiting in one of them."

    let clearing = Location {
        name("Clearing")
        description("Trodden grass, and a gap in the trees to the east.")
    }

    let thicket = Location {
        name("Thicket")
        description("Blackthorn on every side but the one you came in by.")
    }

    let bandit = Actor {
        name("patient bandit")
        adjectives("patient")
        description("He has all day, and knows it.")
    }

    let cosh = Item {
        name("leather cosh")
        adjectives("leather")
        trait(.weapon, true)
    }

    let twig = Item {
        name("birch twig")
        adjectives("birch")
    }

    @Global var truce = false

    let melee = MeleeCombat()

    var content: GameContents {
        melee
    }

    var map: WorldMap {
        clearing.east(thicket)
        player.starts(in: clearing)
        bandit.starts(in: clearing)
        cosh.starts(in: clearing)
        twig.starts(in: clearing)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("parley", intent: Intent("parley"))
        SyntaxRule("resume", intent: Intent("resume"))
    }

    var rules: Rules {
        melee.villain(
            bandit, key: "bandit", strength: 4,
            weapons: [cosh],
            prose: MeleeCombat.VillainProse(
                miss: ["The cosh thumps into bark."],
                wound: ["The bandit takes it on the forearm."],
                knockout: "The bandit sits down hard and stops moving.",
                death: "The bandit folds into the grass."))
        world.before(Intent("parley")) {
            truce = true
            try reply("You put your hands up.")
        }
        world.before(Intent("resume")) {
            truce = false
            try reply("You put your hands down.")
        }
    }

    var timers: [TimedEvent] {
        melee.aggression(
            of: bandit, key: "bandit", daemonName: "melee.bandit",
            strikesFirst: 0,
            playerStrength: 20,
            while: { !truce },
            prose: MeleeCombat.AggressionProse(
                miss: ["The bandit lunges and comes up short."],
                wound: ["The bandit opens a cut along your arm."],
                playerDeath: "The bandit puts his knife somewhere final."))
    }
}

/// Fixture for the strike-first probability itself: a skulker at the thief's
/// `PROB 20`, waiting one room away. Two rooms so the roll can be watched
/// starting and stopping at a threshold the player crosses on foot — which is
/// also what proves the roll sits behind the same-room guard rather than
/// burning a draw on every turn nobody is standing with him.
struct SkulkerGame: Game {
    let title = "Skulker"
    let intro = "A hollow, a den, and a reason not to go into the den."

    let hollow = Location {
        name("Hollow")
        description("Damp leaf litter. The den opens east.")
    }

    let den = Location {
        name("Den")
        description("Low, dry, and occupied.")
    }

    let skulker = Actor {
        name("lean skulker")
        adjectives("lean")
        description("Waiting to see what you do.")
    }

    let dirk = Item {
        name("bone dirk")
        adjectives("bone")
        trait(.weapon, true)
    }

    let melee = MeleeCombat()

    var content: GameContents {
        melee
    }

    var map: WorldMap {
        hollow.east(den)
        player.starts(in: hollow)
        skulker.starts(in: den)
        dirk.startsHeld
    }

    var rules: Rules {
        melee.villain(
            skulker, key: "skulker", strength: 4,
            weapons: [dirk],
            prose: MeleeCombat.VillainProse(
                miss: ["The dirk finds nothing but air."],
                wound: ["The skulker hisses through his teeth."],
                knockout: "The skulker drops where he stood.",
                death: "The skulker lets go of everything at once."))
    }

    var timers: [TimedEvent] {
        melee.aggression(
            of: skulker, key: "skulker", daemonName: "melee.skulker",
            strikesFirst: 20,
            playerStrength: 20,
            prose: MeleeCombat.AggressionProse(
                miss: ["The skulker darts in and misses."],
                wound: ["The skulker scores your ribs."],
                playerDeath: "The skulker finds the gap he was waiting for."))
    }
}

/// Fixture for the `while:` aggression gate: a heckler whose counter-attack
/// only fires while `enraged` is set. `provoke`/`soothe` flip the gate. The
/// gate closes over `enraged` and is evaluated before any RNG draw, so quiet
/// turns leave the seeded stream untouched — a gate test can prove the draw
/// sequence resumes exactly where it left off.
///
/// His `strikesFirst` is 25 rather than the default 100, which is what makes
/// the alignment test say anything about the strike-first roll: at 100 the roll
/// is skipped entirely and a gate test could not tell whether it sits before or
/// behind the gate.
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
            strikesFirst: 25,
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
