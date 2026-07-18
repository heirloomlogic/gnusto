# Containers, Doors, and Locks

Hold things, open and close, lock with keys, and gate the map.

## Overview

Most of what makes a world feel physical comes from a small family of item traits: things you can put objects **on** or **inside**, things that **open and close**, things a **key** locks, and **doors** that gate one room from the next. All of them are declared the same way as any other trait — a word inside an `Item { … }` block, or, for the lock/key relationship, one line in the `map` — and all of them expose live state you can read and set from a rule.

For the traits themselves see ``ItemTrait``; for writing the rules that react to them see <doc:WritingRules>.

## Surfaces and containers

A ``surface`` is something other items can rest **on**; a ``container`` is something they can go **inside**. Declaring the trait is all it takes — the parser then accepts `put book on table` and `put coin in box`, and the items travel with their holder.

```swift
let table = Item {
    name("wooden table")
    description("A sturdy oak table.")
    surface
    scenery
}

let sack = Item {
    name("brown sack")
    adjectives("brown")
    description("A soft brown sack.")
    container
    openable
}
```

Cap how much a container holds with ``capacity(_:)`` — the put-in action refuses once it's full:

```swift
let basket = Item {
    name("wicker basket")
    container
    capacity(3)
}
```

Inside a rule, the live relationships are:

- ``Item/holds(_:)`` — is that item on or inside this one?
- ``Item/contents`` — everything currently on or inside it, sorted for stable iteration.
- ``Item/move(inside:)`` and ``Item/move(onto:)`` — place an item directly, bypassing the parser (they trap if the target isn't a container or surface).

```swift
box.after(.open) {
    if box.holds(gem) {
        say("Nestled inside is a glittering gem.")
    }
}
```

## Opening and closing

A bare ``container`` is *always open* — its contents are reachable at all times. Add ``openable`` to give it a lid the player must work: an openable item **starts closed** unless it also declares ``startsOpen``. The parser handles `open sack` and `close sack`; a closed container hides and blocks its contents.

```swift
let chest = Item {
    name("treasure chest")
    container
    openable          // starts closed
}

let cupboard = Item {
    name("cupboard")
    container
    openable
    startsOpen        // begins the game open
}
```

``transparent`` splits the difference: the contents are *visible* even while the item is closed — a glass jar, a display case — but still not *reachable* until it's opened. (The same trait lets light through a shut container; see <doc:DarknessTimeAndDeath>.)

```swift
let jar = Item {
    name("glass jar")
    container
    openable
    transparent       // you can see what's inside a closed jar; you can't take it yet
}
```

Read and set the state with ``Item/isOpen``. It reflects the current state of an openable item; assigning to something that isn't openable is a harmless no-op.

```swift
lid.after(.push) {
    chest.isOpen = true
    say("The lid swings back.")
}
```

## Locks and keys

A lock is declared not as a trait but as a relationship in the `map` block: ``Item/lockedBy(_:)`` names the key that locks and unlocks an item. The entry alone makes the item lockable — there's no separate `lockable` trait — and it **starts locked** unless the item also declares ``startsUnlocked``.

```swift
let chest = Item {
    name("iron chest")
    container
    openable
}

let brassKey = Item {
    name("brass key")
    adjectives("brass")
}

var map: WorldMap {
    chest.lockedBy(brassKey)      // chest starts locked; the brass key works it
    // …placements…
}
```

The player then types `unlock chest with brass key` before `open chest`, and `lock chest with brass key` to secure it again. Because the key is an ordinary property reference, renaming it is a compile error, not a broken game. Two guard-rails are enforced at startup as fatal ``BootstrapError``s: naming a key that isn't a stored property, and giving one item two `lockedBy` entries.

Read and set the lock from a rule with ``Item/isLocked`` (a no-op on a non-lockable item):

```swift
panel.after(.push) {
    vault.isLocked = false
    say("Something clicks, and the vault unlocks.")
}
```

## Doors between rooms

A door is just an ``openable`` item shared between two rooms and named as the gate on the exit. Use the directional `via:` form (or the general ``Location/exit(_:to:via:)``) on **both** sides, passing the same item — the exit is passable only while that door is open.

```swift
let trapDoor = Item {
    name("trap door")
    openable
    scenery
}

var map: WorldMap {
    livingRoom.down(cellar, via: trapDoor)
    cellar.up(livingRoom, via: trapDoor)
}
```

Because a door is an ordinary item, everything above composes: give the door a ``Item/lockedBy(_:)`` entry and the player must unlock it before it will open; declare it ``hidden`` (below) and the exit stays secret until the door is revealed.

When a passage is gated by something that *isn't* an item — a drawbridge lowered by a lever elsewhere — reach for ``Location/exit(_:to:when:otherwise:)`` instead. Its condition is evaluated at the moment the player tries to move, and the `otherwise` message is the refusal shown while it's false. The condition is ordinary Swift, so it reads whatever state you track — here a ``Global``:

```swift
@Global var drawbridgeLowered = false

var map: WorldMap {
    gatehouse.north(courtyard, when: { drawbridgeLowered }, otherwise: "The drawbridge is up.")
}
```

## Hidden items

An item declared ``hidden`` exists and is placed like any other, but it's kept out of visibility and room descriptions until it's revealed — a panel behind a painting, a trap door under a rug. Call ``Item/reveal()`` when the player uncovers it; from then on it behaves normally. ``Item/isRevealed`` reports the current state (and is always `true` for an item that was never `hidden`).

```swift
let rug = Item {
    name("oriental rug")
    surface
    scenery
}

let trapDoor = Item {
    name("trap door")
    openable
    scenery
    hidden            // not mentioned until the rug is moved
}

var rules: Rules {
    rug.after(.push, .take) {
        trapDoor.reveal()
        say("With the rug aside, a trap door is revealed in the floor.")
    }
}
```

## Worked example

The **Lighthouse** example (`Sources/Lighthouse/`) puts all of this in one small game: a `shelf` you take a key off, a `chest` you open for the lamp and oil, and a `storeroomDoor` locked by that key. `LighthouseTranscriptTests` drives each one.

## See also

- <doc:WritingRules>
- <doc:AnatomyOfAGame>
- <doc:DarknessTimeAndDeath>
- ``ItemTrait``
- ``Item/lockedBy(_:)``
- ``Location/exit(_:to:via:)``
