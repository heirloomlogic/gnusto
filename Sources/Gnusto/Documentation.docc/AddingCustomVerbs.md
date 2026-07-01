# Adding Custom Verbs

Teach the parser words the built-in table doesn't know.

## Overview

Gnusto ships with a standard verb table: `take`, `drop`, `examine`, `wear`, `go`, `look`, and their synonyms. When your game needs a verb of its own — `ring`, `buy`, `dig`, `pull` — you add a row to the parser with a ``SyntaxRule`` and handle the resulting ``Intent`` in a rule.

There are two halves to a custom verb: teaching the parser to *recognize* it, and writing a rule to *respond* to it.

## Declare the verb

List new verbs in your game's `verbs` block. Each ``SyntaxRule`` pairs a verb word (or words) with the sentence shape it accepts and the ``Intent`` it produces on a match:

```swift
struct Temple: Game {
    static let ring = Intent("ring")

    let bell = Item { name("brass bell") }

    var verbs: [SyntaxRule] {
        SyntaxRule("ring", slots: .direct, intent: Self.ring)
    }
    // rules below
}
```

Exposing the intent as a `static let` constant lets your rules refer to the same intent the verb emits, without re-spelling the string.

## Choose a sentence shape

The `slots` parameter is the shape the parser expects *after* the verb word. The cases of ``SyntaxRule/Slots`` cover the common patterns:

| Slots | Player types | Command gets |
|---|---|---|
| ``SyntaxRule/Slots/none`` | `pray` | just the intent |
| ``SyntaxRule/Slots/direction`` | `dig down` | a ``Command/direction`` |
| ``SyntaxRule/Slots/direct`` | `ring bell` | a ``Command/directObject`` |
| ``SyntaxRule/Slots/directThenParticle(_:)`` | `pick bell up` | direct object, trailing particle |
| ``SyntaxRule/Slots/directPrepIndirect(_:)`` | `put bell on hook` | direct + indirect objects |

A rule can carry several verb tokens for one shape — `SyntaxRule("look", "at", slots: .direct, intent: .examine)` matches `look at bell`. You can register several rows for one intent to give the player synonyms:

```swift
var verbs: [SyntaxRule] {
    SyntaxRule("ring",  slots: .direct, intent: Self.ring)
    SyntaxRule("sound", slots: .direct, intent: Self.ring)
    SyntaxRule("chime", slots: .direct, intent: Self.ring)
}
```

## Respond to the intent

A custom intent has no built-in default action, so a bare `ring bell` would just report that the game didn't understand. Give it behavior with a `before` rule that ``reply(_:)``s — `reply` handles the action in place of any default:

```swift
var rules: Rules {
    bell.before(Self.ring) {
        try reply("The bell tolls, deep and sonorous. Somewhere, a door unlatches.")
    }
}
```

Because the object resolved into ``Command/directObject``, you can attach the rule to the object (`bell.before(…)`) or handle the intent more broadly on the ``World`` when several objects share behavior:

```swift
world.before(Self.ring) {
    guard let thing = command.directObject else {
        try refuse("Ring what?")
    }
    try reply("You ring the \(thing.name). Nothing happens.")
}
```

## Reclaiming a built-in verb

A verb table merges the built-in rows, each content bundle's, each plugin's, and the game's own, under a **last-wins** policy keyed on what the player types (the verb tokens plus the slot shape). If your row's verb and shape exactly match a built-in, yours reclaims it — the parser emits *your* intent instead — and the engine logs a non-fatal warning so the override is never silent. This lets a game repurpose, say, `read` without forking the engine.

## Where verbs can come from

The `verbs` block exists on more than the game type. A ``GameContent`` bundle and a ``GamePlugin`` each carry their own `verbs`, all merged into one table at startup. That is exactly how a reusable commerce plugin ships `buy`/`sell` for any host to splice in — see <doc:Plugins>.

## See also

- <doc:WritingRules>
- <doc:TheTurnPipeline>
- <doc:Plugins>
