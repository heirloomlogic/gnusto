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
   `Sources/MyGame` and `Tests/MyGameTests` directories, and the struct.

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

## What the template demonstrates

- A `Game` struct with rooms, items, a blocked exit, and scored victory
- A custom player-typeable verb (`ring`) and the rule that answers it
- The `@main` entry point via `GameMain`
- Transcript tests with `GnustoTestSupport` (`play` + `expectInOrder`)

The full authoring guides live in Gnusto's DocC catalog — start with
"Getting Started with Gnusto".
