# Gramarye — design document

A demonstration game for the Gnusto engine. An apprentice is left alone in his
master's tower for one morning. A draught closes a door. Everything after that is
his fault only in the narrowest sense.

This document is the story-and-copy source of truth. It is iterated on separately
from the code, by a writer rather than an implementer. **Read [Mechanics
contract](#mechanics-contract) before changing anything** — the game exists to
prove that the engine hosts a *general* spellcasting layer, and the story is the
vehicle, not the cargo.

Tracking issue: [#87](https://github.com/heirloomlogic/gnusto/issues/87).

---

## Contents

- [What this game is for](#what-this-game-is-for)
- [Mechanics contract](#mechanics-contract)
- [Premise](#premise)
- [The player](#the-player)
- [The master](#the-master)
- [Map](#map)
- [The one timer](#the-one-timer)
- [The solution](#the-solution)
- [The spellbook](#the-spellbook)
- [Copy](#copy)
- [Content scope](#content-scope)
- [Known defects](#known-defects)
- [Open questions](#open-questions)

---

## What this game is for

`GnustoSpellcasting` claims to host a *general* spell system rather than one
particular game's. A claim like that is only worth what it is tested against, and
one spell tests nothing: any engine can run one spell.

So Gramarye runs **four spells in four different casting paradigms** — an at-will
cantrip, a spell memorized from a book and spent in the speaking, a spell drawn
from an energy pool, and a scroll good for exactly one reading — and threads all
four onto a single chain where each one opens exactly one obstacle. Remove any of
the four and the amulet is unreachable. That is the demonstration: not that the
layer *can* express four paradigms, but that a real puzzle can depend on all of
them at once.

The second thing it demonstrates is smaller and just as deliberate. The
apprentice never learns a spell by being told one. He goes to the book looking for
the thing he thinks he needs, doesn't find it, and blunders into the thing the
player actually needs. Six reads, one per obstacle, in chain order, and the book
never reads ahead.

---

## Mechanics contract

The middle column is how the story *currently* carries each mechanic. The right
column is what has to remain true no matter how the story is rewritten.

| Mechanic | How the story carries it | Must survive rewriting |
|---|---|---|
| Cantrip — `.cantrip` | **glow**, a finding-light. Free, at-will, repeatable. | The free spell is **not** flavour: it is the only way one required object is ever found. A cantrip that only prints a sentence proves nothing. |
| Memorized — `.prepared(book:learnVia:)` | **unbar**, memorized from the master's book, spent in the speaking. | Memorizing needs the book *in hand*, and the casting consumes the preparation. Both refusals stay reachable. |
| Energy — `.energy(_:)` | **firebolt**, four out of a pool of twelve, hurled at a target. | One spell that draws on a pool, with a `rest` that refills it, and a target check that fails on the wrong noun. |
| Scroll — `.scroll(_:)` | **passwall**, inked on brittle parchment, good for one reading. | The scroll is consumed **on success only**. A refused cast leaves the parchment intact, and the game says so on the page. |
| Four paradigms, one chain | Each spell opens exactly one obstacle, in order: niche, door, wall, golem. | **Four** distinct paradigms, **one** obstacle each, in chain order. Fewer paradigms, or two spells on one obstacle, and the game stops being the proof it exists to be. |
| Custom trait | `TraitKey<Bool>.combustible` on the golem. | Targeted spells check an author-declared trait, so casting at the wrong thing is a wasted turn rather than a win. |
| Fuse that re-arms | `doorSeals`, two turns in, but only while the apprentice is in the study — otherwise it waits. | The inciting event cannot fire the player into an unwinnable state. Whatever seals the door must wait for them to be on the right side of it, with the book. |
| No unwinnable state, by any route | Nothing carries this yet; see [Known defects](#known-defects). | **The game cannot be made unwinnable, by the fuse or by the player.** Whatever closes a barrier, whether a rule, a timer or a `close` command, has to leave a way back or refuse. |
| `@Global` state | `doorSealed`, distinguishing "nothing is wrong yet" from "open again because you unbarred it". | The book's first read is gated on the *event*, not on the door's position — a boolean the door itself cannot supply. |
| `hidden` / `reveal()` | The scroll in the niche; the amulet behind the golem. | **Two** hidden things, each revealed by a different spell, so reveal is shown twice by two routes. |
| State-keyed `describe` | Study, gallery, warded door, granite wall, niche — five rules, each reading its own state. | Every solved gate is visible the next time the player looks. No room describes a barrier that is no longer there. |
| Clue ladder | Six spellbook reads, one per obstacle, never reading ahead. | The book answers the *current* obstacle and no later one. A read that hands out two spells at once collapses the game. |
| Blocked exits | `out` and `down` from the study, refused in the game's own words. | The tower cannot be left. The refusal is authored, never the stock line. |
| Scoring | Ten points on taking the amulet, and that ends the game. | `maxScore == 10`, paid by **one** award, at the win. This game is not a scoring demo and should not grow into one. |

**Free to change:** every name, all prose, the room descriptions, the master's
voice, the tone, the title, and the specific spell words.

**Not free to change without revisiting the implementation plan:** everything in the
right-hand column above.

The Scroll row is the subtle one. `passwall` refuses *before* it charges, so a cast
in the wrong room costs nothing — and the game says *the scroll survives the false
start* out loud, because a one-shot resource that might have been silently burned is
a resource no player will spend. Move that check after the cost and the game becomes
unwinnable by accident, and nothing in the tests will notice.

---

## Premise

The Circle has summoned the master, at no notice, in the way of Circles. He leaves
in a hurry, gets as far as the threshold, comes back, and asks the apprentice
whether the amulet is secret and whether it is safe — then answers the first half
himself, at volume, by announcing exactly where it hangs. Mind the tower. Nothing
ever happens here.

Two turns later the study window lets in a draught, the warded door swings to, and
the wards lock of their own accord, which is a feature the master has always been
rather proud of. The amulet is now on the far side of it. The apprentice touched
nothing, and knows perfectly well how that will sound.

The game is the hour it takes him to get through his master's own security using
his master's own book, badly.

---

## The player

An apprentice, competent enough and not yet good. He is characterized entirely by
how the narration treats him — dry, faintly exasperated, on his side — and never
by a backstory.

What matters structurally is that **he is not the master.** He does not know these
spells; he has to go and find each one at the moment he needs it. A protagonist
who already knew the four spells would turn a four-paradigm demonstration into a
four-item checklist.

---

## The master

Offstage for the whole game and present in every line of the book.

He is untidy, precise about the wrong things, and fond of his own cleverness — a
man who files a stationer's receipt as a bookmark, indexes straight from
"divination" to "drowning, avoidance of", and writes a spell for firing kilns
without ever mentioning that it also destroys golems. The book is the nearest he
comes to conversation.

He returns for one paragraph at the end, takes inventory of the wreckage, names
the window as the culprit — because of course he knew about the window — and
laughs. **That laugh is the point of the ending.** The game spends its whole
length letting the apprentice dread a reckoning, and the reckoning is a man who
finds it funny. A rewrite may change everything about him except that.

---

## Map

Three rooms in a line, with a magical gate between each pair.

```
    Study ── west (warded door) ── Long Gallery ── north (granite wall) ── Undercroft
      │
      └── out / down: refused. You were left to mind the tower.
```

| Room | Notes |
|---|---|
| **Study** | Start. The spellbook, the shadowed niche, the warded door, and the window. Two states — door open, door shut. Everything the player needs to begin is in this room, which is why the fuse waits for them to be in it. |
| **The Long Gallery** | Between the two gates. Two states — granite wall, or the mist archway that replaced it. Nothing to pick up; the room *is* the obstacle. |
| **The Undercroft** | The amulet on its hook, and the golem standing in front of it. One state, and see [Open questions](#open-questions) about that. |

Both gates are shared items on the exit in both directions, so the map has two
doors and four exits. Neither yields to an ordinary hand: `OPEN DOOR` and `OPEN
WALL` are refused in prose that points at the magic without naming the spell.

---

## The one timer

One fuse, and it is the inciting incident.

`doorSeals` is armed at bootstrap for two turns. When it fires it checks where the
apprentice is. **If he is not in the study, it re-arms for one more turn and says
nothing** — and it will keep doing that indefinitely.

That guard is load-bearing, not politeness: the book is on the study desk and the
niche is beside the study door, so an apprentice sealed into the gallery has no book,
no cantrip, no scroll and no way back. The door waits until he is on the right side
of it, however long that takes.

Everything before the slam is a prologue with nothing wrong in it, and the book
agrees: read it in those two turns and it offers a treatise on the correct storage of
newts.

---

## The solution

Ten moves, four spells, four gates.

```
take spellbook          — memorizing needs it in hand
cast glow               — the niche gives up the scroll        (the cantrip gate)
take passwall scroll
memorize unbar          — book in hand, one door per sitting
cast unbar              — the warding-marks die                (the memorized gate)
west
cast passwall           — the granite turns to mist            (the scroll gate)
north
cast firebolt at golem  — raw clay cannot abide it             (the energy gate)
take amulet             — ten points, and the master's return
```

What the annotations don't carry:

- **The cantrip gate** is the reason `glow` is not flavour. Cast anywhere else, or
  twice, and it is free, repeatable and no help.
- **The memorized gate** has three reachable refusals — casting before memorizing,
  memorizing without the book, memorizing twice — and all three are in the tests.
- **The scroll gate** refuses in two ways (wrong room, already-open wall) and the
  parchment survives both.
- **The energy gate** spends four of twelve. At any other target the firebolt washes
  off, and because the refusal aborts before the cost, the pool is untouched.

Ten points on taking the amulet, and taking it ends the game.

Pinned seed: **0**. The game makes no random draws — there is no roaming actor and
no chance roll anywhere in it — so any seed reproduces any route. The seed is
recorded for replay hygiene, so that a transcript filed against this game can be
re-run exactly, and so that a future change which *does* introduce a draw doesn't
silently invalidate every walkthrough on file.
`GramaryeTests.theFullWalkthroughRecoversTheAmulet` walks this route at seed 0.

---

## The spellbook

Six reads, in chain order, keyed on how far the player has got. This is the game's
clue system and its comic engine at once, and the rule behind it is worth stating
plainly: **the apprentice asks about the obstacle in front of him, the book
declines to help with it, and what falls out of the pages is the next spell he
needs.**

| State | He looks for | He finds |
|---|---|---|
| Before the slam | nothing; duty reading | the correct storage of newts |
| Door sealed, scroll hidden | warded doors | **glow**, "a small finding-light" |
| Scroll found, door shut | warded doors, again | **unbar**, with the small print |
| Door open, wall standing | walls of dressed granite | a stationer's receipt for one parchment |
| Wall open, golem standing | golems | **firebolt**, filed under the firing of kilns |
| Golem gone | nothing in particular | nothing. He enjoys it. |

Two constraints on any rewrite. The book must never hand out a spell for an
obstacle the player has not reached — `theSpellbookNeverReadsAhead` asserts that
the first useful read mentions `glow` and does *not* contain the words `unbar`,
`firebolt` or `pottery`. And the first state must exist: a book that starts
helping before anything is wrong tells the player the door is going to close.

---

## Copy

Draft prose. This is the layer a writer should expect to replace wholesale. The
voice is dry third-person-close, long sentences that arrive at a short one, and
the narrator is amused by the apprentice without being cruel to him.

### Opening

> The tower has been in an uproar since dawn — cloak, staff, letters, a hat he
> cannot find because he is wearing it. The Circle has summoned your master, and
> the Circle does not care to wait.
>
> At the threshold he stops, turns back, and takes you by the shoulder, fixing you
> with the look he otherwise reserves for cracked cauldrons. "The amulet," he
> says. "Is it secret? Is it safe?" He then reminds you, at some volume, that it
> hangs on its hook in the undercroft, behind the warded door — which rather
> settles the first question. Should anything happen while he is away — anything
> at all — you are to see that it remains secure.
>
> And he is gone, down the hill at a pace that does not suit his robes, leaving
> you to mind the tower on the theory that nothing ever happens here.
>
> The master's spellbook is on the desk. It knows more magic than you do, though
> in fairness, so does the door.

### Rooms, both states

**The Study**, door open (before the slam, and again after `unbar`) — *A close,
candle-warm room walled in books. The heavy door in the west wall stands open, its
warding-marks dark; beside it, the shadowed niche.*

**The Study**, door shut — *A close, candle-warm room walled in books. A heavy
door stands shut in the west wall, its frame cut with old warding-marks; beside
it, a shadowed niche.*

**The Long Gallery**, wall standing — *A cold stone gallery. The way east runs
back to the study; to the north the passage is stopped by a blank wall of dressed
granite, fitted so close a knife could not find the seams. You are, for reference,
larger than a knife.*

**The Long Gallery**, wall dispersed — *A cold stone gallery. The way east runs
back to the study. To the north, where the granite wall stood, an archway of grey
mist breathes cellar-cold air.*

**The Undercroft** — *A low vaulted cellar, the air chalky with old magic.*

### Barriers and the niche

- **warded door**, shut — *A stout door, held shut by the warding-marks cut into
  its frame. It is not locked in any sense a key could improve.*
- **warded door**, open — *The warding-marks are dark and dead. The door stands
  open on the gallery.*
- **granite wall** — *A wall of dressed granite, seamless and cold. No door, no
  crack — just stone.*
- **granite wall**, dispersed — *Where the granite stood there hangs a soft grey
  mist, cool as cellar air. You could walk through it as through a curtain.*
- **niche**, scroll hidden — *A niche cut shoulder-high into the stone beside the
  door. The shadow in it lies deeper than any candle can account for; if something
  rests there, no unaided eye will find it.*
- **niche**, scroll revealed — *The shadow has been persuaded to give up its
  secret: a rolled parchment rests in the niche.*
- **niche**, scroll taken — *An empty niche cut shoulder-high into the stone. What
  it kept, you carry now. Do try not to lose it.*
- **study window** — *The study window stands open to the morning. A pleasant
  draught comes and goes. It is the least suspicious thing in the tower.*

### The slam

> Behind you, the warded door meets its frame with a boom that rattles the
> inkwells. The warding-marks flare and settle into a steady burn: the wards lock
> of their own accord whenever the door closes — a feature the master has always
> been rather proud of. You touched nothing. There will be time to establish that
> later. The pressing matter is that the amulet is now on the far side of a sealed
> door, and your instructions were not ambiguous.

### The four castings

> Pale light seeps from your fingers, and in the niche it finds a rolled
> parchment.
>
> You speak the unbinding, correctly, on the first attempt. The warding-marks
> gutter and die, and the door drifts open.
>
> You read the scroll and it crumbles to ash — but the granite before you turns to
> a soft grey mist you can step through.
>
> Fire leaps from your hand and bursts against the golem; it slumps to rubble, and
> behind it the amulet gleams on its hook.

### The refusals that point the way

> The warding-marks hold the door fast; no amount of pulling will embarrass them
> into moving. Marks like these are made to be unmade — the master's book would
> know the word.
>
> You push; the wall declines to notice. It was built by someone who knew what
> they were doing, which puts you at a disadvantage. Still, what a mason fitted a
> mage may unfit, and stone keeps other laws than doors do.
>
> You begin the reading, then stop: the working wants a wall of stone before you,
> and there is none here. The scroll survives the false start.
>
> The firebolt washes over the granite wall and leaves it untouched.
>
> You were left to mind the tower. A tower cannot be minded from the road, however
> much you might prefer to try.

### The ending

> You lift the master's amulet from its hook. Secure at last — held personally by
> the one responsible for its safety, which is nearly the same thing.
>
> Behind you, someone clears his throat.
>
> The master stands in the archway that was, until recently, his granite wall. He
> takes a slow inventory: the warded door unbound, the wall dispersed, the golem
> redistributed evenly across the floor, and his amulet in your fist. "The
> window," he says at last, mildly. "I have asked you before to keep it shut. A
> draught takes that door, and the wards see to the rest." He regards the rubble
> that was, as of this morning, the finest guardian clay can make. And then, to
> your lasting relief, he begins — quite helplessly — to laugh.

---

## Content scope

The title and the prose are original. *Enchanter* and its spell words are
trademarks; what this game reproduces is the set of general RPG casting paradigms
— at-will, memorized, energy pool, one-shot scroll — which belong to the form
rather than to any one work. A rewrite may borrow the shape of that tradition and
must not borrow its vocabulary.

The magic is domestic throughout. Nothing in the tower is sinister, nothing is
being punished, and the worst thing that happens to anybody is a golem.

---

## Known defects

**The copy above is transcribed from the game as it ships, not as it should read.**
Several of those lines are known to be wrong, and a rewrite should fix them rather
than faithfully preserve them.

The list is deliberately not here. It would go stale the first time an issue closed,
and a stale entry is worse than none: a play-test verifier reading it would dismiss a
genuine regression as somebody else's problem. Two files carry it instead, and
neither can rot.

- [`gramarye-playtest-2026-07-30.md`](gramarye-playtest-2026-07-30.md) is the last
  round, dated in its own filename. It names each wrong line, the frame it printed
  in, and the cause.
- [`gramarye-playtest-ledger.md`](gramarye-playtest-ledger.md) is append-only: every
  finding ever filed against this game, and what became of it.

For what is open right now, ask the tracker: `gh issue list --state open --search
Gramarye`.

One of them isn't a prose problem, and a writer should know about it anyway. **The
game can be made permanently unwinnable in two commands** — `west`, `close door` —
because the barriers are gated on `.open` and not on `.close`. Repairing it is a
design call with three incompatible reasonable answers, and the round's verifier
declined to pick between them. The contract row above, *no unwinnable state by any
route*, is what any answer has to satisfy.

---

## Open questions

1. **The energy pool is declared but never squeezed.** One cast of one four-point
   spell against a twelve-point pool means `rest` is never needed and the pool never
   constrains anything. The paradigm is honestly demonstrated — the cost is charged,
   and a refused cast provably isn't — but it is never *felt*. A second combustible
   obstacle, or a smaller pool, would make the number mean something.

   *Checked by the 2026-07-30 round:* every `SPELLS` reading is true, and nobody in
   that round typed `SPELLS` even once — which is its own comment on how much the pool
   is doing.
2. **Three memory slots for one memorized spell.** `memorySlots: 3` is the default
   and nothing in the game can fill it. Either a second memorized spell earns the
   slots or the number should come down to what the game uses.
3. **The Undercroft has one state and needs two.** It never mentions the way back
   south, and it reads the same before and after the golem is destroyed — the rubble
   the ending inventories ("redistributed evenly across the floor") is not on the page
   anywhere, and the amulet's hook, which the master names in the opening, is only
   ever mentioned in firebolt's own success line. The other two rooms have state-keyed
   descriptions and this one should too. Confirmed by the round; the vocabulary half
   is #99 and the missing second state is still a design question.
