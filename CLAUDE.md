# Gnusto — orientation for agents

Gnusto is a Swift engine for parser IF (Zork-style text adventures). A game is one
Swift type: you declare rooms, things and rules; the engine parses input, runs the
turn, prints the result.

This file is a map, not a manual. The DocC articles in
`Sources/Gnusto/Documentation.docc/` are the manual and are accurate — read the one
that covers your task before writing code.

## Layout

| Path | What |
|---|---|
| `Sources/Gnusto/` | the engine. `Declarations/` is the author-facing DSL; `Engine/` is the runtime; `Actions/` is verbs, default actions and player-facing text; `Parser/` is the parser and vocabulary |
| `Sources/Gnusto*/` | optional libraries spliced in as `GameContent`/`GamePlugin`: `GnustoClock`, `GnustoConversation`, `GnustoScoring`, `GnustoSpellcasting`, `GnustoMeleeCombat`, `GnustoDangerousDark`, `GnustoActors`. Plus `GnustoMacros` (the `#verb` macro) and `GnustoTestSupport` (the `play` harness) |
| `Sources/CloakOfDarkness`, `Lighthouse`, `Zork1`, `Gramarye`, `Fulminate` | demo games, also the engine's real test corpus |
| `Tests/GnustoTests/` | one suite per subject; `Support/` holds the fixture games |
| `docs/games/*.md` | per-game design docs — **story-and-copy source of truth**, iterated separately from code. Not every game has one; alongside each, its play-test round reports and ledger |
| `docs/playtesting.md` | how to play a game by hand and read the transcript as prose, plus the calibration answer key |
| `.claude/skills/playtest/`, `.claude/workflows/playtest.js` | the automated play-test harness: subagents play, read prose, and report lines untrue of their frame |
| `bin/playtest-replay` | one-line non-interactive replay of any game, seed pinned |
| `FIDELITY.md` | Zork 1 only: where its content departs from the original. Nothing else uses it |

## Commands

```sh
swift build
swift test                                    # ~880 tests, sub-second
swift test --filter FulminateTests
swift run Fulminate                            # pipe stdin to play scripted; GNUSTO_PLAIN=1 forces plain output
swift package --allow-writing-to-package-directory format-source-code
xcrun swift-format lint --strict --parallel --recursive --configuration .swift-format Sources Tests

bin/playtest-replay --build Fulminate                              # once
bin/playtest-replay Fulminate --commands probe.txt --seed 0 --tail 60
```

CI runs the strict lint. Run it before you claim done.

`GNUSTO_SEED` pins a binary's random stream the way `play(_:_:seed:)` pins a test's, so
a hand-played session replays as a test. `GNUSTO_TRANSCRIPT` records it,
`GNUSTO_SAVE_DIR` keeps scripted saves out of your real slots, and a line starting `//`
or `#` is a tester comment that never reaches the parser. See `docs/playtesting.md`.

## Reading order for a new task

- **Any game work** — `Sources/Lighthouse/` is the feature tour and the shortest complete read.
- New verb → `AddingCustomVerbs.md`, then `StubVerbs.md`. Rules → `WritingRules.md`.
  Turn order → `TheTurnPipeline.md`.
- Actors → `ActorsAndVehicles.md`. Plugins/bundles → `Plugins.md`, `ContentBundles.md`.
- Tests → `TestingYourGame.md`.
- The built-in verb table is two declaration arrays, one per file, each stating its
  intent once and deriving the rest. `Actions/CoreVerbs.swift` holds `cores` — the
  ~31 intents the engine backs with behavior — and derives `SyntaxRule.coreTable`,
  `builtInIntents`, `engineIntents` and the stage-4 dispatch from it; the handler
  bodies stay in `Actions/DefaultActions.swift`. `Actions/StubVerbs.swift` holds
  `stubs` — ~47 intents that are words with one line of prose and no mechanic — and
  derives `stubTable` and `stubIntents`; their copy is `GameText.stubs`.
  `SyntaxRule.standardTable` is both tables. The intent constants are split the same
  way: core in `Actions/Command.swift`, stub in `Actions/StubVerbs.swift`. Stock
  lines are `Actions/GameText.swift`.

