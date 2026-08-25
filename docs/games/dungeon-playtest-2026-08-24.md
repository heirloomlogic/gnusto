# Dungeon — playtest round, 2026-08-24

Commit `9caa400` · seed `52` · `fix: none` · charters: explorer ×3, timekeeper ×3, solver,
wrong-footer (interrogator filtered itself out — Dungeon depends on no `GnustoConversation`).
Oracle tiers: T0 kernel, T1 `docs/games/dungeon.md`, T2 `DungeonWalkthroughTests`, T3 source,
T4 ledger — all five. **`verifyEffort: medium`, turned down from the inherited default** to
afford a three-region split with a proven prefix per region; SKILL.md requires the header to
say so. Budget: 120 turns per charter over 8 seats.

40 findings reached verification. **30 confirmed** (18 unanimous, 12 `needs-human`), 10
refuted, 0 routed. Rater agreement 29/40 = 72.5%; 11 disagreements, all resolved to
`needs-human`.

**Turns: 45,915 `turn=cost` lines under `.context/playtest/`.** The workflow's own header
reports 37,820 and splits it 9,397 tester / 28,423 verifier. Both are wrong and the
completeness critic proved how — see *Coverage*. The honest split is 16,932 tester, 20,888
verifier, 8,095 the orchestrator's pre-dispatch work.

**23 `refuted` ledger keys were passed as `ledgerKeys`; the `fixed` and `confirmed` ones were
withheld**, because a `fixed` key feeds `seen` and would make the harness drop a regression in
silence. Seven further suppression strings were passed: three standing for the fixes in
**unmerged PR #328** (the sphere/robot prose, the mailbox `scenery` trait, the tied-rope floor
listing) and four for #286's still-unticked boxes. #286 was also passed as a `routedIssue`, so
a symptom belonging to one of its open classes is forwarded rather than re-judged.

**The completeness critic rates this round `round-is-thin` — for reasons that have nothing to
do with the ones it gave the last one.** Every target #291 set was reached. What is thin now
is elsewhere, and the critic is precise about where: six regions have no charter-typed command
in them at all, the 32-room Endgame was never entered by a live session, and the harness's own
coverage arithmetic overstates the round by a factor of five. Read *Coverage* before treating
30 confirmed findings as a thorough pass.

## Why this round exists

#291 is a round *plan*, not a defect. Its finding is about construction rather than prose: all
eight charters of the 2026-08-18 round shared one route prefix, that prefix contained `attack
thief with sword`, and the consequence was not a thin patch but a **structural** blank. Five
regions came back at 0/10, 0/8, 0/5, 0/2 and 1/13 rooms worked, and six of the game's
thirty-five timers could not have fired in any session however long it ran. `shadowy figure` —
both halves of `thief.roams`'s prose, `Sources/Dungeon/Prose+Thief.swift:35-36` — appeared zero
times in about 18,900 played commands.

So this round's whole preparation was **route prefixes, proven before dispatch**. Nine were cut
out of the committed 744-command route in `Tests/GnustoTests/DungeonWalkthroughTests.swift`
(`static let route`; the seed is read from `DungeonWalkthroughTests.seed` = 52, never from a
number written down elsewhere), and each was replayed and its landing room read off the
`[status]` footer before a single charter was dispatched. That is the direct answer to #291's
"operator error to not repeat": the 2026-08-18 focus string asserted a river current the game
does not have (`Sources/Dungeon/Regions/River.swift:24`), and four of one charter's passes were
unrunnable by construction. A prefix nobody has replayed is the same class of mistake.

### The prefixes, and where each was proven to land

| File under `.context/playtest/routes/` | Slice | Landed in | Serves |
|---|---|---|---|
| `2026-08-24-thief-alive.txt` | `route[0:40]` | Cyclops Room, moves 40 | #291 targets 1, 2, 9 |
| `2026-08-24-water-works.txt` | `route[0:117]` | Maintenance Room, moves 114 | target 3 |
| `2026-08-24-still-water.txt` | `route[0:124]` | Reservoir, moves 121 | target 8 |
| `2026-08-24-open-flame.txt` | `route[0:184]` | Mine Entrance, moves 179 | target 7 |
| `2026-08-24-the-machine.txt` | `route[0:225]` | Machine Room, moves 219 | target 7 |
| `2026-08-24-beside-the-basket.txt` | `route[0:567]` | Volcano Bottom, moves 554 | targets 4, 6 |
| `2026-08-24-the-broad-ledge.txt` | `route[0:596]` | Wide Ledge, moves 583 | targets 4, 6 |
| `2026-08-24-the-hole.txt` | `route[0:597]` | Dusty Room, moves 584 | target 6 |
| `2026-08-24-the-chute-head.txt` | `route[0:717]` | Slide Room, moves 702 | target 5 |

