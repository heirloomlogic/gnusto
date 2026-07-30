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
