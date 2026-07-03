import Gnusto

/// A logic-only plugin exercising the Phase-8 plugin seams: a plugin-minted
/// `attack` intent with verbs and a stage-4 default, a daemon the host
/// splices through its `timers` block, and a parameterized rule factory
/// that calls `describeSurroundings()`.
struct BrawlPlugin: GamePlugin {
    static let attack = Intent("attack")

    var verbs: [SyntaxRule] {
        SyntaxRule("attack", .directObject, intent: Self.attack)
    }

    /// The futile default a host rule can override per actor.
    var actions: [IntentAction] {
        action(Self.attack) {
            try reply("Violence gets you nowhere here.")
        }
    }

    var timers: [TimedEvent] {
        daemon("brawl.pulse", autostart: true) {
            say("[pulse]")
        }
    }

    /// A "current" that drags the player somewhere and re-describes.
    @RuleBuilder
    func drift(to destination: Location, on intent: Intent) -> Rules {
        world.before(intent) {
            player.location = destination
            say("The floor tilts and deposits you elsewhere.")
            describeSurroundings()
            try reply("")
        }
    }
}

/// Host for `BrawlPlugin`: one bruiser actor with a host override, one
/// unprotected dummy that falls through to the plugin default, and a dark
/// side room for the darkness path of `describeSurroundings()`.
struct BrawlGame: Game {
    let title = "Brawl"
    let intro = "A gymnasium of regrettable decisions."

    let gym = Location {
        name("Gymnasium")
        description("Mats everywhere.")
    }

    let storeroom = Location {
        name("Storeroom")
        description("Shelves in the gloom.")
        dark
    }

    let bruiser = Actor {
        name("bruiser")
        description("Knuckles like walnuts.")
    }

    let dummy = Actor {
        name("training dummy")
        adjectives("training")
        description("Sand-filled.")
    }

    let brawl = BrawlPlugin()

    var map: WorldMap {
        gym.north(storeroom)
        storeroom.south(gym)
        player.starts(in: gym)
        bruiser.starts(in: gym)
        dummy.starts(in: gym)
    }

    var verbs: [SyntaxRule] {
        brawl.verbs
        SyntaxRule("slide", intent: Intent("slide"))
        SyntaxRule("slip", intent: Intent("slip"))
    }

    var actions: [IntentAction] {
        brawl.actions
    }

    var timers: [TimedEvent] {
        brawl.timers
    }

    var rules: Rules {
        // Host override beats the plugin's futile default for this actor.
        bruiser.before(BrawlPlugin.attack) {
            try reply("The bruiser catches your fist like a thrown apple.")
        }
        brawl.drift(to: gym, on: Intent("slide"))
        brawl.drift(to: storeroom, on: Intent("slip"))
    }
}

/// Broken on purpose: the host's own daemon reuses the plugin's timer name.
struct ClashingTimersGame: Game {
    let title = "Clash"
    let intro = "?"

    let gym = Location {
        name("Gymnasium")
        description("Mats everywhere.")
    }

    let brawl = BrawlPlugin()

    var map: WorldMap {
        player.starts(in: gym)
    }

    var timers: [TimedEvent] {
        brawl.timers
        daemon("brawl.pulse") {
            say("[thump]")
        }
    }
}
