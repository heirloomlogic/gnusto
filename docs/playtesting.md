# Play-testing a Gnusto game

There is a class of defect this repo's tests structurally cannot catch.

A transcript test asserts that a line **appears**. It never asks whether the line is
**true of the frame it printed in** — the room the player is standing in, the hour on
the clock, the state of the world at that moment. Only a reader asks that. So the
whole suite passes while:

- an NPC goes on "looking at the fire" from the bottom of a dark coal cellar;
- an indoor blast tells a player sixty feet and two walls away that "the note in your
  ears steps down one";
- dust settles "on the hall table" in a transcript read from the kitchen;
- `get pike` answers "The Dr. Pike would take exception to that." because the game
  re-skinned every actor-directed stock line except one.

Every one of those was found by a person playing with a transcript running and reading
the output as prose. None was found by `swift test`. This document is how you do that
by hand; `.claude/skills/playtest/` is how you hand it to several Claude subagents at
once.

## The one command

```sh
bin/playtest-replay --build Fulminate       # once
bin/playtest-replay Fulminate --commands probe.txt --seed 0 --label mine --tail 60
```

`--build` is a separate one-shot on purpose. Replaying never builds, so a dozen
parallel testers can't trigger a dozen builds, and a stale binary is a legible error
instead of a mystery. It asks `swift build --show-bin-path` for the location rather
than guessing: under the swiftbuild build system the binary is in
`.build/out/Products/Debug`, not `.build/debug`, and a stale copy from an earlier
`swift run` may be sitting in the other one.

`bin/playtest-replay --help` lists every flag.

## Iterative replay

You don't hold a session open. Each turn is a fresh process that replays the **whole**
accumulated command list with the seed pinned. Append a command, run again, read the
new tail.

That sounds wasteful and isn't: a 120-turn replay measures about 25 ms, so replaying a
120-turn probe 120 times costs less than the time you spend reading one transcript.
What it buys is worth much more than it costs:

- **Determinism, by construction.** The transcript you just read is exactly the string
  `play(Game(), commands, seed: 0)` produces in the suite. So your command list *is*
  the regression test — no translation step, nothing to get wrong.
- **No process to supervise.** Nothing to wedge, nothing to poll, no framing protocol
  needed to know a turn is finished.

The cost that *is* real is tokens, or attention: re-reading a growing transcript every
turn. Hence `--tail`. Read the tail; open the full file when you need earlier context.

## Read the transcript file, not stdout

The plain IO handler prints the `> ` prompt but **not** the piped command, so stdout
looks like this:

```
> Front Hall

Black and white tile, worn through to the grout along the line people walk. …
```

Answers with the questions missing. `GNUSTO_TRANSCRIPT` records `> look` interleaved
with the output, byte-for-byte what `ScriptedIOHandler` produces in the suite — so the
file is both readable *and* the exact string a test asserts on. `bin/playtest-replay`
sets it for you and prints the path in its trailer.

## Annotate as you go

A line whose first non-space characters are `//` or `#` is recorded in the transcript
and **never reaches the parser**. No turn, no clock tick, no rule, no fuse. So a
command file is also a notebook:

```
// Clock-watcher: Timeline row "5:48 Constance -> backYard".
// Her ARRIVAL line masks the standing listing line, so probe the turn after too.
south
west
z
z
z
z
z
z
z
time
look
```

The annotated transcript is the artifact you attach to a bug report. `script` and
`unscript` do the same thing mid-session in an interactive game.

## Never count commands as turns

Meta commands (`score`, `quit`, `version`, `undo`, `restart`, `save`, `restore`) and
**every command that fails to parse** cost no turn. This is the most common timing
mistake in the repo, and the harness prints it back at you every run:

```
> x tile
I don't know the word "tile".

> quit
Your score is 0, in 3 turns.
```

Four commands, three turns. If you assumed four you are now reasoning about the wrong
minute. Anchor every hour you claim with a real reading — `time`, or a room listing you
can place — rather than with arithmetic.

## Deep states: save once, restore per probe

Reaching 6:26 by typing thirty `z`s in every probe is a waste. Save at the anchor once
and restore into it:

```sh
bin/playtest-replay Fulminate --commands prologue.txt --label deep --save anchor
bin/playtest-replay Fulminate --commands probe.txt   --label deep --restore anchor
```

Both `save` and `restore` are two-turn interactions — the parser knows only the bare
verb, and the engine asks for a filename on the next line — which the flags handle.
Restoring costs no turn, so it doesn't move the clock. Saves land under
`GNUSTO_SAVE_DIR` inside the label's scratch directory, so they never touch your real
save slots and parallel testers can't read each other's.

## What to look for

`.claude/skills/playtest/references/playtester-brief.md` has the full judgement kernel
and is worth reading even if you never run the automated harness. The two rules that
catch the most:

