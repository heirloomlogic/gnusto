# Text and Randomness

Re-skin the engine's stock lines, and roll dice that replay.

## Overview

Two systems give a game its voice: ``GameText``, the table of every stock line the engine can say, and the seeded random stream behind ``random(_:)``, `oneOf(_:)`, and ``chance(_:)``, which lets responses vary without ever varying between replays of the same seed.

## Speaking in your own voice

Every standard response — `Taken.`, `You can't go that way.`, the inventory header, the parser's complaints — lives on a ``GameText`` value. Override any subset from your game's `text` property; everything you don't touch keeps the classic default:

```swift
struct Snark: Game {
    // …

    var text: GameText {
        var text = GameText()
        text.taken = "Snagged."
        text.cantGoThatWay = "Walls exist, you know."
        return text
    }
}
```

Fixed lines are plain strings. Lines built around a name are closures, so the override controls the whole sentence:

```swift
text.cantReach = { "The \($0) is right there, and yet." }
```

The article helpers the defaults use — ``GameText/indefinite(_:)`` and ``GameText/indefiniteList(_:)`` — are public statics, so custom lines can format listings the same way the engine does.

Text a game declares itself (descriptions, rule replies) never goes through `GameText`; it's already in your voice.

## Randomness that replays

Rule bodies can vary their behavior with three helpers:

```swift
thief.before(.examine) {
    try reply(oneOf(
        "The thief eyes you with polite menace.",
        "The thief pretends not to notice you.",
    ))
}

world.afterEachTurn {
    if chance(5) {
        say("Somewhere below, something skitters.")
    }
}

let damage = random(2...12)
```

All three draw from one stream whose position lives in the world state. That buys two guarantees:

- **Replays**: a world built with ``GameWorld/init(game:seed:)`` plays out identically for the same seed and commands, on every platform — the backbone of transcript tests and reproducible bug reports. The plain ``GameWorld/init(game:)`` seeds fresh each run.
- **Saves**: the stream's position is part of the saved state, so a restored game continues with exactly the randomness it would have had.

Pin the seed in a test the same way the engine's own suite does:

```swift
let world = try GameWorld(game: MyGame(), seed: 42)
```

## See also

- <doc:WritingRules>
- <doc:TheTurnPipeline>
