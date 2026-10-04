# Yonk Milestone 1A: Game Packaging and Terminal Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** Milestones 1A and 1B are implemented, with engine/terminal qualification recorded at root `1c3717aa` and companion `827956bb`. The final cache, deployment-trait and documentation fixes are implemented and focused local qualification has passed; the single scoped re-review, latest-source hosted Linux/macOS qualification and native Terminal visual acceptance remain pending. Companion documentation is locally updated at `6c051a49`; public companion remains `827956bb` until coordinated publication. Release compatibility, immutable versions, signing, notarization and upload are separate unperformed handoff checks. Yonk, Blorple and Lobal remain future milestones.

**Tracking:** Checked implementation steps record the delivered code and local task evidence in `.superpowers/sdd/2026-10-03-yonk-milestone-1a-packaging/` and `.superpowers/sdd/2026-10-03-yonk-milestone-1b-engine/`; they do not certify latest hosted or release acceptance. The default SwiftBuild maintainer-plugin failure remains a reproduced baseline; passing local maintainer qualification used the supported native backend with its deprecation warning retained. Final fixes are tracked in `.context/yonk-final-review.md` and `.context/yonk-final-fixes-report.md`.

**Goal:** Make all seven demos and generated author games library-only packages, deployable through one reusable terminal package and generated build packages, with working development, MCP, replay, preflight and release workflows.

**Architecture:** Gnusto exports a presentation-independent `PackagedGame` factory and the small shared interfaces needed by an external terminal client. A separate `GnustoTerminal` repository owns terminal handlers and process launch. Gnusto's tools generate an ignored Swift package that combines one game library with one front end; no maintained per-game executable targets remain.

**Tech Stack:** Swift 6.2 manifests, Swift Testing, SwiftPM traits, Bash 3.2 entry-point shims, Node 22 tooling and `node:test`, DocC and the existing Persnicket formatting configuration. Node is required by the development/build scripts, not by recipients of an exported game.

**Spec:** `docs/superpowers/specs/2026-10-03-yonk-design.md`, sections 1.1 and 1.5–1.7. Milestone 1B's engine plan covers sections 1.2–1.4; Yonk implementation remains milestone 2.

## Global Constraints

- Swift tools version stays `6.2`; Gnusto's platform floors stay `.macOS(.v15)` and `.iOS(.v18)`. GnustoTerminal supports macOS 15 and Linux; it is not added to Gnusto's iOS dependency graph.
- Games export `public let game = PackagedGame { ConcreteGame() }`; the concrete game and its protocol witnesses stay internal.
- `PackagedGame` has `init<G: Game>(_ make: @escaping @Sendable () -> G)`, `title: String` and `makeGame() -> any Game`, with no `main()`.
- Every demo and generated starter has one library target and library product, with no executable product or maintained entry point. Only generated packages have executable targets.
- Terminal is the default front end. `bin/run-game` handles development execution; `bin/export-game` handles deployment; selecting `yonk` reports that the front end is unavailable until milestone 2.
- Gnusto and game libraries never depend on GnustoTerminal or Yonk. Neither front-end repository imports a demo game.
- Development/MCP builds enable `Playtest`; deployed builds disable it across the complete graph. Separate scratch paths isolate the two modes.
- MCP stdout is protocol only. Warm launches do not invoke SwiftPM; successful preflight primes development binaries.
- No deprecated aliases, old executable products or fallback `GameMain` API remain after cutover.
- Preserve game prose, mechanics, save paths, terminal history, completion, transcript bytes, status policy, startup diagnostics and process exit behavior.
- Every new public declaration has a doc comment and parameter/return/throw documentation where applicable. DocC warnings are errors.
- Markdown is never hard-wrapped. Preserve unrelated workspace edits; do not rename the current Gnusto branch.
- Stage the new repository under `.context/companions/GnustoTerminal`. Record both repositories' commits and dependency revisions in `.context/yonk-milestone-1.md`.
- Do not change release signing identities, secrets, runner images or upload policy as part of this migration.

## Review Focus

- A game package and its transitive front end must use the same Gnusto module and the developer's current sources, including uncommitted edits; pin this with a real dependency-graph integration test in Task 3.
- A warm MCP connection must neither print build chatter on stdout nor rebuild after a deployment; pin this with a fake-Swift invocation log and a real MCP handshake in Tasks 3 and 5.
- Deleting or renaming a source file, changing the frontend checkout or changing the catalog must invalidate a cached binary; pin all four inputs in Task 3.
- Quotes, spaces and shell metacharacters in checkout paths must remain literal; pin this with spawned argument vectors and a path containing `$(touch sentinel)` in Task 3.
- Export failure and resource-bearing dependencies must not corrupt an existing deployment or work only inside the build directory; pin both conditions in Task 4.

## File Structure and Ownership

| Repository | Files | Responsibility |
|---|---|---|
| Gnusto | `Sources/Gnusto/Engine/PackagedGame.swift` | presentation-independent game factory |
| Gnusto | `Sources/Gnusto/Engine/PreparedGame.swift`, `GameWorld.swift` | read-only bootstrap diagnostics and history URL available to clients |
| Gnusto | `Sources/Gnusto/IO/SeedRequest.swift`, `TranscriptRequest.swift` | shared environment request values, extracted from GameMain |
| Gnusto | `Sources/Gnusto/IO/DisplayWidth.swift` | shared text-column calculations; one implementation for TextWrap, MCP and terminal clients |
| Gnusto | `Sources/Gnusto/IO/PlaytestLaunch.swift` | trait-safe public facade over the internal MCP server |
| GnustoTerminal | `Package.swift`, `Sources/GnustoTerminal/{TerminalLaunch,ConsoleIOHandler,TerminalIOHandler,KeyDecoder,PlaytestMode}.swift` | terminal presentation and process composition |
| Gnusto | `gnusto-games.json`, `bin/lib/game-catalog.mjs` | explicit list of importable games and their exports |
| Gnusto | `bin/lib/game-build.mjs`, `bin/build-game` | generated package, dependency graph, cache and binary location |
| Gnusto | `bin/run-game`, `bin/export-game`, `bin/lib/game-export.mjs` | run and stage one selected game |
| Gnusto | `bin/gnusto-mcp`, `bin/playtest-replay`, `bin/playtest-preflight`, `bin/lib/playtest-focus.js` | migration of existing play-test consumers |
| Gnusto | `Package.swift`, `Sources/<Game>/Packaged.swift`, `bin/templates/`, `bin/new-game` | atomic library-only game and starter cutover |
| Both | `Tests/`, `bin/tests/`, `.github/workflows/`, DocC and README files | regression evidence, CI and author documentation |

