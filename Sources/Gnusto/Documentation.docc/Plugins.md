# Plugins

Package a reusable game system as an importable unit of verbs and rules.

## Overview

<doc:ContentBundles> let a game split its *own* world across types and packages. A **plugin** goes one step further: it packages a reusable game *system* — commerce, combat, dialog, magic — as an importable unit of verbs and rules that any game can opt into. Instead of hand-copying the same `buy`/`sell` logic into every shop game, you write it once as a ``GamePlugin`` and splice it in.

A plugin is **logic only**. It contributes the player-typeable vocabulary a system needs and the rules that react to it, but it owns no rooms, items, or `@Global` state of its own. It operates over entities and state the *host* game declares, receiving what it needs as parameters. That's what keeps it portable — it assumes nothing about the host's world beyond the traits and intents they agree on.

## A plugin is a `GamePlugin`

```swift
struct CommercePlugin: GamePlugin {
    static let buy = Intent("buy")
    static let sell = Intent("sell")

    var verbs: [SyntaxRule] {
        SyntaxRule("buy",  slots: .direct, intent: Self.buy)
        SyntaxRule("sell", slots: .direct, intent: Self.sell)
    }
}
```

`verbs` and `rules` both default to empty, so a plugin declares only what it needs. Exposing the intents as `static let` constants lets host rules name the same intents the verbs emit.

## The host splices verbs and rules

The host stores the plugin as a plain property and splices its vocabulary into its own `verbs` block. A plain plugin property is neither a ``Location``, ``Item``, nor `@Global`, so the bootstrap's reflection walk ignores it — it never becomes an entity and never collides.

```swift
struct LampShop: Game {
    let commerce = CommercePlugin()
    @Global var purse = Purse(coins: 10)          // the HOST owns the wallet
    let lantern = Item { name("brass lantern"); trait("price", 5) }

    var verbs: [SyntaxRule] { commerce.verbs }    // splice the vocabulary
    // rules below
}
```

## Parameterized rules over host entities

The plugin's rules need the host's own lantern and purse — things it can't know about in advance. So rules that touch host state are exposed as **parameterized methods** returning ``Rules``, which the host calls with its own declarations. The wallet is handed in as closures that read and adjust the host's `@Global`; they run under the live turn, so they see and mutate state exactly as an inline rule would.

```swift
extension CommercePlugin {
    @RuleBuilder
    func purchase(
        of item: Item,
        balance: @escaping @Sendable () -> Int,
        charge:  @escaping @Sendable (Int) -> Void
    ) -> Rules {
        item.before(Self.buy) {
            let price = item.trait("price", as: Int.self) ?? 0
            guard balance() >= price else {
                try refuse("You can't afford the \(item.name); it costs \(price) coins.")
            }
            charge(price)
            try reply("You buy the \(item.name) for \(price) coins. You have \(balance()) left.")
        }
    }
}

// in the host:
var rules: Rules {
    commerce.purchase(of: lantern,
                      balance: { purse.coins },
                      charge:  { purse.coins -= $0 })
}
```

The protocol's own `rules` requirement is for self-contained, world-scoped rules that need nothing from the host; anything host-specific goes through a factory method like this.

## A plugin can contribute only vocabulary

The rules are optional. A plugin can teach the parser a word and leave the behavior to the host, which handles the shared intent in its own `rules`:

```swift
struct Appraiser: GamePlugin {
    var verbs: [SyntaxRule] {
        SyntaxRule("appraise", slots: .direct, intent: Intent("appraise"))
    }
}

// in the host:
var rules: Rules {
    gem.before(Intent("appraise")) {
        try reply("The \(gem.name) is worth \(gem.trait("price", as: Int.self) ?? 0) coins.")
    }
}
```

## Content-bearing plugins own their region

A logic-only ``GamePlugin`` declares no world of its own — it operates entirely over entities the host passes it. A plugin that needs to ship its *own* rooms, items, and `@Global` state is a <doc:ContentBundles> instead: a ``GameContent`` carries `map`, `rules`, and `verbs`, and the bootstrap discovers its entities by reflection, [namespacing](<doc:ContentBundles#EntityIDs-are-namespaced-by-the-bundle>) them under the bundle so a reusable plugin can't collide with the host. List it in the game's `content`.

The two roles compose in one type. A single struct can conform to ``GameContent`` (for its auto-namespaced region and self-contained rules) **and** expose host-facing rule factories exactly like a ``GamePlugin`` — factories are just methods returning ``Rules``, so any type can offer them:

```swift
struct ShrineContent: GameContent {
    static let donate = Intent("donate")

    let shrine = Location { name("Stone Shrine"); description("…") }   // its own room
    @Global var visits = 0                                             // its own state

    var verbs: [SyntaxRule] { SyntaxRule("donate", slots: .direct, intent: Self.donate) }
    var rules: Rules { shrine.onEnter { visits += 1; try reply("…") } }  // self-contained

    // Host-facing factory over a host item + host global — the GamePlugin pattern.
    func offering(of item: Item,
                  merit: @escaping @Sendable () -> Int,
                  credit: @escaping @Sendable (Int) -> Void) -> Rules {
        item.before(Self.donate) { credit(item.trait("value", as: Int.self) ?? 0)
            try reply("Your merit rises to \(merit()).") }
    }
}
```

The host lists it in `content` (registering the namespaced region) **and** splices the factory into its own `rules`, wiring it to host declarations:

```swift
struct PilgrimGame: Game {
    let shrineKit = ShrineContent()
    @Global var merit = 0
    let coin = Item { name("brass coin"); trait("value", 7) }

    var content: GameContents { shrineKit }
    var verbs: [SyntaxRule] { shrineKit.verbs }
    var rules: Rules {
        shrineKit.offering(of: coin, merit: { merit }, credit: { merit += $0 })
    }
    // map: place coin in shrineKit.shrine, wire plaza ↔ shrineKit.shrine, …
}
```

References stay token-based across the boundary, so a host item can sit in a plugin room and a plugin rule can hook a host entity regardless of the namespace.

## Worked examples

- `Tests/GnustoTests/Support/CommerceGame.swift` — the logic-only commerce plugin (`buy`/`sell` verbs, `purchase`/`sale` factories, `LampShop` host); `PluginTests` drives a buy/sell turn end to end.
- `Tests/GnustoTests/Support/ShrineContent.swift` — the content-bearing `ShrineContent` plugin (owns a namespaced shrine region *and* exposes an `offering` factory) with its `PilgrimGame` host; `ContentPluginTests` drives a donate turn across the namespace boundary and checks the namespacing.
