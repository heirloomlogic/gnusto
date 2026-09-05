# Bootstrap Diagnostics

Every message the bootstrap can print, and what to change.

## Overview

A Gnusto game is validated once, at boot. `Bootstrap.build` reads every
declaration the game and its content bundles make, checks them against each
other, and either hands back a definition or reports every problem it found at
once — never the first one, because a game with four mistakes in its map should
cost one build to find all four.

A problem that would leave the world incoherent is fatal: ``BootstrapError`` is
thrown and the game never starts. A problem that only leaves a declaration inert
is a warning on standard error, and play continues. The distinction is worth
holding on to, because a warning describes a line of your source that does
nothing at all — a flag with no effect, a rule that can never fire, a
description with nowhere to print — and nothing at runtime will ever mention it
again.

Warnings print **before** the IO handler is built. ``TerminalIOHandler`` enters
the alternate screen buffer in its initializer, so a stderr write after that
would be painted over and lost; ``GameMain`` writes the report first, on the
primary screen, where it is still there after the game exits. It goes to stderr
rather than stdout so it stays out of the play transcript.

That is the ``GameMain`` path and the MCP play-test server, which reports the
same list into its session banner. A world built by hand — a test calling
`play(_:_:)`, a custom front end constructing ``GameWorld`` itself — prints
nothing, so run the game once as a binary after changing declarations.

The report reads:

```
Gnusto: the game definition has 2 warning(s) (play continues):
  • item "lamp" declares startsLit but is not a lightSource; the flag has no effect.
  • location "cellar" declares alwaysDescribed but has no description(…) trait and no describe { … } rule; the flag has nothing to print.
```

A fatal error reads the same way, deliberately, so the two are one thing to
learn:

```
Gnusto: the game definition is invalid (1 problem(s)):
  • "attic" declares its north exit more than once.
```

## Fatal: `BootstrapError`

``BootstrapError`` carries every diagnostic in ``BootstrapError/diagnostics``
and renders them all in its `description`. It is thrown at three gates, and each
gate has to pass before the next one runs:

1. **Placement and map**, after reflection has discovered the declarations and
   the `map` block has been evaluated.
2. **Vocabulary**, after every declared name, synonym, adjective, verb-pattern
   literal and noise word has been split the way the tokenizer splits player
   input.
3. **Rules and timers**, after the `rules` and `timers` blocks have been
   evaluated in a registration frame.

The gating is why a game with a broken map and a duplicate rule reports only the
map: the rules block has not been read yet. Fix the first list, build again, and
the second appears. Each gate reports everything it found.

### Gate 1 — declarations, map and placement

Two of these lines contain backticks; they are shown below as single quotes so
the table renders.

| Diagnostic | Cause and fix |
|---|---|
| `content bundles A and B share the namespace "N", so every property name any two of them have in common mints one entity ID and only one of those declarations survives; override 'var namespace' to give each bundle its own.` | Two instances of one ``GameContent`` type, or two types that overrode `namespace` to the same string. Override ``GameContent/namespace`` on one. |
| `the game stores "attic" (Attic), a content bundle it never lists in its content block; nothing it declares — rooms, items, globals, rules, verbs, timers — is registered. Add attic to 'var content'.` | A bundle held as a property but missing from ``Game/content``. |
| `"player" is a reserved entity ID (declared by MyGame); rename this declaration.` | The bootstrap synthesizes the player under that ID. Rename yours. |
| `entity "coin" is declared by both MyGame and Attic.` | Two declarations minted the same `EntityID`. Rename one, or namespace the bundle. |
| `"a" and "b" are the same Location value; each location must be its own declaration.` | One `Location` (or `Item`, or `Actor`) value assigned to two properties. Each entity is its own `let`. |
| `location "hall" has no name(…) trait.` | Also `item "…"` and `actor "…"`. Every entity needs a `name(…)` trait. |
| `the north exit references a location that is not a stored property of the game or any of its content bundles.` | Also `… references an item …`. The `map` block named something the reflection walk never saw — usually a computed property or one declared in an extension. |
| `"attic" declares its north exit more than once.` | Two `map` entries claim one direction. |
| `"attic"'s north exit uses "door" as a door, which is not declared openable.` | A door exit needs an ``openable`` item; `go` has no open state to gate on otherwise. |
| `"coin" is placed on "table", which is not declared as a surface.` | Declare ``surface``, or place it `inside`. |
| `"coin" is placed inside "box", which is not declared as a container.` | Declare ``container``. |
| `"sword" starts heldBy "troll", which is not an Actor.` | |
| `the map block declares player.starts(in:) more than once.` | |
| `the map block never declares player.starts(in:).` | |
| `"box" declares lockedBy more than once.` | |
| `the map closes a placement cycle: "box" inside "sack", "sack" inside "box"; nothing in a cycle is in any room, so none of it can ever be listed, reached, taken or seen, and no rule can undo a placement that was never valid. Place one of them in a room.` | Two or more placements close a loop. The message names every link. |
| `verb pattern "…" must start with a literal word.` | A custom ``SyntaxRule`` whose first element is a slot. |
| `verb pattern "…" has more than one <object> slot.` | Also `<second object>`, `direction`, and `topic`. |
| `verb pattern "…" puts the <second object> slot before <object>.` | |
| `verb pattern "…" must end with its topic slot.` | A topic is variable-width and unmeasured, so nothing may follow it. |
| `verb pattern "…" combines a topic slot with a <second object> slot.` | Also `… with a direction slot`. |
| `verb pattern "…" needs a literal word between an object slot and whatever follows it.` | Where an object phrase ends is arithmetic when everything behind it has a fixed width and a search otherwise; a search needs a word to search for. |

