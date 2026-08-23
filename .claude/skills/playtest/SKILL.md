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

Testers play through the game's own MCP server, registered per game in `.mcp.json`, so
a round needs no build step of its own beyond the one below. The blind charters get a
live coverage queue instead of a map: what the game has shown them and they have not
followed up, every item a command to paste.

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
  turns: 60
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
with `ls docs/games/`; don't work from a list, here or anywhere.

Pass the doc whenever there is one. It changes what the verifiers can
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
| `focus` | none | The coverage split, as **one string** with regions separated by `\|` — an array is silently read as a single region. Each region becomes one `explorer` *and* one `timekeeper`, up to three of each; the explorers are handed different divergence policies. Say how each region is reached, and **name no room**. See below. |
| `verifyEffort` | inherit | Reasoning effort for the verifiers — the round's largest fan-out, and so its cost. Turn it down to buy a bigger round; read the warning below first. |
| `rounds` / `dryRounds` | `1` / `2` | Loop until N consecutive rounds surface nothing new. |
| `packagePath` | `"."` | Drive another checkout — a worktree at an older commit, for calibration. |
| `ledgerKeys` | `[]` | Keys from previous reports, so the loop doesn't re-find its own rejections. |
| `routedIssues` | `[]` | `[{number, owns}]` for open issues that own a defect class. Derive it fresh — see above. |

**A round finds and files; it does not fix.** The fix phase is gone, and with it the
gate that existed to check the fixers. Fixing was where the harness stopped being
safe: the failure mode was never a crash, it was a *plausible* wrong fix in a densely
prose-coupled suite, applied by an agent that had read the finding and not the game.
Read the round's issue, then fix by hand — `references/fixer-brief.md` is still the
rules that bind whoever does, and it now binds a person.

Every confirmed finding still carries an `ownerClass`, because the issue checklist
labels each row with its owner. It classifies and no longer decides anything.

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

**Name no room.** A region is pasted verbatim into a blind explorer's prompt, and the room
roster is the answer key that charter exists to reconstruct. The dry run now fails on a
roster name in a blind prompt — but it matches whole names, so it catches the copy-paste
version and not an operator who writes "Landing" for "Upstairs Landing". The rule is
yours to keep.

**Space is still expressible — say the affordance, not the roster.** This reads like a
rule against splitting a small game by place, and it is not. The game's own opening prints
its exits: Fulminate's first paragraph says *"the stairs go up"*, so **"the floor above"**
leaks nothing the player has not already been handed, exactly as an hour leaks nothing the
watch does not. "Below the ground floor", "outside the house", "as deep as you can get"
are all fair. `Vane's Study` is not.

Getting this wrong costs a whole axis. Fulminate's 2026-08-17 round split by clock alone,
on the reasoning that a nine-room game's map cannot be named — and left the vertical axis
owned by nobody. Both of the two scheduled arrival lines that printed in *zero* transcripts
were upstairs, and so were both `talk.shows` rows that never fired, including the one the
round was dispatched to reach. A 26-turn probe of `up`, `west`, `z`×24 filled five blank
cells afterwards. It was not expensive; it was unassigned.

**A region is an assignment, so give every seat one.** The sighted charters are told to
*"Find your own charter in it and treat that row as your assignment"* — so a `focus` with
no charter rows in it assigns nothing, and the charter falls back to instinct. In that same
round the timekeeper owned the whole cross-product, read two unlabelled time windows, and
spent three quarters of its probes on the first one. `explorer` and `timekeeper` both
instantiate per region now, so the number of regions you declare is the number of copies
of each you get, capped at three.

**`verifyEffort` is the cost dial, and it is sharp.** The verifiers are the round's
largest fan-out — two independent raters over each batch of 25 findings — so they set its
cost. They are also the layer whose failure is invisible: a fixer misled by a bad finding
damages prose that was right, which is loud, while a refuter that rejects *good* findings
produces a thin round that reads as a clean one. Turn it down to afford more charters or
more turns, and say in the report's header that you did. The **collator** is on Haiku
permanently and needs no flag: it reads files and adds up integers, and there is no
judgement in it to lose.

**Anything the report states as a number is counted, not asked.** The rule exists because
the same mistake happened three times: the 2026-07-31 round self-reported 2 unknown-word
replies against transcripts holding 261, the 2026-08-11 round self-reported 112 of 195
rooms against a real 155, and the 2026-08-17 round reported 295 turns spent — exactly the
sum of six testers' self-reports — against artifacts holding about 1,493. None of them was
a tester lying; a field description is read seventy-nine different ways by seventy-nine
agents, and a derived number does not depend on that.

