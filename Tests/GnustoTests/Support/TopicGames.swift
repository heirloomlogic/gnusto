import Gnusto

/// A house with two people in it and three shapes of topic row: a subject
/// addressed to somebody (`ask butler about …`), a subject addressed to
/// nobody (`think about …`), and a bare subject with no introducing word
/// (`mutter …`).
struct ManorParserGame: Game {
    let title = "Manor"
    let intro = ""

    let hall = Location {
        name("Hall")
        description("A hall.")
    }

    let scullery = Location {
        name("Scullery")
        description("A scullery.")
    }

    let butler = Actor {
        name("butler")
        description("The butler.")
    }

    /// Out of the player's sight, so a topic row with an unresolvable object
    /// still fails on the object.
    let footman = Actor {
        name("footman")
        description("The footman.")
    }

    let lamp = Item {
        name("lamp")
        adjectives("brass")
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("ask", .directObject, "about", .topic, intent: Intent("ask"))
        SyntaxRule("think", "about", .topic, intent: Intent("think"))
        SyntaxRule("mutter", .topic, intent: Intent("mutter"))
    }

    var rules: Rules {
        butler.before(Intent("ask")) {
            try reply("The butler considers \"\(command.topic?.text ?? "-")\".")
        }
    }

    var map: WorldMap {
        hall.north(scullery)
        scullery.south(hall)

        player.starts(in: hall)
        butler.starts(in: hall)
        lamp.starts(in: hall)
        footman.starts(in: scullery)
    }
}

/// Every way a topic row can be malformed, in one game so the bootstrap
/// reports them together. Kept separate from `BadPatternsGame` so that
/// suite's own diagnostic count stays exactly as pinned.
struct BadTopicPatternsGame: Game {
    let title = "Bad Topics"
    let intro = ""

    let den = Location {
        name("Den")
        description("A den.")
    }

    var map: WorldMap {
        player.starts(in: den)
    }

    var verbs: [SyntaxRule] {
        // A topic that doesn't end the pattern.
        SyntaxRule("ask", .topic, "about", intent: Intent("bad1"))
        // Two topics.
        SyntaxRule("say", .topic, .topic, intent: Intent("bad2"))
        // A topic alongside a second object.
        SyntaxRule(
            "tell", .directObject, "to", .indirectObject, "about", .topic,
            intent: Intent("bad3"))
        // A topic alongside a direction.
        SyntaxRule("dig", .direction, "about", .topic, intent: Intent("bad4"))
        // An object slot running straight into a topic, with no word between.
        SyntaxRule("quiz", .directObject, .topic, intent: Intent("bad5"))
    }
}