### Gate 2 — vocabulary

Every declared phrase goes through the same splitter as player input:
lowercased, a trailing `'s` dropped, every other non-alphanumeric a separator.
A declaration the splitter cannot turn into a word is dead on arrival, and used
to be silently so.

| Diagnostic | Cause and fix |
|---|---|
| `"coin" declares the name "…", which has no letters or digits in it; there is no word there for the parser to match.` | Also `the adjective "…"` and `the synonym "…"`. |
| `the verb pattern "…" declares the word "…", which the parser splits differently from what the player types; no input can reach it.` | A literal in a custom pattern that is not a single bare word. |
| `noise word "some" is also an item word; stripping it would make that word untypeable.` | The clause names what it collided with: `a verb word`, `a structural word in a verb pattern`, `a direction`, or `an item word`. Filler is dropped at tokenize time, before any matching, so a word that is both filler and a real word is a word nobody can type. The built-in articles (`the`, `a`, `an`, `my`, `that`, `this`, `some`) are checked against your declarations too, which is how an item that answers to `some` gets caught. |

### Gate 3 — rules and timers

| Diagnostic | Cause and fix |
|---|---|
| `item "chest" declares both a static description(…) and a describe { … } rule; an item may have only one.` | Also `location`, and `firstSight(…)` against `presence`. Pick the trait or the rule. |
| `item "chest" declares more than one describe { … } rule.` | Also `presence` and `reach`. |
| `a before rule (watching take, open) is attached to an item that is not a stored property of the game or any of its content bundles.` | Also `… to a location …`. The rule's scope token is opaque, so the phase and the intents it watches are the anchor for finding it in your source. |
| `item "chest" has a beforeEachTurn rule, which only locations support.` | Also `afterEachTurn` and `onEnter`. |
| `location "hall" has a presence rule, which only items and actors support.` | Also `reach`. |
| `a world-level onEnter rule is not supported.` | Also `describe`, `presence`, `reach`. |
| `two timers are both named "lantern"; timer names must be unique within the game and within each bundle.` | A bare name two *different* owners (game and bundle, or two bundles) both declare is namespaced at bootstrap and legal. This one is the same owner declaring the name twice — split the block or rename one. |
| `two timers both resolve to "Clock.roam"; a bare timer name must not collide with a bundle's namespaced timer key.` | The game (or a bundle) declares a timer whose bare name is exactly `"Namespace.name"` while that same `name` is contested and gets namespaced into `Namespace` — both declarations land on one schedule key and the second would silently win. Rename one. |
| `fuse "lantern" declares after: 0; a fuse needs at least one turn.` | |

## Non-fatal: the warning list

Warnings accumulate in the definition and are rendered by its warning report.
Each one describes a declaration that compiles, reads as live, and does nothing.

