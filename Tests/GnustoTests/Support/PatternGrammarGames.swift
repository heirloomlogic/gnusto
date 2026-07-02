import Gnusto

/// Exercises the Phase 6 pattern grammar: verb shapes the old five-slot enum
/// couldn't express — two objects around a preposition, a particle on either
/// side of the object, and multi-word verb literals.
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

    var map: WorldMap {
        player.starts(in: workshop)
        lamp.starts(in: workshop)
        rug.starts(in: workshop)
        gnome.starts(in: workshop)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("give", .directObject, "to", .indirectObject, intent: Intent("give"))
        SyntaxRule("turn", .directObject, "on", intent: Intent("turnOn"))
        SyntaxRule("turn", "on", .directObject, intent: Intent("turnOn"))
        SyntaxRule("look", "under", .directObject, intent: Intent("lookUnder"))
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
