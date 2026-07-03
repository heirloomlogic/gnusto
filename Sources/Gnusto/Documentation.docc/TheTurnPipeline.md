# The Turn Pipeline

What happens between the player pressing Return and the next prompt.

## Overview

Every line the player types runs through the same fixed sequence of stages. This section walks that sequence — which rules fire, in what order, and how one rule can stop the rest — from raw input to committed state.

## From input to command

The ``REPL`` reads a line and hands it to ``GameWorld/perform(_:)``. The parser first turns the text into a ``Command`` — an ``Intent`` (the canonical action, like ``Intent/take``) plus the objects, preposition, and direction it resolved.

Parsing can fail: an unknown word, nothing in scope, a verb with no object. **Parse failures are free.** No rules run, the state is untouched, and the turn counter does not advance — the player just sees a message ("I don't understand that." / "You can't see any such thing here.") and a fresh prompt. Only a successfully parsed command enters the pipeline below.

## How the parser converses

Three parser behaviors go beyond one-line-in, one-command-out:

- **Questions stay open.** When the parser asks a clarifying question — "Which do you mean: the brass lantern or the rusty lantern?", "What do you want to take?" — the next input line is first tried as its *answer*: an adjective (`brass`), a fuller phrase, or the missing object completes the original command. Narrowing can take several rounds; a line that isn't an answer simply runs as a fresh command and the question is forgotten. Questions, like all parse failures, are free turns.
- **Pronouns.** `it` refers to the last direct object the player named (naming binds even if the action was refused); `them` refers to the group of the last multi-object command. A pronoun whose referent is gone from view fails in scope like any other noun.
- **Multi-object commands.** `all` (or `everything`) in the direct-object slot of `take`, `drop`, `put … in`, or `put … on` expands to the eligible objects — for `take`, everything visible, takable, and not already held; for the rest, everything held. Each object then runs stages 1–7 of the pipeline below as its own single-object ``Command`` with a labeled result line (`brass lantern: Taken.`), so `before`/`after` rules never see "all". The each-turn stages (8–9) still run **once** for the whole command — a burning lantern loses one turn of fuel, not one per object. Other verbs refuse multiple objects, and `all` never fills an indirect slot.

## The stages of a turn

Once a command parses, the engine runs these stages in order. Rules are matched by **scope** (world, the current location, or one of the command's objects) and by **intent** (a rule with no intents listed matches any).

1. **World `before`** — ``World/before(_:perform:)`` rules, matching the intent.
2. **Location `beforeEachTurn`** — ``Location/beforeEachTurn(perform:)`` for the current room, every turn regardless of intent.
3. **Location `before`** — ``Location/before(_:perform:)`` for the current room.
4. **Item `before`** — ``Item/before(_:perform:)`` for the indirect object, then the direct object.
5. **The default action** — the engine's built-in behavior for the intent (pick up the item, walk through the exit, describe the thing). This is where the turn actually *does* something if no rule intervened.
6. **Item `after`** — ``Item/after(_:perform:)`` for the direct object, then the indirect object.
7. **Location `after`** — ``Location/after(_:perform:)`` for the current room.
8. **Location `afterEachTurn`** — ``Location/afterEachTurn(perform:)`` for the room, every turn.
9. **World `after`** — ``World/after(_:perform:)`` rules.
10. **The timer tick** — every running fuse counts down (firing at zero) and every running daemon runs, fuses first, each group in name order. Once per typed command, never on parse errors, and not once the game has ended. See <doc:DarknessTimeAndDeath>. Characters take their turns here too: there is no separate actor phase — a roaming thief or a counter-attacking troll is a daemon on this same clock (<doc:ActorsAndVehicles>), which is why your swing resolves in stage 5 and the villain's answer lands at the end of the turn.

Then the turn counter advances by one and the turn commits.

The symmetry is deliberate: `before` rules run outside-in (world, then location, then item) so broad rules get first say; `after` rules run inside-out. A `before` rule is your chance to *change or forbid* what is about to happen; an `after` rule reacts to what *did* happen.

## Stopping the turn: refuse, reply, and end

A rule body is ordinary Swift, but three helpers change the flow of the turn by throwing an interrupt the engine catches:

- ``refuse(_:)`` — "no, you can't." Prints the message and skips the default action and every remaining `before`/`after` rule. Use it in a `before` rule to veto an action.
- ``reply(_:)`` — "here's what happens instead." Mechanically identical to `refuse`, but named for the case where you are *handling* the action yourself rather than forbidding it. This is how a custom verb produces its result.
- ``end(won:)`` — ends the game, won or lost. The engine prints the final score after the turn's output.
- ``die(_:)`` — kills the player without ending the program: the message, the death banner, the score, and then the interactive RESTART / RESTORE / UNDO / QUIT prompt. Dead is *over but not finished* — each-turn rules and timers stop, yet the loop keeps reading until the player picks an exit. See <doc:DarknessTimeAndDeath>.

All three return `Never`, so they read naturally in a `guard`:

```swift
cloak.before(.drop, .putOn) {
    guard player.location == cloakroom else {
        try refuse("This isn't the best place to leave a smart cloak lying around.")
    }
}
```

To add output *without* stopping the turn, use ``say(_:)``. It appends a line to the turn's output and returns normally, so the default action still runs. A `before` rule that only `say`s adds flavor; one that `refuse`s or `reply`s takes over.

## World time passes even on a refusal

There is one important asymmetry. When a `before` rule refuses an action, the default action and later `before`/`after` rules are skipped — but the turn is still a turn. The each-turn tail (stages 8 and 9) still runs, and the move counter still advances.

This is what makes timed puzzles work. A lantern burning down, a guard on patrol, or — in Cloak of Darkness — the darkness that penalizes *any* fumbling in the dark bar, all live in `afterEachTurn` rules or in fuses and daemons (<doc:DarknessTimeAndDeath>), and they tick even on the turns the player wasted trying something forbidden. Each-turn rules run independently: if one throws, the engine catches it and moves on to the next, so one region's daemon can't silently kill another's.

## Meta intents skip everything

A few intents talk to the *game program*, not the game world: ``Intent/score``, ``Intent/quit``, ``Intent/version``, and the four state-management verbs ``Intent/save``, ``Intent/restore``, ``Intent/undo``, and ``Intent/restart``. These are **meta** intents. They run no rules at all and do not consume a turn — asking for your score is not an action the world should react to, and it should not advance a timed puzzle. Everything in the numbered list above is gated on the intent not being meta.

`save` and `restore` add one more conversational move: they answer with a filename question ("Save to what file?"), and the *next* input line — raw, untokenized — is its answer. Like the parser's clarifying questions, these round-trips are pending state inside ``GameWorld``; the driver just keeps feeding lines. The death prompt after ``die(_:)`` works the same way. See <doc:DarknessTimeAndDeath>.

## Everything commits at once

Throughout the turn, rules and the default action read and write a *scratch* copy of the world state. Nothing is visible outside the turn until it finishes. At the very end, the engine commits that scratch state in one step and returns a ``TurnResult`` — the text to print, whether the game is now finished, and the ``StatusLine`` to show.

Because all mutation funnels through one committed value, a turn is atomic: the player never observes a half-applied turn, and saving the game *is* just serializing that value — that's exactly what the `save` verb writes to disk, and what `undo`'s one-turn snapshot holds in memory. This is the same single-state design described in <doc:AnatomyOfAGame>.

## See also

- <doc:WritingRules>
- <doc:AnatomyOfAGame>
- <doc:AddingCustomVerbs>
- <doc:DarknessTimeAndDeath>