`REPL`, `IOHandler`, `Input`, `CompletionCandidates`, `ScriptedIOHandler`, `StatusFooter`, `TextWrap`, transcript storage/recording and seeded-test support stay in Gnusto: they serve scripts, tests and MCP as well as the terminal. Terminal-specific byte decoding, TTY handling, ANSI rendering and launcher code move to GnustoTerminal. Avoid copying the shared text or transcript algorithms.

## Execution Order

Tasks 1–4 establish tested interfaces and tools before the package cutover. During that preparation, the existing executables still function. Task 5 removes their entry points and `GameMain` while switching every consumer in the same coordinated change; no compatibility structure remains. Task 6 publishes the companion repository, updates CI and proves the integrated result. Review preparatory commits as one unmerged migration until Task 6 passes.

---

### Task 1: Export the game factory and the engine interfaces used by an external client

**Files:**
- Create: `Sources/Gnusto/Engine/PackagedGame.swift`.
- Create: `Sources/Gnusto/IO/SeedRequest.swift` and `TranscriptRequest.swift` by extracting the existing declarations from `GameMain.swift`.
- Create: `Sources/Gnusto/IO/PlaytestLaunch.swift`.
- Modify: `Sources/Gnusto/Engine/PreparedGame.swift`, `GameWorld.swift`, `Sources/Gnusto/IO/DisplayWidth.swift` and `Sources/Gnusto/Playtest/MCPServer.swift`.
- Modify: `Sources/Gnusto/IO/GameMain.swift` to call the extracted values with the new transcript initializer during preparation.
- Test: `Tests/GnustoTests/PackagedGameTests.swift` and `TranscriptRequestTests.swift`; the real MCP facade is exercised by Task 4's trait-isolation integration test.
- Document: `Sources/Gnusto/Documentation.docc/CustomFrontEnds.md` and `Documentation.md`.

**Interfaces:**
- Produces `PackagedGame.init<G: Game>(_:)`, `title` and `makeGame()`.
- Produces `PreparedGame.title: String` and `PreparedGame.warningReport: String?`, both read-only.
- Produces `GameWorld.init(prepared: PreparedGame, saveDirectory: URL? = nil)` for a fresh random seed, alongside the existing explicit-seed initializer; both seeded and unseeded game initializers delegate to these prepared-game paths.
- Produces `StatusLine.init(locationID: EntityID, locationName: String, score: Int, moves: Int)` so an external renderer can construct a status value without importing engine internals.
- Promotes `GameWorld.historyFileURL: URL` and the three `DisplayWidth` measurement/truncation methods to public, with their existing behavior.
- Produces public `TranscriptRequest.init(gameTitled: String, environment: [String: String])`, `url: URL?` and `complaint: String?`. Keep the existing cases, path rules and preflight-open behavior.
- Produces `public enum PlaytestLaunch` with `public static func serve(_ game: PackagedGame, environment: [String: String]) async throws` and `public enum PlaytestLaunchError: Error, CustomStringConvertible { case unavailable }`.

- [x] **Step 1: Write the factory regression**

```swift
import GnustoTestSupport
import Testing

@testable import Gnusto

struct PackagedGameTests {
    @Test func factoryBootsIndependentWorlds() async throws {
        let packaged = PackagedGame { DialRoomGame() }
        #expect(packaged.title == "The Dial Room")
        let first = try GameWorld(game: packaged.makeGame(), seed: 0)
        let second = try GameWorld(game: packaged.makeGame(), seed: 0)
        _ = await first.begin()
        _ = await second.begin()
        _ = await first.perform("north")
        _ = await first.perform("notch")
        #expect(await first.snapshot().moves != second.snapshot().moves)
    }
}
```

Run `swift test --filter PackagedGameTests`. Expect an unknown-type failure before implementation. DialRoomGame begins on the landing; moving north reaches the room whose `notch` rule changes state. Do not use a parse-failure command to test independence.

- [x] **Step 2: Add the presentation-independent factory**

```swift
public struct PackagedGame: Sendable {
    private let make: @Sendable () -> any Game

    public init<G: Game>(_ make: @escaping @Sendable () -> G) {
        self.make = make
    }

    public var title: String { make().title }

    public func makeGame() -> any Game { make() }
}
```

Add full public documentation before committing. The factory stores no console closure, actor, mutable world, dependency on a front end or executable entry point.

- [x] **Step 3: Extract shared request values and expose the required read-only data**

Move `SeedRequest` unchanged into its own file. Move `TranscriptRequest` into its own file, make its initializer and result properties public, and replace `world.definition.title` with the `gameTitled` argument. Update the existing tests and temporary GameMain call site to pass the title. Keep `TranscriptStore` and `TranscriptRecorder` internal; their implementation is reused through the request value and REPL.

```swift
extension PreparedGame {
    public var title: String { definition.title }
    public var warningReport: String? { definition.warningReport }
}
```

Make the existing `historyFileURL` property and `DisplayWidth` type/methods public rather than reimplementing them in the terminal package. Check DocC references to formerly internal names and document each promotion.

Add the public StatusLine initializer with those four arguments assigned to its existing immutable fields. Add the unseeded prepared-game initializer and make `init(game:saveDirectory:)` prepare once and delegate to it; that initializer remains the single place choosing `UInt64.random(in: .min ... .max)`. The terminal launcher must not introduce a second random-seed policy.

- [x] **Step 4: Add the trait-safe MCP facade**

