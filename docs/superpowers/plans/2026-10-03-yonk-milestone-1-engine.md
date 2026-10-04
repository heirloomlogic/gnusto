# Yonk Milestone 1: Engine Changes Implementation Plan

**Status: Superseded; do not execute.** The approved packaging revision in `docs/superpowers/specs/2026-10-03-yonk-design.md` replaces maintained per-game executable targets with library-only games, a reusable GnustoTerminal package and generated terminal/Yonk build packages. It also removes terminal launch behavior from `PackagedGame` and retires `GameMain`. Its replacements are `2026-10-03-yonk-milestone-1a-packaging.md` and `2026-10-03-yonk-milestone-1b-engine.md` in this directory. The remaining content is retained as historical planning material, not an executable plan.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Gnusto the four things the Yonk front end, the Blorple mapper and the Lobal voice interface need from the engine: importable games, a per-turn report, two read-only queries (`vocabulary()` and `mapView()`), and two map hints for authors (`mapRegion` and `.secret`).

**Architecture:** Each demo game's code becomes a library target that exposes one `public let game = PackagedGame { … }`; its executable becomes a two-line `main.swift`. `TurnResult` gains a `report` computed in `GameWorld.perform(_:)` from the internal `TurnAudit` and the player's location before and after. `vocabulary()` and `mapView()` are actor methods that read the world and change nothing. `mapRegion(_:)` is a new `LocationTrait`; `.secret` is a new modifier on `MapEntry`, recorded by the bootstrap into `GameDefinition.secretExits`.

**Tech Stack:** Swift 6.2 tools, SwiftPM, Swift Testing, DocC, swift-format (Persnicket config).

**Spec:** `docs/superpowers/specs/2026-10-03-yonk-design.md`, sections 1.1–1.4 and milestone 1 of section 5.

**One deliberate departure from the spec.** Spec 1.1 says each game type and its `init()` become `public`. A public type conforming to the public `Game` protocol must also make every protocol witness public — `title`, `intro`, `map`, `rules`, `verbs` and the rest, in all seven games and in every game an author ever writes. This plan keeps the game type internal and has each library export one `PackagedGame` value instead. The executable calls `await game.main()`, and a front end calls `Zork1.game.makeGame()`. Task 2 updates the spec's 1.1 and 2.1 to match, so Yonk's per-game app reads `Yonk(Zork1.game)` rather than `Yonk(Zork1.init)`.

## Global Constraints

- Swift tools version stays `6.2`; platform floors stay `.macOS(.v15)` and `.iOS(.v18)`.
- Executable product names do not change: `swift run Zork1`, `bin/gnusto-mcp Zork1`, `bin/playtest-replay`, `bin/playtest-preflight` and `bin/export-game` keep working with the names they use today.
- Nothing new goes under `Sources/Gnusto/Playtest/`: the traits-off build (`--disable-default-traits`) must still compile everything added here.
- Every `public` declaration carries a doc comment, with `- Parameter`/`- Parameters:` and `- Returns:` lines wherever the declaration takes or returns something. The strict lint fails otherwise.
- DocC builds with `--warnings-as-errors`: a double-backtick symbol link may only name a public symbol. Name an internal one in a single-backtick code span.
- Game-target prose follows `ProseConventionTests`: one plain `"""` literal, no `+`, no trailing `\`.
- Markdown is never hard-wrapped: one line per paragraph, one line per list item, one line per table row.
- No deprecated aliases, shims or migration paths for anything replaced.
- `TurnReport`, `WordsInScope`, `RoomMapView` and `MapExit` expose no public initializer; only the engine builds them.
- Before claiming done: `swift test` passes, the strict lint passes, `node .claude/workflows/playtest.dryrun.mjs` passes, and DocC builds with `--warnings-as-errors`.

## Review Focus

- A move the world refuses — a shut gate, a `blocked:` wall, a hidden door, a direction with no exit — must report no movement, even though the parser read a direction. Pinned in Task 4.
- UNDO and RESTART after a walk must report `.relocated`, never a walk back. Pinned in Task 4.
- A teleport into a room that happens to be next door (a rule's `arrive(at:)` into a room an exit also reaches) must report `.teleported`, not a walk. Pinned in Task 4.
- `vocabulary()` asked while a save prompt is open must say the next line is a filename. Pinned in Task 5.
- `mapView()` must not spend a turn or draw from the random stream, however often a front end calls it. Pinned in Task 6.

---

### Task 1: `PackagedGame`, the importable form of a game

**Files:**
- Create: `Sources/Gnusto/IO/PackagedGame.swift`
- Modify: `Sources/Gnusto/IO/GameMain.swift` (lines 22–94: move the body of `main()` into a new internal `ConsoleLaunch`)
- Modify: `Sources/Gnusto/IO/PlaytestMode.swift:42` and `Sources/Gnusto/Playtest/MCPServer.swift:259` (comments that name `GameMain.defaultIOHandler`)
- Modify: `Sources/Gnusto/Documentation.docc/CustomFrontEnds.md`, `Sources/Gnusto/Documentation.docc/Documentation.md`
- Test: `Tests/GnustoTests/PackagedGameTests.swift`

**Interfaces:**
- Consumes: `Game`, `GameWorld.init(game:seed:saveDirectory:)`, `PlaytestServer.serve(game:environment:)`, `REPL`.
- Produces:
  - `public struct PackagedGame: Sendable` with `public init<G: Game>(_ make: @escaping @Sendable () -> G)`, `public var title: String`, `public func makeGame() -> any Game`, `public func main() async`.
  - `enum ConsoleLaunch` (internal) with `static func run<G: Game>(_ make: () -> G) async`.

- [ ] **Step 1: Write the failing test**

Create `Tests/GnustoTests/PackagedGameTests.swift`:

```swift
import Testing

@testable import Gnusto

struct PackagedGameTests {
    @Test func packagedGameBuildsAWorldFromAFreshGame() async throws {
        let packaged = PackagedGame { DialRoomGame() }
        let world = try GameWorld(game: packaged.makeGame(), seed: 0)
        let opening = await world.begin()
        #expect(opening.output.contains("A landing, and a room that keeps changing its mind."))
    }

    @Test func packagedGameReadsTheTitleTheGameDeclares() {
        #expect(PackagedGame { DialRoomGame() }.title == "The Dial Room")
    }
}
```

`DialRoomGame` is the existing fixture in `Tests/GnustoTests/Support/AlwaysDescribedGames.swift`.

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter PackagedGameTests`
Expected: build failure, `cannot find 'PackagedGame' in scope`.

- [ ] **Step 3: Move `main()`'s body into `ConsoleLaunch`**

In `Sources/Gnusto/IO/GameMain.swift`, replace the body of `public static func main() async` with one line, and keep its doc comment. Add one sentence at the end of that doc comment: `` The body is `ConsoleLaunch.run(_:)`, which ``PackagedGame/main()`` runs too. ``

```swift
    public static func main() async {
        await ConsoleLaunch.run(Self.init)
    }
```

Move `defaultIOHandler(world:environment:)` out of the `GameMain` extension into the new enum. Leave `static func run(world:io:transcriptURL:status:)` where it is: `DslQuickWinsTests` calls it on a `GameMain` fixture. Add the enum below the `GameMain` extension in the same file, so it keeps the file's `Darwin`/`Glibc` imports:

```swift
/// Running a game as a console program: the one body that ``GameMain/main()``
/// and ``PackagedGame/main()`` share.
///
/// `--mcp` (or `GNUSTO_MCP`) turns the process into a play-test server when the
/// `Playtest` trait is on, and is refused on standard error when it is off.
/// Otherwise it boots a world, reports bootstrap warnings and bad environment
/// values on standard error, and drives a `REPL` until the game ends.
enum ConsoleLaunch {
    /// Runs the game `make` builds as a console program.
    ///
    /// - Parameter make: builds a fresh instance of the game.
    static func run<G: Game>(_ make: () -> G) async {
        let environment = ProcessInfo.processInfo.environment
        if PlaytestMode.requested(arguments: CommandLine.arguments, environment: environment) {
            #if Playtest
            await PlaytestServer.serve(game: make, environment: environment)
            return
            #else
            writeToStandardError(PlaytestMode.unavailable)
            exit(1)
            #endif
        }
        do {
            let seed = SeedRequest(environment: environment)
            let status = StatusFooter(environment: environment)
            // Unpinned runs go through the unseeded initializer rather than
            // repeating its `UInt64.random` here, so "random by default" stays
            // one policy in one place.
            let world =
                try seed.value.map { try GameWorld(game: make(), seed: $0) }
                ?? GameWorld(game: make())
            // Opens (and, on success, immediately closes) the launch
            // transcript file now, while a failure can still be reported —
            // see the comment below on why that reporting has to happen
            // before the IO handler exists.
            let transcript = TranscriptRequest(world: world, environment: environment)
            // Surface non-fatal bootstrap warnings before the IO handler is
            // built: the full-screen `TerminalIOHandler` enters the alternate
            // screen buffer in its `init`, so a stderr write after that would be
            // painted over. Printing here keeps it on the primary screen, and
            // out of the play transcript (stderr, like the fatal path below).
            if let complaint = seed.complaint {
                writeToStandardError(complaint)
            }
            if let complaint = status.complaint {
                writeToStandardError(complaint)
            }
            if let complaint = transcript.complaint {
                writeToStandardError(complaint)
            }
            if let report = world.definition.warningReport {
                writeToStandardError(report)
            }
            await REPL(
                world: world,
                io: await defaultIOHandler(world: world, environment: environment),
                transcriptURL: transcript.url,
                status: status.inForce
            ).run()
        } catch {
            writeToStandardError("\(error)")
            exit(1)
        }
    }

    // `defaultIOHandler(world:environment:)` moves here unchanged, doc comment
    // included, from the `GameMain` extension.
}
```

