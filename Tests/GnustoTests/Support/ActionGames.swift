import Gnusto

/// A game that teaches the parser a custom verb (`ring`) and, unlike
/// ``CustomVerbGame``, gives it real stage-4 default behavior through the
/// `actions` block instead of leaving it to fall through to "I didn't
/// understand". Proves a custom intent can get a default without any
/// `before`/`after` rule at all.
struct CustomActionGame: Game {
    let title = "Custom Action"
    let intro = "A small chapel."

    static let ring = Intent("ring")

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
        SyntaxRule("ring", slots: .direct, intent: Self.ring)
    }

    var actions: [IntentAction] {
        action(Self.ring) {
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
    static let greet = Intent("greet")

    var verbs: [SyntaxRule] {
        SyntaxRule("greet", slots: .direct, intent: Self.greet)
    }

    var actions: [IntentAction] {
        action(Self.greet) {
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

private let lockedMailboxKey = Item {
    name("brass key")
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
        lockable(with: lockedMailboxKey)
    }

    let key = lockedMailboxKey

    var map: WorldMap {
        player.starts(in: street)
        mailbox.starts(in: street)
        key.starts(in: street)
    }

    var rules: Rules {
        mailbox.before(.open) {
            try proceed()
            say("This line must never print.")
        }
    }
}