`.context/` is gitignored, so the files are working state; **the slice indices above are the
artifact**, and any of the nine regenerates from the committed route in one line. Only the
first is novel: `route[0:40]` is the committed route up to and including the four waits, with
index 41 — `attack thief with sword` — and everything after it dropped. Nothing is edited; the
prefix is a truncation. Replaying one of the long ones needs `--max-turns 800`, because
`bin/playtest-replay` refuses a list over 250 by default.

### What the thief actually needed, which #291 got half right

#291 target 1 proposed lifting an underground treasure to place him. That is one of two gates
and it is the wrong one to plan a charter around.

- **Onstage** is `Sources/Dungeon/Dungeon+Thief.swift:161-167` — a `world.after(.take)` that
  fires once, when a `treasureRoster` item that is not the egg or the bauble is taken while
  `thief.location == nil`, and puts him in the **Treasure Room**, not at the player's elbow.
  That is why #291's own control — `route[0:20]` plus 150 `z` — saw nothing: no treasure had
  been lifted, so `thief.roams` idled and drew nothing from the stream.
- **Being met** is a per-turn coin flip: `Dungeon+Thief.swift:267-273` into
  `Sources/GnustoActors/ActorBehaviors.swift:62-91` — `chance(50)`, then a uniform pick from a
  ~109-room prowl set, and the line prints only if the destination is the player's lit room.
  About **0.46% per idle turn**, whatever the prefix is.

Measured before dispatch: `route[0:40]` plus 160 waits, over six seeds, produced six arrivals
in ~990 idle turns and one seed with none (`.context/playtest/thief-rate/`). Played literally,
#291's target-1 recipe — `route[0:23]`, a detour, `take painting`, then 173 waits — summoned
him and then saw **zero** arrivals (`.context/playtest/thief-prefix/probeE/transcript.txt`). A
charter told only to wait would have met him about three times in five.

What is reliable is `maze.treasureRoom.onEnter { summonThief() }`
(`Dungeon+Thief.swift:239-241`): he is put back in his lair every time it is entered, so each
entry is a fresh look at him. A hundred waits and then repeated entry printed the presence line
**eleven times** (`.context/playtest/thief-prefix/probeF/transcript.txt`). The R1 region text
said so, in those terms and without naming the room.

## The round

The lead sentence is not a prose class. **Every one of #291's nine coverage targets was
reached, and eleven timers that had never fired in any session of this harness fired and were
read** — the six thief timers, `damLeak`, `gnomeArrives`, `gnomeLeaves`, `slideGrip`,
`dustyRoomFalls`'s and `wideLedgeFalls`'s death branches, and `lanternDim`. The 30 confirmed
findings are what was standing behind that door. Nine of them are one class the 2026-08-18
round already named — a static `description` that never learns the state changed — at nine
sites in regions no charter had ever worked.

### The thief, read for the first time

- **He is listed leaning against a wall and armed with a deadly stiletto on the turn after the
  game says he was battered into unconsciousness** — and while it still refuses him a greeting
  because he is "temporarily unable to hear anything at all." *Frame:* Treasure Room, moves 32,
  seed 52. *Cause:* `firstSight(Prose.thiefPresence)` is a static trait on an actor
  (`Sources/Dungeon/Thief.swift:63`), and per K1 an actor's listing line prints on every look
  forever. The game already models the state in another channel —
  `Prose.thiefGreetedOnTheFloor` is the greeting branch for exactly it.
- **Handing him a treasure says he "stops to admire its beauty", and he stabs you on the very
  next turn.** *Frame:* Treasure Room, moves 38, the intervening command a bare `look`.
  *Cause:* the gift line promises the two turns `thief.admires` is supposed to buy; the
  aggression daemon is not gated on the admiration flag on the turn the gift lands.
- **An unconscious actor comes round with no line at all**, so his first blow shares a turn's
  output with the sentence saying he cannot hear. Engine-owned; `needs-human`.
