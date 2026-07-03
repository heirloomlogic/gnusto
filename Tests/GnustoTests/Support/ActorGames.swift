import Gnusto

/// A content bundle owning its own room and its own actor, to prove actors
/// namespace exactly like items (`WatchContent.watchman`).
struct WatchContent: GameContent {
    let gatehouse = Location {
        name("Gatehouse")
        description("A drafty stone gatehouse.")
    }

    let watchman = Actor {
        name("old watchman")
        adjectives("old")
        description("He has watched this gate for longer than anyone knows.")
    }

    var map: WorldMap {
        watchman.starts(in: gatehouse)
    }
}

/// Part A actor fixture: a troll (described), a mule (undescribed), a sentry
/// (rule-hooked), a takable sword and rock beside them, and a bundle-owned
/// watchman behind the corridor.
struct GuardpostGame: Game {
    let title = "Guardpost"
    let intro = "Someone has to stand around menacingly. Several someones."

    let hall = Location {
        name("Hall")
        description("A bare hall.")
    }

    let corridor = Location {
        name("Corridor")
        description("A narrow corridor.")
    }

    let troll = Actor {
        name("surly troll")
        adjectives("surly")
        description("All muscle and grudge.")
        // For an actor this is a *persistent* presence line, printed on
        // every look — not first-sight-only like an item's.
        firstSight("A surly troll glowers from beside the east wall.")
    }

    /// No description — examine should fall back to "nothing special".
    let mule = Actor {
        name("pack mule")
        adjectives("pack")
    }

    /// Behavior via the ordinary rule table.
    let sentry = Actor {
        name("silent sentry")
        adjectives("silent")
        description("Motionless.")
    }

    /// Unlisted until revealed.
    let ghost = Actor {
        name("pale ghost")
        adjectives("pale")
        description("Almost not there.")
        hidden
    }

    let sword = Item {
        name("short sword")
        adjectives("short")
    }

    let rock = Item {
        name("gray rock")
        adjectives("gray")
    }

    let watch = WatchContent()

    var content: GameContents {
        watch
    }

    var map: WorldMap {
        hall.north(corridor)
        corridor.south(hall)
        corridor.north(watch.gatehouse)
        watch.gatehouse.south(corridor)

        player.starts(in: hall)
        mule.starts(in: hall)
        troll.starts(in: corridor)
        sentry.starts(in: corridor)
        ghost.starts(in: corridor)
        sword.starts(in: corridor)
        rock.starts(in: corridor)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("sense", intent: Intent("sense"))
    }

    var rules: Rules {
        sentry.before(.examine) {
            try reply("The sentry ignores you, expertly.")
        }
        world.before(Intent("sense")) {
            ghost.reveal()
            try reply("The air goes cold.")
        }
    }
}

/// Broken on purpose: an actor with no name.
struct NamelessActorGame: Game {
    let title = "Nameless"
    let intro = "?"

    let hall = Location {
        name("Hall")
        description("A bare hall.")
    }

    let spirit = Actor()

    var map: WorldMap {
        player.starts(in: hall)
        spirit.starts(in: hall)
    }
}

/// Broken on purpose: two properties sharing one Actor value.
private let sharedActor = Actor { name("doppelganger") }

struct DuplicateActorGame: Game {
    let title = "Duplicate"
    let intro = "?"

    let hall = Location {
        name("Hall")
        description("A bare hall.")
    }

    let first = sharedActor
    let second = sharedActor

    var map: WorldMap {
        player.starts(in: hall)
        first.starts(in: hall)
    }
}

/// Legal but suspicious: an actor declaring a mechanical item trait.
struct BoxerGame: Game {
    let title = "Boxer"
    let intro = "?"

    let hall = Location {
        name("Hall")
        description("A bare hall.")
    }

    let boxer = Actor {
        name("boxer")
        container
    }

    var map: WorldMap {
        player.starts(in: hall)
        boxer.starts(in: hall)
    }
}
