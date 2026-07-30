# The playtester's brief

Read this before your charter. It is the same for every tester and every game, so
that findings from different testers can be compared, deduplicated, and verified
against one another.

## What you are looking for

**Sentences that are not true of the frame they printed in.** The frame is three
things at once: the room the player is standing in, the hour on the clock, and the
state of the world at that moment.

This is not a hunt for crashes, and it is not a critique of the writing. It is one
question, asked of every line: *given where the player is and what has happened,
is this sentence true?*

`swift test` cannot ask that question. A transcript test asserts that a line
**appears**; it never asks whether the line is **true**. All ~780 tests pass while
an NPC goes on "looking at the fire" from the bottom of a dark coal cellar, because
a test that greps for "looking at the fire" finds it and is satisfied. You are the
part of the process that isn't satisfied.

Every defect in the answer key below was found by a human reading prose, and none
by the suite:

| The line | Why it was false |
|---|---|
| "Mrs. Vane is in her chair with the lamp unlit." | Printed in the Back Yard, where she was standing on the step |
| "the only person here who has looked at the wreckage" | Printed at 5:30, sixteen minutes before there was a wreckage |
| "Fifty, and wearing his hat indoors" | Printed in the back garden |
| "the note in your ears steps down one" | Printed indoors, sixty feet and two walls from the blast |
| "the dust … settles on the hall table" | Printed in the kitchen, which has no hall table |
| "The Dr. Pike would take exception to that." | A stock line with a definite article in front of a proper name |

## How to play

Every turn is a fresh process. You do not hold a session open; you replay the whole
command list from the start each time, with the seed pinned, and read the result.

```sh
bin/playtest-replay <Game> --commands <your-file> --seed 0 --label <your-label> --tail 60
```

Append to your command file, run again, read the new tail. A boot plus a hundred
turns is milliseconds, so replaying is free. Determinism falls out of it: the
transcript you just read is exactly the transcript `play(Game(), [...], seed: 0)`
will produce, which is why your command list *is* your reproducer.

Four things to know:

- **Batch commands when you are only walking.** Add five at a time to cross the
  map, one at a time when you are reading closely.
- **`--tail` is how you stay affordable.** Re-reading a growing transcript every
  turn is the real cost of this job. Read the tail; open the full file only when
  you need earlier context.
- **Annotate as you go.** A line starting `//` or `#` is recorded in the transcript
  and never reaches the parser — no turn, no clock tick, no rule. Write down what
  you are probing and why. The annotated transcript is an artifact someone else
  will read.
- **For a deep state, save once and restore.** `--save <slot>` at the end of a
  prologue, then `--restore <slot>` in each probe, instead of replaying forty
  `z`s. Restoring costs no turn, so it does not move the clock.

## Your reproducer is the deliverable

A finding without a reproducer cannot become a test, and a finding that cannot
become a test will come back. Every finding must carry the seed and the **shortest**
command list that reaches it.

**Replay your reproducer from a clean start before you report it.** If the trimmed
list does not produce the line you are reporting, you have not found the reproducer
yet — say so in your coverage note rather than reporting a sequence that doesn't
work.

## Frame arithmetic

**Never count commands as turns.** Meta commands (`score`, `quit`, `version`,
`undo`, `restart`, `save`, `restore`) and *every command that fails to parse* cost
no turn at all. This is the most common timing mistake in this repo, and it is easy
to make: four commands where one was a typo is three turns, and if you assumed four
you are now reasoning about the wrong minute.

So: compute the hour if you like — turn *n* reads `start + minutesPerTurn·(n−1)` —
but **anchor every hour you claim with a real reading inside the transcript**, from
`time` or from a room listing you can place. A probe whose anchor disagrees with
your arithmetic is void, and reporting it wastes a verifier.

## The judgement kernel

These hold for every game, with no game knowledge at all. When the design doc is
silent, this is your oracle. Each is stated so you can rule on it from a transcript.

**K1 — There are two description channels, and they behave differently.**
`description(…)` / `describe { }` is the *examine* text. `firstSight(…)` /
`presence { }` is the *room-listing* paragraph. On an item the listing line prints
until the player touches it. **On an actor it prints on every look, forever.**

Therefore an actor's listing line must be true in every room and at every hour that
actor can occupy. A listing line that names a place ("in her chair"), a posture
toward a thing that might not be there ("looking at the fire"), or a state that
might not have happened yet ("has looked at the wreckage") is a defect unless it is
a `presence` rule keyed on *both* the room and the state.

**K2 — A static trait and its rule are mutually exclusive.** `description` plus
`describe`, or `firstSight` plus `presence`, on one entity is a fatal bootstrap
error. So the fix for a location-blind `firstSight` is to *delete the trait* and add
a `presence` rule — never to add a second channel. Precedence: runtime assignment >
rule > static trait. Presence has no runtime setter.

**K3 — `onEnter` runs after the player has moved, and cannot block entry.** Prose
claiming the player can't get somewhere, printed while they are standing there, is a
defect: either the prose is wrong or the gate is missing.

**K4 — Actors are always listed if perceivable.** `scenery` has no effect on them;
only `hidden`-and-unrevealed, or being offstage, suppresses one. So an actor who
leaves with no departure line has silently ceased to exist, and an actor whose
departure was narrated but who is still in the listing is the same defect inverted.
Check both directions.

**K5 — `reveal()` is one-way and `isTouched` is read-only.** Neither is a toggle. A
first-time line that prints twice, or state that appears to un-reveal, is a defect.