- **`x large bag`, the bag the listing line says he is holding, returns the thief's own
  description**, and the bare noun answers *"Which do you mean: the discarded bags or the
  thief?"*. `needs-human`.

### The water works, where `damLeak` ran for the first time

- **The blue-button flood prints water in the Maintenance Room every single turn and the parser
  denies the noun.** *Frame:* Maintenance Room, moves 33.

  ```
  > push blue button
  There is a rumbling sound and a stream of water appears to burst from the east wall of the
  room (apparently, a leak has occurred in a pipe).

  The water level here is now up to your ankles.

  > x water
  You can't see any such thing.
  ```

  *Cause:* the leak is a fuse printing a level line plus a `leak`/`pipe` scenery item; nothing
  in that room answers to `water`. The word is in the vocabulary two rooms away.
- **After the leak is plugged, the room's static description is the only channel left speaking
  and it describes a dry room** — while the world still holds it flooded to the hips, which is
  what jams the blue button. *Frame:* Maintenance Room, `floodLevel == 4` and never coming
  down. `needs-human`.
- **With the gates open and the reservoir drained to mud, `x reservoir` from the Dam still
  describes it full.** The verifier extended the tester's reproducer by twelve waits to rule
  out a drain in progress; the line does not move.
- **The ivory torch reports itself burning while the player is under water deep enough to drown
  in on the next turn** — "high in your lungs" and "The torch is burning." in consecutive
  turns.

### The volcano's air half, where the gnome arrived for the first time

- **After the gnome opens a west door and a chimney out of the Wide Ledge, the room description
  never mentions either, and still names only the south door.** *Frame:* Wide Ledge, moves 603,
  balloon gone, gnome paid and vanished — which is to say, the exact state the payment exists
  to produce. *Cause:* the ledge's description is a static string; the payoff opens a west exit
  as a state change and nothing re-describes the room.
- **The balloon tearing itself open is reported to a player on the Wide Ledge as a sound merely
  heard at a distance — three turns after that same room narrated watching it float away above
  them.** *Cause:* `DungeonVolcano.rise(_:from:aboard:watched:)`
  (`Sources/Dungeon/Regions/Volcano.swift:1100-1120`) is handed a `watched` flag and then picks
  between the watched and heard lines on `player.location == volcanoBottom` instead.
- **`x safe` after the charge has blown the box open still calls it intact and stronger than
  anything you carry**, while the room listing beside it has already branched.
- **The balloon's room listing stops reporting the bag and the fire the first time it is
  boarded**, so an inflated, burning balloon and a cold, deflated one print an identical
  paragraph. `needs-human`.

### The chute, where `slideGrip` ran for the first time

- **In the Slide the room says you are hanging on a rope and the parser denies the word.**

  ```
  > down
  Slide

  You are hanging on a rope in a chute of sheet metal, wide enough to fall down and too
  smooth to stand in. The rope goes up into the dark and down into more of it.

  > x rope
  You can't see any such thing.
  ```

  *Cause:* the rope entity stays in the Slide Room when the player descends, and no scenery
  item stands in for it. `x chute` answers, so the room does have scenery vocabulary — the one
  thing holding the player up is the noun left out.
- **In the Slide Room the rope can be taken while it is tied off, and the room goes on saying
  it is tied off at the head of the chute while it is in your hands.** This is the same shape
  as the Dome Room knot that unmerged **PR #328** turns into a separate `ropeOnTheRailing`
  fixture — applied at the chute head, which #328 does not touch.

### The Endgame, read for the first time

Two findings, both from the solver, both in a wing no live session has ever entered.

- **The winning prison cell says the bronze door has appeared "where there was stone before",
  in the one cell the game has just finished describing as having a door of bronze in its
  wall** — a door the player can open and walk through before the ride. *Cause:*
  `Prose.winningCell` (`Prose+Endgame.swift:635`) is written for the source's arrangement,
  where the door appears only after the ride; this port shows it earlier, because
  `prisonCell.describe` (`Endgame+Master.swift:194`) branches on the docked cell and prints
  `prisonCellBronze` while the cell is still in the slot.
- **The Tomb heads' curse says everything of worth is "lifted quietly away and gone", and
  nothing is confiscated.** `robTheAdventurer()` (`Endgame+Rules.swift:139`) is `try
  die(Prose.tombHeadsCurse)` and nothing else; `die` falls through to `Dungeon.onDeath()`, the
  ordinary resurrection scatter. The red crystal sphere is lying on the lawn four moves later.

