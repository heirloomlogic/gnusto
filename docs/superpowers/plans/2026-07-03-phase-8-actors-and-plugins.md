# Phase 8 — Actors, Vehicles & First-Party Plugins: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline) or
> superpowers:subagent-driven-development to implement this plan task-by-task.

Part of the approved Gnusto roadmap (Phases 5–10, "The Road to Zork 1"). Phase 8 teaches the
engine that entities other than the player can hold things, act each turn, and die — and
pressure-tests the plugin architecture of Phases 1–4b across real SPM module boundaries with
the first four first-party plugin targets. The Zork 1 slice grows the Troll Room, a reduced
thief who finally makes the trap-door bar mechanically true, and a trophy case that pays out
points.

**Goal:** a player can light the lantern, descend, walk north into the Troll Room, kill the
troll with the elvish sword under a pinned seed, feel the thief slam and bar the trap door
behind them, lose the painting to his fingers and get it back over his body, and deposit it
in the trophy case for points — while a fixture game proves a red boat can be boarded,
ridden, and loaded with cargo. Every mechanic that generalizes lives in a reusable plugin
target any Gnusto game can import.

## Decisions (locked with the user, 2026-07-03)

1. **Plugin packaging**: four separate SPM library targets/products — `GnustoMeleeCombat`
   (melee-scoped; ranged/magic separate if ever), `GnustoActors`, `GnustoScoring`,
   `GnustoDangerousDark`. Each depends only on `Gnusto`.
