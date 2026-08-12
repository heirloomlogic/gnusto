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
| `focus` | none | The coverage split, in your words, handed to every agent that judges prose. Free text: say which charter takes which region, and how it gets there. See below. |
| `verifyEffort` | inherit | Reasoning effort for the verifiers — the round's largest fan-out, and so its cost. Turn it down to buy a bigger round; read the warning below first. |
| `fix` | `"none"` | `none` files everything, in the round's one issue. `game` also fixes findings owned by the game's own files. `all` fixes engine findings too. No setting touches the harness's own files. |
| `rounds` / `dryRounds` | `1` / `2` | Loop until N consecutive rounds surface nothing new. |
| `packagePath` | `"."` | Drive another checkout — a worktree at an older commit, for calibration. |
| `ledgerKeys` | `[]` | Keys from previous reports, so the loop doesn't re-find its own rejections. |
| `routedIssues` | `[]` | `[{number, owns}]` for open issues that own a defect class. Derive it fresh — see above. |

**`fix` defaults to `none`, and the fix phase is experimental.** Fixing is where the
harness stops being safe: the failure mode isn't a crash, it's a *plausible* wrong fix
in a densely prose-coupled suite. Run a round with `fix: "none"`, read the findings
yourself, then decide.

Three overrides ignore the flag entirely. No design doc means no prose fixing. A fix
that would change a count or structure pinned by a mechanics contract is escalated to
a human, never applied — the gate checks that independently, because a prohibition only
the offender checks is not a prohibition. And **the harness does not repair itself
mid-round**: a finding whose `ownerClass` is `harness` is filed at every setting,
because a fixer editing the workflow that is currently running it, or the briefs its
sibling agents are still reading, changes the run underneath itself.

Every finding the round files carries a `notFixedReason`, and the workflow logs the
breakdown whether or not anything was fixable — including the round where nothing was.
`references/report-shape.md` defines the reasons.

**`focus` is how a game bigger than one round gets a split instead of an accident.** Six
charters all start where the player starts. On a nine-room game that costs nothing; on a
196-room one they spend the budget walking in, and the coverage grid then reports
wherever they happened to wash up. Name the regions, hand each charter one, and say **how
it gets there** — a game whose far side is two hundred correct commands from the front
door needs a route prefix, and the pinned seed the route was proven under, or the prefix
lands somewhere else. It reaches the verifiers too, who have to replay the same
reproducers.

Free text, not a region schema, because what a split has to say differs per game: a
route prefix in one, an hour of the evening in another. `docs/games/dungeon-playtest-2026-08-11.md`
is the worked example — eight regions over six charters, each with the walkthrough stage
that reaches it.

**`verifyEffort` is the cost dial, and it is sharp.** The verifiers are one agent per
fresh finding, so on a round that finds sixty they are most of the bill. But they are
also the layer whose failure is invisible: a fixer misled by a bad finding damages prose
that was right, which is loud, while a refuter that rejects *good* findings produces a
thin round that reads as a clean one. Turn it down to afford more charters or more turns,
and say in the report's header that you did. **Both censuses** — unknown words and rooms
— are on Haiku permanently and need no flag: each runs one `grep` and counts, and there
is no judgement in either to lose.

**Anything the report states as a number is counted, not asked.** Both censuses exist
because the same mistake happened twice: the 2026-07-31 round self-reported 2 unknown-word
replies against transcripts holding 261, and the 2026-08-11 round self-reported 112 of 195
rooms against a real 155. Neither was a tester lying — a field description is read
seventy-nine different ways by seventy-nine agents, and a derived number does not depend
on that. The pattern to copy when adding the third: a hardcoded command, a strict schema
with a `note` for the empty case, started early and awaited late so it overlaps the gate,
and **the self-report kept beside the count rather than replaced by it**, so a reader can
see the two disagree.

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
