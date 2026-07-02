# ``Gnusto``

A Swift engine for writing parser-driven interactive fiction — text adventures in the tradition of Zork and Infocom's ZIL.

@Metadata {
    @DisplayName("Gnusto")
    @TitleHeading("Framework")
}

## Overview

Gnusto turns a single Swift type into a playable text adventure. You *declare* your world — its rooms, its things, and the rules that govern them — and the engine parses player input, runs the turn, and prints the result.

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

let world = try GameWorld(game: TinyGame())
await REPL(world: world, io: ConsoleIOHandler()).run()
```

That is a complete, runnable game. The player can `look`, `examine coin`, `take coin`, check their `inventory`, and try to go `north`.

### The shape of a game

A game is one type conforming to ``Game``. The engine reads four things off that type:

- the ``Location``, ``Item``, and ``Global`` values you declare as stored properties, which it discovers by reflection and names after each property.
- a `map` block of exits and initial placements, built from compile-checked property references (``WorldMap``).
- a `rules` block of `before`/`after`/each-turn hooks that react to what the player does (``Rules``).
- an optional `verbs` block that teaches the parser new words (``SyntaxRule``).

The same value is both the *declaration* and the live *reference*: `let cloak = Item { … }` declares the cloak, and `cloak.isWorn` reads its live state inside a rule. See <doc:AnatomyOfAGame> for how that works.

### How a turn runs

Each line the player types is parsed into a ``Command``, then run through a fixed pipeline: world/location/item `before` rules, the built-in default action, then `after` rules, then each-turn rules. Any rule can ``refuse(_:)`` an action, ``reply(_:)`` in its place, or ``end(won:)`` the game. All state changes commit atomically at the end of the turn. See <doc:TheTurnPipeline>.

### Scaling up

A game need not live in one file — or even one package. Compose `map` and `rules` from per-region helpers (<doc:SplittingAGameAcrossFiles>), promote a region to a self-contained ``GameContent`` bundle (<doc:ContentBundles>), or package a reusable system like commerce or combat as a ``GamePlugin`` (<doc:Plugins>).

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:AnatomyOfAGame>
- <doc:TheTurnPipeline>

### Declaring the World

- ``Game``
- ``Location``
- ``Item``
- ``Player``
- ``World``
- ``WorldMap``
- ``MapEntry``
- ``Direction``

### Describing Entities

- ``LocationTrait``
- ``ItemTrait``
- ``adjectives(_:)``
- ``synonyms(_:)``
- ``firstSight(_:)``
- ``dark``
- ``wearable``
- ``scenery``
- ``surface``

### Writing Rules

- <doc:WritingRules>
- ``Rule``
- ``Rules``
- ``Intent``
- ``Command``
- ``say(_:)``
- ``refuse(_:)``
- ``reply(_:)``
- ``end(won:)``

### Custom State and Traits

- <doc:CustomStateAndTraits>
- ``Global``
- ``GlobalValue``
- ``StateValue``

### Adding Vocabulary

- <doc:AddingCustomVerbs>
- ``SyntaxRule``
- ``SyntaxElement``

### Text and Randomness

- <doc:TextAndRandomness>
- ``GameText``
- ``random(_:)``
- ``chance(_:)``

### Running a Game

- ``GameWorld``
- ``TurnResult``
- ``StatusLine``
- ``GameStatus``
- ``REPL``
- ``IOHandler``
- ``ConsoleIOHandler``
- ``ScriptedIOHandler``

### Composing Large Games

- <doc:SplittingAGameAcrossFiles>
- <doc:ContentBundles>
- <doc:Plugins>
- ``GameContent``
- ``GameContents``
- ``GamePlugin``

### Identity and Storage

- ``EntityID``
- ``Placement``
- ``BootstrapError``

### Result Builders

- ``GnustoBuilder``
- ``LocationBuilder``
- ``ItemBuilder``
- ``MapBuilder``
- ``RuleBuilder``
- ``VerbBuilder``
- ``ContentBuilder``
