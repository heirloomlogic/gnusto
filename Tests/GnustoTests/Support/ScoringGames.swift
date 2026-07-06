import Gnusto
import GnustoScoring

/// Fixture for the `GnustoScoring` plugin: one vault room, a gem worth
/// points on first take and first deposit in the display case, a decoy sack
/// (a container that is *not* the case), a worthless pebble wired through
/// `treasures` to prove zero/absent values award nothing, and two custom
/// verbs — one probing `awardOnce` directly, one dying — to reach the
/// non-treasure paths.
struct TreasureVaultGame: Game {
    let title = "Vault"
    let intro = "The vault door stands open, this once."
    let maxScore = 10

    let vault = Location {
        name("Vault")
        description("Steel walls, a display case, and dust.")
    }

    let gem = Item {
        name("green gem")
        adjectives("green")
        description("It throws sparks of green light.")
        trait(.takeValue, 4)
        trait(.depositValue, 6)
    }

    let pebble = Item {
        name("gray pebble")
        adjectives("gray")
        description("A pebble of no worth at all.")
    }

    let showcase = Item {
        name("display case")
        adjectives("display")
        container
    }

    let sack = Item {
        name("burlap sack")
        adjectives("burlap")
        container
    }

    let scoring = Scoring()

    var content: GameContents {
        scoring
    }

    var map: WorldMap {
        player.starts(in: vault)
        gem.starts(in: vault)
        pebble.starts(in: vault)
        showcase.starts(in: vault)
        sack.starts(in: vault)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("meditate", intent: Intent("meditate"))
        SyntaxRule("perish", intent: Intent("perish"))
    }

    var rules: Rules {
        scoring.treasures([gem, pebble], into: showcase)

        // Probes awardOnce directly: pays 5 the first time, nothing after.
        world.before(Intent("meditate")) {
            scoring.awardOnce("insight", points: 5)
            try reply("You feel briefly enlightened.")
        }
        world.before(Intent("perish")) {
            try die("The dust was not dust.")
        }
    }
}

/// Fixture for the additive scoring APIs: `Scoring.visit(_:register:points:)`
/// (an award-once `onEnter` rule) and `Scoring.penalize(_:)` (an unregistered
/// deduction that can repeat and take the score negative). A gallery, an inner
/// hall the player earns points for first entering, and a trap verb that docks
/// points each time.
struct GalleryGame: Game {
    let title = "Gallery"
    let intro = "Marble floors and a doorway inward."
    let maxScore = 25

    let gallery = Location {
        name("Gallery")
        description("Marble, with an archway to the north.")
    }

    let hall = Location {
        name("Inner Hall")
        description("A vaulted hall hung with tapestries.")
    }

    let scoring = Scoring()

    var content: GameContents {
        scoring
    }

    var map: WorldMap {
        player.starts(in: gallery)
        gallery.north(hall)
        hall.south(gallery)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("stumble", intent: Intent("stumble"))
    }

    var rules: Rules {
        // Entering the hall pays 25, once.
        scoring.visit(hall, register: "hall", points: 25)
        // Each stumble docks 10 — no register, so it repeats and can go below
        // zero.
        world.before(Intent("stumble")) {
            scoring.penalize(10)
            try reply("You stumble and bark your shin.")
        }
    }
}
