# Getting Started with Gnusto

Build and run your first text adventure, one piece at a time.

## Overview

This guide walks you from an empty package to a small, playable game. By the end you will have declared two rooms and an object, wired them together, added a rule, tested a play session, and run the whole thing at a prompt. It assumes you can write basic Swift; it assumes nothing about interactive fiction.

Prefer to start from something that already runs? The repo ships a complete starter package at `Templates/NewGame` — copy it out, rename it, and skim this guide for the *why* behind each piece.

## Add Gnusto to your package

Add Gnusto as a dependency, list it in your executable target, and give the test target the `GnustoTestSupport` product (it links the toolchain's Testing library, so it belongs in test targets only):

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MyGame",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/HeirloomLogic/Gnusto", from: "0.1.0")
    ],
    targets: [
        .executableTarget(
            name: "MyGame",
            dependencies: [
                .product(name: "Gnusto", package: "Gnusto")
            ]
        ),
        .testTarget(
            name: "MyGameTests",
            dependencies: [
                "MyGame",
                .product(name: "GnustoTestSupport", package: "Gnusto"),
            ]
        ),
    ]
)
```

Gnusto requires macOS 15 or newer (it uses `Synchronization.Mutex`), and builds with the Swift 6 language mode.

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

Three lines turn a game value into a running session:

```swift
let world = try GameWorld(game: MyGame())
await REPL(world: world, io: ConsoleIOHandler()).run()
```

``GameWorld`` validates the game and builds its initial state up front — a mistake like an exit to an undeclared room is caught here, as a thrown ``BootstrapError``, not at runtime. ``REPL`` runs the prompt/parse/perform/print loop, and ``ConsoleIOHandler`` reads from and writes to the terminal.

Wrap it in a `do`/`catch` in your `main.swift`:

```swift
import Gnusto

do {
    let world = try GameWorld(game: MyGame())
    await REPL(world: world, io: ConsoleIOHandler()).run()
} catch {
    print("Couldn't start the game: \(error)")
}
```

Run `swift run`, and you can already `look` around and try to move.

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

Now the player can walk `north`, `examine lantern`, `take lantern`, and see it in their `inventory`. The ``adjectives(_:)`` let them type `take brass lantern` or just `take brass`. The last word of `name(_:)` ("lantern") is the noun the parser keys on.

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

- `Templates/NewGame` in the repo — the complete starter package this guide builds up to
- <doc:AnatomyOfAGame> — how declarations, identity, and live references fit together
- <doc:TheTurnPipeline> — exactly what happens each turn
- <doc:WritingRules> — the full vocabulary of game logic
- <doc:AddingCustomVerbs> — teach the parser new words with `#verb`
- <doc:TestingYourGame> — transcript tests with GnustoTestSupport
- <doc:CustomStateAndTraits> — carry your own data on entities and in globals
