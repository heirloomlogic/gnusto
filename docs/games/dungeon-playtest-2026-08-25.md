# Dungeon — playtest round, 2026-08-25

Commit `3a3b3e3` · seed `52` · `fix: none` · charters: explorer ×3, timekeeper ×3, solver,
wrong-footer (interrogator filtered itself out — Dungeon depends on no `GnustoConversation`).
Oracle tiers: T0 kernel, T1 `docs/games/dungeon.md`, T2 `DungeonWalkthroughTests`, T3 source,
T4 ledger — all five. **`verifyEffort: medium`, turned down from the inherited default** to
afford a three-region split with a proven save per region; SKILL.md requires the header to say
so. Budget: 120 turns per charter over 8 seats.

48 findings reached verification. **33 confirmed, 11 refuted, 4 dropped, 0 routed.** The
workflow reports 33/15/0; four of its fifteen refutations are a procedural non-answer rather
than a refutation and are reclassified here — see *Dropped*. Rater agreement 31 of 44 = 70.5%.

**Turns: 15,074 `turn=cost` lines under `.context/playtest/`, residual zero.** Testers 7,781,
verifiers 859, orchestrator 6,434. Every tree is attributed; this is the first Dungeon round
for which that is true.

**33 `refuted` ledger keys were passed as `ledgerKeys`; every `fixed` and `confirmed` key was
withheld**, because a `fixed` key feeds `seen` and would make the harness drop a regression in
silence — and `3a3b3e3` had just rewritten 28 of those sites. Nothing was passed as a
`routedIssue`: `gh issue list --state open --label enhancement` returned empty, and the repo's
only open issue is #281, a SwiftPM pin owning no defect class.

**The completeness critic rates the round `verifier-suspect`, not `round-is-thin`.** The
coverage complaint that dominated the last three rounds is discharged. The new complaint is
about the verifier, and it is correct.

## Why this round exists

The 2026-08-24 round confirmed 30 findings and its own critic still called it thin, for a map
reason: six regions had no charter-typed command in them at all, the Endgame's 32 rooms were
entered by zero live sessions, and 26 of ~181 rooms were *worked* against a header reading 69%.
Two sessions had pasted ~700-command route prefixes and contributed nine commands of their own
between them.

That round's ranked list is this round's charter. Item 1, *fix the instrument*, landed in
`3a3b3e3`. Items 2–6 are here.

### The construction: saves, not prefixes

The seven target areas sit 270–780 commands down the committed walkthrough. A pasted prefix
charges its whole length against a 120-turn budget; a `restore` costs one free turn. So the
round's preparation was **ten entry points, each cut from a committed array, replayed, and its
landing room read off the `[status]` footer before anybody was dispatched.**

| Slot | Cut from | Landed in | moves | score |
|---|---|---|---:|---:|
| `r1-1` | `DungeonEndgameTests.intoTheEndgame` (771 cmds) | Tomb of the Unknown Implementer | 754 | 616 |
| `r1-2` | `pastTheCrypt` (778) | Top of Stairs | 761 | 631 |
| `r1-3` | `pastTheCrypt + throughTheBox` (804) | Dungeon Entrance | 787 | 661 |
| `r1-4` | `+ theQuiz` (808) | Dungeon Entrance, all three answered | 791 | 661 |
| `r2-1` | `route[0:278]` | West Teller's Room | 270 | 260 |
| `r2-2` | `route[0:338]` | Low Room | 329 | 341 |
| `r3-1` | `route[0:447]` | Dam Base, raft inflated | 436 | 413 |
| `r3-2` | `route[0:493]` | Room in a Puzzle | 481 | 471 |
| `r3-3` | `route[0:567]` | Volcano Bottom, in the basket | 554 | 511 |
| `wf-1` | `route[0:441]` | Reservoir North | 430 | 413 |

**The slice indices are the artifact**; `.context/` is gitignored and the files regenerate in
one line. `route` is **747 commands at HEAD** and the seed is read from
`DungeonWalkthroughTests.seed`, never from a number written down elsewhere.