### The floor, and three stock lines

- **`climb staircase` in the Cyclops Room answers "The staircase is not something you could
  climb."** about the broad stone staircase that is the room's only way up and that `up` walks.
- **Turning the lamp off prints two near-identical darkness sentences back to back** — "It is
  now pitch black." then "It is pitch black. You are likely to be eaten by a grue." — where
  walking into a dark room prints only the second. `needs-human`; a control probe is cited.
- **`launch`, standing beside the balloon on the ledge, answers "You're not in the boat!"** — a
  stock line about a boat hundreds of moves away. Engine-owned.
- **`x me` in a room the game has just declared pitch black answers "You look much as you
  always do."** Engine-owned; `needs-human`.
- **A second `light match` while one is burning answers "It's already on."** — the engine's
  switch language, about a matchbook. `needs-human`.
- **The Gallery's paragraph names "vandals" twice and the parser does not know the word.**
  `needs-human`. This is the round's only game-printed unknown word; see *Coverage*.

## Filed

30 confirmed findings, grouped into 8 classes and filed as **#329**, *Dungeon: play-test round
2026-08-24 — 30 findings in 8 classes*. Every confirmed finding is filed; the round finds and
files, and nothing in it edits the tree.

**One confirmed finding is held back and is NOT in the issue.**
`decl::Sources/Dungeon/Regions/Prose+Temple.swift::torchRoomRope` — *the Torch Room lists the
one rope twice, in two contradictory states, in the same description* — sits inside the class
PR #328 is restructuring right now (`Sources/Dungeon/Regions/Temple.swift` and
`Prose+Temple.swift` are both in that diff, and its `FIDELITY.md` entry describes the rope
hanging "twenty feet below on the floor of the Torch Room"). Filing a finding off an unmerged
PR is filing a consequence of a change nobody has reviewed. It is recorded in the ledger below
as `held`, with its full key, and becomes an ordinary candidate the day #328 lands or closes.
If #328 fixes it, it never needed a ticket; if it survives #328, it is a live defect with a
reproducer already written.

| Class | Severity | Owner | Sites |
|---|---|---|---|
| A description that never learns the state changed | major | `game` | 9 |
| Nouns the prose prints that the parser denies | major | `game` | 6 |
| The thief's listing line and his gift line | major | `game` | 2 |
| The volcano's air half | major | `game` | 3 |
| The Endgame's two prose faults | major | `game` | 2 |
| Three stock lines in frames the game cannot re-skin | minor | `engine` / `game` | 3 |
| Two floor-level repeats | minor | `game` | 2 |
| `search trunk` finds nothing of interest in a trunk bulging with jewels | minor | `game` | 1 |
| The round's own coverage arithmetic | note | `harness` | 3 |

## Routed elsewhere

**#286** was passed as the round's one `routedIssue`, owning its still-unticked classes (D4,
D8, D11, D12 and the `needs-human` leftovers of its ticked boxes). **Nothing was routed to
it.** No symptom this round produced belonged to one of those classes — which is a real
result and not an omission: the three regions this round was built to reach are regions #286's
round never entered, so there was little for them to collide with.

## Refuted

Ten, and all ten turn on the same distinction rather than on ten different arguments: *a line
that is silent, awkward or incongruous is not a line that is false.* Six of the ten were
refuted as "judged in a frame it does not print in" or "restated the line more strongly than it
reads", and `explorer-1` and `explorer-3` own seven of the ten between them.

