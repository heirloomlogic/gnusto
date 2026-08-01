# Fulminate — playtest round, 2026-07-31

Commit `9659318` · seed `0` · `fix: "none"` · charters: tourist, clock-watcher, vandal,
interrogator, solver, idiot, re-reader (7 of 7 applicable, none skipped)
Oracle tiers: T0 kernel, T1 design doc (`docs/games/fulminate.md`, contract + timeline +
solution), T2 `FulminateTests`, T3 source, T4 git history.
Budget: 420 turns planned, **3,616 spent over 273 probes** — 8.6× the budget.
79 agents, 0 errors, 4.6M subagent tokens, 51 minutes wall clock.

**This is the first round ever run against `main`.** The 2026-07-29 round was a
calibration exercise against `3fab729` and `c9d3cb5`, neither an ancestor of `main`; it
graded the harness rather than the game and filed no issue. There is therefore no prior
finding count for this tree to be compared against, and none of the ledger's existing
rows was passed in as `ledgerKeys` — every one of them is `confirmed` against a
*historical* tree and was fixed on the way to `main`, so suppressing them would have
hidden regressions rather than duplicates. Nothing in the ledger reappeared.

70 findings raised → **57 confirmed** (48 `confirmed-defect`, 9 `needs-human`), 13
refuted, 0 routed, 0 fixed. Completeness critic: **sound**. Deduplicating the 57 by root
cause gives **18 classes**, filed as one issue.

## The round

The dominant class is the one the game's own design doc promises against and its test
suite half-checks: **nouns the prose puts on the page that the parser cannot answer.**
The transcripts hold 261 unknown-word replies over 59 distinct words, and separately a
long tail of `You can't see any such thing` answering words the room printed one line
earlier. Everything else divides into two families — prose written for one room while a
timetable moves the speaker through two, and engine defaults answering in frames the
game has just contradicted.

51 of the 57 predate this branch; 6 were introduced by two recent commits, both of them
feature work rather than repairs, so **no fix in this repo's history reintroduced a class
it was fixing** — the failure mode the 2026-07-29 calibration caught in `c9d3cb5` did not
recur.

- **~59 nouns the prose prints are not in the vocabulary, across all nine rooms.**
  *Frame:* everywhere, all evening — the Front Hall's `corner` and `passage` at 5:30, the
  indoor blast paragraph's `crockery`/`shelf`/`plaster`/`sash`/`pane` at 5:46 in six
  rooms, the yard's `fire` at 5:48 while three actors are described looking at it, Pike's
  `hat` in three rooms in five separate sentences, the cellar's `dust` in a search
  refusal that points the player straight at it. *Cause:* item vocabulary comes from
  `name`/`synonyms`/`adjectives`, and these nouns live only in prose — several are worse
  than absent, because `hat`, `marble` and `pine` are declared as *adjectives* and
  `board` and `carpet` resolve to items in other rooms, so the game answers "You can't
  see any such thing" for a word it printed one turn earlier. `FulminateTests` walks the
  house asking for six nouns and never fires a timed event, which is why the alarm prose
  is uncovered.
- **Four conversation replies stage themselves in a room the speaker has left.**
  *Frame:* Back Yard, 5:48–5:54, whenever Constance is on the step; Front Hall, 6:16, for
  Teague. *Cause:* Constance's `presence` rule was correctly keyed on her room — the
  source comment says so — but her greeting, her alibi row and her table `fallback` are
  flat strings that name the parlour grate and the parlour wallpaper. Teague's recant has
  him "sit down on the arm of the chair" in a hall with no chair, and since the receipt
  does not exist until 6:10, that line is false in *every* frame it can reach.
- **Mrs. Kettle's four timetable rows and Teague's alibi answer in the past tense about
  the future.** *Frame:* Kitchen, from 5:32 — fourteen minutes before the blast she
  testifies to what people did "when it went". *Cause:* the rows call
  `clock.location(of:at:)` with a hard-coded future `TimeOfDay` and interpolate it into
  past-tense prose with no guard on `clock.now`. Constance's `julian` row already carries
  exactly this guard (`when: { !blastHappened }`, with a comment explaining why); Kettle's
  and Teague's did not get one.