```swift
public enum PlaytestLaunchError: Error, CustomStringConvertible {
    case unavailable

    public var description: String {
        "--mcp (or GNUSTO_MCP) asks for the play-test server, and this binary was built without it. Rebuild with the Gnusto package's Playtest trait enabled."
    }
}

public enum PlaytestLaunch {
    public static func serve(
        _ game: PackagedGame, environment: [String: String]
    ) async throws {
        #if Playtest
        await PlaytestServer.serve(game: game.makeGame, environment: environment)
        #else
        throw PlaytestLaunchError.unavailable
        #endif
    }
}
```

Change the internal `PlaytestServer.serve` parameter to `game: () -> any Game`; its immediate `PreparedGame(game())` call opens the existential. Preserve the protocol-channel claiming, output interception and bootstrap-failure path. The facade file lives outside `Playtest/` and therefore compiles when that directory is excluded. Preserve the existing full refusal message in the actual error implementation so its documented wording and diagnostics do not drift.

- [x] **Step 5: Verify the shared interfaces**

Run `swift test --filter 'PackagedGameTests|TranscriptRequestTests|SeedRequestTests|PlaytestModeTests'`. Run a traits-off library build with `swift build --disable-default-traits --scratch-path .build-notraits`. Add the traits-off subprocess refusal check to the integration suite in Task 4, where an executable exists. The companion package in Task 2 is the cross-module compilation check; an `@testable` engine test alone is insufficient.

- [x] **Step 6: Commit**

```sh
git add Sources/Gnusto Tests/GnustoTests/PackagedGameTests.swift Tests/GnustoTests/TranscriptRequestTests.swift
git commit -m "feat: expose game factories and external launch interfaces"
```

Before staging, inspect the diff and exclude unrelated changes. The integrated handshake is required in Tasks 4 and 5, rather than duplicated with a mock of the facade.

---

### Task 2: Establish GnustoTerminal and preserve its terminal behavior

**Files:**
- Create in `.context/companions/GnustoTerminal`: `Package.swift`, `.gitignore`, `README.md`, `.swift-format`, `Sources/GnustoTerminal/TerminalLaunch.swift` and `Sources/GnustoTerminal/PlaytestMode.swift`.
- Stage the existing `ConsoleIOHandler.swift`, `TerminalIOHandler.swift` and `KeyDecoder.swift` in that repository; remove their engine copies at Task 5's cutover.
- Move terminal-only tests at cutover: `TerminalKeyDecoderTests.swift`, `TerminalPasteTests.swift` and `TerminalStatusBarTests.swift`.
- Split `TerminalUXTests.swift`: line editor, paste and persistent history tests go to `GnustoTerminal/Tests/GnustoTerminalTests/TerminalUXTests.swift`; REPL and completion-candidate tests remain in Gnusto as `CompletionCandidatesTests.swift`.
- Create: `GnustoTerminal/Tests/GnustoTerminalTests/TerminalLaunchTests.swift`.

**Interfaces:**
- Consumes Task 1's public game factory, prepared diagnostics, history URL, transcript request and MCP facade, plus Gnusto's existing public REPL and handlers protocol.
- Produces `public enum TerminalLaunch` with `public static func run(_ game: PackagedGame, arguments: [String] = CommandLine.arguments, environment: [String: String] = ProcessInfo.processInfo.environment) async -> Int32`.
- Produces internal `static func usesInteractiveIO(arguments: [String], environment: [String: String], stdinIsTTY: Bool, stdoutIsTTY: Bool) -> Bool` for deterministic launcher-policy tests.
- TerminalLaunch returns `0` on normal completion and `1` on bootstrap or unavailable-MCP failure; the generated executable owns `exit`.

- [x] **Step 1: Initialize the companion and manifest**

```sh
mkdir -p .context/companions/GnustoTerminal
git -C .context/companions/GnustoTerminal init -b main
```

Use this manifest structure, with documentation and no executable target:

```swift
// swift-tools-version: 6.2
import Foundation
import PackageDescription

let forwarded: Set<Package.Dependency.Trait> = [
    .trait(name: "Playtest", condition: .when(traits: ["Playtest"]))
]
let engineDependency: Package.Dependency =
    ProcessInfo.processInfo.environment["GNUSTO_ENGINE_PATH"].map {
        .package(name: "Gnusto", path: $0, traits: forwarded)
    } ?? .package(
        url: "https://github.com/HeirloomLogic/Gnusto",
        branch: "main",
        traits: forwarded)

let package = Package(
    name: "GnustoTerminal",
    platforms: [.macOS(.v15)],
    products: [.library(name: "GnustoTerminal", targets: ["GnustoTerminal"])],
    traits: [
        .trait(name: "Playtest", description: "Enable Gnusto MCP launch."),
        .default(enabledTraits: ["Playtest"]),
    ],
    dependencies: [engineDependency],
    targets: [
        .target(
            name: "GnustoTerminal",
            dependencies: [.product(name: "Gnusto", package: "Gnusto")]),
        .testTarget(
            name: "GnustoTerminalTests",
            dependencies: ["GnustoTerminal"]),
    ]
)
```

`GNUSTO_ENGINE_PATH` is a development override for testing this coordinated change. Generated builds must use the dependency-identity policy and graph checks in Task 3. The default branch reference is for prerelease integration; replace it with the coordinated published version in the release handoff. Do not label a branch reference as an immutable release pin.

- [x] **Step 2: Write the launcher-selection tests**

```swift
import Testing
@testable import GnustoTerminal

struct TerminalLaunchTests {
    @Test(arguments: [
        (true, true, false, true),
        (true, false, false, false),
        (false, true, false, false),
        (true, true, true, false),
    ])
    func interactivePolicy(
        stdin: Bool, stdout: Bool, forced: Bool, expected: Bool
    ) {
        let environment = forced ? ["GNUSTO_PLAIN": ""] : [:]
        #expect(TerminalLaunch.usesInteractiveIO(
            arguments: ["game"], environment: environment,
            stdinIsTTY: stdin, stdoutIsTTY: stdout) == expected)
    }
}
```

Run `GNUSTO_ENGINE_PATH="$PWD" swift test --package-path .context/companions/GnustoTerminal`; expect missing launcher symbols before implementation.

