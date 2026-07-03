# Content Bundles

Give a region its own declarations — its own type, and even its own package.

## Overview

<doc:SplittingAGameAcrossFiles> shows how a game's `map` and `rules` compose from per-region helpers, but its **entity declarations** all have to stay in the one ``Game`` struct's body. Content bundles lift that limit. A bundle is a self-contained slice of the world — its own rooms, items, and `@Global` state, plus the geography, rules, and verbs that go with them — declared in its own type, and even its own SPM package.

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

`map`, `rules`, and `verbs` all default to empty, so a bundle declares only what it needs. The bundle stores its declarations exactly as a game does, and the bootstrap discovers them by reflecting over the bundle. Each entity is named after its property, prefixed by the bundle's [namespace](<doc:ContentBundles#EntityIDs-are-namespaced-by-the-bundle>) (`trunk` → ``EntityID`` `"Attic.trunk"`), so a reusable bundle can't collide with the host.

A bundle with **no rooms at all** is how a stateful plugin ships: `GnustoDangerousDark` is just a namespaced `@Global` counter, a daemon, and three init knobs — added to `content` like any region (see <doc:Plugins#The-first-party-plugins>).

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

Each ``Location``/``Item``/``Global`` mints a reference token when it's created, and the bootstrap matches the tokens it discovers against the tokens a bundle's `map`/`rules` reference. A freshly constructed bundle carries *different* tokens than the one the game stored, so its references wouldn't resolve. Listing the stored instances keeps the identities aligned. (The bootstrap reads `content` once and reuses it, so a single build is always self-consistent; the contract matters because the game's top-level `map` references the stored `attic`.)

## EntityIDs are namespaced by the bundle

A bundle's entities are namespaced by the bundle, while the game's own entities stay bare. `attic.landing` becomes ``EntityID`` `"Attic.landing"`; the game's `foyer` stays `"foyer"`. The namespace defaults to the bundle's **type name**, so each distinct bundle type gets a distinct prefix automatically and a reusable bundle dropped into any host can't clash — even if the host and the bundle both declare a `landing`, they resolve to `"landing"` and `"Attic.landing"`. References at the authoring site are token-based (`attic.landing`), so the namespace is invisible there; it only shows up in the raw ID string, which is internal (display and parsing use each entity's `name(_:)`).

Collisions are still fatal, but now only when two bundles share a namespace **and** a property name. That happens when a host stores **two instances of the same bundle type** — both default to the type-name namespace, so `Attic.landing` is declared twice and the bootstrap rejects the game: `entity "Attic.landing" is declared by both Attic and Attic.` Give each instance a distinct namespace by overriding `var namespace`:

```swift
struct Attic: GameContent {
    let name: String
    var namespace: String { name }   // "NorthAttic", "SouthAttic", …
    // …
}
```

Because bundle-owned entity IDs are namespaced, so are their save-file keys — a bundle's `@Global` persists under `Bundle.flag`. Nothing shipped before this change owned bundle content, so there's no migration; keep a plugin's own state additive as usual.

## Cross-bundle references

- **Top-level wiring** — a game connecting one bundle's room to another's — is ordinary, compile-checked property access: `attic.landing.down(cellar.vault)`. Renaming either room breaks the exit at compile time.
- **Bundle-to-bundle** references (a bundle that needs to point at another bundle's entity from *inside* its own `map`/`rules`) use explicit injection: construct the dependency first and hand the shared instance in (`Attic(cellarDoor: cellar.door)`), so both sides reference the same token. Keep these localized; most cross-region wiring belongs at the top level.

## Multi-package

Because a bundle is a self-contained `Sendable` value type, it can live in its own SPM module: export the ``GameContent`` type, depend on it from the host, and list it in `content`. Nothing else changes.

## Worked example

`Tests/GnustoTests/Support/BundleGame/` is a minimal game built this way: `AtticContent` and `CellarContent` each own a room, an item, and rules (the attic also adds a `rummage` verb), and `BundleGame` composes them with a cross-bundle exit. `BundleCompositionTests` boots it and confirms every bundle's rules and verbs fire, the cross-bundle exit traverses both ways, each bundle's IDs are namespaced by its type, and two instances sharing a namespace are rejected.

For a bundle that also carries logic over the *host's* world — a content-bearing plugin — see <doc:Plugins>.
