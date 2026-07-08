import Gnusto

extension Intent {
    /// `GreetingPlugin`'s verb. (`CustomActionGame` reuses `.ring` from
    /// `CustomVerbGames.swift` — #verb constants are module-wide statics on
    /// `Intent`, so a shared verb is declared once and listed everywhere.)
    #verb("greet", ["greet", .directObject])
}

/// A game that teaches the parser a custom verb (`ring`) and, unlike
/// ``CustomVerbGame``, gives it real stage-4 default behavior through the
/// `actions` block instead of leaving it to fall through to "I didn't
/// understand". Proves a custom intent can get a default without any
/// `before`/`after` rule at all.
struct CustomActionGame: Game {
    let title = "Custom Action"
    let intro = "A small chapel."

    let chapel = Location {
        name("Chapel")
        description("A small stone chapel.")
    }

    let bell = Item {
        name("bronze bell")
        adjectives("bronze")
    }

    var map: WorldMap {
        player.starts(in: chapel)
        bell.starts(in: chapel)
    }

    var verbs: [SyntaxRule] {
        .ring
    }

    var actions: [IntentAction] {
        action(.ring) {
            say("The bell chimes sweetly.")
        }
    }
}

/// A game whose `actions` block replaces the built-in `take` default with a
/// themed message, proving a game can override a built-in's stage-4 behavior
/// (not just its vocabulary) and that the override is recorded as a non-fatal
/// warning.
struct ThemedTakeGame: Game {
    let title = "Themed Take"
    let intro = "A vault."

    let vault = Location {
        name("Vault")
        description("A cramped stone vault.")
    }

    let coin = Item {
        name("gold coin")
        adjectives("gold")
    }

    var map: WorldMap {
        player.starts(in: vault)
        coin.starts(in: vault)
    }

    var actions: [IntentAction] {
        action(.take) { [coin] in
            try reply("You pocket the \(coin.name) with a guilty glance.")
        }
    }
}

/// A plugin that ships a whole verb behavior — vocabulary (`greet`) and a
/// stage-4 default — with no host rules at all, exercising `GamePlugin.actions`
/// spliced by the host exactly like `verbs`.
struct GreetingPlugin: GamePlugin {
    var verbs: [SyntaxRule] {
        .greet
    }

    var actions: [IntentAction] {
        action(.greet) {
            say("You wave and offer a warm greeting.")
        }
    }
}

/// A host that splices only `verbs` + `actions` from ``GreetingPlugin`` — no
/// rules of its own handle `greet` — proving the plugin-provided default runs
/// end to end.
struct GreeterGame: Game {
    let title = "Greeter"
    let intro = "A sunny courtyard."

    let plugin = GreetingPlugin()

    let courtyard = Location {
        name("Courtyard")
        description("A sunny courtyard.")
    }

    let statue = Item {
        name("stone statue")
        adjectives("stone")
    }

    var map: WorldMap {
        player.starts(in: courtyard)
        statue.starts(in: courtyard)
    }

    var verbs: [SyntaxRule] {
        plugin.verbs
    }

    var actions: [IntentAction] {
        plugin.actions
    }
}

/// The `proceed()` acceptance fixture from the Task 5 brief: a `before(.open)`
/// rule runs the built-in `open` default via `proceed()`, then embellishes
/// the result with an extra line.
struct MailboxGame: Game {
    let title = "Mailbox"
    let intro = "A quiet street."

    let street = Location {
        name("Street")
        description("A quiet street.")
    }

    let mailbox = Item {
        name("small mailbox")
        adjectives("small")
        container
        openable
    }

    let map1 = Item {
        name("city map")
    }

    var map: WorldMap {
        player.starts(in: street)
        mailbox.starts(in: street)
        map1.starts(inside: mailbox)
    }

    var rules: Rules {
        mailbox.before(.open) {
            try proceed()
            say("A city map is tucked inside the lid.")
        }
    }
}

/// A fixture proving `proceed()` propagates a `TurnInterrupt` thrown by the
/// default action it invokes — here, the built-in `open` refuses because the
/// mailbox is locked, and the embellishment line after `proceed()` never runs.
struct LockedMailboxGame: Game {
    let title = "Locked Mailbox"
    let intro = "A quiet street."

    let street = Location {
        name("Street")
        description("A quiet street.")
    }

    let mailbox = Item {
        name("small mailbox")
        adjectives("small")
        container
        openable
    }

    let key = Item {
        name("brass key")
    }

    var map: WorldMap {
        player.starts(in: street)
        mailbox.starts(in: street)
        mailbox.lockedBy(key)
        key.starts(in: street)
    }

    var rules: Rules {
        mailbox.before(.open) {
            try proceed()
            say("This line must never print.")
        }
    }
}

/// A fixture proving that once `proceed()` runs the default action early
/// from an *earlier* before-phase (here, `world.before`), the pipeline skips
/// every remaining stage 1–3 before-phase for the rest of the turn — an
/// `item.before` guard declared on the direct object must never run once the
/// default has already fired. If the guard ran, its refusal/marker would
/// appear in the transcript after the take succeeds; it must not.
struct EarlyProceedSkipsLaterGuardsGame: Game {
    let title = "Early Proceed"
    let intro = "A workshop."

    let workshop = Location {
        name("Workshop")
        description("A cluttered workshop.")
    }

    let wrench = Item {
        name("iron wrench")
        adjectives("iron")
    }

    var map: WorldMap {
        player.starts(in: workshop)
        wrench.starts(in: workshop)
    }

    var rules: Rules {
        world.before(.take) {
            try proceed()
            say("The world itself lets you take it.")
        }
        wrench.before(.take) {
            say("GUARD RAN")
            try refuse("The wrench is bolted down.")
        }
    }
}

/// A fixture proving `proceed()` also skips a *sibling* rule in the SAME
/// before-phase — not just later phases. Two `world.before(.take)` rules land
/// in the one `worldBefore` sequence; the first calls `proceed()`, and the
/// second (which would mark itself and refuse) must never run once the default
/// has fired. If the sibling ran, "SIBLING RAN" would appear after the take
/// succeeds; it must not.
struct EarlyProceedSkipsSiblingInSamePhaseGame: Game {
    let title = "Early Proceed Sibling"
    let intro = "A workshop."

    let workshop = Location {
        name("Workshop")
        description("A cluttered workshop.")
    }

    let wrench = Item {
        name("iron wrench")
        adjectives("iron")
    }

    var map: WorldMap {
        player.starts(in: workshop)
        wrench.starts(in: workshop)
    }

    var rules: Rules {
        world.before(.take) {
            try proceed()
            say("The first world rule lets you take it.")
        }
        world.before(.take) {
            say("SIBLING RAN")
            try refuse("The second world rule refuses.")
        }
    }
}
