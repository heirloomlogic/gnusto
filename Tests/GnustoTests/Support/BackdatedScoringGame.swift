import Gnusto

@testable import GnustoScoring

/// A treasure, a cabinet, and a verb that writes the ledger keys a build from
/// before the entity-ID change would have left behind: `take.silver coin` and
/// `deposit.silver coin`, derived from the display name rather than from
/// `coin`. Deliberately not a copy of the other vault fixtures — nothing here
/// has to stay in step with them, and its own numbers say so.
///
/// `@testable` because ``Scoring/claimed`` and ``Scoring/cased`` are the
/// plugin's own storage and there is no public way to seed them. It lives in
/// its own file so the fixtures in `ScoringGames.swift` go on compiling
/// against the public surface.
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

    var verbs: [SyntaxRule] {
        SyntaxRule("backdate", intent: Intent("backdate"))
    }

    var rules: Rules {
        scoring.treasures([coin], into: cabinet)
        world.before(Intent("backdate")) {
            scoring.claimed.names.insert("take.silver coin")
            scoring.cased.names.insert("deposit.silver coin")
            try reply("The ledger is written in an older hand.")
        }
    }
}
