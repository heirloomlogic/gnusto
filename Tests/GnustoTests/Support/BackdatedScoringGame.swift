import Gnusto

@testable import GnustoScoring

/// Writes the save a build from before the entity-ID change would have left:
/// the coin taken and cased, the score paid for both, and a ledger holding
/// `take.silver coin` and `deposit.silver coin` — keys derived from the
/// display name rather than from `coin`.
///
/// It declares the same world, under the same title, as ``BackdatedVaultGame``,
/// so the file it writes restores into that game. What it deliberately lacks is
/// the `treasures(_:into:)` splice: the reconcile that comes with it runs at the
/// end of every costing turn, and would credit the new `deposit.coin` key before
/// the save was ever written. The old ledger cannot be held still in a world
/// that is already reconciling it, which is why this is a second fixture rather
/// than a second verb on the first.
///
/// `@testable` because ``Scoring/claimed`` and ``Scoring/cased`` are the
/// plugin's own storage and there is no public way to seed them.
struct LegacyVaultGame: Game {
    let title = "Backdated"
    let intro = "A ledger written in an older hand."
    let maxScore = 10

    let archive = Location {
        name("Archive")
        description("Shelves, and a cabinet with a glass front.")
    }

    let coin = Item {
        name("silver coin")
        adjectives("silver")
        trait(.takeValue, 3)
        trait(.depositValue, 7)
    }

    let cabinet = Item {
        name("cabinet")
        container
    }

    let scoring = Scoring()

    var content: GameContents { scoring }

    var map: WorldMap {
        player.starts(in: archive)
        coin.starts(in: archive)
        cabinet.starts(in: archive)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("backdate", intent: Intent("backdate"))
    }

    var rules: Rules {
        world.before(Intent("backdate")) {
            coin.move(inside: cabinet)
            player.score = 10
            scoring.claimed.names.insert("take.silver coin")
            scoring.cased.names.insert("deposit.silver coin")
            try reply("The ledger is written in an older hand.")
        }
    }
}

/// The current build of the same game: one treasure, one cabinet, and the
/// entity-ID keys. It restores the file ``LegacyVaultGame`` wrote, and what it
/// then scores is the cost of the change.
///
/// Deliberately not a copy of the other vault fixtures — nothing here has to
/// stay in step with them, and its own numbers say so.
struct BackdatedVaultGame: Game {
    let title = "Backdated"
    let intro = "A ledger written in an older hand."
    let maxScore = 10

    let archive = Location {
        name("Archive")
        description("Shelves, and a cabinet with a glass front.")
    }

    let coin = Item {
        name("silver coin")
        adjectives("silver")
        trait(.takeValue, 3)
        trait(.depositValue, 7)
    }

    let cabinet = Item {
        name("cabinet")
        container
    }

    let scoring = Scoring()

    var content: GameContents { scoring }

    var map: WorldMap {
        player.starts(in: archive)
        coin.starts(in: archive)
        cabinet.starts(in: archive)
    }

    var rules: Rules {
        scoring.treasures([coin], into: cabinet)
    }
}
