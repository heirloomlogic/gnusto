# ``GnustoScoring``

Treasure and event scoring, over an award table the bootstrap can add up.

## Overview

A game's `maxScore` is a literal, read at bootstrap before a single rule has run,
so on its own it is the author's arithmetic and nothing else. Add a sixth award
and forget the total, and the game ships with a ceiling the player walks straight
past. This library makes the award table the one place a register's points are
written, and hands the total to the bootstrap, which compares it against
`maxScore` and warns when the two disagree.

``Scoring`` is a `GameContent` bundle rather than a `GamePlugin`, because it owns
saved state: two sets of register names — the awards already paid, and the
treasures currently sitting in the trophy case. Both are `@Global`, so they
namespace under `Scoring` and ride along in save files. That makes the wiring two
steps rather than one. List the instance in the game's `content` block, then
splice its rule factories into the game's own `rules`.

Everything the rules operate on is the host's. The host declares the treasures
and puts a `.takeValue` and a `.depositValue` on each, declares the trophy case,
and names the rooms whose first entry pays. ``Scoring`` reads those traits and
moves the number; the engine's `score` verb, status line and end-of-game epilogue
do all the reporting.

**Take** value is paid once per treasure and never taken back — dropping a gem
down a well does not refund it. **Deposit** value follows the original Zork's
in-case accounting: credited when the treasure lands in the trophy case, debited
when it comes back out, so the displayed score rises and falls as the hoard is
rearranged. ``Scoring/awardOnce(_:)`` on a register missing from the table is a
`fatalError` rather than a silent zero, because a typo that pays nothing puts the
game quietly past its own maximum and nothing else would catch it.

## Wiring

```swift
import Gnusto
import GnustoScoring

struct Hoard: Game {
    let title = "Hoard"
    let maxScore = 38

    let scoring = Scoring(awards: ["cellar": 25])

    let cellar = Location { name("Cellar"); description("A low, dirt-floored cellar.") }
    let idol = Item {
        name("jade idol")
        trait(.takeValue, 5)
        trait(.depositValue, 8)
    }
    let trophyCase = Item { name("trophy case"); container; openable; transparent }

    var content: GameContents { scoring }

    var rules: Rules {
        scoring.treasures([idol], into: trophyCase)
        scoring.visit(cellar, register: "cellar")
    }

    var map: WorldMap { … }
}
```

25 for the cellar, 5 for taking the idol, 8 for casing it: 38, which is what
`maxScore` says. Change any one of the three and the bootstrap says so.

An award that fires from somewhere other than a room entry calls
``Scoring/awardOnce(_:)`` from inside any rule body, and reads its points from
the same table:

```swift
beacon.after(.turnOn) {
    scoring.awardOnce("beacon")
}
```

``Scoring/penalize(_:)`` is the other direction, and is deliberately not
registered — a death toll is charged every time. The score is a plain `Int` with
no floor, so it can go negative, as it does in the original after an early death.

Treasure values are not listed in the award table. They are already declared on
the items, and ``Scoring/declaredMaxScore(items:)`` sums them off the world. A
game with an empty table and no valued treasures declares nothing and opts out of
the check.

## Worked examples

`Sources/Lighthouse/` is the shortest: two event awards, one through
``Scoring/visit(_:register:)`` and one through ``Scoring/awardOnce(_:)``.
`Sources/Zork1/` is the full shape — five event awards plus nineteen treasures
whose take and deposit values total exactly the original's 350.

## Topics

### The content bundle

- ``Scoring``
- ``Scoring/init(awards:)``
- ``Scoring/awards``

### Rules the host splices

- ``Scoring/treasures(_:into:)``
- ``Scoring/visit(_:register:)``

### Scoring from a rule body

- ``Scoring/awardOnce(_:)``
- ``Scoring/penalize(_:)``

### Declaring a treasure's value

- ``Gnusto/TraitKey/takeValue``
- ``Gnusto/TraitKey/depositValue``

### Checking the total

- ``Scoring/declaredMaxScore(items:)``
