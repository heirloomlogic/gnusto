# MyGame

A Gnusto game: one game struct, a library export, and transcript tests. Written by `bin/new-game`, so the name above and everything below already say your game's name.

```sh
swift test             # run the transcript tests
bin/run-game MyGame    # build and play the terminal development launcher
```

`Sources/MyGame/Packaged.swift` exports `public let game = PackagedGame { MyGame() }`. `gnusto-games.json` identifies the package, library product, module and exported value. The game has no maintained executable target: Gnusto's tools generate a launcher in an ignored build cache and combine the game library with the terminal front end.

To obtain the development executable's absolute path without launching it:

```sh
bin/build-game MyGame
```

Use the returned path, including when piping commands; its private launcher name is independent of the game name:

```sh
printf 'look\nquit\ny\n' | "$(bin/build-game MyGame)"
```

The tools require Swift 6.2 or newer and Node.js. For a coordinated prerelease checkout, set `GNUSTO_TERMINAL_PATH` to its `GnustoTerminal` checkout before running, exporting or preflighting the game.

## Let an agent play-test it

Run `bin/playtest-preflight MyGame`, then use `/playtest` in Claude Code. This package includes the skill, MCP registration, and tool settings. For a terminal dispatch, use `bin/playtest-preflight MyGame --headless`; findings stay in a report for review.

Automated rounds require Python 3 and an authenticated Claude Code installation with the `Workflow` tool, in addition to Swift, Node.js and Git. The [play-testing guide](docs/playtesting.md) covers setup, permissions, server restarts, and reading the report.

## The tools in `bin/`

The tools are shims over the resolved Gnusto checkout. Run `swift package resolve` once to resolve a version dependency. Updating Gnusto updates the tools too.

- `bin/run-game MyGame` builds and plays the generated terminal development launcher.
- `bin/build-game MyGame` prints the absolute path of that launcher; `--force` rebuilds it.
- `bin/gnusto-mcp MyGame` serves the game's MCP protocol on stdio; `.mcp.json` runs it for your client.
- `bin/playtest-preflight MyGame` checks the server and prepares the round arguments. Add `--headless` to dispatch through Claude Code.
- `bin/playtest-routes MyGame list` lists committed deep starts; `verify` replays them to check their landings.
- `bin/playtest-replay MyGame --commands probe.txt --seed 0 --label mine` replays a command list with a fixed random seed.
- `bin/playtest-measure .context/playtest/mine/probe-*` measures how much of the game the probes reached.
- `bin/export-game MyGame` builds a standalone binary under `dist/`, without the play-test server. Development launchers enable this package's `Playtest` trait and forward it to the engine; deployment launchers disable it through the graph and use a separate cache.

The generator refuses a released Gnusto that lacks the game factory, required tools or `Playtest` trait. Until a compatible release ships, generate with `--dep-path` pointing at the coordinated prerelease engine checkout. Path dependencies must provide the same factory, tools and trait.

## What this game already demonstrates

- A `Game` struct with rooms, items, a blocked exit, and scored victory
- A custom player-typeable verb (`ring`) and the rule that answers it
- A live `describe` description that reacts to game state
- A `PackagedGame` library export and explicit game catalog
- Transcript tests with `GnustoTestSupport` (`play` + `expectInOrder`)

## Publish binaries on a tag

`.github/workflows/release.yml` is already here. Once this package is at a repo root on GitHub, pushing a version tag builds the game for macOS and Linux and attaches the binaries to the release:

```sh
git tag 1.0.0
git push origin 1.0.0
```

The workflow discovers your games from `gnusto-games.json` and exports each library through the generated launcher flow.

With no further setup the macOS binaries are ad-hoc signed, and macOS refuses to open a downloaded copy until the player clears its quarantine flag. To publish notarized binaries that open on download, add a Developer ID certificate and an App Store Connect API key as repository secrets. The comment above the "Sign and notarize" step in the workflow lists the five secrets, and "Sharing Your Game" in Gnusto's DocC catalog walks through creating them.

The full authoring guides live in Gnusto's DocC catalog — start with "Getting Started with Gnusto".
