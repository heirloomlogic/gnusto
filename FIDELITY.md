# Fidelity Ledger

Tracks every place a Gnusto game content slice knowingly departs from the
source material it's modeling, or from a "finished" implementation of its
own mechanics — so a later pass has a checklist instead of a memory. Each
entry below is grouped by the task that introduced it.

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
  lantern off banks the remaining turns (the classic economy); the dim
  warning prints wherever the player is, without the original's
  can-you-see-the-lamp check. A burned-out lantern refuses `turn on` with
  `Prose.lanternSpent`, and nothing in the slice replaces it.
- **The grue is deterministic and lingering-based**, where the original
  rolls dice per dark turn: warning on the first consecutive turn *ending*
  in darkness, one silent grace turn, death on the third, counter reset by
  any lit turn. Chosen so transcripts reproduce without pinned seeds and
  the warning is a guaranteed fairness beat. As of Phase 8 the daemon
  lives in the `GnustoDangerousDark` plugin (the promised extraction was
  the file move it was engineered to be); Zork 1 passes its own prose in
  and takes the stock warn-at-1/die-at-3 schedule, so behavior and
  transcripts are unchanged. The warning and death prose are original —
  the famous "likely to be eaten by a grue" sentence is Infocom's and is
  deliberately not reproduced ("grue" the name is fair game under the
  names-vs-prose line above). One sharp edge, accepted: UNDO from a grue
  death restores the counter at 2, so the revived player has zero safe
  dark moves — grues are unforgiving; RESTORE and RESTART are the real
  outs.
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
- **Combat is `GnustoMeleeCombat`'s simplified table**, not the original's
  per-weapon melee tables: one roll per swing (miss/wound/knockout/kill at
  fixed 30/70/85 breaks), villain answers on the end-of-turn clock, player
  wounds never heal, and a knocked-out troll falls to the next clean blow.
  Deterministic under a pinned seed; the transcripts record their
  sequences.
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
- **The custom verbs' responses are now the original Zork I text**, same as
  every other line. Infocom's famous joke replies (the hollow voice's
  "Fool.", the wave-of-nausea, and so on) now carry through; the verb
  *words* the player types (`xyzzy`, `plugh`, `pray`, …) are the iconic ones
  and were always used as-is.

### Custom verbs (`Systems.swift`)

- **The verbs are declared now but mostly inert.** `dig`, `wave`, `touch`,
  `wind`, `inflate`/`deflate`, `launch`, `raise`/`lower`, `turn … with …`,
  `tie`/`untie`, `give`, `ring`, and the magic words (`xyzzy`, `plugh`,
  `odysseus`/`ulysses`) parse and answer with a polite stage-4 default. Their
  real mechanics arrive with the regions that need them (the shovel, the
  clockwork canary, the plastic boat, the dam controls, the Cyclops), which
  only have to add an item-scoped rule — the parser already knows the word.
