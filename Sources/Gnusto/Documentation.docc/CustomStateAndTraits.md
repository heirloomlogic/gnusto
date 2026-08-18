# Custom State and Traits

Carry your own data on entities and in globals, alongside the engine's closed core.

## Overview

The engine only ever branches on a closed set of traits and scalar globals, and that is what keeps its behavior auditable: every decision it can make is visible in a handful of small enums. Your game's own data does not have to live in that set. A wallet, a set of combat stats, an item's price — custom state and custom traits ride along type-erased through the same storage the engine already saves and restores, read by your rules and by nothing else.

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
lantern.before(.buy) {
    guard purse.coins >= 5 else { try refuse("You can't afford it.") }
    purse.coins -= 5
    try reply("Sold. You have \(purse.coins) coins left.")
}
```

The type needs only `Codable` and `Sendable` — not `Hashable`. The boxed bytes are what participate in the world state's equality and hashing.

Those bytes are the reason to touch a struct global once per rule body rather than field by field. Reading one decodes and writing one encodes, so `purse.coins -= 5` is a decode, a mutate and an encode — fine on its own, but a rule that sets four fields pays for four round trips and, worse, loses an update if a nested expression writes the same global between the read and the write. Read it into a local, mutate the local, and assign it back once:

```swift
var wallet = purse
wallet.coins -= 5
wallet.receipts.append("lantern")
purse = wallet
```

> Note: A custom global is stored as opaque bytes, so if you change its shape, an old save may no longer decode — and a stored value that fails to decode is a `fatalError`, not a fall back to the declared default. (The default is only reached when the global's ID is *absent* from the save, which is what happens when you add a whole new global.) Save validation cannot catch it first: it checks only that a `.data` case is still a `.data` case, and one payload looks like another. So keep custom state structs additive and optional-tolerant — new fields with defaults, and a hand-written `init(from:)` that keeps the default when a field won't decode. Versioned codecs are a later effort.

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

## Worked example

The **Lighthouse** example (`Sources/Lighthouse/`) keeps two `@Global`s — `tideStage`, bumped by a daemon and read by a room's live description, and `keeperGreeted`, flipped by a dialogue rule — a compact look at custom state driving prose and branching.

`Tests/GnustoTests/Support/CustomStateGames.swift` builds `ShopGame`: a `Purse` struct held in a `@Global`, a lantern with a `trait(.price, 5)`, and a game-defined `buy` verb whose rule reads the price and debits the purse — the commerce plugin in miniature. `CustomStateTests` boots it and confirms the struct global round-trips through save/restore, the custom trait reads back through the typed subscript, and absent/wrong-type reads return `nil`.

## See also

- <doc:WritingRules>
- <doc:Plugins>
- ``Global``
- ``GlobalValue``
