import Gnusto

/// Phase 4 worked example — a logic-only ``GamePlugin`` packaging a small
/// commerce system: `buy`/`sell` verbs plus rule factories that price a host
/// item and move money in a host-owned wallet. It is ``ShopGame`` (Phase 3)
/// refactored into plugin + host, proving verbs and rules a game hand-wrote can
/// instead be spliced from a reusable unit. Reuses ``Purse`` from
/// `CustomStateGames`.
public struct CommercePlugin: GamePlugin {
    /// Creates the plugin. It carries no configuration of its own.
    public init() {}

    /// The intent the `buy` verb emits, shared so host rules can name it.
    public static let buy = Intent("buy")
    /// The intent the `sell` verb emits, shared so host rules can name it.
    public static let sell = Intent("sell")

    /// The player-typeable verbs the plugin contributes.
    public var verbs: [SyntaxRule] {
        SyntaxRule("buy", slots: .direct, intent: Self.buy)
        SyntaxRule("sell", slots: .direct, intent: Self.sell)
    }

    /// Lets the player buy `item` for its `price` trait, paying from a wallet
    /// the host owns. `balance` reads the current funds; `charge` deducts. Both
    /// run under the live turn, so they read and mutate the host's `@Global`
    /// exactly as an inline rule would.
    @RuleBuilder
    public func purchase(
        of item: Item,
        balance: @escaping @Sendable () -> Int,
        charge: @escaping @Sendable (Int) -> Void
    ) -> Rules {
        item.before(Self.buy) {
            let price = item[.price] ?? 0
            guard balance() >= price else {
                try refuse("You can't afford the \(item.name); it costs \(price) coins.")
            }
            charge(price)
            try reply("You buy the \(item.name) for \(price) coins. You have \(balance()) left.")
        }
    }

    /// Symmetric to ``purchase(of:balance:charge:)``: selling `item` credits the
    /// host's wallet with its `price`.
    @RuleBuilder
    public func sale(
        of item: Item,
        credit: @escaping @Sendable (Int) -> Void
    ) -> Rules {
        item.before(Self.sell) {
            let price = item[.price] ?? 0
            credit(price)
            try reply("You sell the \(item.name) for \(price) coins.")
        }
    }
}

/// The host game: it stores the plugin as a plain property, owns the `@Global`
/// wallet and the priced item, and opts in by splicing the plugin's `verbs` and
/// rule factories into its own blocks.
struct LampShop: Game {
    let title = "The Lamp Shop"
    let intro = "A cramped shop lit by a single flame."

    /// A plain stored value — not a Location/Item/@Global, so the bootstrap's
    /// reflection walk ignores it.
    let commerce = CommercePlugin()

    /// The host owns the wallet; the plugin only reads and adjusts it.
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

    /// Splice the plugin's vocabulary.
    var verbs: [SyntaxRule] {
        commerce.verbs
    }

    /// Splice the plugin's rules, wiring them to this game's item and wallet.
    var rules: Rules {
        commerce.purchase(
            of: lantern,
            balance: { purse.coins },
            charge: { purse.coins -= $0 })
        commerce.sale(
            of: lantern,
            credit: { purse.coins += $0 })
    }
}

/// A minimal plugin that adds only vocabulary and no rules, exercising the
/// protocol's defaulted `rules`. A host that splices its verb can then handle
/// the intent with its own rule.
struct VocabularyOnlyPlugin: GamePlugin {
    /// The intent the `appraise` verb emits, shared so host rules can name it.
    static let appraise = Intent("appraise")

    var verbs: [SyntaxRule] {
        SyntaxRule("appraise", slots: .direct, intent: Self.appraise)
    }
}

/// A host that opts into ``VocabularyOnlyPlugin`` and supplies the rule itself,
/// showing the alternative to parameterized factories: the plugin contributes
/// only the word, the host contributes the behavior.
struct AppraiseShop: Game {
    let title = "The Appraiser"
    let intro = "A dusty shop that will value anything."

    let appraiser = VocabularyOnlyPlugin()

    let shop = Location {
        name("Appraiser's Shop")
        description("A dusty shop counter.")
    }

    let gem = Item {
        name("green gem")
        adjectives("green")
        description("A glittering green gem.")
        trait(.price, 42)
    }

    var map: WorldMap {
        player.starts(in: shop)
        gem.starts(in: shop)
    }

    var verbs: [SyntaxRule] {
        appraiser.verbs
    }

    var rules: Rules {
        gem.before(VocabularyOnlyPlugin.appraise) {
            let price = gem[.price] ?? 0
            try reply("The \(gem.name) is worth \(price) coins.")
        }
    }
}
