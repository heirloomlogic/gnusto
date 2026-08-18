# Fulminate — playtest round, 2026-08-17

Commit `1df88f3` · seed `0` · `fix: "none"` · charters: explorer ×2, timekeeper,
interrogator, solver, wrong-footer (6 of 6 applicable, none skipped)
Oracle tiers: T0 kernel, T1 design doc (`docs/games/fulminate.md`, contract + timeline +
solution), T2 `FulminateTests`, T3 source, T4 git history.
Budget: 360 turns planned (60 × 6). **1,505 engine turns spent over 81 probes.**
14 agents, 0 errors, 1.5M subagent tokens, 52 minutes wall clock.

15 findings raised → **15 confirmed** (10 `confirmed-defect`, 5 `needs-human`), 12
refuted, 0 routed, 0 fixed. Verifier agreement **88.9%** (24 of 27 double-rated, 0
single-rated). Completeness critic: **`round-is-thin`**. Deduplicating the 15 by root
cause gives 13 classes; the critic adds 3 more that no tester raised, for **16**, filed
as one issue.

## What this round's header has to declare

**The declared bar failed.** Before the round was dispatched, the pass condition was
written down and fixed: *no `PlaytestSignals` rule trips in any session*. Three of seven
sessions tripped, and the metrics say the failure is wider than the gates show — see
**The harness result** below. This is reported as a result, not tuned away.

**Two harness defects were fixed in `d77f5fe` before dispatch**, and both would have
produced a completed round reporting wrong numbers: sessions now write where the collator
looks, and the ledger stopped leaking the map into blind prompts. Both held — all 7
sessions wrote a `closing.json`, `sessionsUnfinished` is empty, and the dry run's firewall
assertions passed.

**Six ledger keys were deliberately withheld.** The 2026-07-31 round refuted thirteen
claims; seven were passed in as `ledgerKeys` and six were not. The six withheld
(R04, R05, R07, R08, R10, R11) are exactly those refuted as `licensed-by-doc`, and
`docs/games/fulminate.md:77-83` has since narrowed that clause in as many words: *"Free to
change is not the same as free to be wrong… Nine of the 2026-07-31 round's thirteen
refutations leaned on this clause and two leaned on it too hard."* Pasting them would have
suppressed findings the doc now says are filable. Four of this round's twelve refutations
still came back `licensed-by-doc`, so the clause is still load-bearing and still worth
watching.

**The 2026-07-29 round's 15 refuted keys were never written down anywhere and are
unrecoverable.** That round was a calibration exercise against historical trees; its
ledger section deliberately records no refuted rows. Nothing can pass them forward.

**The recorded ledger keys cannot mechanically dedupe anything, and this round's cannot
either until the format changes.** Dedup (`playtest.js:1055-1069`) keys on
`decl::<file>::<declaration>` whenever the clusterer locates the declaration and only
falls back to `<ownerFile>::<normalize(excerpt)>` when it returns `unlocated`; matching is
exact set membership. The ledger's keys are display-truncated with `…`, which
`normalize()` never emits, so they match nothing. Their only live effect is the prompt
paste, and that reaches **sighted charters only** — `playtest.js:968` guards on
`!charter.blind`. This round's ledger append therefore records the workflow's own returned
`key` verbatim, `decl::` prefix included, which is the shape dedup actually compares.

**The batching risk.** Findings are verified in batches of 25 by two independent raters,
which is the same shape as checklist-burning: a rater can skim a list and agree. The two
mitigations are the per-item `attemptedRefutation`, required on every verdict whether it
confirms or refutes, and the published agreement rate. Both are reported here. The critic
adds a caution the brief did not anticipate — see **Is the verifier actually verifying?**
below — that of 26 rater pairs, **10 ran byte-identical command lists**, so on that subset
rater 2 contributed no independent probing and the agreement figure is worth less than it
looks.

**The charter roster changed since 2026-07-31 and per-charter coverage does not compare.**
That round ran tourist, clock-watcher, vandal, interrogator, solver, idiot and re-reader.
Those charters no longer exist except interrogator and solver; the roster is now explorer
(blind, one copy per focus region), timekeeper, interrogator, solver and wrong-footer.

## The round

The dominant class is the one this harness exists to catch and a transcript test
structurally cannot: **a sentence that is true of the story but false of the frame it
printed in.** Eleven of the fifteen findings are that, and the mechanism is almost always
the same — a `description`, a topic row or a `TimedEvent` body written as one flat string
for a game whose timetable moves both the speaker and the player.

