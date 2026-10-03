# Yonk Milestone 1B: Engine Reports and Map Queries Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** Awaiting plan review and execution-method selection. No implementation has started.

**Goal:** Give every front end a public per-turn report, a complete in-scope vocabulary query, a filtered room-map query, and author hints for mazes and secret exits.

**Architecture:** Library-only games and generated terminal/MCP launchers from milestone 1A remain intact. Gnusto records actual player movement in live turn scratch data and publishes one net arrival on TurnResult; vocabulary and map queries evaluate read-only in throwaway frames. Map hints become declarations validated at bootstrap, with Zork 1's nineteen maze/dead-end rooms annotated.

**Tech Stack:** Swift 6.2 manifests, Swift Testing, SwiftPM Playtest trait, DocC and the existing Persnicket formatting configuration.

**Spec:** `docs/superpowers/specs/2026-10-03-yonk-design.md`, sections 1.2–1.4 and milestone 1 of section 5. Prerequisite: `docs/superpowers/plans/2026-10-03-yonk-milestone-1a-packaging.md` has produced working terminal builds and play-test tools.

## Global Constraints

- Swift tools version stays `6.2`; platform floors stay `.macOS(.v15)` and `.iOS(.v18)`.
- No per-game executable target, root executable product, `GameMain` or `PackagedGame.main()` is introduced. Development/play-test/deployment checks use milestone 1A's generated packages.
- New engine APIs stay outside `Sources/Gnusto/Playtest/` and compile with the Playtest trait disabled.
- Every public declaration has a doc comment, parameter/return documentation where applicable, and no DocC link to an internal symbol.
- `TurnReport`, `WordsInScope`, `RoomMapView` and `MapExit` expose no public initializer; only the engine builds these values.
- Game-target prose follows ProseConventionTests: one plain multi-line literal, no concatenation and no trailing backslash.
- Map knowledge is owned by the mapper, never serialized or undone by the engine. Exits never expose destinations through mapView.
- Markdown is never hard-wrapped. Preserve unrelated edits and the current branch name.
- These tasks derive from the former plan's engine-only tasks; this document is their active replacement. No step in the superseded plan is an execution dependency.

## Review Focus

- A parsed direction and an adjacent room are insufficient evidence of walking; Task 2 records actual traversal and tests a GO rule that teleports.
- ENTER and FOLLOW must report the exit actually taken, including two exits with one destination; Task 2 tests ambiguity and conditional gating.
- UNDO, RESTART and RESTORE filenames relocate without map edges; Task 2 covers all three state replacements and confirms failed moves report no movement.
- An open save/restore prompt changes the accepted input context; Task 3 verifies filename context without exposing hidden-object vocabulary.
- Repeated queries must not advance moves, randomness or mutable globals; Task 4 compares state before and after query evaluation and uses a condition that writes scratch state.

## File Structure

| Files | Responsibility |
|---|---|
| `Declarations/Traits.swift`, `WorldMap.swift`, `Engine/Bootstrap.swift`, `GameDefinition.swift` | validated map-region and secret-exit declarations |
| `Engine/TurnReport.swift`, `TurnFrame.swift`, `GameWorld.swift`, `Actions/DefaultActions.swift` | public report backed by actual traversal records |
| `Engine/GameWorld+Vocabulary.swift` | full vocabulary, split by word kind and input context |
| `Engine/GameWorld+MapView.swift` | filtered current-room view with no exit destinations |
| `Tests/GnustoTests/Support/{MapHintGames,CartographyGames}.swift` and focused suites | declaration, movement, vocabulary and read-only query regressions |

All source paths in this table are relative to `Sources/Gnusto/`. Test paths are relative to the repository root. This plan touches no terminal implementation files.

---

### Task 1: `mapRegion(_:)` and `.secret`

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

Run: `swift test --filter MapHintTests` Expected: build failure, `cannot find 'mapRegion' in scope` and `value of type 'MapEntry' has no member 'secret'`.

- [ ] **Step 4: Add the trait**

