# Bootstrap Diagnostics

Every message the bootstrap can print, and what to change.

## Overview

A Gnusto game is validated once, at boot. `Bootstrap.build` reads every
declaration the game and its content bundles make, checks them against each
other, and either hands back a definition or reports every problem it found at
once — never the first one, because a game with four mistakes in its map should
cost one build to find all four.

Reports use a stable order. A build with the same mistakes therefore prints
the same list in the same order.

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

That is the ``GameMain`` path and the MCP play-test server, which writes the same report to standard error and also carries it in the `survey` tool's result, so an agent sees it without reading the client's log. A world built by hand — a test calling `play(_:_:)`, a custom front end constructing ``GameWorld`` itself — prints nothing, so run the game once as a binary after changing declarations.

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
2. **Vocabulary**, after every item's and actor's declared name, synonym and adjective, every verb-pattern literal and every noise word has been split the way the tokenizer splits player input. A location's name is not vocabulary — nothing parses a room name — so it is not split or checked.
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
| `plugin "combat" (CombatPlugin) stores @Global "round"; a GamePlugin cannot declare global state. Use a GameContent bundle instead.` | Also `Location`, `Item`, and `Actor`. A logic-only ``GamePlugin`` cannot own declarations because the bootstrap does not register or namespace them. Move stateful content to ``GameContent``. |
| `"player" is a reserved entity ID (declared by MyGame); rename this declaration.` | The bootstrap synthesizes the player under that ID. Rename yours. |
| `entity "coin" is declared by both MyGame and Attic.` | Two declarations minted the same `EntityID`. Rename one, or namespace the bundle. |
| `"a" and "b" are the same Location value; each location must be its own declaration.` | One `Location` (or `Item`, or `Actor`) value assigned to two properties. Each entity is its own `let`. |
| `location "hall" has no name(…) trait.` | Also `item "…"` and `actor "…"`. Every entity needs a `name(…)` trait. |
| `item "coin" declares name(…) more than once.` | Also `description(…)`, `firstSight(…)`, the two-state description forms, `pronoun(…)`, `capacity(…)`, custom traits, and location names/descriptions/custom traits. These are single-valued declarations; remove the duplicate instead of relying on the later value. `adjectives` and `synonyms` deliberately accumulate. |
| `the north exit from "hall" references a location that is not a stored property of the game or any of its content bundles.` | Also `… door from "hall" references an item …`. The `map` block named something the reflection walk never saw — usually a computed property or one declared in an extension. If the source is also unresolved, the diagnostic names the direction instead. |
| `"attic" declares its north exit more than once.` | Two `map` entries claim one direction. |
| `"coin" declares its placement more than once: first in "hall", then inside "box".` | An item can have one initial position. This applies to every placement spelling: `starts(in:)`, `starts(on:)`, `starts(inside:)`, `startsWorn`, `startsHeld`, and `starts(heldBy:)`, including declarations split between the host map and a content bundle's map. Remove one entry. |
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
| `the verb pattern "…" declares the word "…", which must be a single lowercase alphanumeric token the parser can match.` | A literal in a hand-built custom pattern that contains punctuation or whitespace, or uses uppercase. `#verb` rejects the same spelling at compile time. |
| `noise word "some" is also an item word; stripping it would make that word untypeable.` | The clause names what it collided with: `a verb word`, `a structural word in a verb pattern`, `a direction`, or `an item word`. Filler is dropped at tokenize time, before any matching, so a word that is both filler and a real word is a word nobody can type. The built-in filler (`the`, `a`, `an`, `my`, `that`, `this`, `some`, `please`) is checked against your declarations too, which is how an item that answers to `some` gets caught. |

### Gate 3 — rules and timers

