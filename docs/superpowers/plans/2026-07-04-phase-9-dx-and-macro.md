# Phase 9 — `#verb` macro, GnustoTestSupport, template & OperaHouse rewrite: Implementation Plan

Part of the approved Gnusto roadmap (Phases 5–10, "The Road to Zork 1").

## Context

Phases 5–8 of the approved "Road to Zork 1" roadmap are merged (PR #14, 317 tests green).
Per the approved Roadmap v2 (2026-07-01), Phase 9 is the developer-experience phase before
Phase 10 (complete Zork 1, 350 pts): collapse custom-verb boilerplate, ship the transcript-test
helpers as a public product, provide a starter template, and make OperaHouse (the taste
benchmark) showcase the modern engine. Workspace branch is at main (683ed05), clean.

Invariants: `CloakTranscriptTests` needles unchanged; Zork1 untouched (no FIDELITY.md change);
no-legacy-shims (superseded APIs deleted outright); `.dev-tooling` sentinel gating untouched;
verify in Debug locally (`swift test -c release` has a known toolchain quirk on this Mac — CI
covers Release).

## Part A — `#verb` macro (CONFIRMED by user 2026-07-03: swift-syntax dependency accepted)

**Ground truth (verified):** rule factories take variadic `Intent` (Item.swift:282, Actor:150,
Location:136, World:27, IntentAction:35), so a leading-dot `.ring` key must be `static` in
`extension Intent` (built-ins: Actions/Command.swift:13+). `VerbBuilder` already has splice
overloads (Builders.swift:70-76). Bootstrap validates patterns at launch via `patternProblems`
(SyntaxRule.swift:89-134). Plugins aren't reflected — hosts splice their `verbs`.

**Surface syntax** — freestanding declaration macro, valid only inside `extension Intent {}`
(enforced via `lexicalContext` diagnostic):

```swift
extension Intent {
    #verb("ring", ["ring", .directObject])
    #verb("attack", ["attack", .directObject], ["kill", .directObject], ...)  // synonyms
    #verb("steal", ["take", .directObject])   // reclaim a built-in under a new intent
    #verb("sing")                             // pattern defaults to ["sing"]
}
// game/plugin:
var verbs: [SyntaxRule] { .ring; .sing }               // one identifier per verb
var rules: Rules { bell.before(.ring) { ... } }        // typed, autocompletable
```

Expands to `public static let ring = Intent("ring", syntax: [SyntaxRule("ring", .directObject,
intent: Intent("ring"))])`. Irreducible residue: the intent must still be listed in a `verbs`
block (macros can't auto-register; a new non-fatal bootstrap warning catches "rule watches an
intent no verb row produces").

**Tasks:**
1. `Package.swift`: swift-syntax `"601.0.0"..<"700.0.0"` (outside devDependencies — cannot be
   dev-gated); `.macro` target `GnustoMacros` (SwiftSyntaxMacros, SwiftCompilerPlugin);
   `Gnusto` target depends on it (no new product — macros ride in the library);
   `.testTarget GnustoMacrosTests` (+SwiftSyntaxMacrosTestSupport, XCTest). Commit
   `Package.resolved` (pins CI + assertMacroExpansion formatting).
2. Substrate: `Intent` gains `public let syntax: [SyntaxRule]` **excluded from ==/hash**
   (hand-written, raw-based — Intent is a dictionary key in actionOverrides/metaIntents);
   `VerbBuilder.buildExpression(_ intent: Intent) -> [SyntaxRule]` splices rows; new
   `Sources/Gnusto/Declarations/VerbMacro.swift`:
   `@freestanding(declaration, names: arbitrary) public macro verb(_ intentName: String, _ patterns: [SyntaxElement]...)`.
3. Bootstrap: non-fatal warning for rule-watched intents no verb row produces.
4. `Sources/GnustoMacros/VerbMacro.swift`: lexicalContext check; intent name must be a plain
   string literal + valid identifier; patterns must be literal `.word`/`.directObject`/
   `.indirectObject`/`.direction` elements; port `patternProblems` as compile-time diagnostics
   (Bootstrap's runtime check stays for hand-built rules).
5. Tests: GnustoMacrosTests golden expansions + diagnostics; e2e — rewrite
   `Tests/GnustoTests/Support/CustomVerbGames.swift` onto `#verb` (`.ring/.polish/.sing/.steal`),
   new tests for row merge, dead-intent warning, equality-ignores-syntax. Keep ≥1 raw
   `SyntaxRule(..., intent:)` fixture — the substrate stays public (it's the expansion target,
   not superseded).
6. Adoption: `GnustoMeleeCombat` — delete `static let attack`, 9 rows → one `#verb("attack", ...)`
   + `verbs { .attack }`; migrate high-noise fixtures (ActorGames, ActionGames,
   DslQuickWinGames); rewrite `AddingCustomVerbs.md` around declare→list→respond; fix stale
   `slots: .direct` snippets in Plugins.md:86 & ContentBundles.md:25; swap the template's verb
   to `#verb` (task C.4).

(A zero-dep `Verb` reflection type was offered as an alternative; user chose the macro.)

## Part B — GnustoTestSupport

Promote the internal helpers (Tests/GnustoTests/Support/Transcript.swift) verbatim to a public
library target. 508 call sites / 34 test files migrate by import only (same names/signatures).

1. `Package.swift`: `.library(name: "GnustoTestSupport", ...)` + target (deps: Gnusto,
   devPlugins); add to GnustoTests deps.
2. `Sources/GnustoTestSupport/Play.swift` (imports Gnusto): `public func play(_ game: some Game,
   _ commands: [String], seed: UInt64? = nil) async throws -> String`;
   `public func turnOutput(of:in:) -> String`.
   `Sources/GnustoTestSupport/Expectations.swift` (imports Testing — isolated to this one file):
   `public func expectInOrder(_ transcript: String, _ needles: [String], sourceLocation: SourceLocation = #_sourceLocation)`.
   Doc comment + article note: link into **test targets only** (Testing lives in the toolchain,
   not the OS).
3. **Spike gate:** `swift build` + `swift build -c release` must compile the target standalone;
   fallback is `#if canImport(Testing)` around Expectations.swift only. Do NOT make
   expectInOrder throwing — 178 call sites rely on non-fatal `Issue.record` + per-needle
   source locations.
4. Delete `Tests/GnustoTests/Support/Transcript.swift`; add `import GnustoTestSupport` to the
   34 caller files. Fixture games stay in Tests (engine fixtures, not author tooling).

## Part C — Starter template: `Templates/NewGame/`

Ready-to-copy standalone package (recommended over DocC-only walkthrough — shows the consumer
`Package.swift`, test-target wiring, and entry point, which CloakOfDarkness can't; CI-buildable
via path dependency, no credentials).

1. `Templates/NewGame/`: README.md (3-step copy instructions), Package.swift
   (`.package(path: "../..")` with commented-out git-URL line for real copies; executable
   `MyGame` + `MyGameTests` using GnustoTestSupport product), Sources/MyGame/MyGame.swift
   ("The Bell Tower": 2 rooms, rope+bell, blocked exit, `require`, custom `ring` verb, scored
   win via `end(won:)`), Entry.swift (`@main` GameMain), MyGameTests.swift (2 transcript tests).
2. Verify: `swift test --package-path Templates/NewGame`.
3. CI: append template test step to `.github/workflows/test.yml` (path dep resolves the root
   manifest without `.dev-tooling`, so no Persnicket resolution).
4. If Part A lands: swap the verb declaration to `#verb` form.

## Part D — OperaHouse rewrite (transcript-preserving; target: zero needle changes)

1. Cloak guard → `try require(player.location == cloakroom, else: "This isn't the best place...")`
   (Helpers.swift:33).
2. Closure description for the hook (the canonical Phase-5+ use; precedent
   `zork1TrophyCase`, House.swift:37-48): hoist `cloak`/`hook` to file-scope `private let
   velvetCloak`/`brassHook` (stored-property init can't reference siblings), give the hook
   `description { brassHook.holds(velvetCloak) ? "...with a cloak hanging on it." : "...screwed to the wall." }`,
   struct keeps `let cloak = velvetCloak` / `let hook = brassHook`, DELETE the
   `hook.before(.examine)` rule. Default examine prints description verbatim
   (DefaultActions.swift:545-553) → byte-identical. Known benign delta on untested input:
   `read hook` now prints the description (note in PR).
3. Rejected (verified, keep as-is): closure description for `message` (can't capture the game's
   `@Global`; the file-scope-bundle workaround reads worse — and afterEachTurn+runtime-override
   is itself a feature showcase); `cloakIsHung` → `hook.holds(cloak)` (drop-path win must score:
   `alternateWinViaDrop`; isLit-latch double-scores); `#verb` for "hang" ("hang X on Y" is a
   built-in `.putOn` row, SyntaxRule.swift:180); doors/containers/hidden/GameText (behavior
   changes Cloak doesn't need).

## Part E — Docs

1. New `Sources/Gnusto/Documentation.docc/TestingYourGame.md` (product wiring w/ test-target-only
   note, play/expectInOrder/turnOutput, seed pinning; template's test as worked example);
   add to Documentation.md topics.
2. `GettingStarted.md`: test target in the Package.swift snippet, short "Test it" section,
   pointer to `Templates/NewGame`.
3. `AddingCustomVerbs.md` rewrite rides with Part A.

## Order & verification

Order: B (spike first) → D → C → A (biggest risk isolated last; each part leaves the suite
green) → E rides with its parts. Single PR (matches Phases 5–8 convention), branch off main.

Verify each part: `swift build && swift test` (Debug) green; `CloakTranscriptTests` needles
unchanged after D; `swift test --package-path Templates/NewGame` green after C; after A,
GnustoMacrosTests + CustomVerbTests green and `swift run` smoke of CloakOfDarkness binary
(`BIN=$(swift build --show-bin-path); printf 'south\nnorth\nwest\nhang cloak on hook\neast\nsouth\nread message\n' | "$BIN/CloakOfDarkness"` — never pipe through `swift run`).
Final: full suite Debug, push, CI covers Release + lint + template.

## Decisions

- **#verb macro confirmed** (user, 2026-07-03): swift-syntax accepted as the first
  consumer-facing dependency.
- Template form: ready-to-copy `Templates/NewGame/` package (recommended; not contested).
