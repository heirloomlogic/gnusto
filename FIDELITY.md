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
  that actually holds the key is Phase 7 content.
- **The cellar is a stub**, not the full Zork cellar (no maze, no thief, no
  troll, no score). It exists only so the trap door leads somewhere real and
  the dark-room mechanic (`dark` trait, "It is pitch black") is
  demonstrable now. The full cellar arrives with Phase 7.
- **The brass lantern is just an item.** It has no light-source behavior;
  standing in the dark cellar is genuinely pitch black even while carrying
  it. Phase 7 is expected to make `dark`-location lighting react to a
  carried lit lantern.
- **The trap door can still be opened from the cellar side.** In the
  finished game, the thief eventually bars it from below; that arrives with
  the thief in Phase 8. For now, `livingRoom.down(cellar, via: trapDoor)` /
  `cellar.up(livingRoom, via: trapDoor)` share one door state with no extra
  restriction once it's open again.
- **Known soft-lock, not a Task 8 bug — a solo player without a light
  source who descends the trap door is stuck, full stop, until Phase 7.**
  `cellar.onEnter` (`Sources/Zork1/House.swift`) slams and closes the trap
  door behind the player on entry. The cellar is `dark`, and
  `Visibility.collect` (`Sources/Gnusto/Engine/Visibility.swift`) has a
  single early-return guard for darkness (`guard !isDark(...) else {
  return result }`) that sits *before* both the room-contents walk and the
  door-folding loop later in the same function — so under darkness neither
  one runs, and a door referenced only by an exit (never placed `in:` a
  room) never enters scope. Concretely: `open trap door` from inside the
  cellar fails at the parser with "You can't see any such thing," not a
  `refuse`-level "it's dark" message, because the trap door was never a
  candidate noun to begin with. Nothing else in this slice can reopen it
  from below. This is a genuine, intentional soft-lock in the current
  build — not a death, and not (yet) recoverable — pending Phase 7's light
  sources (lantern) and grue, which is when darkness in this cellar
  becomes survivable (lit) or lethal (grue) rather than merely stuck.
  Worth noting for calibration: the original Zork 1 doesn't let you reopen
  the trap door from below either — the thief bars it once he arrives —
  but the original handles a lightless cellar by killing the player to the
  grue after a few dark turns, so unlit descent is never a stable state
  there. Our engine has no grue yet, so the same starting conditions
  produce a stuck state instead of a game over; that gap is what makes
  this "soft-lock" rather than "death," and it closes when Phase 7 lands.
  `Tests/GnustoTests/Zork1Tests.swift`
  (`darkCellarSoftLockIsThePhase7Seam`) pins this as current intended
  behavior end to end: the slam, the refusal of `up` while closed, the
  parser's inability to resolve `open trap door` as a noun, and a further
  `look` that still reports pitch black rather than a room, confirming no
  other command reopens a path out.
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

- No thief, no troll, no score/treasure scoring, no maze, no full cellar —
  all later phases per the Roadmap v2 plan.
