# Getting Started with Gnusto

Build and run your first text adventure, one piece at a time.

## Overview

![A lantern lights an open stone doorway and the stairs beyond.](getting-started.png)

By the end of this guide you will have a game with two rooms, one object, one rule, and a test that plays it. It assumes you can write basic Swift; it assumes nothing about interactive fiction.

Prefer to start from something that already runs? `bin/new-game Zwank ~/dev/Zwank --dep-path /path/to/Gnusto` writes a complete starter package named for your game — then skim this guide for the *why* behind each piece.

## Add Gnusto to your package

These articles describe the coordinated packaging migration. Until a compatible Gnusto release includes `PackagedGame` and the generated build tools, point `bin/new-game` at this checkout with `--dep-path`. The generator refuses an incompatible release before writing a package.

Add Gnusto to your game library and keep `GnustoTestSupport` in its test target. A generated starter supplies this manifest, its game catalog and tool shims:

```swift
// swift-tools-version: 6.2
import PackageDescription

let forwarded: Set<Package.Dependency.Trait> = [
    .trait(name: "Playtest", condition: .when(traits: ["Playtest"]))
]
let package = Package(
    name: "MyGame",
    platforms: [.macOS(.v15)],
    products: [.library(name: "MyGame", targets: ["MyGame"])],
    traits: [
        .trait(name: "Playtest", description: "Enable development MCP launch."),
        .default(enabledTraits: ["Playtest"]),
    ],
    dependencies: [.package(name: "Gnusto", path: "/path/to/Gnusto", traits: forwarded)],
    targets: [
        .target(name: "MyGame", dependencies: [.product(name: "Gnusto", package: "Gnusto")]),
        .testTarget(name: "MyGameTests", dependencies: [
            "MyGame", .product(name: "GnustoTestSupport", package: "Gnusto"),
        ]),
    ]
)
```

Gnusto needs a Swift 6.2 toolchain and the Swift 6 language mode. The `.macOS(.v15)` floor above is `Synchronization.Mutex`; Linux is tested in CI and needs no platform line. iOS is supported too, at `.iOS(.v18)` for the same reason. Add that line if your game is an app rather than a terminal program, and give it an ``IOHandler`` of its own — see <doc:CustomFrontEnds>.

## Declare a game

A game is a single type conforming to ``Game``. Start with just a title and an intro:

```swift
import Gnusto

struct MyGame: Game {
    let title = "My First Game"
    let intro = "A cool breeze drifts down the hall."
}
```

``Game`` requires an `init()`, but Swift synthesizes it for free as long as every stored property has a default value — which they always will here, since rooms, items, and state are declared with initializers.

## Add a room

Declare a ``Location`` as a stored property. The property name (`hall`) becomes the room's internal identity; the `name(_:)` trait is what the player sees.

```swift
struct MyGame: Game {
    let title = "My First Game"
    let intro = "A cool breeze drifts down the hall."

    let hall = Location {
        name("Entrance Hall")
        description("A long hall of grey stone. A doorway opens to the north.")
    }

    var map: WorldMap {
        player.starts(in: hall)
    }
}
```

The `map` block is where geography and starting positions live. `player.starts(in:)` places the player; without it, the game has nowhere to begin.

## Run it

Export the game factory from `Sources/MyGame/Packaged.swift`:

```swift
import Gnusto

/// The importable game used by generated front ends.
public let game = PackagedGame { MyGame() }
```

The concrete game stays internal. `gnusto-games.json` identifies the package, library product, module and factory:

```json
{"version":1,"package":"MyGame","games":[{"name":"MyGame","product":"MyGame","module":"MyGame","symbol":"game"}]}
```

