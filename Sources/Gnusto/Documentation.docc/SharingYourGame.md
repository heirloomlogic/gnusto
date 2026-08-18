# Sharing Your Game

Turn a finished game into a single command-line binary you can hand to a friend.

## Overview

A Gnusto game is a Swift package, but the person you want to play it shouldn't need Xcode, a toolchain, or any idea what "SwiftPM" means. This guide takes a game from *runs on my machine* to *a single file that runs on a friend's Mac* — first by making the game a proper executable, then by giving it a polished terminal front end, and finally by exporting the release binary with `bin/export-game`.

The export path is intentionally small for a first pass: it builds a **macOS** binary for one of the demo products and prints exactly how to share it. Cross-platform Linux binaries and real notarization are noted here as future work, not yet built.

## Make a game runnable

An executable game is one type that conforms to both ``Game`` and ``GameMain``, marked `@main`. ``GameMain`` supplies the `main()` entry point — it boots a ``GameWorld`` from your game and drives it to completion — so you never write a `main.swift`:

```swift
import Gnusto

@main struct Zork1: Game, GameMain {
    let title = "Zork I: The Great Underground Empire"
    // rooms, items, map, rules…
}
```

When the game's declarations live in one place, `@main` sits right on the game type, as in `Sources/Zork1/Zork1.swift`. When you'd rather keep the entry point in its own file, put `@main` on a one-line conformance instead — `Sources/CloakOfDarkness/Entry.swift` does exactly that:

```swift
@main
extension OperaHouse: GameMain {}
```

Either way, the executable target in your `Package.swift` produces a binary you can run with `swift run`. If you started from `Templates/NewGame`, this is already wired up. New to Gnusto? Begin with <doc:GettingStarted>.

## What running gives the player

Run the game in a real terminal and ``GameMain`` reaches for the full-screen ``TerminalIOHandler``: a fixed status bar (room name, score, moves) above a story window that re-wraps the whole transcript to the window width — so **resizing the window reflows the text** — with its own line editor (arrow keys, input history, Home/End, bracketed paste), and PageUp/PageDown scrollback. It's the classic Infocom interpreter feel, hand-rolled from `termios` and ANSI with no added dependencies.

That front end is chosen automatically, and only when it's safe:

- **Interactive terminal** (stdin *and* stdout are both a TTY) → ``TerminalIOHandler``.
- **Piped, redirected, or CI** → the plain ``ConsoleIOHandler``, so transcripts and scripted runs stay clean, escape-code-free text.
- **`GNUSTO_PLAIN`** in the environment forces the plain handler even in a terminal, for anyone who wants it. See <doc:SharingYourGame#Environment-variables> for the full set.

```sh
swift run Zork1                     # full-screen interpreter
printf 'look\nquit\n' | swift run Zork1   # plain text, no escape codes
GNUSTO_PLAIN=1 swift run Zork1      # plain, even in a terminal
```

One caveat: `swift run` has been observed to interfere with stdin for this project, which the raw-mode interpreter is sensitive to. If interactive input misbehaves under `swift run`, run the built binary directly, or use the exported binary from the next section. Ask for the binary's location rather than assuming it — the directory differs between build systems, and a stale copy from an earlier run may be sitting in the other one:

```sh
swift build --product Zork1
"$(swift build --product Zork1 --show-bin-path)/Zork1"
```

## Environment variables

Five variables configure a running game, a sixth reports on one, and a seventh replaces the game with a play-test server. All are optional — a game with none of them set behaves exactly as it always has.