- [x] **Step 3: Preserve the handlers and implement the launcher**

Add `import Gnusto` to moved handler files. Keep terminal signal restoration, raw-mode handling, bracketed paste, end-of-game presentation and history limits unchanged. Use Gnusto's public `DisplayWidth` and `TextWrap`; do not copy either.

The launcher's control flow is:

```swift
if PlaytestMode.requested(arguments: arguments, environment: environment) {
    do {
        try await PlaytestLaunch.serve(game, environment: environment)
        return 0
    } catch {
        writeToStandardError(String(describing: error))
        return 1
    }
}
do {
    let seed = SeedRequest(environment: environment)
    let status = StatusFooter(environment: environment)
    let prepared = try PreparedGame(game.makeGame())
    let world = seed.value.map { GameWorld(prepared: prepared, seed: $0) }
        ?? GameWorld(prepared: prepared)
    let transcript = TranscriptRequest(
        gameTitled: prepared.title, environment: environment)
    for message in [
        seed.complaint, status.complaint,
        transcript.complaint, prepared.warningReport,
    ].compactMap({ $0 }) {
        writeToStandardError(message)
    }
    let interactive = usesInteractiveIO(
        arguments: arguments, environment: environment,
        stdinIsTTY: isatty(STDIN_FILENO) == 1,
        stdoutIsTTY: isatty(STDOUT_FILENO) == 1)
    let io: any IOHandler = interactive
        ? TerminalIOHandler(historyURL: await world.historyFileURL)
        : ConsoleIOHandler()
    await REPL(
        world: world, io: io,
        transcriptURL: transcript.url, status: status.inForce,
        environment: environment).run()
    return 0
} catch {
    writeToStandardError(String(describing: error))
    return 1
}
```

Add Foundation and conditional Darwin/Glibc imports. Warnings must be emitted before constructing TerminalIOHandler, whose initializer changes the screen. MCP selection precedes bootstrap, seed parsing and terminal construction. Preserve the current seed ordering and save-directory environment behavior; do not add an alternate RNG policy to the engine.

`usesInteractiveIO` is `stdinIsTTY && stdoutIsTTY && environment["GNUSTO_PLAIN"] == nil`. It ignores ordinary arguments; MCP has already selected its separate path.

- [x] **Step 4: Adapt cross-package terminal tests**

Keep tests that only exercise KeyDecoder or TerminalIOHandler internals under `@testable import GnustoTerminal`. Add ordinary `import Gnusto` for public shared types. Status-bar tests use Task 1's public StatusLine initializer, retaining the existing names, scores, move counts, clipping and width assertions. No copied engine fixture or `@testable import Gnusto` is needed in the companion suite.

The split core completion suite retains its existing `MiniGame` and `RecordingIOHandler` fixtures and never imports GnustoTerminal. Do not make engine test fixtures public just to copy them into a second package.

- [x] **Step 5: Run the terminal regressions and commit the companion**

Run the companion suite with `GNUSTO_ENGINE_PATH="$PWD"`. Compare test names/assertions before and after moving them; every existing line-editor, paste, status and history assertion must still be exercised. Run strict swift-format using the copied configuration. Commit the companion's files locally; record its commit in `.context/yonk-milestone-1.md`. Publication occurs after Task 6's coordinated checks.

---

### Task 3: Generate one-game build packages with explicit catalogs and stable caches

**Files:**
- Create: `gnusto-games.json`, `bin/lib/game-catalog.mjs`, `bin/lib/game-build.mjs` and executable `bin/build-game`.
- Create: `bin/tests/game-catalog.test.mjs` and `game-build.test.mjs`.
- Create fixtures under `bin/tests/fixtures/game-build/` for a library product whose name differs from its module and a resource-bearing game.
- Modify: `.gitignore` for `.build-launchers/` and companion guidance in `docs/playtesting.md`.

**Interfaces:**
- `loadGames(packageRoot: string): GameCatalog` validates `gnusto-games.json`.
- `resolveCatalogGame(catalog: GameCatalog, words: string): GameEntry` returns one unambiguous entry or throws.
- `makeBuildSpec({packageRoot, engineRoot, terminalRoot, game, mode}): BuildSpec` creates the deterministic generated manifest and entry point.
- `buildGame(spec: BuildSpec, {force = false, swift = "swift", environment = process.env}): Promise<BuildResult>` returns `{binary, binDirectory, packageRoot, scratchPath, fingerprint}`.
- `bin/build-game <Game> [--mode development|deployment] [--force] [--json]` defaults to development; stdout contains exactly one absolute binary path or one JSON result. Diagnostics go to stderr.
- `GNUSTO_TERMINAL_PATH` selects an explicit companion checkout during development; unset, use `https://github.com/HeirloomLogic/GnustoTerminal` on `main` until coordinated releases establish a version requirement.

- [x] **Step 1: Define and test the catalog**

Use version 1, the actual root package name and an explicit list of game exports:

```json
{
  "version": 1,
  "package": "Gnusto",
  "games": [
    {"name":"CloakOfDarkness","product":"CloakOfDarkness","module":"CloakOfDarkness","symbol":"game"},
    {"name":"Lighthouse","product":"Lighthouse","module":"Lighthouse","symbol":"game"},
    {"name":"Zork1","product":"Zork1","module":"Zork1","symbol":"game"},
    {"name":"Dungeon","product":"Dungeon","module":"Dungeon","symbol":"game"},
    {"name":"Gramarye","product":"Gramarye","module":"Gramarye","symbol":"game"},
    {"name":"Fulminate","product":"Fulminate","module":"Fulminate","symbol":"game"},
    {"name":"KindlyDeep","product":"KindlyDeep","module":"KindlyDeep","symbol":"game"}
  ]
}
```

Validate version, nonempty package/product/name values, Swift module identifiers, `symbol === "game"` and uniqueness after the existing name-folding rule. Reject missing/malformed catalogs and unknown games before invoking SwiftPM. The product is data, not generated Swift code; module/symbol are validated before interpolation.

