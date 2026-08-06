# Fidelity Ledger

Tracks every place a Gnusto game content slice knowingly departs from the
source material it's modeling, or from a "finished" implementation of its
own mechanics — so a later pass has a checklist instead of a memory. Each
entry below is grouped by the task that introduced it.

**Two games are ledgered here, and they do not follow the same prose rule.**
Everything from *Task 8* down to *Fidelity pass — the long tail* is Zork 1, which
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
  lantern off banks the remaining turns (the classic economy); the dim
  warning prints wherever the player is, without the original's
  can-you-see-the-lamp check. A burned-out lantern refuses `turn on` with
  `Prose.lanternSpent`, and nothing in the slice replaces it.
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
- **The barrel at Aragain Falls is a vehicle.** Climb into it and `look` shows the
  inside of a barrel rather than the falls; say `geronimo` and it goes over.
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
  way up or down.
- **The robot has one room of earshot.** The engine deliberately lets an
  order-taker be named out of sight — that is what makes "the robot goes where
  you cannot" work — and deliberately leaves *how far* to the game. This game
  says one room, plus the cage you are standing in while the robot is outside
  it. Without it you can order the robot to lift a cage in the Dingy Closet
  while standing in a forest two hundred rooms above it.

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
`substantial` and adapted to put back the one fact the trilogy dropped — the rim
is fifteen feet across, which is why rising past it wrecks the balloon. And
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
Anywhere else the blast is fatal if you are standing in it and says "There is an
explosion nearby" if you are not, and the room stays open. Sealing an arbitrary
room needs a per-room flag the engine has no place for, and the only room the
puzzle ever seals is the Dusty Room.

**Also landed here.** `Sources/Gnusto/Engine/RoomDescriber.swift` now filters
`scenery` out of the *"In the X is a Y."* and *"On the X is a Y."* listings, the
way it already filtered it out of the room's own. Without it the balloon's cloth
bag, receptacle and braided wire — three fittings the basket's own description
already names — each got a line of its own in every room description. No other
game in the repo puts scenery inside a container or on a surface, and the whole
suite is unchanged by it. `ContainerTests` pins the new rule against a fixture
of its own rather than against this game's transcripts.

**Four listing lines this milestone could not use.** The nested lister has no
presence channel: an item inside a container gets *"In the wicker basket is a
blue label."* and nothing else, where an item on the floor gets its `firstSight`
until it is touched. The crown, the card, the Flathead stamp and the blue label
each start inside something and never sit loose in a room untouched, so their
source lines — two of them `identical` entries — would never have printed, and
they are not declared. Worth its own engine issue rather than four dead
constants.

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
