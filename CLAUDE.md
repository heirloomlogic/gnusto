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
| `Sources/CloakOfDarkness`, `Lighthouse`, `Zork1`, `Gramarye`, `Fulminate`, `KindlyDeep`, `Dungeon` | demo games, also the engine's real test corpus. `Dungeon` (mainframe Zork) is built one milestone at a time and **adapts** its prose where the others reproduce or invent — read `FIDELITY.md`'s Dungeon section before writing a line of it |
| `Tests/GnustoTests/` | one suite per subject; `Support/` holds the fixture games |
| `docs/games/*.md` | per-game design docs — **story-and-copy source of truth**, iterated separately from code. Not every game has one; alongside each, its play-test round reports and ledger |
| `docs/playtesting.md` | how to play a game by hand and read the transcript as prose, plus the calibration answer key |
| `.claude/skills/playtest/`, `.claude/workflows/playtest.js` | the automated play-test harness: subagents play, read prose, and report lines untrue of their frame |
| `bin/playtest-replay` | one-line non-interactive replay of any game, seed pinned |
| `FIDELITY.md` | Zork 1 and Dungeon only: where their content departs from the original. Nothing else uses it. The two do **not** share a prose rule: Zork 1 reproduces verbatim, Dungeon adapts, and the Dungeon section states its rule before any region entry |

## Commands

```sh
swift build
swift test                                    # ~1,060 tests, sub-second
swift test --filter FulminateTests
swift run Fulminate                            # pipe stdin to play scripted; GNUSTO_PLAIN=1 forces plain output
swift package --allow-writing-to-package-directory format-source-code

.build/checkouts/Persnicket/bin/ci-lint-setup  # once per checkout — generates .swift-format
xcrun swift-format lint --strict --parallel --recursive --configuration .swift-format Sources Tests

bin/playtest-replay --build Fulminate                              # once
bin/playtest-replay Fulminate --commands probe.txt --seed 0 --label mine --tail 60
```

CI runs the strict lint. Run it before you claim done.

**`.swift-format` is gitignored and generated, not checked in.** The lint fails with
*"Unable to read configuration"* in a fresh checkout until `ci-lint-setup` writes it,
and that script lives in the Persnicket checkout — so `swift build` (or `swift package
resolve`) has to have run first. `.dev-tooling` is the sentinel that turns the dev
plugins on; CI touches it, and a workspace that has it already is set. See
`.github/workflows/lint.yml`, which is the authority on the sequence.

`GNUSTO_SEED` pins a binary's random stream the way `play(_:_:seed:)` pins a test's, so
a hand-played session replays as a test. `GNUSTO_TRANSCRIPT` records it,
`GNUSTO_SAVE_DIR` keeps scripted saves out of your real slots, `GNUSTO_STATUS=1` appends
a `[status] room=… | moves=… | turn=cost|free | …` line to every turn (a `REPL`
argument, not an environment read — the suite is unaffected), and a line starting `//`
or `#` is a tester comment that never reaches the parser. See `docs/playtesting.md`.

`GNUSTO_SEED` also seeds the **suite**: it supplies the seed for every `play(_:_:)` call
that passed none of its own, and leaves the calls that did pin one alone. That is what
makes a sweep possible — `for s in $(seq 0 99); do GNUSTO_SEED=$s swift test; done` finds
an unpinned test that only passes when the dice are kind. A sweep is a band, not a proof;
for one suspect route, a throwaway scratch test over thousands of seeds is far more
sensitive. See `TestingYourGame.md`, "Sweep for tests that pass by luck".

## Reading order for a new task

- **Any game work** — `Sources/Lighthouse/` is the feature tour and the shortest complete read.
  For a companion actor or a survival clock, `Sources/KindlyDeep/` is the worked example:
  a follow daemon that parks and rejoins, and two failing clocks built from one helper.
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

**A bundle's entity IDs are namespaced under its type**, so two bundles may use the
same property name freely — `DungeonCellar.chasm` and `DungeonRoundRoom.chasm` are
different entities and neither shadows the other. What is fatal is two bundles
sharing a *namespace* (two instances of one type — override `var namespace`), and a
bundle the game stores but forgets to list in `content`, which registers nothing it
declares.

Rule phases by scope, all filed in `Engine/Bootstrap.swift`:

| Scope | Phases |
|---|---|
| item / actor | `before`, `after`, `describe`, `presence`, `reach` |
| location | `before`, `after`, `beforeEachTurn`, `afterEachTurn`, `onEnter`, `describe` |
| world | `before`, `after` |

In any rule body: `say`, `refuse`, `reply`, `handled`, `require(_:else:)`, `end(won:)`, `die`,
`describeSurroundings`, `arrive(at:)`, `enter(_:)`, `proceed`.
`refuse`/`reply`/`handled`/`end`/`die` are `throws -> Never`.
`gameText` is the stock line table this turn is being spoken from — write that, never a
bare `text`, which inside a `Game`'s `rules` reaches the game's own (usually computed)
property and rebuilds the whole table. A `GameContent`/`GamePlugin` has no `text` at all.
Same root cause one scope up: a constant prose table is a `static let = { … }()`, never a
computed `static var`, which rebuilds it on every read.

## Gotchas that cost real time

- **Two description channels, not one.** `description(…)` / `describe { }` is the
  *examine* text. `firstSight(…)` / `presence { }` is the *room-listing* paragraph.
  On an item the listing line prints until the player touches it; on an actor it
  prints on every look, forever. The listing line covers every place the room
  lists the thing — on the floor, on a surface, or one level down inside a
  container — so a nested item says its own sentence instead of the stock "In the
  X is a Y." Only one level, though: a room lists what stands in it and what
  those hold, never what *their* contents hold — and the bootstrap **warns**
  for a listing line the map buries below that, naming the holder chain, so a
  line that can never print says so at build time.
