# One Checkout, Two Roots: Packaging the Play-Test Round

**Date:** 2026-09-01

**Status:** Approved in discussion; spec pending review

**Issue:** #368, scope items 1, 4, 5 and 6, plus what item 3 left behind

## Problem

A downstream author with their own package — call the game `Zwank` — should be able to say `playtest Zwank` and get the round this repository gets. `Sources/Gnusto/Playtest/` already ships inside the library target and `GameMain.main()` already answers `--mcp`, so `@main struct Zwank: Game, GameMain {}` is already a fourteen-tool play-test server. The gap has always been distribution, not capability.

Two of #368's six items have closed it halfway. Item 2 (PR #384) replaced `Templates/NewGame/` with `bin/templates/` and `bin/new-game`, and gave a generated package *shims* rather than copies: `bin/lib/gnusto-tooling.sh` finds the Gnusto checkout by three filesystem probes and runs `GNUSTO_PACKAGE_PATH="$pkg" exec "$repo/bin/$tool"` after `cd "$pkg"`, so nothing in an author's `bin/` has a version of its own. Item 3 (PR #387) gave `.claude/workflows/playtest.js` four layout arguments — `projectName`, `enginePath`, `conventionsPath`, `gameDocsDir` — each defaulted to this repository's value, so a round can be told the package's shape instead of assuming this one.

What is left is the front door and everything an agent reads.

`bin/playtest-preflight` cannot be shimmed. `bin/lib/playtest-focus.js:31` anchors `ROOT` to the *engine's* root and `bin/playtest-preflight:46` chdirs to it, so a shimmed preflight would build the engine, read the engine's `.mcp.json`, and write round arguments about a package the author does not have. `bin/playtest-routes` cannot be shimmed for the same one reason — which means a downstream round can play, and can distil, and can never commit what it learned. The promise SKILL.md makes to a new author, that "a downstream author on day one has no walkthrough and never will; they run a round, and the second one is faster than the first without their having written anything", is true of the design and false of the shipped code.

`.claude/skills/playtest/SKILL.md` assumes `docs/games/` throughout, runs `gh issue list` against *this* tracker, and lists every `bin/` script by path — four of which a generated package does not have. And there is no author-facing article on running a round at all: `PlayTesting.md` documents the instruments and stops there, because until now the round was not something an author could reach.

## Design

### Two roots, one of which is new

`GNUSTO_PACKAGE_PATH` is already the contract. `bin/export-game:21` and `bin/gnusto-mcp:67` both read `${GNUSTO_PACKAGE_PATH:-$(dirname "$0")/..}`, because under a shim's `exec` a `$0`-derived root lands in the engine rather than in the author's package. The node side needs the same move, plus a distinction the current code does not draw.

Two families of path are conflated in `ROOT` today:

| Family | Members | Whose |
|---|---|---|
| package-relative | `.mcp.json`, `.claude/settings.json`, `docs/games/`, `.playtest/`, `.context/`, `bin/gnusto-mcp`, `bin/playtest-replay`, `swift package describe`'s cwd | the author's game |
| engine-relative | `.claude/workflows/playtest.js`, `.claude/skills/playtest/references/` | the harness itself |

**Nothing in `bin/lib/playtest-focus.js` is engine-relative.** Every one of its six `ROOT` consumers — `read`, `gameDoc`, `routeManifests`, `describePackage`, `SCRATCH` and `routesDir` — wants the package. That is why one line unbinds the module:

```js
const ROOT = process.env.GNUSTO_PACKAGE_PATH
  ? path.resolve(process.env.GNUSTO_PACKAGE_PATH)
  : path.resolve(__dirname, '..', '..')
```

`bin/playtest-preflight` then needs a second constant, `ENGINE = path.resolve(__dirname, '..')`. `__dirname` is always the engine's `bin/`, because a shim `exec`s the engine's copy of the script — which makes `ENGINE` the checkout SwiftPM actually resolved, by construction rather than by search. It serves the three sites that mean the harness rather than the package: the `--headless` prompt at `:618`, the printed dispatch banner at `:628-629`, and the two new arguments below.

In this repository the two roots are equal and every generated prompt is byte-identical. That is the property the whole design rests on, and the check for it is the one PR #387 used: diff the dry run's `/tmp/prompts.txt` dump against the pre-change one.

The recursion terminates at depth one and there is no double-`cd`. A shim `exec`s `$repo/bin/$tool`, and `$repo` is never `$pkg` because `gnusto_is_checkout` requires `Sources/Gnusto`. `bin/playtest-replay` is already fully unbound — `invocation_dir` captured at `:170`, `pkg` restored at `:204` — and is the model for the rest. Its `--start` has always read the *game's* `.playtest/<Game>/routes/`, because `bin/lib/playtest-route-prefix.js:44` takes the package as its root and never consults `ROOT` at all. What was missing downstream was not the reader; it was the producer.

### What preflight derives

