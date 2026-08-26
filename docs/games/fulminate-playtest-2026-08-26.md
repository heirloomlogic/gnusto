# Fulminate — playtest round, 2026-08-26

Commit `da3e623` · seed `0` · `fix: "none"` · charters: explorer ×3, timekeeper ×3,
interrogator, solver, wrong-footer (9 of 9 applicable, none skipped)
Oracle tiers: T0 kernel, T1 design doc (`docs/games/fulminate.md`, contract + timeline +
solution), T2 `FulminateTests`, T3 source, T4 git history.
Budget: 540 turns planned (60 × 9). **1,288 engine turns counted off the `[status]`
footers** — 330 in tester sessions, 56 in rewound branches, 339 in the testers' own
`replay` probes, 563 in verifier probes.
16 agents, 0 errors, 1.50M subagent tokens, 531 tool calls, 50 minutes wall clock.

22 findings raised → **16 confirmed** (12 unanimous `confirmed-defect`, 4 `needs-human`),
6 refuted, 0 routed, 0 fixed. Verifier agreement **81.8%** (18 of 22 double-rated, 0
single-rated). Deduplicating the 16 by declaration gives **15**; by root cause, **6
classes**. The completeness critic adds 3 more that no tester raised, for **9**, filed as
one issue. Critic trustworthiness: **sound**.

## What this round's header has to declare

**Two operator changes were made before dispatch, and both are load-bearing.**

**1. `docs/games/fulminate-playtest-focus.md` was written for this round** and did not
exist before it. Preflight would otherwise have passed `focus: ""` and all nine seats
would have started where the player starts — which is what 2026-08-17 did, and its own
coverage section is the record of what that cost. The new file splits on **both** axes,
vertical and clock, in three regions written in affordances rather than room names. The
firewall property was checked by injecting the real focus string into a patched copy of
`playtest.dryrun.mjs` and re-running the prompt assertions; all of them passed. **The
split is why this round found what it found**, and it is also why the round has the
specific hole reported under *Coverage* below. Both halves of that belong in the header.

**2. `ledgerKeys` was overridden by hand, 109 → 15.** `ledgerKeysFrom()`
(`bin/playtest-preflight:371-376`) scrapes every backticked `a::b` string out of the whole
ledger — *confirmed* rows and incidental prose alike. The 2026-08-17 rows are full,
untruncated `decl::` keys, so unlike the older `…`-truncated ones they match the dedup at
`playtest.js:1055-1069` exactly. Four of them (C2 `teague.description`, C4
`rules/suitcase.before(.take)`, C7 `rules/teague.topics/constance`, C7
`rules/labLamp.describe`) are still open and unrepaired — the last two were checked against
source before dispatch and stand as filed. Handing those to testers as already-rejected
would have suppressed them. What was passed instead: the 2026-08-17 and 2026-07-31
refutations only, minus the `licensed-by-doc` ones, on the reason 2026-08-17 gave for
withholding six of the same kind — `docs/games/fulminate.md:77-83` has since narrowed that
clause in as many words. **This is a preflight defect, not a one-off**: the next round
will scrape the same 109 and will now also scrape this round's confirmed keys.

**The declared bar passed, all four items.** It was written down before dispatch, at
`.context/playtest-2026-08-26-bar.md`, and each item is checked here against artifacts
rather than against a tester's word:

| # | Bar | Result | Evidence |
|---|---|---|---|
| 1 | every region produces a tester frame | **met** | findings from all three: R1 → 9, R2 → 4, R3 → 3 |
| 2 | both never-printed arrival lines print in a **tester** transcript | **met** | Delphine 6:02 and Pike 6:14 in `Fulminate-2026-08-26-r1-session-explorer-2/probe-001/transcript.txt`, `-timekeeper-1/`, `-timekeeper-2/`, `-interrogator/` |
| 3 | both never-fired `shows` rows fire, with a citable probe | **met** | `show ledger to pike` ×17 (`-session-explorer-2/probe-001/`), `show letters to delphine` ×2 plus its `again:` variant (`-session-interrogator/probe-001/`) |
| 4 | the partial-win ending appears in an artifact with a path | **met** | `-session-solver/probe-001/branch-002.txt` and `branch-003.txt`, plus `-verify-b01-r1-16/probe-001/` and `-r2-16/probe-001/` (three `.replays/` probes also held it — see *Evidence destroyed after the round*) |