The first two now come from `closing.json`, which the session server writes at `finish` out
of the status line and the parser's own record of tokens it could not consume. **The rooms
are recorded by `EntityID`, and the roster they are scored against is copied out of the
`survey` tool rather than transcribed by the cartographer** — one key space on both sides,
because a display name cannot be a key. Dungeon declares 143 rooms under 126 distinct
`name(…)` strings, seven of them "Coal Mine", so the 2026-08-18 round's "119 of 195 rooms
visited" was a fraction whose numerator and denominator could not meet: a tester who
walked all seven Coal Mines contributed one, and seventeen rooms were uncountable
however carefully the two sides were matched. That file
also carries `firedTimers`, the engine's count of every fuse and daemon body that actually
ran — which is what lets the round name a timer that was **declared and never fired in any
session**. Nothing else can: a timer whose body only sets a flag prints nothing, so silence
in a transcript is not evidence either way, and the 2026-08-18 round needed a completeness
critic with two hand-built controls to settle it for six of Dungeon's thirty-five. The third is
counted off the `[status]` footers: every footer says `turn=cost` or `turn=free`, so the
round greps for the first across four places — the testers' transcripts, the `branch-NNN.txt`
files a rewind wrote off, the probes under `.context/playtest/.replays/` that the server's
own `replay` tool writes, and the `bin/playtest-replay` probes under the round's `-play-` and
`-verify-` labels. The collator does all of it; nobody is asked how far they got.

The last of those four is the newest and was the largest. `bin/playtest-replay` wrote no
footers until #288, so its transcripts held no `turn=cost` to grep and its labels matched no
glob — two independent exclusions, and the 2026-08-18 round's own completeness critic caught
one of them. It reported 11,238 turns over artifacts holding 32,987 further typed commands.

There is a fifth grep now, with no glob in it at all: every `turn=cost` under
`.context/playtest`. It is not added to the total — it is *differenced* against it, and the
critic is handed the residual. A sum over an enumerated list of globs has been short three
times running and each time reported a plausible number and waited a round; a residual is
how the next uncounted tree says so on the round it appears in rather than the one after.

Two lessons worth carrying, because the third instance taught them and the first two
didn't. **A number cannot be counted until something writes the thing down** — turns
stayed a self-report for as long as it did because `replay` wrote no file, so a verifier's
turns existed nowhere to be counted. And **a rewind is not an erasure**: a room worked for
ten turns and then rewound out was still worked, so the coverage arithmetic reads the
branch files too.

**The pattern to copy for the next number: have the engine write it down, then glob for the
file.** An agent grepping transcripts for the engine's own prose is the second-best version
of this and goes wrong the moment a game re-voices the line — grepping for the *footer*,
which the harness writes and no game can re-voice, is the acceptable middle.

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
.claude/workflows/playtest.dryrun.mjs  zero-agent dry run — a CI gate, not a suggestion
bin/playtest-measure                   how curiously a session played, off its artifacts
bin/gnusto-mcp, .mcp.json              every game as a live play-test server
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

## Before you dispatch a round

```sh
node .claude/workflows/playtest.dryrun.mjs
```

Stubs every agent and runs the real orchestration, so the cheap failures show up in
two seconds instead of costing a full fan-out: a helper deleted by an edit somewhere
else, a phase name that no longer matches `meta`, a roster that hands the wrong
assignment to the wrong charter. It has caught all three.

It also writes every generated prompt to `/tmp/prompts.txt` and then **asserts against
them**, which is the only cheap place to check the firewall — that a blind charter's
prompt carries no design doc, no judgement kernel, no timer schedule and no region but
its own is a property of the *text*, and grepping it is how you know. That assertion
earned itself immediately: the operator's coverage plan was being pasted into every
prompt, so a blind explorer got nine of Fulminate's ten rooms three lines above its
brief telling it "you have no map, no room list".

The other assertions pin the batched verifiers (two raters, batch/rater labels, a
measurable agreement denominator) and the absence of the retired censuses. It exits
non-zero when any of them fails.

