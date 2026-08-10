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
| An ``Item`` | `before`, `after`, `describe` |
| A ``Location`` | `before`, `after`, `beforeEachTurn`, `afterEachTurn`, `onEnter`, `describe` |
| The ``World`` | `before`, `after`, `beforeEachTurn`, `afterEachTurn` |

- `before(_:perform:)` runs before the default action, for the listed intents. Veto the action with ``refuse(_:)``, or handle it yourself with ``reply(_:)``.
- `after(_:perform:)` runs after the default action succeeded, for the listed intents. React to what happened.
- `beforeEachTurn` / `afterEachTurn` run on *every* turn spent in the location (or, on `world`, everywhere) regardless of intent — the home for daemons and timers. `afterEachTurn` runs even on refused turns, because world time still passes.
- `onEnter` (locations only) runs the moment the player arrives, just before the room is auto-described.
- `describe` supplies a *live description* that is recomputed each time the item or location is described — see **Live descriptions with `describe`** below.

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

Items expose ``Item/isHeld``, ``Item/isWorn``, ``Item/isTouched``, ``Item/name``, a settable ``Item/description``, ``Item/holds(_:)``, the scope questions ``Item/isReachable``, ``Item/isReachable(from:)`` and ``Item/isVisible``, and the movers ``Item/move(to:)``, ``Item/vanish()`` and ``Item/replace(with:)``, which swaps one thing for another where it stands:

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

``Player/item`` is the player themselves as a thing in the world — what `X ME` examines. The engine synthesizes it, so no game declares it, but it is an ordinary ``Item``: give it a `describe { }` rule, set its ``Item/description`` at runtime, hang `before`/`after` rules on it. It is always in scope and never in a room, so it appears in no room description, no inventory, and no `TAKE ALL`.

```swift
player.item.describe {
    player.isCarrying(lantern) ? "Lit from below, and grubby." : "Grubby."
}
```

Without a rule, examining yourself prints ``GameText/selfDescription``, alongside the other stock lines a game can re-skin — ``GameText/cantTakeSelf``, ``GameText/cantSearchSelf``, ``GameText/cantGreetSelf``, ``GameText/cantFollowSelf``.

The command being performed is available as `command` (``Command``): its ``Command/intent``, ``Command/directObject``, ``Command/indirectObject``, ``Command/direction``, ``Command/preposition``, and the raw ``Command/verbPhrase`` the player typed.

```swift
bar.beforeEachTurn {
    guard !bar.isLit else { return }
    if command.intent == .go, command.direction == .north { return }
    try refuse("Blundering around in the dark isn't a good idea!")
}
```

For state the engine doesn't already track — a wallet, an item's price, a creature's HP — reach for a ``Global`` or a custom trait. See <doc:CustomStateAndTraits>.

## Live descriptions with `describe`

A `description(…)` trait is fixed text. When what the player should read depends on the world — a lantern that reads differently lit or dark, a trapdoor open or shut — attach a ``Item/describe(_:)`` (or ``Location/describe(_:)``) rule instead. It takes a closure that the engine calls *every time the entity is described*, so it always reflects the current state:

```swift
var rules: Rules {
    lantern.describe {
        lantern.isLit
            ? "The lantern is on, casting a warm circle of light."
            : "A battered brass lantern, presently dark."
    }
}
```

Like any rule, `describe` is declared in the `rules` block, and the closure reads live state through your declarations — including the entity's own (here, `lantern.isLit`).

Three things are worth knowing:

- **`describe` and a static `description(…)` are mutually exclusive.** Declaring both on the same entity — or two `describe` rules for it — is a fatal ``BootstrapError`` caught at startup, not a silent last-writer-wins. Pick one per entity.
- **A runtime assignment still wins.** Setting ``Item/description`` (or ``Location/description``) directly in a rule overrides the `describe` closure from then on — useful for a one-way change like a lever that reveals a passage.
- **Keep the closure pure.** It runs on every look and examine; read state, return a string, and don't mutate the world from inside it.

## When the room's description *is* the state

A room is described in full the first time the player walks in and briefly on every entry after that — its name and the things lying in it, but not its long description, because the player has already read it. That is the classic behaviour and it is right for a room made of stone.

It is wrong for a room the player is *rewriting*. A sliding-block floor, a mirror box, a machine whose dials have moved: there the `describe { … }` closure is the only readout there is, and a brief re-entry silently withholds it. The player types `undo` after a push and gets the heading and nothing under it. Declare ``alwaysDescribed`` and the long description prints on every entry too:

```swift
let puzzle = Location {
    name("Room in a Puzzle")
    alwaysDescribed
}
```

It is opt-in, one room at a time; every other room keeps the brief revisit. The three paths it fixes are UNDO, RESTORE, and walking back in through an exit — all of which re-describe as an entry rather than as a LOOK. On a room with nothing to print — no `description(…)` and no `describe { … }` — the trait is a bootstrap warning, since it has no text to un-hide.

