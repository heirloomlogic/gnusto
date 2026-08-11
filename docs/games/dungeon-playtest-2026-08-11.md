# Dungeon — playtest round, 2026-08-11

Commit `0080053` · seed `2` · charters: tourist, clock-watcher, vandal, solver, idiot,
re-reader. Not run: interrogator — `Package.swift` gives Dungeon no `GnustoConversation`,
so the charter filtered itself out.
Oracle tiers: T0 kernel, T1 design doc (`docs/games/dungeon.md` — contract, map,
solution), T2 `DungeonTests` + `DungeonEndgameTests` + `DungeonWalkthroughTests`, T3
source. Budget: ~720 turns planned (120 × 6). **50,479 commands spent across 184
transcripts to buy 4,241 commands of exploration** — see Coverage, which is the number
this round is really about.

First round this game has ever had. `fix: "none"`, so nothing here was applied.

## The round

Two classes account for most of it, and they are the two a transcript test cannot reach.
The first is a **static trait asserting a fact that has a state behind it** — the trait
cannot branch, so the sentence goes on being printed after the state moves. The second is
a **fuse body that says its line without asking where the player is standing**. All 42
findings are `preexisting`; no recent fix reintroduced anything, and the verifiers dated
every one of them.

- **`x window` says the kitchen window is "not enough to allow entry" while the player is
  standing in the Kitchen, having just climbed through it.** *Frame:* Kitchen, turn 5,
  one turn after `open window` at Behind House. *Cause:* `house.window` carries a static
  `description(Prose.kitchenWindow)` (`Regions/House.swift:50-55`) and the window is the
  `via:` door on four exits, so `isOpen` is exactly the state the sentence is about. The
  two *room* descriptions keep saying "slightly ajar" too, but those are the source's own
  lines and only the examine text claims the window will not admit you.
- **The Winding Passage reports the Round Room's machinery as turning after the
  triangular button has stopped it** — in the room description, in the whirring's examine
  text, and in the blocked north exit. *Frame:* Winding Passage, one move southeast of a
  Round Room that printed "the machinery that turned it has stopped" two turns earlier.
  *Cause:* three static texts in `Regions/Prose+Mirror.swift` assert the sound as fact.
  The Round Room itself was given a `describe { }` rule for exactly this reason — its doc
  comment says a room that went on whirring "would be telling the player their own
  solution had not worked" — and the room next door, reporting the same machine, never
  got the same treatment.
- **The lantern's burn-down fuse announces "The lamp appears a bit dimmer." in a sunlit
  Forest, with the lamp lying on the floor of Stream View two hundred feet down.**
  *Frame:* Forest, above ground, after a grue death scattered the player's belongings.
  *Cause:* `fuse("lanternDim") { say(Prose.lanternDim) }` (`Regions/House.swift:533-542`)
  has an unconditional `say`; per K10 a fuse's text lands wherever the player happens to
  be, so the body has to ask its own question. Its two sibling rungs are written the same
  way, and `lanternDies` goes further and offers advice about a lamp the player is not
  holding. `DungeonTemple.burnCandleStage()` already guards every line on
  `candles.isVisible` — the pattern is in the codebase and was not applied here. One
  branch fixes all three rungs.
- **The struck-match fuse announces "The match has gone out." two turns after that match
  blew the player to pieces in the Gas Room**, printing above ground to a player
  resurrected with empty hands. *Frame:* Forest. *Cause:* the same unbranched `say`, in a
  different bundle — `fuse("matchBurnsOut", after: 2)` at `Regions/Dam.swift:672-675`. It
  needs its own guard on `matchbook.isVisible`.
- **Examine answers about the wrong place, four sites.** `x tree` from ten feet up the
  tree answers with the view from the ground, including "Something pale is tucked into a
  nest high up among the leaves" while the nest is beside the player and the egg is in
  the room listing. On the Rocky Ledge, `x passage` answers with the far-distance line
  about a passage the room has just placed directly below. In the Gas Room `x stairs` — a
  noun the room's own description prints — is answered with the coal gas's description.
  In the Vault the curtain of light hangs "where the north wall ought to be", in a room
  with a north wall of its own. *Cause:* one static description serving two frames, and
  in the volcano's case a synonym list doing it deliberately: `wideLedgeRock`
  (`Regions/Volcano.swift:414-419`) claims `rim`, `drop`, `bottom` and `door` against one
  description of the rock underfoot, so examining a thing the room has just placed two
  hundred feet above you answers with the ground you are standing on.
