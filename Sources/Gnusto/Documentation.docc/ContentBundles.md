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
        .rummage                     // a #verb-declared intent; see AddingCustomVerbs
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

A bundle the game stores but never lists is registered by nothing: its rooms, items, `@Global`s, rules, verbs, and timers all go quietly missing, and the first symptom is a region that isn't there. That is a fatal bootstrap diagnostic too, naming the property it found and the bundle's type.

## EntityIDs are namespaced by the bundle

A bundle's entities are namespaced by the bundle, while the game's own entities stay bare. `attic.landing` becomes ``EntityID`` `"Attic.landing"`; the game's `foyer` stays `"foyer"`. The namespace defaults to the bundle's **type name**, so each distinct bundle type gets a distinct prefix automatically and a reusable bundle dropped into any host can't clash — even if the host and the bundle both declare a `landing`, they resolve to `"landing"` and `"Attic.landing"`. References at the authoring site are token-based (`attic.landing`), so the namespace is invisible there; it only shows up in the raw ID string, which is internal (display and parsing use each entity's `name(_:)`).

So two bundles may use the same property name freely: an `Attic` and a `Cellar` that each declare a `chasm` mint `Attic.chasm` and `Cellar.chasm`, and neither can shadow the other. Namespacing is what makes region bundles safe to write independently, and the natural names (`chasm`, `stream`, `ladder`, `door`) are exactly the ones two regions both want.

Collisions are still fatal, but now only when two bundles share a **namespace** and a property name. That happens when a host stores **two instances of the same bundle type** — both default to the type-name namespace, so `Attic.landing` is declared twice. The bootstrap rejects the game with a fatal diagnostic naming the shared namespace, both declaring types, and the cure — printed ahead of the per-entity lines (`entity "Attic.landing" is declared by both Attic and Attic.`) that say which IDs were lost.

Give each instance a distinct namespace by overriding `var namespace`:

```swift
struct Attic: GameContent {
    let name: String
    var namespace: String { name }   // "NorthAttic", "SouthAttic", …
    // …
}
```

Because bundle-owned entity IDs are namespaced, so are their save-file keys — a bundle's `@Global` persists under `Bundle.flag`. Keep a bundle's own state additive, for the same reason any saved state has to be: a field that changes shape is a save file that no longer reads.

## A bundle can add a field to the status footer

``StatusLine`` says the room, the score and the moves, and the engine cannot reach the libraries that know anything else: `GnustoClock` depends on `Gnusto`, not the other way round. So a bundle that knows something a tester needs hands it up:

```swift
public var statusFields: [(String, String)] { [("time", now.formatted(format))] }
```

Nothing prints unless a session asks for a footer (`GNUSTO_STATUS=1`; see <doc:PlayTesting>), at which point the pairs are appended to every turn's `[status]` line after the four standard fields, in declaration order:

```
[status] room=Front Hall | moves=12 | score=0 | turn=cost | time=5:46 pm
```

Each field is read inside a live turn frame, so it may read globals, traits and the turn counter freely — `Clock`'s hour is a function of `moves`, and a value computed at bootstrap would say half past five forever. That frame is a **throwaway**, discarded rather than committed, so a field must be **read-only**: one that writes loses its write silently. There is no cheap way to enforce that — the frame has to be live for the reads to work — so it is a contract rather than a guarantee.

The frame is built over the world as the turn stood at its **close**: after its `afterEachTurn` rules and its timer tick, and before its move counter advanced. That is the same instant every rule in the turn read, so a field derived from `moves` names the turn it is printed under rather than the one after it — `Clock`'s hour and the hour that turn's `describe` blocks printed are one reading. The four standard fields beside it are the opposite kind of fact and are read *after* the counter moves, because `moves=` is the count the turn left behind. A turn that advanced no counter — a parse error, a meta verb, the opening, UNDO, RESTORE — has no such instant, and the field is read live, which for that turn is the same world. This was wrong once, and it cost two days: the footer's `time=` stood one tick ahead of every hour the game itself printed, and only on turns that cost a move.

## Cross-bundle references

- **Top-level wiring** — a game connecting one bundle's room to another's — is ordinary, compile-checked property access: `attic.landing.down(cellar.vault)`. Renaming either room breaks the exit at compile time.
- **Bundle-to-bundle** references (a bundle that needs to point at another bundle's entity from *inside* its own `map`/`rules`) use explicit injection: construct the dependency first and hand the shared instance in (`Attic(cellarDoor: cellar.door)`), so both sides reference the same token. Keep these localized; most cross-region wiring belongs at the top level.

## Multi-package

Because a bundle is a self-contained `Sendable` value type, it can live in its own SPM module: export the ``GameContent`` type, depend on it from the host, and list it in `content`. Nothing else changes.

## Worked example

The **Lighthouse** example (`Sources/Lighthouse/`) splits its tower into a `Tower` bundle that owns the Lamp Room and the beacon, while the host wires the stairs up to it and the cross-bundle rule that relighting the beacon depends on oil found below — the ordinary division of labor between a bundle and its host.

It also has a second bundle for the other reason to want one. `Fixtures` owns no geography at all: it is eight scenery items that exist so every noun the rooms print is a noun the parser knows, kept out of the host so the host stays short. Its items are placed by the *host's* `map` (`fixtures.sea.starts(in: jetty)`) — placements resolve against one pooled registry, so a host placing a bundle's item is ordinary; what a bundle cannot do is *name* a room it doesn't declare, since the only rooms it can store are its own. A bundle is somewhere to put declarations, and "a region" is only the most obvious reason to need one.

`Tests/GnustoTests/Support/BundleGame/` is a minimal game built this way: `AtticContent` and `CellarContent` each own a room, an item, and rules (the attic also adds a `rummage` verb), and `BundleGame` composes them with a cross-bundle exit. `BundleCompositionTests` boots it and confirms every bundle's rules and verbs fire, the cross-bundle exit traverses both ways, each bundle's IDs are namespaced by its type, and two instances sharing a namespace are rejected.

For a bundle that also carries logic over the *host's* world — a content-bearing plugin — see <doc:Plugins>.