```javascript
import assert from "node:assert/strict";
import test from "node:test";
import {validateCatalog, resolveCatalogGame} from "../lib/game-catalog.mjs";

test("a library product may have a different module name", () => {
  const catalog = validateCatalog({
    version: 1, package: "Story",
    games: [{name: "Story", product: "StoryLibrary", module: "Story", symbol: "game"}]
  });
  assert.equal(resolveCatalogGame(catalog, "story").product, "StoryLibrary");
});
test("ambiguous names and executable Swift fragments are refused", () => {
  assert.throws(() => validateCatalog({
    version: 1, package: "Story",
    games: [
      {name: "Story", product: "A", module: "A", symbol: "game"},
      {name: "story", product: "B", module: "B", symbol: "game"}
    ]
  }));
  assert.throws(() => validateCatalog({
    version: 1, package: "Story",
    games: [{name: "Story", product: "Story", module: "Story; fatalError()", symbol: "game"}]
  }));
});
```

Export `validateCatalog(value: unknown): GameCatalog` for these tests. Run `node --test bin/tests/game-catalog.test.mjs` and observe the missing-module failure before implementation.

- [x] **Step 2: Define the generated package and process entry point**

Use `.build-launchers/<Game>/development/package` and `.build-launchers/<Game>/deployment/package` for generated sources, with separate sibling `scratch` directories. The generated executable product is the catalog's `name`; the target is `GameLauncher`. The generated manifest depends only on the selected game package and GnustoTerminal, plus a root override for their shared engine when needed. All products/modules come from the validated catalog.

```swift
import GnustoTerminal
import Zork1

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

let result = await TerminalLaunch.run(Zork1.game)
exit(result)
```

The generated manifest declares and forwards `Playtest` to the game package, terminal package and any direct engine override using the exact forwarding set from Task 2. Declare no default forwarding to a dependency that cannot honor the selected trait; fail with its package name instead of silently shipping the server.

Use `spawn`/`execFile` argument arrays, never shell-evaluate a manifest, source path or catalog value. Encode Swift string literals by escaping backslashes, quotes and control characters; JSON serialization by itself is not shell escaping.

For the demo Zork1 graph, the generated manifest has this complete shape; replace the validated literal names and paths when rendering other catalogs:

```swift
// swift-tools-version: 6.2
import PackageDescription

let forwarded: Set<Package.Dependency.Trait> = [
    .trait(name: "Playtest", condition: .when(traits: ["Playtest"]))
]
let package = Package(
    name: "Zork1TerminalBuild",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "Zork1", targets: ["GameLauncher"])],
    traits: [
        .trait(name: "Playtest", description: "Enable the development MCP server."),
        .default(enabledTraits: ["Playtest"]),
    ],
    dependencies: [
        .package(name: "Gnusto", path: "../Dependencies/gnusto", traits: forwarded),
        .package(name: "GnustoTerminal", path: "../Dependencies/gnustoterminal", traits: forwarded),
    ],
    targets: [
        .executableTarget(
            name: "GameLauncher",
            dependencies: [
                .product(name: "Zork1", package: "Gnusto"),
                .product(name: "GnustoTerminal", package: "GnustoTerminal"),
            ])
    ]
)
```

- [x] **Step 3: Pin dependency identity and current-source behavior with a real graph test**

For the demo root, the game package is Gnusto itself: reference its ignored `Dependencies/gnusto` symlink from the generated root and pass that same dependency path to the terminal manifest through `GNUSTO_ENGINE_PATH`. The frontend reference uses `Dependencies/gnustoterminal`. For an independent author package, resolve its engine through the existing `gnusto_find_repo` behavior and inspect its dependency declaration before deciding the identity policy.

A path-dependent author game keeps the exact engine path already in its manifest; feed that same path to the terminal manifest and do not add a second direct engine dependency. Renaming that path to a `gnusto` symlink would change its SwiftPM identity and can create two modules. A URL-dependent author game instead gets a generated-root path override through a symlink named after the URL dependency's actual identity (normally `gnusto`); feed that same override path to the terminal manifest. Its root path override replaces the URL node rather than linking a second released engine. The game package itself uses a distinct identity derived from its dependency location; product/module names continue to come from the catalog.

Run `swift package --package-path <generated-package> show-dependencies --format json` during integration verification. Assert exactly one Gnusto identity, one GnustoTerminal identity and the selected game root, and assert that source paths resolve to the current checkouts. Build a fixture that references the newly added PackagedGame API from both sides of the boundary, then edit its source without committing and rebuild to prove the deployed executable reflects the edit. Test both a path-dependent author game and a URL-dependent author game. This test must pass before choosing this graph mechanism for the cutover; a successful import-only mock is insufficient.

If a user game has a package identity colliding with an engine/front-end identity, report the collision before generating a graph. Cover that error explicitly and teach independent authors to use a distinct package identity; do not disguise two packages under aliases.

- [x] **Step 4: Implement cache validity and warm-start behavior**

Fingerprint generated manifest/entry-point text, the catalog, tool version, build mode, source file contents and relative path lists for the game, engine and local front end, plus dependency manifests/lockfiles and toolchain selection. Enumerate directories as well as files so deletion changes the fingerprint. Exclude generated output, `.git`, `.context` and all build directories. Remote resolved checkout inputs and the generated `Package.resolved` also participate.

A cache hit requires the fingerprint and an existing executable binary. It reads local state without invoking SwiftPM. A miss uses an exclusive per-generated-package lock, rechecks validity after acquiring it, writes changed generated files atomically and invokes SwiftPM with `--package-path` and `--scratch-path`. Serialize cold resolution/builds for the same package; two identical callers share the successful result. Build chatter goes to stderr. Record the binary path and final fingerprint only after a successful build; failed builds never mark a stale binary current.

Add fake-Swift tests whose executable records each argument vector. Assert zero invocations on a warm cache hit, one effective build under concurrent identical callers, invalidation on edit/deletion/catalog/frontend changes, and distinct scratch paths for development/deployment. Run the test once with an engine path containing spaces, a quote and the literal `$(touch sentinel)`; assert the sentinel does not exist and the recorded path is unchanged.

