# Phase 7 — Time, Light, and Death: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline) or
> superpowers:subagent-driven-development to implement this plan task-by-task.

Part of the approved Gnusto roadmap (Phases 5–10, "The Road to Zork 1"). Phase 7 makes the
world's clock and the world's darkness real: items can carry light into dark rooms (`turn on
lantern`), fuses and daemons tick once per typed command (the ZIL QUEUE/CLOCKER model), the
player can SAVE / RESTORE / UNDO / RESTART, a `die(…)` helper ends the player without ending
the program (the classic post-death prompt), and the Zork 1 slice grows the cellar region —
where lingering in the dark now gets you eaten by a grue. This closes the seam documented in
`FIDELITY.md`: the dark-cellar soft-lock becomes survivable (lit lantern, chimney escape) or
lethal (grue), never merely stuck.

**Goal:** a player can descend the trap door with a lit brass lantern, walk the Cellar →
East of Chasm → Gallery → Studio loop, escape up the chimney with the painting, watch the
lantern burn down on a timer, die to a grue if they dawdle in the dark, and UNDO/RESTORE
their way back — all reproducible in transcript tests.

**Architecture:** lit/unlit item state, the fuse/daemon *schedule*, and everything else that
changes lives in `WorldState` (Codable, so save/restore is a serialization call away — and
`rngState` already rides along, so a restored game replays the exact random stream). Timer
*bodies* are closures registered declaratively at bootstrap and re-bound by name on restore;
they are never serialized. The save-filename prompt and the death prompt reuse the shape
`pendingClarification` proved in Phase 6: pending state on the `GameWorld` actor consumes the
next input line, so `REPL` and `IOHandler` need zero changes and `ScriptedIOHandler`
transcript tests drive every round-trip. The one-step UNDO snapshot lives on the actor, not
in `WorldState`, so history never leaks into save files.

**Tech stack:** Swift 6, zero dependencies (Foundation's `JSONEncoder`/`FileManager` only;
precedent: `RefToken.swift` already imports Foundation), Swift Testing (`@Test`/`#expect`),
transcript tests via `play(game, [commands], seed:)` + `expectInOrder`.

## Global Constraints

