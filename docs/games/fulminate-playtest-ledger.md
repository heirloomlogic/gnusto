# Fulminate — playtest ledger

Append-only. One row per dedupe key the harness has ever seen, with what became of it.

This is the loop's memory, and it exists for two reasons. Without it, a round
rediscovers everything a previous round already rejected, forever — the harness argues
with itself instead of converging. And with it, a key marked `fixed` that shows up again
is not a new finding, it is a **regression**, and it goes back at raised severity.

Pass `ledgerKeys` into the workflow with every key below whose verdict is `refuted` or
`fixed`.

The key is `<ownerFile>::<normalized offending text>`, with the frame deliberately
excluded — one untrue sentence seen at two hours is one defect, so keying on the frame
would dispatch two fixers at one branch. Keys are abbreviated here for reading; the
full ones are in the round reports.

## 2026-07-29 — calibration, `3fab729` and `c9d3cb5` (`fix: none`, nothing applied)

Every row below was found against a historical tree, not against `main`. They are
recorded so a later round can tell a rediscovery from a regression, but **none of them
is an open defect in the current game** — they were all fixed on the way to `main`, by
`3ec0521`, `c9d3cb5`, `1460aad` and `23195d5`.

| Key (abbreviated) | Tree | Verdict | Note |
|---|---|---|---|
| `Fulminate.swift::black and white tile worn through to the grout…` | A | confirmed | A1. Unanswerable noun; the reply is an unknown-word reply but the game printed the word, so K8 not #76 |
| `Fulminate.swift::the dr pike would take exception to that` | A | confirmed | A2. `cantTakeActor` not re-skinned; missed on the first pass, found after the vandal's checklist was made explicit |
| `Fulminate.swift::the only person here who has looked at the wreckage…` | A | confirmed | A3 |
| `Fulminate.swift::mrs vane is in her chair with the lamp unlit` | A | confirmed | A4, the marquee defect. Found independently by two charters |
| `Fulminate.swift::fifty and wearing his hat indoors…` | A | confirmed | A5 |
| `DefaultActions.swift::search clock → you cant see any such thing` | A | confirmed | **Not in the answer key.** The substance of `1460aad`; found unprompted |
| `Fulminate.swift::on her feet with her arms at her sides looking at the fire` | C | confirmed | C1. Introduced by `c9d3cb5` — the fix for A4 reintroduced the class one branch shallower |
| `Fulminate.swift::the note in your ears steps down one` | C | confirmed | C3. Introduced by `3ec0521`, half-fixed by `c9d3cb5` |
| `Fulminate.swift::the dust comes down the passage… settles on the hall table` | C | confirmed | Introduced by `3ec0521`. Points at itself when read in the kitchen |

Refuted keys from these rounds are listed in the round report rather than here, because
a refutation against a historical tree does not license suppressing the same claim
against `main` — the code it was refuted on isn't the code that ships.

## Provenance, for the rows marked "introduced"

```
git log -S 'looking at the fire' --oneline 23195d5 -- Sources/Fulminate/Fulminate.swift
  23195d5 Fix the second round of Fulminate playtest notes
  c9d3cb5 Add live presence lines, and fix the Fulminate playtest notes   <- introduced
```

`c9d3cb5`'s own commit message says *"One of them was mine."* It is the tree's
confession, and reproducing it mechanically is the capability that separates this
harness from one that only re-finds old bugs.

## 2026-07-31 — first round against `main`, `9659318` (`fix: none`, nothing applied)

Every `confirmed` row below is an **open defect in the game as it ships**, filed as
**#122**. Full keys, frames and reproducers: `docs/games/fulminate-playtest-2026-07-31.md`.
Seed `0`, 7 charters, 273 probes, 3,616 engine turns. 70 raised → 57 confirmed,
13 refuted. Deduplicating the 57 by root cause gives 18 classes; the Class column names
them in the order they appear as checklist boxes in #122, so `C1` is the first box and
`C17` the seventeenth. `C18` is the harness box and has no rows here — it was found by
the completeness critic and confirmed by hand, not raised as a tester finding.

None of the rows from the 2026-07-29 calibration reappeared, so this round records **no
regressions**. `ledgerKeys` was passed empty on purpose: every existing row is `confirmed`
against a historical tree rather than `refuted` or `fixed`, and suppressing those would have
hidden regressions rather than duplicates.