In `Sources/Gnusto/Declarations/Traits.swift`, add a case to `LocationTrait.Kind` after `case alwaysDescribed`:

```swift
        case mapRegion(String)
```

Every exhaustive `switch` over `LocationTrait.Kind` now fails to compile until it handles the new case. `LocationDefinition.init(traits:onDuplicate:)` is handled in Step 5; find any other with `rg -n 'case \.alwaysDescribed' Sources` and give each a `case .mapRegion:` arm that does what that switch does for a trait it does not care about.

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

Until Task 4 adds `GameWorld/mapView()`, that symbol link does not resolve. Write the last paragraph's link as a code span, `` `GameWorld.mapView()` ``, here; Task 4 Step 5 turns it into a link.

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

As in Step 4, write ``GameWorld/mapView()`` as the code span `` `GameWorld.mapView()` `` until Task 4.

In `Sources/Gnusto/Engine/Bootstrap.swift`, in the `GameDefinition(` call (~line 1111), add `secretExits: secretExits,` directly after the `reachableRooms: Set(…)` argument and before `globals:`.

- [ ] **Step 9: Run the tests**

Run: `swift test --filter MapHintTests` Expected: everything passes except `zorkOnesMazeIsOneRegion` (`maze.count` is 0).

- [ ] **Step 10: Mark Zork 1's maze**

The fifteen maze rooms and four dead ends are the `Location` blocks at lines 36–134 of `Sources/Zork1/Regions/Maze.swift`; each ends with a `dark` line. Add `mapRegion("Maze")` after each one:

```bash
perl -pi -e 'if ($. >= 36 && $. <= 134 && /^        dark$/) { $_ .= "        mapRegion(\"Maze\")\n" }' Sources/Zork1/Regions/Maze.swift
rg -c 'mapRegion\("Maze"\)' Sources/Zork1/Regions/Maze.swift
```

Expected: `19`. Then check that `gratingRoom`, `cyclopsRoom`, `treasureRoom` and `strangePassage` were not touched: `git diff Sources/Zork1/Regions/Maze.swift` shows 19 added lines, all above `// MARK: - The grating, cyclops, and treasure`.

The maze is the `ZorkMaze` content bundle, so its entity IDs are namespaced under the bundle type: `ZorkMaze.maze1`, which is what the test names.

- [ ] **Step 11: Run the tests to verify they pass**

Run: `swift test --filter MapHintTests` Expected: 6 tests pass.

Run: `swift test` Expected: all tests pass. Zork 1 plays exactly as before: the trait changes no prose and no behavior.

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

### Task 2: The per-turn report

**Files:**
- Create: `Sources/Gnusto/Engine/TurnReport.swift`
- Modify: `Sources/Gnusto/Engine/GameWorld.swift` (`TurnResult`, `perform(_:)`, `commit(_:)`), `Sources/Gnusto/Engine/TurnFrame.swift` (`Scratch` movement funnels), and `Sources/Gnusto/Actions/DefaultActions.swift` (`travel` and `enter`)
- Create: `Tests/GnustoTests/Support/CartographyGames.swift`
- Test: `Tests/GnustoTests/TurnReportTests.swift`
- Modify: `Sources/Gnusto/Documentation.docc/CustomFrontEnds.md`

**Interfaces:**
- Consumes: `mapRegion(_:)` and `MapEntry.secret` from Task 1 (the fixture declares both); internal `TurnAudit`, `DefaultActions.engineIntents`, `GameDefinition.exits`, `WorldState.playerLocation`.
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

Run: `swift test --filter TurnReportTests` Expected: build failure, `value of type 'TurnResult' has no member 'report'`.

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
        /// `enter the trap door`, `follow the troll`. Both the direction and
        /// destination come from a confirmed traversal, rather than a parsed
        /// direction or a guess about an adjacent room.
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

/// One actual player-location mutation in a live turn, never saved or undone.
struct MapTransition: Sendable {
    let from: EntityID
    let to: EntityID
    let direction: Direction?
}

