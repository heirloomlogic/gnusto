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

/// A bundle that declares one of every entity kind the reflection walk knows —
/// a location, an item, an actor, and a `@Global` — so a game that stores two of
/// them proves the collision check covers all four and not just rooms.
struct AlphaBundle: GameContent {
    let foyer = Location {
        name("Alpha Foyer")
        description("The alpha foyer.")
    }

    let umbrella = Item {
        name("black umbrella")
        adjectives("black")
        description("A furled black umbrella.")
    }

    let porter = Actor {
        name("night porter")
        adjectives("night")
        description("He minds the desk.")
    }

    @Global var arrivals = 0

    var map: WorldMap {
        umbrella.starts(in: foyer)
        porter.starts(in: foyer)
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

/// A deliberately invalid game: it stores ``CellarContent`` but never lists it
/// in `content`, so nothing registers the bundle and its whole region — rooms,
/// items, rules, verbs, timers, map — would silently not exist. The bootstrap
/// must say so rather than boot a game missing half its world.
struct UnlistedBundleGame: Game {
    let title = "Half a World"
    let intro = "One region listed, one forgotten."

    let attic = AtticContent()
    let cellar = CellarContent()

    var content: GameContents {
        attic
    }

    var map: WorldMap {
        player.starts(in: attic.hall)
    }
}
