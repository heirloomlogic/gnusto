# Writing Rules

Attach game logic to items, locations, and the world.

## Overview

Rules are where a game stops being a map of static rooms and starts reacting. A rule is a phase (when it runs), an owner (what it watches), an optional set of intents (which actions it cares about), and a body of ordinary Swift that reads and writes the live world.

Every rule lives in a game's `rules` block, which yields a ``Rules`` value:

```swift
var rules: Rules {
    cloak.after(.take, .wear)  { bar.isLit = false }
    bar.beforeEachTurn         { … }
    world.after(.go)           { … }
}
```

This guide is a catalogue of what you can attach and how the bodies read state. For the order rules fire in, see <doc:TheTurnPipeline>.

## Choose an owner and a phase

A rule is created by a factory method on the thing it watches. Three owners are available:

| Owner | Factories |
|---|---|
| An ``Item`` | `before`, `after` |
| A ``Location`` | `before`, `after`, `beforeEachTurn`, `afterEachTurn`, `onEnter` |
| The ``World`` | `before`, `after`, `beforeEachTurn`, `afterEachTurn` |

- `before(_:perform:)` runs before the default action, for the listed intents. Veto the action with ``refuse(_:)``, or handle it yourself with ``reply(_:)``.
- `after(_:perform:)` runs after the default action succeeded, for the listed intents. React to what happened.
- `beforeEachTurn` / `afterEachTurn` run on *every* turn spent in the location (or, on `world`, everywhere) regardless of intent — the home for daemons and timers. `afterEachTurn` runs even on refused turns, because world time still passes.
- `onEnter` (locations only) runs the moment the player arrives, just before the room is auto-described.

## Match specific intents

The intents you pass to `before`/`after` filter the rule. List one or several; list none to match every action.

```swift
// Only when the player tries to take OR wear the cloak:
cloak.before(.take, .wear) { … }

// On any action targeting the statue:
statue.before() { say("The statue's eyes seem to follow you.") }
```

The built-in intents are constants on ``Intent`` (``Intent/take``, ``Intent/drop``, ``Intent/examine``, ``Intent/go``, and so on). Custom verbs mint their own — `Intent("ring")` — which you match the same way. See <doc:AddingCustomVerbs>.

## Read and write live state

Inside a rule body, your declarations *are* the live entities. The bare identifiers `player`, `command`, `world`, and every room and item you declared resolve to the current turn's state.

Items expose ``Item/isHeld``, ``Item/isWorn``, ``Item/isTouched``, ``Item/name``, a settable ``Item/description``, ``Item/holds(_:)``, and the movers ``Item/move(to:)`` and ``Item/vanish()``:

```swift
lever.after(.take) {
    say("It comes loose in your hand.")
    trapdoor.description = "The trapdoor now stands open."
}
```

Locations expose a settable ``Location/isLit``, ``Location/isVisited``, ``Location/contains(_:)``, ``Location/name``, and a settable ``Location/description``:

```swift
cloak.after(.drop, .putOn) { bar.isLit = true }
```

The player exposes a settable ``Player/location`` (assigning teleports without describing the destination), a settable ``Player/score``, ``Player/moves``, ``Player/isCarrying(_:)``, and ``Player/isWearing(_:)``:

```swift
message.before(.read) {
    player.score += 1
    say(message.description)
    try end(won: true)
}
```

The command being performed is available as `command` (``Command``): its ``Command/intent``, ``Command/directObject``, ``Command/indirectObject``, ``Command/direction``, ``Command/preposition``, and the raw ``Command/verbPhrase`` the player typed.

```swift
bar.beforeEachTurn {
    guard !bar.isLit else { return }
    if command.intent == .go, command.direction == .north { return }
    try refuse("Blundering around in the dark isn't a good idea!")
}
```

For state the engine doesn't already track — a wallet, an item's price, a creature's HP — reach for a ``Global`` or a custom trait. See <doc:CustomStateAndTraits>.

## Produce output and control the turn

Four free functions are available in any rule body:

- ``say(_:)`` — add a line to the turn's output and keep going. The default action still runs.
- ``refuse(_:)`` — print a complaint and abort the action (and remaining rules).
- ``reply(_:)`` — print a response *in place of* the default action. Same mechanics as `refuse`, different intent: use it when your rule is the behavior, not a veto.
- ``end(won:)`` — end the game; the engine prints the final score afterward.

`say` returns normally; the other three return `Never` and read well after a `guard … else`.

## Compose rules across regions

`rules` is a result-builder, and it accepts whole ``Rules`` values as well as individual rules. Break a large game's logic into per-region helper properties and splice them together:

```swift
var rules: Rules {
    foyerRules      // a Rules value defined in another file
    cloakroomRules
    barRules
}
```

This is the same composition that lets a big game span multiple files — see <doc:SplittingAGameAcrossFiles>.

## See also

- <doc:TheTurnPipeline>
- <doc:AddingCustomVerbs>
- <doc:CustomStateAndTraits>