The other half of the same problem is a rule that moves the player *within* one room. ``describeSurroundings(withRoomName:)`` re-describes from a rule body, and by default it is a full LOOK, heading included — so a step-by-step puzzle that re-describes on every move announces the same arrival nineteen times. Pass `withRoomName: false` and everything but the heading prints:

```swift
puzzle.before(.go) {
    // …walk one square of the grid…
    describeSurroundings(withRoomName: false)
    try handled()
}
```

Between them: the trait decides *what* a description contains, the argument decides whether it opens by announcing where the player is.

A rule that moves the player *between* rooms wants both halves at once, and ``arrive(at:withRoomName:)`` is the pair written once:

```swift
mirror.before(.touch) {
    say("The room spins, and settles the other way round.")
    arrive(at: mirrorRoomSouth)
    try handled()
}
```

It does not end the turn — so it is as legal in an `after` rule or a daemon as in a `before` one — and it fires no `onEnter` on the destination, because it is a teleport rather than a walk.

### Teleporting or walking in: `arrive(at:)` and `enter(_:)`

Which is usually what you want. Sometimes it isn't, and then ``enter(_:)`` is the other move — everything a `go` through an exit does once the exit itself has passed:

```swift
stairs.before(.climb) {
    say("You haul yourself up.")
    try enter(belfry)
    try handled()
}
```

|  | ``arrive(at:withRoomName:)`` | ``enter(_:)`` |
|---|---|---|
| the destination's `onEnter` rules | don't run | **run**, before the room is described |
| a boarded vehicle | stays where it was | **comes along**, cargo and all |
| the description | a full LOOK, every time | an **entry** — brief on a revisit |
| ends the turn | no | no |

So `enter(_:)` `throws`: an `onEnter` rule that ``die(_:)``s or ``refuse(_:)``s ends the turn from inside the move, and the room is then never described.

Reach for `arrive(at:)` when the game is *putting* the player somewhere — a trapdoor, a spell, a scripted transition — and for `enter(_:)` when the fiction is that they walked. The choice is worth making rather than defaulting: a room that scores, announces or kills on arrival gets that from its `onEnter` rules, so a teleport into it has to repeat the room's own logic, and the two can drift apart.

## Live room-listing lines with `presence`

`describe` supplies the *examine* text. The other line the engine prints about an entity is its paragraph in the room description — the ``firstSight(_:)`` trait, shown until the player touches an item and shown on every look for an actor. ``Item/presence(_:)`` (or ``Actor/presence(_:)``) is its live form, and it follows exactly the same rules as `describe`:

```swift
var rules: Rules {
    constance.presence {
        constance.isIn(parlour)
            ? "Mrs. Vane is in her chair with the lamp unlit."
            : "Mrs. Vane is on the step and no further."
    }
}
```

`presence` and a static `firstSight(…)` on the same entity — or two `presence` rules for it — is the same fatal ``BootstrapError``. A `presence` rule on a location is a diagnostic too: rooms have descriptions, not presence lines.

The line is consulted wherever the room *lists* the thing, not only when it is lying on the floor — so an item that starts inside a container or on a surface gets its own paragraph in place of the stock *"In the chest is a tan label."*, and a rule can say which:

```swift
tanLabel.presence {
    boat.holds(tanLabel)
        ? "A tan label is lying inside the boat."
        : "There is a tan label here."
}
```

One level, which is as far as the listing itself goes: a room describes the things standing in it and what those hold, not what *their* contents hold.

This is the rule to reach for when somebody moves. A person on a schedule ends up described in terms of the room they left, and no amount of careful static wording fixes that.

## Live reach with `reach`

The third text-free phase. ``Item/reach(otherwise:_:)`` answers "can the player put a hand on this from where they are standing", and the engine asks it wherever a verb has to *touch* something — so a room the map keeps as one place and the game divides into squares says that once rather than guarding `take`, `open` and `put in` one rule at a time:

```swift
var rules: Rules {
    card.reach(otherwise: "The card is squares away from you, across the sand.") {
        grid.playerSquare == grid.cardSquare
    }
}
```

It runs at **stage 0**, ahead of every `before` rule — which is the point, since an item that answers its own verb pre-empts the default action. Two `reach` rules on one entity is a fatal ``BootstrapError``; locations don't take one. <doc:ContainersDoorsAndLocks> has what it does and doesn't cover.

## Produce output and control the turn

Five free functions are available in any rule body:

- ``say(_:)`` — add a line to the turn's output and keep going. The default action still runs.
- ``refuse(_:)`` — print a complaint and abort the action (and remaining rules).
- ``reply(_:)`` — print a response *in place of* the default action. Same mechanics as `refuse`, different intent: use it when your rule is the behavior, not a veto.
- ``handled()`` — finish an action without adding a line, after the rule has already produced its whole response with ``say(_:)``.
- ``end(won:)`` — end the game; the engine prints the final score afterward.

`say` returns normally; the other four return `Never` and read well after a `guard … else`.

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
- <doc:ContainersDoorsAndLocks>