`roundArgs()` stops hardcoding this repository's layout and derives it, with derivations that return this repository's current values when run here:

| Arg | Derivation | This repo | A generated package |
|---|---|---|---|
| `projectName` | the manifest's `name` | `Gnusto` | `Zwank` |
| `enginePath` | `ENGINE === ROOT ? 'Sources/Gnusto' : path.join(ENGINE, 'Sources/Gnusto')` | `Sources/Gnusto` | absolute, into the checkout |
| `conventionsPath` | `CLAUDE.md` under `ROOT`, else `''` | `CLAUDE.md` | `''` |
| `gameDocsDir` | `docs/games` if the directory exists, else `''` | `docs/games` | `docs/games` |
| `gameSourceDir` | `Sources/<game>` if present, else the matching target's `path`; a red row if neither resolves | `Sources/Fulminate` | `Sources/Zwank` |
| `refPath` | `ENGINE === ROOT` ? the relative path : `path.join(ENGINE, …)` | `.claude/skills/playtest/references` | absolute |
| `workflowPath` | always `path.join(ENGINE, '.claude/workflows/playtest.js')` | absolute | absolute |
| `tracker` | `gh repo view` exits 0 at `ROOT` | `true` | usually `false` |

`projectName` becomes the bare manifest name, so every prompt reads "for the Gnusto repo" where it read "for the Gnusto engine repo". That is a deliberate one-word change across the whole prompt surface, and the dry run's assertions move with it in the same commit rather than being worked around.

`gameSourceDir` fails loudly rather than defaulting. A wrong game source path does not produce an error; it produces a plausible round whose clusterer cites declarations in files nobody has.

`tracker` is printed as a dim note and never as a check row. A package with no tracker is a perfectly good state, and a red row for it is a row an operator learns to skip past — the argument `focusRows` already makes for failing open. It degrades to `false` on `ENOENT` as readily as on a non-zero exit, because the container CI runs in has no `gh` at all.

### The fifth hardcoded site

#368 named four places where `playtest.js` assumes this repository and item 3 unbound three of them. The survey missed two more, and the second is the sharper.

`REF = '.claude/skills/playtest/references'` at `:186` is engine-relative and reaches four prompts. It becomes `refPath`.

The clusterer prompt at `:1691` tells its agent to `grep -rn` a fragment of the excerpt under `${pkg}/Sources/`. Downstream the engine sits at `.build/checkouts/Gnusto/Sources/Gnusto`, which is not under `Sources/` — so a downstream round's clusterer physically cannot locate an engine-owned string, returns `unlocated`, and every engine-owned finding loses its dedup key. Two findings quoting one sentence then become two defects, and the round reports more distinct classes than it found. It greps both `${pkg}/${gameSourceDir}` and `${enginePath}`.

`ownerClass`'s surviving `Tests/` and `docs/playtesting.md` literals stay. `Tests/` is SwiftPM's default layout and `bin/new-game` writes it; `docs/playtesting.md` never matches downstream and is harmless. Both get a line of comment saying so, because unexplained residue reads as an oversight.

### The skill, and why it is not a plugin

The delivery vehicle was recorded as settled in `2026-09-01-new-game-generator-design.md:115` — "a Claude Code plugin with a marketplace manifest". **This spec reverses that.** The note was written beside the shim mechanism, before it had been used, and the mechanism changes the answer: a SwiftPM git checkout is the whole repository, so `.build/checkouts/Gnusto/.claude/workflows/playtest.js` and `.../references/` are already on the author's disk the moment `swift build` has run. A plugin would carry a second copy of files that are already there, on a second version axis, behind an install story — to buy discoverability in a session that is not in the author's package, which is not where anyone play-tests.

So `bin/new-game` writes `.claude/skills/playtest/SKILL.md`, and it is thin on purpose. Its whole content is two commands and where the answers come from:

1. `bin/playtest-preflight <Game>` — builds, proves the server answers, writes `.context/playtest-round-args.json`.
2. `Workflow({ scriptPath: <the workflowPath in that JSON>, args: <that JSON> })`.
3. Afterwards: the report at `gameDocsDir`, the routes to verify and commit, and the issue — filed when `tracker`, written into the report when not.

Everything with doctrine in it stays single-sourced in the checkout, and the file says so: the judgement kernel, the finding contract and the report shape are the briefs at `refPath`, and copying them here is the drift `gnusto-tooling.sh` exists to prevent. Charters, schemas, calibration and the focus-file rules are not in it either. Forty lines rot slowly, and CI exercises both of its commands.

The template also gains `.claude/settings.json`, without which a generated package fails preflight's `mcp key` row on arrival. It carries `enabledMcpjsonServers`, a `permissions.allow` for the tools a round runs, and the `MCP_TIMEOUT` / `CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS` pair — both load-bearing, because `preflight:622` spreads the *package's* env into `claude -p`, so without them a downstream headless round dies at six hundred seconds at whatever phase it had reached, silently. `bin/new-game`'s existing lowercase substitution names the server key for free.

