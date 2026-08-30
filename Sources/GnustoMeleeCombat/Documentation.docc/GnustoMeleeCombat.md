# ``GnustoMeleeCombat``

The attack verbs promoted to a mechanic: weapons, villain health, and a villain who answers.

## Overview

The engine ships `attack` as a stub verb, so every game already knows the word
and answers it with a sentence. This library takes the word over and puts a body
behind it. A swing resolves a weapon, rolls once out of a hundred against a
per-weapon table, and spends the villain's health; a knockout puts him on the
floor for 2 turns; the last hit prints his death line, runs the host's
`onDefeat` hook, and removes him from play — so the death line is the last thing
said about him, and has to account for the body. The exchange a player recognizes
from Zork — swing, answer, swing — is written nowhere. It falls out of the turn
pipeline: the player's blow resolves in the command stages and the villain's
lands with the end-of-turn timers.

Because the library claims `.attack`, `MeleeCombat(text:)` is where that verb's
voice lives. `text.stubs.attack` is the line a game without combat
prints, and a game with this library never prints it. The four refusals the
mechanics own — swinging at something no villain rule claimed, swinging
bare-handed, naming a feather as a weapon, naming a sword you aren't holding —
are ``MeleeCombat/CombatText``, passed at init.

It is a `GameContent` bundle rather than a `GamePlugin` because it saves a
ledger: each villain's health, his stun countdown, whether he is currently in a
fight, and the player's own wounds, keyed by a string the host chooses. Nothing
else belongs to it. The villains are the host's actors, the weapons are the
host's items carrying the ``Gnusto/TraitKey/weapon`` trait, and every line
either side speaks arrives as ``MeleeCombat/VillainProse`` and
``MeleeCombat/AggressionProse``, which carry no defaults at all — a library
cannot guess a villain's death sentence.

Every roll draws from the game's seeded stream, so a pinned seed replays a fight
blow for blow. The guards are ordered so quiet turns draw nothing: a villain in
another room, or behind a closed `while:` gate, or already engaged, burns no
randomness, which is what keeps one villain's presence from shifting another
villain's draws. Two simplifications are deliberate and want ledgering per game:
the player's wounds never heal, and a defeated villain stays defeated.

## Wiring it in

Mark the weapons, register each villain in `rules`, and splice his
counter-attack daemon into `timers`.

```swift
import Gnusto
import GnustoMeleeCombat

struct Cavern: Game {
    let melee = MeleeCombat()

    let sword = Item {
        name("elvish sword")
        trait(.weapon, true)
        trait(.weaponStrength, 3)   // a keen blade: misses less, kills more
    }
    let troll = Actor { name("troll") }
    let axe = Item { name("bloody axe") }
    @Global var passageClear = false

    var content: GameContents { melee }

    var rules: Rules {
        melee.villain(
            troll, key: "troll", strength: 2,
            weapons: [sword],
            prose: MeleeCombat.VillainProse(
                miss: ["The troll swings; the axe bites air."],
                wound: ["Your blow lands, and the troll grunts."],
                knockout: "The troll drops where he stood, out cold.",
                // The body dissolves in the line, because the actor is
                // removed a moment later and nothing else will say so.
                death: "The troll dies, and his body dissolves."),
            onDefeat: {
                passageClear = true          // unbar the door
                axe.move(to: player.location)  // and drop the loot
            })
    }

    var timers: [TimedEvent] {
        melee.aggression(
            of: troll, key: "troll", daemonName: "melee.troll",
            strikesFirst: 33,
            prose: MeleeCombat.AggressionProse(
                miss: ["The axe passes within an inch of your ear."],
                wound: ["The axe catches your shoulder."],
                playerDeath: "The troll's axe removes your head."))
    }
}
```

The two calls share a `key:`, and that is the whole of the connection between
them. A villain registered with `villain` alone never fights back and stays down
for good once knocked out; one given an `aggression` daemon wakes up on his own.

## The numbers

``Gnusto/TraitKey/weaponStrength`` slides the outcome cutpoints, out of 100.
Strength 2 is the baseline — miss ≤ 30, wound ≤ 70, knockout ≤ 85, kill above —
so a plain ``Gnusto/TraitKey/weapon`` with no keenness declared fights as it did
before the trait existed. Strength 1 or less is a clumsy blade at 40/76/90;
3 or more is a keen one at 22/64/82. When the player names no weapon, the
keenest one he is holding serves.

The counter-attack rolls a flat table: miss ≤ 50, wound ≤ 85, an outright kill
above. `playerStrength` is how many wounds the player survives, default 2.
`strikesFirst` is the odds out of 100 that a villain starts a fight on a turn
the player hasn't — 100 fights on sight, 0 only ever answers a blow, and neither
of those two values draws from the stream. `while:` is an extra gate checked
before the same-room guard, for a villain whose combat is scoped to one room; it
does not gate coming round from a knockout, so a man knocked out where his gate
is shut still wakes up.

## The worked example

`Sources/Zork1/` wires two villains against this library. The troll is the
straightforward one: he blocks a passage, starts a fight one turn in three, and
his axe is lootable once he falls. The thief is the awkward one, and is why
`while:` exists — he prowls the whole underground picking pockets and fights
only in his own lair, so his gate is closed on almost every turn he is alive.

## Topics

### The bundle

- ``MeleeCombat``
- ``MeleeCombat/init(text:)``
- ``MeleeCombat/verbs``
- ``MeleeCombat/actions``

### Registering a villain

- ``MeleeCombat/villain(_:key:strength:weapons:prose:onDefeat:)``
- ``MeleeCombat/aggression(of:key:daemonName:strikesFirst:playerStrength:while:prose:)``

### Traits the host declares on its items

- ``Gnusto/TraitKey/weapon``
- ``Gnusto/TraitKey/weaponStrength``

### The system's own voice

- ``MeleeCombat/CombatText``
- ``MeleeCombat/CombatText/init()``
- ``MeleeCombat/CombatText/attackFutile``
- ``MeleeCombat/CombatText/noWeapon``
- ``MeleeCombat/CombatText/notAWeapon``
- ``MeleeCombat/CombatText/weaponNotHeld``

### A villain's lines

- ``MeleeCombat/VillainProse``
- ``MeleeCombat/VillainProse/init(miss:wound:knockout:death:)``
- ``MeleeCombat/VillainProse/miss``
- ``MeleeCombat/VillainProse/wound``
- ``MeleeCombat/VillainProse/knockout``
- ``MeleeCombat/VillainProse/death``

### His counter-attack lines

- ``MeleeCombat/AggressionProse``
- ``MeleeCombat/AggressionProse/init(miss:wound:playerDeath:)``
- ``MeleeCombat/AggressionProse/miss``
- ``MeleeCombat/AggressionProse/wound``
- ``MeleeCombat/AggressionProse/playerDeath``
