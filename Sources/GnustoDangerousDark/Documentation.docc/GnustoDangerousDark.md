# ``GnustoDangerousDark``

Darkness that kills: a warning, a grace period, then dice.

## Overview

The engine's own darkness is a description problem. A dark room prints "It is
pitch black. You can't see a thing.", its contents stop being resolvable nouns,
and the player is inconvenienced. They can stand there for a hundred turns.
This library supplies the consequence, on the schedule the original used.

``DangerousDark`` is a `GameContent` bundle with no rooms in it — one namespaced
counter, one daemon, four knobs on `init`. Wiring is a single line: list the
instance in the game's `content` block. It reads `player.location.isLit`, which
already answers the whole question of whether there is light here from anything,
so a host that has declared its dark rooms and a lamp has declared everything
this needs. The schedule is settled at `init`, and so is the prose — with one
subject passed at the moment it is spoken: the death line is handed the vehicle
the player was aboard, because a sentence about being found has to say where.

The daemon counts consecutive turns *ending* in darkness, wherever they are
spent. Lingering is lethal and movement is not, so a lightless dash toward the
stairs can still work. Any reachable light resets the count to zero. Dark turn 1
prints the warning; dark turns 2 through `graceTurns + 1` are a silent grace;
from dark turn `graceTurns + 2` on, every turn rolls `chance(lethality)` to be
eaten. The warning turn is always safe, which is the classic fairness contract:
a player who UNDOes a death gets the warning beat back before the dice can turn
on them again.

Two instances in one game collide on their shared `@Global` namespace before the
timer name matters. One lethal dark per game.

## Wiring

```swift
import Gnusto
import GnustoDangerousDark

struct Deeps: Game {
    let title = "Deeps"

    let dark = DangerousDark()   // stock prose, one turn of grace, 50% a turn

    var content: GameContents { dark }

    var map: WorldMap { … }
}
```

A game with its own voice for the dark passes all four:

```swift
let dark = DangerousDark(
    warning: Prose.grueWarning,
    death: Prose.grueDeath,
    graceTurns: 1,
    lethality: 50)
```

`death` takes a subject where the other three lines do not: the **vehicle the
player was aboard**, or nothing when they were on their own feet. Write both
halves with `.naming(orBare:)`:

```swift
static let grueDeath = GameText.Line<GameText.Noun?>.naming(
    orBare: "…the room…"
) {
    "…\($0)…"
}
```

**The death this daemon deals is always the lingering one**, and the line has to
be true of that. The counter cannot reach the dice before the third dark turn, so
nothing it kills was killed on the turn it walked into the dark. Zork draws the
distinction with two separate sentences and this is the second of them: `V-WALK`
(`gverbs.zil:1578`) says *"You have walked into the slavering fangs of a lurking
grue!"* and fires only on a **blocked** move in the dark, which is a branch this
library does not have; `GOTO` (`:2110-2114`) names the vehicle you are sitting in,
or says "room". Both halves are the game's words — the stock line names no place
at all, because a library that has not seen the game should not decide what to
call the place somebody was taken from.

`warning` is said *once* per turn, through the engine's `sayOnceThisTurn(_:)`.
A game that also points `text.pitchBlack` at the same sentence — Zork does,
because there the dark-room line *is* the threat — reads it a single time on the
turn it walks into the dark, whichever speaker got there first. Two different
sentences are two different sentences, and both print. A warning swallowed for
repeating the room's own line is still a warned turn.

## Making the dark harmless

For a room whose solution is to stand in the dark on purpose, or a scene that
should not be interrupted, set ``DangerousDark/suspended``:

```swift
cryptDoor.after(.close) { dark.suspended = true }
cryptDoor.after(.open) { dark.suspended = false }
```

**Do not stop the daemon by name.** It is called `"grue"`, and
`stopDaemon("grue")` freezes the counter at whatever it had reached, so resuming
can put the player straight onto a dice turn and cost them the warning.
Suspending resets the count on every suspended turn, for exactly that reason, and
draws no randomness while it is set.

## Worked example

`Sources/Zork1/` wires this over the engine's own light mechanics — the brass
lantern is a `lightSource` on two fuses, and the grue is what makes the fuses
matter. The engine's side of it (the `dark` trait, `lightSource`, what counts as
light reaching a room, `die(_:)` and the resurrection hook) is the *Darkness,
Time, and Death* article in the `Gnusto` documentation.

## Topics

### The content bundle

- ``DangerousDark``
- ``DangerousDark/init(warning:death:graceTurns:lethality:)``

### Turning the dark off and on

- ``DangerousDark/suspended``

### The daemon

- ``DangerousDark/timers``
