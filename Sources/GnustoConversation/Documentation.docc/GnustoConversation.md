# ``GnustoConversation``

Adds ASK, TELL and SHOW, the per-actor tables that answer them, and a saved
record of what the player has worked out.

## Overview

The engine ships around fifty stub verbs so that no word a player tries in their
first five minutes comes back as *I don't know the word*. `ask`, `tell` and
`show` are deliberately not among them. A stub is a word with one line of stock
prose and no mechanic behind it, and there is no line that answers `ask the
butler about the murder` — the verb wants a topic slot, somebody to ask, and a
table to look the subject up in. So the three words live here instead, with the
table behind them, and `talk to` and a bare `hello` come along with them.

What the table is for is the shape a mystery needs and nothing in the engine
offered: an actor who says one thing until the player can prove otherwise, and
something else afterwards. A row can require a fact, be retired by one, teach
one, or test what is true of the world at the moment the player raises the
subject. The facts are saved, so what a suspect says is a function of how much
of the case has already been made against him.

``Conversation`` is a `GameContent` bundle rather than a `GamePlugin`, because
it owns state: the facts learned so far, and which rows each actor has already
given in full. Both are globals namespaced under the bundle, so save, restore
and UNDO carry them with no work from the host. Everything else is the host's —
the actors, the rows, and every word spoken, the five stock lines included,
which arrive through ``Conversation/init(text:)``.

```swift
import Gnusto
import GnustoConversation   // .product(name: "GnustoConversation", package: "Gnusto")

struct Fulminate: Game {
    let talk = Conversation()

    var content: GameContents { talk }        // the verbs, the facts, the heard set

    var rules: Rules {
        talk.greeting(
            of: julian,
            again: "\"Mm,\" he says, to the clamp.",
            reply: "\"You're early,\" he says to the bench. \"That's all right. Nothing's early enough.\"")

        talk.topics(
            of: julian,
            fallback: "\"Later,\" he says, without turning round. \"You'll have all of it after six.\""
        ) {
            topic(
                "delphine", "marsh",
                reply: """
                    "Delphine keeps her own counsel." He tightens a clamp. "It was the counsel I liked first."
                    """)
        }
    }
}
```

<doc:Conversations> is the full account: how a subject is matched, what gates a
row, how an answer is made to land once, and a worked interrogation.

## Topics

### The layer

- ``Conversation``

### What the player knows

- ``Fact``

### Topic rows

- ``topic(_:only:knowing:unless:learning:when:again:id:reply:)``
- ``topic(_:only:knowing:unless:learning:when:again:id:perform:)``
- ``TopicEntry``
- ``TopicBuilder``

### Articles

- <doc:Conversations>