Three things a later round must not re-derive the hard way:

- **The 2026-08-24 round's nine indices are off by one at HEAD.** `38e27b8` removed `drop rope`
  at old index 98 and `3a3b3e3` rewrote stage 15.
- **A stage head is not an entry point.** Every stage of this route begins and ends at the
  trophy case, so `route[0:270]` — the head of the Bank stage — lands in the Living Room. The
  first cut of `r2-1`/`r2-2`/`r3-1`/`r3-3` was made at stage heads, landed all four at home,
  and was thrown away. Cut at the first index whose footer names a room in the target region.
- **Saves are label-scoped.** Both `bin/playtest-replay` and the session server use
  `.context/playtest/<label>/saves/`, and there is no cross-label restore. Each slot was
  replayed once under `prefix-check-<slot>` and the `.gnusto` file copied into the eight
  `Dungeon-r1-session-<key>/saves/` directories the workflow's own labels resolve to. Verified
  end to end before dispatch: a copied, renamed save restores to its recorded room.

Slots are named `r<N>-<n>` and never after where they land. The region text is pasted verbatim
into a blind explorer's prompt, so it was checked mechanically against Dungeon's 129 room
display names: the three blind-visible focus segments contain none. A fourth focus segment
carries the sighted seats' assignments — `regions.length` is 4 but `copies` caps at 3, so
segment 4 is assigned to no explorer and read only by charters that get the whole string.

### It worked, and here is the measurement

**Longest verbatim run from any `routes/*.txt` file, per session: zero. For all eight.** Every
one of 1,260 in-session commands was the tester's own. Seven of eight sessions open
`restore` / `<slot>` / `look`; the eighth is `wrong-footer`, deliberately cold.

That is why `roomsWorked` can be read straight this round. The harness calls it an upper bound
because a route file's own `take lamp` credits its room — here there is no route file in any
session to over-count.

## The round

**Nine sites where a static `description` states an exit the map does not have, or a state the
world has left behind.** The class is three rounds old; the map is new.

- Small Room's description reuses Stone Room's exit sentence verbatim — "A passage leads north,
  and the stairs go up to the south" → frame: Small Room, `up` answers "You can't go that way."
  → cause: the sentence is true of Stone Room, which has the staircase, and was copied to a
  room whose south exit is level.
- Dungeon Entrance says "Passages lead away to the south" → frame: south is a wall of wood →
  cause: the description was written for the room before the door was added and never branched.
- The Parapet says "A stair leads down to the south" → frame: `down` refused, `south` works.
- The winning cell names the bronze door in the south wall as the only way out → frame: `south`
  refused from inside the docked cell.
- With the beam blocked, one LOOK prints both that the beam crosses from one wall to the other
  and that it is interrupted → cause: two sentences on one axis, neither reading the other.

**Eleven unanswerable nouns, and they cluster exactly where no tester had been.** `joints` and
the masonry in the Endgame's Stone Room; `depository` and `doorway` in both teller rooms;
`landing` at Top of Stairs; `staff` on the Dungeon Master; `plate` and `wall` in the Machine
Room; `watch` on the gnome; `depression` in the Pool Room; `forest` in the Forest; and every
scenery noun the river stretches print — landing, dam, shore, cliffs, rocks, beach, bank.
CLAUDE.md states the rule without qualification: *every noun a room description prints must be
answerable.*

**One blocking finding.** The Bank's curtain of light is a single object that stays wherever it
last set the player down, so after one transit the wing cannot be traversed as its own signs
describe.

**Two actors answer from outside their own frame.** The Dungeon Master's `before(.follow)` and
`before(.stay)` rules answer from anywhere in the game; "The Dungeon Master walks away and is
gone." prints to a player shut in the Prison Cell who cannot see him. And `endgame.pine` prints
one unbranched sentence in every room beside the box.

## Filed

One issue for the round, holding every confirmed class as a checklist row. 33 confirmed:
19 major, 11 minor, 1 blocking, 2 note. `ownerClass`: 31 game, 2 engine.