| # | Charter | Claim | Refutation |
|---|---|---|---|
| R1 | explorer-1 | The thief's only landing blow is a coup de grace, printed against a player never wounded once | The finding reported a missing wounded tier in `GnustoMeleeCombat`; the tier is there. At most a taste finding about one word, reported as a mechanism failure that does not exist. |
| R2 | explorer-1 | The thief's listing line says "leaning against one wall" while he is a shadowy figure passing through | The clause is true of any room with a wall, so there is nothing a fixer could point at as false. The line is trilogy-verbatim and prints wherever he stands. |
| R3 | explorer-1 | `take chalice` answers "You can't reach the silver chalice" one turn after the game said it vanished | An information leak, not a false sentence. |
| R4 | explorer-1 | A theft from the player's own hands is reported with the passive line used for the floor | Same line, both cases, by design. |
| R5 | explorer-2 | The Gas Room's smell promises a worsening ten turns never deliver | The smell is a warning about an open flame, not a countdown. |
| R6 | timekeeper-3 | The gnome says he has no time to waste and is still on the ledge 29 turns later | `gnomeLeaves` is five turns from the moment you *first speak to him*, which the tester had not done. |
| R7 | explorer-3 | `x brick` calls the brick hollow one turn after the fuse is packed into it | Hollow is what it is; the fuse does not fill it. |
| R8 | explorer-3 | Volcano Bottom says daylight enters from the cone, and the room is pitch black | Rated `note`; the description is of the place, not of the light the player has. |
| R9 | timekeeper-1 | The lantern's final line tells the player to find more light, in a daylit outdoor room | The line is the lamp's, not the room's, and the game does not claim the room went dark. |
| R10 | timekeeper-3 | "The ledge collapses." is broadcast unbranched to every room inside the volcano | Judged in a frame it does not print in. |

### Rater-independence audit

The workflow persists nothing, so the rationales exist nowhere afterwards unless the report
carries them. Two raters, batches of 25, 40 findings each rated twice, no single-rated finding.
Agreement 29/40 = **72.5%**; the 11 disagreements all resolved to `needs-human`.

Here is one finding both raters refuted, with each rater's `attemptedRefutation` in full — R2,
the thief's listing line:

> **Rater 1** — The case FOR: a man who 'slips into the room' and leaves the same turn is not
> idling against the masonry, so 'leaning against one wall' reads as a pose belonging to
> somewhere he lives. That is a real stylistic tension, and if the line had said 'against the
> granite wall' or 'over his hoard' I would have confirmed it. It does not — it says something
> true of any room with a wall — so there is no clause a fixer could point at as false, and
> 'rewrite it anyway' is the taste finding the brief ranks lowest.

> **Rater 2** — The strongest case AGAINST my refutation, which is real: "leaning" is a settled
> posture, and a man who slipped in one turn ago and melts away at the end of this one is
> passing through, not lounging. If the round wanted that as the finding, it would need to
> argue posture rather than place, and it would need to reckon with the fact that the prowling
> thief is meant to be doing exactly this. The clause would have to be false for me to confirm;
> it is at worst mildly incongruous, and the doc comment records the line as trilogy-verbatim,
> where the identical LDESC prints wherever the thief stands. Refused on 'a line that is silent
> or awkward is not a line that is false' — the ledger's own standing note about the Dam
> charter.

**They read as separately reasoned, not interchangeable.** Rater 1 argues from what a fixer
could point at; rater 2 argues from posture versus place and then from provenance, and reaches
the same verdict by a route rater 1 does not take. Both open by stating the case against
themselves, which is the brief working. Doc-licensed refutations were 4 of 40 — well under the
two-in-five threshold at which the blind brief would need tightening — so the blindness is
priced correctly.

## Coverage

**This section is the completeness critic's, and it corrects the workflow's own header three
ways. Read it before believing any number above it.**

### The nine targets #291 set

| # | #291's target | Reached | Evidence |
|---|---|---|---|
| 1 | `thief.roams` × the lit prowl rooms | **yes** | fired 494×; the presence line read in the Cyclops Room and the Treasure Room |
| 2 | `thief.steals` in the player's room, `thief.fights` in the lair | **yes** | `steals` 494×, `fights` 2,368×, `stashes` 494×, `admires` 7×, `opensEgg` 7× |
| 3 | `damLeak` × Maintenance Room, all nine rungs plus the drown | **yes** | fired 28×; explorer-2 rode it to drowning without leaving the room |
| 4 | `gnomeArrives` / `gnomeLeaves` × Wide Ledge | **yes** | arrive at drift-off+10, leave at first-word+5, on-cell and displaced |
| 5 | `slideGrip` × the Slide | **yes** | fired 3×; the grip expired and the wing was read |
| 6 | `dustyRoomFalls` and `wideLedgeFalls`, on foot and untied-balloon | **yes** | both death branches taken on foot (blast+5 and blast+13); the stranding branch too |
| 7 | Coal Mine — gas × open flame, coal-to-diamond, `object:coal:burn` | **partly** | 17 of 20 rooms entered, the machine worked; **`object:coal:burn` still untaken** |
| 8 | `object:trunk:open` × Reservoir | **no** | explorer-2 drew the `abstain` divergence policy and declined it; the trunk was *searched*, which is finding C9 |
| 9 | `lanternDim` / `lanternLastGasp` / `lanternDies` read in a true frame | **yes** | all three fired in the timekeepers' own replay trees and were read; one produced R9, refuted |

