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
- [The player](#the-player)
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
| `TIME` verb | Checking your watch — which is on the player's wrist, worn from turn one, and cannot be taken off. | Reachable from every room. The watch and the hall clock read from the same source and must never disagree. |
| Alarms fire exactly once | The blast, the telephone, the coroner — plus an incidental radio car at 5:52. | **Three** load-bearing alarms, one of them a hard deadline that ends the game. (The two beats after the blast are *fuses*, relative to the event rather than to the clock. They are decorative by construction and are not part of this count.) |
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
| Answers that land once | Every table carries an `again:` line in its own voice, and so does every `talk.shows` row. | Nobody recites an important paragraph twice. Mrs. Kettle is the deliberate exception: her rows read the timetable live, so they go on answering. |
| Nothing speaks from a room it has left | Constance's greeting, alibi row and fallback branch on which of her two rooms she is in; both blast bodies branch on which of the house's three levels the player is standing on, not on where they were and not merely on indoors/outdoors. | A reply or a timed-event body either reads the frame it prints in or stops naming anything that room-specific. The house has levels, and a sentence about what is above or below the listener has to read them. |

**Free to change:** every name, all prose, room descriptions, topic keywords, the tone, the
title, and which suspect is guilty.

**Free to change is not the same as free to be wrong.** That clause licenses a rewrite; it
does not license a line that is false of the frame it prints in. A sentence naming the
parlour grate while the speaker stands in the back garden, a stub verb reporting an
ordinary evening thirty feet from a burning building, an account in the past tense of an
event eight minutes off — each is a defect whatever the prose around it says, and "all
prose is free to change" is not a refutation of one. Nine of the 2026-07-31 round's
thirteen refutations leaned on this clause and two leaned on it too hard.

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

A week ago he wrote to you — wrote, because Julian assumes his telephone is tapped, and
you of all people know he is right to. Somebody has been in his lab. Nothing taken, he
said, which was the part that bothered him. To most readers that sentence is a shrug. To
you it means somebody was copying, and copying means it is not over. *Come Tuesday. Six
o'clock.*

The streetcar puts you on Orange Grove at half past five — early. Julian is in the
carriage house getting together the thing he means to show you, which is why the stove is
lit on a June evening. You are still in the front hall at 5:46 when the lab goes up and
takes most of the garden wall with it. He died keeping your appointment. You have the
rest of the evening to think about that.

A radio car comes at 5:52. The patrolman takes names, posts himself at the wreckage, and
says nothing further. What downtown told him — that the deputy coroner, the county man in
the household's word, is due by ten of seven — is his to give and the player's to ask for.
The deadline is *learned*, not given; nobody standing in that hall at half past five knows
the county's schedule, and an arrival that announces it has handed the player the clock
rather than made them find it.

The deputy coroner is not a judge. He is a man who closes files. A dead rocketry man, a
shed full of chemicals, a reputation the neighbors have been enjoying for years —
*accidental* is already written in the box, and everyone in this house can live with it.
Once it is filed, nobody ever looks again. You are not here to win a conviction by ten of
seven. You are here to put one paragraph in the record before the stamp comes down.

> **Author's note** — this note goes in the game type's doc comment, per the Gramarye
> precedent. Julian Vane is fictional. The setting borrows the shape of a real 1952
> Pasadena explosion; the crime, the household, and every person in it are invented, and
> no accusation here is made of anyone who lived. Every character is a type of the
> period, never a portrait of a person; the working rule is in
> [Content scope](#content-scope).

---

## The player

A private investigator, but a particular one. During the war you did counterintelligence
work — vetting the arroyo circle when the rockets suddenly mattered — and in 1948, when
the letters about *associations* started, Julian's file crossed your desk a second time.
You read all of it: the desert business, the Sunday-night people, the foreign postmarks.
You wrote the minority opinion — that Julian Vane was reckless, indiscreet, and no kind
of spy — and you were overruled, and the clearance died anyway. When the loyalty
machinery started eating men you knew were clean, you resigned before it could eat you.
Now you do insurance work out of an office on Spring Street, and you hate it.

Julian remembers you as the only man in the whole apparatus who was fair. That is why the
letter came to you, and why it came as a letter.

What the history buys, structurally:

- **Standing.** You can interrogate a household because interrogation was your trade, and
  the deputy coroner takes your statement because your old service card still opens that
  much.
- **The house knows you.** You took statements in this front hall in 1948. Constance
  remembers. The longcase clock kept time through both visits, and the watch on your
  wrist — the one object in this game that is yours — you set by that clock on the way in,
  out of a habit from the job you don't have any more.
- **A debt.** Your fair report saved nothing. The firing happened anyway, and the firing
  put Julian in the carriage house. You ride the streetcar out carrying that.
- **The trap.** You were built to see spies. Every apparatus in this house is real — and
  none of it is the answer. Your expertise opens every door and points at the wrong ones.
  The player's arc is learning to stop reading the file and look at the household.

`X ME` answers *The same man who took statements in this hall in 1948, four years older.* —
the history, in one line, on the turn a player is most likely to ask for it. Accusing
yourself is refused rather than taken down: *The coroner would take the name down. Give
him a better one.* The accusation is the deadline's teeth, and it will not be spent on a
joke.

---

## Cast

Five scheduled actors — four suspects and one honest witness — plus one unscheduled
patrolman. Each suspect carries at most one apparatus; innuendo dies when it is a pile.

**These people move, and their prose has to know it.** A line that describes somebody by a
room they have left, or by a wreckage that has not happened yet, reads as a bug — and a
play-tester caught three of them. So: nothing in a description or a presence line may assume
a place the person is not currently standing in, or a time the game has not reached. Where
that needs to vary, it varies — `describe { }` for the examine text, `presence { }` for the
room-listing line. Constance's presence line is keyed on which room she is in; Constance's,
Mrs. Kettle's and Teague's descriptions are keyed on whether the blast has happened. Dr.
Pike's is written to be true in the parlour, the yard and the study alike, which is the
cheaper fix where it works.

**The rule reaches refusals too.** A `refuse` string is a constant in exactly the way a
`description(…)` is. The 2026-08-17 round found Teague's twice over: his description called
this *"a house where a man has just died"* from 5:38, six minutes before there was a death
and forty minutes before the telephone tells the player about it; and the suitcase's refusal
put its owner *"somewhere in this house"* for the whole evening, including the twenty-four
minutes he spends on the far side of the front door. Both now read the data that moved him:
the blast flag, and his own timetable.

One word is reserved: **arithmetic** belongs to Constance's shock and appears nowhere else.
The 2026-07-31 round found the code spending it in two other places first — Teague's
"I'd check her arithmetic" at 5:38, and the ledger's "the ordinary arithmetic of a man
with no money" — against a branch of hers gated on the blast, so the reserved word was
always spent before it did its work. Both are `figures` and `bookkeeping` now. A
rewrite that wants the word back somewhere else has to take it out of her first.

### Constance Vane — the mother

Seventy-one. Owns the house and rents out the rooms because the money ran out in 1931 and
never came back. Ran out of patience with her son somewhat later. She sits in the parlour
with the lamp off because the lamp costs money.

Since a quarter to six she has been in shock, and her shock looks like nothing at all:
flat, procedural, terribly still. She is not grieving like a woman surprised by a death;
she is holding still like a woman doing arithmetic. Her topic table is nearly all
refusals until the glove.

**Her apparatus:** none — and that is the point of her. Every investigative habit the
player owns slides off a seventy-one-year-old woman in an unlit parlour, which is why she
is the answer.
**Her lie:** that she was in the parlour all evening.
**Her fallback:** *Mrs. Vane looks past you at the wallpaper* — in the parlour, where the
wallpaper is. She spends 5:48 to 5:54 on the back step, and her greeting, her alibi row
and this fallback all branch on which of the two she is standing in.

### Delphine Marsh — the partner

Thirty-four. Paints, mostly at night. Keeps her own hours and her own counsel and a
bundle of the lodge's correspondence in Julian's desk, which is not where she left it.
Everything about her invites the wrong conclusion, and the game should let the player
reach it.

**Her apparatus:** the lodge. The letters imply she arrived in Julian's life arranged —
called, not met. She may test you with half a phrase to see whether you know the other
half; you do, from the file, and the game can let you choose whether to give it. What
they went out to the desert to do stays offstage entirely.
**Her lie:** that she doesn't know what's in the letters.
**Her fallback:** *She goes on looking at whatever she was looking at.* — but the first
time, at length: she hears the question and lets you watch her decide against it. The bare
line on its own reads like the parser failed, which is the opposite of the point.

### Howard Teague — the boarder

Fifty-six. Navy in the first war — the wrong war, which stings him — and writes sea
stories for the pulps about the one he missed. Three months behind on the room. Borrows
things and returns them a little different. He is the most helpful person in the house,
which is its own kind of tell.

**His apparatus:** the pulps and the past. He tells himself that selling pages back to
the lab that used to want them is closer to salvage than theft, and he has a writer's
gift for believing his own copy.
**His lie:** that he was at the drugstore on Colorado from half past five.
**His fallback:** *"Couldn't tell you, friend."*

### Dr. Aldous Pike — the visitor

Fifty. From the lab that fired Julian, here to collect notebooks that the lab's counsel
believes are the lab's. Wears his hat indoors. Wants very badly to be somewhere else.

**His apparatus:** the new regime. Behind the counsel stand the men who arrived after the
war and took the program out from under its founders. Pike never names them; he says
things like *"the men we have now prefer the notebooks in order,"* and once, carefully,
does not pronounce a name that would want an umlaut. His lie has a second floor: the
earlier visit was not about notebooks, and you may recognize the visit report, because
you filed one shaped like it once.
**His lie:** that this is his first visit to the house.
**His fallback:** *"I don't see how that concerns me."*

### Mrs. Iris Kettle — the cook

Sixty-two. Cooks, cleans, and misses nothing. She is not a suspect and never lies, and
she is the mechanism by which the schedule becomes testimony: `ASK KETTLE ABOUT <person>`
returns where that person actually was, read out of the timetable.

**Her apparatus:** none, and keep it that way — no file anywhere, no affiliation, no
angle. The moment she has an affiliation she has an angle, and her testimony is the one
thing the game cannot let the player doubt.
**Her fallback:** *"That I couldn't say."*

### The patrolman

Unscheduled, and stays that way — scenery with a topic table, not a sixth timetable. From
5:52 he stands in the back yard, at the gap where the carriage house door used to be, and
the wreckage is shut from that moment: the way in is refused in his words, and a player who
was standing in it when he arrived is walked out of it. That is why the player cannot dig
the answer out of the debris. He knows exactly one useful thing — when the deputy coroner is
due — and he has three answers and volunteers none of them; the deadline reaches the page
only because somebody asked him for it.

The lab is therefore open for the three turns between the blast and the radio car, and
owned by the police after that. Six minutes with the wreckage, which gives you nothing, is
the more useful lesson than an evening of sifting it.

**His fallback:** *"Best keep back from there."*

---

## Map

Nine the player can reach, plus one they can't.

```
                    Carriage House  ──  (Wreckage after 5:46)
                          │ south
                     Back Yard
                          │ east
    Cellar ── up ──── Kitchen ──── north ── Front Hall ──── west ──── Parlour
                                                │
                                               up
                                                │
                   Boarder's Room ── west ── Landing ── west ── Vane's Study
```

The kitchen is the hub, not the front hall: the back yard and the cellar both open
off it, which is why Mrs. Kettle sees everyone who crosses the house.

| Room | Notes |
|---|---|
| **Front Hall** | Start. The longcase clock. The telephone. Teague's coat on the hat stand. |
| **Parlour** | Constance's chair. Heavy furniture, no lamp lit. |
| **Kitchen** | Mrs. Kettle's ground. The back stairs pass through — this is how she sees things. The room names all three of its exits, and the drawer. Going **up** the back stairs is refused in the game's own words: they are the household's, not yours. |
| **Cellar** | **Dark.** Needs the flashlight from the kitchen drawer; standing down there in the dark says where it lives, once. The scorched glove is here, behind the coal bin. |
| **Back Yard** | Between the house and the carriage house. The garden wall. |
| **Carriage House** | Julian's lab. Julian is alive in it until 5:46. Becomes **Wreckage**, and is sealed from 5:52 by the patrolman posted at the gap on the yard side. Reachable for three turns in between. |
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
| 5:52 | — | The radio car. The patrolman takes names, posts at the gap where the door was, and stops talking. **The wreckage is shut from here on.** **The deadline reaches the page when somebody asks him for it** — and not before. |
| 5:54 | Constance | Back to the parlour, and stays there. |
| 6:00 | Kettle | Back to her kitchen, on the grounds that somebody has to. |
| 6:02 | Delphine | Up to the study, straight to the desk drawers. |
| **6:10** | Teague | Home, with a paper bag. **The receipt exists from here on.** |
| 6:14 | Pike | Into the study, and not pleased to find company. |
| **6:20** | — | **The telephone rings.** Second alarm — the lab's night man, about Pike. Answered in the hall; heard as eleven rings from the parlour, the kitchen, the landing, the study and the boarders' room; not heard at all in the cellar or out back. |
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

Every noun a room description puts on the page is answerable — `X TILE`, `X GROUT`,
`X HAT STAND`, `X BACK STAIRS`, `X COAL BIN`, `X STOVE PIPE`. A room that names a thing
the game doesn't know the word for reads like a bug, so a rewrite that introduces a new
noun should introduce the scenery item with it. `FulminateTests` walks the house asking
for each of them.

**And every noun the *examine* text puts on the page, and every noun a timed event puts
on it.** The 2026-07-31 round counted 261 unknown-word replies over 59 distinct words the
game had printed itself, because the walk covered only the room descriptions and never
fired a timed event. Three things close that class, and a rewrite has all three:

- a scenery item, where the noun is a stable thing a room owns — the six in
  `Sources/Fulminate/Fixtures.swift`, plus the yard's fire and the lab's shell, which
  read `blastHappened` and so live in the host;
- a synonym, where the noun is a facet of something that already exists. Watch for a word
  declared as an **adjective**: the tokenizer will never accept one as the last word of a
  phrase, so `hat`, `marble`, `pine` and `doctor` were unreachable words the prose printed;
- deleting the noun, where it belongs to no room. The indoor blast paragraph prints in six
  rooms, and this engine has no backdrop scenery, so it may not name the crockery or the
  ceiling: what a paragraph like that can carry is a sound and a house going quiet. The
  per-level clauses added for #305 obey the same rule — "above you", "below you", "close
  by", never "the roof" or "the landing", because no room upstairs owns either word.

A word that travels with a person goes `heldBy` them — Dr. Pike's hat, the patrolman's
notebook. Held items are in scope wherever their owner is standing and are not listed, so
the word answers in three rooms and no room listing changes.

**Front Hall** — *Black and white tile, worn through to the grout along the line people
walk. A hat stand with one coat on it. A longcase clock in the corner keeps better time
than the household does. The front door is east, the parlour west, the kitchen passage
south, and the stairs go up.*

**Parlour** — *Furniture too big for the room and too good to sell, arranged around a cold
grate. The lamp is not lit. Mrs. Vane does not light it until it is properly dark.*

**Kitchen** — *Scrubbed pine and a stove that has been going since before you got here.
The back stairs come down at the far end, which means anyone who uses them comes through
here whether they meant to or not. There is a drawer under the counter. The hall is north,
the yard door west, and the cellar steps go down.*

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
> "Mr. Teague come down my back stairs into the kitchen at eighteen minutes to six with
> his hat already on. I know because the pot goes on at a quarter to, and I was standing
> right there getting it ready."

("The kitchen" is not written in that line — it is read out of Teague's timetable at
5:42, per the mechanics contract.)

**Teague, shown the receipt:**
> He looks at it for a while. "Six-oh-five," he says. "Yeah." He hands it back and does
> not let go of it straight away. "I went after. I needed to have been somewhere."

(The gesture is his hands, not the furniture. The receipt does not exist until 6:10, and
his timetable puts him in the front hall until half past and his own room after — neither
of which has a chair in it, so the line this used to carry was false in every frame it
could reach.)

**Teague, on what he told Constance:**
> "I told the old lady he'd gone out. That's all I told her. I wanted half an hour in
> that lab and I didn't want her watching the yard while I had it." He looks past you.
> "It wasn't a lie that was supposed to do anything."

(The gesture names nobody's furniture, for the same reason his hands do above. He used to
look at the window; the confession lands in the front hall, which has none, and `window`
is not a word this game answers anywhere. The lab lamp's pre-blast line printed the noun
too, and now the man inside works to the bench and forgets the rest — which names
nothing the yard has to answer for either.)

**Constance, shown the glove:**
> She takes it out of your hand, which you were not expecting, and turns it over once.
> "I have been sitting here," she says, "trying to remember whether I put it back."

(She takes it, so the glove moves to her. "Sitting" is "standing" on the back step, where
she spends six minutes of the evening.)

### Endings

This game declares no `Scoring`, so `text.scoreLine` is re-skinned to count minutes rather
than points: *You were in that house for N turns.* Every ending used to close on "Your
score is 0, in N turns." — the win included, directly under the paragraph saying something
had been achieved. An award table would be a different game; the evening is measured in
time, so the epilogue is too.

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
costs nothing, and a clock you can outlast is scenery. Under the file-closing frame it
needs no further explanation — the deputy coroner does not argue with you; you spent your
credibility on the wrong name, and the stamp comes down anyway.

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

The Cold War is the second register of the same trick. The espionage furniture is all
real inside the fiction — Pike really is collecting for the institution, Teague really is
selling pages, the letters really are what they are, and the player's own history primes
them to read the house as a nest of it. None of it killed anybody. The game offers the
lurid explanation twice, in two flavors, and it is wrong both times.

**Period texture.** The copy may take furniture and idiom from the public history of
postwar Pasadena — rocketry, security hearings, boarding houses, lodges — and quiet
allusions for readers who know that history are welcome. Three rules keep this honest.
Every character is a type of the period, never a portrait of a person: if a draft drifts
close enough to any identifiable person, living or dead, that a reader could mistake the
character for them, change details until it reads as the type again. Nothing the game
invents — above all the crime and the lies that cause it — may be attributable, even by
implication, to anyone who lived. And no allusion may ever be load-bearing: the story
must work completely for a reader who recognizes none of it, so neither this document nor
anything else in the repository keeps an annotated key.

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

1. **Is eight turns enough with the living victim?** Sixteen minutes of game time. Long
   enough to feel like an opportunity, short enough to feel like a loss. Worth testing at
   the keyboard rather than deciding on paper.

### Settled

- **Who did it:** Constance as the hand, Teague's throwaway lie as the cause, per
  [The solution](#the-solution). The alternatives (Teague deliberate, Pike on the
  institution's behalf) were considered and dropped — the as-built timetables would make
  Teague's guilt a spoiler rather than a puzzle, and Pike's version is a colder, more
  expected story.
- **The player character:** the investigator who handled Julian's file and wrote the
  minority opinion. See [The player](#the-player).
- **The deadline is a file-closing, not a verdict,** and it is learned in play at 5:52
  rather than stated in the opening.
- **Title:** *Fulminate*. Becomes the SPM target name.
- **Wrong accusation ends the game.** See [Endings](#endings).