| Key (abbreviated) | Class | Verdict | Note |
|---|---|---|---|
| `Fulminate.swift::mrs vane is on the step and no further watching it burn delphi…` | C1 nouns | confirmed | major, tourist |
| `Fulminate.swift::slates come out of the sky and go into the grass edgefirst  th…` | C1 nouns | confirmed | major, tourist |
| `Fulminate.swift::dr pike is standing about with his hat on   x hat you cant see…` | C1 nouns | confirmed | major, tourist |
| `Fulminate.swift::black and white tile worn through to the grout along the line…` | C1 nouns | confirmed | major, tourist |
| `Fulminate.swift::x tile black and white laid in a diamond and worn through to t…` | C1 nouns | confirmed | minor, tourist |
| `Fulminate.swift::scrubbed pine and a stove that has been going since before you…` | C1 nouns | confirmed | major, tourist |
| `Fulminate.swift::somebodys workshop and somebody elses chapel a long scarred be…` | C1 nouns | confirmed | major, tourist |
| `Fulminate.swift::x coal bin a plank bin with three winters of coal dust in it a…` | C1 nouns | confirmed | major, tourist |
| `Fulminate.swift::dry grass and a low brick wall that used to be taller the carr…` | C1 nouns | confirmed | major, tourist |
| `Fulminate.swift::north the patrolman puts an arm across the gap without any par…` | C1 nouns | confirmed | minor, tourist |
| `Fulminate.swift::something in the wreckage lets go and settles and the note in…` | C8 wreckage scope | needs-human | minor, tourist |
| `Fulminate.swift::a typewriter with a sheet still in it and a suitcase on the be…` | C9 suitcase | confirmed | major, tourist |
| `Fulminate.swift::a desk with a green shade over the lamp and every drawer stand…` | C14 desk | confirmed | minor, tourist |
| `Fulminate.swift::x letters a dozen letters in three different hands tied with g…` | C1 nouns | confirmed | minor, tourist |
| `Fulminate.swift::x lamp a standard lamp with a fringed shade and a bulb that ha…` | C1 nouns | confirmed | minor, tourist |
| `Fulminate.swift::a radio car pulls up out front and a patrolman comes through t…` | C1 nouns | confirmed | minor, tourist |
| `Fulminate.swift::t10 548  player walks out to the yard blastafter fires here  w…` | C4 blast.after | confirmed | major, clock-watcher |
| `Fulminate.swift::t8 544  says he is going for cigarettes and goes  z time passe…` | C10 timetable stops | confirmed | major, clock-watcher |
| `Fulminate.swift::somewhere out behind the house something goes off with a flat…` | C1 nouns | confirmed | minor, clock-watcher |
| `Fulminate.swift::t41 650 the deadline  z time passes the county man comes up th…` | C13 coroner | needs-human | minor, clock-watcher |
| `Fulminate.swift::time your watch says 552 pm a car door goes out front a patrol…` | C10 timetable stops | confirmed | minor, clock-watcher |
| `Fulminate.swift::greet constance yes says mrs vane to no question and goes on l…` | C2 room staging | confirmed | major, vandal |
| `Fulminate.swift::ask constance about parlour i have been in the parlour all eve…` | C2 room staging | confirmed | major, vandal |
| `Fulminate.swift::ask constance about rockets mrs vane looks past you at the wal…` | C2 room staging | confirmed | major, vandal |
| `Fulminate.swift::there is no moment in which it is about to happen the carriage…` | C6 stubs | confirmed | major, vandal, introduced by 93597fa |
| `Fulminate.swift::listen you hear nothing out of the ordinary something in the w…` | C6 stubs | confirmed | major, vandal, introduced by 93597fa |
| `Fulminate.swift::smell you smell nothing out of the ordinary a radio car pulls…` | C6 stubs | confirmed | major, vandal, introduced by 93597fa |
| `StubVerbs.swift::eat mrs kettle mrs kettle is not food  pull mrs kettle mrs ket…` | C7 stubs at people | needs-human | major, vandal, introduced by 63593d5 |
| `StubVerbs.swift::search mrs kettle you are not putting a hand on mrs kettle ton…` | C7 stubs at people | needs-human | major, vandal, introduced by 93597fa |
| `Fulminate.swift::black and white tile worn through to the grout  the front door…` | C6 stubs | confirmed | major, vandal, introduced by 93597fa |
| `Fulminate.swift::furniture too big for the room and too good to sell arranged a…` | C6 stubs | confirmed | major, vandal |
| `Fulminate.swift::ask kettle about delphine miss marsh was in the back yard when…` | C3 tense | confirmed | major, interrogator |
| `Fulminate.swift::mrs vane comes out as far as the step and stops there she does…` | C2 room staging | confirmed | major, interrogator |
| `Conversation.swift::show letters to delphine she unties the string and reads the t…` | C5 shows again | confirmed | major, interrogator |
| `Fulminate.swift::show watch to patrolman the patrolman looks at it and looks aw…` | C12 noInterest case | confirmed | major, interrogator |
| `Fulminate.swift::howard teague is here being helpful  ask teague about drugstor…` | C3 tense | confirmed | major, interrogator |
| `Fulminate.swift::west back yard dry grass and a garden wall that is now shorter…` | C4 blast.after | confirmed | major, solver |
| `Fulminate.swift::the county man comes up the path at ten to seven and he is not…` | C13 coroner | confirmed | minor, solver |
| `Fulminate.swift::accuse mrs vane the county man writes down her name and closes…` | C17 score line | needs-human | minor, solver |
| `Fulminate.swift::dry grass and a garden wall that is now shorter at the north e…` | C1 nouns | confirmed | major, idiot |
| `Fulminate.swift::what is left of the carriage house is standing in pieces and s…` | C8 wreckage scope | needs-human | major, idiot |
| `Fulminate.swift::north front hall there is an overcoat here  x can a paperwrapp…` | C11 sealed can | needs-human | major, idiot |
| `Fulminate.swift::take all suitcase taken   i you are carrying a suitcase a wris…` | C9 suitcase | confirmed | major, idiot |
| `Fulminate.swift::boarders room a typewriter with a sheet still in it and a suit…` | C9 suitcase | confirmed | minor, idiot |
| `Fulminate.swift::time your watch says 546 pm somewhere out behind the house som…` | C11 sealed can | needs-human | minor, idiot |
| `Fulminate.swift::mrs vane is in her chair with the lamp unlit dr pike is standi…` | C1 nouns | confirmed | minor, idiot |
| `Fulminate.swift::ask constance about julian she takes a moment to find you as t…` | C1 nouns | confirmed | minor, idiot |
| `Fulminate.swift::somewhere out behind the house something goes off  in the kitc…` | C1 nouns | confirmed | minor, idiot |
| `Conversation.swift::show glove to constance she takes it out of your hand which yo…` | C5 shows again | confirmed | major, re-reader |
| `Fulminate.swift::ask kettle about constance mrs vane was in the parlour when it…` | C3 tense | confirmed | major, re-reader |
| `Fulminate.swift::show receipt to teague he looks at it for a while sixohfive he…` | C2 room staging | confirmed | major, re-reader |
| `Fulminate.swift::x suitcase brown scuffed at the corners and packed the strap i…` | C9 suitcase | confirmed | major, re-reader |
| `Fulminate.swift::ask patrolman about wreckage not till the county mans been he…` | C1 nouns | confirmed | major, re-reader |
| `Fulminate.swift::ask teague about drugstore mrs kettle keeps a good kitchen and…` | C16 arithmetic | needs-human | minor, re-reader |
| `Fulminate.swift::show glove to constance she takes it out of your hand which yo…` | C15 glove | confirmed | minor, re-reader |
| `Fulminate.swift::west vanes study a desk with a green shade over the lamp and e…` | C14 desk | confirmed | minor, re-reader |
| `Fulminate.swift::dr pike is standing about with his hat on   x hat you cant see…` | C1 nouns | confirmed | minor, re-reader |