- [x] **Step 5: Verify and commit**

Run `node --test bin/tests/game-catalog.test.mjs bin/tests/game-build.test.mjs`. Run the real graph tests with the local companion and both independent game dependency forms. Until Task 5 changes the manifest, use the fixtures for actual generated builds; the demo catalog is ready for the cutover but its entries still refer to the old root executable products.

Commit the catalog/build generator/tests only after those checks pass. Record graph evidence and the actual toolchain version in the context handoff.

---

### Task 4: Run and export generated terminal games without losing resources or prior exports

**Files:**
- Create: `bin/run-game` and `bin/lib/game-export.mjs`.
- Modify: `bin/export-game`.
- Create: `bin/tests/game-export.test.mjs` and `game-deployment.integration.mjs`.
- Modify tests: `bin/tests/help-flags.test.mjs`, `value-flags.test.mjs` and `settings-permissions.test.mjs`.

**Interfaces:**
- `bin/run-game <Game> [--frontend terminal|yonk]` builds in development mode and replaces its process with the game, preserving stdin and exit status.
- `bin/export-game [<Game>] [--frontend terminal|yonk]` lists catalog game names when no game is supplied; a named game builds in deployment mode and stages `dist/<Game>`.
- `stageTerminalExport({binary, binDirectory, destination}): Promise<{binary: string, resources: string[]}>` validates and atomically stages a distribution.
- `yonk` is recognized and returns a clear unavailable-front-end error before building. Unknown frontend names and missing flag values are errors.

- [x] **Step 1: Write the deployment failure regression**

```javascript
import assert from "node:assert/strict";
import fs from "node:fs/promises";
import path from "node:path";
import os from "node:os";
import test from "node:test";
import {stageTerminalExport} from "../lib/game-export.mjs";

test("a missing build output leaves the previous export intact", async () => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "gnusto-export-"));
  try {
    const destination = path.join(root, "dist", "Story");
    await fs.mkdir(path.dirname(destination), {recursive: true});
    await fs.writeFile(destination, "previous");
    await assert.rejects(stageTerminalExport({
      binary: path.join(root, "missing", "Story"),
      binDirectory: path.join(root, "missing"),
      destination
    }));
    assert.equal(await fs.readFile(destination, "utf8"), "previous");
  } finally {
    await fs.rm(root, {recursive: true, force: true});
  }
});
```

Run `node --test bin/tests/game-export.test.mjs` and observe the missing-module failure.

- [x] **Step 2: Implement run/export command parsing and trait policy**

The Bash run shim locates the package through `GNUSTO_PACKAGE_PATH` or its own root, calls build-game, and uses `exec "$binary"` after build diagnostics finish. This preserves interactive stdin and process signals. Keep `-h`/`--help` independent of package resolution.

Export builds with `-c release --disable-default-traits` against the generated package and its deployment scratch path. Development uses debug with the default `Playtest` trait. Do not change the root package's trait in place or reuse its `.build` binary. Forward the local frontend override as a literal environment value.

Replace executable-product discovery with the catalog; update user-facing terminology to game names. Preserve the current no-argument listing behavior, atomic fresh-inode replacement and useful deployment instructions.

- [x] **Step 3: Stage binary and resource bundles**

Inspect the generated product's bin directory for the resource bundles belonging to its resolved dependency graph, using `.bundle` on macOS and `.resources` where SwiftPM uses that suffix. Validate the complete staged output before changing `dist`. For a resource-free graph, retain the single-file `dist/<Game>` deployment. For a resource-bearing graph, create a sibling, versioned distribution directory containing the executable and resource bundles, then atomically switch `dist/<Game>` to that distribution's executable; retain the old distribution until the switch succeeds. Use relative links and tell the user to distribute the complete directory for that case.

Prove the accessor lookup works with a fixture that reads `Bundle.module` at startup. Test it after copying the distribution elsewhere and temporarily moving its source checkout/build directory out of reach. If the platform's generated accessor cannot find adjacent staged resources, fix the distribution layout and fixture together before shipping; copying bundles without the relocated launch check is not evidence.

Never copy `GnustoTestSupport` or Swift Testing into a shipped graph. Preserve executable permissions and avoid modifying a binary inode that may be mapped by a running process.

- [x] **Step 4: Prove trait isolation and protocol refusal**

The integration script builds a development fixture, performs an MCP initialize handshake, exports the same fixture, and invokes the deployed binary with both `--mcp` and `GNUSTO_MCP=1`. Expect nonzero exit, the existing built-without-it message on stderr and no game/protocol text on stdout. Reconnect to the development binary and expect the same valid handshake with no rebuild. Assert their binary paths and scratch paths differ.

Run failure tests for missing terminal checkout, invalid front-end name, missing `--frontend` value, failed Swift build and interrupted staging. Every failed export leaves the prior executable usable.

- [x] **Step 5: Verify and commit**

Run `node --test bin/tests/game-export.test.mjs bin/tests/help-flags.test.mjs bin/tests/value-flags.test.mjs bin/tests/settings-permissions.test.mjs` and the deployment integration script with the local companion. Commit the CLI changes and fixtures. The demo CLI becomes fully usable in the next task's atomic library cutover.

---

### Task 5: Cut over every demo, author starter and play-test consumer together

**Files:**
- Modify: `Package.swift`; all seven demo entry-point declarations; `Sources/Gnusto/Documentation.docc/{CustomFrontEnds,GettingStarted,SharingYourGame,TestingYourGame,Documentation}.md` and `CLAUDE.md`.
- Create: `Sources/{CloakOfDarkness,Lighthouse,Zork1,Dungeon,Gramarye,Fulminate,KindlyDeep}/Packaged.swift`.
- Delete at cutover: `Sources/Gnusto/IO/{GameMain,ConsoleIOHandler,TerminalIOHandler,KeyDecoder,PlaytestMode}.swift` and the demo `Entry.swift` files.
- Modify: `bin/templates/Package.swift`, `Sources/MyGame/Entry.swift` (replace with `Packaged.swift`), `gnusto-games.json` (create), `README.md` and `bin/run-game` shim (create).
- Modify: `bin/new-game`; `Tests/GnustoTests/{NewGameTests,DslQuickWinsTests,PlaytestPathTests}.swift`; `Support/DslQuickWinGames.swift`.
- Modify: `bin/{gnusto-mcp,playtest-replay,playtest-preflight}`, `bin/lib/playtest-focus.js` and any consumer of its former executable-product helpers.
- Test: `bin/tests/{generated-paths,preflight-validation,game-catalog,game-build}.test.mjs` and `bin/tests/game-cutover.integration.mjs`.

