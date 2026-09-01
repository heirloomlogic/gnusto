# Sharing Your Game

Turn a finished game into a single command-line binary you can hand to a friend.

## Overview

The person you want to play your game should not need Xcode, a toolchain, or any idea what SwiftPM is. This guide takes a game from *runs on my machine* to *one file that runs on somebody else's*, which is `bin/export-game` and a short conversation with Gatekeeper.

`bin/export-game` builds macOS only, because it builds on the machine you are standing at. Tagging a version gets both platforms: `.github/workflows/release.yml` builds every executable product for macOS and Linux and attaches them to the release. Neither path notarizes, so a downloaded macOS binary still has to be un-quarantined by hand.

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

Seven variables configure a running game, two report on one, and one replaces the game with a play-test server. All are optional — a game with none of them set behaves exactly as it always has.

| Variable | Effect |
|---|---|
| `GNUSTO_PLAIN` | Forces the plain ``ConsoleIOHandler`` even in a terminal. A flag, not a setting: *any* value counts, including an empty one. |
| `GNUSTO_SEED` | Pins the random stream to a whole number, so the whole session replays identically. Also seeds the test suite's unpinned `play(_:_:)` calls — see <doc:TestingYourGame#Sweep-for-tests-that-pass-by-luck>. |
| `GNUSTO_TRANSCRIPT` | Records the session from launch. `1`, `on`, `true` or `yes` writes a timestamped file; anything else is a slot name, or a path if it contains a `/`. |
| `GNUSTO_TRANSCRIPT_DIR` | Where slot-named transcripts go. Defaults to `<app support>/Gnusto/Transcripts/<game>`. Read whenever a transcript file is resolved, so it also applies to a `script` typed mid-session — not only at launch. |
| `GNUSTO_SAVE_DIR` | Where saves go. Defaults to `<app support>/Gnusto/Saves/<game>`. Point it somewhere disposable to keep a scripted run out of your real save slots. |
| `GNUSTO_STATUS` | Appends a `[status] room=… | moves=… | turn=cost\|free` line to every turn. Takes `1`/`0`, `on`/`off`, `true`/`false`, `yes`/`no`; anything else is a complaint on stderr rather than a guess. Read by ``GameMain`` and handed to ``REPL`` as an argument, not read from the environment down in the engine — so `GNUSTO_STATUS=1 swift test` changes nothing. See <doc:PlayTesting>. |
| `GNUSTO_PLAYTEST_DIR` | Where play-test sessions write. Defaults to `.context/playtest`. Same reason as `GNUSTO_SAVE_DIR`: a harness driving a checkout it doesn't own has to keep its output away from yours. |
| `GNUSTO_MCP_MAX_SESSIONS` | How many play-test sessions may hold a live world at once. Defaults to 32. Over the cap the oldest is evicted to its command list and replays itself on next use, so an evicted session answers exactly as it did before — it just costs more to ask. |
| `GNUSTO_STACK_REPORT` | Prints how much of the bootstrap's 16 MB stack the game's declarations actually used, one line per boot, on stderr. A flag, not a setting. Diagnostic — see <doc:SplittingAGameAcrossFiles#Split-for-reading-not-for-the-stack>. |
| `GNUSTO_MCP` | Serves the play-test protocol over stdio instead of playing, the same as the `--mcp` flag. A flag, not a setting. For a client that can set an environment but not an argument vector — see <doc:PlayTesting>. |

`GNUSTO_SEED` is what makes a bug report reproducible. Everything random in a game — combat rolls, roaming actors, ``oneOf(_:)`` prose — draws from one seeded stream, so a transcript recorded under a pinned seed replays turn for turn on any machine, and the command list drops straight into a `play(_:_:seed:)` test. See <doc:TestingYourGame> for the in-suite side of the same knob.

```sh
GNUSTO_SEED=0 GNUSTO_TRANSCRIPT=1 swift run Lighthouse
```

A value that isn't a whole number from 0 to 18446744073709551615 is reported on standard error and ignored, and the game seeds at random as usual. Silence would be worse than a complaint: the one thing the variable is for is reproducibility, so a typo that quietly handed back a random stream would defeat it.

Comments, `script`/`unscript` and the play-test server are the tester's other knobs. They belong to the front end rather than the environment, and they have their own page: <doc:PlayTesting>.

## How your prose is laid out

An ordinary newline inside a paragraph is a soft break and folds to a space; only a blank line starts a new paragraph. **Both** channels do this — the full-screen interpreter reflows the folded paragraph to the window width, and plain output prints it as one line for the terminal, pipe or file it lands in to handle. So write your `"""` literals hard-wrapped for whatever reads well in the editor: where you break a line is never where the player sees a break. You never need a trailing `\` and you never need `"…" + "…"`; interpolate into one literal and let the fold do its job.

Two ways to say you meant a break:

- **`<br>`** is a hard break *within* a paragraph — a banner's title above its tagline. The full-screen renderer honors it as a break; plain output turns it into a newline, so it never shows literally on either path.
- **Indent a line by two spaces** and it becomes a *form*: a sign, an inscription, a scrap of verse, a map legend. A form keeps its own line endings, its own inner spacing and its indentation, on both channels, and is only ever chopped if it is wider than the window.

See <doc:TextAndRandomness> for where game text like the startup banner is customized.

## Export a standalone binary

`bin/export-game` release-builds an executable product and copies the single binary into `dist/`:

```sh
bin/export-game Lighthouse   # → dist/Lighthouse
bin/export-game              # lists the available products
```

The script ships in `Templates/NewGame/bin/`, so a package copied out of the template already has it. It discovers the current package's executable products from its manifest, so it lists whatever your package ships — the seven demo games in the Gnusto repository, or your own game — with no edits. Under the hood it's `swift build -c release --product <Product>` followed by a copy of the built binary to `dist/<Product>` — no bundle, no installer, one file.

## Share it on macOS 15+

On macOS 15 or newer the binary dynamically links the Swift runtime that ships with the OS, so the file **is** the game: your friend runs it directly, with no Xcode and no Swift toolchain installed.

```sh
./dist/Lighthouse
```

The one wrinkle is Gatekeeper. A binary someone *downloads* is quarantined, and macOS will refuse to run it until that's cleared. The recipient can clear it themselves:

```sh
xattr -dr com.apple.quarantine ./Lighthouse
```

or you can ad-hoc sign the binary before sending it:

```sh
codesign -s - dist/Lighthouse
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