| class | n |
|---|---:|
| `unanswerable-noun` | 11 |
| `exit-prose-mismatch` | 5 |
| `prose-untrue-of-state` | 5 |
| `prose-untrue-of-frame` | 5 |
| `unwinnable` | 2 |
| `prose-taste` | 2 |
| `gate-not-gating` | 1 |
| `mechanic-contradicts-prose` | 1 |
| `repeat-behavior` | 1 |

## Refuted

Eleven, each with a dedupe key and a reasoned argument. The verifier is plainly reading rather
than stamping: refutations cite MDL line numbers (`dung.355:2976`, `act4.231:1024`,
`rooms.394:794`), quote the reproducing frame with move numbers, and in two cases run a further
probe to knock down the finding's *premise* rather than its conclusion.

Seven of the eleven are some form of "the source or the doc already says so"
(`required-by-contract` ×2, `licensed-by-doc` ×1, `stock-behavior-by-design` ×4). That is 47%,
just over the two-in-five line the brief sets. Not alarming for a first blind round on
mainframe Zork, where the mechanics contract is unusually load-bearing — but it is the number
to watch. If the next blind round is also near half, the brief needs a line telling testers
that reproduced MDL puzzle structure is not a prose defect, without handing them the doc.

### Rater-independence audit

Three findings drew the same verdict from both raters with both rationales on the record.

- **Small Room's stairs (both confirmed).** *Separately reasoned.* Both steel-man the deictic
  reading and kill it with different evidence — rater 1 on the exit-list position and the fact
  that `UP` is refused outright, rater 2 on the room's three real northward exits being
  compressed into one clause.
- **Bronze door (both refuted).** *Separately reasoned, the clearest of the three.* Rater 1
  argues from internal contrast — the door that really cannot be opened says so, in
  `Prose.lockedCellDoor`. Rater 2 argues from the source and the map. Neither rationale
  contains the other's evidence.
- **Beam blocked (both confirmed).** *Close to interchangeable.* Both build the same defence,
  illustrate it with a swapped simile, and kill it with the same three moves in the same order.
  This one is not independent evidence.

**Two of three separately reasoned, one interchangeable. 70.5% agreement is low enough to be
real** — two rubber-stampers agree at 95–100%, and thirteen disagreements over 44 findings is a
working panel.

The independence problem in this round is not the raters. It is that the panel accepted a
procedural non-answer as a verdict four times, and nothing in the two-rater design catches
that, because both raters were handed the same broken tool.

## Dropped

**Four findings, reclassified out of `refuted`.** All four carry the identical verdict string —
`not-reproducible: The tester did not re-verify the trimmed reproducer from a clean start.` —
which names a defect in the tester's process, not in the claim. All four carry an **empty
dedupe key**, so none could enter the ledger regardless.

The cause is on the record: **the MCP `replay` tool is sessionless and boots into
`.context/playtest/.replays/`, which holds no save files**, so it answers `Restore failed.` to
every `r1-*`/`r2-*`/`r3-*` slot. Probes 001–005, 007, 010 and 016 under `.replays/` all carry
that line. Any reproducer needing a save could not satisfy `replayedCleanly`. Three seats
worked around it independently — `timekeeper-1` by copying the saves into its own label,
`explorer-1` and `explorer-2` by re-issuing the game's own `restore` in-session — and the
verifier found the same fix mid-round (`verify-b01-r2-01` through `-05` failed, `-01b` through
`-05b` succeeded) and never applied it backwards.

Two of the four were re-run from a clean start with the slot restored, first by the round's
critic and then independently while writing this report
(`.context/playtest/Dungeon-check/river/transcript.txt`, seven commands):

```
> launch    …The river flows quietly here.               [moves=438]
> x river   The Frigid River lives up to its name, and it is in a hurry.   [moves=439]
> wait / wait / look
            …The river flows quietly here.               [moves=443, still stretch 1]
```

Both reproduce. Whether they are *defects* is a live question the verifier never reached —
"flows quietly" against "in a hurry" may be reproduced mainframe copy, and a poled boat with no
current may be by design — but `not-reproducible` is a statement of fact and it is the wrong
one. All four are carried into the next round's dedupe set and **none is counted as covered.**