extension GameWorld {
    /// Combines parser information with the live turn's recorded movement.
    func report(
        of audit: TurnAudit, from origin: EntityID,
        recorded movement: TurnReport.Movement?
    ) -> TurnReport {
        var report = TurnReport()
        report.understood = audit.understood
        report.unknownWords = audit.unknownWords
        let destination = state.playerLocation
        guard destination != origin else { return report }
        if audit.answeredPrompt || audit.intent == .undo
            || audit.intent == .restart || audit.intent == .restore {
            report.movement = .relocated(to: destination)
        } else if case .walked(let from, let to, let direction) = movement,
            from == origin, to == destination {
            report.movement = .walked(from: from, to: to, direction: direction)
        } else {
            report.movement = .teleported(from: origin, to: destination)
        }
        return report
    }
}
```

- [ ] **Step 4a: Record actual traversal direction at the movement funnels**

Add `var mapTransitions: [MapTransition] = []` to `Scratch`. Extend `walkPlayer(to:)` to `walkPlayer(to:direction:)`, defaulting direction to `nil`; record the origin before mutation and append a transition after a real location change. Record directionless changes in `teleportPlayer(to:)` too. These records live only in Scratch, never WorldState, so they add nothing to SAVE or UNDO serialization.

```swift
mutating func walkPlayer(to room: EntityID, direction: Direction? = nil) {
    let origin = state.playerLocation
    state.setPlayerLocation(walkingTo: room)
    roomsOccupied.append(room)
    if origin != room {
        mapTransitions.append(MapTransition(from: origin, to: room, direction: direction))
    }
}

mutating func teleportPlayer(to room: EntityID) {
    let origin = state.playerLocation
    state.setPlayerLocation(placingAt: room)
    roomsOccupied.append(room)
    if origin != room {
        mapTransitions.append(MapTransition(from: origin, to: room, direction: nil))
    }
}
```

Add `direction: Direction? = nil` to `DefaultActions.enter` and pass it to `walkPlayer`. In every successful branch of `travel`, pass the actual `direction` to `enter`. ENTER-by-door-name, FOLLOW and EXIT-on-foot already go through travel, so they now record the chosen direction without examining the exit table afterward. An author calling directionless `enter` keeps the default; it produces an arrival without a map line. Never evaluate a conditional/dynamic destination again just to derive a report.

In `GameWorld.commit`, initialize the returned TurnResult's movement from the recorded transitions:

```swift
var result = TurnResult(
    output: scratch.output.joined(separator: "\n\n"),
    isFinished: scratch.state.status.isFinal,
    status: statusLine(),
    paragraphs: scratch.command?.intent.isMeta == true ? [] : scratch.output,
    asides: scratch.asides)
if let first = scratch.mapTransitions.first,
    first.from != scratch.state.playerLocation {
    if scratch.mapTransitions.count == 1,
        let direction = first.direction {
        result.report.movement = .walked(
            from: first.from, to: first.to, direction: direction)
    } else {
        result.report.movement = .teleported(
            from: first.from, to: scratch.state.playerLocation)
    }
}
return result
```

The public report represents one net arrival, so a turn with multiple player-location changes is conservatively directionless rather than inventing a direct edge across intermediate rooms. A round trip ending at its origin reports no movement, matching the spec's location-change condition. `perform(_:)` subsequently adds parser information and recognizes state replacement; direct REPL/MCP audited paths retain their existing parser-audit behavior.

- [ ] **Step 4b: Pin custom movement and state-replacement cases**

Add a second fixture whose GO-north before rule calls `arrive(at: garden)` and handles the command. Use the existing CartographyGame with a parameterless companion fixture rather than changing its default behavior. Include two distinct exits onto the same room and a gate that blocks only the first compass-order candidate for FOLLOW; the recorded direction must be the one travel actually used. Include an onEnter teleport and a self-loop exit.

```swift
@Test func aParsedDirectionDoesNotTurnATeleportIntoAWalk() async throws {
    let world = try GameWorld(game: RedirectedMovementGame(), seed: 0)
    _ = await world.begin()
    let report = await world.perform("north").report
    #expect(report.movement == .teleported(
        from: EntityID("hall"), to: EntityID("garden")))
}

