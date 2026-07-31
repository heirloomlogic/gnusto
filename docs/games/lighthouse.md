# The Lighthouse — design document

A demonstration game for the Gnusto engine. A rock, a tower, a rising sea, and one
job: keep the light.

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

That is the whole design rule, and it is what keeps the file short enough to read
in one sitting: **one idiom, one entity, one demonstration.** A second locked door
would teach nothing the first one didn't.

The one thing that rule does not cover is scenery, and scenery is not an exception
to it — it is the price of the prose. Every noun a room description prints has to
be a noun the parser knows, or the room reads as unfinished. So the game carries
eleven items nobody has to touch, and the eight below the tower live in a bundle
of their own (`Fixtures`) rather than in the host, precisely so that the file an
author reads to learn the idioms stays the length it advertises.

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
| Content bundle | `Tower` owns the Lamp Room and the beacon; `Fixtures` owns the scenery. | The goal lives in a bundle and the fuel for it lives in the host. The seam is the demonstration. |
| Cross-bundle rule | Lighting the beacon is the host's rule, because it checks for the oil can found downstairs. | The winning rule stays the host's. A bundle that could win on its own proves nothing about bundles. |
| Promoted stubs | Four stub verbs the game contradicts — `pour`/`empty` on the can, `burn` on the lamp and the beacon, `swim`/`dive` on the jetty. | A stub line the game has just called false gets a rule. Per entity, with `reply`/`refuse`, never a wholesale re-skin. |
| Plugins | `GnustoScoring` (stateful, in `content`) and `GnustoActors` (logic-only, spliced into `timers`). | **Both** kinds of plugin, wired the two different ways. |
| Scoring | Five for reaching the storeroom, twenty for the beacon. | `maxScore` stays the sum of its declared awards — checked at bootstrap against the `Scoring` award table — and there are **two** of them, one for progress, one for the win. |

**Free to change:** every name, all prose, the room descriptions, the keeper's
identity and voice, the tone, the title, the tagline, and the specific numbers on
the tide and the lamp.

**Not free to change without revisiting the implementation plan:** the counts in
the right column — one daemon, two fuses, one locked door, one roaming actor, one
custom verb, two scoring awards; the Lamp Room staying dark; the beacon living in
a different bundle from the oil that lights it; and `maxScore` staying the sum of
what the game actually pays out.

The Scoring row used to be the one nothing checked. The engine still reads `maxScore`
at bootstrap, before any scoring rule can run, so it is still a literal — but the two
awards are now declared in the `Scoring` award table, which is the only place a
register's points are written, and the bootstrap compares the table's total against
`maxScore` and warns when they disagree. A rewrite that adds a third award and forgets
the total is a warning on startup and a red test, not a game that quietly ships a
maximum it can never reach.

**Two bundles, for two different reasons.** `Tower` is a bundle because a *region*
wants to own its declarations; `Fixtures` is a bundle because eight scenery items
would otherwise be a third of the host file. Both are `GameContent`, and the
second is there to say that "a region" is only the most obvious reason to want one.
A rewrite may fold `Fixtures` back into the host if it can do so without doubling
the host's length; it may not fold `Tower` in, because the cross-bundle seam is the
demonstration.

---

## Premise

A light on a rock, forty years of keeping it, and a leg that can no longer carry
oil up the stairs.

The storm went through in the night and took the beacon with it. The keeper got
down the tower a step at a time and stood at the bottom taking stock: the tender
not due for a week; the oil in the storeroom; stairs she can still climb, slowly,
both hands to the rail — and no way on earth to climb them holding a can of oil.
A dry beacon does not light for sentiment. So she rowed out on the ebb for the
only help there was, which is you, and had the mooring line in your hands before
you had agreed to anything.

That was a quarter of an hour ago. The sea has turned since, and the jetty you are
standing on is the lowest thing for a mile.

---

## The player

Nobody in particular, and that is deliberate. This game is read by an author
looking at the source with the prose as a second concern; a player character with
a history would be a paragraph they have to hold in their head while they are
trying to see how a fuse is declared.

So: you are whoever the keeper could find, and what you have that she needs is
exactly two free hands. That is the entire characterization, and it is also the
subject — tonight the light gets kept by borrowed hands or not at all. `X ME`
gets the engine's stock answer, and that is the correct amount of
characterization for this game.

---

## The keeper

The one other soul on the rock, and the game's whole social surface.

