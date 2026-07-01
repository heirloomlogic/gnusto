# Content bundles

[Splitting a game across files](splitting-a-game-across-files.md) shows how a game's `map` and `rules` compose from per-region helpers — but its **entity declarations** all have to stay in the one `Game` struct's body. Content bundles lift that limit. A bundle is a self-contained slice of the world — its own rooms, items, and `@Global` state, plus the geography, rules, and verbs that go with them — declared in its own type, and even its own SPM package.

Reach for a bundle when a region is big or independent enough to own its declarations (not just its `map`/`rules`), or when you want to ship a region as a reusable package. For everything smaller, the extension-based file split is lighter and is still the right tool.

## A bundle is a `GameContent`

```swift
struct Attic: GameContent {
    let landing = Location { name("Attic Landing"); description("A dim landing.") }
    let trunk   = Item { name("steamer trunk"); adjectives("steamer") }

    var map: WorldMap { trunk.starts(in: landing) }

    var rules: Rules {
        trunk.before(.open) { try reply("It's locked.") }
    }

    var verbs: [SyntaxRule] {        // optional — bundles can add verbs too
        SyntaxRule("rummage", slots: .direct, intent: Intent("rummage"))
    }
}
```

`map`, `rules`, and `verbs` all default to empty, so a bundle declares only what it needs. The bundle stores its declarations exactly as a game does, and the bootstrap discovers them by reflecting over the bundle, naming each entity after its property (`trunk` → `EntityID("trunk")`).

## The game lists its bundles in `content`

```swift
struct MyGame: Game {
    let attic  = Attic()
    let cellar = Cellar()

    var content: GameContents {
        attic
        cellar
    }

    var map: WorldMap {
        attic.landing.down(cellar.vault)   // cross-bundle wiring, top level
        player.starts(in: attic.landing)
    }
}
```

The game's own `map`/`rules`/`verbs` still work and are merged with every bundle's.

## The one rule: list the stored instances

`content` must yield the **same bundle instances the game stores** — `var content { attic; cellar }`, never `var content { Attic(); Cellar() }`.

Each `Location`/`Item`/`@Global` mints a reference token when it's created, and the bootstrap matches the tokens it discovers against the tokens a bundle's `map`/`rules` reference. A freshly constructed bundle carries *different* tokens than the one the game stored, so its references wouldn't resolve. Listing the stored instances keeps the identities aligned. (The bootstrap reads `content` once and reuses it, so a single build is always self-consistent; the contract matters because the game's top-level `map` references the stored `attic`.)

## EntityIDs are bare property names — collisions are fatal

A bundle's entities get the same bare property-name IDs the game's do, so save-file keys stay stable and `attic.landing` is just `EntityID("landing")`. The flip side: if two bundles (or a bundle and the game) both declare an entity named `landing`, the bootstrap rejects the game with a fatal diagnostic — `entity "landing" is declared by both Attic and Cellar.` — rather than letting one silently shadow the other. Rename one of the two declarations. (Per-bundle namespacing is a possible future addition; for now, keep names distinct.)

## Cross-bundle references

- **Top-level wiring** — a game connecting one bundle's room to another's — is ordinary, compile-checked property access: `attic.landing.down(cellar.vault)`. Renaming either room breaks the exit at compile time.
- **Bundle-to-bundle** references (a bundle that needs to point at another bundle's entity from *inside* its own `map`/`rules`) use explicit injection: construct the dependency first and hand the shared instance in (`Attic(cellarDoor: cellar.door)`), so both sides reference the same token. Keep these localized; most cross-region wiring belongs at the top level.

## Multi-package

Because a bundle is a self-contained `Sendable` value type, it can live in its own SPM module: export the `GameContent` type, depend on it from the host, and list it in `content`. Nothing else changes.

## Worked example

`Tests/GnustoTests/Support/BundleGame/` is a minimal game built this way: `AtticContent` and `CellarContent` each own a room, an item, and rules (the attic also adds a `rummage` verb), and `BundleGame` composes them with a cross-bundle exit. `BundleCompositionTests` boots it and confirms every bundle's rules and verbs fire, the cross-bundle exit traverses both ways, the IDs are bare property names, and a colliding ID is rejected.
