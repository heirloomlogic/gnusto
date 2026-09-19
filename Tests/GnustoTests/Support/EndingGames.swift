import Gnusto

/// See ``end(won:)`` for the contract these demonstrate: a win and a loss,
/// neither involving `die(_:)`.
struct VictoryGame: Game {
    let title = "Victory"
    let intro = "A door, and open sky beyond it."
    let maxScore = 1

    let hall = Location {
        name("Hall")
        description("A bare hall. A door stands open to the north.")
    }

    var map: WorldMap {
        player.starts(in: hall)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("escape", intent: Intent("escape"))
    }

    var rules: Rules {
        world.before(Intent("escape")) {
            player.score = 1
            say("The door swings open onto open sky. You have won!")
            try end(won: true)
        }
    }
}

/// The loss counterpart.
struct DefeatGame: Game {
    let title = "Defeat"
    let intro = "A vault, and a countdown you cannot stop."

    let vault = Location {
        name("Vault")
        description("Steel walls. A red light blinks overhead.")
    }

    var map: WorldMap {
        player.starts(in: vault)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("surrender", intent: Intent("surrender"))
    }

    var rules: Rules {
        world.before(Intent("surrender")) {
            say("You set down your tools. The vault seals. You have lost.")
            try end(won: false)
        }
    }
}