| Warning | Cause and fix |
|---|---|
| `custom verb "…" overrides a built-in verb of the same shape.` | A ``SyntaxRule`` in `verbs` matching a core row's verb word and shape with a different intent. Reclaiming is legal and last-wins; the warning exists so it is never an accident. |
| `verb row "throw <object> into <second object>" is "throw <object> in <second object>" respelled, and can never match: a pattern's preposition already answers to its synonyms.` | Two rows on the merged table — the game's own, a bundle's, or the engine's — differing only in how a preposition is spelled. `in` already answers to `inside` and `into`, and `on` to `onto` and `upon`, so the row named first takes every line the second would. Delete the second row. |
| `item "it" answers to "it", a reserved parser word (pronoun or multi-object keyword); the parser will never match it to this item.` | The reserved set is `it`, `them`, `all`, `everything`; they resolve before any item lexicon. Rename the noun or adjective. |
| `item "lamp" declares startsLit but is not a lightSource; the flag has no effect.` | Add ``lightSource``. |
| `item "box" declares startsUnlocked but has no lockedBy entry; the flag has no effect.` | Lockability comes from the `lockedBy` map entry, not a trait. |
| `item "robot" declares takesOrders but is not an actor; only a person can be given an order, and the flag has no effect.` | Declare it as an `Actor`. |
| `item "Vane" is named "Mrs. Vane", which reads as a proper name but is not declared properName; stock lines will say "the Mrs. Vane".` | Add ``properName``. Not inferred, because "Elvish sword" is a common noun and so is "Orange Grove Avenue". Locations are exempt — the engine never articles a room name. |
| `actor "troll" declares the item trait "container"; actors hold things via their inventory, and the trait will behave item-like if left in place.` | Checked for `wearable`, `scenery`, `surface`, `container`, `openable`, `startsOpen`, `transparent`, `lockable`, `startsUnlocked` and `capacity`. Legal, almost never meant; the trait is left in place rather than stripped. |
| `custom action for intent "undo" will never run; the engine answers undo before the turn pipeline.` | UNDO, RESTART, SAVE and RESTORE are answered before any stage runs. Nothing can override them. |
| `custom action for intent "take" overrides the built-in default of the same intent.` | Keyed off the **core** verb table, not the whole standard table, which is why overriding a stub verb is silent: a stub has no behavior to shadow, so the warning would be noise. See <doc:StubVerbs>. |
| `custom action for intent "brawl" overrides an earlier custom action of the same intent.` | Two `actions` rows for one intent; the later wins. Bundle rows come before the host game's. |
| `a rule watches intent "accuse", but no verb row produces it; if it was declared with #verb, list .accuse in a verbs block.` | Usually the forgotten `verbs` entry. The rule is fine; nothing typed can reach it. |
| `a verb row produces intent "accuse", but nothing answers it; give it an action(.accuse) or a rule, or the verb just prints the engine's fall-back line.` | The mirror of the above. A rule that answers one noun and leaves the rest to the fall-back is the documented pattern and warns nothing, and a catch-all rule with empty `intents` names no intent, so `world.beforeEachTurn` cannot switch this check off. |
| `location "cellar" declares alwaysDescribed but has no description(…) trait and no describe { … } rule; the flag has nothing to print.` | The flag un-hides a long description on revisits. With no long description, the transcript reads identically with the flag and without it. |
| `item "brazier" declares alwaysListed but has no firstSight(…) trait and no presence { … } rule; the flag has nothing to keep.` | The item-side twin of the row above. The flag keeps a listing paragraph printing past the first touch, so an item with no listing paragraph reads identically with the flag and without it. |
| `item "gem" declares firstSight(…) but the map places it 2 levels below the room — inside "box", inside "chest"; a room description lists what stands in the room and what those things hold, and goes no deeper, so the line has nowhere to print.` | Also `a presence { … } rule`, and `actor "…"`. Only a chain that reaches a room is judged: an item starting offstage or in somebody's hands has no static position for the map to be wrong about. |
| `the game's maxScore is 350, but its scoring content declares awards totalling 340; 10 point(s) of the maximum are unreachable.` | The other direction reads `10 point(s) can be scored past the maximum`. Content conforming to ``ScoreDeclaring`` knows its own award table; content that totals nothing returns `nil` and the check is skipped, so a deliberately unreachable ceiling stays shippable by opting out. |

## Reading diagnostics in a test

``BootstrapError`` is public and so is ``BootstrapError/diagnostics``, so a test
asserts on a bad game directly rather than through a transcript:

```swift
#expect(throws: BootstrapError.self) {
    _ = try GameWorld(game: BadGame())
}
```

Inside the engine's own suite, where `Bootstrap` is visible, calling
`Bootstrap.build(BadGame())` directly gets at the diagnostic array itself, which
is how the exact strings above are pinned. <doc:TestingYourGame> covers that
side, including the fixture games in `Tests/GnustoTests/Support/`.

## `GNUSTO_STACK_REPORT`

The bootstrap runs on a thread the engine sizes at 16 MB rather than on whatever
stack it was called from, because the stack it costs scales with the whole
declaration surface and a Swift Testing body has 512 KB of its own. Setting
`GNUSTO_STACK_REPORT` prints what a boot actually used, one line per game, on
stderr:

```
$ GNUSTO_STACK_REPORT=1 swift run Dungeon
Gnusto: Dungeon bootstrapped using 340 KB of the 16384 KB bootstrap stack.
```

It is a flag in the manner of `GNUSTO_PLAIN`, so any value counts, including an
empty one. Deliberately not a warning: stack usage varies with build mode,
platform and address-space layout, and a machine-dependent figure in the list
above would fire on some machines and not others. Dungeon is 23 content bundles
and some 800 declarations, which is the sense of scale to read 340 KB against.
See <doc:SplittingAGameAcrossFiles>.

## Topics

- ``BootstrapError``
- ``BootstrapError/diagnostics``
- ``GameContent/namespace``
- ``Game/content``
- ``Game/verbs``
- ``Game/actions``
- ``Game/timers``
- ``Game/maxScore``
- ``ScoreDeclaring``
- ``ScoreDeclaring/declaredMaxScore(items:)``
- ``SyntaxRule``
- ``firstSight(_:)``
- ``properName``
- ``alwaysDescribed``
- ``alwaysListed``
- ``lightSource``
- ``startsLit``
- ``startsUnlocked``
- ``takesOrders``
- ``openable``
- ``container``
- ``surface``

## See also

- <doc:AnatomyOfAGame>
- <doc:ContentBundles>
- <doc:StubVerbs>
- <doc:TestingYourGame>
- <doc:SplittingAGameAcrossFiles>
