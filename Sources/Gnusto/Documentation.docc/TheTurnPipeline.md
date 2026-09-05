# The Turn Pipeline

What happens between the player pressing Return and the next prompt.

## Overview

Every line the player types runs through the same fixed sequence of stages. This section walks that sequence — which rules fire, in what order, and how one rule can stop the rest — from raw input to committed state.

## From input to command

The ``REPL`` reads a line and hands it to ``GameWorld/perform(_:)``. The parser first turns the text into a ``Command`` — an ``Intent`` (the canonical action, like ``Intent/take``) plus the objects, preposition, and direction it resolved.

Parsing can fail: an unknown word, nothing in scope, a verb with no object. **Parse failures are free.** No rules run, the state is untouched, and the turn counter does not advance — the player just sees a message ("I don't understand that." / "You can't see any such thing here.") and a fresh prompt. Only a successfully parsed command enters the pipeline below.

## How the parser converses

Five parser behaviors go beyond one-line-in, one-command-out:

- **Questions stay open.** When the parser asks a clarifying question — "Which do you mean: the brass lantern or the rusty lantern?", "What do you want to take?" — the next input line is first tried as its *answer*: an adjective (`brass`), a fuller phrase, or the missing object completes the original command. Narrowing can take several rounds; a line that isn't an answer simply runs as a fresh command and the question is forgotten. Questions, like all parse failures, are free turns.
- **Pronouns.** `it` refers to the last direct object the player named (naming binds even if the action was refused); `them` refers to the group of the last multi-object command, or to the last single thing the player named that was declared `plural` — the stairs, the gloves — since a plural thing is one thing and that is the pronoun English gives it. Both go in the same slot, so the one named last is the one meant. `them` naming one thing is a noun phrase and works in either object slot, for every verb, exactly as `it` does; it is only a group of two or more that the four multi-object verbs alone will take. A pronoun whose referent is gone from view fails in scope like any other noun, and one bound to nothing answers "I don't know what “them” refers to."
- **Multi-object commands.** `all` (or `everything`) in the direct-object slot of `take`, `drop`, `put … in`, or `put … on` expands to the eligible objects — for `take`, everything **reachable**, takable, and not already carried at any depth (so the water in the bottle in your hand is skipped, and so are the medal behind a shut glass case and the axe in the troll's hands); for the rest, everything held, direct children only, so `drop all` empties your hands and not your sack. Each object then runs stages 1–7 of the pipeline below as its own single-object ``Command`` with a labeled result line (`brass lantern: Taken.`), so `before`/`after` rules never see "all". The each-turn stages (8–9) still run **once** for the whole command — a burning lantern loses one turn of fuel, not one per object — and they run before any object's command exists, so their rules see a ``Command`` carrying the group's intent with no direct object: `command.intent` is what the player typed, `command.directObject` is nil. Other verbs refuse multiple objects, and `all` never fills an indirect slot.
- **Conjunction lists.** `take the bottle and the sack` names the objects instead of sweeping for them, and runs the same per-object expansion: same verbs, same labeled lines, same once-per-turn upkeep. Two differences from `all`. The list keeps the order the player wrote, where `all` sorts by name. And a list is **not** filtered — `take all` skips a scenery statue, but a player who names the statue asked about that thing and is told why they can't have it. A conjunction never fills the indirect slot (`put the coin in the box and the sack` refuses), and `and` is not a command separator: `take the sword and go north` is one unresolvable noun phrase, not two commands.

  The split is a **second pass**, tried only once the whole phrase has failed to name anything. That is what makes the word safe to add: an item declared `name("cup and saucer")` answers to every word of itself, so `take cup and saucer` is one thing, and no phrase that worked before means something else now. The cost is that a game holding a `cup`, a `saucer` *and* a `cup and saucer` can't ask for the first two together — the name wins. Declare a synonym without the conjunction if you need both readings.

  **A comma separates too**, so `take the bottle, the sack and the lamp` is the same list `take the bottle and the sack and the lamp` is, and `take the bottle, the sack` needs no `and` at all. The addressing path reads the *first* comma first (`troll, take the sword`) and only hands it over when the words before it name nobody, so no order changes meaning. Below that, a comma separates more strongly than `and` does — the phrase is cut at its commas and each group is then offered as a name before its own `and` is read as punctuation, which is what lets `take cup and saucer, the coin` be two things and keep the first one's name. A comma standing on its own at either end of a phrase, or doubled, is punctuation and drops out: `take the lamp,` is still one lamp, and the Oxford comma of `take the coin, the feather, and the idol` is one separator, not two.

- **Exclusions.** `take all but the sword` is the escape hatch when `all` would sweep up the one thing the player wants left alone — a lit lamp, a cursed idol, the thing that kills you when you carry it. `but` and `except` are the same word to the parser, what follows is read exactly as a direct slot is — so it separates on the conjunction and on the comma alike, and `take all except the sword and the lamp` and `take all except the sword, the lamp` both except two — and `them` takes an exception as readily as `all` does. Excepting something that was never in the set is deliberately no error: the player said which things they didn't mean, not which things are here, so `take all but the statue` runs whether or not the statue was ever on offer. A subtraction that empties a group that wasn't empty says so in its own words rather than claiming the room is bare — that goes for the container `put all in the sack` takes out of its own group, too.

  The word is claimed **only behind a multi-object keyword**, and that is what makes it safe to add. `all`, `everything` and `them` are reserved words no item can answer to, so a phrase this split claims can never also be something's declared name — `take last but one ticket` finds no keyword in front of the `but` and resolves as the one object it names, without needing the conjunction's second pass to rescue it. The same rule is why `take the coin but the feather` is left unread: a phrase that names two things and excepts one of them is not English anybody types, and refusing it keeps the word available to games.

## The stages of a turn

Once a command parses, the engine runs these stages in order. Rules are matched by **scope** (world, the current location, or one of the command's objects) and by **intent** (a rule with no intents listed matches any).

1. **World `before`** — ``World/before(_:perform:)`` rules, matching the intent.
2. **Location `beforeEachTurn`** — ``Location/beforeEachTurn(perform:)`` for the current room, every turn regardless of intent.
3. **Location `before`** — ``Location/before(_:perform:)`` for the current room.
4. **Item `before`** — ``Item/before(_:perform:)`` for the indirect object, then the direct object.
5. **The default action** — the engine's built-in behavior for the intent (pick up the item, walk through the exit, describe the thing). This is where the turn actually *does* something if no rule intervened. A custom verb has no built-in behavior, so if nothing else claims the intent this stage answers `text.cantDoThat` and the turn ends here, free (see below).
6. **Item `after`** — ``Item/after(_:perform:)`` for the direct object, then the indirect object.
7. **Location `after`** — ``Location/after(_:perform:)`` for the current room.
8. **Location `afterEachTurn`** — ``Location/afterEachTurn(perform:)`` for the room, every turn.
9. **World `after`** — ``World/after(_:perform:)`` rules.
10. **The timer tick** — every running fuse counts down (firing at zero) and every running daemon runs, fuses first, each group in name order. Once per typed command, never on parse errors, and not once the game has ended. See <doc:DarknessTimeAndDeath>. Characters take their turns here too: there is no separate actor phase — a roaming thief or a counter-attacking troll is a daemon on this same clock (<doc:ActorsAndVehicles>), which is why your swing resolves in stage 5 and the villain's answer lands at the end of the turn.

Then the turn counter advances by one and the turn commits.

`before` rules run outside-in — world, then location, then item — so the broadest rule gets first refusal; `after` rules run inside-out. A `before` rule changes or forbids what is about to happen. An `after` rule only gets to have an opinion about what already did.

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

There is exactly one exception, and it is the case where *nobody* refused. If a custom verb reaches stage 5 with no action, no rule and no stub line to answer it, the player is told "You can't do that." — and that turn is free, like a parse error. The message says nothing happened, so nothing may: no each-turn rules, no timer tick, no move, and the UNDO snapshot still points at the last command that did something. A refusal is the game answering; this is the game having no answer.

Free means free all the way down, too. The `before` rules of stages 1–3 have already run by the time stage 4 gives up, and any of them may have mutated the scratch state — so the engine commits the *pre-turn* state on this path instead of the scratch copy, and the turn's mutations vanish with it. The same rollback covers the `it` binding: naming a thing binds the pronoun before the pipeline runs, but a turn nothing answered never happened, so it leaves `it` pointing where the last real turn left it. A `before` rule that mutates state and then answers nothing has mutated nothing.

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
