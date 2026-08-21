# ``GnustoActors``

Daemons that make an NPC wander, tag along, or go through your pockets.

## Overview

An actor who stands where the author put him is scenery with a name on it. Four
factories here cover the behaviors that make one feel like a person in the room:
he moves around a set of rooms on his own, he keeps up with the player, he takes
things, and he has something to say when spoken to.

``ActorBehaviors`` is a `GamePlugin`, which here means it owns nothing at all —
no entities, no `@Global`, no saved state. An actor's position *is* his
placement, which the engine already saves. So the plugin is never listed in
`content`; it is stored as a plain property, and the host splices the return
values into its own blocks. The three daemon factories return a `TimedEvent` for
the `timers` block; ``ActorBehaviors/reaction(of:to:reply:)`` returns `Rules` for
the `rules` block. Everything they act on — the actor, the room set, the loot,
the prose — is handed in by the host.

Randomness is drawn only after a factory's guards pass. A roaming daemon whose
actor is out of position, or a thief whose player has nothing worth taking,
consumes no randomness at all, so a seeded transcript that never meets the actor
stays stable no matter what he gets up to elsewhere. `while:` on
``ActorBehaviors/roams(_:daemonName:rooms:chancePerTurn:while:arrival:departure:)``
and ``ActorBehaviors/follows(_:daemonName:rooms:while:arrivals:)`` is evaluated
before the position guard for the same reason: a shut gate is a quiet, draw-free
turn.

None of these daemons acts for an actor whose `Actor.isUnconscious` is set. A
man lying on the floor does not wander off, catch you up, or lift anything out of
your hands, and he draws no randomness deciding not to. The flag is the engine's
rather than this plugin's because what usually puts a villain down is a combat
plugin, and two plugins cannot see each other: `GnustoMeleeCombat` sets it and
this one reads it, with neither library knowing the other exists.

## Wiring

```swift
import Gnusto
import GnustoActors

struct Gallery: Game {
    let title = "Gallery"
    let actors = ActorBehaviors()

    let thief = Actor { name("shadowy figure"); synonyms("thief", "figure") }
    let painting = Item { name("oil painting"); adjectives("oil") }
    let cellar = Location { name("Cellar"); description("…") }
    let studio = Location { name("Studio"); description("…") }

    var timers: [TimedEvent] {
        actors.roams(
            thief,
            daemonName: "thief.roam",
            rooms: [cellar, studio],
            chancePerTurn: 50,
            arrival: "A shadow detaches itself from the doorway.",
            departure: "The shadow is somewhere else, and you did not see it go.")
        actors.steals(
            thief,
            daemonName: "thief.steal",
            candidates: [painting],
            chancePerTurn: 30,
            announcement: { "A hand you never see relieves you of the \($0)." })
    }

    var rules: Rules {
        actors.reaction(of: thief, to: [.give, .attack], reply: "The figure is not there when you reach it.")
    }

    var map: WorldMap { … }
}
```

## Roaming and following are different daemons

``ActorBehaviors/roams(_:daemonName:rooms:chancePerTurn:while:arrival:departure:)``
teleports the actor within a room set, with no exit-graph awareness — a wall
between two rooms in the set will not stop him. It has both an `arrival` and a
`departure` line, because the player can be standing in either room.

``ActorBehaviors/follows(_:daemonName:rooms:while:arrivals:)`` moves the actor to
wherever the player now stands. Daemons tick at the end of the turn, after `go`
has resolved and the new room has been described, so the companion catches up on
the same turn and his arrival line trails the room description. There is no
`departure` line, because he only ever moves *toward* the player and nobody is
left behind to watch him go. He draws no randomness whatever: `arrivals` is
cycled by the saved turn counter, so the line varies from arrival to arrival and
stays identical across a save and restore. Pass one line for a fixed
announcement, or a dozen so a constant companion does not wear his welcome out.

Both prose channels are gated on light. In the dark, or a room away, the movement
is silent.

Two ways to scope a follower, and they scope different things. `rooms:` is a
whitelist of *destinations* — a gaoler who walks the corridors and will not set
foot in a cell follows you along the one and lets you go into the other, which is
what makes "somewhere he will not go" a place you can stand. `while:` is the
gate, for the companion who has been told to wait. `stopDaemon(_:)` parks him
where he stands and `startDaemon(_:)` picks him up again; `Sources/KindlyDeep/`
turns its whole endgame on which room the mule was standing in when he was
parked.

Start a follower co-located with the player and there is no spurious arrival on
turn one.

## The thief takes from anywhere in the room

``ActorBehaviors/steals(_:daemonName:candidates:chancePerTurn:announcement:)``
lifts a candidate from wherever it lies in the shared room: out of the player's
hands, off the floor, or from inside anything open, to any depth. Only another
actor's hands are out of reach. The theft is announced only when the room is lit;
in the dark you find out when you check your pockets.

## Worked examples

`Sources/Lighthouse/` has a keeper who roams two rooms stacked on a staircase.
`Sources/KindlyDeep/` has the follow-park-rejoin cycle in full, and its design
doc (`docs/games/kindly-deep.md`) is where the reasoning lives.
`Sources/Zork1/` runs the thief: roaming the whole underground, stealing from the
treasure roster, and fighting back only in his own lair.

## Topics

### The plugin

- ``ActorBehaviors``
- ``ActorBehaviors/init()``

### Moving an actor

- ``ActorBehaviors/roams(_:daemonName:rooms:chancePerTurn:while:arrival:departure:)``
- ``ActorBehaviors/follows(_:daemonName:rooms:while:arrivals:)``

### Taking things

- ``ActorBehaviors/steals(_:daemonName:candidates:chancePerTurn:announcement:)``

### Answering the player

- ``ActorBehaviors/reaction(of:to:reply:)``
