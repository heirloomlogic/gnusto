# Fidelity Ledger

Tracks every place a Gnusto game content slice knowingly departs from the
source material it's modeling, or from a "finished" implementation of its
own mechanics — so a later pass has a checklist instead of a memory. Each
entry below is grouped by the task that introduced it.

## Task 8 — Zork 1 slice: White House (`Sources/Zork1/`)

### Prose

- **Every room and item description is original placeholder text**, written
  to convey the same facts a finished description would (what's here, which
  exits lead where, what's worth touching) without reproducing or lightly
  rewording Infocom's copyrighted text. Every description is a named
  constant in `Sources/Zork1/Prose.swift`, so a later verbatim-text pass is
  a mechanical one-constant-at-a-time edit. Room and item *names* ("West of
  House", "brass lantern", "jewel-encrusted egg") are the iconic proper
  nouns and are used as-is — only the descriptive prose around them is
  original.

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
    is modeled as a **two-way** path in this slice. The authentic Zork
    canyon has no way back up without climbing gear this slice doesn't
    model (that's a deliberate one-way trap in the original game); making
    it round-trip here is a simplification so the region is fully explorable
    and testable without stranding the player or introducing gear the brief
    didn't ask for. Revisit when/if the canyon's onward geography (and the
    climbing mechanic that unlocks the return trip) is built.
  - `Forest (northeast)` is a minimal dead-end-ish stub connecting back to
    `Forest (west)` and `Forest (east)`; the real game's forest maze logic
    (movement without a fixed map) is not modeled here.

### Mechanics simplified or deferred

- **Tree climbing is just the `up`/`down` exit pair** between Forest Path
  and Up a Tree — there's no dedicated `climb` verb yet. `climb tree` will
  currently fall through to "I didn't understand"; only `up` gets you into
  the tree. A `climb` custom verb mapping onto the same exit is future work.
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

- **All prose remains original placeholder text**, same policy and same
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
  the real 350 until more treasures exist. One deliberate divergence:
  points are award-once and never deducted — the original's in-case
  accounting subtracts a treasure's case value when you take it back out;
  `GnustoScoring`'s registers pay once and stay paid. The thief does not
  rob the trophy case (his reach is held items only — see the thief entry).
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

- **All prose remains original placeholder text**, same policy as ever;
  "troll" the name is fair game, Infocom's sentences are not. The troll's
  strength (2) and the sword/knife as the weapons that can reach him are
  the original's data.
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
- **Defeat is permanent and bodiless.** The troll vanishes with his death
  line ("sinks into the shadows"); there is no bloody axe to loot, and he
  never recovers to block again — the original's randomized recovery and
  loot are not modeled.

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
  (extensions on the same `enum Prose`). Pure relocation — the text is
  unchanged and the one-constant-per-entity verbatim-swap path is intact.
- **The custom verbs' responses are original placeholder text**, same as
  every other line. Infocom's famous joke replies (the hollow voice's
  "Fool.", the wave-of-nausea, and so on) are deliberately not reproduced;
  the verb *words* the player types (`xyzzy`, `plugh`, `pray`, …) are the
  iconic ones and are used as-is.

### Custom verbs (`Systems.swift`)

- **The verbs are declared now but mostly inert.** `dig`, `wave`, `touch`,
  `wind`, `inflate`/`deflate`, `launch`, `raise`/`lower`, `turn … with …`,
  `tie`/`untie`, `give`, `ring`, and the magic words (`xyzzy`, `plugh`,
  `odysseus`/`ulysses`) parse and answer with a polite stage-4 default. Their
  real mechanics arrive with the regions that need them (the shovel, the
  clockwork canary, the plastic boat, the dam controls, the Cyclops), which
  only have to add an item-scoped rule — the parser already knows the word.
- **`diagnose` and `count` are not implemented.** The original's health-report
  and inventory-count verbs are out of scope for this slice.
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
- **Score ranks are shown, but the rank names are original placeholders.**
  The ladder's thresholds are game data used as-is; the titles ("Wanderer",
  "Trespasser", … "Master of the Underground") stand in for Infocom's
  ("Beginner" … "Master Adventurer") on the same names-vs-prose line as
  everything else. The `score` verb is a meta intent (it skips all rules), so
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
- **The resurrection prose is original placeholder text** (`Prose.resurrection`,
  in `Prose+Systems.swift`), one constant like everywhere else — Infocom's
  resurrection narration is not reproduced. The player is resurrected in
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

- **All room, item, and message prose is original placeholder text**, same
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

- **All room, item, and message prose is original placeholder text**, same
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

- **The Maintenance Room flood is a deterministic band model.** The blue button
  starts a `damFlood` daemon; the water is narrated rising past the ankles
  (turn 4), the waist (turn 8), and the neck (turn 12), and anyone still in the
  room when it fills at turn 13 drowns, at which point the room seals (the daemon
  stops). The original raises a continuous water level and computes drowning from
  it; the fixed bands and 13-turn seal reproduce the player-facing arc (warned,
  then drowned if you linger) deterministically, so no seed is needed. **Leaving
  the room is the only escape** — the tube-of-gunk leak-plugging puzzle is not
  modeled; the tube is a readable souvenir for now.
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

- **All room, item, and message prose is original placeholder text**, same
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
- **The red-hot bell is a `@Global` flag, not an item swap.** Ringing sets
  `bellHot` (which the take-refusal reads) and the ring reply narrates the glow;
  the bell's examine text does not change, and there is no separate red-hot-bell
  item. The bell cools after a fixed 20 turns — a **deliberate anti-softlock**
  (the original can leave the bell permanently hot and unusable); the cool is a
  plain fuse.
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

- **All room, item, and message prose is original placeholder text**, same policy
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

- **All room, item, and message prose is original placeholder text**, same policy
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
- **The machine transmutes coal only.** Feeding it coal, shutting the lid, and throwing
  the switch with the screwdriver (a `ZorkDam` tool — the rule is host-wired, like the
  dam bolt) makes a huge diamond; the wrong tool, an open lid, or no coal does nothing.
  The original also grinds any *non*-coal contents into a lump of "gunk"; that
  destruction is not modeled — a closed machine with no coal simply whirs to no effect.

### Scoring

- **The Drafty Room pays 13 on first arrival** (the original's room `VALUE`),
  host-wired via `scoring.visit` alongside the kitchen, cellar, and East-West Passage.
- **Three treasures carry the original's numbers and join the host roster**: the jade
  figurine (find 5 / case 5), the sapphire-encrusted bracelet (5 / 5), and the huge
  diamond (10 / 10). All pay out in the living-room trophy case. The coal itself is not
  a treasure — it carries the original's `SIZE` 20 as its weight and is consumed by the
  machine.