All four show surfaces fired this round, including `show glove to mrs. vane` — the critic
counted them off the artifacts, and the previous round's two never-fired rows are no longer
never-fired.

**Four of the sixteen "confirmed" rows are `needs-human`, and one of those had no
confirming vote at all.** A split verdict is reconciled to `needs-human`
(`playtest.js:1799`), and `needs-human` is then counted into `confirmed`. C1, C9 and C15
each drew one `refuted` and one `confirmed-defect`. **C16 drew `needs-human` and
`refuted` — no rater confirmed it** — and it is in the confirmed list anyway. That is
arithmetic worth knowing about before reading the headline number; the class is still
worth a person's attention, but it is not a confirmed defect and this report does not
present it as one.

## The round

Two classes carry most of it, and both are the same failure at different scales: **a
static string that was written once, for one frame, and is printed in others.** Everything
here predates this branch; nothing was introduced by it.

- **Teague's 5:36 departure is narrated as a sound heard through a door while the player
  is standing in the room with him.** *Frame:* Boarder's Room, 5:36 pm, moves=4, pre-blast,
  with "Howard Teague is here, being helpful." in the same turn's output. *Cause:* the
  `Stop(at: TimeOfDay(17, 36), …, departure:)` string in `teagueDay`
  (`Fulminate.swift:1106`) is written for a listener elsewhere — "Teague's door goes, and
  there are feet on the back stairs" — but a `Stop(departure:)` prints **only** in the
  room being left, so the co-located frame is the only frame it can ever print in. The
  sibling stops in the same table are all witnessed events. Two testers reached it
  independently by different routes; one line, one fix.
- **Delphine's 6:26 departure says she "takes the cellar stairs down" from a room two
  floors from any stair.** *Frame:* Vane's Study, 6:26 pm, moves=29. *Cause:*
  `delphineDay`'s `Stop(at: TimeOfDay(18, 26), in: cellar, departure:)`
  (`Fulminate.swift:1230`); her previous stop pins the printing room to the study for the
  whole evening, so the sentence can only ever print upstairs, and names a fixture the
  study has not got — one the game calls "the cellar steps" everywhere else.
- **Pike takes his hat off and four separate strings go on saying he never has.** *Frame:*
  Vane's Study, 6:16–6:36 pm, after `show ledger to pike` prints "and takes his hat off at
  last." *Cause:* three static declarations with no branch — his own `description`
  (`:911`), the hat item's `description` (`Fixtures.swift:96`), and three conversation
  strings that stage him under a brim (`:2461`, `:2485`, `:2687`, one of them the `again:`
  of the very row that removed the hat). The state to branch on already exists: the show
  row sets `learning: .notebooksSold`, and the neighbouring "He adjusts the hat he has not
  taken off" row is already gated `unless: .notebooksSold`. A fourth site — his listing
  line, "Dr. Pike is standing about with his hat on." — was named by a verifier and filed
  by nobody; it is carried into the issue.
