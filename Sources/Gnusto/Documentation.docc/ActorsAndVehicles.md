# Actors & Vehicles

People to meet and boats to board: characters that hold, act, and die,
and enterables the player can ride.

## Overview

A world with one person in it is a museum. The player is not the only
thing that can hold something, take a turn, or leave; an ``Actor``
compiles down to the same storage as an ``Item``, and a vehicle is one
trait plus one field of world state. There is no new subsystem here,
which is why there is so little of it to learn.

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

To read that placement back, ask ``Actor/location``. It is the room the
actor stands in, or `nil` while they are offstage:

```swift
fuse("thiefReturns", after: 12) {
    guard thief.location == nil else { return }   // still out there
    thief.move(to: treasureRoom)
}
```

Reach for it rather than substituting ``Player/location`` for an actor's
room. The two agree in the common case — you are handing somebody
something, so you are standing where they are — and part company the
moment either of you walks, which is when `player.location` starts
answering the wrong room quietly. ``Actor/isIn(_:)`` asks the same
question of one specific room when that is all you need.

``Item/location`` answers it for a thing rather than a person, and is
the same accessor underneath — the difference is that a thing can be
nested, so that one walks up through hands, surfaces and containers to
find the room, while an actor is only ever standing in one. That is what
to ask when you want the room a dropped treasure ended up in; see
<doc:ContainersDoorsAndLocks>.

For the commonest reason to want it — somebody leaves, and something
stays behind where they stood — don't read the room at all. Use
``Actor/replace(with:)``, which does the swap in one call:

```swift
gnome.replace(with: chimney)      // he goes; the hole he left stays
```

``Actor/vanish()`` clears the placement, so the read-then-move spelling
has to happen in that order and quietly aims at the wrong room if it
doesn't. `replace(with:)` has no order to get wrong.

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

`GnustoMeleeCombat` composes exactly this. A game that wants wounded,
sleeping, or petrified characters keeps that state in a ``Global`` of its own —
declared traits are bootstrap data and cannot be written during play.

``Actor/isUnconscious`` is the one condition the engine holds itself, and the
reason has nothing to do with the engine: two plugins have to agree on it. A
villain `GnustoMeleeCombat` has just knocked down must stop roaming and
stealing under `GnustoActors`, and neither library can see the other, so the
flag lives where both can reach it. The engine still branches on it nowhere.
Set and clear it yourself if your game puts somebody out by its own means, and
the daemons that consult it will behave.

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
``describeSurroundings(withRoomName:)`` for the classic follow-up LOOK, or
``arrive(at:withRoomName:)`` to move the player and look in one step. Where the
player is aboard something, the move you want is usually ``enter(_:)`` instead:
`arrive(at:)` moves the player alone and leaves the vehicle at the dock, and
`enter(_:)` takes the hull and its cargo along the way a `go` does. See
<doc:WritingRules>.

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

Anything *other* than a greeting after the comma — `keeper, open the door` — is
an order, and is refused with ``GameText/notTakingOrders`` unless the person
addressed has been declared able to take one. See below.

## Giving orders

One trait makes somebody order-taking:

```swift
let robot = Actor {
    name("robot")
    takesOrders
}
```

`robot, push the triangular button` then becomes a real command with the robot
as its agent, and reaches the rules with ``Command/actor`` naming it:

```swift
button.before(.push) {
    guard command.actor == robot else { try refuse("You can't reach it.") }
    try reply("Whirr, click. Something heavy lifts in the darkness.")
}
```

`command.actor` is `nil` for everything the player does on their own account,
which is every command typed without an addressee. Nobody who hasn't opted in
is affected: an order to them is refused at the parser exactly as it always was.

Four things are worth knowing, and all four follow from one decision.

**The engine's own default actions never run for somebody else.** Every one of
them takes into the player's hands, walks the player's legs, and reaches with
the player's arm; running one for a robot is the "addressee field that quietly
ran the command as the player" that makes a parser lie. So an order gets the
`before` stages — the world's rules, the room's, the addressee's own, the
objects' — and never stage 4, the game's `actions` rows included. An order
happens where a rule makes it happen, or not at all. `after` rules don't see
one either, for the ordinary reason: answering means `reply` or `refuse`, which
end the turn where they stand, exactly as they do for the player.