**This is a harness defect the round's own construction exposed**, and it is the first item on
the next round's list.

## Coverage

This section is the completeness critic's, recounted off the artifacts. **The workflow's
arithmetic is correct this round** — every published number reconciles — but three of its
figures are computed over the wrong denominator and are corrected here.

### Rooms — 72 of 195 entered, 68 worked, and the two numbers are honest

72 visited, 68 worked, 123 never entered; 72 + 123 = 195 exactly, and no off-roster ids.

**Entered fell from 128 to 72 and that is the trade, not a regression.** Reach was exchanged
for coverage deliberately. The 2026-08-24 failure mode — 717 of 734 commands pasted and every
room they scrolled past scored as entered — does not occur here. This round's 72 is 72 rooms
somebody stood in and typed in.

Two corrections to the entered figure, both in the same direction:

- `DungeonAboveGround.forestDeep` is credited to four charters and was reached **by dying**. It
  is a resurrection landing, not exploration; `roomsOnlyInBranches` is `['…forestDeep']` for
  three of them.
- Every session's `westOfHouse` is the boot room the `restore` prompt is answered in.

The 4 entered-but-not-worked rooms are Clearing, Dam, Reservoir and East Corridor. The grid and
`worked` disagree nowhere.

### The grid — charter × region

Cell = rooms in that region the charter typed its own non-travel, non-meta command in.
`.` = entered, nothing typed. `–` = never reached.

| charter | Abv·14 | Hse·4 | Cel·5 | Maz·23 | Rnd·8 | Dam·9 | Tmp·12 | Mir·10 | Pal·7 | Mine·20 | Riv·17 | Vol·11 | Bnk·9 | Ali·9 | Rid·2 | Pzl·3 | End·32 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| explorer-1 | . | – | – | – | – | – | – | – | – | – | – | – | – | – | – | – | 11 |
| explorer-2 | 1† | – | 2 | – | – | – | 1 | – | – | – | – | – | 9 | 7 | 2 | – | – |
| explorer-3 | . | – | – | – | – | 1 | – | – | – | – | 8 | 2 | – | – | – | 1 | – |
| timekeeper-1 | . | – | – | – | – | – | – | – | – | – | – | – | – | – | – | – | 11 |
| timekeeper-2 | 1† | – | – | – | – | – | – | – | – | – | – | – | 7 | 7 | – | – | – |
| timekeeper-3 | 1† | – | – | – | – | – | – | – | – | – | – | 8 | – | – | – | – | – |
| solver | . | – | – | – | – | – | – | – | – | – | – | – | – | – | – | – | 10 |
| wrong-footer | 5 | 2 | – | – | 1 | 3 | – | – | – | – | 2 | – | – | – | – | – | 2 |
| **round** | **6** | **2** | **2** | **–** | **1** | **3** | **1** | **–** | **–** | **–** | **8** | **8** | **9** | **9** | **2** | **1** | **16** |

† the death-landing in the Forest, above.

**The seven areas this round was dispatched to read: Bank 9/9, Alice 9/9, Riddle 2/2 —
complete. River 8/17, Volcano 8/11, Endgame 16/32, RoyalPuzzle 1/3.** All seven cleared the
bar, which was one `X` each. Last round all seven were dashes or transit-only.

**Four entire regions are a solid dash: Maze 23, Coal Mine 20, Mirror 10, Palantir 7.** Sixty
rooms — 31% of the game — in which no live tester typed one command. Add Temple 1/12 and
RoundRoom 1/8 and it is 78 of 195 rooms in six regions effectively unread. That is nobody's
silence, because nobody was assigned there; a dash is the loudest cell on the board.

### Charters — three different silences, which must not look alike

