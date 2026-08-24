# Fidelity Ledger

Tracks every place a Gnusto game content slice knowingly departs from the
source material it's modeling, or from a "finished" implementation of its
own mechanics — so a later pass has a checklist instead of a memory. Each
entry below is grouped by the task that introduced it.

**Two games are ledgered here, and they do not follow the same prose rule.**
Everything from *Task 8* down to *The kitchen window* is Zork 1, which
reproduces its source verbatim and says so in every section. Everything from
*Dungeon* onward is an adaptation instead, and that section states its own rule
before any region entry. Read it before writing a line of Dungeon prose; carrying
Zork 1's across is the mistake it exists to prevent.

## Task 8 — Zork 1 slice: White House (`Sources/Zork1/`)

### Prose

- **Every room and item description is now the original Zork I text**,
  reproduced from the `historicalsource/zork1` archive under the MIT license
  (see `THIRD_PARTY_NOTICES` at the repo root for provenance). Every
  description is a named constant in `Sources/Zork1/Prose.swift`, and the
  verbatim-text swap was applied one constant at a time. Room and item
  *names* ("West of House", "brass lantern", "jewel-encrusted egg") are the
  iconic proper nouns and were always used as-is; the descriptive prose
  around them now carries the original Zork I text too.

### Map topology

- The above-ground map (`Sources/Zork1/AboveGround.swift`) follows the
  well-known Zork 1 layout for this region in spirit — the house exterior
  ring, the forest and clearings north of it, the tree with the egg's nest,
  the leaf-covered grating, and a canyon dropping away to the east — but
  several specific connections are simplified rather than researched
  street-by-street against a canonical map:
  - The kitchen window sits on Behind House's **west** exit rather than a
    diagonal/southwest approach some maps use; Behind House's forest
    connection was moved to **east** to make room for it (a single room
    can't have the same direction point to two different exits).
  - The canyon (Canyon View → Rocky Ledge → Canyon Bottom → End of Rainbow)
    is modeled as a **two-way** path. This entry once claimed the authentic
    canyon was a one-way trap needing climbing gear — that was **wrong**.
    The original's canyon rooms are all `CLIMBABLE-CLIFF` with unconditional
    up/down exits (verified against `1dungeon.zil` in Phase 10.9), so a
    two-way canyon *is* canonical and nothing here diverges. The rainbow
    (Phase 10.9) is an additional crossing of the falls, not the canyon's
    only return.
  - `Forest (northeast)` is a minimal dead-end-ish stub connecting back to
    `Forest (west)` and `Forest (east)`; the real game's forest maze logic
    (movement without a fixed map) is not modeled here.

### Mechanics simplified or deferred

- **Tree climbing is a real `climb` verb (closed in the fidelity pass).** For a
  long while tree climbing was only the `up`/`down` exit pair between Forest Path
  and Up a Tree, and `climb tree` fell through to "I didn't understand." The
  `climb` verb now exists (`Systems.swift`); `climb tree` reaches the perch, the
  same place `up` leads (`AboveGround.swift` rules). Off a climbable it answers
  with a polite default. The chimney/dome/canyon still use their own `up`/`down`
  gates rather than `climb` — a minor remaining seam, not a wart.
- **The grating's key doesn't exist yet.** `ZorkAboveGround.grating` is
  `lockable(with: skeletonKey)`, and `skeletonKey` is declared but never
  placed in any `map` block, so it starts (and stays) `.nowhere` — legal per
  Bootstrap (an unplaced item defaults to `.nowhere`), and confirmed by
  running the bootstrap: no stub room was needed. `open grating` therefore
  always refuses with the engine's standard "is locked" message. The maze
  that actually holds the key was deferred out of Phase 7 (which took the
  cellar region instead) and remains future content.
- **The trap door is really barred now (Phase 8).** The slam prose's "you
  hear a bolt slide home above you" told the truth-to-be since Phase 5;
  with the thief in play it is mechanically true: descending while he
  lives sets the bar, opening from the cellar side refuses, the living
  room side is never barred (the bolt is on top), and killing the thief
  is the only unbarring — the original also relents after other events,
  which we don't model. A *lightless* player still can't reopen it from
  below regardless (a dark room's scope collapses), but since Phase 7
  that's no longer a soft-lock — see the next entry.
- **The Phase-5 "known soft-lock" is closed (Phase 7).** The earlier ledger
  pinned a genuine stuck state: a lightless player sealed in the dark stub
  cellar, with no grue to end it and no way out. Phase 7 closed it from
  both directions promised then — the brass lantern is a real light source
  (lit, the cellar is a described room and the trap door is back in scope),
  and the cellar region's Gallery/chimney loop gives even a lightless
  player a dash to daylight (`chimneyEscapeInTheDark` pins it). The pinning
  test `darkCellarSoftLockIsThePhase7Seam` was deleted with the seam;
  `cellarLoopByLanternLight` is its replacement reality. Darkness turning
  *lethal* (the grue) is the remaining Phase-7 piece, ledgered separately
  when it lands.

## Phase 7 — cellar region & the lit lantern (`Sources/Zork1/Cellar.swift`)

- **All prose is now the original Zork I text**, same policy and same
  one-constant-per-entity structure as Task 8 above.
- **The cellar region is the classic loop plus the Troll Room (Phase 8)**:
  Cellar (in `ZorkHouse`) → East of Chasm → Gallery (painting) → Studio →
  chimney up to the Kitchen, and now north from the Cellar into the Troll
  Room. The maze and everything deeper stay future content.
- **The chimney is a plain one-way exit** (`studio.up(kitchen)`, no
  `kitchen.down`). The original's restriction — climbable only while
  carrying at most one item plus the lamp — is not modeled.
- **The Gallery is inherently lit** ("daylight from somewhere high above"),
  matching the original; it doubles as the resting point that makes the
  lightless chimney dash survivable.
- **Treasure scoring is live for exactly two treasures (Phase 8).** The
  painting pays the original's 4 on first take and 6 on first trophy-case
  deposit; the egg pays 5 and 5 (values are data, not prose — used as-is).
  `maxScore` is 20, the sum of what this slice can score, standing in for
  the real 350 until more treasures exist. Scoring now models the original's
  in-case accounting: **take** value is paid once for good, but **deposit**
  value is credited when a treasure lands in the trophy case and debited
  again when it is taken back out, so the score rises and falls as the hoard
  is rearranged (`GnustoScoring`'s reversible deposit register).
- **The lantern's fuel is deliberately tiny**: dim warning after 20 burning
  turns, dead after 25 — the original burns for hundreds. Chosen so a
  transcript test (`lanternBurnsOut`) can watch the whole arc. Turning the
  lantern off banks the remaining turns (the classic economy). Every rung
  now carries the original's can-you-see-the-lamp check *(closed in the
  fidelity pass — the warnings used to print wherever the player was)*: they
  are said `from: lantern`, and the last one is said before the flame goes
  out, so a lamp dying at the player's feet still explains the blackout. A
  burned-out lantern refuses `turn on` with `Prose.lanternSpent`, and nothing
  in the slice replaces it.
- **The grue rolls the dice** *(closed in the fidelity pass — was a deterministic
  linger clock)*, like the original: a warning on the first consecutive turn *ending*
  in darkness (the kept fairness beat — the grue never eats you on the turn the dark
  begins), one silent grace turn, then from the third dark turn on it rolls
  `chance(lethality)` (Zork 1 uses 50%) to be eaten each turn; any lit turn resets the
  count. The daemon lives in the `GnustoDangerousDark` plugin (`graceTurns` and
  `lethality` are knobs); Zork 1 passes its own prose in. The warning and death prose are
  original — the famous "likely to be eaten by a grue" sentence is Infocom's and is
  deliberately not reproduced ("grue" the name is fair game under the names-vs-prose line
  above). Because death is now a roll, the dark-lingering transcripts are seed-pinned (the
  cost of the dice); the warning still guarantees a safe first dark turn even after an UNDO
  revive.
- **The white house exterior is four separate scenery items**
  (`whiteHouseAtWest`/`AtNorth`/`AtSouth`/`AtBehind`), one per house-side
  room, all sharing the same name and `Prose.whiteHouse` text. A single
  `Item` occupies exactly one placement at a time (the last `starts(in:)`
  for a given item wins, with no duplicate-placement diagnostic), so "the
  house is examinable from every side" needed one scenery item per room
  rather than one item registered four times.
- **Cross-bundle egg/trophy-case sharing uses a file-scope `let`.**
  `ZorkAboveGround.egg` and `ZorkHouse.trophyCase` are both aliases of
  file-scope values declared in `Sources/Zork1/House.swift`
  (`zork1Egg`/`zork1TrophyCase`), following the same pattern
  `DslQuickWinGames.swift`'s `eggItem`/`trophyCaseItem` pair uses within a
  single file — a stored property's initializer can't reference `self` or a
  sibling stored property, but a closure captured in a later top-level
  `let` can freely name an earlier one. This was chosen over the
  `ContentBundles` article's "explicit injection" pattern (constructing one
  bundle with a reference to the other's item) because the trophy case's
  closure needs to name the egg *inside its own description closure*, which
  runs into the same self-reference restriction either way; the file-scope
  idiom resolves both problems (cross-bundle sharing and self-reference) at
  once.

### Out of scope for Task 8 (unchanged)

- No maze, no full cellar beyond the loop — later phases per the Roadmap
  v2 plan. (Treasure scoring arrived in Phase 8; the troll and thief have
  their own Phase-8 entries below.)

## Phase 8 — the Troll Room (`Sources/Zork1/Cellar.swift`)

- **All prose is now the original Zork I text**, same policy as ever;
  "troll" the name was always used as-is, and Infocom's sentences now carry
  through too. The troll's strength (2) and the sword/knife as the weapons
  that can reach him are the original's data.
- **The passages beyond the troll are honest stubs.** East (toward the
  round-room side of the dungeon) and west (toward the maze) refuse with
  the troll's block while he lives, and with a collapsed-passages line
  after — their regions are later phases. In the original both passages
  open onto real map. *(Updated in Phase 10.4: east now opens onto the
  East-West Passage once the troll falls; only west remains a stub.)*
- **Combat reads a per-weapon table** *(closed in the fidelity pass — was a single
  fixed table)*. One roll per swing (miss/wound/knockout/kill), but the cutpoints now
  slide with the weapon's `.weaponStrength`: the elvish sword (keen, 3) whiffs less and
  kills more than the nasty knife (2) or the thief's stiletto (clumsy, 1), the original's
  per-weapon distinction. Strength 2 is the historic 30/70/85 table, so an ordinary weapon
  fights exactly as before. The villain answers on the end-of-turn clock, player wounds
  never heal, and a knocked-out troll falls to the next clean blow. Deterministic under a
  pinned seed; the transcripts record their sequences.
- **Defeat is permanent; his axe is now lootable (closed in the fidelity
  pass).** The troll still vanishes with his death line ("sinks into the
  shadows") and never recovers to block again — the original's randomized
  recovery isn't modeled. But his **bloody axe** (a `ZorkCellar` item, `.nowhere`
  in his hands while he lives) now clatters to the Troll Room floor on defeat
  (his `onDefeat`, host-wired in `Zork1`) and can be taken; it is `.weapon` and
  `.sharp` (holes the river boat, like the other blades). Earlier the body took
  the axe into the floor with it.

## Phase 8 — the reduced thief (`Sources/Zork1/Cellar.swift` + host wiring)

- **The thief is deliberately reduced.** He roams exactly four rooms
  (Cellar, East of Chasm, Gallery, Studio) by teleport-within-set — no
  exit-graph pathing, no visits to the rest of the map. He steals only
  the two treasures (painting, egg), only from the player's hands: the
  trophy case, the floor, and the lantern/sword are all beyond his reach,
  where the original's thief lifts nearly anything from nearly anywhere.
  No maze lair, no treasure room, no stiletto, no egg-opening service,
  no fencing of goods — all deferred with the maze.
- **He doesn't fight back.** Registered as a `GnustoMeleeCombat` villain
  (strength 2, killable with sword or knife) but with no aggression
  daemon — evasive, not aggressive, in this reduced form. The original's
  thief is one of the game's deadliest fighters.
- **Movement and theft respect darkness.** His arrivals, departures, and
  thefts are announced only in lit rooms (`GnustoActors` behavior); in
  the dark he works in silence, which also keeps the Phase-7 dark-room
  transcripts stable.
- **Death scatters the loot at your feet** (rather than the original's
  recovering-it-from-his-lair), unbars the trap door, and stops his
  daemons. Treasures recovered this way re-take/re-deposit without
  double-scoring (award-once registers).

## Phase 10.2 — Zork 1 toolkit (`Sources/Zork1/Systems.swift`, `Burden.swift`, `House.swift`)

The systems layer that flips the slice from a 20-point placeholder toward the
real 350-point game: a custom verb vocabulary, weight/burden, liquid handling,
score ranks, and a longer lantern burn. No new rooms this task.

### Prose

- **`Prose.swift` is split by region** into `Prose+AboveGround.swift`,
  `Prose+House.swift`, `Prose+Cellar.swift`, and `Prose+Systems.swift`
  (extensions on the same `enum Prose`). Pure relocation — the text was
  unchanged, and the one-constant-per-entity structure is the path the
  verbatim swap later flowed through cleanly.
- **The custom verbs' responses are the original Zork I text**, same as
  every other line. Infocom's famous joke replies (the hollow voice's
  "Fool.", the wave-of-nausea, and so on) carry through; the verb
  *words* the player types (`xyzzy`, `plugh`, `pray`, …) are the iconic ones
  and were always used as-is. That still holds for every verb Zork has original
  text for, including the ones the engine has since taken over as stubs: Zork
  overrides those verbs' stage-4 defaults, so the reproduced text stays inside
  `Sources/Zork1/` where `THIRD_PARTY_NOTICES` scopes it.
- **Verbs the original didn't have answer in the engine's voice.** The engine's
  stub set is wider than Zork's verb pack, so `sing`, `jump`, `kneel`, `listen`,
  `eat` and the rest reply with Gnusto's generic line rather than anything
  Infocom wrote. A departure, and the right one: the alternative is
  `I don't know the word "sing"`.

### Custom verbs (`Systems.swift`)

- **Most of the verb pack moved into the engine.** `dig`, `wave`, `touch`,
  `tie`/`untie`, `give`, `smell`, `drink`, `fill`, `pour`, `climb`, `pray` and the
  magic words `xyzzy`/`plugh` are engine *stub verbs* now, so every Gnusto game
  gets them. What stays in `Systems.swift` is the vocabulary that is actually
  Zork's: `wind`, `inflate`/`deflate`, `launch`, `raise`/`lower`, `turn … with …`,
  `ring`, `echo`, `odysseus`/`ulysses`, `hello`/`hi`, `fix`, `diagnose`.
  **No player-visible text changed for the verbs Zork already had**: it keeps an
  `action(…)` override for each of those thirteen, so the reply is still the
  original's line, not the engine's. That is also deliberate on licensing
  grounds — the reproduced Infocom text stays inside `Sources/Zork1/`, per
  `THIRD_PARTY_NOTICES`. The ~34 stub verbs Zork *never* had (`sing`, `jump`,
  `kneel`, `eat`, …) are new vocabulary answering in the engine's voice.
- **The verbs that remain are still mostly inert.** Their real mechanics arrive
  with the regions that need them (the clockwork canary, the plastic boat, the dam
  controls, the Cyclops), which only have to add an item-scoped rule — the parser
  already knows the word.
- **`diagnose` is modeled; `count` is now the engine's.**
  `diagnose` reports the death toll and how many resurrections remain
  (`action(.diagnose)` in `Zork1`, reading the host's `deaths` counter): perfect
  health while unscathed, otherwise "killed N times" with the survivals left. The
  original's per-wound severity is not reported — the slice tracks no numeric
  player-wound state, only deaths. `count` parses (it is an engine stub) but Zork
  gives it no meaning of its own.
- **`turn … with …` outspecifies `turn … on`** (specificity 22 vs 21) so
  "turn bolt with wrench" never trips the light switch. The engine's bare
  `turn <object>` stub sits below both at 11.
- **Bare `turn bolt` is ours, not the original's.** The original had no bare
  `turn` verb; the engine ships one, so the bolt gets a `bolt.before(.turn)` rule
  pointing at the tool ("Your bare hands aren't enough. The bolt needs a tool.")
  rather than the engine's generic "The bolt doesn't turn."

### Burden / weight (`Burden.swift`)

- **Every takeable item weighs a flat 5 by default**, with a carrying cap of
  100 (the original's cap) — twenty small things. Heavy items (the coffin,
  the gold) will override `.weight` in later regions; none do yet, so the cap
  itself is effectively unreachable with current content and is exercised
  only indirectly through the chimney gate below.
- **The chimney gate is the original's "one item plus the lamp" rule (closed in
  the fidelity pass).** Climbing the Studio chimney is refused with more than one
  thing in hand *besides* the lamp — the lamp rides free (`studio.before(.go)`
  filters `house.lantern` out of the count). While the lamp is carried for light
  (every playable descent), this is observationally identical to the earlier
  `inventory.count <= 2` simplification; the difference — carrying two non-lamp
  things up a lightless chimney — only arises in the dark, where you couldn't see
  to climb anyway.

### Liquids (`House.swift`)

- **Water can't be carried loose** — taking it always refuses ("slips
  between your fingers"); it lives in the bottle. `drink` and `pour` empty
  the bottle; `fill` needs a `.waterSource` room.
- **The `.waterSource` location trait ships dormant.** No room sets it in this
  slice (the reservoir and its shores arrive with the dam), so `fill` always
  reports there's nothing to fill from. The verb and trait exist now so those
  rooms only have to flip the trait on.

### Scoring

- **`maxScore` is now 350**, the real ceiling, though only a fraction is
  reachable in the current slice.
- **Visit awards are live for the kitchen (10) and the cellar (25)**, matching
  the original's event scoring.
- **Death now carries a 10-point toll** (Phase 10.3, below), so a death docks
  the score before the player is resurrected; only the final death lets the
  banner show the score untouched by that turn's toll.
- **Score ranks are shown, and the rank names are now Zork's own titles.**
  The ladder's thresholds are game data used as-is; the titles ("Beginner",
  "Amateur Adventurer", "Novice Adventurer", "Junior Adventurer",
  "Adventurer", "Master", "Wizard", "Master Adventurer") are the original
  Zork I ranks, reproduced from the `historicalsource/zork1` archive under
  the MIT license (see `THIRD_PARTY_NOTICES`) on the same names-vs-prose line
  as everything else. The `score` verb is a meta intent (it skips all rules), so
  the rank is appended via an `action(.score)` override whose first line
  reproduces the engine's score line verbatim.

### Lantern

- **The lantern fuel is scaled up toward the original's long burn**: a dim
  warning at 200 turns, a last-gasp warning at 225 (a new third fuse), and
  darkness for good at 230 — replacing the deliberately tiny Phase-7 values
  (20/25) that only existed so a short transcript could watch it die. Still a
  fraction of the original's hundreds of turns, but long enough that fuel is
  no longer a near-term concern. Turning the lantern off still banks all three
  fuses' remaining turns.

## Phase 10.3 — Death & resurrection (`Sources/Zork1/Zork1.swift`)

Zork's canonical resurrection, implemented on the game's `onDeath()` hook (a
`.consumed` outcome for the survivable deaths, `.fallThrough` for the last
one). A `@Global var deaths` counts them.

- **Death is survivable — twice.** The first two deaths cost 10 points, scatter
  the player's belongings, and set them back on their feet in the forest; the
  world stays in play (no banner, no prompt). The **third death is final** and
  falls through to the engine's standard `*** You have died ***` banner and
  RESTART / RESTORE / UNDO / QUIT prompt. This matches the original's cap of two
  resurrections. (The number is game data, used as-is.)
- **The resurrection prose is now the original Zork I text** (`Prose.resurrection`,
  in `Prose+Systems.swift`), one constant like everywhere else — Infocom's
  resurrection narration now carries through. The player is resurrected in
  **Forest West** (`aboveGround.forestWest`); the original's exact resurrection
  room isn't researched here, only that it's the forest.
- **The scatter is random** *(closed in the fidelity pass — was a deterministic
  round-robin)*, like the original: every carried item is flung to a random one of the
  six above-ground rooms (West of House, North of House, South of House, Behind House,
  Forest Path, Clearing), one `random(…)` draw apiece. The **lamp is the one exception —
  it always returns to the living room** (so light is always recoverable), a deliberate
  anti-softlock kept on purpose. `player.inventory` is iterated id-sorted, so only the
  destinations vary, not the order they are drawn in; the draws mean a death carrying kit
  is now seed-pinned in tests (the cost of the randomness).

## Phase 10.4 — Round Room hub (`Sources/Zork1/Regions/RoundRoom.swift`)

The underground crossroads east of the Troll Room: the East-West Passage, the
Round Room and its passages, the Chasm, Deep Canyon, Damp Cave, and the Loud
Room with the platinum bar. First region under `Sources/Zork1/Regions/` — the
three earlier regions stay flat at the target root (SwiftPM is
directory-agnostic; this only organizes the many regions still to come).

### Prose

- **All room, item, and message prose is now the original Zork I text**, same
  policy and one-constant-per-entity structure as every prior task
  (`Prose+RoundRoom.swift`). Room and treasure *names* ("Round Room", "Loud
  Room", "platinum bar") are the iconic ones, used as-is.

### Map topology

- **The exit table is the canonical Zork 1 layout** (verified against the
  original `1dungeon.zil`): East-West Passage E↔Round Room, N/Down→Chasm;
  Round Room E↔Loud Room, W↔East-West Passage, N↔North-South Passage;
  North-South Passage N→Chasm, NE↔Deep Canyon, S↔Round Room; Chasm SW/Up→
  East-West Passage, S→North-South Passage; Deep Canyon SW→North-South Passage,
  Down→Loud Room; Loud Room E↔Damp Cave, W→Round Room, Up↔Deep Canyon; Damp
  Cave W↔Loud Room.
- **Exits onward to unbuilt regions are simply absent, not stubbed.** The Round
  Room's south (Narrow Passage) and southeast (Engravings Cave), the Chasm's and
  Deep Canyon's northwest edges toward the reservoir, Deep Canyon's east to the
  dam, and Damp Cave's east to the White Cliffs all lead into regions that don't
  exist yet, so they give the engine's plain "you can't go that way" rather than
  an honest-stub refusal — the hub interior itself is fully connected and
  stubs-free. The Chasm's downward drop and Damp Cave's southward crack are
  authored `blocked:` refusals (the original blocks both with a message).
- **`Winding Passage` is deferred to the Mirror region (T7), not built here.**
  The roadmap's T4 line lists it, but canonically it connects only to Mirror
  Room 2 and Tiny Cave — both Mirror/Temple geography with no edge to the Round
  Room hub. Building it now would strand a room with no reachable exits, so it
  waits for T7 (which also lists it).
- **The Troll Room's east passage is now real.** It opens onto the East-West
  Passage once the troll falls (`when: { trollDefeated }`, host-wired since it
  crosses bundles), replacing the Phase-8 collapsed-passage stub. The **west**
  passage (toward the maze) stays an honest stub until T10.

### The Loud Room

- **The acoustics puzzle is the original's SACREDBIT + read-loop** *(closed in the
  fidelity pass — was a match-all garble rule)*. On still water the room runs the
  original's read-loop: every command but movement, looking, `echo`, and taking the
  bar echoes the last word of your input back (`loudRoomEcho`). The platinum bar
  carries its own take-lock — the `SACREDBIT`, modeled as `platinumBar.before(.take)`
  — so it is untakeable until `echo` sets `loudRoomAcousticsFixed` and lifts the lock.
  One small liberty: taking the bar while loud answers with the roar (the take-lock's
  message) rather than an echo, so the SACREDBIT is the live, observable mechanism.
- **The water-driven ejection is present but dormant.** While `waterMoving` is
  true the room scrambles the player out to one random neighbour (Damp Cave,
  Round Room, or Deep Canyon — the original's `LOUD-RUNS` set) — this region's
  only RNG draw, guarded so still-water turns never touch the stream.
  `waterMoving` defaults false and is owned here but driven by the dam region
  (T5); until then the ejection path is unexercised. Its exact end-of-turn
  timing (the original ejects at `M-END`, after the command) is modeled as a
  start-of-turn `beforeEachTurn` bounce and will be revisited when T5 wires and
  tests the water state.
- **The platinum bar carries the original's numbers** (weight/`SIZE` 20, find
  10, case 5) and is in the host `scoring.treasures` roster.

### Scoring

- **The East-West Passage pays 5 on first arrival** (the original's room
  `VALUE`), host-wired via `scoring.visit` alongside the kitchen and cellar.

## Phase 10.5 — Dam & Reservoir (`Sources/Zork1/Regions/Dam.swift`)

Flood Control Dam #3, its lobby and Maintenance Room, the Dam Base, the three
reservoir rooms, and the stream. The region's machinery — the four buttons, the
green bubble, and the bolt-worked sluice gates — is the first player-operated
mechanism in the slice, and the first source of the moving water the Loud Room
has been waiting on since Phase 10.4.

### Prose

