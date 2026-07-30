# Fulminate — playtest calibration, 2026-07-29

The first round the harness ever ran. Its purpose is not to fix Fulminate — it is to
answer one question about the harness: **can it independently re-find what a human
found by reading prose?** A harness that can't is not worth running, and the only way
to know is to point it at a tree whose defects are already known.

So this is a graded exercise, not a maintenance round. `fix: "none"` throughout;
nothing here was applied to the game.

## Setup

| | |
|---|---|
| Trees | `3fab729` (before any playtest round), `c9d3cb5` (after the first round of fixes) |
| Seed | `0` |
| Oracle tiers | T0 kernel, T1 design doc, T2 `FulminateTests`, T3 source |
| Kernel read from | the current checkout — `CLAUDE.md` did not exist at some of these commits |

Neither commit is an ancestor of `main`; both are on the pre-squash `issue-72-topics`
branch. That is why the results are written down here rather than checked in CI, and
why this file is the durable record.

## Tree A — `3fab729`

Two passes. The first ran four charters cold. The second re-ran one charter after the
first pass exposed a flaw in its brief.

### Pass 1: 4 charters, 94 probes, 924 engine turns, 44 agents

| # | Answer-key defect | Result | Found by |
|---|---|---|---|
| A1 | `x tile` unanswerable while the Front Hall prints "worn through to the grout" | **found** | tourist *and* vandal, independently |
| A2 | `get pike` → "The Dr. Pike would take exception to that." | **MISSED** | — |
| A3 | Mrs. Kettle "has looked at the wreckage" before there is one | **found** | clock-watcher |
| A4 | "Mrs. Vane is in her chair with the lamp unlit" printed in the Back Yard | **found** | clock-watcher *and* tourist, independently |
| A5 | Dr. Pike "wearing his hat indoors" in the back garden | **found** | clock-watcher |

**4 of 5.** Findings: 43 raw → 18 confirmed, 9 needs-human, 11 refuted.

Two things worth more than the score.

**A1 landed on the right side of a tie-break that was designed for it.** The reply to
`x tile` is `I don't know the word "tile"`, which normally routes to #76 and out of the
round. It was correctly kept, because the game's own description printed the word — and
the verifier's reasoning quoted the brief's own worked example back at it. It then went
further than the tester had: near-miss controls (`x door`, `x tiles`, `x floor`,
`x half-moon table` all fail; `x clock` and `x coat` answer) to prove the room was in
scope and the words genuinely absent, and it *corrected the finding upward* — `hat`
appears in five sentences, not three, and `pad` belongs to a different owning text and
is strictly a second finding.

**A4's trap was sprung on purpose.** Mrs. Vane's *arrival* line prints on the turn she
arrives and masks the standing listing line, so a probe that looks on the arrival turn
sees correct prose and finds nothing. The charter brief says so, the clock-watcher
waited the extra turn, and the line appeared.

### Why A2 was missed, and the fix

The vandal never typed `get <actor>` at all. It filed ten findings, six of which were
confirmed — but not the two-command probe that is the highest-yield in the harness.

The charter brief was at fault, not the agent. It said to check whether the actors have
proper names and then "run the actor-directed verbs", leaving the agent to derive which
verbs mattered and against whom. It derived something else and went exploring.

The fix moves the derivation out of the prompt and into the script: the survey already
reports which stock keys the game re-skinned and which actors are proper-named, so
`articleSweep()` now subtracts one from the other and hands the vandal a literal,
numbered list of commands to run, marked mandatory and first. **Deriving a checklist is
where an agent gets lost; executing one is not.**

### Pass 2: vandal only, re-run against the same tree

| # | Result | Category |
|---|---|---|
| A2 | **found** | `stock-line-not-reskinned` — "`cantTakeActor` is not re-skinned, so the engine interpolates a definite article in front of every proper name" |

**Tree A: 5 of 5.** A1, A3, A4 and A5 were re-found in this pass too, so the fix cost
no coverage.

### A sixth defect, not in the key

The vandal also filed this, unprompted:

> `search clock` answers "You can't see any such thing." — the out-of-scope reply — for
> a longcase clock the room description names two lines above.

That is the substance of commit **`1460aad`, "Stop SEARCH denying that visible things
exist"**, which is not in the answer key and which no charter was told to look for.
Verified by hand:

```
3fab729:  > search clock   →  You can't see any such thing.
main:     > search clock   →  You find nothing of interest in the longcase clock.
```

The verifier's reasoning is the part worth keeping. It didn't argue from the prose; it
read the engine's own doc comments and found them contradicting the code —
`cantSeeAnySuchThing` is documented as "Known words that name nothing currently in
view", and `cantReach`'s comment says it is "distinct from `cantSeeAnySuchThing`, which
is for a noun that isn't in scope at all." Then it proved scope directly: `x clock`
answers "The clock says 5:30 pm", so the noun is unambiguously in view while `search
clock` denies it exists. It listed eleven more frames, including `search kettle`
denying the existence of a woman listed one line above, and flagged for the fixer that
the change would move every game's transcripts and that `CLAUDE.md` would need updating
with it.

Which is exactly what happened historically, and is also the reason `CLAUDE.md:97` was
stale until this branch corrected it.

The re-run also produced a finding *about the harness*: five of the six stock keys in
the sweep checklist don't exist at `3fab729`, and neither do the `greet` and `follow`
verbs — they arrived in `1460aad` and `3ec0521`, after this commit. Twelve of
thirty-six checklist rows were therefore vacuous. That is an anachronism, not a defect:
the briefs are accurate about the tree they ship with, which isn't this one. The
harness now says so out loud whenever `packagePath` isn't the current checkout, and
tells testers to note such rows as uncovered rather than file them.

## Tree C — `c9d3cb5`

The interesting tree, and the one a naive harness fails. `c9d3cb5` is a *fix* commit:
it repaired A4 by replacing the static listing line with a `presence` rule. The rule it
added keys on the blast alone — it knows *when* but not *where* — so the same class of
bug came straight back one branch shallower, and the human who wrote it noted as much:
*"One of them was mine."*

| # | Answer-key defect | Provenance |
|---|---|---|
| C1 | "looking at the fire" from Vane's Study at 6:02 and the bottom of the dark cellar at 6:26 | **introduced by `c9d3cb5`** |
| C3 | "the note in your ears steps down one" printed indoors, sixty feet and two walls away | **introduced by `c9d3cb5`** |
| C6 | A2's `get pike`, still present | preexisting |

### Result: 3 of 3, plus the dust line

2 charters, 48 probes, 551 engine turns, 21 agents. 17 raw findings → 11 confirmed,
2 needs-human, 4 refuted.

| # | Result |
|---|---|
| C1 | **found**, `presence-line-location-blind`, both frames |
| C3 | **found**, `prose-untrue-of-state` |
| C6 | **found**, `stock-line-not-reskinned` |
| — | **also found:** the dust "comes down the passage from the direction of the kitchen", printed *in* the kitchen, pointing at itself |

That last one is the "settles on the hall table" beat — the third defect acceptance
criterion 1 names, and the one that could not be found at `3fab729` because the fuse
did not exist there yet.

### The C1 writeup is the best evidence in this document

The verifier didn't argue from prose. It went to the code and found the fix's own
principle stated five lines above the rule that breaks it:

> The author's own comment on the sibling rule (`constance.presence`,
> `Fulminate.swift:1348-1356`) states the principle explicitly: *"Six minutes of her
> evening are spent out of that chair, and the presence line has to know it."*
> Constance's rule is keyed on `constance.isIn(parlour)`; Delphine's is keyed on
> `blastHappened` alone.

So `c9d3cb5` fixed A4 by writing a rule that knows *where*, wrote down why that
mattered, and then put a sibling rule next to it that knows only *when*. The verifier
also noticed the false line contradicts Delphine's own arrival line one turn earlier —
"starts on the desk drawers" against "on her feet with her arms at her sides" — and
declined to route it to a human, on the grounds that the in-file precedent two rules up
makes the fix unambiguous.

It then corrected the tester's reproducer: the cellar frame needs a *lit* flashlight,
because an unlit cellar prints nothing at all, so the 19-command study probe is joined
by a 31-command cellar probe. One defect, two confirmed frames, correctly deduplicated
to a single branch.