- **`interrogator` — never dispatched**, filtering itself out on the absent
  `GnustoConversation`. It has now never run in four rounds. The cost this round: no seat
  systematically interrogated the Dungeon Master, the robot, the gnome or the thief.
  `explorer-2` got three distinct robot refusals by accident and says it "did not map which
  orders draw which"; `explorer-1` tried two Dungeon Master commands and never made the
  endgame's obvious next move. `ask` is not a word this engine knows, which an interrogator
  would have hit in its first ten turns.
- **`solver` — ran, and returned a real clean result on its own axis.** Dungeon is winnable at
  seed 52 on the documented chain: *"Your score is 716 of a possible 716, in 815 turns."* It
  attacked five gates and all held. But its live turns are moves 791–815, about 90 turns, all
  inside the endgame from save `r1-4`. Its silence covers ~25 rooms, not 195.
- **`wrong-footer` — ran, discharged both standing orders**, and published two genuine negative
  results: 21 stub verbs all re-skinned and in the game's register, and both player-entity rows
  clean. It opened the red buoy (reversible, nothing consumed — so last round's abstaining
  explorer gave up nothing) and typed `eat garlic` at move 32, which is finding 31. But it
  could not reach four of six generated article-sweep rows, and ran its repeat sweep only in
  the Living Room — never underground, never in a room with a live per-turn daemon, which is
  exactly where a stuck line would be.
- **`timekeeper-2`'s "my region is honestly clockless" is a true negative, not a shortfall.**
  `DungeonBank` declares no timers and `DungeonAlice` exactly one; it fired that one three
  different ways and converted the rest of its budget into state-axis work.

### Timers — eight never fired, not fourteen

The workflow's session-level census reports 14 never fired. It is right about sessions and
wrong about the round: `firedTimers` is a session field and a `bin/playtest-replay` probe
writes no closing record. **Six of the fourteen fired inside this round's own artifacts.**

| timer | census | actually |
|---|---|---|
| `exorcismLapse` | never fired | ✓ `Dungeon-critic-exorcism/exo-stay/transcript.txt` — "The tension of this ceremony is broken…", Entrance to Hades, moves 146 |
| `bellCools` | never fired | ✓ `…/exo-resume/transcript.txt` — "The bell appears to have cooled down.", moves 160 |
| `brochureArrives` | never fired | ✓ all three exorcism probes |
| `lanternDim` | never fired | ✓ six probes, e.g. `prefix-check-r1-stairs/probe-001/transcript.txt:4782` |
| `lanternLastGasp` | never fired | ✓ same six |
| `candlesBurn` | never fired | ✓ `Dungeon-critic/probe-003/transcript.txt` — three stages, all Entrance to Hades |

**Genuinely untouched by any artifact: eight** — `brickBlast`, `damLeak`, `dustyRoomFalls`,
`endgame.herald`, `lanternDies`, `slideGrip`, `thief.opensEgg`, `wideLedgeFalls`. Each was
grepped for its own body's prose across every transcript in the tree.

Two of the eight cannot be found by reading prose at all. `thief.opensEgg`'s body is
`aboveGround.egg.isOpen = true` and nothing else (`Dungeon+Thief.swift:328`) — it must be read
by state. `endgame.herald` is structurally unreachable here: no save in this round holds a
world below 616 points, and the herald arms at score + 10 per death.

Publishing fourteen would send the next round chasing five clocks already on the record.

**Three of the four timers the last round named as untouched fired this round**:
`endgame.swordGlow` 310×, `cageGas` 2×, `endgame.pine` 1×. The fourth, `exorcismLapse`, was
never assigned to a seat — it lives in `Regions/Temple.swift:735` and the Temple is not one of
the three regions, because regions were picked by "no `X` last round" and the Temple already
had one. **That is an operator error: a region is an assignment, and this timer was written
into no assignment.** It was closed afterwards by orchestrator probe rather than by a tester —
three probes at seed 52, provenance stated:

- `exo-stay` — ring the bell, stay: the line printed at +6, at the gate.
- `exo-leave` — ring the bell, walk two rooms away: the line printed **nowhere**.
- `exo-resume` — return and try to finish from stage 2: `read book` recited but did not banish;
  `east` still answered *"Some invisible force prevents you from passing through the gate."*

