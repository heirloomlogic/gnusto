# Phase 10 — Zork 1 Complete (350 points)

## Context

Roadmap v2 ("The Road to Zork 1") Phases 5–9 are merged (PRs #11–#15). Phase 10 is the
finale: complete Zork 1 in `Sources/Zork1/` — full ~110-room map, all 19 treasures, all
puzzles, 350 points, winnable at the Stone Barrow. The current slice has 23 rooms
(house/above-ground/cellar/Troll Room), a reduced thief, painting+egg scoring, maxScore 20.

Binding constraints (unchanged): all descriptive prose is ORIGINAL PLACEHOLDER text, one
named constant per description (verbatim Infocom text arrives later from the user as a
constant-by-constant swap; iconic NAMES are fair game); numeric game data (point values,
strengths, turn counts) is data and used as-is; every knowing divergence gets a FIDELITY.md
entry; [[no-legacy-shims]] — superseded code is deleted outright.

## USER DECISIONS (locked, 2026-07-05)

1. **One PR per task** — 14 small sequential PRs, each implemented by an **Opus 4.8
   subagent** (`Agent` tool, `model: "opus"`), each merged to `main` before the next task
   starts. Rationale: Fable tokens are nearly exhausted; every merged PR is durable progress.
2. **Canonical resurrection for Zork 1 only** — the engine's default stays the current
   death prompt (RESTART/RESTORE/UNDO/QUIT); Zork 1 diverges via a new additive game-level
   death hook to model the original (−10 points, teleport to Forest, possessions scattered,
   final death still reaches the prompt).
3. **Full fidelity** — complete 15-room maze (+4 dead ends), restore the canonical one-way
   canyon (rainbow is the return route), thief roams the whole underground.

Settled during planning (no user input needed):
- Lantern fuel → realistic values with `wait`-driven tests (NOT a test-seam init param —
  `@Global` defaults are baked at declaration; a parameterized Zork1 fights the model).
- Thief architecture: keep `actors.roams`/`actors.steals` wiring (expanded), ADD a bespoke
  draw-free `thiefStash` daemon + lair-scoped aggression via new `while:` param — not a
  full bespoke rewrite.
- Loud Room is drain-state-dependent (canonical). Songbird ambience daemon skipped
  (ledgered); `wind canary` → bauble is deterministic. Joke verbs minimal set: xyzzy/plugh,
  hello sailor, smell. `diagnose`/`count` skipped (ledgered).

## Canonical scoring (verified vs InvisiClues; sums to 350)

Event points (78): into Kitchen 10 · Cellar 25 · East-West Passage 5 · Drafty Room 13 ·
Treasure Room 25 — implemented as `scoring.visit(...)` onEnter+awardOnce registers.

Treasures touch/case (272): egg 5/5 · canary 6/4 · bauble 1/1 · painting 4/6 · platinum
bar 10/5 · ivory torch 14/6 · gold coffin 10/15 · sceptre 4/6 · trunk of jewels 15/5 ·
crystal trident 4/11 · jade figurine 5/5 · sapphire bracelet 5/5 · huge diamond 10/10 ·
bag of coins 10/5 · crystal skull 10/10 · scarab 5/5 · large emerald 5/10 · silver
chalice 10/5 · pot of gold 10/10. All 19 in trophy case → ancient map appears → SW from
West of House → Stone Barrow → `end(won: true)`.

## Architecture

- **Bundles**: one `GameContent` struct per region in `Sources/Zork1/Regions/`:
  `RoundRoom.swift`, `Dam.swift`, `Temple.swift`, `Mirror.swift`, `CoalMine.swift`,
  `River.swift`, `Maze.swift`; plus `Systems.swift` (ZorkBurden weight bundle + shared
  verbs) and `Thief.swift`. Existing `AboveGround/House/Cellar` stay. Prose split into
  `Prose+<Region>.swift` extensions (enum Prose is caseless-extensible), one constant per
  description, no file over ~500 lines.
- **Cross-bundle sharing**: prefer host-wired rules in `Zork1.swift` (bundle instances are
  stored properties — `house.rope`, `dam.screwdriver` reachable); file-scope `let` idiom
  (the `zork1Egg` precedent in House.swift) ONLY where an item is named inside another
  bundle's declaration closures (descriptions, `lockable(with:)`).
- **Additive engine/plugin changes** (all in T1; no shims):
  - E1 `Player.inventory: [Item]` (mirror of `Actor.inventory`) — Player.swift.
  - E2 `Item.contents: [Item]` (children `.on`/`.inside`, sorted) — Item.swift.
  - E3 built-in `wait` verb (`["wait"]`, `["z"]` → "Time passes." via GameText) — engine.
  - E4 `MeleeCombat.aggression(..., while: @Sendable () -> Bool = {true})` — extra guard
    before the same-room check (scopes thief combat to his lair).
  - E5 `Item.moveToPlayer()` (placement `.heldBy(.player)`) — for the burning match.
  - E6 `Scoring.visit(_ room:register:points:) -> Rules` factory + a score-penalty API
    (`Scoring.penalize(_ points:)` or equivalent WorldState score mutation) for death −10.
  - E7 game-level death hook: additive `Game`-protocol customization point (e.g. defaulted
    `onDeath` handler invoked by the `died` TurnInterrupt path BEFORE the engine prompt;
    handler can consume the death — teleport/penalize/print — or fall through to the
    prompt). Default behavior byte-identical to today; only Zork1 overrides.
- **RNG discipline** (the Phase-8 lesson): every new daemon must guard BEFORE drawing so
  quiet turns are draw-free. New RNG consumers: expanded thief roam/steal, bat drop, Loud
  Room ejection (only while water moves). Deterministic (draw-free) daemons: river current,
  maintenance flood, thiefStash, candle/match/bell fuses, drain/refill fuses. All
  seed-pinned tests carry `// re-pin expected in T14`; T14 re-pins everything once.
- **maxScore = 350 lands in T2** and never changes (existing "of a possible 20" assertions
  updated once). Tests must never assert placeholder-only phrasing except where the test is
  about that line — the verbatim-prose swap later must not break tests.

## Tasks (one PR each, sequential; branch off fresh `main` each time)

**T1 — Engine & plugin additions (E1–E7)** — no Zork1 changes. Unit/fixture tests for each
(wait verb transcript, inventory/contents helpers, aggression `while:`, visit factory,
penalty, death hook with a fixture game proving default-unchanged + override-consumed).
Also commits this plan as `docs/superpowers/plans/2026-07-05-phase-10-zork-1-complete.md`.
Files: `Sources/Gnusto/Declarations/{Player,Item}.swift`, SyntaxRule/DefaultActions/GameText
(wait), `Sources/GnustoMeleeCombat/MeleeCombat.swift`, `Sources/GnustoScoring/Scoring.swift`,
engine run-loop death path; new tests in `Tests/GnustoTests/`.

**T2 — Zork1 toolkit** — new `Sources/Zork1/Systems.swift` + `Verbs`: `#verb` pack (give/
hand-to, tie/untie, dig, wave, touch/rub, wind, inflate/deflate, launch, raise/lower,
turn-X-with-Y (specificity 22 beats `turn on` 21), pray, ring, echo, odysseus/ulysses,
xyzzy/plugh, hello, smell) with stage-4 defaults; `ZorkBurden` weight bundle
(`TraitKey<Int> .weight` default 5, recursive load via E1/E2, carryCap ~100, world
`before(.take)` refusal; chimney gate becomes `player.inventory.count <= 2`); liquid water
rework (take-needs-bottle, drink/pour/fill at `.waterSource` rooms); score-rank names via
`.score` action override (rank table = data); lantern resize (dim 200 / last-gasp 225 /
dead 230, third fuse added; two fuel tests rewritten with `wait` filler arrays);
`maxScore = 350` + the four existing assertion updates; Prose.swift split into per-bundle
files; visit awards kitchen 10 + cellar 25. FIDELITY: wait line, matches/verb cuts, chimney
count-not-lamp rule.

**T3 — Death & resurrection (Zork1 only)** — implement the canonical rules via E7:
−10 points per death, teleport to Forest, possessions scattered (brief carries the verified
canonical scatter: lamp handling, above-ground placement list), death counter, final death
→ engine prompt. Rewrite the grue/troll death transcripts (they currently pin the prompt).
Executor verifies exact canonical behavior against walkthrough sources before coding.
FIDELITY: any simplification of the scatter algorithm.

**T4 — Round Room hub** — new `Regions/RoundRoom.swift`: East-West Passage (visit +5),
Round Room, N-S Passage, Chasm, Deep Canyon, Damp Cave, Winding Passage stubs-free wiring;
delete Troll Room east collapsed-stub outright (east now gated on `trollDefeated`);
Loud Room + platinum bar 10/5: room ejects player while `waterMoving` (seeded oneOf —
the one draw here), otherwise any-intent garble rule until bare `echo` fixes acoustics
(`location.before` with no intents matches all; let go/look pass). Sword/knife stay sharp
(trait set in T2). Tests: troll-kill→E-W(+5)→Round Room walk; echo/bar transcript.

**T5 — Dam & Reservoir** — new `Regions/Dam.swift`: Dam, Dam Lobby, Maintenance Room
(dark; red button toggles light), Dam Base, Reservoir South/Reservoir/Reservoir North,
Stream View/Stream. Buttons (before(.push)+reply): yellow=bubble glows/enables bolt,
brown=clears, blue=deterministic flood daemon (ankle/waist/neck bands → drown; room seals
at 13), `turn bolt with wrench` (requires bubble) toggles gates → 8-turn drain/refill
fuses; `reservoirDrained`/`waterMoving` globals drive conditional exits + Loud Room state;
trunk of jewels 15/5 hidden→revealed on drain; refill while standing in Reservoir = death.
Items: wrench, screwdriver, matchbook (Lobby), guidebook, tube, hand pump (Reservoir
North). Water sources registered. Tests: bolt/drain/trunk; flood bands + drowning; refill
death; bolt-without-bubble refusal.

**T6 — Temple, Hades, Dome rope** — new `Regions/Temple.swift`: Engravings Cave, Dome Room
(tie rope to railing → conditional `down` to Torch Room; take-as-untie; no climb back up),
Torch Room (ivory torch 14/6, permanent lightSource, `.openFlame` trait minted here),
Temple, Altar (black book, candles — lightSource + openFlame with banked burn fuses like
the lantern; PRAY at Altar teleports player+held items to Forest — the coffin egress),
Egyptian Room (gold coffin 10/15 container holding sceptre 4/6; coffin weight 55 blocks
rope descent via load cap ~50), Cave (draft snuffs candles), Entrance to Hades, Land of
the Dead (crystal skull 10/10). Exorcism state machine: ring bell (swaps to red-hot bell,
snuffs candles, stage 1, 3-turn lapse fuse) → light candles with match (stage 2, window
renewed) → read book (spirits vanish, south opens). Matches: finite (5), burning match via
E5 `moveToPlayer`, 2-turn fuse. Bell cools after 20 (deliberate anti-softlock, FIDELITY).
Tests: full ritual; lapse reset; draft; matches finite; hot bell; rope/coffin/pray.

**T7 — Mirror rooms & Atlantis chain** — new `Regions/Mirror.swift`: Narrow Passage,
Mirror Room S, Winding Passage, Cave S, Mirror Room N, Cold Passage, Slide Room (one-way
slide → Cellar), Twisting Passage, Atlantis Room (crystal trident 4/11). `touch mirror`
teleports between the two Mirror Rooms (duplicate room names fine — Forest precedent).
Connects Round Room side to Reservoir North side: after T7 the underground is one graph.
Executor must verify this exit table hardest (most error-prone geography). Tests: mirror
round-trip, slide one-way, trident, geography smoke walk.

**T8 — Coal mine & diamond** — new `Regions/CoalMine.swift`: Squeaky Room, Bat Room (jade
5/5; bat seizes you → random coal-maze room unless garlic held — garlic check BEFORE the
draw), Shaft Room (basket-on-chain: container, take-refused; `lower/raise basket` moves it
Shaft↔Drafty, workable only from Shaft; lit torch in open basket lights Drafty via
lightReaches), Smelly Room, Gas Room (sapphire bracelet 5/5; entering with a lit
`.openFlame` item or striking one inside = die(); lantern safe), 4-room coal maze, Ladder
Top/Bottom, Dead End (coal, weight 8), Timber Room, Drafty Room (visit +13; crack
Timber↔Drafty requires `player.inventory.isEmpty`), Machine Room (open lid, coal in, close
lid, `turn switch with screwdriver` → diamond 10/10; non-coal contents survive, FIDELITY).
Tests: torch-in-basket lighting; gas explosion + lantern-safe; empty-hands crack (grue
warning, not death); coal→diamond; bat with/without garlic (pinned).

**T9 — Frigid River, rainbow & canyon** — new `Regions/River.swift`: boat trio (pile of
plastic / magic boat `enterable`+`container` / punctured boat — traits are definition-time,
so state = item swap), inflate-with-pump (on ground only), sharp-trait puncture on board
and on stow, `launch` + walking-into-river conditional exits, river 1–5 with deterministic
current daemon (drift every 2 turns; past river5 = over-the-falls death; no upstream),
buoy in river4 (emerald 5/10 inside; reachable from boat — verified), White Cliffs, Sandy
Beach (shovel), Sandy Cave (dig×4 with shovel → scarab 5/5; 5th dig = buried alive), Shore,
Aragain Falls. `wave sceptre` at Falls/End of Rainbow toggles `rainbowSolid` → pot of gold
10/10 revealed + rainbow crossing exit. RESTORE CANONICAL ONE-WAY CANYON (delete the
two-way FIDELITY divergence; reroute the smoke-walk test over the rainbow). Tests:
inflate/launch/drift/land+buoy; puncture; falls death; no-swim; dig; rainbow round trip.

**T10 — Maze, Cyclops & grating** — new `Regions/Maze.swift`: full 15-room maze + 4 dead
ends with canonical exit graph (executor verifies every room×direction incl. one-ways and
self-loops), skeleton key FINALLY placed (canonical maze room — closes the Phase-5
`.nowhere` seam), skeleton + rusty knife + bag of coins 10/5, Grating Room (grating becomes
a real door: host wires `clearingGrating.down(gratingRoom, via: grating)` both ways; unlock
from below with key; first open from below showers leaves + reveals topside), Cyclops Room
(cyclops states hungry→thirsty→asleep via give lunch then water/bottle; or bare `odysseus`/
`ulysses` → flees, smashing east wall → Strange Passage → Living Room conditional exits;
attack = canned reaction, he doesn't fight — FIDELITY), Treasure Room + Strange Passage
geography (thief behavior arrives T11; visit +25 deferred to T11). Delete Troll Room west
stub. Tests: maze thread traversal, grating round-trip, odysseus, lunch+water, blocked
stairs/wall.

**T11 — Thief endgame** — expand roams to the whole underground room list (exclusions:
Treasure Room arrival-by-roam, Land of the Dead — brief carries the list) and steals
candidates to all treasures (still held-only, FIDELITY); new `Thief.swift`: draw-free
`thiefStash` daemon (in lair → silently deposit loot), lair defense (Treasure Room onEnter
summons him; `melee.aggression(..., while: { thief.isIn(treasureRoom) })` with stiletto
prose — evasive elsewhere), chalice 10/5 guarded while he lives, `give X to thief`
(accepts anything; egg starts a 4-turn `thiefOpensEgg` fuse → egg opened properly, canary
intact), onDefeat → dropAll (hoard+stiletto) + unbar + stop all his daemons. Egg becomes
openable container (rework `zork1Egg`): player-forced open wrecks canary → brokenCanary
(0/0). Treasure Room visit +25. All existing thief transcripts re-recorded (roam-set
change breaks their seeds — by design, once). Tests: ferry-loot-to-lair, defended lair,
egg service, forced egg, kill-drops-everything, guarded chalice (pinned seeds, marked).

**T12 — Canary, bauble & treasure glue** — canary 6/4 (inside egg, state from T11),
brass bauble 1/1: `wind canary` in forest rooms (once) → songbird drops it; broken canary
wheezes. Audit all 19 treasures carry correct takeValue/depositValue and are in the host
`scoring.treasures` roster. Tests: wind-canary paths.

**T13 — Endgame wiring** — trophy case `after(.putIn)`: when it holds all 19 → ancient map
(hidden, pre-placed in case) revealed + announcement; `westOfHouse.sw(stoneBarrow,
when: { map.isRevealed })`; Stone Barrow room: epilogue + `end(won: true)`. Negative test:
SW refused before map. FIDELITY: award-once vs original in-case accounting (score never
drops when a treasure leaves the case).

**T14 — Full 350 walkthrough + seed re-pin + docs sweep** — the phase acceptance: one
scripted walkthrough (~400–600 commands, InvisiClues route) from West of House to
`end(won: true)` at 350, asserting per-region score checkpoints, map appearance, rank name,
epilogue; lantern→torch light handoff proves fuel economy end-to-end; troll+thief deaths
in-run (seed found by scripted brute-force scan after content freeze; egg-first + knockout-
finish reduce variance). Re-pin every seeded test in the suite. FIDELITY + README/docs
final sweep. Possibly split into `Zork1WalkthroughTests.swift`; keep in default run unless
>~60s.

## Execution model (per task)

1. Fable (minimal tokens): create branch `heirloomlogic/phase-10-t<N>-<slug>` off fresh
   `main`, spawn ONE Opus 4.8 subagent (`Agent`, `model: "opus"`) with the task brief:
   the task's section from the committed plan doc + canonical data tables + repo
   conventions (placeholder prose, one-constant-per-description, FIDELITY, test style,
   seed discipline, `swift build && swift test` green before PR).
2. The subagent implements, verifies canonical map/mechanics details via web sources where
   the plan says "executor verifies", updates FIDELITY.md in the same commit, runs the
   full suite, opens the PR (`gh pr create --base main`) with `Phase 10.<N>` title.
3. User merges; next task starts from updated main. If Fable's budget runs out mid-phase,
   any future session picks up at the next unmerged task using the committed plan doc.

## Verification

- Per task: new transcript tests + entire existing suite green (`swift build && swift test`)
  before the PR; every region task includes an RNG-free geography smoke walk.
- Phase acceptance (T14): the 350-point Won walkthrough + full-suite green + CI.
- Manual: `swift run Zork1` remains playable end-to-end.

## Risks

- **Seed shifts**: contained by draw-free daemon design, routing tests around random
  actors, and the single T14 re-pin pass (thief tasks re-record locally too).
- **Canonical map errors**: every region brief requires executor verification of the exit
  table against canonical sources before coding; Mirror chain and maze flagged hardest.
- **Transcript brittleness**: anchor on room names/event lines only, never prose bodies.
- **Save-format**: new @Globals break old saves — zero users, noted in FIDELITY.
- **Walkthrough length**: `play()` handles hundreds of commands; fallback is a save/restore
  chain split (mechanism already tested).
