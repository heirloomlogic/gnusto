# Adding Custom Verbs

Teach the parser words the built-in table doesn't know.

## Overview

Gnusto ships with a standard verb table: `take`, `drop`, `examine`, `wear`, `go`, `look`, and their synonyms. When your game needs a verb of its own — `ring`, `buy`, `dig`, `pull` — you add a row to the parser with a ``SyntaxRule`` and handle the resulting ``Intent`` in a rule.

There are two halves to a custom verb: teaching the parser to *recognize* it, and writing a rule to *respond* to it.

## Declare the verb

List new verbs in your game's `verbs` block. Each ``SyntaxRule`` is a *pattern*: the words the player types, in order, with slots where noun phrases (or a direction) go. String literals in a pattern are literal words; the slots are ``SyntaxElement/directObject``, ``SyntaxElement/indirectObject``, and ``SyntaxElement/direction``. The row produces an ``Intent`` on a match:

```swift
struct Temple: Game {
    static let ring = Intent("ring")

    let bell = Item { name("brass bell") }

    var verbs: [SyntaxRule] {
        SyntaxRule("ring", .directObject, intent: Self.ring)
    }
    // rules below
}
```

Exposing the intent as a `static let` constant lets your rules refer to the same intent the verb emits, without re-spelling the string.

## Shape the pattern

A pattern reads the way it's typed. Some shapes, from the standard table and beyond:

| Pattern | Player types | Command gets |
|---|---|---|
| `SyntaxRule("pray", intent: …)` | `pray` | just the intent |
| `SyntaxRule("dig", .direction, intent: …)` | `dig down` | a ``Command/direction`` |
| `SyntaxRule("ring", .directObject, intent: …)` | `ring bell` | a ``Command/directObject`` |
| `SyntaxRule("pick", .directObject, "up", intent: …)` | `pick bell up` | a direct object |
| `SyntaxRule("give", .directObject, "to", .indirectObject, intent: …)` | `give bell to monk` | direct + indirect objects |
| `SyntaxRule("look", "under", .directObject, intent: …)` | `look under rug` | a direct object |

The rules: a pattern starts with at least one literal word (the verb); it can hold at most one direct-object and one indirect-object slot, direct first, with a literal word between them; a direction slot ends its pattern and never mixes with object slots. The bootstrap validates every custom row and reports malformed patterns as fatal diagnostics, all at once.

When both `turn on lamp` and `turn lamp on` should work, register both orders — several rows can share one intent, which is also how synonyms work:

```swift
var verbs: [SyntaxRule] {
    SyntaxRule("ring",  .directObject, intent: Self.ring)
    SyntaxRule("sound", .directObject, intent: Self.ring)
    SyntaxRule("turn", "on", .directObject, intent: Self.light)
    SyntaxRule("turn", .directObject, "on", intent: Self.light)
}
```

Among rows sharing a verb word, the parser tries the most specific pattern first (more literal words, then more slots); ties keep their table order. The literal word sealing the direct object ahead of an indirect slot arrives on ``Command/preposition``.

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

A verb table merges the built-in rows, each content bundle's, each plugin's, and the game's own, under a **last-wins** policy keyed on what the player types (the full pattern). If your row's pattern exactly matches a built-in, yours reclaims it — the parser emits *your* intent instead — and the engine logs a non-fatal warning so the override is never silent. This lets a game repurpose, say, `read` without forking the engine.

## Where verbs can come from

The `verbs` block exists on more than the game type. A ``GameContent`` bundle and a ``GamePlugin`` each carry their own `verbs`, all merged into one table at startup. That is exactly how a reusable commerce plugin ships `buy`/`sell` for any host to splice in — see <doc:Plugins>.

## See also

- <doc:WritingRules>
- <doc:TheTurnPipeline>
- <doc:Plugins>