- **Five nouns the prose prints and the parser denies.** `papers` (`x desk`, the
  arrangement of them *is* the clue), `chain` (the ceiling light's description names it
  twice and makes the wiped chain the evidence), `dust` (the `blast.after` fuse declares
  it settled on every flat top in six rooms), `circle` (`x grass`, "a scorched
  half-circle"), and `cellar steps` — declared in the Kitchen only, so the noun leaves
  scope the moment the player walks down them, and the Cellar's own 6:26 arrival line
  prints it. Four answer "I don't know the word", which is a vocabulary gap rather than a
  scope one. *Cause:* one declaration each; `chain` was **introduced seven commits back**
  by `9caa400`, whose job was closing an unanswerable-noun defect on the same object.
- **Three places where the prose offers an act and the engine refuses it in its own
  voice.** `turn on lamp` on a lamp whose description spends two sentences on its switch
  state → "You can't turn that on." `pull light` on a pull-chain → "The ceiling light
  doesn't budge." `enter wreckage` during the three turns the doc says the lab is open →
  "You can't get into the wreckage.", while `north` on the very next turn walks straight
  in. *Cause:* no device trait, no `before(.pull)`, no `before(.board)`. The repair pattern
  for all three is already in the file — `ceilingLight.before(.turnOn, .turnOff)` refuses
  in the game's voice, with a comment naming this exact defect.
- **`X ME` says the player took statements "in this hall" from a rented bedroom.**
  *Frame:* Boarder's Room 5:34, Upstairs Landing 5:38. *Cause:* `text.selfDescription`
  (`:158`) is a static string carrying a deictic that is only true in the Front Hall, and
  the doc's own map table calls the Landing "Upstairs hall". Split 1–1; carried as
  `needs-human`, with both rationales below.
- **Eight stub verbs answer in the engine's voice** in a game that re-skinned seven
  others. *Cause:* `GameText.stubs` rows never assigned. No rater confirmed it. Recorded
  as a scope question for a person: which of the engine's ~47 stubs does this game mean to
  voice?

## Filed

16 findings → 15 declarations → 6 classes, plus 3 the critic adds. Filed as **#334**,
*Fulminate: play-test round 2026-08-26 — 9 defect classes*.

| Class | Findings | Severity | Owner | Site |
|---|---|---|---|---|
| A timetable string names a frame it cannot print in | C1+C9, C12 | major | `game` | `Fulminate.swift:1106`, `:1230` |
| Pike's hat comes off and four strings never read it | C7, C8, C14 (+1 unfiled) | major | `game` | `:911`, `Fixtures.swift:96`, `:2461`/`:2485`/`:2687` |
| A printed noun the parser denies | C2, C3, C6, C10, C13 | major ×3, minor ×2 | `game` | `desk`, `ceilingLight`, `blast.after`, `dryGrass.describe`, `cellarSteps` |
| The prose offers an act, the engine refuses it in its own voice | C4, C5, C11 | minor | `game` | `studyLamp`, `ceilingLight`, `debris`/`carriageHouse.describe` |
| A deictic in the player's own description | C15 | major (`needs-human`) | `game` | `Fulminate.swift:158` |
| Eight stubs left in the engine voice | C16 | minor (no confirming vote) | `game` | `GameText.stubs` |
| *critic:* three unknown words nobody argued | — | — | `game` | `arroyo`, `lining`, `stoop` |
| *critic:* the Carriage House got zero commands in 1,288 turns | — | — | `harness`/coverage | see below |
| *critic:* two counting blind spots in the collator | — | — | `harness` | `closing.json`, `.replays/` |

Every `ownerClass` came back `game`. No finding this round was the engine's.

## Refuted

| # | Charter | Claim | Refutation |
|---|---|---|---|
| R01 | explorer-3 | The patrolman line prints "the wreckage" and the parser then denies it | Both nouns are declared and real; "You can't see any such thing" is the reserved out-of-scope reply, and the sentence locates both nouns outside the player's room in the act of naming them. `stock-behavior-by-design` |
| R02 | explorer-3 | The aftershock daemon calls the hour "night" at ten to six in June | "a night like this" is the occasion, not the hour or the darkness; the game's register uses the word that way throughout. Nothing false of the frame. `licensed-by-doc` |
| R03 | explorer-1 | The Landing names two of three exits and omits the stairs down | The copy is printed verbatim in `fulminate.md`'s Rooms section; four other rooms name no exits at all, so exit-listing is not a house rule. An omission is not a false clause. `licensed-by-doc` |
| R04 | solver | Every ending closes on "You were in that house for N turns", against a source comment saying minutes | `fulminate.md`'s Endings section specifies that copy verbatim, down to the word "turns". `licensed-by-doc` |
| R05 | explorer-3 | A carried item returns its full visual description in a pitch-black room | `DefaultActions.examine:709` adjudicates this deliberately and says why — four commits old, an argued decision rather than a default. `stock-behavior-by-design` |
| R06 | explorer-1 | FOLLOW says "no idea which way X went" after the game narrated which way | `follow` searches one exit deep and `GameText.lostThem`'s doc comment says so; Teague is four rooms away and the back stairs are not an exit of that room. `stock-behavior-by-design` |

**A note that runs the other way.** R04's refutation was argued against a Parlour ending —
an indoor frame. The critic found a *carriage-house death* frame that prints the same line
outdoors, after the building the sentence names has stopped existing. That is a different
frame and is fair to file next round; it is not a re-find.

### The rater-independence audit

The script writes no rationales to disk, so they exist only here.

**A pair both raters confirmed — C7, Pike's hat.** Their `attemptedRefutation`s, in full:

> **Rater 1.** *The strongest case against: "takes his hat off at last" could be a
> momentary gesture — a man lifts his hat and puts it back — in which case the standing
> description remains true of the evening as a whole. And Pike's description is documented
> as deliberately location-blind […] so one might read it as intentionally frame-free.
> Neither holds. "At last" marks a capitulation, not a lift, and nothing in the code puts
> the hat back; and location-blindness is orthogonal — the false clause here is about a
> state the game changed, not a room.*

> **Rater 2.** *The best case for the line: "he has not had the hat off since he came" is
> a claim about a habit rather than about this second […] Two things kill that. The
> sentence is in the present perfect and is offered as the reason he is the way he is, so
> it is a claim about now; and the hat's removal is the single dramatic beat of the scene
> the show row exists to deliver, so contradicting it one turn later is the worst possible
> place to be approximately true.*

**These read as separately reasoned.** They attack different defences (momentary-gesture +
location-blindness vs. habitual-vs-present), cite different precedents in the file (the
`blastHappened` cast descriptions vs. the glove row's `perform:` conversion), and reached
the frame at different move counts — 24/25 against 26/27, off command lists of 27 and 32
lines respectively.

**But the round-wide picture is worse than that pair.** Of 18 rater pairs whose probe
directories can be compared, **12 ran byte-identical command lists** on their first probe
(`Fulminate-2026-08-26-r1-verify-b01-r{1,2}-NN/probe-001/commands.txt`). That is the same
caution the 2026-08-17 round raised at 10 of 26, and it is a larger fraction here. On that
subset rater 2 contributed no independent probing, and the 81.8% agreement figure is worth
less than it looks.

**The three splits, with both sides.** C1 and C9 are one declaration reached by two
testers; rater 1 refuted both on the ground that `Clock+Schedule.swift:77` prints a
departure only in the room being left, so the line is branched and the co-located frame is
the only one it has. Rater 2 confirmed both on the ground that this makes it *worse*, not
better: if the co-located frame is the only frame, then a line written for someone who
cannot see the door is wrong in every frame it will ever have. **Rater 2 is right, and
rater 1's own evidence proves it** — that is the reasoning recorded here so the next
round does not have to re-derive it. C15 split on whether "in this hall" is a present-tense
claim about the player's surroundings or a past-tense clause locating a 1948 event; that
one is genuinely a judgement and stays `needs-human`.

## Coverage

Every number below is counted off `closing.json` and the `[status]` footers. Where the
critic's recount disagrees with the harness's own figure, **the critic's is reported and
the disagreement is named**.

### Rooms — the harness figure is wrong in both directions

`coverage.rooms` reports **8 visited, 8 worked, of 10**, with `Carriage House` and
`Orange Grove Avenue (street)` never visited.

- **The denominator is wrong by one.** `street` is not a room, it is an offstage holding
  pen: `Fulminate.swift:390` says so — *"Off the map: no exit leads here and the player
  never sees it."* No rule ever moves the player there. **Corrected: 9 reachable rooms, 8
  entered, 1 never entered.**
- **`worked` is technically true and badly misleading.** It credits a room where a session
  typed one non-travel command; by that standard the Parlour is "worked" on three
  `accuse`s. Counted off the transcripts:

| Room | Distinct real commands | Total | Reading |
|---|---|---|---|
| Vane's Study | 44 | 115 | genuinely worked |
| Boarder's Room | 37 | 72 | genuinely worked |
| Cellar | 16 | 37 | worked |
| Back Yard | 13 | 23 | worked |
| Kitchen | 6 | 21 | the flashlight errand + 1 ask |
| Front Hall | 7 | 18 | 5 of 7 are the Teague/receipt errand |
| Upstairs Landing | 6 | 10 | **1 real noun all round** (`x runner`) |
| Parlour | 3 | 8 | 3 accusations; zero furniture, zero conversation |
| Carriage House | **0** | **0** | — |

**187 of 304 real commands (61.5%), and 81 of 132 distinct ones, landed in two rooms.**
The honest figure is **four rooms worked, four touched, one blank.**

### Charter × room

`X` worked · `.` passed through only · `–` never reached

| Charter | Hall | Parl | Kitc | Cell | Yard | Carr | Land | Stud | Brdr |
|---|---|---|---|---|---|---|---|---|---|
| explorer-1 | . | – | – | – | – | – | X | X | X |
| explorer-2 | . | – | – | – | – | – | X | X | X |
| explorer-3 | . | – | X | X | X | – | – | – | – |
| interrogator | . | – | – | – | – | – | . | X | X |
| solver | X | X | X | X | . | – | – | – | – |
| timekeeper-1 | . | – | – | – | – | – | . | X | X |
| timekeeper-2 | . | – | – | – | – | – | X | X | X |
| timekeeper-3 | . | – | X | X | X | – | – | – | – |
| wrong-footer | . | – | – | – | – | – | X | X | X |
| testers' `.replays/` | X | X | X | X | X | . | X | X | X |

**Eight of nine seats crossed the Front Hall and only the solver typed a noun in it.**

### Event × room

`X` a tester stood there and typed something on that turn · `.` stood there only · `–` never

| Event | Hall | Parl | Kitc | Cell | Yard | Carr | Land | Stud | Brdr |
|---|---|---|---|---|---|---|---|---|---|
| blast 5:46 | . | . | – | X | . | **–** | X | X | X |
| blast.after 5:48 | . | X | – | X | X | – | X | . | X |
| blast.settling 5:50 | . | – | – | X | X | – | . | X | X |
| radio car 5:52 | . | – | – | X | . | † | – | X | X |
| Delphine 6:02 | . | – | . | X | – | – | – | X | X |
| Pike 6:14 | X | . | – | . | X | – | . | X | X |
| telephone 6:20 | X | X | **–** | . | X | – | . | X | X |
| Delphine→cellar 6:26 | – | X | – | X | X | – | . | X | X |
| Teague 6:30 | – | – | – | X | . | – | . | X | X |
| coroner 6:50 | – | – | – | X | . | – | – | . | X |

† Three probes entered the Carriage House at 5:52 and were evicted by the patrolman
**inside the same turn**, so the footer records Back Yard.

Full time × room cross-product, all 41 two-minute ticks × 9 rooms = 369 cells: **239
occupied (65%), 144 worked (39%).** Verifier replays added **zero** cells the testers had
not already stood in.

### The Carriage House — the round's largest single hole, and it is the split's fault

Zero commands, ever, in 1,288 turns. It is three moves from the start. It holds five
examinable objects, a workbench with a scorch mark "older than tonight", a sealed can of
the murder weapon, **and Julian Vane — the victim, who has never been examined by anybody
in any round** — plus its own `describe`, its own `before(.listen)` and `before(.smell)`
rules, a pre-blast and a post-blast description, and a death ending nobody produced.

The critic produced that ending in nine commands
(`.context/playtest/Fulminate-2026-08-26-critic/probe-001/transcript.txt`):

```
> z
Vane says "hold this a moment" and you never learn what. The bench, the roof,
and the better part of the garden wall arrive in the yard ahead of you.

*** You have died ***
```

`hold this a moment` appears in **zero other files** under `.context/playtest/`.
`clock.blast` fired 81 times this round and its `carriageHouse` branch
(`Fulminate.swift:1326`) never once. Also caught in that same probe and seen by no seat:
Teague's carriage-house beats at 5:38 and 5:42, visible only from inside the room.

**This is a consequence of the focus split written for this round, and it should be read
as one.** The regions were drawn as **floor × hour** and six of nine seats drew the
upstairs floor; the Carriage House only exists before 5:44, and no region owned the
pre-blast ground floor or the outbuilding. The last round left the vertical axis
unassigned; this one fixed that and left the *early ground floor* unassigned instead. The
lesson is not "write no focus file" — it found the upstairs defects nothing else could —
it is that **a three-region split of a nine-room game must still name a seat for the rooms
outside every region**, and this one did not.

Four rooms produced zero findings — Front Hall, Parlour, Kitchen, Carriage House — and in
all four the cause is that nobody worked them, not that they are clean.

### Actors

| Actor | Examined | Addressed |
|---|---|---|
| Dr. Pike | 7 | 22 |
| Delphine Marsh | 10 | 13 |
| Howard Teague | 5 | 18 |
| Patrolman | 3 | **0** |
| **Julian Vane** | **0** | **0** |
| **Constance / Mrs. Vane** | **0** | 1 (`show glove`) |
| **Mrs. Kettle** | **0** | 1 (`ask kettle about teague`) |

Three of seven actors were never looked at, and two of those are the answer to the
mystery. Mrs. Kettle got one of her four generated-testimony rows — and hers is the one
surface in the game whose past tense is read from `location(of:at:)`, which the
interrogator itself named as the highest-value unprobed thing in the game. The patrolman
was asked nothing at all.

### Timers

11 declared, **11 fired, 0 never fired**: `clock.coroner` 381, `constance.day` /
`delphine.day` / `kettle.day` / `pike.day` / `teague.day` 373 each, `clock.telephone` 250,
`clock.radioCar` 108, `clock.blast` 81, `blast.after` 9, `blast.settling` 9. No timer went
undeclared or unfired.

Two **branches** went unread and are the right analogue: `clock.blast`'s carriageHouse
death branch (0 of 81 firings) and `clock.radioCar`'s carriageHouse eviction branch (3 of
108, all in replays).

### Turns — verified exactly, and the residual is solved

`330 sessions + 56 branches + 339 testers' replays + 563 verifier probes = 1,288.` All four
re-counted off `turn=cost` footers; all four match. **Testers 725, verifiers 563 — a
0.78:1 verifier-to-tester ratio.** This round played more than it argued, which is the
healthy direction and the opposite of the last two.

Testers ran ~34% over a 540-turn budget, and nearly every seat disclosed the overrun in its
own note rather than hiding it.

**The residual.** The unglobbed grep found 3,504 `turn=cost` footers under
`.context/playtest`, leaving 2,216 unattributed. They are **another game's artifacts
sharing this checkout**: fourteen directories, every one `game=Dungeon seed=52` —
`prep-p-2` (704), `prep-p-1` (644), `prep-c-2` (218), `prep-c-1` (179), `prep-m-2` (125),
`prep-m-1` (120), `prep-d-1` (110), `prep-z-2` (35), `prep-z-1` (29), `chk-d1` (15),
`chk-p2` (11), `chk-z-2` (11), `chk2-z2` (10), `chk-m1` (5), summing to exactly 2,216.
`3,504 − 2,216 = 1,288`. **The harness's total is correct and this round's alarm can be
retired.** The residual mechanism worked as designed: it named an uncounted tree on the
round it appeared in rather than a round later.

### Unknown words — 11 distinct, 15 occurrences, and three were never adjudicated

Six of the eleven are words the game itself printed and then refused:

| Word | Printed by | Filed? |
|---|---|---|
| `papers` | `x desk` | C2, both raters confirmed |
| `chain` | ceiling light | C3, both raters confirmed |
| `circle` | `x grass` | **C10, both raters confirmed** — the critic could not confirm it reached the list; it did |
| `arroyo` | `x pike` — *"back up the arroyo"* | **never mentioned in any report. Unadjudicated.** |
| `lining` | `x glove` — *"burned back to the lining"* | **never mentioned. Unadjudicated.** |
| `stoop` | Cellar description — *"you walk it at a stoop"* | **never mentioned. Unadjudicated.** |

`window`, `explosion` and `frotz` were guesses the game never printed; `notebooks` and
`visit` are topic keywords the interrogator correctly explained away.

`arroyo` is the strongest of the three unargued — a place name in a character's own
description, in a game where *where were you* is the mechanic. All three may refute, but
nobody argued them either way, and **an unargued one is invisible rather than cleared.**
They are carried into the next round's set as *unexamined*, not as covered. One
possibility worth checking rather than asserting: the sighted charters' do-not-report paste
carried a truncated 2026-07-31 key naming the same Cellar sentence `stoop` sits in, which
would explain the silence among sighted seats but not among the blind explorers.

### One self-report that outran its artifact

Explorer-3's round summary claims it reached *"the Carriage House for the one turn the
patrolman allows"*. Its `closing.json` lists four rooms and the Carriage House is not among
them; its 45 status footers cover Front Hall, Kitchen, Cellar and Back Yard and none of
them. The frame it is thinking of was `.replays/probe-004`, a sessionless throwaway. Its own
in-transcript `[finish]` note is accurate and does not claim it. **Reach, not coverage —
counted blank.**

### Two counting blind spots, both new and both `harness`

- **`closing.json`'s `roomsVisited`, and any footer-derived count, are blind to a room the
  player was moved out of inside one turn.** Three probes entered the Carriage House at
  5:52 and were evicted by the patrolman within the turn, so the footer recorded the Back
  Yard. `neverVisited` is therefore a slight over-report; `worked` is unaffected. The
  pattern to copy is the usual one: have the engine write the entry down rather than
  inferring it from the turn's closing state.
- **`coverage.turns.replayProbes` reported 31 against 29 directories on disk.** Counted at
  the time as `ls -d .context/playtest/.replays/probe-* | wc -l` → 29. The turn total is derived from
  footers rather than from this count, so no reported number moves; it is a directory
  tally that is wrong and would be believed.

### Evidence destroyed after the round, and the defect that did it

**All 29 probe directories under `.context/playtest/.replays/` were deleted after this
report was written**, by a run of `bin/playtest-preflight`. The script's cleanup removed
the whole shared `.replays` tree rather than the one probe its own `replay` check had
just written. Two defects in one line, and they propped each other up: the check
`exists(REPLAY_TREE)` was satisfied by any probe any previous round had left — so a
genuinely stale server would have passed it on somebody else's evidence — and it only
appeared to work because the cleanup then removed the tree. It also contradicts the
invariant CLAUDE.md states in as many words, that `.context/playtest/` may hold every
round the checkout has ever run.

**Fixed in this branch.** Preflight now diffs the probe set across its own `replay` call,
asserts that a *new* probe appeared, and removes only that one. The regression is pinned
by a canary probe surviving a full preflight run.

**What was lost, and what was not.** The 16 confirmed findings each carried a
`.replays/probe-NNN/transcript.txt` in their `transcriptPath`, and those files are gone.
Everything else survives and is untouched: all **9** session transcripts with their
`closing.json` and rewound branches, all **43** verifier probe directories, and the
critic's own probe. Every confirmed finding still has at least one surviving witness —
the verifiers replayed each one independently, under `-verify-b01-r{1,2}-NN/probe-001/`,
and those are the probes the report's own rater-independence audit cites. Three citations
in this report pointed into the deleted tree and have been re-pointed above.

**The reproducers themselves are unaffected**, because they are command lists rather than
files: every one in this report and in #334 replays from a clean start at seed 0.

### Charters that ran but did not run their region

**None.** All nine seats filed, all nine produced a transcript, a `closing.json` and turns
over budget rather than under it. The confirmed findings are spread across eight of the
nine.

**One seat found nothing in its own class, and that is a result.** The **solver** was sent
to break four gates and every one held: the game is winnable at seed 0 on the doc's route,
`ACCUSE` before 5:46 is refused, the keystone ask is genuinely gated on the receipt, the
wrong-name ending fires, and the deadline loss fires at 6:50 on the correct
`sawTheWreckage` branch. It spent 64 session turns plus 5 rewound branches plus 40 replay
turns proving it. Its single finding is against the **design doc**, not the game — the
Evidence table implies the glove is required for the two-name ending and it is not, which
the code comment at `Fulminate.swift:2701` already admits. **That is "ran hard, found the
game clean", and it is recorded as evidence of cleanliness.** The solver was also the only
seat that worked the ground floor at all.

**The silences this round are regional, not charter-shaped.** That is the thing the split
got wrong, and it is named above.

### Dropped

**0 findings dropped for budget, 0 as non-reproducible.** All 16 confirmed carry a replayed
reproducer and a probe path. Testers self-dropped two claims before filing (Teague's
"a man has just died" examine text, unreachable inside budget from upstairs; Delphine's
listing line against her examine text, read as tension rather than contradiction) and
recorded both in their coverage notes; neither is counted as covered.

The three unargued unknown words are **unexamined, not dropped**, and are not counted as
covered.

## Next round's targets

Carried from the critic, in its priority order:

1. **Carriage House × 5:34–5:44, pre-blast, with a committing seat.** Three moves from the
   start. Sweep its five objects, examine and question Julian Vane, catch Teague's 5:38 and
   5:42 beats, then stay for 5:46 and take the death ending.
2. **Front Hall × 5:30, furniture sweep.** `x telephone`, `x clock`, `x hat stand`,
   `x table`, `x tile`, `x grout`, `x overcoat`, `take overcoat`, `search overcoat`,
   `x front door` — none has ever been typed.
3. **Front Hall × 6:20, the telephone call.** `clock.telephone` fired 250 times and no seat
   stood in the hall for it. Three charters named this as their own biggest gap.
4. **Parlour × the whole evening, with Constance.** Never examined by any tester in any
   round.
5. **Kitchen × Mrs. Kettle's generated testimony.** One of four rows asked all round, and
   hers is the only surface that can contradict the timetable.
6. **Back Yard × the patrolman, 5:56–6:50.** Asked nothing in the entire round; the
   "deadline reaches the page when somebody asks him for it" surface is unprobed.
7. **Upstairs Landing × any hour, real nouns.** One noun typed in the round's most-crossed
   room. Also settle whether Vane's Study genuinely offers the `up` exit the coverage queue
   reported and nobody typed.
8. **Adjudicate `arroyo`, `lining` and `stoop`.**
9. **The "You were in that house for N turns" line from the carriage-house death frame** —
   a different frame from the one R04 was refuted against.

And one operator item: **fix `ledgerKeysFrom()` so it scrapes refuted rows only**, or the
next round will suppress this round's sixteen.

## Hygiene

- Seed `0`, pinned via `GNUSTO_SEED` on every session, branch and replay probe.
- Budget 540 planned, 1,288 spent; testers 725 (~34% over), verifiers 563.
- Charters not run: **none**. Sessions unfinished: **none** — all 9 wrote a `closing.json`.
- `bin/playtest-preflight Fulminate` green before dispatch: build, 13 tools, `closing.json`
  4/4 fields, `replay` probe written, `.mcp.json` key matched.
- `node .claude/workflows/playtest.dryrun.mjs` green; the firewall assertions were also run
  against this round's real `focus` string via a patched copy, and passed.
- This round changed no source. No test count and no diff stat to report.
