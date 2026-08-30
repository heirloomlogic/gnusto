# The round report

Two committed artifacts per round, one tracker entry, and a scratch directory that
isn't committed.

| Path | Committed | Contents |
|---|---|---|
| `.context/playtest/<label>/<probe>/` | no | one run: `transcript.txt` with the `//` annotations, `commands.txt` — every line actually fed — its stderr, and a summary naming the game, seed and label. A session and a `bin/playtest-replay` probe hold the same two names, which is what lets `bin/playtest-measure` read either |
| `.context/playtest/<label>/<probe>/branch-NNN.txt` | no | turns a `rewind` wrote out of the transcript. Really played, so they count toward coverage; not canonical, so the reproducer beside them does not produce them |
| `.context/playtest/.replays/<probe>/` | no | one sessionless `replay` — the same `commands.txt` and `transcript.txt`, plus a `summary.txt` naming the seed. The leading dot reserves it: no tester label can start with one |
| `<probe>/saves-in/` | no | the `.gnusto` slots a **staged** probe was run against, copied in beside its transcript. Present only when the run passed `savesFrom` / `--saves-from`, and the reason a staged finding still replays after its label is cleaned |
| `docs/games/<game>-playtest-<YYYY-MM-DD>.md` | **yes** | the round report below |
| `docs/games/<game>-playtest-ledger.md` | **yes** | append-only: every dedupe key ever seen, with its verdict |
| one GitHub issue | — | every confirmed class as a checklist — see `issue-shape.md` |

What a reader needs in order to *judge* a finding goes in the report; what a fixer needs
in order to pick up one class goes in the issue. `issue-shape.md` owns the second.

**Cite the probe, never the label.** A label is a namespace holding every run a tester
made; the probe directory under it is one run, written once and never rewritten. So a
citation is `.context/playtest/<label>/probe-004/transcript.txt` — the path the tool
printed — and a citation ending at the label points at a directory, not at evidence.

**A staged probe is weaker evidence, and the citation has to say so.** Most probes
reproduce from `commands.txt` and a seed alone. One whose list begins `restore` does
not: it reproduces only while the slots it was staged from survive. So cite the source
with it — the label from the finding's `savesFrom`, and the `saves-in/` directory in the
probe, which holds the same bytes and is the one that still exists after the round's
labels are cleaned. `bin/playtest-replay --saves-from` and the `replay` tool's
`savesFrom` both take either spelling. A staged probe cited as though it were an
ordinary one claims the stronger thing, and the next reader finds out the hard way.

**A frame read from `replay` is citable too, and citing it is not optional.** Every
`replay` call now answers with `transcript=<path>` on its first line and writes that
file. Before it did, the 2026-08-17 round produced a report asserting an ending branch
that appears in **no file in the tree**, and three charters whose load-bearing frames
came from free replays nobody could re-read. If you read a line off a replay and quote
it, quote the path with it; a claim whose only witness was a tool result that scrolled
past is a claim the next reader cannot check.

The report is committed even when the round found nothing. "We ran and found
nothing" is the single most useful thing to be able to prove six months later, and
it is the only way the harness can be caught grading itself generously.

The ledger is the loop's memory. Refuted keys suppress re-finding, so the loop
doesn't rediscover its own rejections forever. A key marked `fixed` that reappears
is not a new finding — it is a **regression**, and it goes back at raised severity.

**Write every key in full.** A key is matched against `normalize()`, which emits nothing
but `[a-z0-9 ]`, so a key stored with an ellipsis in it can never equal one a round
produces — it is inert, and a file full of them reads exactly like a game nothing has
ever been refuted about. Three ledgers were written that way from their first round, so
every round since was handed nothing; `bin/playtest-preflight`'s `ledger` row and
`playtest.dryrun.mjs` both fail on it now rather than reporting zero.
Prefer `decl::<file>::<declaration>`, which is short enough that abbreviating it never
tempts anybody.

A ledger section's preamble names the one issue its `confirmed` rows were filed as, so
a key traces to a ticket without a column per row: *"Every `confirmed` row is an open
defect in the game as it ships, filed as #<N>."* Which is why the ledger is appended
after the issue is filed, not before.

## Sections, in order

1. **Header** — game, commit, seed, date, charters run, **which oracle tiers were
   available**, and turns planned versus spent. The tier list is what tells a reader
   how blind the round was; a round with no design doc is a legitimate round, but a
   round with no design doc that reads as though it had one is not.
2. **The round** — the closing note, in the shape of the commit messages these fixes
   used to land as. A lead sentence naming the class, then one bullet per defect,
   each **defect → frame → cause**, in that order, with the cause naming the missing
   branch. Where a defect was introduced by an earlier fix, the lead sentence says
   so.