- **Game-wide refusals that are false in the room they print in.** `drink` and `fill`
  answer "There is nothing here to drink." and "There is no water here to fill it from."
  in the seven rooms the game itself flags `.waterSource` — and the bottle's own rule
  already reads that predicate, so the bottle fills at the spot where the bare verb
  denies the water exists. `dive` answers "There's nothing here to dive into." on top of
  a dam holding back a reservoir; its twin `.swim` was re-skinned and `.dive` was left on
  the engine stub. `smell` answers "You smell nothing out of the ordinary." in the two
  rooms in the game whose descriptions are *about* a smell — the Smelly Room and the Gas
  Room. *Cause:* `DungeonSystems.actions` installs all of these as unconditional
  game-wide defaults (`Systems.swift:178-191`).
- **The Endgame's mirror box disagrees with itself about its own open side.** You can
  step out through the open pine end and cannot step back in through it, and the refusal
  — "There is no opening in the side facing you" — is a claim about the box, made while
  the box stands open and the player walked through that face one turn earlier. *Cause:*
  `MirrorBox.isOpenToward(_:)` (`Regions/Endgame+MirrorBox.swift:150`) recognises only
  the mirror as an opening; `leaveTheBox()` recognises both. The two halves of one
  doorway disagree. The flanking room's listing line makes it worse: `boxFaceName(.pine)`
  is the unbranched "a wall of pale pine", so the room describes a shut wall where an
  open one stands.
- **"The pine wall swings out on its hinges. Beyond it is the hallway." is printed while
  the box stands crosswise**, where beyond the pine end is a Narrow Room — and the next
  command proves it. *Cause:* `Prose.boxPineSwingsOpen` is static, while `leaveTheBox()`
  computes the actual landing from the bearing. The game already knows which bearings are
  end-on (`MirrorBox.isEndOn`); the sentence needs the branch the movement code has.
- **The sword's warning system reports a change in the danger when only your grip
  changed.** Putting the elvish sword down one room from the Guardians prints "The blue
  light goes out of the sword"; picking it straight back up prints "has come up to a
  fierce blue light". *Cause:* the `endgame.swordGlow` daemon computes
  `house.sword.isHeld ? swordGlowStrength : 0`, so an unheld sword reads as a sword in no
  danger. Same owner, and worth fixing together: `x sword` never mentions the glow at
  all, so the one command a player would use to check the warning tells them nothing.
- **The quiz voice repeats itself in the same breath.** Knocking while a question is
  outstanding prints the question, and the daemon then prints "The voice waits, and then
  puts the question again" plus the same question, on the same turn. *Cause:* the
  re-knock path does not clear `quizWaitedATurn`. The right-answer path guards against
  exactly this and says so in a comment — the re-knock path is the same case with the fix
  missing.
- **`greet troll` answers with the engine's stock "nods, and says nothing"** — a courteous
  acknowledgement asserted from a creature mid-swing, on a turn the melee daemon also
  answers. The game re-skins ten stock keys and sixteen stub verbs and none of the six
  actor-directed ones.