She has kept this light for forty years — long enough that "the keeper" has worn
the place a name would go, and the game never gives her one. The storm that took
the beacon reads to her as weather; weather has been trying this tower her whole
working life, and the tower is still here. The dark lamp is another matter. A
kept light going unkept is the one thing on this rock she treats as serious.

The leg went bad this season. She can still climb her own stairs, a step at a
time, both hands to the rail; what she cannot do is climb them with a can of oil,
or kneel to the reservoir once she is up. That distinction is load-bearing. It is
why you exist — and it is why her roaming is characterization rather than
contradiction: all night she hauls herself between the base and the lamp room,
checking on the one thing here she cannot fix.

She tells you where the key is and where the oil is, once, properly — and after
that she tells you again, shorter, as often as you ask, because she has answered
worse questions than yours.

**Her one job, structurally:** she is the hint system, and she is a roaming actor,
and those two facts are in tension on purpose. She is not always where you left
her. A player who wants the briefing may have to go and find her, which is the
cheapest possible lesson that an actor with a schedule is a different animal from
a signpost.

**Her prose knows she moves.** She occupies two rooms, one below the other, and
every line about her is written to be true in both: the standing line describes
her rather than her surroundings, and the arrival and departure lines name the
stairs without naming a direction. Her briefing knows it too — it says where the
key and the oil *are*, never where she is standing or what the player is already
carrying, so it stays true at the top of the tower with the key in your pocket.
(Settled — see [Open questions](#open-questions).)

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

The Lamp Room's darkness is not decoration. It is the reason the oil lamp has to
be lit and carried rather than merely fetched, and it is why the fuse on the lamp
is a threat rather than a light show.

---

## The two clocks

This game runs two timers at once and they measure different things. A player
conflates them, and that confusion is the intended texture.

**The tide** is a daemon. It ticks at the end of every turn from the first one,
wherever the player is standing, and it never stops. It only *speaks* on the
jetty:

| Turn on the jetty | What the sea does |
|---|---|
| 1 | *Cold water sluices between the planks of the jetty.* |
| 2 | The same line again. |
| 3 | *The sea is at your ankles, filling the spaces between the planks without hurry. It has never once needed to hurry.* |
| 4 | It closes over you. |

So the real deadline is **three turns to get off the jetty**, and it is spent
before the player has understood that it was running. There is no deadline on the
win — a player who reaches the base has the rest of the evening. That is a
deliberate shape, and the tagline now keeps faith with it: *Keep the light*
promises tending, not a race. (Settled — see [Open questions](#open-questions).)

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

Both fuse lines are narration and the fuse itself is not. The lamp can be lit and
left in a room the player has walked out of, so each line checks that the flame is
somewhere it could be watched; the lamp goes out on turn nine either way.

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

The gates, in the order a player meets them:

1. **The tide gate.** Leave the jetty within three turns or drown. It is the only
   thing in the game that can kill you, and it is over before the player knows it
   started.
2. **The shelf gate.** The key is on the shelf and the shelf announces it. This is
   the tutorial gate — the one every player passes.
3. **The lock gate.** `unlock door with key`, then `open door`. Two commands, not
   one; the engine does not fold them, and a player who types only the first gets
   *The storeroom door is closed.*
4. **The container gate.** The chest is closed and the tools are in it.
5. **The light gate.** The Lamp Room is dark. Climb without a lit lamp and the
   answer is *It is pitch black. You can't see a thing.*
6. **The fuel gate.** `light beacon` with the oil can anywhere but your hands is
   refused: *The wick takes your flame and starves on it: the reservoir is dry.
   You'll want the oil can in hand before you try that.* This is the cross-bundle
   seam — a `Tower` item, gated on a host item, by a host rule. The refusal names
   the hands rather than the storeroom on purpose, because the gate is holding and
   not distance: a player standing over a can they set down needs to be told to
   pick it up.

Twenty-five points: five the moment you step into the storeroom (paid silently —
the player finds out from `SCORE`) and twenty on the beacon. The silence is
`Scoring.visit`'s documented behavior, left on display: this is the game an
author reads to learn what the plugin does, and what the plugin does is award
without a word. (Settled — see [Open questions](#open-questions).)

Pinned seed: **0**. The keeper's roaming is the only thing in the game that draws
from the random stream, and a route that expects to find her in a particular room
needs the seed to say so. `LighthouseTranscriptTests.winningPath` walks this exact
route at seed 0; `keeperBriefsOnceThenReminds` uses seed 3, because at seed 0 she
leaves the base on the very turn the player arrives; and the walk that asks her
three questions in a row uses seed 22, because three questions need three turns
of her staying put.

---

## Copy

Draft prose. This is the layer a writer should expect to replace wholesale — but
the voice note below is meant to survive any rewrite.

**Voice.** The narrator is plain, sea-literate, and dry. It treats the sea as a
colleague of long standing rather than a menace; it reports, and it never tells
you to be worried — the facts are expected to manage that on their own. Short
declaratives, sea nouns, no adverbs. The keeper talks the same way, weathered
shorter. And the subject — forty years of tending — enters through objects,
never statements: the worn spot on the shelf, the twice-mended clasp, the
hollowed treads, brass bright only in the grip-places. The history lives in the
nouns the entities already own; the copy may not add an entity to carry it.

That last clause is about *features*, not vocabulary. A noun a room prints must be
answerable, so a rewrite that names a new thing owes the game an item for it — see
[The scenery](#the-scenery).

### Opening

> The keeper's boat brought you out on the last of the ebb, and the sea has been
> turning since. Above the jetty the lighthouse stands dark. "A dark light is how
> ships are lost," she said on the crossing — flat, the way you would say the
> stove had gone out. Then she handed you the mooring line.

> **The Lighthouse**
> Keep the light.

### Rooms

**Jetty** — the body of the description is constant and the last sentence reads
the tide:

> A short timber jetty on stone footings runs out from the foot of the lighthouse
> to the mooring where the keeper's boat rides.
>
> — at stage 0: *The tide is low, the planks dry underfoot.*
> — at stages 1–2: *Water is beginning to lap over the far planks.*
> — at stage 3 and after: *The sea stands over the planks now, and it is not
> going back.*

**Base of the Lighthouse** — *The round stone room at the foot of the tower. A
shelf is set into the wall at hand height, worn smooth at one spot about the size
of a key. The stairs climb into the dark above, each tread hollowed at the
center, and a stout door leads east to the storeroom. The jetty is back to the
south.*

**Storeroom** — *Tar, brine, and forty years of things put where they go. Coiled
rope hangs on pegs by size, and the sea chest sits against the far wall. The only
door is back to the west.*

**Lamp Room** — *Glass on every side, and the night pressed up against all of it.
The great beacon squats cold at the center on its iron carriage. Stairs spiral
back down.* (Unlit: *It is pitch black. You can't see a thing.*)

### Things

- **stone shelf** — *A slab set into the wall at hand height, and one spot on it
  is polished where forty years of hands have put the same key down.* It carries
  no listing line of its own; the engine's own surface listing — *On the stone
  shelf is a brass key.* — is the announcement, and it stops when the key does.
- **brass key** — *A stubby brass key, green at the teeth.*
- **storeroom door** — *Stout, salt-swollen, and hung to open inward, which is how
  you hang a door on a rock.*
- **heavy chest** — *A brine-swollen sea chest, its clasp mended twice with
  copper wire — both times by somebody who meant it to last.* It will not be
  carried: *Brine-swollen, full of oil, and going nowhere. Take what's in it.*
  Being a fixture, it has no floor listing either — the storeroom's own
  description says where it sits, and saying so twice was the shelf's old bug.
- **oil lamp** — *A dented brass lamp, its wick trimmed square — the keeper's
  trim. It sloshes; there is oil in it yet. A wick kept like this burns from the
  top every time it is lit: snuff it and strike it fresh, and it gives you the
  same stretch of light again.*
- **oil can** — *A tin can heavy with lamp oil, its handle worn bright.*
- **beacon**, dark — *The great beacon, cold and dark, its reservoir dry. The
  brass is bright where hands go and dull where they don't — polished by work,
  not for visitors.*
- **beacon**, lit — *The beacon roars with light, its beam wheeling out across the
  black water.* Reachable: the winning rule sets `isLit` before it ends the game,
  so a save taken on the final move restores a lighthouse that is lit.

### The scenery

Nobody has to touch any of these. They exist because the rooms name them, and a
room that names a thing the parser does not know reads like a bug. They live in
the `Fixtures` bundle, and — for the Lamp Room — in `Tower`.

- **sea** (`water`, `tide`, `waves`, `ebb`) — *Coming in, the way
  it comes in twice a day whether or not anybody is standing here to watch. It has
  had this jetty before and given it back.*
- **timber jetty** (`planks`, `boards`, `footings`) — *Timber on stone
  footings, and the timber is the part that gets replaced. The planks are laid a
  finger apart so the sea can come up between them instead of lifting the lot.*
- **keeper's boat** (`mooring`, `dinghy`) — *An open boat, rowed out and
  rowed back for forty years, with the mooring line made fast in a hitch you could
  undo one-handed in the dark. She has had to.*
- **lighthouse** (`tower`), from the jetty — *Stone, tapered, whitewashed to the
  gallery rail, and dark at the top where it has no business being dark. From out
  on the water it is the first thing anyone looks for.*
- **stone wall** (`stone`, `walls`, and `tower`/`lighthouse` from inside — the
  view from within a lighthouse is its wall) — *Blocks the length of your forearm, laid in a circle thick enough that
  the weather out there is a rumor in here.*
- **stone stairs** (`treads`, `rail`, `steps`, `staircase`) — *They climb into the
  dark and go on climbing. Every tread is hollowed at the center, and the rail is
  bright along its whole length where a hand has gone.*
- **coiled rope** (`coils`, `pegs`) — *Hung on pegs by size, largest to the left.
  Somebody put them in that order and everybody since has kept them in it.*
- **stores** (`tar`, `brine`, `gear`, `supplies`) — *Tar and brine and forty years
  of things put where they go. Nobody on this rock has had to look for anything in
  a long while.*
- **glass** (`panes`, `windows`) — *Curved panes in a brass frame, every
  one of them clean on the inside. The salt on the outside is nobody's fault and
  nobody's to fix.*
- **night** (`sky`) — *Black, and up against the glass on every side of you.
  Somewhere out in it is water, and somewhere on the water are people who would
  like to know where this rock is.*
- **spiral stairs** (same words as the stone flight below, so the room decides
  which one you meant), in the Lamp Room — *Iron, and narrow enough
  that two people meeting on them would have to settle it between themselves.
  Hollowed at the center, the same as the stone ones below.*

The parts of things answer through the things themselves: `teeth` is the key,
`wick` is the lamp, `clasp` and `wire` are the chest, `handle` and the bare noun
`oil` are the can, and `reservoir`, `carriage` and `ring` are the beacon.

### The keeper

Examined:

> Small, weathered, and square-set. The bad leg is the newest thing about her, and
> she has already stopped mentioning it.

Standing line, printed on every look while she is in the room — it describes
her, not her surroundings, so it is true above and below:

> The old keeper is here, her weight on the good leg, listening to the sea the
> way most people listen to a room.

Arrival and departure, printed only when the player is somewhere lit and can see
it happen. Both lines name the stairs and neither names a direction, so they are
true climbing or descending:

> A slow tread on the stairs, and the keeper arrives at her own pace, the bad
> leg last.

> The keeper takes to the stairs, both hands to the rail, a step at a time.

First `TALK TO KEEPER` — the briefing, which is also the walkthrough:

> The keeper looks you over once, the way she would look over weather. "Storm
> took the light, and my leg won't take those stairs with an oil can in hand,"
> she says. "Key's on the shelf. Lamp and oil are in the chest in the storeroom.
> Get her burning. There's boats out on this water tonight, and I know every one
> of them by her bell."

Every `TALK TO KEEPER` after that:

> "Key's on the shelf, oil's in the chest," the keeper says again, patient as
> tide. "The light's waited long enough."

### The tide

> Cold water sluices between the planks of the jetty.

> The sea is at your ankles, filling the spaces between the planks without
> hurry. It has never once needed to hurry.

> The sea comes over the planks in one long push and takes you with it — without
> malice, without much noticing. High above, the tower stays dark. Forty years
> that light burned on every tide of the year. It does not burn tonight.

### The lamp

> The oil lamp's flame sinks to a sullen flicker.
> The oil lamp gutters, and goes out.

### The stub verbs this game contradicts

Four stock lines that would be false here, and only here. Everything else the
engine says for `sing` or `pray` stands.

> `pour can` / `empty can` — Not on the floor. That oil has one place to go
> tonight.

> `burn lamp` — That is what it is for. Light it.

> `burn beacon` — That is the whole idea. Light it.

> `swim` / `dive`, on the jetty — The sea is right there and it is coming to you.
> Going to meet it would only save it the trip.

### Refusal and ending

The fuel gate:

> The wick takes your flame and starves on it: the reservoir is dry. You'll want
> the oil can in hand before you try that.

The win:

> You tip the last of the oil into the reservoir and touch your lamp to the
> wick. Flame runs the ring — and the great beacon comes up roaring, its beam
> wheeling out across the black water.
>
> Far off, thin under the wind, a ship's bell answers. Then another, farther
> out. The keeper could name them both.

---

## Known defects

**The copy above is the game as it ships.** That has not always been true, and the
way to keep it true is not to keep a list here — a list would go stale the first
time an issue closed, and a stale entry is worse than none: a play-test verifier
reading it would dismiss a genuine regression as somebody else's problem. Two
files carry it instead, and neither can rot.

- [`lighthouse-playtest-2026-07-30.md`](lighthouse-playtest-2026-07-30.md) is the
  last round, dated in its own filename. It names each wrong line, the frame it
  printed in, and the cause.
- [`lighthouse-playtest-ledger.md`](lighthouse-playtest-ledger.md) is append-only:
  every finding ever filed against this game, and what became of it.

For what is open right now, ask the tracker: `gh issue list --state open --search
Lighthouse`.

The first round's findings are all closed, each with a transcript test in
`LighthouseTranscriptTests` that fails without its fix: the keeper's direction-blind
stair lines and her frame-blind briefing, the shelf that went on announcing a
pocketed key, both lamp fuses narrating a flame nobody could see, the takeable
chest, the two dozen unanswerable nouns, the three untrue stub lines, the fuel gate
that sent you downstairs for a can at your feet, and the beacon's unreachable lit
branch.

---

## Open questions

1. **How hard should the keeper press?** Her briefing and reminder carry no
   deadline, deliberately — the game doesn't run one. But a keeper this steeped
   in the work might reasonably harry a stranger while her light is dark. If she
   reads too calm at the keyboard, the pressure goes into her diction — the
   reminder losing words, never gaining a clock.
2. **Should the game re-skin any stock text for register?** It re-skins none.
   Four stub verbs are promoted per-entity because their stock lines are *untrue*
   here; the rest of the ~47 answer in the engine's voice, which is a lighthouse
   keeper's rock speaking as a parser. That is a register mismatch and not a
   falsehood, and fixing it would mean a `text: GameText` block and a contract row
   of its own — a different demonstration from the one this game makes.

### Settled

- **The subject: keeping the light.** Forty years of tending, passing through a
  stranger's hands for one night. It enters through objects (the worn spot, the
  mended clasp, the hollowed treads, the grip-bright brass), is planted in the
  briefing's last line, and is paid off by the answering bells. The boats stay
  unnamed — "I know every one of them" is a bigger claim than any name.
- **The tagline.** *Keep the light.* The tide stays exactly as built — lethal on
  the jetty, inert everywhere else — and the copy stops promising a race. The
  game's real shape, a sharp scare and then unhurried work, is the subject's
  shape: tending is not a sprint.
- **The keeper's leg vs. her roaming.** She can climb her own stairs, slowly,
  both hands to the rail; what she cannot do is climb them carrying oil, or
  kneel to the reservoir at the top. The roaming is in character: all night she
  checks on the one thing on this rock she cannot fix.
- **Her prose in two rooms.** The standing line describes her rather than her
  surroundings, and the arrival and departure lines name the stairs without
  naming a direction, so every line is true above and below. `ActorBehaviors.roams`
  takes one arrival line and one departure line for the whole room set and offers
  no per-room seam, so direction-neutral is not a preference — it is the only way
  the pair can both be true.
- **The jetty's material.** Timber on stone footings. The old copy had a stone
  jetty with planks in the tide lines; the planks were always the better detail,
  so the jetty is theirs now.
- **Five silent points.** Kept, and stated in [The solution](#the-solution) as
  the plugin behaving exactly as documented — this is the game an author reads
  to learn what `Scoring.visit` does, and what it does is award without a word.
- **The lamp banks nothing.** Carried in the lamp's own copy: a square-trimmed
  wick burns from the top every lighting, so relighting buys the same stretch of
  light again. The mechanic and the fiction now say the same thing.
- **The shelf announces nothing of its own.** A listing line runs until its own
  item is touched, and nothing ever touches a shelf — so a `firstSight` there
  doubled the engine's surface listing on the first visit and outlived the key on
  every one after. The engine's line is the whole announcement now.
- **The fuel gate names your hands.** The predicate is *the can is held*, and the
  refusal says so. Widening it to accept a can lying on the floor was the other
  way out; naming the hands keeps the gate a one-line `require` an author can read
  at a glance, which is what this rule is in the game to be.
- **The beacon is lit before the game ends.** One line, set ahead of `end(won:)`.
  It does not make the lit `describe` branch reachable by an examine — the game is
  over — but it makes the branch honest, and a save taken on the winning move now
  restores a lighthouse that is burning.
- **A second bundle, for the scenery.** `Fixtures` exists so that answering every
  printed noun does not double the length of the file an author reads to learn the
  idioms. See the note under [Mechanics contract](#mechanics-contract).
