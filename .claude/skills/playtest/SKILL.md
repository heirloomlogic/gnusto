---
name: playtest
description: Run an automated play-test round against a Gnusto game — Claude subagents play it, read the transcripts as prose, and report lines that are not true of the frame they printed in. Use when asked to playtest or play-test any game this package builds, named in whatever words the user typed; when asked to find prose defects, or to check whether a game's writing is true of where the player is standing; or after changing a game's copy, timers, or actor scheduling. Also use to reproduce a reported transcript defect, or to calibrate the harness against a historical commit.
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
bin/playtest-preflight <Game>
```

The first is one command, and it is not optional. It builds, then proves the game's MCP server
answers by speaking JSON-RPC at it over a pipe of its own — which is the only way to
check when the session's own registration has failed, because then the client is
exactly the wrong thing to ask. It exits non-zero and names the remedy when the round
is not dispatchable. It takes the game in whatever words you have: `Zork1`, `zork1`
and `Zork 1` all resolve against the package's executable products.

It then **writes the round's arguments** to `.context/playtest-round-args.json`,
derived rather than retyped — capabilities off the manifest, `docPath` and the ledger
and the focus split off `docs/games/`, the seed off the game's committed routes, and
`roundId` from today's date. The six paragraphs below explain what each one means and
what it costs to get wrong; none of them is yours to assemble by hand any more.

**There is no second command.** A game whose map outruns a round's budget reaches its
far side from a **deep start** rather than on foot, and those are committed:
`.playtest/<Game>/routes/<name>.json` holds the commands and the landing, so a fresh
checkout and a downstream clone have the same ones the round that made them had. Nothing
is cut at dispatch time and preflight's `routes` row only reads the files.

They used to be saved games — `.gnusto` bytes under gitignored `.context/`, cut from a
route scraped out of a Swift test — so a focus file describing nine of them and a
checkout holding none looked exactly alike, and the only thing that noticed was eight
testers all answering `Restore failed.`

`bin/playtest-routes <Game> verify` is the check that replaced the receipt: it replays
each route and refuses one that no longer lands where its manifest claims. Read its
lines against the region's own sentence, because **a deep start is chosen by what is
true where it lands and never by the room the `[status]` footer names**. `wf-1` on
2026-08-25 was cut three hundred commands past `take trunk`, so the footer said the
right room while the trunk was already in the trophy case and the pairing the round
existed to judge was offered to nobody.

Read `.context/playtest-round-args.json` into `args`, then invoke the workflow using its resolved path and the complete object:

```javascript
Workflow({ scriptPath: args.workflowPath, args })
```

Use the generated path and arguments. In a generated package the workflow lives in the Gnusto dependency checkout; preflight resolves that location and the package layout together.

If this session has no `Workflow` tool, run `bin/playtest-preflight <Game> --headless`. It dispatches through `claude -p` with explicit tool permissions and `tracker: false`: confirmed findings go into the report for review, without attempting issue creation. The Claude installation must provide `Workflow`; allowing a tool does not install it. A missing tool or denied operation must be reported, not replaced with a claimed successful round.

**`roundId` is required and has no default.** It is what keeps one round's artifacts
out of the next round's arithmetic: every label the harness generates leads with it,
and the collator's globs match on it. A default would be a collision that happens
silently, which is what three rounds running did — each reporting turn and session
counts with a previous round's sessions folded in, because the only "round" in a label
was the retry round, `r1`, which Tuesday and Thursday both use. Preflight fills it in.

**Nothing needs clearing between rounds.** `.context/playtest/` may hold every round
this checkout has ever run and the arithmetic stays right. What a previous round left
now lands in the unglobbed residual, which the critic is told to name.

`scriptPath` rather than `{name: "playtest"}` because the workflow registry is read
when the session starts: a checkout that gained `.claude/workflows/` after the session
began won't resolve the name, and the failure mode is a confusing "not found" rather
than anything informative. The path always works. `{name: "playtest"}` is equivalent
once a session has picked the file up.

**Work out `capabilities` from the manifest, not from a list in this file** — there is
deliberately no per-game config. `swift package describe` or `Package.swift` shows
what a game depends on: `GnustoClock` → `clock`, `GnustoConversation` → `talk`,
`GnustoScoring` → `score`, `GnustoSpellcasting` → `magic`. Charters filter themselves
on that, so a game with no clock gets no clock-watcher. A game is a **product**, and a
product name is not a target name: read the product's own `targets` and walk the graph
from there, or a package that names the two differently answers with an empty list that
reads exactly like a game with nothing in it.

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

Four artifacts, in this order — the ledger's preamble names the issue, so it goes last:

1. the round report, `docs/games/<game>-playtest-<YYYY-MM-DD>.md`
2. **any routes the Distill phase wrote**, under `.playtest/<game>/routes/`
3. **one issue** for confirmed findings when `tracker` is true and creation is approved; otherwise the proposed issue body stays in the report
4. every dedupe key, appended to `docs/games/<game>-playtest-ledger.md`

**The routes are the one artifact the round writes and does not commit.** The Distill
phase leaves them on disk and logs their names; `bin/playtest-routes <game> verify`
proves each from a second replay, and then they go in the same commit as the report. A
route nobody commits is a deep start the next fresh checkout does not have — which is
the whole failure the saved games were retired for.

`references/report-shape.md` has the two files, `references/issue-shape.md` the issue.
Commit the report even when the round found nothing — a provable empty round is the
point — but a round that confirmed nothing files no issue.

**One issue per round, per game, holding every class as a checklist** — not one per
class, not a separate one for the engine's share. 2026-07-30 filed thirteen in a day;
`issue-shape.md` has the shape and the round that made the rule necessary. Not
`routedIssues`, which runs the other way: those are open issues that *receive*
forwarded symptoms.

When `tracker` is true, the title is the key, so search before you create:

```sh
gh issue list --state all --search "<Game>: play-test round <YYYY-MM-DD>"
```

A second filing should collide the way a second report would, rather than resting on
whoever remembered the rule.

## Options

| Argument | Default | Notes |
|---|---|---|
| `seed` | `0` | Pins the stream via `GNUSTO_SEED`. Record it; a finding without a seed isn't reproducible. |
| `turns` | `60` | Engine turns per charter. Token cost, not CPU cost, is the real budget. **It is scored against all four of a tester's turn trees** — its session, the branches a rewind wrote off, its `replay` probes and its `bin/playtest-replay` probes — while the `[status]` move counter shows only the first. Testers spent 8x their budget without feeling it on 2026-08-25; the tester prompt now says so in as many words. |
| `charters` | all applicable | Comma-separated subset, e.g. `"tourist,clock-watcher"`. |
| `focus` | none | The coverage split, as **one string** with regions separated by `\|` — an array is silently read as a single region. Each region becomes one `explorer` *and* one `timekeeper`, up to three of each; the explorers are handed different divergence policies. Say how each region is reached, and **name no room**. See below. |
| `focusSighted` | none | The half of the split a blind seat may not have — a row keyed to a sighted charter, or one naming the walkthrough by type, the ledger's verdicts, or the room a deep start lands in. **Not** every mention of a deep start: a region must tell its tester which route to open with and roughly how deep it stands, or the tester walks instead. Never chunked, never seated, appended to the sighted charters' plan. It is everything below the focus file's **second** `---` rule. See below. |
| `routes` | `[]` | The names of the committed deep starts `open({start: …})` will accept, read off `.playtest/<Game>/routes/`. Every seat is told the whole set, so a region saying "start from `d-1`" is obeyed rather than guessed at. **Names only** — a route's landing is a room name, and a room name is what the firewall exists to withhold. An empty list is a game whose testers play cold, which is what a downstream game has on day one. |
| `verifyEffort` | inherit | Reasoning effort for the verifiers — the round's largest fan-out, and so its cost. Turn it down to buy a bigger round; read the warning below first. |
| `rounds` / `dryRounds` | `1` / `2` | Loop until N consecutive rounds surface nothing new. |
| `packagePath` | `"."` | Drive another checkout — a worktree at an older commit, for calibration. |
| `ledgerKeys` | `[]` | Keys from previous reports, so the loop doesn't re-find its own rejections. |
| `routedIssues` | `[]` | `[{number, owns}]` for open issues that own a defect class. Derive it fresh — see above. |

**A round finds and reports; it does not fix.** The fix phase is gone, and with it the
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

**A list longer than the cap is doubled up, not dropped.** Declare four regions against a
cap of three and the seating splits them 2/1/1 rather than handing the fourth to nobody;
the dispatch log prints every seat's chunk and names how many took more than one, and the
dry run fails if any declared region reaches no blind explorer. It used to truncate in
silence, and a region nobody was seated on reads afterwards exactly like a region nobody
found anything in — that is 60 of Dungeon's rooms on 2026-08-25. A doubled seat still
costs that seat's attention, so **declare at most three regions when you can**, and split
the rest across a second round.

**The rooms outside every region are told to the testers, because they cannot be
checked.** A split is a plan for the rooms it names, and *"name no room"* means nothing
here can compare a split against the roster and report the gap. So **every seat that
plays** is handed the standing residual — rooms no region describes are owned by nobody,
and are yours when your own assignment runs dry — and the dry run asserts every one of
them got it. Every seat, not only the two charters that instantiate per region: the
interrogator and the solver read the whole focus file, which makes them the seats most
able to notice a room that is in none of it.

Two rounds are why. The 2026-08-17 Fulminate round split by clock alone and lost the
storey above; the 2026-08-26 round fixed the vertical axis and lost the early ground
floor and the outbuilding instead. Both times the unowned rooms produced **zero
findings**, and both times that reads afterwards like rooms nobody found anything in. On
the second, one of them had taken zero commands in 1,288 turns and held the victim, a
death ending nobody had ever produced, and a scheduled branch that fired eighty-one times
and never once took it. **Declaring another region closes the hole the last round found;
the residual is what covers the next one.**

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
critic with two hand-built controls to settle it for six of Dungeon's thirty-five.

**Every one of those numbers starts at the landing for a session opened with `start:`.**
A route is the harness's walk, not the tester's, so the rooms it crossed, the rooms it
worked, the timers it fired and the words it typed are all cleared before the tester's
first line — otherwise eight seats each carrying Dungeon's ninety-room start would
publish a round that covered the map and worked none of it. `prefixTurns` is how many
lines the route took, written into every `closing.json` and `0` for a cold session, and
it is a turn count rather than a correction to apply to the rest.

The third number is
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
bin/playtest-preflight                 the front door — run this first, always
bin/playtest-replay                    the replay helper; --start begins deep
bin/playtest-routes                    cuts, distils and verifies a deep start
bin/lib/playtest-distill.js            the shrink: the ddmin pass and its predicate
bin/lib/playtest-focus.js              the focus split, the ledger, and where routes live
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

**What it cannot tell you is anything about the servers**, and that is
`bin/playtest-preflight`'s half of the job. Run both; they overlap nowhere.

Preflight performs, and now owns, the two checks this section used to describe as
rituals. Both used to fail quietly, which is why they were worth a check rather than a
memory — and why a check performed from memory was the wrong shape for them.

*Whether the game's MCP server is reachable.* The round fails at `ToolSearch` for every
tester when it isn't, and there are two ways. A `.mcp.json` added mid-session is not
picked up until the session restarts. And `bin/gnusto-mcp` used to run `swift build`
before it `exec`ed, so every registered game attempted a rebuild at once and they
queued on SwiftPM's `.build` lock — seven servers taking **46 seconds** to answer on a
fully warm tree, which is past the default startup timeout, and far worse on a cold one.
Seven servers vanishing at once looks exactly like a broken `.mcp.json` and is nothing
of the kind.

The script now skips the build when no source has been touched since its last one, so
the steady state is **~150ms** for all seven. **The exception is the first connect after
an edit**: one changed source invalidates every game's stamp at once and they queue for
the lock exactly as before, 46 seconds again. That is why `MCP_TIMEOUT` is set to
180000 in `.claude/settings.json` rather than left to whoever dispatches, and why
preflight builds serially ahead of any client. Run it after editing the engine and no
server pays that cost at all.

*Whether the server is the code you just wrote.* `bin/gnusto-mcp` builds and `exec`s
once, when the client connects — so a server is frozen at the commit its session
started on. Edit the engine mid-session and every tester goes on playing the old
binary, silently and successfully. **Restart the session after any change under
`Sources/Gnusto/Playtest/`.** No retry fixes this one; it is the one condition where
restarting really is the answer.

Preflight proves the binary is current by opening a session, finishing it, and reading
the result: a current server returns `roomsVisited` — one `{id, name}` row per room —
plus `roomsWorked`, `unknownWords`, `firedTimers` and `prefixTurns`, and leaves a
`closing.json` in the probe directory. A stale one returns none of them and writes no file, and a round
dispatched against it collates nothing, reports every session as never having finished,
and looks exactly like a round where the testers all crashed. It checks the other half
in the same breath, because the round's turn count depends on it: a `replay` that
answers `[playtest] replay lines=1 …` and leaves a probe under
`.context/playtest/.replays/`. A server predating that writes nothing, and the
collator's replay glob comes back empty — which reads as a round whose verifiers never
checked anything rather than as a stale binary. It deletes its own scratch afterwards.

**The round checks once more, from the inside.** Preflight drives the server over a
pipe of its own, which is what makes it work when registration has failed — and what
stops it proving that *this session's* MCP client ever connected. So `playtest.js`
opens with a `Preflight` phase: one agent, `ToolSearch`, open, finish. If the tools do
not resolve it logs the remedy and returns without dispatching, rather than fanning
eight testers into the same wall and collecting eight reports saying they could not
find the tools.

**An empty `ToolSearch` is always the server and never the prompt.** Every tester is
told so in as many words, and told to stop rather than improvise — a blind charter has
no CLI fallback by design, and handing it one to route around an operator's mistake
would breach the firewall to fix the wrong problem.

**A reproducer taken from a deep start is replayed with `--start`, and stages
nothing.** `bin/playtest-replay <Game> --start <route> --commands <file>` plays the
committed route ahead of the list and takes the seed off its manifest — a route
replayed at another seed lands somewhere else and says nothing about it, so a `--seed`
that disagrees is refused rather than honored. It reads the same
`.playtest/<Game>/routes/` store `open({start: …})` plays and appends the same `look`
after it, which is what makes the verifier's opening frame the tester's opening frame.

**The tester's own door is not that one.** The MCP `replay` tool always boots at turn
zero and takes no route, and a blind charter has no CLI by design — so a tester
re-verifies a deep reproducer by taking a `checkpoint` on the turn its session opens,
which is the frame the route stopped on, and restoring to it. The finding then carries
`startedFrom`, and the route name is what turns a list that only means something at the
landing into one anybody can run.

Everything below is what is left once that case is gone: a **tester's own** mid-session
`save`.

**A reproducer that starts with `restore` needs a save door, and both harnesses have
one.** The MCP `replay` tool takes `savesFrom`; `bin/playtest-replay` takes
`--saves-from`. Either copies `*.gnusto` slots in before the game boots, and **neither
can write back into the source it read**. Without it the game answers *"Restore
failed."*, and **that answer is about the harness, not about the finding**: it produced
four false `not-reproducible` verdicts on 2026-08-25, two of which reproduce in seven
commands. The `replay` tool now says so on its own answer, on a `restore-unreachable`
line, so a verifier reading a bad verdict is told which of the two facts it is holding.

**Both take a label or a path, and after the round it has to be a path.** A bare name is
a play label; anything holding a slash is a directory of slots. The path form exists
because the label form expires: labels are cleaned between rounds and a fixer picks the
class up afterwards, so the label a report names is usually gone by the time anybody
replays it. Every staged probe keeps the bytes it ran on in `saves-in/` beside its
transcript for exactly this, and `--saves-from <probe>/saves-in` reproduces a reported
finding with nothing else surviving. Which means the finding has to *carry* its source:
`savesFrom` is a field on the finding contract, the round prints it to the verifier as
`Saves:`, and `issue-shape.md` requires it beside any reproducer that restores.

**The two differ in where the copy lands, and it matters.** `replay` stages into a
throwaway it deletes, so the staging lasts one call. The script has no per-run save
directory — saves belong to the label, which is what makes `--save`/`--restore` work
across two runs — so its copy **joins that label permanently**, and every later probe
under the same label restores those slots without passing the flag. It records a
`.staged-from` marker for exactly that reason, and reads the receipt off the marker, so an
inheriting run says so too. Give each replay its own label suffix and the question does
not arise.

Either way a staged probe says so on its header line and in `summary.txt` and keeps the
staged bytes in its own `saves-in/`: it reproduces from its command list only while those
slots exist, which is weaker evidence than a clean start and is labelled as such.

**Ship at least one deep start the round can actually use**, and let
`bin/playtest-routes` cut it. It is chosen by *route state*, not by the room name the
`[status]` footer reports: `wf-1` on 2026-08-25 was cut three hundred commands past
`take trunk`, so `object:trunk:open` was offered to nobody while the footer said the
right room. And check who is alive in it — every deep start that round shipped ran past
`attack thief with sword`, which silently removed the thief from three of four regions.
Both of those are read off the script's own `cut` and `verify` lines, which print the
landing room, the move count, the score and the inventory for exactly this.

**A round with no routes to ship is not stuck**, and this is the property worth
knowing before you go looking for a walkthrough to cut one from. `.playtest/` starts
empty, the testers play cold, and the round's **Distill** phase turns its own play into
the deep starts the *next* round opens at. A downstream author on day one has no
walkthrough and never will; they run a round, and the second one is faster than the
first without their having written anything.

The phase runs after play and before the report. An agent reads the sessions' own
`commands.txt` and `closing.json` files and names up to three **targets** — states worth
being able to return to — and for each one the session and the line that first reached
it. That is the whole of its judgement. It never decides which of sixty commands
mattered: it passes a directory and a line number to `bin/playtest-routes <game>
distill`, which drops the commands that cost no turn, then drops contiguous runs and
replays after each, keeping a cut only when the game still lands in the same place. An
agent inferring causality from prose is guessing at something a replay can know.

**The budget is 300 replays a target and it is printed, not hidden.** Running to
convergence is not something a round can buy — measured on Dungeon, ~2,400 replays for a
113-command list and ~16,500 for a 719-command one (#359) — so the goal is *shorter*,
never *minimal*, and a target that stopped at the bound is logged as `CAPPED` with every
segment it managed to drop above it. A phase that silently truncated its own coverage
would read as one that covered everything.

Two things the shrink cannot check, both worth reading a new route against by hand
before you trust it. The predicate compares the landing — room, score, the `look` and
the `inventory` — so **timer state and where the actors are are outside it**: a route can
preserve the room and still have left the thief somewhere else. And a route whose
session died or won is refused rather than committed, because an ended game answers
`look` and `inventory` with the same line and a deep start has to be somewhere a tester
can play from.

The shrink's own replays are not the round's turns and are counted by nobody: they run
under a `routes-distill-<name>` label, outside every glob the collator reads, because
they are neither a tester's coverage nor a finding's evidence. The number of them is on
the script's own output. Do not widen a glob to catch them.

**The session door for a tester's own saves is `savesFrom` on `open`.** A round's deep
starts do not come through it — those are routes, and `start:` is their door. Before
#333 there was neither: bytes had to be hand-copied into every `<sessionLabel>/saves/`
directory before dispatch, which meant knowing the workflow's label scheme in advance,
and the 2026-08-25 operator did it eight times by hand.

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
