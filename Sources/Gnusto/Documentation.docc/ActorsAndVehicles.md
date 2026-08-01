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
  ``GameText/actorHere`` ("A troll is here." — or "Arthur is here." for an
  actor declared `properName`; see <doc:TextAndRandomness>).
- Both descriptive channels have a live form, declared in a `rules` block:
  ``Actor/describe(_:)`` for the examine text and ``Actor/presence(_:)`` for
  the standing line. `presence` is what a person on a schedule needs — a
  woman described as sitting in her chair should not go on being described
  that way once she is standing in the garden:

  ```swift
  constance.presence {
      constance.isIn(parlour) ? Prose.inHerChair : Prose.onTheStep
  }
  ```

  A rule and its static counterpart are mutually exclusive: `description(…)`
  plus `describe { … }`, or `firstSight(…)` plus `presence { … }`, on the
  same entity is a fatal bootstrap diagnostic.
- `take troll` refuses with ``GameText/cantTakeActor``, and `take all`
  skips people structurally.
- The builder takes the item trait vocabulary. The descriptive traits all
  mean what they mean on items (`hidden` actors lurk until `reveal()`;
  a `lightSource` actor glows). Mechanical traits (`container`,
  `surface`, `wearable`…) are legal but warned about at bootstrap: actors
  hold things via their inventory, not by being furniture.
- A named character wants `properName`, or every stock line that names
  them says "the Mrs. Vane". One word, and the whole table reads right —
  see <doc:TextAndRandomness>.

`starts(in:)` is the only placement an actor accepts.

The player is an actor too — the engine synthesizes ``Player/item`` for
them, so `X ME` has something to answer with and a game has somewhere to
hang the answer. It differs from the cast in two ways: it is in no room
(and so is never listed, never taken, never followed), and it is not
counted as company — a bare `hello` in a room with one other person still
means that person.

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
plugin's job (stealing), not a default's. A rule asks the same question
with ``Item/isVisible`` and ``Item/isReachable``; on the axe they answer
true and false.

The question runs the other way too. ``Item/isReachable(from:)`` is the
same walk anchored on somebody else — their room, their hands, every
open container and surface there, to any depth — and it is symmetric
about the hands: what the *player* is carrying is not in it either.
Darkness is the one place the two anchors part company, because darkness
models the player's perception and an NPC has none to model: an unlit
room narrows the player's reach to their pockets and leaves the troll's
arm exactly where it was. So a thief unions the pair, one set for the
room and one for the pockets:

```swift
let loot = treasures.filter { $0.isReachable || $0.isReachable(from: thief) }
```

``Actor/possesses(_:)`` is the ownership question rather than the scope
one — is this anywhere under him, hands or bag, to any depth — and stays
true in the dark, a room away, and offstage. ``Actor/holds(_:)`` is its
one-level form. `GnustoActors`' theft daemon needs both: the union above
says what he can get at, and `possesses` is what stops him lifting the
coin out of the purse he stole a turn ago.

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

The **Lighthouse** example (`Sources/Lighthouse/`) wires exactly this: a
keeper declared as an ``Actor`` and set roaming two rooms by `GnustoActors`,
with a `talk` verb of its own that she answers. It keeps that verb on purpose,
as the worked example of a game reclaiming a word — `GnustoConversation` ships
a `talk` too, and the two never meet because Lighthouse doesn't splice the
plugin.

## Saying hello

`greet <somebody>` is built in, along with `hello <somebody>` and
`hi <somebody>`, and so is the addressed form `keeper, hello`. All of them
produce ``Intent/greet``, so an actor answers every spelling with one rule:

```swift
keeper.before(.greet) { try reply("\"Evening,\" she says, and means it.") }
```

Bare `hello`, `talk to <somebody>` and `say hello to <somebody>` come from
`GnustoConversation`, which also gives you `greeting(of:reply:again:)` — one
declaration answering GREET and TALK together, with a second line for the
second time, because nobody introduces themselves twice.

Anything *other* than a greeting after the comma — `keeper, open the door` —
is refused with ``GameText/notTakingOrders``. The engine has no system for one
character to act on another's word, and the alternative most parsers reach for
(run the command, but as the player) is worse than not understanding the
sentence.

## Following somebody out of the room

`follow <somebody>`, `chase`, and `go after` take the player after somebody who
has just left. The search is **one exit deep**: it looks for an exit from this
room whose destination is the room they are actually standing in. That is a
fact about the world, not a guess — a wider search would walk the player into
rooms the quarry isn't in, chosen by a heuristic nobody wrote, and print
"(after the keeper)" above an empty room. When no single exit leads there, the
verb says ``GameText/lostThem`` and stays put.

Movement itself runs through the same code `go` uses, so a shut door or a
false conditional refuses with exactly the words it would have refused `go`
with — and the "(after …)" aside is printed only once the exit has actually
passed. A `.blocked` exit carries no destination, so the search can't see
where it would have led; following somebody through one gets
``GameText/lostThem`` rather than the authored refusal. An ungated exit always
wins over a conditional one onto the same room, so a gate that happens to be
shut never shadows an open way round.

The target is *nameable* while out of sight even though it is not *visible*:
"You can't see any such thing" is the wrong answer to `follow him` on the turn
after he walked out. That widening reaches FOLLOW's noun phrase and nothing
else, so every other verb still tells the truth about what is in view.

A game that wants a longer pursuit buys it explicitly. FOLLOW puts its target
in the direct-object slot, so the actor's own rules run first:

```swift
teague.before(.follow) {
    guard player.location == kitchen, teague.isIn(carriageHouse) else { return }
    say("(after Teague, out through the yard door)")
    player.location = backYard
    describeSurroundings()
    try reply("He is across the grass and inside before you are through the door.")
}
```

That is `Sources/Fulminate/`, where one crossing on the household's timetable
is two rooms long and the rest are one.

The **Kindly Deep** example (`Sources/KindlyDeep/`) is the companion half:
`follows` keeps a mule at your shoulder, `stopDaemon`/`startDaemon` park him
where he cannot go and pick him up again on the far side, and starting him
co-located with the player avoids a spurious turn-one arrival.
`KindlyDeepTests` pins the follow/park/rejoin contract.

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
