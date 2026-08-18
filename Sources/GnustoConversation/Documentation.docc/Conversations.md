# Conversations

ASK, TELL and SHOW, the tables that answer them, and the facts that decide which
answer comes out.

## Overview

A stub verb is a word the parser knows with one line of stock prose behind it
and no mechanic, which is why the engine can ship about fifty of them and why
`ask`, `tell` and `show` are none of the fifty. There is no single line that
answers `ask the butler about the murder`. The verb wants a topic slot, somebody
to ask, and a table to look the subject up in, and no stub row carries a topic
slot for a reason of its own: a topic never fails to match, so a canned topic row
would absorb the scope failures of every more specific row sharing its verb word,
and `ask butler about the murder` in a house with no butler would answer with
prose rather than *You can't see any such thing.*

So the three words live in this library. What they buy is the shape a mystery
needs: an actor who says one thing until the player can prove otherwise, and
something else afterwards.

## Wiring it up

```swift
import Gnusto
import GnustoConversation   // .product(name: "GnustoConversation", package: "Gnusto")

struct Fulminate: Game {
    let talk = Conversation()

    var content: GameContents { talk }

    var rules: Rules {
        talk.greeting(of: kettle, reply: "…")
        talk.topics(of: kettle) { … }
        talk.shows(receipt, to: teague, reply: "…")
    }
}
```

Listing the layer in `content` registers all of it at once: the verbs, the two
globals, and the default actions that answer when no table did. The two globals
are the whole of its state — the facts the player has worked out, and which rows
each actor has already given in full — and both travel in save files under the
bundle's namespace.

## The verbs

| What the player types | Intent |
|---|---|
| `ask the butler about the murder` | `.ask` |
| `tell the butler about the letter` | `.tell` |
| `show the letter to the butler` | `.show` |
| `talk to the butler`, `speak with the butler` | `.talk` |
| `hello`, `hi` | `.greet` |

SHOW is an ordinary two-object row — a thing is a thing, so it needs no topic
slot. The dative is not expressible, since two object slots can't sit side by
side, so `show butler the letter` is not a sentence this game speaks.

Greeting is split between the engine and this library on purpose. `greet X`,
`hello X`, `hi X` and `say hello to X` are core rows present in every game; the
bare `hello` and `hi` are not, so that a game without a conversation layer can
own those two words outright. TALK is a separate intent — GREET is the hello,
TALK is settling in for one — and ``Conversation/greeting(of:for:learning:again:reply:)``
answers both by default, so the player is never made to guess which word the
game wanted.

## An actor's topic table

``Conversation/topics(of:for:fallback:again:_:)`` declares what one actor will
say about what. Rows fire only when that actor is the one being addressed.

```swift
talk.topics(
    of: julian,
    fallback: "\"Later,\" he says, without turning round. \"You'll have all of it after six.\"",
    again: "\"You had that off me.\" He does not turn round. \"Six o'clock.\""
) {
    topic(
        "letter", "lab", "break in", "intruder", "somebody",
        reply: """
            "Nothing taken." He lets that sit. "A thief takes. A man who takes nothing is coming back."
            """)
    topic(
        "teague", "boarder", "howard",
        reply: """
            "Howard borrows things. They come back a little different." He almost smiles. "Most things don't \
            come back at all."
            """)
}
```

One rule is registered per intent, each scanning the whole table. That is what
makes `fallback:` expressible at all: a per-row rule cannot know that no later
row matched.

### Matching is by keyword, not by phrase

A row answers when every word of one of its keywords appears somewhere in what
the player typed, in any order. `topic("murder", "body")` answers `ask butler
about the murder`, `… about that dreadful murder` and `… about the body` alike,
while `topic("murder weapon")` needs both words present. Each keyword is
normalized exactly as the parser normalizes player input, so articles, capitals
and punctuation don't matter.

Rows are tried in declaration order and the first match wins, so the specific go
above the general, and for a subject whose answer changes, the gated version goes
above the ungated one.

