import Gnusto

/// Exercises the Phase 6 pattern grammar: verb shapes the old five-slot enum
/// couldn't express — two objects around a preposition, a particle on either
/// side of the object, and multi-word verb literals.
///
/// It also carries the **direction slot**, whose rules are peculiar enough to
/// have their own issue (#151). A direction slot may not share a pattern with
/// an object slot — `BadPatternsGame` pins that refusal — but it may share one
/// with a literal word, which is the only way to write mainframe Zork's
/// `PUSH THE SANDSTONE WALL NORTH`. What the workaround does not buy is the
/// binding: a literal is matched, never resolved, so the rule never learns
/// which noun the player typed. The `push` rows below are here for exactly
/// that, and the verb word is deliberately a **core** one, so what the
/// direction row displaces is visible.
struct WorkshopGame: Game {
    let title = "Workshop"
    let intro = "A cluttered workshop."

    let workshop = Location {
        name("Workshop")
        description("Benches piled with half-finished contraptions.")
    }

    let lamp = Item {
        name("brass lamp")
        adjectives("brass")
        description("A dented brass lamp.")
    }

    let rug = Item {
        name("woven rug")
        adjectives("woven")
        scenery
        description("A rug of tight geometric weave.")
    }

    let gnome = Item {
        name("garden gnome")
        adjectives("garden")
        scenery
        description("A gnome with a knowing smirk.")
    }

    /// What the wordier `push` row names. `box` is a declared synonym the
    /// parser knows perfectly well, and `wooden` an adjective it derives from
    /// the name — neither reaches a literal row, which is why the wordier
    /// spellings cost one row each.
    let crate = Item {
        name("wooden crate")
        synonyms("box")
        adjectives("wooden")
        description("A crate of rough boards, heavy enough to need a shoulder.")
    }

    var map: WorldMap {
        player.starts(in: workshop)
        lamp.starts(in: workshop)
        rug.starts(in: workshop)
        gnome.starts(in: workshop)
        crate.starts(in: workshop)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("give", .directObject, "to", .indirectObject, intent: Intent("give"))
        SyntaxRule("turn", .directObject, "on", intent: Intent("turnOn"))
        SyntaxRule("turn", "on", .directObject, intent: Intent("turnOn"))
        SyntaxRule("look", "under", .directObject, intent: Intent("lookUnder"))

        // The direction slot. Row one is the shape a sliding-block room wants;
        // row two is a wordier spelling bought back. The Swift-side intent is
        // `shove` because `push` is already a core intent — only the *verb
        // word* is shared, and a custom row that shares a word but not a shape
        // overrides nothing, silently.
        SyntaxRule("push", .direction, intent: Intent("shove"))
        SyntaxRule("push", "crate", .direction, intent: Intent("shove"))
    }

    var rules: Rules {
        gnome.before(Intent("give")) {
            try reply("The gnome accepts your gift with a stony nod.")
        }
        lamp.before(Intent("turnOn")) {
            try reply("The lamp hums to life.")
        }
        rug.before(Intent("lookUnder")) {
            try reply("Only dust under there.")
        }

        // The bare `push` row parses with a nil direction rather than asking,
        // so the game has to ask in its place. That displacement is the pin.
        world.before(Intent("shove")) {
            guard let direction = command.direction else {
                try reply("Push it which way? North, south, east or west.")
            }
            try reply("You put your shoulder to whatever lies \(direction.rawValue).")
        }
    }
}

/// Every way to write a malformed verb pattern, in one game, so the
/// bootstrap's all-at-once diagnostic reporting is provable.
struct BadPatternsGame: Game {
    let title = "Bad Patterns"
    let intro = ""

    let den = Location {
        name("Den")
        description("A den.")
    }

    var map: WorldMap {
        player.starts(in: den)
    }

    var verbs: [SyntaxRule] {
        // Starts with a slot instead of a verb word.
        SyntaxRule(.directObject, "please", intent: Intent("bad1"))
        // Two object slots with nothing between them.
        SyntaxRule("give", .directObject, .indirectObject, intent: Intent("bad2"))
        // A direction combined with an object slot.
        SyntaxRule("throw", .directObject, .direction, intent: Intent("bad3"))
    }
}