2. **Vehicles**: engine core (placement/visibility/movement are engine-owned internals a
   plugin can't reach — same reason containers were core in Phase 5). Test fixture only;
   no Zork boat this phase.
3. **Combat model**: Zork-style-lite with seeded RNG — weapons, actor health/strength,
   outcome table (miss/wound/knockout/kill), villain counter-attacks; deterministic under
   pinned seed.
4. **Thief scope**: reduced — bars the trap door, roams the cellar region, steals;
   treasure room/maze/egg-opening deferred to the maze phase.
5. **Actor declaration**: thin `Actor` type — own declaration type for authoring clarity +
   actor-specific API, compiling to the same underlying entity storage (single-path
   WorldState/visibility/save).

## Global Constraints

- **Verification**: `swift test` (Debug) green after every task; Debug authoritative
  locally (known release-mode toolchain quirk).
- **No-regression canaries**: `Sources/CloakOfDarkness/OperaHouse.swift` needs ZERO source
  changes; `CloakTranscriptTests` byte-identical at every task boundary. Phase-7 Zork
  transcripts stay green throughout; the grue trio must pass **unmodified** after the
  DangerousDark lift (the "lift, don't rewrite" acceptance bar).
- **TDD**: failing test first, every task.
- **No legacy shims**: superseded code deleted outright (the grue section of
  `Sources/Zork1/Cellar.swift`, `Prose.cellarNorthBlocked`, stale FIDELITY entries).
- **Public-API discipline**: plugin targets import `Gnusto` plainly — anything missing is
  an engine change in Part A, never a `@testable` cheat.
- **Prose policy**: every player-visible string in plugins and slice is original
  placeholder prose. Names ("grue", "troll", "thief") are fine; iconic Infocom sentences
  are not. Original Zork *numbers* (troll strength 2, painting 4/6, egg 5/5) are data, not
  prose. Every compromise gets a `FIDELITY.md` entry.
- **Determinism**: any test that can see a `random`/`oneOf`/`chance` outcome pins its seed
  via `play(_:_:seed:)`. Plugin daemons draw RNG **only after** their guards pass, so
  quiet turns burn no stream.
- **Idioms** (match existing code exactly): all mutable state in `WorldState`; mutation
  only inside `frame.with { }`; no lock re-entry; engine branches only on built-in traits;
  fatal bootstrap diagnostics accumulate in `BootstrapError`, non-fatal notes on
  `GameDefinition.warnings`; stock lines on `GameText`.
- **Commits**: one or more per task; message ends with
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

---

## Part A — Engine core

**Architecture:** one storage path, two authoring types. `Actor` is a declaration veneer —
Bootstrap registers it into the same `registry.items`/`definition.items`/`placements` world
as items, flagged `isActor` on `ItemDefinition`, so save format, visibility, pronouns,
rules, and the parser need no second entity kind. Vehicles ride on one new `WorldState`
field (`playerVehicle: EntityID?`); the player still never appears in `placements` and
`playerLocation` stays the room, so every existing darkness/visibility read is untouched by
construction.

### Task A1: The `Actor` declaration type (M)

New `Sources/Gnusto/Declarations/Actor.swift`: `public struct Actor` with `@ItemBuilder`
init (reuses the item trait vocabulary — descriptive traits meaningful; mechanical item
traits like `container` produce a non-fatal bootstrap warning, not stripped). Internal
`Item(token:traits:)` bridge so Bootstrap registers actors into `registry.items` (no new
RefToken minted). Bootstrap reflection gains the `Actor` case; `ItemDefinition.isActor`
flag; nameless-actor diagnostic worded "actor". `isTakable` becomes
`!isScenery && !isActor` (so `take all` skips actors structurally); `DefaultActions.take`
refuses actors with new `GameText.cantTakeActor` ("The troll would take exception to
that."). Rule factories `before`/`after` (same `Rule(scope: .item(token))` — one rule
table) + `starts(in:)` only. Live proxies: `name`, `description` (get/set), `isRevealed`,
`reveal()`. **No core alive/dead flag** — the engine has no behavior that branches on it;
plugins compose `vanish()`/`dropAll()`/custom traits. Pronoun "it" binds to actors;
him/her deferred (documented). Fixture `Tests/GnustoTests/Support/ActorGames.swift`
(hall/corridor, troll, sword, rock) + `ActorTests.swift`.

### Task A2: Actors in room descriptions (S)

`RoomDescriber` excludes `isActor` items from the item paragraphs and lists perceivable
actors AFTER them (people close the scene), sorted by ID. An actor's `firstSight` is its
**persistent presence line** (always shown, not touch-gated — ZIL's LDESC role; documented
divergence on `firstSight(_:)`); otherwise new `GameText.actorHere` ("A surly troll is
here."). NPC-held items are not listed in room descriptions. Hidden/dark behavior
unchanged.

### Task A3: Actor state API + NPC-held perception (M)

`Actor` gains `location: Location?`, `isIn(_:)`, `move(to:)`, `vanish()` (inventory goes
offstage with it — call `dropAll()` first for the classic clatter), `holds(_:)`,
`inventory: [Item]` (ID-sorted), `dropAll()`. `Item.move(heldBy: Actor)` overload +
declarative `Item.starts(heldBy: Actor)` (new `PlacementTarget.heldBy(RefToken)`; fatal
bootstrap diagnostic when the target isn't an Actor). `Visibility.collect`: NPC-held items
become **visible but not reachable** (the closed-glass-container split — `cantReach`
refusal, parser scope works; stealing is a plugin's job). `Visibility.lightReaches`
continues through non-player holders — a lit lamp in an NPC's hand lights the room
(corrects a Phase-7 simplification; nothing regresses — no content used non-player
holders). Save/restore round-trip pinned.

### Task A4: Plugin seams — `GamePlugin.timers`, `describeSurroundings()`, `command` (S)

**Decision: actors act via plugin daemons on the Phase-7 tick — no new turn phase** (ZIL
NPCs were clock interrupts; `tickTimers` already provides ordering, save re-binding, and
death handling). `GamePlugin` gains defaulted `@TimerBuilder var timers: [TimedEvent]`
(the `[TimedEvent]` splice overload shipped in Phase 7 — this closes the genuine gap that
`GamePlugin` never declared the block; names stay global, plugins prefix by convention).
`GameContent`/`GamePlugin` gain the same `command` accessor `Game` has (rule bodies in
bundles need `command.direction`/`command.indirectObject`). New helper
`describeSurroundings()` — LOOK-equivalent for rule/daemon bodies ("The current carries
the boat downstream."). The attack path needs NO engine work — pinned by a fixture-plugin
test: plugin-minted `Intent("attack")` + verb row + `IntentAction` default + host
`actor.before` override, proving precedence through the existing tables.

### Task A5: Vehicles I — `enterable`, `playerVehicle`, BOARD/DISEMBARK (M)

Single `enterable` trait (no separate vehicle trait — a chair refuses `.go` via rule; a
cargo vehicle also declares `container`). `WorldState.playerVehicle: EntityID?`; the ONLY
reader is the self-healing resolver `Visibility.boardedVehicle(definition:state:)` (nil
unless the vehicle is placed in the player's room — rules that teleport the player strand
the vehicle gracefully). Intents `.board`/`.disembark` (ordinary world actions, stages
1–5, so `boat.before(.board)` works day one); rows: enter/board/get in/get into
directObject; exit [directObject]/disembark/get out [of directObject]. Bare `out`/`in`
remain directions (parser's bare-direction check precedes verb rows — pinned).
`DefaultActions.board`/`disembark` with full refusal ladder; new GameText:
`cantEnterThat`, `cantEnterCarried`, `alreadyInVehicle`, `mustExitFirst`, `boarded`,
`disembarked`, `notInVehicle`, `notInThat`. `Player.vehicle: Item?` read-only (the gate
terrain rules key on). Fixture `VehicleGames.swift` (dock/boathouse/dark cave, red boat,
crate, pebble) + `VehicleTests.swift`; UNDO/save round-trips pinned.

### Task A6: Vehicles II — riding exits, "in the red boat", cargo (M)

The shared arrival path (`DefaultActions.enter(_:frame:)`) also moves the boarded vehicle
in the same `with` block — cargo rides free (placement `.inside(vehicle)` unchanged); all
exit gating identical to walking; terrain rules are game `before(.go)` over
`player.vehicle`. Room title becomes `GameText.locationInVehicle` ("Boathouse, in the red
boat"); `pitchBlack` still wins in darkness; StatusLine keeps the plain name. The boarded
vehicle is skipped from its own room's listing. `drop` while boarded in a
container-vehicle lands `.inside` (capacity NOT enforced on this implicit path — `putIn`
remains the gate; documented). `take <boarded vehicle>` → new `notWhileInside`.
`Item.move(to:)` carries the boarded player (river-current pattern; documented loudly —
`move(inside:/onto:)`/`vanish()` strand instead, pinned). Darkness interplay emergent and
pinned (ride into dark → pitchBlack; lit lantern in the boat lights the room).

### Task A7: DocC sweep (S)

New `Documentation.docc/ActorsAndVehicles.md` (declaring actors, firstSight-as-presence,
the no-alive-flag philosophy + vanish/corpse pattern, inventories,
visible-not-reachable, light in NPC hands, actor turns as daemons, the whole vehicle
story). Topic group in `Documentation.md`; `TheTurnPipeline.md` "characters take their
turns on the clock" note; `Plugins.md` gains `timers`.

## Part B — First-party plugins & Zork slice

**Architecture:** two plugin shapes, both proven by Phase 1–4b fixtures. State-bearing
systems (`DangerousDark`, `Scoring`, `MeleeCombat`) are `GameContent` bundles with **no
rooms/items** — namespaced `@Global` state, auto-collected verbs/actions/timers,
host-facing `@RuleBuilder` factories (the ShrineContent precedent promoted to real
targets). The stateless one (`ActorBehaviors`) is a logic-only `GamePlugin` returning
`TimedEvent`s/`Rules` the host splices (the CommercePlugin precedent). Plugin prose
arrives as **init/factory parameters with original-prose defaults** (`GameText` is a
fixed struct; extensions can't add stored properties). `Package.swift` rows land
per-task so every commit builds. Happy codebase facts: the elvish sword, trophy case,
painting, and egg already exist; the SCORE verb and death/win score epilogue are already
engine-side — `Scoring` adds no verbs.

### Task B1: Package restructuring + `GnustoDangerousDark` (M)

`Package.swift`: `.library(name: "GnustoDangerousDark", …)` +
`.target(name: "GnustoDangerousDark", dependencies: ["Gnusto"], plugins: devPlugins)`;
`Zork1` and `GnustoTests` gain the dep (pattern repeated by B2/B4/B5 for their targets).
`Sources/GnustoDangerousDark/DangerousDark.swift`: the Cellar.swift grue daemon moved
verbatim as `public struct DangerousDark: GameContent` — `@Global darkTurns` (namespaced
`DangerousDark.darkTurns`), `init(warning:death:graceTurns:)` with original-prose
defaults (warn on dark turn 1, die on `graceTurns + 2`), daemon name stays literal
`"grue"` (two instances collide on namespace before timer name; documented). Zork 1
adopts with `DangerousDark(warning: Prose.grueWarning, death: Prose.grueDeath)`; the
grue section of `Sources/Zork1/Cellar.swift` is deleted. **Acceptance bar: the grue trio
(`lingeringInTheDarkIsFatal`, `theLanternKeepsTheGrueAway`,
`restoreFromTheGruesDeathPrompt`) passes unmodified.** Fixture two-room cave game +
cadence/reset/carried-lamp/graceTurns-3 tests. (@Global ID change breaks old saves —
zero users, commit message notes it.)

### Task B2: `GnustoScoring` (M)

`TraitKey<Int>` extensions `.takeValue`/`.depositValue`. `public struct Scoring:
GameContent`: `@Global claimed` (wrapper struct over `Set<String>` owning its
GlobalValue conformance), `awardOnce(_ register:points:)` (idempotent; zero points
no-op; score never decreases — award-once matches the original's one-time treasure
points), `@RuleBuilder treasures(_ items:into trophyCase:)` — per item: `after(.take)`
awards `.takeValue` once; `after(.putIn)` guarded by `trophyCase.holds(item)` awards
`.depositValue` once (placement check filters the sack decoy; no `command` needed).
`maxScore` stays host-owned (read at bootstrap before rules evaluate; documented advice
"sum your declared values"). Fixture VaultGame (gem 4/6, case, decoy sack, maxScore 10)
+ idempotence/decoy/zero-value/direct-awardOnce/death-epilogue/save-restore tests.

### Task B3: Zork slice — trophy case pays out (S)

Painting gains `trait(.takeValue, 4)`/`trait(.depositValue, 6)`; egg 5/5 (original Zork
numbers = data, not prose). `maxScore = 20` (FIDELITY: stands in for 350 until more
treasures exist). Host: `let scoring = Scoring()` in `content`;
`scoring.treasures([cellar.painting, aboveGround.egg], into: house.trophyCase)` spliced
into `rules`. Tests `depositPaintingScoresPoints` (4 → 10 → still 10 after
re-deposit), `eggScoresOnTheWayIn`; audit confirms existing transcripts unaffected
(score-line prefix assertions still match "Your score is …"). FIDELITY: only two
treasures scored; score never decrements on removal; thief does not rob the case (B7).

### Task B4: `GnustoActors` (M)

Logic-only `public struct ActorBehaviors: GamePlugin`, three factories (the plugin owns
no entities and no state — position IS the actor's placement):
- `roams(_ actor:daemonName:rooms:chancePerTurn:arrival:departure:) -> TimedEvent` —
  teleport within the room set (no exit-graph pathing; documented); moves to a random
  *other* room; announcements only when the player's room is lit and is the room
  left/entered (the thief moves silently past a blind player — classic, and what keeps
  Phase-7 dark transcripts stable).
- `steals(_ actor:daemonName:candidates:chancePerTurn:announcement:) -> TimedEvent` —
  when co-located, moves one random *held* candidate `heldBy` the actor and announces.
  Candidates are host-chosen; items inside the trophy case are immune by construction
  (`isHeld` check).
- `reaction(of:to:reply:) -> Rules` — canned reply when the intents target the actor.
**RNG discipline: draws only after all guards pass** (actor placed in set → chance gate →
destination/loot pick). Host stops daemons by name on actor death. Fixture
`ActorBehaviorGames.swift` (PatrolGame; 100% variants for exactness, 50% seed-pinned) +
determinism/darkness/theft/skip/stopDaemon/save-restore tests.

### Task B5: `GnustoMeleeCombat` (L)

`TraitKey<Bool>.weapon`. `public struct MeleeCombat: GameContent`:
- Mints `MeleeCombat.attack` (the engine mints nothing); verbs: attack/kill/hit/fight
  bare + attack/kill/hit/stab/strike "with" indirect-object rows; stage-4 default action
  replies `attackFutile`.
- `Ledger` `@Global` (namespaced `MeleeCombat.ledger`): villain `health`/`stunned` keyed
  by explicit registration key (lazy-seeded from `strength`), `playerHealth`.
- `CombatText` init param (engine-voice lines: `attackFutile`, `noWeapon`, `notAWeapon`,
  `weaponNotHeld`).
- `villain(_ actor:key:strength:weapons:prose:onDefeat:) -> Rules` —
  `actor.before(attack)`: resolve weapon (named indirect object must be registered +
  held; else first held registered weapon; else `noWeapon`); stunned villain → clean
  kill (the classic finish-the-unconscious rule); else ONE `random(1...100)` vs the
  fixed table — miss ≤ 30, wound ≤ 70 (health −1), knockout ≤ 85 (`stunned = 2`), else
  kill. At 0 health: death prose, `onDefeat()`, `vanish()`. Every path ends the turn
  via `reply` (the futile default never double-prints). `VillainProse`
  (miss[]/wound[]/knockout/death, `oneOf`-rotated).
- `aggression(of:key:daemonName:playerStrength:prose:) -> TimedEvent` — guards before
  any draw (villain alive, not stunned [stun decrements silently — recovery turns],
  co-located); one draw: miss ≤ 50 / wound ≤ 85 (player health −1) / kill → `try
  die(prose.playerDeath)`; player wounds don't heal this phase (FIDELITY). The classic
  exchange emerges structurally: your swing resolves in stages 1–5, his answer lands in
  stage 6 (timers).
ArenaGame fixture (dummy strength 3, sword weapon, feather decoy). Seeds discovered by
scanning (~first 100) for needed outcome sequences, hard-pinned with sequence comments.
Tests: seed-free guard refusals; pinned kill (+ vanished target, onDefeat probe);
knockout (stun silence, clean finish); counter-attack player death (banner + UNDO
revive); same-seed byte-identical determinism; mid-fight save/restore ledger
round-trip.

### Task B6: Zork slice — the Troll Room and the troll gate (M)

Delete `cellar.north(blocked: Prose.cellarNorthBlocked)` + that Prose constant; rewrite
`Prose.cellar` (passage no longer rubble-choked). `ZorkCellar` gains `trollRoom`
(dark), `troll` Actor, `@Global trollDefeated`; map: `troll.starts(in: trollRoom)`;
cross-bundle exits in `Zork1.map` (`house.cellar.north(cellar.trollRoom)` + reverse).
Gate: `trollRoom.before(.go)` — east/west while troll alive →
`refuse(Prose.trollBlocksTheWay)`; after → `refuse(Prose.trollRoomPassagesCollapsed)`
(honest stub for the future east-west passage and maze). Sword + knife gain
`trait(.weapon, true)`. Host wires `melee.villain(cellar.troll, key: "troll",
strength: 2, weapons: [house.sword, house.knife], …, onDefeat: { trollDefeated =
true })` + `melee.aggression(…, daemonName: "melee.troll", …)`. Existing transcripts
never go north from the cellar and the aggression daemon draws only when co-located —
unpinned Phase-7 transcripts untouched. Tests (pinned seeds):
`trollBlocksThePassagesUntilDefeated`, `theTrollCanKillYou` (banner, "of a possible
20", UNDO revives). FIDELITY: no troll axe/bloody-axe loot, permanent defeat, no wound
healing, simplified outcome table vs the original's; delete the rubble entry.

### Task B7: Zork slice — the reduced thief (L)

`thief` Actor (starts in the Gallery), `@Global thiefDefeated`;
`@Global trapDoorBarred` in ZorkHouse. Timers: `actors.roams(cellar.thief, daemonName:
"thiefRoams", rooms: [house.cellar, cellar.eastOfChasm, cellar.gallery,
cellar.studio], chancePerTurn: 50, …)` + `actors.steals(…, daemonName: "thiefSteals",
candidates: [cellar.painting, aboveGround.egg], chancePerTurn: 30, …)`. The bar (host
rules — spans two bundles, exactly the host-owns-the-seam doctrine):
`house.cellar.onEnter { if !thiefDefeated { trapDoorBarred = true } }`;
`house.trapDoor.before(.open) { if player.location == house.cellar && trapDoorBarred {
refuse(Prose.trapDoorBarred) } }` — one-sided (the Phase-5 slam prose "a bolt slides
home above you" finally mechanically true); re-descending re-bars while the thief
lives. Thief as villain (NO aggression daemon — evasive, not aggressive; FIDELITY):
`onDefeat` sets `thiefDefeated`, unbars, `stopDaemon` both, scatters held loot to the
room, says the scatter line. Thief carries no flavor knife this phase (FIDELITY).
Tests (pinned seeds): `theThiefBarsTheTrapDoorFromBelow` (bar, chimney escape,
living-room open OK, re-bar), `theThiefStealsAndTheSwordGetsItBack` (theft line,
inventory lacks painting, kill, scatter, take, trap door opens, `up` → Living Room —
the route home closed since Phase 5 works at last), `killingTheThiefStopsHisDaemons`.
**Audit + re-pin**: new daemons shift the RNG draw sequence — B6's pinned seeds
re-verified here (budget for re-pinning); the two Gallery-crossing Phase-7 transcripts
(`cellarLoopByLanternLight`, grue lantern walk) get seed-pinning if they flake
(sanctioned hardening, decision noted in test comments). FIDELITY: teleport-in-set
roaming, steals only the two treasures, doesn't rob the case, doesn't fight back, no
treasure room/maze/stiletto/egg-opening, killing him is the only unbarring.

### Task B8: Docs & fidelity sweep (S)

`Plugins.md` "First-party plugins" section (the two shapes recap, table of four
targets — what each owns, what the host passes, one wiring line each — Zork 1 as the
worked example, the prose-as-parameters pattern and why `GameText` can't carry plugin
lines). `ContentBundles.md` cross-ref ("a bundle with no rooms is how a stateful
plugin ships"). `FIDELITY.md` consistency pass — every "Phase 8 will…" promise in
older entries resolved or re-pointed.

## Contract reconciliation (locked between the two halves)

1. **`command` in bundle/plugin rule bodies**: engine adds it in A4 (GameContent +
   GamePlugin get Game's accessor). Consumed by B5 (indirect object) and B6 (direction).
2. **`Intent.attack`**: owned by `MeleeCombat`; the engine mints nothing (A4's test
   proves the path with its own fixture intent).
3. **Actor API**: A1/A3's surface covers every Part B request; indirect objects already
   parse with actor direct objects (actors are items to the parser).
4. **Fixture filenames**: Part A owns `Support/ActorGames.swift`; Part B's behavior
   fixtures live in `Support/ActorBehaviorGames.swift`.

## Execution order

B1 → B2 → B3 (no Actor dependency; package shape lands early) → A1 → A2 → A3 → A4 →
B4 → B5 → A5 → A6 (vehicles placed so plugin work isn't blocked) → B6 → B7 → A7 + B8
(docs), then PR against `main`. Every task leaves the suite green.

## Deferred (documented, not planned)

him/her pronouns; runtime-varying presence lines; listing NPC inventory in room
descriptions; reach restrictions out of a vehicle; capacity on the implicit
drop-into-vehicle; StatusLine vehicle suffix; boardable actors (a horse); ranged/magic
combat; exit-graph-aware roaming; the full thief (treasure room, maze, stiletto,
egg-opening, fencing).