### What gates a row

| Parameter | What it asks |
|---|---|
| `knowing:` | a fact the player must already have learned |
| `unless:` | a fact that retires the row — the lie the actor stops telling |
| `learning:` | a fact the player learns by hearing this answer |
| `when:` | a live condition on the world, read at the moment the player asks |
| `only:` | restrict the row to some of the table's intents |

A row the player hasn't earned is skipped, so a later row or the fallback answers
instead. `only: [.tell]` is for a subject the player can volunteer but not ask
about.

`knowing:` and `unless:` are for what the player has worked out; `when:` is for
what is currently true. Fulminate keeps the two apart deliberately — whether the
carriage house has gone up is a plain `@Global` rather than a ``Fact``, because
nobody deduced it — and Teague's alibi needs both, since he can't tell the lie
before there is anything to lie about:

```swift
topic(
    "drugstore", "alibi", "evening", "colorado", "where",
    unless: .kettleSawTeague,
    when: { clock.now >= TimeOfDay(17, 46) },
    reply: """
        "Drugstore on Colorado. Left here about half past, walked down, had a Coca-Cola, walked back. \
        Ask them, they know me."
        """)
```

### The fallback, and the value of staying quiet

`fallback:` is what the actor says when nothing matched. Left off, the table says
nothing and the next rule answers — another table, a `GnustoActors` reaction, or
this layer's own default. That silence is the hook for a fallback that has to
read the world. Mrs. Vane's is the line she gives most often and therefore the
one that most needed to know which room she is standing in, so it is a rule
declared after her table:

```swift
constance.before(.ask, .tell) {
    guard command.topic != nil else { return }
    try reply(
        constance.isIn(parlour)
            ? "Mrs. Vane looks past you at the wallpaper."
            : "Mrs. Vane looks past you at the end of the garden.")
}
```

### `reply:` and `perform:`

`reply:` is a line, and it ends the turn. `perform:` is a rule body: `say`,
`reply`, `refuse` and world mutation behave as they do in any rule, and the turn
ends only if the body says so. Use it when the answer moves the world, or when
the sentence has to read the frame it prints in.

## Saying it once

A row with no `again:` repeats forever and records nothing. That is the default,
and a game that never writes `again:` produces byte-identical saves.

A table's `again:` retires its `reply:` rows. A `perform:` row does not inherit
it and opts in by naming a line of its own, because a body can move the world and
a table default must never be able to change what the world *does*, only what is
*said*. A `perform:` row that names one runs its body once; the repeat is the
line alone.

A row that has been heard still **matches** and still owns its keyword. It never
falls through to a later row or to the fallback, because an actor who
demonstrably has an answer should not sound blank about the subject. Gating
composes at no cost: a lie and the confession that replaces it are separate rows
with separate keys, tracked apart. A repeat costs a turn, like any other answer.

A row's key in the heard set is derived from its content — keywords, intents,
gate facts — rather than its position, because the two fail in opposite
directions. A position key shifts when an author inserts a row above it and makes
a never-before-seen answer come out as *I have answered that*: content lost, no
diagnostic. A content key changes when an author edits a keyword, which makes the
row look unheard, so the line plays once more — which is what it did before the
feature existed. Give a row an `id:` when its keywords or gates are likely to be
edited after release, when its actor shares a display name with another, when two
rows should retire together, or when two rows differ only in which `when:`
closure they carry: the key records that a row *has* one, not which one.

An `id:` is also the only handle on a row from outside the table.

- ``Conversation/hasHeard(_:from:)``
- ``Conversation/unhear(_:from:)`` — one row, given in full again
- ``Conversation/unhearEverything(from:)`` — an actor's whole memory

## Greetings

```swift
talk.greeting(
    of: teague,
    again: "\"Still here,\" he says, pleased about it.",
    reply: """
        "Teague," he says, and has your hand before you have offered it. "Anything you need in this house, \
        you come to me."
        """)
```