- **Fourteen findings of nouns the prose prints and the parser cannot answer**, deduping
  to one class: `field` (the game's opening room), `path` (four above-ground rooms),
  `clearing`, `trees`, `forest`, `passage`, `passageway`, `crawlway`, `doorway`,
  `passages` (the Round Room's description is entirely about them), `pages`, `bank`,
  `wreckage`, `equipment`, `sand` (named three times in one room), `shaft`, `walls`. The
  census counted **28 unknown-word replies over 13 distinct words**.
- **Two comments in `Dungeon.swift` describe the carousel's southwest passage into the
  maze as an unbuilt seam.** It is built, it has been since M4, and the loop that builds
  all nine sits directly below the second comment.

## Fixed

Nothing. The round ran `fix: "none"`, as #190 requires: the failure mode is a plausible
wrong fix in a suite where `DungeonTests.swift` alone is 3,974 lines of substring
assertions lifted from the prose. No `Sources/` file was touched.

## Filed, not fixed

42 findings, deduplicating to the classes in the round's one issue. The workflow's
breakdown: `needs-human` 5, `out-of-mode` 37, `harness` 0, `unclassified` 0.

| Class | Severity | Why not fixed here |
|---|---|---|
| Unbranched fuse bodies (lantern ×3 rungs, match) | major | `out-of-mode` |
| Static examine text with a state behind it (window, whirring ×3, pine wall, library books, slide rope, narrow ledge) | major | `out-of-mode` |
| Examine answering about the wrong place (tree, rocky ledge, volcano synonyms ×3, vault curtain) | major | `out-of-mode` |
| Gas Room `x stairs` answers with the gas | minor | `needs-human` |
| Game-wide refusals false in the room (`drink`/`fill` vs `.waterSource`) | major | `needs-human` — the predicate exists; which rooms should answer differently is a design call |
| `dive` and `smell` game-wide | major | `out-of-mode` |
| Mirror box's two halves disagree about the open pine end | major | `needs-human` — the box's own model is at stake |
| Sword glow reports grip as danger; quiz voice repeats | major | `out-of-mode` |
| `greet troll`; `enter window` refused in the stock voice | major / minor | `out-of-mode` / `needs-human` |
| 31 of ~48 stub verbs unmodified | minor | `needs-human` — how much of the engine's register to keep is a policy call |
| 14 unanswerable nouns | minor | `out-of-mode` |
| Stale carousel-seam comments | note | `out-of-mode` |

## Refuted

13 of 55 findings refuted (24%). The verifier earned its keep: five of the thirteen are
the vandal charter reading the Dam region's flood as a prose defect when the room
paragraphs are trilogy-verbatim and assert nothing the water contradicts.

| # | Charter | Claim | Refutation |
|---|---|---|---|
| 1 | tourist | The Round Room is not `alwaysDescribed`, so a player walking back in is never told the carousel stopped | Stock behaviour by design. The brief re-entry asserts nothing about the machinery, and the moment of the change prints "Click. Somewhere a long way off, a great deal of machinery slows and stops…" |
| 2 | tourist | The nest is listed "birds nest" one paragraph from its own text calling it "a small bird's nest" | Licensed by the doc. Both forms parse, so K8 holds; the apostrophe-less form is mainframe `BIRDS-NEST`, and `dungeon.md:73` puts sentence-level copy in the free-to-change column |
| 3 | vandal | The Dam Lobby says both "Private" doorways stand open on the turn walking through either is refused for water | The refusal is about the destination, not the doorway. The doorways are open; the water is on the far side |
| 4 | vandal | `x doorways` reports them "standing open" with a flooded room behind both | Same. The only text claiming shut doors is a source comment, not printed prose |
| 5 | vandal | The Maintenance Room describes itself dry while the player stands knee-deep | Nothing in `Prose.maintenanceRoom` asserts dryness. "Describes itself dry" is inference from omission; the flood's report channel is the `damLeak` daemon, which fires every flooded turn |
| 6 | vandal | `take`, `search` and an order to an actor answer in the engine's voice | Each line is true of a hostile troll mid-swing, and `notTakingOrders` is the documented, test-pinned answer for an actor without `takesOrders`. Style preference with no untruth shown |
| 7 | vandal | `follow troll` resolves an actor the player cannot see | `ActorsAndVehicles.md` specifies exactly this: FOLLOW's noun phrase is widened to name out-of-sight actors. The cited disagreement with `examine` is the documented intent |
| 8 | vandal | The green bubble describes itself identically lit and unlit | "The sort that lights when a circuit is live" is a definition, true either way — and the room paragraph prints "The green bubble is glowing serenely" one line above it |
| 9 | vandal | The Loud Room echoes "your words" after `smell` and `listen` | `RoundRoom.swift:307-317` refuses every intent but `.go`, `.look`, `.take` and `.echo` by flinging the last word back, and says so. The objection applies to every non-exempt verb |
| 10 | vandal | `x boat` answers with its room-listing sentence | The sentence is true of the frame, and `Prose.pileOfPlastic` is annotated *Trilogy verbatim*. K1 is about a listing line that cannot be true in every frame, not one true sentence serving both channels for a static object |
| 11 | idiot | At Bank Entrance `x furniture` describes signs in a room whose description says the furniture is gone | Misquoted. The room says "**Most** of the furniture has gone… What is left is two signs" — the signs *are* the remaining furniture, and `furniture` is a declared synonym |
| 12 | re-reader | The troll's body ceases to exist with no line; `x troll` then answers "You can't see any such thing" | `MeleeCombat.villain(…)` documents removal at defeat; every villain on this library behaves so. The death line is true when it prints |
| 13 | re-reader | The Dungeon Master's listing line spells him lower-case while every other line capitalizes him | Licensed by the doc — sentence-level copy, and the arrival line and listing line are different channels |

## Coverage

**The survey's own coverage arithmetic was wrong, and the completeness critic caught it.**
This is the most important thing in the round, so it goes first.

The survey reported 112 of 195 rooms visited and named 83 as never entered. Derived from
the transcripts instead, the real figures are **155 of 195 entered and 40 never entered**
— 43 of the 83 "never visited" rooms, 52% of that list, appear as room headings in dozens
of transcripts. The survey's census was tester self-report, never reconciled against the
184 transcripts. The error is one-directional — every room provably never entered *is* on
the list, so nothing was over-claimed as covered — but a round-2 planner handed it would
spend its budget re-walking rooms that have already been walked. The roster itself is
right: 195 rooms, being 143 literal `Location { }` declarations plus 52 from the room
factories. A naive grep returns 196; the extra is `Bank.swift`'s `room(for inner:)`
factory body, which is not a room.

**Two tiers of "visited", and the distinction is the round's real limit.** 91.6% of this
round's engine work was replaying committed routes:

| | commands |
|---|---|
| Total effective, 184 transcripts | **50,479** |
| Verbatim prefix of a file in `.context/playtest/routes/` | 46,238 |
| Tester-authored | **4,241** |

**21 rooms were entered only inside a replayed prefix and never once under a tester's own
command** — the whole Alice region, the whole river/rainbow run, plus Altar, Engravings
Cave and Top of Stairs. No noun in any of them was ever examined. They are "visited" only
in the sense that the screen printed them while the harness typed somebody else's
walkthrough at them. **Count them blank.** This is the cost of the route-prefix mechanism
that made the deep regions reachable at all: it buys reach, and reach is not coverage.

**Rooms** — 155 of 195 entered; 156 with the critic's own Studio probe, which it ran to
show what a blank costs: the Studio is 30 turns from a cold start and one step south of a
Gallery that 145 transcripts stood in, and nobody took the step.

Never entered, 40: Studio · Steep Crawlway · `maze4`, `maze8`–`maze14`, `deadEnd1`–`deadEnd4`,
Grating Room (13) · `mine2`, `mine3`, `mine5` · `river5`, `whiteCliffsNorth`,
`whiteCliffsSouth`, `rockyShore`, `chasmDeadEndNorth`, `chasmDeadEndWest` ·
`westViewingRoom`, `eastViewingRoom` · `hallwayB`, `hallwayC`, `hallwayD`, `hallwayG`,
nine of the ten Narrow Rooms, `eastCorridor`.

**Region × charter.** `X` = the charter typed at least one of its own commands there.
`.` = the region only flashed past inside a replayed prefix. `-` = never reached.

| Region | tourist | clock | vandal | solver | idiot | re-reader |
|---|---|---|---|---|---|---|
| AboveGround | X | X | X | X | X | X |
| House | X | X | X | X | X | X |
| Cellar | X | X | X | X | X | X |
| Maze | . | X | X | X | X | X |
| RoundRoom | X | X | X | X | . | . |
| Dam | . | X | X | X | . | . |
| Temple | . | X | X | X | . | . |
| Mirror | X | X | X | X | . | . |
| CoalMine | . | X | . | X | . | . |
| Palantir | - | X | - | X | - | . |
| **River** | **-** | **.** | **-** | **.** | **-** | **.** |
| Volcano | - | X | - | X | - | . |
| Bank | . | . | . | . | X | . |
| **Alice** | **.** | **.** | **.** | **.** | **-** | **.** |
| **Riddle** | **.** | **.** | **.** | **.** | **-** | **.** |
| RoyalPuzzle | - | . | - | X | - | . |
| Endgame | - | - | - | X | - | X |

Three rows have no `X` anywhere. **River, Alice and Riddle were assigned to no charter and
probed by nobody** — that is a hole in the operator's split, not in the charters. The
split named eight regions and the game has seventeen.

**Charters — probed-and-clean versus never-probed.** All six that ran produced findings,
so no charter's silence needs explaining; the silence here is region-shaped. *Temple* and
*Palantir* were probed by charters that typed their own commands and produced zero
verifications: a genuine clean bill at seed 2. *River*, *Alice* and *Riddle* produced zero
because nobody was ever there. Those two results must not be read alike.

*interrogator* did not run — Dungeon has no `GnustoConversation` dependency, so the
charter filtered itself out on the manifest. It is the charter whose whole job is asking
the game about the nouns it prints, which makes it the worst one to lack in a round whose
largest blank is twenty-one rooms nobody addressed a command to.

**Timers × exercised.** 35 named timers. **Ten branches never fired anywhere in 184
transcripts**: `lanternDies` (the 350-turn rung), `damLeak`'s drowning (`Prose.floodDrowns`),
`exorcismLapse`, all three stages of `candlesBurn` (`candlesShorter`, `candlesVeryShort`,
`candlesGone`), `cageGas`'s kill branch, `gnomeLeaves`, `dustyRoomFalls`
(`debrisBlocksTheWay`), `endgame.pine` (`boxPineSwingsShut`), `endgame.quiz`'s
failed-for-good branch, and the gas explosion's carried-flame-in branch (only the
struck-a-match branch fired). Six more fired only inside a replayed prefix, with nobody
watching: `bellCools`, `cageGas`'s onset, `balloonDrifts` descending, `burnerBurnsOut`,
`wideLedgeFalls`, `endgame.herald`.

**Deaths** — 17 resurrections, every one into the Forest with belongings scattered. **The
terminal death was never reached**, so the losing ending's prose is entirely unread.

**Turns** — the testers' self-reports are low by about 2.5× even counting only novel
commands (self-reported 1,202; actually 4,241). Tourist reported one unknown-word reply
and drew three. The survey copied the self-reports forward unchecked.

**Dropped** — none. All 55 findings were verified; none was dropped for budget, and none
was found non-reproducible by its verifier.

**What a second round should probe first**, from the critic, in order: the Alice region
examined rather than transited (its `cageGas` fuse fired in 63 transcripts with nobody
watching); the river and rainbow run, likewise, plus the four rooms the route never
touches; the Endgame's mirror box at berths other than A; the candle ladder entire; the
thirteen maze rooms off the route's line; the Studio's chimney burden gate; one route
driven to a third death for the losing ending; Steep Crawlway and the two Bank Viewing
Rooms; and `mine2`/`mine3`/`mine5` with the Gas Room's walk-in-with-a-flame branch.

Completeness critic's verdict on the round: **sound**.

## Hygiene

- `swift test --build-system swiftbuild` — 1,498 tests in 100 suites, 0 failures.
  **No `Sources/` file was touched this round**, so a green suite here is a baseline, not
  evidence that anything was fixed.
- Strict lint — clean.
- Test files +0 / −0 lines. No assertion was removed, none weakened, no needle dropped.
- Two spot-checks were replayed by hand rather than taken from the verifiers: the kitchen
  window (`.context/playtest/Dungeon-spotcheck/probe-001`) and the tree
  (`probe-002`). Both reproduce exactly as filed.
