# Run a Play-test Round

A round sends agents through a game, replays their evidence, and writes a report of confirmed and refuted findings. It is the author-facing workflow around the instruments in <doc:PlayTesting>.

## Start with preflight

From the game package root, build once and run preflight with the executable product's name:

```sh
swift build
bin/playtest-preflight MyGame
```

Preflight checks the game and its MCP connection, then writes `.context/playtest-round-args.json`. That file is the round's contract. `roundId` keeps a round's artifacts separate; `tracker` says whether confirmed findings may become GitHub issues; the package layout identifies the game, its sources, documents, and MCP server; and `enginePath`, `refPath`, and `workflowPath` identify the resolved engine sources, round references, and workflow. Pass the whole object to `Workflow`; do not replace its paths with paths from this checkout.

```javascript
Workflow({ scriptPath: args.workflowPath, args })
```

If you are dispatching from a terminal, run `bin/playtest-preflight MyGame --headless`. It invokes the installed Claude CLI and records proposed findings in the report. Headless rounds do not create GitHub issues.

## The first round plays cold

A new game needs no design document, focus file, route, or coverage ledger before its first round. Preflight supplies seed `0` unless committed routes require another shared seed. Testers begin at the opening turn and play without a map or answer key.

The first round can create the material that makes the second one deeper. When a session reaches a place worth revisiting, the round runs `bin/playtest-routes MyGame distill` on that session. Distill replays and shortens the recorded commands, then commits a route only after a cold replay reaches the same landing. Later rounds can use that route as a deep start instead of walking there again.

## Focus files and dependency updates

A focus file is optional. When you add one, put it in `docs/games/` and name it so that its filename, with punctuation and case ignored, is `<game>-playtest-focus`. For example, `My Game` can use `my-game-playtest-focus.md`. A name that does not fold to that form is treated as if no focus file exists, with no warning.

The harness comes from the resolved Gnusto dependency. `swift package update` can change it when it changes the engine, even if none of your game files changed. Record the resolved dependency when you compare rounds before and after an update.

## Topics

- <doc:PlayTesting>
