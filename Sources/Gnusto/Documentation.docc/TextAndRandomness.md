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

Every line is a ``GameText/Line``, and a `Line` takes a bare string as readily as a closure — so whether a line names the thing it is about, or looks around before it speaks, is the game's call and not a shape the engine picked:

```swift
text.cantReach = .naming { "\($0.sentenceCased) is right there, and yet." }
text.pitchBlack = .live { lantern.isOn ? "Dark, and getting darker." : "Pitch black." }
```

What the generic parameter says is what the line is *given*. A line built around a name takes a ``GameText/Noun``; one about nothing in particular takes `Void`, and reaches for ``GameText/Line/live(_:)`` when it wants the turn it prints in rather than the moment it was written. Neither costs a game that wants the plain sentence anything: that spelling is the string literal, in every slot.

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

Those three are the same type, and it is the same type the lines above use. A verb with no object slot on any row — `sing`, `pray`, `swim` — is a `Line<Nothing>`.

A `Line` is handed a ``GameText/Noun``, never a bare name: the rendered phrase plus its number, so ``GameText/Noun/verb(_:_:)`` can pick the form that agrees and a game may call a thing `rails` and get "The rails are not food." Interpolating one prints its phrase, so a line with no verb to agree pays nothing for the facility. The number comes from the `plural` trait, declared for the same reason `properName` is: no engine should guess it, and no game should have to rename a thing to suit a stock line.

A line about **several** things is a line about one. ``GameText/Noun/list(_:)`` joins them into a single noun that carries the number the *whole phrase* has — plural when there are several, and also when the only one is itself plural:

```swift
text.inTheContainer = .naming { "In \($0.holder) \($0.item.verb("is", "are")) \($0.item)." }
```

That second rule is why the helper exists rather than a `[Noun]` parameter. The engine used to decide by counting, so one plural thing in a box printed "In the hamper is some scales." — and the rule lived in the line's body, where a game re-voicing it had to re-derive it and could get it wrong the same way. The template above never counts anything.

``GameText/inventorySentence`` is the exception, over ``GameText/Carried``: it has something to say about *each* thing it lists — which of them is being worn — so it cannot have them joined before the game has had its say.

A line about **two** things is a `Line` too, over a role struct that names them — ``GameText/Holding`` (a thing and what holds it), ``GameText/Gift``, ``GameText/Aboard``:

```swift
text.putItemIn = .naming { "You tuck \($0.item) into \($0.holder)." }
```

The roles are a type rather than a pair because `\($0.holder)` answers the question an author actually asks — which one is the container? — and `\($1)` does not. Both halves are nouns, which matters more here than for a one-object line: a two-object sentence has two things its verb might agree with, and it is rarely the one named first. ``GameText/itemOnSurface`` reads "On the table are the rails."

Every stock line is a `Line`. What differs is its **subject** — the type it is about — and the set of those is the ``LineSubject`` protocol rather than a list somebody has to keep current: ``GameText/Nothing``, ``GameText/Noun`` and `Noun?`, the role structs above, and five more for the lines about something that isn't in the world at all. A word quoted back at the player is a ``GameText/Word`` (``GameText/unknownWord``, ``GameText/noReferent``); the part of a sentence the parser is still waiting for is a ``GameText/Prompt`` (the `missing…` family); the things one phrase matched are ``GameText/Choices`` (``GameText/ambiguous``); the title is a ``GameText/Banner`` and the score a ``GameText/Score``.

Those last five are the ones a line may **not** leave unsaid, and the type enforces it. `Line` is `ExpressibleByStringLiteral` only where its subject conforms to ``DroppableSubject``, so a fixed sentence is available to every line about a thing in the world — `text.putItemIn = "Done."` prints no names and is still true — and unavailable where the subject *is* the content:

```swift
text.unknownWord = "Eh?"                                    // does not compile
text.unknownWord = .naming { "There is no \"\($0)\" here." } // the only way to write it
```

A line handed *nothing* has nothing to drop, which is why ``GameText/pitchBlack`` is a `Line<Nothing>` and takes a literal like the rest.

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