That is the full `say(_:from:)` contract, and the code's own comment states it: *"the state
change is unconditional and the telling is not."* Both halves hold. **Four rounds of silence on
this timer was a coverage gap, not a defect** — the only path anyone has ever walked, the
route's stage 5, completes the exorcism and calls `stopFuse`, so the fuse could never fire.

### Turns — reconciled exactly, residual zero

| bucket | turns | probes |
|---|---:|---:|
| tester sessions (transcripts + `branch-*.txt`) | 1,072 | 8 sessions |
| `.replays/` — the testers' | 47 | 18 |
| `Dungeon-r1-play-*` — testers' own CLI probes | 6,662 | 19 |
| `Dungeon-r1-verify-*` — verifiers | 859 | 105 |
| orchestrator: `prefix-check-*`, `Dungeon-survey`, `Dungeon-critic*`, `Dungeon-check` | 6,434 | 17 |
| **total on disk** | **15,074** | |

The workflow published 14,234 with 586 unattributed. The 586 is
`Dungeon-critic-exorcism/` (462) and `Dungeon-critic-trunk/` (124), written twenty-five minutes
after the last tester session closed — the orchestrator's own critic work under labels the
classifier's "every other label" bucket did not in fact catch. Both facts want fixing; neither
makes the total unsafe.

**Tester-to-verifier is 7,781 : 859, about 9:1.** This round played far more than it argued,
which is the healthy direction and the opposite of 2026-08-17. But testers were budgeted ~960
and spent 7,781 — an 8× overrun, almost all in the 6,662 turns of CLI reproducer probes, which
cost no session budget and so were never felt. Four seats say in their own `finish` notes that
they overspent the 120-turn session budget. **The budget is not being enforced and is not being
measured against the thing testers actually spend.**

### Unknown words — 17, not 49, and six printed nouns went unfiled

The survey reports 49 occurrences over 16 tokens. The top token is a bare `,` at 31
occurrences — punctuation from a comma-addressing attempt, not a word — and `frotz` is the
reserved non-word. **Net of both: 17 occurrences over 14 tokens**, which at this map size is
good news and should be read as such.

The gap is inside the 14. Three printed nouns were noticed and filed — `depository`, `joints`,
`watch`, each carrying a `[suspicious]` annotation. **Six more were typed once, refused, and
never followed up**, and every one is a noun the game itself prints: `concrete`
(`Prose+Dam.swift:74`), `robe` (`Prose+Endgame.swift:474`, the Dungeon Master's own
description), `vicinity` (`Prose+River.swift:23`), `wood`, `planks`, and `hallway` — the last
being the name of the room it was typed in. The rule is explicit: a word the game printed and
cannot answer is an ordinary finding. Six arrived as parse-record entries instead. **That is a
gap in the round.**

### Untaken forks — 37, and the label overstates the risk

The critic closed five of the 37 in 18 turns from a cold start
(`Dungeon-critic/probe-002/transcript.txt`): `burn nest`, `burn tree`, `burn trees`,
`open trees`, `open forest`. **Not one is irreversible.** With no flame in hand `burn X` is a
free refusal, and `open X` on scenery is a free refusal.

The fork queue labels every `burn`/`open`/`drink` on any noun a divergence, so "37 irreversible
forks declined" is a category error for at least those five and probably for most of the 15
`burn`/`open` rows on above-ground scenery. The genuinely committing set is much shorter:
`object:cake:eat` (the blue cake, the Alice death), `object:dam:open`, and putting the sharp
stick in the boat.

**`object:trunk:open` was never offered to anybody, and that is an operator error.**
`route[123]` is `take trunk`; `wf-1` was cut at `route[0:441]`, three hundred commands later,
by which point the trunk is in the trophy case. The slot was chosen by room name and not by
route state, and the `[status]` footer confirmed the right room while the world had moved on.
Probed afterwards at `route[0:123]` (`Dungeon-critic-trunk/trunk/transcript.txt`): `open trunk`
answers the stock *"You can't open that."* while `search trunk` answers a bespoke line. Whether
that pairing is a defect is a judgement the verifiers never got to make.

