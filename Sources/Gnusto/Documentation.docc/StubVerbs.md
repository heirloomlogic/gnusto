# Stub Verbs

The verbs the parser knows as words even where your game has no mechanic.

## Overview

A player five minutes into their first room will type `attack the chair`, `smell`,
`listen`, `climb the ladder`, `jump`, `dig`, `buy lamp`. None of those is a verb
most games implement. All of them are verbs every player tries.

`I don't know the word "attack"` answers the wrong question. It says the
*program* is unfinished. `Attacking the chair rarely improves matters.` says the
*world* is — and the player learns something from the second answer and nothing
from the first.

So the engine ships about fifty of these words with a line of stock prose each.
Nothing about them is a special case in the parser. A stub verb is an ordinary
row in the standard table whose intent happens to have no mechanic behind it,
which means it:

1. **Is in the vocabulary**, so it is never `I don't know the word`.
2. **Resolves its objects through normal scope.** `attack the grue` where there
   is no grue still answers *"You can't see any such thing."* A stub doesn't buy
   politeness by weakening scope honesty.

   Scope is the *visible* set, which admits what can be seen through the glass
   of a shut jar or in somebody else's hands — so the physical stubs re-check
   **reach** and refuse with ``GameText/cantReach``, exactly as `push` does.
   Through the shut bottle in Zork's kitchen, `push water`, `squeeze water` and
   `burn water` now all answer *"You can't reach the quantity of water."*, and
   opening the bottle lets all three through.

   Which verbs check is a call made per verb, because a blanket guard would be
   wrong: `smell`, `listen to`, `point at`, `count`, `buy`, `sell` and `wake`
   are fine at a distance — you can smell a fire across a room, count coins
   behind glass, and shout somebody awake. `throw … at …` checks the projectile
   and deliberately not the target, and `give … to …` is the one stub that
   checks both slots, since handing something over is contact with the gift and
   with whoever takes it.
3. **Costs a turn.** Flailing at the chair takes time; fuses and daemons tick.
   This is the substantive difference from the parse error it replaces, which was
   free.
4. **Is overridable at every layer, with no warning** — because overriding is
   the expected end state, not a mistake.

## What's in the set

Violence and force: `attack`/`kill`/`hit`/`fight` (bare or `with` a weapon),
`break`/`smash`/`destroy`, `burn`, `cut`/`slice`, `dig`, `pull`/`drag`,
`turn`/`rotate`, `squeeze`, `shake`, `knock (on)`, `throw … at …`.

Senses: `touch`/`feel`/`rub`, `smell`/`sniff`, `listen (to)`, `taste`/`lick`.

Body: `eat`, `drink`, `sleep`, `wake (up)`.

Social: `kiss`/`hug`, `give`/`hand … to …`, `yell`/`shout`/`scream`, `wave`,
`point at`.

Motion: `climb (up/down/on)`, `jump (over)`, `swim`, `dive`, `stand (up)`,
`sit (down/on)`, `lie (down)`, `kneel`.

Liquids and containers: `fill`, `pour`, `empty`, `tie`, `untie`.

Ritual and flavor: `pray`, `sing`, `curse`/`swear`, `xyzzy`/`plugh`, `count`,
`think`, `wish`.

Commerce: `buy`, `sell`. Fixtures: `blow`.

Deliberately **not** stubs: `again`/`oops`/`verbose`/`brief`/`notify`/`script`
are missing *features*, and a canned refusal would be a worse answer than the
error. `ask`/`tell`/`show` belong to `GnustoConversation`, which has a topic slot
and somebody to ask. Bare `hello`/`hi`, `ring` and `wind` are left free for games
that want to own them outright.

## Aimed at yourself

The player is an entity, and it is called "yourself" — so a stub line that names
its object would read *"The yourself is not food."* Every name-carrying stub
checks for the player and answers ``GameText/StubReplies/yourself`` instead.
Stubs whose lines name nothing keep their own answer, because it already reads
correctly: `taste me` still says *"You'd rather not."*

Eighteen of them are handed an **optional** name, and either of two things puts
a verb there. Some have rows that carry no object at all — `smell` and `smell the
troll` are one intent — so one sentence has to read both ways. The rest fill the
slot on every row but read perfectly well with the name left out: `knock`,
`taste`, `kiss`, `count`, `buy` and `sell` are about the player as much as the
thing, so the name is offered rather than required.

The player takes the nameless half rather than the `yourself` deferral, which is
the same answer by a different road: `smell me` still says *"You smell nothing
out of the ordinary."* Seventeen of the eighteen also skip the `somebodyElse`
guard, and that follows from the shape rather than being a convenience — a line
with a nameless half is a line that can be said about anybody. `touch` is the
one that keeps it, because laying hands on somebody is not the same as listening
to them; `kiss` is the one that shows why the call is per verb, since kissing
somebody is what the verb is *for*.

## Re-skinning a line

Every stub line lives on ``GameText/stubs``, one property per intent. Override
the ones that clash with your voice and leave the rest:

```swift
var text: GameText {
    var text = GameText()
    text.stubs.attack = .naming { "The Institute frowns on assaulting \($0)." }
    text.stubs.pray = "No one is listening. You checked."
    return text
}
```

## Promoting a stub to real behavior

This is the part that makes the whole design worth it: the parser already knows
the word, so a game only has to add a rule. No `#verb`, no `verbs` entry, no
warning. Zork's climbable tree is one line:

```swift
tree.before(.climb) {
    try reply(Prose.treeClimb)
}
```

For behavior that spans every object rather than one, use an `actions` row —
`GnustoMeleeCombat` turns the whole `attack` family into real combat that way:

```swift
public var actions: [IntentAction] {
    action(.attack) {
        try reply(text.attackFutile(command.directObject?.indefiniteName ?? "that"))
    }
}
```

### To change only the words, assign the line

An `actions` row replaces the stub's **whole** default, and the reach guard is
part of that default: `DefaultActions.run` returns from an override before it
calls `requireReach`, because a game that claims the verb is saying it will
decide for itself what "close enough to touch" means. `GnustoMeleeCombat` wants
exactly that.

A game that only wants a different sentence does not, and gets it anyway. So
re-voicing is an assignment, not a row — and the assignment is a sentence:

```swift
var text: GameText {
    var text = GameText()
    text.stubs.climb = "That is not something you could climb."
    return text
}
```

A line that *does* want to name what the player pointed at says so, in the same
slot:

```swift
text.stubs.climb = .naming(orBare: "There's nothing here worth climbing.") {
    "You can't climb onto \($0)."
}
```

Both halves, because a line that owns a nameless half has two things to say and
writing only one leaves the engine's narrator answering the other. See
``GameText/Line``.

The assignment keeps the reach guard, the object's rendered name, its number
agreement, and the ``GameText/StubReplies/yourself`` and
``GameText/StubReplies/somebodyElse`` guards — and, since wanting the name is
now something an assignment can do, it has stopped being a reason to reach for a
row at all. The row keeps none of them, and
nothing warns — a row and an assignment look equally reasonable at the call site.
`Sources/Dungeon/` re-skinned seventeen stubs with rows and had given all four
away without noticing.

**The rule of thumb:** an `actions` row means *this game has behavior here*. If
all it has is a sentence, assign the sentence.

### Use `reply`, not `say`

The stage-4 default *says* its line rather than refusing, so world time passes on
a stub turn. That means a `before` rule which only `say`s does **not** suppress
the stock line — the player gets both. Promote a stub with ``reply(_:)`` or
``refuse(_:)``, which end the turn.

### Precedence

Not "item beats room". `before` rules run outside-in, so whoever `reply`s or
`refuse`s **first** wins:

1. World `before`
2. Location `beforeEachTurn`, then location `before`
3. Item `before` — indirect object, then direct object
4. The game's `actions` row for that intent
5. The engine's stub line

So a `world.before(.dig)` pre-empts a `sand.before(.dig)`. See
<doc:TheTurnPipeline>.

## Reclaiming the word entirely

If you want the *word* to mean something else, claim its row. Reclaiming a stub
row is silent, unlike reclaiming a core row:

```swift
var verbs: [SyntaxRule] {
    SyntaxRule("attack", .directObject, intent: Intent("brawl"))
}
```

## Notes for engine work

- The table is split: ``SyntaxRule/coreTable`` is the rows with real behavior,
  ``SyntaxRule/stubTable`` is these, and `standardTable` is both. Bootstrap keys
  its override warning off `coreTable`, and that split *is* the stub flag.
- A stub's intent, rows and line are one `StubVerb` value, so a stub can't be
  half-declared — rows with no line would fall through to stage 4's last resort,
  so a word the engine advertises would answer "You can't do that." Core verbs
  have the same shape for the same reason: a `CoreVerb` is an intent, its rows
  and its handler, and both tables and both intent sets are derived from those
  two arrays rather than restated.
- Stub intents are deliberately **not** in `DefaultActions.builtInIntents`, which
  is what keeps `action(.dig)` from warning. `handledIntents` is the union, used
  for the dead-intent check. `engineIntents` is the third set — UNDO, RESTART,
  SAVE and RESTORE, which `GameWorld.run` answers before the pipeline — and an
  `actions` row for one of those warns that it can never run.
- No stub row uses a `.topic` slot, and none should. A topic never fails to
  match, so a low-specificity topic row silently absorbs the scope failures of
  every more specific row sharing its verb word — `say hello to butler` with no
  butler present would answer a canned line instead of "You can't see any such
  thing."
- A bare `verb <object>` row suppresses the `missingIndirect` prompt from any
  `verb <object> PREP <second object>` row on the same verb word, because the
  parser returns on the first row that *matches* and only falls back to a
  near-miss when nothing matched. That is why `give` and `throw` ship
  second-object-only: `give lamp` asking *"What do you want to give the lamp
  to?"* beats a canned line.

## See also

- <doc:AddingCustomVerbs>
- <doc:WritingRules>
- <doc:TheTurnPipeline>
- <doc:TextAndRandomness>
