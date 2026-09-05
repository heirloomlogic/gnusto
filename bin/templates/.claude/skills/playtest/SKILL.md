---
name: playtest
description: Run an automated play-test round against this package's Gnusto game, inspect its transcript, and report reproducible prose defects. Use when asked to playtest or play-test the game, or reproduce a reported transcript defect.
---

# Play-test MyGame

Work from the game package root. Read `docs/playtesting.md` for prerequisites and troubleshooting.

1. Run `bin/playtest-preflight MyGame` (or the executable product the user named). Stop on a failed check and report the remedy it prints.
2. Read `.context/playtest-round-args.json` into `args`. Keep every generated field, including `roundId`, `tracker`, and the package layout. Do not assume this package has design documents, committed routes, or a GitHub tracker.
3. Dispatch using the workflow path preflight resolved:

```javascript
Workflow({ scriptPath: args.workflowPath, args })
```

The workflow and its references belong to the Gnusto dependency. Use `args.workflowPath` and `args.refPath`; do not copy the engine's workflow into this package or guess its checkout path.

If the current session has no `Workflow` tool, run `bin/playtest-preflight MyGame --headless`. This starts `claude -p`; that installation must itself provide `Workflow`. Headless rounds write findings into the report with `tracker: false` and do not create GitHub issues. Report a missing tool or denied operation as a failed dispatch; do not invent a substitute round or claim success.

Write the returned report and ledger using the package layout and report instructions returned by the workflow. When `tracker` is false, preserve the proposed issue body in the report. When it is true, search for an existing round issue with `gh issue list` and obtain approval before creating one. A round with no confirmed findings needs no issue. Play-testing reports defects; it does not fix the game.

Verify any routes the round creates with `bin/playtest-routes MyGame verify` before committing them with the report. Preflight defaults `roundId` to today's local date. For a separate interactive round on the same day, give it a distinct suffix before dispatch. Artifacts with different round IDs do not need clearing.
