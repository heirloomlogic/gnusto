# The playtester's brief

Read this before your charter. It is the same for every charter that reads it, so
that a finding of yours reads the same way as one from a tester who was somewhere
else in the game.

**The blind charters do not read this file.** They get `finding-contract.md` and
nothing else, on purpose: somebody handed the map navigates instead of exploring.
If you are one of them you are not here.

## What you are looking for

**Sentences that are not true of the frame they printed in.** The frame is three
things at once: the room the player is standing in, the hour on the clock, and the
state of the world at that moment.

This is not a hunt for crashes, and it is not a critique of the writing. It is one
question, asked of every line: *given where the player is and what has happened,
is this sentence true?*

`swift test` cannot ask that question. A transcript test asserts that a line
**appears**; it never asks whether the line is **true**. Every test passes while an
NPC goes on "looking at the fire" from the bottom of a dark coal cellar, because a
test that greps for "looking at the fire" finds it and is satisfied. You are the
part of the process that isn't satisfied.

Every defect in this answer key was found by a human reading prose, and none by the
suite:

| The line | Why it was false |
|---|---|
| "Mrs. Vane is in her chair with the lamp unlit." | Printed in the Back Yard, where she was standing on the step |
| "the only person here who has looked at the wreckage" | Printed at 5:30, sixteen minutes before there was a wreckage |
| "Fifty, and wearing his hat indoors" | Printed in the back garden |
| "the note in your ears steps down one" | Printed indoors, sixty feet and two walls from the blast |
| "the dust … settles on the hall table" | Printed in the kitchen, which has no hall table |
| "The Dr. Pike would take exception to that." | A stock line with a definite article in front of a proper name |

## How a session works

You play the live game through its own MCP server, one turn at a time. `open`
starts a session and hands back the game's first words; `move` takes turns; the
session stays open, so there is no replaying from the start to see the next line.

- **Every turn ends with a `[status]` line** naming the room, the move counter and
  whether the command cost a turn. Read it rather than computing it. Meta commands
  and parse failures cost no turn, stub verbs like `sing` and `dig` do, and this
  footer is why none of that is arithmetic you have to get right any more.
- **`coverage` is a worklist, not a statistic.** Each item is a command you can
  paste and a sentence saying where the game showed you the thing. The count it
  returns is a countdown.
- **`note` costs no turn.** Use it the moment a line reads wrong, at the turn that
  printed it — not forty turns later from memory. `suspicious: true` marks it.
  Notes are written into the transcript, so they live in the evidence.
- **`finish` accepts.** It does not refuse, it has no minimum on the reason, and it
  does not close the session — you can call `move` again after. What it does is
  account: it tells you what was still open when you stopped, and that list *is*
  the round's coverage gap. An unexplained gap is still counted as a gap, so say
  why in `leaving` if you are stopping on purpose.
- **If your `open` returns an `instruction`, follow it for the whole session.** It
  tells you what to do the first time the game offers something you cannot take
  back. Another tester has the opposite orders, so the branch you leave alone is
  covered by them and the one you take is yours to describe.

Write nothing outside `.context/playtest/`.

## Your reproducer is the deliverable

A finding without a reproducer cannot become a test, and a finding that cannot
become a test will come back. Every finding carries the seed and the **shortest**
command list that reaches it — not the forty commands you actually typed.

The server replays and verifies that list for you and records the transcript path
it produced. If the trimmed list does not produce the line you are reporting, you
have not found the reproducer yet; say so in your coverage note rather than
reporting a sequence that does not work.

`replay` writes its own probe directory and hands back `transcript=<path>` on the
first line. Copy that path into your finding whenever the frame you are quoting
came from a replay rather than from your own session — it is the file that holds
the turn, and a quote with no file behind it cannot be checked by anyone who
wasn't there.

## The judgement kernel

Three rules that hold for every game, statable from a transcript with no game
knowledge. Everything else the engine guarantees is in `CLAUDE.md`, which you have
— repeating it here is where doc-drift comes from.

**K1 — There are two description channels, and they behave differently.**
`description(…)` / `describe { }` is the *examine* text. `firstSight(…)` /
`presence { }` is the *room-listing* paragraph. On an item the listing line prints
until the player touches it. **On an actor it prints on every look, forever.**

So an actor's listing line must be true in every room and at every hour that actor
can occupy. One that names a place ("in her chair"), a posture toward a thing that
might not be there ("looking at the fire"), or a state that might not have happened
yet ("has looked at the wreckage") is a defect unless it is a `presence` rule keyed
on *both* the room and the state. Name the channel in your fault: the fix for a
location-blind `firstSight` is to delete the trait and add a `presence` rule, never
to add a second channel — declaring both is a fatal bootstrap error.

**K4 — Actors are always listed if perceivable.** `scenery` has no effect on them;
only `hidden`-and-unrevealed, or being offstage, suppresses one. So an actor who
leaves with no departure line has silently ceased to exist, and an actor whose
departure was narrated but who is still in the listing is the same defect inverted.
Check both directions.

**K10 — Fuses are relative to an event; alarms are absolute.** A fuse's text lands
one or two turns after its event, by which time the player may have walked away. So
aftermath prose has to be judged on **two independent axes**: where the player is
*now*, and where the player *was then*. "There is grass in your cuff" belongs to
where they were knocked down. "The note in your ears steps down one" belongs to an
ear that was actually ringing. Judge each clause separately — a single sentence can
be half true.

## What is never a finding, from anyone

1. **A character declining to do something is characterization, not a defect.**
   "The game said no" is never by itself a finding. Mrs. Vane refusing to light the
   lamp is who she is.
2. **A refusal that is correct and merely terse.**
3. **Prose you would have written differently.** Taste findings are admissible at
   the lowest severity, must be labelled as taste, and must never crowd out a truth
   finding.

Notice what is *not* on that list: anything owned by another issue. **Which defect
classes are owned elsewhere is supplied per round**, in your prompt, from the issues
open when the round runs. If your prompt names none, nothing is owned elsewhere and
every symptom you find is yours to judge. That indirection exists because this list
once named three issues by number, all three were fixed, and the brief went on
telling testers to forward the exact symptoms that had become regressions. A stale
"already owned" rule is worse than a wrong one: a wrong rule produces a finding the
verifier can refute, a stale one produces silence.

If a rule here contradicts what the code does, the code wins, and the contradiction
is itself a `doc-drift` finding against this file.

## What a good finding looks like

> **Claim.** Mrs. Vane's room-listing line says she is "in her chair with the lamp
> unlit" while she is standing in the Back Yard.
>
> **Frame.** Back Yard, 5:50 (the turn's `[status]` line reads `room=Back Yard |
> moves=10`), after the blast, on the turn *after* her arrival line was spent.
>
> **Reproducer.** seed 0; `south`, `west`, `z`×7, `look`.
>
> **Excerpt.** `Mrs. Vane is in her chair with the lamp unlit.` printed in the
> Back Yard listing, three lines under "some of it is still burning quietly".
>
> **Fault.** A static `firstSight` on an actor. Per K1 it prints on every look
> forever, so it has no way to know she spends part of the evening out of that
> chair. The fix is to delete the trait and add a `presence` rule keyed on her
> location.

Note what makes it good: the frame is read off the status footer rather than
computed from a command count, the reproducer is eleven commands rather than the
forty the tester typed, the excerpt is quoted verbatim so the round can trace it
back to the declaration that printed it, and the fault names the mechanism instead
of saying "this is wrong".
