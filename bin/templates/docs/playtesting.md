# Play-testing MyGame

An automated round sends agents through the game, checks their findings against replayed transcripts, and returns a report. It needs Swift 6.2 or newer, Git, Node.js, Python 3, and an authenticated Claude Code installation that provides the `Workflow` tool. Keep `node`, `python3`, and `claude` on your PATH. GitHub CLI is optional; without a tracker, findings stay in the report.

## Start a round

From this package's root:

```sh
swift build
bin/playtest-preflight MyGame
```

Preflight builds the game, checks its MCP server over a separate connection, checks route manifests and seed agreement, and writes `.context/playtest-round-args.json`. Fix a failed check before dispatching.

In Claude Code, `/playtest` uses the skill shipped in `.claude/skills/playtest/SKILL.md`. The agent reads the JSON into `args` and calls:

```javascript
Workflow({ scriptPath: args.workflowPath, args })
```

Use the whole JSON object. The workflow lives in the resolved Gnusto dependency, so its path can change when that dependency moves. Optional design documents and routes are discovered by preflight; neither is required for a first round.

For a terminal dispatch:

```sh
bin/playtest-preflight MyGame --headless
```

This runs `claude -p` with explicit tool permissions and no permission prompts. The Claude installation still needs `Workflow`; an allowlist cannot add a missing tool. Headless rounds set `tracker: false` and keep proposed issue bodies in the report for you to review. They do not file issues. A denied operation or missing tool must be reported as a failure.

Interactive rounds may use a GitHub tracker when `gh repo view` succeeds. Settings allow issue searches and require approval for `gh issue create`. Review the proposed issue before approving it.

## When a round cannot start

- A connected MCP server keeps running the binary it started with. After changing the engine's play-test code, rebuild with preflight and restart the MCP session; the existing connection cannot pick up the new binary.
- If `ToolSearch` finds no `mcp__mygame__*` tools, check the server connection and `.mcp.json` registration. Rewriting a tester's prompt will not register a missing server. Run preflight, retry the connection, then restart the session if necessary.
- The MCP client may ask once to approve this package's server. The first build can exceed its startup timeout. Preflight builds ahead of the connection; `.claude/settings.json` supplies a 180-second timeout.

## Focus and round artifacts

A focus file splits blind and sighted instructions with two `---` rules. The text between them reaches blind testers verbatim. Everything below the second rule is sighted-only: put walkthrough answers, ledger verdicts, and the room a deep route lands in there. Blind regions may name the route to use and its approximate depth, but must not reveal its landing.

`roundId` is required, and the workflow uses it to separate session labels and counts. Preflight defaults to today's local date, so headless dispatches for the same game on the same day share an ID. For a separate interactive round that day, give `args.roundId` a distinct suffix before dispatching. Earlier rounds with different IDs do not need clearing.

Transcripts, probes, and staged saves live under `.context/playtest/`, which this package's `.gitignore` already keeps out of version control along with `.build/` and `dist/`. Reports and ledgers belong with the game's documents. Routes under `.playtest/MyGame/routes/` should be committed: a fresh checkout needs their commands to reproduce a deep start. Run `bin/playtest-routes MyGame verify` before committing routes returned by a round.

The report preserves confirmed and refuted findings and any proposed issue body. Review it before changing the game; the round itself makes no game fixes.
