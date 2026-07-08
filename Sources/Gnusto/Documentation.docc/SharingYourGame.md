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

Run the game in a real terminal and ``GameMain`` reaches for the full-screen ``TerminalIOHandler``: a fixed status bar (room name, score, moves) above a story window that re-wraps the whole transcript to the window width — so **resizing the window reflows the text** — with its own line editor (arrow keys, input history, Home/End), and PageUp/PageDown scrollback. It's the classic Infocom interpreter feel, hand-rolled from `termios` and ANSI with no added dependencies.

That front end is chosen automatically, and only when it's safe:

- **Interactive terminal** (stdin *and* stdout are both a TTY) → ``TerminalIOHandler``.
- **Piped, redirected, or CI** → the plain ``ConsoleIOHandler``, so transcripts and scripted runs stay clean, escape-code-free text.
- **`GNUSTO_PLAIN=1`** in the environment forces the plain handler even in a terminal, for anyone who wants it.

```sh
swift run Zork1                     # full-screen interpreter
printf 'look\nquit\n' | swift run Zork1   # plain text, no escape codes
GNUSTO_PLAIN=1 swift run Zork1      # plain, even in a terminal
```

One caveat: `swift run` has been observed to interfere with stdin for this project, which the raw-mode interpreter is sensitive to. If interactive input misbehaves under `swift run`, run the built binary directly — `swift build && .build/debug/Zork1`, or the exported binary from the next section.

## The `<br>` hard-break marker

Because the interpreter reflows every paragraph to the current width, an ordinary newline inside a paragraph is treated as a soft break and folds to a space — only a blank line starts a new paragraph. That's what keeps prose authored as multi-line `"""` literals from shattering when the window is narrow.

For the rare *intentional* break within a paragraph — a banner's title above its tagline, a sign, a scrap of verse — write the `<br>` marker. The full-screen renderer honors it as a hard break; plain output turns it back into a newline, so it never shows literally on either path. See <doc:TextAndRandomness> for where game text like the startup banner is customized.

## Export a standalone binary

`bin/export-game` release-builds an executable product and copies the single binary into `dist/`:

```sh
bin/export-game Zork1        # → dist/Zork1
bin/export-game              # lists the available products
```

It knows the two demo products the package ships, `Zork1` and `CloakOfDarkness`. Under the hood it's just `swift build -c release --product <Product>` followed by a copy of the built binary to `dist/<Product>` — no bundle, no installer, one file.

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

### Current limits

This is a deliberately small first pass:

- **macOS only.** The export script produces a macOS binary. Cross-compiling a portable Linux binary from a Mac is impractical; producing Linux (and tagged macOS) release binaries belongs in a CI release workflow, which is planned but not yet built.
- **The two demo products.** `bin/export-game` targets `Zork1` and `CloakOfDarkness`; point it at your own executable product by adding it to the script's product list.
- **No notarization.** Real Apple notarization is out of scope — the Gatekeeper steps above are the supported way to share for now.
