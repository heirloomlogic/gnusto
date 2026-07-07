# Declared-Once Entities: Killing the File-Scope Item Idiom

**Date:** 2026-07-07
**Status:** Approved in discussion; spec pending review

## Problem

Every entity is supposed to be one stored property of its `Game` or
`GameContent` struct — Bootstrap reflects over stored properties, the property
name becomes the `EntityID`, and the bundle supplies the namespace. But a Swift
stored-property initializer runs before `self` exists, so it cannot reference a
sibling stored property. Three situations therefore force an item out to file
scope, with a stored-property alias added back so reflection still discovers it:

1. **`lockable(with: key)`** — the lock's initializer needs the key item
   (`skeletonKeyItem` / `let skeletonKey = skeletonKeyItem` in
   `Sources/Zork1/AboveGround.swift`).
2. **Self-referencing dynamic descriptions** — `zork1Lantern`'s closure reads
   its own `isLit` (`Sources/Zork1/House.swift`).
3. **Sibling- and cross-bundle-referencing dynamic descriptions** —
   `zork1TrophyCase`'s closure reads `zork1Egg`, which lives in a *different
   bundle* (`ZorkAboveGround.egg` aliases it).

The result is the friction under review: some items declared at file scope,
some in the struct, and aliases like `let skeletonKey = skeletonKeyItem`
bridging the two.

### Rejected direction: move all items to file scope

There is no cataloging mechanism for top-level declarations. `Mirror` cannot
enumerate file-scope constants and Swift macros cannot collect declarations
across a file, so registration would become a hand-maintained list — the
declare-it-twice problem for *every* item. It would also forfeit the property
name as the entity ID, automatic per-bundle namespacing, and the ability to
host two instances of one bundle type.

## Design

Make the three forcing cases expressible inside the struct, in the two blocks
that are computed properties (where sibling references already work): `map`
and `rules`. Then delete the escape hatches. After this change, **every
entity is a stored property of its game or bundle, declared exactly once** —
an invariant, not a convention.

### 1. Lock/key wiring moves to the `map` block

```swift
struct ZorkAboveGround: GameContent {
    let skeletonKey = Item { name("skeleton key") }
    let grating = Item {
        name("iron grating")
        container
        openable
        scenery
        hidden
    }

    var map: WorldMap {
        grating.lockedBy(skeletonKey)   // ← implies lockable; starts locked
        …
    }
}
```

- New `MapEntry.Kind.lockKey(item: RefToken, key: RefToken)` plus
  `Item.lockedBy(_ key: Item) -> MapEntry`, exactly parallel to
  `starts(in:)`. Precedent: door wiring (`via:`) is already relational map
  wiring, not a trait.
- **The entry itself confers lockability.** There is no separate `lockable`
  trait to forget the key for — the "lockable but keyless" state is
  unrepresentable, which is stronger than a bootstrap diagnostic. The key
  reference is an ordinary property access, so renaming the key is
  compiler-checked.
- `startsUnlocked` remains a trait (it is intrinsic to the item, not
  relational). `startsUnlocked` on an item with no `lockedBy` entry becomes a
  non-fatal warning ("flag has no effect"), matching the `startsLit`-without-
  `lightSource` policy.
- Two `lockedBy` entries for the same item: fatal diagnostic, matching the
  duplicate-exit policy.
- Deleted outright (no shims): `lockable(with: Item)` in
  `Declarations/Traits.swift`, `ItemTrait.Kind.lockable(key:)`,
  `ItemDefinition.lockKeyToken`, and Bootstrap's post-hoc key-token
  resolution pass. Bootstrap instead resolves the map entry alongside
  placements and sets `ItemDefinition.lockKey`/`isLockable`.

### 2. Dynamic descriptions become `describe` rules

```swift
struct ZorkHouse: GameContent {
    let lantern = Item {
        name("brass lantern")
        synonyms("lamp")
        lightSource
    }

    var rules: Rules {
        lantern.describe {
            lantern.isLit ? Prose.lanternOn : Prose.lanternOff
        }
        …
    }
}
```

- New declarations `item.describe { … } -> Rule` and
  `location.describe { … } -> Rule`, collected in `rules` blocks like
  `before`/`after`. The body is `@Sendable () -> String` — unlike other rule
  bodies it *returns* the text, so the rule table stores describe closures in
  their own slots (`itemDescribe` / `locationDescribe:
  [EntityID: @Sendable () -> String]`).
- `TurnFrame.describedText(of:)` resolution order becomes: runtime override
  (`item.description = "…"`) → describe rule → static `description(…)` trait.
  This is the same order dynamic closures occupy today.
