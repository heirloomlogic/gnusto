# The Lighthouse — design document

A demonstration game for the Gnusto engine. A rock, a tower, a rising sea, and one
job: get the light burning again before the tide takes the jetty.

This document is the story-and-copy source of truth. It is iterated on separately
from the code, by a writer rather than an implementer. **Read [Mechanics
contract](#mechanics-contract) before changing anything** — this game exists to
show a working author one idiom at a time, and the story is the vehicle, not the
cargo.

Tracking issue: [#87](https://github.com/heirloomlogic/gnusto/issues/87).

---

## Contents

- [What this game is for](#what-this-game-is-for)
- [Mechanics contract](#mechanics-contract)
- [Premise](#premise)
- [The player](#the-player)
- [The keeper](#the-keeper)
- [Map](#map)
- [The two clocks](#the-two-clocks)
- [The solution](#the-solution)
- [Copy](#copy)
- [Known defects](#known-defects)
- [Open questions](#open-questions)

---

## What this game is for

The engine ships three worked examples and they are not interchangeable.
`CloakOfDarkness` is the minimal acceptance benchmark — the standard IF exercise,
three rooms, one trick. `Zork1` is the full reconstruction, and reading it means
reading a hundred and ninety rooms. Neither is what an author wants on their first
afternoon.

The Lighthouse is the one in between: **the shortest complete read in the repo.**
Four rooms, twelve moves, one winnable ending, and every piece in it exists to
show an idiom an author reaches for in their first week — a container, a locked
door, a fuse, a daemon, a roaming actor, a piece of custom global state, a content
bundle, two plugins, and one custom verb. Nothing here is decorative. If a feature
is in the game, the win path goes through it or the death does.

One idiom per entity, and each idiom demonstrated once. That is what keeps the file
short enough to read in a sitting. A second locked door would teach nothing the
first one didn't.

---

## Mechanics contract

The middle column is how the story *currently* carries each mechanic. The right
column is what has to remain true no matter how the story is rewritten.

| Mechanic | How the story carries it | Must survive rewriting |
|---|---|---|
| Container | The sea chest in the storeroom, closed, holding both tools. | One closed container standing between the player and the tools they need. |
| Surface | The stone shelf in the base, with the key lying on it. | One surface, holding the thing you need first, in plain sight from the doorway. |
| Door + lock | The stout storeroom door, worked by the brass key. | **One** locked gate, and its key found before it. Not two — the second teaches nothing. |
| Fuse | The oil lamp: a flicker at six turns lit, out at nine. Relighting restarts the burn from full. | **Two** fuses, warning then failure, on one object. Relighting restarts rather than banks. |
| Daemon | The tide, rising every turn, drowning anyone still on the jetty. | **One** always-running daemon, and its danger confined to one room, so the player learns that a daemon ticks everywhere and only *matters* somewhere. |
| Darkness | The Lamp Room is dark, and the beacon in it is out. | The goal room stays dark. This is the only thing making the portable light load-bearing. |
| Actor | The keeper, limping between the base and the lamp room. | **One** roaming actor, drawing from the seeded stream only on turns she could actually be seen. |
| Custom verb | `TALK TO KEEPER`, and the terser `TALK KEEPER`. | **One** custom verb, both sentence shapes, answered by a rule rather than an action. |
| `@Global` state | `tideStage`, read by the jetty's live description; `keeperGreeted`, gating the briefing. | One number that live prose reads, and one flag that fires a line exactly once. Both save and restore. |
| Content bundle | `Tower` owns the Lamp Room and the beacon. | The goal lives in a bundle and the fuel for it lives in the host. The seam is the demonstration. |
| Cross-bundle rule | Lighting the beacon is the host's rule, because it checks for the oil can found downstairs. | The winning rule stays the host's. A bundle that could win on its own proves nothing about bundles. |
| Plugins | `GnustoScoring` (stateful, in `content`) and `GnustoActors` (logic-only, spliced into `timers`). | **Both** kinds of plugin, wired the two different ways. |
| Scoring | Five for reaching the storeroom, twenty for the beacon. | `maxScore` stays the sum of its declared awards, and there are **two** of them — one for progress, one for the win. |

**Free to change:** every name, all prose, the room descriptions, the keeper's
identity and voice, the tone, the title, the tagline, and the specific numbers on
the tide and the lamp.

**Not free to change without revisiting the implementation plan:** everything in the
right-hand column above.

One of those rows has teeth the others don't. The engine reads `maxScore` at
bootstrap, before any scoring rule can run, so the total is the author's arithmetic
and **nothing checks it** — not the tests, not the harness. A rewrite that adds a
third award and forgets the total ships a game that can never reach its own maximum,
and nothing will say so.

---

## Premise

A light on a rock, and a keeper too old to climb her own stairs.

The storm went through in the night and took the beacon with it. The keeper got
down the tower and no further; her leg is finished for the season and the tender
is not due for a week. She rowed out for the only help available, which is you,
and brought you back on the last of the ebb.

That was a quarter of an hour ago. The sea has turned since, and the jetty you are
standing on is the lowest thing for a mile.

---

## The player

Nobody in particular, and that is deliberate. This game is read by an author
looking at the source with the prose as a second concern; a player character with
a history would be a paragraph they have to hold in their head while they are
trying to see how a fuse is declared.

So: you are whoever the keeper could find, you have hands, and you can climb
stairs. `X ME` gets the engine's stock answer, and that is the correct amount of
characterization for this game.

---

## The keeper

The one other soul on the rock, and the game's whole social surface.

She is old, her leg is bad, and she is not fussed about it. She has kept this
light for long enough that the storm reads to her as weather rather than as
disaster; the thing she is short on is not courage but stairs. She tells you where
the key is and where the oil is, once, properly — and after that she tells you
again, shorter, as often as you ask, because she has answered worse questions than
yours.

**Her one job, structurally:** she is the hint system, and she is a roaming actor,
and those two facts are in tension on purpose. She is not always where you left
her. A player who wants the briefing may have to go and find her, which is the
cheapest possible lesson that an actor with a schedule is a different animal from
a signpost.

**Her prose has to know she moves.** She occupies two rooms, one below the other,
so any line describing her arrival, her departure, or her surroundings has to be
true in both. Most of them aren't; see [Known defects](#known-defects).

---

## Map

Four rooms. Three of them are one move apart.

```
                 Lamp Room   ← dark; the beacon
                     │ up
                     │
    Jetty ── north ── Base ── east (stout door) ── Storeroom
```

| Room | Notes |
|---|---|
| **Jetty** | Start, and the only lethal room. Live description — the prose rises with the water. No static description at all; the `describe` rule is the whole thing. |
| **Base of the Lighthouse** | The hub. The stone shelf and the brass key on it. The keeper, when she is down. Stairs up, door east, jetty south. |
| **Storeroom** | Behind the locked door. The sea chest, holding the lamp and the oil can. Worth five points to reach. |
| **Lamp Room** | **Dark.** The beacon on its carriage. Lives in the `Tower` bundle, not in the host — the one piece of geography the game does not own. |

---

## The two clocks

This game runs two timers at once and they measure different things. A player
conflates them, and that confusion is the intended texture.

**The tide** is a daemon. It ticks at the end of every turn from the first one,
wherever the player is standing, and it never stops. It only *speaks* on the
jetty:

| Turn on the jetty | What the sea does |
|---|---|
| 1–2 | *Cold water sluices between the planks of the jetty.* |
| 3 | *The tide is coming in fast now — the jetty is awash to your ankles.* |
| 4 | It closes over you. |

So the real deadline is **three turns to get off the jetty**, and it is spent before
the player has understood that it was running. There is no deadline on the win — a
player who reaches the base has the rest of the evening. Whether the tagline should
go on implying otherwise is a live question; see [Open questions](#open-questions).

**The lamp** is a pair of fuses, and they only run while it is burning:

| Turns lit | What the lamp does |
|---|---|
| 6 | *The oil lamp's flame sinks to a sullen flicker.* |
| 9 | *The oil lamp gutters, and goes out.* |

Dousing the lamp stops both. Relighting it starts both again from zero, so the
lamp holds nine turns of light at a time and an unlimited number of nine-turn
stretches. That is a simplification and the code says so: a fuller model banks the
remaining fuel on turn-off, and the clean restart is chosen because it keeps the
idiom legible in ten lines. The nine turns are generous by design — the winning
route only needs three of them.

---

## The solution

Twelve moves, no red herrings, six gates.

```
north              — off the jetty before the sea takes it     (the tide gate)
take key           — from the shelf                            (the shelf gate)
unlock door with key
open door
east                                                           (the lock gate)
open chest                                                     (the container gate)
take lamp
take can
light lamp
west
up                                                             (the light gate)
light beacon                                                   (the fuel gate)
```

What the annotations don't carry:

- **The tide gate** is the only thing in the game that can kill you, and it is over
  before the player knows it started.
- **The lock gate** costs two commands, not one. The engine does not fold `unlock`
  into `open`, and a player who types only the first is told the door is closed.
- **The light gate** is why the Lamp Room is dark, and the only thing making the
  portable lamp load-bearing rather than scenery.
- **The fuel gate** is the cross-bundle seam: a `Tower` item, gated on a host item,
  by a host rule. Its refusal is in [Copy](#copy).

Twenty-five points: five the moment you step into the storeroom (paid silently — the
player finds out from `SCORE`) and twenty on the beacon.

Pinned seed: **0**. The keeper's roaming is the only thing in the game that draws
from the random stream, and a route that expects to find her in a particular room
needs the seed to say so. `LighthouseTranscriptTests.winningPath` walks this exact
route at seed 0; `keeperBriefsOnceThenReminds` uses seed 3, because at seed 0 she
leaves the base on the very turn the player arrives.

---

## Copy

Draft prose. This is the layer a writer should expect to replace wholesale. The
voice is plain and unhurried: short declaratives, sea nouns, no adverbs, and the
narrator never tells you to be worried.

### Opening

> The keeper's boat brought you out on the last of the ebb, and already the sea is
> turning. The lighthouse stands dark above the jetty — and a dark lighthouse is
> how ships are lost.

> **The Lighthouse**
> Relight the beacon before the tide comes in.

### Rooms

**Jetty** — the body of the description is constant and the last sentence reads
the tide:

> A short stone jetty runs out from the foot of the lighthouse to the mooring
> where the boat is tied.
>
> — at stage 0: *The tide is low, the boards dry underfoot.*
> — at stages 1–2: *Water is beginning to lap over the far boards.*
> — at stage 3 and after: *The sea is nearly over the boards — no time left.*

**Base of the Lighthouse** — *The round stone room at the foot of the tower. A
shelf is set into the wall, stairs climb into the dark above, and a stout door
leads east to the storeroom. The jetty is back to the south.*

**Storeroom** — *A cramped space that smells of tar and brine. Coils of rope and a
heavy chest fill most of it. The only door is back to the west.*

**Lamp Room** — *Glass walls wrap the top of the tower, open to the night on every
side. The great beacon squats at the center on its iron carriage. Stairs spiral
back down.* (Unlit: *It is pitch black. You can't see a thing.*)

### Things

- **stone shelf** (listing line) — *A brass key lies on the stone shelf.*
- **brass key** — *A stubby brass key, green at the teeth.*
- **heavy chest** — *A brine-swollen sea chest with an iron clasp.*
- **oil lamp** — *A dented brass lamp with a stub of wick. It sloshes — still some
  oil in it.*
- **oil can** — *A tin can heavy with lamp oil.*
- **beacon**, dark — *The great brass beacon is cold and dark, its oil reservoir
  bone dry.*
- **beacon**, lit — *The beacon roars with light, its beam wheeling out across the
  black water.*

### The keeper

Standing line, printed on every look while she is in the room:

> The old keeper stands by the window, favoring one leg.

Arrival and departure, printed only when the player is somewhere lit and can see
it happen:

> The keeper climbs stiffly into the room.
> The keeper limps away up the stairs.

First `TALK TO KEEPER` — the briefing, which is also the walkthrough:

> The old keeper turns from the window. "Storm doused the beacon and my leg's no
> good for the stairs," she says. "The storeroom key's on the shelf yonder; the
> oil's in the chest inside. Light her again before the tide's full in, would
> you?"

Every `TALK TO KEEPER` after that:

> "Key's on the shelf, oil's in the chest," the keeper says again, patient as
> tide. "Light her before the water's full in."

### The tide

> Cold water sluices between the planks of the jetty.
> The tide is coming in fast now — the jetty is awash to your ankles.
> The sea closes over the jetty, and over you.

### The lamp

> The oil lamp's flame sinks to a sullen flicker.
> The oil lamp gutters, and goes out.

### Refusal and ending

The fuel gate:

> The beacon's reservoir is dry. You'll want the oil from the storeroom.

The win:

> You tip the last of the oil into the beacon's reservoir and touch your lamp to
> the wick. Flame runs along it — and the great beacon roars alight, its beam
> wheeling out across the black water. Far off, a ship's bell answers.

---

## Known defects

**The copy above is transcribed from the game as it ships, not as it should read.**
Several of those lines are known to be wrong, and a rewrite should fix them rather
than faithfully preserve them.

The list is deliberately not here. It would go stale the first time an issue closed,
and a stale entry is worse than none: a play-test verifier reading it would dismiss a
genuine regression as somebody else's problem. Two files carry it instead, and
neither can rot.

- [`lighthouse-playtest-2026-07-30.md`](lighthouse-playtest-2026-07-30.md) is the
  last round, dated in its own filename. It names each wrong line, the frame it
  printed in, and the cause.
- [`lighthouse-playtest-ledger.md`](lighthouse-playtest-ledger.md) is append-only:
  every finding ever filed against this game, and what became of it.

For what is open right now, ask the tracker: `gh issue list --state open --search
Lighthouse`.

The ones a writer meets first are the keeper's lines, the shelf's listing line, both
lamp fuses and the beacon's refusal. The mechanics contract licenses all of those
fixes: each is prose, or scenery behind prose, and none of the counts in the
right-hand column moves.

---

## Open questions

1. **Should the tagline stop implying a race?** *"Relight the beacon before the tide
   comes in"* reads as a global clock, and there isn't one — the tide is lethal on
   the jetty and inert everywhere else, so a player who walks north on turn one has
   all evening. A playtest round filed this as a defect twice and it was refuted
   both times, as **licensed by the contract**: the type doc comment says "the
   rising `tide` that eventually floods the jetty", the `timers` comment says "time
   passes wherever the player is, but the sea only threatens on the jetty", and the
   tagline prints at boot, on the jetty, at stage 0 — the one moment when it is
   exactly true. That is a good argument and it is not the whole question, because
   the line goes on being read after that moment. Three ways out: leave it, reword
   the tagline to promise the jetty rather than the game, or give the tide somewhere
   else to reach. The contract permits the third only by *moving* the daemon's one
   lethal room, never by adding a second.
2. **The beacon's lit description can never print.** The winning rule calls
   `end(won:)` before anything sets `beacon.isLit`, so half of `beacon.describe` is
   dead prose and `Tower`'s doc comment advertises a branch that cannot be reached.
   Filed as [#95](https://github.com/heirloomlogic/gnusto/issues/95) with three
   options: set the trait before ending, delete the branch, or give the player one
   turn with the lit beacon before the ship's bell. The third is the better scene
   and the most work.
3. **Five points arrive without a word.** `Scoring.visit` awards on entry and says
   nothing, so a player learns about the storeroom's five points only by typing
   `SCORE`. That is the plugin's behaviour, not this game's — but this is the game
   an author reads to learn what scoring looks like.
4. **The lamp banks nothing.** Deliberate, and documented in the source, but a
   reader coming from the Zork lantern will expect fuel to be spent rather than
   reset. Worth a sentence in the game's own prose, or worth changing.