**Interfaces:**
- Every demo library product has the same name as its module and exports `game: PackagedGame`. CloakOfDarkness exports `PackagedGame { OperaHouse() }`; each other demo exports its same-named game.
- Starter `MyGame` is a library product and target, tested through `MyGameTests`. Its catalog contains package/name/product/module `MyGame` and symbol `game`.
- `playtest-focus.js` exports `gameNames()`, retains `targetsOfProduct(name)` and `resolveGame(words)` return shapes, and derives source/capability data from catalog library products and their actual manifest targets.
- `bin/playtest-replay <Game> --build` still prints the absolute development binary path; its recorded path continues to belong to the invoking game package.
- `bin/gnusto-mcp <Game>` uses build-game's cache policy and launches the returned binary with `--mcp`.

- [x] **Step 1: Write the library-only starter assertions**

Change NewGameTests' executable-target assertion to require a library product and `.target(`, reject `.executableTarget(` and `@main`, and require `Sources/Zwank/Packaged.swift`, `gnusto-games.json` and `bin/run-game`. Parse the catalog and check package/product/module/name `Zwank` and symbol `game`. Check that no template spelling remains.

In generated-paths tests, stub the new build-game path response and assert that a generated package's run/export/replay/MCP shims forward its package root and caller-relative paths. Keep the existing wrong-package discriminators rather than only testing an exit code.

- [x] **Step 2: Convert the manifest and exports**

Replace the seven executable products with:

```swift
.library(name: "CloakOfDarkness", targets: ["CloakOfDarkness"]),
.library(name: "Lighthouse", targets: ["Lighthouse"]),
.library(name: "Zork1", targets: ["Zork1"]),
.library(name: "Dungeon", targets: ["Dungeon"]),
.library(name: "Gramarye", targets: ["Gramarye"]),
.library(name: "Fulminate", targets: ["Fulminate"]),
.library(name: "KindlyDeep", targets: ["KindlyDeep"]),
```

Change their seven `.executableTarget` declarations to `.target` without changing dependencies or lint plugins. Remove `@main` and `GameMain` from Zork1, Dungeon, Gramarye, Fulminate and KindlyDeep; remove CloakOfDarkness/Lighthouse Entry.swift. Add each documented `public let game = PackagedGame { ... }` export. Repeat the exact library-only structure for the starter; there is no `MyGameMain` target.

Move the terminal files/tests staged in Task 2 out of Gnusto. Keep the shared types extracted in Task 1. Remove the fixture's `GameMain` conformance and replace its old `MainableGame.run` test with `await REPL(world: world, io: io).run()`; retain the scripted-loop assertion. Remove obsolete GameMain and terminal-handler DocC symbol links from engine Topics and replace narrative references with code spans or the external package's documentation link.

- [x] **Step 3: Change catalog consumers and build paths**

Replace playtest-focus's executable filtering with `loadGames(ROOT)` and `gameNames()`. Validate each catalog product against the actual manifest's library products when preflight describes the package, and derive its target closure with `targetsOfProduct`; do not assume product and target names match. Preflight's selected source target is the one containing the catalog module. Update error messages from “no executable product” to “no game”.

Replace replay's `swift build --product` block and MCP's build block with `bin/build-game` in development mode. Preserve `GNUSTO_MCP_BUILD=1` as a forced-build request. The path cache written for replay remains under the invoking package's playtest root; a cache hit is accepted only after the shared fingerprint validates it.

Update template shims to dispatch `run-game` and the internal build tool through the existing `gnusto_exec` mechanism. New-game's default version-pin path must refuse a released Gnusto that lacks `PackagedGame` or the new build tools instead of generating a broken package and printing the old compatibility warnings. Its error explains `--dep-path` for the coordinated prerelease checkout. Preserve generated source name substitution, path quoting, MCP/settings key matching and the existing tool-location probes.

- [x] **Step 4: Verify demos and an independent author package**

```sh
swift test
node --test bin/tests/*.test.mjs
node .claude/workflows/playtest.dryrun.mjs
GNUSTO_TERMINAL_PATH="$PWD/.context/companions/GnustoTerminal" bin/run-game CloakOfDarkness
GNUSTO_TERMINAL_PATH="$PWD/.context/companions/GnustoTerminal" bin/playtest-preflight Zork1
```

Create `.context/packaging-check/AuthorStory` with `bin/new-game AuthorStory .context/packaging-check/AuthorStory --dep-path "$PWD"`. Run its tests, scripted terminal session, export and preflight from its own directory and from an unrelated working directory through its shims. Confirm the returned binary path resolves under AuthorStory's generated build cache and its preflight source/docs paths name AuthorStory while harness paths name the engine.

Use the integration script to run `look` and `quit` in each of the seven demos with isolated save directories. Confirm stdout begins with each game's own banner and no import/build text. Replay an existing committed Zork1 and Dungeon deep-start route with the recorded seed and landing checks.

- [ ] **Step 5: Verify real terminal behavior and commit the coordinated cutover**

The cutover is committed and actual PTY checks passed. The native visual, scrollback, PageUp and PageDown portion remains a human acceptance gate after CUA access to Terminal was denied; this combined step stays open for that portion.

In a real terminal, test editing, arrow-key history, Tab completion, bracketed paste, resizing, scrollback, Ctrl-C during a save prompt, EOF and the final-frame return to shell. Save the transcript/checklist under `.context/`; passing renderer tests alone does not prove raw-terminal restoration.