**An actor's room-listing line prints on every look, forever.** `firstSight(…)` /
`presence { }` is the room-listing paragraph; `description(…)` / `describe { }` is the
examine text. On an *item* the listing line stops once the player touches it. On an
*actor* it never stops. So an actor's listing line has to be true in every room and at
every hour that actor can occupy — and a line like "Mrs. Vane is in her chair with the
lamp unlit" cannot be, because she spends six minutes of the evening out of the chair.

**A fuse's text lands a turn or two after its event, by which time the player may have
walked away.** So aftermath prose has to be judged on two independent axes: where the
player is *now*, and where they were *then*. Judge each clause separately — one
sentence can be half true. "There is grass in your cuff" belongs to where they were
knocked down; "the note in your ears steps down one" belongs to an ear that was
actually ringing.

## Where a round's output goes

| Path | Committed | What |
|---|---|---|
| `.context/playtest/<label>/` | no | transcripts, effective command lists, stderr |
| `docs/games/<game>-playtest-<date>.md` | yes | the round report |
| `docs/games/<game>-playtest-ledger.md` | yes | append-only dedupe keys and verdicts |

The report is committed even when the round found nothing — a provable empty round is
the most useful thing to have six months later, and the only way to catch the harness
grading itself generously. The ledger is what stops a loop rediscovering its own
rejected findings forever.

One wrinkle: `.github/workflows/documentation.yml` does `rm -rf ./docs` in its own
runner before generating the DocC site there. That doesn't touch the repo, but it does
mean nothing under `docs/` is published to the documentation site. Reports live there
to be read in the repo and in PR diffs.

## Calibration: the answer key

A harness that can't re-find what a human already found isn't worth running. The
commits below are the graded exercise. They are on the pre-squash `issue-72-topics`
branch, so they are reachable by SHA in a full clone but are **not** ancestors of
`main` — which is why the results are written down here rather than checked in CI.

```sh
git worktree add /tmp/gnusto-cal 3fab729
bin/playtest-replay --build Fulminate --package-path /tmp/gnusto-cal
bin/playtest-replay Fulminate --commands probe.txt --package-path /tmp/gnusto-cal --label cal
```

**The three defects usually cited do not co-exist in any single tree.** At `3fab729`
`Fulminate.swift` contains no `fuse(` calls at all, so the untrue aftermath beats
cannot be rediscovered there — there are no aftermath beats yet to be untrue. They
were introduced by `3ec0521` and `c9d3cb5`, the commits that fixed the *first* round.
`23195d5`'s own note — "One of them was mine" — is literally true.

### Tree A — `3fab729`, before any playtest round

| # | Defect | Frame | Charter | Cost |
|---|---|---|---|---|
| A1 | `x tile` → `I don't know the word "tile"`, while the Front Hall prints "Black and white tile, worn through to the grout" | Front Hall, 5:30 | tourist | 1 command |
| A2 | `get pike` → "The Dr. Pike would take exception to that." | Parlour, 5:30 | vandal | 2 commands |
| A3 | Mrs. Kettle is "the only person here who has looked at the wreckage" sixteen minutes before there is one | Kitchen, 5:30 | tourist | 2 commands |
| A4 | Room listing says "Mrs. Vane is in her chair with the lamp unlit" while she is out in the yard watching the carriage house burn | Back Yard, 5:50 | clock-watcher | 11 commands |
| A5 | `x pike` → "wearing his hat indoors" in the back garden | Back Yard, 5:50 | clock-watcher | same probe |

A4 is the one to watch. Her **arrival** line prints on the turn she arrives and masks
the standing listing line, so a probe that looks on the arrival turn sees correct prose
and finds nothing. One more `z` and the static line appears. A charter that doesn't
know this scores zero on the marquee defect.

A1 is the tie-break case: the reply is an unknown-word reply, which normally routes to
#76 — but the game's own description printed the word, so it is an unanswerable noun
and it belongs to the round.

### Tree C — `c9d3cb5`, the only tree where "one of them was mine" is testable

| # | Defect | Frame | Provenance |
|---|---|---|---|
| C1 | Delphine's presence rule keys on the blast alone, so she is "looking at the fire" from Vane's Study at 6:02 and from the bottom of the dark cellar at 6:26 | Study 6:02; Cellar 6:26 | **introduced by `c9d3cb5`** |
| C3 | "the note in your ears steps down one" still printed indoors, sixty feet and two walls away | Front Hall, 5:50 | **introduced by `c9d3cb5`** |
| C6 | A2's `get pike` still present | any | preexisting |

C1 is the whole design earning its keep. The fix for A4 reintroduced the same class of
bug one branch shallower: a `presence` rule that knows *when* but not *where*. Both
probes come straight off the design doc's Timeline rows — read the table, occupy the
cell, `look`. A harness that finds A4 but not C1 has learned to check rooms and not
states, and will keep signing off on the next version of this bug.

The bar: every Tree A defect rediscovered; C1 rediscovered **and** attributed to the
commit that introduced it; and no more than one confirmed finding in five turning out
to be a false positive. A harness with a high false-positive rate costs more than it
saves, because the fixes it prompts make the game worse than it was.