And it gains `docs/games/.gitkeep`, so the report, the ledger and a future design doc have the home the artifact shapes name. Deliberately not a stub `<game>.md`: a design doc that says nothing real would still be handed to the verifiers as a mechanics contract, and "There is NO design doc" is the honest day-one branch and the well-tested one.

### The artifact shapes

`report-shape.md` and `issue-shape.md` are read by agents directly, so their `docs/games/…` paths and their `gh` blocks are the last two places the round assumes this repository. The two artifact rows become `<gameDocs>/…` with the reporter's prompt stating the round's value, and the issue step branches on `tracker`: with a tracker, one issue per round per game, searched before created; without one, the same body under its own heading in the report. Same shapes, one branch, nothing dropped.

## Testing

`Tests/GnustoTests/NewGameTests.swift` gains the two new shims in its existing loop — which already asserts the executable bit, the `source` line and that the last line is exactly `gnusto_exec <tool> "$@"`, the copy-paste failure that would otherwise ship a routes shim dispatching replay. It gains `.claude/settings.json` in `namedFiles`, so the `MyGame`/`mygame` sweep actually opens it, and a test asserting the *pair* preflight checks: the single `.mcp.json` key equals the single `enabledMcpjsonServers` entry equals the lowercased game name.

One node-level test pins the line the whole design rests on — `require('bin/lib/playtest-focus').ROOT`, with and without `GNUSTO_PACKAGE_PATH` — in under a second and with no toolchain, guarded on `node` being present the way `bin/playtest-replay` guards `--start`. Everything heavier belongs to CI: `PlaytestPathTests.swift:13-20` records why the suite refuses to run `swift`, and preflight's first act is a real build.

`playtest.dryrun.mjs`'s downstream scenario gains assertions for both new arguments, each paired with a positive check — every "does not contain" in that block can pass by the prompts having gone empty. Its `gameSourceDir` fixture is monorepo-shaped rather than `Sources/Zwank`, because the natural spelling is what a *correct* round prints and an assertion against it would fail on success. The static `ownerClass` check widens from three literals to include `Sources/` outright, since a prompt-text assertion cannot see a function that prints nothing. And the default `refPath` is checked to name a directory that actually holds `finding-contract.md` — once a default is the only thing tying every prompt to those files, a typo ships prompts citing a brief that does not exist while every existing assertion stays green.

## CI

A third job, `generated-round`, in the same `swift:6.3.3-noble` container plus `actions/setup-node`. It runs `bin/playtest-preflight Scratch` inside a freshly generated package and asserts over the arguments file that the layout was derived and not assumed, and that `enginePath`, `refPath` and `workflowPath` all point into the engine checkout.

Its own job rather than a step in `test-linux`, for the reason `harness.yml:9-11` already gives: that container ships no Node, and adding a runtime to the job that runs the whole suite is a cost the suite should not carry. The one command exercises the shim, `gnusto_find_repo`, the build, a live MCP handshake over a pipe, `open`/`survey`/`finish`/`replay`, the `closing.json` field check, `.mcp.json` against `.claude/settings.json`, and the arguments derivation — which is the whole chain, and the only check that can say a downstream round is dispatchable.

Every row should be green. `routes`, `ledger` and the two `focus` rows produce no row at all for a package with no `.playtest/` and no game doc, which is exactly the day-one state this design is for.

## Documentation

`PlayTestingYourOwnGame.md` is the author-facing counterpart to the maintainer-facing `docs/playtesting.md`. `PlayTesting.md` covers the instruments; this covers the round, which is the thing an author currently cannot discover: what it costs, the two commands, the arguments and what they mean, and the day-one shape — no design doc, no focus file, no routes, no ledger, seed 0, testers playing cold, and the round's own Distill output becoming round two's deep starts. It carries the two traps worth knowing in advance: a focus file at a path that does not fold to `<game>-playtest-focus` yields `null` in silence, and `swift package update` moves the harness with the engine, so a round before and after can differ with nothing in the package's diff to show it.

`PlayTesting.md`'s "has all three" paragraph becomes five and links out; `Documentation.md` and `README.md` gain the same.

## Out of scope

Four defects the survey turned up, all real today, none of them #368's business. Each has its own issue:

- **#389** — `bin/playtest-routes` is not in this repository's `.claude/settings.json` allowlist, so every Distill phase stalls on a permission prompt.
- **#390** — `bin/templates/` ships no `.gitignore`, so a generated package tracks `.build/`, `.context/` and `dist/` — while `playtest.js:397` tells every agent that `.context/playtest/` is gitignored.
- **#391** — `bin/playtest-preflight`'s `capabilitiesOf` walks the target graph from the *product* name. Product equals target for every game here, so it is invisible; downstream it yields `capabilities: []` with no diagnostic.
- **#392** — `bin/new-game Gnusto` produces a package that satisfies `gnusto_is_checkout`, which under `GNUSTO_REPO` is an infinite `exec` loop.