**Seven of the fifteen were introduced by `7c92508`, the commit that fixed the previous
round's eighteen classes**, and the 2026-07-31 report's closing claim — *"no fix in this
repo's history reintroduced a class it was fixing"* — is no longer true. Two of the seven
are verifiable in the diff as the repair writing the defect:

- `7c92508` **added** `text.stubs.climb` and `text.stubs.stand` verbatim as they stand
  today. Class C6 of the last round was the un-re-skinned stubs; the re-skin is the fix,
  and two of the sentences it wrote assert a frame — *"in this house"*, *"since the
  streetcar"* — that the game contradicts outdoors and after the blast respectively.
- `7c92508` **removed** *"window and pane and loose sash in the place shivers at once"*
  from the blast paragraph — that is class C1, the unanswerable nouns — and in the same
  commit **added** *"works to the bench and not to the window"* to the lab lamp. It
  deleted an unanswerable noun in one declaration and wrote a fresh one in another. C1
  reintroduced by its own repair.

Four more (Teague's death clause, the Cellar deixis pair, Constance's chair arms, Teague's
`window`) trace to `ed8d377` from 2026-07-29 and so **predate the last round and were
missed by it**. Three carry no blame commit.

That distribution is the argument for the rule this harness already adopted: **a round
finds and files; it does not fix.** `7c92508` repaired eighteen classes in one commit, and
this round is the bill. Nothing here edits the tree.

**The fifteenth finding is a two-day-old engine regression, and it is the headline** —
because it is a defect in the instrument the testers are told to read the frame off.