A greeting registers as a before rule, so it runs ahead of this layer's own
default and ahead of a `GnustoActors` reaction declared after it. Nobody
introduces themselves twice and there are four ways to say hello, so an opening
line without an `again:` wears out in the first minute.

The `perform:` form is for a greeting that reads the world it is said in. An
actor keeping a timetable is not in one room all evening, and a hello that names
the furniture has to know whose furniture it is naming:

```swift
talk.greeting(
    of: constance,
    again: "Mrs. Vane has already said the one word she means to say to you."
) {
    try reply(
        """
        "Yes," says Mrs. Vane, to no question, and goes on looking at \
        \(constance.isIn(parlour) ? "the grate" : "the fire").
        """)
}
```

## Showing evidence

``Conversation/shows(_:to:learning:again:reply:)`` is one actor's reaction to one
thing put in front of them, and it is where a piece of evidence usually teaches
its fact:

```swift
talk.shows(
    receipt, to: teague, learning: .teagueRecanted,
    again: "\"You've got the slip,\" he says, and does not look at it a second time.",
    reply: """
        He looks at it for a while. "Six-oh-five," he says. "Yeah." He hands it back and does not let go of \
        it straight away. "I went after. I needed to have been somewhere."
        """)
```

The rule is scoped on the actor rather than on the item, because item `before`
rules run indirect object first, which puts this ahead of any rule the shown
thing has of its own. The `perform:` form takes a reaction that moves the world,
and on a repeat the body does not run — `again:` is the whole of the answer,
which is what makes a transfer safe to write into the line:

```swift
talk.shows(
    glove, to: constance, learning: .constanceBroke,
    again: "The glove is in her lap. She has not looked down at it since she put it there."
) {
    glove.move(heldBy: constance)
    try reply(
        """
        She takes it out of your hand, which you were not expecting, and turns it over once. "I have been \
        \(constance.isIn(parlour) ? "sitting" : "standing") here," she says, "trying to remember whether I \
        put it back."
        """)
}
```

The paragraphs a case turns on are the ones a player is most likely to try
twice, so a reaction without an `again:` recites the confession word for word.

## The fact ledger

``Fact`` is modelled on `Intent`: an opaque string identity a game extends with
constants of its own, so a mistyped fact is a compile error rather than a topic
that silently never unlocks.

```swift
extension Fact {
    /// Mrs. Kettle saw Teague come through her kitchen — the drugstore alibi
    /// is dead.
    static let kettleSawTeague = Fact("kettleSawTeague")
    /// The receipt is stamped 6:05: he went to the drugstore *after*, to buy
    /// the alibi, and he has admitted it.
    static let teagueRecanted = Fact("teagueRecanted")
    /// The keystone: Teague told Constance her son had gone out. Knowing this
    /// is what separates the full ending from the partial one.
    static let teagueLied = Fact("teagueLied")
}
```

Three methods read and write the ledger from any rule body:
``Conversation/knows(_:)``, ``Conversation/learn(_:)`` and
``Conversation/forget(_:)``. The last two are idempotent, and teaching happens on
every hearing rather than only the first — which matters only to a game that has
called `forget` in between, where re-teaching is the least surprising thing to
do.

The ledger is a global, so it saves, restores and undoes with the rest of the
world and the host arranges nothing. It is also what an ending can be gated on.
Fulminate's two winning endings differ by one fact, because a player who never
found out why she believed the lab was empty has solved the case without
understanding it:

```swift
constance.before(.accuse) {
    say(
        talk.knows(.teagueLied)
            ? """

            The county man writes for a long time. When he is finished he reads it back, and there are two \
            names in it, and only one of them meant anything by it.
            """
            : """

            The county man writes down her name and closes the book. He does not ask why, and you do not \
            have an answer that would fit in the space provided.
            """)
    try end(won: true)
}
```

## The stock lines

Five lines cover the turns no row answered. They live on ``Conversation/Text``
rather than on the engine's own table, because a plugin that claims a verb owns
that verb's voice, and they are handed in at construction.

