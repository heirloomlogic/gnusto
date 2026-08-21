# ``GnustoSpellcasting``

Four ways a spell becomes available, over one way of writing what it does.

## Overview

Magic systems differ in their bookkeeping, not in their effects. An at-will
cantrip, a spell memorized from a book and spent in the speaking, a bolt paid
for out of an energy pool, and a scroll good for one reading all do the same
sort of thing to the world; what separates them is when the game says no. This
library keeps the two apart. A spell's effect is an ordinary rule body, written
exactly as any other rule body is, and a ``SpellCost`` sits beside it deciding
availability and price.

A spell's identity is its own intent, declared with `#verb` like any custom
verb, so `glow`, `cast glow` and `read passwall` are parser rows and a spell can
carry as many phrasings as its author wants. ``Spellcasting/spell(_:cost:effect:)``
returns the actions that intent needs — the cast handler, plus the memorize
handler when the cost is ``SpellCost/prepared(book:learnVia:)`` — and the game
splices them into its `actions` block.

It is a `GameContent` bundle rather than a `GamePlugin`, because it has state to
save. The finite spell memory and the energy pool are `@Global`s it owns, so
both travel in a save and come back correctly under UNDO; the defaults are 3
slots and 12 mana. Everything else is the host's: the spellbook, the scroll, the
targets, and every word of prose an effect prints. The bundle contributes two
verbs of its own — `rest` (or `meditate`), which refills the pool, and `spells`
(or `magic`), which reports what is held in mind and how much energy is left —
and adds `spell` to the parser's noise words, so `cast the glow spell` reaches
`glow`.

Casting runs gate, effect, pay. Availability is checked first; the effect runs
second and may refuse on its own account with `require` or `reply`; only an
effect that finished pays. So a firebolt aimed at nothing costs no energy, and a
scroll read at the wrong wall survives.

## Wiring it in

```swift
import Gnusto
import GnustoSpellcasting

extension Intent {
    #verb("glow", ["glow"], ["cast", "glow"])
    #verb(
        "firebolt", ["firebolt"], ["cast", "firebolt"],
        ["firebolt", .directObject], ["cast", "firebolt", "at", .directObject])
}

struct Tower: Game {
    let magic = Spellcasting(memorySlots: 3, maxMana: 12)

    var content: GameContents { magic }
    var verbs: [SyntaxRule] { [.glow, .firebolt] }

    var actions: [IntentAction] {
        magic.spell(.glow, cost: .cantrip) {
            say("Pale light seeps from your fingers.")
        }
        magic.spell(.firebolt, cost: .energy(4)) {
            guard let target = command.directObject else {
                try reply("Cast firebolt at what?")
            }
            target.vanish()
            say("Fire leaps from your hand and bursts against \(target.definiteName).")
        }
    }
}
```

A ``SpellCost/prepared(book:learnVia:)`` spell carries its own memorize intent,
so the one `spell(_:cost:effect:)` call registers both halves:

```swift
magic.spell(.unbar, cost: .prepared(book: spellbook, learnVia: .learnUnbar)) {
    try require(!wardedDoor.isOpen, else: "The door already stands open.")
    wardedDoor.isOpen = true
    say("The warding-marks gutter and die, and the door drifts open.")
}
```

Pass `book: nil` and the spell can be memorized anywhere; pass an item and it
has to be in hand.

## The worked example

`Sources/Gramarye/` is a small original game built to test the claim in the
first sentence of this page. It runs one spell per paradigm and chains them so
each opens exactly one obstacle: the cantrip finds the scroll, the memorized
spell opens the warded door, the energy spell destroys the golem, the scroll
passes the wall. Remove any one of the four and the amulet is unreachable, which
is a stronger demonstration than four spells that happen to work. Its design
document is `docs/games/gramarye.md`.

## Topics

### The bundle

- ``Spellcasting``
- ``Spellcasting/init(memorySlots:maxMana:)``
- ``Spellcasting/memorySlots``
- ``Spellcasting/maxMana``

### Registering a spell

- ``Spellcasting/spell(_:cost:effect:)``

### The four paradigms

- ``SpellCost``
- ``SpellCost/cantrip``
- ``SpellCost/prepared(book:learnVia:)``
- ``SpellCost/energy(_:)``
- ``SpellCost/scroll(_:)``

### What the bundle contributes to the host

- ``Spellcasting/verbs``
- ``Spellcasting/actions``
- ``Spellcasting/noiseWords``