### Refuted this round — pass these as `ledgerKeys` next time

| Key (abbreviated) | Charter | Refutation kind |
|---|---|---|
| `Fulminate.swift::cellar cold and low enough that you walk it at a stoop it smel…` | tourist | stock-behavior-by-design |
| `Fulminate.swift::search coat the overcoat is empty  open coat you cant open tha…` | tourist | stock-behavior-by-design |
| `Fulminate.swift::mrs kettle comes out drying her hands and does not stop drying…` | clock-watcher | misquoted-prose |
| `Fulminate.swift::sing your singing is better kept to yourself  pray your prayer…` | vandal | licensed-by-doc |
| `Fulminate.swift::pike go north dr pike hears you out and goes on doing exactly…` | interrogator | licensed-by-doc |
| `Fulminate.swift::delphine marsh did not go down when it went she did not even p…` | solver | characterization |
| `Fulminate.swift::time your watch says 550 pm something in the wreckage lets go…` | solver | licensed-by-doc |
| `Fulminate.swift::time your watch says 546 pm somewhere out behind the house som…` | solver | licensed-by-doc |
| `Conversation.swift::show receipt to teague he looks at it for a while sixohfive he…` | solver | stock-behavior-by-design |
| `Fulminate.swift::look back yard dry grass and a garden wall that is now shorter…` | idiot | licensed-by-doc |
| `Fulminate.swift::dr pike arrives in the yard holding his hat against his chest…` | idiot | licensed-by-doc |
| `Fulminate.swift::x lamp a standard lamp with a fringed shade and a bulb that ha…` | idiot | stock-behavior-by-design |
| `Fulminate.swift::look boarders room a typewriter with a sheet still in it and a…` | re-reader | stock-behavior-by-design |

Four of the thirteen refutations handed over a *better* claim than the one they killed.
Only one of those — the suitcase still described "on the bed" after `take` — was also filed
independently, by the idiot charter, and appears above as a `C9 suitcase` row. The other
three (Pike's examine text contradicting his own arrival line; `attack`/`wave`/`give`
aimed at a listed actor; a stale source comment at `Fulminate.swift:268-270`) were never
raised as findings, so
they have no keys and are carried as next-round targets in the report rather than as rows
here.

## 2026-08-17 — second round against `main`, `1df88f3` (`fix: none`, nothing applied)

Every `confirmed` row below is an **open defect in the game as it ships**, filed as
**#280**. Full keys, frames, reproducers, coverage grids and the harness result:
`docs/games/fulminate-playtest-2026-08-17.md`. Seed `0`, 6 charters, 81 probes, 1,505
engine turns. 15 raised → 15 confirmed (10 `confirmed-defect`, 5 `needs-human`), 12
refuted. Verifier agreement 88.9% over 27 double-rated findings, 0 single-rated.
Deduplicating the 15 by root cause gives 13 classes; the critic added 3 more that no
tester raised, for the 16 checklist boxes in #280, and the Class column names them in box
order. `C13`, `C14` and `C16` are the harness boxes and have no rows here — like `C18` of
the previous round, they were found by the completeness critic and confirmed by hand.

