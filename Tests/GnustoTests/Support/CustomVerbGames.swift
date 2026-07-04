import Gnusto

// Custom verbs, declared once. Each #verb yields a typed intent constant
// (`.ring`) carrying its rows; the games below list the intents they teach in
// their `verbs` blocks and key rules on the same constants.
extension Intent {
    #verb("ring", ["ring", .directObject])
    #verb("polish", ["polish", .directObject, "with", .indirectObject])
    #verb("sing")
    // Same verb token and slot shape as the built-in `take`, so listing this
    // row reclaims it (last-wins) and emits `.steal` instead.
    #verb("steal", ["take", .directObject])
}

/// Exercises vocabulary extension: a game that teaches the parser new
/// player-typeable verbs by listing `#verb`-declared intents in its `verbs`
/// block, with the behavior living in ordinary `before` rules keyed on the
/// same intents.
struct CustomVerbGame: Game {
    let title = "Custom Verbs"
    let intro = "A small chapel for trying out new words."

    let chapel = Location {
        name("Chapel")
        description("A small stone chapel.")
    }

    let bell = Item {
        name("bronze bell")
        adjectives("bronze")
        description("A heavy bronze bell.")
    }

    let cloth = Item {
        name("soft cloth")
        adjectives("soft")
        description("A soft polishing cloth.")
    }

    var map: WorldMap {
        player.starts(in: chapel)
        bell.starts(in: chapel)
        cloth.starts(in: chapel)
    }

    /// Three new verbs: a plain transitive verb, a verb with a preposition
    /// shape (proving the preposition is harvested into the vocabulary), and a
    /// verb with no handling rule (proving the unhandled path falls through to
    /// the default "I didn't understand").
    var verbs: [SyntaxRule] {
        [.ring, .polish, .sing]
    }

    var rules: Rules {
        bell.before(.ring) {
            try reply("The bell chimes sweetly.")
        }
        bell.before(.polish) {
            try reply("You polish the bell to a warm shine.")
        }
        // No rule handles `sing`: the parser still emits the intent, and the
        // default action reports that it didn't understand.
    }
}

/// A game whose custom verb deliberately collides with a built-in: the row
/// `take <thing>` is reclaimed to mean "steal" rather than the built-in take.
/// Proves last-wins override and the non-fatal collision warning.
struct VerbOverrideGame: Game {
    let title = "Override"
    let intro = "A vault with a single coin."

    let vault = Location {
        name("Vault")
        description("A cramped stone vault.")
    }

    let coin = Item {
        name("gold coin")
        adjectives("gold")
        description("A single gold coin.")
    }

    var map: WorldMap {
        player.starts(in: vault)
        coin.starts(in: vault)
    }

    var verbs: [SyntaxRule] {
        .steal
    }

    var rules: Rules {
        coin.before(.steal) {
            try reply("You pocket the coin with a guilty glance.")
        }
    }
}

/// A game that keys a rule on a `#verb` intent but forgets to list it in a
/// `verbs` block — the mistake the dead-intent bootstrap warning names.
struct ForgottenVerbGame: Game {
    let title = "Forgotten"
    let intro = "A chapel where the bell can't be rung."

    let chapel = Location {
        name("Chapel")
        description("A small stone chapel.")
    }

    let bell = Item {
        name("bronze bell")
        adjectives("bronze")
        description("A heavy bronze bell.")
    }

    var map: WorldMap {
        player.starts(in: chapel)
        bell.starts(in: chapel)
    }

    var rules: Rules {
        bell.before(.ring) {
            try reply("The bell chimes sweetly.")
        }
    }
}
