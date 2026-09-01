# Gnusto

Gnusto is a Swift engine for writing interactive fiction. One type is one game: rooms, things, and rules are ordinary stored properties, and the engine takes it from the player's sentence to the next prompt.

You declare the world and the engine finds those declarations by reflection, naming each one after the property it was stored in. Nothing has to be registered anywhere, and every reference is ordinary property access, so a room you misspell is a build error rather than a bug report. `swift run` and it is a game.

It also answers for about fifty verbs your game does not implement — `attack`, `dig`, `smell`, `xyzzy` — with a line of stock prose each. `I don't know the word "attack"` tells the player the *program* is unfinished. *"You shout. Nothing shouts back."* tells them the world is. Every one of those lines is yours to replace.

The name comes from the Enchanter spell that copies a scroll into your spellbook.

## A tiny game

```swift
import Gnusto

struct TinyGame: Game {
    let title = "A Tiny Game"
    let intro = "You wake in a small, bright room."

    let room = Location {
        name("Bright Room")
        description("A plain white room with a single door, to the north.")
    }

    let coin = Item {
        name("gold coin")
        description("A heavy gold coin.")
    }

    var map: WorldMap {
        room.north(blocked: "The door is locked.")
        player.starts(in: room)
        coin.starts(in: room)
    }
}
```