The room whose `before` rules run is the room the **addressee** is standing in,
not the player's — that is where the thing is being done. The one told is told
*first*, ahead of the thing it names, so a rule like `robot.before(.go)` can
answer an order that carries no object at all:

```swift
robot.before(.go) {
    guard command.direction == .north else { try refuse("The treads grind.") }
    robot.move(to: closet)
    try reply("The robot clanks north through the doorway.")
}
```

**An order nobody wrote a rule for says so and costs nothing** —
``GameText/doesNotKnowHow``, thrown as the same free `unhandled` a custom verb
nothing answers gets. An order a rule *does* answer is an ordinary turn: the
each-turn rules run, the clock ticks, the move counts. As with a stub verb,
answer with `reply` or `refuse` rather than a bare `say`, or the stock line
prints underneath yours.

**The words after the comma are read where the addressee is standing**, not
where the player is. That is the point of sending somebody somewhere: the robot
in the closet can name the button in the closet, and `push the triangular
button` typed on your own behalf still answers "You can't see any such thing".
Darkness doesn't gate it, for the same reason it doesn't gate an NPC's reach —
the dark is the player's problem. A robot that should be blind in an unlit room
refuses in a rule.

**An order-taker is nameable while out of sight**, the way FOLLOW's quarry is:
you call after the robot through the doorway. That widening reaches the address
slot alone — `examine robot` in the room it left is still "You can't see any
such thing", and so is `robot, hello`, because calling after somebody carries
an order and not a greeting. It reaches only actors that opted in. A question
an incomplete order raises stays an order: `robot, push` asks "What do you want
to push?", and the answer completes the robot's command, not yours.

Two things an order deliberately isn't. `robot, take all` is refused: the
multi-object loop expands against what the *player* can get at and runs stage 4
per object. And an order-taker who is in no room at all — held, contained,
`vanish()`ed — falls back to the stock refusal, because there is nowhere for the
order to be carried out.

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
    arrive(at: backYard)
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

`enter`/`board`/`get in`/`go through` and `exit`/`disembark`/`get out` move
the player in and out (bare `in`/`out` remain directions). While boarded:

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

`.board` is one intent doing two jobs, in this order: a **door** on an exit of
the room you are standing in is a way through and takes that exit (see
<doc:ContainersDoorsAndLocks>), an **`enterable`** is a vehicle and admits you,
and anything else is neither — ``GameText/cantEnterThat``. So the verb that
boards the boat also walks you through the kitchen window, which is what the
classic games do with it.

For currents and other rule-driven travel, `Item/move(to:)` on the
boarded vehicle carries the passenger; follow with
``describeSurroundings(withRoomName:)`` if they should see the new banks.
`move(inside:)`, `move(onto:)`, and `vanish()` deliberately do *not* — a
vehicle that leaves the room any other way strands its passenger on foot,
gracefully.

Stranding is permanent, and that is deliberate. The boarding is cleared at
the instant the player and the vehicle stop sharing a room — whichever of
the two moved — so the vehicle's later travels leave the player where they
are, and walking back to where the vehicle is left standing leaves them on
foot beside it. A player teleported out of a boat by a death, a spell or a
trapdoor has to `board` it again to be in it again.

Disembarking is worth one warning. `get out` carries no direct object, so
a rule on the vehicle itself never sees it — a gate that has to hold
(open water below, nine hundred feet of nothing below) belongs on
`world.before(.disembark)`, keyed on ``Player/vehicle``.

## Topics

- ``Actor``
- ``Actor/location``
- ``Actor/isIn(_:)``
- ``Actor/replace(with:)``
- ``takesOrders``
- ``Command/actor``
- ``enterable``
- ``Player/vehicle``
- ``describeSurroundings(withRoomName:)``
- ``arrive(at:withRoomName:)``
- ``enter(_:)``
