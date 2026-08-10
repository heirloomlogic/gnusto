import Gnusto

/// Exercises the Phase 6 pattern grammar: verb shapes the old five-slot enum
/// couldn't express — two objects around a preposition, a particle on either
/// side of the object, and multi-word verb literals.
///
/// It also carries the **direction slot**, in both of the shapes that can hold
/// a noun beside one.
///
/// The `push` rows are the **literal** shape: a word standing where the noun
/// goes. It matches text and never resolves it, so `Command.directObject` stays
/// nil and the rule never learns which thing was named — adjectives, synonyms
/// and disambiguation all stop at the pattern. The verb word is deliberately a
/// **core** one, so what a bare direction row displaces is visible too.
///
/// The `shift` row is the **object-slot** shape #151 added: `.directObject`
/// immediately before a trailing `.direction`. The direction slot takes exactly
/// one token and ends the pattern, so the noun phrase is everything before the
/// last token and resolves like any other. That is what makes
/// `shift iron crate north` — an adjective the pattern never spelled out —
/// reach the rule with the crate bound.
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

    /// A thing whose own name carries the particle that `turn <object> on`
    /// ends with. Splitting on the *first* `on` hands the pattern the switch's
    /// adjective and loses the noun; counting back from the end takes the
    /// literal that is actually there. Issue #215.
    let onSwitch = Item {
        name("on switch")
        description("A brass toggle, engraved ON.")
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

    /// A second crate, so a bare `crate` is ambiguous. The object-slot shape
    /// asks which one even with a direction on the end of the line; the literal
    /// shape cannot, because it never resolves anything to be ambiguous about.
    let ironCrate = Item {
        name("iron crate")
        adjectives("iron")
        description("A crate banded in iron, and heavier for it.")
    }

    var map: WorldMap {
        player.starts(in: workshop)
        lamp.starts(in: workshop)
        rug.starts(in: workshop)
        onSwitch.starts(in: workshop)
        gnome.starts(in: workshop)
        crate.starts(in: workshop)
        ironCrate.starts(in: workshop)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("give", .directObject, "to", .indirectObject, intent: Intent("give"))
        SyntaxRule("turn", .directObject, "on", intent: Intent("turnOn"))
        SyntaxRule("turn", "on", .directObject, intent: Intent("turnOn"))
        SyntaxRule("look", "under", .directObject, intent: Intent("lookUnder"))

        // A trailing-literal row on a verb word nothing else answers to, so
        // what it does with a line that stops short of the particle is
        // visible instead of being covered by a shorter core row.
        SyntaxRule("wind", .directObject, "up", intent: Intent("wind"))

        // The direction slot. Row one is the shape a sliding-block room wants;
        // row two is a wordier spelling bought back. The Swift-side intent is
        // `shove` because `push` is already a core intent — only the *verb
        // word* is shared, and a custom row that shares a word but not a shape
        // overrides nothing, silently.
        SyntaxRule("push", .direction, intent: Intent("shove"))
        SyntaxRule("push", "crate", .direction, intent: Intent("shove"))

        // The object-slot shape, on its own verb word so the rows above keep
        // pinning what the literal shape does and does not buy.
        SyntaxRule("shift", .directObject, .direction, intent: Intent("shift"))

        // The shapes a slot's *token width* can place that the rule about a
        // trailing direction could not. Each one's noun phrase ends a fixed
        // number of tokens from the end of the line — two here rather than the
        // one `shift` counts back. Issue #215.
        SyntaxRule("wedge", .directObject, .direction, "hard", intent: Intent("wedge"))
        SyntaxRule("hurl", .directObject, "at", .direction, intent: Intent("hurl"))
        SyntaxRule("lob", .directObject, "at", .indirectObject, .direction, intent: Intent("lob"))
    }

    var rules: Rules {
        gnome.before(Intent("give")) {
            try reply("The gnome accepts your gift with a stony nod.")
        }
        lamp.before(Intent("turnOn")) {
            try reply("The lamp hums to life.")
        }
        onSwitch.before(Intent("turnOn")) {
            try reply("The switch clicks over.")
        }
        rug.before(Intent("lookUnder")) {
            try reply("Only dust under there.")
        }
        world.before(Intent("wind")) {
            try reply("Nothing here has a key to wind.")
        }

        // The bare `push` row parses with a nil direction rather than asking,
        // so the game has to ask in its place. That displacement is the pin.
        world.before(Intent("shove")) {
            guard let direction = command.direction else {
                try reply("Push it which way? North, south, east or west.")
            }
            try reply("You put your shoulder to whatever lies \(direction.rawValue).")
        }

        // The object-slot shape's counterpart: the rule can name what it was
        // handed, which is the whole of what #151 bought.
        world.before(Intent("shift")) {
            guard let target = command.directObject, let direction = command.direction else {
                return
            }
            try reply("You shove \(target.definiteName) \(direction.rawValue).")
        }

        // The wider shapes, each naming both of the slots it was handed, so a
        // split that lands one token off is visible in the prose.
        world.before(Intent("wedge")) {
            guard let target = command.directObject, let direction = command.direction else {
                return
            }
            try reply("You wedge \(target.definiteName) \(direction.rawValue), hard.")
        }
        world.before(Intent("hurl")) {
            guard let target = command.directObject, let direction = command.direction else {
                return
            }
            try reply("You hurl \(target.definiteName) off \(direction.rawValue).")
        }
        world.before(Intent("lob")) {
            guard
                let target = command.directObject,
                let recipient = command.indirectObject,
                let direction = command.direction
            else {
                return
            }
            try reply(
                "You lob \(target.definiteName) at \(recipient.definiteName), "
                    + "who ducks \(direction.rawValue).")
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
        // Two object slots with nothing between them: the first has a suffix
        // that is not fixed-width and no literal word to close it on.
        SyntaxRule("give", .directObject, .indirectObject, intent: Intent("bad2"))
        // Two direction slots. Width has nothing to say about this one — the
        // parser fills a single `direction`, so the second would overwrite the
        // first and the rule would never learn there had been two.
        SyntaxRule("cross", .direction, "then", .direction, intent: Intent("bad3"))
    }
}