- **The `[status]` footer's `time=` is one 2-minute tick ahead of every hour the game
  itself prints.** *Frame:* every cost turn, all evening — on turn 1 the wristwatch reads
  5:30 pm under a footer stamped `time=5:32 pm`; the blast paragraph prints in a turn whose
  watch reads 5:46 and whose footer reads `time=5:48 pm`. *Cause:* `Clock.now = start + player.moves
  * minutesPerTurn` (`Sources/GnustoClock/Clock.swift:106-113`) is sampled by the whole
  turn — the `.time` action, `describe` blocks, and the alarms and scheduled actor moves in
  the timer phase — *before* the move counter advances, while `GameWorld.statusFields()` is
  read *after* `finishTurn`. Introduced 2026-08-15 by `7cec4aa`, whose subject line is *"A
  turn can say where and when it printed"* — the exact property it is one tick wrong about,
  and the same commit shipped `aClockGameShowsTheHour`
  (`Tests/GnustoTests/StatusFooterTests.swift:188-196`), which pins the off-by-one in
  place. **The offset is not constant**: a free turn does not advance the counter, so
  `frotz` prints the narrated hour correctly while every cost turn is two minutes ahead. A
  tester cannot correct for it by habit, only by reading `turn=` first. It contradicts the
  design doc's own turn-to-time table (*"Turn n reads 17:30 + 2(n-1), so the blast ends
  turn 9"*) directly, and `references/finding-contract.md` tells every tester to *"Take the
  room and the hour from the `[status]` line the turn printed."* Three of the six charters
  discovered and worked around it independently this round, and two of them **dropped
  otherwise-sound findings** because of it. `needs-human`: the fix is a real fork — snapshot
  `statusFields` before the counter advances (an engine change at `GameWorld`/`REPL`
  affecting every bundle's contributed fields, not the one-line `Clock` change), subtract
  `minutesPerTurn` inside `Clock.statusFields` (wrong while the clock is paused or on a free
  turn), or leave the code and correct the two harness documents. Somebody has to decide
  which artifact is wrong before an agent picks by coin flip.
  **Decided 2026-08-18: the first.** The contributed fields are sampled at the turn's
  close, before the counter advances. The ledger's Amendments section carries the
  reasoning and what the other two forks would have cost; this entry stands as the round
  wrote it.

- **`X TEAGUE` says the house is one "where a man has just died" six minutes before the
  explosion, while Dr. Pike is alive in the Parlour.** *Frame:* Kitchen, 5:40 pm, before
  the 5:46 blast; the same string still prints at 5:48 and at 6:22. *Cause:* a bare
  unbranched `description(…)` at `Fulminate.swift:800-805`. The file goes to deliberate
  trouble elsewhere to keep the death unsaid — Constance's `julian` row is gated on
  `!blastHappened` so she says "Julian is in the shed" until 5:46 — and `7c92508` keyed
  Constance's and Mrs. Kettle's descriptions on the blast. Teague's is the one that was
  missed. It also front-runs the game's own reveal: the 6:20 telephone is written to be the
  first hint that Pike is gone.

- **The 5:46 blast tells a player standing in the Cellar that breakage is happening
  "below you".** *Frame:* Cellar, 5:48 pm — the lowest room in the house. *Cause:* the
  `clock.blast` event body branches indoors/outdoors but not on floor, so its deixis is
  written from the ground floor. The 5:50 `blast.after` body has the same shape and puts a
  door below the same player. The critic demonstrated the defect pointing the other way:
  one 26-turn wait probe put *"Below you a long run of breakage starts and finishes"* on
  the page while the player stood on the **second floor**.

- **Taking the boarder's suitcase is refused because its owner is "somewhere in this
  house", four minutes after the game showed him leaving by the front door.** *Frame:*
  Boarder's Room, 5:54 pm. *Cause:* `suitcase.before(.take)` is a flat refusal string with
  no read of Teague's timetable position; he is off-map 5:44–6:10.

- **Mrs. Kettle's keystone testimony attaches the back-stairs crossing to the wrong
  minute.** *Frame:* Kitchen, 5:44 pm on the watch. *Cause:* her `teague` topic row names
  5:42 — the minute the timetable has him coming back in from the yard door — but he came
  down the back stairs at 5:36, and a player standing in the kitchen watches both crossings
  print their own arrival lines. The row is hand-written prose where the contract says past
  tense is read from the timetable. `needs-human`: which of the two the confession is
  supposed to hang on is a story decision.

- **Constance puts her hands back on the arms of her chair while standing on the back
  step.** *Frame:* Back Yard, 5:50 pm on the watch. *Cause:* her post-blast `julian` topic
  row ends with a flat gesture clause naming the parlour furniture. Same family as open
  class C2 from 2026-07-31, and a different declaration from the four already filed there.

- **The noun `window` is printed by two declarations and known nowhere.** *Frames:*
  Teague's `teagueLied` confession ends *"He looks at the window."* in the Front Hall at
  6:18, a room with no window; the lab lamp's pre-blast examine text prints it too.
  *Cause:* neither room declares a `window` scenery item and the word is absent from the
  vocabulary, so the game prints a noun it then denies. The confession is the keystone
  sentence of the fuller ending.

- **The scorched glove still says it "has been pushed behind the coal bin" while the player
  is carrying it.** *Frame:* Cellar, 5:44 pm, one turn after `TAKE GLOVE` and with `I`
  confirming it in inventory. *Cause:* the placement clause — the clue that somebody hid it
  deliberately — is the last sentence of a static `description` and encodes where the object
  was found rather than what it is. Invisible to anyone who examines it only before taking
  it. `needs-human`, and the round's one rater disagreement: one refuted it as ordinary
  static description, one confirmed it.

- **The Boarder's Room prints "the light" as a pointed detail and no light exists there.**
  *Frame:* Boarder's Room, 6:32 pm, in the Teague event. *Cause:* the room declares no lamp
  object, so the parser either denies the noun or silently binds the player's own
  flashlight. `needs-human`.

- **The Back Yard prints nothing when Teague crosses it twice**, although the rooms on
  either side narrate him going out through the yard door and arriving at the carriage
  house door. *Frame:* Back Yard, 5:36–5:44. *Cause:* the timetable's crossing lines are
  declared on the endpoint rooms, not the room between them. `needs-human`: a silent
  middle leg may be intended.

- **The re-skinned STAND stub says the player has been on their feet "since the
  streetcar", two turns after the game knocked them into the grass and stood them back
  up.** *Frame:* Back Yard, 5:52 pm on the footer. *Cause:* `text.stubs.stand` is one
  string with no read of the `knockedFlat` state the game itself set.

- **The re-skinned CLIMB stub says "in this house" and "go up by going up" while the player
  is outdoors trying to climb a brick garden wall**, from which `up` is not an exit at all.
  *Frame:* Back Yard, 5:36 pm. *Cause:* `text.stubs.climb` assumes an interior frame.

- **TOUCH answers "You feel nothing out of the ordinary." about a lit cast-iron stove and
  about the open fire in the wreckage.** *Frame:* Kitchen, 5:34 pm, and the Back Yard after
  the blast. *Cause:* `GameText.Stubs.touch` is the engine's stock line and Fulminate does
  not re-skin it; per the CLAUDE.md rule the cheap correct fix is assigning the line, not
  adding an `action` row.

## Filed

Sixteen classes, filed as one issue: **#280**.

| Class | Severity | Owner | Site |
|---|---|---|---|
| `[status]` footer time one tick ahead of every printed hour (**regression**, `7cec4aa`) | major | `engine` | `Sources/GnustoClock/Clock.swift` + `GameWorld.statusFields()` |
| Teague's description asserts a death before the blast | major | `game` | `Fulminate.swift` `teague.description` |
| Blast/aftermath deixis unbranched by floor ("below you" in the Cellar) | major | `game` | `Fulminate.swift` `clock.blast`, `blast.after` |
| Suitcase refusal names its owner in the house after he left | major | `game` | `Fulminate.swift` `suitcase.before(.take)` |
| Mrs. Kettle's keystone testimony names the wrong minute | major | `game` | `Fulminate.swift` `kettle.topics/teague` |
| Constance's chair-arms gesture on the back step | major | `game` | `Fulminate.swift` `constance.topics/julian` |
| `window` printed by two declarations, known nowhere | major | `game` | `Fulminate.swift` `teague.topics/constance`, `labLamp.describe` |
| Glove keeps its placement clause once carried | major | `game` | `Fulminate.swift` `glove` |
| Boarder's Room prints "the light" with no light object | major | `game` | `Fulminate.swift` `teagueDay` |
| STAND stub contradicts `knockedFlat` | major | `game` | `Fulminate.swift` `text.stubs.stand` |
| CLIMB stub assumes an interior frame | major | `game` | `Fulminate.swift` `text.stubs.climb` |
| TOUCH not re-skinned over fire | major | `game` | `Fulminate.swift` `text.stubs.touch` (line, not a row) |
| Back Yard silent on Teague's two crossings | minor | `game` | `Fulminate.swift` |
| MCP `replay` writes no probe directory | major | `harness` | `Sources/Gnusto/Playtest/PlaytestTools.swift` |
| `closing.json.roomsVisited` drops rooms worked in a rewound branch | major | `harness` | `Sources/Gnusto/Playtest/PlaytestSession.swift` |
| `coverage.turnsSpent` is asked, not counted | minor | `harness` | `.claude/workflows/playtest.js` |

**Provenance across the fifteen findings:** `7c92508` (2026-08-01, the previous round's
fix commit) ×7 · `ed8d377` (2026-07-29, predates the previous round and was missed by it)
×4 · `7cec4aa` (2026-08-15, engine) ×1 · no blame commit recorded ×3.

`ownerClass` says who owns the site, not what happens next; a round files everything and
fixes nothing. The three `harness` boxes were raised by the completeness critic and
confirmed here by hand, not by a tester — the same provenance as 2026-07-31's C18. **A
`Harness` box is always filed and never fixed by the round.**

One classification correction worth recording: the TOUCH finding's `ownerFile` came back
`Sources/Gnusto/Actions/GameText.swift`, which the workflow's `ownerClass()` rule mapped to
`game`. The site that should change is Fulminate's `text.stubs.touch` assignment, so the
class is right and the file was not; it is listed above at the site that should change.

## Refuted

Twelve claims went in and did not survive: `stock-behavior-by-design` ×5,
`licensed-by-doc` ×4, `characterization` ×2, `none` ×1.

| # | Charter | Claim | Refutation |
|---|---|---|---|
| 1 | explorer-1 | "A night like this" at 5:52 contradicts the lamp's "not properly dark" | Both replay verbatim, but they are not about the same thing: one is an idiom for the evening, the other a claim about a bulb. The register is used consistently elsewhere. |
| 2 | explorer-1 | The overcoat nudges at pockets but searching it always answers empty | The tester never played past 6:10. After "The front door goes. Teague is back", the same command returns the 6:05 receipt. The doc designs the empty pocket deliberately: "a slip stamped 6:05 cannot be in a pocket at half past five." |
| 3 | explorer-1 | The letter the opening hangs the story on is not a word the parser knows | `X LETTER` in Vane's Study answers with the lodge bundle; the Hall answer is the engine's correct out-of-scope reply. The doc's answerability rule covers room descriptions, examine text and timed events — the blurb is none of the three. |
| 4 | explorer-1 | The kitchen drawer reads identically shut, open, and open-with-flashlight | The description asserts nothing about state, and the invariance is the engine's: `DefaultActions.examine` prints the description and nothing else for every container in every Gnusto game. |
| 5 | explorer-2 | The study lamp's off-switch is made load-bearing, then `TURN ON LAMP` is stock-refused | "It is switched off" is true and is the forensic point. The refusal is `text.cantTurnOnThat` for a non-device; the lamp is `scenery`. Settled precedent: the parlour lamp was refuted the same way on 2026-07-31. |
| 6 | explorer-2 | Teague is listed "being helpful" one turn after sitting alone in the dark | A standing epithet naming no place, object or event; the doc mints it as one and licenses the construction. |
| 7 | explorer-2 | The closing move count is always 41, in engine vocabulary | The load-bearing claim is false. `text.scoreLine` prints the live counter — replays produced 41, 22, and 3–33; the tester's own sibling finding quotes 28. |
| 8 | timekeeper | Mrs. Kettle is "keeping busy" while standing in the yard doing nothing | The game stages her doing exactly that one turn earlier in the same transcript: "comes out drying her hands and does not stop drying them." |
| 9 | timekeeper | The STAND refusal says you stay down; the next paragraph says you get up | Two beats of one turn. The `world.before(.stand)` reply resolves the instant; `fuse("blast.after")` fires at end of turn. Filed by the tester itself at severity `note`. |
| 10 | interrogator | The 6:20 telephone names a fact about a suspect that no topic row answers | "I don't see how that concerns me" is Pike's specified fallback, verbatim in the doc, and required by the mechanics contract. A character declining is characterization. |
| 11 | solver | The wrong-accusation ending opens on a bare "He" and narrates the coroner early | All four endings compress to the county man's act and all four can fire before 6:50. The doc's Endings section specifies this branch with the same pronoun, verbatim. |
| 12 | wrong-footer | Ten stub verbs sit in adventure-game register inside a 1952 noir | All ten print where claimed, but none makes a false claim about the frame — the doc's actual boundary. Two supporting facts are also wrong (`.attack`/`.kiss` are not re-skinned; the reproducer lands at 5:32 with Julian alive), and it bundles ten declarations into one report. |

### Is the verifier actually verifying?

The refuted list is not empty and it is not soft. Refutations 2, 7 and 12 each go and
*fetch* something — the post-6:10 receipt, three live `scoreLine` values, a grep proving
`.attack` and `.kiss` are not in the tree — rather than reasoning from the finding's own
text. Refutation 12 attacks the reproducer's frame and finds it lands fourteen minutes
before the moment the finding describes. Refutations 4 and 5 cite engine line numbers. Two
of the twelve (1, 6) are argument rather than evidence, but they are still specific
arguments about a specific line.

**Two cautions, both against reading the agreement rate too generously.**

The critic was not handed the confirmed findings' `attemptedRefutation` text and it is not
on disk, so the audit the brief asks for — sample two or three and say whether they read as
separately reasoned — **was not performed. Do not read this section as having audited the
confirmed side.** What the critic could audit instead was the probe directories the two
raters wrote: of 26 pairs, **16 ran materially different command lists and 10 ran
byte-identical ones.** The identical ten are consistent with both raters simply replaying
the supplied reproducer, which is defensible, but on that subset rater 2 contributed no
independent probing.

On the blind-charter test: of 17 findings from the two blind explorers, 7 were refuted, but
only **2** as `licensed-by-doc` (12%), well under the two-in-five threshold that would say
the brief needs tightening. The blind charters' real failure mode this round was register
objections and engine-stock-behavior objections — 6 of their 7 refutations.

## The harness result — the declared bar, and it failed

The bar was fixed before dispatch and is absolute rather than comparative, because
Fulminate cannot *confirm* a harness improvement (only Dungeon has the map) and the
2026-07-31 baseline recorded no per-session breadth to compare against. Pass was: **no
`PlaytestSignals` rule trips in any session.**

Read off the seven `closing.json` files before any finding was read:

| session | cmds | rooms | noun-follow | breadth | novel | discharge | open | tripped |
|---|---|---|---|---|---|---|---|---|
| explorer-1/probe-001 | 42 | 4 | **0.067** / 45 | **1.41** / 17 | 0.86 | 0.16 | 151 | noun-follow, breadth |
| explorer-2/probe-001 | 37 | 7 | **0.048** / 21 | **1.17** / 12 | 0.59 | 0.15 | 131 | noun-follow, breadth |
| explorer-2/probe-002 | 10 | 5 | – / 0 | – / 0 | 0.70 | 0.11 | 50 | — |
| interrogator/probe-001 | 40 | 5 | 0 / 2 | 1.63 / 8 | 0.65 | 0.08 | 135 | — |
| solver/probe-001 | 29 | 3 | 0 / 11 | 1.44 / 9 | 0.62 | 0.11 | 93 | — |
| timekeeper/probe-001 | 42 | 5 | 0 / 12 | 1.13 / 8 | **0.45** | 0.11 | 128 | novel-command |
| wrong-footer/probe-001 | 45 | 4 | 0.25 / 4 | 1.67 / 6 | 0.73 | 0.12 | 106 | — |

**Fail: three of seven sessions tripped.** But the honest reading is worse than three of
seven, and it is the reason to report this rather than tune it:

**Every session is below the interaction-breadth threshold** — 1.41, 1.17, 1.63, 1.44,
1.13, 1.67, all under 2. Four escape the flag only because `objectsBound < 10`, the
minimum-sample gate, not because they played any deeper. **Every session with a meaningful
noun sample has a noun-follow rate at or near zero.** The gates are hiding one uniform
behaviour, not isolating three bad sessions.

**The signal fired, was heard, and was overridden.** This is not a silent failure.
`nudge()` delivered it into `move` results and both explorers quote it back in their own
closing notes — *"the harness flagged twice with a noun-follow rate of 0.07"*, and *"I chose
breadth across seven rooms and the endgame over closing that tail, and the tail is
genuinely unread."* The testers made a deliberate trade the briefs never told them how to
price.

**What the trade cost is measurable.** 2026-07-31 filed ~59 unanswerable nouns as class
C1; that issue is still open and nothing has been fixed in the tree since (`fix: none`
both rounds). This round's transcripts hold **12 unknown-word replies over 9 distinct
words**, and only one of the nine (`window`) is a noun the game printed. That is not
evidence the nouns were fixed — it is a measure of what the round *asked*, with 93–151
queue items left open per session at discharge rates of 0.08–0.16. The charter that exists
to find printed-but-unanswerable nouns spent its turns on rooms and hours instead.

**Recommendation, not applied here:** the fix belongs in `references/playtester-brief.md`,
not in the thresholds. Do not re-tune the signal to pass. Two rounds of evidence now say
blind explorers optimise for map and clock coverage because that is what the briefs and the
coverage queue's own framing reward, and the noun queue is what gets dropped when the turn
budget binds.

## Coverage

Counted off the transcripts under `.context/playtest/`, not off the survey. Where they
disagree the transcript wins and the disagreement is named.

### Three corrections to the round's own arithmetic

**Rooms: 9 of 9 worked, not the 8 of 9 the survey reports.** `coverage.rooms.neverVisited`
names Vane's Study. That is a bookkeeping artifact. explorer-2 stood in the Study for
**10 turns**, 6:30 to 6:48, examined the lamp, read the ledger and had Dr. Pike in the room
— `.context/playtest/Fulminate-r1-session-explorer-2/probe-001/branch-003.txt`. The turns
were then rewound out of the canonical transcript, and `closing.json.roomsVisited` does not
carry rooms worked inside a rewound branch. Verified by hand: six branch files in this
round hold **102 real engine turns** that the coverage denominator cannot see, and no
`closing.json` in the round lists Vane's Study. **This under-reports in the direction that
flatters the round**, and it is filed as a harness class.

**Turn accounting: the survey's `turnsSpent: 295` is asked, not counted.** It is exactly
the sum of the six testers' self-reported `turnsSpent` fields (41 + 96 + 41 + 48 + 28 +
41). The artifacts say: **252** turns in the seven session transcripts (counted as
`[status]` lines), **+102** in the six rewound branch files = **354 tester turns**; plus
**1,027** commands over 62 verify probes, **73** over the timekeeper's 7 replay probes,
**39** over the critic's 2 and **12** over the cartographer's 2 = **1,505 engine turns for
the round**, across 81 probes in 67 labels. The verifier stage cost
roughly three times what the testers did. Nothing is wrong with that, but "295" describes
about a fifth of the round, and SKILL.md's own rule — *anything the report states as a
number is counted, not asked* — is not yet true of this field. Filed as a harness class.