| Variable | Effect |
|---|---|
| `GNUSTO_PLAIN` | Forces the plain ``ConsoleIOHandler`` even in a terminal. A flag, not a setting: *any* value counts, including an empty one. |
| `GNUSTO_SEED` | Pins the random stream to a whole number, so the whole session replays identically. Also seeds the test suite's unpinned `play(_:_:)` calls — see <doc:TestingYourGame#Sweep-for-tests-that-pass-by-luck>. |
| `GNUSTO_TRANSCRIPT` | Records the session from launch. `1`, `on`, `true` or `yes` writes a timestamped file; anything else is a slot name, or a path if it contains a `/`. |
| `GNUSTO_TRANSCRIPT_DIR` | Where slot-named transcripts go. Defaults to `<app support>/Gnusto/Transcripts/<game>`. Read whenever a transcript file is resolved, so it also applies to a `script` typed mid-session — not only at launch. |
| `GNUSTO_SAVE_DIR` | Where saves go. Defaults to `<app support>/Gnusto/Saves/<game>`. Point it somewhere disposable to keep a scripted run out of your real save slots. |
| `GNUSTO_STACK_REPORT` | Prints how much of the bootstrap's 16 MB stack the game's declarations actually used, one line per boot, on stderr. A flag, not a setting. Diagnostic — see <doc:SplittingAGameAcrossFiles#Split-for-reading-not-for-the-stack>. |
| `GNUSTO_MCP` | Serves the play-test protocol over stdio instead of playing, the same as the `--mcp` flag. A flag, not a setting. For a client that can set an environment but not an argument vector — see [Serving the game to an agent](#Serving-the-game-to-an-agent). |

`GNUSTO_SEED` is what makes a bug report reproducible. Everything random in a game — combat rolls, roaming actors, ``oneOf(_:)`` prose — draws from one seeded stream, so a transcript recorded under a pinned seed replays turn for turn on any machine, and the command list drops straight into a `play(_:_:seed:)` test. See <doc:TestingYourGame> for the in-suite side of the same knob.

```sh
GNUSTO_SEED=0 GNUSTO_TRANSCRIPT=1 swift run Lighthouse
```

A value that isn't a whole number from 0 to 18446744073709551615 is reported on standard error and ignored, and the game seeds at random as usual. Silence would be worse than a complaint: the one thing the variable is for is reproducibility, so a typo that quietly handed back a random stream would defeat it.

Comments and `script`/`unscript` are the tester's other two knobs, and they belong to the front end rather than the environment — see the next section.

## Play-testing conveniences

Comments, paste-folding, and transcript recording are all front-end concerns: those lines never reach ``GameWorld``, so none of them costs a turn or moves the clock.

### Comments

A line whose first non-blank characters are `//` or `#` is a note, not a command. The story window shows it in dim italics and a running transcript records it, but the engine never sees it — no parse, no rules, no fuse or daemon. Comments also stay out of Up/Down recall, so the history stays a list of things the game actually ran.

### Pasting a note

In a terminal that supports bracketed paste, pasting a multi-line block into a line that already begins `//` or `#` folds it into one comment: every line break becomes a single space, and nothing is submitted until you press Return. Pasting into any other line still submits one command per line, so a walkthrough can be replayed by pasting it. Terminals without bracketed paste — the Linux console, or tmux without pass-through — behave as before, submitting one line at a time.

### Recording a transcript

`script` starts writing the session to a file and `unscript` stops; `script <name>` names it, and a name containing `/` or starting with `~` is treated as a path. To record from the opening text instead, set `GNUSTO_TRANSCRIPT` to a path, or to `1` for a timestamped file in the game's transcripts directory (`<app-support>/Gnusto/Transcripts/<title>/`, which `GNUSTO_TRANSCRIPT_DIR` overrides). A transcript is plain text — `> command` lines interleaved with the game's output, comments included — so a tester can attach one to a bug report.

### Serving the game to an agent

Every Gnusto game is also a play-test server. `GameMain` answers `--mcp` — or the `GNUSTO_MCP` environment variable, for a client that can set an environment but not an argument vector — by speaking the Model Context Protocol over stdio instead of playing. An agent opens a session, takes turns, reads back its own transcript, and is told what the game has shown it that it never followed up.

Nothing in your game has to know about this. The switch lives in the `GameMain` protocol extension every game already conforms to, so a game written by somebody who has never read this page becomes a server for the cost of a flag.

`bin/gnusto-mcp` is the launcher, and a copy ships in `Templates/NewGame/bin/`:

```sh
bin/gnusto-mcp MyGame
```

It builds the game, asks where the binary landed, and hands the process over. **Stdout is the protocol**, so the build's progress goes to stderr and nothing else is printed at all — which is also why the build isn't silenced, since a failing server's stderr is where a client shows you the compile error.

Register the game with a `.mcp.json` at your package root, one entry per game:

```json
{
  "mcpServers": {
    "mygame": { "command": "bin/gnusto-mcp", "args": ["MyGame"] }
  }
}
```

One binary is one game, so no tool ever takes a game name. If you copied `Templates/NewGame`, both files are already there and renaming the product in `.mcp.json` is the only edit.

Two things worth knowing before the first run. A cold start builds the game, which can take longer than a client's startup timeout — get the build out of the way once with `swift build`, or raise the timeout (`MCP_TIMEOUT`, in milliseconds); later runs are a no-op build and start immediately. And a project-scoped server is approved once, per project, on first use.

## The `<br>` hard-break marker

Because the interpreter reflows every paragraph to the current width, an ordinary newline inside a paragraph is treated as a soft break and folds to a space — only a blank line starts a new paragraph. That's what keeps prose authored as multi-line `"""` literals from shattering when the window is narrow.

For the rare *intentional* break within a paragraph — a banner's title above its tagline, a sign, a scrap of verse — write the `<br>` marker. The full-screen renderer honors it as a hard break; plain output turns it back into a newline, so it never shows literally on either path. See <doc:TextAndRandomness> for where game text like the startup banner is customized.

## Export a standalone binary

`bin/export-game` release-builds an executable product and copies the single binary into `dist/`:

```sh
bin/export-game Zork1        # → dist/Zork1
bin/export-game              # lists the available products
```

It discovers the current package's executable products from its manifest, so it lists whatever your package ships — the demo `Zork1` and `CloakOfDarkness` here, or the `MyGame` in a fresh `Templates/NewGame` copy, with no edits to the script. Under the hood it's just `swift build -c release --product <Product>` followed by a copy of the built binary to `dist/<Product>` — no bundle, no installer, one file.

## Share it on macOS 15+

On macOS 15 or newer the binary dynamically links the Swift runtime that ships with the OS, so the file **is** the game: your friend runs it directly, with no Xcode and no Swift toolchain installed.

```sh
./dist/Zork1
```

The one wrinkle is Gatekeeper. A binary someone *downloads* is quarantined, and macOS will refuse to run it until that's cleared. The recipient can clear it themselves:

```sh
xattr -dr com.apple.quarantine ./Zork1
```

or you can ad-hoc sign the binary before sending it:

```sh
codesign -s - dist/Zork1
```

## Publish binaries for a tag

`bin/export-game` only builds for the Mac you run it on. To publish binaries for both macOS and Linux, push a version tag. The release workflow (`.github/workflows/release.yml`) builds every executable product for macOS (arm64) and Linux (x86_64) and attaches them to the GitHub release for that tag:

```sh
git tag 1.0.0
git push origin 1.0.0        # → a release with runnable macOS + Linux binaries
```

The workflow reads your products from the manifest the same way `bin/export-game` does, so it needs no edits as products change. A copy ships with the starter template at `Templates/NewGame/.github/workflows/release.yml`: drop the NewGame folder at your repo root and tagging publishes your game unchanged.

In this repo the workflow excludes the `Zork1` demo, and the binaries it publishes exist to exercise the workflow, not to feature a game.

### Current limits

- **`bin/export-game` builds one product for one platform.** It exports a single executable product per run, for the Mac you run it on. Run it with no arguments to list your products, then name the one you want. For every product across both platforms, tag a release instead.
- **No notarization.** Real Apple notarization is out of scope; the Gatekeeper steps above are the supported way to share. The release binaries are ad-hoc signed, so a downloaded copy stays quarantined until the recipient clears it.