That is a complete game. The player can `look`, `examine coin`, `take coin`, check their `inventory`, and try to go `north`. To build one from scratch, read [Getting Started](https://heirloomlogic.github.io/gnusto/documentation/gnusto/gettingstarted); to skip the setup, run `bin/new-game Zwank ~/dev/Zwank` and start writing rooms.

## What it plays like

Four turns on a jetty, spent entirely on verbs the game does not implement:

```
> shout
You shout. Nothing shouts back.

Cold water sluices between the planks of the jetty.

> wish
Wishing doesn't make it so.

Cold water sluices between the planks of the jetty.

> xyzzy
Nothing happens.

The sea is at your ankles, filling the spaces between the planks
without hurry. It has never once needed to hurry.

> think
You think. Nothing occurs to you.

The sea comes over the planks in one long push and takes you with
it — without malice, without much noticing. High above, the tower
stays dark. Forty years that light burned on every tide of the
year. It does not burn tonight.

*** You have died ***

Your score is 0 of a possible 25, in 4 turns.
```

Nobody wrote a rule for any of those four commands. The stock lines came from the engine, the tide came from a daemon, and the drowning came from a fuse that had been running since turn one.

```sh
printf 'shout\nwish\nxyzzy\nthink\n' | GNUSTO_SEED=0 swift run Lighthouse
```

## The demo games

Seven of them, and they are the engine's real test corpus as well as its documentation — a regression in scope resolution shows up as Zork's thief taking something he could not see.

| Run it | | |
|---|---|---|
| `swift run CloakOfDarkness` | three rooms, a velvet cloak, a message in sawdust | the standard IF acceptance benchmark |
| `swift run Lighthouse` | a rock, a tower, a rising sea, and one job: keep the light | four rooms, twelve moves, one idiom per entity |
| `swift run Gramarye` | an apprentice alone in his master's tower for one morning | four spells in four casting paradigms, all load-bearing |
| `swift run Fulminate` | Pasadena, June 1952 — a rocketry man dies in his own carriage house and you have an hour and four minutes to name the killer | a wall clock and a conversation system |
| `swift run KindlyDeep` | a fall of rock, two clocks that run down, and a mule who follows | thirst and fatigue, and a companion who parks and rejoins |
| `swift run Zork1` | the full 350-point reconstruction | prose reproduced verbatim from the published Zork I source |
| `swift run Dungeon` | the MIT mainframe Zork, the one Zork I was cut down from | 143 rooms so far against a 196-room original, built one region at a time |

**Lighthouse** is the one to read first: containers and a locked door, a fuse and a daemon, a roaming actor, `@Global` state, a content bundle, and two plugins, in a game you can finish in a few minutes. **Dungeon** is the scale test, and it is what finds the bugs a four-room game cannot.

In a real terminal all seven launch a full-screen interpreter — a status bar above a story window that re-wraps as you resize, with arrow-key line editing, history, and scrollback. Piped or redirected runs fall back to plain text automatically, and `GNUSTO_PLAIN=1` forces plain output in a terminal too.

## Optional libraries

Seven separate products you import only if you want them. Each is spliced into a game as content or as a plugin, and a game that declares none of them is unaffected by all of them.

| | |
|---|---|
| `GnustoClock` | a wall clock — a time of day the game is measured against, not a turn counter |
| `GnustoConversation` | asking, telling, showing, and remembering what somebody has already been asked |
| `GnustoScoring` | points, treasures, and a single award table nothing can silently disagree with |
| `GnustoSpellcasting` | four casting paradigms, from at-will cantrip to one-shot scroll |
| `GnustoMeleeCombat` | swinging at something that swings back |
| `GnustoDangerousDark` | the dark that has a grue in it |
| `GnustoActors` | characters who roam, follow, steal, and react |

An eighth product, `GnustoTestSupport`, belongs in a test target: it links the toolchain's Testing library.

## Testing a game

A game is a value and a play session is a function of its typed input, so a test is a list of commands and a check on the transcript:

```swift
let transcript = try await play(Lighthouse(), ["north", "take key", "look"])

#expect(turnOutput(of: "north", in: transcript).contains("On the stone shelf is a brass key."))
#expect(!turnOutput(of: "look", in: transcript).contains("brass key"))
```

That is a real test from this suite, and it checks something a unit test cannot reach: the key is announced on the way in and not again on the way out.

`GNUSTO_SEED` pins the random stream, so a session a player recorded replays turn for turn on your machine and drops straight into a test. See [Testing Your Game](https://heirloomlogic.github.io/gnusto/documentation/gnusto/testingyourgame).

## Play-testing

A transcript test asserts that a line *appears*. It never asks whether the line is *true of the room the player is standing in*. That is how a suite stays green while a character goes on looking at the fire from the bottom of a dark coal cellar.

So every Gnusto game is also a play-test server. An agent opens a session, takes turns, reads back its own transcript, and is told what the game has shown it that it never followed up:

```sh
bin/gnusto-mcp Fulminate       # registered per game in .mcp.json
```

Nothing in your game has to know about this — the switch lives in the `GameMain` extension every game already conforms to. To replay a script non-interactively instead, seed pinned:

```sh
bin/playtest-replay --build Fulminate
bin/playtest-replay Fulminate --commands probe.txt --seed 0
```

[`docs/playtesting.md`](docs/playtesting.md) is how to do it by hand, and it carries the calibration answer key — the defects a round is supposed to find, so a round that finds nothing is a broken harness rather than a clean game.

## Share your game

Conform a game type to `GameMain`, mark it `@main`, and it is an executable. Export a single binary from it:

```sh
bin/export-game Lighthouse       # → dist/Lighthouse
```

On macOS 15+ that binary links the Swift runtime that ships with the OS, so the recipient runs it with no Xcode and no toolchain. `bin/export-game` builds only for the machine you are standing at; pushing a version tag builds every product for macOS and Linux and attaches them to the release. Neither path notarizes, so a downloaded macOS binary stays quarantined until it is cleared — the full workflow is in [Sharing Your Game](https://heirloomlogic.github.io/gnusto/documentation/gnusto/sharingyourgame).

## Documentation

The authoring guides are at **[heirloomlogic.github.io/gnusto](https://heirloomlogic.github.io/gnusto/documentation/gnusto/)** — start with Getting Started, then read Lighthouse. CI publishes them on each version tag.

To build them locally, first `touch .dev-tooling` to enable the dev-only DocC plugin:

```sh
swift package --allow-writing-to-directory .docs-build \
  generate-documentation --target Gnusto --output-path .docs-build
```

Write to `.docs-build`, never to `docs/`. The plugin deletes its output path before writing, and `docs/` is hand-written and tracked.

## Requirements

- Swift 6.2 toolchain, Swift 6 language mode
- macOS 15 or newer, iOS 18 or newer, or Linux. Both Apple floors are `Synchronization.Mutex`.

CI tests on Linux and builds every product for iOS; the release workflow ships macOS and Linux binaries. Beyond Foundation the engine imports `Synchronization` and `Dispatch` and nothing else; every platform-specific call sits behind `#if canImport(Darwin)` in five files, four of them the terminal front end or the play-test transport and the fifth a thread-priority hint. So a game can run wherever you can supply an `IOHandler`. On iOS you supply one rather than let `GameMain` pick; see [Custom Front Ends](https://heirloomlogic.github.io/gnusto/documentation/gnusto/customfrontends).

## Licence

MIT. See [`LICENSE`](LICENSE).

The bundled **Zork1** demo is an original Swift re-implementation of *Zork I: The Great Underground Empire* (Marc Blank, Dave Lebling, Bruce Daniels, and Tim Anderson; Infocom, 1980), and reproduces text from the publicly available [historicalsource/zork1](https://github.com/historicalsource/zork1) collection. It is included for education and historical work, is excluded from published release binaries, and is credited in full in [`THIRD_PARTY_NOTICES`](THIRD_PARTY_NOTICES).