- **All room, item, and message prose is now the original Zork I text**, same
  policy and one-constant-per-entity structure as every prior task
  (`Prose+Dam.swift`). Room and item *names* ("Dam", "Maintenance Room", "trunk
  of jewels", "hand-held air pump") are the iconic ones, used as-is.

### Map topology

- **The exit table is the canonical Zork 1 layout** (verified against the
  original `1dungeon.zil`): Dam Down/E→Dam Base, N↔Dam Lobby, W→Reservoir South,
  S→Deep Canyon; Dam Lobby N/E→Maintenance Room, S↔Dam; Maintenance Room
  S/W→Dam Lobby; Dam Base N/Up→Dam; Reservoir South E→Dam, W↔Stream View,
  SE↔Deep Canyon, SW↔Chasm, N→Reservoir (only when drained); Reservoir
  N↔Reservoir North, S↔Reservoir South, Up/W→Stream, Down blocked; Reservoir
  North S→Reservoir (only when drained), N→Atlantis (T7); Stream View E→Reservoir
  South, W blocked; Stream Down/E→Reservoir, Up/W blocked.
- **The cross-region edges to the Round Room hub are host-wired.** Deep Canyon's
  east (to the Dam) and northwest (to Reservoir South), and the Chasm's northeast
  (to Reservoir South), cross the `ZorkRoundRoom`/`ZorkDam` bundle boundary, so
  the host owns them — the same seam as the troll's east exit. These are the
  "await their region" edges the Round Room region (10.4) deliberately left
  absent.
- **The reservoir bed is crossable only while drained.** Reservoir South↔Reservoir
  and Reservoir North↔Reservoir are conditional exits gated on `reservoirDrained`
  (the original's `LOW-TIDE`); a full reservoir refuses with a "you would drown"
  message (`IF LOW-TIDE ELSE "You would drown."`).
- **The stream's boat-only `LAND` disembark is deferred to the river region
  (T9).** The original reaches Stream View from the stream via a `LAND` exit used
  only when boating; the engine has no `LAND` direction and the boat isn't built
  yet, so that edge is absent. Both stream rooms stay reachable on foot — Stream
  View from Reservoir South's west, the Stream from the drained reservoir bed — so
  nothing is stranded.
- **Dam Base is a bare room this task.** The pile of plastic (the inflatable
  boat) that canonically starts here belongs to the river region (T9) and is not
  placed yet.

### Mechanics simplified or deferred

- **The Maintenance Room flood is a continuous rising level** *(closed in the fidelity
  pass — was a three-band model)*. The blue button starts a `damFlood` daemon; the water
  climbs one body-part step every turn along the original's ladder — ankles, shins, knees,
  hips, waist, chest, neck — narrated each turn, and once it tops the neck the room is full,
  anyone still here drowns, and the room seals (the daemon stops). The level is a plain
  deterministic counter (`floodLevel`), not a dice roll, so no seed is needed. **Leaving
  the room is the only escape** — the flood itself is not tube-pluggable (nor is
  it in the original). The tube of gunk is no longer inert, though: it now patches
  the punctured river boat (closed in the fidelity pass — see the Phase 10.9
  entry below).
- **`waterMoving` is driven across the bundle boundary by the host.** The Loud
  Room (in `ZorkRoundRoom`) reads `waterMoving`, but a bundle can't reach another
  bundle's `@Global` from its own rules, so the `turn bolt with wrench` rule and
  the eight-turn `damDrain`/`damRefill` fuses — the only writers of `waterMoving`
  — live in the host (`Zork1.swift`), the same way `cellar.trollDefeated` is
  written from the host. The original keeps a single global flag both areas share
  directly.
- **The gates take a flat eight turns to drain or refill** (the original's
  `GATE-INT`), driving `waterMoving` for the duration (the Loud Room ejects while
  it runs) and toggling `reservoirDrained` when they settle. Draining reveals the
  trunk of jewels (`hidden` until the drain fuse calls `reveal()`); refilling
  while standing on the reservoir bed drowns you.
- **The bolt requires the charged panel, not just the wrench.** `turn bolt with
  wrench` refuses unless the yellow button has set `bubbleGlowing` (the original's
  green bubble / `GATE-FLAG`); the brown button clears it. The red button toggles
  the Maintenance Room's own light (tracked with a flag so a carried lantern isn't
  mistaken for it). Turning the bolt with anything but the wrench is refused.
- **The matchbook and hand pump are placed now, inert until later.** The
  matchbook (Dam Lobby) is a readable item here; its finite, lightable matches
  arrive with the Temple exorcism (T6). The hand pump (Reservoir North) inflates
  the boat in the river region (T9). Both sit in their canonical rooms so the
  parser and geography are complete from the start.

### Scoring

- **The trunk of jewels carries the original's numbers** (weight/`SIZE` 35, find
  15, case 5) and is in the host `scoring.treasures` roster, paying out in the
  living-room trophy case like the other treasures.

### Water sources

- **The reservoir shores and the stream are the slice's first fillable rooms.**
  Reservoir South/North, the Reservoir bed, Stream View, and the Stream all carry
  the `.waterSource` trait (minted dormant in Phase 10.2), so an emptied bottle
  fills there — the "there's no water here" default now has somewhere it doesn't
  apply.

## Phase 10.6 — Temple, Hades & Dome rope (`Sources/Zork1/Regions/Temple.swift`)

The dark religious heart of the underground: the Engravings Cave and the Dome
Room's rope descent, the Torch Room's ivory torch, the Temple, Altar, and
Egyptian Room, and the draughty way down to the Entrance to Hades and the Land
of the Dead. The region's set piece is the exorcism ritual (ring bell → light
candles → read book) that banishes the spirits guarding the crystal skull.

### Prose

- **All room, item, and message prose is now the original Zork I text**, same
  policy and one-constant-per-entity structure as every prior task
  (`Prose+Temple.swift`). Room and item *names* ("Torch Room", "ivory torch",
  "gold coffin", "crystal skull") are the iconic ones, used as-is.

### Map topology

- **The exit table is the canonical Zork 1 layout** (verified against the
  original `1dungeon.zil`): Engravings Cave W→Round Room, E→Dome Room; Dome Room
  W→Engravings Cave, Down→Torch Room (only with the rope tied); Torch Room Up
  blocked (the rope hangs out of reach — a one-way drop), S/Down→Temple; Temple
  N/Up→Torch Room, E/Down→Egyptian Room, S→Altar; Egyptian Room W/Up→Temple;
  Altar N→Temple, Down→Cave; Cave Down→Entrance to Hades; Entrance to Hades
  Up→Cave, S→Land of the Dead (only once the spirits are banished); Land of the
  Dead N→Entrance to Hades.
- **The Round Room→Engravings Cave crossing is host-wired.** The Round Room's
  southeast passage (left absent "for its region" in Phase 10.4) crosses the
  `ZorkRoundRoom`/`ZorkTemple` boundary, so the host owns it — the same seam as
  the dam's Deep Canyon edges.
- **The cave→altar climb is a slice-only convenience.** Canonically the Cave
  (TINY-CAVE) leads *onward* — north and west into the mirror region — with no
  way back up to the altar; the temple complex reconnects to the rest of the map
  only through that mirror region. The mirror region is a later phase (T7), so
  without a temporary `cave.up(altar)` a player who descended the one-way rope
  and went down past the altar would be stranded. This extra exit stands in until
  T7 wires the canonical onward path, at which point it is removed/reconciled.
  The Cave's canonical north/west openings are absent for the same "await their
  region" reason. **Reconciled in Phase 10.7:** the mirror region has landed, so
  the temporary `cave.up(altar)` exit is removed — the altar-crack drop is once
  again strictly one-way, and the Cave's canonical north (Mirror Room 2) and west
  (Winding Passage) openings are host-wired, reconnecting the temple complex to
  the rest of the map through the mirror rooms. See the Phase 10.7 entry below.

### Mechanics simplified or deferred

- **`.openFlame` is minted here, read by no one yet.** The trait (a
  `TraitKey<Bool>`, like `.waterSource`) marks the torch, the lit candles, and a
  struck match as naked flames; the Gas Room (T8) will read it to tell a safe
  light from one that ignites the air. Nothing in this task depends on it.
- **The ivory torch is a lit `lightSource` that refuses `.turnOff`** — the
  documented "no always-burning trait" idiom — rather than a bespoke
  ever-burning item.
- **The red-hot bell reads as red hot** *(closed in the fidelity pass — the examine
  text was previously static)*. Ringing sets the `bellHot` `@Global` flag; while it
  is set the bell's examine text glows red (`bell.describe` → `redHotBell`, the
  original's distinct red-hot bell), and the take-refusal reads the same flag. The
  heat is still modeled as a flag rather than a separate red-hot-bell entity — the
  swap adds no behavior the flag doesn't already carry. The bell cools after a fixed
  20 turns — a **deliberate anti-softlock kept on purpose** (the original can leave
  the bell permanently hot and unusable); the cool is a plain fuse.
- **The exorcism is a small stage machine with a three-turn window.** Ringing the
  bell at the gate freezes the spirits (stage 1) and arms a 3-turn `exorcismLapse`
  fuse; lighting the candles renews the window and reaches stage 2; reading the
  book at stage 2 banishes the spirits and opens the way south. Letting the
  window lapse resets the sequence. This reproduces the original's timed ritual
  without modeling its exact per-object interrupt bookkeeping.
- **The candles use a two-fuse burn economy** (dim warning, then out for good),
  banked while unlit, versus the lantern's three fuses — the candles are a
  shorter-lived light and don't warrant the extra last-gasp stage. The cave's
  draught snuffs them (banking their fuel), which is why the ritual's candles must
  be lit at the gate below the draught, not carried down alight.
- **Matches are finite and the burning match is a real, short-lived item.**
  Striking a match (host-wired: the matchbook is a `ZorkDam` item, the burning
  match a `ZorkTemple` one) decrements a count of 5, moves the burning match into
  the player's hand (E5 `moveToPlayer()`), and arms a 2-turn fuse that vanishes
  it. The matchbook parses as "matches"/"matchbook"; singular "match" is not a
  recognized noun (it collides with the burning match), so the strike command is
  "light matches".
- **The coffin's load block is coffin-specific (closed in the fidelity pass).**
  The gold coffin (too big to squeeze down to Hades) is stopped at the altar's
  downward crack — the original's `COFFIN-CURE` — forcing the player to carry it
  out by praying. The altar's `before(.go)` now refuses the descent only while
  the coffin is in hand (`!coffin.isHeld`); any other load, however heavy,
  squeezes through, where the earlier `carried weight ≤ 50` cap would also have
  blocked a hypothetical 50+ non-coffin load. On realistic loads the two are
  identical (nothing else near the altar approaches 50), so no pinned transcript
  moved.
- **Praying at the altar is host-wired** (it teleports the player, and whatever
  they hold, to `ZorkAboveGround`'s forest — the same room the resurrection
  uses), because the altar is a temple room but the destination is another
  bundle's. It is the coffin's only egress from the temple complex.

### Scoring

- **Four new treasures carry the original's numbers and join the host roster**:
  ivory torch (find 14 / case 6), gold coffin (10 / 15), sceptre (4 / 6), and
  crystal skull (10 / 10). All are added to `scoring.treasures`, paying out in
  the living-room trophy case like the rest. The sceptre starts inside the
  coffin.

## Phase 10.7 — Mirror rooms & the Atlantis chain (`Sources/Zork1/Regions/Mirror.swift`)

The connective tissue of the underground: the two Mirror Rooms and the tangle of
passages — Narrow, Winding, Cold, Twisting — that thread them to the Round Room
hub, the drowned Atlantis Room and the reservoir beyond, and a one-way slide down
to the Cellar. With this region in, the whole underground is a single connected
graph.

### Prose

- **All room, item, and message prose is now the original Zork I text**, same policy
  and one-constant-per-entity structure as every prior task (`Prose+Mirror.swift`).
  Room and item *names* ("Mirror Room", "Atlantis Room", "Slide Room", "crystal
  trident") are the iconic ones, used as-is. The two Mirror Rooms share the name
  "Mirror Room", and the Small Cave shares "Cave" with the temple's Tiny Cave —
  duplicate room names are fine (the game's own "Forest" and "Cave" rooms do the
  same).

### Map topology

- **The exit table is the canonical Zork 1 layout** (verified against the original
  `1dungeon.zil`): Narrow Passage N→Round Room, S↔Mirror Room (north); Mirror Room
  (north) N↔Narrow Passage, W↔Winding Passage, E↔Tiny Cave; Winding Passage
  N↔Mirror Room (north), E↔Tiny Cave; Mirror Room (south) N↔Cold Passage,
  W↔Twisting Passage, E↔Small Cave; Cold Passage S↔Mirror Room (south), W↔Slide
  Room; Twisting Passage N↔Mirror Room (south), E↔Small Cave; Small Cave
  N↔Mirror Room (south), W↔Twisting Passage, Down/S→Atlantis (both openings lead
  there); Atlantis Room Up↔Small Cave, S→Reservoir North; Slide Room E↔Cold
  Passage, Down→Cellar.
- **The three cross-region seams are host-wired** in `Zork1.swift`, the same way
  every prior region's onward edges are: the Round Room hub's south to the Narrow
  Passage (absent since Phase 10.4), the Atlantis Room's south to Reservoir North
  (absent since Phase 10.5), and the Tiny Cave's north/west into the mirror rooms
  (the Phase 10.6 reconciliation — the temporary `cave.up(altar)` is removed and
  the temple complex now reconnects through here).
- **The slide is one-way.** The steep metal slide drops from the Slide Room into
  the Cellar with no way back up it — so there is no matching `cellar.up` to the
  Slide Room (as with the studio chimney). The Slide Room's canonical north
  opening onto the coal-mine entrance awaits its region (T8) and is simply absent.
- **The northern Mirror Room is naturally lit, the southern one is dark.** The
  original flags `MIRROR-ROOM-2` (the hub side) with `ONBIT` and leaves
  `MIRROR-ROOM-1` dark; that lighting is game data and is reproduced as-is, so the
  northern room's mirror can be found and touched without a lamp.

### The mirror teleport

- **Touching a mirror moves the player to the other Mirror Room** — the only
  passage between the map's two halves. This is a draw-free, deterministic
  teleport (`before(.touch)` on each mirror: narrate the rumble, set
  `player.location`, describe). **The floor swap and the breakable mirror are now
  modeled (closed in the fidelity pass):** passing through swaps whatever *loose*
  (takeable) items lie on the two rooms' floors — the fixtures, including the
  mirrors, stay put — via the new engine accessors `Location.contents` and
  `Item.isTakable`; and attacking either mirror smashes both (they are two faces
  of one passage), setting a `mirrorBroken` `@Global` (the original's
  `MIRROR-MUNG`) that kills the teleport for good — a touch on the shards falls
  through to the plain reply. One nuance left as-is: held items still ride along
  with the player (as the original), and the "seven years' bad luck" is narrated,
  not mechanized.

### Scoring

- **The crystal trident carries the original's numbers** (weight/`SIZE` 20, find
  4, case 11) and joins the host `scoring.treasures` roster, paying out in the
  living-room trophy case like the rest.

## Phase 10.8 — Coal mine & diamond (`Sources/Zork1/Regions/CoalMine.swift`)

The dead coal mine reached north from the Slide Room: the Mine Entrance and the
bat that guards the way in, the Shaft Room with its basket on a chain, the coal
gas that makes any naked flame fatal, the four-room coal maze, and — through a
crack too narrow to pass carrying anything — the Drafty Room and the Machine
Room, where coal fed to the machine and its switch thrown becomes a diamond. Two
treasures lie in the open (the jade figurine and the sapphire bracelet); the
third, the huge diamond, has to be made.

### Prose

- **All room, item, and message prose is now the original Zork I text**, same policy
  and one-constant-per-entity structure as every prior task (`Prose+CoalMine.swift`).
  Room and item *names* ("Coal Mine", "Gas Room", "Machine Room", "huge diamond",
  "jade figurine", "sapphire-encrusted bracelet") are the iconic ones, used as-is.
  The four maze rooms all share the name "Coal Mine", as the original's do.

### Map topology

- **The exit table is the canonical Zork 1 layout** (verified against the original
  `1dungeon.zil`): Mine Entrance W→Squeaky Room; Squeaky Room N→Bat Room, E→Mine
  Entrance; Bat Room S→Squeaky Room, E→Shaft Room; Shaft Room Down→blocked, W→Bat
  Room, N→Smelly Room; Smelly Room Down→Gas Room, S→Shaft Room; Gas Room Up→Smelly
  Room, E→Coal Mine 1; the maze — Mine 1 N→Gas Room, E→self, NE→Mine 2; Mine 2
  N→self, S→Mine 1, SE→Mine 3; Mine 3 S→self, SW→Mine 4, E→Mine 2; Mine 4 N→Mine
  3, W→self, Down→Ladder Top; Ladder Top Down→Ladder Bottom, Up→Mine 4; Ladder
  Bottom S→Dead End, W→Timber Room, Up→Ladder Top; Dead End N→Ladder Bottom;
  Timber Room E→Ladder Bottom, W→Drafty Room (empty-handed only); Drafty Room
  S→Machine Room, E→Timber Room (empty-handed only); Machine Room N→Drafty Room.
  The self-loops and the four "wrong" maze exits are the original's and are kept.
- **The Slide Room's north opening onto the Mine Entrance is host-wired** in
  `Zork1.swift` (it crosses from `ZorkMirror`), closing the seam Phase 10.7 left
  absent. This is the only way in — the mine has no other connection to the map.
- **The canonical IN and OUT aliases fold into WEST and EAST.** The Mine Entrance's
  `IN` (to the Squeaky Room) and the Drafty Room's `OUT` (to the Timber Room) are
  duplicate exits to the same rooms its `WEST`/`EAST` already reach, so only the
  cardinal exits are wired.

### Mechanics simplified or deferred

- **The vampire bat reads *held* garlic, not garlic in the room.** Entering the Bat
  Room without the garlic clove (a `ZorkHouse` item) in hand gets you seized and
  carried to a random one of eight mine rooms; hold the garlic and the bat keeps
  off. The check is host-wired (the bat is a mine fixture, the garlic a house item),
  and the garlic guard comes *before* the random draw, so an armed descent never
  touches the random stream — this is the region's one source of randomness. The
  original also accepts garlic simply dropped in the room; here it must be carried.
- **The Gas Room reads the `.openFlame` trait** (minted in Phase 10.6, unread until
  now). At the end of any turn spent there with a lit open flame in hand — the ivory
  torch, the lit candles, or a struck match, carried in or lit on the spot — the air
  goes up and the player dies (`afterEachTurn` → `die`). The electric lantern carries
  no flame and is safe, exactly as in the original.
- **The basket is modeled as the original's two objects.** The real container (open,
  transparent, `capacity` 50) and a stand-in trade rooms when the chain is worked, so
  "raise basket" and "lower basket" always name a basket in the Shaft Room however the
  chain hangs, and never two at once. It is worked only from the Shaft Room, can't be
  taken, and a lit torch left in it lights whichever room it hangs in (the engine's
  `lightReaches` walks through the open container) — which is how the Drafty Room, past
  the empty-handed crack, is lit for the machine work.
- **The machine transmutes coal, and destroys everything else (closed in the
  fidelity pass).** Feeding it coal, shutting the lid, and throwing the switch with
  the screwdriver (a `ZorkDam` tool — the rule is host-wired, like the dam bolt) makes
  a huge diamond. Throwing the switch on a closed machine holding **non-coal** contents
  now grinds them to a worthless slag and loses them (the original's non-coal
  destruction, earlier a no-op); an empty machine still simply whirs to no effect. One
  detail unchanged: when coal *and* other things share the machine, the coal path runs
  and the non-coal contents survive (the diamond forms; the extras are not swept up).

### Scoring

- **The Drafty Room pays 13 on first arrival** (the original's room `VALUE`),
  host-wired via `scoring.visit` alongside the kitchen, cellar, and East-West Passage.
- **Three treasures carry the original's numbers and join the host roster**: the jade
  figurine (find 5 / case 5), the sapphire-encrusted bracelet (5 / 5), and the huge
  diamond (10 / 10). All pay out in the living-room trophy case. The coal itself is not
  a treasure — it carries the original's `SIZE` 20 as its weight and is consumed by the
  machine.

## Phase 10.9 — Frigid River, rainbow & canyon (`Sources/Zork1/Regions/River.swift`)

The river run below Flood Control Dam #3: the inflatable boat that makes it passable, the
current that carries it down five stretches, the White Cliffs on the west bank, the sandy
east bank with its buried scarab, Aragain Falls, and the rainbow the sceptre wakes. Exit
tables and item data were verified against `1dungeon.zil` / `1actions.zil`
(`historicalsource/zork1`).

### Prose

- **All room, item, and message prose is now the original Zork I text.** Iconic *names*
  (Frigid River, White Cliffs Beach, Sandy Cave, Aragain Falls, On the Rainbow, End of
  Rainbow, magic boat, red buoy, pile of plastic) were always used as-is; the descriptive
  bodies now carry the original Zork I text too.
- **The tan label ships** *(closed by #203, which the claim above predated)*. `BOAT-LABEL`
  (`1dungeon.zil:941`) and the second line `IBOAT-FUNCTION` prints on a successful inflate
  (`1actions.zil:2820`) are both here. **The one departure is typographic:** the original's
  fine print is a single hard-wrapped block, and this reflows it, so each instruction and
  each line of the closing warning stands as its own paragraph.

### Map topology

- **The canyon is two-way, and that is canonical** — see the corrected note in the Phase 8
  "Map topology" section above. The rainbow is an *additional* crossing of the falls (End
  of Rainbow ↔ On the Rainbow ↔ Aragain Falls, walkable only while solid), not a
  replacement for the canyon climb. This reverses the (mistaken) plan direction to "restore
  a one-way canyon"; there was never a one-way canyon to restore.
- **The White Cliffs' foot-paths (N↔S and the west passage into the Damp Cave) are gated
  on being on foot** — `player.vehicle == nil` — where the original gates on the boat being
  *deflated*. So a player who lands and merely steps out of the (still-inflated) boat can
  walk the cliffs here, whereas the original would make them deflate it first. The Damp
  Cave seam (a `ZorkRoundRoom` room) is host-wired.
- **The boat launches only from the river proper** — Dam Base, the two White Cliffs
  beaches, Sandy Beach, and the Shore, each onto its canonical stretch. The original also
  lets the boat be launched on the drained reservoir and the stream; that reservoir/stream
  boating is not modeled (the boat is treated as a river-region tool). The stream's
  boat-only `LAND` disembark, deferred from Phase 10.5, remains unmodeled for the same
  reason.

### Mechanics simplified or deferred

- **The current is a continuous per-turn interrupt** *(closed in the fidelity pass — was a
  self-rearming fuse)*. A `riverCurrent` daemon runs every turn the player is afloat,
  counting the stretch's canonical dwell down (River-1/2: 4 turns, River-3: 3, River-4: 2,
  River-5: 1) in the `riverDwell` global; at zero it moves the boat — and its passenger and
  cargo — one stretch down and reloads the next dwell. A stretch entered by paddling is
  reloaded during the command, so the daemon decrements it that same turn (reload at
  **dwell + 1**); a stretch reached by drifting reloads at **dwell** on the drift path, so
  the player nets exactly the canonical number of turns on each stretch either way. The
  daemon sorts before the thief's, draws no RNG, and moves the boat on the same turns the
  old fuse did, so every pinned river transcript is byte-identical. Drifting off River-5
  goes over Aragain Falls (fatal); `up` is always refused ("strong currents"). Draw-free —
  the schedule is fixed data.
- **"Sharp" is a six-item trait, not a general edge test.** A new `TraitKey<Bool>.sharp`
  marks exactly the items the original enumerates as boat-punishers — the sword, the nasty
  knife, and the sceptre today; the rusty knife, the thief's stiletto (Phase 10.11), and the
  troll's bloody axe (the fidelity pass) carry it too. Boarding the boat carrying one, or
  stowing one in it, bursts it (fatal if afloat, a mere wreck ashore). **Repair is now
  modeled (closed in the fidelity pass):** `fix boat with gunk` seals the wreck with the
  dam's tube (host-wired, tube↔boat spanning two bundles), spending the tube and trading the
  punctured boat back for the seaworthy one. Since a puncture afloat is always fatal, the
  wreck is only ever patched ashore.
- **The boat's two valves grade their refusals as the original does** *(closed by #197 — the
  deflate ground check had been dropped and inflate asked its questions out of order)*. Both
  gate on the boat lying directly in the room (`<NOT <IN? … ,HERE>>`), and inflate asks that
  before it looks at the tool. **One syntactic addition:** the original's only INFLATE syntax
  is `INFLAT OBJECT WITH OBJECT`, its lung-power line reached through `BLOW IN` / `BREATHE`;
  this port also accepts a bare `inflate <thing>` and answers it with that same line.
- **Digging the Sandy Cave**: three digs with the shovel bare the scarab, a fourth collapses
  the hole and buries the player — the original's `BEACH-DIG` counter, used as-is. Bare
  hands do nothing.
- **The buoy is an openable container**; opening it exposes the large emerald, which scores
  on the take (the original scores it the moment the buoy is opened — the difference is one
  `take` command and never observable in the score line).
- **The rainbow keeps its middle room** (On the Rainbow); waving the sceptre while standing
  on it drops the player into the falls, exactly as the original. Waving it at either end
  turns the rainbow solid and reveals the pot of gold at the End of Rainbow; waving again
  reverts it (the pot, once revealed, stays).

### Scoring

- **Three treasures carry the original's numbers and join the host roster**: the large
  emerald (find 5 / case 10, inside the buoy), the jewelled scarab (5 / 5, dug from the
  sand), and the pot of gold (10 / 10, at the rainbow's end). All pay out in the trophy
  case. The buoy, boat, shovel, and pump are tools, not treasures. T9 adds no new
  event-visit awards.

## Phase 10.10 — Maze, Cyclops & grating (`Sources/Zork1/Regions/Maze.swift`)

The great maze west of the Troll Room: fifteen twisting passages and four dead ends, the
skeleton's cache in Maze-5 (the skeleton key, at last, plus the bag of coins and the rusty
knife), the grating up into the forest Clearing, and the Cyclops Room with its stair up to
the Treasure Room and the Strange Passage home. Exit tables and item data were verified
against `1dungeon.zil` / `1actions.zil` (`historicalsource/zork1`).

### Prose

- **All room, item, and message prose is now the original Zork I text.** Iconic *names* (Maze,
  Dead End, Grating Room, Cyclops Room, Treasure Room, Strange Passage, cyclops, skeleton
  key, bag of coins, rusty knife) were always used as-is; the descriptive bodies now carry
  the original Zork I text too. Every maze passage deliberately shares one name and
  one description — the sameness is the puzzle.

### Map topology

- **The maze's exit graph is reproduced verbatim from `1dungeon.zil`**, including its
  one-way `PER MAZE-DIODES` drops (Maze-2→Maze-4, Maze-7→Dead-End-1, Maze-9→Maze-11,
  Maze-12→Maze-5, all `down`) and its self-loops (Maze-1 `north`, Maze-6 `west`, Maze-8
  `west`, Maze-9 `northwest`, Maze-14 `northwest`, each returning to itself).
- **The maze entrance is one-way.** The Troll Room's west passage (host-wired, gated on
  `trollDefeated`) drops into Maze-1, which — as in the original — has no exit back to the
  Troll Room. Deleting the old collapsed-rubble stub in `ZorkCellar` was part of this task.