### Findings dropped

Four, above. Beyond them the round left **1,776 coverage-queue items open** at `finish`
(explorer-2 alone 379, explorer-3 283, timekeeper-2 283, wrong-footer 240). Nobody closed a
queue.

### Annotation density — a hygiene defect

43 `[suspicious]` notes across eight transcripts: explorer-1 12, explorer-3 12, explorer-2 9,
timekeeper-1 3, timekeeper-3 3, timekeeper-2 2, **solver 1, wrong-footer 1**. `wrong-footer`'s
`finish` note claims five verified reproducers; its transcript carries one annotation. Whatever
else it filed exists only in its structured report and cannot be found by a reader working from
the artifact. An annotation is what makes a finding auditable off the transcript six months
later, and two seats filed without leaving one.

## What the next round should take

1. **Fix `replay` so a reproducer can restore.** The sessionless `replay` tool boots into
   `.replays/` and cannot see the session's saves, which cost this round four findings and
   produced four false `not-reproducible` verdicts. Either give `replay` the calling session's
   save directory, or teach the verifier to copy saves into its label — the verifier discovered
   the second fix mid-round and never applied it backwards.
2. **Build a save with the thief ALIVE.** Route command 42 is `attack thief with sword`, so he
   is dead in every save this round shipped. That silently removed him from three of four
   regions, and it blocks `thief.opensEgg`, the timekeepers' arrival-and-departure passes in
   the Bank and Alice wings, and every listing line he has.
3. **The four zeroed regions** — Maze 23, Coal Mine 20, Mirror 10, Palantir 7. Sixty rooms, no
   seat. The mine's basket-and-machine has never been touched by anybody; `timekeeper-2` flagged
   that `r2-2`'s "Machine Room" is Alice's, not the mine's. `slideGrip` lives in Palantir and
   has never fired in any round.
4. **`damLeak` × Maintenance Room**, never fired anywhere in the tree. Push the blue button
   (`Regions/Dam.swift:745`), stay, and let the whole daemon run.
5. **The six unfiled printed nouns**, and a brief line making it explicit that a refused noun
   the game printed is a finding to file, not a parse-record entry.
6. **Measure the budget against CLI probes, not session turns.** Testers spent 8× their budget
   without feeling it.
7. **Fix the fork queue's label** so a free refusal is not called a divergence, or the next
   round spends a policy debate on `open forest`.

## Hygiene

- Seed **52**, read from `DungeonWalkthroughTests.seed`. `verifyEffort: medium`, declared.
- `swift build` clean. `node .claude/workflows/playtest.dryrun.mjs` — all assertions passed,
  before dispatch. The SKILL.md staleness check passed: `closing.json` carried `roomsVisited`,
  `roomsWorked`, `unknownWords` and `firedTimers`, and `replay` wrote `.replays/probe-001/`.
- The round changed no code. Test files ±0; no assertion removed, no needle weakened.
- Charters not run: `interrogator` (no `GnustoConversation`). Sessions unfinished: 0 — all
  eight closed and left a `closing.json`.
- **Dispatch note.** All seven game MCP servers failed to connect in the dispatching session.
  The cause is not `.mcp.json`: `bin/gnusto-mcp` runs `swift build` before it execs, seven
  servers start together, and SwiftPM serialises them on a `.build` lock — *"Another instance
  of SwiftPM (PID: …) is already running using '.build', waiting…"*. On a cold tree they all
  miss the client timeout. The round was dispatched through the headless `claude -p` fallback
  with `MCP_TIMEOUT=180000` and `CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0`; the servers connected
  on the fourth `ToolSearch` attempt once the tree was warm.
- Two stale facts found while preparing, neither this round's to fix: `docs/games/dungeon.md`
  lines 950 and 987 still say "seed 2" after the re-pin recorded at `FIDELITY.md:1285`, and
  `.claude/workflows/playtest.js:1741` says "143 rooms under 126 distinct names", which counts
  only literal `Location { }` declarations and misses the 52 built by factory functions.