Six of #291's nine are clean, one is partial, one produced a finding by a different verb, and
one — the trunk — was declined by a divergence policy rather than by budget. That last is worth
naming: `abstain` is a legitimate policy and the fork is irreversible, but with one explorer
per region there was no committing tester left to take it.

### The room denominator is wrong in both directions

Dungeon declares **195 rooms**; 173 carry `isReachable: true`, and the workflow scores against
that flag. The eight ids it reported "on no roster" are none of the three explanations it
offers — not a stale build, not another game, not a runtime name. They are eight rooms the
survey itself flags `isReachable: false` **and players stood in anyway**:

```
DungeonAlice.cage          DungeonVolcano.volcanoCore
DungeonBank.smallRoom      DungeonVolcano.volcanoNearNarrowLedge
DungeonBank.vault          DungeonVolcano.volcanoNearViewingLedge
DungeonRiver.river1        DungeonVolcano.volcanoNearWideLedge
```

`definition.reachableRooms` walks the static exit table, and these eight are entered by
rule-driven moves — balloon flight, the bank curtain teleport, the river current, the cage drop
— so the table cannot see them. **The honest playable denominator is at least 181.**

### Entered is not covered, and here the gap is a factor of five

128 distinct room ids were entered. **63 of them — 49% — come from exactly two sessions and are
unique to neither.** `explorer-3` and `timekeeper-3` each report the identical 127 rooms,
because both pasted a ~700-command committed prefix. Longest verbatim prefix per session,
measured against `.context/playtest/routes/*.txt`:

| session | commands | route prefix | its own |
|---|---|---|---|
| explorer-3 | 734 | **717** | **17** |
| timekeeper-3 | 618 | **596** | **22** |
| timekeeper-2 | 136 | 120 | 16 |
| explorer-2 | 267 | 120 | 147 |
| wrong-footer | 134 | 41 | 93 |
| explorer-1 | 93 | 34 | 59 |
| timekeeper-1 | 74 | 51 | 23 |
| solver | 27 | 10 | 17 |

explorer-3's entire own session work is 7 commands; timekeeper-3's is 2. Counting a room
**worked** only when a charter typed a non-travel, non-meta command in it past its prefix:
**26 rooms worked with a charter's own session commands**, 49 more worked only inside a pasted
walkthrough, and across every artifact in the round 125 room names stood in, 87 worked, **38
stood in and never worked anywhere by anybody**.

**26 of ~181 is 14%. The header reads as 69%.** A long proven prefix bought this round its nine
targets — and it also bought a coverage number that is not coverage. Both are true and the
second is the price of the first; the fix is an instrument change, not a smaller prefix (see
*What the next round should take*).

Fairness note: `timekeeper-1`, `timekeeper-2` and `solver` did most of their real work in their
own `bin/playtest-replay` trees, which `closing.json` cannot see, so 26 is a floor.

### The grid, region × charter

`X` = worked with the charter's own commands · `r` = commands typed, but only inside a pasted
route · `.` = entered, travel only · `-` = never entered

```
region       decl/reach   ex1  ex2  ex3  tk1  tk2  tk3  slv   wf | entered
AboveGround      14/14     X    X    r    X    r    r    X    X  |  13
House             4/4      X    X    r    X    r    r    X    X  |   4
Cellar            5/5      X    X    X    X    r    r    -    X  |   4
Maze             23/23     X    r    r    X    r    r    -    X  |  10
RoundRoom         8/8      -    X    r    -    r    r    -    -  |   8
Temple           12/12     -    X    r    -    r    r    -    -  |  12
Dam               9/9      -    X    r    -    X    r    -    -  |   8
CoalMine         20/20     -    X    r    -    -    r    -    -  |  17
Mirror           10/10     -    X    r    -    -    r    -    -  |   9
Volcano          11/7      -    -    r    -    -    X    -    -  |  10
Palantir          7/7      -    -    X    -    -    .    -    -  |   3
River            17/16     -    -    r    -    -    r    -    -  |  11
Bank              9/7      -    -    r    -    -    r    -    -  |   6
Alice             9/8      -    -    r    -    -    r    -    -  |   9
Riddle            2/2      -    -    r    -    -    r    -    -  |   2
RoyalPuzzle       3/3      -    -    r    -    -    r    -    -  |   2
Endgame          32/18     -    -    -    -    -    -    -    -  |   0
                195/173                                          | 128
```

