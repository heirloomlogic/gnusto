import Gnusto
import GnustoActors

/// Fixtures for `GnustoActors`. `WanderGame` exercises roaming (100% so
/// every turn moves, announcements asserted under a pinned seed);
/// `PickpocketGame` exercises theft, reactions, and daemon stopping.
struct WanderGame: Game {
    let title = "Wander"
    let intro = "Someone is pacing the grounds."

    let yard = Location {
        name("Yard")
        description("Patchy grass.")
    }

    let armory = Location {
        name("Armory")
        description("Racks, mostly empty.")
    }

    let chapel = Location {
        name("Chapel")
        description("Cold candles.")
    }

    let crypt = Location {
        name("Crypt")
        description("You should not be able to read this.")
        dark
    }

    let wanderer = Actor {
        name("restless wanderer")
        adjectives("restless")
        description("Never still.")
    }

    let behaviors = ActorBehaviors()

    var map: WorldMap {
        yard.north(armory)
        armory.south(yard)
        armory.east(chapel)
        chapel.west(armory)
        chapel.down(crypt)
        crypt.up(chapel)

        player.starts(in: yard)
        wanderer.starts(in: armory)
    }

    var timers: [TimedEvent] {
        behaviors.roams(
            wanderer,
            daemonName: "wander",
            rooms: [yard, armory, chapel, crypt],
            chancePerTurn: 100,
            arrival: "The wanderer saunters in.",
            departure: "The wanderer slips away.")
    }
}

struct PickpocketGame: Game {
    let title = "Pickpocket"
    let intro = "Mind your pockets."

    let plaza = Location {
        name("Plaza")
        description("Sun and pigeons.")
    }

    let thief = Actor {
        name("nimble thief")
        adjectives("nimble")
        description("All fingers.")
    }

    let locket = Item {
        name("silver locket")
        adjectives("silver")
    }

    let coin = Item {
        name("bent coin")
        adjectives("bent")
    }

    /// A steal candidate lying on the floor of the thief's room — reachable
    /// now that theft is no longer held-only.
    let pebble = Item {
        name("dull pebble")
        adjectives("dull")
    }

    /// A closed strongbox on the floor, and the gem locked inside it. The gem
    /// is a steal candidate but stays immune by construction: the thief cannot
    /// rifle a shut container.
    let strongbox = Item {
        name("iron strongbox")
        adjectives("iron")
        container
        openable
    }

    let gem = Item {
        name("green gem")
        adjectives("green")
    }

    let behaviors = ActorBehaviors()

    var map: WorldMap {
        player.starts(in: plaza)
        thief.starts(in: plaza)
        locket.startsHeld
        coin.startsHeld
        pebble.starts(in: plaza)
        strongbox.starts(in: plaza)
        gem.starts(inside: strongbox)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("greet", .directObject, intent: Intent("greet"))
        SyntaxRule("accuse", intent: Intent("accuse"))
        SyntaxRule("whistle", intent: Intent("whistle"))
    }

    var timers: [TimedEvent] {
        behaviors.steals(
            thief,
            daemonName: "pick",
            candidates: [locket, coin, pebble, gem],
            containers: [strongbox],
            chancePerTurn: 100,
            announcement: { "Featherlight fingers make off with the \($0)." })
    }

    var rules: Rules {
        behaviors.reaction(
            of: thief, to: [Intent("greet")],
            reply: "He nods, warily.")
        world.before(Intent("accuse")) {
            let haul = thief.inventory.map(\.name).joined(separator: ", ")
            try reply("Haul: \(haul.isEmpty ? "nothing" : haul).")
        }
        world.before(Intent("whistle")) {
            stopDaemon("pick")
            try reply("The whistle freezes every hand in the plaza.")
        }
    }
}