- Conflict policy mirrors today's: an entity with both a static
  `description(…)` trait and a `describe` rule is a fatal diagnostic
  (replacing `hasDynamicDescriptionConflict`); two `describe` rules for the
  same entity are likewise fatal.
- **Deleted outright (no shims): the closure form of the `description { … }`
  trait**, for both items and locations (`ItemTrait.Kind.dynamicDescription`,
  `LocationTrait.Kind.dynamicDescription`, and the
  `GameDefinition.dynamicDescription` fields). Rationale: inside any struct,
  a trait-position closure cannot reference `self`, siblings, or the bundle's
  `@Global`s — the very restriction under repair — so it only ever worked
  from file scope. Keeping it would preserve two mechanisms for one concept,
  one of them crippled. After this change there is exactly one static form
  (the trait) and one dynamic form (the rule). *Note: this deletion is a
  delta from the originally discussed `description { $0.isLit }` item-
  parameter variant — subsumed because `describe` rules cover self-reference
  and more.*

### 3. Cross-bundle descriptions are host wiring

The trophy case (in `ZorkHouse`) describes itself by whether it holds the egg
(in `ZorkAboveGround`). Neither bundle can see the other's properties — but
the host stores both, and cross-bundle wiring is already the host's job (the
kitchen window exit, the cellar/Troll Room exits). The egg is declared once,
in `ZorkAboveGround`; the host declares the description:

```swift
// Zork1.rules
house.trophyCase.describe {
    house.trophyCase.holds(aboveGround.egg)
        ? Prose.trophyCaseHolding("a \(aboveGround.egg.name)")
        : Prose.trophyCaseEmpty
}
```

`ZorkAboveGround.egg` stops being an alias of a shared file-scope value and
becomes the sole declaration; `ZorkHouse` no longer declares the egg in any
form.

## Migration inventory

All file-scope items and their aliases are eliminated; each becomes a plain
stored property.

| Site | Change |
| --- | --- |
| `Sources/Zork1/AboveGround.swift` | `skeletonKeyItem` inlined as `skeletonKey`; `grating` drops `lockable(with:)`; `map` gains `grating.lockedBy(skeletonKey)` |
| `Sources/Zork1/House.swift` | `zork1Lantern`, `zork1TrophyCase`, `zork1Egg` inlined as `lantern`, `trophyCase`, `egg` (egg moves to `ZorkAboveGround` as the sole declaration); lantern gains a `describe` rule in `House.rules`; the `lanternDies` fuse writes `lantern.isLit` (timers are a computed property — `self` is available) |
| `Sources/Zork1/Zork1.swift` | gains the trophy-case `describe` rule (cross-bundle) |
| `Sources/CloakOfDarkness/OperaHouse.swift` | `velvetCloak`/`brassHook` inlined; hook's dynamic description becomes a `describe` rule — this file is the acceptance benchmark, so its file-scope preamble and apology comment disappearing is the headline win |
| `Tests/GnustoTests/Support/DslQuickWinGames.swift` | `eggItem`/`trophyCaseItem` pair inlined; describe rule |
| `Tests/GnustoTests/Support/ContainerGames.swift`, `ActionGames.swift`, `ContainerTests.swift` | `lockable(with:)` → `lockedBy` map entries; file-scope keys inlined |
| Engine DocC / doc comments | the workaround explanations (`AboveGround.swift` header, `House.swift` header, `Traits.swift` cross-references) are deleted, not preserved as history |

New engine tests: `lockedBy` resolution (including dangling key and duplicate
entry diagnostics), `startsUnlocked`-without-`lockedBy` warning, `describe`
rule resolution order (override > rule > static), static-plus-describe and
double-describe diagnostics, cross-bundle describe declared by the host.

## Error handling summary

| Situation | Outcome |
| --- | --- |
| `lockedBy` key or item not a stored property | fatal diagnostic (as today for exits/placements) |
| duplicate `lockedBy` for one item | fatal diagnostic |
| `startsUnlocked` with no `lockedBy` | non-fatal warning |
| static `description(…)` + `describe` rule | fatal diagnostic |
| two `describe` rules for one entity | fatal diagnostic |
| `describe` on entity not a stored property | fatal diagnostic (as for other rules) |

## Out of scope

- Any other trait taking an entity reference — `lockable(with:)` was the only
  one; the category closes with it.
- Sibling references in *trait* position generally (e.g. a future
  `description` that names another item at declaration time). The doctrine
  this design establishes: intrinsic properties are traits; anything
  relational or state-reading lives in `map`/`rules`.
- `firstSight`, `synonyms`, and all other static traits — unchanged.
