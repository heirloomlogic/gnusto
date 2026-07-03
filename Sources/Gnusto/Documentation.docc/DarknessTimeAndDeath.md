# Darkness, Time, and Death

Light sources that carry into dark rooms, fuses and daemons that tick the world's clock, saving and undoing, and killing the player without ending the program.

## Overview

Four mechanics turn a collection of rooms into a game with stakes: darkness the player must bring light into, timed events that move the world along whether or not the player acts, the classic SAVE / RESTORE / UNDO / RESTART meta-verbs, and death that offers a way back. This article covers all four — they interlock, and the Zork-style burning lantern chased by a grue uses every one of them.

## Darkness and light sources

A location declared ``dark`` has no light of its own:

```swift
let cellar = Location {
    name("Cellar")
    description("A low, dirt-floored cellar.")
    dark
}
```

In the dark, the player sees "It is pitch black. You can't see a thing." instead of a room description, and the room's scope collapses: its contents and exit doors stop being resolvable nouns. Carried items stay usable — you can always fumble with what's in your hands.

An item declared a ``lightSource`` can push the darkness back:

```swift
let lantern = Item {
    name("brass lantern")
    lightSource          // can hold light; starts unlit
}

let torch = Item {
    name("burning torch")
    lightSource
    startsLit            // begins the game lit
}
```

The player operates light sources with the built-in verbs — `turn on lantern`, `light lantern`, `turn off lantern`, `extinguish`, `douse`, `blow out` (both particle orders parse: `turn lantern on` works too). Turning a light on in a dark room prints the revealed room in the same turn; turning the only light off announces the darkness. Rules can flip the state directly through ``Item/isLit`` — the raw setter changes only the light, announcing nothing.

A room counts as lit when it has light of its own (``Location/isLit``'s setter grants or removes exactly that) or when a lit light source's light *reaches* it:

- carried by the player (lighting only the room the player is in),
- lying in the room, or sitting on a surface in it (however deeply stacked),
- inside a container in the room — if the container is open or `transparent`. A closed opaque chest swallows the light; a shut glass box passes it.

Reading ``Location/isLit`` answers the whole question — "is there light here, from anything" — which is also what a rule like a grue daemon wants to know. There is no separate "always burning" trait: make a torch inextinguishable by refusing `.turnOff` in a rule.

## Fuses and daemons

A ``TimedEvent`` is a named timer declared in a game or bundle `timers` block. A **fuse** fires once, a declared number of turns after it is started; a **daemon** runs at the end of every turn while active:

```swift
var timers: [TimedEvent] {
    fuse("lanternDies", after: 25) {
        lantern.isLit = false
        say("The brass lantern flickers and goes out.")
    }
    daemon("grue", autostart: true) {
        guard !player.location.isLit else { return }
        try die("You are devoured by a grue.")
    }
}
```

Rules start and stop timers by name: ``startFuse(_:after:)`` (the optional count overrides the declared one; restarting resets it), ``stopFuse(_:)``, ``fuseRemaining(_:)``, ``startDaemon(_:)``, ``stopDaemon(_:)``, ``isDaemonActive(_:)``. `autostart` covers timers that should run from turn one with no starting rule. Naming a timer no `timers` block declares is a wiring error and traps; declaring two timers with one name is a fatal bootstrap diagnostic (timer names are global across the game and its bundles — a bundle's own rules refer to them by the literal string, so they are deliberately not namespaced).

Timers tick **once per typed command**, at the very end of the turn — after the world's `after`/each-turn rules, fuses first and then daemons, each group in name order. `take all` over five objects ticks once, not five times. They tick on refused turns (world time passes) but not on parse errors, meta commands, or once the game has ended. A timer started during a turn ticks at the end of that same turn, so a `fuse(after: 1)` started by a rule fires as that very turn ends.

Only the *schedule* — which timers are running, and the fuses' remaining counts — lives in the world's state. The bodies are code, registered at bootstrap; a restored save re-binds its schedule to the declared bodies by name. That split is what lets timers survive save files.

## Save, restore, undo, restart

Four engine-level meta verbs manage the game as a program. Like all meta intents they run no rules and cost no turn — and they are deliberately not overridable through a game's `actions` block.

- **`save`** asks "Save to what file?" and writes the whole world state — placements, the turn counter, the timer schedule, the random stream, everything — as JSON to the answered path. Relative paths resolve against the current directory; an empty answer cancels.
- **`restore`** asks for a filename, validates the file (a save from a different game is refused with its own message), and swaps the saved state in. Because the random stream rides along, a restored game replays exactly the randomness it would have had.
- **`undo`** reverses exactly one turn, from a snapshot the engine takes before every turn that actually runs. One level, classic-style; the snapshot lives outside the world state, so undo history never leaks into save files.
- **`restart`** rewinds to the pristine opening — same seed, so a restarted game is the identical game — and replays the intro.

The filename prompts are round-trips through the normal input loop: the driver (``REPL``/``IOHandler``) never knows a question is open, which also means a ``ScriptedIOHandler`` transcript can script `save`, the path, and the reply like any other lines.

## Death — and the way back

``end(won:)`` finishes the game outright. ``die(_:)`` is the other ending: it kills the *player* but keeps the *program* alive.

```swift
poison.before(.take) {
    try die("Ill-advised. The world goes dark.")
}
```

The engine prints the message, the death banner, and the score, then offers the classic choice:

```
*** You have died ***

Your score is 0, in 12 turns.

Would you like to RESTART, RESTORE a saved game, UNDO your last turn, or QUIT?
```

Every input line goes to that prompt until the player picks an exit — the four answers reuse the meta-verbs above, so `undo` from the prompt revives on the turn before the fatal one, and a failed restore re-offers the prompt rather than stranding a dead world. Death from a timer body follows the same shape as death from a rule.

A dead world's time has stopped: each-turn rules and timers no longer run. Internally that state is ``GameStatus/dead`` — "over, but the conversation continues" — which is why a driver loops on `TurnResult.isFinished` rather than checking the status itself. A game-supplied resurrection hook (revive the player instead of prompting, Zork-style) is a planned seam on `die(_:)`; only the prompt ships today.

## The worked example: the lantern and the grue

`Sources/Zork1/` ties it together. The brass lantern is a `lightSource` whose fuel is two fuses — a dim warning at 20 burning turns, dead at 25 — started by an `after(.turnOn)` rule and *paused* by `after(.turnOff)` (bank `fuseRemaining`, stop the fuses; relighting restarts them at the banked counts). The grue is an autostarted daemon that counts consecutive turns ending in darkness: a warning, a silent turn of grace, then `die(…)` — and any lit turn resets it. Both survive save/restore because their state is a `@Global` and the timer schedule.

## See also

- <doc:TheTurnPipeline>
- <doc:WritingRules>
- <doc:TextAndRandomness>