3. **Filed** — the round's one issue, named once, then the classes inside it. Every
   confirmed finding is filed: a round finds and files, and nothing in it edits the
   tree. Each entry carries an `ownerClass`, which labels the row with its owner and
   decides nothing.
4. **Routed elsewhere** — one entry per open issue the round forwarded symptoms to,
   with counts, plus anything promoted *out* of a bucket and the argument for it. Omit
   the section when the round routed nothing, which is the common case. An issue that
   has since closed does not belong here at all: its symptoms are regressions, and
   they go under *Fixed* or *Filed*.
5. **Refuted** — the claim *and* the refutation. This section is how the verifier
   gets audited. A round with an empty refuted list either got lucky or isn't
   really refuting. It also carries the **rater-independence audit**: quote at
   least one finding both raters judged the same way, its `raterViews` in full —
   each rater's own `attemptedRefutation`, side by side — and say whether they
   read as separately reasoned or interchangeable. The script writes nothing to
   disk, so if the report does not carry the rationales they exist nowhere
   afterwards, and the agreement percentage has to be taken on trust. The
   2026-08-18 Dungeon round had to judge independence off
   `commands.effective.txt` byte-comparisons for exactly that reason.
6. **Coverage** — the load-bearing section. See below.
7. **Hygiene** — the seed, the turn budget, and any charter that did not run. A round
   that changes nothing has no test count or diff stat to report.

## Coverage is the section that keeps the report honest

Every blank cell is a place a defect could be sitting. A report that omits the grid
reads as "we covered everything" when it covered eleven cells of thirty-six.

Four things, none of them optional:

- **Which charters found nothing, and why.** "Not run — budget" and "run, found
  nothing in its own class" are very different results and must not look the same.
- **Rooms entered *and* rooms worked, each as a count and a list, with the
  never-entered ones named.** Both come from `coverage.rooms`, and both are **read
  off the `closing.json` each session wrote at `finish`**, never from what a tester
  said: `visited` is the union of every session's `roomsVisited`, `worked` the union
  of every session's `roomsWorked`, `neverVisited` and `neverWorked` the roster minus
  each, rendered `Name (id)`, and `offRoster` a room id the roster does not hold.
  Both sides are room **ids**, because a display name is prose and two rooms may
  share one — so an `offRoster` entry no longer means somebody retyped a name, it
  means the artifacts and the roster describe different builds, and that is worth a
  sentence of its own. `total` is **every declared room**, `ruleEntered` of them
  reachable only through a rule rather than an exit: a balloon flight or a trapdoor
  lands the player in a room the static exit table does not point at, and scoring
  those out of the roster reported the same rooms as simultaneously off-roster and
  never-entered. The gap that used to
  live in this bullet is now `coverage.sessionsUnfinished` — a probe holding a
  transcript with no closing record beside it, which is a session that played and
  left no account of itself. **Name those.** A coverage figure computed without them
  is a floor and has to say so. The 2026-08-11 Dungeon round published "112 of 195"
  against a real 155 because this number used to be asked rather than counted.
