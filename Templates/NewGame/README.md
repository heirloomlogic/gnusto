# NewGame — a starter Gnusto package

A complete, ready-to-copy game package: one game struct, an executable entry
point, and a transcript test. Copy it out, rename it, and start writing rooms.

## Start your own game from this template

1. Copy the directory anywhere outside the Gnusto repo:

   ```sh
   cp -R Templates/NewGame ~/Projects/MyGame
   ```

2. In your copy's `Package.swift`, replace the local path dependency with the
   git URL (the commented-out line above it).

3. Rename `MyGame` to taste — the package name, the two target names, the
   `Sources/MyGame` and `Tests/MyGameTests` directories, the struct, and the
   product name in `.mcp.json`.

Then:

```sh
swift test        # run the transcript tests
swift build       # build the game
```

Run the built binary directly to play (piping input through `swift run`
swallows stdin during the build):

```sh
"$(swift build --show-bin-path)/MyGame"
```

## Let an agent play-test it

`.mcp.json` and `bin/gnusto-mcp` are already wired up: your game is an MCP
play-test server, and an agent can open a session, take turns, and read back
what the prose actually printed. Nothing in your game has to know about it —
`GameMain` answers `--mcp` for every Gnusto game, yours included.

An MCP client asks once to approve a project-scoped server, then:

```sh
bin/gnusto-mcp MyGame      # what the client runs; stdout is the protocol
```

The first run builds, which can outlast a client's startup timeout. Run
`swift build` once first, or raise the client's timeout (`MCP_TIMEOUT`, in
milliseconds).

## Replay a script instead

For a probe you want to run again tomorrow and get the same prose back,
`bin/playtest-replay` plays a command file with the random seed pinned and writes
the transcript to disk:

```sh
bin/playtest-replay --build MyGame                          # once, separately
bin/playtest-replay MyGame --commands probe.txt --seed 0 --label mine --tail 40
```

Building is a separate step on purpose: a replay that also builds cannot be
trusted to have replayed the same binary twice. Output lands under
`.context/playtest/<label>/<probe>/` as `transcript.txt`, `commands.txt`,
`stderr.txt` and `summary.txt`, and `bin/playtest-measure` reads one of those
directories back and reports what the run covered — rooms entered, distinct
verbs, objects examined, objects touched and then looked at again:

```sh
bin/playtest-measure .context/playtest/mine/probe-001
```

The one flag that does not work here is `--start`, which plays a committed route
before your commands. Routes are cut by tooling that lives in the Gnusto
repository; this package refuses the flag rather than failing obscurely.

## What the template demonstrates

- A `Game` struct with rooms, items, a blocked exit, and scored victory
- A custom player-typeable verb (`ring`) and the rule that answers it
- A live `describe` description that reacts to game state
- The `@main` entry point via `GameMain`
- Transcript tests with `GnustoTestSupport` (`play` + `expectInOrder`)

## Hand the game to a friend

`bin/export-game` release-builds a product and copies the single binary into
`dist/`:

```sh
bin/export-game MyGame     # → dist/MyGame
bin/export-game            # lists this package's executable products
```

It reads the products out of your `Package.swift`, so renaming the game needs no
edits to the script. On macOS 15+ the binary links the Swift runtime that ships
with the OS, so the recipient runs the one file with no Xcode and no toolchain —
though a downloaded binary stays quarantined until they clear it, which the
script's closing note spells out.

## Publish binaries on a tag

`.github/workflows/release.yml` ships with this template. Once your copy is at a
repo root on GitHub, pushing a version tag builds your game for macOS and Linux
and attaches the binaries to the release:

```sh
git tag 1.0.0
git push origin 1.0.0
```

It discovers your executable products automatically, so it needs no edits.

The full authoring guides live in Gnusto's DocC catalog — start with
"Getting Started with Gnusto".
