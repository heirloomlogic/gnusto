import Gnusto

/// A worked example proving a game can be composed from independent content
/// bundles. The game declares no rooms or items of its own: ``AtticContent``
/// and ``CellarContent`` each carry their own. The game stores the two bundle
/// instances, lists them in `content`, and wires the exit *between* them at the
/// top level with ordinary, compile-checked property access (`attic.hall`,
/// `cellar.vault`) — the simplest form of cross-bundle reference.
struct BundleGame: Game {
    let title = "Bundles"
    let intro = "An attic above a cellar."

    let attic = AtticContent()
    let cellar = CellarContent()

    /// The bundles whose declarations make up this game. Listing the stored
    /// instances (not fresh ones) is what lets the bootstrap match the tokens
    /// it discovers against the tokens the bundles' map/rules reference.
    var content: GameContents {
        attic
        cellar
    }

    /// Top-level geography: the player start and the one exit that crosses from
    /// the attic bundle into the cellar bundle and back.
    var map: WorldMap {
        attic.hall.down(cellar.vault)
        cellar.vault.up(attic.hall)
        player.starts(in: attic.hall)
    }
}

/// A bundle that declares an entity named `foyer`.
struct AlphaBundle: GameContent {
    let foyer = Location {
        name("Alpha Foyer")
        description("The alpha foyer.")
    }
}

/// A deliberately invalid game: two instances of the *same* bundle type share
/// the default type-name namespace, so both mint `EntityID("AlphaBundle.foyer")`.
/// The bootstrap must reject it with a fatal collision diagnostic rather than
/// silently letting one overwrite the other — the case a host resolves by giving
/// each instance a distinct `namespace`.
struct CollidingBundleGame: Game {
    let title = "Collision"
    let intro = "Two foyers, one namespace."

    let alpha = AlphaBundle()
    let beta = AlphaBundle()

    var content: GameContents {
        alpha
        beta
    }

    var map: WorldMap {
        player.starts(in: alpha.foyer)
    }
}
