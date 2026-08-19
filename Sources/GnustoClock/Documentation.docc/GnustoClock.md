# ``GnustoClock``

Puts a wall clock over the engine's turn counter, so a game can be played
against an evening rather than a move count.

## Overview

An adventure counts moves. A mystery counts minutes: every alibi in the house
is stated as a time, and a player who cannot check one against a clock is being
asked to take the game's word for it. This library gives the move counter an
hour and a minute, a `time` verb that reads it back, alarms that go off at a
stated hour, and timetables that keep an actor where his day says he is.

The clock is **derived, not ticked**. ``Clock/now`` is a pure function of the
engine's `moves`, so every rule, action, fuse and daemon in one turn reads the
same time, the timer tick that closes the turn included. A clock advanced by a
daemon of its own would be read differently by daemons sorting before and after
it, which would make the hour depend on other timers' names. Deriving also
inherits the engine's own notion of world time: the hour doesn't move on a parse
error or a meta command, and `take all` costs one turn rather than four.

``Clock`` is a `GameContent` bundle rather than a `GamePlugin`, because it has
state to keep — the minutes a game has moved the clock by hand, whether it is
paused, and which stop each scheduled actor was last seen keeping. A bundle's
globals namespace themselves and travel in save files, so the host lists the
clock in `content` and gets all three for nothing. Everything else belongs to
the host: the rooms, the actors, the bodies of the alarms, and the timetables. A
``Timetable`` holds no state of its own, which is what lets a game declare one
as an ordinary computed property naming its own rooms, and what makes
``Timetable/location(at:)`` an answer available at bootstrap, in a rule, and in
a plain unit test.

```swift
import Gnusto
import GnustoClock          // .product(name: "GnustoClock", package: "Gnusto")

struct Fulminate: Game {
    let clock = Clock(
        startingAt: TimeOfDay(17, 30),
        minutesPerTurn: 2,
        timeIs: { "Your watch says \($0)." }
    )

    var content: GameContents { clock }        // the verb, the action, the saved state

    var timers: [TimedEvent] {
        clock.schedule(teague, daemonName: "teague.day", teagueDay)

        clock.at(TimeOfDay(17, 46), named: "clock.blast") {
            blastHappened = true
        }
    }
}
```

Reading the time needs a live turn, so ``Clock/now`` belongs in a rule body, a
`describe` block, an action or a timer, and not in a `map` block, which is
evaluated at bootstrap. A `map` block that wants to place a scheduled actor asks
the timetable instead, which reads no world state:
`teague.starts(in: teagueDay.location(at: clock.start))`. A stored clock also
hands the play-test status footer a `time=5:46 pm` field, which a timed game
wants, since a line true at half past five and false at six reads the same in a
transcript that never says which it was.

## Topics

### The clock

- ``Clock``

### Times of day

- ``TimeOfDay``
- ``TimeFormat``

### An actor's day

- ``Timetable``
- ``Stop``
