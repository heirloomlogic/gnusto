import Gnusto
import GnustoScoring

/// Fixture for the `GnustoScoring` plugin: one vault room, a gem worth
/// points on first take and first deposit in the display case, a decoy sack
/// (a container that is *not* the case), a worthless pebble wired through
/// `treasures` to prove zero/absent values award nothing, and two custom
/// verbs — one probing `awardOnce` directly, one dying — to reach the
/// non-treasure paths.
///
/// Its ceiling is the sum of everything it can pay: the gem's 4 on the take and
/// 6 in the case, the pebble's nothing, and the 5 for `meditate`.
struct TreasureVaultGame: Game {
    let title = "Vault"
    let intro = "The vault door stands open, this once."
    let maxScore = 15

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

    let scoring = Scoring(awards: ["insight": 5])

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
            scoring.awardOnce("insight")
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

    let scoring = Scoring(awards: ["hall": 25])

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
        scoring.visit(hall, register: "hall")
        // Each stumble docks 10 — no register, so it repeats and can go below
        // zero.
        world.before(Intent("stumble")) {
            scoring.penalize(10)
            try reply("You stumble and bark your shin.")
        }
    }
}

/// Fixtures for the bootstrap's `maxScore` check: one room, one award, and a
/// ceiling the caller sets. `maxScore` is read before any rule can run, so the
/// check compares it against the ``Scoring`` award table, which is where a
/// register's value is written.
///
/// Three shapes, keyed by the ceiling: one that agrees with the table, one that
/// sits under it (the game can score past its own maximum), and one that sits
/// over it (points nothing can pay).
struct DeclaredScoreGame: Game {
    let title = "Ceiling"
    let intro = "A room, and one thing worth doing in it."
    let maxScore: Int

    let cell = Location {
        name("Cell")
        description("Four walls and a hook.")
    }

    let scoring: Scoring

    /// - Parameters:
    ///   - maxScore: the ceiling the game claims.
    ///   - awards: the registers it can actually pay; the default totals 10.
    init(maxScore: Int, awards: [String: Int] = ["hook": 10]) {
        self.maxScore = maxScore
        self.scoring = Scoring(awards: awards)
    }

    /// `Game` requires a no-argument initializer; the honest ceiling is the
    /// sensible default for it.
    init() {
        self.init(maxScore: 10)
    }

    var content: GameContents {
        scoring
    }

    var map: WorldMap {
        player.starts(in: cell)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("reach", intent: Intent("reach"))
    }

    var rules: Rules {
        world.before(Intent("reach")) {
            scoring.awardOnce("hook")
            try reply("You reach the hook.")
        }
    }
}