The last two lines of that block are an instruction, not code: cut the existing `private static func defaultIOHandler(world:environment:) async -> any IOHandler` and its doc comment from the `GameMain` extension and paste them in their place.

- [ ] **Step 4: Fix the two comments that name the moved function**

In `Sources/Gnusto/IO/PlaytestMode.swift:42` and `Sources/Gnusto/Playtest/MCPServer.swift:259`, change `GameMain.defaultIOHandler` to `ConsoleLaunch.defaultIOHandler`. Check for any other mention:

Run: `grep -rn "GameMain.defaultIOHandler\|GameMain\.main()'s body" Sources Tests`
Expected: no output.

- [ ] **Step 5: Write `PackagedGame`**

Create `Sources/Gnusto/IO/PackagedGame.swift`:

```swift
/// A game packaged for a program that imports it rather than runs it.
///
/// A game's own type stays internal to its library, so nothing outside the
/// library can name it. The library exports one `PackagedGame` instead, and
/// every way of starting the game goes through that value:
///
/// ```swift
/// // Sources/Zork1/Packaged.swift, in the library
/// public let game = PackagedGame { Zork1() }
///
/// // Sources/Zork1Main/main.swift, the executable
/// import Zork1
///
/// await game.main()
///
/// // a front end that imports the library
/// let world = try GameWorld(game: Zork1.game.makeGame())
/// ```
public struct PackagedGame: Sendable {
    private let make: @Sendable () -> any Game
    private let launch: @Sendable () async -> Void

    /// Packages a game.
    ///
    /// - Parameter make: builds a fresh instance of the game. It runs once for
    ///   each world built from it, so every world starts from the game as
    ///   declared.
    public init<G: Game>(_ make: @escaping @Sendable () -> G) {
        self.make = make
        self.launch = { await ConsoleLaunch.run(make) }
    }

    /// The title the game declares.
    public var title: String { make().title }

    /// A fresh instance of the game, to build a ``GameWorld`` from.
    ///
    /// - Returns: a new instance of the packaged game.
    public func makeGame() -> any Game { make() }

    /// Runs the game as a console program, exactly as ``GameMain/main()``
    /// does: `--mcp` and the `GNUSTO_*` environment variables included.
    public func main() async { await launch() }
}
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `swift test --filter PackagedGameTests`
Expected: 2 tests pass.

- [ ] **Step 7: Document it**

In `Sources/Gnusto/Documentation.docc/CustomFrontEnds.md`, add a section directly before `## What the engine needs from the platform`:

```markdown
## Importing a game instead of running it

A front end that is its own program, such as a Mac app, cannot import a game's executable target. Put the game in a library target and export one ``PackagedGame`` from it: `public let game = PackagedGame { MyGame() }`. The game type stays internal, so none of its properties need to be `public`. The executable target is then two lines, `import MyGame` and `await game.main()`, and the front end builds its worlds from `MyGame.game.makeGame()`. Every demo game in this package is built this way, and so is the starter `bin/new-game` writes.
```

In the same file's `## Topics` list, add `- ``PackagedGame``` directly after `- ``GameMain```. In `Sources/Gnusto/Documentation.docc/Documentation.md`, add `- ``PackagedGame``` directly after the `- ``GameMain``` line (line 208).

- [ ] **Step 8: Run the whole suite**

Run: `swift test`
Expected: all tests pass.

- [ ] **Step 9: Commit**

```bash
git add Sources/Gnusto/IO/PackagedGame.swift Sources/Gnusto/IO/GameMain.swift Sources/Gnusto/IO/PlaytestMode.swift Sources/Gnusto/Playtest/MCPServer.swift Sources/Gnusto/Documentation.docc/CustomFrontEnds.md Sources/Gnusto/Documentation.docc/Documentation.md Tests/GnustoTests/PackagedGameTests.swift
git commit -m "feat: add PackagedGame, the importable form of a game"
```

---

### Task 2: Demo games and the starter become importable

**Files:**
- Modify: `Package.swift` (products at lines 70–76; the seven `.executableTarget` blocks from line 159)
- Modify: `Sources/Zork1/Zork1.swift:22-23`, `Sources/Dungeon/Dungeon.swift:22-23`, `Sources/Gramarye/Gramarye.swift:34-35`, `Sources/Fulminate/Fulminate.swift:55-56`, `Sources/KindlyDeep/KindlyDeep.swift:39-40`
- Delete: `Sources/Lighthouse/Entry.swift`, `Sources/CloakOfDarkness/Entry.swift`
- Create: `Sources/<Game>/Packaged.swift` and `Sources/<Game>Main/main.swift` for each of the seven games
- Modify: `bin/templates/Package.swift`, `bin/templates/README.md:40`, `bin/new-game:215-219`
- Delete: `bin/templates/Sources/MyGame/Entry.swift`
- Create: `bin/templates/Sources/MyGame/Packaged.swift`, `bin/templates/Sources/MyGameMain/main.swift`
- Modify: `Sources/Gnusto/Documentation.docc/SharingYourGame.md:13-33`, `.github/workflows/documentation.yml:77-79`
- Modify: `docs/superpowers/specs/2026-10-03-yonk-design.md` (sections 1.1 and 2.1)

**Interfaces:**
- Consumes: `PackagedGame` from Task 1.
- Produces: for each game `X` in `CloakOfDarkness`, `Lighthouse`, `Zork1`, `Dungeon`, `Gramarye`, `Fulminate`, `KindlyDeep`: a library target `X` (module `X`) exporting `public let game: PackagedGame`; a library product `XGame`; an executable target `XMain`; the executable product `X`, unchanged. The starter gets the same shape under `MyGame`, `MyGameGame` and `MyGameMain`.

There is no failing unit test to write first: this task changes package structure, and the existing suite plus the tooling checks below are the test. Every one of them already passes; each must still pass afterwards.

- [ ] **Step 1: Record the baseline**

Run: `swift build 2>&1 | tail -1 && bin/export-game`
Expected: `Build complete!`, then the seven executable product names: CloakOfDarkness, Dungeon, Fulminate, Gramarye, KindlyDeep, Lighthouse, Zork1 (in whatever order the script prints them). Keep the list to compare in Step 8.

- [ ] **Step 2: Rewrite the manifest's game products and targets**

In `Package.swift`, replace the seven `.executable(...)` product lines with:

```swift
        .executable(name: "CloakOfDarkness", targets: ["CloakOfDarknessMain"]),
        .executable(name: "Lighthouse", targets: ["LighthouseMain"]),
        .executable(name: "Zork1", targets: ["Zork1Main"]),
        .executable(name: "Dungeon", targets: ["DungeonMain"]),
        .executable(name: "Gramarye", targets: ["GramaryeMain"]),
        .executable(name: "Fulminate", targets: ["FulminateMain"]),
        .executable(name: "KindlyDeep", targets: ["KindlyDeepMain"]),
        // Each game is also a library, so a program that is not the game's own
        // executable — a Mac front end — can import it. The library exports one
        // `PackagedGame`; see that type for why the game's own type stays internal.
        .library(name: "CloakOfDarknessGame", targets: ["CloakOfDarkness"]),
        .library(name: "LighthouseGame", targets: ["Lighthouse"]),
        .library(name: "Zork1Game", targets: ["Zork1"]),
        .library(name: "DungeonGame", targets: ["Dungeon"]),
        .library(name: "GramaryeGame", targets: ["Gramarye"]),
        .library(name: "FulminateGame", targets: ["Fulminate"]),
        .library(name: "KindlyDeepGame", targets: ["KindlyDeep"]),
```

Then, for each of the seven game targets, change `.executableTarget(` to `.target(` (keep its name, dependencies, plugins and the comment above it) and add an executable target directly after it. For Zork1:

```swift
        .target(
            name: "Zork1",
            dependencies: [
                "Gnusto", "GnustoDangerousDark", "GnustoScoring", "GnustoActors",
                "GnustoMeleeCombat",
            ],
            plugins: devPlugins
        ),
        .executableTarget(
            name: "Zork1Main",
            dependencies: ["Zork1"],
            plugins: devPlugins
        ),
```

Do the same for `CloakOfDarkness`, `Lighthouse`, `Dungeon`, `Gramarye`, `Fulminate` and `KindlyDeep`, each executable named `<Game>Main` and depending only on `"<Game>"`. The `GnustoTests` target's dependency list names the seven game targets, which keep their names, so it does not change.

- [ ] **Step 3: Take `@main` off the five games that carry it**

In each of these files, replace the two lines `@main` / `struct X: Game, GameMain {` with the single line `struct X: Game {`, leaving the doc comment above untouched:

- `Sources/Zork1/Zork1.swift:22-23` → `struct Zork1: Game {`
- `Sources/Dungeon/Dungeon.swift:22-23` → `struct Dungeon: Game {`
- `Sources/Gramarye/Gramarye.swift:34-35` → `struct Gramarye: Game {`
- `Sources/Fulminate/Fulminate.swift:55-56` → `struct Fulminate: Game {`
- `Sources/KindlyDeep/KindlyDeep.swift:39-40` → `struct KindlyDeep: Game {`

Delete `Sources/Lighthouse/Entry.swift` and `Sources/CloakOfDarkness/Entry.swift`.

Check that each doc comment above the five structs still reads truthfully. If one says the type is `@main` or runnable on its own, change that sentence to say the executable lives in `Sources/<Game>Main`.

Run: `grep -rn "@main\|GameMain" Sources/CloakOfDarkness Sources/Lighthouse Sources/Zork1 Sources/Dungeon Sources/Gramarye Sources/Fulminate Sources/KindlyDeep`
Expected: no output.

- [ ] **Step 4: Export each game and give each its executable**

Create `Sources/<Game>/Packaged.swift` for each game. The game's type is `OperaHouse` for CloakOfDarkness, and the target's own name for the other six. Zork1's:

```swift
import Gnusto

/// Zork I, for a program that imports this library rather than running it.
/// `Sources/Zork1Main` runs it as a console game; a front end builds its worlds
/// from `game.makeGame()`.
public let game = PackagedGame { Zork1() }
```

The other six files differ only in the first sentence of the doc comment (name the game: *Cloak of Darkness*, *Lighthouse*, *Dungeon*, *Gramarye*, *Fulminate*, *Kindly Deep*), the `Sources/<Game>Main` path, and the type inside the closure (`OperaHouse()`, `Lighthouse()`, `Dungeon()`, `Gramarye()`, `Fulminate()`, `KindlyDeep()`).

Create `Sources/<Game>Main/main.swift` for each game. Zork1's:

```swift
import Zork1

await game.main()
```

The other six differ only in the module they import.

- [ ] **Step 5: Build, run and test**

Run: `swift build 2>&1 | tail -1`
Expected: `Build complete!`

Run: `printf 'look\nquit\ny\n' | GNUSTO_PLAIN=1 swift run Zork1 2>&1 | head -5`
Expected: Zork I's intro text.

Run: `swift test`
Expected: all tests pass.

- [ ] **Step 6: Give the starter the same shape**

In `bin/templates/Package.swift`, add a `products:` argument between `traits:` and the dependency comment, and replace the `.executableTarget` block:

```swift
    products: [
        .executable(name: "MyGame", targets: ["MyGameMain"]),
        // The game as a library, so a front end can import it. See `PackagedGame`.
        .library(name: "MyGameGame", targets: ["MyGame"]),
    ],
```

```swift
        .target(
            name: "MyGame",
            dependencies: [
                .product(name: "Gnusto", package: "Gnusto"),
                .product(name: "GnustoScoring", package: "Gnusto"),
            ]
        ),
        .executableTarget(
            name: "MyGameMain",
            dependencies: ["MyGame"]
        ),
```

Delete `bin/templates/Sources/MyGame/Entry.swift`. Create `bin/templates/Sources/MyGame/Packaged.swift`:

```swift
import Gnusto

/// The game, for a program that imports this library rather than running it.
/// `Sources/MyGameMain` runs it as a console game; a front end builds its worlds
/// from `game.makeGame()`.
public let game = PackagedGame { MyGame() }
```

Create `bin/templates/Sources/MyGameMain/main.swift`:

```swift
import MyGame

await game.main()
```

In `bin/templates/README.md:40`, replace `- The `@main` entry point via `GameMain`` with:

```markdown
- A library holding the game, exported as one `PackagedGame`, and a two-line executable that runs it
```

In `bin/new-game`, add one line after the `mv` for `Sources/MyGame` (line 215), so the executable directory is renamed too:

```bash
mv "$destination/Sources/MyGameMain" "$destination/Sources/${game}Main"
```

The `sed` pass that follows rewrites `MyGame` inside every file, which turns `MyGameMain` into `<Game>Main` and `MyGameGame` into `<Game>Game`.

- [ ] **Step 7: Prove the starter and the generator**

Run: `swift test --package-path bin/templates`
Expected: the starter's tests pass.

Run:

```bash
rm -rf "$TMPDIR/Zwank" && bin/new-game Zwank "$TMPDIR/Zwank" --dep-path "$PWD" && ls "$TMPDIR/Zwank/Sources" && (cd "$TMPDIR/Zwank" && swift build 2>&1 | tail -1 && bin/export-game)
```

Expected: `Zwank  ZwankMain`, then `Build complete!`, then `Zwank`.

- [ ] **Step 8: Prove the tooling still resolves every game**

Run: `bin/export-game`
Expected: the same seven names as Step 1.

Run: `bin/playtest-preflight Zork1`
Expected: every row green, including `game source` (it resolves `Sources/Zork1`) and the capability list (it walks `Zork1Main` → `Zork1` → its plugins).

Run: `node --test bin/tests/`
Expected: all pass.

- [ ] **Step 9: Update the prose that describes the old shape**

In `Sources/Gnusto/Documentation.docc/SharingYourGame.md`, replace lines 13–33 (the `## Make a game runnable` section, through the paragraph that ends "Begin with <doc:GettingStarted>.") with:

````markdown
## Make a game runnable

A game is a library target and a small executable target. The library holds the game and exports it as one ``PackagedGame``; the game's own type stays internal:

```swift
// Sources/Zork1/Packaged.swift
import Gnusto

public let game = PackagedGame { Zork1() }
```

The executable runs it:

```swift
// Sources/Zork1Main/main.swift
import Zork1

await game.main()
```

In `Package.swift`, the executable product keeps the game's name, so `swift run Zork1` runs it, and a library product (`Zork1Game`) lets another program import it. A Mac front end is the reason to split the two. If you started with `bin/new-game`, this is already wired up. New to Gnusto? Begin with <doc:GettingStarted>.

A game that will never be imported can still be one executable target: mark the game type `@main` and conform it to ``GameMain``, which runs the same code ``PackagedGame/main()`` does.
````

In `.github/workflows/documentation.yml:77-79`, change `ships seven demo executables and a macro target` to `ships seven demo games and a macro target`.

In `docs/superpowers/specs/2026-10-03-yonk-design.md`:
- Replace the first paragraph of section 1.1 (the one beginning "An app cannot import an executable target.") with: `An app cannot import an executable target. Each of the seven demo games moves its code into a library target that exports one value, `public let game = PackagedGame { Zork1() }`, and its executable becomes a two-line `main.swift` that calls `await game.main()`. The game type stays internal: a public type conforming to `Game` would have to make every protocol witness public too. `bin/new-game` and `bin/templates/` produce the same split.`
- Replace the second paragraph of section 1.1 (the one beginning "Constraints:") with: `Constraints: `swift run Zork1`, `bin/gnusto-mcp Zork1`, `bin/playtest-replay`, `bin/playtest-preflight` and every test keep working unchanged, which means the executable *product* names do not change.`
- In section 2.1's code block, change `Yonk(Zork1.init)` to `Yonk(Zork1.game)`.

- [ ] **Step 10: Commit**

```bash
git add -A Package.swift Sources/CloakOfDarkness Sources/CloakOfDarknessMain Sources/Lighthouse Sources/LighthouseMain Sources/Zork1 Sources/Zork1Main Sources/Dungeon Sources/DungeonMain Sources/Gramarye Sources/GramaryeMain Sources/Fulminate Sources/FulminateMain Sources/KindlyDeep Sources/KindlyDeepMain bin/templates bin/new-game Sources/Gnusto/Documentation.docc/SharingYourGame.md .github/workflows/documentation.yml docs/superpowers/specs/2026-10-03-yonk-design.md
git commit -m "feat: make every demo game and the starter importable as a library"
```

---

### Task 3: `mapRegion(_:)` and `.secret`

**Files:**
- Modify: `Sources/Gnusto/Declarations/Traits.swift` (`LocationTrait.Kind` at line 3; new factory after `alwaysDescribed` at line 501)
- Modify: `Sources/Gnusto/Engine/GameDefinition.swift` (`LocationDefinition` at line 31; `GameDefinition` after `reachableRooms`, line ~290)
- Modify: `Sources/Gnusto/Declarations/WorldMap.swift` (`MapEntry` at line 11)
- Modify: `Sources/Gnusto/Engine/Bootstrap.swift` (location diagnostics ~line 353; `claimExit` ~line 425; the map-entry loop ~lines 449–600; the `GameDefinition(` call ~line 1111)
- Modify: `Sources/Zork1/Regions/Maze.swift` (lines 36–134)
- Modify: `Sources/Gnusto/Documentation.docc/WorldMapAndExits.md`, `Sources/Gnusto/Documentation.docc/BootstrapDiagnostics.md`
- Create: `Tests/GnustoTests/Support/MapHintGames.swift`
- Test: `Tests/GnustoTests/MapHintTests.swift`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  - `public func mapRegion(_ label: String) -> LocationTrait`
  - `public var secret: MapEntry { get }` on `MapEntry`
  - `LocationDefinition.mapRegion: String?` (internal)
  - `GameDefinition.secretExits: [EntityID: Set<Direction>]` (internal)

- [ ] **Step 1: Write the fixtures**

Create `Tests/GnustoTests/Support/MapHintGames.swift`:

```swift
import Gnusto

/// The fixture for the two map hints: a pair of maze rooms sharing one
/// `mapRegion`, and a secret exit out of the hall.
struct MapHintGame: Game {
    let title = "Map Hints"
    let intro = "A hall, a hidden stair, and a little maze."

    let hall = Location {
        name("Hall")
        description("A bare hall.")
    }
    let attic = Location {
        name("Attic")
        description("A dusty attic.")
    }
    let mazeA = Location {
        name("Twisty Passage")
        description("Passages twist away.")
        mapRegion("Maze")
    }
    let mazeB = Location {
        name("Twisty Passage")
        description("Passages twist away.")
        mapRegion("Maze")
    }

    var map: WorldMap {
        player.starts(in: hall)
        hall.up(attic).secret
        hall.north(mazeA)
        attic.down(hall)
        mazeA.north(mazeB)
        mazeA.south(hall)
        mazeB.south(mazeA)
    }
}

/// `.secret` on a blocked exit, which can never be walked and so never drawn.
struct SecretBlockedExitGame: Game {
    let title = "Secret Wall"
    let intro = "A hall."

    let hall = Location {
        name("Hall")
        description("A bare hall.")
    }

    var map: WorldMap {
        player.starts(in: hall)
        hall.west(blocked: "The west wall is solid stone.").secret
    }
}

/// `.secret` after a map entry that is not an exit.
struct SecretPlacementGame: Game {
    let title = "Secret Coin"
    let intro = "A hall."

    let hall = Location {
        name("Hall")
        description("A bare hall.")
    }
    let coin = Item {
        name("coin")
    }

    var map: WorldMap {
        player.starts(in: hall)
        coin.starts(in: hall).secret
    }
}

/// A room declaring two regions, and a room declaring a blank one.
struct BadRegionGame: Game {
    let title = "Bad Regions"
    let intro = "Two rooms."

    let hall = Location {
        name("Hall")
        description("A bare hall.")
        mapRegion("Maze")
        mapRegion("Caves")
    }
    let cellar = Location {
        name("Cellar")
        description("A damp cellar.")
        mapRegion("  ")
    }

    var map: WorldMap {
        player.starts(in: hall)
        hall.down(cellar)
        cellar.up(hall)
    }
}
```

- [ ] **Step 2: Write the failing tests**

Create `Tests/GnustoTests/MapHintTests.swift`:

```swift
import Testing

@testable import Gnusto
@testable import Zork1

struct MapHintTests {
    @Test func roomsSharingARegionCarryItsLabel() throws {
        let (definition, _) = try Bootstrap.build(MapHintGame())
        #expect(definition.locations[EntityID("mazeA")]?.mapRegion == "Maze")
        #expect(definition.locations[EntityID("mazeB")]?.mapRegion == "Maze")
        #expect(definition.locations[EntityID("hall")]?.mapRegion == nil)
    }

    @Test func aSecretExitIsRecordedAndAnOrdinaryOneIsNot() throws {
        let (definition, _) = try Bootstrap.build(MapHintGame())
        #expect(definition.secretExits[EntityID("hall")] == [.up])
        #expect(definition.secretExits[EntityID("attic")] == nil)
        // `.secret` changes what a map draws, never where the exit goes.
        guard case .to(let destination)? = definition.exits[EntityID("hall")]?[.up] else {
            Issue.record("the secret exit is not an ordinary exit to the attic")
            return
        }
        #expect(destination == EntityID("attic"))
    }

    @Test func aSecretBlockedExitIsFatal() {
        expectDiagnostic(
            SecretBlockedExitGame(),
            "\"hall\"'s west exit is blocked and declared .secret; a blocked exit is never walked, so it would never be drawn.")
    }

    @Test func secretAfterAnEntryThatIsNotAnExitIsFatal() {
        expectDiagnostic(
            SecretPlacementGame(),
            "the placement of \"coin\" is declared .secret; only an exit can be secret.")
    }

    @Test func aDuplicateOrBlankRegionIsFatal() {
        expectDiagnostic(BadRegionGame(), "location \"hall\" declares mapRegion(…) more than once.")
        expectDiagnostic(BadRegionGame(), "location \"cellar\" declares a whitespace-only mapRegion(…) trait.")
    }

    @Test func zorkOnesMazeIsOneRegion() throws {
        let (definition, _) = try Bootstrap.build(Zork1())
        let maze = definition.locations.filter { $0.value.mapRegion == "Maze" }.keys
        #expect(maze.count == 19)
        #expect(maze.contains(EntityID("ZorkMaze.maze1")))
        #expect(maze.contains(EntityID("ZorkMaze.deadEnd4")))
        #expect(!maze.contains(EntityID("ZorkMaze.gratingRoom")))
    }

    /// Bootstrapping `game` fails, and its diagnostics include `expected`.
    private func expectDiagnostic(
        _ game: some Game, _ expected: String, sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(sourceLocation: sourceLocation) {
            try Bootstrap.build(game)
        } throws: { error in
            (error as? BootstrapError)?.diagnostics.contains(expected) == true
        }
    }
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `swift test --filter MapHintTests`
Expected: build failure, `cannot find 'mapRegion' in scope` and `value of type 'MapEntry' has no member 'secret'`.

- [ ] **Step 4: Add the trait**

In `Sources/Gnusto/Declarations/Traits.swift`, add a case to `LocationTrait.Kind` after `case alwaysDescribed`:

```swift
        case mapRegion(String)
```

Every exhaustive `switch` over `LocationTrait.Kind` now fails to compile until it handles the new case. `LocationDefinition.init(traits:onDuplicate:)` is handled in Step 5; find any other with `grep -rn "case .alwaysDescribed" Sources` and give each a `case .mapRegion:` arm that does what that switch does for a trait it does not care about.

After the `alwaysDescribed` declaration (line 501), add:

```swift
/// Draws this room as part of one shape on a map, with every other room
/// declaring the same label.
///
/// A maze is the case it exists for. Its rooms look alike to the player, and
/// that is the puzzle; a map that drew each one separately, keyed on rooms the
/// player cannot tell apart, would solve it for them. Rooms sharing a label
/// draw as one shape with that label, and moves inside it draw nothing.
///
/// ```swift
/// let maze1 = Location {
///     name("Maze")
///     description(Prose.maze)
///     dark
///     mapRegion("Maze")
/// }
/// ```
///
/// Nothing in the engine reads it: it is reported by ``GameWorld/mapView()``
/// for a front end that draws a map.
///
/// - Parameter label: the name the shape is drawn with.
/// - Returns: the trait.
public func mapRegion(_ label: String) -> LocationTrait {
    LocationTrait(kind: .mapRegion(label))
}
```

Until Task 6 adds `GameWorld/mapView()`, that symbol link does not resolve. Write the last paragraph's link as a code span, `` `GameWorld.mapView()` ``, here; Task 6 Step 7 turns it into a link.

- [ ] **Step 5: Store it on the location definition**

In `Sources/Gnusto/Engine/GameDefinition.swift`, add a stored property to `LocationDefinition` after `isAlwaysDescribed`:

```swift
    /// The map shape this room is drawn as part of, if any. See ``mapRegion(_:)``.
    var mapRegion: String?
```

and a case to its `init(traits:onDuplicate:)` switch, after `case .alwaysDescribed:`:

```swift
            case .mapRegion(let label):
                if mapRegion != nil { onDuplicate("mapRegion(…)") }
                mapRegion = label
```

In `Sources/Gnusto/Engine/Bootstrap.swift`, in the location diagnostics loop (after the `diagnoseBlank(definition.description, …)` call at ~line 354), add:

```swift
            diagnoseBlank(
                definition.mapRegion, on: "location \"\(id)\"", as: "mapRegion(…) trait")
```

- [ ] **Step 6: Add the `.secret` modifier**

In `Sources/Gnusto/Declarations/WorldMap.swift`, add a stored property to `MapEntry` after `let kind: Kind`, and the modifier below it:

```swift
    /// Whether a map leaves this exit undrawn until the player has gone
    /// through it. Set by ``secret``.
    var isSecret = false

    /// This exit, kept off a map until the player has gone through it.
    ///
    /// For an exit that is always open but should still be a surprise: a
    /// passage behind a waterfall, a gap in a hedge. Most games never need it.
    /// A door the game declares `hidden` is already left off a map until it is
    /// revealed, and a conditional exit is left off while its condition is
    /// false.
    ///
    /// ```swift
    /// var map: WorldMap {
    ///     behindFalls.west(hiddenCave).secret
    ///     hiddenCave.east(behindFalls)
    /// }
    /// ```
    ///
    /// It changes nothing about how the exit is walked. Written after anything
    /// that is not an exit, or after a blocked exit, it is a bootstrap error.
    public var secret: MapEntry {
        var entry = self
        entry.isSecret = true
        return entry
    }
```

- [ ] **Step 7: Record secret exits at bootstrap**

In `Sources/Gnusto/Engine/Bootstrap.swift`:

Next to `var exits: [EntityID: [Direction: ExitTarget]] = [:]` (~line 398), add:

```swift
        var secretExits: [EntityID: Set<Direction>] = [:]