**Six regions have no `X` anywhere** — River, Bank, Alice, Riddle, RoyalPuzzle and the air half
of Volcano. Every command ever typed in them this round was somebody else's walkthrough
scrolling past. **The Endgame's 32 rooms were entered by zero sessions**: the solver
gate-tested the wing thoroughly through 11 replay probes and the 716-point win route, and says
plainly that it played no live turn deeper than move 26. Gating is not reading. The two
failures must be kept apart — the `interrogator` charter is *unrun*; the Endgame is *unread but
gate-proven*. Neither is clean.

### Charters

No charter that ran found nothing; all eight are represented in the 40 findings.
**`interrogator` never ran at all**, filtering itself out on the absent `GnustoConversation`.
That is a blank, not a clean bill: nothing about ask/tell/show/give-to-actor, addressed
imperatives beyond the handful `wrong-footer` improvised at the thief, or conversational
refusals was probed by anybody. The one `properName` actor in the cast — the volcano gnome —
had `greet gnome` and `follow gnome` left **unrun** on `wrong-footer`'s own mandatory checklist,
because it could not reach him.

### Timers

35 declared. The workflow's session-only list names ten never fired and **overstates by six**:
`lanternDies` and `lanternLastGasp` both fired and were read in the timekeepers' own
`bin/playtest-replay` trees, and `endgame.crypt`, `endgame.mirror`, `endgame.quiz` and
`endgame.herald` were exercised in the solver's replay probes.

**Genuinely untouched by any artifact in this round: four.** `cageGas`
(`Regions/Alice.swift:573`, fuse after 6), `exorcismLapse` (`Regions/Temple.swift:720`, fuse
after 6, re-armed at 3), `endgame.pine` and `endgame.swordGlow`. `exorcismLapse` is the
sharpest of the four: its line is said `from: entranceToHades`, which is exactly the
`say(_:from:)` frame question this harness exists to ask, and it has never printed.

Fired counts, this round: `endgame.blessing` 2368 · `endgame.master` 2368 · `forestSongbird`
2368 · `grue` 2368 · `melee.troll` 2368 · `thief.fights` 2368 · `thief.roams` 494 ·
`thief.stashes` 494 · `thief.steals` 494 · `damLeak` 28 · `balloonDrifts` 26 · `matchBurnsOut`
13 · `candlesBurn` 9 · `brochureArrives` 7 · `thief.admires` 7 · `thief.opensEgg` 7 ·
`burnerBurnsOut` 6 · `dustyRoomFalls` 6 · `brickBlast` 5 · `wideLedgeFalls` 4 · `bellCools` 3 ·
`slideGrip` 3 · `gnomeArrives` 2 · `lanternDim` 2 · `gnomeLeaves` 1.

One apparent contradiction was chased and came back clean, on the record: `"You'd better have
more light..."` appears in `timekeeper-1`'s session transcript while its `closing.json` records
`lanternDies: 0`. The line is inside a `//` tester comment at line 519, not game output. The
session-level record is right about sessions.

### Turns

Total `turn=cost` under `.context/playtest/`: **45,915**.

| | workflow header | actual |
|---|---|---|
| testers | 9,397 | **16,932** (2,020 session + 512 branch + 6,865 `play-*` + 7,535 `.replays`) |
| verifiers | 28,423 | **20,888** |
| orchestrator, pre-dispatch | — | **8,095** |
| total | 37,820 | **45,915** |

The 8,095 residual the harness flags resolves exactly and is named here as SKILL.md requires:
`prefix-check` 4,233 + `thief-rate` 2,190 + `thief-prefix` 1,664 + `Dungeon-survey` 8. All
Dungeon, all mtimed 18:32–19:26, before the testers were dispatched at 19:30. It is the
orchestrator's own pre-dispatch work — proving the nine route files land where the charters
were told, and measuring the thief's teleport rate. It is a fourth tree the arithmetic counts
for nobody.

