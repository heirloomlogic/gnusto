import Gnusto

/// A second content bundle: the cellar region of ``BundleGame``, in its own
/// file. Proves a game composes from more than one bundle and that each
/// bundle's rooms, items, and rules register and fire independently.
struct CellarContent: GameContent {
    let vault = Location {
        name("Cellar Vault")
        description("A cold cellar vault with damp stone walls.")
    }

    let coin = Item {
        name("silver coin")
        adjectives("silver")
        description("A tarnished silver coin.")
    }

    var map: WorldMap {
        coin.starts(in: vault)
    }

    var rules: Rules {
        coin.before(.examine) {
            try reply("[cellar] The coin gleams faintly in the dark.")
        }
    }
}
