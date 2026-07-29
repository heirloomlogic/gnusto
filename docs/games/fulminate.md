# Fulminate — design document

A demonstration game for the Gnusto engine. Pasadena, June 1952. A rocketry man dies in
his own carriage house and you have an hour and four minutes to say who killed him.

This document is the story-and-copy source of truth. It is iterated on separately from the
code, by a writer rather than an implementer. **Read [Mechanics contract](#mechanics-contract)
before changing anything** — the game exists to prove a set of engine behaviors, and the
story is the vehicle, not the cargo.

Tracking issue: [#40](https://github.com/heirloomlogic/gnusto/issues/40).

---

## Contents

- [What this game is for](#what-this-game-is-for)
- [Mechanics contract](#mechanics-contract)
- [Premise](#premise)
- [Cast](#cast)
- [Map](#map)
- [Timeline](#timeline)
- [The solution](#the-solution)
- [Evidence and facts](#evidence-and-facts)
- [Copy](#copy)
- [Content scope](#content-scope)
- [Build phasing](#build-phasing)
- [Open questions](#open-questions)

---

## What this game is for

Gnusto grew up hosting Zork 1 — an exploration adventure. Issue #40 asks whether the engine
generalizes to a **clock-driven mystery**, which needs three things Zork never did: a
time-of-day clock, NPCs who keep a daily schedule, and conversation about abstract subjects.

Fulminate is the proof. Every mechanic below is load-bearing: remove it and the game stops
being solvable. That is deliberate. A demo where the new subsystem is decorative proves
nothing.

The engine work ships as three libraries; Fulminate grows across the same three pull
requests.

The title is the coroner's word and the player's job. Fulminate of mercury is what goes in
the box marked *cause*; to fulminate is to denounce.

---

## Mechanics contract

The middle column is how the story *currently* carries each mechanic. The right column is
what has to remain true no matter how the story is rewritten.

| Mechanic | How the story carries it | Must survive rewriting |
|---|---|---|
| Time-of-day, `minutesPerTurn` | The hall clock. Every alibi is stated as a time. | Times stay minute-precise and stated on the page. |
| `TIME` verb | Checking your watch. | Reachable from every room. |
| Alarms fire exactly once | The blast, the telephone, the coroner. | **Three** alarms, one of them a hard deadline that ends the game. |
| Deterministic timetables | Five people on their evening rounds. | **Five** scheduled actors, with stops on *both sides* of the blast. |
| Arrival / departure prose | Footsteps on the back stairs. A door in the yard. | At least one crossing the player can witness, and one they can miss. |
| Movement is silent in the dark | Delphine goes down to the cellar at 6:26. | The cellar stays dark and stays on somebody's route. |
| `location(of:at:)` lookup | Mrs. Kettle's testimony; the alibi check. | Past-tense truth is **read from the timetable**, never hand-written prose. |
| ASK / TELL about a topic | Every interrogation. | Topics stay abstract nouns, never takeable items. |
| SHOW item to actor | Receipt, ledger, glove, letter. | At least three pieces of physical evidence that flip a story. |
| A lie retired by evidence (`unless:`) | Teague's drugstore alibi dies when Kettle contradicts it. | At least two suspects lie first and talk second. |
| Content gated on knowledge (`knowing:`) | Constance breaks only once you have the glove. | The confession stays gated on physical evidence. |
| A fact taught by evidence (`learning:`) | The receipt teaches that Teague lied to Constance. | The keystone fact is *learned*, never assumed. |
| Per-actor fallback replies | "Mrs. Vane looks past you." | Everyone has a fallback. No dead air. |

**Free to change:** every name, all prose, room descriptions, topic keywords, the tone, the
title, and which suspect is guilty.

**Not free to change without revisiting the implementation plan:** the counts in the right
column, the three-alarm structure, the dark room on somebody's route, and the rule that
past-tense truth comes out of `location(of:at:)` rather than authored strings.

That last rule is the single most important one. It is the whole demonstration. If a
suspect's account of the past is hand-written prose that happens to agree with the
schedule, the game proves nothing — the schedule has to be the source.

---

## Premise

Orange Grove Avenue, Pasadena. Millionaire's Row gone to seed: the big houses carved into
rented rooms, the lawns going brown, the money moved to San Marino two decades ago.

**Julian Vane** was a propulsion engineer at the lab up the arroyo until they let him go
over what the letter called *associations*. He kept working anyway, in the carriage house
behind his mother's place, and he kept company that gave the neighbors something to do.

A week ago he wrote to you. Somebody has been in his lab. Nothing taken, he said, which
was the part that bothered him.

You take the streetcar out on a Tuesday evening to hear the rest of it. You are still in
the front hall at 5:46 when the carriage house goes up and takes most of the garden wall
with it.

The county man is due at 6:50. What he writes down is what happened.

> **Author's note** — this note goes in the game type's doc comment, per the Gramarye
> precedent. Julian Vane is fictional. The setting borrows the shape of a real 1952
> Pasadena explosion; the crime, the household, and every person in it are invented, and
> no accusation here is made of anyone who lived.

---

## Cast

Five scheduled actors. Four suspects and one honest witness.

### Constance Vane — the mother

Seventy-one. Owns the house and rents out the rooms because the money ran out in 1931 and
never came back. Ran out of patience with her son somewhat later. She sits in the parlour
with the lamp off because the lamp costs money.

**Her lie:** that she was in the parlour all evening.
**Her fallback:** *Mrs. Vane looks past you at the wallpaper.*

### Delphine Marsh — the partner

Thirty-four. Paints, mostly at night. Keeps her own hours and her own counsel and a
bundle of the lodge's correspondence in Julian's desk, which is not where she left it.
Everything about her invites the wrong conclusion, and the game should let the player
reach it.

**Her lie:** that she doesn't know what's in the letters.
**Her fallback:** *She goes on looking at whatever she was looking at.*

### Howard Teague — the boarder

Forty-ish. Ex-Navy, writes for the pulps, three months behind on the room. Borrows things
and returns them a little different. He is the most helpful person in the house, which is
its own kind of tell.

**His lie:** that he was at the drugstore on Colorado from half past five.
**His fallback:** *"Couldn't tell you, friend."*

### Dr. Aldous Pike — the visitor

Fifty. From the lab that fired Julian, here to collect notebooks that the lab's counsel
believes are the lab's. Wears his hat indoors. Wants very badly to be somewhere else.

**His lie:** that this is his first visit to the house.
**His fallback:** *"I don't see how that concerns me."*

### Mrs. Iris Kettle — the cook

Sixty-two. Cooks, cleans, and misses nothing. She is not a suspect and never lies, and
she is the mechanism by which the schedule becomes testimony: `ASK KETTLE ABOUT <person>`
returns where that person actually was, read out of the timetable.

**Her fallback:** *"That I couldn't say."*

---

## Map

Nine the player can reach, plus one they can't.

```
                    Carriage House  ──  (Wreckage after 5:46)
                          │ south
    Cellar ── up ──  Back Yard
      │                   │ east
     up                   │
      │                   │
    Kitchen ──── north ── Front Hall ──── west ──── Parlour
                              │
                             up
                              │
    Boarder's Room ── west ── Landing ── west ── Vane's Study
```

| Room | Notes |
|---|---|
| **Front Hall** | Start. The longcase clock. The telephone. Teague's coat on the hat stand. |
| **Parlour** | Constance's chair. Heavy furniture, no lamp lit. |
| **Kitchen** | Mrs. Kettle's ground. The back stairs pass through — this is how she sees things. |
| **Cellar** | **Dark.** Needs the flashlight from the kitchen drawer. The scorched glove is here. |
| **Back Yard** | Between the house and the carriage house. The garden wall. |
| **Carriage House** | Julian's lab. Julian is alive in it until 5:46. Becomes **Wreckage**. |
| **Landing** | Upstairs hall. |
| **Vane's Study** | The desk. The ledger. The lodge letters. |
| **Boarder's Room** | Teague's. A typewriter and a suitcase that is packed too early. |
| **Orange Grove Avenue** | Off the map — no exit leads here. Where Teague is from 5:44 to 6:10. |

The dark cellar is not decoration. It is where the engine's "NPC movement is silent in an
unlit room" behavior gets demonstrated, and it is why the flashlight exists.

---

## Timeline

Two minutes per turn. The game opens at **5:30 pm** and ends no later than **6:50 pm** —
forty turns of investigation after the blast. Turn *n* reads `17:30 + 2(n-1)`, so the blast
ends turn 9, the telephone turn 26, and the coroner turn 41.

**This table is as-built.** The five timetables in `Sources/Fulminate/Fulminate.swift` are
the source of truth; if they and this disagree, they win.

| Time | Who | Beat |
|---|---|---|
| **5:30** | — | You arrive. Julian is alive in the carriage house, and **askable for eight turns.** |
| 5:36 | Teague | Down the back stairs into the kitchen — *through the room Mrs. Kettle is standing in.* |
| 5:38 | Teague | Out the yard door and into the carriage house. |
| 5:42 | Teague | Back through the kitchen, saying nothing to anybody. |
| 5:44 | Teague | Across the front hall and out the front door, "for cigarettes". |
| **5:46** | — | **The blast.** First alarm. Julian is gone. |
| 5:46 | Teague | Off the map, on Orange Grove Avenue, where the player can't follow. |
| 5:48 | Constance, Kettle, Pike | Out to the yard. Delphine is already standing in it. |
| 5:54 | Constance | Back to the parlour, and stays there. |
| 6:00 | Kettle | Back to her kitchen, on the grounds that somebody has to. |
| 6:02 | Delphine | Up to the study, straight to the desk drawers. |
| **6:10** | Teague | Home, with a paper bag. **The receipt exists from here on.** |
| 6:14 | Pike | Into the study, and not pleased to find company. |
| **6:20** | — | **The telephone rings.** Second alarm — the lab's night man, about Pike. |
| 6:26 | Delphine | Down to the cellar, without a light. **Silent — the cellar is dark.** |
| 6:30 | Teague | Up to his room. |
| **6:50** | — | **The coroner.** Third alarm. Accident ruling. Game over. |

**The receipt is not in the coat until 6:10.** A slip stamped 6:05 cannot be in a pocket at
half past five. Searching the coat early turns up an empty pocket — the honest answer, and
the better one, because it gives the evidence a time as well as a place.

Two structural notes for whoever rewrites this:

**Julian is alive for the first eight turns.** A player who spends them talking to the
victim learns things a player who wanders the garden does not. That costs nothing to
build — conversation and the alarm know nothing about each other — and it rewards the
instinct a mystery player already has.

**Teague is off the map from 5:44 to 6:10.** There are questions you can only put to him
inside a window. Spend the window in the cellar and you have spent it. This is the
schedule doing dramatic work rather than set dressing, and some version of it should
survive any rewrite.

---

## The solution

**Constance did it, and did not mean to.**

She put the can where the heat would find it. She meant to take the lab — the thing that
had taken her son years before it killed him, and that brought those people to her door on
Sunday nights. She believed Julian had gone out.

She believed it because **Teague told her so.** Teague said it to buy himself a clear half
hour with the notebooks he had been selling to Pike's outfit a few pages at a time.

So the mother is the hand and the boarder's small self-serving lie is the cause, and
neither of them meant to kill anybody. Pike is a coward and a receiver of stolen goods and
nothing worse. Delphine is guilty of nothing at all, which is why the letters point at her
so hard for so long.

`ACCUSE CONSTANCE` wins the game.

If you have also learned that Teague lied to her — the fact the drugstore receipt teaches —
you get the fuller ending, in which the county man writes down two names instead of one.
That second tier is the demonstration of knowledge-gated content, and it is the better
story besides: the game's real subject is that a lie told for a trivial reason killed a man,
and a player who never finds that out has solved the case without understanding it.

---

## Evidence and facts

Four objects. Each one flips somebody's story.

| Object | Where | Show it to | Teaches |
|---|---|---|---|
| **Drugstore receipt** | Teague's coat, front hall | Teague | `teagueLied` — that he told Constance her son had gone out |
| **Ledger** | The study desk | Pike | `notebooksSold` — pages were going to the lab a few at a time |
| **Scorched glove** | The cellar (dark — bring the flashlight) | Constance | `constanceBroke` — the confession |
| **Lodge letter** | The study desk | Delphine | `delphineCleared` — the red herring dies |

And the testimony that does not come in an object:

| Fact | How it's learned |
|---|---|
| `kettleSawTeague` | `ASK KETTLE ABOUT TEAGUE` — she saw him on the back stairs at 5:42 |
| `teagueRecanted` | Showing him the receipt, which is time-stamped 6:05 |

The chain the player actually walks:

1. Teague says he was at the drugstore from 5:30.
2. Mrs. Kettle says she saw him in her kitchen at 5:42. His alibi is dead.
3. The receipt in his coat is stamped 6:05 — he went to the drugstore *after*, to buy the
   alibi. Confronted, he gives up the lie he told Constance.
4. That lie is the thing Constance cannot answer. With the glove in your hand, she stops
   trying.

Step 2 is the one that matters technically. Mrs. Kettle's answer is not a written line; it
is read out of Teague's timetable at 5:42. Change his schedule and her testimony changes
with it, automatically. That is the demonstration.

---

## Copy

Draft prose. This is the layer a writer should expect to replace wholesale. The voice is
deadpan and period: short declaratives, concrete nouns, no adverbs, and the narrator never
tells you how to feel.

### Opening

> **FULMINATE**
> Pasadena, June 1952.
>
> The letter said somebody had been in his lab and nothing had been taken, and that the
> second part was what worried him. It was signed with a fountain pen that had been going
> dry.
>
> The streetcar puts you on Orange Grove at half past five. The house is the fourth one
> down, and it was somebody's idea of a palace once.

### Rooms

**Front Hall** — *Black and white tile, worn through to the grout along the line people
walk. A hat stand with one coat on it. A longcase clock in the corner keeps better time
than the household does. The front door is east, the parlour west, the kitchen passage
south, and the stairs go up.*

**Parlour** — *Furniture too big for the room and too good to sell, arranged around a cold
grate. The lamp is not lit. Mrs. Vane does not light it until it is properly dark.*

**Kitchen** — *Scrubbed pine and a stove that has been going since before you got here.
The back stairs come down along the far wall, which means anyone using them comes through
here. A drawer under the counter. The yard door is west, the cellar steps go down.*

**Cellar** — *Cold, and it smells like a cellar.* (Unlit: *It is pitch black.*)

**Back Yard** — *Dry grass and a garden wall that used to be taller. The carriage house
stands at the north end with its lamp burning.*

**Carriage House** *(before)* — *Somebody's workshop and somebody else's chapel. A bench
down one side under a rack of tools, a cot down the other, and a sealed can of something
sitting where the heat off the stove can reach it.*

**Wreckage** *(after)* — *The roof is in the yard. What is left of the bench is burning
quietly and nobody has thought to put it out.*

**Landing** — *A runner going bald down the middle. The study is west, the boarder's room
east.*

**Vane's Study** — *A desk with a green shade over the lamp, and every drawer open. Not
ransacked. Searched by somebody who intended to put it all back.*

**Boarder's Room** — *A typewriter with a sheet still in it, and a suitcase on the bed
that is packed for a longer trip than anybody has mentioned.*

### Sample interrogation

The full topic tables go in the implementation. These are the beats that must survive.

**Teague, before the receipt:**
> "Drugstore on Colorado. Left here about half past, walked down, had a Coca-Cola,
> walked back. Ask them, they know me."

**Mrs. Kettle, on Teague:**
> "Mr. Teague come down my back stairs at a quarter to six with his hat already on. I
> know because I had the pot on and the pot goes on at a quarter to."

**Teague, shown the receipt:**
> He looks at it for a while. "Six-oh-five," he says. "Yeah." He sits down on the arm of
> the chair, which is not his chair. "I went after. I needed to have been somewhere."

**Teague, on what he told Constance:**
> "I told the old lady he'd gone out. That's all I told her. I wanted half an hour in
> that lab and I didn't want her watching the yard while I had it." He looks at the
> window. "It wasn't a lie that was supposed to do anything."

**Constance, shown the glove:**
> She takes it out of your hand, which you were not expecting, and turns it over once.
> "I have been sitting here," she says, "trying to remember whether I put it back."

### Endings

**Full win** — accuse Constance knowing `teagueLied`:
> The county man writes for a long time. When he is finished he reads it back, and there
> are two names in it, and only one of them meant anything by it.

**Partial win** — accuse Constance without it:
> The county man writes down her name and closes the book. He does not ask why, and you do
> not have an answer that would fit in the space provided.

**Wrong accusation** — ends the game:
> He hears you out. Then he writes *accidental* in the box marked cause, and the case is
> a page in a drawer in a building in Los Angeles.

A wrong name ends the run. It is the deadline's teeth: an accusation you can take back
costs nothing, and a clock you can outlast is scenery.

**Out of time:**
> The county man comes up the path at ten to seven and you have nothing to give him.

---

## Content scope

The lodge is background texture. It exists, the neighbors disapprove, the letters allude
to rites that nobody in the game describes. There is no occult content on the page beyond
period-plausible unease, and **none of it is the answer**.

Keeping it a red herring is what keeps it in the background structurally rather than by
polite omission — the game repeatedly offers the lurid explanation and it is repeatedly
wrong. The solution is domestic and venal, which is both the better mystery and the only
version of this material worth writing.

The real man this setting borrows from led a life that included a great deal this game has
no interest in. The game's position is that the interesting question about him was never
the occultism. It was that he was somebody's son.

---

## Build phasing

Fulminate grows across the three pull requests that build the engine work.

| PR | Engine | Fulminate gains | Its transcript test pins |
|---|---|---|---|
| **1** | `GnustoClock` — time of day | Nine rooms, the props, the clock, `TIME`, the blast and the coroner. Julian dies on schedule. Not yet solvable. | Walking the house; the clock reading correctly; the blast landing at 5:46. |
| **2** | `GnustoClock` — timetables | The five actors on their rounds. Kettle's testimony becomes readable. | A crossing witnessed and a crossing missed; the cellar staying silent. |
| **3** | `.topic` slot + `GnustoConversation` | Interrogation, the evidence chain, `ACCUSE`, both endings. | The winning walkthrough, a wrong accusation, and running out of clock. |

---

## Open questions

1. **Who did it — still open.** The draft above has Constance as the hand and Teague's
   throwaway lie as the cause. The alternatives on the table are Teague doing it
   deliberately (harder, more conventionally noir) or Pike doing it on the institution's
   behalf. **Nothing in PR1 encodes the answer** — the rooms, the clock and the blast are
   the same whoever is guilty — so this can stay open while the engine work starts, and
   wants settling before the timetables land in PR2.
2. **Is eight turns enough with the living victim?** Sixteen minutes of game time. Long
   enough to feel like an opportunity, short enough to feel like a loss. Worth testing at
   the keyboard rather than deciding on paper.

### Settled

- **Title:** *Fulminate*. Becomes the SPM target name.
- **Wrong accusation ends the game.** See [Endings](#endings).