- **`diagnose` is modeled; `count` is not (closed in the fidelity pass).**
  `diagnose` now reports the death toll and how many resurrections remain
  (`action(.diagnose)` in `Zork1`, reading the host's `deaths` counter): perfect
  health while unscathed, otherwise "killed N times" with the survivals left. The
  original's per-wound severity is not reported — the slice tracks no numeric
  player-wound state, only deaths. The original's `count` verb stays out of scope.
- **`turn … with …` outspecifies `turn … on`** (specificity 22 vs 21) so a
  future "turn bolt with wrench" never trips the light switch.

### Burden / weight (`Burden.swift`)

- **Every takeable item weighs a flat 5 by default**, with a carrying cap of
  100 (the original's cap) — twenty small things. Heavy items (the coffin,
  the gold) will override `.weight` in later regions; none do yet, so the cap
  itself is effectively unreachable with current content and is exercised
  only indirectly through the chimney gate below.
- **The chimney gate is a count, not the original's rule.** The original lets
  you climb the Studio chimney carrying at most one item plus the lamp; this
  slice simplifies that to "no more than two things in hand" (a
  `player.inventory.count <= 2` check on `studio` climbing up).

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
- **The scatter is deterministic, not random.** The original strews your
  belongings around above-ground rooms unpredictably; this slice fixes the
  placement instead: the **lamp always returns to the living room** (so light is
  always recoverable), and every other carried item is dealt out one per room,
  round-robin, across a fixed list of above-ground rooms (West of House, North
  of House, South of House, Behind House, Forest Path, Clearing). `player.inventory`
  is sorted by id, so the placement is stable and no RNG is drawn — a quiet,
  reproducible turn. Revisit if the canonical randomized scatter is wanted.

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

- **The acoustics puzzle is modeled with a match-all garble rule.** On still
  water the room refuses every command but movement and looking until the player
  says `echo`, which sets `loudRoomAcousticsFixed` and frees the platinum bar.
  The original instead keeps a `SACREDBIT` on the bar (untakeable) and runs a
  bespoke read-loop; the garble rule reproduces the player-facing behavior — you
  cannot take the bar until you echo — without the read-loop.
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
- **The coffin's load block is a ≤50 weight cap at the altar crack, not a
  coffin-specific rule.** Canonically the gold coffin (too big to squeeze down to
  Hades) is stopped at the altar's downward crack by a dedicated `COFFIN-CURE`
  flag, forcing the player to carry it out by praying. Here the block is a
  general "carried weight ≤ 50" cap on the altar's `down` (reusing
  `burdenWeight`); the coffin at weight 55 trips it while ordinary exploring
  loads do not, so the puzzle — pray to get the coffin out — is unchanged, but a
  hypothetical 50+ non-coffin load would also be blocked.
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
  `player.location`, describe). Two simplifications from the original: only the
  player moves (held items ride along; the original also swaps whatever lies loose
  on the two rooms' floors), and the mirror **cannot be broken** (the original's
  smash-for-seven-years'-bad-luck, which disables the passage, is not modeled).

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

- **The current is a self-rearming fuse, not a continuous interrupt.** Each stretch arms a
  one-shot `riverDrift` fuse for that stretch's canonical dwell (River-1/2: 4 turns,
  River-3: 3, River-4: 2, River-5: 1); when it fires it moves the boat — and its
  passenger and cargo — one stretch down and re-arms. Because the engine ticks a fuse on
  the very turn it is armed, the fuse is armed at **dwell + 1** so the player nets exactly
  the canonical number of turns on each stretch. Drifting off River-5 goes over Aragain
  Falls (fatal); `up` is always refused ("strong currents"). Draw-free — the schedule is
  fixed data.
- **"Sharp" is a six-item trait, not a general edge test.** A new `TraitKey<Bool>.sharp`
  marks exactly the items the original enumerates as boat-punishers — the sword, the nasty
  knife, and the sceptre today; the rusty knife, the thief's stiletto (Phase 10.11), and the
  troll's bloody axe (the fidelity pass) carry it too. Boarding the boat carrying one, or
  stowing one in it, bursts it (fatal if afloat, a mere wreck ashore). **Repair is now
  modeled (closed in the fidelity pass):** `fix boat with gunk` seals the wreck with the
  dam's tube (host-wired, tube↔boat spanning two bundles), spending the tube and trading the
  punctured boat back for the seaworthy one. Since a puncture afloat is always fatal, the
  wreck is only ever patched ashore.
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
  wall; only the rout does. Two accepted divergences remain: the original's separate
  eyeing/gasping room-look variants aren't reproduced, and attacking a *sleeping* (fed) cyclops
  shrugs rather than waking him (the wake-on-attack is still unmodeled).
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
- **He steals any treasure you carry** (the full 17-item host roster), still only while it is
  held by the player — items on the floor, in the case, or inside a container are safe. This
  held-only simplification is unchanged from Phase 8.
- **He ferries his takings to the hoard.** A draw-free `thiefStash` daemon deposits everything
  he carries (bar the stiletto) onto the Treasure Room floor whenever he is in the lair.
- **He defends his lair to the death.** Entering the Treasure Room summons him home, and a
  `melee.aggression(…, while: { thief.isIn(treasureRoom) })` daemon lets him fight back
  *only there* — evasive everywhere else. He carries the stiletto (the sixth `.sharp`
  boat-puncturer; the original's SIZE 10) and, killed, drops his whole hoard plus the
  stiletto and unbars the trap door.
- **The silver chalice** (find 10 / case 5) sits in the Treasure Room and is **guarded**: the
  host refuses the take while the thief lives. The original lets you snatch it and has him
  steal it back; modeling that round-trip faithfully is deferred — a hard refusal until he
  falls is the stand-in.
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
green, seeds unchanged). The costlier items were left for later passes, not written off: the
cyclops `CYCLOWRATH` timer and the skeleton disturb-curse landed in the next pass (below);
the thief's held-only theft and the silver chalice's snatch-and-resteal run through the shared
`GnustoActors` steal daemon that every seed pin depends on, so closing them is a larger task
carrying a deliberate one-time re-pin (the same operation Phase 10.11 already performed on
purpose); and the currently-deterministic divergences (grue, scoring accounting, melee table,
death scatter, flood bands, Loud Room garble, river current) trade canonical randomness for
seed-free transcripts and remain revisitable if that trade is later reversed. The individual
entries above are updated in place; the closures:

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