Run `bin/run-game MyGame`, and you can already `look` around and try to move. The script generates an ignored executable package combining your game library with [GnustoTerminal](https://github.com/HeirloomLogic/GnustoTerminal). Neither your game nor Gnusto depends on a front end. During this coordinated prerelease, set `GNUSTO_TERMINAL_PATH` to the companion checkout if its matching revision is not yet published.

On macOS, set `GNUSTO_YONK_PATH` to a coordinated [Yonk](https://github.com/HeirloomLogic/Yonk) checkout and run `bin/run-game MyGame --frontend yonk` to generate and launch the same game through Yonk. Terminal remains the default. Yonk export is a later app-packaging step; `bin/export-game` continues to produce the terminal distribution.

``GameWorld`` validates the game before play; a bad exit throws ``BootstrapError``. The terminal launcher's ``REPL`` drives the prompt/parse/perform/print loop. Custom clients can drive the world directly or provide their own ``IOHandler``; see <doc:CustomFrontEnds>.

## Add a second room and connect them

Exits are declared on locations in the `map` block. Each directional method (``Location/north(_:)``, ``Location/south(_:)``, …) is an ordinary property reference, so a typo or a renamed room is a compile error, not a broken game.

```swift
let hall = Location {
    name("Entrance Hall")
    description("A long hall of grey stone. A doorway opens to the north.")
}

let library = Location {
    name("Dusty Library")
    description("Shelves sag under mildewed books. The hall lies south.")
}

var map: WorldMap {
    hall.north(library)
    library.south(hall)

    player.starts(in: hall)
}
```

Exits are one-directional by design — declare both `hall.north(library)` and `library.south(hall)` if you want the player to be able to walk back.

## Add a thing

Declare an ``Item`` the same way, then place it in the `map`:

```swift
let lantern = Item {
    name("brass lantern")
    adjectives("brass", "old")
    description("An old brass lantern, its glass sooty but intact.")
}

var map: WorldMap {
    hall.north(library)
    library.south(hall)

    player.starts(in: hall)
    lantern.starts(in: library)
}
```

Now the player can walk `north`, `examine lantern`, `take lantern`, and see it in their `inventory`. The ``adjectives(_:)`` let them type `take brass lantern` or `take old lantern`; a phrase has to end on a noun, so `take brass` on its own is not one of them. The last word of `name(_:)` ("lantern") is the noun the parser keys on.

Everything you declare is split into words the same way the parser splits what the player types — lowercased, a trailing possessive dropped, every other punctuation mark a separator. So `name("Mrs. Vane")` prints its period and answers to `mrs vane`, and `adjectives("master's")` is the same declaration as `adjectives("master")`. Write the second: a declaration should read the way the parser stores it.

## React with a rule

So far every verb uses its built-in behavior. To add your own logic, write a rule in the `rules` block. Rules are `before`/`after` hooks attached to a location, an item, or the whole world.

```swift
var rules: Rules {
    lantern.after(.take) {
        say("It's heavier than it looks.")
    }

    library.before(.go) {
        guard command.direction != .south else { return }
        try refuse("There's no exit that way — only back south to the hall.")
    }
}
```

The first rule runs *after* the player successfully takes the lantern and adds a line of flavor with ``say(_:)``. The second runs *before* movement in the library and ``refuse(_:)``s any direction but south. Inside a rule body, bare identifiers like `command`, `player`, and your own `lantern` refer to the live turn — reading and writing them touches the current game state.

To learn what rules can do — the phases, the ordering, and the difference between `refuse`, `reply`, `say`, and `end` — read <doc:WritingRules> and <doc:TheTurnPipeline>.

## Test it

A play session is just typed input and printed output, so the natural test plays a scripted session and asserts on the transcript:

```swift
import GnustoTestSupport
import Testing

@testable import MyGame

struct MyGameTests {
    @Test func theLanternIsWhereTheBreezeSaysItIs() async throws {
        let transcript = try await play(MyGame(), ["north", "take lantern"])
        expectInOrder(transcript, ["Dusty Library", "Taken."])
    }
}
```

`play` boots the game and feeds it each command; `expectInOrder` asserts the beats appear in order and shows the full transcript when one doesn't. See <doc:TestingYourGame> for turn slicing and pinning the random stream.

## A fuller example

Gnusto ships with **Cloak of Darkness**, Roger Firth's classic one-room demonstration game, as its `CloakOfDarkness` target. It exercises nearly every feature in a page of code — dark rooms, a wearable cloak, scored actions, a losing state, and per-turn rules — and is worth reading start to finish once the basics click.

## Next steps

- `bin/new-game` in the repo — writes the complete starter package this guide builds up to
- <doc:AnatomyOfAGame> — how declarations, identity, and live references fit together
- <doc:TheTurnPipeline> — exactly what happens each turn
- <doc:WritingRules> — the full vocabulary of game logic
- <doc:AddingCustomVerbs> — teach the parser new words with `#verb`
- <doc:TestingYourGame> — transcript tests with GnustoTestSupport
- <doc:CustomStateAndTraits> — carry your own data on entities and in globals
