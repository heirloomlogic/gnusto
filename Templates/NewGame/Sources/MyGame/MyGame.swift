import Gnusto

/// A two-room starter game: fetch the rope, climb the tower, ring the bell.
/// Every piece here — rooms, items, map, a custom verb, rules — is explained
/// in Gnusto's "Getting Started" guide.
struct MyGame: Game {
    /// The game's title.
    let title = "The Bell Tower"
    /// The game's one-line tagline.
    let tagline = "A starter game."
    /// The maximum achievable score.
    let maxScore = 1
    /// The opening text shown when play begins.
    let intro = "Mist hangs over the village. Somewhere above, a bell waits."

    // MARK: - Rooms

    let garden = Location {
        name("Village Garden")
        description("A quiet garden. A worn staircase climbs north into the tower.")
    }

    let tower = Location {
        name("Bell Tower")
        description("Wind slips through the openings. The great bronze bell hangs overhead.")
    }

    // MARK: - Things

    let rope = Item {
        name("frayed rope")
        adjectives("frayed", "old")
        description("Old but serviceable. It looks like it belongs on a bell.")
    }

    let bell = Item {
        name("bronze bell")
        adjectives("great", "bronze")
        description("It hasn't rung in years.")
        scenery
    }

    // MARK: - Map

    /// Geography and initial entity placement.
    var map: WorldMap {
        garden.north(tower)
        tower.south(garden)
        garden.south(blocked: "The village lies that way, but your business is the bell.")

        player.starts(in: garden)
        rope.starts(in: garden)
        bell.starts(in: tower)
    }

    // MARK: - Vocabulary

    /// Teach the parser a new verb; the rule below gives it behavior.
    var verbs: [SyntaxRule] {
        SyntaxRule("ring", .directObject, intent: Intent("ring"))
    }

    // MARK: - Rules

    /// All game logic.
    var rules: Rules {
        bell.before(Intent("ring")) {
            try require(rope.isHeld, else: "You need something to swing the clapper with.")
            player.score += 1
            say("You haul on the rope. The great bronze bell peals out over the village!")
            try end(won: true)
        }
    }
}