**This round records regressions, and they are the round's headline.** Seven of the
fifteen findings were introduced by `7c92508`, the commit that fixed the previous round's
eighteen classes, so the 2026-07-31 entry's claim that no fix in this repo's history
reintroduced a class it was fixing no longer holds. Two are verifiable in that diff:
`7c92508` added `text.stubs.climb` and `text.stubs.stand` verbatim, and it removed an
unanswerable noun from the blast paragraph (class `C1` of the last round) while adding a
fresh one, `window`, to the lab lamp. A further four findings trace to `ed8d377`
(2026-07-29) and so predate the previous round and were missed by it. The `C13` engine row
is a separate regression, two days old, from `7cec4aa`.

`ledgerKeys` was passed as the **seven** keys from the 2026-07-31 refuted table that were
*not* refuted as `licensed-by-doc`. The six that were (R04, R05, R07, R08, R10, R11) were
withheld on purpose: `docs/games/fulminate.md:77-83` has since narrowed that clause, and
passing them would have suppressed findings the doc now says are filable.

**Keys below are the workflow's own, recorded in full and untruncated** — the shape dedup
actually compares. Every previous row in this file is display-truncated with `…`, which
`normalize()` never emits, so none of them can match anything: dedup keys on
`decl::<file>::<declaration>` whenever the clusterer locates the declaration and only
falls back to `<ownerFile>::<normalized excerpt>` when it returns `unlocated`. Row `C15`
below is the one finding that took that fallback, and its key is excerpt-derived noise
rather than a declaration — recorded as returned, and not expected to match.

