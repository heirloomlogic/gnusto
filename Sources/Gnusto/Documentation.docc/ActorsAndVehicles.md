# Actors & Vehicles

People to meet and boats to board: characters that hold, act, and die,
and enterables the player can ride.

## Overview

Phase 8 taught the engine that entities other than the player can hold
things, take turns, and leave the world. Both features are deliberately
thin: an ``Actor`` compiles down to the same storage as an ``Item``, and a
vehicle is one trait plus one field of world state — everything else
composes from machinery that already existed.

## Declaring an actor

```swift
let troll = Actor {
    name("troll")
    description("A mountain of gristle and bad temper.")
    firstSight("A troll stands square in the middle of the room.")
}

var map: WorldMap {
    troll.starts(in: trollRoom)
}
```

An ``Actor`` is declared like an item and stored like one — same
placements, visibility, save format, pronouns, and rule table. What the
engine adds is perception and manners:

- Actors are listed **after** the item paragraphs, as people. An actor's
  `firstSight(_:)` is its *standing presence line*, printed on every look
  (ZIL's LDESC role) — handling a person doesn't wear off their entrance
  the way touching a prop does. Without one, the stock line is
  ``GameText/actorHere`` ("A troll is here.").
- `take troll` refuses with ``GameText/cantTakeActor``, and `take all`
  skips people structurally.
- The builder takes the item trait vocabulary. The descriptive traits all
  mean what they mean on items (`hidden` actors lurk until `reveal()`;
  a `lightSource` actor glows). Mechanical traits (`container`,
  `surface`, `wearable`…) are legal but warned about at bootstrap: actors
  hold things via their inventory, not by being furniture.

`starts(in:)` is the only placement an actor accepts.

## Inventories

An actor holds items exactly the way the player does — placements:

```swift
axe.starts(heldBy: troll)          // declaratively, in the map block
stiletto.move(heldBy: thief)       // imperatively, in a rule (theft)

troll.holds(axe)                   // → true
troll.inventory                    // → [axe], ID-sorted
troll.dropAll()                    // everything to the floor of his room
```

What an actor in the room is holding is **visible but not reachable**:
the player can see, name, and examine the axe in the troll's hands, but
`take axe` refuses with ``GameText/cantReach`` — the same split as the
contents of a shut glass jar. Taking things *out* of those hands is a
plugin's job (stealing), not a default's.

Light follows the same honesty: a lit lantern in an actor's hand lights
the room the actor is in, and leaves with him.

## No alive flag, on purpose

The engine has no built-in alive/dead state for actors, because it has no
behavior that would branch on one. Death is a composition:

```swift
troll.dropAll()      // the classic clatter of dropped loot
troll.vanish()       // gone (inventory goes along if not dropped)
// …or move a corpse Item in, or flip a custom trait — the game's voice.
```

`GnustoMeleeCombat` composes exactly this; a game that wants wounded,
sleeping, or petrified characters builds them from custom traits.

## Actors take their turns on the clock

There is no separate actor phase in the turn pipeline: characters act via
**daemons** — the same end-of-turn clock as fuses and every other timed
event (see <doc:DarknessTimeAndDeath>). A plugin ships behavior as timer
factories the host splices:

```swift
var timers: [TimedEvent] {
    actors.roams(thief, daemonName: "thiefRoams",
                 rooms: [cellar, gallery, studio])
    actors.steals(thief, daemonName: "thiefSteals",
                  candidates: [painting],
                  announcement: { "A feather-light touch — and the \($0) is gone." })
}
```

Rules and daemons that change what the player sees can call
``describeSurroundings()`` for the classic follow-up LOOK.

## Vehicles

One trait makes something boardable:

```swift
let boat = Item {
    name("red boat")
    enterable
    container        // an open hull, if it should carry cargo
}
```

`enter`/`board`/`get in` and `exit`/`disembark`/`get out` move the player
in and out (bare `in`/`out` remain directions). While boarded:

- `go` moves the vehicle — and everything in it — along with the player,
  through the same exits walking uses. Terrain limits are ordinary rules:

  ```swift
  world.before(.go) {
      if player.vehicle == boat, command.direction == .up {
          try refuse("The boat declines the stairs.")
      }
  }
  ```

- The room title reads "Boathouse, in the red boat"
  (``GameText/locationInVehicle``), and the vehicle is left out of its own
  room listing.
- `drop` lands things in the hull of a cargo vehicle (capacity is not
  enforced on this implicit path — `put in` remains the gate), and `take
  boat` refuses with ``GameText/notWhileInside``.
- Darkness is unchanged: riding into a dark cave is pitch black, and a
  lit lantern dropped in the open hull lights wherever the boat is.

``Player/vehicle`` is read-only — board and disembark are actions, so a
`boat.before(.board)` rule can gate them.

For currents and other rule-driven travel, `Item/move(to:)` on the
boarded vehicle carries the passenger; follow with
``describeSurroundings()`` if they should see the new banks.
`move(inside:)`, `move(onto:)`, and `vanish()` deliberately do *not* — a
vehicle that leaves the room any other way strands its passenger on foot,
gracefully.

## Topics

- ``Actor``
- ``enterable``
- ``Player/vehicle``
- ``describeSurroundings()``