- **Verification**: `swift test` (Debug) must pass after every task. `swift test -c release`
  has a known toolchain quirk on this Mac (suite doesn't run) — Debug is authoritative locally.
- **No-regression canary**: `Sources/CloakOfDarkness/OperaHouse.swift` must need ZERO source
  changes, and `CloakTranscriptTests` must pass byte-identical. Cloak has no light-source
  items and never dies, so every task below is additive from its point of view — verify after
  each task anyway.
- **TDD**: write the failing test first.
- **No legacy shims**: superseded behavior is replaced outright. The one deliberate deletion
  this phase is `Zork1Tests.darkCellarSoftLockIsThePhase7Seam` (Task 7), whose replacement
  tests are specified there — the seam it pins is the thing this phase removes.
- **Idioms** (match existing code exactly):
  - All mutable state lives in `WorldState`; mutation only inside `frame.with { }`; never
    evaluate `id`/`Ctx.current` inside a `with` closure (lock recursion traps).
  - Rules/actions signal with `try refuse(…)`/`try reply(…)`; `say(…)` appends without
    interrupting; programmer errors trap with a clear `Gnusto:` message.
  - The engine branches only on built-in traits ("closed core, open edges").
  - Fatal bootstrap problems accumulate in `BootstrapError` (report ALL at once); non-fatal
    notes append to `GameDefinition.warnings`.
  - Stock player-facing lines live on `GameText`; parse errors and meta replies are free
    (no rules, `moves` doesn't advance).
- **Zork 1 fidelity**: all new Zork slice text is PLACEHOLDER prose written fresh for this
  repo — including the grue warning; the iconic "…likely to be eaten by a grue" sentence is
  Infocom's and must NOT be used. `FIDELITY.md` is updated in Tasks 7, 8, and 9.
- **Commits**: one or more per task; message ends with
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

---

## Task 1: Light sources — `lightSource` trait, `litItems`, and the darkness predicate

**Goal**: an item can be a light source with lit/unlit runtime state, and
`Visibility.isDark` counts a lit source carried by the player or shining in the room — the
engine-side half of closing the dark-cellar seam.

**Files:**
- Modify: `Sources/Gnusto/Declarations/Traits.swift` (`.lightSource`, `.startsLit` trait
  kinds + public `lightSource`/`startsLit` values)
- Modify: `Sources/Gnusto/Engine/GameDefinition.swift` (`ItemDefinition.isLightSource`,
  `ItemDefinition.startsLit`)
- Modify: `Sources/Gnusto/Engine/WorldState.swift` (`var litItems: Set<EntityID> = []`)
- Modify: `Sources/Gnusto/Engine/Bootstrap.swift` (seed `litItems`; warning for `startsLit`
  without `lightSource`)
- Modify: `Sources/Gnusto/Engine/Visibility.swift` (rework `isDark`, delete its stale
  "Seam:" comment; new private `lightReaches`)
- Modify: `Sources/Gnusto/Declarations/Item.swift` (`var isLit: Bool` proxy),
  `Sources/Gnusto/Declarations/Location.swift` (`isLit` getter reworked)
- Create: `Tests/GnustoTests/LightSourceTests.swift`,
  `Tests/GnustoTests/Support/LightGames.swift` (fixture: a lit-by-default `torch`, an unlit
  `lamp`, a `dark` cave, a glass box, an opaque chest, a shelf)

**Spec**:
1. Two new item traits, mirroring `openable`/`startsOpen` exactly:
   `public let lightSource = ItemTrait(kind: .lightSource)` (the item can hold light) and
   `public let startsLit = ItemTrait(kind: .startsLit)` (it begins the game lit). No
   separate "switchable" trait: every `lightSource` accepts `turn on`/`turn off` by default
   (Task 2), and an always-lit torch is `lightSource` + `startsLit` plus a game rule
   refusing `.turnOff` — one trait fewer, and the Zork slice needs nothing more.
2. `WorldState.litItems: Set<EntityID>` mirrors `openItems`: only `lightSource` items ever
   appear in it (Bootstrap seeds `items.filter { $0.value.isLightSource && $0.value.startsLit }`;
   the proxy setter guards). New non-fatal bootstrap warning:
   `item "candle" declares startsLit but is not a lightSource; the flag has no effect.`
3. `Item.isLit: Bool { get set }` proxy, modeled on `isLocked` (setter is a silent no-op for
   non-`lightSource` items; it also does *not* auto-describe the room — only the Task-2
   default actions announce light changes; document that on the property).
4. `Visibility.isDark(at:definition:state:)` becomes:
   room in `litRooms` → not dark; otherwise dark unless some member of `state.litItems`
   *reaches* the room. `lightReaches(_ location:, from id:, definition:, state:)` walks UP
   the placement chain from the lit item (bounded by a `visited` set against runtime cycles,
   same rationale as `collect`):
   - `.room(let r)` → `r == location`;
   - `.heldBy(.player)` → `location == state.playerLocation` (a carried lamp lights only the
     room the player is in); any other holder → false;
   - `.on(let parent)` → continue up from `parent`;
   - `.inside(let parent)` → continue up only if the container is open
     (`Visibility.isOpen`) **or** `transparent` (light passes through glass both ways —
     symmetric with the visibility walk); a closed opaque container swallows the light;
   - `.nowhere`/missing → false.
   This deliberately does **not** reuse `visibleItems` — visibility depends on darkness, so
   the light computation must be a pure placement walk (no circularity). A `hidden` lit item
   still counts: it is the light that matters, not whether the player has noticed the item.
5. The dark early-return in `collect` is **unchanged** — a genuinely dark room still
   collapses scope (contents and exit doors). The seam closes because a lit source makes
   `isDark` false, not because dark scope grows.
6. `Location.isLit` **getter** becomes `!Visibility.isDark(at:…)` (the one darkness
   predicate everywhere); the **setter** keeps writing `litRooms` (the room's own light).
   Asymmetry documented on the property: read "is there light here", write "give/remove the
   room's inherent light". Cloak reads `bar.isLit` with no light sources in play — identical
   result.

**Tests** (`LightSourceTests.swift`; drive state via fixture rules, since the verbs land in
Task 2):
- Entering the dark cave with the lit torch held → room described, not `pitchBlack`; and
  `visited` gets marked (assert via a second entry being brief).
- Lit torch left in the cave lights it for a lampless player; carrying it away re-darkens.
- Lit torch on the shelf in the cave → lit; inside the open chest → lit; inside the closed
  opaque chest → `pitchBlack`; inside the closed glass box → lit.
- A lit source in room A does not light dark room B; a carried lit source lights only the
  player's room.
- A rule flipping `lamp.isLit = true` while in the dark cave: the *next* `look` shows the
  room (no auto-describe from the raw setter).
- Bootstrap: `startsLit`-without-`lightSource` fixture boots with the warning on
  `GameDefinition.warnings`; `isLit` setter on a plain item is a no-op.
- `DarknessTests`, `VisibilityTests`, `CloakTranscriptTests` unchanged and green.

## Task 2: `turn on` / `turn off` / `light` / `extinguish` — and light reveals the room

**Goal**: the player operates light sources with real verbs, and the classic beats land:
lighting a lamp in the dark prints the room; extinguishing the only light announces the
darkness.

**Files:**
- Modify: `Sources/Gnusto/Actions/Command.swift` (`Intent.turnOn`, `Intent.turnOff`)
- Modify: `Sources/Gnusto/Actions/SyntaxRule.swift` (standard-table rows)
- Modify: `Sources/Gnusto/Actions/DefaultActions.swift` (`turnOn`/`turnOff` defaults;
  `builtInIntents` grows)
- Modify: `Sources/Gnusto/Actions/GameText.swift` (new lines)
- Test: extend `Tests/GnustoTests/LightSourceTests.swift`

**Spec**:
1. New intents `Intent.turnOn` (`"turnOn"`) and `Intent.turnOff` (`"turnOff"`) — *one intent
   per action*: "light lamp" and "turn on lamp" are the same act, so rules key on one intent.
   Not meta; they are ordinary world actions (rules see them, `moves` advances).
2. Standard-table rows (both particle orders, per the `pick up` precedent):
   ```swift
   .init("turn", "on", .directObject, intent: .turnOn),
   .init("turn", .directObject, "on", intent: .turnOn),
   .init("switch", "on", .directObject, intent: .turnOn),
   .init("switch", .directObject, "on", intent: .turnOn),
   .init("light", .directObject, intent: .turnOn),
   .init("turn", "off", .directObject, intent: .turnOff),
   .init("turn", .directObject, "off", intent: .turnOff),
   .init("switch", "off", .directObject, intent: .turnOff),
   .init("switch", .directObject, "off", intent: .turnOff),
   .init("extinguish", .directObject, intent: .turnOff),
   .init("douse", .directObject, intent: .turnOff),
   .init("blow", "out", .directObject, intent: .turnOff),
   .init("blow", .directObject, "out", intent: .turnOff),
   ```
3. `DefaultActions.turnOn`: require direct object; `isLightSource` else
   `refuse(text.cantTurnOnThat)`; reachable else `cantReach`; already lit →
   `refuse(text.alreadyOn)`. Then, in one place: capture `wasDark = Visibility.isDark(at:
   playerLocation…)` *before* inserting into `litItems` (and `touched`), say
   `text.nowOn(item.name)`, and if `wasDark` and the room is now lit, call
   `RoomDescriber.describeCurrentLocation(mode: .look, frame: frame)` — verbose, the classic
   "the room is revealed" moment (and `RoomDescriber` marks it visited for free).
4. `DefaultActions.turnOff` mirrors: `cantTurnOffThat`, `alreadyOff`, remove from
   `litItems`, say `text.nowOff(item.name)`, and if the room was lit and is now dark, say
   `text.nowDark`.
5. New `GameText` members (defaults):
   - `nowOn: (name) -> "The \($0) is now on."`
   - `nowOff: (name) -> "The \($0) is now off."`
   - `alreadyOn = "It's already on."` / `alreadyOff = "It's already off."`
   - `cantTurnOnThat = "You can't turn that on."` / `cantTurnOffThat = "You can't turn that off."`
   - `nowDark = "It is now pitch black."`

**Tests**:
- Transcript: carry the unlit lamp into the dark cave (pitch black), `turn on lamp` → "The
  lamp is now on." followed by the full room description in the same turn; `turn off lamp` →
  "The lamp is now off." + "It is now pitch black."
- `light lamp` and `turn lamp on` behave identically to `turn on lamp`; `extinguish`/`blow
  out` mirror off.
- `turn on rock` → "You can't turn that on."; `turn on lamp` twice → "It's already on.";
  turning on a lamp visible through the closed glass box → `cantReach` (reachability guard).
- Turning the lamp on in an already-lit room prints `nowOn` only (no re-describe).
- An `item.before(.turnOff)` rule can refuse (the always-lit-torch pattern works).

## Task 3: Fuses & daemons — the world's clock

**Goal**: first-class timed events in the ZIL QUEUE/CLOCKER mold: a fuse fires once after N
turns, a daemon runs every turn while active; bodies are declared at bootstrap, schedule
state is pure `Codable` data, and everything ticks exactly once per typed command.

**Files:**
- Create: `Sources/Gnusto/Declarations/Timers.swift` (`TimedEvent`, `fuse`/`daemon`
  factories, rule-body helpers)
- Modify: `Sources/Gnusto/Declarations/Builders.swift`
  (`public typealias TimerBuilder = GnustoBuilder<TimedEvent>`)
- Modify: `Sources/Gnusto/Declarations/Game.swift`, `Declarations/GameContent.swift`
  (`@TimerBuilder var timers: [TimedEvent] { get }`, defaulted `[]` — same shape as `verbs`)
- Modify: `Sources/Gnusto/Engine/WorldState.swift`
  (`var activeFuses: [String: Int] = [:]`, `var activeDaemons: Set<String> = []`)
- Modify: `Sources/Gnusto/Engine/GameDefinition.swift`
  (`var timers: [String: TimedEvent] = [:]`, installed post-registration like `rules`)
- Modify: `Sources/Gnusto/Engine/Bootstrap.swift` (collect, validate, seed autostarts)
- Modify: `Sources/Gnusto/Engine/GameWorld.swift` (`tickTimers(frame:)` in `finishTurn`)
- Test: `Tests/GnustoTests/TimerTests.swift`, `Tests/GnustoTests/Support/TimerGames.swift`

**Spec**:
1. ```swift
   /// A named timed event: a fuse (fires once, N turns after it is started)
   /// or a daemon (runs at the end of every turn while active). The body is
   /// registered at bootstrap and never serialized; only the schedule
   /// (name → turns remaining / active flag) lives in WorldState.
   public struct TimedEvent: Sendable {
       enum Kind: Sendable { case fuse(turns: Int), daemon }
       let name: String
       let kind: Kind
       let autostart: Bool
       let body: @Sendable () throws -> Void
   }
   public func fuse(_ name: String, after turns: Int, autostart: Bool = false,
                    perform body: @escaping @Sendable () throws -> Void) -> TimedEvent
   public func daemon(_ name: String, autostart: Bool = false,
                      perform body: @escaping @Sendable () throws -> Void) -> TimedEvent
   ```
   A dedicated `timers` block (not the `rules` builder) because `Rules` is
   `GnustoBuilder<Rule>` and timers are a different element type; `verbs`/`actions` set the
   precedent for parallel blocks. `autostart` exists because rule bodies can't run at
   bootstrap, and a from-turn-one daemon (the grue) shouldn't need a start-me rule.
2. Bootstrap phase (alongside `rules`, inside the registration frame): collect
   `game.timers + modules.flatMap(\.timers)`. Fatal diagnostics, accumulated: duplicate name
   (`two timers are both named "grue"; timer names must be unique across the game and its
   bundles`); `fuse(after: n)` with `n < 1`. Timer names are global, not namespaced — a
   bundle's body calls `startFuse("lanternDies")` by the literal name it declared, so
   namespacing would break the author's own string; the duplicate diagnostic is the
   collision guard. Then seed: autostart fuse → `state.activeFuses[name] = turns`;
   autostart daemon → `state.activeDaemons.insert(name)`.
3. Rule-body helpers (in `Timers.swift`, all via `Ctx.current`, all trapping with a clear
   `Gnusto:` message on an undeclared name or a fuse/daemon kind mismatch — programmer
   errors, matching the `proceed()` policy):
   - `public func startFuse(_ name: String, after turns: Int? = nil)` — `nil` uses the
     declared count; restarting an already-running fuse resets it (documented).
   - `public func stopFuse(_ name: String)` — no-op if not running.
   - `public func fuseRemaining(_ name: String) -> Int?` — `nil` when not running.
   - `public func startDaemon(_ name: String)` / `public func stopDaemon(_ name: String)` /
     `public func isDaemonActive(_ name: String) -> Bool`.
4. `GameWorld.finishTurn` gains the tick, inside the existing non-meta block, *after* the
   each-turn/world-after rules and *before* `moves += 1`, re-guarded on
   `status == .playing` (an each-turn rule may have ended the game):
   ```swift
   if !intent.isMeta {
       if frame.with({ $0.state.status }) == .playing { …each-turn rules… }
       if frame.with({ $0.state.status }) == .playing { tickTimers(frame: frame) }
       frame.with { $0.state.moves += 1 }
   }
   ```
   Timers are the world's clock and fire last, after the rules have reacted to the command
   (ZIL's CLOCKER also ran at end of turn). Because `finishTurn` runs once per typed command
   (already true for multi-object commands) and never for meta intents or parse errors, the
   required tick discipline falls out structurally: daemons DO run on refused turns (world
   time passes), DON'T run on parse errors or once `status != .playing`.
5. `tickTimers` semantics, deterministic and re-entrant-safe:
   - Snapshot the active fuse names, sorted; for each, re-check it is still scheduled (an
     earlier body may have stopped it), decrement; at zero, remove from `activeFuses`
     *first*, then run the body. A fuse started during a turn ticks at the end of that same
     turn (so `fuse(after: 1)` started mid-turn fires that turn's end) — documented, and
     pinned by a test.
   - Then the active daemons, name-sorted, same re-check; a daemon started during a turn
     first runs at the end of that same turn (symmetric with fuses).
   - Each body runs under the same interrupt handling as `runCatching` (`refused`/`replied`
     print; game-over sets status); after each body, bail out if `status != .playing`.
6. Save-format note (consumed by Task 5): `activeFuses`/`activeDaemons` are already in
   `WorldState`, so schedules save for free; on restore, names re-bind to
   `definition.timers` bodies, and unknown names are dropped (spec'd in Task 5).

**Tests** (`TimerGames.swift` fixture: verbs like `prime`/`defuse`/`summon`/`banish` whose
rules call the helpers; a `fuse("bomb", after: 3)`, a `daemon("drip")`, an autostart daemon,
an autostart fuse):
- `prime` then three filler turns → the bomb body's line appears exactly at the end of the
  third turn, and never again; `fuseRemaining("bomb")` counts down (probe verb reports it).
- `defuse` before it fires → never fires; restarting resets the count.
- `summon` → drip line at the end of that same turn and each turn after; `banish` stops it;
  a refused turn still drips; a parse error (`xyzzy`) does not.
- Autostart daemon runs from turn 1 with no rule involved.
- `take all` over three objects → exactly one drip (tick once per command).
- A fuse body that ends the game stops later daemons that same turn.
- Bootstrap diagnostics: duplicate timer names and `after: 0` produce accumulated fatal
  diagnostics — assert both appear together.

## Task 4: UNDO and RESTART — snapshots on the actor

**Goal**: `undo` reverses exactly one turn from an in-memory pre-turn snapshot; `restart`
rewinds to the pristine post-bootstrap opening. Both are free meta commands that never touch
save files or `WorldState` history.

**Files:**
- Modify: `Sources/Gnusto/Actions/Command.swift` (`Intent.undo`, `Intent.restart`;
  `metaIntents` grows)
- Modify: `Sources/Gnusto/Actions/SyntaxRule.swift` (`.init("undo", intent: .undo)`,
  `.init("restart", intent: .restart)`)
- Modify: `Sources/Gnusto/Engine/GameWorld.swift` (`initialState`, `undoSnapshot`,
  interception in `run(_:)`, `performUndo()`, `performRestart()`)
- Modify: `Sources/Gnusto/Actions/GameText.swift` (`undone`, `cantUndo`)
- Test: `Tests/GnustoTests/UndoRestartTests.swift`

**Spec**:
1. `GameWorld` stores `private let initialState: WorldState`, captured in
   `init(game:seed:)` *after* seeding `rngState` — so RESTART replays the identical game,
   randomness included. It also gains `private var undoSnapshot: WorldState?`.
2. These verbs need the actor (snapshots), not the pipeline, so `run(_ parsed:)` intercepts
   them before pronoun binding and before any frame exists:
   ```swift
   switch parsed.intent {
   case .undo: return performUndo()
   case .restart: return performRestart()
   default: break
   }
   ```
   The intents are in `metaIntents` for semantic consistency (no rules, no `moves`), but
   they never reach `performStages`/`DefaultActions` — document on the switch that the
   Phase-7 meta verbs (undo/restart, and Task 5's save/restore) are engine-level and not
   overridable via `actionOverrides`.
3. Snapshot capture point (review refinement — NOT in `run(_:)` up front): take
   `undoSnapshot = state` at the top of `runTurn(_:)`, and in `runMultiTurn(_:_:)` only
   *after* the expansion guards succeed (just before its `TurnFrame` is created). This way
   free replies (`multipleNotAllowedWith`, empty expansion, stale `them`) do NOT clobber
   the snapshot — snapshot policy: every turn that actually runs stages, nothing else.
   Parse errors, clarification questions, and meta commands never reach these points (so
   `score` between a mistake and its `undo` doesn't destroy the snapshot). One level only.
4. `performUndo()`: no snapshot → `freeReply(text.cantUndo)`. Otherwise `state =
   undoSnapshot!`, `undoSnapshot = nil`, clear `pendingClarification`, then build a frame,
   `say(text.undone)`, `RoomDescriber.describeCurrentLocation(mode: .entry, frame:)`, and
   commit — the player sees where (and when: the status line's rewound `moves`) they are.
   RESTART/RESTORE also clear `undoSnapshot` ("undo of a restore is not a thing").
5. `performRestart()`: `state = initialState`; clear `undoSnapshot` and
   `pendingClarification`; return `begin()` (intro + banner + first look, exactly like a
   fresh boot). No are-you-sure confirmation — `quit` doesn't confirm today either; one
   consistent policy, and a confirmation layer is a later-phase nicety.
6. New `GameText`: `undone = "Previous turn undone."`, `cantUndo = "There's nothing to undo."`

**Tests**:
- `take lamp` / `undo` → "Previous turn undone.", lamp back in the room (`take lamp` works
  again), `moves` rewound (score-line probe shows the pre-take count).
- `undo` twice → second gets `cantUndo`; `undo` as the very first command → `cantUndo`;
  `undo` itself consumes no turn.
- A parse error between a turn and `undo` doesn't disturb the snapshot; a `score` doesn't
  either; an empty `take all` (free reply) doesn't either (pins the capture-point
  refinement).
- Fixed seed: command with `oneOf(…)` output → `undo` → same command → the *same* random
  line (snapshot restored `rngState`).
- `restart` → intro/banner/first-room reprinted; state reset (taken item back); `undo`
  right after restart → `cantUndo`; with a fixed seed, play after restart matches the
  original opening moves exactly.
- Multi-object: `take all` / `undo` reverses the whole command (one snapshot per typed
  command).

## Task 5: SAVE and RESTORE — files, fingerprints, and the filename prompt

**Goal**: `save` prompts for a filename and writes the whole `WorldState` as JSON with a
game fingerprint; `restore` prompts, validates, and swaps the state in. Free turns, polite
failures, works end-to-end in a `ScriptedIOHandler` transcript.

**Files:**
- Create: `Sources/Gnusto/Engine/SaveFile.swift` (`import Foundation`)
- Modify: `Sources/Gnusto/Actions/Command.swift` (`Intent.save`, `Intent.restore`;
  `metaIntents` grows), `Actions/SyntaxRule.swift` (rows `save`/`restore`)
- Modify: `Sources/Gnusto/Engine/GameWorld.swift` (`PendingPrompt`, interception, save/
  restore performers; retire the stale `TurnResult` "Seam: pendingQuery" comment — the
  pending-prompt mechanism on the actor is that seam, realized)
- Modify: `Sources/Gnusto/Actions/GameText.swift` (new lines)
- Test: `Tests/GnustoTests/SaveRestoreTests.swift`

**Spec**:
1. `SaveFile.swift`:
   ```swift
   /// The on-disk save format: a version, the game's identity, and the whole
   /// world state. Timer bodies and rules are code, not data — a restore
   /// re-binds the saved schedule to the bootstrapped definition by name.
   struct SaveFile: Codable {
       static let currentFormat = 1
       let format: Int
       let title: String
       let state: WorldState
   }
   ```
   Fingerprint is the game `title` plus the `format` int — the only stable identity a
   `Game` currently exposes (no version field exists; adding one is out of scope). Encoding
   via `JSONEncoder` with `.sortedKeys` (stable diffs); write via
   `Data.write(to:options: .atomic)`; `URL(fileURLWithPath:)` resolves relative paths
   against the current directory — exactly the classic behavior. Overwriting an existing
   file is silent (classic).
2. The filename prompt reuses the proven pending-input shape. `GameWorld` gains:
   ```swift
   private enum PendingPrompt {
       case saveFilename
       case restoreFilename(returnToDeathPrompt: Bool)   // Bool used by Task 6
       case deathChoice                                   // installed by Task 6
   }
   private var pendingPrompt: PendingPrompt?
   ```
   At the very top of `perform(_:)` (before `pendingClarification`): if a prompt is pending,
   the raw input line answers it — **not** tokenized (filenames contain dots and slashes the
   tokenizer would mangle); just trimmed of whitespace.
3. Flow: `save` parses normally, `run(_:)` intercepts → sets `pendingPrompt =
   .saveFilename`, returns `freeReply(text.savePrompt)`. Next line: empty → clear prompt,
   `freeReply(text.cancelled)`; otherwise attempt the write → `freeReply(text.saved)` or
   `freeReply(text.saveFailed)`. `restore` mirrors with
   `.restoreFilename(returnToDeathPrompt: false)`. A pending prompt cannot coexist with a
   pending clarification (a successful `save` parse means no question was open, and prompts
   are answered before parsing).
4. Restore validation, in order: file unreadable / not JSON / wrong `format` →
   `freeReply(text.restoreFailed)`; `title` mismatch → `freeReply(text.wrongGameSave)`.
   On success: filter `state.activeFuses`/`activeDaemons` down to names present in
   `definition.timers` (a same-title-different-build save shouldn't crash the tick loop;
   dropping unknown names is the defensive choice given a title-only fingerprint —
   documented in `SaveFile.swift`); assign `state`, clear `undoSnapshot`,
   `pendingClarification`, `pendingPrompt`; then frame → `say(text.restored)` +
   `RoomDescriber.describeCurrentLocation(mode: .entry, frame:)` → commit. `moves` is
   whatever was saved; the restore itself costs nothing.
5. New `GameText`:
   - `savePrompt = "Save to what file?"` / `restorePrompt = "Restore from what file?"`
   - `saved = "Saved."` / `saveFailed = "Save failed."`
   - `restored = "Restored."` / `restoreFailed = "Restore failed."`
   - `wrongGameSave = "That save file is from a different game."`
   - `cancelled = "Cancelled."`
6. Transcript shape (what tests and players see):
   ```
   > save
   Save to what file?
   > /tmp/gnusto-test-1234.sav
   Saved.
   ```

**Tests** (unique paths under `FileManager.default.temporaryDirectory`, so no cwd
dependence; tests clean up after themselves):
- Round-trip: play, `save`, keep playing (move rooms, take things, burn RNG), `restore` →
  state rewound (room, inventory, `moves`, score all match the save point; probe lines).
- RNG resumes exactly: fixed seed, a `oneOf` verb after `save`, note the line; `restore`,
  same verb → same line.
- Timer schedule round-trips: start a fuse, `save`, let it fire, `restore` → it fires again
  at the original count.
- `restore` a file saved by a different game (two fixture games) → `wrongGameSave`; a
  garbage file → `restoreFailed`; a missing file → `restoreFailed`; empty filename at
  either prompt → `Cancelled.`; all free turns (moves probe).
- `mistake / save / undo` still undoes the mistake (saving is meta and leaves the snapshot
  alone).

## Task 6: Death — `die(…)`, `GameStatus.dead`, and the RESTART/RESTORE/UNDO/QUIT prompt

**Goal**: a rule can kill the player without ending the program: banner, score, and the
classic interactive prompt, with all four exits working — built on Tasks 4 and 5.

**Files:**
- Modify: `Sources/Gnusto/Declarations/Helpers.swift` (`TurnInterrupt.died`,
  `public func die(_:)`)
- Modify: `Sources/Gnusto/Engine/WorldState.swift` (`GameStatus.dead`,
  `var isFinal: Bool`)
- Modify: `Sources/Gnusto/Engine/GameWorld.swift` (`handle(_:frame:)`, `finishTurn`
  epilogue, `commit`/`freeReply` finished-checks, `.deathChoice` prompt handling)
- Modify: `Sources/Gnusto/Actions/GameText.swift` (`deathBanner`, `deathPrompt`,
  `deathChoiceUnrecognized`)
- Test: `Tests/GnustoTests/DeathTests.swift`,
  `Tests/GnustoTests/Support/DeathGames.swift` (fixture: a `poison` item whose
  `before(.take)` calls `try die("Ill-advised. The world goes dark.")`, plus a timer-borne
  death to prove the tick path)

**Spec**:
1. ```swift
   /// Kills the player: prints the message, then the death banner; the engine
   /// then reports the score and offers RESTART / RESTORE / UNDO / QUIT.
   /// Distinct from `end(won:)`, which finishes the game outright.
   ///
   /// Seam: a later phase may add a game-supplied `onDeath` handler that can
   /// revive the player (resurrection) before the prompt is offered; only the
   /// prompt path exists today.
   public func die(_ message: String) throws -> Never {
       throw TurnInterrupt.died(message: message)
   }
   ```
   `TurnInterrupt` gains `case died(message: String)`.
2. `GameStatus` gains `case dead`, plus
   `var isFinal: Bool { self == .won || self == .lost || self == .quit }` — dead is *over*
   but not *finished*: the REPL keeps reading. Audit every `status != .playing` /
   `== .playing` site:
   - `commit` and `freeReply` `isFinished:` → `status.isFinal` (the two that must change,
     or the REPL would exit at death).
   - `finishTurn`'s each-turn guard, the tick guard, the multi-object loop break, and the
     score epilogue keep `== .playing` / `!= .playing` — a dead world's time has stopped,
     and the epilogue *should* fire for dead (classic score-on-death).
3. `handle(_:frame:)` gains:
   ```swift
   case .died(let message):
       frame.say(message)
       frame.say(frame.definition.text.deathBanner)
       frame.with { $0.state.status = .dead }
   ```
   `finishTurn`'s epilogue, after the score line: `if status == .dead {
   frame.say(text.deathPrompt) }`. Output order on a fatal turn: death message, banner,
   score line, prompt — whether death came from a stage 1–5 rule or from a Task-3 timer
   body (the tick's catch delegates to the same `handle`).
4. `GameWorld.perform`, after `run(parsed)` returns: if `state.status == .dead`, set
   `pendingPrompt = .deathChoice`. While that prompt is pending, *every* input line routes
   to it (normal commands are unreachable — classic): lowercase/trim the line and match
   - `"restart"` → clear prompt, `performRestart()` (status back to `.playing` via
     `initialState`);
   - `"restore"` → `pendingPrompt = .restoreFilename(returnToDeathPrompt: true)`,
     `freeReply(text.restorePrompt)`; a failed/cancelled restore prints its failure line
     *and* re-issues `deathPrompt`, restoring `pendingPrompt = .deathChoice`; a successful
     one clears everything and plays on;
   - `"undo"` → `performUndo()`; the snapshot predates the fatal turn, so this revives
     (classic UNDO-after-death); if no snapshot exists, print `cantUndo` + `deathPrompt`
     and keep the prompt;
   - `"quit"`/`"q"` → `state.status = .quit`; result output is empty (score already printed
     at death), `isFinished` true;
   - anything else → `freeReply(text.deathChoiceUnrecognized)` and the prompt stays.
   This reuses `performRestart`/`performUndo`/the restore performer verbatim — one
   mechanism for the death prompt and the normal verbs.
5. New `GameText`:
   - `deathBanner = "*** You have died ***"`
   - `deathPrompt = "Would you like to RESTART, RESTORE a saved game, UNDO your last turn, or QUIT?"`
   - `deathChoiceUnrecognized = "Please type RESTART, RESTORE, UNDO, or QUIT."`

**Tests**:
- `take poison` → its message, "*** You have died ***", the score line, the prompt — and
  the REPL is still alive (a following input is consumed by the prompt, not dropped).
- Prompt discipline: `look` while dead → `deathChoiceUnrecognized`, still dead; `undo` →
  revived at the pre-fatal turn (poison untaken, `moves` rewound); `restart` → full
  opening; `quit` → transcript ends, `isFinished`.
- Death → `restore` → filename of an earlier save → alive at the save point; death →
  `restore` → bad filename → `Restore failed.` + the death prompt again.
- Death from a daemon body (fixture timer calls `die`) produces the same banner/score/
  prompt ordering, and no other daemon runs after it that turn.
- Death during `take all` (poison among the loot): the object loop stops at the death, one
  labeled line, then banner/score/prompt.
- `end(won:)` unchanged: Cloak canary byte-identical.

## Task 7: Zork slice — the cellar region and the lit lantern

**Goal**: the cellar stops being a stub: the Cellar → East of Chasm → Gallery (painting) →
Studio → chimney-up-to-Kitchen loop, with the brass lantern a real, finite light source —
the soft-lock's replacement reality, minus the grue (Task 8).

**Files:**
- Create: `Sources/Zork1/Cellar.swift` (`ZorkCellar` bundle)
- Modify: `Sources/Zork1/House.swift` (lantern traits + rules + timers),
  `Sources/Zork1/Zork1.swift` (cross-bundle exits), `Sources/Zork1/Prose.swift` (new
  constants — all original placeholder prose)
- Modify: `Tests/GnustoTests/Zork1Tests.swift` (delete
  `darkCellarSoftLockIsThePhase7Seam`; new tests)
- Modify: `FIDELITY.md`

**Spec**:
1. `ZorkCellar` bundle:
   - `eastOfChasm = Location { name("East of Chasm"); description(Prose.eastOfChasm); dark }`
     with a scenery `chasm` item (examinable flavor).
   - `gallery = Location { name("Gallery"); description(Prose.gallery) }` — **lit**, as in
     the original; it also gives a lightless dash a resting point.
   - `studio = Location { name("Studio"); description(Prose.studio); dark }` with a scenery
     `chimney` item.
   - `painting = Item { name("painting"); adjectives("beautiful");
     firstSight(Prose.paintingFirstSight); description(Prose.painting) }`, starts in
     `gallery`. Just a takable item — treasure scoring is a later phase (FIDELITY note).
   - Internal map: `eastOfChasm.east(gallery)`, `gallery.west(eastOfChasm)`,
     `gallery.north(studio)`, `studio.south(gallery)`.
2. Cross-bundle geography in `Zork1.map` (the kitchen-window precedent):
   `house.cellar.south(cellar.eastOfChasm)`, `cellar.eastOfChasm.north(house.cellar)`, and
   the one-way chimney `cellar.studio.up(house.kitchen)` — no `kitchen.down` (classic: the
   chimney is climbable only from below; the original's two-item carry limit on the chimney
   is NOT modeled — FIDELITY note). `house.cellar` also gains a blocked-north stub
   (`Prose.cellarNorthBlocked`) where the Troll Room arrives in a later phase (FIDELITY
   note).
3. The lantern (in `ZorkHouse`): add `lightSource` and `synonyms("lamp")`; description
   becomes a closure — `description { lantern.isLit ? Prose.lanternOn : Prose.lanternOff }`
   (use the file-scope-`let` idiom established by `zork1TrophyCase` if self-reference
   demands it).
4. Lantern fuel via the Task-3 machinery, showcasing fuses (grue showcases daemons):
   - `ZorkHouse` gains `@Global var lanternDimIn = 20`, `@Global var lanternDiesIn = 25`,
     `@Global var lanternBurnedOut = false`.
   - `var timers: [TimedEvent]`:
     `fuse("lanternDim", after: 20) { say(Prose.lanternDim) }` and
     `fuse("lanternDies", after: 25) { lanternBurnedOut = true; lantern.isLit = false;
     say(Prose.lanternDies) }`.
   - Rules: `lantern.before(.turnOn) { try require(!lanternBurnedOut, else: Prose.lanternSpent) }`;
     `lantern.after(.turnOn) { if lanternDimIn > 0 { startFuse("lanternDim", after: lanternDimIn) };
     startFuse("lanternDies", after: lanternDiesIn) }`;
     `lantern.after(.turnOff) { lanternDimIn = fuseRemaining("lanternDim") ?? 0;
     lanternDiesIn = fuseRemaining("lanternDies") ?? 0; stopFuse("lanternDim");
     stopFuse("lanternDies") }` — pausing consumes no fuel (the classic economy), and
     exercises `fuseRemaining`/`startFuse(after:)`/`stopFuse` end to end. Numbers (25
     total, dim at 20) are deliberately small: long enough for the cellar loop (~12
     turns), short enough to burn out inside a transcript test.
   - After the fuse kills the light, darkness is *discovered*, not announced (the fuse body
     isn't the turn-off action); Task 8's grue warning covers the next dark turn.
5. **Delete `darkCellarSoftLockIsThePhase7Seam`** — the seam is closed by design: from the
   dark cellar, `south → east` reaches the lit Gallery, and `up` the chimney exits to the
   Kitchen. Its FIDELITY entry is rewritten (see below). Verify `fullSliceSmokeWalk` and
   `kitchenSweepWithAllAndPronouns` still pass.
6. `FIDELITY.md`: new "Phase 7 — cellar region" section; rewrite/remove the now-false
   entries ("brass lantern is just an item", "the cellar is a stub", "Known soft-lock" —
   the last becomes a short "closed in Phase 7" note describing the two escapes); add:
   chimney one-way with no carry limit, gallery lit per the original, troll passage
   blocked-stub, painting unscored, maze + skeleton key still deferred, lantern fuel 25
   turns (test-friendly) vs. the original's hundreds.

**Tests** (all in `Zork1Tests.swift`):
- `cellarLoopByLanternLight`: window route to the Living Room, `take lantern`,
  `turn on lantern` ("The brass lantern is now on."), `push rug`, `open trap door`, `down`
  → "Cellar" *described* (not pitch black) + the slam line, `south` → "East of Chasm",
  `east` → "Gallery" + the painting's firstSight, `take painting` → "Taken.", `north` →
  "Studio", `up` → "Kitchen" — the seam's two closures (light AND chimney) in one walk.
- `chimneyEscapeInTheDark`: descend lightless → pitch black + slam; `south` (still pitch
  black), `east` → "Gallery" described, `north`, `up` → "Kitchen". (Task 8 must keep this
  passing — the dash is fast enough to outrun the grue.)
- `lanternBurnsOut`: `turn on lantern` in the (lit) Living Room, 19 filler `look`s → dim
  warning at the right turn, 5 more → `Prose.lanternDies`; `turn on lantern` →
  `Prose.lanternSpent`. Also: `turn off` mid-burn, several turns, `turn on` → the dim
  warning arrives late by exactly the paused turns (fuel paused).

## Task 8: The grue — darkness becomes lethal

**Goal**: lingering in the dark kills: an original-prose warning on the first dark turn, one
silent turn of grace, death on the third — a Zork1-slice daemon engineered so Phase 8's
`GnustoDangerousDark` plugin can lift it out wholesale.

**Files:**
- Modify: `Sources/Zork1/Cellar.swift` (grue daemon + `@Global`), `Sources/Zork1/Prose.swift`
  (`grueWarning`, `grueDeath`), `Tests/GnustoTests/Zork1Tests.swift`, `FIDELITY.md`

**Spec**:
1. Placement decision: **a first-party content pattern in the Zork1 slice**, not an engine
   default or a `GameText` knob. Justification: the roadmap's Phase 8 ships
   `GnustoDangerousDark` as a plugin — the right long-term home; the engine default staying
   non-lethal keeps Cloak (whose dark bar is a puzzle, not a death trap) untouched by
   construction; and the pattern needs nothing the engine doesn't already expose
   (`player.location.isLit`, a daemon, `die`) — itself a good API proof. The daemon is
   written self-contained (one `@Global`, no house/cellar references) so extracting it into
   the plugin is a file move.
2. In `ZorkCellar`: `@Global var darkTurns = 0` and
   ```swift
   var timers: [TimedEvent] {
       daemon("grue", autostart: true) {
           guard !player.location.isLit else { darkTurns = 0; return }
           darkTurns += 1
           if darkTurns == 1 {
               say(Prose.grueWarning)
           } else if darkTurns >= 3 {
               try die(Prose.grueDeath)
           }
       }
   }
   ```
   Lingering-based, not movement-based: the daemon counts consecutive turns *ending* in
   darkness, wherever spent. Justification: no exit-graph awareness needed, the warning
   turn is a guarantee (the classic fairness contract), and it lets the lightless chimney
   dash succeed — enter cellar (1, warning), `south` (2, silence), `east` into the lit
   Gallery (reset). Deterministic death on the third turn rather than seeded `chance(…)`:
   transcripts stay reproducible without pinning seeds everywhere; the Phase-8 plugin is
   the place for configurable randomness. (One sharp edge, accepted and documented: UNDO
   from a grue death restores `darkTurns == 2`, so the revived player has zero safe dark
   moves — grues are unforgiving; RESTORE/RESTART are the real outs.)
3. Prose (original, never Infocom's — the iconic "likely to be eaten by a grue" sentence
   must NOT appear): `grueWarning` along the lines of "The darkness here is total.
   Something with slow, wet breathing has noticed you."; `grueDeath` e.g. "Claws find you
   long before your eyes adjust. You are devoured by a grue." ("grue" as a name is
   consistent with the ledger's names-vs-prose line; final wording at implementation time,
   logged in `FIDELITY.md`).
4. `FIDELITY.md`: grue entry — deterministic 3-turn schedule vs. the original's randomized
   chance; warning prose original, famous line deliberately not reproduced;
   lingering-not-movement model; lives in the slice pending the Phase-8 plugin.
5. Verify `chimneyEscapeInTheDark` and `fullSliceSmokeWalk` still pass.

**Tests**:
- `lingeringInTheDarkIsFatal`: descend lightless → pitch black + slam + `grueWarning` (same
  turn, in that order); `look` (silent grace turn — assert no second warning); `look` →
  `grueDeath`, "*** You have died ***", score line, death prompt; then `undo` → "Previous
  turn undone." + pitch black (alive, on the brink); then `quit` from the next death →
  transcript ends. (Exercises death + undo + prompt on the real slice.)
- `theLanternKeepsTheGrueAway`: the `cellarLoopByLanternLight` route extended with a few
  loitering `look`s in the dark-trait rooms while lit — the warning string never appears
  in the transcript.
- Slice save/restore round-trip: `save` before descending, die to the grue, `restore` at
  the death prompt → alive at the save point with the lantern schedule intact (the Phase-7
  integration test: light + timers + death + save in one transcript).

## Task 9: Documentation & fidelity sweep

**Goal**: authors learn light, time, death, and the meta-verbs from DocC; the ledger and
pipeline article match reality.

**Files:**
- Create: `Sources/Gnusto/Documentation.docc/DarknessTimeAndDeath.md` — light sources
  (`lightSource`/`startsLit`, `isLit`, where light reaches), `turn on`/`light` verbs and
  reveal-on-light, fuses & daemons (declaration, helpers, once-per-command tick, what saves
  and what re-binds), save/restore/undo/restart (file format, fingerprints, one-level
  undo), `die(_:)` vs `end(won:)` and the death prompt, and the grue as a worked
  "dangerous dark" pattern pointing at the Zork slice.
- Modify: `Sources/Gnusto/Documentation.docc/TheTurnPipeline.md` — stage-6 section gains
  the timer tick (after world-after rules, once per typed command, not on parse errors or
  after the game ends); "meta intents" section gains save/restore/undo/restart and the
  prompt round-trips; a short death subsection (dead ≠ finished).
- Modify: `Sources/Gnusto/Documentation.docc/Documentation.md` — topics: the new article
  under a "### Time, Light, and Death" group with `TimedEvent`,
  `fuse(_:after:autostart:perform:)`, `daemon(_:autostart:perform:)`,
  `startFuse`/`stopFuse`/`fuseRemaining`/`startDaemon`/`stopDaemon`/`isDaemonActive`,
  `die(_:)`; `lightSource`/`startsLit` added to "Describing Entities".
- `AddingCustomVerbs.md`: untouched (no grammar changes this phase).
- Modify: `FIDELITY.md` — final consistency pass over the Task 7/8 edits (the Phase-7
  section reads as one story; every "Phase 7 will…" promise in older entries is resolved
  or re-pointed).

**Tests**: `swift build` (DocC compiles); full suite green; `CloakTranscriptTests`
byte-identical one last time.

---

## Self-review notes

- Dependency spine: 1→2 (verbs need the trait/state), 3 independent of 1–2 (scheduled after
  so darkness work stays contiguous), 4→5→6 in order (the death prompt calls
  `performUndo`/`performRestart`/the restore performer — build the callees first), 7 needs
  1–3, 8 needs 3+6+7, 9 last. No task leaves the suite red: the slice keeps its Phase-6
  behavior untouched until Task 7, which is when the pinned soft-lock test is deliberately
  replaced.
- The four hard integration decisions, made and localized: (a) light is a placement-chain
  walk (`lightReaches`), never the visibility set — no circularity; (b) all interactive
  prompts (save/restore filenames, death choices) are one `PendingPrompt` enum on the
  actor, answered at the top of `perform` from the raw line — `REPL`/`IOHandler` untouched,
  transcript-testable; (c) `GameStatus.dead` is over-but-not-finished, with
  `GameStatus.isFinal` replacing exactly two `!= .playing` checks (`commit`, `freeReply`)
  and no others; (d) undo history is actor state (`undoSnapshot`), initial state is
  captured post-seed (`initialState`), and neither ever enters `WorldState`. Snapshot
  capture happens where the turn actually runs (top of `runTurn`, post-guard in
  `runMultiTurn`) so free replies never clobber it.
- Timer edge semantics are pinned by tests, not prose alone: started-this-turn ticks this
  turn (fuse and daemon alike), tick order is fuses-then-daemons name-sorted, bodies see
  the same interrupt handling as each-turn rules, and status is re-checked between bodies.
- Type/member names used across tasks: `lightSource`, `startsLit`,
  `ItemDefinition.isLightSource`, `WorldState.litItems`/`activeFuses`/`activeDaemons`,
  `Visibility.lightReaches`, `Item.isLit`, `Intent.turnOn/.turnOff/.save/.restore/.undo/.restart`,
  `TimedEvent`, `TimerBuilder`, `startFuse`/`stopFuse`/`fuseRemaining`/`startDaemon`/
  `stopDaemon`/`isDaemonActive`, `GameWorld.tickTimers`/`initialState`/`undoSnapshot`/
  `PendingPrompt`, `SaveFile`, `TurnInterrupt.died`, `die(_:)`, `GameStatus.dead`/`isFinal`,
  `GameText.nowOn/.nowOff/.alreadyOn/.alreadyOff/.cantTurnOnThat/.cantTurnOffThat/.nowDark/
  .savePrompt/.restorePrompt/.saved/.saveFailed/.restored/.restoreFailed/.wrongGameSave/
  .cancelled/.undone/.cantUndo/.deathBanner/.deathPrompt/.deathChoiceUnrecognized`,
  `ZorkCellar`. Grep before renaming anything.
- Deliberate scope exclusions (documented where relevant): no restart/quit confirmation, no
  game version field in save fingerprints, no resurrection `onDeath` hook (seam comment
  only), no carry-limit chimney, no maze/skeleton key/troll/thief, no randomized grue —
  each either a later-phase roadmap item or a one-line justification in its task.