- **The `blast.after` fuse narrates the house's interior at a player standing on the
  lawn.** *Frame:* Back Yard, 5:48, having been indoors at 5:46. *Cause:* the fuse
  branches on `wasInTheYardForTheBlast` alone — the "where were you then" axis, which
  correctly owns "grass in your cuff" but has no business choosing "a door goes above
  you" or "Dust comes along the passage". Its sibling `blast.settling` eleven lines below
  reads `player.location`, so the pattern for the fix is already in the file.
- **The game's four most important paragraphs recite verbatim on a second showing.**
  *Frame:* Parlour 5:56/5:58 for the glove, Back Yard 5:44/5:46 for the letters, Front
  Hall 6:16/6:18 for the receipt. *Cause:* `Conversation.shows(_:to:learning:reply:)`
  takes no `again:` parameter at all, where its siblings `greeting` and `topic` both do.
  This is an engine gap, and it breaks the mechanics contract's "Nobody recites an
  important paragraph twice" row, whose one named exception is Mrs. Kettle.
- **Five stub verbs answer untruthfully in frames the game deliberately built.** *Frame:*
  Back Yard 5:48–5:52 and the Parlour at 5:32. *Cause:* Fulminate sets five `text` keys
  and no `text.stubs.*` at all. So `stand` says "You're already standing." on the one turn
  the game has said you are on your back; `listen` and `smell` report an ordinary evening
  thirty feet from a burning building the game says has taken the hair off your hand;
  `climb stairs` is disproved by `up` on the next turn; `sit` finds nothing comfortable in
  the room built out of armchairs, with Mrs. Vane sitting in one.
