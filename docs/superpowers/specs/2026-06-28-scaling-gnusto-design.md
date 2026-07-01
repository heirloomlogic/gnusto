# Roadmap: Scaling Gnusto to Larger Games

## Context

Cloak of Darkness works, but it's a single-room-ish game authored as one struct. Before building larger games, we want to know what the current architecture allows and what it blocks. Five concerns were raised: (1) must a whole game live in one file, (2) must all rules be in one property, (3) must the whole map be in one property, (4) can a game extend Gnusto's vocabulary, (5) can we add plugins for game systems (commerce, combat, dialog, magic, transport, crafting).

This document is a **roadmap with recommendations — no code yet**. It records the accurate current state (verified against source), then sequences the work to get from here to large, multi-file, plugin-extensible games. Each effort below is independently shippable; a later "writing-plans" pass turns a chosen effort into an implementation plan.

The guiding constraint throughout: preserve Gnusto's **auditable, compile-checked, declarative** character. Every verb and behavior should remain readable in source.

## Current state (verified)

| Concern | Status today | Evidence |
|---|---|---|
| Whole game in one file? | **Entity *declarations* yes; logic no.** Stored properties (`let room = Location{…}`, `let item = Item{…}`, `@Global`) must sit in the type's primary declaration (Swift rule), and bootstrap discovers them by reflecting over that one type. `map`/`rules` and helpers can live in extensions across files. | `Bootstrap.swift:28` `Mirror(reflecting: game).children` |
| All rules in one property? | **No — already composable.** `var rules: Rules { foyerRules; barRules }` works; helpers split across files. | `Builders.swift:52` `buildExpression(_ rules: Rules)` |
| Whole map in one property? | **No — already composable**, identical mechanism. | `Builders.swift:64` `buildExpression(_ map: WorldMap)` |
| Extend vocabulary? | **No — the real gap.** Bootstrap hardcodes the verb table; `SyntaxRule` is internal; `Game` has no hook. Custom `Intent("x")` can be minted but the parser never emits it, so its rules never fire. | `Bootstrap.swift:181` `SyntaxRule.standardTable` |
| Plugins for game systems? | **No.** Blocked by the vocabulary gap *and* closed engine enums: `StateValue` (bool/int/double/string only), `Placement`, and trait kinds can't be extended by a game/plugin without forking. | `RefToken.swift:30`, `Traits.swift`, `WorldState.swift` |

**Takeaway:** #2 and #3 are already solved (documentation/example work only). #1, #4, #5 are real work, and **#4 (vocabulary) is the keystone** — without it custom verbs are unreachable by players and every plugin is mute.

## Dependency graph

```
Phase 0  Document existing composition (rules/map split, multi-file via extensions)
            │  (no engine change)
            ▼
Phase 1  Vocabulary extension  ── keystone, smallest, independently valuable ──┐
                                                                                │
Phase 2  Declaration modularity (content bundles) ── independent of Phase 1 ──┐ │
                                                                              │ │
Phase 3  Extensible state & traits ───────────────────────────────────────┐  │ │
                                                                           ▼  ▼ ▼
Phase 4  Plugin packaging:  v1 logic-only (needs 1 + 3) · v2 content-bearing (needs 2)
```

Phases 1, 2, 3 are largely independent and could be tackled in any order or in parallel. Recommended order is by value/risk: vocabulary first (smallest, unblocks the most), then modularity, then extensible state, then plugin packaging on top.

---

## Phase 0 — Document existing composition (no engine change)

Splitting rules and map is already supported; the only gap is that authors don't know it.

- **Multi-file game:** keep all entity declarations in the game struct's primary file; move `map`, `rules`, and grouped helper computed properties (`var atticRules: Rules { … }`) into `extension OperaHouse { … }` blocks in separate files. Compose: `var rules: Rules { atticRules; barRules }`.
- Deliverable: a short authoring guide + a multi-file variant of an example/test game proving the pattern.
- Cost: trivial. Do this regardless of what else is prioritized.

## Phase 1 — Vocabulary extension (the keystone)

**Goal:** a game (and later a plugin) can add player-typeable verbs that produce custom intents, which existing before/after rules then handle.

**Recommended design:**
- Promote `SyntaxRule` and `SyntaxRule.Slots` to `public` (the type is already pure data and reads like a declaration). Keep `extraWord`/`specificity` internal.
- Add a defaulted result-builder hook to the `Game` protocol, mirroring how `rules` defaults to empty:
  ```swift
  @VerbBuilder var verbs: [SyntaxRule] { get }      // extension default: []
  typealias VerbBuilder = GnustoBuilder<SyntaxRule> // + buildExpression([SyntaxRule]) for splicing plugin tables
  ```