```

Give `claimExit` a `secret` parameter, and record or refuse it after filing the exit:

```swift
        func claimExit(
            _ target: ExitTarget, _ direction: Direction, from fromID: EntityID, secret: Bool
        ) {
            if exits[fromID]?[direction] != nil {
                diagnostics.append(
                    "\"\(fromID)\" declares its \(direction) exit more than once.")
            }
            exits[fromID, default: [:]][direction] = target
            guard secret else { return }
            if case .blocked = target {
                diagnostics.append(
                    "\"\(fromID)\"'s \(direction) exit is blocked and declared .secret; "
                        + "a blocked exit is never walked, so it would never be drawn.")
            } else {
                secretExits[fromID, default: []].insert(direction)
            }
        }
```

Pass `secret: entry.isSecret` at each of the five `claimExit(` calls in the map-entry loop (the `.exit`, `.blockedExit`, `.doorExit`, `.conditionalExit` and `.dynamicExit` cases).

At the top of the loop body, before `switch entry.kind {`, add:

```swift
            if entry.isSecret, let subject = nonExitSubject(of: entry) {
                diagnostics.append("\(subject) is declared .secret; only an exit can be secret.")
            }
```

and define the helper beside `claimPlacement`:

```swift
        /// What a map entry that is not an exit declares, in a diagnostic's
        /// words, or `nil` for an exit. Resolves quietly: an unregistered item
        /// is reported by the case that resolves it, not here as well.
        func nonExitSubject(of entry: MapEntry) -> String? {
            switch entry.kind {
            case .exit, .blockedExit, .doorExit, .conditionalExit, .dynamicExit:
                return nil
            case .placement(let item, _):
                return "the placement of \"\(registry.id(for: item)?.raw ?? "an item")\""
            case .playerStart:
                return "player.starts(in:)"
            case .lockKey(let item, _):
                return "the lockedBy entry for \"\(registry.id(for: item)?.raw ?? "an item")\""
            }
        }
```

- [ ] **Step 8: Carry secret exits on the definition**

In `Sources/Gnusto/Engine/GameDefinition.swift`, add directly after `let reachableRooms: Set<EntityID>`:

```swift
    /// The exits declared ``MapEntry/secret``, by room. Nothing in the turn
    /// reads it; ``GameWorld/mapView()`` reports it.
    let secretExits: [EntityID: Set<Direction>]
```

As in Step 4, write ``GameWorld/mapView()`` as the code span `` `GameWorld.mapView()` `` until Task 6.

In `Sources/Gnusto/Engine/Bootstrap.swift`, in the `GameDefinition(` call (~line 1111), add `secretExits: secretExits,` directly after the `reachableRooms: Set(…)` argument and before `globals:`.

- [ ] **Step 9: Run the tests**

Run: `swift test --filter MapHintTests`
Expected: everything passes except `zorkOnesMazeIsOneRegion` (`maze.count` is 0).

- [ ] **Step 10: Mark Zork 1's maze**

The fifteen maze rooms and four dead ends are the `Location` blocks at lines 36–134 of `Sources/Zork1/Regions/Maze.swift`; each ends with a `dark` line. Add `mapRegion("Maze")` after each one:

```bash
perl -pi -e 'if ($. >= 36 && $. <= 134 && /^        dark$/) { $_ .= "        mapRegion(\"Maze\")\n" }' Sources/Zork1/Regions/Maze.swift
grep -c 'mapRegion("Maze")' Sources/Zork1/Regions/Maze.swift
```

Expected: `19`. Then check that `gratingRoom`, `cyclopsRoom`, `treasureRoom` and `strangePassage` were not touched: `git diff Sources/Zork1/Regions/Maze.swift` shows 19 added lines, all above `// MARK: - The grating, cyclops, and treasure`.

The maze is the `ZorkMaze` content bundle, so its entity IDs are namespaced under the bundle type: `ZorkMaze.maze1`, which is what the test names.

- [ ] **Step 11: Run the tests to verify they pass**

Run: `swift test --filter MapHintTests`
Expected: 6 tests pass.

Run: `swift test`
Expected: all tests pass. Zork 1 plays exactly as before: the trait changes no prose and no behavior.

- [ ] **Step 12: Document both hints**

In `Sources/Gnusto/Documentation.docc/WorldMapAndExits.md`, add a section directly before `## Topics`:

```markdown
## Hints for a map

Two declarations exist only for a front end that draws a map as the player explores. Nothing in a turn reads them, and most games need neither.

``mapRegion(_:)`` draws every room declaring the same label as one shape. A maze is the reason: its rooms look alike to the player, and a map that drew each one would solve it for them. Zork 1's nineteen maze rooms each declare `mapRegion("Maze")`.

``MapEntry/secret``, written after an exit, keeps that exit off a map until the player has gone through it: `behindFalls.west(hiddenCave).secret`. A door declared `hidden` is already left off until it is revealed, and a conditional exit while its condition is false, so `.secret` is only for an exit that is always open and should still be a surprise. After a blocked exit, or after anything that is not an exit, it is a bootstrap error.
```

and in the `## Topics` section, add a new group directly after the `### Declaring exits` group:

```markdown
### Hints for a map

- ``mapRegion(_:)``
- ``MapEntry/secret``
```

In `Sources/Gnusto/Documentation.docc/BootstrapDiagnostics.md`, in the Gate 1 table:
- In the row for `location "hall" declares an empty name(…) trait.`, append to the cause cell: ` Also `mapRegion(…)`.`
- In the row for `item "coin" declares name(…) more than once.`, add `mapRegion(…)` to the list of location declarations it covers.
- Add two rows after the row for `"attic" declares its north exit more than once.`:

```markdown
| `"hall"'s west exit is blocked and declared .secret; a blocked exit is never walked, so it would never be drawn.` | ``MapEntry/secret`` hides an exit until the player has gone through it, and nobody goes through a blocked exit. Remove `.secret`. |
| `the placement of "coin" is declared .secret; only an exit can be secret.` | Also `player.starts(in:)` and `the lockedBy entry for "…"`. `.secret` was written after a map entry that is not an exit. Remove it. |
```

- [ ] **Step 13: Commit**

```bash
git add Sources/Gnusto/Declarations/Traits.swift Sources/Gnusto/Declarations/WorldMap.swift Sources/Gnusto/Engine/GameDefinition.swift Sources/Gnusto/Engine/Bootstrap.swift Sources/Zork1/Regions/Maze.swift Sources/Gnusto/Documentation.docc/WorldMapAndExits.md Sources/Gnusto/Documentation.docc/BootstrapDiagnostics.md Tests/GnustoTests/Support/MapHintGames.swift Tests/GnustoTests/MapHintTests.swift
git commit -m "feat: add the mapRegion and .secret map hints"
```

---

### Task 4: The per-turn report

**Files:**
- Create: `Sources/Gnusto/Engine/TurnReport.swift`
- Modify: `Sources/Gnusto/Engine/GameWorld.swift` (`TurnResult` at lines 25–51; `perform(_:)` at lines 249–258)
- Create: `Tests/GnustoTests/Support/CartographyGames.swift`
- Test: `Tests/GnustoTests/TurnReportTests.swift`
- Modify: `Sources/Gnusto/Documentation.docc/CustomFrontEnds.md`

**Interfaces:**
- Consumes: `mapRegion(_:)` and `MapEntry.secret` from Task 3 (the fixture declares both); internal `TurnAudit`, `DefaultActions.engineIntents`, `GameDefinition.exits`, `WorldState.playerLocation`.
- Produces:
  - `public struct TurnReport: Sendable, Equatable` with `understood: Bool`, `unknownWords: [String]`, `movement: TurnReport.Movement?`
  - `public enum TurnReport.Movement: Sendable, Equatable` with `walked(from: EntityID, to: EntityID, direction: Direction)`, `teleported(from: EntityID, to: EntityID)`, `relocated(to: EntityID)`
  - `public internal(set) var report: TurnReport` on `TurnResult`
  - The fixture `CartographyGame`, which Tasks 5 and 6 use.

- [ ] **Step 1: Write the fixture**

Create `Tests/GnustoTests/Support/CartographyGames.swift`:

```swift
import Gnusto

/// The fixture for what a front end reads after each turn: ``TurnReport``,
/// ``GameWorld/vocabulary()`` and ``GameWorld/mapView()``.
///
/// One small house holds one of every kind of exit, so each read is pinned by
/// a walk of a few moves:
///
/// - the hall: a plain exit north; a trap door down, hidden under the rug until
///   it is pushed; a gate east, latched until `unlatch`; a solid wall west;
/// - the kitchen: a plain exit back south, a secret ladder up, and a dynamic
///   exit east whose destination is chosen when it is walked;
/// - the cellar, which is dark;
/// - two rooms of a maze, sharing one `mapRegion`.
///
/// `pray` puts the player in the garden without walking, from anywhere.
struct CartographyGame: Game {
    let title = "Cartography"
    let intro = "A small house, drawn for a map."

    @Global var gateOpen = false

    let hall = Location {
        name("Hall")
        description("A bare hall with a rug on the floor. The kitchen is north, and a gate stands east.")
    }
    let kitchen = Location {
        name("Kitchen")
        description("A cold kitchen. A door opens east.")
    }
    let garden = Location {
        name("Garden")
        description("A walled garden.")
    }
    let cellar = Location {
        name("Cellar")
        description("A damp cellar.")
        dark
    }
    let loft = Location {
        name("Loft")
        description("A low loft under the eaves.")
    }
    let mazeA = Location {
        name("Twisty Passage")
        description("Passages twist away in every direction.")
        mapRegion("Maze")
    }
    let mazeB = Location {
        name("Twisty Passage")
        description("Passages twist away in every direction.")
        mapRegion("Maze")
    }

    let rug = Item {
        name("rug")
        description("A threadbare rug.")
        scenery
    }
    let trapDoor = Item {
        name("trap door")
        openable
        hidden
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("unlatch", intent: Intent("unlatch"))
        SyntaxRule("pray", intent: Intent("pray"))
    }

    var map: WorldMap {
        player.starts(in: hall)
        rug.starts(in: hall)
        hall.north(kitchen)
        hall.down(cellar, via: trapDoor)
        hall.east(garden, when: { gateOpen }, otherwise: "The gate is latched.")
        hall.west(blocked: "The west wall is solid stone.")
        kitchen.south(hall)
        kitchen.up(loft).secret
        kitchen.exit(.east, toward: { mazeA })
        cellar.up(hall, via: trapDoor)
        garden.west(hall)
        loft.down(kitchen)
        mazeA.north(mazeB)
        mazeB.south(mazeA)
        mazeB.west(kitchen)
    }

    var rules: Rules {
        rug.before(.push) {
            trapDoor.reveal()
            try reply("You push the rug aside. There is a trap door under it.")
        }
        world.before(Intent("unlatch")) {
            gateOpen = true
            try reply("You lift the latch.")
        }
        world.before(Intent("pray")) {
            arrive(at: garden)
            try handled()
        }
    }
}
```

- [ ] **Step 2: Write the failing tests**

Create `Tests/GnustoTests/TurnReportTests.swift`:

```swift
import Foundation
import Testing

@testable import Gnusto

struct TurnReportTests {
    private let hall = EntityID("hall")
    private let kitchen = EntityID("kitchen")
    private let cellar = EntityID("cellar")
    private let garden = EntityID("garden")
    private let mazeA = EntityID("mazeA")

    /// A fresh ``CartographyGame`` with its opening already printed, saving
    /// into a directory of its own.
    private func world() async throws -> GameWorld {
        let saves = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let world = try GameWorld(game: CartographyGame(), seed: 0, saveDirectory: saves)
        _ = await world.begin()
        return world
    }

    @Test func aWalkNamesBothRoomsAndTheDirection() async throws {
        let world = try await world()
        let report = await world.perform("north").report
        #expect(report.understood)
        #expect(report.unknownWords.isEmpty)
        #expect(report.movement == .walked(from: hall, to: kitchen, direction: .north))
    }

    @Test func aDynamicExitIsAWalkToWhereverItLed() async throws {
        let world = try await world()
        _ = await world.perform("north")
        #expect(
            await world.perform("east").report.movement
                == .walked(from: kitchen, to: mazeA, direction: .east))
    }

    @Test func enteringADoorByNameIsAWalkInTheDoorsDirection() async throws {
        let world = try await world()
        _ = await world.perform("push rug")
        _ = await world.perform("open trap door")
        #expect(
            await world.perform("enter trap door").report.movement
                == .walked(from: hall, to: cellar, direction: .down))
    }

    @Test func aRuleThatPutsThePlayerNextDoorIsATeleportNotAWalk() async throws {
        let world = try await world()
        // The hall has an exit east to the garden, latched. Praying is not using it.
        #expect(await world.perform("pray").report.movement == .teleported(from: hall, to: garden))
    }

    @Test func aRefusedMoveReportsNoMovement() async throws {
        let world = try await world()
        for line in ["east", "west", "down", "south"] {
            let report = await world.perform(line).report
            #expect(report.understood, "\(line)")
            #expect(report.movement == nil, "\(line)")
        }
    }

    @Test func undoAndRestartAreRelocationsNotWalks() async throws {
        let world = try await world()
        _ = await world.perform("north")
        #expect(await world.perform("undo").report.movement == .relocated(to: hall))
        _ = await world.perform("north")
        #expect(await world.perform("restart").report.movement == .relocated(to: hall))
    }

    @Test func aLineTheGameCannotReadIsNotUnderstood() async throws {
        let world = try await world()
        let report = await world.perform("frotz").report
        #expect(!report.understood)
        #expect(report.unknownWords == ["frotz"])
        #expect(report.movement == nil)
    }

    @Test func theOpeningCarriesAnEmptyReport() async throws {
        let world = try GameWorld(game: CartographyGame(), seed: 0)
        #expect(await world.begin().report == TurnReport())
    }
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `swift test --filter TurnReportTests`
Expected: build failure, `value of type 'TurnResult' has no member 'report'`.

- [ ] **Step 4: Write the report type and its derivation**

Create `Sources/Gnusto/Engine/TurnReport.swift`:

```swift
/// What a turn did besides print: whether the line was understood, and
/// whether the player moved.
///
/// A front end that only prints text never needs this. One that draws a map
/// does. The transcript cannot say which way the player went — `n`, `north` and
/// `go north` are one move, and a refusal names no direction — and a room's
/// name is prose that two rooms may share. ``GameWorld/perform(_:)`` fills it
/// in; ``GameWorld/begin()`` and ``GameWorld/requestQuit()`` leave it empty.
public struct TurnReport: Sendable, Equatable {
    /// How the player came to stand somewhere else when a turn ended.
    public enum Movement: Sendable, Equatable {
        /// The player went out of `from` through an exit: `north`, `go up`,
        /// `enter the trap door`, `follow the troll`. `to` is where the turn
        /// left them, which is the exit's destination unless a rule carried
        /// them on.
        case walked(from: EntityID, to: EntityID, direction: Direction)
        /// The game put the player in `to` without an exit: a rule's
        /// `arrive(at:)`, a spell, a fall.
        case teleported(from: EntityID, to: EntityID)
        /// UNDO, RESTART or RESTORE replaced the world, and the player stands
        /// in `to`. Nothing was walked.
        case relocated(to: EntityID)
    }

    /// Whether the parser got a command out of the line. False for a parse
    /// error, an open clarifying question, and a line that answered an engine
    /// prompt.
    public internal(set) var understood = false

    /// Every word of the line the game has never heard of, in the order typed.
    public internal(set) var unknownWords: [String] = []

    /// How the player's location changed during the turn, or `nil` when they
    /// ended it where they began it. An exit that leads back into the room it
    /// leaves is therefore not reported.
    public internal(set) var movement: Movement?
}

extension GameWorld {
    /// The report for a line just performed.
    ///
    /// - Parameters:
    ///   - audit: what the parser made of the line.
    ///   - origin: where the player stood before the line ran.
    /// - Returns: the turn's report.
    func report(of audit: TurnAudit, from origin: EntityID) -> TurnReport {
        var report = TurnReport()
        report.understood = audit.understood
        report.unknownWords = audit.unknownWords
        report.movement = movement(of: audit, from: origin, to: state.playerLocation)
        return report
    }

    /// How the player got from `origin` to `destination`, or `nil` when the two
    /// are the same room.
    private func movement(
        of audit: TurnAudit, from origin: EntityID, to destination: EntityID
    ) -> TurnReport.Movement? {
        guard destination != origin else { return nil }
        // A prompt's answer (RESTORE's filename, the death prompt's choice) and
        // the engine-level verbs (UNDO, RESTART) swap a whole world in.
        if audit.answeredPrompt || audit.intent.map(DefaultActions.engineIntents.contains) == true {
            return .relocated(to: destination)
        }
        if let direction = audit.direction ?? exitTaken(by: audit, from: origin, to: destination) {
            return .walked(from: origin, to: destination, direction: direction)
        }
        return .teleported(from: origin, to: destination)
    }

    /// The exit ENTER or FOLLOW went through, which the parse cannot name
    /// because the player typed a thing or a person rather than a direction.
    ///
    /// Asked of those two verbs only. Every other directionless move is the
    /// game putting the player somewhere, and a rule that drops them in a room
    /// one exit away has still not walked there.
    private func exitTaken(
        by audit: TurnAudit, from origin: EntityID, to destination: EntityID
    ) -> Direction? {
        guard audit.intent == .board || audit.intent == .follow else { return nil }
        let exits = definition.exits[origin] ?? [:]
        // Fixed compass order, as FOLLOW uses, so two exits onto one room never
        // make the answer depend on dictionary iteration.
        return Direction.allCases.first { direction in
            switch exits[direction] {
            case .to(let target), .door(let target, _), .conditional(let target, _, _):
                return target == destination
            case .blocked, .dynamic, nil:
                return false
            }
        }
    }
}
```

- [ ] **Step 5: Carry the report on `TurnResult` and fill it in**

In `Sources/Gnusto/Engine/GameWorld.swift`, add to `TurnResult` directly after `public let status: StatusLine`:

```swift
    /// What the turn did besides print. See ``TurnReport``.
    public internal(set) var report = TurnReport()
```

Replace `perform(_:)` (lines 249–258, doc comment included) with:

```swift
    /// Parses and performs one line of player input. Parse errors are free:
    /// no rules run and the turn counter doesn't advance. Question-type
    /// errors ("Which do you mean…?") stay open: the next line is first
    /// tried as their answer, and falls back to being a fresh command.
    ///
    /// - Parameter input: one line of player input.
    /// - Returns: the turn's output, status and ``TurnReport``.
    public func perform(_ input: String) -> TurnResult {
        let origin = state.playerLocation
        let (performed, audit) = performAudited(input)
        var result = performed
        result.report = report(of: audit, from: origin)
        return result
    }
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `swift test --filter TurnReportTests`
Expected: 8 tests pass.

- [ ] **Step 7: Run the whole suite**

Run: `swift test`
Expected: all tests pass.

- [ ] **Step 8: Document it**

In `Sources/Gnusto/Documentation.docc/CustomFrontEnds.md`, add a section directly after `## The status line` and its paragraphs (before `## Completion candidates`):

```markdown
## What a turn did

``TurnResult/report`` says what the turn did besides print, for a front end that draws a map or listens for speech. ``TurnReport/understood`` and ``TurnReport/unknownWords`` say how the parser read the line. ``TurnReport/movement`` says whether the player moved, and how: ``TurnReport/Movement/walked(from:to:direction:)`` through an exit, ``TurnReport/Movement/teleported(from:to:)`` when the game put them somewhere, and ``TurnReport/Movement/relocated(to:)`` when UNDO, RESTART or RESTORE replaced the world. Rooms are named by their ``EntityID``, never by display name, for the reason ``StatusLine/locationID`` gives. The report is filled in by ``GameWorld/perform(_:)`` only; the opening and a front end's quit carry an empty one.
```

In the `## Topics` list, add `- ``TurnResult/report``` and `- ``TurnReport``` directly after `- ``TurnResult```.

- [ ] **Step 9: Commit**

```bash
git add Sources/Gnusto/Engine/TurnReport.swift Sources/Gnusto/Engine/GameWorld.swift Sources/Gnusto/Documentation.docc/CustomFrontEnds.md Tests/GnustoTests/Support/CartographyGames.swift Tests/GnustoTests/TurnReportTests.swift
git commit -m "feat: report what each turn did, movement included"
```

---

### Task 5: `vocabulary()`

**Files:**
- Create: `Sources/Gnusto/Engine/GameWorld+Vocabulary.swift`
- Test: `Tests/GnustoTests/VocabularyTests.swift`
- Modify: `Sources/Gnusto/Documentation.docc/CustomFrontEnds.md`

**Interfaces:**
- Consumes: `CartographyGame` from Task 4; internal `GameWorld.currentScope(orders:)`, `GameWorld.pendingPrompt`, `Vocabulary` (`itemLexicons`, `sortedVerbWords`, `sortedDirectionWords`, `prepositions`, `noiseWords`, and the statics `reservedWords`, `conjunctions`, `exclusions`, `possessives`).
- Produces: `public struct WordsInScope: Sendable, Equatable` with `expectsFilename: Bool`, `verbs`, `nouns`, `adjectives`, `directions`, `prepositions`, `filler` (each `[String]`, sorted); `public func vocabulary() -> WordsInScope` on `GameWorld`.

- [ ] **Step 1: Write the failing tests**

Create `Tests/GnustoTests/VocabularyTests.swift`:

```swift
import Foundation
import Testing

@testable import Gnusto

struct VocabularyTests {
    /// A fresh ``CartographyGame`` with its opening already printed, saving
    /// into a directory of its own.
    private func world() async throws -> GameWorld {
        let saves = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let world = try GameWorld(game: CartographyGame(), seed: 0, saveDirectory: saves)
        _ = await world.begin()
        return world
    }

    @Test func everyKindOfWordIsListed() async throws {
        let words = try await world().vocabulary()
        #expect(!words.expectsFilename)
        #expect(words.verbs.contains("take"))
        #expect(words.verbs.contains("undo"))
        #expect(words.verbs.contains("unlatch"))
        #expect(words.nouns.contains("rug"))
        #expect(words.directions.contains("north"))
        #expect(words.directions.contains("n"))
        #expect(words.prepositions.contains("with"))
        #expect(words.filler.contains("the"))
        #expect(words.filler.contains("and"))
        #expect(words.verbs == words.verbs.sorted())
    }

    @Test func aHiddenDoorHasNoWordsUntilItIsRevealed() async throws {
        let world = try await world()
        let before = await world.vocabulary()
        #expect(!before.nouns.contains("door"))
        _ = await world.perform("push rug")
        let after = await world.vocabulary()
        #expect(after.nouns.contains("door"))
        #expect(after.adjectives.contains("trap"))
    }

    @Test func aSavePromptExpectsAFilename() async throws {
        let world = try await world()
        _ = await world.perform("save")
        #expect(await world.vocabulary().expectsFilename)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter VocabularyTests`
Expected: build failure, `value of type 'GameWorld' has no member 'vocabulary'`.

- [ ] **Step 3: Write it**

Create `Sources/Gnusto/Engine/GameWorld+Vocabulary.swift`:

```swift
/// Every word the parser accepts at one moment, sorted by the job it does in
/// a sentence.
///
/// A superset of ``CompletionCandidates``. Tab completion offers the words a
/// player starts or ends a command with; a listener correcting a misheard line
/// has to know that `the`, `with` and `under` are words too, or it will
/// "correct" them. Built by ``GameWorld/vocabulary()``.
public struct WordsInScope: Sendable, Equatable {
    /// Whether the engine is waiting for a save or restore filename. While it
    /// is, the next line is a name, and none of the lists below applies to it.
    public let expectsFilename: Bool
    /// Every verb the game knows, the engine-level ones (`undo`, `save`,
    /// `again`) included.
    public let verbs: [String]
    /// The nouns of everything the player can see now: things, people, and
    /// the doors on this room's exits.
    public let nouns: [String]
    /// The adjectives of the same things.
    public let adjectives: [String]
    /// Every direction word: `north`, `n`, `up`, `in`.
    public let directions: [String]
    /// The words that place a verb's second object: `in`, `on`, `with`,
    /// `under`.
    public let prepositions: [String]
    /// The words the parser drops or reads as grammar rather than as names:
    /// articles, `and`, `but`, `except`, pronouns, possessives, `all`.
    public let filler: [String]
}

extension GameWorld {
    /// Every word the parser accepts right now.
    ///
    /// It reads the world and changes nothing, so a front end may ask after
    /// every turn. It costs one scope walk.
    ///
    /// - Returns: the words, each list sorted.
    public func vocabulary() -> WordsInScope {
        let vocabulary = definition.vocabulary
        var nouns: Set<String> = []
        var adjectives: Set<String> = []
        for id in currentScope(orders: false).visibleItems {
            guard let lexicon = vocabulary.itemLexicons[id] else { continue }
            nouns.formUnion(lexicon.nouns)
            adjectives.formUnion(lexicon.adjectives)
        }
        let filler = vocabulary.noiseWords
            .union(Vocabulary.reservedWords)
            .union(Vocabulary.conjunctions)
            .union(Vocabulary.exclusions)
            .union(Vocabulary.possessives)
        let expectsFilename: Bool
        switch pendingPrompt {
        case .saveFilename, .restoreFilename:
            expectsFilename = true
        default:
            expectsFilename = false
        }
        return WordsInScope(
            expectsFilename: expectsFilename,
            verbs: vocabulary.sortedVerbWords,
            nouns: nouns.sorted(),
            adjectives: adjectives.sorted(),
            directions: vocabulary.sortedDirectionWords,
            prepositions: vocabulary.prepositions.sorted(),
            filler: filler.sorted())
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter VocabularyTests`
Expected: 3 tests pass.

- [ ] **Step 5: Document it**

In `Sources/Gnusto/Documentation.docc/CustomFrontEnds.md`, add at the end of the `## Completion candidates` section:

```markdown
A front end that corrects what a speech recognizer heard needs more than that. ``GameWorld/vocabulary()`` returns ``WordsInScope``: the same verbs, nouns and directions, the adjectives split from the nouns, and the prepositions and filler words Tab completion leaves out, so that `the` and `with` are not mistaken for misheard nouns. ``WordsInScope/expectsFilename`` says when the next line is a save name instead.
```

In the `## Topics` list, add `- ``GameWorld/vocabulary()``` and `- ``WordsInScope``` directly after `- ``CompletionCandidates/Context```.

- [ ] **Step 6: Commit**

```bash
git add Sources/Gnusto/Engine/GameWorld+Vocabulary.swift Sources/Gnusto/Documentation.docc/CustomFrontEnds.md Tests/GnustoTests/VocabularyTests.swift
git commit -m "feat: add GameWorld.vocabulary(), every word the parser accepts now"
```

---

### Task 6: `mapView()`, and the milestone's checks

**Files:**
- Create: `Sources/Gnusto/Engine/GameWorld+MapView.swift`
- Test: `Tests/GnustoTests/MapViewTests.swift`
- Modify: `Sources/Gnusto/Declarations/Traits.swift` and `Sources/Gnusto/Engine/GameDefinition.swift` (turn Task 3's two code spans into links)
- Modify: `Sources/Gnusto/Documentation.docc/CustomFrontEnds.md`

**Interfaces:**
- Consumes: `CartographyGame` from Task 4; `LocationDefinition.mapRegion` and `GameDefinition.secretExits` from Task 3; internal `ExitTarget`, `Visibility.isDark(at:definition:state:)`, `Visibility.isPerceivable(_:definition:state:)`, `TurnFrame(definition:state:descriptionMode:)`, `Ctx.$frame`, `TurnFrame.retire()`.
- Produces:
  - `public struct RoomMapView: Sendable, Equatable` with `id: EntityID`, `name: String`, `region: String?`, `exits: [Direction: MapExit]`
  - `public struct MapExit: Sendable, Equatable` with `kind: MapExit.Kind`, `isSecret: Bool`, and `public enum Kind: Sendable, Equatable { case open, blocked, unknownDestination }`
  - `public func mapView() -> RoomMapView` on `GameWorld`

- [ ] **Step 1: Write the failing tests**

Create `Tests/GnustoTests/MapViewTests.swift`:

```swift
import Testing

@testable import Gnusto

struct MapViewTests {
    private let open = MapExit(kind: .open, isSecret: false)
    private let blocked = MapExit(kind: .blocked, isSecret: false)

    /// A fresh ``CartographyGame`` with its opening already printed.
    private func world() async throws -> GameWorld {
        let world = try GameWorld(game: CartographyGame(), seed: 0)
        _ = await world.begin()
        return world
    }

    @Test func theHallShowsOnlyWhatThePlayerCouldFind() async throws {
        let view = try await world().mapView()
        #expect(view.id == EntityID("hall"))
        #expect(view.name == "Hall")
        #expect(view.region == nil)
        // The trap door is hidden and the gate is latched: neither is drawn yet.
        #expect(view.exits == [.north: open, .west: blocked])
    }

    @Test func aRevealedDoorAndAnOpenedGateAppear() async throws {
        let world = try await world()
        _ = await world.perform("push rug")
        #expect(await world.mapView().exits[.down] == open)
        #expect(await world.mapView().exits[.east] == nil)
        _ = await world.perform("unlatch")
        #expect(await world.mapView().exits[.east] == open)
    }

    @Test func theKitchenFlagsItsSecretAndItsDynamicExit() async throws {
        let world = try await world()
        _ = await world.perform("north")
        #expect(
            await world.mapView().exits == [
                .south: open,
                .up: MapExit(kind: .open, isSecret: true),
                .east: MapExit(kind: .unknownDestination, isSecret: false),
            ])
    }

    @Test func aDarkRoomShowsNoExits() async throws {
        let world = try await world()
        _ = await world.perform("push rug")
        _ = await world.perform("open trap door")
        _ = await world.perform("down")
        let view = await world.mapView()
        #expect(view.id == EntityID("cellar"))
        #expect(view.name == "Cellar")
        #expect(view.exits.isEmpty)
    }

    @Test func aMazeRoomCarriesItsRegion() async throws {
        let world = try await world()
        _ = await world.perform("north")
        _ = await world.perform("east")
        let view = await world.mapView()
        #expect(view.region == "Maze")
        #expect(view.exits == [.north: open])
    }

    @Test func askingCostsNoTurnAndNoRandomness() async throws {
        let world = try await world()
        _ = await world.perform("unlatch")
        let before = await world.snapshot()
        for _ in 0..<5 { _ = await world.mapView() }
        let after = await world.snapshot()
        #expect(after.moves == before.moves)
        #expect(after.rngState == before.rngState)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter MapViewTests`
Expected: build failure, `cannot find 'MapExit' in scope`.

- [ ] **Step 3: Write it**

Create `Sources/Gnusto/Engine/GameWorld+MapView.swift`:

```swift
/// What a map may show of the room the player is standing in.
///
/// It names exits and never says where they lead: a map knows a way out exists,
/// and learns where it goes when the player walks it. What it leaves out is
/// what the player could not know is there. Built by ``GameWorld/mapView()``.
public struct RoomMapView: Sendable, Equatable {
    /// The room, by the ID the game declared it under.
    public let id: EntityID
    /// The room's name, as the status line shows it.
    public let name: String
    /// The ``mapRegion(_:)`` label the room declares, if any.
    public let region: String?
    /// The exits a map may draw, by direction. Empty in a dark room.
    public let exits: [Direction: MapExit]
}

/// One way out of a room, as a map may draw it.
public struct MapExit: Sendable, Equatable {
    /// What kind of way out it is.
    public enum Kind: Sendable, Equatable {
        /// An exit the player can try: a plain exit, a door that is not
        /// hidden (open or shut), or a conditional exit whose condition holds.
        case open
        /// A declared dead end: it refuses with a message every time.
        case blocked
        /// An exit whose destination is chosen when it is walked, so even a
        /// map that has walked it once cannot say where it leads next time.
        case unknownDestination
    }

    /// What kind of way out it is.
    public let kind: Kind
    /// Whether the game declared it ``MapEntry/secret``. A map leaves a secret
    /// exit undrawn until the player has gone through it.
    public let isSecret: Bool
}

extension GameWorld {
    /// What a map may show of the room the player is standing in.
    ///
    /// Left out: a door that is `hidden` and not yet revealed, and a
    /// conditional exit whose condition is false right now. In a dark room,
    /// every exit is left out. It reads the world and changes nothing, so a
    /// front end may ask after every turn.
    ///
    /// - Returns: the room's map view.
    public func mapView() -> RoomMapView {
        let here = state.playerLocation
        let location = definition.locations[here]
        let name = location?.name ?? here.raw
        guard !Visibility.isDark(at: here, definition: definition, state: state) else {
            return RoomMapView(id: here, name: name, region: location?.mapRegion, exits: [:])
        }
        let secret = definition.secretExits[here] ?? []
        // A conditional exit's gate reads the world through `Ctx.current`, so
        // it needs a frame. Built over the live state and discarded rather than
        // committed, as `statusFields()` does: nothing a gate writes survives.
        let scratch = TurnFrame(definition: definition, state: state, descriptionMode: .brief)
        let exits = Ctx.$frame.withValue(scratch) { () -> [Direction: MapExit] in
            var exits: [Direction: MapExit] = [:]
            for (direction, target) in definition.exits[here] ?? [:] {
                guard let kind = mapKind(of: target) else { continue }
                exits[direction] = MapExit(kind: kind, isSecret: secret.contains(direction))
            }
            return exits
        }
        _ = scratch.retire()
        return RoomMapView(id: here, name: name, region: location?.mapRegion, exits: exits)
    }

    /// How a map draws one declared exit, or `nil` when it does not draw it
    /// at all. Runs a conditional exit's gate, so it must be called inside a
    /// bound frame and never while holding that frame's lock.
    private func mapKind(of target: ExitTarget) -> MapExit.Kind? {
        switch target {
        case .to:
            return .open
        case .blocked:
            return .blocked
        case .door(_, let door):
            return Visibility.isPerceivable(door, definition: definition, state: state) ? .open : nil
        case .conditional(_, let condition, _):
            return condition() ? .open : nil
        case .dynamic:
            // Not run: its destination is the one thing a map must not learn
            // before the player walks it.
            return .unknownDestination
        }
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter MapViewTests`
Expected: 6 tests pass.

- [ ] **Step 5: Turn Task 3's code spans into links**

In `Sources/Gnusto/Declarations/Traits.swift` (the `mapRegion(_:)` doc comment) and `Sources/Gnusto/Engine/GameDefinition.swift` (the `secretExits` doc comment), replace `` `GameWorld.mapView()` `` with ``` ``GameWorld/mapView()`` ```.

- [ ] **Step 6: Document it**

In `Sources/Gnusto/Documentation.docc/CustomFrontEnds.md`, add at the end of the `## What a turn did` section (from Task 4):

```markdown
A map also needs to know what to draw around the room the player is in. ``GameWorld/mapView()`` returns a ``RoomMapView``: the room's ID and name, its ``mapRegion(_:)`` label, and the exits a map may show, each a ``MapExit``. It never says where an exit leads; a map learns that from ``TurnReport/movement`` when the player walks it. It leaves out a hidden door until it is revealed, a conditional exit while its condition is false, and every exit of a dark room. It flags an exit declared ``MapEntry/secret``, which a map should not draw until it has been walked.
```

In the `## Topics` list, add `- ``GameWorld/mapView()```, `- ``RoomMapView``` and `- ``MapExit``` directly after `- ``TurnReport```.

- [ ] **Step 7: Commit**

```bash
git add Sources/Gnusto/Engine/GameWorld+MapView.swift Sources/Gnusto/Declarations/Traits.swift Sources/Gnusto/Engine/GameDefinition.swift Sources/Gnusto/Documentation.docc/CustomFrontEnds.md Tests/GnustoTests/MapViewTests.swift
git commit -m "feat: add GameWorld.mapView(), what a map may show of this room"
```

- [ ] **Step 8: Run every check CI runs**

Run: `swift test`
Expected: all tests pass.

Run: `swift build --disable-default-traits 2>&1 | tail -1`
Expected: `Build complete!` (nothing added lives under `Playtest/`).

Run: `.build/checkouts/Persnicket/bin/ci-lint-setup && xcrun swift-format lint --strict --parallel --recursive --configuration .swift-format Sources Tests`
Expected: no output. If it reports anything, fix it, re-run, and commit the fix as `style: satisfy the strict lint`.

Run: `node .claude/workflows/playtest.dryrun.mjs`
Expected: passes.

Run: `swift package --allow-writing-to-directory .context/docs generate-documentation --target Gnusto --output-path .context/docs --warnings-as-errors`
Expected: `Finished building documentation` with no warnings. A warning here is almost always a double-backtick link to an internal symbol; change it to a single-backtick code span.

Run: `bin/playtest-preflight Zork1`
Expected: every row green.
