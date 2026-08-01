# The round report

Two committed artifacts per round, one tracker entry, and a scratch directory that
isn't committed.

| Path | Committed | Contents |
|---|---|---|
| `.context/playtest/<label>/<probe>/` | no | one run: its transcript with the `//` annotations, its effective command list, its stderr, and a summary naming the game, seed and label |
| `docs/games/<game>-playtest-<YYYY-MM-DD>.md` | **yes** | the round report below |
| `docs/games/<game>-playtest-ledger.md` | **yes** | append-only: every dedupe key ever seen, with its verdict |
| one GitHub issue | — | every confirmed class as a checklist — see `issue-shape.md` |

What a reader needs in order to *judge* a finding goes in the report; what a fixer needs
in order to pick up one class goes in the issue. `issue-shape.md` owns the second.

**Cite the probe, never the label.** A label is a namespace holding every run a tester
made; the probe directory under it is one run, written once and never rewritten. So a
citation is `.context/playtest/<label>/probe-004/transcript.txt` — the path the tool
printed — and a citation ending at the label points at a directory, not at evidence.

The report is committed even when the round found nothing. "We ran and found
nothing" is the single most useful thing to be able to prove six months later, and
it is the only way the harness can be caught grading itself generously.

The ledger is the loop's memory. Refuted keys suppress re-finding, so the loop
doesn't rediscover its own rejections forever. A key marked `fixed` that reappears
is not a new finding — it is a **regression**, and it goes back at raised severity.

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
3. **Fixed** — each with the test that fails without it.
4. **Filed, not fixed** — the round's one issue, named once, then the classes inside
   it and the reason each wasn't fixed. The workflow hands you the reason: every
   entry in the returned `filed` carries a `notFixedReason`, and `filedByReason`
   totals them. Elaborate on it in the operator's words; don't reconstruct it.
5. **Routed elsewhere** — one entry per open issue the round forwarded symptoms to,
   with counts, plus anything promoted *out* of a bucket and the argument for it. Omit
   the section when the round routed nothing, which is the common case. An issue that
   has since closed does not belong here at all: its symptoms are regressions, and
   they go under *Fixed* or *Filed*.
6. **Refuted** — the claim *and* the refutation. This section is how the verifier
   gets audited. A round with an empty refuted list either got lucky or isn't
   really refuting.
7. **Coverage** — the load-bearing section. See below.
8. **Hygiene** — test count, lint result, and the diff stat for test files, with an
   explicit statement that no assertion was removed.

## Coverage is the section that keeps the report honest

Every blank cell is a place a defect could be sitting. A report that omits the grid
reads as "we covered everything" when it covered eleven cells of thirty-six.

Four things, none of them optional:

- **Which charters found nothing, and why.** "Not run — budget" and "run, found
  nothing in its own class" are very different results and must not look the same.
- **Rooms visited, as a count and a list, with the never-visited ones named.**
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
FulminateTests, T3 source. Budget: 190 turns planned, 174 spent over 31 probes.

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

## Fixed

| # | Finding | Site | Test that fails without the fix |
|---|---|---|---|
| F-0003 | `cantTakeActor` not re-skinned | `Sources/Fulminate/Fulminate.swift` `text` block | `actorLinesAreAllInTheGamesOwnVoice` |

Doc changes in this commit: `docs/games/fulminate.md` — Cast copy for Mrs. Kettle.

## Filed, not fixed

Two findings, deduplicating to one class. Filed as #80.

| Class | Severity | Why not fixed here |
|---|---|---|
| Mrs. Vane's location-blind listing line | major | `needs-human` — more than one reasonable design. |

The right-hand column starts from the finding's `notFixedReason`:

| Reason | Means |
|---|---|
| `needs-human` | The verifier confirmed it and declined to let a fixer near the design. |
| `harness` | Owned by the harness, which does not repair itself mid-round. |
| `out-of-mode` | The `fix` setting this round didn't reach its owner class. |
| `unclassified` | Nothing recognised the `ownerFile` — usually the tester invented or misspelled it, and worth correcting in the finding rather than explaining away here. |

## Routed elsewhere

- **#nnn** — 24 distinct unknown words, 61 occurrences: `attack break burn climb dig
  eat hit jump kick kiss knock listen pray pull ring shout sing sleep smell swim
  taste throw touch yell`. One aggregated comment; dropped from the fix stage.
  Promoted **out** of the bucket: `tile` — the Front Hall's own description prints
  "black and white tile, worn through to the grout", so the game invited the word (K8).

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
