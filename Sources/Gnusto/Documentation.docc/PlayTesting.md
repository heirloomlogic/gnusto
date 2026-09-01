# Play-testing a Game

Reading a transcript as prose, and the tools that make somebody else do it.

## Overview

A transcript test asserts that a line *appears*. It never asks whether the line is *true of the room the player is standing in*. That gap is not a hole in anybody's test suite — it is a hole in what a test suite can express, and it is where this class of defect lives: a character goes on looking at the fire from the bottom of a dark coal cellar; dust settles on the hall table in a transcript read from the kitchen; a room offers an exit it described two states ago.

Every assertion in this repo's suite passes while those lines print. Catching them means playing the game and reading what comes back, which is slow, and which nobody does often enough. So the engine ships the machinery to make it cheap: a status footer that says where a line was printed from, a replay script that pins the seed, and a play-test server that hands the whole job to an agent and then asks it what it never followed up.

## The tester's knobs

Three conveniences belong to the front end rather than the engine, which is what makes them free: those lines never reach ``GameWorld``, so none of them costs a turn or moves a clock.

### Comments

A line whose first non-blank characters are `//` or `#` is a note, not a command. The story window shows it in dim italics and a running transcript records it, but the engine never sees it — no parse, no rules, no fuse or daemon. Comments also stay out of Up/Down recall, so the history stays a list of things the game actually ran.

### Pasting a note

In a terminal that supports bracketed paste, pasting a multi-line block into a line that already begins `//` or `#` folds it into one comment: every line break becomes a single space, and nothing is submitted until you press Return. Pasting into any other line still submits one command per line, so a walkthrough can be replayed by pasting it. Terminals without bracketed paste behave as before, one line at a time.

### Recording a transcript

`script` starts writing the session to a file and `unscript` stops; `script <name>` names it, and a name containing `/` or starting with `~` is treated as a path. To record from the opening text instead, set `GNUSTO_TRANSCRIPT` — see <doc:SharingYourGame#Environment-variables>. A transcript is plain text, `> command` lines interleaved with the game's output and comments included, so a tester can attach one to a bug report.

## The status footer

`GNUSTO_STATUS=1` appends one line to every turn:

```
[status] room=Coal Cellar | moves=41 | turn=cost
```

That line is the whole point of the exercise. Reading a transcript, you cannot tell which room a paragraph was printed *from* — only which room it talks *about*, which is exactly the thing under suspicion. The footer answers the first question so the prose can be judged on the second.

`turn=cost|free` is the other half. **Counting commands is not counting turns**: a parse failure and a meta verb are free, and a stub verb is not. Four commands can be three turns, and a tester who assumed four is now reasoning about the wrong minute of a timed game. See <doc:TheTurnPipeline>.

The variable is read by ``GameMain`` and handed to ``REPL`` as an argument rather than read from the environment down inside the engine, so `GNUSTO_STATUS=1 swift test` changes nothing. A ``GameContent`` or ``GamePlugin`` can contribute its own field — see <doc:ContentBundles>.

## Replaying a script

`bin/playtest-replay` plays a command file non-interactively with the seed pinned, and writes the evidence to disk:

```sh
bin/playtest-replay --build Fulminate                    # once, separately
bin/playtest-replay Fulminate --commands probe.txt --seed 0 --label mine --tail 60
```

Building is a separate one-shot on purpose: a replay that also builds cannot be trusted to have replayed the same binary twice. Output lands under `.context/playtest/<label>/<probe>/` as `transcript.txt`, `commands.txt`, `stderr.txt` and `summary.txt` — the same two evidence files the session server writes, under the same names. Read the transcript file rather than the tail on your terminal — the tail is for checking the run happened.

`bin/playtest-measure` reads a probe directory and reports what the run covered: rooms entered, distinct verbs, objects examined, objects touched and then re-examined. Its counting rules are frozen deliberately, so a number from last year still compares.

A package written by `bin/new-game` has all three: `bin/playtest-replay`, `bin/playtest-measure` and `bin/export-game` are shims over the copies in the Gnusto checkout it depends on, so they are never a version behind the engine they are driving. Run `swift build` once before the first one, since the tools live in a checkout SwiftPM has to have resolved.

`docs/playtesting.md` in the repository is the operating manual for doing this by hand, and carries the calibration answer key — the defects a round is supposed to find. A round that finds nothing is a broken harness before it is a clean game.

## Serving the game to an agent

Every Gnusto game is also a play-test server. ``GameMain`` answers `--mcp` — or the `GNUSTO_MCP` environment variable, for a client that can set an environment but not an argument vector — by speaking the Model Context Protocol over stdio instead of playing. An agent opens a session, takes turns, reads back its own transcript, and is told what the game has shown it that it never followed up.

Nothing in your game has to know about this. The switch lives in the ``GameMain`` protocol extension every game already conforms to, so a game written by somebody who has never read this page becomes a server for the cost of a flag.

`bin/gnusto-mcp` is the launcher, and a generated package gets a shim over it:

```sh
bin/gnusto-mcp MyGame
```

It builds the game, asks where the binary landed, and hands the process over. **Stdout is the protocol**, so the build's progress goes to stderr and nothing else is printed at all — which is also why the build isn't silenced, since a failing server's stderr is where a client shows you the compile error.

Register the game with a `.mcp.json` at your package root, one entry per game:

```json
{
  "mcpServers": {
    "mygame": { "command": "bin/gnusto-mcp", "args": ["MyGame"] }
  }
}
```

