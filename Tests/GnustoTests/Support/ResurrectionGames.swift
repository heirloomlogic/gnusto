import Gnusto

/// Fixture for the game-level death hook (`Game.onDeath`) in its consuming
/// form: dying teleports the player to the clearing, docks the score, drops
/// what they carried where they fell, bumps a death counter, and continues
/// play — no banner, no prompt. The canonical Zork resurrection in miniature.
struct ResurrectionGame: Game {
    let title = "Resurrection"
    let intro = "A cave, a clearing, and a stubborn refusal to stay dead."

    let cave = Location {
        name("Dark Cave")
        description("Damp stone. Something lurks.")
    }

    let clearing = Location {
        name("Sunlit Clearing")
        description("Grass, sky, and a second chance.")
    }

    let torch = Item {
        name("pine torch")
        adjectives("pine")
    }

    @Global var deaths = 0

    var map: WorldMap {
        player.starts(in: cave)
        torch.startsHeld
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("provoke", intent: Intent("provoke"))
        SyntaxRule("count", intent: Intent("count"))
    }

    var rules: Rules {
        world.before(Intent("provoke")) {
            try die("The lurking thing strikes you dead.")
        }
        world.before(Intent("count")) {
            try reply("Deaths: \(deaths).")
        }
    }

    func onDeath() -> DeathOutcome {
        deaths += 1
        // Scatter what you carried where you fell, dock a toll, and wake up
        // in the clearing.
        for item in player.inventory {
            item.move(to: cave)
        }
        player.score -= 10
        player.location = clearing
        say("A cold wind gathers you up and sets you down elsewhere.")
        return .consumed
    }
}

/// Fixture for the death hook's *fall-through* form: the handler runs (bumps
/// a counter, prints a line) but returns `.fallThrough`, so the standard
/// banner and RESTART / RESTORE / UNDO / QUIT prompt still appear.
struct StubbornDeathGame: Game {
    let title = "Stubborn Death"
    let intro = "A ledge, and a long way down."

    let ledge = Location {
        name("Cliff Ledge")
        description("Wind, and a great deal of empty air.")
    }

    @Global var deaths = 0

    var map: WorldMap {
        player.starts(in: ledge)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("jump", intent: Intent("jump"))
    }

    var rules: Rules {
        world.before(Intent("jump")) {
            try die("You leap, and the ground rushes up.")
        }
    }

    func onDeath() -> DeathOutcome {
        deaths += 1
        say("(The mountain notes your passing.)")
        return .fallThrough
    }
}
