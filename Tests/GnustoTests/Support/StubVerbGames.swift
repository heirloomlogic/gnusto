import Gnusto

/// A room with one of everything a stub verb might name: something takeable,
/// somebody to be rude to, a container, and a fixture. Declares no verbs and no
/// actions at all — the point is what a game gets for *free*.
struct StubLab: Game {
    let title = "Stub Lab"
    let intro = "A bare room for trying words in."

    let lab = Location {
        name("Laboratory")
        description("A bare room with a bench along one wall.")
    }

    let rod = Item {
        name("brass rod")
        adjectives("brass")
        description("A plain brass rod.")
    }

    // No `openable`, so it's always open — the stub verbs that name it don't
    // care, and this keeps `pour`/`empty` off the closed-container path.
    let flask = Item {
        name("glass flask")
        adjectives("glass")
        container
    }

    let bench = Item {
        name("long bench")
        adjectives("long")
        scenery
        surface
    }

    let rat = Actor {
        name("grey rat")
        adjectives("grey")
        description("A grey rat, watching you.")
    }

    var map: WorldMap {
        player.starts(in: lab)
        rod.starts(in: lab)
        flask.starts(in: lab)
        bench.starts(in: lab)
        rat.starts(in: lab)
    }
}

/// The scope-honesty fixture. The grue is declared but never placed, so "grue"
/// is a word the game knows and an object that is never in view — which is
/// exactly the case that must answer "You can't see any such thing." rather than
/// a stub verb's canned line.
struct GrueLab: Game {
    let title = "Grue Lab"
    let intro = "A bare room, and something not in it."

    let lab = Location {
        name("Laboratory")
        description("A bare room.")
    }

    let grue = Item {
        name("lurking grue")
        adjectives("lurking")
        synonyms("lurker")
        description("You should not be able to see this.")
    }

    var map: WorldMap {
        player.starts(in: lab)
    }
}

/// Re-skins one stub line and leaves the rest alone.
struct ReskinnedStubGame: Game {
    let title = "Reskinned"
    let intro = "A room with a house style."

    let room = Location {
        name("Room")
        description("A plain room.")
    }

    var text: GameText {
        var text = GameText()
        text.stubs.sing = "You are asked, politely, to stop."
        return text
    }

    var map: WorldMap {
        player.starts(in: room)
    }
}

/// Promotes one stub with an `actions` row and another with an item rule, so a
/// single transcript shows both layers beating the engine's line — and shows the
/// rule beating the row.
struct StubPrecedenceGame: Game {
    let title = "Stub Precedence"
    let intro = "A room with a dummy and a rock."

    let room = Location {
        name("Room")
        description("A plain room.")
    }

    let dummy = Item {
        name("straw dummy")
        adjectives("straw")
        description("A straw dummy on a post.")
    }

    let rock = Item {
        name("grey rock")
        adjectives("grey")
        description("An ordinary rock.")
    }

    var actions: [IntentAction] {
        action(.attack) { try reply("You flail at the scenery.") }
    }

    var rules: Rules {
        dummy.before(.attack) {
            try reply("The dummy takes it well.")
        }
    }

    var map: WorldMap {
        player.starts(in: room)
        dummy.starts(in: room)
        rock.starts(in: room)
    }
}

/// Claims a stub verb's exact row shape for an intent of its own. Reclaiming a
/// stub must be silent: there is no behavior to shadow.
struct OwnAttackRowGame: Game {
    let title = "Own Attack Row"
    let intro = "A room where attacking means something else."

    let room = Location {
        name("Room")
        description("A plain room.")
    }

    let dummy = Item {
        name("straw dummy")
        adjectives("straw")
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("attack", .directObject, intent: Intent("brawl"))
    }

    var rules: Rules {
        dummy.before(Intent("brawl")) {
            try reply("You brawl with the dummy.")
        }
    }

    var map: WorldMap {
        player.starts(in: room)
        dummy.starts(in: room)
    }
}

/// Watches a stub intent from an item rule and nothing else — no `verbs` entry,
/// no `actions` row. The engine already produces the rows, so this must not warn
/// about a dead intent.
struct AttackableDummyGame: Game {
    let title = "Attackable Dummy"
    let intro = "A room with a dummy."

    let room = Location {
        name("Room")
        description("A plain room.")
    }

    let dummy = Item {
        name("straw dummy")
        adjectives("straw")
    }

    var rules: Rules {
        dummy.before(.attack) {
            try reply("The dummy takes it well.")
        }
    }

    var map: WorldMap {
        player.starts(in: room)
        dummy.starts(in: room)
    }
}
