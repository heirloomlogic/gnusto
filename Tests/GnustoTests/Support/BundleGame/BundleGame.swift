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

/// A small bundle held *inside* another bundle rather than by the game — the
/// shape ``NestedBundleHost`` uses to prove that registering a holder does not
/// register what it holds.
struct BuriedContent: GameContent {
    let cave = Location {
        name("Buried Cave")
        description("A cave under the ledge.")
    }

    let pebble = Item {
        name("grey pebble")
        adjectives("grey")
        description("A smooth grey pebble.")
    }

    var map: WorldMap {
        pebble.starts(in: cave)
    }

    var rules: Rules {
        cave.onEnter { say("[buried] The cave swallows the light.") }
    }
}

/// A bundle that stores another bundle. Registering this one registers its own
/// `ledge` and nothing of ``BuriedContent``: `content` is the game's block, so
/// a nested bundle has to be listed by the game as `<holder>.<property>`.
struct LedgeContent: GameContent {
    let buried = BuriedContent()

    let ledge = Location {
        name("Windy Ledge")
        description("A ledge above a cave.")
    }
}

/// A deliberately invalid game: it lists the holder but not the bundle the
/// holder stores, so ``BuriedContent``'s room, item, placement and rule would
/// all silently not exist.
struct UnlistedNestedBundleGame: Game {
    let title = "Buried"
    let intro = "A ledge above a cave nobody registered."

    let outer = LedgeContent()

    var content: GameContents {
        outer
    }

    var map: WorldMap {
        player.starts(in: outer.ledge)
    }
}

/// The valid counterpart: the same two bundles, with the nested one listed in
/// `content` under the path that reaches it. Its entities register, its
/// placement resolves and its rule fires.
struct NestedBundleHost: Game {
    let title = "Buried"
    let intro = "A ledge above a cave."

    let outer = LedgeContent()

    var content: GameContents {
        outer
        outer.buried
    }

    var map: WorldMap {
        outer.ledge.down(outer.buried.cave)
        player.starts(in: outer.ledge)
    }
}

/// A deliberately invalid game: it stores ``AtticContent`` and writes its map
/// against the stored instance, but `content` constructs a fresh one. The
/// namespace matches, so the old namespace-keyed check passed this and left
/// the author with a map diagnostic pointing at the wrong thing.
struct FreshInstanceBundleGame: Game {
    let title = "Twice Made"
    let intro = "One attic built twice."

    let attic = AtticContent()

    let hall = Location {
        name("Host Hall")
        description("The host's own hall.")
    }

    var content: GameContents {
        AtticContent()
    }

    var map: WorldMap {
        hall.up(attic.hall)
        player.starts(in: hall)
    }
}

/// A deliberately invalid game: one stored bundle instance, listed twice. The
/// cure is deleting the second listing, not overriding `namespace`.
struct DoubleListedBundleGame: Game {
    let title = "Twice Listed"
    let intro = "One attic, named twice."

    let attic = AtticContent()

    var content: GameContents {
        attic
        attic
    }

    var map: WorldMap {
        player.starts(in: attic.hall)
    }
}