- **The grating is a real two-way door** between the Grating Room and the above-ground
  Clearing (host-wired `via:` the grating item, a `ZorkAboveGround` entity). Because the
  engine only folds a door into scope where it is perceivable and the grating starts hidden
  (revealed topside by clearing the leaves), entering the Grating Room reveals it from below
  so it can be unlocked with the skeleton key. Opening it from below showers the forest's
  leaves down and lights the room — the original's `GRATE-REVEALED` / leaf-drop, folded into
  one open.
- **The Strange Passage east to the Living Room is host-wired**, gated on the cyclops having
  smashed the east wall (the original's `MAGIC-FLAG`); until then the Living Room's west door
  is "nailed shut."

### Mechanics simplified or deferred

- **The cyclops's wrath is modeled (closed in the fidelity pass).** Steel still can't beat
  him — `attack` is a canned shrug — but the attempt, like giving him the lunch that leaves
  him desperate for a drink, now *rouses* his hunger, and from there the original's
  `CYCLOWRATH` / `I-CYCLOPS` timer climbs one rung of the verbatim `cyclomad` ladder each turn
  you stay, eating you on the seventh (`cyclopsRoom.afterEachTurn`, a deterministic `@Global`
  counter — the escalation and eat-you lines are Infocom's). Both original outs still call him
  off (each sets `cyclopsSubdued`): feed him to sleep (give the lunch, then the open water
  bottle) or shout `odysseus`/`ulysses` (he flees through the east wall). One faithful nuance
  restored: the timer arms **only when provoked** (attacked, or fed the lunch) — mere loitering
  never wakes it, exactly as the original enables `I-CYCLOPS`. Feeding never opens the east
  wall; only the rout does. **Wake-on-attack is now modeled (closed in the fidelity pass):**
  striking the fed, sleeping cyclops rouses him — his `cyclopsSubdued` calm breaks, the stair
  he guards closes again, and the wrath he'd banked resumes climbing (a cyclops routed by
  `odysseus` has vanished, so this only ever fires on the sleeper). Examining him now reads his
  state too — fast asleep once drugged, an ordinary hungry giant otherwise. One accepted
  divergence remains: the original's separate eyeing/gasping *room-look* variants (the
  cyclops's state folded into the room description) aren't reproduced — the slice shows his
  presence through the actor's own line, and the mood paragraphs would double with it.
- **The skeleton's disturb-curse is modeled (closed in the fidelity pass).** Disturbing the
  bones — `take`, `search` (`.lookIn`), or `move` (`.push`) — now wakes the ghost, who banishes
  your carried valuables to the Land of the Dead and mutters off, exactly as the curse prose
  (`Prose.skeletonLeaveItBe`, unchanged) has always described. Host-wired, since the
  destination is a `ZorkTemple` room (`temple.landOfDead`); the scatter mirrors `onDeath()`.
  Two divergences: **the lamp is spared** (a deliberate anti-softlock, exactly as the death
  scatter spares it, so light is never lost to the curse — the original banishes everything),
  and the slice's single `landOfDead` room (whose description is already the canonical Land of
  the Living Dead text) stands in for the original's separate LAND-OF-LIVING-DEAD. The
  burned-out lantern is present as takeable junk.
- **The Treasure Room and Strange Passage geography is built, but the thief, his hoard, the
  silver chalice, and the Treasure Room's +25 visit award arrive in Phase 10.11.**

### Scoring

