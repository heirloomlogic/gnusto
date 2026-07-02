# Phase 5 — Containers & the Visible World: Implementation Plan

Part of the approved Gnusto roadmap (Phases 5–10, "The Road to Zork 1"). Phase 5 adds
the container/visibility core, doors & conditional exits, the intent-override table,
several DSL quick wins, and the first Zork 1 slice (White House region, placeholder prose).

## Global Constraints

- **Verification**: `swift test` (Debug) must pass after every task. `swift test -c release`
  has a known toolchain quirk on this Mac (suite doesn't run) — Debug is authoritative locally.
- **No-regression canary**: `Sources/CloakOfDarkness/OperaHouse.swift` must need ZERO source
  changes, and `CloakTranscriptTests` must pass byte-identical. Existing test fixture games may
  be updated only where a task explicitly says so.
- **TDD**: write the failing test first (Swift Testing `@Test`/`#expect`; transcript tests via
  `play(game, [commands])` + `expectInOrder` from `Tests/GnustoTests/Support/Transcript.swift`).
- **Idioms** (match existing code exactly):
  - All mutable state lives in `WorldState` (one Codable value); mutation only inside
    `frame.with { }`; never hold the lock across a call that re-enters it (lock recursion traps).
  - Traits are immutable definition data; new trait factories follow the flat style of
    `wearable`/`surface`/`scenery` in `Sources/Gnusto/Declarations/Traits.swift`.
  - Stock player-facing text goes in the internal `Messages` enum (`Sources/Gnusto/Actions/Messages.swift`).
  - Rules/actions signal with `try refuse(...)` / `try reply(...)` (throw `TurnInterrupt`);
    `say(...)` appends output without interrupting.
  - Bootstrap problems: fatal diagnostics accumulate in `BootstrapError` (report ALL at once);
    non-fatal notes append to `GameDefinition.warnings`.
  - Engine branches only on built-in trait enums ("closed core, open edges").
- **Breaking changes are fine** (zero users) but each task leaves the whole suite green.
- **Commits**: one or more commits per task on the current branch; message ends with
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- Docs: DocC guide updates are deferred to a later phase EXCEPT where a task says otherwise.

## Task 1: `Placement.held` → `Placement.heldBy(EntityID)`

**Goal**: Generalize "held by the player" to "held by any entity" so NPC inventory (Phase 8)
is symmetric with player inventory. Pure mechanical refactor; observable behavior unchanged.

**Spec**:
1. In `Sources/Gnusto/Engine/WorldState.swift`, change `Placement`'s `case held` to
   `case heldBy(EntityID)`. Keep Codable conformance (synthesized is fine — save format may
   change; zero users).
2. Add a reserved player ID: `extension EntityID { public static let player = EntityID("player") }`
   (put it next to `EntityID`'s declaration in `Sources/Gnusto/Engine/RefToken.swift`).
3. Update every pattern match / construction site: `Engine/GameWorld.swift` (`currentScope`),
   `Actions/DefaultActions.swift` (take/drop/inventory/etc.), `Engine/RoomDescriber.swift`,
   `Engine/Bootstrap.swift` (map evaluation: `startsHeld`, `startsWorn`). `Item.isHeld` and
   `Player.isCarrying` now mean `placement == .heldBy(.player)`.
4. Bootstrap diagnostic: if any declared entity's inferred `EntityID` equals `"player"` (bare,
   after namespacing rules), report a fatal diagnostic — the ID is reserved. Add a test with a
   game that declares `let player2...`? No — test a game with a stored property named `player`
   of type `Item` and assert the diagnostic fires. (Check first how the bootstrap treats a
   property literally named `player` today; the `Player` proxy is not a stored `Item`/`Location`
   so there may be no conflict — if reflection can't hit this case, assert-and-document instead
   with a guard in `Bootstrap.register`.)
5. No public authoring API changes: `startsHeld`, `startsWorn`, `isHeld`, `isWorn` behave
   identically.

**Tests**: full suite green, unchanged (that IS the acceptance). Plus the reserved-ID
diagnostic test if reachable, and one new unit test asserting `Item.isHeld` reflects
`.heldBy(.player)`.

**Size**: S. Model: mechanical multi-file — mid tier.

## Task 2: Extract `Visibility.swift`

**Goal**: One shared visible/reachable computation replacing the hand-rolled placement walks,
so containers (Task 3) change exactly one algorithm. Behavior-preserving refactor.

**Spec**:
1. New `Sources/Gnusto/Engine/Visibility.swift`: an enum namespace (like `DefaultActions`) with:
   - `static func visibleItems(at location: EntityID, definition: GameDefinition, state: WorldState) -> Set<EntityID>`
     — items whose placement chain roots in the (lit) location: directly in the room, on surfaces
     (recursively), plus items `heldBy(.player)` always. Mirrors today's `GameWorld.currentScope()`
     semantics exactly (today: room contents one surface/container level deep — replicate the
     exact current behavior first; deepening happens in Task 3).
   - `static func reachableItems(...) -> Set<EntityID>` — today identical to visible; the split
     exists so Task 3 can diverge them (closed transparent container: visible, not reachable).
   - `static func isDark(at location: EntityID, definition: GameDefinition, state: WorldState) -> Bool`
     — move the logic from `WorldState.isDark()` here (resolving that seam comment); keep a
     forwarding method on `WorldState` only if call sites make it awkward otherwise (prefer
     migrating call sites).
2. Rewire the three consumers to call `Visibility`: `GameWorld.currentScope()`,
   `RoomDescriber` (its surface-listing loop keeps producing byte-identical output — the
   describer still controls FORMAT; visibility only answers "which items"), and any
   `DefaultActions` placement walks.
3. Delete the now-duplicated walks.

**Tests**: full suite green, byte-identical transcripts (`CloakTranscriptTests` especially).
Add focused unit tests for `Visibility.visibleItems` (item in room, on surface, held, in dark
room → only held) so Task 3 has a harness to extend.

**Size**: S–M. Model: refactor with judgment — mid tier.

## Task 3: Container traits, state & visibility recursion

**Goal**: Real containers: open/closed/locked/transparent, contents participating in scope
and description, authored declaratively.

**Spec**:
1. New `ItemTrait` factories in `Declarations/Traits.swift` (flat style, like `wearable`):
   - `container` — items can be placed `.inside`; contents visible/reachable per open state.
   - `openable` — gains open/close verbs (Task 4); **starts closed** unless `startsOpen`.
   - `startsOpen`
   - `transparent` — contents visible while closed (still not reachable).
   - `lockable(with key: Item) -> ItemTrait` — starts **locked** unless `startsUnlocked`;
     stores the key's `RefToken` (traits are built before the registry exists); Bootstrap
     resolves token→`EntityID` onto `ItemDefinition` and reports a fatal diagnostic if the key
     is not a declared item.
   - `startsUnlocked`
   - `capacity(_ n: Int)` — max direct contents count (enforced in Task 4's putIn).
   `ItemDefinition` (in `Engine/GameDefinition.swift`) gains the corresponding stored fields
   via its existing `init(traits:)` switch (compiler-enforced exhaustiveness).
2. `WorldState` gains `openItems: Set<EntityID>` and `lockedItems: Set<EntityID>`, seeded by
   Bootstrap from traits (`openable` + `startsOpen` → open; `lockable` without `startsUnlocked`
   → locked). Semantics: a `container` WITHOUT `openable` is always open (`isOpen == true`,
   setting it is a no-op or programmer-error trap — pick one and test it).
3. `Item` proxy API (in `Declarations/Item.swift`, matching `isWorn`'s get/set style):
   `isOpen: Bool { get set }`, `isLocked: Bool { get set }`, `isContainer: Bool { get }`,
   plus placement movers `move(inside: Item)`, `move(onto: Item)`, `move(heldBy: Item)`
   (validate the target has the right trait where applicable; `move(to: Location)` exists).
4. **Visibility recursion** (extends Task 2's module): recurse through surfaces (always) and
   containers (when open OR transparent), any depth. Reachable diverges: recurse containers
   only when OPEN (transparent+closed = visible, not reachable). Parser scope
   (`GameWorld.currentScope`) uses **visible** (you can refer to what you can see); actions
   check **reachable** and refuse (Task 4 wires those refusals; this task only provides the sets).
5. Bootstrap validation: `.starts(inside:)` target must have `container` (mirror the existing
   surface check); contents of a closed opaque container do NOT appear in room descriptions
   (RoomDescriber consumes visibility, so this falls out — test it).

**Tests** (fixture: new `Support/ContainerGames.swift`, e.g. a `PantryGame` with an openable
opaque crate, a transparent jar, an always-open basket, a locked chest + key):
visible/reachable matrices per state; bootstrap diagnostics (inside non-container, key not
declared); room description hides closed-crate contents, shows jar contents; save/restore
round-trips openItems/lockedItems (encode/decode `WorldState`).

**Size**: L — the riskiest task of the phase. Model: most capable.

## Task 4: Container verbs, default actions & push-to-reveal

**Goal**: The player can actually use containers; the rug/trap-door pattern works.

**Spec**:
1. New built-in `Intent`s (`Actions/Command.swift`): `.open`, `.close`, `.lock`, `.unlock`,
   `.putIn`, `.lookIn`, `.push`. New rows in `SyntaxRule.standardTable`
   (`Actions/SyntaxRule.swift`): `open X`, `close X`, `shut X`, `lock X with Y`,
   `unlock X with Y`, `put X in Y` / `put X into Y` (Slots `.directPrepIndirect("in")` and
   `("into")`), `look in X` (multi-word verb `["look","in"]`, `.direct`), `search X`,
   `push X`, `move X`.
2. `DefaultActions` implementations (follow `take`'s structure: guards → `try refuse(Messages…)`
   → mutate in one `frame.with` → say):
   - **open**: requires `openable` + reachable; refuse if locked ("The X is locked."), if
     already open, or not openable ("You can't open that."). On success: "Opened." — but if the
     container has visible contents, "Opening the X reveals a Y and a Z."
   - **close**: inverse guards; "Closed."
   - **lock/unlock X with Y**: requires lockable, correct declared key held; distinct refusals
     for wrong key / key not held / not lockable.
   - **putIn**: direct object held; target reachable + container + open (refuse "The X is
     closed."); capacity enforced ("There's no room."); reject cycles (item into itself/its own
     contents chain). Mirrors `putOn`.
   - **lookIn/search**: closed opaque → "The X is closed."; empty → "The X is empty.";
     else list contents ("In the X are a Y and a Z." — reuse/extend `RoomDescriber` list
     formatting helpers rather than duplicating).
   - **push**: default "You can't move that." / "Pushing the X reveals nothing." — pick one
     stock message; the interesting behavior is authored via rules + reveal (below).
   - **take** gains: taking an item from inside/on a reachable open container works
     (reachability from Task 3 already permits it — verify + test); taking from a closed
     container refuses via the not-in-scope path naturally.
3. **Hidden-until-revealed**: new `hidden` ItemTrait; `WorldState.revealedItems: Set<EntityID>`;
   hidden items are excluded from visibility and room description until revealed;
   `Item.reveal()` proxy method (and `isRevealed` getter). Authored usage (this is the
   acceptance shape — a fixture game must read exactly like this):
   ```swift
   let rug = Item { name("oriental rug"); scenery }
   let trapDoor = Item { name("trap door"); openable; scenery; hidden }
   // rules:
   rug.after(.push) {
       guard !trapDoor.isRevealed else { try reply("The rug has already been moved.") }
       trapDoor.reveal()
       say("Moving the rug reveals a trap door beneath it.")
   }
   ```
   (Note `after(.push)` runs after the default push message — if that reads badly, the fixture
   uses `before(.push)` + `try reply(...)`; implementer picks whichever transcript reads best
   and documents the choice in the fixture.)
4. New stock messages go in `Messages`.

**Tests**: transcript tests on the Task 3 fixture(s) extended with: open/close/lock/unlock
flows including every refusal; put-in + capacity + cycle; look-in all three states; push+reveal
(hidden item unmentioned before, present after); take from open container.

**Size**: M–L. Model: standard/most capable.

## Task 5: Intent-override table + `proceed()`

**Goal**: Games and plugins can replace or extend the *default action* for any intent —
the seam that lets Phase 8's combat plugin ship a real `attack`, and lets authors give custom
verbs stage-4 behavior instead of "I didn't understand".

**Spec**:
1. New `IntentAction` value (intent + `@Sendable () throws -> Void` body) with factory
   `action(_ intent: Intent, perform:)`; `typealias ActionBuilder = GnustoBuilder<IntentAction>`.
2. `Game`, `GameContent`, and `GamePlugin` gain a defaulted `@ActionBuilder var actions: [IntentAction] { [] }`.
   Bootstrap merges: built-ins < bundle/plugin contributions < game, **last-wins by intent**,
   with a non-fatal `warnings` note on override (mirror the verb-override policy and its test).
   Merged table lands on `GameDefinition.actionOverrides: [Intent: ...]`.
3. `DefaultActions.run` consults `actionOverrides[intent]` first; built-in switch is the
   fallback. An override runs at stage 4 exactly like a built-in (before rules already ran;
   after rules still run; `refuse`/`reply` inside behave identically).
4. `proceed()` in `Declarations/Helpers.swift`: callable ONLY from a `before` rule; runs the
   stage-4 action (override or built-in) immediately, then returns so the rule can embellish;
   sets a `defaultRan` flag on `Scratch` so the pipeline skips stage 4. Calling it twice, or
   from an `after`/each-turn rule, traps with a clear message (fatalError, consistent with
   `Ctx.current`'s misuse style). Acceptance shape:
   ```swift
   mailbox.before(.open) {
       try proceed()                    // built-in open runs here
       say("A city map is tucked inside the lid.")
   }
   ```
5. GamePlugin docs-comment updated: plugins can now ship whole verb behaviors
   (`verbs` + `actions`) without host rules.

**Tests**: custom intent + `action` gives it default behavior (no more "I didn't understand");
game override of a built-in (e.g. `take` themed) wins with a warning recorded; plugin-provided
action spliced by host works; `proceed()` embellish flow; `proceed()` misuse traps
(use `#expect(exitsWith:)`-style if available, else assert via a precondition-testing pattern
already used in the suite — if none exists, document the trap and test only the happy paths).

**Size**: M. Model: standard.

## Task 6: Doors & conditional exits

**Goal**: Declarative doors shared between two rooms, and state-gated exits — no
`world.before(.go)` workarounds.

**Spec**:
1. `ExitTarget` (in `Engine/GameDefinition.swift` or wherever it lives — check `WorldMap`)
   gains `case door(to: EntityID, door: EntityID)` and
   `case conditional(to: EntityID, condition: @Sendable () -> Bool, blocked: String)`
   (adjust: the MAP-BLOCK types may carry `RefToken`s that Bootstrap resolves to `EntityID`s,
   matching how exits already resolve).
2. Map sugar on `Location` — the authoring spellings that MUST work (acceptance shape):
   ```swift
   livingRoom.down(cellar, via: trapDoor)
   cellar.up(livingRoom, via: trapDoor)
   clearing.west(forest, when: { gratingUnlocked }, otherwise: "The way is barred.")
   ```
   Do NOT triple every direction overload by hand if there's a cleaner path: prefer giving the
   existing direction helpers `via:`/`when:otherwise:` parameters or a general
   `exit(_:to:via:)` + thin direction sugar — implementer judgment, keep `Location.swift` from
   bloating (it is already overload-heavy; consider generating the 12 directions from one
   private helper).
3. `via:` doors: Bootstrap validates the door item has `openable`; the SAME item can appear on
   exits of two rooms (that's the point — shared state through one EntityID). **Door scope**:
   `Visibility` includes any item referenced as a door by the current room's exits, regardless
   of placement (doors typically have no placement at all) — it can be examined/opened/closed
   from both sides. A `hidden` door (Task 4) stays out of scope until revealed, and `go`
   through it behaves as if the exit weren't there ("You can't go that way.") until revealed.
4. `DefaultActions.go`: door exit → refuse "The trap door is closed." when closed (name from
   the door item), "The grating is locked." when locked... wait — locked-but-closed reads as
   closed; only distinguish when the player tries to OPEN it. Keep go's refusal on the open
   state only. Conditional exit → evaluate `condition()` inside the live frame; false →
   refuse with `blocked` text; true → normal movement.
5. Bootstrap diagnostics: `via:` target not `openable`; door token not a declared item.

**Tests** (fixture `Support/DoorGames.swift`): closed door blocks, open door passes, state
shared across both sides (open from below, ascend); locked door: `open` refuses "locked",
unlock-with-key then open then pass; conditional exit false→blocked text, flip `@Global`,
true→passes; hidden door invisible + impassable until revealed; bootstrap diagnostics.

**Size**: M. Model: most capable (touches Bootstrap resolution + Visibility + go).

## Task 7: DSL quick wins — `require`, `TraitKey`, closure descriptions, `GameMain`

**Goal**: Four small ergonomic wins the Zork slice (Task 8) should be written with.

**Spec**:
1. **`require`** (in `Helpers.swift`):
   `public func require(_ condition: Bool, else message: String) throws` — refuses with
   `message` when false. (Name it `require`; collision with Swift's `#require` macro in tests
   is a non-issue — different namespaces — but verify test-target compilation.)
2. **`TraitKey<Value>`** (new `Declarations/TraitKey.swift`):
   `public struct TraitKey<Value: GlobalValue>: Sendable { let name: String; let defaultValue: Value? }`
   with `init(_ name: String)` and `init(_ name: String, default: Value)`.
   Trait factory overload `trait(_ key: TraitKey<V>, _ value: V)`. Typed subscripts on
   `Item`/`Location`: `subscript<V>(key: TraitKey<V>) -> V?`; where the key carries a default,
   a non-optional overload returns `V`. Authoring shape:
   ```swift
   extension TraitKey<Int> { static let price = Self("price") }
   let lantern = Item { name("brass lantern"); trait(.price, 5) }
   let cost = lantern[.price]   // Int?
   ```
   Migrate ALL fixture/test uses of the string API (`trait("price", 5)`, `.trait("price", as:)`)
   to keys, then DELETE the string API entirely (zero users — no deprecation shims, ever;
   user directive 2026-07-02). Internal storage stays `customTraits: [String: StateValue]`
   (TraitKey resolves to its name). Suite must compile clean with only the TraitKey API.
3. **Closure descriptions**: `ItemTrait`/`LocationTrait` gain
   `.dynamicDescription(@Sendable () -> String)` via `description { ... }` factory overloads.
   Precedence: runtime string override (`item.description = ...`) > closure > static string.
   The closure runs under the live frame (evaluate at read time in the proxy/`TurnFrame`
   described-text path — proxies captured in the closure already resolve via `Ctx.current`).
   Static `description("...")` and closure on the same entity = bootstrap diagnostic (ambiguous).
4. **`GameMain`** (new `IO/GameMain.swift`):
   `public protocol GameMain { init() }` + extension constrained to `Self: Game` providing
   `static func main() async` that boots `GameWorld(game: Self())` and runs the `REPL` with
   `ConsoleIOHandler` — whatever `Sources/CloakOfDarkness/main.swift` does today, factored.
   Convert CloakOfDarkness's main.swift to `@main` on... NO — OperaHouse.swift must not change;
   `main.swift` is a different file and MAY be replaced by a minimal `@main struct` wrapper IF
   that keeps OperaHouse.swift untouched and transcripts identical; otherwise leave Cloak alone
   and only add the protocol + tests. Acceptance shape: `@main struct Zork1: Game, GameMain {}`
   compiles (Task 8 consumes it).

**Tests**: `require` both branches; TraitKey typed read (present/absent/defaulted), one
deprecated-API test updated; closure description reflects live state across turns (transcript:
examine before/after a `@Global` flips), override-beats-closure precedence, static+closure
diagnostic; GameMain: compile-level test (a fixture game conforming; invoking main() in a test
is not required — REPL needs stdin; assert the protocol wires by calling the underlying
factored run function with `ScriptedIOHandler` if the factoring makes that natural).

**Size**: M (four small features). Model: standard.

## Task 8: Zork 1 slice — White House (ZorkAboveGround + ZorkHouse)

**Goal**: The first real Zork 1 content: `Sources/Zork1/` executable target with two region
bundles, exercising every Phase 5 capability at authentic scale. **PLACEHOLDER PROSE ONLY**:
write original, mechanics-accurate descriptions — do NOT reproduce Infocom's copyrighted text.
Iconic proper names (room names like "West of House", item names like "brass lantern",
"jewel-encrusted egg") are fine. Structure every description as a named constant so a later
verbatim-text pass is mechanical.

**Spec**:
1. Package.swift: new executable target `Zork1` depending on `Gnusto` (mirror CloakOfDarkness).
2. Layout:
   - `Sources/Zork1/Zork1.swift` — `@main struct Zork1: Game, GameMain` (Task 7); title
     "Zork I: The Great Underground Empire" (title/tagline are facts, not prose); host owns
     cross-region `@Global`s and wires cross-bundle exits.
   - `Sources/Zork1/AboveGround.swift` — `struct ZorkAboveGround: GameContent` (~16 rooms):
     West of House, North of House, South of House, Behind House, Forest (west/east/northeast +
     Forest Path), Up a Tree, Clearing (grating), Clearing (east), Canyon View, Rocky Ledge,
     Canyon Bottom, End of Rainbow. Items: mailbox (`container; openable; scenery`) + leaflet
     (inside), jewel-encrusted egg (in a nest, Up a Tree), grating (`openable; lockable(with:)`
     — key doesn't exist yet; declare a `skeletonKey` placed `.nowhere`... `nowhere` placement
     = simply never placed in `map`; verify an unplaced item is legal at bootstrap, else park it
     in a stub room), pile of leaves (pushing/moving reveals the grating — `hidden` grating +
     move-leaves rule), tree (scenery, `climb`ing is just the Up a Tree exit for now), front
     door (scenery; opening refuses — nailed shut), white house (scenery, examinable from the
     four house-side rooms).
   - `Sources/Zork1/House.swift` — `struct ZorkHouse: GameContent` (3 rooms + cellar stub):
     Kitchen, Living Room, Attic, plus a stub Cellar room (`dark`) so the trap door leads
     somewhere real (full cellar is Phase 7's slice). Items: kitchen window (`openable` door
     between Behind House and Kitchen — starts closed, "slightly ajar" is prose), sack
     (`container` + garlic, lunch inside), bottle (`container; transparent` + water item
     inside), brass lantern (Living Room; just an item until Phase 7 makes it a light source),
     elvish sword, oriental rug + hidden trap door (`openable; hidden` — push rug reveals; the
     Task 4 acceptance pattern), trophy case (`container; openable; transparent; scenery`),
     rope + nasty knife (Attic).
   - `Sources/Zork1/Prose.swift` (or per-bundle `Prose` enums) — every description string a
     named constant: `Prose.westOfHouse`, `Prose.mailbox`, etc.
   - `FIDELITY.md` at repo root: ledger started — placeholder prose (verbatim pass pending),
     tree climb simplified to an exit, grating key unplaced until Maze phase, cellar stubbed,
     lantern not yet a light source, no thief/troll/score yet.
3. Wiring: host `map` connects Behind House ↔ Kitchen `via:` window; Living Room ↔ Cellar stub
   `via:` trapDoor; cross-bundle forest↔clearing paths as needed. Use faithful Zork 1 map
   topology for these regions (implementer: derive from well-known Zork 1 maps; where uncertain,
   pick something sane and note it in FIDELITY.md).
4. Trap door slam: entering the Cellar closes the trap door behind you
   (`cellar.onEnter { ... trapDoor.isOpen = false ... }`) — the classic moment, and it proves
   shared-door state; the stub Cellar's `up` exit goes back through the (now closed) trap door,
   and it can be re-opened from below for now (barring arrives with the thief, Phase 8;
   FIDELITY.md notes it).
5. Use the Phase 5 DSL throughout: `require`, TraitKeys where natural, at least one closure
   description (e.g. trophy case empty vs holding the egg), `proceed()` at least once
   (e.g. mailbox open embellishment or window open), conditional exit at least once if a
   natural spot exists (else skip — don't force it).

**Tests** (`Tests/GnustoTests/Zork1Tests.swift`, transcript style):
- open mailbox → reveals leaflet; read leaflet; close mailbox.
- Behind House: open window, enter west → Kitchen (door refuses before opening).
- Living Room: push rug → trap door revealed; open trap door; down → Cellar (dark: scope
  collapses — "It is pitch black" per current dark-room behavior); trap door slammed shut
  (transcript shows the slam line); up → refused while closed; open + up works.
- Up a Tree: take egg; down; put egg in trophy case (open case first).
- Clearing: move leaves → grating revealed; open grating → refused (locked).
- Full-slice smoke walk touching every room once (asserts room names in order).

**Size**: L (content-heavy, mechanically straightforward). Model: standard.
