# Gnusto

A Swift engine for parser-driven interactive fiction — text adventures in the tradition of Zork and Infocom's ZIL.

Gnusto turns a single Swift type into a playable text adventure. You *declare* your world — its rooms, its things, and the rules that govern them — and the engine parses player input, runs the turn, and prints the result.

## A tiny game

```swift
import Gnusto

struct TinyGame: Game {
    let title = "A Tiny Game"
    let intro = "You wake in a small, bright room."

    let room = Location {
        name("Bright Room")
        description("A plain white room with a single door, to the north.")
    }

    let coin = Item {
        name("gold coin")
        description("A heavy gold coin.")
    }

    var map: WorldMap {
        room.north(blocked: "The door is locked.")
        player.starts(in: room)
        coin.starts(in: room)
    }
}
```

That is a complete game. The player can `look`, `examine coin`, `take coin`, check their `inventory`, and try to go `north`. See the [Getting Started](Sources/Gnusto/Documentation.docc/GettingStarted.md) guide to build one from scratch, or copy the ready-to-run package in [`Templates/NewGame`](Templates/NewGame).

## Run and play

The package ships three demo games as executables. Run any of them with SwiftPM:

```sh
swift run CloakOfDarkness   # the minimal benchmark — three rooms
swift run Lighthouse        # the feature tour — see below
swift run Zork1             # the full 350-point reconstruction
```

They form a ladder. **Cloak of Darkness** is the smallest complete game. **The Lighthouse** is the feature tour: one small, winnable game whose every piece demonstrates an idiom you reach for early — containers and surfaces, a locked door, a fuse and a daemon, a roaming character, `@Global` state, a content bundle, and the scoring and actor plugins. **Zork1** is the whole thing. The Lighthouse is the one to read after [Getting Started](Sources/Gnusto/Documentation.docc/GettingStarted.md) — the guides it maps to link back to it.

In a real terminal this launches a full-screen, Infocom-style interpreter — a status bar (room, score, moves) above a story window that re-wraps as you resize, with arrow-key line editing, input history, and scrollback. Piped or redirected runs (and CI) fall back to plain text automatically; `GNUSTO_PLAIN=1` forces plain output in a terminal too.

## Share your game

Make a game a runnable executable by conforming its type to `GameMain` and marking it `@main` — no `main.swift` required. Then export a single binary you can hand to a friend:

```sh
bin/export-game Zork1        # → dist/Zork1
```

On **macOS 15+** the binary links the Swift runtime that ships with the OS, so the recipient runs `./dist/Zork1` directly — no Xcode, no toolchain. A downloaded binary is quarantined by Gatekeeper; clear it with `xattr -dr com.apple.quarantine ./Zork1`, or ad-hoc sign before sharing (`codesign -s - dist/Zork1`).

This first pass is macOS-only (Linux release binaries via CI are planned) and skips real notarization. The full workflow — the `TerminalIOHandler`, the `<br>` marker, and the export limits — is in [Sharing Your Game](Sources/Gnusto/Documentation.docc/SharingYourGame.md).

## Documentation

The full authoring guides live in Gnusto's DocC catalog — start with **Getting Started with Gnusto**. CI publishes the rendered docs to GitHub Pages on each version tag (see [`.github/workflows/documentation.yml`](.github/workflows/documentation.yml)).

Build the docs locally:

```sh
touch .dev-tooling   # enables the dev-only swift-docc-plugin
swift package --allow-writing-to-directory ./docs \
  generate-documentation --target Gnusto --output-path ./docs
```

## Requirements

- macOS 15 or newer (the engine uses `Synchronization.Mutex`)
- Swift 6.2 toolchain, Swift 6 language mode

## Attribution

The bundled **Zork1** demo is an original Swift re-implementation of *Zork I: The Great Underground Empire* (Marc Blank, Dave Lebling, Bruce Daniels, and Tim Anderson; Infocom, 1980). Its room descriptions, object descriptions, and messages reproduce text from the original Zork I source, drawn from the publicly available [historicalsource/zork1](https://github.com/historicalsource/zork1) collection. Included for education, discussion, and historical work — see [`THIRD_PARTY_NOTICES`](THIRD_PARTY_NOTICES) for full credits and license.
