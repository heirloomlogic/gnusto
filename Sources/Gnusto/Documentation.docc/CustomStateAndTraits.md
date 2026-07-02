# Custom State and Traits

Carry your own data on entities and in globals, alongside the engine's closed core.

## Overview

A ``Global`` normally holds one scalar (`Bool`, `Int`, `Double`, `String`), and an item or location carries only the traits the engine knows about (`wearable`, `surface`, `dark`, …). Those closed sets are deliberate: the engine's behavior branches over a small, readable vocabulary you can audit at a glance. But a game system — a wallet, combat stats, an item's price — needs to carry data the engine itself never acts on. Custom state and custom traits are the open edges beside that closed core: unlimited declarative data for your rules to read and write, boxed through the same storage the engine already saves and restores.

The split is the whole idea. **The engine still switches only on the closed core.** Your custom values ride along type-erased and are only ever read by your own rule code.

## Rich `@Global` state

Any `Codable & Sendable` type can be a global. Conform it to ``GlobalValue`` with an empty conformance — the default implementation JSON-boxes it into the type-erased ``StateValue/data(typeName:bytes:)`` case, so there's nothing to hand-pack:

```swift
struct Purse: Codable, Sendable, GlobalValue {
    var coins: Int
    var receipts: [String] = []
}

struct MyGame: Game {
    @Global var purse = Purse(coins: 10)
    // …
}
```

Read and write it in rules exactly like a scalar global — it participates in the turn's commit and in save/restore through the one world-state funnel:

```swift
lantern.before(Intent("buy")) {
    guard purse.coins >= 5 else { try refuse("You can't afford it.") }
    purse.coins -= 5
    try reply("Sold. You have \(purse.coins) coins left.")
}
```

The type needs only `Codable` and `Sendable` — not `Hashable`. The boxed bytes are what participate in the world state's equality and hashing.

> Note: A custom global is stored as opaque bytes, so if you change its shape, an old save may no longer decode — the global then falls back to its declared default. Keep plugin/system state structs additive and optional-tolerant (new fields with defaults), and you'll stay compatible. Versioned codecs are a later effort.

## Custom traits

Declare a typed key once, then use it to declare a custom property inside an `Item { … }` or `Location { … }` block with `trait(_:_:)`. The value is boxed with the same rule as a `@Global`, so a scalar or a whole struct both work:

```swift
extension TraitKey<Int> { static let price = Self("price") }
extension TraitKey<String> { static let region = Self("region") }

let lantern = Item {
    name("brass lantern")
    trait(.price, 5)
}

let docks = Location {
    name("The Docks")
    trait(.region, "waterfront")
}
```

Read it back on the live proxy with the typed subscript, which returns `nil` when the trait is absent or stored as a different type:

```swift
let price = lantern[.price] ?? 0
```

A key declared with a default (`TraitKey("weight", default: 1)`) can be read as a non-optional `V` through `item[default: .weight]` instead.

Custom traits are **immutable declared facts** — they never touch the world state. For per-entity state that *changes* during play (an item's current charge, a creature's HP), use a `@Global` keyed however your system needs; traits are for the fixed properties an entity is born with.

## Closed core, open edges

The engine never switches on a custom trait or a `.data` global — it only branches over the closed ``ItemTrait``/``LocationTrait`` kinds and scalar ``StateValue`` cases it acts on (`isSurface`, `isWearable`, `dark`, …). That's what keeps the engine auditable: every behavior it drives is still visible in a handful of small enums, while your systems get unlimited declarative properties that only your rules interpret.

## Worked example

`Tests/GnustoTests/Support/CustomStateGames.swift` builds `ShopGame`: a `Purse` struct held in a `@Global`, a lantern with a `trait(.price, 5)`, and a game-defined `buy` verb whose rule reads the price and debits the purse — the commerce plugin in miniature. `CustomStateTests` boots it and confirms the struct global round-trips through save/restore, the custom trait reads back through the typed subscript, and absent/wrong-type reads return `nil`.

## See also

- <doc:WritingRules>
- <doc:Plugins>
- ``Global``
- ``GlobalValue``