- Merge at one point: `Bootstrap.swift:181` → `let syntaxRules = SyntaxRule.standardTable + game.verbs`. Phase 3 of bootstrap already harvests verb words and prepositions into the `Vocabulary`, so custom verbs become parseable with no further change.
- **Behavior path — before-rules only, no per-intent closure.** A custom intent's behavior lives in a `before` rule that calls `reply(…)`/`refuse(…)` (which now actually fires, because the parser emits the intent). If parsed but unhandled, the player correctly sees "I didn't understand." This adds *zero* new machinery — no changes to `DefaultActions`, the pipeline, or `Rule`. Keeps one place to look for custom behavior (the `rules` block).
- **Collision policy:** built-ins first, **last-wins** dedupe by `(verb tokens, slot shape)`, with a non-fatal diagnostic when a game row shadows a built-in. Lets an author reclaim a verb while keeping overrides visible.

**Change set:** publicize `SyntaxRule`/`Slots`; add `verbs` hook + builder overload; one-line bootstrap merge; optional collision dedupe+diagnostic. Backward compatible (`verbs` defaults empty).

**Known limitation to flag:** `reply` short-circuits the turn, so a custom verb can't easily "succeed then run `after` rules." Custom verbs are usually self-contained, so accept this for now; add a `proceed()` sentinel later only if a game needs it.

**Critical files:** `Actions/SyntaxRule.swift`, `Engine/Bootstrap.swift`, `Declarations/Game.swift`.

## Phase 2 — Declaration modularity (content bundles)

**Goal:** split a game's rooms/items/globals across many files and even separate Swift packages, removing the "all stored properties in one type/one file" constraint — without losing property-name-derived `EntityID`s or compile-time reference safety.

**Recommended design (the `content` builder, mirroring `map`/`rules`):**
- A new public protocol for a coherent slice of the world, with its own geography/logic:
  ```swift
  public protocol GameContent: Sendable {
      @MapBuilder  var map: WorldMap { get }   // defaults empty
      @RuleBuilder var rules: Rules  { get }   // defaults empty
  }
  ```
  A bundle stores its own `let foyer = Location{…}` / `let lantern = Item{…}` / `@Global`s.
- The `Game` protocol gains one defaulted member:
  ```swift
  @ContentBuilder var content: GameContents { get }   // extension default: empty
  ```
  The builder yields the **actual bundle instances** the game stores (`var content { attic; library }`), so the tokens bootstrap reflects are exactly the tokens those bundles' `map`/`rules` reference — this is what avoids the fatal "two instances, disjoint tokens" hazard of naive nesting.
- **Bootstrap change:** factor phase-1 registration into a helper; run it over the game's own children (as today) *and* over each `game.content.modules` bundle's children. Aggregate each bundle's `map.entries`/`rules.rules` into the existing single map/rules passes (rules still evaluated inside the registration frame).
- **EntityIDs:** default to **bare property names with a hard collision diagnostic** (`EntityID "foyer" declared by both AtticContent and LibraryContent`). Optional opt-in per-bundle namespacing (`attic.foyer`) for games that genuinely collide. Bare-by-default keeps save-file keys stable.
- **Cross-references:** within a bundle and from top-level wiring (`game.map` referencing `attic.foyer`) stay ordinary, compile-time-checked property access. Bundle-to-bundle references use explicit injection (`AtticContent(library: library)`) sharing the same instance — opt-in, localized, token-safe.
- **Multi-package:** because a bundle is a self-contained `Sendable` value type, it can ship in its own SPM module and be imported; the host depends on it and lists it in `content`.

**Change set:** one new protocol + builder + aggregate type; one Bootstrap discovery/aggregation change; reword the "not a stored property" diagnostic. **No change** to `Location`/`Item`/`Global`/`RefToken`/`Registry`/`TurnFrame`/`WorldState`/proxies. Backward compatible; existing games and tests compile unchanged. Add a new multi-bundle test fixture rather than migrating Cloak of Darkness.

**Critical files:** `Engine/Bootstrap.swift`, `Declarations/Game.swift`, `Declarations/Builders.swift`, new fixture in `Tests/.../Support`.

## Phase 3 — Extensible state & traits (for plugin systems)

**Goal:** game systems carry rich custom state and custom entity properties despite the closed `StateValue`/trait enums, while keeping the single-`Codable`-`WorldState` save model.

