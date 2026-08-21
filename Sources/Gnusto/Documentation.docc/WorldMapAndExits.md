# The World Map and Its Exits

How rooms connect, and where everything starts.

## Overview

`foyer.south(bar)` puts an exit on the foyer. It puts nothing on the bar. Walking
south out of the foyer and walking north out of the bar are two facts about two
rooms, and the `map` block states each one:

```swift
var map: WorldMap {
    foyer.south(bar)
    bar.north(foyer)
}
```

Inferring the reverse would be right most of the time and quietly wrong for a
chute, a trap door that latches behind you, or a crawl that comes out somewhere
other than where it went in. One line per direction means an asymmetric map needs
no special case, and a one-way passage is written the same way as a two-way one:
by leaving the second line out.

`map` is a result-builder property yielding a ``WorldMap`` — a flat list of
``MapEntry`` statements covering exits, initial placements, the player's start,
and lock/key pairs. Every reference in it is ordinary property access, so
renaming a room breaks its exits at compile time. Because it is a builder, a
large map splits into per-region helper properties across files; see
<doc:SplittingAGameAcrossFiles>.

## Directions

``Direction`` has twelve cases: the eight compass points, `up`, `down`, `in`, and
`out`. The parser accepts each by name and by its abbreviation — `n`, `sw`, `u`,
`d` — plus `inside` and `outside`.

`in` and `out` are directions like any other, and unrelated to `enter <thing>`,
which is a verb that takes a noun. See <doc:ContainersDoorsAndLocks>.

## The five kinds of exit

Each kind is one general form on ``Location`` taking a ``Direction``, plus twelve
one-line spellings that name the direction instead. Maps are written in the
spellings; the general form is for a direction held in a variable.

### Plain

A way through, with nothing gating it.

```swift
jetty.north(base)
base.south(jetty)
base.up(tower.lampRoom)
```

The general form is ``Location/exit(_:to:)``. The third line above is
`Sources/Lighthouse/`, whose stairs lead into a room declared by a separate
``GameContent`` bundle — an exit crosses that boundary like any other.

### Blocked

A direction the player can try and never take. It exists so the refusal is the
game's own rather than the stock *"You can't go that way."*

```swift
foyer.north(
    blocked: """
        You've only just arrived, and besides, the weather outside
        seems to be getting worse.
        """)
```

The general form is ``Location/exit(_:blocked:)``. A blocked exit names no
destination, which has one consequence noted below.

### Through a door

One ``openable`` item, named on the exit from both sides:

```swift
storeroomDoor.lockedBy(brassKey)
base.east(storeroom, via: storeroomDoor)
storeroom.west(base, via: storeroomDoor)
```

The two entries share a single item with a single open state, so opening the door
in the base opens it in the storeroom. While it is shut, `go east` refuses by
naming it. While it is ``hidden`` and unrevealed the exit answers *"You can't go
that way"*, because a door the player has not found is not a door they can be
told is closed.

The general form is ``Location/exit(_:to:via:)``. Bootstrap sets ``Item/isDoor``
from the exit, so a door that hangs on one declares nothing; a `via:` item that
is not `openable` is a fatal diagnostic, since `go` would have no open state to
gate on. Locks, keys, and what `enter <door>` does are
<doc:ContainersDoorsAndLocks>'s subject.

### Conditional

A gate evaluated at `go` time, carrying the refusal to print while it is shut:

```swift
domeRoom.down(torchRoom, when: { ropeTiedToRailing }, otherwise: Prose.domeNoRope)
```

The closure runs inside the live turn frame, so it reads globals, item state and
the clock as of the turn the player tried the exit. Reach for it where the thing
gating the passage is not an item you can hang a door on — a rope tied off
upstairs, an undefeated troll, a mule with an opinion:

```swift
forks.exit(
    .north,
    to: oldWorks,
    when: { !biscuit.isIn(forks) },
    otherwise: """
        Biscuit puts himself across the mouth of the old works like a bolted gate. …
        """)
```

The general form is ``Location/exit(_:to:when:otherwise:)``. A conditional exit
decides *whether* the player moves, never *where* they arrive.

### Toward a destination chosen at `go` time

Here the destination is the closure, and the exit is always passable:

```swift
mirrors.slideRoom.exit(
    .down,
    toward: { palantirWing.chuteRopeRigged ? palantirWing.slideOne : house.cellar })
```

That is Dungeon's chute: it always takes you, and what the rope decides is where
you land. Nothing downstream checks that the room the closure names has anything
to do with the direction, which is what makes a non-Euclidean passage possible at
all. Dungeon's Round Room is eight headings over one turning floor:

```swift
let exits = carouselExits
for (heading, destination) in exits {
    crossroads.roundRoom.exit(
        heading,
        toward: {
            crossroads.carouselSpinning
                ? exits[crossroads.carouselTwist % exits.count].1 : destination
        })
}
```