- **The naming stubs render people as furniture, and `touch` contradicts the game's own
  refusal one turn later.** *Frame:* Kitchen, 5:32–5:46, with Mrs. Kettle at her stove.
  *Cause:* `StubVerb.named` guards exactly one object — the player, because the line would
  otherwise read "The yourself is not food." — and has no `isActor` guard, so every naming
  stub renders a named person as an object. Separately, `cantSearchActor` refuses actor
  contact by design and Fulminate re-skinned it ("You are not putting a hand on Mrs.
  Kettle tonight"), while the `.touch` stub has no actor check and reports a completed act
  of contact on the next line. Not the K9 article bug — article handling is correct
  throughout.
- **The wreckage is unreferenceable for the six minutes the yard spends describing it.**
  *Frame:* Back Yard, 5:46–5:52. *Cause:* `clock.blast` calls `debris.reveal()` but leaves
  the item in `carriageHouse`; only the 5:52 `clock.radioCar` moves it to `backYard`. The
  settling fuse says "Something in the wreckage lets go" while `x wreckage` answers with
  the out-of-scope line K7 reserves for a noun that isn't there.
- **The suitcase is packed by three sentences and empty by mechanic.** *Frame:* Boarder's
  Room, 5:34–5:40. *Cause:* declared `container` with no contents and no
  `before(.lookIn)`, so the stock empty-container line answers a question the prose has
  already answered twice the other way. It is also takeable — `take all` lifts a boarder's
  packed case out of his rented room while he stands there being helpful, in a game that
  refuses the overcoat on exactly those grounds — and the room description goes on saying
  "a suitcase on the bed" afterwards.
- **Teague is narrated out the front door and still listed in the hall on the next turn.**
  *Frame:* Front Hall, 5:46. *Cause:* his 17:44 `Stop` carries an *arrival* string whose
  content is a departure, and the 17:46 stop that actually moves him carries no
  `departure:`. Constance's 17:54 stop is the mirror image — `departure:` only, no
  `arrival:` — so a player who deliberately waits in the parlour to watch her come back
  gets the crossing as a silent diff between two room listings.
- **The sealed can describes a bench sixty feet away and then leaves your hands in
  silence.** *Frame:* Front Hall, 5:44 and 5:46. *Cause:* a static `description(…)`
  hard-coding its starting position on an item with no take-refusal, and `clock.blast`
  calling `can.vanish()` unconditionally without checking whether the player is holding
  it.
- **`show <anything> to patrolman` prints a sentence beginning with a lowercase "the".**
  *Frame:* Back Yard, 5:54. *Cause:* `Conversation(noInterest: { "\($0) looks at it and
  looks away." })` interpolates the rendered phrase at sentence-initial position without
  `GameText.sentenceCase($0)` — the rule `CLAUDE.md` states verbatim. Five proper-named
  actors hid it; the patrolman is the one actor without `properName`.
- **The 6:50 coroner tells a player who never left the Front Hall that he looked at the
  wreckage "for rather less time than you did".** *Frame:* Front Hall and the dark cellar,
  6:50. *Cause:* it is the only one of the game's timed events with no branch on
  `player.location` or world state; the other four all read the player's room.
- **Vane's Study is a room paragraph about a desk whose examine text is the engine's
  shrug.** *Frame:* Vane's Study, 5:40–5:46. *Cause:* `desk` declares `scenery` and
  `surface` and no description, so the one detail the room made load-bearing — every
  drawer standing open, searched by somebody who meant to put it back — is denied by
  `x desk`, `x drawers` and `search desk` alike. Every neighbouring item has a
  description.
- **Constance "takes it out of your hand" and the glove stays in your inventory** —
  which is what lets you hand it to her again. *Frame:* Parlour, 6:00. *Cause:* the reply
  asserts a transfer `Conversation.shows` never performs.
- **"Arithmetic", the one word the design doc reserves, is spent twice before its
  reserved use.** *Frame:* Kitchen 5:38 (Teague) and Vane's Study 5:46 (the ledger),
  against Constance's line which is gated on `blastHappened`. *Cause:* a contract
  violation in `Sources/Fulminate/Fulminate.swift`, not a bug — the doc says "arithmetic
  belongs to Constance's shock and appears nowhere else", and the code puts it in two
  other mouths, the earlier of which a player reaches first.
- **Every ending, the winning one included, closes on "Your score is 0."** *Frame:* all
  five endings. *Cause:* Fulminate declares no `Scoring` content and does not re-skin
  `text.scoreLine`, so a period mystery reports an arcade score under the paragraph
  saying the case is closed.
- **The round's own unknown-word counter reported 2 occurrences where the transcripts
  hold 261.** *Cause:* `unknownWords` is a self-reported field on the tester schema
  (`.claude/workflows/playtest.js:314`) whose own description tells testers that a word
  the game printed "is a K8 unanswerable-noun finding" — so for the exact case the
  counter exists to measure, the schema instructs them to file it elsewhere. One tester
  reported `body` ×2; the rest filed findings instead. Line 1196 then asks the critic to
  flag the list being empty, which it did. **Harness-owned, and filed at every `fix`
  setting by rule.**

## Fixed

Nothing. `fix: "none"`, by request — the fix phase is experimental and the skill's
standing advice is to read a round's findings before letting a fixer near a
prose-coupled suite. No file under `Sources/` was touched; `git status` is clean.

## Filed, not fixed

All 57, deduplicating to 18 classes. Filed as **#122**.

| Reason | Count | What it means here |
|---|---|---|
| `out-of-mode` | 48 | `fix: "none"` reached no owner class. |
| `needs-human` | 9 | The verifier confirmed the defect and declined to let a fixer pick between designs. |
| `harness` | 0 | The workflow classified none as harness-owned; the counter defect above was found by the critic and by hand afterwards, and is filed as a Harness box regardless. |
| `unclassified` | 0 | Every `ownerFile` resolved. |

The nine `needs-human` findings cluster in six classes: the two engine stub-verb classes,
the wreckage scope window (move `debris` at 5:46, or add synonyms to
`carriageHouseOutside` — two reasonable repairs), the sealed can (refuse the take, or
branch the description), the reserved word "arithmetic" (a doc change or a code change,
and the doc is the source of truth), and the score line.

## Refuted

13 of 70 — a 19% refutation rate, distributed across all seven charters (tourist 2,
clock-watcher 1, vandal 1, interrogator 1, solver 4, idiot 3, re-reader 1). Each
refutation replayed the reproducer from a clean start in its own
`Fulminate-r1-verify-NN/probe-NNN/` directory and cited it.

| # | Charter | Claim | Refutation |
|---|---|---|---|
| R01 | tourist | The scorched glove is listed in plain sight while its description says it was pushed behind the coal bin | Neither sentence is false of the frame; the stock listing asserts only that the glove is in the cellar. Design suggestion, not a defect |
| R02 | tourist | `search coat` answers in the engine's voice where the game twice pointed at the pockets | "The overcoat is empty." is the fact the doc asks the beat to carry. The "twice" is quoted from a source comment the player never sees; only one refusal names the pockets |
| R03 | clock-watcher | Mrs. Kettle is "the only person here who has looked at the wreckage" in a yard full of people looking at it | The tester split a conjunctive relative clause. "Only" scopes the whole conjunct — three people have stopped, she has not. True, and only true there |
| R04 | vandal | Fulminate re-skins five stock keys and zero of ~48 stubs, so a large slice answers in the engine's voice | Mechanically true, but every quoted line is a short declarative with no anachronism. `63593d5` removed six overrides on purpose. (The *specific* stubs that are false of their frame were filed separately and confirmed) |
| R05 | interrogator | `notTakingOrders` interpolates the actor's name twice where English wants a pronoun | Nothing untrue of the frame; the closure has no pronoun channel by construction. Prose-taste at most |
| R06 | solver | The game says Delphine "did not go down when it went" to a player two rooms inside | True of the frame; the guard is deliberate and the fix would delete the beat from the doc's canonical route |
| R07 | solver | The 5:50 settling fuse pairs its outdoor opener with an indoor tail | Every clause is perceivable from the grass; the finding shows how the sentence was composed, not that it is untrue |
| R08 | solver | The blast paragraph names the kitchen as somewhere else while the player is in it | The finding concedes "not false, but the deixis is wrong". A plain locative is not a distancing |
| R09 | solver | The fuller ending is reachable with the receipt still in Teague's coat | Reproduced, but the SHOW reply names no hand and both scope gates hold. A preference for Inform's carried-object rule |
| R10 | idiot | Kettle's listing line says "keeping busy" while she stands at a fire | Her arrival line one turn earlier says she never stops drying her hands. The doc names the always-true static line as the cheaper fix where it works |
| R11 | idiot | Pike is "standing about with his hat on" one turn after his arrival put the hat in his hands | The line names no room, hour or event, and `x pike` next turn agrees the hat is on. The tester's own alternative fix concedes he cannot say which sentence is wrong |
| R12 | idiot | `turn on lamp` answers "You can't turn that on." about a lamp the prose says works | `parlourLamp` is never lit by any rule, timer or action anywhere in the file. There is no frame in which the refusal is false |
| R13 | re-reader | Items the room paragraph puts on furniture are announced again by the stock listing line | "here" designates the room, not the floor. And the prescribed fix does not work: `RoomDescriber` prints surface contents anyway |

**Four refutations handed over a better claim than the one they killed, and nobody filed
any of them.** They are carried into the next round's targets rather than lost:

- R11 names the *examine* text — "he has not had the hat off since he came" — as the
  sentence actually false of a player who watched the hat come off.
- R13 shows `take suitcase` leaves the room description saying "a suitcase on the bed".
  (This one *was* independently filed by the idiot charter and is confirmed in C9 below,
  so it is the one residual that did land.)
- R08 and R04 hand over live K8 and scope-refusal symptoms with reproducers.

**A caution on the refuted list.** Nine of the thirteen turn at some point on
`docs/games/fulminate.md:73` — "Free to change: every name, all prose, room descriptions,
topic keywords, the tone…". That clause is a licence to *rewrite* prose, and it is being
read as a licence for prose to be *wrong*. It refutes taste objections correctly (R04,
R05, R10) and is doing more work than it should in R06 and R07. Worth a sentence in the
doc distinguishing the two.

## Coverage

The load-bearing section, recounted from the transcripts under `.context/playtest/` by
the critic, not from testers' self-reports. Where they disagree the transcript wins:
three charters under-reported their own turn counts (clock-watcher 221 against 255, idiot
205 against 231, interrogator 168 against 180), so **no number in the survey header was
reconciled against a transcript** and the survey's "1,766 turns" is 78 short of the 1,844
the play labels actually hold.

| Group | Probes | Engine turns |
|---|---|---|
| `Fulminate-survey` | 4 | 45 |
| `Fulminate-r1-play-*` (7 charters) | 124 | 1,844 |
| `Fulminate-r1-verify-*` (70 labels) | 142 | 1,659 |
| `Fulminate-critic` | 3 | 68 |
| **Total** | **273** | **3,616** |

Per charter: tourist 31 probes, idiot 21, re-reader 19, clock-watcher 15, solver 15,
interrogator 14, vandal 9.

**Charters** — all seven ran, all seven filed, all seven had findings confirmed. Nobody
came back empty, so there is no "run, found nothing" row and no "not run — budget" row.
The real gap is per *class*, not per charter, and three charters discharged only part of
what they own:

- **tourist** owns K8 and stopped at 5:58; half the evening's prose was never read by the
  charter whose class it is.
- **vandal** owns stock refusals and never entered the Cellar, Vane's Study or the
  Boarder's Room — a third of the map, including the darkest refusal surface in the game.
- **clock-watcher** owns the timed cross-product and never stood in Vane's Study at any
  hour, which is where three of the five timetables end.

Two subsystems have exactly one witness each: **every ending is solver-only**, and the
study and Constance's confession rows are re-reader-only. If the solver misread an ending,
nothing in this round would have caught it.

**Rooms** — 9 of 9 entered, never-visited: none. Off-map by design: Orange Grove Avenue.
But the distribution is very uneven: Front Hall 269 probes, Kitchen 173, Back Yard 112,
Parlour 46, Upstairs Landing 43, Boarder's Room 31, Carriage House 25, Vane's Study 20,
Cellar 18. **Three rooms were entered by under 8% of probes**, and the Landing's 43 are
almost all walk-throughs.

**Hour × room — 103 of 162 cells (64%).** `—` = sealed by the patrolman from 5:52,
unreachable by construction, not a gap. `*` = filled by the critic's pass only, not by
the round.

| Time | Hall | Parl | Kitc | Cell | Yard | Carr | Land | Stud | Brdr |
|---|---|---|---|---|---|---|---|---|---|
| 5:30 | ✓ | | | | | | | | |
| 5:36 | ✓ | ✓ | ✓ | | ✓ | | | | ✓ |
| 5:38 | ✓ | ✓ | ✓ | | ✓ | ✓ | | | ✓ |
| 5:42 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | | ✓ |
| 5:44 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | | ✓ | ✓ |
| 5:46 blast | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓* | ✓ | ✓ |
| 5:48 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 5:50 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 5:52 radio car | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 5:54 | ✓ | ✓ | ✓ | ✓ | ✓ | — | | ✓ | |
| 6:00 | ✓ | ✓ | ✓ | | ✓ | — | | ✓ | |
| 6:02 | ✓ | ✓ | ✓ | | ✓ | — | | ✓ | |
| 6:10 | ✓ | ✓ | ✓ | | ✓ | — | | ✓ | |
| 6:14 | ✓ | ✓ | ✓ | | ✓ | — | | ✓* | |
| 6:20 phone | ✓ | ✓ | ✓ | ✓ | | — | | ✓ | ✓ |
| 6:26 | ✓ | | ✓ | ✓ | | — | | | ✓ |
| 6:30 | ✓ | | ✓ | | | — | | | |
| 6:50 coroner | ✓ | | ✓ | | | — | | | |

The 5:30 row is structurally Hall-only. Every other blank is a real hole, and they have a
shape: **the Upstairs Landing is blank at 11 of 18 rows**, and the whole **6:26–6:50
stretch was read in three rooms of nine**. Only 9 probes of 273 ran past 6:40 and only 7
reached the deadline — **97% of this round stops before the last five minutes of the
game.**

**Event × room** — counts, not ticks, so a 1 reads as the thin cell it is:

| Event | Hall | Parl | Kitc | Cell | Yard | Carr | Land | Stud | Brdr |
|---|---|---|---|---|---|---|---|---|---|
| blast 5:46 | 37 | 20 | 38 | 5 | 82 | 3 (death) | 1* | 14 | 2 |
| blast.after 5:48 | 35 | 19 | 26 | 3 | 82 | 7 | 1 | 14 | 2 |
| blast.settling 5:50 | 29 | 18 | 18 | 3 | 79 | 8 | 2 | 12 | 2 |
| radio car 5:52 | 25 | 12 | 9 | 3 | 61 | 9 | 1 | 9 | 2 |
| telephone 6:20 | 20 | 2 | 4 | 1 | **0** | **0** | **0** | 1 | 1 |
| coroner 6:50 | 4 | **0** | 2 | **0** | **0** | **0** | **0** | **0** | **0** |

The blast trilogy and the radio car are saturated. The two late alarms are not: the
telephone was heard in 6 rooms of 9, the coroner in **2 of 9**.

**Actor stops — 22 declared arrival/departure lines, 20 witnessed.** **Dr. Pike's 6:14
study arrival was never printed once in the entire round**; Delphine's 6:02 study arrival
was seen by exactly one tester; her 6:26 cellar departure never printed at all, because
nobody stood in the study at 6:26.

**Conversation — 211 ASK/TELL/SHOW commands, and one whole branch never fired.**
`SHOW LEDGER TO PIKE` fired in no transcript, so `notebooksSold` was never learned and
three gated replies are unread prose. Constance's `teague` row under
`knowing: .teagueLied` — the keystone sentence behind the fuller ending — never printed.
Nor did her `evening` row under `knowing: .constanceBroke`, nor her `lab`/`shed` row.
Teague's and Mrs. Kettle's table fallbacks were never reached.

**Endings — all four reached, plus death, all by one charter.** Win/fuller ×5,
win/partial ×3, loss/wrong-name ×1, loss/6:50 ×6, death ×3. `ACCUSE` before the blast
(the "Not yet" refusal) printed 0 times in the round and once in the critic's pass.

**Untouched by anybody's charter:** UNDO/RESTART/SAVE/RESTORE around the endings (5 such
commands in 273 probes; UNDO and RESTART zero), and the empty-input case, which the
replay harness makes untestable by stripping blank lines — a harness gap, not a tester's
skip.

