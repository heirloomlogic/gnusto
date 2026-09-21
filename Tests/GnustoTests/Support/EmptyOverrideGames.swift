import Gnusto

extension Intent {
    #verb("burnish", ["burnish", .directObject])
}

// Fixtures for the explicitly-empty `verbs`/`actions`/`timers` overrides. The
// coverage they carry is that they *compile*: `var verbs: [SyntaxRule] { [] }`
// used to be `ambiguous use of 'buildExpression'`, because an empty array
// literal fits both the `[SyntaxRule]` and the `[Intent]` overload of
// `VerbBuilder.buildExpression`. Nothing at runtime can assert that, so the
// declarations below stand in for the assertion and the tests only check that
// a bundle/plugin/game declaring them still contributes nothing.
//
// Only `verbs` was ever ambiguous — `ActionBuilder` and `TimerBuilder` each
// have a single array-taking `buildExpression`, so `actions` and `timers`
// already took `[]`. They are written out here to pin that, because the
// builder they share is one generic type and a second overload added to
// either would reintroduce the same ambiguity.

/// A bundle that writes all three optional tables out as empty.
struct EmptyOverrideBundle: GameContent {
    let cellar = Location {
        name("Cellar")
        description("A dry stone cellar.")
    }

    var verbs: [SyntaxRule] { [] }
    var actions: [IntentAction] { [] }
    var timers: [TimedEvent] { [] }
}

/// A plugin that writes all three optional tables out as empty.
struct EmptyOverridePlugin: GamePlugin {
    var verbs: [SyntaxRule] { [] }
    var actions: [IntentAction] { [] }
    var timers: [TimedEvent] { [] }
}

/// A game that writes all three optional tables out as empty, and hosts the
/// bundle that does the same.
struct EmptyOverrideGame: Game {
    let title = "Empty Overrides"
    let intro = ""

    let attic = Location {
        name("Attic")
        description("A low attic.")
    }

    let lamp = Item {
        name("brass lamp")
    }

    let bundle = EmptyOverrideBundle()

    var content: GameContents { bundle }

    var verbs: [SyntaxRule] { [] }
    var actions: [IntentAction] { [] }
    var timers: [TimedEvent] { [] }

    var map: WorldMap {
        attic.down(bundle.cellar)
        bundle.cellar.up(attic)
        player.starts(in: attic)
        lamp.starts(in: attic)
    }
}

/// A game with one non-empty `verbs` spelling apiece, so the fix for the
/// empty literal is shown not to have cost the forms that already worked: a
/// bare intent, an array of intents, and a spliced `[SyntaxRule]` table.
struct NonEmptyOverrideGame: Game {
    let title = "Non-Empty Overrides"
    let intro = ""

    let attic = Location {
        name("Attic")
        description("A low attic.")
    }

    var verbs: [SyntaxRule] {
        Intent.examine
        [.take, .drop]
        Intent.burnish.syntax
    }

    var map: WorldMap {
        player.starts(in: attic)
    }
}
