# Adding Custom Verbs

Teach the parser words the built-in table doesn't know.

## Overview

Gnusto ships with a standard verb table: `take`, `drop`, `examine`, `wear`, `go`, `look`, and their synonyms. When your game needs a verb of its own — `ring`, `buy`, `dig`, `pull` — you declare it once with `#verb` and handle it in a rule.

There are three beats to a custom verb: **declare** it, **list** it in a `verbs` block, and **respond** to it in a rule.

## Declare the verb

`#verb` lives inside an `extension Intent` — that placement is what makes the leading-dot spelling (`.ring`) work everywhere an ``Intent`` is expected. Its first argument names the intent; each argument after that is one complete *pattern*: the words the player types, in order, with slots where noun phrases (or a direction) go.

```swift
extension Intent {
    #verb("ring", ["ring", .directObject])
}
```

This generates a typed constant, `Intent.ring`, that carries its verb row. String literals in a pattern are literal words; the slots are ``SyntaxElement/directObject``, ``SyntaxElement/indirectObject``, and ``SyntaxElement/direction``. With no pattern at all, the verb is the name: `#verb("sing")` accepts a bare `sing`.

Patterns are validated as you type — a malformed shape is a compile-time error, with the same wording the bootstrap uses for hand-built rows.

## List it, then respond to it

The rows reach the parser through your game's `verbs` block, which splices everything a listed intent carries. A rule keyed on the same constant gives the verb behavior — a custom intent has no built-in default action, so an unhandled one just reports that the game didn't understand:

```swift
struct Temple: Game {
    let bell = Item { name("brass bell") }

    var verbs: [SyntaxRule] {
        .ring
    }

    var rules: Rules {
        bell.before(.ring) {
            try reply("The bell tolls, deep and sonorous. Somewhere, a door unlatches.")
        }
    }
}
```

List several intents as one array — bare `.ring` statements on consecutive lines would parse as a single chained member access:

```swift
var verbs: [SyntaxRule] {
    [.ring, .polish, .sing]
}
```

If you forget the listing, the rule silently never fires from typed input; the bootstrap records a non-fatal warning naming the intent and the fix.

Because the object resolves into ``Command/directObject``, you can attach the rule to the object (`bell.before(…)`) or handle the intent more broadly on the ``World`` when several objects share behavior:

```swift
world.before(.ring) {
    guard let thing = command.directObject else {
        try refuse("Ring what?")
    }
    try reply("You ring the \(thing.name). Nothing happens.")
}
```

## Shape the pattern

A pattern reads the way it's typed. Some shapes, from the standard table and beyond:

| Pattern | Player types | Command gets |
|---|---|---|
| `#verb("pray")` | `pray` | just the intent |
| `#verb("dig", ["dig", .direction])` | `dig down` | a ``Command/direction`` |
| `#verb("ring", ["ring", .directObject])` | `ring bell` | a ``Command/directObject`` |
| `#verb("pick", ["pick", .directObject, "up"])` | `pick bell up` | a direct object |
| `#verb("give", ["give", .directObject, "to", .indirectObject])` | `give bell to monk` | direct + indirect objects |
| `#verb("peek", ["look", "under", .directObject])` | `look under rug` | a direct object |

The rules: a pattern starts with at least one literal word (the verb); it can hold at most one direct-object and one indirect-object slot, direct first, with a literal word between them; a direction slot ends its pattern and never mixes with object slots.

Several patterns on one `#verb` share the intent — that is how synonyms and alternate word orders work:

```swift
extension Intent {
    #verb("ring",
          ["ring", .directObject],
          ["sound", .directObject])
    #verb("light",
          ["turn", "on", .directObject],
          ["turn", .directObject, "on"])
}
```

Among rows sharing a verb word, the parser tries the most specific pattern first (more literal words, then more slots); ties keep their table order. The literal word sealing the direct object ahead of an indirect slot arrives on ``Command/preposition``.

## Reclaiming a built-in verb

A verb table merges the built-in rows, each content bundle's, each plugin's, and the game's own, under a **last-wins** policy keyed on what the player types (the full pattern). If your pattern exactly matches a built-in, yours reclaims it — the parser emits *your* intent instead — and the engine logs a non-fatal warning so the override is never silent. The intent name doesn't have to match the typed word, which is what makes a reclaim readable:

```swift
extension Intent {
    #verb("steal", ["take", .directObject])   // `take coin` now means stealing
}
```

## The substrate: raw `SyntaxRule`

`#verb` expands to a `static let` whose ``Intent`` carries ``SyntaxRule`` rows — the same rows you can build by hand when a table is genuinely dynamic:

```swift
var verbs: [SyntaxRule] {
    SyntaxRule("ring", .directObject, intent: Intent("ring"))
}
```

The two forms interoperate: an `Intent("ring")` built from a string matches a `#verb`-minted `.ring` everywhere (the rows an intent carries are not part of its identity). Hand-built rows are validated by the bootstrap at launch instead of at compile time.

## Where verbs can come from

The `verbs` block exists on more than the game type. A ``GameContent`` bundle and a ``GamePlugin`` each carry their own `verbs`, all merged into one table at startup. That is exactly how a reusable plugin ships a whole verb — `GnustoMeleeCombat` declares `#verb("attack", …)` once and lists `.attack` in its `verbs`, and any host that splices the plugin gets the entire combat vocabulary. See <doc:Plugins>.

## See also

- <doc:WritingRules>
- <doc:TheTurnPipeline>
- <doc:Plugins>
