# The Kindly Deep — design document

A demonstration game for the Gnusto engine. A fall of rock, two clocks that run
down, and a mule who has to be somewhere.

This document is the story-and-copy source of truth. It is iterated on separately
from the code, by a writer rather than an implementer. **Read [Mechanics
contract](#mechanics-contract) before changing anything** — this game exists to
prove one substrate works, and the story is the vehicle, not the cargo.

Tracking issue: [#126](https://github.com/heirloomlogic/gnusto/issues/126).

> **This file arrived after the game did.** KindlyDeep shipped in `0b78ad8` with no
> design doc, was play-tested on 2026-08-02, and came back with 64 findings. So the
> [Copy](#copy) section below was written **prescriptively**: where the shipped line
> was wrong it is quoted as *shipped* and the corrected line is written out beside
> it.
>
> **Those corrections have now been applied.** The whole of #126 landed on
> 2026-08-03, so the "shipped" column below is a record of what the game *used to*
> say, kept because a fixer reading this next round needs to know which lines were
> deliberately changed and why. See [Known defects](#known-defects) for what that
> means for the next round.

---

## Contents

- [What this game is for](#what-this-game-is-for)
- [Mechanics contract](#mechanics-contract)
- [Premise](#premise)
- [The player](#the-player)
- [Biscuit](#biscuit)
- [Map](#map)
- [The two clocks](#the-two-clocks)
- [The solution](#the-solution)
- [Copy](#copy)
- [Content scope](#content-scope)
- [Known defects](#known-defects)
- [Open questions](#open-questions)

---

## What this game is for

The engine ships four worked examples and they are not interchangeable.
`CloakOfDarkness` is the minimal acceptance benchmark. `Lighthouse` is the
shortest complete read — one idiom, one entity, one demonstration. `Gramarye`
proves `GnustoSpellcasting` hosts four casting paradigms rather than one game's.
`Zork1` is the full reconstruction.

The Kindly Deep is the **survival-and-companion** proof, and it makes one claim:
that the engine can run a game whose entire subject is *state the prose has to
check*. Two failing clocks that end in death unless relieved. One companion whose
whole dramatic function is to be somewhere — following, parked where a route
excludes him, rejoining through a barrier. Nothing here is a set piece. Every
mechanic in this game is a number or a location that some sentence has to read
before it opens its mouth.

That is the design rule, and it is stricter than it sounds: **no line in this game
may assert a fact it did not check.** A room that describes a beam lying across a
gate has to know whether the beam is still there. A death that says hooves are
coming near has to know whether the mule can reach you. A pitch-black line that
puts him nearby has to know he is not two rooms away behind a crawl he cannot use.

The 2026-08-02 round is worth reading as a comment on that rule rather than as a
list of bugs. Twenty-five of its sixty-four findings were `prose-untrue-of-state`,
and ten of those were one predicate — *where is the mule* — going unasked. The game
failed at precisely the thing it exists to demonstrate. That is a useful failure and
this document exists to make it non-repeatable: the invariant is now a contract row,
not a habit.

The one thing that rule does not cover is scenery, and scenery is not an exception
to it — it is the price of the prose. Every noun a room prints has to be a noun the
parser knows, or the room reads as unfinished. This game printed about sixty it
didn't. See [The nouns the mine prints](#the-nouns-the-mine-prints).

---

## Mechanics contract

The middle column is how the story *currently* carries each mechanic. The right
column is what has to remain true no matter how the story is rewritten.

| Mechanic | How the story carries it | Must survive rewriting |
|---|---|---|
| Failing clock | Thirst and fatigue: a counter, three warnings, and a fuse the last warning arms. | **Two** clocks, one mechanic, different numbers and different prose — the same code parameterized twice. One clock proves nothing about a substrate. |
| Clock numbers | Thirst warns at 12/20/28; fatigue at 16/26/36; grace 8, so the deaths land on turns 36 and 44. | The two ladders stay **offset**, so a player never meets both crises at once, and thirst always bites first. The grace stays long enough to cross the map. |
| Relief resets both halves | `drink` zeroes `thirst` *and* `stopFuse("dehydration")`; `rest` does the same for fatigue. | Relieving a condition must stop the armed fuse, not merely reset the counter. A reset that leaves the fuse running is a death the player earned their way out of. |
| Companion actor | Biscuit, following by daemon, parked by the crawl, rejoined through the air-door. | **One** companion. Follow → park → rejoin is the whole cycle and the reason this game exists. |
| **Every line about the companion reads his location** | Ten sites did not, until #126 closed. | **No sentence asserts where he is without asking.** This is the central invariant. It is not a stylistic preference; it is the thing the demo demonstrates. |
| Consumable resource | Three swallows in the canteen, and no other water in the workings. | **Three**, and no second source. Sharing one with the mule costs a swallow and does **not** reset thirst — a generosity that costs nothing is not a beat. |
| Two-sided barrier | The air-door: a wall from the Forks, a liftable bar from the shaft. | One barrier whose description reads which side you are standing on, refuses from the bad side, and reunites the companion from the good one. |
| Scoring | Five awards of five: `lamp`, `canteen`, `door`, `beam`, `bell`. `maxScore` 25, declared in the `Scoring` award table. | Five awards, five points each, total checked against `maxScore` at bootstrap. **`door` and `beam` are the mule's** — see below. |
| Two endings | Both come up (25). You come up alone (15). | The game does **not** refuse abandonment. It permits it and tells the truth about it. |
| No unwinnable state, by any route | The lamp cannot be dropped; closing the air-door cannot seal the game, because the crawl runs both ways. | **The game cannot be made unwinnable.** Not by a dropped light, not by a closed door, not by any order of operations. |
| Two plugins, two wirings | `GnustoScoring` is stateful and goes in `content`; `GnustoActors` is logic-only and splices into `timers`. | **Both** kinds, wired the two different ways. |
| Custom verbs | Nine intents — `drink`, `rest`, `give`, `talk`, `ring`, `pull`, `sit`, `pet`, `harness` — each with the phrasings a player might actually reach for. | A verb a player cannot guess is a verb the game does not have. The haul answers to seven words because nobody who has not driven a mule knows which one is right. |
| Every printed noun answerable | The words the rooms say are *present* all answer; a `Fixtures` bundle holds the seventeen with nothing else to hang on. | A named thing the parser doesn't know reads as a bug. |

**Free to change:** every name, all prose, the room descriptions, the mule's name
and character, the tone, the title, the tagline, and the setting.

**Not free to change without revisiting the implementation plan:** everything in the
right-hand column — and specifically the two offset ladders, the five awards of five,
the three swallows, the two endings, and the companion invariant.

**The `door` and `beam` awards are the mule's, and that is load-bearing.**
`airDoor.before(.open)` refuses from the Forks side, so the only way to score `door`
is to lift the bar at the Shaft Bottom — which is also the line that moves Biscuit to
you and restarts his daemon. Reuniting with him and scoring those five points are the
same act. Gate the haul on his presence and `beam` joins it. Which means the two
endings need **no new register and no change to `maxScore`**:

| Route | lamp | canteen | door | beam | bell | Total |
|---|---|---|---|---|---|---|
| Both come up | 5 | 5 | 5 | 5 | 5 | **25** |
| You come up alone | 5 | 5 | — | — | 5 | **15** |

The ten points the bleak ending forfeits are exactly the two awards the mule earns.
A rewrite that adds a sixth award, or that pays for the bell twice, breaks this and
the bootstrap will say so.

---

## Premise

A roof came down between a man and the way out, and left him the company of a mule.

The fall took the main entry, the water, and the dinner bucket, and it took them an
hour ago — long enough that the arithmetic is finished and the sitting still has
stopped being useful. The men above have marked these workings lost and will timber
their way in from the far side, which is measured in days. The man has a cap-lamp
that went out when he did, a flint striker on his belt where it always is, and no
water at all.

He also has Biscuit, who has been hauling for him for two years, who knows these
roads in the dark better than he knows them in the light, and who is standing
somewhere close in the pitch black, breathing, and waiting to hear what the two of
them do next.

There is a hoisting shaft at the far end of the workings, and a signal bell at the
bottom of it, and one ring travels four hundred feet to an engineer who is
allegedly awake. Everything between here and there is the game.

---

## The player

A mine driver, two years on this section, and characterized almost entirely by
competence. He knows the gauge of the rails by walking them. He counts his
swallows. He does not sleep beside an open flame, and he does not put his striker
down, because those are not preferences — they are the two rules that keep a man
alive underground and he has never once been tempted to test either.

That competence is the reason the game can be quiet. Nobody has to be told the
situation is bad; the player character has already done the arithmetic in the intro
and the narration simply proceeds from it. There is no panic in this prose and there
should not be. `X ME` gets the engine's stock answer, and that is the correct amount
of characterization for a man whose interiority is expressed by knowing where things
go.

What he does *not* have is any way to shift twelve feet of poplar, and that is the
whole shape of the game: the one thing standing between him and the cage is the one
thing he cannot do alone.

---

## Biscuit

A mine mule, no particular color under the dust, built close to the ground and wide
through the chest. Two years of hauling for this driver. He has spent his working
life around falling rock and formed no opinion of it.

He is the game's only actor and its entire social surface, and he is written from
the outside. The narration never tells you what he thinks; it tells you what a driver
who has watched him for two years reads off him — ears forward, head low, feet
planted, the expression of an animal who was about to mention it. That distinction is
the voice and it should survive any rewrite. He is not a talking animal and he is not
a symbol. He is a colleague who cannot speak.

**Structurally, his job is to be somewhere.** He follows you room to room by daemon.
The crawl is a gap a mule cannot use, so entering it parks him. The air-door is
racked in its frame and opens only from the shaft side, so lifting that bar is what
brings him back. Follow, park, rejoin — and every one of those states is a fact the
prose has to read before it says anything about him.

**The rule for his prose, stated once so it can be enforced:**

> Every sentence that mentions Biscuit is either true wherever he is, or is guarded
> by a check that he is here. There is no third option, and "he is usually here" is
> not a check.

That rule is why the drink scene already branches on `biscuit.isIn(player.location)`
and prints his supervision only when he is supervising. It is the pattern; ten other
sites need it. See [Companion-aware copy](#companion-aware-copy).

He blocks the way north into the old works, and this is characterization rather than
a puzzle: he has walked past bad air before and can smell what you cannot. It is also
the only time in the game he refuses you anything.

**He must be declared `properName`.** He is called Biscuit; without the trait the
engine's stock lines say "the Biscuit", and the bootstrap has been emitting a warning
that says so on every launch since the game shipped.

---

## Map

Seven rooms. Six of them are one move apart; the seventh kills you.

```
                        The Old Works          ← reachable only when he is not
                              │ north            with you. Bad air. Lethal.
                              │
  The Stable ─ east ─ The Fresh Fall ─ east ─ The Forks
                              │                   │ east
                       south │ down               │
                              │             The Low Crawl ─ east ─┐
                     The Shelter Hole              ╵ down         │
                                                   └──────────── The Shaft Bottom
                                                                  ╵
                                      The Forks ══ air-door ══════╯
                                                  (westbound only)
```

| Room | Notes |
|---|---|
| **The Fresh Fall** | Start. North is the fall itself — a flat authored refusal, not a door. The shelter hole is both `south` and `down`, because the prose calls it "a step down". |
| **The Stable** | Biscuit's own room, and the only place with water in it — a trough that is dry. The corn bin holds the canteen. |
| **The Shelter Hole** | The only place `rest` works. Straw, a bench, a dry floor. |
| **The Forks** | The junction. North to the old works, barred by the mule. The air-door east in its frame. The crawl at floor level beside it. |
| **The Low Crawl** | Hands and knees. Biscuit cannot enter, and entering parks him **wherever he currently is** — which is the hinge the whole endgame turns on. |
| **The Shaft Bottom** | The goal. The shaft, the cage gate, the beam across it, the bell, the haul tack on its peg, and the air-door's good side. |
| **The Old Works** | Bad air. Entering is fatal and there is no warning past the one the mule gives you with his body. |

**The air-door swings one way, and that is deliberate.** The frame is racked, so it
will never be pushed open from the Forks side; the bar is on the shaft side, and a
bar is a thing that lifts. Once lifted, the door is a westbound route — shaft to
Forks — for the player, and the way the mule comes to you. The player's route *east*
is the crawl, in every state of the door. This is coherent and should not be
"fixed" into a two-way passage: a door that only swings one way is a real thing, and
the asymmetry is what makes the crawl matter after the reunion.

**One map change this document introduced,** and the game now has it: the Low Crawl
has a mouth at the Shaft Bottom end (`shaftBottom.down(lowCrawl)`). The Shaft Bottom
used to declare exactly one exit, so the crawl could never be re-entered from the east
and the Low Crawl's own "the crawl runs east and west" was true only westbound. It
does three things at once: it makes that sentence honest, it makes the crawl a genuine
two-way route so no closed door can strand the player, and it is what makes the Old
Works reachable — see below.

**How the Old Works became reachable.** `lowCrawl.onEnter` stops the follow daemon,
parking Biscuit *wherever he is standing*. Enter the crawl from the Forks and he is
parked at the Forks, which is why north stays shut. Enter it from the **Shaft
Bottom** and he is parked at the Shaft Bottom — so you come up out of the crawl into
the Forks alone, `!biscuit.isIn(forks)` is finally true, and the north heading is
open. The gas death stops being dead code and becomes what it was always written to
be: the price of having left him behind. Its last line — *"The mule would have
stopped you; the mule was not there to."* — is true for the first time.

---

## The two clocks

Two timers, one mechanic, deliberately offset so the player never meets both crises
in the same turn. Thirst always bites first.

**Thirst.** Ticks every turn from turn one. Reset by `drink`, which also stops the
armed fuse. Three swallows exist and no more.

| Turn | What it says |
|---|---|
| 12 | *Your mouth has gone tacky and your tongue keeps finding the roof of it.* |
| 20 | *Thirst has stopped being an opinion and started being a fact.* |
| 28 | *Your lips have split…* — and this one arms the fuse. |
| **36** | Death. |

**Fatigue.** Same shape, different numbers. Reset only by `rest`, and only on the
straw in the Shelter Hole.

| Turn | What it says |
|---|---|
| 16 | *A yawn ambushes you mid-step.* |
| 26 | *Your eyelids have taken on weight.* |
| 36 | *You are walking asleep, in the technical sense…* — arms the fuse. |
| **44** | Death. |

The grace is **8 turns** in both cases, which is the number that matters most: it is
long enough to cross the map from anywhere to the relief, and short enough that the
player has to move. A rewrite may change the ladders; it may not close that gap.

`rest` costs you the lamp — nobody sleeps beside an open flame — so you wake in
absolute dark and need the striker again. That is not a punishment, it is the reason
the lamp is a recurring decision rather than a switch you flip once.

---

## The solution

Two routes, and both are endings.

### Both come up — 25 points, 11 turns

```
light lamp          — beat 1: the striker, and the first sight of him   (score: lamp)
west                — the stable
wait                — beat 2: he noses the canteen out of the corn bin  (score: canteen)
take canteen
east                — back to the fresh fall
east                — the forks
east                — the crawl; he cannot follow, and parks here
east                — the shaft bottom, alone
open air-door       — the bar lifts; he comes through                   (score: door)
harness biscuit     — beat 5: he hauls the beam off the gate            (score: beam)
ring bell           — the cage                                          (score: bell)
```

Verified at seed 0 against the shipped binary: *Your score is 25 of a possible 25,
in 11 turns.*

The gates, in the order a player meets them:

1. **The dark gate.** Every room is dark and the lamp is the only light. This is the
   first move of the game and the striker scene is its reward.
2. **The water gate.** Three swallows exist. Finding them is beat 2 — the mule's, by
   design, but the corn bin gives them up to anyone who takes the room's own prose
   at its word and looks under the loose board. The only water in the workings must
   not depend on the player happening to linger.
3. **The crawl gate.** A gap a man can use and a mule cannot. It is not an obstacle;
   it is a separation, and the game's whole second half is about undoing it.
4. **The bar gate.** The door opens from one side only. Reaching that side means
   going through the crawl, which means leaving him.
5. **The haul gate.** Twelve feet of poplar you cannot shift and he can.

### You come up alone — 15 points

```
light lamp
west
search corn bin     — the canteen, the hard way                         (score: canteen)
take canteen
east
east
east                — the crawl; he parks at the forks
east                — the shaft bottom
ring bell           — and you ring it anyway                            (score: bell)
```

The route reaches the Shaft Bottom alone and holding 10 points; `x biscuit` there
answers *You can't see any such thing.*

**This is a legal ending and not a failure state.** The game does not refuse it, does
not scold, and does not make it hard — it simply tells the truth about what you did
and pays you ten points less. That is the design: the tagline is a promise the player
can decline, and a game that made abandonment impossible would be making the choice
on their behalf.

The mechanism is the beam. Ringing with twelve feet of poplar still across the gate
is not the good ending, and the cager above has to deal with a barred gate and a
driver who came up on his own. See [The two endings](#the-two-endings).

**No pinned seed.** This game draws no randomness — the follow-arrival lines cycle on
the turn counter rather than on the random stream — so no test here is seeded and no
route depends on one.

---

## Copy

Draft prose. This is the layer a writer should expect to replace wholesale — but the
voice note below is meant to survive any rewrite, and **the corrected lines in this
section are the specification, not a suggestion.**

Where a line is known to be wrong, it appears as:

> **Shipped:** the line as the game prints it today.
> **Corrected:** what it should say, and what it has to read to say it.

**Voice.** Plain, dry, and trade-literate. The mine is a workplace, not a haunted
house — the narrator knows what a singletree is, what a trip is, and why you keep a
striker on your belt, and it never stops to explain any of it. Short declaratives.
Understatement doing the work that adjectives would do in a worse game. The humor is
dry and comes from competence meeting absurdity, never from the character being
foolish. And the mule is read, never voiced: what he is thinking is always reported
as what a driver sees him do.

The subject is the second rule: **the game is about the fact that neither of them
gets out alone.** It enters through work — the collar sized for a mule who has worn
it daily for years, the two years of walking the rails together in the dark, the
debts you pay when you can — and it is paid off, or refused, at the bell.

### Opening

> The roof gave no more warning than a handful of dust, and then the world came down
> behind you with a sound you felt in your teeth. That was... some time ago. You came
> back to yourself in the perfect dark, and you have been sitting in it since, doing
> the arithmetic: the fall is between you and the main entry; your cap-lamp went out
> when you did; your water went under the rock with your dinner bucket; and the shift
> above will have marked these workings lost until the men can timber their way in,
> which is measured in days, not hours.
>
> Somewhere close, something large shifts its weight and breathes — patient,
> unbothered, smelling of hay. It would be a strange sort of comfort to anyone who
> had not spent two years leading Biscuit along these entries. To you it is just the
> mule, waiting to hear what the two of you do next.
>
> There is a flint striker on your belt, where it always is. Down here you learn:
> first the lamp, then the plan.

> **The Kindly Deep**
> Two went down; two come up.

### Rooms

**The Fresh Fall** — as shipped, and correct.

> The entry ends, abruptly, in a wall of fallen rock and splintered timber — the whole
> roof of the main entry, brought down and settled in to stay. Rails run under the
> rubble and do not come out. The stable lies west, the shelter hole is a step down to
> the south, and the entry runs east toward the forks.

**The Stable** — as shipped, and correct.

> Whitewashed walls, worn brick underfoot, and the deep sweet smell of hay: the
> underground stable, kept cleaner than most kitchens because the stable boss holds
> strong views. Biscuit's stall stands open, his name chalked over it in a careful
> hand, and the water trough beside it stands dry. The entry back east is clear.

**The Shelter Hole** — as shipped, and correct.

> A timbered shelter hole cut into the rib, where a man steps in when the trip runs: a
> bench, a dry floor, and — luxury of luxuries — a heap of clean straw somebody's
> conscience left here. It is the driest, safest corner these workings have to offer,
> which is to say it is dry and mostly safe. The entry is back up to the north.

**The Low Crawl** — as shipped, and correct.

> Rock above, rock below, rock pressing in from both sides, and you between on your
> hands and knees with the lamp throwing your own shadow into your eyes. The crawl
> runs east and west, and it is no place to stop and think — thinking is better done
> where there is room to stand up and pace.

**The Forks** — needs a `describe { }` keyed on `airDoor.isOpen`. Per CLAUDE.md the
static `description(…)` is **deleted**; declaring both is a fatal `BootstrapError`.

> **Shipped** (prints in both states, and names the wrong compass direction):
> *The entry forks here at the mouth of the old works. North, the old heading runs off
> into a silence that smells faintly, sweetly wrong. East, the air-door stands in its
> frame — and past it, the shaft — but the fall has racked the frame and jammed it
> fast on this side. Beside it, at floor level, the rock left a low dark gap along the
> edge of the fall: a crawl, for anyone honest about their size.*

Two things are wrong. The door is described as shut after it has been opened and
walked through — `x air-door` says the opposite one turn later — and "East" is
assigned to the door when `east` has always been the crawl.

> **Corrected, door shut:**
> *The entry forks here at the mouth of the old works. North, the old heading runs off
> into a silence that smells faintly, sweetly wrong. The air-door stands in its frame
> at the far side, and past it the shaft — but the fall racked the frame and jammed it
> fast from this side, and it is not going to be argued with. Beside it, at floor
> level, the rock left a low dark gap along the edge of the fall: a crawl, running
> east, for anyone honest about their size.*

> **Corrected, door open:**
> *The entry forks here at the mouth of the old works. North, the old heading runs off
> into a silence that smells faintly, sweetly wrong. The air-door stands open at the
> far side, swung back on its racked hinges the only way it will go, and the
> ventilation moves through it the way it was built to. It will not take you east —
> it opens toward you and always will. The crawl still runs east at floor level, and
> it is still the only way a man gets to the shaft.*

**The Shaft Bottom** — needs a `describe { }` keyed on `beamHauled`, and gains the
crawl mouth in both branches.

> **Shipped** (prints the beam across the gate forever, and never names the crawl the
> player just came out of):
> *And here it is: the shaft bottom, the one door out of the world below. The hoisting
> shaft rises out of sight, breathing cold top-side air down on you. The cage gate
> stands in its frame — with a twelve-foot beam lying square across it, delivered by
> the same event that delivered everything else today. On the wall, the signal bell
> and its rope; on a peg, the haul tack, collar and chains kept where the work is. The
> air-door is in the west wall, and its bar is on this side.*

> **Corrected, beam still across:**
> *And here it is: the shaft bottom, the one door out of the world below. The hoisting
> shaft rises out of sight, breathing cold top-side air down on you. The cage gate
> stands in its frame — with a twelve-foot beam lying square across it, delivered by
> the same event that delivered everything else today. On the wall, the signal bell
> and its rope; on a peg, the haul tack, collar and chains kept where the work is. The
> air-door is in the west wall, and its bar is on this side; the crawl comes out at
> floor level beside it.*

> **Corrected, beam hauled clear:**
> *And here it is: the shaft bottom, the one door out of the world below. The hoisting
> shaft rises out of sight, breathing cold top-side air down on you. The cage gate
> stands clear in its frame, and the beam that was across it lies where it was dragged,
> off to one side and out of the argument. On the wall, the signal bell and its rope;
> on a peg, the haul tack, collar and chains back where the work is. The air-door is
> in the west wall, and its bar is on this side; the crawl comes out at floor level
> beside it.*

**The beam and the cage gate** — the room is not the only thing that forgets the haul.
Both items carry a static `description(…)` that outlives the state it describes, and
both need the same `beamHauled` branch the room gets.

> **beam, shipped** (prints one turn after the game narrated it being dragged off):
> *Twelve feet of poplar, lately part of the roof, now lying across the cage gate with
> the settled look of an object that weighs more than you do. Considerably more. You
> know someone it does not outweigh.*
> **beam, corrected once hauled:** *Twelve feet of poplar, lately part of the roof and
> lately across the gate, now lying off to one side with the settled look of an object
> that has been moved by something stronger than it is. You know someone it does not
> outweigh, and now so does it.*

> **cage gate, shipped:** *The gate the cage lands behind, sound enough and perfectly
> useless while twelve feet of poplar lies across it.*
> **cage gate, corrected once hauled:** *The gate the cage lands behind, sound enough
> and — now that there is nothing lying across it — good for exactly the one thing it
> was built for.*

**The Old Works** — no description at all today. It needs one, because it is about to
be reachable.

> **New:**
> *An old heading, worked out and abandoned, and the air in it is sweet. Nothing here
> has been touched in years: the props still stand, the floor is undisturbed, and the
> quiet is the particular quiet of a place that has stopped exchanging air with the
> rest of the world. It is, in every visible respect, the most restful room in these
> workings.*

The room should read *pleasant*. That is the point of bad air and it is why the mule
is the only one of you who can tell.

### Companion-aware copy

Ten sites assert where Biscuit is without asking. Each needs a guard on
`biscuit.isIn(player.location)` and, where the beat still has to land without him, a
second branch. The drink scene already does this correctly and is the pattern to
copy.

**The pitch-black line** — prints on every dark turn, in every room.

> **Shipped:** *Dark of the sort found only underground: complete, unhurried, and
> inches from your face. Somewhere near, hooves shift on stone. The flint striker is
> on your belt, and using it is the only good idea available.*

It is worst in the Low Crawl, where it prints in the same turn's output as the beat
saying his bray *"recedes behind you, complaining, until the stone shuts it out
altogether."*

> **Corrected, he is with you:** unchanged from shipped.
> **Corrected, he is not:** *Dark of the sort found only underground: complete,
> unhurried, and inches from your face. Nothing shifts in it and nothing breathes but
> you, which is a new development and not a welcome one. The flint striker is on your
> belt, and using it is the only good idea available.*

**The rest scene** — has him standing watch over you, and re-pinches a lamp that is
already out.

> **Shipped:** *You pinch the lamp out first — nobody sleeps next to an open flame,
> and the oil will be wanted later — and lie down in the straw… Biscuit stands over
> you in the dark, head low, doing the watching, turnabout being fair, since you have
> done his for two years.*

Two guards: the lamp clause prints only when the lamp is lit, and the watching clause
only when he is in the room.

> **Corrected, alone:** *…and lie down in the straw and let the weight of the shift
> come off your shoulders. Nobody stands over you; there is nobody down here to do it,
> and you sleep the shallow way a man sleeps when the watching is his own job too.*

**The corn-bin find, the hard way** — ends on a reaction shot from a mule three rooms
east.

> **Shipped:** *…Biscuit, when you look up, has the expression of an animal who was
> about to mention it.*
> **Corrected, alone:** *…and you sit back on your heels with it, wishing briefly and
> uselessly that there were somebody here to be smug at you about it.*

**Both deaths** — each places him at your side.

> **Thirst, shipped:** *…the last thing you hear is hooves on stone, coming near, too
> late.*
> **Corrected, alone:** *…and the last thing you hear is nothing at all, which is
> worse, and is the thing you were trying to avoid the whole time.*

> **Fatigue, shipped:** *…Something warm noses your cheek once, twice — and gets no
> answer.*
> **Corrected, alone:** *…Nothing noses your cheek. The cold does all of the
> attending, and it is thorough.*

**The haul** — this one is not a branch. `hitchOnAndHaul()` should **require his
presence**, because the scene is four sentences about his shoulders and his hooves
and there is no honest version of it performed by a man alone.

> **New refusal, he is not here:** *You look at the collar on its peg and at twelve
> feet of poplar, and the arithmetic is the same as it was: this is a two-body
> problem. He is not here. You left him on the other side of a crawl he cannot use.*

That refusal is also the game's last chance to tell the player what they have done,
which is why it names it plainly rather than hinting.

**`push` / `pull` / `take beam`** — already refuses, but the refusal locates him.

> **Shipped:** *…hauling is a trade with a professional standing eight feet away.*
> **Corrected, alone:** *…hauling is a trade, and the professional is two rooms back
> the way you came.*

### The warnings that watch a flame that isn't lit

Two rungs of the survival ladders describe the player staring into lamplight. Both
fire off a turn counter, so both are reachable in absolute dark — by doing nothing but
waiting from turn one, having never struck the striker at all.

> **Fatigue, stage 2, shipped:** *Twice now you have caught yourself standing still,
> staring at the lamp-flame, thinking nothing at all — and down here, thinking nothing
> at all is how accidents get their start.*
> **Corrected, lamp out:** *Twice now you have caught yourself standing still in the
> dark, thinking nothing at all — and down here, thinking nothing at all is how
> accidents get their start.*

> **Thirst, stage 3, shipped:** *Your lips have split, there is an ache setting up
> behind your eyes, and the lamp-flame doubles when you look at it too long.*
> **Corrected, lamp out:** *Your lips have split, and there is an ache setting up
> behind your eyes that the dark does nothing to help with.*

The guard is `capLamp.isLit`, and it is the same shape as the companion guard: a line
that describes what the player can see has to know whether they can see.

### The two endings

**Both come up** — the shipped four-paragraph ending, and it is good. It stays exactly
as it is, now guarded on `beamHauled && biscuit.isIn(shaftBottom)`.

> You take the pull and ring — one long stroke, and the sound goes up the shaft like a
> bird out of a trap. A pause, long enough to fit a whole day's fear into. Then, faint
> and far above, the answering signal: heard, coming.
>
> The cage comes down singing on its guides, and the cager steps out of it already
> talking — they had you marked for lost, the men are still two days from the far side
> of that fall, how in God's name — and stops, because Biscuit has stepped forward to
> inspect the cage in a proprietary manner.
>
> A mule cannot climb a ladderway, and the sling goes on him first — he suffers it
> with the dignity of long practice, and rises out of sight glaring like a parcel with
> opinions. The cage comes back for you. The gate rings shut, the deck lifts, and the
> dark of the workings drops away beneath your boots, already turning back into
> geography.
>
> Outside, they say, it is raining — soft, gray, spring rain. Biscuit has not stood in
> rain for four years. You find you are glad it will be the first thing he gets.

**You come up alone** — new. Reached by ringing with the beam still across the gate.
The refusal that currently blocks it becomes this instead.

> You take the pull and ring — one long stroke, and the sound goes up the shaft like a
> bird out of a trap. A pause, long enough to fit a whole day's fear into. Then, faint
> and far above, the answering signal: heard, coming.
>
> It takes them the better part of an hour to work the beam off the gate from their
> side, and they do it with three men and a chain and a good deal of shouted advice,
> all of which you listen to from four feet away with nothing useful to offer. The
> cager does not say anything about it. He has been down a long time and has seen men
> come up in worse order than this.
>
> Nobody asks about the mule until the deck lifts. Then somebody does, and you find
> that the sentence you had ready does not come out, because there is no version of it
> that is about the beam.
>
> Outside it is raining — soft, gray, spring rain, the first in a week. You stand in
> it a while. Four hundred feet down, in the dark, something large shifts its weight
> and breathes, and goes on waiting to hear what the two of you do next.

That last clause is the tagline inverted, and it is the whole reason this ending
exists. **It does not editorialize.** No line calls the player cruel, or a coward, or
tells them they should have gone back. It reports what happened and stops, and the
final image does the rest — which is the game's voice doing its job under the worst
conditions the game can arrange for it.

### The scenes that are already right

Transcribed for the record; a rewrite should keep what they do.

**Beat 1, the striker** — fires once; every relight afterwards is ordinary lamp
business.

> The flame takes on the second strike, steadies, and the dark steps back to a
> respectful distance. The first thing the light finds is a long mild face, inches from
> yours, ears forward — Biscuit, of course, dusty to the knees and entirely
> unsurprised. Whatever happens next, you will not be doing it alone.

**Beat 2, the nose-out** — waits for him to actually be in the stable, so it lands the
turn after his arrival line instead of on top of it.

> Biscuit walks straight past his own stall — past the hay, past the dry trough — and
> puts his nose under the loose board at the foot of the corn bin, lifting it with the
> ease of long practice. Underneath, where a man keeps what he means to come back for:
> a tin canteen, stoppered, and full when you shake it. He looks from it to you and
> back, in case you are slow this morning.

**Beat 3, the refusal at the old works** — repeats every time, because the mule does
not tire of the argument.

> Biscuit puts himself across the mouth of the old works like a bolted gate. Head low,
> feet planted; when you press, he leans his whole patient weight against you and
> pushes you back a step. He has walked past bad air before, and he can smell what you
> cannot. The old works stay shut, says the mule, and the mule has seniority.

**Beat 4, the crawl** — the separation.

> You get down on your hands and knees at the edge of the fall, where the rock left a
> gap a man can use if he is honest about his size. Biscuit tries to follow — one hoof,
> then a knock of his head against stone — and cannot. The bray that follows you into
> the crawl is the most reproachful sound you have ever heard from anything on four
> legs. It recedes behind you, complaining, until the stone shuts it out altogether.

**The rejoin** — the bar lifts, and so does the mood.

> The door is jammed from the far side, but from here the bar lifts like it was
> waiting for you, and the door swings wide with a groan of old hinges. Ventilation
> sighs through the opening — and so does Biscuit, arriving at a businesslike trot,
> pressing his forehead against your chest hard enough to stagger you. Apology
> accepted, apparently. Provisionally.

**Sharing the canteen** — the beat the whole resource mechanic exists for. Costs a
swallow, resets nothing.

> You cup your hand and pour, and he takes it in one long pull that empties your palm
> and then asks, politely, for the rest. It was yours, and you will feel the lack of
> it — but he has hauled all shift on hay and promises, and some debts you pay when you
> can.

### The last swallow

All three swallows print one line today, so the one that empties the canteen still
says he stopped *"while there is still something to stop for."*

> **Corrected, on the last swallow:** *You work the stopper out and drink, and this
> time there is nothing to count and no reason to stop early, so you finish it. It
> goes down cold and tastes of tin. The stopper goes back in from habit, which is the
> only reason left to do it.*

### The lines the mine currently gets wrong about itself

Small, and each one line.

| Command | Shipped | Corrected |
|---|---|---|
| `smell`, at the Forks | *You smell nothing out of the ordinary.* | *You smell it the way you have all along: a faint sweetness off the north heading, pleasant, and entirely wrong.* |
| `smell`, in the Stable | *You smell nothing out of the ordinary.* | *Hay, brick, and mule. If the rest of these workings smelled like this, nobody would ever go up.* |
| `sit` (bare), in the Shelter Hole | *There is nothing here built for sitting…* | Route bare `sit` to the bench, which already has a reply. |
| `burn straw` | *You have no way to set fire to the straw.* | *You have a striker and a lit lamp and no shortage of straw, which between them make this the single worst idea available to you down here.* |
| `stand` / `kneel`, in the Low Crawl | *You're already standing.* | *You are on your hands and knees, and the rock has strong opinions about alternatives.* |
| `search canteen` | *You find nothing of interest in the canteen.* | *There is water in it, which is the entire point of it, and no room for anything else.* |
| `pet me` | *There is nothing here that would care to be petted.* | With Biscuit in the room, route to his pet reaction; alone, *There is nothing down here that would care to be petted, including you.* |
| `give X to me` | *There is no one here to give it to but yourself.* | With Biscuit in the room, route to the give rule; alone, keep the stock line. |
| `eat biscuit` | *The Biscuit is a person, and people are not for eating.* | Fixed by `properName` plus a stub reply: *He is a colleague, and a thin one at that.* |

**Every "shipped" line in that table is the engine's, not this game's** — the game
authored none of them, it simply left the stock answer standing where the stock answer
is false. So the repair is **promotion per entity, never a wholesale `text.stubs`
re-skin**: a rule on `straw`, on the Low Crawl, on the canteen. Two traps, both in
CLAUDE.md and both easy to walk into here:

- **Use `reply` or `refuse`, not `say`.** Stage 4 uses `say`, so a rule that only
  `say`s prints *both* lines — the correction and the stock line it was meant to
  replace.
- **Overriding a stub verb is silent; overriding a core verb warns.** `smell` and
  `sit` are promoted intents in this game, so nothing will tell you if a rule is
  shadowing something it shouldn't.

Re-skinning `GameText.stubs` wholesale would fix these *and* about forty lines that are
merely in the wrong register rather than untrue. That is a different job and it is
[Open question 1](#open-questions).

### The nouns the mine prints

About sixty distinct words, 286 occurrences. They sort into three buckets, and the
third is the one worth arguing about.

**(a) Attach to an item that already exists** — synonyms and adjectives, no new
entities:

| Word | Goes on |
|---|---|
| `stopper` | canteen |
| `wick` | cap-lamp |
| `belt` | flint striker (it is where the striker rides) |
| `initials` | bench |
| `hinges`, `frame` | air-door |
| `frame` | cage gate (a different room, so no clash) |
| `bracket` | signal bell |
| `gauge` | rails |
| `prop`, `props`, `dust`, `wall` | the fall |
| `mouth` | old works |
| `ladderway` | hoisting shaft |
| `hooves`, `hoof`, `forelock`, `animal`, `beast`, `creature` | Biscuit |

**(b) Need a new scenery item** — the rooms name them and nothing answers:

| Item | Room | Answers |
|---|---|---|
| `entry` | Fresh Fall, Stable, Shelter Hole, Forks — one per room | `entry`, `entries`, `roadway` |
| `walls` | Stable | `wall`, `walls`, `whitewash`, `whitewashed`, `stable` |
| `wall` | Shaft Bottom | `wall`, `walls` |
| `floor` | Stable | `floor`, `brick`, `bricks` |
| `rib` | Shelter Hole | `rib`, `floor`, `shelter`, `hole`, `timbers` |
| `rock` | Low Crawl | `rock`, `stone`, `sides`, `wall`, `walls`, `roof`, `floor` |
| `crawl` | Low Crawl | `crawl`, `gap` — the room cannot answer its own name today |

`entry` is the single most-printed noun in the game — four room descriptions and the
intro twice — and it is unanswerable everywhere. It is the first thing to fix.

**(c) Referents, and correctly unanswerable.** A noun that names something *not in the
workings* is not scenery and does not need an item. The stable boss, the trip and its
cars, the cager, the hoisting engineer, the men timbering from the far side, the
kitchens, the dinner bucket under the rock: all of them are real in the fiction and
none of them is here. The 2026-08-02 census counted occurrences without drawing this
line, so its sixty-word list overstates the work.

The distinction is worth writing down because it is a rule a future round can apply:
**the K8 obligation is to nouns the room says are present.** A noun the prose uses to
locate the mine in a working world is doing a different job, and giving it an item to
be examined would make the game worse, not better.

---

## Content scope

The title, the world and the prose are original. The setting is a West Virginia coal
mine late in the 1800s, and the mining vocabulary — entry, rib, shelter hole, trip,
singletree, cage, ladderway — is the trade's own rather than any one work's. The
mechanics are the general survival and companion paradigms and belong to the form.

The mine is a workplace and the tone stays level. Nothing here is supernatural,
nobody is being punished, and the one cruelty available in the game is the player's
own.

---

## Known defects

**The copy transcribed above as "shipped" is the game as it ships, not as it should
read.** Many of those lines are known to be wrong; that is what the "corrected" column
is for, and a rewrite should apply it rather than faithfully preserve what is there.

The full list is deliberately not here. It would go stale the first time an issue
closed, and a stale entry is worse than none: a play-test verifier reading it would
dismiss a genuine regression as somebody else's problem. Two files carry it instead,
and neither can rot.

**As of 2026-08-03 the list is empty.** Every box in #126 is fixed, which means the
ledger's `fixed` rows are now live tripwires: a line from that round showing up again
in a transcript is a **regression**, not a new finding, and goes back at raised
severity.

- [`kindly-deep-playtest-2026-08-02.md`](kindly-deep-playtest-2026-08-02.md) is the
  first round, dated in its own filename. It names each wrong line, the frame it
  printed in, and the cause.
- [`kindly-deep-playtest-ledger.md`](kindly-deep-playtest-ledger.md) is append-only:
  every finding ever filed against this game, and what became of it.

For what is open right now, ask the tracker: `gh issue list --state open --search
KindlyDeep`.

The 2026-08-02 round ran `fix: "none"` and, because this document did not exist, the
harness clamped prose fixing off regardless — so all twenty classes went to
[#126](https://github.com/heirloomlogic/gnusto/issues/126) unfixed. **All of them
closed on 2026-08-03**, working from the corrected column above and from
[Settled](#settled) rather than from the boxes at face value: the ending is a branch
rather than a gate, the Old Works is reachable rather than cut, and the haul is gated
on the mule.

Four decisions were made during the fix that this document had not anticipated, all of
them the same rule applied to prose that did not exist when it was written:

- **The bleak ending's first paragraph branches on `beamHauled`.** The version written
  above has three men working the beam off the gate from above, which is true if you
  never hauled it — and false in the state where you hauled it and *then* left him.
  That state is reachable: haul, walk back west through the door, close it behind you,
  and take the crawl, because the shaft's `onEnter` only restarts his daemon while the
  door is open. One unconditional paragraph there would have reintroduced the exact
  defect this round existed to retire. Both branches converge on *"Nobody asks about
  the mule until the deck lifts"*, whose closing clause also branches: with the beam
  already moved, there is no version of the sentence that does not begin with the beam
  he moved for you. Score on that route is 20 — `beam` was earned and `door` was too.
- **The Old Works death describes the room first.** `onEnter` runs *before* the room
  is auto-described and this one ends the turn, so the description written above would
  never have printed. It calls `describeSurroundings()` first: the whole beat is that
  the place reads restful right up until the fourth step.
- **Three more scenery items than the noun table lists**, each forced by this round's
  own new prose rather than by the census. The Shaft Bottom's corrected paragraph names
  the crawl mouth, so the crawl mouth is an item; the Old Works has a description now,
  so its props and its air are items; and the Forks' paragraph names the fall twice
  while the fall itself lives a room west, so the Forks has its own edge of it.
- **`x frame` at the Shaft Bottom asks which.** Both the cage gate and the air-door
  answer to `frame` and the room names both, so the parser disambiguates. The noun
  table below assumed the two were never in scope together; they are, because a door
  is in scope from both sides. A disambiguation prompt is the right answer to a room
  with two framed things in it, and is not the same failure as an unknown word.

---

## Open questions

1. **How much stub register is worth buying?** Partly answered on 2026-08-03, and the
   answer was *both, in that order*. Every stub that made a false claim about the room
   is promoted per entity with `reply` — `smell` at the Forks and in the Stable,
   `listen` at the Forks, `climb` at the shaft, `stand`/`kneel` in the crawl, `burn` on
   the straw, `lookIn` on the canteen, `eat` on the mule — because those were
   falsehoods and a promotion is the only thing that removes one. Under those sits a
   ten-line `text.stubs` block for the rooms where the stock answer is merely in the
   wrong century. What is still open is whether the remaining ~35 are worth the same
   treatment, and the round's own refutations say probably not: the aggregate complaint
   is a preference, and a contract row for it would be a promise to keep forever.
2. **Does the companion surface deserve more than three beats?** `talk`, `pet` and
   `give` are the entire social mechanic, and the water-sharing beat — the best thing
   in the game — printed in *no transcript in the entire first round*, because the
   charter that owned it never ran. Before adding beats, the next round should
   actually read the ones that exist.
3. **Should the bleak ending be reachable without ever meeting him?** Today you cannot
   avoid the striker scene, so every player meets Biscuit before they can leave him. A
   version where the lamp is lit in a room he is not in would make the abandonment
   colder and the game meaner. Probably not worth it, but it has not been tried.
4. ~~**The rails are plural and the engine's stubs are not.**~~ **Answered
   2026-08-03**, and in the game's favor: the noun stayed plural and the engine learned
   to agree with it. `Sources/Gnusto/Declarations/Traits.swift` grows a `plural` trait
   beside `properName`, declared for the same reason — a trailing "s" is not a number
   ("the brass", "a glass"), so the engine asks rather than guesses. The seven stub
   lines whose verb agrees with their object (`eat`, `smash`, `pull`, `turn`, `untie`,
   `give`, `somebodyElse`) now take a `GameText.Noun`, which is the rendered phrase
   plus its number, and conjugate for themselves. `eat rails` reads *"The rails are not
   food."*, and the trait reaches the indefinite article too, since English has no
   plural form of its own: a plural thing lying in a room lists as *"some"*.

### Settled

- **The endings branch; abandonment is permitted.** Making it impossible would put
  the choice in the author's hands instead of the player's, and the game's whole
  subject is that neither of them gets out alone — a claim worth nothing if the game
  enforces it. The bleak ending forfeits exactly the two awards the mule earns, so
  `maxScore` and the bootstrap check are untouched.
- **The bleak ending does not editorialize.** It reports and stops. The inverted
  tagline in its last line is the entire comment, and adding a second one would tell
  the player how to feel about a choice the game just spent eleven turns letting them
  make.
- **The Old Works becomes reachable, and the gas death goes live.** It is dead content
  today — no description, unreachable in 237 probes, an `onEnter` death that cannot
  fire. Reaching it costs one map line (`shaftBottom.down(lowCrawl)`), because entering
  the crawl from the east parks Biscuit at the shaft and drops you into the Forks
  alone. The death's existing last line, *"The mule would have stopped you; the mule
  was not there to,"* becomes true for the first time — and the room reads pleasant,
  because that is what bad air is like and why the mule is the only one who can tell.
- **The air-door swings one way and stays that way.** The player's route east is the
  crawl in every state. A door racked in its frame that opens toward you only is
  physically coherent, it is what the code already does, and the asymmetry is what
  keeps the crawl load-bearing after the reunion. The prose was wrong, not the map.
- **The haul requires the mule.** The scene is four sentences about his shoulders and
  his hooves; there is no honest version performed by a man alone. Gating it also
  makes `beam` the second of the two mule awards, which is what makes the score
  arithmetic on the two endings work without a new register.
- **The lamp cannot be dropped.** The striker already has this guard and the lamp's own
  doc comment claims the invariant — *"Worn on the cap, so always to hand"* — without
  enforcing it. Dropping it doused is an unwinnable game in three turns, with no death
  and no warning, which is the one thing this contract does not permit.
- **Referents are not scenery.** A noun naming something outside the workings — the
  stable boss, the trip, the cager, the engineer — needs no item. The K8 obligation is
  to nouns the room says are *present*.
- **Biscuit is `properName`.** He is called Biscuit. The bootstrap has said so on
  every launch since the game shipped.