| Diagnostic | Cause and fix |
|---|---|
| `item "chest" declares both a static description(…) and a describe { … } rule; an item may have only one.` | Also `location`, and `firstSight(…)` against `presence`. A two-state trait counts as the static text and is named as written — `a static description(when:_:otherwise:) and a describe { … } rule` — so the line can be grepped for. Pick the trait or the rule. |
| `item "chest" declares both description(…) and description(when:_:otherwise:); an item may have only one.` | Also `firstSight(…)` against `firstSight(when:_:otherwise:)`. The two-state trait *is* the description; there is no fixed text for it to fall back on. |
| `item "statue" declares description(when: \Actor.isUnconscious, …) but is not an actor; only an Actor has that Bool.` | An `Actor` key path names state only a person carries. Declare the thing an ``Actor``, or key on one of ``Item``'s own Bools. |
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
| `item "it" answers to "it", a reserved parser word (pronoun or multi-object keyword); the parser will never match it to this item.` | The reserved set is `it`, `them`, `him`, `her`, `all`, `everything`; they resolve before any item lexicon. Rename the noun or adjective — and for `him`/`her`, declare ``pronoun(_:)`` instead, which is what binds those two. |
| `item "lamp" declares startsLit but is not a lightSource; the flag has no effect.` | Add ``lightSource``. |
| `item "box" declares startsUnlocked but has no lockedBy entry; the flag has no effect.` | Lockability comes from the `lockedBy` map entry, not a trait. |
| `item "box" declares startsOpen but is not openable; the flag has no effect.` | Add ``openable``, or remove ``startsOpen``. |
| `item "box" declares capacity but is not a container; the trait has no effect.` | Add ``container``, or remove the capacity. |
| `item "window" declares transparent but is not a container; the trait has no effect.` | Transparency only exposes a closed container's contents. Add ``container``, or remove ``transparent``. |
| `item "hat" starts worn but is not wearable; the placement creates an item the player cannot remove or wear again.` | Add ``wearable``, or use `startsHeld`. |
| `item "robot" declares takesOrders but is not an actor; only a person can be given an order, and the flag has no effect.` | Declare it as an `Actor`. |
| `item "Vane" is named "Mrs. Vane", which reads as a proper name but is not declared properName; stock lines will say "the Mrs. Vane".` | Add ``properName``. Not inferred, because "Elvish sword" is a common noun and so is "Orange Grove Avenue". Locations are exempt — the engine never articles a room name. |
| `item "lamp" gives one sentence to firstSight(…) and description(…); the room listing is spent on first touch and EXAMINE is not, so examining it while it is held will assert where it is lying.` | The two channels are read at different times: the listing line prints until the item is touched, the examine text prints forever. One sentence that says where the thing lies is true on the first and false on the second. Write two sentences. |
| `actor "troll" declares the item trait "container"; actors hold things via their inventory, and it will behave item-like if left in place.` | Checked for `wearable`, `scenery`, `surface`, `container`, `openable`, `startsOpen`, `transparent`, `startsUnlocked`, `capacity`, and a `lockedBy` map entry — the message reads `actor "troll" declares a lockedBy entry; …` for that one, since there is no `lockable` trait to declare. Legal, almost never meant; the actor is left as declared rather than stripped of the trait. |
| `custom action for intent "undo" will never run; the engine answers undo before the turn pipeline.` | UNDO, RESTART, SAVE, RESTORE, AGAIN and OOPS are answered before any stage runs. Nothing can override them. |
| `custom action for intent "take" overrides the built-in default of the same intent.` | Keyed off the **core** verb table, not the whole standard table, which is why overriding a stub verb with a *closure* row or a rule is silent: a stub has no behavior to shadow, so the warning would be noise. The *line* form is the one exception, next row. See <doc:StubVerbs>. |
| `default line for intent "sing" replaces the engine's stub verb; assign text.stubs.sing instead, which keeps the verb's own guards.` | `action(.sing, say: …)` on an intent the engine already answers with a stub. The line works, but `text.stubs.sing = …` is the same sentence and keeps the verb's reach guard, the object's rendered name and the `yourself`/`somebodyElse` guards. |
| `the default line for intent "wind" names its object, but the verb row "wind" takes none; that command would answer with a parse error. Use action(.wind, orBare:naming:), which asks for both halves.` | A `naming:` line is built out of the object's name and has nothing to say without one, so a bare row for the same verb would fall through to the parser's failure and cost a turn. Give the bare half its own sentence with `orBare:`. |
| `custom action for intent "brawl" overrides an earlier custom action of the same intent.` | Two `actions` rows for one intent; the later wins. Bundle rows come before the host game's. |
| `a rule watches intent "accuse", but no verb row produces it; if it was declared with #verb, list .accuse in a verbs block.` | Usually the forgotten `verbs` entry. The rule is fine; nothing typed can reach it. |
| `a verb row produces intent "accuse", but nothing answers it; give it an action(.accuse) or a rule, or the verb just prints the engine's fall-back line.` | The mirror of the above. A rule that answers one noun and leaves the rest to the fall-back is the documented pattern and warns nothing, and a catch-all rule with empty `intents` names no intent, so `world.beforeEachTurn` cannot switch this check off. |
| `location "cellar" declares alwaysDescribed but has no description(…) trait and no describe { … } rule; the flag has nothing to print.` | The flag un-hides a long description on revisits. With no long description, the transcript reads identically with the flag and without it. |
| `item "brazier" declares alwaysListed but has no firstSight(…) trait and no presence { … } rule; the flag has nothing to keep.` | The item-side twin of the row above. The flag keeps a listing paragraph printing past the first touch, so an item with no listing paragraph reads identically with the flag and without it. |
| `item "slab" declares description(when: \.isOpen, …) but is not openable; the flag never changes, so one of its two texts never prints.` | Also `firstSight(when:…)`, and `\.isLit` without `lightSource`, `\.isLocked` without a `lockedBy` entry, `\.isWorn` without `wearable`. A two-state text keyed on a Bool the item cannot change has one state. Add the trait, or key on a Bool that moves. `\.isRevealed` warns on anything (`is never described before it is revealed`): neither channel is asked about a `hidden` thing until `reveal()`, and nothing else is ever unrevealed. |
| `item "coin" declares firstSight(when: \.isTouched, …) but is not alwaysListed; the listing stops at the first touch, so one of its two texts never prints.` | The listing channel's own dead branches: `\.isTouched` without ``alwaysListed`` (an actor's line is standing and exempt), `\.isHeld` (`is never listed while it is held`), and on either channel `\.isVisible` (`is only described while it is visible`). The same Bools are live on the examine channel, which is asked whatever the player holds. |
| `item "gem" declares firstSight(when:_:otherwise:) but the map places it 2 levels below the room — …` | The buried-listing warning below, naming the two-state trait rather than the `presence { … }` rule it lowers into. |
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
- ``pronoun(_:)``
- ``alwaysDescribed``
- ``alwaysListed``
- ``lightSource``
- ``startsLit``
- ``startsUnlocked``
- ``takesOrders``
- ``openable``
- ``container``
- ``surface``

## Entity interpolation warns at compile time

Interpolating an `Item`, `Actor`, or `Location` directly into a `String` produces a
compiler warning. Use `item.definiteName` or `item.indefiniteName`, the corresponding
actor properties, or `location.name` in prose. Ignoring the warning preserves the
existing struct dump; interpolation does not read live game state for you.

Swift skips unavailable interpolation overloads and falls back to its generic
implementation, so Gnusto uses deprecated overloads to issue this warning. Build
with `-warnings-as-errors` (`swift build -Xswiftc -warnings-as-errors`) to reject it.
Values erased to `Any` or passed through an unconstrained generic still use Swift's
generic interpolation and cannot receive this type-specific warning.


## See also

- <doc:AnatomyOfAGame>
- <doc:ContentBundles>
- <doc:StubVerbs>
- <doc:TestingYourGame>
- <doc:SplittingAGameAcrossFiles>