**K6 — Meta intents and parse failures cost no turn.** See *Frame arithmetic*.

**K7 — `search` / `find` / `look for` all mean the same intent**, and it refuses in
a fixed order: `cantReach` for something out of reach, then a person, then anything
that isn't a container ("You find nothing of interest in the …").
**"You can't see any such thing" is reserved for a noun that isn't in scope at
all** — so that answer to `search <a thing the room just described>` is a defect,
not stock behavior. (This changed; older notes say otherwise. Trust the code.)

**K8 — Every noun the game prints must be answerable.** Not just room descriptions:
examine texts, refusals, blocked-exit prose, topic answers. If the game's prose put
a word on the page, the parser must know it. Vocabulary comes from `name` (last word
is the noun, earlier words are adjectives) plus `synonyms` and `adjectives`.

**The tie-break that matters:** `I don't know the word "X"` is issue #76 — *unless
the game's own prose printed X*, in which case it is K8 and it is yours. A room that
describes "black and white tile, worn through to the grout" and then cannot answer
`x tile` is a K8 finding, even though the reply is an unknown-word reply. Ask: did
the game invite this word? If yes, report it. If you invented the word, bucket it.

**K9 — Stock lines interpolate a definite article into a name.** Twenty-seven of
them do. A game whose actors have proper names or honorifics must re-skin every
actor-directed one, and the failure is mechanically detectable with zero game
knowledge: `the ` immediately followed by a capitalized word, or by
`Mr`/`Mrs`/`Miss`/`Dr`/`Sir`. "The Dr. Pike would take exception to that." is the
whole class.

**K10 — Fuses are relative to an event; alarms are absolute.** A fuse's text lands
one or two turns after its event, by which time the player may have walked away. So
any aftermath prose has to be judged on **two independent axes**: where the player
is *now*, and where the player *was then*. "There is grass in your cuff" belongs to
where they were knocked down. "The note in your ears steps down one" belongs to an
ear that was actually ringing. Judge each clause separately — a single sentence can
be half true.

**K11 — Clock time is derived from the move count, not ticked.** Every rule, action,
fuse and daemon in one turn reads the same time.

**K12 — Bootstrap warnings are surfaced at runtime.** Warning text in the transcript
preamble, or on standard error, is a finding in its own right.

**K13 — The known words are the standard verb table plus the game's own verbs.**
Anything else answers `I don't know the word "…"`. See K8 for the tie-break.

## What is never a finding, from anyone

1. **`I don't know the word "X"` for a word you invented.** That is issue **#76**
   (stub verbs), already owned. Collect them in one deduplicated list with counts
   and hand it over as a routed bucket, never as findings. `attack`, `break`,
   `burn`, `climb`, `dig`, `eat`, `jump`, `kiss`, `listen`, `pray`, `sing`, `smell`,
   `throw`, `touch` are all #76's. **Exception:** promote out of #76 if the word is
   a synonym for an intent the engine already has, or if the game's prose invited it
   (K8).
2. **A character declining to do something is characterization, not a defect.**
   "The game said no" is never by itself a finding. Mrs. Vane refusing to light the
   lamp is who she is.
3. **A refusal that is correct and merely terse.**
4. **Prose you would have written differently.** Taste findings are admissible at
   the lowest severity, must be labelled as taste, and must never crowd out a truth
   finding.

**Two things that used to belong on that list and no longer do.** Both were fixed,
so the old behaviour is now a **regression**, and reporting it at raised severity is
exactly right:

- **`x me` / `x myself` / `x self` answer.** The player is a real entity, always in
  scope, placed nowhere — so it never shows up in a room listing, an inventory or
  `take all`, but examining it works. `I don't know the word "me"` is a defect now.
  A game that gives the player no description of their own is worth a `note`; the
  engine supplies a stock one.
- **Pasting a multi-line block into a line that already begins `//` or `#` folds it
  into one comment.** Every line break becomes a single space and nothing submits
  until Return. Pasting into any *other* line still submits one command per line, on
  purpose, so a walkthrough can be replayed by pasting it — that is not a defect.
  Terminals without bracketed paste submit line-at-a-time as before.

This is the ordinary fate of a "never a finding" list: it is a snapshot of which
defects are owned elsewhere, and it goes stale the moment one of them is fixed. If a
rule here contradicts what the code does, the code wins and the contradiction is
itself a `doc-drift` finding against this file.

## What a good finding looks like

> **Claim.** Mrs. Vane's room-listing line says she is "in her chair with the lamp
> unlit" while she is standing in the Back Yard.
>
> **Frame.** Back Yard, 5:50 (anchored: `time` printed 5:50 on turn 10), after the
> blast, on the turn *after* her arrival line was spent.
>
> **Reproducer.** seed 0; `south`, `west`, `z`×7, `look`.
>
> **Excerpt.** `Mrs. Vane is in her chair with the lamp unlit.` printed in the
> Back Yard listing, three lines under "some of it is still burning quietly".
>
> **Fault.** A static `firstSight` on an actor. Per K1 it prints on every look
> forever, so it has no way to know she spends part of the evening out of that
> chair. Per K2 the fix is to delete the trait and add a `presence` rule keyed on
> her location.

Note what makes it good: the hour is anchored to a real reading, the reproducer is
eleven commands rather than the forty the tester actually typed, the excerpt is
quoted verbatim, and the fault names the mechanism rather than saying "this is
wrong".