**Recommended design:**
- **State — one type-erased boxed case.** Add `case data(typeName: String, bytes: Data)` to `StateValue`, plus a `GlobalValue` default for any `Codable & Hashable & Sendable` type that encodes/decodes itself through it. Then `@Global var stats = CombatStats()` "just works" and participates in commit/rollback and save/restore unchanged. Keeps **all** mutable state in the one existing funnel — preferred over a parallel `any Codable` side table.
- **Traits — keep core enums closed; add an open `custom` namespace.** The engine still branches only over the closed, readable trait kinds it acts on (`isSurface`, `isWearable`, …). Add a separate `custom(key: String, value: StateValue)` trait + a `trait("price", 5)` factory, stored as immutable `customTraits: [String: StateValue]` on the definition (never touches `WorldState`). Plugins read them via a typed accessor (`item.trait("price", as: Int.self)`). Mutable per-entity state (current HP) goes through `@Global`, not traits.

This split — closed core the engine switches on; open `custom`/`@Global` for plugin data — preserves auditability while giving plugins unlimited declarative properties.

**Risk to flag:** `.data` blobs are opaque, so a plugin changing its state struct breaks old saves. Recommend additive/optional-tolerant plugin state structs as convention; versioned codecs are a later effort.

**Critical files:** `Engine/RefToken.swift` (StateValue case + GlobalValue default), `Declarations/Traits.swift` + `Engine/GameDefinition.swift` (custom-trait namespace).

## Phase 4 — Plugin packaging

**Goal:** bundle verbs + rules (+ optionally content/state) into an importable unit a game opts into. This is a **thin composition** over Phases 1–3, not new mechanism.

- **v1 — logic-only plugins (needs Phases 1 + 3).** A plugin contributes verbs and rules over entities/globals the host game declares:
  ```swift
  public protocol GamePlugin {
      @VerbBuilder var verbs: [SyntaxRule] { get }   // default []
      @RuleBuilder var rules: Rules        { get }   // default empty
  }
  ```
  Host opts in by splicing: `var verbs { combat.verbs }`, `var rules { combat.rules(against: troll) }`. Worked example (commerce): plugin defines `Intent.buy/.sell` + `SyntaxRule` rows; host declares `@Global var coins` and `let lamp = Item { trait("price", 5) }`; a `lamp.before(.buy)` rule checks the wallet and replies. Every line readable in source.
- **v2 — content-bearing plugins (needs Phase 2). DONE (Phase 4b).** A plugin ships its own rooms/items by being a `GameContent` bundle the host lists in `content`. The bootstrap now namespaces each bundle's entity IDs by the bundle's `namespace` (defaulting to its type name; overridable for two instances of one type), so a reusable plugin can't collide with the host — game-owned entities stay bare. One type can be both content-bearing (conform to `GameContent`) and expose host-facing rule factories like a `GamePlugin`. Worked example: `Support/ShrineContent.swift` (`ShrineContent` + `PilgrimGame`), tests `ContentPluginTests`.

**Critical files:** new `Declarations/GamePlugin.swift`; reuses everything from Phases 1–3.

---

## Recommended sequence & rationale

1. **Phase 0** now (trivial, unblocks multi-file authoring immediately).
2. **Phase 1 (vocabulary)** — smallest engine change, independently valuable (any game gets custom verbs), and the keystone for plugins.
3. **Phase 2 (modularity)** — enables genuinely large, multi-file/multi-package worlds.
4. **Phase 3 (state/traits)** — unlocks rich plugin data.
5. **Phase 4 (plugins)** — v1 once 1+3 land; v2 once 2 lands.

Phases 1–3 are independent enough to reorder or parallelize if priorities shift.

## Verification approach (per phase, when implemented)

- **Unit/bootstrap tests** in `Tests/GnustoTests` for each change: custom verb parses and its rule fires (P1); collision diagnostic fires, cross-bundle reference resolves (P2); custom `@Global` struct round-trips through save/restore, custom trait reads back (P3); a sample plugin drives a full buy/sell turn (P4).
- **Acceptance:** keep Cloak of Darkness passing unchanged after every phase (backward-compat proof), and add one new fixture per phase demonstrating the new capability end-to-end via the `ScriptedIOHandler`/REPL path.
- **Auditability check:** after P1, dumping the resolved verb table shows every verb; after P3, the engine's behavior still switches only over closed core enums.

## Open questions to resolve at implementation time

- P1: verb override policy — confirm "last-wins + diagnostic" vs. hard-reject.
- P1: do we want a `proceed()` sentinel so custom verbs can run `after` rules? (defer unless needed)
- P2: bare EntityIDs (collisions = error) vs. namespaced by default — **resolved (Phase 4b):** game-owned entities stay bare; bundle-owned entities are namespaced by the bundle's type name (overridable). Save-file contract preserved because the only shipped game (Cloak) owns all its entities, so no ID changed; bundle-owned IDs/`@Global` keys are namespaced going forward.
- P2: should shared `@Global`s live only at top level by convention? (simplest)
- P3: save-format versioning for opaque `.data` state — convention now, versioned codecs later.