One binary is one game, so no tool ever takes a game name. If you started with `bin/new-game`, both files are already there and already carry your game's name — there is no edit.

Two things worth knowing before the first run. A cold start builds the game, which can take longer than a client's startup timeout — get the build out of the way once with `swift build`, or raise the timeout (`MCP_TIMEOUT`, in milliseconds). And a running server is frozen at the commit it started on, so restart the session after editing the engine.

## The tools

Fourteen of them. The ones that advance a world are applied in the order they arrived on the wire, so two `move` calls in flight cannot land in an order nobody picked; the rest are answered concurrently.

| Tool | Turns | What it does |
|---|---|---|
| `survey` | none | Everything true of the game before anybody plays it: rooms and connections, declared fuses and daemons, the verb table, the cast, the maximum score, and the bootstrap's warnings. This is the answer key, so a session opened in a play-testing role is refused it. |
| `vocabulary` | none | Whether the parser knows each of a list of words, in one call. Also answer-key data, and refused to a tester for the same reason: somebody who can look up the vocabulary can never find the defect where a room description prints a noun the parser has never heard of. |
| `resolve` | none | What each of a list of words actually names in the room the session is standing in — not whether the game knows the word, which is what `vocabulary` answers. Answer-key data too, and refused to a tester for a sharper version of the same reason: several words all answered by the *same* thing is a defect no other instrument here can see, and somebody who can ask has been handed it. |
| `open` | — | Boots the game at a pinned seed and returns the session id, the opening text, and the status line. It also takes `start`, the name of a committed route: the server plays that walk before the session's first turn and hands back the frame it ends on. The session records to disk from this moment, so a crash anywhere still leaves evidence. |
| `move` | yes | Plays one or more commands and returns transcript form with a `[status]` line under every turn. The batch stops early, and says how many commands went unrun, when the game ends. |
| `recall` | none | Reads a numbered slice of the transcript back, optionally filtered — each matching turn returned whole, so the command that caused a line comes with it. |
| `coverage` | none | What the game has shown you and you never followed up, cheapest first, each one a command to paste: a noun the prose printed that you never named, a direction a room described that you never took, an object you changed and never looked at again. |
| `note` | none | Writes a comment into the transcript at the turn you are standing on, so a wrong line gets flagged when you read it rather than reconstructed forty turns later. |
| `finish` | — | Says what you found and that you are stopping. It always accepts, and it tells you what was still open. |
| `checkpoint` | none | Marks where you are standing. Not the game's own SAVE — that is a thing you should still type at the game when you mean to test it. |
| `restore` | — | Returns the world, the timer queue and the move counter to a checkpoint. The abandoned turns leave the command list and are kept beside the transcript as `branch-NNN.txt`, so a branch you walked away from is still evidence. |
| `rewind` | — | Takes back the last few recorded lines. Comments count as lines, because that is how they are numbered everywhere else. |
| `export` | — | Writes the evidence out and checks that it replays: the command list goes through a fresh copy of the game and the result is compared byte for byte, so what you cite is provably a regression test. |
| `replay` | none | Plays a command list in a brand-new copy with no session at all. Give it an excerpt to `expect` and you get a verdict instead — whether that text really printed, at which turn, in which room, and the whole turn it printed in. |

The refusals in the first two rows are the design, not a limitation. A tester holding the answer key stops being a player, and the defect that matters most is the one only a player can see.

### Deep starts

A game whose map outruns a session's budget cannot be tested at its far end on foot. So a route — a command list, the seed it was recorded at, and the frame it ends in — is committed beside the game:

```
.playtest/<Game>/routes/<name>.json
```

`open` takes one by name and plays it silently. The tester is handed the frame it stopped on and never the commands: `recall` will not read them back, and the rooms the route crossed are not credited as anything the tester covered. `closing.json` records `prefixTurns`, so a round can say how much of a session was the harness walking rather than the tester playing.

A route is checked by **replay, never by a hash**. Bytes on disk cannot say what they were cut from; a command list can be run. If it no longer ends where its manifest claims, it is stale, and the failure says which room it ends in now.

**A game with no routes needs nothing.** `.playtest/` starts empty, every session opens at turn zero, and a game's routes accumulate out of the sessions that found somewhere worth returning to.

That accumulation is not a session replayed verbatim. Sixty turns reached somewhere of which perhaps twelve mattered, and the other forty-eight were a tester trying fifty ways of working a lever with the lantern burning down — so a learned route is **distilled** before it is committed. The commands that cost no turn go first, for one confirming replay; then contiguous runs are dropped and replayed after each, and a cut is kept only when the game still lands in the same room with the same score, the same `look` and the same `inventory`. The survivor is replayed once more from nothing and the manifest records where that actually landed. `bin/playtest-routes <Game> distill` is that tool, and the harness's own round runs it as a phase.

The shrink is bounded and says so. It stops at a replay budget rather than at minimality, and its predicate compares the landing — so it does not check timer state or where the actors are, and a route can preserve the room and still have left the thief somewhere else.

### Where sessions live

Under `.context/playtest`, or wherever `GNUSTO_PLAYTEST_DIR` points. `GNUSTO_MCP_MAX_SESSIONS` caps how many hold a live world at once — 32 by default. Past the cap the oldest is evicted to its command list and replays itself on next use, so an evicted session answers exactly as it did before; it just costs more to ask.

## Topics

- <doc:TestingYourGame>
- <doc:TheTurnPipeline>
- <doc:SharingYourGame>
- ``GameMain``
- ``REPL``
- ``ScriptedIOHandler``