@Test func aRestoreFilenameRelocatesInsteadOfDrawingAnExit() async throws {
    let world = try await world()
    _ = await world.perform("save")
    _ = await world.perform("hall-slot")
    _ = await world.perform("north")
    _ = await world.perform("restore")
    #expect(await world.perform("hall-slot").report.movement == .relocated(to: hall))
}
```

Add this fixture to CartographyGames.swift:

```swift
struct RedirectedMovementGame: Game {
    let title = "Redirected Movement"
    let hall = Location { name("Hall"); description("A hall.") }
    let garden = Location { name("Garden"); description("A garden.") }
    var map: WorldMap {
        player.starts(in: hall)
        hall.north(garden)
    }
    var rules: Rules {
        hall.before(.go) {
            arrive(at: garden)
            try handled()
        }
    }
}
```

Test FOLLOW and ENTER on the two-exit fixture through the actual default handlers, not a fake audit. Base the FOLLOW routes on the existing FollowTests' two-exit and conditional-gate fixtures and assert the returned report's actual direction as well as their existing transcript behavior. Assert that an onEnter teleport never reports a walked edge to its final non-exit destination, and that the self-loop reports `nil`. These checks prevent the superseded plan's parsed-direction and adjacent-room inference from returning.

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
        result.report = report(of: audit, from: origin, recorded: performed.report.movement)
        return result
    }
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `swift test --filter TurnReportTests` Expected: the original eight report tests and the added causal-movement/state-replacement tests pass.

- [ ] **Step 7: Run the whole suite**

Run: `swift test` Expected: all tests pass.

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

### Task 3: `vocabulary()`

**Files:**
- Create: `Sources/Gnusto/Engine/GameWorld+Vocabulary.swift`
- Test: `Tests/GnustoTests/VocabularyTests.swift`
- Modify: `Sources/Gnusto/Documentation.docc/CustomFrontEnds.md`

**Interfaces:**
- Consumes: `CartographyGame` from Task 2; internal `GameWorld.currentScope(orders:)`, `GameWorld.pendingPrompt`, `Vocabulary` (`itemLexicons`, `sortedVerbWords`, `sortedDirectionWords`, `prepositions`, `noiseWords`, and the statics `reservedWords`, `conjunctions`, `exclusions`, `possessives`).
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

Run: `swift test --filter VocabularyTests` Expected: build failure, `value of type 'GameWorld' has no member 'vocabulary'`.

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

Run: `swift test --filter VocabularyTests` Expected: 3 tests pass.

- [ ] **Step 4a: Verify repeated vocabulary queries leave state untouched**

Add this test to VocabularyTests and run that suite again:

```swift
@Test func repeatedVocabularyQueriesDoNotChangeTheWorld() async throws {
    let world = try await world()
    let before = await world.snapshot()
    for _ in 0..<5 { _ = await world.vocabulary() }
    let after = await world.snapshot()
    #expect(after.moves == before.moves)
    #expect(after.rngState == before.rngState)
    #expect(after.globals == before.globals)
}
```

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

### Task 4: `mapView()`, and the milestone's checks

**Files:**
- Create: `Sources/Gnusto/Engine/GameWorld+MapView.swift`
- Test: `Tests/GnustoTests/MapViewTests.swift`
- Modify: `Sources/Gnusto/Declarations/Traits.swift` and `Sources/Gnusto/Engine/GameDefinition.swift` (turn Task 1's two code spans into links)
- Modify: `Sources/Gnusto/Documentation.docc/CustomFrontEnds.md`

**Interfaces:**
- Consumes: `CartographyGame` from Task 2; `LocationDefinition.mapRegion` and `GameDefinition.secretExits` from Task 1; internal `ExitTarget`, `Visibility.isDark(at:definition:state:)`, `Visibility.isPerceivable(_:definition:state:)`, `TurnFrame(definition:state:descriptionMode:)`, `Ctx.$frame`, `TurnFrame.retire()`.
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

Run: `swift test --filter MapViewTests` Expected: build failure, `cannot find 'MapExit' in scope`.

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

Run: `swift test --filter MapViewTests` Expected: the six original tests pass.

- [ ] **Step 4a: Verify exit-condition writes are discarded**

Add the following fixture to CartographyGames.swift and the test to MapViewTests.swift. The exit predicate is deliberately impure; it must execute against the query's throwaway frame rather than the saved/live world.

```swift
struct QueryMutationGame: Game {
    let title = "Query Mutation"
    @Global var probes = 0
    let hall = Location { name("Hall"); description("A hall.") }
    let garden = Location { name("Garden"); description("A garden.") }
    var map: WorldMap {
        player.starts(in: hall)
        hall.east(garden, when: { probes += 1; return true }, otherwise: "Closed.")
    }
}

