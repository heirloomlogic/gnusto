# Phase 6 — Pattern Grammar & Player Dialogue: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline) or
> superpowers:subagent-driven-development to implement this plan task-by-task.

Part of the approved Gnusto roadmap (Phases 5–10, "The Road to Zork 1"). Phase 6 replaces
the fixed five-shape verb syntax with a general pattern grammar, and teaches the engine the
conversational parser moves a Zork-sized game needs: pronouns ("take lamp. rub it."),
multi-object commands ("take all"), disambiguation and completion round-trips ("Which do
you mean…?" / "What do you want to take?" answered on the next line), a re-skinnable
`GameText` table so a game can speak in its own voice, and a seeded RNG so random text and
events replay deterministically in transcripts and saves.

**Goal:** a player can type `take all`, `drop it`, answer `brass` to "Which do you mean…?",
and a game can say `Snagged.` instead of `Taken.` — all deterministic under a fixed seed.

**Architecture:** the parser stays a pure function; everything stateful (pronoun bindings,
pending clarification questions, RNG state) lives in `WorldState` or on the `GameWorld`
actor. Multi-object commands expand in `GameWorld` (which has state) into per-object runs of
the existing pipeline stages, so rules always see single-object `Command`s.

**Tech stack:** Swift 6, zero dependencies, Swift Testing (`@Test`/`#expect`), transcript
tests via `play(game, [commands])` + `expectInOrder`.

## Global Constraints

- **Verification**: `swift test` (Debug) must pass after every task. `swift test -c release`
  has a known toolchain quirk on this Mac (suite doesn't run) — Debug is authoritative locally.
- **No-regression canary**: `Sources/CloakOfDarkness/OperaHouse.swift` must need ZERO source
  changes, and `CloakTranscriptTests` must pass byte-identical. Test fixture games may be
  updated only where a task explicitly says so (the `SyntaxRule` rewrite touches every
  custom-verb fixture mechanically).
- **TDD**: write the failing test first.
- **No legacy shims**: superseded APIs are deleted outright (`SyntaxRule.Slots`, the
  `Messages` enum), never deprecated or wrapped. Zero users.
- **Idioms** (match existing code exactly):
  - All mutable state lives in `WorldState`; mutation only inside `frame.with { }`; never
    evaluate `id`/`Ctx.current` inside a `with` closure (lock recursion traps).
  - Rules/actions signal with `try refuse(…)`/`try reply(…)`; `say(…)` appends without
    interrupting.
  - Fatal bootstrap problems accumulate in `BootstrapError` (report ALL at once); non-fatal
    notes append to `GameDefinition.warnings`.
  - Parse errors are free: no rules run, `moves` doesn't advance.
- **Zork 1 fidelity**: any new Zork slice text is PLACEHOLDER prose written fresh for this
  repo (see `FIDELITY.md`); never Infocom's text.
- **Commits**: one or more per task; message ends with
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

---

## Task 1: Pattern grammar — `SyntaxElement` replaces `Slots`

**Goal**: a verb row is a free-form pattern of literal words and typed slots, so games can
declare shapes the fixed enum can't: `give <obj> to <obj>`, `turn <obj> on`,
`dig <obj> with <obj>`, three-word verbs, and so on.

**Files:**
- Modify: `Sources/Gnusto/Actions/SyntaxRule.swift` (delete `Slots`, add `SyntaxElement`,
  rewrite `standardTable` in the new syntax)
- Modify: `Sources/Gnusto/Parser/StandardParser.swift` (general pattern matcher)
- Modify: `Sources/Gnusto/Engine/Bootstrap.swift` (vocabulary harvest + pattern validation)
- Modify (mechanical, same shapes re-expressed): `Tests/GnustoTests/Support/CustomVerbGames.swift`,
  `ActionGames.swift`, `OverridePrecedenceGames.swift`, `CommerceGame.swift`,
  `ShrineContent.swift`, `CustomStateGames.swift`, `DslQuickWinGames.swift`,
  `BundleGame/AtticContent.swift`, `Sources/Gnusto/Declarations/GamePlugin.swift` (doc comment)
- Test: `Tests/GnustoTests/ParserTests.swift` (existing table-driven cases must keep passing),
  new `PatternGrammarTests.swift`

**Spec**:
1. New public element type in `SyntaxRule.swift`:

   ```swift
   /// One element of a verb pattern: a literal word the player must type, or
   /// a slot the parser fills. String literals in a pattern are `.word`s.
   public enum SyntaxElement: Sendable, Hashable, ExpressibleByStringLiteral {
       case word(String)
       case directObject
       case indirectObject
       case direction
       public init(stringLiteral value: String) { self = .word(value) }
   }
   ```

2. `SyntaxRule` becomes `let elements: [SyntaxElement]` + `let intent: Intent`, with
   `public init(_ elements: SyntaxElement..., intent: Intent)`. String literals make the
   table read naturally:

   ```swift
   .init("take", .directObject, intent: .take)
   .init("pick", "up", .directObject, intent: .take)
   .init("pick", .directObject, "up", intent: .take)
   .init("put", .directObject, "on", .indirectObject, intent: .putOn)
   .init("go", .direction, intent: .go)
   .init("look", intent: .look)
   ```

   Delete `Slots` and the old `init(_ verb: String..., slots:intent:)` outright.
   `Key` (dedupe/last-wins identity) becomes the element array. `extraWord` is replaced by
   `var literalWords: [String]` (every `.word`'s text, in order). `specificity` becomes
   `literalWords.count * 10 + slotCount` (slotCount = non-word elements); document that ties
   are broken by stable sort order, and that the old ordering behavior is preserved for the
   standard table (verified by the existing `ParserTests` cases).
3. Parser: replace the five-case `switch rule.slots` with one pattern matcher. Walk the
   elements over the token remainder with a cursor:
   - `.word(w)` directly after a literal (or at pattern start): the current token must equal
     `w`, else this rule structurally fails (try the next candidate).
   - `.word(w)` after an *open* object slot: scan for the first occurrence of `w` after the
     cursor; the tokens between cursor and it (must be non-empty) become that slot's phrase.
   - `.directObject`/`.indirectObject` as the last element: consumes all remaining tokens;
     if none remain, record the near-miss `.missingObject(verb:)` (first slot) or
     `.missingIndirect(verb:objectName:preposition:)` (second slot, when the first phrase
     resolves — same behavior as today's "hang cloak").
   - `.directObject`/`.indirectObject` mid-pattern: opens a slot that the next `.word`
     closes (validation guarantees a `.word` follows).
   - `.direction`: one token looked up in `vocabulary.directions`; special case preserved:
     a pattern ending in `.direction` with no tokens left parses successfully with a `nil`
     direction (bare "go" → default action asks "Which way?").
   - After the walk, all tokens must be consumed.
   Candidate filtering: a rule is a candidate when the tokens start with its leading run of
   `.word`s. `verbPhrase` = the leading `.word` run joined by spaces. `preposition` on
   `ParsedCommand` = the first `.word` *after* the direct-object slot, if any. Slot-phrase
   resolution via the existing `resolve(_:in:)`, near-miss bookkeeping (`bestFailure`)
   unchanged.
4. Bootstrap: harvest the first `.word` of each rule into `verbWords` and every subsequent
   `.word` into `prepositions`. Validate each *custom* rule (fatal diagnostics, all at once):
   - pattern must start with `.word`;
   - at most one `.directObject` and one `.indirectObject`; `.indirectObject` only after
     `.directObject`; at most one `.direction`; `.direction` never combined with object slots;
   - two object slots must have at least one `.word` between them;
   - an object slot not at the end must be immediately followed by a `.word`.
   (The standard table is covered by the parser tests, not runtime validation.)
5. Re-express every fixture's `verbs` rows in the new syntax (`slots: .direct` →
   `.directObject`, `slots: .directPrepIndirect("with")` → `.directObject, "with",
   .indirectObject`, etc.). No behavioral change intended anywhere.

**Tests** (`PatternGrammarTests.swift`, fixture game with custom verbs):
- `give <obj> to <obj>` parses with both objects and `preposition == "to"`.
- Both `turn <obj> on` and `turn on <obj>` rows coexist and each parses ("turn lamp on",
  "turn on lamp") to the same intent.
- A three-literal verb (`look under <obj>`) beats shorter rows by specificity.
- Malformed custom patterns (leading slot; two adjacent object slots; direction + object)
  each produce a fatal bootstrap diagnostic, and multiple problems report together.
- Full existing suite green (`ParserTests` unchanged is the acceptance for the rewrite).

## Task 2: Pronouns — "it"

**Goal**: `take lamp` then `rub it` works; `it` follows the last direct object the player
named, across turns, and survives save (it lives in `WorldState`).

**Files:**
- Modify: `Sources/Gnusto/Engine/WorldState.swift` (`var pronounIt: EntityID?`)
- Modify: `Sources/Gnusto/Parser/StandardParser.swift` (`Scope` gains `pronounIt`,
  resolution special case), `Sources/Gnusto/Parser/ParseError.swift` (`.noReferent(String)`)
- Modify: `Sources/Gnusto/Engine/GameWorld.swift` (bind after parse, pass into `Scope`)
- Modify: `Sources/Gnusto/Actions/Messages.swift` (`noReferent`), `Bootstrap.swift`
  (reserved-word warning)
- Test: new `PronounTests.swift`

**Spec**:
1. `Scope` gains `let pronounIt: EntityID?` (and, in Task 3, `pronounThem: [EntityID]`).
   `GameWorld.currentScope()` reads it from `state`.
2. In `resolve(_:in:)`, before lexicon matching: a phrase that is exactly `["it"]` resolves
   to `scope.pronounIt` — visible → success; bound but not visible → `.notInScope`; unbound
   → `.noReferent("it")` with message `I don't know what "it" refers to.`
3. After a successful parse (in `perform`, before `runTurn`), if the parsed command has a
   direct object, bind `state.pronounIt` to it. (Binding happens even if the action then
   refuses — the player *named* the thing.) Note the write happens on the actor before the
   frame exists, so mutate `state` directly.
4. Bootstrap: non-fatal warning when an item's nouns/synonyms claim a reserved parser word
   (`it`, `them`, `all`, `everything`) — the pronoun/`all` checks run first, so such an item
   could never be referred to by that word.

**Tests**:
- Transcript: `take lantern` / `drop it` → "Dropped."; `x it` still describes the lantern.
- `rub it` (unknown verb aside — use `x it`) before anything is named → the no-referent line,
  and the turn is free (`moves` unchanged via a `score`-line probe or state assertion).
- Binding goes stale correctly: name an item, leave it in another room, `x it` → "You can't
  see any such thing."
- Binding sets even on a refused take (`take hook` where hook is scenery, then `x it`).
- Reserved-noun fixture (item with `synonyms("it")`) boots with a warning on
  `GameDefinition.warnings`.

## Task 3: Multi-object commands — "take all", "drop all", "them"

**Goal**: `take all` / `drop all` / `put all in sack` run the normal pipeline once per
expanded object with `name: result` lines; other verbs refuse multiple objects; `them`
refers to the last multi-object group.

**Files:**
- Modify: `Sources/Gnusto/Parser/StandardParser.swift` (`all`/`everything`/`them` markers on
  the direct slot; `ParsedCommand` gains `var multiple: MultiObject?`
  where `enum MultiObject { case all, them }`; `Scope.pronounThem`)
- Modify: `Sources/Gnusto/Engine/WorldState.swift` (`var pronounThem: [EntityID] = []`)
- Modify: `Sources/Gnusto/Engine/GameWorld.swift` (expansion, per-object execution)
- Modify: `Sources/Gnusto/Actions/Messages.swift` (new lines), `Command.swift` (doc note:
  rules always see single objects)
- Test: new `MultiObjectTests.swift`

**Spec**:
1. Parser: in the *direct* slot only, a phrase of exactly `["all"]` or `["everything"]`
   yields `multiple = .all`; exactly `["them"]` yields `multiple = .them` (resolution and
   filtering happen in `GameWorld`, which has state). In the indirect slot both fail with a
   new `ParseError.multipleNotAllowed` → `You can't use multiple objects there.`
2. `GameWorld` keeps `static let multiObjectIntents: Set<Intent> = [.take, .drop, .putIn,
   .putOn]`. A `multiple` command for any other intent returns, parse-error style (free
   turn), `You can't use multiple objects with "<verbPhrase>".` (`Messages.multipleNotAllowedWith`).
3. Expansion (on the actor, before any frame):
   - `.all` + `.take`: visible items (current `Visibility.visibleItems`) that are takable
     (`isTakable`) and not already held.
   - `.all` + `.drop`: items with placement `.heldBy(.player)`.
   - `.all` + `.putIn`/`.putOn`: held items minus the indirect object itself.
   - `.them`: `state.pronounThem` filtered to currently visible.
   - Sort by display name for stable output. Empty expansion → free-turn message:
     take → `There is nothing here to take.` (`nothingToTakeHere`); drop/putIn/putOn →
     `You aren't carrying anything.` (`notCarryingAnything`); empty/stale `them` →
     the Task 2 no-referent line for "them".
4. Execution: extract stages 1–5 of `runTurn` (the `do/catch` block) into
   `performStages(_ command: Command, frame: TurnFrame)`. Single-object turns call it once
   (behavior identical). A multi-object turn loops over the expansion: per object, reset
   `defaultRan` (each object gets its own stage-4; `proceed()`'s once-per-turn guard becomes
   once-per-object), build a single-object `Command`, record `output.count`, run
   `performStages`, then merge that object's appended output entries into one entry:
   `"<display name>: " + entries.joined(separator: " ")`. If an object's run ends the game
   (`state.status != .playing`), stop the loop. Stage 6 (each-turn rules, `moves += 1`) runs
   ONCE for the whole command. After a multi run, bind `state.pronounThem` to the expanded
   IDs (and leave `pronounIt` alone).
5. Rules and default actions are untouched: they always receive a single-object `Command`.

**Tests** (fixture room with several takables, one scenery, one held item):
- `take all` → one `name: Taken.` line per item, name-sorted; scenery and already-held
  excluded; a second `take all` → `There is nothing here to take.` and costs no turn.
- `drop all` includes a worn item and merges its two messages:
  `velvet cloak: (first taking off the velvet cloak) Dropped.`
- `put all in sack` skips the sack itself.
- `open all` → the multiple-objects refusal, no turn consumed.
- A `before(.take)` rule that refuses one specific item shows the refusal on that item's
  line while the others are taken (per-object pipeline proof).
- `take all` then `drop them` drops exactly the group.
- An each-turn world rule fires exactly once during `take all` (stage 6 runs once).

## Task 4: Disambiguation & completion round-trip

**Goal**: the parser's clarifying questions become real questions: the next input line can
answer them, by naming adjectives ("brass"), a fuller phrase ("the rusty lantern"), or the
missing object — or ignore them and issue a fresh command.

**Files:**
- Modify: `Sources/Gnusto/Parser/ParseError.swift` (question context: insertion point)
- Modify: `Sources/Gnusto/Parser/StandardParser.swift` (attach token positions; internal
  `parse(tokens:scope:)` entry so augmented reparses skip re-tokenizing)
- Modify: `Sources/Gnusto/Engine/GameWorld.swift` (`pendingClarification` actor state)
- Test: new `DisambiguationTests.swift` (fixture with a brass lantern and a rusty lantern)

**Spec**:
1. The three question-type errors carry where the answer belongs, as token arrays:
   `.ambiguous(names: [String], prefix: [String], suffix: [String])`,
   `.missingObject(verb: String, prefix: [String])` (suffix is empty),
   `.missingIndirect(verb:objectName:preposition:prefix:)` — where the augmented command is
   `prefix + answerTokens + suffix`. For an ambiguous phrase spanning `tokens[a..<b]`:
   `prefix = tokens[..<a]`, `suffix = tokens[a...]` — the answer's adjectives *prepend* to
   the phrase ("brass" + "lantern"), and a fuller answer simply adds redundant matching
   words. Player-facing messages are unchanged.
2. `GameWorld` gains `private var pendingClarification: (prefix: [String], suffix: [String])?`.
   In `perform`:
   - No pending: parse normally; a question-type failure sets `pendingClarification` (the
     question was already the returned output; parse errors stay free).
   - Pending: tokenize the input and try `parse(tokens: prefix + answer + suffix)`.
     Success → clear pending, run. Question-type failure (e.g. still ambiguous between two
     brass lanterns) → update pending to the new context and return the new question. Any
     other failure → clear pending and parse the input as a fresh command (so `look` or
     `take sword` abandons the question); the fresh result is handled normally (including
     setting a new pending if it asks its own question).
3. A successful command always clears pending. Questions never consume a turn.

**Tests**:
- `take lantern` → "Which do you mean: the brass lantern or the rusty lantern?" (free turn);
  `brass` → "Taken." — and `moves` counted exactly one turn total.
- Answer with a full phrase (`the rusty lantern`) works.
- `take` → "What do you want to take?"; `brass lantern` → "Taken."
- `hang cloak` (fixture with hook) → "What do you want to hang the … on?"; `hook` completes it.
- Ignoring the question with a fresh command (`look`) works; the pending is gone afterward
  (a later bare `brass` reports normally instead of completing anything).
- Two-round narrowing: three lanterns where the answer `brass` still matches two → a second
  question, then `small` resolves.

## Task 5: `GameText` — the re-skinnable voice

**Goal**: every stock player-facing string lives on a public `GameText` value a game can
override wholesale or per-line; the internal `Messages` enum is deleted.

**Files:**
- Create: `Sources/Gnusto/Actions/GameText.swift`
- Delete: `Sources/Gnusto/Actions/Messages.swift`
- Modify: `Sources/Gnusto/Declarations/Game.swift` (defaulted `var text: GameText`),
  `Engine/GameDefinition.swift` (+ `let text: GameText`), `Engine/Bootstrap.swift` (pass
  through), `Actions/DefaultActions.swift`, `Engine/RoomDescriber.swift`,
  `Engine/GameWorld.swift`, `Parser/ParseError.swift` (`playerMessage(_ text: GameText)`)
- Test: new `GameTextTests.swift`

**Spec**:
1. `public struct GameText: Sendable` with `public init()` and one `public var` per current
   `Messages` member (same names: `taken`, `dropped`, `cantGoThatWay`, …), including the
   members added by Tasks 2–4 (`noReferent`, `multipleNotAllowed`, `nothingToTakeHere`,
   `notCarryingAnything`, …). Parameterized messages are `@Sendable` closures with the
   defaults inlined, e.g.
   `public var cantReach: @Sendable (String) -> String = { "You can't reach the \($0)." }`.
   The article/list helpers (`indefinite`, `indefiniteList`) become `public static func`s on
   `GameText` — formatting utilities games can reuse, not skinnable lines.
2. `Game` gains `var text: GameText { get }`, defaulted to `GameText()`; it lands on
   `GameDefinition.text`. Call sites read `frame.definition.text.…`; `ParseError.playerMessage`
   becomes `playerMessage(_ text: GameText)` (its only caller, `GameWorld.perform`, has the
   definition).
3. Rule-body access for authors: `frame`-less code already gets text implicitly through
   defaults; no new global is added (a game that wants its own lines in rules just writes
   them — `GameText` is for the *engine's* stock lines).

**Tests**:
- Fixture overriding `taken = "Snagged."` and `cantGoThatWay`; transcript shows both.
- Defaults unchanged: the Cloak canary transcript stays byte-identical (existing test).

## Task 6: Seeded RNG

**Goal**: rule bodies can vary text and outcomes (`oneOf`, `chance`, `random`) with all
randomness flowing through one seedable, savable stream — same seed, same game.

**Files:**
- Create: `Sources/Gnusto/Declarations/Randomness.swift`
- Modify: `Sources/Gnusto/Engine/WorldState.swift` (`var rngState: UInt64 = 0`),
  `Engine/GameWorld.swift` (seeding inits)
- Test: new `RandomnessTests.swift`

**Spec**:
1. `WorldState.rngState: UInt64` (Codable — restore resumes the exact stream; Phase 7's
   save/restore gets determinism for free).
2. `GameWorld` gains `public init(game: some Game, seed: UInt64) throws` which sets
   `state.rngState = seed &+ 0x9E3779B97F4A7C15` after bootstrap; the existing
   `init(game:)` delegates with `seed: UInt64.random(in: .min ... .max)`.
3. `Randomness.swift`: an internal SplitMix64 step
   (`func nextRandom(_ state: inout WorldState) -> UInt64` — advance `rngState`, return the
   mixed value; the reference constants: increment `0x9E37_79B9_7F4A_7C15`, mix with
   `z ^= z >> 30; z &*= 0xBF58_476D_1CE4_E5B9; z ^= z >> 27; z &*= 0x94D0_49BB_1331_11EB;
   z ^= z >> 31`), plus public helpers usable in rule bodies (all via
   `Ctx.current.with { }`):
   - `public func random(_ range: ClosedRange<Int>) -> Int`
   - `public func oneOf(_ options: String...) -> String` and `public func oneOf(_ options: [String]) -> String`
   - `public func chance(_ percent: Int) -> Bool` (percent of 100)
   Modulo reduction is fine (games, not cryptography) — say so in a comment.
4. Platform-independent by construction (pure integer arithmetic; document that transcripts
   with a fixed seed are reproducible everywhere).

**Tests**:
- Two worlds with the same seed produce identical transcripts through a rule using
  `oneOf`/`random`/`chance`; a different seed diverges somewhere in a long-enough run.
- `random(1...1) == 1`, `chance(100)`/`chance(0)` are certain.
- Round-trip: copying `rngState` mid-stream and replaying yields the same tail (asserted at
  the `WorldState` level).

## Task 7: Zork slice exercise + integration transcript

**Goal**: prove the phase on the White House slice with a played transcript — and keep all
prose placeholder.

**Files:**
- Modify: `Sources/Zork1/House.swift` / `Prose.swift` only if a small placeholder line is
  needed; `Tests/GnustoTests/Zork1Tests.swift`

**Spec**: a transcript test walking the slice: `take all` in the kitchen (sack, bottle —
name-labeled lines), `drop all`, `take sack` / `open it` / `look in it` (pronoun through
containers), and a disambiguation exchange if the slice has a natural noun collision
(if not, don't force one — the `DisambiguationTests` fixture covers it). Any new text is
original placeholder prose.

**Tests**: the transcript above via `play(Zork1(), …)` + `expectInOrder`.

## Task 8: Documentation

**Goal**: authors learn the pattern grammar and the new dialogue behavior from DocC.

**Files:**
- Modify: `Sources/Gnusto/Documentation.docc/AddingCustomVerbs.md` (rewrite for
  `SyntaxElement` patterns: literals, slots, validation rules, specificity)
- Create: `Sources/Gnusto/Documentation.docc/TextAndRandomness.md` (`GameText` overrides;
  `oneOf`/`random`/`chance`; seeding and transcript determinism)
- Modify: `Sources/Gnusto/Documentation.docc/Documentation.md` (topics list),
  `TheTurnPipeline.md` (a short "how the parser converses" section: pronouns, `all`
  expansion running the pipeline per object, clarification questions being free turns)

**Tests**: `swift build` (DocC articles are compiled for syntax only in CI's docs job; no
unit tests).

---

## Self-review notes

- Task 1 must land first (2–4 build on the pattern matcher's slot positions).
- Tasks 2→3→4 in order (3 reuses 2's `Scope` plumbing; 4 reuses 1's position bookkeeping).
- Task 5 after 2–4 so the new messages move into `GameText` once, in one sweep.
- Task 6 is independent; scheduled late to keep the parser work contiguous.
- `ParsedCommand` gains fields in 2–4; `ParserTests`' `Expected` comparisons are on
  intent/objects/direction and stay valid.
- Type names used across tasks: `SyntaxElement`, `ParsedCommand.multiple` (`MultiObject`),
  `Scope.pronounIt`/`pronounThem`, `WorldState.pronounIt`/`pronounThem`/`rngState`,
  `GameText`, `GameWorld.performStages`. Grep before renaming anything.