| Line | When it is said |
|---|---|
| `nothingToSay` | ASK or TELL, no matching row and no fallback |
| `nothingToTalkAbout` | TALK to somebody who has no greeting |
| `noInterest` | SHOW something no `shows` row covers |
| `cantTalkTo` | the addressee is inanimate |
| `cantTalkToSelf` | the addressee is the player |

The three that name somebody are handed a rendered phrase — "the butler", "Mrs.
Vane" — rather than a bare name, and three of the five carry a verb that has to
agree with whoever they name. A game with a plural cast in the room would
otherwise get *the twins waits for you to come to the point*, with no cure but to
re-voice a line it was happy with. Open such a line with `sentenceCased`, never
with a hand-written "The".

```swift
static let talkText: Conversation.Text = {
    var text = Conversation.Text()
    text.noInterest = .naming { "\($0.sentenceCased) looks at it and looks away." }
    return text
}()

let talk = Conversation(text: talkText)
```

That is Fulminate's entire re-voicing. One line, because a woman who looks at a
thing and looks away says more about the house than "shows no interest" does.

## Composing with other rules

A table registers before rules on its actor, so it takes an ordinary place in the
precedence: world, then location, then item and actor `before` rules, then the
game's `actions` row, then the engine's default. Within one actor, declaration
order decides. `GnustoActors`' `reaction(of:to:reply:)` is this one level cruder,
being a before rule that always says the same thing, so a reaction declared after
a table becomes its catch-all and one declared before shadows the table entirely.

A game with a conversation verb of its own reuses a table by naming it —
`topics(of: butler, for: [.ask, .tell, .interrogate])` — and `greeting(of:for:)`
takes the same parameter for a game that has minted its own way of saying hello.

## A worked interrogation

Fulminate's boarder lies about where he spent the evening, and the case takes the
alibi apart in four moves. Each is a row or a showing; nothing but the facts
enforces the order they come in.

**The cook.** Mrs. Kettle's answers are not authored prose — each one reads the
person's timetable, so an edit to Teague's evening changes what she says about
it. Her row teaches the fact that kills his alibi, and it declines to testify
until the clock has reached the minute it quotes:

```swift
topic(
    "teague", "boarder", "howard",
    learning: .kettleSawTeague,
    when: { clock.now >= Fulminate.sawTeague }
) {
    try reply(
        """
        "Mr. Teague come down my back stairs into the \(room(teagueDay, at: Fulminate.sawTeague)) at \
        eighteen minutes to six with his hat already on. I know because the pot goes on at a quarter to, \
        and I was standing right there getting it ready."
        """)
}
```

**The contradiction.** `kettleSawTeague` retires the drugstore lie by `unless:`
and turns on the row beneath it, where he starts questioning her clock instead of
his own:

```swift
topic(
    "drugstore", "alibi", "evening", "colorado", "where", "kitchen",
    knowing: .kettleSawTeague, unless: .teagueRecanted,
    reply: """
        "Mrs. Kettle keeps a good kitchen and a better clock." He recrosses his legs. "A man can pass \
        through a kitchen on his way to the drugstore. I'd check her figures."
        """)
```

**The receipt.** Stamped 6:05, which is after the blast: showing it teaches
`teagueRecanted`, and the row above closes with `"You've got the slip," he says.
"I'm done selling you the drugstore."`

**The keystone.** One row is gated on the recantation and teaches the fact the
full ending turns on, which is the only place in the game it can be learned:

```swift
topic(
    "constance", "vane", "old lady", "mother", "told",
    knowing: .teagueRecanted, learning: .teagueLied,
    reply: """
        "I told the old lady he'd gone out. That's all I told her. I wanted half an hour in that lab and \
        I didn't want her watching the yard while I had it." He looks at the window. "It wasn't a lie \
        that was supposed to do anything."
        """)
```

Four rows, one showing, and three facts. The player types ordinary English at a
man in a chair, and the chain is checkable from a save file.