- **One treasure carries the original's numbers and joins the host roster**: the leather bag
  of coins (find 10 / case 5, in Maze-5's cache), paying out in the trophy case. The
  skeleton key and rusty knife are tools, not treasures. Phase 10.10 adds no new event-visit
  award (the Treasure Room's +25 is deferred to 10.11).

## Phase 10.11 — Thief endgame (`Sources/Zork1/Thief.swift`)

The reduced Phase-8 cutpurse is promoted to the canonical endgame antagonist. The thief's
actor, his stiletto, and the `thiefDefeated` flag move out of `ZorkCellar` into a dedicated
`ZorkThief` bundle; because every one of his behaviours reaches across bundles (the blades
that fell him, the treasures he covets, his lair in the maze, the trap door he bars), all of
his roaming, stealing, stashing, lair defence, egg service, and death stay host-wired in
`Zork1.swift`. Item values and turn counts verified against `1dungeon.zil` / `1actions.zil`.

### Prose

- **All new prose is now the original Zork I text.** Iconic *names* (thief, stiletto, silver
  chalice, clockwork canary) were always used as-is; descriptions now carry the original
  Zork I text too.

### Mechanics — now modeled

- **The thief roams the whole underground.** His roam set is every room below the trap door,
  excluding only his own lair (the Treasure Room — he is *summoned* there to defend it rather
  than wandering in) and the Land of the Dead. As in earlier phases the roam is a teleport
  within the set (no exit-graph awareness), and the daemon guards before it draws, so quiet
  turns burn no randomness.
- **He lifts any treasure within reach** *(closed in the fidelity pass — was held-only)*. From
  the full host roster, the thief's steal daemon takes a treasure from wherever it lies in the
  room he shares with you: held in your hands, on the floor, or inside an open container he can
  rifle (the trophy case is wired in as one). Only a shut container or another room keeps a
  treasure safe — the original's thief, who lifts nearly anything from nearly anywhere.
- **He ferries his takings to the hoard.** A draw-free `thiefStash` daemon deposits everything
  he carries (bar the stiletto) onto the Treasure Room floor whenever he is in the lair.
- **He defends his lair to the death.** Entering the Treasure Room summons him home, and a
  `melee.aggression(…, while: { thief.isIn(treasureRoom) })` daemon lets him fight back
  *only there* — evasive everywhere else. He carries the stiletto (the sixth `.sharp`
  boat-puncturer; the original's SIZE 10) and, killed, drops his whole hoard plus the
  stiletto and unbars the trap door.
- **The silver chalice** (find 10 / case 5) sits in the Treasure Room and is **snatchable**
  *(closed in the fidelity pass — was hard-refused while the thief lived)*. There is no take
  guard: you can grab it straight from the hoard (the original's snatch), but because the
  thief now lifts treasures back from your hands and off the floor, holding it while he lives
  is only a loan — his steal daemon takes it back on a later turn, the original's
  snatch-and-resteal.
- **Give the egg to the thief and he opens it cleanly.** A four-turn `thiefOpensEgg` fuse sets
  the egg open with the clockwork canary intact; you recover the opened egg among his effects
  when he dies. The service is silent (you aren't watching) and is cancelled if he dies first.
- **The jewel-encrusted egg is now an openable container.** Forcing it open *by hand* (the
  built-in `open`) wrecks the canary — the intact `golden clockwork canary` is swapped for a
  worthless `broken clockwork canary` and a `canaryRuined` flag is set. Only the thief's
  careful hands (above) open it without ruin.

### Mechanics still simplified or deferred

- **The thief has no `CYCLOWRATH`-style eat-you timer of his own**; he simply fights in his
  lair and is otherwise evasive. (The cyclops *does* now have his wrath timer — see the
  Phase-10.10 cyclops entry, closed in the fidelity pass.)
- **The canary's own scoring (find 6 / case 4) and the `wind canary` → brass bauble trick are
  deferred to Phase 10.12.** This phase introduces the canary item and its intact/ruined
  state only; the canary and bauble are *not* yet in the host `scoring.treasures` roster.

### Scoring

- **The silver chalice joins the host roster** (find 10 / case 5), bringing it to 17 of the
  eventual 19 treasures (canary and bauble land in 10.12).
- **The Treasure Room pays 25 on first entry** (`scoring.visit`), the last of the five event
  awards.

### Tests

- **Expanding the thief's roam set changed his teleport destinations, shifting the seeded RNG
  stream for every test where he can now wander into the player's room.** All affected
  seed-pinned Zork 1 transcripts were re-recorded once here (the roadmap's planned, one-time
  break). Phase 10.14 confirmed these seeds still hold under the frozen content and cleared the
  provisional `// re-pin expected in T14` markers — no seed values changed.

## Phase 10.12 — Canary, bauble & treasure glue (`Sources/Zork1/Zork1.swift`, `House.swift`)

The clockwork canary becomes a scored treasure, its brass bauble joins the world, and the
`wind canary` → songbird trick is wired — completing the nineteen-treasure roster. The canary
lives in `ZorkHouse` and the forest rooms in `ZorkAboveGround`, so the whole trick is
host-wired in `Zork1.swift` alongside the egg's force-open rule. Values and the qualifying
rooms verified against `1dungeon.zil` / `1actions.zil` (`CANARY-OBJECT`, `FOREST-ROOM?`).

### Prose

- **All new prose is now the original Zork I text.** Iconic *names* (clockwork canary, brass
  bauble, songbird) were always used as-is; descriptions now carry the original Zork I text too.

### Mechanics — now modeled

- **`wind canary` summons the songbird.** Wound out among the trees, the intact canary calls a
  songbird that drops the brass bauble — exactly once (`baubleDropped`). The qualifying rooms
  are the canonical `FOREST-ROOM?` set: the three Forest rooms, the Forest Path, and Up a Tree.
  Wound up in the tree, the bauble falls to the Forest Path below (canonical), so it never
  lands out of reach.
- **Anywhere else, or after the bird has come, the intact canary just chirps** a short tinny
  tune (one line, covering both the wrong-room and already-sung cases, as in the original).
- **The ruined bird only grinds.** Winding the `broken clockwork canary` produces a grinding of
  stripped gears — no song, no songbird, no bauble.

### Mechanics still simplified or deferred

- **The songbird is narration only** — there is no `songbird` actor, matching the plan's
  skipped songbird-ambience daemon. It exists solely as the flavor of the bauble's arrival.

### Scoring

- **The canary joins the host roster** (find 6 / case 4) and **the brass bauble** (find 1 /
  case 1), bringing it to the full **19 of 19** treasures. `maxScore` stays 350 (fixed in
  10.2). The roster is shared with the thief's steal list, so he now covets both — canonical.
- **The 350 is now checked rather than trusted.** The five event awards live in the
  `Scoring` award table (10 + 25 + 5 + 13 + 25 = 78) and the nineteen treasures carry
  143 points of `.takeValue` and 129 of `.depositValue`; the bootstrap sums all three
  and warns if the total misses `maxScore`. It comes to exactly 350, so the original's
  ceiling is genuinely reachable here and not merely asserted.
- **The ruined canary is worthless here.** The original grudgingly pays a single point
  (`TVALUE 1`) for casing the `broken clockwork canary`; here it carries no value and is not in
  the roster, so forcing the egg simply forfeits the canary's score. Keeping the broken bird
  out of the roster also avoids a twentieth entry that would muddy the "all nineteen cased"
  endgame check (Phase 10.13).

### Tests

- **The ruined-bird paths are pinned deterministically** (`Zork1BaubleTests`): forcing the egg
  above ground, then winding the broken canary (only grinds, no bauble), and casing it (scores
  nothing).
- **The full intact `wind canary` → bauble → case run is exercised by the Phase 10.14
  walkthrough** (`Zork1WalkthroughTests`). The intact canary is only recoverable by the thief's
  clean-open service; the walkthrough arms it in the lair (give egg, retreat one room while the
  four-turn fuse works, return and kill), recovers the opened egg with the canary whole, winds
  it in the forest for the bauble, and cases both — proving the whole chain end-to-end.

## Phase 10.13 — Endgame wiring: the Stone Barrow & the ancient map (`Sources/Zork1/Zork1.swift`, `AboveGround.swift`)

The game becomes winnable. Once all nineteen treasures rest in the trophy case, an ancient
map to the Stone Barrow appears among them; with the map revealed, the way southwest from
West of House opens onto the barrow, and stepping inside wins the game at 350. The map, the
trophy case, and the barrow span the `ZorkAboveGround`/`ZorkHouse` boundary, so the whole
endgame is host-wired in `Zork1.swift` beside the trophy-case and canary rules. The
southwest-to-barrow route is verified against `1dungeon.zil` (`WEST-OF-HOUSE` → `STONE-BARROW`)
and the reveal-on-completion trigger against `1actions.zil` (`SCORE-OBJ`/`WON-FLAG`).

### Prose

- **All new prose is now the original Zork I text.** Iconic *names* (Stone Barrow, ancient map)
  were always used as-is; the room description, the map, the "map appears" line, and the victory
  epilogue now carry the original Zork I text too.

### Mechanics — now modeled

- **All nineteen treasures cased reveals the map.** A trophy-case `after(.putIn)` rule fires
  when the deposited treasure completes the set (`treasureRoster.allSatisfy { case.holds($0) }`);
  it reveals the pre-placed `hidden` ancient map and announces its arrival. The map stays
  hidden inside the (transparent) case until then, so it never shows in the case's contents nor
  is swept up by "take all from case."
- **The southwest path opens with the map.** `westOfHouse.southwest(stoneBarrow, when: { map.isRevealed })`
  — refused with a "no path southwest" message until the map appears.
- **The two-step barrow entry is modeled** *(closed in the fidelity pass — was "collapsed to
  one")*. Faithful to the original: you first reach the **Stone Barrow** and see its description
  (the open stone door in the east face), then go *west* or *in* to a second **Inside the
  Barrow** room that ends the game. The `insideBarrow.onEnter` rule says the epilogue, then calls
  `end(won: true)`; the engine skips that room's description (the throw precedes it) and appends
  the final score line. There is no engine "you have won" banner, so the epilogue carries the
  flourish. The `stoneBarrow → insideBarrow` legs (`west` and `in`) live in `ZorkAboveGround`'s
  map; the gated way *to* the barrow (southwest from West of House) stays host-wired.

### Mechanics still simplified or deferred

- **The ancient map is inert flavor.** It is readable and takeable but has no other use; the
  southwest exit gates on the map's *revealed* state, not on carrying or reading it.

### Scoring

- **`maxScore` stays 350** (fixed in 10.2). The map and barrow are not treasures — no value, and
  the map is absent from `treasureRoster`.
- **In-case accounting modeled** *(closed in the fidelity pass — was "award-once, never
  revoked")*. Like the original, Gnusto's Scoring plugin adds each treasure's case value while it
  sits in the case (keyed `deposit.<name>`) and subtracts it again on withdrawal, so the
  displayed score rises and falls as you rearrange the hoard. Take value is still paid once for
  good. Consequence: depositing a treasure, scoring it, then withdrawing it nets zero — you can
  no longer bank 350 by shuffling a single treasure in and out. The map requires all nineteen
  present *simultaneously* at a `putIn`; the endgame trigger reads live case contents, so it is
  unaffected by the deposit accounting.

### Tests

- **The southwest gate and the partial-hoard case are pinned deterministically, seedless**
  (`Zork1EndgameTests`, above ground and clear of the roaming thief): southwest from West of
  House is refused before the map appears; casing the jeweled egg alone reveals no map and
  leaves the path shut (proof the gate wants all nineteen, not any one deposit).
- **The full all-nineteen → map → barrow → 350 win is exercised by the Phase 10.14 walkthrough**
  (`Zork1WalkthroughTests`). Collecting nineteen treasures is a several-hundred-command run
  through the whole dungeon (thief- and light-economy sensitive); the walkthrough drives it to
  `end(won: true)` at exactly 350, asserting each region's score checkpoint, the light handoff,
  the map's appearance, the rank name, and the barrow epilogue.

## Phase 10.14 — Full 350 walkthrough, seed re-pin & docs sweep (`Tests/GnustoTests/Zork1WalkthroughTests.swift`)

The phase acceptance: one scripted playthrough wins *Zork I* at the full 350 points, all nineteen
treasures cased, and the suite's provisional seed markers are cleared. No game content changed.

### The walkthrough

- **The run is a ~340-command playthrough pinned to seed 32**, driven through the `play` harness
  like every other Zork transcript. It asserts each region's running-score checkpoint (75 → 350),
  the two in-run combats (troll and thief killed, no player death), the intact-canary recovery,
  the lantern→torch light handoff (the lantern is switched off for the permanent torch and never
  burns low), the ancient map's appearance, the rank of Master Adventurer, and the Stone
  Barrow epilogue. It runs in the default suite (~0.1 s).
- **The seed is found by brute-force scan, not chosen.** The only randomness is in the run's first
  ~50 commands (Phase A): the troll's death, the thief's roaming/stealing, and the thief's death in
  his lair. The thief is lethal on the very turn you enter the Treasure Room, so most seeds lose the
  run to his stiletto; a scan of seeds 0–599 finds 47 that survive both combats *and* let the egg
  service finish. Seed 32 is the lowest.
- **Once the thief falls, the run is fully deterministic** — every RNG source (troll, thief
  roam/steal/fight, the garlic-guarded coal-mine bat) is dead or guarded — so the entire
  treasure-collecting back half (Phase B) plays out identically for every winning seed. This is why
  the scan's Phase-A survivors and the full-win seeds are the same 47.

### Divergences the walkthrough works around (route shape, not fidelity gaps)

- **The egg is handed to the thief in his lair, not caught mid-roam.** A Gallery hand-off (the
  original's natural spot) is impractical against a whole-underground roamer — he leaves within a
  turn or two of the game's start. The walkthrough instead gives the egg on a first lair visit,
  retreats one room while the four-turn open fuse runs (his aggression is gated to the Treasure
  Room, so the wait is safe), and returns to kill him and recover the opened egg. Same canonical
  outcome (thief opens the egg, canary intact), reached by a route the roamer allows.
- **The pot of gold is fetched above ground, not from the boat.** The sceptre carries the `.sharp`
  trait (its point holes the inflatable boat — see Phase 10.9), so it can't ride the river. The
  walkthrough waves it at the End of Rainbow via the canyon first, which solidifies the rainbow
  permanently; the later river dive (emerald, scarab) then returns dry-shod across that same solid
  rainbow. Both treasures are collected; only the order is dictated by the sharp-sceptre rule.

### Seed re-pin

- **The provisional `// re-pin expected in T14` markers are cleared across the suite.** They were
  placed when the thief's expanded roam set forced a one-time transcript re-recording (Phase
  10.11); Phase 10.14 confirmed those seeds still hold under the now-frozen content, so the markers
  were removed and no seed values changed. The comments explaining *why* each seed is used remain.

## Fidelity pass — low-risk canonical closures (post-Phase 10)

A follow-up audit of this ledger for deferred divergences worth closing. Five low-risk,
additive mechanics were restored — each canonical behaviour a player would actually hit,
each touching no seed-pinned RNG stream (the new tests are additive; the whole suite stays
green, seeds unchanged). The costlier items landed in the two passes below: the cyclops
`CYCLOWRATH` timer and the skeleton disturb-curse (Tier 2), then the theft, determinism, and
structural divergences (Tier 3). The individual entries above are updated in place; the
closures:

- **`climb` verb** — `climb tree` reaches Up a Tree (`Systems.swift`, `AboveGround.swift`).
- **`diagnose` verb** — reports the death toll and resurrections remaining (`Zork1.swift`).
- **Machine non-coal destruction** — a closed machine with non-coal contents grinds them to
  a worthless slag (`Zork1.swift` machine rule, `Prose+CoalMine.swift`).
- **Troll's bloody axe** — drops to the Troll Room floor on defeat, lootable, `.weapon` and
  `.sharp` (`Cellar.swift` axe item, `Zork1.swift` `onDefeat`, `Prose+Cellar.swift`).
- **Boat repair** — `fix boat with gunk` patches the punctured boat with the dam's tube
  (`Zork1.swift` host-wired, `Prose+River.swift`).

## Fidelity pass — the underground's teeth (post-Phase 10)

A second closure pass restoring the two lethal mechanics the audit had shelved as Tier 2. Both
bind to paths no pinned transcript takes (no test attacks the cyclops or disturbs the
skeleton; the seed-32 walkthrough only *routs* the cyclops and never touches the bones), so
both are additive — the full suite stays green with no seed change. The exact `CYCLOPS-FCN` /
`CYCLOMAD` prose was transcribed from the MIT-licensed Zork I source (`1actions.zil`). The
individual Phase-10.10 entries above are updated in place; the closures:

- **Cyclops `CYCLOWRATH` wrath timer** — once provoked (attacked, or fed the lunch), his hunger
  climbs the verbatim `cyclomad` ladder one rung a turn and eats you on the seventh; feeding him
  the water or shouting `odysseus` calls him off. Fully `ZorkMaze`-local, deterministic, no RNG
  (`Maze.swift` `cyclopsRoom.afterEachTurn` + `cyclopsProvoked`/`cyclopsWrath`, `Prose+Maze.swift`,
  and the lunch arming in `Zork1.swift`'s host give-rule).
- **Skeleton disturb-curse** — taking, searching, or moving the bones banishes your carried
  valuables (lamp spared) to the Land of the Dead. Host-wired (`Zork1.swift` `maze.skeleton`
  rules → `temple.landOfDead`), reusing the existing curse prose.

## Fidelity pass — the deferred divergences reversed (Tier 3, post-Phase 10)

The final closure pass, reversing the divergences the earlier audit had ruled "won't fix."
Every remaining deferred item was restored to canon. Ten mechanics, in two groups.

The **RNG-free** group touches no seeded stream, so the suite stayed green with no re-pin:

- **Two-step Stone Barrow** — you reach the barrow, then step *west*/*in* to a second Inside
  the Barrow room that wins (`AboveGround.swift` `insideBarrow`, `Zork1.swift` `onEnter`).
- **In-case scoring** — deposit value is credited into the case and debited on withdrawal, so
  the score rises and falls (`GnustoScoring`'s reversible `cased` register).
- **Red-hot bell** — the bell's examine text glows red while `bellHot` (`Temple.swift`
  `bell.describe`); the 20-turn auto-cool anti-softlock is kept on purpose.
- **Continuous flood** — the Maintenance Room water climbs a body-part ladder one step a turn
  (ankles → neck → drown) instead of three fixed bands (`Dam.swift` `damFlood`).
- **Loud Room SACREDBIT + read-loop** — the platinum bar carries its own take-lock and every
  other command echoes the last word (`RoundRoom.swift`).
- **River current** — a continuous per-turn `riverCurrent` daemon carries the boat, not a
  self-rearming fuse; byte-identical to the old timing (`River.swift`).

The **RNG-touching** group deliberately re-accepts randomness — the reverse of the
determinism-for-seed-freedom trade — so each carried a scoped, one-time re-pin (the Phase
10.11 operation), done incrementally as each landed:

- **Full theft fidelity** — the thief lifts treasures from your hands, the floor, or an open
  container (the trophy case); the silver chalice is snatchable and he steals it back
  (`GnustoActors` `steals` widened, `Zork1.swift` chalice guard dropped). Re-pinned the two
  thief-route tests and rebuilt the `GnustoActors` theft unit test.
- **Per-weapon melee** — `.weaponStrength` slides the outcome cutpoints so the elvish sword
  outclasses the knife and stiletto; strength 2 is the old 30/70/85 table
  (`GnustoMeleeCombat`). Only the chalice-lair test re-pinned.
- **Dice grue** — after the guaranteed warning and a grace turn, each dark turn rolls
  `chance(lethality)` (`GnustoDangerousDark`, 50% in Zork 1). The first-turn warning is the
  kept anti-softlock. Re-pinned the dark-lingering tests.
- **Random death scatter** — belongings strew to random above-ground rooms; the lamp still
  returns to the Living Room (`Zork1.swift` `onDeath`, kept anti-softlock). Re-pinned the two
  scatter tests.

The 350-point seed-32 walkthrough is unaffected throughout: it never dies, never lingers in
the dark, and its troll/thief kills survive the new tables. Anti-softlock guards kept by
explicit decision: the grue's first-turn warning, the lamp sparing (scatter), and the bell's
auto-cool.

## Villains that block rather than swing (#237)

`I-FIGHT` (`1actions.zil:3810`) has a villain strike only when `FIGHTBIT` is already
set — the player has engaged him — or when his own `F-FIRST?` branch fires: `<PROB 33>`
for the troll (`:702`), `<PROB 20>` for the thief (`:2064`), and no branch at all for
the cyclops, who never starts one. `MeleeCombat.aggression` had none of this and rolled
every turn the player shared a room with a conscious villain. Both Dungeon and Zork 1
made the call, and both were far more lethal than the games they reconstruct.

The plugin now carries all three halves: a `strikesFirst` probability, an `engaged` set
in the combat ledger, and `FIGHTBIT`'s clearing rule — the bit drops when the two of
them stop sharing a room, so walking out ends a fight and walking back in asks the
question again. Two placements were read off the source rather than guessed, and both
went against the first draft:

- **A refused swing does not engage.** `HERO-BLOW` sets the bit before it resolves the
  blow, so a miss engages as thoroughly as a wound — but `V-ATTACK` (`gverbs.zil:176`)
  refuses three ways before it ever reaches `HERO-BLOW`, and those three are almost
  exactly the plugin's own. So waving something that isn't a weapon is not a provocation.
- **A shut host gate does not disengage.** `I-FIGHT` skips the engrossed thief's turn —
  the man admiring a gift you handed him — without clearing his bit. Ours clears
  engagement above the `while:` gate, on the room test alone, for the same reason.

**Zork 1 paid a much smaller toll**, because its routes already budget three
blows a villain where Dungeon's budget one: seven issues across four tests,
against Dungeon's 175. Its walkthrough moved from seed 32 to seed 0 and got
markedly easier to win in the process — 235 of seeds 0–599 now carry that exact
route, where 47 did before. Its own measurement, same method, seeds 0–40:
deaths within one turn 14/41 → 7/41, two turns 27/41 → 11/41, three turns
34/41 → 18/41, eight turns 41/41 → 35/41. Three tests that died to an
unprovoked troll now pick the fight they lose, for the reason Dungeon's did.

**The re-pin toll.** The strike-first roll is a new draw on the turns an unengaged
villain shares the player's room, and the troll gates the underground in both games, so
the stream moves for nearly every route below the trap door. 175 Dungeon tests went red.
The default `strikesFirst: 100` skips the draw entirely, which is what kept the plugin's
own fixtures and every non-Zork suite untouched.

Dungeon's constants moved as follows, each re-derived by brute-force scan against the
routes that use it, not renumbered: **11 → 18** (the descent, 150 uses; still "the troll
falls to the first blow"), **10 → 41** (the carousel), **12 → 14** (the shaft), **55 →
120** (the thief's lair), and the walkthrough's **2 → 52**, which `DungeonEndgameTests`
shares. Four tests kept pins of their own. The endgame quiz draws its three questions
from eight by rejection sampling, so both the questions and the draws they cost moved:
its answers were re-derived to *temple, nowhere, forest*.

Three claims changed rather than moved, and the comments say so instead of quietly
renumbering. Two seeds that used to buy "the troll's swings all miss" now buy a troll who
never swings at all. And `dyingToTheTrollCostsTenPointsAndYourHands` now picks the fight
it dies in: an unprovoked death was a one-in-twenty event after this change, and pinning a
seed for it would have been testing the rare path rather than the behaviour.

**One thing that looked free and is not.** A swing at something already dead is
`cantSeeAnySuchThing`, a `freeReply` that costs no turn and no draw — so budgeting a
spare blow per fight looked like a way to widen the walkthrough's acceptance set from one
seed in four hundred to eight, at no cost to the stream. It is not free in *transcript*
terms: `DungeonEndgameTests` builds its route from the walkthrough's, and three of the
tests riding it scan the whole transcript for exactly that line. The spares were reverted
and the narrow seed kept.

## Fidelity pass — the long tail (post-Phase 10)

A follow-up pass closing the last small divergences a player would actually hit. Each is
additive and touches no seeded stream — the full suite stays green with no re-pin (the
seed-32 walkthrough routs the cyclops rather than fighting him, never smashes a mirror, and
never carries the coffin down or climbs the chimney with an overload). The individual entries
above are updated in place; the closures, and two small reusable engine accessors that
unlocked them:

- **Two engine accessors** — `Location.contents` (the loose items on a room's floor, mirroring
  `Item.contents`) and `Item.isTakable` (a public read of "not scenery, not an actor"). Both
  are draw-free reads used by the mirror floor-swap.
- **Cyclops wake-on-attack** — striking the fed, sleeping cyclops rouses him: the stair recloses
  and his banked wrath resumes; examining him now reads asleep-vs-awake (`Maze.swift`
  `cyclops.before(.attack)`/`.before(.examine)`, `Prose+Maze.swift`). The room-look mood
  paragraphs stay deferred (they'd double with the actor's own presence line).
- **Breakable mirror + floor swap** — attacking either mirror smashes both and kills the
  teleport for good (`mirrorBroken`, the original's `MIRROR-MUNG`); passing through swaps the two
  rooms' loose floor items, fixtures left in place (`Mirror.swift`, `Prose+Mirror.swift`).
- **Coffin-specific altar block** — the crack refuses the descent only while the gold coffin is
  in hand, not by a generic weight cap (`Temple.swift` `altar.before(.go)`, the original's
  `COFFIN-CURE`).
- **Chimney "one item plus the lamp"** — the lamp rides free up the Studio chimney; more than one
  other thing is refused (`Zork1.swift` `cellar.studio.before(.go)`). Observationally identical
  to the old count while the lamp is carried for light.

Deliberately still deferred (documented, low value): the cyclops's eyeing/gasping room-look
variants; the mirror's "seven years' bad luck" as narration rather than a mechanic; held items
riding along through the mirror (as the original).

## The kitchen window (`Sources/Zork1/`, carried by an engine change)

Three closures rather than divergences, all of them `V-THROUGH`'s
(`gverbs.zil:1404`) and `KITCHEN-WINDOW-F`'s (`1actions.zil:246-266`). They
arrived with Dungeon's #233 fourth pass, because the same source lines were
frozen the same way in both games and repairing one and not the other is how a
fixed defect comes back.

- **`enter window` / `go through window` walk you through it.** The source routes
  `ENTER OBJECT`, `CLIMB WITH OBJECT` and `WALK IN/WITH/ON OBJECT` to one routine
  that walks a door and boards a vehicle, and this engine's `.board` now does the
  same for any door on an exit of the room you are standing in. Nothing is
  declared per game; the window was already the door on the exit. Previously
  `west` walked you in and `enter window` answered "You can't get into that."
- **Both room paragraphs branch on the window again.** `EAST-HOUSE`
  (`1actions.zil:22-28`) and `KITCHEN-FCN` (`:389-397`) end on *"…a small window
  which is open."* or *"…slightly ajar."*, and only the shut half had been
  reproduced — so Behind House and the Kitchen both called the window ajar while
  it stood open. Verbatim is a claim about a line, and a branched line has two
  halves.
- **`x window`'s "not enough to allow entry" stops at the point the source stops
  it.** `KITCHEN-WINDOW-F` prints that only while `KITCHEN-WINDOW-FLAG` is clear
  — until the player has opened or closed the window — and falls through to
  `V-EXAMINE`'s stock line afterwards. The flag is **approximated by the window's
  open state**, which differs from the source only in that closing the window
  again restores the "slightly ajar" answer where the source would keep the stock
  one. The state the sentence is a claim about is the open one, so this is the
  closer reading of the two.
- **`GameText.cantEnterThat` carries `V-THROUGH`'s last line here**: "You hit
  your head against the … as you attempt this feat." The stock text takes the
  thing's name for that reason.

## The stub floor (`Sources/Zork1/Prose+Stubs.swift`, #242, #325)

The other side of the defect Dungeon's fifth pass repaired, and filed at the time
for the reason the kitchen window states: a defect repaired on one side of a
shared source and left on the other comes back. Thirteen of the engine's 47 stub
verbs answered here in Zork I's voice and **thirty-four in Gnusto's**, in the
repository's flagship verbatim reproduction; `MeleeCombat()` was constructed bare,
so `attackFutile` — the most reachable stock line in the game — was the plugin's.

The floor is now `text.stubs`, not `action(…)` rows. That is the same mechanism
change Dungeon made and for the same reason: `DefaultActions.run` returns from an
action override *before* `requireReach`, so all thirteen rows had silently given
up the reach guard, the object's rendered name, its number agreement and the
`yourself`/`somebodyElse` guards.

**#325 is the second pass, and its subject is the frame rather than the voice.**
Ten of these lines asserted a place, an occupant or a state the line never read —
"Nobody here returns your greeting." with the troll in the room, "The cyclops isn't
sleeping." with the cyclops asleep, "You are already standing, I think." to a man
sitting in the magic boat. Four of the repairs *added* source text rather than
inventing any: `V-HELLO`'s three branches, `V-ALARM`'s actor branch, `V-LOWER`'s
`HACK-HACK` stem, and `V-TURN` under the `turn … with …` row that `gsyntax.zil:505`
sends there — so this game reproduces more of `gverbs.zil` after the pass than
before it, not less. The three remaining are inventions moved off the room; they
are in the *Inventions* group below.

**Twenty-seven lines are `gverbs.zil`'s as written**, each cited at its
assignment: `V-SQUEEZE`, `V-ATTACK`, `V-MUNG`, `V-BURN`, `V-CUT`, `V-MOVE`,
`V-TURN`, `V-SHAKE`, `V-KNOCK`, `V-EAT`, `V-KISS`, `V-GIVE`, `V-YELL`, `V-SWIM`,
`V-STAND`, `V-FILL`, `V-POUR-ON`, `V-TIE`, `V-UNTIE`, `V-PRAY`, `V-CURSES`,
`V-ADVENT`, `V-COUNT`, `V-WISH`, `V-BLAST`, `V-SMELL`, `V-LISTEN`. **The
narrator's first person is kept** — "I'd sooner kiss a pig.", "I've known strange
people, but fighting a X?", "I don't think that the X would agree with you."
Dungeon converted these to the second person because an adaptation may; this game
may not, and `Prose.drinkWater` has kept the source's "I" since Task 8.

### Departures — the source has a line, and it renders differently

- **`V-SKIP` and `HACK-HACK` draw, and a `GameText` line cannot.** `jump` is one
  of four (`WHEEEEE`, `gverbs.zil:1272`) and `touch`/`wave` one of three
  (`HO-HUM`, `:2031`). A stock line has no turn frame and so no access to the
  seeded stream, and the only two ways to reach it — a rule or an `action(…)` row
  — are the mechanism this floor exists to stop using. Each takes one entry:
  `jump` the one its table is named for, `touch` and `wave` the third of three.
- **`dig` loses its instrument.** `V-DIG` (`:416`) answers about the tool and
  defaults it to `HANDS`; the engine hands the line no instrument, so the hands
  are written into the sentence.
- **`knock` keeps both branches, and loses one article.** `V-KNOCK` (`:765`)
  answers "Nobody's home." at a `DOORBIT` object and "Why knock on a X?" at
  anything else. Both are reproduced (#247) — the split is a game-wide rule,
  since a stub line cannot see doorness. What departs is the article: the source
  writes `"Why knock on a " D ,PRSO "?"`, and every named stub line in the engine
  is handed the *definite* phrase, uniformly. So this game says "Why knock on the
  small mailbox?". Widening the engine for one game's article would put `knock`
  out of step with the other thirty-four named stub lines, which is a worse
  trade than one word.
- **`give` answers with the actor branch throughout.** `V-GIVE` (`:714`) has a
  non-actor branch and the engine's line cannot tell the two apart, so a mailbox
  refuses politely where the source would say "You can't give a X to a Y!"
- **`MeleeCombat.notAWeapon` names one of two.** `V-ATTACK:188` names both target
  and weapon; the plugin hands the line only the weapon, so the target is "it".
  `noWeapon` was widened by this change and does name its target.
- **`bare climb`, `smell`, `listen`, `wave` and `wake` have no source verb.**
  Zork I's `SMELL`, `LISTEN` and `WAVE` always take an object
  (`gsyntax.zil:439`, `:291`, `:544`), and the objectless rows the engine parses
  have nothing to reproduce. `smell` and `climb` keep the sentences this game
  gave both halves before the split, so nothing a player had already read changed.

- **`raise`/`lower` take `HO-HUM`'s third, and `V-STAND` loses its vehicle
  branch.** `V-LOWER` (`:902`) is `HACK-HACK "Playing in this way with the "`,
  which draws one of three; `raise` calls it outright (`:1131`). These are rows
  on verbs this game owns rather than stub lines, so they could have drawn — but
  drawing would put them out of step with `jump`, `touch` and `wave`, which
  cannot, so all five take a fixed entry and this is the same third of three.
  `V-STAND` (`:1305`) is the harder one: aboard a vehicle the source performs
  `V?DISEMBARK` instead of speaking, and ``Player/vehicle`` is read-only from a
  rule, so `ZorkRiver`'s `world.before(.stand)` says where the player is sitting
  and names the word that gets him out. Both were flat claims about the room
  before #325 — "There's nothing here to lower." with the rope over the Dome Room
  rail, "You are already standing, I think." to a man adrift on the Frigid River.
- **`V-HELLO` keeps its three branches and loses its draw.** `hello` was a verb
  of this game's own until #325, answering "Nobody here returns your greeting."
  from a row that could not see the room the troll was standing in. It is the
  engine's ``Intent/greet`` now — `ZorkSystems` contributes only the two bare
  words the engine deliberately leaves to games — so the actor branch (`:727`)
  and the non-actor branch (`:731`) both reproduce, and the objectless branch's
  `PICK-ONE HELLOS` (`:2199`) takes two of its four entries rather than drawing.
  The non-actor branch's article departs exactly as `knock`'s does: the source
  writes `"to a " D ,PRSO`, and every named line in the engine is handed the
  definite phrase.
- **`V-ALARM`'s actor branch arrives, on one actor.** `wake` (`:157-166`) wakes a
  sleeping actor and tells an upright one he is wide awake; a stub line can see
  neither, so both its halves were false in front of the drugged cyclops. The
  branch is two rules over one helper (#325) — the cyclops's own for `wake
  cyclops` and his room's for bare `wake`, which names nobody and so reaches no
  item rule — and waking him costs what striking him costs. He is the only
  sleeper in the game. The floor keeps the non-actor branch, which is what a line
  can word.

### Inventions — Zork I has no such verb at all

Twelve of the engine's stubs appear nowhere in `gsyntax.zil`, so these lines are
**written, not reproduced**, and are recorded separately for that reason. They are
in the register — terse, dry, exclamatory, rude to the player where the source is
rude — but no ZIL routine stands behind them and none is cited at its assignment.

`sing`, `buy`, `sell`, `think`, `point`, `kneel`, `lie`, `sit`, `sleep`, `taste`,
`dive`, `empty` — plus `yourself`, for which no ZIL routine ever had to render the
player's name, and `throwAt`, whose `THROW AT` requires an actor
(`gsyntax.zil:486`) and drops the object rather than refusing.

**Five of them were about the room or its company, and #325 moved them off it.**
`buy` said "This is a dungeon, not a bazaar!" in the open field the game starts in.
Bare `climb` said "There's nothing here worth climbing. Try up or down." on the
Forest Path, whose own description is *one particularly large tree with some low
branches*, whose tree answers `climb tree` by putting you up it, and which is one of
the many rooms with neither of the exits the line recommends. `point` ("Nobody is
looking.") and `kneel` ("Nobody is impressed.") counted the room's occupants in
front of the troll, the thief and the cyclops — the greeting defect one verb over.
`dive` ("That would take more water than you have.") reads as a claim about the
water within reach, in a game with nine rooms that have water in them.

An invented line is free to be about the narrator or the player; it is not free to
survey a room it never read. The two rooms whose descriptions **are** about a smell
— the Smelly Room's *foul odor* and the Gas Room's *smells strongly of coal gas* —
answer bare `smell` for themselves for the same reason, in two more invented lines,
since the source has no room-scoped `V-SMELL` branch to reproduce.

**And a row that names its object has to write back the guards it skipped.**
`DefaultActions.run` answers `yourself` and `somebodyElse` before an `action(…)`
override is consulted, so widening `raise`/`lower` from a flat line to one that
names what it was aimed at made `raise me` answer "Playing in this way with
yourself has no effect." `ZorkSystems.refuseIfPerson(_:)` restores the two guards
the row was never given. This is the cost the floor's own header names, met head-on
rather than avoided: these are verbs the game owns, so the row is the right
mechanism and the guards are the game's to write.

### An older claim, corrected

`Sources/Zork1/Prose+Systems.swift` opened with *"These are the authentic Zork I
texts, reused under license"* while most of the verb constants beneath it were
modern inventions — `verbSmell` was "You smell nothing you could put a name to."
where `V-SMELL` is "It smells like a X.", and `verbDigFutile`, `verbTouch`,
`verbWave`, `verbGiveNoTaker`, `verbTieNothing` and `verbClimbNothing` were
likewise this repository's own. Provenance is now stated per constant rather than
per file: a reproduced line cites its ZIL routine and an invented one says
nothing, because it has nothing to cite.

### An engine change carried by this one

Six stub lines — `smell`, `listen`, `touch`, `wave`, `wake`, `climb` — and
`MeleeCombat.noWeapon` shipped as plain `String`s, so no game could say what they
were about. Four of the source's answers are jokes *about the thing named*, so the
verbatim rule could not be met without widening them; they now take an optional
name (`StubVerb.optionallyNamed`). Behavior-preserving for every other game: the
engine defaults keep their wording and ignore the name.

**Since #245** the same shape covers every stub line with an object to name —
eighteen, not six — behind a `GameText.Line` that takes a bare string as readily
as a naming closure, so widening one stopped being an API break. That made one
shortfall recorded above reachable, and **#247 took it**: `V-KNOCK`'s two
branches both answer now. `DOORBIT` is a fact about the thing knocked on and no
stub line can see one, so the split is a game-wide `world.before(.knock)` rule
reading ``Item/isDoor``, with the floor keeping the branch a line can word.

### Tests

#325 added `raiseAndLowerNameWhatTheyAreAimedAt` and
`bareClimbDoesNotSurveyARoomItNeverRead` (`Zork1SystemsTests`),
`helloReadsWhoIsInTheRoom` and `buyingDoesNotAnnounceWhereYouAreStanding`
(`Zork1ProseTests`), `wakingTheCyclopsReadsWhetherHeIsAsleep` (`Zork1MazeTests`),
`standReadsWhetherYouAreSittingInTheBoat` (`Zork1RiverTests`) and
`theTwoRoomsThatSmellSayWhatOfTheirOwnSmell` (`Zork1CoalMineTests`). Each asserts
**both** frames — the line where it is true and the different line where the flat
literal lied — and three of them assert the old sentence is gone.

`Tests/GnustoTests/Zork1ProseTests.swift`. The sweep,
`noEngineStubLineSurvivesInZork1`, is the twin of Dungeon's and derives its
completeness from `Mirror` over `GameText.StubReplies`, so a forty-eighth stub
cannot arrive unvoiced. The rest reach the player through the real pipeline —
including `theFloorKeepsTheReachGuardTheRowsGaveAway`, which is what the mechanism
change bought back. The seed-0 350-point walkthrough is unmoved: no stub verb
appears in its route.

## Dungeon (`Sources/Dungeon/`)

### The prose rule, stated before any region entry

**Dungeon is an adaptation, not a reproduction.** That is the sharpest difference
from every section above. `Sources/Zork1/` reproduces the original Zork I text
verbatim, one named constant at a time, under the MIT grant recorded in
`THIRD_PARTY_NOTICES`; that is what fidelity means there. Dungeon reproduces the
trilogy only where the trilogy fits the mainframe world, and writes its own prose
everywhere else. Swapping a trilogy line in unchecked is a defect here, however
much it looks like a fidelity fix.

The authority is `docs/games/dungeon-prose-comparison.md` ("The adopted policy —
Infocom voice, mainframe world"). Per line:

1. **`identical` (36) and `minor` (23)** — take the trilogy line verbatim. Same
   sentence, cleaner typography (the MDL doubles spaces after full stops),
   MIT-licensed, exactly as `Sources/Zork1/` already does.
2. **`substantial` (48)** — check the trilogy line against that room's exit table
   in `docs/games/dungeon-atlas.md` *first*. The trilogy usually rewrote the prose
   because it had rewritten the room, so its line can name exits this game does
   not have. Where it contradicts the mainframe map or a mainframe puzzle, adapt
   it: keep the voice, fix the facts.
3. **Mainframe-only content** — written fresh in the Infocom register. The Bank of
   Zork, the Royal Puzzle, the Endgame and the rest have trilogy counterparts to
   learn the voice from; the words are this project's own.

**Where a description and the exit table disagree, the table wins.** Mainframe
descriptions routinely enumerate their exits in prose, so the description is what
yields. The topology is not negotiable (`docs/games/dungeon.md`, mechanics
contract).

### Known divergences

- **`maxScore` is 716 — one ceiling where the original keeps two.** The mainframe
  carries `SCORE-MAX` 616 (main dungeon) and `EG-SCORE-MAX` 100 (endgame), and
  `score` reports whichever region the player is standing in (`rooms.394`,
  `SCORE-BLESS`); the two are summed nowhere in the source. We sum them, because
  Gnusto models one `maxScore` and its bootstrap totals the `Scoring` award table
  against it — one ceiling makes that check earn its keep, two would need it
  disabled or worked around. The cost is cosmetic and known: a player who finishes
  the main dungeon perfectly sees 616/716 where the original showed 616/616, and
  the endgame then carries them the rest of the way rather than restarting at
  zero. Full reasoning in `docs/games/dungeon-atlas.md` ("What `Sources/Dungeon/`
  uses").
- **`SCORE-MAX` is 616, and this file said 591 until #167.** The missing 25 are
  the Royal Puzzle's gold card, which `dung.355:6324` declares inside
  `<PUT <OBJECT …> ,OROOM <GET-ROOM "CP">>` instead of at top level.
  `makstr.44:315` totals every `<OBJECT …>` call wherever the form sits, so the
  card always counted; the reader that produced 591 — and anyone scanning that
  file for top-level objects — did not. 616 is the figure mainframe Zork is
  usually quoted at. Recorded here because the wrong number was published in this
  repo, not because the original diverges.
- **No 1981 MDL text is reproduced.** `THIRD_PARTY_NOTICES` records that the
  1981-07-22 MDL — the version this game reconstructs — reached the public through
  Bob Supnik's 2003 release rather than through MITDDC, and that no comparable
  licence grant has been located for it, unlike the 1977 and 1978 MDL that MITDDC
  published under MIT No Attribution. So the 1981 source is consulted for structure
  only: map topology, exit tables, point values, object properties, puzzle logic.
  The prose rule above is what keeps that true of the text: every line is either
  the MIT-licensed trilogy's or this project's own. That is a constraint the policy
  has to go on satisfying, not a coincidence it happens to satisfy today.
- **`maxScore` ratchets while the game is being built.** 716 is the finished
  figure; each milestone declares the ceiling its own content can pay, and the last
  one lands on 716. The bootstrap's award-table check writes to standard error on
  every launch, so seven milestones of a deliberate mismatch would train everyone to
  ignore the one check that keeps the table honest. `Sources/Zork1/` set the
  precedent. Full reasoning in `docs/games/dungeon.md` ("The ceiling ratchets while
  the game is being built"); `ScoringTests.everyDemoGameCanPayItsOwnMaximum` is the
  row that holds each milestone to its own number.

### Milestone 1 — above ground, the white house, the cellar

23 rooms: the four sides of the house, five Forest rooms and the perch above one of
them, the Clearing, the three canyon rooms, Kitchen / Living Room / Attic / Cellar,
and — below — the Troll Room, the North-South Crawlway, West of Chasm, the Gallery
and the Studio.

**Where this departs from `Sources/Zork1/`, and why.** All of it is the mainframe's
map, taken from `dung.355` and checked room by room against the exit counts in
`docs/games/dungeon-atlas.md`. These are not liberties; they are the source.

- Behind House opens **east onto the Clearing**, not into forest.
- There is **no Forest Path**. The great climbable tree stands in an ordinary Forest
  room, north of the house.
- There is **one Clearing**, and it is the hub the whole wood drains into. Two of
  its exits (north, east) lead back into it, as do two of the deep forest's — the
  mainframe's way of making the wood feel like a wood.
- **Canyon View stands on the canyon's south wall**, reached east from one Forest
  room and southeast from another, with the forest west and south of it. Zork I
  stands it on the west wall and leads a path northwest.
- The **Cellar runs east** to the Troll Room and south to West of Chasm; Zork I
  runs it north and south.
- The **Troll Room opens in four directions**, and the troll gates three of them.
- The **Gallery and Studio hang off the crawlway**, so the painting can be had
  without ever meeting the troll — where Zork I puts the Gallery behind him. The
  Studio's doors are north and northwest, not south.
- The **Attic is dark.** The mainframe gives it no light bit, so the lamp has to go
  up the stairs.
- The **trap door bars itself for good** on the first descent, with nobody in the
  story to blame and no negotiating from below ("The door is locked from above").
  Zork I makes it the thief's doing and frees it when he falls. The Studio chimney
  is the way back, and the mainframe's rule for it is exact: at most two things in
  hand, and one of them the lamp.
- **`climb chimney` is a second spelling of that exit, and a departure.** The
  source has no `CLIMB` row that walks it; `up` is the only way. Added because
  the chimney's own description says it "looks climbable" and the stub floor's
  refusal denied the verb the room had just advertised — the 2026-08-18 round's
  D4. Both spellings go through one load gate (`Dungeon.chimneyLoadGate()`), so
  the count rule above holds whichever the player types, and the Kitchen end
  refuses in the same words `down` does.
- **The small mailbox is a fitting, and its line stops at the first touch.**
  `MAILB` (`dung.355:5083`) is `<+ ,OVISON ,CONTBIT>` with no `TAKEBIT` — a
  container bolted to the field — and this game had left `scenery` off it, so
  `take all` on turn one walked away with the mailbox and the brochure fuse
  posted into wherever it had last been set down (the 2026-08-18 round's D4). The
  trait is on now, and the *listing* line survives it: a fitting the author gave
  a line of its own still earns one. It also survives in practice as `ODESC1`
  does, on every look — `firstSight` stops at the first touch, and `touched` is
  set by TAKE, which is the one thing the trait refuses. Examining, opening and
  posting into the box all leave it alone.
- Values are the mainframe's, and two are not Zork I's: the painting cases for
  **7** where the trilogy pays 6, and the clockwork canary for **2** where it pays
  4. The egg is 5/5 and the bauble 1/1 in both.

**Declared but not yet walkable.** `maxScore` is 66; a perfect milestone-1
playthrough scores **56**. The clockwork canary (6+2) and the brass bauble (1+1) it
summons both need the egg opened by careful hands, and the only careful hands in
this game are the thief's, who lands with a later region. Forcing the egg yourself
wrecks the bird and forfeits both — as the mainframe intends. The content is
correct; only the route is missing.

**Seams left for later milestones**, each an exit the source has and this milestone
does not build the far side of:

- the Clearing's grating, down into the Grating Room (the maze);
- Canyon Bottom's path north to the End of Rainbow (the river and the rainbow);
- the Troll Room's north passage to the East-West Passage (**closed by milestone
  2**) and south into the maze;
- the Gallery's west door into the Bank of Zork's entrance hall;
- the Living Room's nailed west door onto the Strange Passage (the cyclops opens
  it). The door and its lettering are declared here; the exit is not.

**Deferred, and deliberately.** The score-rank ladder (meaningless under a
ratcheting ceiling); the thief; the brick's fuse (the brick starts in the Attic, so
the object lands here inert); burning the leaves and the paper.

### Milestone 2 — the underground crossroads and Flood Control Dam #3

17 rooms: the East-West Passage, the Round Room, the North-South Passage, the Deep
Ravine, the Chasm, Deep Canyon, the Loud Room and the Damp Cave; then the Dam, its
Lobby, the Maintenance Room, the Dam Base, Reservoir South, the reservoir itself,
Reservoir North, Stream View and the Stream. Forked from `Sources/Zork1/`'s
`Regions/RoundRoom.swift` and `Regions/Dam.swift` and re-topologized. Every room
came out with the number of exits `docs/games/dungeon-atlas.md` records for it,
which is the checksum on reading the tables out of `dung.355` (#156).

**Where this departs from `Sources/Zork1/`, and why.**

- **The Round Room is a carousel.** It has **nine** passages, machinery turning
  under the floor, and while that machinery runs, the passage you take has nothing
  to do with where you come out. Zork I's Round Room is a three-way junction with
  cave-ins. `CAROUSEL-FLIP` starts clear and the only thing that clears it is the
  triangular button in the Machine Room, so in this milestone the room always
  spins. The three passages built here are declared with ``Location/exit(_:toward:)``
  — the dynamic exit — so the East-West Passage's five points, which are an
  `onEnter` award, still get paid; the draw is taken once per attempt in a
  `before(.go)` rule, as `CAROUSEL-OUT` does.
- **The Deep Ravine is a room Zork I does not have**, and it is the junction that
  ties the East-West Passage, the Chasm and Reservoir South together. Without it
  the dam is reachable only through the carousel.
- **The Loud Room hangs off the North-South Passage** and climbs to the Damp Cave,
  where Zork I hangs it off the Round Room and climbs to Deep Canyon.
- **The Loud Room's acoustics have nothing to do with the dam.** `ECHO-ROOM`
  (`act1.254`) never reads `LOW-TIDE`, which is consulted in exactly four places:
  the Dam room's description, the bolt, and the three reservoir descriptions. So
  the room roars from the first moment until somebody says `echo` in it. Zork I is
  the version that couples the two, and this game does not carry its `waterMoving`.
- **The Damp Cave runs south and east**, east being the top of the dam, and narrows
  to the west. Zork I mirrors it.
- **There is no exit between the Dam and Reservoir South.** Zork I invented that
  one. The shore is reached from Deep Canyon (down its northwest passage) or from
  the Deep Ravine's staircase.
- **The sluice gates move the water instantly.** `BOLT-FUNCTION` re-bits the
  reservoir in the same breath that prints the message; Zork I's eight-turn drain
  and refill are the trilogy's addition, and neither the fuses nor the
  refill-drowning they make possible exist here. Nobody can be standing on the
  reservoir bed when the gates close, because the bolt is on top of the dam.
- **The leak can be plugged.** `plug leak with putty`, the putty squeezed out of
  the tube — the mainframe's `LEAK-FUNCTION` and its `PLUG` verb, both of which
  Zork I dropped. The blue button jams once the water has run at all, so plugging
  it keeps the room rather than postponing the loss of it.
- **Reservoir South has six exits** where Zork I gives it four, and **Stream View's
  path runs north and east** rather than following the stream west to east.
- Values are the mainframe's, and neither is Zork I's: the platinum bar is
  **12 to find and 10 to case** where the trilogy pays 10 and 5, and the trunk of
  jewels **15 and 8** where it pays 15 and 5. The East-West Passage's `RVAL` of 5
  is the same in both.

**Adapted rather than reproduced, line by line.** `PASS1` and `PASS5` are in the
comparison's `identical` bucket and `INSTR` in its `minor` one, so those three
rooms are the trilogy verbatim. `LOBBY` is bucketed `substantial`, but the check
that bucket asks for comes out clean — both rooms have the same three ways out —
so its wording stands too. `CAVE3`, `CHAS1`, `DOCK`, `MAINT` and `STREA` are
`substantial` **and** differ because the exits or the fixtures differ, so each
keeps the trilogy's voice with its facts corrected. `CAROU`, `DAM`, `RAVI1`,
`CANY1`, `ECHO` and the three reservoir rooms print from routines in the source
and so have no line to compare; where a trilogy counterpart exists it is the
skeleton, and the rest is written fresh. The guidebook and the matchbook are the
trilogy's verbatim: the mainframe's variants (3.7 cubic feet of concrete, 37
billion cubic feet of reservoir, the Central Bureaucracy's grant, MIT Tech and
Mr. TAA) are 1981 text with no located grant, and the joke is the same joke.

**Mechanics simplified or deferred.**

- **The flood ladder walks straight.** The source raises `WATER-LEVEL` every turn
  and indexes the nine-rung ladder at `level/2`, which never prints "up to your
  ankles" and prints "over your head" twice before drowning you on turn fifteen.
  This game walks one rung a turn from the ankles and drowns on the tenth. The
  ladder's words are the trilogy's, which carries the same nine.
- **The matchbook's five matches** are not modelled; it is a readable object.
  Lighting things is the coal mine's milestone.
- **The wire coil at Stream View is inert**, exactly as the brick in the Attic is.
  The explosion they make together belongs to a later milestone.
- **The screwdriver and the hand pump are inert** for the same reason: the machine
  switch and the boat are later.
- The mainframe's Loud Room takes over the input loop outright and drops you into
  the Ancient Chasm if you break out of it. Here it is an ordinary `before` rule
  that echoes the last word of anything but movement, looking and `echo`.

**Declared but not yet walkable: nothing.** `maxScore` goes 66 → **116**, and a
perfect playthrough of milestones 1 and 2 together scores **106** — the ten still
missing are milestone 1's canary and bauble, which wait on the thief.

**Content in a milestone-2 room that milestone 2 does not declare.** The dented
steel box and the Stradivarius inside it stand in the Round Room and are invisible
until the triangular button in the Machine Room stops the carousel — a room a later
milestone builds. Declaring them here would add twenty unpayable points and an
unreachable object. See `docs/games/dungeon.md`, "The ceiling ratchets".

**Seams left for later milestones**, each an exit the source has and this milestone
does not build the far side of:

- five of the Round Room's nine passages — north and south to the Engravings Cave,
  east to the Grail Room, southeast to the Winding Passage, southwest into the
  maze — and its `out` to the Cold Passage. While the carousel turns, each of them
  answers "You can't go that way" rather than being told the room turned and then
  refused anyway;
- the Deep Ravine's west crawl to the Rocky Crawl;
- the Loud Room's east door onto the Ancient Chasm;
- Reservoir North's tunnel north to the Atlantis Room;
- Stream View's path north to the Glacier Room;
- the Dam Base's launch onto the Frigid River, and the `launch` and `cross` exits
  the reservoir and the stream have for a boat that does not exist yet;
- Deep Canyon's northwest passage and the Deep Ravine's staircase are both gated in
  the source on carrying the gold coffin, which starts in the Egyptian Room. Until
  that room is built the gate is vacuously open, so the plain exit is declared.

**Also landed here.** The bottle in the Kitchen can at last be filled: the five
water rooms carry the mainframe's `RGWATER`, and milestone 1 had none of them,
which is why its `fill` rule was an unconditional refusal.

### Milestone 3 — the temple, Hades, the mirror rooms and the coal mine

42 rooms in three region bundles. The temple quarter: the Rocky Crawl, the Dome
Room, the Torch Room, the Grail Room, the Temple and its Altar, the Egyptian
Room, the Glacier Room and the Ruby Room behind it, the Engravings Cave, the
Entrance to Hades and the Land of the Living Dead. The mirror network: two Mirror
Rooms, two Caves, the Steep and Narrow Crawlways, the Cold and Winding Passages,
the Atlantis Room and the Slide Room. The coal mine: the Mine Entrance, the
Squeaky and Bat Rooms, the Shaft Room, the Wooden Tunnel, the Smelly and Gas
Rooms, seven Coal Mine rooms, both ends of the ladder, a Dead End, the Timber
Room, the Lower Shaft and the Machine Room. Forked from `Sources/Zork1/`'s
`Regions/Temple.swift`, `Regions/Mirror.swift` and `Regions/CoalMine.swift` and
re-topologized. Every room came out with the number of exits
`docs/games/dungeon-atlas.md` records for it, which is the checksum on reading
the tables out of `dung.355` (#156).

**Where this departs from `Sources/Zork1/`, and why.**

- **The Temple hangs off the Grail Room, not the Torch Room.** Zork I folds the
  whole quarter into one vertical shaft — Torch Room down to Temple down to
  Altar down to Hades. In the mainframe `TEMP1`'s only door is `MGRAI`'s
  staircase, the Torch Room drops instead into milestone 1's North-South
  Crawlway, and the Altar is a dead end with no hole in its floor.
- **The Temple is the west end of the building and the Altar the east**, with
  the inscription on the south wall and the granite on the north. Zork I runs
  the building north-south and re-letters every wall.
- **The Egyptian Room's staircase climbs to a Glacier Room**, and over the ice
  is the way the gold coffin leaves that quarter. Zork I gives the Egyptian Room
  one staircase west and no glacier at all.
- **There is no crystal skull and no sceptre.** Both are the trilogy's
  inventions: the mainframe's Land of the Living Dead holds a pile of bodies and
  pays a **room value of 30**, and its gold coffin is empty.
- **The Rocky Crawl and the Deep Ravine both run west into each other.** Not a
  transcription slip — `CRAW1` west is `RAVI1` and `RAVI1` west is `CRAW1`.
- **The southern Mirror Room is the lit one** (`RLIGHTBIT` on `MIRR2`), where
  Zork I lights the northern; and the mirror is worked with `RUB`, which the
  engine folds onto the same intent as `touch`.
- **The Winding Passage has one exit and the sound of another.** Zork I gives it
  a north passage; the mainframe gives it a wall with the Round Room's machinery
  behind it, declared as a refusing exit because the refusal is half the room.
- **The Cold Passage crosses a path running north**, not south; the **Atlantis
  Room's tunnel runs southeast**; the two Caves are different rooms, one dropping
  to Atlantis and one to the gate of Hades.
- **The coal maze is seven rooms**, not four, and the Gas Room is not one of its
  doors: the mine is entered from a **Wooden Tunnel** Zork I never built, and the
  Gas Room is a dead end off it. The bat drops you into any of the seven or
  either end of the ladder (`BAT-DROPS`).
- **The room at the bottom of the shaft is the Lower Shaft**, not the Drafty
  Room, and its narrow ways out are east and northeast. Reaching it **lit** is
  the mainframe's `LIGHT-SHAFT` award: ten points, once, an *event* award and not
  a room `VALUE`, because a room value would pay out to anybody who stumbled in
  in the dark.
- **The crack past the Timber Room is a pair of conditional exits**, as in the
  source (`EMPTY-HANDED`), rather than a `before(.go)` rule: the refusal is the
  same either way round.
- Values are the mainframe's, and four are not Zork I's: the gold coffin is
  **3 to find and 7 to case** where the trilogy pays 10 and 15, the sapphire
  bracelet **5 and 3** where it pays 5 and 5, the huge diamond **10 and 6** where
  it pays 10 and 10, and the grail (**2 and 5**) and the ruby (**15 and 8**) have
  no trilogy counterpart at all. The ivory torch (14+6) and the crystal trident
  (4+11) are the same in both.

**Adapted rather than reproduced, line by line.** `TSHAF`, `ICE`, `JADE`,
`COFFI`, `ENGRA`, `TBASK` and `DIAMO` are in the comparison's `identical`
bucket, so those lines are the trilogy's verbatim, as are the Dome Room, the two
Mirror Rooms, the Slide Room, the Ladder Top, the Dead End, the coal-maze line
and the gate of Hades — all rooms the trilogy copied whole or prints from a
routine with a matching trilogy counterpart. `TEMP1`, `TEMP2`, `EGYPT`, `ATLAN`,
`BOOM`, `CAVE1`, `ENTRA` and `PASS4` are `substantial` **and** differ because the
room differs, so each keeps the trilogy's voice with its facts corrected.

**The `minor` bucket is not safe on exits either**, which is new to this
milestone. `CAVE4`, `PASS3`, `SMELL` and `SQUEE` are all bucketed `minor` — the
two lines are a handful of characters apart — and all four of those characters
are compass points the mainframe does not have. The mechanics contract says the
table wins over the description, so all four are adapted rather than taken
verbatim. The bucket measures string distance; it does not measure whether the
room is the same room.

**Written fresh:** the Rocky Crawl, the Grail Room, the Glacier Room and the
Ruby Room (no trilogy counterpart at all), the Steep and Narrow Crawlways, the
Wooden Tunnel, and the two gas-explosion endings.

**Mechanics simplified or deferred.**

- **The slide is the plain drop into the Cellar.** The source's `SLIDE-EXIT`
  turns the chute into a rope-climb down `SLID1`–`SLID3` to a Slide Ledge and a
  Sooty Room once a broken timber has been tied at the top; those five rooms and
  the red crystal sphere in them are a later milestone's, so this one declares
  the plain drop and records the seam.
- **The mainframe's death is not adopted.** `rooms.394` sends a corpse to the
  Entrance to Hades to be prayed back at the Altar. Milestone 1 already shipped
  the forest resurrection and its tests pin it; converting is its own change.
- **The mirror swap moves loose floor items only**, where the source swaps the
  two rooms' whole object lists. Swapping fixtures would move the mirrors
  themselves out of their rooms.
- **The bell is one object with a flag**, where the source swaps `BELL` for a
  separate red-hot `HBELL`. Its refusal is an ``Item/reach(otherwise:)`` rule, so
  take, ring and every other verb the engine gates on reach answer with the
  source's one sentence; the listing line still reads "brass bell" while it
  glows, because nothing renames an item at runtime.
- **The candles burn in the source's three stages** — twenty turns, then ten,
  then five — and start burning when they are first picked up, which is the
  source's own `TAKE` branch. Without that they would be a second everlasting
  lamp.
- **The matchbook is the match**, as in the source, where `MATCH` is one object
  with a count on it: striking one lights the book in your hand for two turns.
  Milestone 2 left it a readable object because nothing yet needed a flame.
- **The exorcism's clock is the source's**: six turns after the bell, three after
  the candles, twenty before the bell cools. `EXORCISE` is the source's own hint
  verb and never performs the ceremony.
- **The rope tied to the railing is two fixtures, where the source is one flag.**
  `ROPE-AWAY` (`act3.199:1287`) takes the coil out of your hands, drops it into
  the Dome Room and sets `NDESCBIT` on it, so one object is both the thing you
  carried in and the thing hanging through the dome. Gnusto cannot switch a
  static trait on at runtime, so the coil goes offstage when the knot is tied and
  a `scenery` fitting stands in for it at each end — one at the rim, one twenty
  feet below on the floor of the Torch Room, because a rope hung through a dome
  is in two rooms at once and an item is in one. It is the `steelCage`/`cageBars`
  shape. **Where this game is gentler:** the source refuses `TAKE` outright while
  the knot holds (*"The rope is tied to the railing."*) and makes you `UNTIE`
  first; here `take rope` at the rim does both in one move. Both ends of the trip
  are the source's otherwise — the knot can only be reached from the rim, and
  undoing it shuts the Dome Room's drop. (#286)

**Also landed here.** Four rooms are ``alwaysDescribed`` — the Dome Room, the
Torch Room, the Glacier Room, the Entrance to Hades, the two Mirror Rooms, the
Bat Room and the Machine Room — because in each of them the state of the puzzle
appears only in the long description, and a brief re-entry (after UNDO, or after
walking back in) would print a bare room name over a barred gate, an unmelted
glacier or an open lid. That is the engine feature #149 landed for.

**The carousel moved to the host.** Milestone 2 declared the Round Room's three
built passages inside ``DungeonRoundRoom``. As of this milestone **eight** of the
source's nine are built and they reach four different bundles, so the exit list,
the draw and the `before(.go)` guard all live in ``Dungeon`` instead. Nothing
else moved; the ninth passage, southwest into the maze, is the last seam left in
the room.

**Declared but not yet walkable: nothing.** `maxScore` goes 116 → **265**, and a
perfect playthrough of milestones 1 to 3 together scores **255** — the ten still
missing are milestone 1's canary and bauble, which wait on the thief.

**Seams left for later milestones**, each an exit the source has and this
milestone does not build the far side of:

- the Round Room's last passage, southwest into the maze;
- the Torch Room's door west into the Tiny Room;
- the Egyptian Room's door south to Volcano View;
- the Ruby Room's passage west into the Lava Room;
- the Engravings Cave's southeast passage to the Riddle Room;
- the Land of the Living Dead's east passage to the Tomb of the Unknown
  Implementer;
- the Slide Room's chute, which becomes a rope-climb down the coal chute once a
  timber is tied at the top.

### Milestone 4 — the Frigid River, the maze, the Cyclops and the Treasure Room

40 rooms in two region bundles. The river: five stretches of the Frigid River,
both White Cliffs beaches, the Sandy Beach, the Shore, Aragain Falls, the Rainbow
Room, the End of Rainbow, and the rocky western approach — Rocky Shore, the Small
Cave, the Ancient Chasm and two dead ends off it. The maze: fifteen twisting
passages, four dead ends, the Grating Room, the Cyclops Room, the Treasure Room
and the Strange Passage. Forked from `Sources/Zork1/`'s `Regions/River.swift` and
`Regions/Maze.swift` and re-topologized. Every room came out with the number of
exits `docs/games/dungeon-atlas.md` records for it — the atlas now publishes the
tables themselves (#156), so this is the first milestone whose map was read off
the committed document rather than out of `dung.355`.

**Where this departs from `Sources/Zork1/`, and why.**

- **The maze is entered from the south**, through the Troll Room's third gated
  passage, and Maze-1 comes back **west**. Zork I hangs the whole maze west of
  him and makes the return symmetric.
- **Six bearings inside the maze are not the trilogy's**, and each is exactly the
  sort of thing a contributor would "fix" back: Maze-2 reaches Maze-4 by going
  **north** where Zork I goes down; Maze-7 reaches Dead End-1 **northeast** where
  Zork I goes down; Maze-9 reaches Maze-11 **east** and Maze-10 **down**, which is
  Zork I's pair swapped; Maze-12 reaches Maze-5 **west** where Zork I goes down;
  Maze-15 opens on the cyclops **northeast** where Zork I goes southeast.
- **The cyclops leaves by the north wall**, not the east, so the Strange Passage
  hangs north of his room and comes back south. Its one entrance is therefore
  "to the south", where the trilogy says west.
- **The Strange Passage is worth 10 points and the Treasure Room 25**, both room
  `RVAL`s. Zork I has no room value anywhere in this region.
- **The Treasure Room's granite wall is its north one**, because its **east** wall
  is a passage into the Royal Puzzle's antechamber — a door Zork I has no use for
  and therefore walls up. That east door is a seam this milestone leaves open.
- **`temple` and `treasure` are magic words.** Said in the Temple, `treasure`
  puts you in the Treasure Room; said in the Treasure Room, `temple` puts you
  back. The shared north wall of solid granite is the hint, and the endgame's own
  question set asks about it. Nothing in the trilogy connects the two rooms.
- **The dead ends are named "Dead End" and described with the trilogy's
  sentence.** `dung.355` gives `DEAD1` and `DEAD2` their long and short strings
  the wrong way round and gives `DEAD3`–`DEAD7` the short string twice, so the
  source's own display names are inconsistent five ways. The trilogy wrote the
  sentence the slip was meant to be, and it is taken verbatim — except for the two
  dead ends off the Ancient Chasm, which are nowhere near a maze and get a line of
  their own.
- **The river's banks are reversed.** The White Cliffs wall the **east** shore and
  the Sandy Beach, the Shore and Rocky Shore are all **west**; Zork I puts them the
  other way round and rewrote every description that names a bank.
- **There is no current.** `dung.355` registers no clock interrupt for the river,
  so a boat that is not paddled stays where it is. Zork I's eight-turn drift, and
  the fuse that carries it, are the trilogy's invention.
- **The river is dark.** The mainframe gives `RLIGHTBIT` to the Rainbow Room and
  the End of Rainbow and to nothing else down here — not the five stretches, not
  either beach, not the Shore, not Aragain Falls. The Attic set the precedent at
  milestone 1: where the source withholds the light bit, so does this game.
- **There is no Sandy Cave and no jewelled scarab.** The shovel lies in the Small
  Cave on the western approach, and what four digs in the beach turn up is a
  **statue**, worth 10 to find and 13 to case. The fifth dig collapses the hole,
  as in both sources.
- **The White Cliffs have no way inland.** Zork I bores a foot-path west into the
  Damp Cave; here the wall is solid, and the road to the west bank on foot is the
  Loud Room's own east door — the Ancient Chasm, the Small Cave and Rocky Shore,
  four rooms Zork I does not have.
- **There is no sceptre.** The broken sharp stick at the Dam Base does both of the
  sceptre's jobs: waved at either end of the rainbow it makes the rainbow solid
  and reveals the pot of gold, and carried aboard the boat it lets the air out.
  **It is also the only thing in the game that holes the boat** — Zork I bursts it
  on a whole class of sharp things, and this game therefore has no `sharp` trait
  at all.
- **The pot of gold stands at the End of Rainbow from the first turn**, hidden
  rather than conjured: the source flips its visible bit, it does not create it.
  And the End of Rainbow is walkable from Canyon Bottom, so the pot never needs a
  boat.
- **The barrel at Aragain Falls is a vehicle, and it shuts the view as well as the
  room paragraph.** Climb into it and `look` shows the inside of a barrel rather
  than the falls; say `geronimo` and it goes over. The line it shows says the
  falls cannot be seen from in there, so the falls, the rainbow over them and the
  path off the north end each carry a `reach(otherwise:)` guard and a
  `before(.examine)` guard on `player.vehicle != barrel` and answer in the
  barrel's voice instead of describing themselves (#286). **Neither source does
  that**: the mainframe leaves the outdoor scenery in scope and relies on the
  barrel's own `look`, so `x falls` from inside it answers in full. This is
  therefore stricter than both, in the same way the cliff path below is — a case
  the source did not think to forbid rather than one it meant to allow. The
  barrel itself and `listen` are deliberately not shut: a man in a barrel can see
  the barrel and hear the waterfall.
- Values are the mainframe's, and two are not Zork I's: the silver chalice cases
  for **10** where the trilogy pays 5, and the statue (**10 and 13**) has no
  trilogy counterpart. The emerald (5+10), the pot of gold (10+10) and the bag of
  coins (10+5) are the same in both.

**Adapted rather than reproduced, line by line.** `RIVR2`, `MAZE2`–`MAZE9`,
`MAZ10`–`MAZ15`, `BUOY`, `IBOAT` and `CHALI` are in the comparison's `identical`
bucket and `RIVR1` and `RAINB` in its `minor` one, so those are the trilogy
verbatim, as are Aragain Falls, the White Cliffs' southern beach, the Grating
Room and its three overhead lines, the skeleton and its curse, the bag of coins,
the rusty knife, the burned-out lantern, the boat's inflate and deflate answers,
the three digging lines, and the cyclops's whole repertoire — his blocking, his
eyeing, his gasping, his sleep, the wrath ladder and the meal.

**Four `minor` entries are adapted anyway, and all four for the same reason
milestone 3 recorded: the bucket measures string distance, not whether the room
is the same room.** `RIVR5`, `FANTE`, `BLROO` and `TREAS` each differ from the
trilogy by a single compass point, and in each of them that point is an exit this
game does not have — the Shore is west, not east; the Strange Passage's entrance
is south, not west; the Treasure Room's granite is north, not east.

`BEACH`, `RIVR3`, `RIVR4`, `WCLF1`, `MAZE5` and `DEAD1`–`DEAD4` are `substantial`
and differ because the room differs, so each keeps the voice and loses the wrong
facts. The Cyclops Room, Rocky Shore, the Small Cave, the Ancient Chasm, the two
chasm dead ends, the barrel, the broken sharp stick, the statue, the guano, the
boat's label and the granite wall's word are written fresh. **No 1981 MDL text is
reproduced anywhere.**

**Where this game is stricter than its source.** The mainframe's cliff path asks
only whether you are *carrying* the inflated boat, so a player sitting in it can
ride an inflatable down a foot-wide ledge. That is a case the source did not
think to forbid rather than one it meant to allow, and this game refuses it both
ways.

**Also landed here.** Two rooms are ``alwaysDescribed`` — Aragain Falls, whose
rainbow is reported nowhere else, and the Cyclops Room, whose hole in the north
wall is the only sign he was ever there. Milestone 1's Clearing joins them,
because it now has to report the grating: its description moved to the host,
where the grating's state is visible, and its `before(.open)` refusal became a
conditional one now that the keys exist.

**Declared but not yet walkable: nothing.** `maxScore` goes 265 → **393**, and a
perfect playthrough of milestones 1 to 4 together scores **383** — the ten still
missing are still milestone 1's canary and bauble, which wait on the thief.

**Not built, deliberately.** `FCHMP`, "Moby lossage": one blocked exit, an empty
description, and a room function that kills on any verb but `look`. It is where
the source puts you after River-5, and this game dies at the lip instead.

**Seams left for later milestones**, each an exit the source has and this
milestone does not build the far side of:

- the Treasure Room's east passage into the Royal Puzzle's antechamber.

### Milestone 5 — the Bank of Zork, the well, the tea party and the robot

20 rooms in three region bundles, and the first milestone that forked nothing
from `Sources/Zork1/`, because there was nothing there to fork. The Bank of
Zork — the entrance hall, both teller's rooms, both
Viewing Rooms, the Safety Depository, the Chairman's Office, the Small Room and
the Vault. The Alice area, which is `dung.355`'s own heading and this bundle's
boundary too — the Circular Room at the bottom of the well, the Top of Well, the
Tea Room, the Posts Room and the Pool Room under its table, the Low Room, the
Machine Room, the Dingy Closet and the Cage. And the two rooms of the riddle,
the Riddle Room and the Pearl Room, which are the only road to any of it. Every
room came out with the number of exits `docs/games/dungeon-atlas.md` records for
it.

**Where this departs from `Sources/Zork1/`, and why.** Zork I has none of these
rooms, so the comparison that matters here is with Zork II, which took most of
them and rebuilt the game around them.

- **The Bank hangs off the Gallery**, west, through a door milestone 1 left
  undeclared. Nine rooms and 40 points come through one doorway.
- **`BKTWI` and `BKVAU` declare no exits.** Both are `NULEXIT` in the source.
  The way out of either is through a wall.
- **The curtain of light reaches four rooms, and which one depends on the
  bearing you last walked into the Depository on.** That is `SCOL-ROOMS`: west
  from the West Teller's Room gives the West Viewing Room, east from the East
  Teller's the East Viewing Room, north from the Chairman's Office the Small
  Room — and *south*, which no doorway can give you, the Vault. The only thing
  north of the Depository is the curtain itself, so the one way to arrive
  heading south is to come back out through it.
- **Four walls out of sixteen lead anywhere but the front door.**
  `SCOL-WALLS` pairs the west Viewing Room's east wall with the east Viewing
  Room, the Small Room's south wall with the Vault, and both of those backwards.
  Every other wall puts you in the Bank Entrance, which is `SCOLEXIT`'s
  destination and the only way to leave the building with the takings: the
  Depository's own east and west doorways ring `BKALARM` on anything belonging
  to the bank.
- **Two rooms in this game are called Machine Room, and they are not the same
  room.** `MACHI` is the coal mine's, with the lid and the switch, and milestone
  3 built it. `CMACH` is this one, with the round, square and triangular
  buttons, west of the Low Room and north of the Dingy Closet. The atlas's *in
  `Sources/Zork1/`* column points `CMACH` at `Regions/CoalMine.swift` because
  that column matches on display name; it is matching the wrong room.
- **The Low Room has nine exits and they reach two rooms** — five the Machine
  Room, four the Tea Room.
- **The Posts Room has no way in.** No exit anywhere in the atlas leads to
  `ALISM`; you arrive by eating the 'Eat-Me' cake in the Tea Room and finding
  that the table has become a roof and its legs four posts. The orange-icing
  cake is the way back, and it works under the table and nowhere else.
- **The well is a vehicle.** `BUCKE` carries `VEHBIT` and the two well rooms
  carry `RBUCKBIT`; pouring the bottle's water into the bucket raises it, and
  emptying it lowers it. The water stays in the bucket, which is what makes the
  trip reversible — the Alice area has no other exit in either direction.
- **The white crystal sphere is a trap with two answers.** Lifting it off its
  pedestal drops a steel cage on whoever did the lifting. Done by hand it costs
  you the room and the way out is `robot, lift the cage`; ordered, the cage
  lands on the robot, which does not mind, and the sphere is free.
- **The triangular button stops the Round Room's carousel**, which is what
  finally puts the dented steel box and the Stradivarius inside it in play —
  milestone 2 declared neither and named this button as the reason.
- Values are the mainframe's throughout: the zorkmid bills 10+15, the portrait
  10+5, the pearl necklace **9+5** — the one treasure in the game worth more
  found than cased — the sphere 6+6, the tin of spices 5+5, the Stradivarius
  10+10, and the Top of Well's room `RVAL` 10.

**Adapted rather than reproduced, line by line.** Eleven of this milestone's
entries are in the comparison's `identical` bucket — `BKEXE`, `BKVAU`, `BUCKE`,
`BWELL`, `IRBOX`, `MPEAR`, `PEARL`, `RBTLB`, `ROBOT`, `STRAD` and `TWELL` — so
the Chairman's Office, the Vault, the wooden bucket, the Circular Room, the
steel box, the Pearl Room, the pearl necklace, the green piece of paper, the
robot, the Stradivarius and the Top of Well are the trilogy's lines verbatim.
`CAGED` is `minor` and taken as it stands. The issue that commissioned this milestone
said the opposite: that all of this prose had to be written fresh, because the
trilogy's versions belonged to changed puzzles. Fifteen entries out of
twenty-three say otherwise, so the milestone followed the policy.

**Two `minor` entries are adapted anyway, for the reason milestones 3 and 4 both
recorded: the bucket measures string distance, not whether the room is the same
room.** `ALICE` and `ALISM` both enumerate their exits in prose, and the
trilogy's versions of both drop or change them.

`ALITR`, `BKBOX`, `BKVE`, `BKVW`, `CAGER`, `BILLS` and `PORTR` are
`substantial` and differ because the puzzle differs, so each keeps the voice and
loses the wrong facts — `ALITR` is the comparison's own worked example of that,
since what leaks from that ceiling is not the same substance in the two
versions. `RIDDL` is filed `substantial` and its trilogy column is **empty**:
no trilogy room answers to it at all.

The Bank Entrance, both teller's rooms, the Small Room, the stone cube, the
curtain, all sixteen walls, the Riddle Room and its verse, the well's etchings,
the cakes, the posts, the pool, the flask, the tin of spices, the Low Room, the
Machine Room, the three buttons, the pedestal, the cage in both of its states
and the robot's instruction sheet are written fresh. **No 1981 MDL text is
reproduced anywhere** — including the ring of letters round the well and the
sheet that came with the robot, both of which are 1981 typography in the source.
Each says what the source's says, because what they say is a hint and a hint is
structure; neither says it in the source's characters.

**Where this game is gentler than its source, and why.**

- **The Cage is lit, and it kills you on a clock.** `dung.355` withholds
  `RLIGHTBIT` from `CAGED` and gives the room no exit at all. A dark room with no
  exits and no way to die is a save file the player has to reload; this game
  lights the cage — it is a cage standing on the floor of a lit closet — and
  admits the gas the alarm company plainly installed, on a six-turn fuse. The
  resurrection milestone 1 built is what makes that recoverable.
- **The cakes survive being bitten.** The source declares one of each. The only
  way out of the small world under the table is the orange-icing cake, so a cake
  eaten to nothing would strand a player four inches high with the spices in
  hand and nothing to do with them.
- **The bucket does not travel.** The engine carries a boarded vehicle wherever
  its passenger walks, which is right for the boat and the balloon and would let
  a player wheel the well's only lift into the Round Room and shut the Alice
  area behind them for good. Both ends of the trip also require you to be *in*
  the bucket, so it can never be left at one end of a shaft that has no other
  way up or down — **except by dying in the Alice area**, which is where the
  missing clock shows. The mainframe empties the bucket a hundred turns after it
  rises (`<CLOCK-INT ,BCKIN 100>`, `act3.198:58`, fired by `<CEVENT 0 BUCKET T
  "BCKIN">`, `dung.354:1560`), and an emptied bucket at the top descends on its
  own, so the source never has to think about a player separated from the lift.
  This game has no such fuse. Death is the only way to be parted from the
  bucket, so death is where it goes back: `Dungeon.onDeath()` empties it and
  returns it to the Circular Room, alongside clearing `DungeonAlice.shrunk`. It
  is the same repair twice — a resurrection restores the body, and the Alice
  wing is the one place that keeps state about the body. Without it the tin of
  spices and the crystal sphere are sealed in and `maxScore` is unreachable.
- **The robot has one room of earshot.** The engine deliberately lets an
  order-taker be named out of sight — that is what makes "the robot goes where
  you cannot" work — and deliberately leaves *how far* to the game. This game
  says one room, plus the cage you are standing in while the robot is outside
  it. Without it you can order the robot to lift a cage in the Dingy Closet
  while standing in a forest two hundred rooms above it.
- **`robot, take sphere` costs nothing, where the source charges everything.**
  `SPHERE-FUNCTION` (`act3.199:231`) gives the ordered branch to `JIGS-UP` with
  `ROBOT-CRUSH`: the cage traps the robot, the robot short-circuits, and it
  *crushes the sphere beneath him as he falls*. So in the mainframe the second
  answer to this puzzle destroys the robot, the treasure and six of the
  available points, and only the first answer — spring the trap yourself, then
  `robot, lift the cage` — wins. This game keeps the trap and drops the
  punishment: the cage lands on a machine that does not mind, and the sphere is
  left loose on the closet floor. The two answers are equal here and they are
  not in the source. `Prose.robotSpringsTheCage` is the sentence that says so,
  and it says the sphere is *set down*, because a sphere in an actor's hand is
  a sphere outside the player's scope — see the note on that constant. (#286)

**Also landed here.** The Round Room's description stopped being permanent:
until this milestone nothing could stop the machinery under its floor, and a
room that went on whirring afterwards would be telling the player their own
solution had not worked. Its `describe` rule and the machinery's own now read
`carouselSpinning`, and both stayed in `DungeonRoundRoom`, because everything
they read is that bundle's. The Top of Well's ten points are paid from an
`afterEachTurn` rule rather than from `scoring.visit`: a room value is an
arrival award, and the usual way into that room is riding a vehicle up, which
moves the bucket and carries the player and runs no `onEnter` at all. That is
the hole the Bank of Zork spike recorded (#132), and this is the first room in
the game to fall into it.

**Declared but not yet walkable: nothing.** `maxScore` goes 393 → **499**, and a
perfect playthrough of milestones 1 to 5 together scores **489** — the ten still
missing are still milestone 1's canary and bauble, which wait on the thief.

**Not built, deliberately.** The gate on the Low Room's nine exits. All nine are
`<CEXIT "FROBOZZ" … MAGNET-ROOM-EXIT>`, and `FROBOZZ` is a flag `dung.355` never
sets anywhere — the source's idiom for *a routine decides this*. That routine is
in a file the extraction does not carry, so the destinations are the atlas's and
the gate is left out rather than invented, which is the seam convention's second
rule. The same is true of the Depository's east and west doorways: what is built
there is `BKALARM`, whose sentence the source does carry, on the one condition
the four `SCOL` tables imply.

**Seams left for later milestones: none.** Every exit these twenty rooms declare
reaches a room that exists.

### Milestone 6 — the volcano, the balloon, the Library and the Dusty Room

10 rooms in one region bundle, and the only part of the map you get to by
flying. The Volcano Bottom and the Lava Room over it; four levels of open air in
the shaft — `VAIR1` to `VAIR4`; the Narrow Ledge with the Library behind it; the
Wide Ledge with the Dusty Room behind that; and Volcano View on the far wall,
which is reached on foot and reaches nothing but the room it is reached from.
Every room came out with the number of exits `docs/games/dungeon-atlas.md`
records for it.

**The Ruby Room is not one of them.** The issue that commissioned this milestone
names the Ruby Room as content to build. Milestone 3 built it, and the ruby in
it has counted toward `maxScore` since then. What milestone 6 owed that room was
its **west passage**, which is one host-wired edge.

**Where this departs from `Sources/Zork1/`, and why.** Zork I has none of these
rooms either, so the comparison that matters is with Zork II, which took all of
them.

- **The whole quarter is dark but the Dusty Room.** `dung.355`'s `ROOM` macro
  defaults a room's flags to `RLANDBIT` alone, and `SAFE` is the only room here
  that adds `RLIGHTBIT`. So a shaft with daylight visibly coming down it is
  pitch black to stand in. That is the source, and it is the same reading that
  made the Frigid River dark at milestone 4.
- **The four air rooms carry no land bit at all.** They are `RAIRBIT` rooms, and
  the source refuses to let anybody step out of a vehicle in one: *"You realize,
  just in time, that disembarking here would probably be fatal."* Refused, not
  permitted and then punished.
- **The Lava Room's second exit is west, not east.** The comparison document
  files `LAVA` as `minor`, which would ordinarily mean taking the trilogy's line
  verbatim; the trilogy's line says the exits are east and south, because the
  room it reached east of there was the Glacier Room. The mainframe reaches the
  Ruby Room, west. The room decides.
- **The Ruby Room's passage runs west from both ends.** `RUBYR` west to `LAVA`,
  `LAVA` west to `RUBYR` — the mainframe's own doubling, the same one the Deep
  Ravine's crawl has, and not a transcription slip.
- **The Wide Ledge is east of `VAIR4`, and both sources' paragraphs say west.**
  This one is not the trilogy rewriting a room the mainframe kept. `dung.355`
  prints *"To the west, there is a place to land on a wide ledge"* and files
  `VAIR4 EAST -> LEDG4` and `VAIR4 LAND -> LEDG4` in its own exit table, so the
  original contradicts itself, and Zork II inherited the paragraph without the
  table. The table wins — the mechanics contract's rule, and the only reading
  the map supports, since `LEDG4 WEST` is already the gnome's chimney down to
  the volcano floor and `DungeonVolcano.ledgeLandings` reads the bearing three
  ways. Recorded here rather than only in the prose file because the departure
  is from the *prose of both sources at once* rather than from one of them.
  `VAIR2`, whose paragraph says west and whose ledge is west, is untouched.
  (#233, second pass.)
- **Volcano View hangs off the Egyptian Room**, south, through a door that
  room's description has named since milestone 3. It is the one ledge nothing
  can land on: `DOWN` and `CROSS` are both declared in its exit table and both
  refuse.
- **The balloon rises only while the receptacle is open *and* alight.** Shutting
  the lid over a live fire is the only way to come down and keep the balloon: a
  balloon whose fire has gone out sinks too, and does not survive the floor. The
  #133 spike had the fire and the sinking and not the lid.
- **The rim is fifteen feet across.** A balloon that climbs past `VAIR4` tears
  itself open on it and the wreck lands at the bottom. Zork II flies it out of
  the volcano and kills the pilot in the Flathead Mountains instead; the
  mainframe is the authority on what a puzzle does, so the rim is what is built.
- **The brick, the wire coil and the hole are one puzzle spread over three
  milestones.** The brick landed inert in the Attic at milestone 1 and the wire
  on the bank at Stream View at milestone 2, and both entries said so. This is
  the milestone that gives them something to do: brick in the hole, wire in the
  brick, a match to the wire, and two turns to be somewhere else.
- **The blast has an aftermath, and it is on a clock.** Five turns later the
  Dusty Room comes down — on you, if you are still in it — and eight turns after
  that the Wide Ledge follows. That leaves exactly four moves between the
  explosion and the room sealing itself: south, take the crown, take the card,
  north. The card in the box says as much before you light anything.
- Values are the mainframe's: the priceless zorkmid 10+12, Lord Dimwit's crown
  15+10, the Flathead stamp 4+10. No room in the volcano carries an `RVAL`.

**Adapted rather than reproduced, line by line.** Ten of this milestone's
entries are in the comparison's `identical` bucket — `VAIR1`, `VAIR2`, `LEDG3`,
`HOOK1`, `HOOK2`, `GNOME`, `CARD`, `DBALL`, `STAMP` and `BRICK` — and `VLBOT`
and `LIBRA` are `minor`, so the Volcano Core, the level of the small ledge,
Volcano View, both hooks, the gnome, the card, the wrecked balloon, the Volcano
Bottom and the Library are the trilogy's lines verbatim.

Three entries depart from that, each for a reason the comparison document cannot
see. `LAVA` is `minor` and adapted anyway, for the exit above. `VAIR4` is
`substantial` and adapted **twice**: to put back the one fact the trilogy dropped
— the rim is fifteen feet across, which is why rising past it wrecks the balloon
— and to send the aviator east rather than west, for the exit-table reason
recorded above. And
**`VAIR3` is filed with no trilogy counterpart and has one**: Zork II declares
`VAIR-3`, *Volcano by Viewing Ledge*, whose line differs from the mainframe's by
two words. The atlas misses the pairing because the display names differ and the
room declares no exits, so neither the name matcher nor the graph matcher can
reach it. It is taken here as the `minor` entry it would have been. The
generated documents are not edited by hand.

**`LEDG4` and `SAFE` are in no bucket at all, because both sources generate them
from code.** `dung.355` gives each an empty description and a room routine, and
the trilogy does the same; the text here is the trilogy's routine's, which is
MIT-licensed like any other trilogy line.

Written fresh: the shaft's scenery, the blue label that drops out of the bag,
the gnome's own description, the zorkmid's face and the stamp's, and everything
the explosion says. **No 1981 MDL text is reproduced anywhere** — including the
coin and the stamp, which in the source are figures drawn in 1981 typography.
Reading either reports what the figure says and does not redraw it. The blue
label goes the same way the robot's instruction sheet went at milestone 5, and
for the same reason: what it says is the three words the balloon answers to, and
that is structure.

**The stranding the issue warned about is real, and it is kept.** Untie a
still-burning balloon on a ledge and it leaves without you — the #133 spike
reproduced that, and this milestone reproduces it too, because the source
answers it rather than preventing it. Ten turns later a volcano gnome walks out
of the ledge wall and sells the way down for any treasure at all, and the door
he opens never shuts again. He waits indefinitely: the mainframe arms his
five-turn watch on the first word said to him and not before, so a stranded
player who leaves a gnome alone is not stranded. Two losses are still final, and
both are the source's: offer him the brick and he leaves for good, and light the
burner with nobody aboard and the rim takes the balloon. Neither kills the
player; both cost whatever is left of the volcano's 61 points.

**Where this game is narrower than its source.** The mainframe seals *any* room
the brick goes off in, empties it of everything takeable, and — in the Living
Room — empties the trophy case with it. This game gives the aftermath to the one
room the source's own clock names, the Dusty Room, and to the ledge it stood on.
Anywhere else the blast is fatal if you are standing in it and the room stays
open. Sealing an arbitrary room needs a per-room flag the engine has no place
for, and the only room the puzzle ever seals is the Dusty Room.

**And the quarter has an earshot.** The mainframe prints "There is an explosion
nearby", the rumble of the Dusty Room going down and the Wide Ledge's *(That was
a narrow escape!)* unconditionally, so all three followed a player who had died
in the volcano and woken among the trees. Here the three read one
``DungeonVolcano/insideTheVolcano`` — the floor, the four levels of shaft, the
three ledges, the Library and the Dusty Room — and are heard nowhere else. The
cost is stated where it is paid: the brick travels, this bundle can only name its
own quarter, and a charge carried across the map and set off there is now heard
by nobody rather than by everybody. The robot's one room of earshot, above, is
the same call made at milestone 5.

**Also landed here.** `Sources/Gnusto/Engine/RoomDescriber.swift` now filters
`scenery` out of the *"In the X is a Y."* and *"On the X is a Y."* listings, the
way it already filtered it out of the room's own. Without it the balloon's cloth
bag, receptacle and braided wire — three fittings the basket's own description
already names — each got a line of its own in every room description. No other
game in the repo puts scenery inside a container or on a surface, and the whole
suite is unchanged by it. `ContainerTests` pins the new rule against a fixture
of its own rather than against this game's transcripts.

**Four listing lines this milestone could not use.** The nested lister had no
presence channel: an item inside a container got *"In the wicker basket is a
blue label."* and nothing else, where an item on the floor got its `firstSight`
until it was touched. The crown, the card, the Flathead stamp and the blue label
each start inside something and never sit loose in a room untouched, so their
source lines — two of them `identical` entries — would never have printed, and
they were not declared. Filed as its own engine issue rather than four dead
constants.

> **Since settled — #176.** `presence { }` / `firstSight(…)` is now consulted
> wherever an item is listed, one level down included, so the channel exists.
> The four lines above are declared as of #207 — see the entry below this one.
> That was the follow-up's work, not this record's. What the widening
> *did* bring back is ten lines the game had already written and could not
> print: the sack and the bottle on the kitchen table, the knife on the attic
> table, the Stradivarius in the steel box, the emerald in the buoy, the four
> cakes on the tea table, and the tan label folded inside the boat. Every one is
> the source's own sentence, and every one had been losing to the stock
> *"On the X is a Y."*
>
> Two of them now read *less* like a nested thing than the stock line did, and
> deliberately so: the mainframe's own `FDESC` for the violin is "There is a
> Stradivarius here.", which under the opened steel box says *here* rather than
> *in the box*. The author's declared line wins over the engine's template —
> that is what the channel is for — and where a line wants to name its container
> the game can say so, as the boat label does.

> **An eleventh line, withdrawn — #205.** The widening reaches one level down;
> it does not reach two. `FOOD` starts in `SBAG` and `SBAG` starts on the
> kitchen table, which puts the hot pepper sandwich a level below anything a
> room description walks. Its listing line —
>
> > A hot pepper sandwich is here.
>
> was declared here at milestone 1 and printed on no turn of any playthrough.
> It is now withdrawn from `Sources/Dungeon/Regions/Prose+House.swift` rather
> than kept as a constant nothing reads. The placement is the source's and
> stands; the line is the thing that had nowhere to go. `Sources/Zork1/`
> declares no listing line for its own lunch and so never had the problem,
> which is why this is a Dungeon entry and not a shared one.
>
> The reconstruction did not notice for seven milestones, which is the whole
> argument of #205: the bootstrap now warns when an item declares a listing
> line the map buries out of reach, so the next one is caught at build time
> rather than by hand-reading a transcript for a sentence that isn't there.
> The sandwich was the only such line in the corpus.

> **The four, now declared — #207.** `dung.355` has all four, in the field
> `mdl_reader` already reads for every other object's listing line:
>
> | id | field | source line |
> |---|---|---|
> | `CROWN` | `ODESCO` | The excessively gaudy crown of Lord Dimwit Flathead is here. |
> | `CARD` | `ODESC1` | There is a card with writing on it here. |
> | `STAMP` | `ODESC1` | There is a Flathead stamp here. |
> | `BLABE` | `ODESC1` | There is a blue label here. |
>
> `CARD`, `STAMP` and `BLABE` are `identical` entries, so the trilogy carries
> them across unchanged and either source yields the same sentence. `CROWN`
> declares two fields: `ODESCO`, above, is the untouched-initial one, which is
> what `firstSight` means; `ODESC1` "Lord Dimwit's crown is here." is the
> after-touch line, and this engine has no channel for one — the stock sentence
> takes over there. It is not reproduced.
>
> **Three of the four are adapted, and the fourth is adapted in one branch of
> two.** Every one of these lines is written for an object lying loose on a
> floor, and not one of these four is ever on one: the crown and the card are in
> the safe until a hand takes them out, and the stamp is in the purple book. So
> the line names its holder — "Inside the box is the excessively gaudy crown of
> Lord Dimwit Flathead." — which is the license this game has and `Sources/Zork1/`
> does not. The Stradivarius went the other way at #176 and the record above
> stands; the difference is that the violin's *here* is at least true of the room
> it prints in, and a crown that is only ever in a box has no such frame.
>
> **Only the blue label carries a `presence { }` rule**, because only its holder
> can be destroyed: the rim tears the bag and `wreckTheBalloon` tips the basket's
> cargo onto the volcano floor, where the label lies loose and untouched and the
> source's own sentence is exactly right. The other three get a static
> `firstSight` — the safe is `scenery` and imbedded, the thief's prowl reaches
> `VLBOT` but no ledge above it, and neither treasure leaves its container except
> by hand. A second constant for any of them would be the sandwich again.

**Declared but not yet walkable: nothing.** `maxScore` goes 499 → **560**, and a
perfect playthrough of milestones 1 to 6 together scores **550** — the ten still
missing are still milestone 1's canary and bauble, which wait on the thief.

**Not built, deliberately.** `FCHMP` — "Moby lossage" — is still not built;
milestone 4 recorded it and nothing here changes that. The trilogy's *Wizard of
Frobozz* wand, which its `I-GNOME` checks for before the gnome will show himself,
is Zork II content and does not exist in the mainframe.

**Seams left for later milestones: none.** Every exit these ten rooms declare
reaches a room that exists.
### The thief (#170)

The thief belongs to no milestone. `docs/games/dungeon.md`'s eight-milestone
breakdown never assigns him, and two milestones had already been built that
depend on him: milestone 1 declared the canary and the bauble and said plainly
that their ten points could not be walked to, and milestone 4 built the Treasure
Room and left it a room with a chalice in it and nothing to take the chalice back
from. He lands here, between milestone 5 and the walkthrough milestone 8 has to
pin, and he is filed at the end of this section rather than folded into a
milestone because he is not one.

**Where this departs from `Sources/Zork1/`'s thief, and why.** That thief is the
nearest thing in the repository to a working model of this one, and four of the
things he does are wrong here.

- **He does not free the trap door.** In Zork I the bar under it is the thief's
  doing and his death lifts it. In the mainframe the trap door bars itself for
  good and the chimney is the way home — recorded under milestone 1 above — so
  killing him changes nothing about the way out. His `onDefeat` is shorter than
  Zork I's by that one line.
- **His stiletto is not sharp.** Zork I makes it one of five blades that hole the
  river boat. Milestone 4 found that the mainframe punctures the boat on the
  broken sharp stick and nothing else, so this game carries no `sharp` trait at
  all, and the stiletto is a weapon and a weight and nothing more.
- **He starts nowhere.** `docs/games/dungeon-atlas.md` records `THIEF`'s start as
  *by code*, not in a room; Zork I stands him in the Gallery from turn one. Here
  the code is a rule: the first treasure lifted off the dungeon floor puts him
  into play, in the Treasure Room, standing over what he has already taken. A
  player who reaches the hoard without lifting anything gets him at the door.
- **His lair pays.** `TREAS` carries a room value of 25 and the chalice in it is
  worth 10 and 10, where Zork I gives the room nothing and the chalice half. The
  35 points milestone 4 declared for walking in are what he is guarding.

**Prose.** `docs/games/dungeon-prose-comparison.md` files `THIEF` as *minor* —
the mainframe has him holding "a bag" and the trilogy "a large bag", and nothing
else between the two differs — so the policy above takes the trilogy's line. His
presence line and his examine text are Zork I's, verbatim. The stiletto's
description is written fresh, because `STILL` carries a size in the source and
nothing else. The death line is adapted: Zork I's ends on a colon and leaves the
listing to whatever the player types next, which is a promise the turn does not
keep, so this one names what fell.

**Reconstructed, and labelled as such.** Two things about him are decisions
rather than findings, because the atlas carries his objects and his lair but not
his routine.

- **Where he will and will not go.** The roam daemon teleports, so the set of
  rooms it draws from has to do the work a walk would have done. He is kept out
  of the Land of the Living Dead, off the water, out of the Small Room and the
  Vault — which the atlas records with zero exits, so a thief dropped in either
  would be sealed in with the hoard — and out of the shrunken world under the tea
  table, which is reached only by eating. Above ground is a boundary rather than
  an exclusion.
- **He does not tidy up in front of a drawn sword, and he does not slip out of
  his own lair while you are standing in it.** Both are there because the
  alternative contradicts itself inside one turn. Daemons fire in name order, so
  the stash would put the chalice back on the floor and the theft would then
  announce having taken it; and the summons brings him home during the command
  stage while his own roaming carries him off again before the turn ends.

**Declared but not walkable: nothing, and for the first time nothing was left
over.** `maxScore` does not move. He scores nothing himself — `THIEF` and `STILL`
both carry no `OFVAL` or `OTVAL` — so the ceiling stays where milestone 6 left
it, at **560**. What moves is the walkable total. Milestone 1's canary (6 and 2)
and bauble (1 and 1) were the ten points every milestone since has had to
describe as still waiting; the route to them is him. A perfect playthrough of
everything built goes 550 to **560 of 560**.

### The broken egg (#178)

Milestone 1 built the egg's ruin as a swapped bird inside a surviving shell. The
mainframe swaps the shell too, and `docs/games/dungeon-atlas.md` has both halves:
`EGG` and `GCANA` leave the game together, `BEGG` arrives with `BCANA` already
inside it, and neither of the survivors carries an `OFVAL` or an `OTVAL`. That is
now what `Sources/Dungeon/` does.

**This entry records a gap closed rather than a departure taken.** The mainframe
behaviour is now reproduced. What is adapted is the prose around it.

- **`BEGG`'s examine text is written fresh.** The intact egg's description is
  Zork I verbatim and is entirely about the clasp and the hinge, neither of which
  survives being forced, so carrying it across would have described an object
  that is no longer there. Its room line — *"There is a somewhat ruined egg
  here."* — is the trilogy's, and `identical` under
  `docs/games/dungeon-prose-comparison.md`, so it is taken as it stands.
- **The line that names what the wreck holds is this game's.** Forcing the egg
  now ends the turn rather than falling through to the built-in open, because
  the object the built-in would have opened has left play — so the rule has to
  do the revealing itself.

**`maxScore` does not move**, and a perfect run still scores 560. Both survivors
are worth nothing, exactly as the mainframe has them. What changes is the price
of forcing it: twenty points rather than ten, the shell's ten joining the
canary's eight and the bauble's two. A player who forces the egg cannot complete
the trophy case at all — which is the mainframe's intent, and which milestone 8's
716-point walkthrough has to route around by going through the thief.

### A knocked-out villain takes no turn (#179)

An engine note rather than a mainframe one, filed here because both games it
touches are in this file. `GnustoMeleeCombat` and `GnustoActors` are independent
libraries that cannot see each other, so a thief battered into unconsciousness by
the first went on picking pockets under the second, on the same turn he was lying
on the floor. `Actor.isUnconscious` is now engine state that both consult.
Nothing in the mainframe changes. The dungeon stops contradicting itself.
### Milestone 7 — the Royal Puzzle

3 rooms in one region bundle, and one of them is sixty-four squares. The Small
Square Room hangs off the Treasure Room's east passage — the one seam milestone
4 left open — with the thief's note nailed up beside a hole in its floor. Down
the hole is the Room in a Puzzle. South of the anteroom, and also behind the
puzzle's steel door, is the Side Room. Each room came out with the number of
exits `docs/games/dungeon-atlas.md` records for it.

**The source calls it the Chinese Puzzle**, and signs it: `act3.199:700` reads
*"CHINESE PUZZLE SECTION (COURTESY OF WILL WENG)"*, and the gold card's own face
names Weng as the approving authority. Weng edited the *New York Times* crossword
from 1969 to 1977. The name "Royal Puzzle" is the trilogy's.

**The claim in the issue that is not true.** The issue says *"the card under a
block is confiscated if spent opening the second exit, so there is exactly one
correct order."* The confiscation is real — `CPSLT-OBJECT` calls
`<REMOVE-OBJECT <PRSO>>` unconditionally before it decides what to print
(`act3.199:896`), and nothing in the source ever puts `GCARD` back. But it is
**not an ordering problem**. It is an exclusive choice, and what is unique is the
correct *exit*, not the correct order:

- the **ceiling opening** at cell 10 costs nothing — push the good ladder into
  cell 11, stand under the hole, go up, and you keep everything you carry;
- the **steel door** at cell 52 costs the card, and the card is the only thing in
  the region worth points.

No sequence of moves opens the door and banks the card, so there is no order that
rescues it. The door is a bail-out, never a step on a winning line. What *is* a
hard one-way state change is `CPBLOCK` (`act3.199:802`): push any wall into the
square under the opening and the ceiling exit is destroyed for the rest of the
game — the flag is never cleared anywhere in the source — at which point the
door, and the forfeiture of the card, is the only way out. Both are pinned by
transcript tests.

**Where this departs from `Sources/Zork1/`, and why.** Zork I has none of this.
Zork III does, and that is a documented gap rather than a decision — see the last
entry below.

- **The grid is 8×8, and every value of it is the source's.** `CPUVEC`
  (`dung.355:3120-3184`) is 64 cells, row-major, one-based, with north = −8 and
  east = +1 (`CPEXITS`, `:3200`). The entire border is fixed marble, which is why
  the source's push routine needs no bounds check anywhere; the playable interior
  is the 6×6 inside it. `theGridIsTheSourcesGrid` checks every landmark the
  source names by number, because an off-by-one here would leave a puzzle that
  still played and could not be solved.
- **The transcription is corroborated from a second place in the source.**
  `CP-ROOM` hardcodes the entry cell's geometry in prose — marble north and west,
  sandstone east and south (`act3.199:829`) — and that agrees with the vector.
  `theEntryCellsProseAgreesWithTheVector` is that cross-check.
- **Diagonals are legal, which is why `CP` has nine exits and not four.** A
  diagonal step is refused only when *both* squares flanking it are walls: you
  may not cut a corner (`act3.199:735-740`). The shortest solution uses diagonals
  throughout.
- **Walls are addressed by compass side, not by material.** `CPNWL`, `CPSWL`,
  `CPEWL`, `CPWWL` (`dung.355:1377-1403`). There is no sandstone-wall object and
  no marble-wall object anywhere in the source, because which one you are shoving
  depends on where you stand. So `push north wall` is the source's phrasing, and
  issue #151's decorative-noun problem cannot arise here — the direction carries
  the whole meaning.
- **The room stops describing itself in prose after the first push.** `CPPUSH`:
  once a wall has moved, every look is a 3×3 diagram with `MM`, `SS`, `??` and
  blank (`CPWHERE`, `act3.199:837`). The diagram's *structure* is reproduced; its
  legend, like every other line here, is written fresh.
- **Two ladders, and one of them is a decoy.** `-2` reaches the ceiling and `-3`
  never does. The source goes further and will not acknowledge a ladder on the
  wrong side of you: the good one counts only to your east and the bad one only
  to your west (`CPLADDER-OBJECT`, `act3.199:770`). Both draw as `SS`.
- **`CPSOLVE` is dead.** The flag is set when you climb out and is read nowhere
  in any file; it scores nothing, so nothing here scores it either. `up` and
  `climb ladder` both leave by the ceiling and print the same line, but they are
  two code paths and not one: `up` falls through to the conditional exit, while
  `climb` moves the player itself. That used to mean the two described the
  arrival differently, because a rule had no way to ask for the `go` it would
  have performed — the engine issue it was worth turned out to be #201, and
  `enter(_:)` is the answer. `climb` calls it, so both paths now describe the
  Small Square Room as an entry.
- **The gold card is worth 25 and no room here is worth anything.** `GCARD` is
  `OFVAL 10 OTVAL 15`, declared inside a `<PUT <OBJECT …> ,OROOM <GET-ROOM
  "CP">>` wrapper at `dung.355:6324` rather than at top level. `CP`, `CPANT` and
  `CPOUT` carry no `RVAL` between them.

**Mechanics simplified or deferred.**

- **Object containment is room-granular, and the source's is square-granular.**
  `CPOBJS` is a 64-slot vector swapped into the room's contents on every step
  (`CPGOTO`, `act3.199:809`), so anything dropped stays in the square it was
  dropped in. Gnusto has one contents list per room. The card is therefore held
  offstage until the player first stands in its square, and a `reach` rule
  (issue #150) is what makes `take card` answer *"the card is squares away from
  you"* rather than succeeding from across the grid. The consequence not
  modelled: **an item dropped inside the puzzle can be picked up from any
  square**, where the source would make you walk back for it.
- **`ODESCO` on the gold card is dead text and is not reproduced.** *"Nestled
  inside the niche is an engraved gold card"* prints only for an object inside a
  container, and the card is never in one. There is **no niche** in the mainframe
  puzzle; the tell is a floor line at cell 37. The niche is Zork III's.
- **The rope is not modelled.** Tying a rope in the anteroom and climbing down
  drops the anchor in after you (`act3.199:1212`). The rope is a `DungeonHouse`
  item and this is a one-room-bundle milestone; the hole is a plain one-way exit
  instead, which is what the source's own outcome amounts to.
- **`push north wall` is not a verb row, and cannot be.** A verb pattern must end
  with its direction slot, so `["push", .direction, "wall"]` is a compile-time
  error from the `#verb` macro. The source's phrasing is bought back the other
  way: the four compass walls are real items, so the wordier sentence resolves to
  the core `.push` intent with a wall as its object, and that item's rule
  performs the shove. Both spellings end in one helper.
- **The sixteenth bundle hit the declaration-body stack limit again.** This is
  the failure `docs/games/dungeon.md` records as its eighth seam lesson and
  issue #174 files: peak bootstrap stack depth scales with the largest single
  declaration body, and a Swift Testing body runs on a cooperative thread with
  far less stack than `main`. Adding this region made the **whole suite** die
  with signal 11 and no message, while `swift run Dungeon` and any single test
  ran fine — the giveaway both times. The remedy is the same one milestone 5
  used: this bundle's `map` is two `@MapBuilder` properties and its `rules` are
  six `@RuleBuilder` ones, and the longest closure in it — the room description
  that *is* the grid — sits in a sub-builder of its own with its first paragraph
  factored out to a function. Worth saying plainly for whoever adds the
  seventeenth: the limit is real, it is hit by *adding a bundle* rather than by
  writing one badly, and the error names nothing.

> **Resolved.** Issue #174 is fixed: `Bootstrap.build` runs on a 16 MB thread the
> engine sizes rather than on whatever stack it was called from, and
> `GNUSTO_STACK_REPORT=1` prints what a boot used. The measurements this note and
> the two below were guessing at are now readable — a cooperative thread gives
> **512 KB**, and Dungeon's bootstrap peak is **355 KB** in debug and 90 KB in
> release. The record above stays as written: it is what was known at the time,
> and the diagnosis it reached was half right in a way worth keeping.

**Prose.** Every line is written fresh. `CP`, `CPANT` and `CPOUT` appear in no
bucket of `docs/games/dungeon-prose-comparison.md`, and neither do any of the
region's objects, so the whole region is case 3 of the prose rule. There is more
text here to not reproduce than in earlier milestones: the source's puzzle is
wordy by mainframe standards, and the card carries a full framed security pass,
the note a signed letter from the thief, the diagram a legend. What crosses over
is the fact each string carries.

**A gap in the atlas, filed rather than fixed.** The prose-comparison document
says the Royal Puzzle is *"content the trilogy never carried over"*. Zork III
carried it over — it is that game's centrepiece. The generated atlas names Zork
I/II/III in its provenance line and `bin/atlas/build_atlas.py:43` loads all
three, yet **the string `Zork III` appears nowhere in the generated document**:
every trilogy cell in 196 rooms and 253 objects reads `Zork I`, `Zork II` or `—`.
So "no counterpart found" here may mean "no counterpart was looked for", and the
same doubt covers the Endgame and the Dungeon Master. It cannot be settled from
the repository, because the ZIL sources are deliberately not vendored. Nothing in
this milestone turns on it: writing fresh is what the committed policy directs
today. The atlas is generated and is not edited by hand, so the fix belongs in
the builder.

> **Resolved.** Issue #184 is fixed, and the doubt above was well placed: it was
> a pairing failure, not a historical one. The `historicalsource/zork3` checkout
> carries **two** complete generations of the game — the one `zork3.zil` names,
> and an older set no master file mentions — and the builder globbed `*.zil`, so
> it read both. Every Zork III room and object was therefore declared twice under
> the same `DESC`, `pair_by_name` threw all of them out as ambiguous, and with no
> name pairs to seed it the graph pass had nothing to grow from. Zero of 57 room
> names and zero of 123 object names survived. The game could not pair with
> anything, and never had.
>
> The builder now loads what each game's own master file names. `CP` pairs with
> Zork III's `CP`, *Room in a Puzzle*, and `CPANT`, `CPOUT` and the ladder pair
> too. Across the atlas the recovery is 117 → 128 rooms and 135 → 152 objects.
>
> **This milestone's prose is unaffected**, which is worth stating rather than
> assuming: `CP`, `CPANT` and `CPOUT` are still in no bucket of the
> prose-comparison document. Zork III describes those rooms from a room function
> rather than from `3dungeon.zil`, so there is still no trilogy line to set
> against the mainframe's, and case 3 still holds. What changed is that it is now
> *checked* rather than merely unrefuted. A source the generator loads and never
> matches is a hard failure from here on — see `unpaired_games`.

**Declared but not yet walkable: nothing.** `maxScore` goes 560 → **585**. The
thief landed between milestone 6 and this one and closed the last gap, so the
sentence every milestone since the first has had to carry — *the ten still
missing are milestone 1's canary and bauble* — retires here. A perfect
playthrough of everything built scores **585 of 585**.

**Not built, deliberately.** `FCHMP` — "Moby lossage" — is still not built. All
nine of `CP`'s exits resolve to it under a flag that is permanently false, which
is the source's idiom for *"the room function owns every direction"* rather than
a destination anybody reaches.

**Seams left for later milestones: none.** Every exit these three rooms declare
reaches a room that exists.

### Milestone 8 — the ceiling's last 131 points, and where they are

No rooms land here. This entry records what milestone 8 turned out to be, because
the issue that describes it (#141) understates it by two regions and the
understatement is not obvious from the atlas.

**The claim in the issue that is not true.** #141 says milestone 8 is *"31
`RENDGAME` rooms worth 100 points"* and that `maxScore` must balance at 691. The
ceiling has been 716 since #167. Milestone 7 left it at 585. **585 + 100 = 685**,
and the missing 31 are main-dungeon object values in rooms nothing has built:
`PAL3` the red crystal sphere (10+5) in the Sooty Room, `PALAN` the blue crystal
sphere (10+5) in the Dreary Room, and `DSTMP` the Don Woods stamp (0+1) affixed
to the free brochure. Every one of the main dungeon's 115 room values is already
in the award table, so the shortfall is entirely objects.

**The 31 are a prerequisite for the 100, not a parallel errand.** `SCORE-BLESS`
(`rooms.394:794`) arms the endgame's herald only once the score has reached
`SCORE-MAX`, and the herald is what makes the Crypt's marble door open at all
(`CRYPT-OBJECT` tests `END-GAME!-FLAG`, `act4.231:39`). A reconstruction stalled
at 585 can never enter the endgame, however completely the endgame is built.

**Nine rooms are unbuilt**, and eight of them are not endgame rooms: `TOMB`,
`PRM`, `PALAN`, `SPAL`, `SLID1`, `SLID2`, `SLID3` and `SLEDG`, plus `FCHMP`,
which stays unbuilt for the reason milestone 7 gave. Two of the eight sit behind
seams earlier milestones declared and named — `LLD2` east and `MTORC` west — and
four of them are the coal chute that milestone 3 stood in for with a single
one-way drop into the Cellar, saying at the declaration site that those five
rooms belonged to a later milestone. They belong to this one.

**Where `Sources/Dungeon/`'s slide departs from the source, and why it still
does.** `SLIDE`'s `down` is `SLIDE-EXIT` (`act3.199:1179`): with a rope tied to
the timber it drops you into `SLID1`, hanging in the chute, with a fuse whose
length is `100 / your carried weight` before your grip fails and you land in the
Cellar anyway; without the rope it is the plain fall the reconstruction already
has. So the shortcut is the source's own unroped outcome and is not wrong today —
it is incomplete, and what it leaves out is the only route to the red sphere.

**`maxScore` does not move.** It stays at 585 and a perfect run still scores 585
of 585. This entry adds no content; it corrects the number the remaining work is
aimed at and says what that work is.

### Milestone 8, part one — the palantir wing and the free brochure

7 rooms in one region bundle, 2 items added to an existing one, and the last
thirty-one points the main dungeon has to pay. The Tiny Room is west of the Torch
Room, the seam milestone 3 declared and named at its declaration site. The Dreary
Room is behind an oak door with a keyhole on each side of it and the key in the
far one. The rest hangs off the coal chute the Slide Room has always had a hole
for: three stretches down to a ledge, and south of the ledge the Sooty Room. Each
room came out with the number of exits `docs/games/dungeon-atlas.md` records,
`PWIND` excepted — see below.

#### Prose

Case 3 throughout — written fresh — **except for two lines the issue that
specified this region did not expect to exist**. It says none of this content
appears in any bucket of `docs/games/dungeon-prose-comparison.md`. That is true
of all seven rooms and of every fixture in them. It is not true of the two
treasures: `PAL3` and `PALAN` are both filed `substantial`, so case 2 applies,
and the trilogy's lines were checked against the atlas before being taken.

- **The blue sphere.** Zork II: *"In the center of the table sits a blue crystal
  sphere."* It asserts a table, and `PTABL` is in `PALAN`, so it agrees with the
  atlas and stands as written.
- **The red sphere.** Zork II: *"There is a beautiful red crystal sphere here."*
  It asserts nothing, so there is nothing to check.

That also settles a question the issue raised and left open. Both mainframe lines
are missing their article — *"There is blue crystal sphere here."* — and the
issue notes the quirk is authentic and almost certainly not worth adapting. The
committed policy answers it without anyone having to decide by taste: the
trilogy's are the lines this game takes, and they have the article.

**Every other line here is this project's own words, including the refusals.**
The issue quotes the mainframe's strings throughout — "The lid falls to cover the
keyhole.", "These are apparently the wrong keys.", "Perhaps if you were
diced....", "Ok, but you know the postal service...", and a dozen more — as the
specification of what each line has to *mean*. None of them is reproduced. No
licence grant has been located for the 1981 MDL, so its text is off limits
however short and however functional the line, and the rule does not bend for a
four-word refusal. What crossed over is the behaviour each string reports.

The brochure's Mock-Turtle curriculum — Ambition, Distraction, Uglification and
Derision; Reeling and Writhing; Mystery, Ancient and Modern; Seaography;
Drawling, Stretching and Fainting in Coils; Laughing and Grief — is Lewis
Carroll's and is public domain. It crosses over because it is the whole joke of
the object. Every framing sentence around it is this game's.

#### Map topology

- **`PWIND` is not an exit, and it is not one item.** The source files the barred
  window in *both* `PRM` and `PALAN` under `#!#!#`, a direction atom no player
  input can produce; that gives the window scope on both sides without giving it
  a walkable direction. Here it is a scenery item in each room, which is the
  shape `DungeonMirror` already uses for the two faces of one mirror passage. So
  the atlas's exit counts of 4 for `PRM` and 3 for `PALAN` come out as 3 and 2
  declared exits, and the missing one is the pseudo-direction in both cases.
- **`SLEDG`'s `up` goes to `SLID2`, not `SLID3`.** The source's own asymmetry,
  reproduced: climbing out of the wing is one stretch shorter than climbing in.
- **`SLIDE`'s `down` is now `SLIDE-EXIT`.** A dynamic exit rather than a
  conditional one, because there is no refusal in it: the chute always takes you,
  and what the rope decides is whether you land in `SLID1` hanging or in the
  Cellar on your back. Milestone 3's plain drop was the source's own unroped
  outcome and remains exactly that.
- **The Slide Room lost its static description** and gained a `describe` rule on
  the host, because whether a rope is tied off at the head of the chute is a fact
  that paragraph now carries. Same shape as the Grating Room, milestone 4.

#### Mechanics — now modeled

- **The oak-door puzzle entire.** Open the near lid, slide the welcome mat under
  the door, put one of the four `PALOBJS` into the near keyhole to punch the key
  out of the far one, lift the mat to get the key off it, empty the near keyhole,
  unlock, open, go north. Both of the source's soft traps with it: `PCHECK`'s lid
  falling on the second tool taken while it stands open, and the key removed from
  the game for good when it is punched through with no mat under the door.
- **The four `PALOBJS` are a trait, not a list.** `TraitKey<Bool>.keyholeTool`,
  declared in `Systems.swift` beside `.openFlame` and for that trait's stated
  reason: the screwdriver is `DungeonDam`'s, the skeleton keys
  `DungeonAboveGround`'s, the broken sharp stick `DungeonRiver`'s and the rusty
  iron key the wing's own, so a list would have had to live on the host and the
  whole puzzle would have followed it there.
- **The grip clock.** `100 / carried weight`, floored at two turns, set at the
  moment of the descent and cancelled outright by reaching the ledge. Travelling
  light is what buys the turns, which is the source's arithmetic read the way it
  reads.
- **Anything let go of in the chute is lost to the Cellar**, and letting go of
  the rope takes you with it.
- **The scrying cycle.** Blue → red → white → blue, one way, fixed, and nothing
  else: no teleport, no score, no combination, no third-sphere effect. Stated
  plainly because assembling the three palantirs is the obvious guess and it is
  wrong.
- **The brochure's post.** `send for brochure` from anywhere, the Kitchen arms a
  three-turn clock and re-arms it on every entry until it fires, and the knock is
  heard wherever the player is standing — the Land of the Dead included. It is
  the one audible line in this game deliberately left without an
  ``Earshot``: a mail-order catalogue that finds you anywhere is the source's own
  joke, and gating it would be correcting a joke.

#### Mechanics simplified or deferred

- **`TIMBER-TIE!-FLAG`'s global scope is not reproduced.** In the source the flag
  is not room-scoped, so a rope tied to the timber in the Royal Puzzle's
  antechamber also turns the Slide Room's `down` into a rope descent — with no
  rope visible anywhere in the Slide Room. Here the anchor has to be in the Slide
  Room and on the ground. The reason is the standard this project holds every
  other line to: a rope descent in a room with no rope in it prints a paragraph
  that is not true of where the player is standing, which is the one defect the
  play-test method exists to catch. The mechanics contract protects topology,
  puzzle logic and values; the scope of a flag is none of those. What is lost is
  a shortcut nobody would find on purpose. What is kept is the source's own
  requirement that the anchor be on the ground rather than in your hands.
- **`SROPE` is not reproduced as a separate object.** The source needs a second
  rope because its `ROPEBIT` rooms have no way to name the coil tied at the top;
  this engine does, because the coil is in the player's hands the whole way down
  and a held item is always in scope. Four more scenery objects would also have
  cost more bootstrap stack than the seventeenth bundle had left; see the hazard
  note below.

  **Corrected 2026-08-24.** This entry used to add that the coil stays in hand
  while it is tied *"exactly as it already does at the Dome Room's railing"*, and
  the railing's half of that was a defect rather than a policy — see the
  milestone 3 entry. The chute's half stands and is not the same fact: you are
  hanging on that rope, `ropeSuspendsYou` refuses to let go of it, and letting go
  deliberately drops you into the Cellar. A rope you are hanging from is in your
  hands. A rope tied to a railing twenty feet over your head is not. (#286)
- **One rope, one knot.** Milestone 8 gives the rope a second place to be tied,
  and the two are mutually exclusive: rigging the chute refuses while the Dome
  Room's railing still holds it, and vice versa. The source needs no such rule
  because its `TIMBER-TIE!-FLAG` is global and it simply does not care; here the
  alternative is a Slide Room whose paragraph reports a rope that is forty rooms
  away, which is the same defect this milestone declined to reproduce two
  entries up. The cost is an ordering the map already forces — down the rope
  into the Torch Room and the Tiny Room first, then round to the chute.
- **`GBROC` has no equivalent, so `brochure` is a word before it is a thing.**
  The source carries a global "free brochure" object that gives the noun scope in
  every room; Gnusto has no such facility, and an item that is nowhere is not in
  scope. `send for brochure` is therefore a literal syntax row rather than a verb
  with an object slot — `Intent/answerWell`'s shape exactly, and for its reason.
  The cost is that `examine brochure`, typed after reading the leaflet and before
  the brochure has come, answers "You can't see any such thing." That is true of
  the world, and it is not the noun-answering defect it resembles: the leaflet is
  a document naming a thing that does not exist yet, not a room description naming
  a thing that does.
- **The mailing label has no login name in it.** The source interpolates the
  player's and addresses the brochure to them "c/o Local Dungeon Master, White
  House, GUE". This engine has no login name, so the label reads *The Adventurer,
  c/o Local Dungeon Master, White House, GUE*. The joke is the address, and the
  address survives.
- **Scrying searches a named set of rooms rather than asking an object where it
  is.** The source asks `,OROOM` and gets an answer; Gnusto exposes containment
  only as "is this item in *that* room", so `Dungeon.scryableRooms` is the set
  searched — the thief's prowl, plus the wing's seven, the Dingy Closet where the
  white sphere starts, the Cage, and the Living Room. A palantir left anywhere
  else reads as darkness, which is the source's own answer for a palantir with no
  room. A general fix belongs in the engine, not here.
- **`SPAL` gets a crack the source does not have.** Its description names "a very
  narrow crack in the north wall" and `PCRAK`, the only crack object, is filed in
  `PALAN` — so `examine crack` in the Sooty Room finds nothing in the source.
  Every printed noun must answer, so the Sooty Room has one of its own. The two
  cracks are a matched pair of hints (the stove's red glow is the glow that lights
  the Dreary Room) and the two rooms are **not** connected.
- **The Don Woods stamp is displayed as *postage stamp*.** A capitalised display
  name warns at bootstrap unless it is `properName`, and a stamp is not a person —
  milestone 6 settled that for the Flathead stamp by putting the name in the
  adjectives, and this follows it. There is a second reason: the Library's stamp
  is already displayed as *stamp*, and two treasures under one display name would
  have the parser asking which stamp you meant every time both stood in the
  trophy case.

#### Scoring

`maxScore` ratchets 585 → **616**, and 616 is `SCORE-MAX`: the main dungeon is
complete. Three objects and no room value — not one of the seven new rooms
carries an `RVAL`, so the award table does not move at all.

| | find | case |
|---|---:|---:|
| blue crystal sphere (`PALAN`, on the table in the Dreary Room) | 10 | 5 |
| red crystal sphere (`PAL3`, in the Sooty Room) | 10 | 5 |
| Don Woods stamp (`DSTMP`, in the free brochure) | 0 | 1 |

Every point is walkable, and the thirty-two treasures the mechanics contract
counts are all declared now.
`theMainDungeonCanNowPayItsWholeSixHundredAndSixteen` holds the figure,
`heCovetsEveryTreasureTheCaseScores` holds the roster at 32, and the bootstrap
raises no award-table warning.

This matters beyond arithmetic. `SCORE-BLESS` (`rooms.394:794`) arms the
endgame's herald only at `SCORE-MAX`, and the herald is what makes the Crypt's
marble door open at all. Until this milestone the reconstruction could not have
entered the endgame however completely the endgame was built.

#### Hazard #174, for whoever adds the eighteenth bundle

It bit again, exactly as the issue predicted, and it is worth recording what
did and did not move it. Adding this bundle put the whole test process over the
bootstrap stack limit — `signal 11`, no message, while `swift run Dungeon` and
the 725-turn walkthrough were fine, because a Swift Testing body runs on a
cooperative thread with far less stack than `main`.

**Splitting declaration bodies bought less than milestone 7's note implies.**
Ten of them were cut in half — `Dungeon.coreRules` into three, `Maze.map`,
`Temple.rules`, `River.rules`, `River.map`, `Dam.rules`, `House.rules`,
`CoalMine.map`, `AboveGround.map` and `AboveGround.rules` — and the process
still died. What settled it was **four scenery objects**: with them the
bootstrap crashed, without them it did not, and one object plus four `onEnter`
rules in their place crashed too. So the limit is a budget over the *whole*
declaration surface, not a ceiling on the largest body, and the splitting is
worth doing because it lowers the peak rather than because it raises the roof.
The eighteenth bundle should assume it has very little room and count entities,
not lines.

> **Resolved**, as milestone 7's note above records. The eighteenth bundle's
> reading of the limit — a budget over the whole declaration surface — was the
> right one; what it could not do was measure it.

#### The thief

His prowl went 107 → **108**, and it gained exactly one of the wing's seven
rooms. The source marks `RSACREDBIT` on the Dreary Room, all three chute
stretches, the Slide Ledge and the Sooty Room; every one of them earns it, since
five are reached only by hanging on a rope and the sixth is behind a locked door
whose key starts on the wrong side of it. `PRM`, the Tiny Room, carries no such
bit and is in the set — it is a plain step west of the Torch Room, and a player
standing in it working a lock with a screwdriver is exactly the sort he visits.

One more room is one more draw from the same seeded stream, so
`theThiefProwlsAndLiftsWhatYouAreCarrying` was re-pinned from seed 18 to seed 36.
Milestone 7 paid the same toll for the same reason.

### Milestone 9 — the Endgame

The last region: the 31 rooms `dung.355` flags `RENDGAME`, worth 100, plus the
Tomb of the Unknown Implementer that is their front door. One bundle, the
eighteenth, and with it `maxScore` reaches **716** — `SCORE-MAX` plus
`EG-SCORE-MAX`, everything the game can pay.

#### Prose

Case 3 throughout, and for once with no exception to name. Not one of the
thirty-two rooms and not one of the objects in them appears in any bucket of
`docs/games/dungeon-prose-comparison.md`, which was checked rather than assumed.
Every line is this project's own words in the Infocom register.

**The Zork III caveat bears hardest here and is still unresolved.** The atlas
pairs nothing at all against Zork III — the string does not appear in the
generated document, across 196 rooms and 253 objects — even though
`bin/atlas/build_atlas.py` loads the corpus. Zork III is where the trilogy put
its own endgame, its own Dungeon Master and its own Guardians. So "the trilogy
never carried this over" is **unproven** for every line of this region, and it is
not asserted anywhere in the committed prose. Writing fresh is correct either
way, because that is what the policy directs for content with no located
counterpart. The fix belongs in the atlas builder; milestone 7 filed the same
observation about the Royal Puzzle.

> **Resolved, and it cost this region four lines.** Issue #184 is fixed —
> milestone 7's note carries the diagnosis. The caveat did bear hardest here: ten
> of these rooms and fifteen of their objects pair with Zork III once the builder
> stops reading that checkout's stale second generation. *"Checked rather than
> assumed"* above was true of the document and false of the world, which is the
> failure mode worth remembering: the check was run, and the thing it ran against
> was empty.
>
> Most of the pairs still change nothing, because a pair only reaches the prose
> rule when **both** sources carry text, and Zork III describes the mirror box,
> the sundial, the panels and the corridors' twins from a room function. Four
> reach it, and all four are now taken from the trilogy rather than written fresh:
>
> - **The Dungeon Master's listing line is `identical` across the two sources**,
>   so it is theirs verbatim — *"The dungeon master is quietly leaning on his
>   staff here."* His examine text stays this project's own; ZIL gives him none.
> - **`ECORR` and `WCORR` are `substantial`**, and Zork III's line was checked
>   against the mainframe exit table before being taken: it says each corridor
>   turns west (east) at both ends, and each has exactly the two exits that make
>   that true.
> - **`NIRVA` is `substantial`.** Both sources furnish the Treasury — chests,
>   zorkmids, statuary, an annotated map, FrobozzCo stock certificates on a desk —
>   where this game had heaped it undifferentiated. The trilogy's furniture is
>   taken; the sealed-room beat that ends the game stays ours.
>
> **And a plain error, found the same way.** All four prison corridors called the
> walls *bare stone*. `dung.355` calls them polished marble, and `act4.231`'s
> `SCORR-ROOM` says so for the two the dungeon file does not describe. They are
> marble now. It was never a decision — it was a line nothing had been in a
> position to check.

#### Map topology

- **`FROBOZZ` is `FCHMP` by another name.** Every row the atlas records as
  `conditional (FROBOZZ)` is a `CEXIT` on a flag nothing ever sets — the
  mainframe's idiom for "the room function owns this direction", exactly as
  `FCHMP` is in the Royal Puzzle. None of them is a declared exit here: they are
  `DungeonEndgame.hallwayRules`, a `before(.go)` rule at stage 3. So the declared
  exit counts are short of the atlas's by precisely the `FROBOZZ` rows, and
  milestone 7's `CP` is short of its nine for the same reason.
- **The ten narrow rooms are reached only by the diagonal slip**, never by the
  exit table. The atlas says as much already: `MRDE`, `MRDW`, `MRGE` and `MRGW`
  have nought exits, and none of the ten is listed as any room's destination.
- **`TOMB` is not a `RENDGAME` room and carries no `RVAL`.** It is the front door
  rather than part of the house, and it is dark and unsacred, so the thief could
  walk into it if he could reach it.

#### Mechanics — now modeled

- **The herald and its score test.** `SCORE-BLESS` arms it at `SCORE-MAX`, with
  the ten a death costs forgiven — so the test is `score + 10 × deaths >= 616`.
  Fifteen turns later a cloaked wraith welcomes you and sets `END-GAME!-FLAG`,
  and until it does, every verb on the Crypt's marble door falls through to
  `HEAD-FUNCTION` and kills you.
- **The crypt transition.** Shut the door, put the light out, and three turns
  later your hands are empty but for a lamp refilled to 350 turns and switched
  off, and the elvish sword. The thief's three daemons stop for good; the sword's
  glow daemon starts. Lit when the fuse fires, it re-arms; left, it does not.
- **Death past the crypt is final**, whatever the death count.
- **The mirror box entire**: bearing in 45-degree steps, five berths along the
  channel, the pole in its four positions, both mirrors, the openable mirror's
  seven turns and the pine end's five, the four coloured panels, the diagonal
  slip past an end-on box, and all four of the Guardians' conditions.
- **The examination**: three questions drawn from eight without replacement,
  re-asked every second turn, five wrong answers to one of them ending it for
  good.
- **The prison**: eight cells on a carousel, a sundial that picks one and a
  button that docks it, and a Dungeon Master who follows you, refuses to enter a
  cell, and carries out an order in the room he is standing in.

#### Mechanics simplified or deferred

- **`INCANT` is dropped.** The source's shortcut back into the endgame is a
  hashed word pair keyed to the player's login name. This engine has no login
  name and no analogue; the transition's own paragraph says the knowledge is
  given rather than naming a word the player could type and find inert.
- **The quiz answers are `answer X` and `say X`, not bare words.** This is
  `Intent/answerWell`'s shape and a deliberate narrowing of what #187 proposed. A
  bare `["skeleton"]` row would put *skeleton* into the verb vocabulary, where
  the maze already has a skeleton and the forest a set of skeleton keys; `forest`,
  `flask` and `knife` are the same problem. The cost the issue names is real and
  unchanged: **an answer outside the eight is a parse failure rather than a wrong
  answer, and a parse failure costs no turn.**
- **`set dial to four` is not reproduced; the dial steps.** Naming a number
  needs one object per number, because this engine hands a rule the *item* a
  noun resolved to and never the word the player typed — and eight more objects
  is more than the eighteenth bundle had, which is the hazard note below rather
  than a design preference. `turn dial` advances it one and reads out where it
  stands, so choosing cell four is three turns of the dial instead of one
  sentence. The puzzle is unchanged: choose a cell, dock it, be inside it when
  it leaves.
- **The heads' large case is not reproduced either.** The mainframe sweeps every
  valuable you carry and every valuable loose in the Tomb into a case that
  appears in the Living Room. There is no case here for the same reason there
  are no numerals, and the death line does not name one — a line that promised a
  case would send a resurrected player to look for something that is not there.
  What is kept is that the valuables go.
- **The cell carousel is modeled as three rooms and two numbers**, which is what
  the atlas already carries: `CELL` docked, `NCELL` cell four riding away,
  `PCELL` any other cell riding away. The source shuffles per-cell object lists
  between them; what is left out is "objects left in a cell ride with it".
- **`MIRROR-DIR?`'s hard-coded north exit is not reproduced.** In the source
  `MRA IN` enters a box standing one room *north* while `MRAE WEST` enters one
  standing in `MRA` itself, which cannot both be true of one geometry. Here you
  step into the box from any room beside it — the hallway to its south or either
  flanking narrow room — and only where mirror #1 is actually facing you. Both
  spellings survive; the inconsistency does not.
- **`MRGO`'s blocked branches do not fall through to `NOGO`.** The source appends
  "There is a wall there." after the mirror message, which reads as two refusals
  for one move. One refusal here, and it says which part of the box is in the
  way.
- **The mirror is the way in and the pine end is a way out, which is the
  source's asymmetry and not a defect.** `MIRIN` (`act4.231:425-429`, and Zork
  III's `3actions.zil:994-1003`, which carries the routine verbatim) admits you
  through mirror #1 alone; `MIROUT` lets you out through either opening. What
  reconciles them is the pine end shutting behind you as you go — *"As you leave,
  the door swings shut."* — and that line was **missing here until #233's fourth
  pass**, which is what let a player stand outside a box with a wooden end swung
  wide that would not admit them. Reproduced now, with `MIRIN`'s three refusals
  in place of one denial about the whole box: a mirror blocks your way, the panel
  is closed, or the structure blocks your way. `MirrorBox.openFace(at:)` names
  the part standing open and `BoxFace.admitsEntry` says whether it is a way in —
  one query and one fact about the face, since the descriptions ask the first and
  the steps ask the second. Only the mirror admits entry, and that is stated
  where the citation is.
- **`enter box` is the `in` direction under another name**, as `MRC`'s `ENTER`
  row is the box. It goes through the same `stepIntoTheBox()`, so it refuses for
  the same reasons.
- **One pole, not `LPOLE` and `SPOLE`.** `POLEUP` is the state, and a `describe`
  rule reads it.
- **One compass instrument, not `ARROW` and `ROSE`**, because the arrow is the
  pointer and the rose is the dial it turns over. The five floor roses `ROSEBIT`
  carries in the hallway are not reproduced at all, and the hallway's description
  does not name one.
- **The bronze door is one object that moves.** `ODOOR` stands between the South
  Corridor and the docked cell, and between cell four and the Treasury; here it
  is hidden until cell four docks and follows the player into the cell that
  carries them out.
- **There are no grues in the Crypt.** This is the one room in the game whose
  solution is to stand in the dark on purpose, and `DangerousDark`'s stock
  schedule starts rolling dice on the third dark turn — against a three-turn fuse
  that re-arms if the room is lit when it fires. A player who shut the door with
  the lamp still burning could be eaten for doing exactly the right thing. The
  daemon stops when the door closes and starts again if the door is opened on
  this side of the transition, so the main dungeon's dark is as dangerous as it
  ever was.

#### Scoring

`maxScore` ratchets 616 → **716**, and every point of the hundred is a room
value: no endgame object carries an `OFVAL` or an `OTVAL`, so the treasure roster
does not move and stays at thirty-two.

| room | | how it is paid |
|---|---:|---|
| Crypt (`CRYPT`) | 5 | `scoring.visit` |
| Top of Stairs (`TSTRS`) | 10 | `awardOnce`, inside the transition |
| Inside Mirror (`INMIR`) | 15 | `scoring.visit` |
| Dungeon Entrance (`FDOOR`) | 15 | `scoring.visit` |
| Narrow Corridor (`BDOOR`) | 20 | `scoring.visit` |
| Treasury of Zork (`NIRVA`) | 35 | `afterEachTurn`, and it ends the game |

**Three of the six cannot be a `scoring.visit`, and it is not the three #187
names.** The issue says `TSTRS` and `CRYPT` are the two that cannot fire
`onEnter`. That is true of the source and false of this engine: `TOMB` NORTH →
`CRYPT` is a door exit, so walking in fires `onEnter` normally, and the marble
door cannot open before the herald — so the Crypt is an ordinary first-visit
award and is declared as one. What the issue misses is the other direction. The
rule that mattered is the general one `docs/games/dungeon.md` already states: *a
room reached by anything but walking never passes through `onEnter`*. The mirror
box's rooms are all reached by a rule assigning `player.location`, so `INMIR`
cannot be a visit — and neither can `FDOOR`, which is walked into from the
hallway *and* stepped into out of the pine end.

**Two of the six, since #201, and the table above is the corrected one.** The
sentence that made it three was a fact about the engine rather than about this
game, and the engine changed: `enter(_:)` is a rule-driven move that *does* run
the destination's `onEnter` rules, and every rule that walks a player around the
mirror box now uses it. So `INMIR` and `FDOOR` are ordinary `scoring.visit`
awards, and the two `Bool`s that stood in for them are gone. `TSTRS` and `NIRVA`
still pay themselves, and both by choice: the crypt's transition is a teleport
rather than a walk, and the Treasury's award has to land after the room has
described itself.

The total is checked against the table at bootstrap and there is no warning on
stderr. `theEndgamesHundredIsAllRoomValue` holds each of the six.

#### Hazard #174, for whoever adds the nineteenth bundle

**It bit, and what it turned out to be is worse than milestone 8 thought.**

Milestone 8 measured the limit as a budget in entities and found that removing
four scenery objects moved the suite from crashing to passing. That reading held
here up to a point: this bundle declares 32 rooms, 35 items and one actor, and
three scenery objects added late — two doorways and a pit — took the suite from
green to `signal code 10` and then `signal 11`, no message either time, while
`swift run Dungeon` and the 815-turn walkthrough stayed fine. Removing three
objects brought it back.

**But the boundary is not a boundary.** The same commit that passed four
consecutive full runs later failed three consecutive ones with nothing changed
between them, and `origin/main` on the same machine passed throughout. So the
eighteenth bundle does not sit under the limit or over it — it sits **on** it,
and whether a given run dies depends on something outside the source. Reading a
single green run as headroom is what this note exists to prevent.

Two things follow, and the second is the load-bearing one:

- **Splitting bodies is not the remedy.** Every `map`, `rules` and `timers`
  member in this bundle is already a sub-builder, and further splitting bought
  nothing — the same result milestone 8 reported.
- **Surface had to be surrendered to get a usable margin**, and each thing
  surrendered is named at its declaration site. Three objects were unreachable
  and cost nothing: the box as seen from the Guardians' own hallway room, which
  kills you before any description prints; the box as seen from `MRD`, which is
  only ever passed through inside the box; and a second pair of Guardian statues
  in a room whose description does not name them. **The eight numerals cost
  something**, and they are the entry above about `set dial to four`.

**The nineteenth bundle should assume there is none.** Nothing further can be
added without an engine fix for #174, and this milestone's own findings from
`/simplify` — a dozen of them, all sound — could not be applied for the same
reason: each attempt to land them put the suite back over the edge. They are
listed in the pull request rather than in the code, which is not where anybody
wants them.

> **Resolved, and one correction to the record.** Issue #174 is fixed — the
> bootstrap runs on a 16 MB thread the engine owns — and the eight numerals are
> back, so `set dial to four` is the source's spelling again. But the margin was
> never as thin as this note believed: measured on the current toolchain, Dungeon
> uses **355 KB of the 512 KB** a cooperative thread gives, and the full suite
> passes repeatedly with the numerals restored *and* the fix disabled. The
> likeliest explanation is that the compiler moved between then and now. Which is
> the sharpest form of the lesson: a cliff nobody can measure is indistinguishable
> from one that has already moved, and eleven declarations were paid to it.

#### The thief

His prowl does not move. Every endgame room is behind the crypt's transition,
which switches his three daemons off for good before the player sets foot in one,
so there is nothing for the exclusion list to exclude. The Tomb is the one room
this milestone adds that he could otherwise reach, and it is not in the set:
`LLD2` is not in it either, because the Land of the Living Dead is sacred ground,
so the Tomb sits behind a room he can never stand in.

#### The sword's warning, and four greetings

Two deliberate departures landed with the second pass over #233. Both replace a
line the sources agree on, which is why they are here rather than only in a doc
comment.

**The sword warns about a blade you can see, not only one in your hand.**
`I-SWORD` (`1actions.zil:3853`, and the MDL's `act1.254:1996` before it) gates
the demon on `<IN? ,SWORD ,ADVENTURER>` and **disables it outright** when the
sword is not held, so the original never reports a change in the danger on a turn
that only changed your grip. This game's daemon did something worse than either:
it read an unheld sword as a sword in no danger, so setting the blade down one
berth from the Guardians printed "The blue light goes out of the sword" and
picking it up printed the warning again. It now gates on `isVisible`, which is
one room wider than the source and is `DungeonHouse.timers`' rule for the
lantern: a blade lying on the floor of the room you are standing in is a blade
you can watch. A blade you have walked away from goes quiet rather than
announcing anything, because nobody is there to see it. Examining the sword also
reports the glow, which `SWORD-FCN` (`1actions.zil:2437`) does too — except that
the source replaces the description with it and this game appends, because the
mainframe's blade has a description worth keeping.

**Four actors answer a greeting hostilely, where both sources have them bow.**
`V-HELLO` (`gverbs.zil:726`) answers a greeting to any `ACTORBIT` object with
*"The troll bows his head to you in greeting"*, and the MDL's `HELLO` is the same
routine; only the troll and the thief get second lines, for when they are down
(`1actions.zil:764`, `:1955`). Gnusto's own placeholder — "The troll nods, and
says nothing." — is the same courtesy in a flatter voice, and the play-test round
filed it as a line asserted from a creature mid-swing. So the troll, the cyclops,
the thief and the robot each answer as what they are, in the source's two states
where the source has two. The thief keeps his courtesy, because his courtesy is
the point of him; the robot does not nod, because it is a machine.

**This is a departure from a line both sources share, and the reason for it is a
second divergence rather than a fidelity argument.** The first draft of this note
claimed the source's own troll is perpetually mid-swing, so its bow was already
odd. That is false. `I-FIGHT` (`1actions.zil:3810`) has a villain strike only
when `FIGHTBIT` is already set — the player has engaged — or when the villain's
own `F-FIRST?` branch says so, and the troll's is `<PROB 33>` (`:701`), the
thief's `<PROB 20>` (`:2063`). An unprovoked source troll therefore spends two
turns in three standing and blocking, which is exactly what its listing line
says it does, and the bow is not incongruous there.

It *was* incongruous here, because this game's troll used to be far more
aggressive than the source's: `MeleeCombat.aggression` autostarted and rolled
every turn the player shared the room, with no strike-first probability and no
engaged/unengaged distinction, so an unprovoked player standing in the Troll Room
died in 40 runs out of 41 inside eight turns. That was filed as #237, which asked
that these four lines be revisited if the aggression were ever brought back to
`PROB 33`.

**#237 has landed, and two of the four lines are back to the source's
courtesy.** The troll and the cyclops bow again — in this game's own words rather
than the ZIL's, since Dungeon adapts — because the argument for their hostility
was about our troll rather than the source's and no longer describes either. The
thief keeps his courtesy and the robot keeps its refusal to nod: neither rested
on the aggression. `Prose+Cellar.swift` and `Prose+Maze.swift` carry the history
above the lines themselves.

**What the fix bought, measured the way the issue measured it** — sword and lamp,
into the Troll Room, then wait, over seeds 0–40:

| turns waited | before | after |
|---|---|---|
| 1 | 16/41 | 4/41 |
| 2 | 23/41 | 10/41 |
| 3 | 32/41 | 17/41 |
| 4 | 37/41 | 28/41 |
| 8 | 40/41 | 33/41 |

Reading the room is no longer very nearly fatal, which was the complaint. Loitering
in it still is, and that is worth being plain about: **the strike-first
probability was only half of what made the room lethal.** Once his roll fires he
is engaged, and `FIGHTBIT` is cleared only by the two of them ceasing to share a
room — so a player who stands there long enough gets a fight eventually and then
faces our outcome table, which is 50 miss / 35 wound / 15 outright kill against a
`playerStrength` of 2. That table is a much harsher simplification of the source's
melee tables than the strike-first branch was of `F-FIRST?`, and #237 put it
explicitly out of scope. It is the next thing to look at if the Troll Room is
still thought too cruel; the two-turns-in-three of blocking is now faithful, and
the arithmetic of the blows is not.

#### The white house's window, and a verb that was missing (#233, fourth pass)

Closures rather than divergences, and the pair of them cost the engine a verb it
did not have. Both are also entries in the Zork 1 half of this ledger, under *The
kitchen window*, because the same source lines were frozen the same way in both
games.

- **`enter window` walks you through it**, as `KITCHEN-WINDOW-F`
  (`1actions.zil:246-266`) does and as the mainframe's map data spells it
  (`"ENTER" ,KITCHEN-WINDOW` on Behind House, `"EXIT" ,KITCHEN-WINDOW` on the
  Kitchen). The repair is the engine's: a door on an exit of the room you are
  standing in is now a way through under `enter`, `go through`, `walk through`,
  `step through` and `climb through`, refusing in the same words `go` refuses in.
  The Bank of Zork's private `walkThrough` verb is gone with it — Zork II keeps
  its walls and curtain inside `V-THROUGH`, which is where they are now.
- **Behind House and the Kitchen branch their last clause on the window again**,
  which both sources do and this game had frozen shut. `Prose.behindHouse` and
  `Prose.kitchen` keep the shut half; their `…OpenWindow` twins carry the other.
  Behind House's rule is the host's, since the room and the window belong to
  different bundles.
- **`GameText.cantEnterThat` is `V-THROUGH`'s own last line** — "You hit your head
  against the … as you attempt this feat.", `gverbs.zil:1438` and
  `act3.199:450`, so both sources have it. It replaces the Bank's "It is solid,
  and you are not.", which was true of a wall and strange about a pebble.

#### The stub floor, and five verb replies taken verbatim (#233, fifth pass)

Box 12 gave the game a written answer for every stub verb, and doing it raised a
question this file had not had to answer before: **the verbatim policy above is
about room descriptions, and says nothing about verb replies.**

`docs/games/dungeon-prose-comparison.md` — the authority the prose rule names —
compares *descriptions*, mainframe against trilogy. Nothing in it covers what
`V-YELL` prints. The precedent was already in the tree and undocumented:
``Prose/drinkWater`` is `V-EAT`'s "Thank you very much. It really hit the spot."
(`gverbs.zil:483`), taken as-is since the bottle was written.

**The policy, stated here because it now covers more than one line.** A trilogy
verb reply is treated exactly as an `identical` description is: taken verbatim
where the mainframe world does not contradict it, under the same MIT grant
`THIRD_PARTY_NOTICES` records, and adapted where it does. These are not
divergences — they are the rule applied to a channel the rule had not yet been
asked about — but they are listed so a reader who finds a trilogy sentence in
this game's mouth can tell it was a decision:

- **"Aaaarrrrgggghhhh!"** — `V-YELL`, `gverbs.zil:1616`.
- **"Wheeeeeeeeee!!!!!"** — one of `V-SKIP`'s four (`WHEEEEE`, `gverbs.zil:1272`);
  the game picks the entry the table is named for rather than rotating, because a
  stub with no mechanic behind it does not earn a random draw.
- **"You are already standing, I think."** — `V-STAND`, `gverbs.zil:1305`.
- **"Such language in a high-class establishment like this!"** — `V-CURSES`,
  `gverbs.zil:382`.
- **"With luck, your wish will come true."** — `V-WISH`, `gverbs.zil:1610`.

Two more are **adapted rather than taken**, both because the original narrates in
the first person where this game narrates in the second: `V-KISS`'s "I'd sooner
kiss a pig." becomes *"You would sooner kiss a pig."*, and `V-ATTACK`'s "I've
known strange people, but fighting a …?" becomes *"You have known strange people,
but fighting that?"*. `V-SQUEEZE`'s actor branch ("The … does not understand
this.", `:1287`) and `V-COMMAND`'s ("The … pays no attention.", `:359`) are taken
with only the engine's own article handling replacing the ZIL's.

**`knock` has two branches, and this game chose which things are doors (#247).**
`V-KNOCK` (`gverbs.zil:766`) answers one way at a `DOORBIT` object and another at
everything else. Both are here: the door half is a game-wide `world.before(.knock)`
rule reading ``Item/isDoor``, the other half is the floor's line, and both are
adapted rather than taken — the source's second branch is a question, and this
narrator does not ask the player questions it will not answer.

`isDoor` is true wherever the map hangs a way through on the thing, which covers
eight for free: the kitchen window, the grating, the trap door, the Palantir's oak
door, and the endgame's crypt, wooden, bronze and cell doors. Seven more declare
the `door` trait because they lead nowhere the map models: the boarded front door,
the Living Room's gothic wooden door, the Riddle Room's stone door, the Royal
Puzzle's two steel doors, the locked cell door and the volcano's small door.
Fifteen in all.

That set is **this game's reading**, not a transcription of the mainframe's
`DOORBIT` list, which is what an adaptation is entitled to. The doorways — the
Bank's, the Dam's, the Living Room's, the Temple's — are deliberately not doors:
a doorway is a hole, and knocking on one earns the other branch. So are the
Temple's Egyptian doors and the gates of Hades, which are scenery in the plural
and read better named than knocked at.

The endgame's wooden door is the standing exception, named in the rule: it answers
its own knock with the quiz, and `before` rules run outside-in, so the game-wide
rule would otherwise speak over it.

**One departure, and it is a mechanism rather than a sentence.** The floor is
installed as `text.stubs` rather than as the `action(…)` rows this game and
`Sources/Zork1/` both used. Nothing in either source distinguishes the two — the
distinction is Gnusto's — but it matters here because an action override returns
before `requireReach`, so the old rows answered about things the player could not
touch. `Sources/Zork1/` used the rows and constructed `MeleeCombat()` with the
plugin's stock text; that was filed rather than fixed here, because its floor
should be Zork I's own lines under the verbatim rule and this game's is an
adaptation. It was fixed by #242 — see *The stub floor* under the Zork 1 half.

#### Where the sources actually are

Several notes above say a question "cannot be settled from the repository,
because the ZIL sources are deliberately not vendored." That remains true of the
repository and has been read as meaning the text is unavailable, which it is not:
the checkouts `bin/atlas/build_atlas.py` reads live outside the tree, and both
departures in this section were settled by reading them. **Check for them before
writing that a source line cannot be confirmed.** They are not vendored, they are
not in the build, and nothing in `Sources/` may quote them beyond what the
committed policy already licenses — but "not vendored" is not "not readable".