**Dropped** — 0 findings dropped for budget, 0 as non-reproducible. Every one of the 70
was replayed by a verifier from a clean start, and all 57 confirmed carry
`replayedCleanly: true`. The four residual claims surfaced inside refutation prose (see
above) were never filed as findings and are **not** counted as covered; they go to the
next round.

## Hygiene

- `swift test` — **987 tests, 0 failures.** My first run reported 1 issue while a
  `bin/playtest-replay` build was concurrently writing the same `.build`; four
  consecutive clean runs afterwards all pass 987/987, and the failure did not recur.
- Strict lint — **clean**, exit 0. Note that `.swift-format` is gitignored and is
  materialized by `.build/checkouts/Persnicket/bin/ci-lint-setup`, exactly as
  `.github/workflows/lint.yml` does it; `CLAUDE.md`'s lint command assumes the file is
  already present.
- Diff stat: **none.** No source file, test file or assertion was touched — `fix: "none"`
  and `git status` clean. The gate agent did not run: `playtest.js:1224` fires it only
  when a fixer reports touched files, so at `fix: "none"` the suite and lint above were
  run by hand instead.
- Marquee finding spot-checked by hand rather than trusted from the agents' transcripts:
  a 16-command probe at seed 0 (`south, west, z×7, time, look, x fire, x flames,
  x wreckage, x crockery, x hat`) reproduces four confirmed findings at once —
  `x fire` → "You can't see any such thing" three lines under "watching it burn" /
  "looking at the fire" / "still burning quietly"; `x wreckage` likewise on the turn the
  fuse says "Something in the wreckage lets go"; `x hat` likewise while Pike "is standing
  about with his hat on"; `x crockery` → unknown word. Transcript:
  `.context/playtest/handcheck/probe-001/transcript.txt`.
