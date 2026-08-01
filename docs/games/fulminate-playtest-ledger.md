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
