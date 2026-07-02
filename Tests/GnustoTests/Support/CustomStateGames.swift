import Gnusto

/// A custom state struct carried by a `@Global`. It needs only `Codable` and
/// `Sendable` — the empty `GlobalValue` conformance picks up the default
/// JSON boxing into `StateValue.data`, so no per-field packing is required.
/// (`Equatable` is here only for the round-trip test's assertion.)
struct Purse: Codable, Sendable, Equatable, GlobalValue {
    var coins: Int
}

/// Typed keys for the custom traits these fixtures share across files —
/// `price` (an item's cost in coins) and `weight` — declared once here so
/// `CommerceGame.swift` and `ShrineContent.swift` can reuse them instead of
/// redeclaring the same `TraitKey` under a different name.
extension TraitKey<Int> {
    static let price = Self("price")
    static let weight = Self("weight")
    static let value = Self("value")
}

/// Exercises Phase 3: rich custom `@Global` state (a `Purse` struct) plus a
/// custom item trait (`price`), driven by a game-defined `buy` verb whose
/// rule reads the trait and mutates the struct global. This is the Phase 4
/// commerce example in miniature.
struct ShopGame: Game {
    let title = "The Lamp Shop"
    let intro = "A cramped shop lit by a single flame."

    /// A whole struct in one global — impossible before Phase 3.
    @Global var purse = Purse(coins: 10)

    let shop = Location {
        name("Lamp Shop")
        description("A cramped shop. A brass lantern sits on the counter.")
    }

    let lantern = Item {
        name("brass lantern")
        adjectives("brass")
        description("A well-made brass lantern.")
        trait(.price, 5)
    }

    var map: WorldMap {
        player.starts(in: shop)
        lantern.starts(in: shop)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("buy", slots: .direct, intent: Intent("buy"))
    }

    var rules: Rules {
        lantern.before(Intent("buy")) {
            let price = lantern[.price] ?? 0
            guard purse.coins >= price else {
                try refuse("You can't afford the brass lantern; it costs \(price) coins.")
            }
            purse.coins -= price
            try reply("You buy the brass lantern for \(price) coins. You have \(purse.coins) left.")
        }
    }
}

extension TraitKey<String> {
    /// Never actually stored under this key by any fixture — used only to
    /// probe the wrong-type read below (the sign's `weight` is stored as an
    /// `.int`, so reading it back as `String` must yield `nil`).
    static let weightAsWrongType = Self("weight")
}

/// A probe game for the `nil` paths of the custom-trait accessor: the sign
/// has a `weight` trait but no `price`, letting a rule confirm that an absent
/// key and a wrong-type read both return `nil`.
struct TraitProbeGame: Game {
    let title = "Trait Probe"
    let intro = "A room with a heavy sign."

    let room = Location {
        name("Room")
        description("A plain room.")
    }

    let sign = Item {
        name("iron sign")
        adjectives("iron")
        description("A heavy iron sign.")
        trait(.weight, 40)
    }

    var map: WorldMap {
        player.starts(in: room)
        sign.starts(in: room)
    }

    var rules: Rules {
        sign.before(.examine) {
            let missing = sign[.price]
            let wrongType = sign[.weightAsWrongType]
            try reply("missing=\(missing as Int?) wrongType=\(wrongType as String?)")
        }
    }
}