- **A static trait and its rule are mutually exclusive** — `description(…)` plus
  `describe { }`, or `firstSight(…)` plus `presence { }`, on one entity is a fatal
  `BootstrapError`. So is declaring the rule twice. Precedence for descriptions:
  runtime assignment > rule > static trait. Presence has no runtime setter.
- **A revisited room is described briefly.** UNDO, RESTORE and walking back in
  through an exit all re-describe as an *entry*, which prints the room name and
  the item paragraphs but skips `description(…)`/`describe { }`. For a room whose
  description **is** the state (a sliding-block floor, a mirror box), declare
  `alwaysDescribed` on the `Location` and it prints every time. The mirror
  problem: `describeSurroundings()` is always a full LOOK, so a rule that moves
  the player *within* one room reprints the heading — pass
  `describeSurroundings(withRoomName: false)`.
- **A rule that moves the player between rooms picks one of two moves.**
  `arrive(at:)` is the `player.location = ` + `describeSurroundings()` pair
  written once: a teleport, so it fires no `onEnter`, carries no boarded vehicle,
  and describes as a full LOOK every time. `try enter(_:)` is the walk — it runs
  the destination's `onEnter` rules, brings a boarded vehicle and its cargo, and
  describes as an *entry* (brief on a revisit, so a room whose description is its
  state wants `alwaysDescribed`). It `throws` because those rules may. Neither
  ends the turn, so both are as legal in a daemon or an `after` rule as in a
  `before` one, and the caller says how the turn finishes. Use `arrive` when the
  game is *putting* the player somewhere and `enter` when the fiction is that
  they walked; `enter` back into the room a rule is already running for
  re-enters the engine, and traps.
- **A live-text closure must never ask for its own text.** `describe { }` and
  `presence { }` are called *from inside* the call producing the text, so
  `describeSurroundings()`, `arrive(at:)` **or a plain read of the entity's own
  `description`** all land back on the closure. That last one is the easy
  mistake — `chest.describe { "\(chest.description) It is scratched." }` is not
  a way to augment the declared text, it is infinite recursion, and the two
  are mutually exclusive anyway so there is no declared text to read. Same
  family as `onEnter` calling `enter` on its own room. All of it used to die in
  an unattributed `signal 10` naming no game and no room; the engine now counts
  the nesting at the two seams where it calls author code and traps by name
  (`TurnFrame.nested(_:within:_:)`, caps on `Reentry`). There are two caps
  because a describer level costs twenty times a walk level; both are bracketed
  by measurement at each end — read `Reentry.cap` before moving either.
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
- **A custom verb nothing answers is also free.** A declared intent with no action,
  no matching rule and no stub line reaches stage 4's last resort: `text.cantDoThat`
  ("You can't do that."), thrown as `TurnInterrupt.unhandled`, which skips the `after`
  rules and every part of `finishTurn` that costs — no each-turn rules, no timer tick,
  no move, and the UNDO snapshot is left where it was.
- **Overriding a stub verb is silent; overriding a core verb warns.** Bootstrap keys
  the warning off `coreTable`, so `action(.dig)` or a rule on `.attack` costs you
  nothing. Promote a stub with `reply`/`refuse` — stage 4 uses `say`, so a rule that
  only `say`s prints *both* lines.
- **To change a stub's words, assign the line; a row buys the whole default.**
  `DefaultActions.run` returns from an `actionOverrides` hit *before*
  `requireReach`, so `action(.squeeze) { try reply(…) }` silently gives up the
  reach guard, the object's rendered name, its number agreement and the
  `yourself`/`somebodyElse` guards. `text.stubs.squeeze = …` keeps all four and
  is what the play-test survey measures. A row means *this game has behavior
  here*; if all it has is a sentence, assign the sentence. The line takes either
  spelling — `text.stubs.sit = "…"` or
  `text.stubs.sit = .naming(orBare: "…") { "You can't sit on \($0)." }` — so
  wanting the object's name has stopped being a reason to reach for a row. A
  plugin that claims a verb owns its register too — `GnustoMeleeCombat` answers
  `.attack`, so `MeleeCombat(text:)` is where that verb's voice lives, not
  `text.stubs.attack`.
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
  described>` is a **bug**, not stock behavior. SEARCH and OPEN also **name a
  `scenery` fitting the room listing withholds** — deliberately; see the
  `scenery` doc comment for why the two disagree.
- **`enter X` / `go through X` is one intent, `.board`, and it does two jobs**:
  a **door** on an exit of the room the player is standing in takes that exit
  (`travel` answers, so a shut door refuses in the same words `go` does), an
  `enterable` is a vehicle and admits them, anything else gets `cantEnterThat`.
  So a door is a way through by name as well as by direction, and a game does
  **not** want its own `#verb` for "go through" — two files in this repo had
  independently minted one before the engine had the word.
- **Containment is room-granular; `reach { }` is the escape hatch.** A thing in one
  square of a floor the player walks around inside is "in the room" from every
  square. `item.reach(otherwise: "…") { … }` narrows that once, for every verb that
  has to *touch* it, and gates `Item.isReachable` too. It runs at **stage 0**,
  ahead of every `before` rule — so it refuses *before* a verb's own complaints,
  where containment refuses after them. Which slots an intent needs is the `reach:`
  column of `cores` and `stubs`; a custom intent is `.notNeeded`.
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

A `fatalError` trap is asserted with `expectTrap`, over a Swift Testing exit test —
a child process per call, so read its doc comment for when that is worth spending.
`TestingYourGame.md` teaches it.

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