## The shape of a game

```swift
struct MyGame: Game {
    let title = "…"; let intro = "…"
    let hall = Location { name("Hall"); description("…") }
    let coin = Item { name("gold coin") }
    var content: GameContents { clock; talk }        // optional libraries
    var verbs: [SyntaxRule] { [.accuse] }            // custom verbs
    var actions: [IntentAction] { … }                // verb-wide default behavior
    var timers: [TimedEvent] { … }                   // fuses, daemons, clock alarms
    var rules: Rules { … }                           // per-entity behavior
    var map: WorldMap { hall.north(other); player.starts(in: hall) }
}
```

**Entities must be stored properties of the `Game` (or a `GameContent`) type's main
body.** The bootstrap finds them by reflection and names each `EntityID` after its
property. Not extensions — Swift won't allow stored properties there, and `Mirror`
won't see them. Same for `@Global`. This is why big games use `GameContent` bundles
rather than extensions.

Rule phases by scope, all filed in `Engine/Bootstrap.swift`:

| Scope | Phases |
|---|---|
| item / actor | `before`, `after`, `describe`, `presence` |
| location | `before`, `after`, `beforeEachTurn`, `afterEachTurn`, `onEnter`, `describe` |
| world | `before`, `after` |

In any rule body: `say`, `refuse`, `reply`, `require(_:else:)`, `end(won:)`, `die`,
`describeSurroundings`, `proceed`. `refuse`/`reply`/`end`/`die` are `throws -> Never`.

## Gotchas that cost real time

- **Two description channels, not one.** `description(…)` / `describe { }` is the
  *examine* text. `firstSight(…)` / `presence { }` is the *room-listing* paragraph.
  On an item the listing line prints until the player touches it; on an actor it
  prints on every look, forever.
- **A static trait and its rule are mutually exclusive** — `description(…)` plus
  `describe { }`, or `firstSight(…)` plus `presence { }`, on one entity is a fatal
  `BootstrapError`. So is declaring the rule twice. Precedence for descriptions:
  runtime assignment > rule > static trait. Presence has no runtime setter.
- **`onEnter` runs *after* the player has moved.** It cannot block entry. To block a
  move, use `sourceRoom.before(.go)` + `guard command.direction` + `refuse`, or a
  conditional exit `exit(_:to:when:otherwise:)` whose `when:` closure is evaluated in
  the live turn frame.
- **Actors are always listed** if perceivable. `scenery` has no effect on them; only
  `hidden`-and-unrevealed or offstage suppresses one.
- **`reveal()` is one-way** and `isTouched` is read-only — neither is a toggle.
- **`maxScore` is checked against the `Scoring` award table.** `Scoring(awards:)` is the
  one place a register's points are written — `awardOnce("beacon")` and
  `visit(_:register:)` read them from there, and an unlisted register is a `fatalError`,
  not a silent zero. The bootstrap adds the table to every treasure's
  `.takeValue`/`.depositValue` and warns when the total misses `maxScore`. Content that
  declares nothing (an empty table, no valued treasures) opts out.
- **Meta intents and parse failures cost no turn** (`Command.metaIntents`,
  `freeReply`). A test that counts turns by counting commands will be wrong the
  moment one of them fails to parse. This is the single most common test-timing bug.
  A **stub verb does** cost a turn, so `sing` or `xyzzy` is not a free line — use
  `frotz` when a test needs a guaranteed parse error.
- **Overriding a stub verb is silent; overriding a core verb warns.** Bootstrap keys
  the warning off `coreTable`, so `action(.dig)` or a rule on `.attack` costs you
  nothing. Promote a stub with `reply`/`refuse` — stage 4 uses `say`, so a rule that
  only `say`s prints *both* lines.