**Sessions unfinished: 0**, genuinely. All seven MCP sessions wrote a `closing.json`; the
seven probes under `Fulminate-r1-play-timekeeper` are `playtest-replay` runs, not orphaned
sessions. The `d77f5fe` collation fix held.

### Room × charter — `X` worked, `.` passed through only, `–` never reached

| charter | Hall | Parlour | Kitchen | Yard | Carriage | Cellar | Landing | Study | Boarder's |
|---|---|---|---|---|---|---|---|---|---|
| explorer-1 | X | X | X | X | – | – | – | – | – |
| explorer-2 | X | . | X | X | – | X | X | X | X |
| timekeeper | X | – | X | X | X | X | – | – | – |
| interrogator | X | X | X | X | X | – | – | – | – |
| solver | X | X | X | – | – | X | – | – | – |
| wrong-footer | X | X | X | X | – | – | – | – | – |

Every room was worked by somebody, but four of nine were worked by **exactly one charter**
— Landing, Study and Boarder's Room all by explorer-2, the Carriage House by two. Six of
six worked the Front Hall and the Kitchen. That is the shape of the round: a very
well-read ground floor and a rumour of a second storey.

### Time band × room — testers only (session + rewound-branch turns)

`X` = a tester typed a non-movement command there in that band; `.` = movement only.

