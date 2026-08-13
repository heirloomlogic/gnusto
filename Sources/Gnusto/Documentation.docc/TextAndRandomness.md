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

Fixed lines are plain strings. A line built around a name is a ``GameText/Line``, which takes a bare string as readily as a naming closure — so whether a line names the thing it is about is the game's call and not a shape the engine picked:

```swift
text.cantReach = .naming { "\($0) is right there, and yet." }
```

## Articles are the engine's job

A naming line receives a ``GameText/Noun`` — a **rendered noun phrase** (`the brass lantern`, `a brass lantern`, `Mrs. Vane`) that also knows its own number — never a bare name. The article is chosen before the closure runs, because only the engine knows which entities carry the `properName` trait:

```swift
let constance = Actor {
    name("Mrs. Vane")
    properName
}
```

With that one word, every stock line reads correctly: `Mrs. Vane is right here.`, `You see nothing special about Mrs. Vane.`, `Mrs. Vane would take exception to that.` Without it they all say `the Mrs. Vane`, and a disambiguation between a person and a prop — which has to article one and not the other in the same sentence — could not be fixed by re-skinning at all.

Where a line *opens* on the phrase, reach for ``GameText/Noun/sentenceCased``: `the troll` has to be capitalized and `Mrs. Vane` must be left alone.

```swift
text.cantTakeActor = .naming { "\($0.sentenceCased) would sooner not." }
```

The other three helpers are public statics too, for a custom line that builds a phrase of its own: ``GameText/definite(_:proper:)``, ``GameText/indefinite(_:proper:)``, and ``GameText/list(_:)``, which joins already-rendered phrases into an English list. A rule can reach the same forms through ``Item/definiteName`` and ``Item/indefiniteName``.

A capitalized `name(…)` on an item or actor without `properName` is a non-fatal bootstrap warning — not an inference, since `Elvish sword` is a common noun, but the author who meant a proper name shouldn't have to find out from a transcript. Location names are exempt: the engine never articles a room.

Text a game declares itself (descriptions, rule replies) never goes through `GameText`; it's already in your voice.

The stub verbs' stock replies are grouped on ``GameText/stubs`` rather than sitting flat alongside the rest, since there are about fifty of them:

```swift
text.stubs.pray = "No one is listening. You checked."
text.stubs.attack = .naming { "The Institute frowns on assaulting \($0)." }
text.stubs.smash = .naming { "\($0.sentenceCased) \($0.verb("is", "are")) stouter than your temper." }
```

Overriding one re-skins the line; replacing the *behavior* is a rule or an `actions` row. See <doc:StubVerbs>.

Those three are the same type, and it is the same type the lines above use. Only a verb with no object slot on any row — `sing`, `pray`, `swim` — is a plain `String`, because there is nothing for a closure to be handed.

A `Line` is handed a ``GameText/Noun``, never a bare name: the rendered phrase plus its number, so ``GameText/Noun/verb(_:_:)`` can pick the form that agrees and a game may call a thing `rails` and get "The rails are not food." Interpolating one prints its phrase, so a line with no verb to agree pays nothing for the facility. The number comes from the `plural` trait, declared for the same reason `properName` is: no engine should guess it, and no game should have to rename a thing to suit a stock line.

A line about **two** things is a `Line` too, over a role struct that names them — ``GameText/Placement`` (a thing and what holds it), ``GameText/Gift``, ``GameText/Aboard``:

```swift
text.putItemIn = .naming { "You tuck \($0.item) into \($0.holder)." }
```

The roles are a type rather than a pair because `\($0.holder)` answers the question an author actually asks — which one is the container? — and `\($1)` does not. Both halves are nouns, which matters more here than for a one-object line: a two-object sentence has two things its verb might agree with, and it is rarely the one named first. ``GameText/itemOnSurface`` reads "On the table are the rails."

The lines that are *not* `Line`s are the ones whose subject is not a thing in the world: a word the player typed (``GameText/unknownWord``), a list (``GameText/ambiguous``), a number (``GameText/scoreLine``), or nothing at all (``GameText/pitchBlack``). They stay closures on purpose — `Line` is `ExpressibleByStringLiteral`, and a `Line` for `unknownWord` would let a game write `text.unknownWord = "Eh?"` and silently drop the word the line is *about*.

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
