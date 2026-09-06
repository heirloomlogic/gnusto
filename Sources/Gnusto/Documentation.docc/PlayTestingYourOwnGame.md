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

## Know the round arguments and their cost

Preflight fills in the values below. Keep those generated values unless you are deliberately planning the round; changing a path or a routing value by hand can make the workflow inspect a different checkout or suppress the wrong finding.

| Argument | Meaning |
| --- | --- |
| `game`, `packagePath`, `mcpServer`, and the document and layout paths | The game to run, its package and server, and the resolved locations of its source, documents, engine, references, conventions, and workflow. These let a round work from a package that depends on Gnusto instead of assuming this checkout's layout. |
| `tracker` | Whether confirmed findings may be filed on the package's GitHub tracker. Headless dispatch sets it to `false`; proposed issue bodies remain in the report. |
| `capabilities` | Optional engine features detected from the game's target graph, such as `clock`, `talk`, `score`, or `magic`. They select only the charters that can exercise those features. |
| `seed` | The shared random seed for every seat and replay. It defaults to `0`; routes must agree with it so a deep start remains reproducible. |
| `turns` | Engine turns available to each charter. This is primarily a token budget: branches and replay probes count too, even when the session move counter does not show them. |
| `roundId` | The local-date identity used in artifact paths, session labels, and the report name. Give a same-day rerun a distinct suffix rather than clearing an earlier round. |
| `focus` and `focusSighted` | The blind and sighted halves of an optional focus file. Blind text assigns coverage without revealing room names; sighted-only text may include walkthrough, ledger, or route-landing answers. |
| `routes` | Names of verified, committed deep starts. The workflow gives every seat those names but withholds their landing rooms; an empty list means play from the opening. |
| `ledgerKeys` and `routedIssues` | Previously refuted finding keys to avoid re-reporting, and open issues that own a defect class and should receive forwarded symptoms. Preflight derives ledger keys; add routed issues only when they currently own the class. |
| `verifyEffort` | Optional reasoning effort for the independent verifiers. This is the principal cost dial: verification fans out two raters per finding batch. Lower it only to fund more turns or charters, record that choice in the report, and expect less reliable refutation. |

Other optional planning controls are `charters` (a comma-separated subset), `rounds` (the maximum total iterations), and `dryRounds` (how many consecutive quiet rounds end the loop). They are absent from preflight's defaults, so add them only when that narrower plan is intentional.

## The first round plays cold

A new game needs no design document, focus file, route, or coverage ledger before its first round. Preflight supplies seed `0` unless committed routes require another shared seed. Testers begin at the opening turn and play without a map or answer key.

The first round can create the material that makes the second one deeper. When a session reaches a place worth revisiting, the round runs `bin/playtest-routes MyGame distill` on that session. Distill replays and shortens the recorded commands, then commits a route only after a cold replay reaches the same landing. Later rounds can use that route as a deep start instead of walking there again.

## Focus files and dependency updates

A focus file is optional. When you add one, put it in `docs/games/` and name it so that its filename, with punctuation and case ignored, is `<game>-playtest-focus`. For example, `My Game` can use `my-game-playtest-focus.md`. A name that does not fold to that form is treated as if no focus file exists, with no warning.

The harness comes from the resolved Gnusto dependency. `swift package update` can change it when it changes the engine, even if none of your game files changed. Record the resolved dependency when you compare rounds before and after an update.

## See also

- <doc:PlayTesting>
- <doc:TestingYourGame>