| band | Hall | Parlour | Kitchen | Yard | Carriage | Cellar | Landing | Study | Boarder's |
|---|---|---|---|---|---|---|---|---|---|
| 5:30–5:44 | X | . | X | X | X | X | . | | X |
| **5:46 blast** | X | . | . | X | | | | | |
| 5:48–5:58 | X | X | X | X | | X | | | |
| 6:00–6:08 | X | X | X | X | | X | | | |
| 6:10–6:18 | X | X | X | X | | X | | | |
| **6:20 phone** | X | | X | X | | . | | | |
| 6:22–6:28 | X | X | . | X | | X | X | | X |
| 6:30–6:38 | X | X | X | X | | X | | X | X |
| 6:40–6:48 | | X | X | X | | X | | X | X |
| **6:50 end** | | X | X | X | | X | | | |

**49 of 90 cells worked, 6 movement-only, 35 blank.** Nine of the blanks are the Carriage
House below 5:44, which stops existing — legitimately dead. Net about 26 live blank cells,
and they cluster: the entire upstairs before 6:22, and the Parlour and Kitchen at 6:20.

Against 2026-07-31's 103 of 162 hour × room cells, this grid is coarser (10 bands rather
than 18 discrete minutes) and is **not** a like-for-like comparison; it is reported in
bands because that is what the two focus regions were written in.