Search active source/docs/tools for `GameMain`, `swift run <Game>`, `swift build --product <Game>` and executable-game discovery. Historical superseded plans may retain those strings; active instructions may not. Reflow every edited Markdown paragraph to one source line. Commit the coordinated engine/game/tool cutover and the companion's source moves together in their owning repositories, recording both commit IDs.

---

### Task 6: Wire CI and publish the companion repository with integrated evidence

**Files:**
- Modify Gnusto: `.github/workflows/{test,release,harness,documentation,ios}.yml` and `bin/templates/.github/workflows/` where present.
- Create GnustoTerminal: `.github/workflows/{test,lint}.yml`, `Sources/GnustoTerminal/Documentation.docc/GnustoTerminal.md` and its README.
- Update: `docs/playtesting.md`, `bin/templates/README.md` and `.context/yonk-milestone-1.md`.
- Modify `docs/superpowers/specs/2026-10-03-yonk-design.md` status only after the corresponding deliverable has actually passed.

**Interfaces:**
- New public repository `HeirloomLogic/GnustoTerminal`, matching Gnusto's verified public visibility, publishes the reusable library rather than demo executables.
- Gnusto CI selects the reviewed companion revision for migration checks; companion CI selects the reviewed Gnusto revision. Neither published Gnusto library manifest gains a terminal dependency.
- Existing release jobs enumerate catalog games and consume staged deployment outputs; signing, compression and uploads remain their current separate steps.

- [x] **Step 1: Test workflow command changes before publication**

Replace test.yml's traits-off root-product build with `bin/build-game CloakOfDarkness --mode deployment --json` and use its returned binary for refusal checks. Replace the generated Scratch product build with the same tool invoked through Scratch's shim. Keep `--build-system swiftbuild --disable-experimental-prebuilts` where the existing Linux workflow requires them; `GNUSTO_SWIFT_BUILD_FLAGS` contains a JSON string array such as `["--build-system","swiftbuild","--disable-experimental-prebuilts"]`, parsed without shell evaluation and included in fingerprints. Reject a value that is not a JSON array of strings.

Harness CI runs the new Node suites on Node 22. Linux test CI installs Node 22 for the generated build commands; do not assume the Swift container ships it. Preserve the root Debug/Release suites, template/generated tests, entity interpolation diagnostics and preflight layout checks.

Change release discovery to the catalog and build every terminal distribution through export-game. Signing receives the staged executable; resource-bearing outputs are archived with their complete distribution directory. Preserve current Darwin signing/notarization configuration and Linux artifact naming. Update documentation workflow comments about demo libraries. iOS continues to build Gnusto-Package and must not resolve GnustoTerminal.

- [x] **Step 2: Run the integrated local checks**

```sh
swift test
GNUSTO_ENGINE_PATH="$PWD" swift test --package-path .context/companions/GnustoTerminal
node --test bin/tests/*.test.mjs
node .claude/workflows/playtest.dryrun.mjs
xcrun swift-format lint --strict --parallel --recursive --configuration .swift-format Sources Tests
swift package --allow-writing-to-directory .context/docs generate-documentation --target Gnusto --output-path .context/docs --warnings-as-errors
```

Resolve maintainer-only tooling through the existing `.dev-tooling` setup before lint/DocC if it is not already available. Run the companion's lint/DocC checks with its own tooling setup. Run the dependency graph, traits-off refusal, relocated-resource and generated-author integration checks. Record which checks ran locally and which require hosted Linux/macOS runners.

- [x] **Step 3: Publish the reviewed companion branch**

Read `gh repo view HeirloomLogic/GnustoTerminal --json nameWithOwner` first. If it exists, use its existing repository and preserve its history; do not create or overwrite it. If it does not exist, publish the prepared local repository:

```sh
gh repo create HeirloomLogic/GnustoTerminal --public --source .context/companions/GnustoTerminal --remote origin --push
```

Publish a development integration branch containing the coordinated package and record its exact revision for Gnusto's CI. The companion cannot pass its default remote build until the matching Gnusto factory/API changes are accessible; configure its integration CI to check out the recorded Gnusto feature revision and supply `GNUSTO_ENGINE_PATH`. Do not claim the two packages are released or mutually main-compatible merely because a local path build passed.

Push the reviewed current Gnusto feature branch with `git push -u origin HEAD` before running the companion's hosted integration job, so its recorded engine revision is actually fetchable. Keep the current branch name and do not push these changes to origin/main directly.

Use generated `Package.resolved` files for ordinary prerelease pins. Managed frontend edits are omitted from that lockfile; their branch/revision is retained in workspace `basedOn` state and their exact source provenance in generated `terminal-source.json` and `build-state.json`. At the release handoff, replace branch requirements with compatible immutable package versions and test a fresh author package against those versions; release/tag creation is a separate release action, not proof supplied by this plan.

- [x] **Step 4: Record completion and commit CI/docs**

The handoff file records engine and companion branch/revision, graph provenance, local checks, hosted CI URLs/results when available, the live-terminal checklist and any release acceptance still outstanding. Milestone 1A is locally complete only when all seven demos and an independent starter run/export/preflight through generated terminal launchers and the deployment/MCP/resource checks pass.

Commit the CI/documentation changes. Do not start the engine-report plan until this plan's package boundary and migrated tools are stable. Keep the current Gnusto branch name; if execution later creates PRs, show the checked-out top branch in Conductor.

## Coverage and Handoff

| Spec requirement | Tasks |
|---|---|
| Library-only demos, starter and factory; retirement of GameMain | 1, 5 |
| One reusable terminal package, terminal behavior preserved | 2, 5 |
| Generated packages, selected game only, no dependency cycles | 3 |
| Run/export front-end selection and unavailable Yonk | 4 |
| Trait forwarding, separate caches, MCP/replay/preflight | 1, 3, 4, 5 |
| Errors, atomic exports and relocated resources | 3, 4 |
| Independent authors, terminal interaction, CI and documentation | 5, 6 |

The next implementation plan is `docs/superpowers/plans/2026-10-03-yonk-milestone-1b-engine.md`. This plan deliberately stops at a working terminal path; it does not implement Yonk, Blorple or Lobal.
