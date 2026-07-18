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

Each line the player types is parsed into a ``Command``, then run through a fixed pipeline: world/location/item `before` rules, the built-in default action, then `after` rules, then each-turn rules and the timer tick. Any rule can ``refuse(_:)`` an action, ``reply(_:)`` in its place, ``end(won:)`` the game, or ``die(_:)`` — death offers the classic RESTART / RESTORE / UNDO / QUIT prompt. All state changes commit atomically at the end of the turn, which is also what `save` writes and `undo` rewinds. See <doc:TheTurnPipeline> and <doc:DarknessTimeAndDeath>.

### Scaling up

A game need not live in one file — or even one package. Compose `map` and `rules` from per-region helpers (<doc:SplittingAGameAcrossFiles>), promote a region to a self-contained ``GameContent`` bundle (<doc:ContentBundles>), or package a reusable system like commerce or combat as a ``GamePlugin`` (<doc:Plugins>).

### Playing and sharing

A game type that also conforms to ``GameMain`` is a complete `@main` executable — `swift run` it and, in a real terminal, it launches a full-screen Infocom-style interpreter (``TerminalIOHandler``) with a status bar and reflow-on-resize. When you're ready to hand it to someone, `bin/export-game` builds a single binary a friend can run on macOS with no toolchain. See <doc:SharingYourGame>.

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
- ``lightSource``
- ``startsLit``
- ``wearable``
- ``scenery``
- ``surface``
- ``container``
- ``openable``
- ``startsOpen``
- ``transparent``
- ``capacity(_:)``
- ``hidden``

### Containers, Doors, and Locks

- <doc:ContainersDoorsAndLocks>
- ``Item/lockedBy(_:)``
- ``startsUnlocked``
- ``Item/isOpen``
- ``Item/isLocked``
- ``Item/reveal()``
- ``Item/isRevealed``
- ``Location/exit(_:to:via:)``
- ``Location/exit(_:to:when:otherwise:)``

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
- ``die(_:)``
- ``Item/describe(_:)``
- ``Location/describe(_:)``

### Actors & Vehicles

- <doc:ActorsAndVehicles>
- ``Actor``
- ``enterable``
- ``Player/vehicle``
- ``describeSurroundings()``

### Time, Light, and Death

- <doc:DarknessTimeAndDeath>
- ``TimedEvent``
- ``fuse(_:after:autostart:perform:)``
- ``daemon(_:autostart:perform:)``
- ``startFuse(_:after:)``
- ``stopFuse(_:)``
- ``fuseRemaining(_:)``
- ``startDaemon(_:)``
- ``stopDaemon(_:)``
- ``isDaemonActive(_:)``

### Custom State and Traits

- <doc:CustomStateAndTraits>
- ``Global``
- ``GlobalValue``
- ``StateValue``

### Adding Vocabulary

- <doc:AddingCustomVerbs>
- ``verb(_:_:)``
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
- ``GameMain``
- ``IOHandler``
- ``ConsoleIOHandler``
- ``TerminalIOHandler``
- ``ScriptedIOHandler``

### Sharing Your Game

- <doc:SharingYourGame>

### Testing Your Game

- <doc:TestingYourGame>

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
- ``TimerBuilder``