Travel runs the same path as every other passable exit, so the destination's
``Location/onEnter(perform:)`` rules fire and a boarded vehicle rides along. That
is the difference between this and assigning ``Player/location`` from a rule,
where neither happens — and it is why the Round Room's carousel can still pay out
an `onEnter` award.

The general form is ``Location/exit(_:toward:)``. Three things come with the
closure:

- **It is a read.** It may run more than once in a turn — `FOLLOW` asks it which
  way the quarry went before travel takes it — so it must answer from state
  rather than change any. A die rolled here is rolled twice.
- **It is not validated at bootstrap.** The other four kinds name a room the
  bootstrap resolves at launch; this one is opaque until it runs, so a
  destination that isn't a stored property of the game surfaces on the turn the
  player takes the exit.
- **It contributes no destination to the reachable-room set**, described below.

## Computing the direction

The general forms take a ``Direction`` value, which is what a loop needs. Dungeon's
Low Room has nine ways out leading to two rooms:

```swift
for direction in Self.lowRoomToMachineRoom {
    lowRoom.exit(direction, to: machineRoom)
}
for direction in Self.lowRoomToTeaRoom {
    lowRoom.exit(direction, to: teaRoom)
}
```

## Where everything starts

The same block places the cast and the props. Every form returns a ``MapEntry``,
so they interleave with exits freely.

| Form | Places | Notes |
|---|---|---|
| ``Player/starts(in:)`` | the player, in a room | Required. Declaring it twice, or not at all, is a fatal diagnostic. |
| ``Actor/starts(in:)`` | an actor, in a room | The only placement an actor accepts. |
| ``Item/starts(in:)`` | an item, on a room's floor | |
| ``Item/starts(on:)`` | an item, on another item | The holder must declare ``surface``. |
| ``Item/starts(inside:)`` | an item, in another item | The holder must declare ``container``. |
| ``Item/startsHeld`` | an item, in the player's hands | |
| ``Item/startsWorn`` | an item, worn by the player | Worn and carried both; `remove` leaves it in hand. |
| ``Item/starts(heldBy:)`` | an item, in an actor's inventory | Takes an ``Actor``. |

```swift
player.starts(in: jetty)
keeper.starts(in: base)
shelf.starts(in: base)
brassKey.starts(on: shelf)
chest.starts(in: storeroom)
oilLamp.starts(inside: chest)
```

An item named by no placement starts offstage, which is legal and is how a thing
that appears mid-game waits its turn. Bring it on with ``Item/move(to:)`` or one
of its siblings, and send it back with ``Item/vanish()``.

Two placements that close a loop — a box inside a bag inside the box — are fatal.
Each entry resolves on its own, since each holder passes the surface or container
check, and nothing in the pair asks where the *holder* sits; the game would boot
with both items in no room at all, listed nowhere and reachable by nobody. The
bootstrap walks each placement chain and reports the loop by name.

## What the bootstrap makes of it

The five exit kinds become five entries in one per-room, per-direction table, and
three facts about that table are worth an author's attention.

**Each direction of each room can be claimed once.** Every kind files its entry
through the same check, so a second claim on the same direction is one
diagnostic — *`"cellar" declares its north exit more than once.`* — whichever
kinds collided.

**Four kinds name their destination at launch; the dynamic one does not.**
References are compile-checked, so what bootstrap catches is a room that is not a
stored property of the game or any of its bundles, which is the mistake a
cross-bundle map makes.

**The reachable-room set is built from the destinations that were named.** Blocked
and dynamic exits contribute none. That set is what tells the engine which rooms
the map admits to, and a room reachable only through a dynamic exit reads as
off-map: an actor standing there will not be named by `FOLLOW` or by the "you see
somebody elsewhere" walk. For the room a game is deliberately hiding that is the
behavior you want. When it isn't, give the room an ordinary exit as well.

## The cost of a sixth kind

The five families repeat once per direction, in `LocationExits.swift`, as
one-liners that delegate to the general form. Keeping them one-liners is what
makes the compass vocabulary read uniformly. The price is stated in that file's
own header: a new exit kind costs one general form on ``Location`` plus twelve
more one-liners.

## Topics

### Declaring exits

- ``Location/exit(_:to:)``
- ``Location/exit(_:blocked:)``
- ``Location/exit(_:to:via:)``
- ``Location/exit(_:to:when:otherwise:)``
- ``Location/exit(_:toward:)``
- ``Direction``

### Placing the player, the cast, and the props

- ``Player/starts(in:)``
- ``Actor/starts(in:)``
- ``Item/starts(in:)``
- ``Item/starts(on:)``
- ``Item/starts(inside:)``
- ``Item/startsHeld``
- ``Item/startsWorn``
- ``Item/starts(heldBy:)``

### The map itself

- ``WorldMap``
- ``MapEntry``

## See also

- <doc:AnatomyOfAGame>
- <doc:ContainersDoorsAndLocks>
- <doc:SplittingAGameAcrossFiles>
- <doc:ActorsAndVehicles>