**CI runs it on every pull request**, as the `Harness` workflow
(`.github/workflows/harness.yml`) — no path filter, so no edit can route around it.
Run it after any edit to `playtest.js` anyway: two seconds here beats a red check and
a round trip. A deliberate change to an asserted property means changing the assertion
in the same commit, which is the point — these are invariants somebody wrote down, not
incidental facts about the text.

**Two things it cannot tell you**, both about the servers rather than the script.

*Whether the game's MCP server is reachable.* Two ways it isn't, and the round fails at
`ToolSearch` for every tester either way, so confirm the tools resolve before dispatching.

A `.mcp.json` added mid-session is not picked up until the session restarts. And
`bin/gnusto-mcp` runs `swift build` before it `exec`s — so on a tree whose engine has just
changed, every registered game attempts a cold rebuild at once, and they can all pass the
client's startup timeout together. Seven servers vanishing looks exactly like a broken
`.mcp.json` and is nothing of the kind. **Run `swift build` to completion in the session
before the one that dispatches**; the script's own header says the same thing, and it is
cheaper to obey than to diagnose.

*Whether the server is the code you just wrote.* `bin/gnusto-mcp` builds and then
`exec`s, once, when the client connects — so a server is frozen at the commit its
session started on. Edit the engine mid-session and every tester goes on playing the
old binary, silently and successfully. **Restart the session after any change under
`Sources/Gnusto/Playtest/`.**

This one fails quietly, which is why it is worth a check rather than a memory. Open a
throwaway session and call `finish` on it:

```
open  label: staleness-check, role: explorer
finish  session: <id>, summary: checking the binary
```

A current server returns `roomsVisited` — one `{id, name}` row per room — plus
`unknownWords` and `firedTimers` in the result
and leaves a `closing.json` in the probe directory. A stale one returns none of them and writes no file
— and a round dispatched against it collates nothing, reports every session as never
having finished, and looks exactly like a round where the testers all crashed.

Check the other half in the same breath, because the round's turn count now depends
on it:

```
replay  commands: ["look"]
```

A current server answers `[playtest] replay lines=1 finished=false transcript=…` and
leaves that file under `.context/playtest/.replays/probe-001/`. A server predating
that writes nothing, and the collator's replay glob comes back empty — which reads as
a round whose verifiers never checked anything rather than as a stale binary.

Delete the scratch directory afterwards, `.replays` included.

## Measuring a change to the harness

Calibration asks whether the harness still finds known defects. This asks the other
question: whether a change to it — a coverage ranking, a charter, a brief — made
testers play *better*. `bin/playtest-measure` is the instrument. Point it at probe
directories and it reads `commands.txt` and `transcript.txt` for distinct rooms
entered, distinct verbs used, distinct objects examined, and command counts. Nothing
is self-reported.

All three producers write that pair under those names — the session server, its
sessionless `replay`, and `bin/playtest-replay` — so one invocation may mix probes
from a whole round. That was not true until #299: the CLI script called its command
list `commands.effective.txt`, so the instrument raised `FileNotFoundError` on the
larger half of a round's probes, and a round whose numbers nobody could get was a
round nobody measured. The layout is now declared once, in `playtest.js`, and
`playtest.dryrun.mjs` reads the producers' own source and fails if one of them stops
writing what is declared.

Three rules, each of which was learned by getting it wrong:

**Run a control, never compare against stored numbers.** Build a binary carrying the
*old* behaviour, run it through the *same* dispatch as the new one, and compare those
two. Recorded numbers from an earlier round were produced by a different driver — a
different model, prompt, or client — and that difference is easily larger than the
effect being measured. In August 2026 a comparison against stored numbers said plain
cheapness ranking cost 12 distinct verbs; a matched control said it cost none, and two
ranking changes had been built to fix a regression that did not exist.

**Only Dungeon can confirm anything.** Its 195 rooms are the only map in the corpus
with headroom. Fulminate's ten put every condition inside every other's spread — over
20 probes its rooms-entered ranges 1–8 with a mean near 5 regardless of what the
harness is doing. It can *falsify* a change cheaply, and it is worth running for that,
but a Fulminate pass is not evidence.

**Say what would count as success before running it.** Write the bar down, then honour
it. Re-tuning until the numbers pass is how a null result becomes a feature.

Two tells that a comparison has drifted, both worth checking before believing a
number: sessions opened per dispatched run (runs that open four sessions each are not
comparable to stored runs that opened one), and the command count moving with the
result — an arm that simply played longer will look better at everything.

```sh
bin/playtest-measure .context/playtest/<label>/probe-*
```