- The 261-occurrence / 59-word unknown-word tally was recounted by hand from the
  transcripts (`grep -rhoE 'I don.t know the word "[a-z]+"' Fulminate-*/*/transcript.txt`),
  confirming the critic against the workflow's own reported `[{body, 2}]`.

## Appendix — dedupe keys

Every key this round produced, so the ledger can abbreviate. Owner file is the prefix
before `::`; the normalized offending text follows it. Frame is deliberately excluded —
one untrue sentence seen at two hours is one defect.

### Confirmed (57)

| # | Verdict | Owner | Key |
|---|---|---|---|
| 01 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `mrs vane is on the step and no further watching it burn delphine marsh is on her feet with her arms at her sid…` |
| 02 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `slates come out of the sky and go into the grass edgefirst  there is grass in your cuff and grit on your teeth…` |
| 03 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `dr pike is standing about with his hat on   x hat you cant see any such thing` |
| 04 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `black and white tile worn through to the grout along the line people walk a hat stand with one coat on it a ha…` |
| 05 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `x tile black and white laid in a diamond and worn through to the grout  x diamond i dont know the word diamond…` |
| 06 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `scrubbed pine and a stove that has been going since before you got here  x pine you cant see any such thing   …` |
| 07 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `somebodys workshop and somebody elses chapel a long scarred bench down one side under a rack of tools a cot do…` |
| 08 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `x coal bin a plank bin with three winters of coal dust in it and no coal the dust on the floor behind it has b…` |
| 09 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `dry grass and a low brick wall that used to be taller the carriage house stands at the north end with its lamp…` |
| 10 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `north the patrolman puts an arm across the gap without any particular force in it nobody past me till the coun…` |
| 11 | needs-human | `Sources/Fulminate/Fulminate.swift` | `something in the wreckage lets go and settles and the note in your ears steps down one it will be there tomorr…` |
| 12 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `a typewriter with a sheet still in it and a suitcase on the bed packed for a longer trip than anybody has ment…` |
| 13 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `a desk with a green shade over the lamp and every drawer standing open not ransacked searched by somebody who …` |
| 14 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `x letters a dozen letters in three different hands tied with grocers string somebody has read them recently th…` |
| 15 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `x lamp a standard lamp with a fringed shade and a bulb that has been in it a while  x bulb i dont know the wor…` |
| 16 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `a radio car pulls up out front and a patrolman comes through the house and out to the wreckage   x patrolman h…` |
| 17 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `t10 548  player walks out to the yard blastafter fires here  west back yard dry grass and a garden wall that i…` |
| 18 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `t8 544  says he is going for cigarettes and goes  z time passes teague crosses the hall says he is going for c…` |
| 19 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `somewhere out behind the house something goes off with a flat unimpressive thump and every window and pane and…` |
| 20 | needs-human | `Sources/Fulminate/Fulminate.swift` | `t41 650 the deadline  z time passes the county man comes up the path at ten to seven and he is not in a hurry …` |
| 21 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `time your watch says 552 pm a car door goes out front a patrolman works through the house taking names yours i…` |
| 22 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `greet constance yes says mrs vane to no question and goes on looking at the grate something in the wreckage le…` |
| 23 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `ask constance about parlour i have been in the parlour all evening she says it to the cold grate in the voice …` |
| 24 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `ask constance about rockets mrs vane looks past you at the wallpaper a radio car pulls up out front and a patr…` |
| 25 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `there is no moment in which it is about to happen the carriage house comes apart  and then the ground hits you…` |
| 26 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `listen you hear nothing out of the ordinary something in the wreckage lets go and settles and the note in your…` |
| 27 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `smell you smell nothing out of the ordinary a radio car pulls up out front and a patrolman comes through the h…` |
| 28 | needs-human | `Sources/Gnusto/Actions/StubVerbs.swift` | `eat mrs kettle mrs kettle is not food  pull mrs kettle mrs kettle doesnt budge  break mrs kettle mrs kettle is…` |
| 29 | needs-human | `Sources/Gnusto/Actions/StubVerbs.swift` | `search mrs kettle you are not putting a hand on mrs kettle tonight  touch mrs kettle you feel nothing out of t…` |
| 30 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `black and white tile worn through to the grout  the front door is east the parlour west the kitchen passage so…` |
| 31 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `furniture too big for the room and too good to sell arranged around a cold grate  mrs vane is in her chair wit…` |
| 32 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `ask kettle about delphine miss marsh was in the back yard when it went ill say that for her and she can do wit…` |
| 33 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `mrs vane comes out as far as the step and stops there she does not call his name she looks at the fire the way…` |
| 34 | confirmed-defect | `Sources/GnustoConversation/Conversation.swift` | `show letters to delphine she unties the string and reads the top one through all the way before she hands it b…` |
| 35 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `show watch to patrolman the patrolman looks at it and looks away  time your watch says 556 pm` |
| 36 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `howard teague is here being helpful  ask teague about drugstore drugstore on colorado left here about half pas…` |
| 37 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `west back yard dry grass and a garden wall that is now shorter at the north end than the south what is left of…` |
| 38 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `the county man comes up the path at ten to seven and he is not in a hurry because nobody has given him a reaso…` |
| 39 | needs-human | `Sources/Fulminate/Fulminate.swift` | `accuse mrs vane the county man writes down her name and closes the book he does not ask why and you do not hav…` |
| 40 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `dry grass and a garden wall that is now shorter at the north end than the south what is left of the carriage h…` |
| 41 | needs-human | `Sources/Fulminate/Fulminate.swift` | `what is left of the carriage house is standing in pieces and some of it is still burning quietly because nobod…` |
| 42 | needs-human | `Sources/Fulminate/Fulminate.swift` | `north front hall there is an overcoat here  x can a paperwrapped can about the size of a coffee tin sealed and…` |
| 43 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `take all suitcase taken   i you are carrying a suitcase a wristwatch being worn  look boarders room a typewrit…` |
| 44 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `boarders room a typewriter with a sheet still in it and a suitcase on the bed packed for a longer trip than an…` |
| 45 | needs-human | `Sources/Fulminate/Fulminate.swift` | `time your watch says 546 pm somewhere out behind the house something goes off with a flat unimpressive thump  …` |
| 46 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `mrs vane is in her chair with the lamp unlit dr pike is standing about with his hat on  time your watch says 5…` |
| 47 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `ask constance about julian she takes a moment to find you as though the question had come from another room my…` |
| 48 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `somewhere out behind the house something goes off  in the kitchen a shelf of crockery goes over all of it one …` |
| 49 | confirmed-defect | `Sources/GnustoConversation/Conversation.swift` | `show glove to constance she takes it out of your hand which you were not expecting and turns it over once i ha…` |
| 50 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `ask kettle about constance mrs vane was in the parlour when it went and stood out in the back yard after with …` |
| 51 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `show receipt to teague he looks at it for a while sixohfive he says yeah he sits down on the arm of the chair …` |
| 52 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `x suitcase brown scuffed at the corners and packed the strap is buckled it has been packed a while  search sui…` |
| 53 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `ask patrolman about wreckage not till the county mans been he shifts his feet theres a body in there ive seen …` |
| 54 | needs-human | `Sources/Fulminate/Fulminate.swift` | `ask teague about drugstore mrs kettle keeps a good kitchen and a better clock he recrosses his legs a man can …` |
| 55 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `show glove to constance she takes it out of your hand which you were not expecting and turns it over once i ha…` |
| 56 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `west vanes study a desk with a green shade over the lamp and every drawer standing open not ransacked searched…` |
| 57 | confirmed-defect | `Sources/Fulminate/Fulminate.swift` | `dr pike is standing about with his hat on   x hat you cant see any such thing  x pikes hat you cant see any su…` |