`git log -S 'looking at the fire' --oneline 23195d5 -- Sources/Fulminate/Fulminate.swift`
puts the sentence's arrival at `c9d3cb5`. **The defect was introduced by the fix.** That
is the capability the issue asked for, and the reason `provenance` is now a required
field on every verdict: the first two rounds established it by argument, and it should
not depend on a verifier thinking to check.

## What the completeness critic caught

The critic's job is to find what the round missed, and its most useful output was
aimed at the harness rather than the game. It read the 94 transcripts directly instead
of trusting the testers' self-reports, and caught the arithmetic flattering itself:

- **"Rooms: 13 of 9 visited"** — arithmetically impossible. Testers wrote "Landing"
  where the survey said "Upstairs Landing", so the union of raw strings overshot the
  denominator. Fixed: room names are now reconciled against the survey roster, and
  anything unmatched is reported as unmatched instead of inflating the numerator.
- **"Turns spent: 618 of ~180"** — the real figure from the transcripts was 924,
  because the denominator omitted the verifiers' own probes. Fixed: the number is now
  labelled as tester turns only, with the critic told to count the true total itself.
- **"Routed 0"** — false. 180 unknown-word replies over 56 distinct words sat in the
  transcripts, and reporting zero made a dropped bucket look like a clean sweep. Fixed:
  the bucket total is passed to the critic explicitly.

On the Tree C round it caught two more: the testers' turn count was low (304, not 282,
and 551 once verifier probes are counted — 6.9× the budget), and **`cellsProbed: 13`
"matches nothing I can construct."** That field is free text, so the labels aren't
comparable between charters and the count was never a coverage number. It is no longer
reported as one; the critic is told to build the cross-product from the transcripts
itself.

Its verdict on both rounds was **`round-is-thin`**, and on Tree A it was right:

> Ninety of ninety-four probes ended at or before 6:18. The game is eighty minutes
> long; this round is a thorough playtest of its first sixteen.

It also refused to let three unrun charters read as silence — "nothing in Fulminate was
found clean this round; everything not reported is unlooked-at, not acquitted" — and
noted that Julian, who is alive for eight turns and is a structural feature of the
design, received **zero commands in 94 probes**.

That is the section working as intended. A report that had simply listed 18 findings
and stopped would have read as a thorough audit of a game it had examined for sixteen
of eighty minutes.

## Assessment

| Criterion | Result |
|---|---|
| Re-finds what a human found | **yes** — Tree A 5/5 (after one charter fix), Tree C 3/3, plus two defects not in the key |
| Catches a defect a *fix* introduced | **yes** — C1, attributed to `c9d3cb5` from the sibling rule's own comment |
| Findings carry replayable reproducers | yes — 1 to 31 commands, every one re-verified from clean by a second agent, twice corrected upward |
| Verifier genuinely refutes | yes — 15 refuted and 11 escalated to `needs-human` across both rounds, on grounds including "licensed by the design doc", "required by the contract" and "misquoted prose" |
| False-positive rate | within bar, but see below |
| A clean round reports empty, not plausible | **not demonstrated** — needs a round on current `main` |
| The fix phase works | **not demonstrated** — never exercised; `fix` stays `none` by default for this reason |

Totals across both trees: 3 rounds, 76 agents, 4.3M subagent tokens, ~1,500 engine
turns, 167 probes. All three answer keys passed. Eight of nine defects the harness
confirmed against the keys were found by a charter reading prose; the ninth (A2)
required fixing the charter first, which is what a calibration is for.

**On false positives.** Nine findings came back `needs-human` rather than confirmed,
which is the verifier declining to certify a judgement call — the right answer, and the
reason the fix phase stays opt-in. Of the 18 confirmed, the ones outside the answer key
are mostly real and mostly *new*: unanswerable nouns across five more rooms, departure
lines printed to rooms the actor was not leaving, an alarm that reports on a wreckage
the player can be standing in. None were plainly wrong. But 18 confirmed against a
5-item key means most of what the harness reports is not gradeable against a human
baseline, and that is the honest limit of this exercise.

**What this does not show.** The fix phase was never exercised. No round has been run
against current `main`, so acceptance criterion 6 — a clean tree produces an empty
report rather than a plausible one — is untested. Three of seven charters never ran.
The interrogator in particular is the largest hole: conversation *is* Fulminate's
subject, and 3 of its 26 authored reply texts ever printed.