@Test func anExitConditionCannotCommitItsWritesThroughAQuery() async throws {
    let world = try GameWorld(game: QueryMutationGame(), seed: 0)
    _ = await world.begin()
    let before = await world.snapshot()
    for _ in 0..<5 {
        #expect(await world.mapView().exits[.east]?.kind == .open)
    }
    let after = await world.snapshot()
    #expect(after.globals == before.globals)
    #expect(after.moves == before.moves)
    #expect(after.rngState == before.rngState)
}
```

Run `swift test --filter MapViewTests` again; expect the original tests and this mutation regression to pass. Expand the fixture's Swift declarations into the repository's normal formatting before committing.

- [ ] **Step 5: Turn Task 1's code spans into links**

In `Sources/Gnusto/Declarations/Traits.swift` (the `mapRegion(_:)` doc comment) and `Sources/Gnusto/Engine/GameDefinition.swift` (the `secretExits` doc comment), replace `` `GameWorld.mapView()` `` with ``` ``GameWorld/mapView()`` ```.

- [ ] **Step 6: Document it**

In `Sources/Gnusto/Documentation.docc/CustomFrontEnds.md`, add at the end of the `## What a turn did` section (from Task 2):

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

Run: `swift test` Expected: all tests pass.

Run: `swift build --disable-default-traits --scratch-path .build-notraits`

Expected: a successful library build (nothing added lives under `Playtest/`). Also run `bin/build-game CloakOfDarkness --mode deployment` and check that the emitted binary refuses `--mcp`; it is the generated package, rather than a root executable product, that now owns the deployed configuration.

Run: `.build/checkouts/Persnicket/bin/ci-lint-setup && xcrun swift-format lint --strict --parallel --recursive --configuration .swift-format Sources Tests` Expected: no output. If it reports anything, fix it, re-run, and commit the fix as `style: satisfy the strict lint`.

Run: `node .claude/workflows/playtest.dryrun.mjs` Expected: passes.

Run: `swift package --allow-writing-to-directory .context/docs generate-documentation --target Gnusto --output-path .context/docs --warnings-as-errors` Expected: `Finished building documentation` with no warnings. A warning here is almost always a double-backtick link to an internal symbol; change it to a single-backtick code span.

Run: `bin/playtest-preflight Zork1` Expected: every row green using the generated development launcher from milestone 1A.

## Coverage and Completion

| Spec requirement | Task |
|---|---|
| mapRegion and secret declarations, bootstrap errors and Zork maze annotation | 1 |
| understood/unknownWords and causal walked/teleported/relocated movement | 2 |
| full sorted vocabulary and filename context | 3 |
| filtered map view, no destination leakage and throwaway query state | 4 |
| traits-off build, migrated terminal/preflight checks, lint and DocC | 4 |

Before completion, run the migrated terminal deployment/MCP isolation check from milestone 1A against the new engine. Record local results separately from hosted Linux/iOS CI and live terminal checks. Yonk first light, mapper rendering and voice integration remain milestones 2–6.
