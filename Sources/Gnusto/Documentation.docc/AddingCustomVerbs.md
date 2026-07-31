# Adding Custom Verbs

Teach the parser words the built-in table doesn't know.

## Overview

Gnusto ships with a standard verb table in two tiers. The **core** tier is verbs the engine backs with real behavior: `take`, `drop`, `examine`, `wear`, `go`, `follow`, `greet`, `look`, `wait` (`z`), and their synonyms. The **stub** tier is verbs the parser knows as *words* with no mechanic behind them — `attack`, `dig`, `smell`, `climb`, `jump`, `buy`, `pray`, `xyzzy` and some forty more — each answering with one line of stock prose. See <doc:StubVerbs> for what they are and how to give one real behavior.

When your game needs a verb neither tier covers — `ring`, `wind`, `chime`, `barter` — you declare it once with `#verb` and handle it in a rule.

`wait` (and its alias `z`) is a normal, time-passing turn: it prints the `timePasses` line ("Time passes.") and lets fuses and daemons tick — the standard way to let a countdown run down or a wandering monster catch up. Re-skin the line by mutating `text.timePasses`.

There are three beats to a custom verb: **declare** it, **list** it in a `verbs` block, and **respond** to it in a rule.

## Declare the verb

`#verb` lives inside an `extension Intent` — that placement is what makes the leading-dot spelling (`.ring`) work everywhere an ``Intent`` is expected. Its first argument names the intent; each argument after that is one complete *pattern*: the words the player types, in order, with slots where noun phrases (or a direction) go.

```swift
extension Intent {
    #verb("ring", ["ring", .directObject])
}
```

This generates a typed constant, `Intent.ring`, that carries its verb row. String literals in a pattern are literal words; the slots are ``SyntaxElement/directObject``, ``SyntaxElement/indirectObject``, ``SyntaxElement/direction``, and ``SyntaxElement/topic``. With no pattern at all, the verb is the name: `#verb("chime")` accepts a bare `chime`.

Pick a name the engine doesn't already own. `#verb` mints `Intent.<name>`, and a second declaration of a name the engine ships makes `.<name>` ambiguous in any file that imports both modules — so `#verb("dig")` in a library is a trap, while `#verb("excavate", ["dig", .directObject])` is fine.

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
    [.ring, .polish, .chime]
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
| `#verb("chime")` | `chime` | just the intent |
| `#verb("tunnel", ["tunnel", .direction])` | `tunnel down` | a ``Command/direction`` |
| `#verb("ring", ["ring", .directObject])` | `ring bell` | a ``Command/directObject`` |
| `#verb("wind", ["wind", .directObject, "up"])` | `wind canary up` | a direct object |
| `#verb("barter", ["barter", .directObject, "for", .indirectObject])` | `barter coin for rope` | direct + indirect objects |
| `#verb("peek", ["look", "under", .directObject])` | `look under rug` | a direct object |
| `#verb("ask", ["ask", .directObject, "about", .topic])` | `ask monk about the bell` | a direct object + a ``Command/topic`` |

The rules: a pattern starts with at least one literal word (the verb); it can hold at most one direct-object and one indirect-object slot, direct first, with a literal word between them; a direction slot ends its pattern and never mixes with object slots; a topic slot also ends its pattern, and never mixes with a second object or a direction.

A **topic** is the odd one out, and deliberately so. The object slots resolve against what the player can see, and refuse anything else — which is right for things and wrong for subjects. A topic instead takes the rest of the line as typed, normalized but never looked up, so `ask the monk about zeppelins` reaches the monk's rules and lets him shrug rather than dying in the parser as "You can't see any such thing." It arrives as a ``Topic`` on ``Command/topic``, with the words already lowercased, stripped of punctuation and filler; ``Topic/normalize(_:)`` puts an author's own keyword through the same mill so the two can be compared. The line exactly as typed is still on ``Command/rawInput``.

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

A verb table merges the built-in rows, each content bundle's, each plugin's, and the game's own, under a **last-wins** policy keyed on what the player types (the full pattern). If your pattern exactly matches a **core** row, yours reclaims it — the parser emits *your* intent instead — and the engine logs a non-fatal warning so the override is never silent. The intent name doesn't have to match the typed word, which is what makes a reclaim readable:

```swift
extension Intent {
    #verb("steal", ["take", .directObject])   // `take coin` now means stealing
}
```

Reclaiming a **stub** row is silent, because a stub has no behavior to shadow and overriding it is the expected end state. That is the whole point of the two tiers: the warning catches you accidentally hiding something real, and stays quiet when you're filling in a blank. See <doc:StubVerbs>.

A few words a game is *likely* to want are deliberately absent from both tiers. Bare `hello` and bare `hi` are the clearest case: they are the kind of one-word verb a game likes to own outright — Zork 1 does — and even a silent reclaim is worse than leaving them free, because the engine would have to pick a greeting line for everybody. The engine ships `greet <object>`, `hello <object>` and `hi <object>`, and leaves the bare forms to `GnustoConversation` or to you. `ring` and `wind` are out for the same reason: a game that has a bell wants to say what ringing it does.

## The substrate: raw `SyntaxRule`

`#verb` expands to a `static let` whose ``Intent`` carries ``SyntaxRule`` rows — the same rows you can build by hand when a table is genuinely dynamic:

```swift
var verbs: [SyntaxRule] {
    SyntaxRule("ring", .directObject, intent: Intent("ring"))
}
```

The two forms interoperate: an `Intent("ring")` built from a string matches a `#verb`-minted `.ring` everywhere (the rows an intent carries are not part of its identity). Hand-built rows are validated by the bootstrap at launch instead of at compile time.

## Where verbs can come from

The `verbs` block exists on more than the game type. A ``GameContent`` bundle and a ``GamePlugin`` each carry their own `verbs`, all merged into one table at startup. That is how a reusable plugin ships a whole verb — `GnustoMeleeCombat` promotes the engine's `attack`/`kill`/`hit`/`fight` stubs to real combat with an `actions` row, and adds the two rows the engine doesn't ship (`stab … with …`, `strike … with …`) to the same intent. See <doc:Plugins>.

Engine intents list the same way your own do. A `#verb` intent carries its rows on the constant; an engine intent keeps its rows in the standard table, and listing it splices those. Rows you're adding to that intent go alongside, spelled as ``SyntaxRule`` values — which is what melee's `verbs` block is:

```swift
public var verbs: [SyntaxRule] {
    .attack                                                                     // the engine's rows
    SyntaxRule("stab", .directObject, "with", .indirectObject, intent: .attack)
    SyntaxRule("strike", .directObject, "with", .indirectObject, intent: .attack)
}
```

Reclaiming a built-in shape *for the intent that already held it* — which is what listing an engine intent does — isn't an override, so it doesn't warn. Reclaiming one for a different intent still does.

## See also

- <doc:StubVerbs>
- <doc:WritingRules>
- <doc:TheTurnPipeline>
- <doc:Plugins>