The misattribution is separate and worse: the header credits `.replays` (7,535 turns, 63
probes) to the verifiers, and every one of those probes is mtimed 19:30–19:44, the tester
window. Verifiers ran 19:53–20:02, in the `Dungeon-r1-verify-*` trees. `.replays` is the MCP
`replay` tool, which only a live session can call. **The verifier:tester ratio is 1.2:1, not
3:1 — this round did not argue more than it played**, and the header's own warning fires on a
number that is not real.

### Forks nobody took

19 stand. The critic spent one probe establishing that they are declined rather than expensive:
`.context/playtest/Dungeon-critic/probe-002/transcript.txt` reaches `object:garlic:eat` at turn
**13** and `object:water:drink` at turn **16** from a cold start. Eight charters converged on
the same opening and none typed either word — and `eat garlic` answers *"The clove of garlic is
not something you could eat."*, a stock refusal on an item the mainframe makes edible and uses
as bat repellent.

The other 17: `object:bags:eat`, `object:bell:open`, `object:bodies:open`, `object:book:burn`,
`object:chute:burn`, `object:coal:burn`, `object:dam:open`, `object:door:burn`,
`object:egg:eat`, `object:gate:open`, `object:lamp:burn`, `object:lettering:burn`,
`object:pool:drink`, `object:river:drink`, `object:rope:burn`, `object:torch:burn`,
`object:trunk:open`.

### Unknown words — clean, and worth saying so

Three tokens: `,` (a parser separator; harness noise), `let`, and **`vandals`**. `vandals` is a
game-printed noun and it did not go unfiled — `wrong-footer` caught it, it reached verification
as finding 15, and it is confirmed. No gap.

### Findings dropped

18 dropped as non-reproducible, 10 merged into an existing class before verification. All 28
are carried into the next round's dedupe set and **none is counted as covered**.
`sessionsUnfinished`: 0 — all eight sessions closed and left a `closing.json`.

## What the next round should take

The critic's ranked list, recorded here rather than filed, because a coverage plan is a plan
and not a defect. #291 was the last one of these and it worked; this is its successor.

1. **Fix the instrument first.** Score rooms against declared locations rather than
   `definition.reachableRooms`; attribute `.context/playtest/.replays/` to the tester who
   opened the session; refuse to credit a room whose only commands came from a pasted
   `routes/*.txt` prefix; and fold the orchestrator's pre-dispatch trees in as a named fourth
   tree. Until the third of those lands, sending a charter down a long committed route buys the
   round a coverage number and no coverage.
2. **The Endgame, played rather than gated.** 32 rooms, 0 entered. The solver's existing saves
   (`Dungeon-r1-play-solver`, slots `stage15`/`chutehead`/`tomb`/`stairs`/`entrance`) make the
   walk free; hand them to a blind explorer and a timekeeper to *read*.
3. **The six regions with no `X`** — River, Bank, Alice, Riddle, RoyalPuzzle, and the air half
   of Volcano — one explorer each, with no route longer than its budget.
4. **The four timers nothing touched**, `exorcismLapse` first.
5. **The `interrogator` charter, which has never run**, pointed at the gnome and the thief.
6. **The cheap irreversible forks**, `object:garlic:eat` and `object:trunk:open` foremost — and
   a committing divergence policy on whichever explorer owns the trunk.

## Hygiene

- Seed **52**, read from `DungeonWalkthroughTests.seed`. `verifyEffort: medium`, declared.
- `swift build` clean; `swift test` — **1,950 tests in 121 suites, 0 failures**.
- `node .claude/workflows/playtest.dryrun.mjs` — all assertions passed, before dispatch.
- Strict lint clean.
- The round changed no code. Test files ±0; no assertion removed, no needle weakened.
- Charters not run: `interrogator` (no `GnustoConversation`).
- **Dispatch note.** The round was driven through `.claude/workflows/playtest.js` as always,
  but the `Workflow` tool is not on every agent's tool surface. Where it is absent, a headless
  `claude -p` session in the same checkout has it — and the game MCP servers connect there once
  `swift build` has run to completion, which is the cold-start warning SKILL.md already gives
  under *Before you dispatch a round*. Two things that session needs and the default does not
  provide: `MCP_TIMEOUT=180000`, and `CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0` — without the
  second, the session terminates its own background tasks after 600 seconds and the round dies
  silently at whatever phase it had reached. The first attempt at this round died exactly that
  way, in the play phase, and was re-run from scratch.
