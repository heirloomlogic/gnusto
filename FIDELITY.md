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
  open onto real map.
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