| Key | Class | Verdict | Note |
|---|---|---|---|
| `decl::Sources/Fulminate/Fulminate.swift::clock` | C1 status-clock | fixed | major, wrong-footer, **regression introduced by `7cec4aa`**; `ownerClass` engine, real site `Sources/GnustoClock/Clock.swift` + `GameWorld.statusFields()`. Repaired 2026-08-18 — see [Amendments](#amendments) |
| `decl::Sources/Fulminate/Fulminate.swift::teague.description` | C2 teague death clause | confirmed | major, explorer-1, introduced by `ed8d377` |
| `decl::Sources/Fulminate/Fulminate.swift::timers/clock.blast` | C3 blast deixis | fixed | major, explorer-1, introduced by `7c92508`. Repaired under #305 — `playerStorey` branches `.cellar`/`.ground`/`.upstairs` |
| `decl::Sources/Fulminate/Fulminate.swift::timers/blast.after` | C3 blast deixis | fixed | minor, explorer-1, introduced by `ed8d377`. Repaired under #305, same branch |
| `decl::Sources/Fulminate/Fulminate.swift::rules/suitcase.before(.take)` | C4 suitcase owner | confirmed | major, explorer-1, introduced by `7c92508` |
| `decl::Sources/Fulminate/Fulminate.swift::rules/kettle.topics/teague` | C5 kettle testimony | fixed | major, interrogator, introduced by `7c92508`. She testifies to **both** crossings, a lookup on each: 5:36 down the back stairs, 5:42 back in from the yard. The `needs-human` fork — which crossing the confession hangs on — was resolved as *both*, since she is at the stove until 5:48 and watched the pair |
| `decl::Sources/Fulminate/Fulminate.swift::rules/constance.topics/julian` | C6 constance chair | fixed | major, interrogator, introduced by `ed8d377`. `perform:` + `constance.isIn(parlour)`. **Six further sites swept in the same PR**, none of them sighted by the round — see the Class 5 note below |
| `decl::Sources/Fulminate/Fulminate.swift::rules/teague.topics/constance` | C7 window | confirmed | major, interrogator, introduced by `ed8d377` |
| `decl::Sources/Fulminate/Fulminate.swift::rules/labLamp.describe` | C7 window | confirmed | minor, solver, **introduced by `7c92508` while fixing C1 of the last round** |
| `decl::Sources/Fulminate/Fulminate.swift::glove` | C8 glove placement | fixed | major, explorer-2, the round's one true rater split. Split per channel: `firstSight(…)` carries where it was found, `description(…)` what it is. The split settles the disagreement in the direction of discoverability — the clue now prints for every player who lights the cellar, not only one who examines before taking |
| `decl::Sources/Fulminate/Fulminate.swift::teagueDay` | C9 boarder's light | fixed | major, explorer-2, introduced by `7c92508`. A `ceilingLight` scenery item, not a prose deletion: the room prints the noun in exactly one line, so the item is placeable. It refuses ON in voice rather than becoming a `lightSource`, because `Stop(arrival:)` is a fixed `String` and could not read the switch |
| `decl::Sources/Fulminate/Fulminate.swift::text/stubs.stand` | C10 stand stub | fixed | major, wrong-footer, **line added by `7c92508`**. The finding's own diagnosis was wrong and was corrected on #280 before the fix: there *was* a read of `knockedFlat`, one turn wide. Repaired by widening `world.before(.stand)` onto `wasInTheYardForTheBlast`, not by assigning the line |
| `decl::Sources/Fulminate/Fulminate.swift::text/stubs.climb` | C11 climb stub | fixed | major, wrong-footer, **line added by `7c92508`**. `.naming(orBare:)`, plus the three flights taking CLIMB for themselves |
| `decl::Sources/Gnusto/Actions/GameText.swift::Stubs.touch` | C12 touch | fixed | major, wrong-footer; site to change is Fulminate's `text.stubs.touch`, and that is where it changed. Stove, stove pipe and yard fire answer for themselves |
| `Sources/Fulminate/Fulminate.swift::z time passes  z time passes  z time passes  z time passes  z time passes` | C15 back yard crossings | fixed | minor, timekeeper; the one `unlocated` fallback key this round. A `perform:` closure on each of the two stops that already narrate the crossing, saying `say(_:from: backYard)` — not a `backYard` stop on the timetable, because the clock samples even minutes only, so a yard stop has to take one off the kitchen or carriage-house leg and `sawTeague` is anchored on the end of the second |

### Refuted this round — pass these as `ledgerKeys` next time

| Key | Charter | Refutation kind |
|---|---|---|
| `decl::Sources/Fulminate/Fulminate.swift::parlourLamp` | explorer-1 | none |
| `decl::Sources/Fulminate/Fulminate.swift::rules/coat.before(.take)` | explorer-1 | licensed-by-doc |
| `decl::Sources/Fulminate/Fulminate.swift::intro` | explorer-1 | stock-behavior-by-design |
| `decl::Sources/Fulminate/Fulminate.swift::drawer` | explorer-1 | stock-behavior-by-design |
| `decl::Sources/Fulminate/Fulminate.swift::studyLamp` | explorer-2 | stock-behavior-by-design |
| `decl::Sources/Fulminate/Fulminate.swift::teague.firstSight` | explorer-2 | characterization |
| `decl::Sources/Fulminate/Fulminate.swift::timers/clock.coroner` | explorer-2 | licensed-by-doc |
| `decl::Sources/Fulminate/Fulminate.swift::rules/constance.presence` | timekeeper | licensed-by-doc |
| `decl::Sources/Fulminate/Fulminate.swift::rules/world.before(.stand)` | timekeeper | stock-behavior-by-design |
| `decl::Sources/Fulminate/Fulminate.swift::rules/pike.topics/fallback` | interrogator | characterization |
| `decl::Sources/Fulminate/Fulminate.swift::actions/accuse` | solver | licensed-by-doc |
| `decl::Sources/Gnusto/Actions/GameText.swift::Stubs.pray` | wrong-footer | stock-behavior-by-design |

Four of the twelve refutations still leaned on `licensed-by-doc`, so the clause the design
doc narrowed after the last round is still doing real work and is still worth watching.
Three refutations went and fetched evidence rather than arguing from the finding's own
text — the post-6:10 receipt in the overcoat, three live `scoreLine` values, and a grep
proving `.attack` and `.kiss` are not re-skinned in this tree — and one of those overturned
a finding by showing its reproducer landed fourteen minutes before the frame it described.

Two residual claims surfaced inside refutation prose and were never filed as findings, so
they have no keys and are carried as next-round targets in the report rather than as rows
here: Dr. Pike's presence line *"standing about with his hat on"* printing unchanged in
the Back Yard in front of a burning building, and the Boarder's Room bed described as
made with squared corners while Teague sits on it. Both were raised as unprobed cells by
explorer-2 rather than as claims, and neither has a verified frame.

## 2026-08-26 — third round against `main`, `da3e623` (`fix: none`, nothing applied)

Every `confirmed` row below is an **open defect in the game as it ships**, filed as
**#334**. Full keys, frames, reproducers, coverage grids, the rater-independence audit and
the refutations: `docs/games/fulminate-playtest-2026-08-26.md`. Seed `0`, 9 charters
(explorer ×3, timekeeper ×3, interrogator, solver, wrong-footer), 9 sessions, 1,288 engine
turns counted off the footers. 22 raised → 16 confirmed (12 unanimous `confirmed-defect`,
4 `needs-human`), 6 refuted, 0 routed. Verifier agreement 81.8% over 22 double-rated
findings, 0 single-rated. Deduplicating the 16 by declaration gives 15 and by root cause 6
classes; the critic added 3 more that no tester raised, for the 9 checklist boxes in #334.
The last two boxes are the harness's and have no rows here.

**This round wrote the game its first focus file.** `docs/games/fulminate-playtest-focus.md`
is new, three regions, split on the vertical *and* clock axes — the fix for the 2026-08-17
round's own diagnosis that a clock-only split left the second storey owned by nobody. It
worked: 13 of the 16 confirmed findings are in rooms the previous round reached with one
charter or none, both scheduled arrival lines that had printed in zero transcripts of any
round printed in tester transcripts, and all four `show` surfaces fired including the two
that never had. **It also produced the round's largest hole** — the split is floor × hour,
six of nine seats drew the upstairs floor, and the Carriage House (which exists only before
5:44) got zero commands in 1,288 turns, taking the victim, a death ending and an unread
`clock.blast` branch with it. Both halves are in #334.

**`ledgerKeys` was overridden by hand, 109 → 15, and the reason was a preflight defect
that has since been fixed on this branch — `ledgerKeysFrom` now reads the verdict column
and returns refutations only, so Fulminate derives 31 rather than 109 and no `confirmed`
or `fixed` row reaches a tester. The paragraph below is kept as the record of why.**
`ledgerKeysFrom()` (`bin/playtest-preflight:371-376`) scrapes *every* backticked `a::b`
string in this file, `confirmed` rows included. The 2026-08-17 rows are full untruncated
`decl::` keys, so unlike every earlier row they match dedup exactly — and four of them
(C2, C4, and both C7s) are still open and unrepaired. Passing them would have told testers
those were already rejected. What was passed instead: the 2026-08-17 and 2026-07-31
**refuted** tables only, minus the `licensed-by-doc` ones, on the reason the 2026-08-17
entry gives for withholding six of the same kind. That was a box in #334 and it is now closed: the
function reads the verdict column, so the three tables of refutations in this file are
what travels and nothing else does. The remaining judgement — whether to withhold the
`licensed-by-doc` refutations — stays the operator's, because it is a reading of the
design doc rather than a column in a table.

**Dedup did not catch C1 and C9, which are one line.** Two testers reached
`Stop(at: TimeOfDay(17, 36), …, departure:)` in `teagueDay` (`Fulminate.swift:1106`) by
different routes; the clusterer located one against the room the frame printed in
(`boardersRoom`) and the other against the timetable (`teagueDay`), so they carry different
keys and were verified twice. Both keys are recorded, and the second is the real site.

**C16 has no confirming vote and is recorded as such.** A split verdict reconciles to
`needs-human` (`playtest.js:1799`) and `needs-human` counts into `confirmed`, so a finding
that drew `needs-human` + `refuted` — no rater confirming it — reached the confirmed list.
It is a scope question for a person, not a defect, and #334 says so in its own box.

| Key | Class | Verdict | Note |
|---|---|---|---|
| `decl::Sources/Fulminate/Fulminate.swift::boardersRoom` | departure-names-wrong-frame | needs-human | major, explorer-1. **Same line as the `teagueDay` row below** — dedup missed it; the real site is `Fulminate.swift:1106`. Raters split: rater 1 refuted on "the engine only prints a departure in the room being left", rater 2 confirmed on the ground that this makes the co-located frame the *only* frame the line will ever have. Preexisting, `60179c4` |
| `decl::Sources/Fulminate/Fulminate.swift::teagueDay` | departure-names-wrong-frame | needs-human | major, explorer-2, the sharper reproducer: the listing line and the offstage-sound departure land in one turn's output. Same declaration as the row above. Preexisting, `60179c4` |
| `decl::Sources/Fulminate/Fulminate.swift::delphineDay` | departure-names-wrong-frame | confirmed | major, timekeeper-2. "Delphine takes the cellar stairs down" printed in Vane's Study; her previous stop pins the printing room upstairs, so it can never print anywhere else. `Fulminate.swift:1230`. Preexisting, `60179c4` |
| `decl::Sources/Fulminate/Fulminate.swift::pike` | pike-hat-state-unread | confirmed | major, explorer-2. Static `description` at `:911`; the show row sets `learning: .notebooksSold`, so the state to branch on already exists. Preexisting, `ed8d377` |
| `decl::Sources/Fulminate/Fixtures.swift::pikeHat` | pike-hat-state-unread | confirmed | major, explorer-2. A second, independent declaration (`Fixtures.swift:96`) carrying the same now-false claim. Fixing Pike's describer leaves this standing. Preexisting, `7c92508` |
| `decl::Sources/Fulminate/Fulminate.swift::talk.topics(of: pike)` | pike-hat-state-unread | confirmed | minor, interrogator. Three sibling strings (`:2461`, `:2485`, `:2687`) stage him under a brim he is not wearing; `:2687` is the `again:` of the row that removed the hat. Preexisting, `ed8d377` |
| `decl::Sources/Fulminate/Fulminate.swift::desk` | unanswerable-noun | confirmed | major, explorer-1. `papers` — the arrangement is the clue, so the noun cannot be deleted. **Introduced by `7c92508`**, the commit whose job was closing this class |
| `decl::Sources/Fulminate/Fulminate.swift::ceilingLight` | unanswerable-noun | confirmed | major, explorer-1. `chain`, named twice and carrying the evidence. **Introduced by `9caa400`** (2026-08-24), which added this object to close an unanswerable-noun defect on it and printed two new nouns, declaring one |
| `decl::Sources/Fulminate/Fulminate.swift::timers.fuse("blast.after")` | unanswerable-noun | confirmed | minor, explorer-1. `dust`, declared settled on every flat top in six rooms; the word exists only as a synonym on the cellar's coal bin. Preexisting, `ed8d377` |
| `decl::Sources/Fulminate/Fulminate.swift::dryGrass.describe` | unanswerable-noun | confirmed | major, explorer-3. `circle` — *"a scorched half-circle"*, absent from the vocabulary entirely. Preexisting, `ed8d377` |
| `decl::Sources/Fulminate/Fulminate.swift::cellarSteps` | unanswerable-noun | confirmed | minor, timekeeper-3. Declared in the Kitchen only, so the noun leaves scope the moment the player walks down it — and the Cellar's own 6:26 arrival line prints it. Preexisting, `60179c4` |
| `decl::Sources/Gnusto/Actions/GameText.swift::cantTurnOnThat` | prose-offers-what-the-mechanic-refuses | confirmed | minor, explorer-1. `studyLamp` (`:960`) has no device trait after two sentences about its switch. `ownerClass` game; the site to change is Fulminate's, not the engine's. Preexisting, `ed8d377` |
| `decl::Sources/Gnusto/Actions/GameText.swift::stubs.pull` | prose-offers-what-the-mechanic-refuses | confirmed | minor, explorer-1. `pull light` on a pull chain. One-token repair: add `.pull` to the existing `ceilingLight.before(.turnOn, .turnOff)`. **Introduced by `9caa400`** |
| `decl::Sources/Fulminate/Fulminate.swift::carriageHouse.describe` | prose-offers-what-the-mechanic-refuses | confirmed | minor, explorer-3. `enter wreckage` refuses during the three turns the doc says the lab is open, while `north` walks in — wrong in both directions. Preexisting, `ed8d377` |
| `decl::Sources/Fulminate/Fulminate.swift::text` | player-description-deixis | needs-human | major, wrong-footer. `text.selfDescription` (`:158`) says "in this hall" from a rented bedroom, and worse on the Landing, which the doc's map table calls "Upstairs hall". Raters split on present-tense claim vs. past-tense clause. Preexisting, `0cf1325` |
| `decl::Sources/Gnusto/Actions/GameText.swift::stubs` | stub-register | needs-human | minor, wrong-footer. Eight stubs at the engine default against seven the game re-skinned. **No rater confirmed this** — one `needs-human`, one `refuted`. Recorded as a scope question, not a defect. `a800ac4` is the pass that set the house voice for the other seven |

### Refuted this round — pass these as `ledgerKeys` next time

| Key | Charter | Refutation kind |
|---|---|---|
| `decl::Sources/Fulminate/Fulminate.swift::timers.clock.at("clock.radioCar")` | explorer-3 | stock-behavior-by-design |
| `decl::Sources/Fulminate/Fulminate.swift::timers.fuse("blast.settling")` | explorer-3 | licensed-by-doc |
| `decl::Sources/Fulminate/Fulminate.swift::landing` | explorer-1 | licensed-by-doc |
| `decl::Sources/Fulminate/Fulminate.swift::constance.before(.accuse)` | solver | licensed-by-doc |
| `decl::Sources/Gnusto/Actions/DefaultActions.swift::examine` | explorer-3 | stock-behavior-by-design |
| `decl::Sources/Gnusto/Actions/GameText.swift::lostThem` | explorer-1 | stock-behavior-by-design |

**Three of the six are `licensed-by-doc`, which is the clause the 2026-08-17 entry warned
was load-bearing and worth watching. It still is.** One of the three should be withheld
next round on a narrower ground than the clause itself: `constance.before(.accuse)` was
refuted against an *indoor* ending frame, and the completeness critic found a
**carriage-house death** frame where the same line says "in that house" after the building
it names has stopped existing. That is a different frame and is fair to file, not a
re-find.

**Never argued at all, and therefore neither confirmed nor cleared:** `arroyo` (printed by
`x pike`), `lining` (`x glove`), `stoop` (the Cellar description). All three are the same
printed-then-refused class as `papers` and `chain`, both of which the raters confirmed
unanimously. They sat in the round's unknown-word tally and reached no report. Carried as
**unexamined**, not as covered, and not passed as `ledgerKeys`.

## Amendments

**2026-08-18 — the `C1 status-clock` row marked `fixed`.** The `[status]` footer box of
#280, and the one finding of that round that was never Fulminate's: the game's prose was
right all along and the scaffolding under it was a tick fast.

The round left it `needs-human` because three repairs were reasonable and the verifier
declined to pick. Fix **(a)** was taken — the contributed fields are now sampled at the
turn's close, before the move counter advances, which is the instant every rule,
`describe` block and timer in that turn read. The other two were rejected with reasons
that are now standing tests rather than an argument in a commit message:

- **(b) subtract `minutesPerTurn` inside `Clock.statusFields`** reads a minute early on a
  paused clock, on a clock moved by `advance(by:)` mid-turn, and on a free turn.
  `aPausedClockReadsTheSameHourInTheProseAndTheFooter` and
  `aClockAdvancedInsideATurnIsReportedAtItsNewHour` are that objection, kept honest.
- **(c) leave the code and correct the documents** would have left
  `finding-contract.md`'s instruction to read the hour off the footer permanently
  qualified — for a field three charters had already worked around by hand and two had
  dropped sound findings over.

The sample rides on the turn's own `Scratch` and `GameWorld.commit(_:)` adopts it, so a
frame that never ran `finishTurn` — the opening, UNDO, RESTART, RESTORE — carries nil and
*clears the previous sample by committing*. That shape was chosen over clearing at each
entry point because an entry-point list has to be kept complete, and the first draft of
one had already missed `requestQuit()`, which reaches `runTurn` without passing through
`performAudited`.

Five tests, four of which fail against the old behaviour; the two that pinned the
off-by-one (`aClockGameShowsTheHour`, and `PlaytestSessionTests`'
`aCommentIsRecordedAndCostsNoTurnAndNoClockTick`) were updated, and nothing else in the
suite moved. Docs corrected in six places, including one claim on
`GameWorld.statusFields()` that was simply false: *"the whole thing is skipped when
nobody declared a field"* is true only of a game with no content bundle at all, because
`Bootstrap` collects one closure per module whether or not the module overrides the
default.

**The other fifteen boxes of #280 are untouched by this.** They are Fulminate's own prose
and stand as filed.

---

### 2026-08-24 — Class 5, and the four `needs-human` boxes

#280's remaining bench, closed. Five boxes moved: **C6** (the sighted Class 5 site) and
the four the round flagged `needs-human` — **C5**, **C8**, **C9**, **C15**. **C3** was
ticked without work: it had already been repaired under #305 and nobody went back to the
box.

**C6 was one site of seven.** The round sighted Mrs. Vane's chair arms and nothing else,
and the reason is worth recording: the reflex reading of that finding is "she named the
parlour," and she did not — she named *a chair*. The parlour is not in the sentence, so a
search for room names walks straight past it, and past the six others:

| Site | Fragment | Frame that contradicted it |
|---|---|---|
| `constance.topics/julian` (C6) | "Her hands go back to the arms of the chair" | Back Yard, 5:48–5:52 |
| `constance.topics/julian` (broke) | "She looks at the lamp she has not lit" | same; the only lamp in the garden is burning |
| `constance.topics/evening` (broke) | "I have been in this chair since" | `talk.shows(glove,…)` carries no room or time gate |
| `delphine.topics/julian` | "She looks at the wreckage" | Vane's Study from 6:02, Cellar from 6:26 |
| `delphine.topics/yard` | "I was out here" | same — deixis, printed indoors and in the dark |
| `kettle.topics/julian` + table `again:` | "The pot gets a stir it does not need" | Back Yard, 5:48–6:00 |
| `teague.topics/drugstore` | "He recrosses his legs" | he stands until 6:30 — **sighted by the 2026-07-31 round** and left `needs-human` |

The last row is the one that should sting: it was found a round earlier, filed, and never
picked up, and it is the same defect the later round refound under a different actor.

**Three findings that only appeared while repairing:**

- **A table's `again:` retires `reply:` rows only.** Converting Mrs. Kettle's `julian` row
  to `perform:` so its body could branch silently dropped it out of the table's repeat
  handling, and the row began repeating itself verbatim. It carries its own `again:` now.
  Anyone taking a site in this class should expect the same.
- **Her table-level `again:` is now unreachable**, because every row below it is `perform:`
  or carries its own. It was corrected rather than left as it was: the next `reply:` row
  written there should inherit a sentence that travels.
- **C5's row was true of the room and false of the minute.** The timetable read supplies
  the *room*, and both of the crossings she watches resolve to the kitchen — so the lookup
  could not see that the row described the 5:36 descent and quoted 5:42. The general form
  is worth keeping: **a lookup proves the noun it returns and nothing else in the
  sentence.**

**The `needs-human` forks, and how each was decided.**

- **C5** — *both* crossings, a lookup on each, rather than moving the anchor to 5:36 or
  rewriting the event to the 5:42 return. She is at the stove until 5:48 and watched the
  pair, so testifying to both is the version that makes the contract's demonstration
  stronger, and it moves no gate: `sawTeague` stays at 5:42, because she cannot testify to
  the second crossing before it happens.
- **C8** — the placement clause moves to `firstSight(…)`. The round's one true rater split
  was whether the clause is *what the glove is* or *where it was found*; it is the second,
  and the split resolves in the direction of discoverability, since the clue now prints for
  every player who lights the cellar rather than only for one who examines before taking.
- **C9** — a `ceilingLight` item, against #319's precedent of losing the noun. #319 chose
  deletion because those nouns could print in many rooms; this one prints in exactly one
  line in exactly one room, so the item is placeable. It **refuses ON in the game's voice
  rather than becoming a `lightSource`** — a switchable bulb would be state
  `Stop(arrival:)` cannot read, and a player who had pulled the chain would be told Teague
  did not put on a light that was on. That is this round's own defect, installed while
  fixing it.
- **C15** — a `perform:` closure on each of the two stops that already narrate the
  crossing, saying `say(_:from: backYard)`. The documented idiom is a `backYard` stop of its
  own, and it was rejected on arithmetic: the clock samples even minutes only, so a yard
  stop has to take a minute off either the kitchen or the carriage-house leg, and C5's
  testimony is anchored on the end of the second. The crossing is now told three times over
  three rooms rather than moved.

  **The first draft was a `backYard.afterEachTurn` diffing `teagueDay.location(at:)` across
  two minutes**, and `/simplify` retired it: the clock already performs that transition, so
  the rule was re-deriving an event rather than reacting to one, it re-read a computed
  `Timetable` twice on every turn a player stood in the yard, and it filed the crossing's
  third line away from the two it belongs to. `Stop`'s own `perform:` was the answer the
  whole time — the argument written into that draft was against adding a *stop*, which is a
  different proposal.

Ten new transcript tests, each asserting the frame where the line is true *and* the frame
where it lied. All ten were confirmed to **fail** against the old source rather than
assumed to. Every site was also driven at the keyboard and read as prose.
