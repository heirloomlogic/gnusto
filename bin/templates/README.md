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

`.mcp.json` and `bin/gnusto-mcp` are already wired up: your game is an MCP play-test server, and an agent can open a session, take turns, and read back what the prose actually printed. Nothing in your game has to know about it — `GameMain` answers `--mcp` for every Gnusto game, yours included.

An MCP client asks once to approve a project-scoped server, then runs `bin/gnusto-mcp MyGame` itself; stdout is the protocol. The first run builds, which can outlast a client's startup timeout — run `swift build` once first, or raise the client's timeout (`MCP_TIMEOUT`, in milliseconds).

## The tools in `bin/`

`bin/export-game`, `bin/playtest-replay` and `bin/playtest-measure` are shims. The real scripts live in the Gnusto checkout this package depends on, so they are never out of step with the engine — `swift package update` moves both together. They need Gnusto resolved, so run `swift build` once before the first one.

- `bin/export-game MyGame` builds a standalone binary under `dist/` you can hand to a friend.
- `bin/playtest-replay MyGame --commands probe.txt --seed 0 --label mine` replays a command list with the random seed pinned, so a hand-played session reproduces exactly.
- `bin/playtest-measure .context/playtest/mine/probe-*` reports how much of the game a round actually reached.

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