- **UNDO, RESTART, SAVE and RESTORE can't be overridden at all.** `GameWorld.run`
  answers them before the pipeline, so no rule sees them and `action(.save)` never
  runs. That's `DefaultActions.engineIntents`, and declaring one now warns rather
  than failing silently.
- **`search X` / `find X` / `look for X` all mean `.lookIn`**, which refuses in a
  fixed order: `cantReach` for something out of reach, `cantSearchActor` for a
  person, then `nothingToSearch` ("You find nothing of interest in the X") for
  anything that isn't a `container`. An item you want searchable must be declared
  `container`. `cantSeeAnySuchThing` is reserved for a noun that isn't in scope at
  all, so "You can't see any such thing" in answer to `search <a thing the room just
  described>` is a **bug**, not stock behavior.
- **The player is an entity**, synthesized by the bootstrap as `EntityID.player` and
  reachable as `player.item`. It answers to `me`/`myself`/`self`, is always in scope,
  and is placed nowhere — so it never appears in a room listing, an inventory, or
  `take all`. Its `isActor` is true, but `definition.actorIDs` (the *cast*) excludes
  it, because every consumer of that set means somebody else.
- **A `GameText` closure gets a rendered phrase, not a bare name** — `"the troll"`,
  `"a troll"`, `"Mrs. Vane"`. The article is the engine's, chosen from the
  `properName` trait; a template that writes its own says "the Mrs. Vane". Open a
  line with `GameText.sentenceCase($0)`, never `"The \($0)"`. A capitalized
  item/actor name without `properName` warns at bootstrap (locations are exempt).
- **Every noun a room description prints must be answerable.** A named thing the
  parser doesn't know reads as a bug; add the scenery item with the noun. Item
  vocabulary comes from `name` and `synonyms` (each a noun phrase: last word =
  noun, earlier words = adjectives) plus `adjectives`. The final token of a
  phrase must be a noun.
- **One splitter, both sides.** `Vocabulary.words(in:)` splits every declared
  phrase exactly as `StandardParser.tokenize` splits player input — lowercased, a
  trailing `'s` dropped, every other non-alphanumeric a separator. So
  `adjectives("master's")` and `adjectives("master")` are the same declaration;
  write the second. A declared word with no letters or digits in it, or one made
  of nothing but filler, is a **fatal** bootstrap diagnostic.
- **`clock.now` needs a live turn** — legal in rules, `describe` blocks and actions;
  not in a `map` block, which runs at bootstrap.
- Bootstrap diagnostics are thorough and fatal. If a game fails to start, read the
  diagnostic list — it names the entity and the conflict.

## Testing conventions

Transcript tests, almost exclusively: `play(Game(), ["cmd", …], seed:)` returns the
whole transcript as a string, then `#expect(...contains(...))`. Helpers in
`GnustoTestSupport`: `play`, `turnOutput(of:in:)` (one turn's output — matches the
*first* occurrence, so vary commands rather than repeating them), `expectInOrder`,
`cachedWorld`. For bootstrap diagnostics, call `Bootstrap.build(BadGame())` directly
and inspect `BootstrapError.diagnostics`.

Assertions are dense substring checks lifted from the prose, so **the game suites are
heavily prose-coupled**: changing a line usually means updating a test. Before
rewriting copy, grep the fragment. Fixture games live in `Tests/GnustoTests/Support/`.

## Working on a demo game

Read `docs/games/<game>.md` first, if there is one. It owns the story, the copy, and a
**mechanics contract** stating which counts and structures may not change even though
all prose may. Alongside it, `<game>-playtest-*.md` is what the last round found and
`<game>-playtest-ledger.md` is every finding ever filed. Commit doc changes with the
code. Then actually play the game
(`swift run <Game>` with piped stdin) and read the transcript as prose: passing tests
do not tell you whether a line is true of where the player is standing.