### Refuted (13)

| # | Charter | Kind | Key |
|---|---|---|---|
| R01 | tourist | stock-behavior-by-design | `cellar cold and low enough that you walk it at a stoop it smells like a cellar there is a scorched glove here …` |
| R02 | tourist | stock-behavior-by-design | `search coat the overcoat is empty  open coat you cant open that` |
| R03 | clock-watcher | misquoted-prose | `mrs kettle comes out drying her hands and does not stop drying them oh the boy she says once and then does not…` |
| R04 | vandal | licensed-by-doc | `sing your singing is better kept to yourself  pray your prayers go unanswered  xyzzy nothing happens  wish wis…` |
| R05 | interrogator | licensed-by-doc | `pike go north dr pike hears you out and goes on doing exactly what dr pike was doing  time your watch says 532…` |
| R06 | solver | characterization | `delphine marsh did not go down when it went she did not even put a hand out` |
| R07 | solver | licensed-by-doc | `time your watch says 550 pm something in the wreckage lets go and settles and the house hears it and holds sti…` |
| R08 | solver | licensed-by-doc | `time your watch says 546 pm somewhere out behind the house something goes off with a flat unimpressive thump a…` |
| R09 | solver | stock-behavior-by-design | `show receipt to teague he looks at it for a while sixohfive he says yeah he sits down on the arm of the chair …` |
| R10 | idiot | licensed-by-doc | `look back yard dry grass and a garden wall that is now shorter at the north end than the south what is left of…` |
| R11 | idiot | licensed-by-doc | `dr pike arrives in the yard holding his hat against his chest he gets within thirty feet of the heat and no fu…` |
| R12 | idiot | stock-behavior-by-design | `x lamp a standard lamp with a fringed shade and a bulb that has been in it a while mrs vane does not light it …` |
| R13 | re-reader | stock-behavior-by-design | `look boarders room a typewriter with a sheet still in it and a suitcase on the bed packed for a longer trip th…` |
