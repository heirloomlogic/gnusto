# Anatomy of a Game

How a single Swift type becomes a world the engine can run.

## Overview

A Gnusto game is one type conforming to ``Game``. That one type carries everything: the rooms and things, where they start, and the rules that govern them. This article covers the model underneath — how the engine finds your declarations, how one value is both a declaration and a live reference, and how the immutable world is kept separate from the state that changes as the player plays.

Once that model is clear, the rest of Gnusto follows from it.

## Declarations are stored properties

Rooms, things, and custom state are declared as **stored properties** of the game type:

```swift
struct OperaHouse: Game {
    let foyer = Location { name("Foyer of the Opera House") }
    let bar   = Location { name("Foyer Bar"); dark }
    let cloak = Item { name("velvet cloak"); wearable }
    @Global var disturbances = 0
}
```

When you construct the world with ``GameWorld/init(game:)``, the engine's bootstrap reflects over the game value with `Mirror` and collects every ``Location``, ``Item``, and ``Global``. It names each entity after the property it was stored in: `foyer` becomes ``EntityID`` `"foyer"`, `cloak` becomes `"cloak"`, and so on. You never write these IDs by hand — the property name *is* the name.

This is why declarations must live in the type's main body, not an extension: Swift only allows stored properties there, and the Mirror only sees stored properties. (When even the declarations need to span files or ship separately, that is what a ``GameContent`` bundle is for — see <doc:ContentBundles>.)

## One value, two roles

A declaration and a live reference are the *same value*.

```swift
let cloak = Item { name("velvet cloak"); wearable }   // the declaration

// …later, inside a rule body:
cloak.after(.take) {
    if cloak.isWorn { … }        // the live reference — reads current state
}
```

`cloak` is an ``Item`` value. Written in the game body it *declares* the cloak. Used in a rule it *reads and writes the live cloak's state*: ``Item/isWorn``, ``Item/isHeld``, ``Item/name``, and so on all consult the current turn.

This works because each ``Location`` and ``Item`` mints a private identity token when it is created. The token — not the struct's contents — is the entity's identity, and it survives copying. Two items are equal when they share a token (``Item/==(_:_:)``). Inside a turn, the token resolves to the entity's ``EntityID`` and then to its state; outside a turn there is no state to read, so a live property access traps with an explanation rather than returning a meaningless value.

References are always compile-checked. `cloak.after(.take)`, `hook.holds(cloak)`, `foyer.north(bar)` — every one is ordinary property access, so renaming a room or deleting an item breaks the build instead of the running game.

## The parts of the `Game` protocol

``Game`` gathers a handful of members, most with defaults so a small game declares only what it needs:

- `title`, `intro`, `tagline`, `maxScore` — the banner and scoring metadata.
- `map` — geography and initial placement, as a ``WorldMap``. Read once at startup to build the initial state.
- `rules` — all game logic, as a ``Rules`` value. Defaults to empty.
- `verbs` — player-typeable verbs this game adds, as `[SyntaxRule]`. Defaults to empty. See <doc:AddingCustomVerbs>.
- `content` — content bundles the game composes itself from, as ``GameContents``. Defaults to empty. See <doc:ContentBundles>.

The protocol extension also hands every game three ambient references usable as bare identifiers inside `map` and `rules` blocks:

- `player` — the ``Player``, for its location, score, and inventory.
- `world` — the ``World``, for rules that apply everywhere (like daemons).
- `command` — the ``Command`` currently being performed, inside a rule body.

## The `map` block

`map` is a result-builder property that yields a ``WorldMap`` — a flat list of ``MapEntry`` statements: exits, blocked exits, initial item placements, and the player's start.

```swift
var map: WorldMap {
    foyer.south(bar)                 // an exit
    foyer.north(blocked: "Not yet.") // a blocked exit with a refusal message
    bar.north(foyer)

    player.starts(in: foyer)         // where the player begins
    cloak.startsWorn                 // where each thing begins
    hook.starts(in: cloakroom)
}
```

Exits are directional and one-way: `foyer.south(bar)` does not imply `bar.north(foyer)`. Declaring both is deliberate, so asymmetric maps (a chute, a one-way door) need no special case. Because `map` is a builder, you can split it across files and compose it from sub-maps — see <doc:SplittingAGameAcrossFiles>.

## Immutable definition, mutable state

Internally, the engine keeps two things strictly apart:

- The **definition** is everything that never changes during play: names, descriptions, exits, rules, and the parser's vocabulary. It is built once, from your declarations, at startup.
- The **state** is everything that *does* change: where each item is, what is lit, the score, the turn count, which things have been touched, and your ``Global`` values.

The entire mutable state is a single `Codable` value. That is a deliberate design choice: because all change funnels through one value, a turn's mutations can be committed atomically at its end (see <doc:TheTurnPipeline>), and save/restore becomes a serialization call rather than a feature bolted across the codebase.

When you write `cloak.isWorn` or `player.score += 1` in a rule, you are reading and writing that one state value through the entity's token — never touching the definition, and never seeing another turn's half-finished changes.

## See also

- <doc:GettingStarted>
- <doc:TheTurnPipeline>
- <doc:WritingRules>
