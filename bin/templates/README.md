# MyGame

A Gnusto game: one game struct, an executable entry point, and transcript tests. Written by `bin/new-game`, so the name above and everything below already say your game's name.

```sh
swift test        # run the transcript tests
swift build       # build the game
```

Run the built binary directly to play — piping input through `swift run` swallows stdin during the build:

```sh
"$(swift build --show-bin-path)/MyGame"
```

## Let an agent play-test it

Run `bin/playtest-preflight MyGame`, then use `/playtest` in Claude Code. This package includes the skill, MCP registration, and tool settings. For a terminal dispatch, use `bin/playtest-preflight MyGame --headless`; findings stay in a report for review.

Automated rounds require Node.js, Python 3, and an authenticated Claude Code installation with the `Workflow` tool, in addition to Swift and Git. The [play-testing guide](docs/playtesting.md) covers setup, permissions, server restarts, and reading the report.

## The tools in `bin/`

All six tools are shims over the resolved Gnusto checkout. Run `swift build` once to resolve the dependency. Updating Gnusto updates the tools too.

- `bin/gnusto-mcp MyGame` serves the game's MCP protocol on stdio; `.mcp.json` runs it for your client.
- `bin/playtest-preflight MyGame` checks the server and prepares the round arguments. Add `--headless` to dispatch through Claude Code.
- `bin/playtest-routes MyGame list` lists committed deep starts; `verify` replays them to check their landings.
- `bin/playtest-replay MyGame --commands probe.txt --seed 0 --label mine` replays a command list with a fixed random seed.
- `bin/playtest-measure .context/playtest/mine/probe-*` measures how much of the game the probes reached.
- `bin/export-game MyGame` builds a standalone binary under `dist/`.

If the generator warns about the pinned Gnusto version, use a release containing the required tools or regenerate with `--dep-path` pointing at a current engine checkout. `swift package update` can select a compatible newer release once one exists.

## What this game already demonstrates

- A `Game` struct with rooms, items, a blocked exit, and scored victory
- A custom player-typeable verb (`ring`) and the rule that answers it
- A live `describe` description that reacts to game state
- The `@main` entry point via `GameMain`
- Transcript tests with `GnustoTestSupport` (`play` + `expectInOrder`)

## Publish binaries on a tag

`.github/workflows/release.yml` is already here. Once this package is at a repo root on GitHub, pushing a version tag builds the game for macOS and Linux and attaches the binaries to the release:

```sh
git tag 1.0.0
git push origin 1.0.0
```

It discovers your executable products from the manifest, so it needs no edits as they change.

The full authoring guides live in Gnusto's DocC catalog — start with "Getting Started with Gnusto".