- **Turns, from `coverage.turns`, and never from what anybody said they spent.**
  `sessions` (the testers' transcripts), `branches` (turns a `rewind` wrote out of a
  transcript — really played, so really counted), `replays` (the `.replays/` tree —
  **the testers'**, because `replay` is an MCP tool and only a live play session can
  call it), `playReplays` and `verifyReplays` (`bin/playtest-replay` under a play or a
  verify label), `harnessReplays` (the round's own errands, under every other label),
  and `total`. Report the total and the tester/verifier split; a round whose verifiers
  outspend its testers many times over played less than it argued, and that belongs in
  the coverage section rather than being averaged away. The 2026-08-17 round published
  295 against artifacts holding about 1,493, because this number used to be asked; the
  2026-08-24 round reported 3:1 verifier-to-tester against a real 1.2:1, because
  `replays` was added to the wrong side.
- **Entered is not covered, and the two must not be one number.** A room the harness
  only walked through while replaying a committed route from
  `.context/playtest/routes/` is reach, not coverage — 21 of Dungeon's were exactly
  that, and the rule is **count them blank**. `coverage.rooms.worked` is the engine's
  own attempt at that line and an upper bound on it: it counts a room a session typed
  a non-travel, non-meta command in, which a route file's own `take lamp` also
  satisfies. The grid is where the distinction really lives: `X` for a room a charter
  typed its own commands in, `.` for one it only passed through, `-` for never
  reached. Where the grid and `worked` disagree, the grid wins and the gap is worth
  naming.
- **The state cross-product as an actual grid** — hours × rooms, or events × rooms.
  Ticks and blanks.
- **Findings dropped, and why** — unverified for budget, or not reproducible. A
  dropped finding is carried into the next round's dedupe set and is **not** counted
  as covered.

## Worked example

```markdown
# Fulminate — playtest round, 2026-07-29

Commit `3fab729` · seed `0` · charters: tourist, clock-watcher, vandal, re-reader
Oracle tiers: T0 kernel, T1 design doc (contract + timeline + solution), T2
FulminateTests, T3 source. Budget: 190 turns planned; 174 counted off the footers
(151 in transcripts, 23 in rewound branches) plus 402 in 31 verifier replay probes.

## The round

Same class throughout: prose that isn't true of where the player is standing, or of
when they're standing there. All four predate this branch.

- **Mrs. Vane is listed "in her chair with the lamp unlit" while she is standing in
  the back garden.** *Frame:* Back Yard, 5:50, turn 10, after the blast, on the turn
  after her arrival line was spent. *Cause:* her room-listing line is a static
  `firstSight` on an actor, and per K1 an actor's listing line prints on every look
  forever — it has no way to know she spends six minutes of the evening out of that
  chair. The fix deletes the trait and adds a `presence` rule keyed on her location.
- **Mrs. Kettle is "the only person here who has looked at the wreckage" sixteen
  minutes before there is a wreckage.** *Frame:* Kitchen, 5:30, turn 2. *Cause:* a
  static `description` asserting a post-blast fact. `describe { }` keyed on whether
  the blast has happened is the channel that can tell the truth here.
- **`get pike` answers "The Dr. Pike would take exception to that."** *Frame:* any
  room with him in it, all evening. *Cause:* the game re-skins ten actor-directed
  stock lines and `cantTakeActor` is not one of them, so the stock line puts a
  definite article in front of a proper name. A sweep of the actor-directed keys says
  this is the only one still missing.

## Filed

Three findings, deduplicating to two classes. Filed as #80.

| Class | Severity | Owner | Site |
|---|---|---|---|
| `cantTakeActor` not re-skinned | major | `game` | `Sources/Fulminate/Fulminate.swift` `text` block |
| Mrs. Vane's location-blind listing line | major | `game` | `Sources/Fulminate/Cast.swift` |

`ownerClass` is one of `game`, `engine`, `harness` or `unknown`. It says who owns the
site, not what should happen next — a round files everything and fixes nothing.
`unknown` means no rule recognised the `ownerFile`, which usually means the tester
invented or misspelled it; correct it in the finding rather than explaining it away
here.

## Routed elsewhere

- **#nnn** — 24 distinct unknown words, 61 occurrences: `attack break burn climb dig
  eat hit jump kick kiss knock listen pray pull ring shout sing sleep smell swim
  taste throw touch yell`. One aggregated comment; dropped from the fix stage.
  Promoted **out** of the bucket: `tile` — the Front Hall's own description prints
  "black and white tile, worn through to the grout", so the game invited the word and
  must answer it.

  (Illustrative. This round routed nothing, because no open issue owned a class.)

## Refuted

| # | Charter | Claim | Refutation |
|---|---|---|---|
| F-0008 | re-reader | Mrs. Vane's listing line prints on every `look` — a stuck record | K1: an actor's presence line prints on every look, forever, by design. F-0002 is the real defect at this site. |
| F-0013 | vandal | Mrs. Vane refuses to light the parlour lamp | Characterization — the room description says her opinion of when it is properly dark differs from everyone else's. |

## Coverage

**Charters** — *solver* not run (budget): the winning route is unverified at this
commit. *interrogator* not run (budget). *idiot* run, 3 findings, all routed.

**Rooms** — 8 of 9. Never visited: **Boarder's Room**. Off-map by design: Orange
Grove Avenue.

**Hour × room** — 14 of 19 Timeline rows probed on-cell. Unprobed: 6:10, 6:14, 6:20,
6:30, 6:50. Everything after 6:14 is unexamined; the third alarm and the ending are
unexercised.

**Event × room** — 4 events × 9 rooms = 36 cells; 11 run.

| | Hall | Parlour | Kitchen | Cellar | Yard | Carriage | Landing | Study | Boarder's |
|---|---|---|---|---|---|---|---|---|---|
| blast 5:46 | ✓ | ✓ | ✓ | — | ✓ | ✓ | — | — | — |
| radio car 5:52 | ✓ | — | — | — | ✓ | ✓ | — | — | — |
| telephone 6:20 | — | — | — | — | — | — | — | — | — |
| coroner 6:50 | — | — | — | — | — | — | — | — | — |

**Dropped** — 2 unverified on budget (F-0021 "grout", F-0022 register on the hat
stand); both carried to the next round's dedupe set, neither counted as covered. 0
dropped as non-reproducible.

## Hygiene

- `swift test` — 783 tests, 0 failures.
- Strict lint — clean.
- Test files +38 / −0 lines. No assertion removed, no needle weakened.
```
