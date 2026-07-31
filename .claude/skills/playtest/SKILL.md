---
name: playtest
description: Run an automated play-test round against a Gnusto demo game — Claude subagents play it, read the transcripts as prose, and report lines that are not true of the frame they printed in. Use when asked to playtest, play-test, or find prose defects in a game (Fulminate, Lighthouse, Gramarye, Zork1, CloakOfDarkness); when asked to check whether a game's writing is true of where the player is standing; or after changing a game's copy, timers, or actor scheduling. Also use to reproduce a reported transcript defect, or to calibrate the harness against a historical commit.
---

# Play-testing a Gnusto game

Several Claude subagents play a demo game, read the transcripts as prose, and report
sentences that are not true of the frame they printed in — the defect class a
transcript test structurally cannot catch, because it asserts a line *appears* and
never asks whether it is *true*.

`references/playtester-brief.md` is the doctrine and the judgement kernel; every
tester reads it. This file is the operator's recipe for starting a round.

## Run a round

```sh
bin/playtest-replay --build <Game>        # once, before dispatch
```

Then work out the arguments and invoke the workflow **by path**:

```
Workflow({ scriptPath: ".claude/workflows/playtest.js", args: {
  game: "Fulminate",
  packagePath: ".",
  docPath: "docs/games/fulminate.md",   // null when the game has no design doc
  capabilities: ["clock", "talk"],
  seed: 0,
  turns: 60,
  fix: "none"
}})
```

`scriptPath` rather than `{name: "playtest"}` because the workflow registry is read
when the session starts: a checkout that gained `.claude/workflows/` after the session
began won't resolve the name, and the failure mode is a confusing "not found" rather
than anything informative. The path always works. `{name: "playtest"}` is equivalent
once a session has picked the file up.

**Work out `capabilities` from the manifest, not from a list in this file** — there is
deliberately no per-game config. `swift package describe` or `Package.swift` shows
what a game depends on: `GnustoClock` → `clock`, `GnustoConversation` → `talk`,
`GnustoScoring` → `score`, `GnustoSpellcasting` → `magic`. Charters filter themselves
on that, so a game with no clock gets no clock-watcher.

**`docPath` is `docs/games/<game>.md` if it exists and `null` if it doesn't.** Check
with `ls docs/games/`; don't work from a list, here or anywhere. A missing doc doesn't
stop the round finding defects; it stops it *fixing* prose, because the repo makes the
design doc the copy source of truth.

Pass the doc **even for a `fix: "none"` round**. It changes what the verifiers can
argue: with a contract they refute on "the doc licenses this", and without one they
fall back to "you cannot tell intent from outside, so a preference is refuted", which
rejects good findings along with bad. See the Refuted section of
`docs/games/gramarye-playtest-2026-07-30.md` for what that looked like in practice.

**Derive `routedIssues` fresh, every round, from the issues that are open right now:**

```sh
gh issue list --state open --label enhancement --json number,title
```

Pass `[{number, owns}]` for any that own a defect class the round should forward
rather than judge — an engine gap with a ticket already on it. Pass nothing when none
do, which is the current state and the safe default.

Do not hardcode this. The harness shipped with #76, #77 and #78 baked in; all three
were fixed within days, and until the list was corrected the briefs were telling
testers to forward the exact symptoms that had just become regressions. A stale
"already owned" rule doesn't produce a bad finding a verifier can catch — it produces
silence.

## Afterwards

Three artifacts, in this order — the ledger's preamble names the issue, so it goes last:

1. the round report, `docs/games/<game>-playtest-<YYYY-MM-DD>.md`
2. **exactly one issue** for the round
3. every dedupe key, appended to `docs/games/<game>-playtest-ledger.md`

`references/report-shape.md` has the two files, `references/issue-shape.md` the issue.
Commit the report even when the round found nothing — a provable empty round is the
point — but a round that confirmed nothing files no issue.

**One issue per round, per game, holding every class as a checklist** — not one per
class, not a separate one for the engine's share. 2026-07-30 filed thirteen in a day;
`issue-shape.md` has the shape and the round that made the rule necessary. Not
`routedIssues`, which runs the other way: those are open issues that *receive*
forwarded symptoms.

The title is the key, so search before you create:

```sh
gh issue list --state all --search "<Game>: play-test round <YYYY-MM-DD>"
```

A second filing should collide the way a second report would, rather than resting on
whoever remembered the rule.

## Options

| Argument | Default | Notes |
|---|---|---|
| `seed` | `0` | Pins the stream via `GNUSTO_SEED`. Record it; a finding without a seed isn't reproducible. |
| `turns` | `60` | Engine turns per charter. Token cost, not CPU cost, is the real budget. |
| `charters` | all applicable | Comma-separated subset, e.g. `"tourist,clock-watcher"`. |
| `fix` | `"none"` | `none` files everything, in the round's one issue. `game` also fixes findings owned by the game's own files. `all` fixes engine findings too. |
| `rounds` / `dryRounds` | `1` / `2` | Loop until N consecutive rounds surface nothing new. |
| `packagePath` | `"."` | Drive another checkout — a worktree at an older commit, for calibration. |
| `ledgerKeys` | `[]` | Keys from previous reports, so the loop doesn't re-find its own rejections. |
| `routedIssues` | `[]` | `[{number, owns}]` for open issues that own a defect class. Derive it fresh — see above. |

**`fix` defaults to `none`, and the fix phase is experimental.** Fixing is where the
harness stops being safe: the failure mode isn't a crash, it's a *plausible* wrong fix
in a densely prose-coupled suite. Run a round with `fix: "none"`, read the findings
yourself, then decide.

Two overrides ignore the flag entirely. No design doc means no prose fixing. And a fix
that would change a count or structure pinned by a mechanics contract is escalated to
a human, never applied — the gate checks that independently, because a prohibition only
the offender checks is not a prohibition.

## What lives where

```
.claude/workflows/playtest.js          the orchestration
.claude/skills/playtest/
  SKILL.md                             this file
  references/
    playtester-brief.md                the doctrine + judgement kernel K1..K13
    finding-contract.md                what a finding must carry
    fixer-brief.md                     the rules a fixer is bound by
    report-shape.md                    the round report and the ledger
    issue-shape.md                     the one issue a round files
bin/playtest-replay                    the replay helper
docs/playtesting.md                    driving it by hand, without any of this
```

The split rule: **if changing it changes the shape of the run, it goes in the JS; if
changing it changes what an agent believes, it goes in `references/`.** So charters and
schemas sit inline next to the fan-out that consumes them, and the doctrine repeated
across every prompt lives in markdown a writer can edit without touching code.

## Calibrating

A harness that can't re-find what a human already found isn't worth running. To check
it, point it at a tree whose defects are known:

```sh
git worktree add /tmp/gnusto-cal 3fab729
bin/playtest-replay --build Fulminate --package-path /tmp/gnusto-cal
# then dispatch with packagePath: "/tmp/gnusto-cal"
```

The briefs are read from the *current* checkout while the binary comes from the old
one, so the harness warns testers that engine facts may be anachronistic. Calibration
is a **multi-tree** exercise — the three defects usually cited don't co-exist in any
single commit. `docs/playtesting.md` has the per-tree answer key and the reasoning;
`docs/games/fulminate-playtest-2026-07-29.md` has the last run's scores.