### Event × room — `X` tester frame, `v` verifier-probe frame only

| event | Hall | Parlour | Kitchen | Yard | Carriage | Cellar | Landing | Study | Boarder's |
|---|---|---|---|---|---|---|---|---|---|
| blast 5:46 | X | X | X | X | — | v | | | v |
| **blast 5:46 death branch** | | | | | **blank** | | | | |
| blast.after | X | v | v | X | — | X | v | | v |
| blast.after (knocked flat) | | | | X | — | | | | |
| blast.settling | X | v | X | X | — | | | | v |
| radio car 5:52 | X | v | X | X | — | | | | v |
| telephone 6:20 | X | X | X | X | — | | | | v |
| coroner 6:50 | v | X | X | X | — | X | | | |

**Two endings printed in zero tester files, and both were claimed as read.** Verified by
hand over the whole `.context/playtest/` tree:

- The 5:46 carriage-house death branch (`"hold this a moment"`) appears in **exactly one
  file, and it is the critic's own probe** — `Fulminate-critic/probe-001/transcript.txt`.
  Both the timekeeper (*"plus the death branch in the lab"*) and the solver (*"I saw the
  prompt fire and read the death text"*) assert they exercised it. Neither has an artifact.
- The partial-win ending (`"writes down her name and closes the book"`) appears in **zero
  files**, despite the solver reporting five minus-one-step replays that produce it.

The explanation is near-certainly the MCP `replay` tool, which writes no probe directory —
explorer-2, wrong-footer and solver all say in their own notes that load-bearing frames
came from free `replay` calls with no session transcript. That is a harness hole rather
than dishonesty, but it means a non-trivial share of this round's evidence **cannot be
audited by anyone who was not there**, which is the exact failure the cite-the-probe rule
exists to prevent. Filed as a harness class.

### Actor-crossing prose — the 28 scheduled arrival/departure lines

- **Never printed anywhere, tester or verifier: 2.** *"Delphine comes into the study and
  starts on the desk drawers."* (6:02) and *"Dr. Pike lets himself into the study and is
  not pleased to find company."* (6:14). Both are Study on-cell, and nobody stood in the
  Study before 6:28 all round.
- **Verifier-probe only, no tester frame: 5.** Teague's 5:42 kitchen re-entry; Constance's
  5:48 Parlour departure and 5:54 return; Kettle's 5:48 departure; Delphine's 6:26 Study
  departure.
- The remaining 21 have at least one tester frame.

The critic showed the vertical gap was cheap rather than impossible: one 26-turn probe of
`up, west, z×24` (`Fulminate-critic/probe-002/transcript.txt`) filled **five alarm × Study
cells the whole round left blank** and printed **both** of the arrival lines that had
never printed anywhere.

### Talk surface

Two of the four `talk.shows` rows never fired in any artifact: **`SHOW LEDGER TO PIKE`**
(`.notebooksSold`) and **`SHOW LETTERS TO DELPHINE`** (`.delphineCleared`), along with both
`again:` variants and every `knowing:`-gated row behind them. `SHOW LEDGER TO PIKE` was
also the named target of this round's focus and it **still did not fire** — both objects
live in Vane's Study, which no charter's assigned time window covered.
`SHOW GLOVE TO CONSTANCE` fired once, inside solver's rewound `branch-001`. Mrs. Kettle was
never examined or spoken to by either explorer; **Dr. Pike was never examined by anybody**,
despite being the man the first hour is about.

### Unknown words

9 distinct over 12 occurrences, reconciled against the per-session records: `coroner` 3,
`notebooks` 2, `answer` 1, `blast` 1, `explosion` 1, `frotz` 1 (the reserved non-word),
`lodgers` 1, `visit` 1, `window` 1. Only `window` is a noun the game printed, and it
arrived as an ordinary finding. See **The harness result** for why this number is a
measure of what the round asked rather than of what the game answers.

### Charters that ran but did not run their region

No charter was silent — all six filed, and all six appear in the refuted list. The silence
is regional:

- **timekeeper's second row.** Assigned 6:20–6:50 across the cross-product; spent the last
  ten turns of the game standing in one lit Cellar and reports that nothing printed. Its
  own note concedes roughly three quarters of its probes went to the first hour. The
  6:30–6:50 band in the Hall, Parlour, Kitchen, Yard and Landing is unprobed by the seat
  that owned it.
- **wrong-footer's stub sweep above the ground floor.** 45 turns, four rooms, zero stub
  verb / wrong-noun / ambiguity probes upstairs or in the Cellar. Three rows of the
  *mandated* article sweep (`take`/`greet`/`follow` Teague) and three more for Julian are
  unrun, so the sweep the charter exists to run is 4 of 6 actors complete.
- **solver's prose obligation**, explicitly declined and said so. A legitimate charter
  boundary, but three of nine rooms got no reading from that seat.

**On the focus split.** The two regions did what they were for — two explorers drew
`commit` and `abstain`, and the 6:20–6:50 half hour that 97% of the last round never
reached was worked by explorer-2 and reached the ending three times. But the split by clock
left the *vertical* axis owned by nobody: Vane's Study is not in either region, and it is
where both never-printed arrival lines and both never-fired `shows` rows live. A clock
split cannot express "upstairs", and this round is the evidence that Fulminate needs both
axes.

### Dropped

**0 findings dropped for budget, 0 as non-reproducible.** All 15 were double-rated; every
confirmed finding carries a replayed reproducer. Testers self-dropped 10 claims before
filing, and those are recorded in their coverage notes rather than as findings — three of
them were dropped specifically because the reporter correctly diagnosed the `[status]`
footer offset, which is now filed as its own class.

The `open`-fork queue and the 93–151 item noun queues per session are **unread, not
dropped**, and are not counted as covered.

## Hygiene

- Seed `0`, pinned. Turn budget 60 per charter; 360 planned, 1,505 engine turns spent over 81 probes in 67 labels.
- No charter skipped. `capabilities: ["clock", "talk"]`, derived from `Package.swift:178-182`.
- `routedIssues: []` — derived fresh; the only open `enhancement` issue is #129 (Dungeon)
  and it owns no class a Fulminate tester could raise.
- Fulminate declares no `Scoring`, so there is no score to check. The solver confirmed
  `text.scoreLine` prints *"You were in that house for N turns."* with a live counter, which
  is what the design doc's Endings section prescribes. 2026-07-31's class C17 (*"every
  ending closes on `Your score is 0`"*) is fixed in the tree; **#122 is closed**, and the
  absence of `GnustoScoring` from `Package.swift` is correct rather than a gap.
- `node .claude/workflows/playtest.dryrun.mjs` — exit 0, 13 agents, all assertions passed.
- Staleness check before dispatch: `open`/`finish` returned `roomsVisited` and
  `unknownWords` and wrote a `closing.json`; the opening queue returned 12 Front Hall nouns
  and none from the intro paragraphs, confirming the server carried `1df88f3`.
- This round changed no source. `swift test` and the strict lint are unaffected.
