# Splitting a game across files

A Gnusto game is one type conforming to `Game`. That does **not** mean it must live in one file. A large game splits cleanly along two of its three parts today; the third has a known boundary worth understanding.

## The one rule: declarations stay in the struct body

Locations, items, and `@Global` state are **stored properties**, and Swift requires stored properties to be declared in a type's main body — not in an extension. The bootstrap also discovers every entity by reflecting over the single `Game` type and naming each entity after its property (`let foyer = Location { … }` becomes `EntityID("foyer")`). So all entity declarations live together, in the file that declares the struct:

```swift
struct OperaHouse: Game {
    let foyer = Location { name("Foyer of the Opera House"); … }
    let bar   = Location { name("Foyer Bar"); dark }
    let cloak = Item { name("velvet cloak"); wearable }
    @Global var disturbances = 0
    // …
}
```

(If you reach the point where even the *declarations* need to span files or ship in a separate package, that's a planned capability — "content bundles" — not yet built. See the scaling roadmap.)

## `map` and `rules` compose across files

Both `map` and `rules` are result-builder properties, and the builder accepts whole `WorldMap` / `Rules` values as well as individual entries. That means you can break each one into per-region helper properties and splice them together:

```swift
extension OperaHouse {
    var map: WorldMap {
        foyerMap        // a WorldMap, defined elsewhere
        cloakroomMap
        barMap
        player.starts(in: foyer)
    }

    var rules: Rules {
        foyerRules      // a Rules value, defined elsewhere
        cloakroomRules
        barRules
    }
}
```

Each helper is itself a builder property, annotated so its body can use the block syntax. Put each region in its own file:

```swift
// OperaHouse+Bar.swift
extension OperaHouse {
    @MapBuilder var barMap: WorldMap {
        bar.north(foyer)
        message.starts(in: bar)
    }

    @RuleBuilder var barRules: Rules {
        bar.beforeEachTurn { … }
        bar.afterEachTurn  { … }
    }
}
```

Inside an extension, the bare identifiers (`bar`, `message`, `player`, `command`, your `@Global`s) resolve to the same declarations and engine globals they would inside the struct — nothing needs to be passed around.

## A recommended layout for a large game

```
MyGame/
  MyGame.swift            // struct: all Location/Item/@Global declarations,
                          //   plus map { … } and rules { … } that compose the regions
  MyGame+Foyer.swift      // foyerMap  + foyerRules
  MyGame+Cloakroom.swift  // cloakroomMap + cloakroomRules
  MyGame+Bar.swift        // barMap    + barRules
```

The struct file stays a readable table of contents — what exists and how the regions connect — while each region's geography and logic lives next to itself.

## Worked example

`Tests/GnustoTests/Support/SplitGame/` is a minimal game authored exactly this way: declarations in `SplitGame.swift`, with `gardenMap`/`gardenRules` in `SplitGame+Garden.swift` and `houseMap`/`houseRules` in `SplitGame+House.swift`. `MultiFileCompositionTests` boots it and confirms that the map entries and rules from every file take effect at runtime.

## What does *not* split yet

| Part | Splits across files? |
|---|---|
| `rules` | Yes — compose from per-region `Rules` helpers. |
| `map` | Yes — compose from per-region `WorldMap` helpers. |
| Entity declarations | No — stored properties must stay in the struct body. |
| Custom verbs / vocabulary | Not yet author-extensible (planned). |

See `docs/superpowers/specs/2026-06-28-scaling-gnusto-design.md` for the roadmap that lifts the remaining limits.
