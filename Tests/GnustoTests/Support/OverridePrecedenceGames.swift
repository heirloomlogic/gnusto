import Gnusto

/// A content bundle contributing a custom verb (`chime`) *and* its stage-4
/// default action, so a host that lists this bundle gets a working `chime`
/// with no rules of its own — the bundle's action applies. The intent is
/// shared file-scope so a host can override the same intent to prove
/// precedence (built-ins < bundles < host game).
let chimeIntent = Intent("chime")

struct ChimeBundle: GameContent {
    let belfry = Location {
        name("Belfry")
        description("A drafty belfry.")
    }

    let bell = Item {
        name("iron bell")
        adjectives("iron")
    }

    var map: WorldMap {
        bell.starts(in: belfry)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("chime", .directObject, intent: chimeIntent)
    }

    var actions: [IntentAction] {
        action(chimeIntent) {
            say("The bundle's bell tolls low and slow.")
        }
    }
}

/// A host that lists ``ChimeBundle`` and adds no action of its own for
/// `chime` — so the bundle-provided default is what runs.
struct BundleActionHostGame: Game {
    let title = "Bundle Action Host"
    let intro = "A drafty belfry."

    let chime = ChimeBundle()

    var content: GameContents {
        chime
    }

    var map: WorldMap {
        player.starts(in: chime.belfry)
    }

    var verbs: [SyntaxRule] {
        chime.verbs
    }
}

/// A host that lists ``ChimeBundle`` but also defines its *own* action for the
/// same `chime` intent. Precedence is built-ins < bundles < host game, so the
/// host's action must win (last-wins after the reorder), and the override is
/// recorded as a non-fatal warning.
struct HostOverridesBundleActionGame: Game {
    let title = "Host Overrides Bundle Action"
    let intro = "A drafty belfry."

    let chime = ChimeBundle()

    var content: GameContents {
        chime
    }

    var map: WorldMap {
        player.starts(in: chime.belfry)
    }

    var verbs: [SyntaxRule] {
        chime.verbs
    }

    var actions: [IntentAction] {
        action(chimeIntent) {
            say("The host's bell rings bright and clear.")
        }
    }
}
