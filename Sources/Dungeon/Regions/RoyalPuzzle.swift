import Gnusto

extension Intent {
    /// `PUSH <direction>`, and the two wordier spellings the source's own
    /// vocabulary implies. The mainframe addresses the puzzle's walls by the
    /// compass side of the square you are standing in — `CPNWL`, `CPSWL`,
    /// `CPEWL`, `CPWWL` (`dung.355:1377-1403`) — and not by what they are made
    /// of, so `push north wall` is its phrasing rather than an invention.
    ///
    /// The three rows are the three shapes a direction slot can carry a noun
    /// in, and this region wants all of them.
    ///
    /// Row one is the bare direction, which is the whole of the meaning here:
    /// the mainframe pushes a *side*, so `push north` is complete.
    ///
    /// Row two is the **literal** noun. It is matched, never resolved, so
    /// `Command.directObject` stays nil — which costs nothing when the direction
    /// already says everything, and is why issue #151 never bit this region. It
    /// stays because it is the most specific row, so `push wall north` still
    /// takes it rather than asking which of the six walls named `wall` was
    /// meant.
    ///
    /// Row three is the **object slot** #151 added. It buys the spellings the
    /// other two cannot reach — `push sandstone wall north`, `push marble wall
    /// west` — which used to die as "You can't see any such thing", because
    /// `west` is not one of the marble wall's nouns.
    ///
    /// **`push north wall` is still not one of these rows.** #215 made
    /// `["push", .direction, "wall"]` a legal pattern — a direction is one token
    /// wide wherever it sits — but the source's own phrasing was already bought
    /// back the other way, and a fourth row would only duplicate it: the four
    /// compass walls are real items, so `push north wall` resolves to the core
    /// `.push` intent with
    /// `northWall` as its object, and that item's rule performs the shove. Every
    /// spelling ends up in ``DungeonRoyalPuzzle/shove(_:)``.
    ///
    /// The Swift name cannot be `push`: `Intent.push` is already a core
    /// constant.
    #verb(
        "pushWall",
        ["push", .direction],
        ["push", "wall", .direction],
        ["push", .directObject, .direction])
}

/// What stands in one square of the puzzle floor.
///
/// The raw values are the source's own, from the legend at `dung.355:3186`:
/// *"0 is no wall, 1 is fixed wall, -1 is movable wall (-2 is good ladder, -3
/// bad ladder)"*. Keeping them means the grid below can be read straight off
/// `CPUVEC` and checked against it line for line.
enum RoyalPuzzleCell: Int, Codable, Sendable {
    /// Walkable, and the only thing a wall can be pushed into.
    case floor = 0
    /// Marble. Bedrock in all but name.
    case marble = 1
    /// Sandstone. Pushable one square at a time.
    case sandstone = -1
    /// The sandstone block whose rungs actually reach the ceiling.
    case goodLadder = -2
    /// The decoy. Rungs that go nowhere, and the source never lets them win.
    case badLadder = -3

    /// Whether a shoulder against it accomplishes anything. The source tests
    /// `<1? .WL>`, so everything negative moves and only `1` never does.
    var isPushable: Bool { rawValue < 0 }
}

/// The Royal Puzzle's geometry, and where the player stands inside it.
///
/// A wrapper struct rather than a bare array so the `GlobalValue` conformance is
/// owned here instead of declared retroactively on a standard-library type, and
/// flat rather than nested because every read of a `@Global` decodes and every
/// write encodes.
///
/// **Indices are zero-based; the source's are one-based.** `CPUVEC`'s cell *n*
/// is this array's index *n − 1*. The landmark constants below are written in
/// this file's numbering and name the source's in a comment, and
/// `theGridIsTheSourcesGrid` checks each of them, because an off-by-one here
/// would be invisible and would make the puzzle subtly unsolvable.
struct RoyalPuzzleGrid: Codable, Sendable, GlobalValue {
    static let width = 8
    static let height = 8

    /// The four the walls can be pushed along. `CPWALLS` (`dung.355:3190`) has
    /// exactly these, so a diagonal shove has nothing to address.
    static let orthogonals: [Direction] = [.north, .east, .south, .west]

    /// The eight the player can walk, in the order the diagram reads them:
    /// the top row, then the sides, then the bottom row.
    static let ring: [Direction] = [
        .northwest, .north, .northeast,
        .west, .east,
        .southwest, .south, .southeast,
    ]

    /// Source cell 10 — where you land coming down, and the only square under
    /// the ceiling opening.
    static let entrySquare = 9
    /// Source cell 11 — the one square the good ladder has to end up in.
    /// `CPEXIT` hardcodes it (`act3.199:718`); no other adjacency wins.
    static let ladderSquare = 10
    /// Source cell 37 — the square under the movable block, where the card is.
    static let cardSquare = 36
    /// Source cell 52 — the slit and the steel door.
    static let doorSquare = 51

    /// `CPUVEC`, `dung.355:3120-3184`, transcribed row by row. The whole border
    /// is fixed marble, which is why the source's push code needs no bounds
    /// check at all; the playable interior is the 6×6 inside it.
    static let initialCells: [RoyalPuzzleCell] = [
        .marble, .marble, .marble, .marble, .marble, .marble, .marble, .marble,
        .marble, .floor, .sandstone, .floor, .floor, .sandstone, .floor, .marble,
        .marble, .sandstone, .floor, .marble, .floor, .goodLadder, .floor, .marble,
        .marble, .floor, .floor, .floor, .floor, .marble, .floor, .marble,
        .marble, .badLadder, .floor, .floor, .sandstone, .sandstone, .floor, .marble,
        .marble, .floor, .floor, .sandstone, .floor, .floor, .floor, .marble,
        .marble, .marble, .marble, .floor, .floor, .floor, .marble, .marble,
        .marble, .marble, .marble, .marble, .marble, .marble, .marble, .marble,
    ]

    var cells = RoyalPuzzleGrid.initialCells
    var playerSquare = RoyalPuzzleGrid.entrySquare

    init() {}

    /// A stale save has to degrade rather than trap: `Global`'s getter
    /// `fatalError`s when a stored value fails to decode instead of falling back
    /// to the declared default, and save validation only checks that a `.data`
    /// case is a `.data` case — it cannot tell one payload from another. So
    /// every field decodes leniently and keeps its default.
    init(from decoder: any Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        if let decoded = try? box.decode([RoyalPuzzleCell].self, forKey: .cells),
            decoded.count == Self.initialCells.count
        {
            cells = decoded
        }
        if let decoded = try? box.decode(Int.self, forKey: .playerSquare) {
            playerSquare = decoded
        }
    }

    /// What stands in a square. Out of range reads as marble, so a bad index
    /// blocks rather than crashes.
    func cell(at square: Int) -> RoyalPuzzleCell {
        cells.indices.contains(square) ? cells[square] : .marble
    }

    /// How far one step in `direction` moves, as a row and column delta. `nil`
    /// for the directions the grid does not model.
    static func delta(_ direction: Direction) -> (row: Int, column: Int)? {
        switch direction {
        case .north: (-1, 0)
        case .south: (1, 0)
        case .east: (0, 1)
        case .west: (0, -1)
        case .northeast: (-1, 1)
        case .northwest: (-1, -1)
        case .southeast: (1, 1)
        case .southwest: (1, -1)
        default: nil
        }
    }

    /// The two orthogonals a diagonal is made of, or `nil` if it is not one.
    static func components(of direction: Direction) -> (Direction, Direction)? {
        switch direction {
        case .northeast: (.north, .east)
        case .northwest: (.north, .west)
        case .southeast: (.south, .east)
        case .southwest: (.south, .west)
        default: nil
        }
    }

    /// The square one step in `direction`, or `nil` off the grid.
    ///
    /// The column arithmetic is checked rather than assumed: a bare
    /// `square - 1` from column zero wraps onto the end of the previous row
    /// instead of leaving the grid.
    func neighbour(of square: Int, _ direction: Direction) -> Int? {
        guard let delta = Self.delta(direction) else { return nil }
        let row = square / Self.width + delta.row
        let column = square % Self.width + delta.column
        guard (0..<Self.height).contains(row), (0..<Self.width).contains(column) else {
            return nil
        }
        return row * Self.width + column
    }

    /// Whether the good ladder stands in its one square with the player under
    /// the opening — the whole win condition, read by a conditional exit.
    var canClimbOut: Bool {
        playerSquare == Self.entrySquare && cell(at: Self.ladderSquare) == .goodLadder
    }

    /// A ladder the player is standing beside, and which side it is on. The
    /// source is deliberately asymmetric here (`CPLADDER-OBJECT`,
    /// `act3.199:770`): the good ladder counts only to the **east** of you and
    /// the bad one only to the **west**, so a good ladder on your west is not a
    /// ladder as far as the game is concerned.
    var ladderInReach: (side: Direction, works: Bool)? {
        if let east = neighbour(of: playerSquare, .east), cell(at: east) == .goodLadder {
            return (.east, true)
        }
        if let west = neighbour(of: playerSquare, .west), cell(at: west) == .badLadder {
            return (.west, false)
        }
        return nil
    }

    /// The eight squares around the player, in the order the diagram reads
    /// them. `nil` is a corner hidden behind the two walls flanking it; off the
    /// grid reads as marble, which is what the border actually is.
    ///
    /// Model values, not glyphs — every character the diagram draws is chosen
    /// in one place, beside the legend that explains it.
    var diagramRing: [RoyalPuzzleCell?] {
        Self.ring.map { direction in
            guard let square = neighbour(of: playerSquare, direction) else { return .marble }
            return cornerIsBlocked(direction) ? nil : cell(at: square)
        }
    }

    /// Whether the square one step away is open floor.
    private func isOpen(_ direction: Direction) -> Bool {
        guard let square = neighbour(of: playerSquare, direction) else { return false }
        return cell(at: square) == .floor
    }

    /// Whether a diagonal has walls on both of the sides it passes between.
    ///
    /// This is the puzzle's one non-obvious rule — you may not cut a corner —
    /// and both the walker and the diagram need it, so it is stated once.
    /// Always `false` for an orthogonal, which has no corner to cut.
    private func cornerIsBlocked(_ direction: Direction) -> Bool {
        guard let (first, second) = Self.components(of: direction) else { return false }
        return !isOpen(first) && !isOpen(second)
    }

    /// What happened when the player tried to walk one square.
    enum StepOutcome: Equatable {
        case moved
        case wall
        /// Both squares flanking a diagonal are walls, so there is no way
        /// between them.
        case corner
    }

    /// What happened when the player tried to push what was in front of them.
    ///
    /// `.moved` carries only the square the wall went *to*: the square it came
    /// from is where the player now stands, which the grid already reports.
    enum PushOutcome: Equatable {
        case moved(into: Int)
        case onlyAPassage
        case doesNotBudge
        case notPushable
    }

    /// Walks the player one square. The puzzle's rule, enforced here rather than
    /// in the code that picks which sentence to print.
    ///
    /// A direction the grid does not model has no neighbour, so it lands on
    /// `.wall` with everything else that cannot be walked into.
    mutating func step(_ direction: Direction) -> StepOutcome {
        guard let target = neighbour(of: playerSquare, direction) else { return .wall }
        guard !cornerIsBlocked(direction) else { return .corner }
        guard cell(at: target) == .floor else { return .wall }
        playerSquare = target
        return .moved
    }

    /// Pushes whatever stands one square away in `direction`. A wall moves only
    /// into open floor, and the player always ends on the square it left — the
    /// two invariants that define the puzzle.
    mutating func push(_ direction: Direction) -> PushOutcome {
        guard Self.orthogonals.contains(direction) else { return .notPushable }
        guard let target = neighbour(of: playerSquare, direction) else { return .doesNotBudge }
        let wall = cell(at: target)
        guard wall != .floor else { return .onlyAPassage }
        guard wall.isPushable,
            let beyond = neighbour(of: target, direction),
            cell(at: beyond) == .floor
        else {
            return .doesNotBudge
        }
        cells[target] = .floor
        cells[beyond] = wall
        playerSquare = target
        return .moved(into: beyond)
    }
}

/// The Royal Puzzle — three rooms, one of which is sixty-four squares.
///
/// The shape of it: the Small Square Room hangs off the Treasure Room's new east
/// passage, with a hole cut in its floor and the thief's note nailed up beside
/// it. Down the hole is the puzzle proper; south of it, and also reachable from
/// inside the puzzle once the steel door is open, is the Side Room.
///
/// **The whole 8×8 grid is one `Location`.** That is the answer the #131 spike
/// came back with, and `docs/games/dungeon.md` ("The Royal-Puzzle question,
/// answered") carries the reasoning. Walking from square to square is a
/// `before(.go)` rule, which runs at stage 3 and so gets there ahead of the exit
/// lookup; the exit table is never consulted for a step and never has to change.
/// No exit kind fits the job: there is no destination to compute, since every
/// step stays in this room, and a refused step has to say *which* thing is in
/// the way, where a conditional exit's `otherwise:` is one string fixed at
/// declaration. The two ways *out* are genuine conditional exits reading the
/// grid.
///
/// **The source calls it the Chinese Puzzle** (`act3.199:700`, "courtesy of Will
/// Weng"), and its nine exits from `CP` all resolve to the dummy room `FCHMP`
/// under a flag that is permanently false — the mainframe's idiom for "the room
/// function owns every direction". Nine, not four, because **diagonals are
/// legal**; what they cannot do is cut a corner between two walls.
///
/// **Two ladders, and only one of them is a ladder.** `-2` reaches the ceiling
/// and `-3` never does, and the source will not even acknowledge one on the
/// wrong side of you. Both draw as `SS`.
///
/// **The entrance can be destroyed.** Push any wall into the square under the
/// opening and `CPBLOCK` latches — the source never clears it — and the ceiling
/// exit is gone for the rest of the game. What is left is the steel door, which
/// costs the card, and the card is the only thing in here worth points. That is
/// the trap, and it is one-way.
///
/// Seams host-wired in ``Dungeon``: the Treasure Room's east passage, which
/// milestone 4 left open, and the gold card's place in the trophy-case roster.
/// See `FIDELITY.md`.
struct DungeonRoyalPuzzle: GameContent {
    // MARK: - The rooms

    /// `CPANT`. Self-lit in the source (`RLANDBIT` + `RLIGHTBIT`), and always
    /// described because what it says about the hole changes once for good.
    let anteroom = Location {
        name("Small Square Room")
        alwaysDescribed
    }

    /// `CP`. Self-lit, and the description *is* the state of the grid — so it
    /// re-describes on every step and every push. Both halves of #149 are
    /// load-bearing: `alwaysDescribed` is why a rewind still prints the
    /// geometry, and `withRoomName: false` on the re-describe is why a
    /// forty-move solve does not print forty room headings.
    let puzzle = Location {
        name("Room in a Puzzle")
        alwaysDescribed
    }

    /// `CPOUT`. Dark — the source gives it the `ROOM` macro's default flags,
    /// which are `RLANDBIT` alone, where both rooms above carry `RLIGHTBIT`
    /// as well.
    let sideRoom = Location {
        name("Side Room")
        alwaysDescribed
        dark
    }

    // MARK: - The gold card

    /// `GCARD`. Ten to find and fifteen to case, and the only points in the
    /// region — none of its three rooms carries an `RVAL`.
    let goldCard = Item {
        name("gold card")
        adjectives("solid", "engraved")
        synonyms("card", "pass")
        description(Prose.goldCard)
        trait(.weight, 4)
        trait(.takeValue, 10)
        trait(.depositValue, 15)
    }

    // MARK: - The note

    /// `WARNI`. The thief's letter, and the one thing in the region that tells
    /// the player what the region is before they drop into it.
    let warningNote = Item {
        name("note of warning")
        adjectives("worn")
        synonyms("note", "paper", "piece", "warning")
        firstSight(Prose.warningNoteInPlace)
        description(Prose.warningNote)
        trait(.weight, 2)
        trait(.burnable, true)
    }

    // MARK: - The slit and the two faces of the door

    /// `CPSLT`. A container of capacity 4, which is exactly the card's `OSIZE`.
    let slit = Item {
        name("small slit")
        synonyms("slit", "slot")
        description(Prose.puzzleSlit)
        container
        scenery
    }

    /// `CPDOR`, the face of the door inside the puzzle.
    let steelDoor = Item {
        name("steel door")
        synonyms("door")
        description(Prose.puzzleSteelDoor)
        scenery
        door
    }

    /// `CPDR2`, the same door from the Side Room, where it has a handle.
    let sideDoor = Item {
        name("steel door")
        synonyms("door")
        description(Prose.puzzleSideRoomDoor)
        scenery
        door
    }

    // MARK: - Scenery

    /// No static description: what the hole looks like changes for good the
    /// moment a wall comes up under it.
    /// The sand the anteroom names three times, in the room that names it. No
    /// static text and no `floor`: the state is the room's own, and the floor
    /// up here is what the hole is cut *in* — the sand is ten feet under it.
    /// (#233)
    let anteroomSand = Item {
        name("sand")
        adjectives("pale", "smooth")
        synonyms("sand", "sandstone")
        scenery
    }

    let hole = Item {
        name("hole")
        synonyms("opening")
        scenery
    }

    /// The four walls the source addresses by compass side. Not by material:
    /// there is no sandstone-wall object and no marble-wall object anywhere in
    /// `dung.355`, because which one you are shoving depends on where you stand.
    ///
    /// No static `description` — these are the only things in the region that
    /// name a direction, so they are the only ones that can say what is actually
    /// on that side. The `describe { }` rules read the grid.
    private static func compassWall(_ side: Direction) -> Item {
        Item {
            name("\(side.rawValue) wall")
            synonyms("walls")
            scenery
        }
    }

    let northWall = compassWall(.north)
    let southWall = compassWall(.south)
    let eastWall = compassWall(.east)
    let westWall = compassWall(.west)

    /// The two materials, so that the diagram's own legend answers. Neither
    /// names a side, so neither can be pushed on its own — `push marble wall`
    /// gets the syntax back. Given a direction, though, the direction is the
    /// whole of the instruction, and `push marble wall north` shoves north.
    let marbleWall = Item {
        name("marble wall")
        synonyms("marble")
        description(Prose.puzzleWallExamined)
        scenery
    }

    let sandstoneWall = Item {
        name("sandstone wall")
        synonyms("sandstone")
        description(Prose.puzzleWallExamined)
        scenery
    }

    /// No static description: which of the two ladders is beside you, and
    /// whether one is at all, is a question about the square you are standing
    /// in. A `describe { }` rule answers it.
    let ladder = Item {
        name("ladder")
        synonyms("rungs")
        scenery
    }

    /// No static description either, for ``ladder``'s reason: whether the
    /// opening is over your head is a question about the square you are
    /// standing in. The room's own paragraph has always got this right —
    /// ``puzzleDescription`` names the opening only in
    /// `RoyalPuzzleGrid.entrySquare` — and the item's examine text did not, so
    /// "It is a long way above your head" was read from all sixty-four
    /// squares, including the sixty-three where `up` answers "There is no way
    /// up from here." (#233)
    let ceilingOpening = Item {
        name("circular opening")
        adjectives("large")
        synonyms("opening", "ceiling")
        scenery
    }

    let sand = Item {
        name("sand")
        synonyms("floor")
        description(Prose.puzzleSandExamined)
        scenery
    }

    // MARK: - State

    /// The whole geometry, and the player's square within it.
    @Global var grid = RoyalPuzzleGrid()

    /// `CPBLOCK!-FLAG`. Latches when a wall is pushed into the entry square, and
    /// the source never clears it.
    @Global var entranceBlocked = false

    /// `CPOUT!-FLAG`. Set in exactly one place — the slit, which eats the card
    /// doing it.
    @Global var doorOpen = false

    /// `CPPUSH!-FLAG`. Once a wall has moved, the room stops describing itself
    /// in prose and starts drawing diagrams.
    @Global var hasPushed = false

    /// Whether the card has been brought into the room's containment. The
    /// source keeps a separate object list per square (`CPOBJS`); Gnusto's
    /// containment is room-granular, so the card joins the room the first time
    /// the player stands in its square. Issue #150.
    @Global var cardUncovered = false

    var verbs: [SyntaxRule] { [.pushWall] }

    // MARK: - Map

    /// Split in two for the reason `docs/games/dungeon.md` records as its
    /// eighth seam lesson: peak bootstrap stack depth scales with the largest
    /// single declaration body, and a test body runs on a cooperative thread
    /// with far less stack than `main`. Adding this bundle to a game that
    /// already had fifteen was enough to overflow it, and the whole suite died
    /// with a signal rather than a message.
    var map: WorldMap {
        puzzleExits
        puzzlePlacements
    }

    @MapBuilder private var puzzleExits: WorldMap {
        anteroom.south(sideRoom)
        anteroom.down(puzzle, when: { !entranceBlocked }, otherwise: Prose.puzzleWayDownBlocked)

        sideRoom.north(anteroom)
        sideRoom.east(puzzle, when: { doorOpen }, otherwise: Prose.puzzleSteelDoorBars)

        // The two ways out, both conditional exits reading the grid or the state
        // the grid produced. Each `otherwise:` is unreachable in practice: the
        // `before(.go)` rule refuses first, because it can tell *which* of the
        // two reasons applies and a single declared string cannot.
        puzzle.up(anteroom, when: { grid.canClimbOut }, otherwise: Prose.puzzleCeilingTooHigh)
        puzzle.west(sideRoom, when: { doorOpen }, otherwise: Prose.puzzleSteelDoorBars)
    }

    @MapBuilder private var puzzlePlacements: WorldMap {
        warningNote.starts(in: anteroom)
        hole.starts(in: anteroom)
        anteroomSand.starts(in: anteroom)
        sideDoor.starts(in: sideRoom)

        slit.starts(in: puzzle)
        steelDoor.starts(in: puzzle)
        for (wall, _) in wallsBySide { wall.starts(in: puzzle) }
        marbleWall.starts(in: puzzle)
        sandstoneWall.starts(in: puzzle)
        ladder.starts(in: puzzle)
        ceilingOpening.starts(in: puzzle)
        sand.starts(in: puzzle)
    }

    /// Six sub-builders rather than one body, and the count is not fussiness.
    /// See the note on ``map``: this bundle's arrival was enough to overflow the
    /// bootstrap's stack on a test thread, and the documented remedy is to keep
    /// every single declaration body small.
    var rules: Rules {
        roomRules
        puzzleDescription
        movementRules
        pushRules
        cardRules
        ladderRules
    }
}

// MARK: - Rules

extension DungeonRoyalPuzzle {
    /// The three room descriptions, and the one-way drop that starts it all.
    @RuleBuilder fileprivate var roomRules: Rules {
        anteroom.describe {
            entranceBlocked ? Prose.puzzleAnteroomBlocked : Prose.puzzleAnteroom
        }

        sideRoom.describe {
            Prose.puzzleSideRoom(open: doorOpen)
        }

        // Which square you land in depends on which way you came, exactly as
        // the source's `GO-IN` hook does it: down the hole puts you under the
        // opening, and the steel door puts you at the door square.
        puzzle.onEnter {
            if command.direction == .east {
                grid.playerSquare = RoyalPuzzleGrid.doorSquare
            } else {
                grid.playerSquare = RoyalPuzzleGrid.entrySquare
                say(Prose.puzzleDropIn)
            }
        }

        hole.describe {
            entranceBlocked ? Prose.puzzleHoleBlocked : Prose.puzzleHole
        }

        anteroomSand.describe {
            entranceBlocked ? Prose.anteroomSandBlocked : Prose.anteroomSand
        }

        ceilingOpening.describe {
            grid.playerSquare == RoyalPuzzleGrid.entrySquare
                ? Prose.puzzleCeilingOpeningExamined
                : Prose.puzzleCeilingOpeningAcrossTheRoom
        }

        warningNote.before(.read) { try reply(Prose.warningNoteText) }
    }

    /// The room whose description *is* the state of the grid, on its own
    /// because it is the longest closure in the bundle.
    @RuleBuilder fileprivate var puzzleDescription: Rules {
        puzzle.describe {
            let state = grid
            var paragraphs = [openingParagraph(state)]

            // The three squares with anything to say for themselves.
            switch state.playerSquare {
            case RoyalPuzzleGrid.entrySquare:
                paragraphs.append(Prose.puzzleCeilingOpening)
            case RoyalPuzzleGrid.cardSquare:
                paragraphs.append(Prose.puzzleFloorDepressed)
            case RoyalPuzzleGrid.doorSquare:
                paragraphs.append(Prose.puzzleDoorWall(open: doorOpen))
            default:
                break
            }

            if let ladder = state.ladderInReach {
                paragraphs.append(Prose.puzzleLadderOnWall(ladder.side.rawValue))
            }

            return paragraphs.joined(separator: "\n\n")
        }
    }

    /// Prose until the first wall moves, diagrams ever after — the source's
    /// `CPPUSH`.
    fileprivate func openingParagraph(_ state: RoyalPuzzleGrid) -> String {
        guard !hasPushed else { return Prose.puzzleDiagram(state.diagramRing) }
        guard warningNote.isTouched else { return Prose.puzzleRoomAtEntry }
        return Prose.puzzleRoomAtEntry + " " + Prose.puzzleThiefWasRight
    }

    /// Walking the grid. A location `before` rule runs at stage 3, ahead of
    /// stage 4's exit lookup, so this intercepts movement without touching the
    /// exit table — and falls through, plainly, at the two places where a real
    /// exit owns the direction.
    @RuleBuilder fileprivate var movementRules: Rules {
        puzzle.before(.go) {
            guard let direction = command.direction else { return }

            // Answered before the grid is touched at all, because every read of
            // a struct `@Global` is a JSON decode and down needs no state.
            if direction == .down { try refuse(Prose.puzzleFloorIsBedrock) }

            // One decode for the whole body, which is the rule the rest of this
            // game follows: a struct global is touched once, not field by field.
            var state = grid

            switch direction {
            case .up:
                // The exit is conditional, but it cannot say *why* it said no,
                // and there are two different reasons. So the refusals are here
                // and only the success falls through to the exit.
                try announceTheClimb(state)
                return
            case .west where state.playerSquare == RoyalPuzzleGrid.doorSquare:
                // The steel door owns this one. Shut, the exit refuses; open,
                // it leads to the Side Room.
                return
            default:
                break
            }

            switch state.step(direction) {
            case .wall:
                try refuse(Prose.puzzleWallThere)
            case .corner:
                try refuse(Prose.puzzleCannotCutTheCorner)
            case .moved:
                try settle(state)
            }
        }
    }

    /// Pushing. Every path out of these rules replies or refuses: nothing in the
    /// engine rolls a turn back, so a body that mutated the grid and then fell
    /// through would print "You can't do that." over a world that had already
    /// moved, and leave the UNDO snapshot a turn stale.
    @RuleBuilder fileprivate var pushRules: Rules {
        puzzle.before(.pushWall) {
            guard let direction = command.direction else { try refuse(Prose.puzzlePushWhichWay) }
            // The object-slot row binds whatever noun was typed, but the source
            // pushes a *side*, so the direction stays the whole of the
            // instruction and the noun only has to be a wall. Anything else
            // named with a direction gets the syntax rather than a shove.
            if let named = command.directObject, !pushableWalls.contains(named) {
                try refuse(Prose.puzzlePushOnlyWalls)
            }
            try shove(direction)
        }

        // `push north wall` reaches the core `.push` intent with the wall as its
        // object, which is the source's own phrasing — so each wall does the
        // push its own side implies rather than answering "You can't move that."
        // Each also reports what is actually on its side, which is the one
        // question only a direction-named thing can answer.
        for (wall, direction) in wallsBySide {
            wall.before(.push) { try shove(direction) }
            wall.describe {
                let state = grid
                let standing =
                    state.neighbour(of: state.playerSquare, direction)
                    .map(state.cell(at:)) ?? .marble
                return Prose.puzzleWallOnSide(direction.rawValue, standing)
            }
        }

        // The materials are not a side, so there is nothing for them to push.
        // They teach the syntax instead. Stated on the walls rather than on the
        // room, so `push card` still gets the stock answer.
        for wall in materialWalls + [ladder] {
            wall.before(.push) { try refuse(Prose.puzzlePushNeedsADirection) }
        }
    }

    /// The card, the slit, and the ladder the player can put a hand on.
    @RuleBuilder fileprivate var cardRules: Rules {
        // Containment is room-granular and the puzzle is one room, so the room
        // has to say what a square means. Issue #150.
        goldCard.reach(otherwise: Prose.goldCardOutOfReach) {
            grid.playerSquare == RoyalPuzzleGrid.cardSquare
        }

        // The half a reach rule cannot answer: which line the room listing
        // prints. Asked of the square directly rather than through
        // `isReachable`, which would run this same closure *and* walk the scope
        // graph to confirm what placement already guarantees — the card is only
        // ever in `puzzle`, and this only ever runs while the player is there.
        goldCard.presence {
            grid.playerSquare == RoyalPuzzleGrid.cardSquare
                ? Prose.goldCardInPlace : Prose.goldCardAcrossTheFloor
        }

        goldCard.before(.read) { try reply(Prose.goldCardText) }

        slit.reach(otherwise: Prose.puzzleSlitOutOfReach) {
            grid.playerSquare == RoyalPuzzleGrid.doorSquare
        }

        // The slit keeps whatever it is given — the source removes the object
        // before it decides what to say about it. Feeding it the card is the one
        // thing that opens the door, and it costs the card to do it.
        slit.before(.putIn) {
            guard let offered = command.directObject else {
                try refuse(Prose.puzzleSlitTooSmall)
            }
            try require(offered.isHeld, else: Prose.puzzleSlitTooSmall)
            guard offered == goldCard else {
                offered.vanish()
                try reply(Prose.puzzleSlitEatsIt)
            }
            goldCard.vanish()
            doorOpen = true
            try reply(Prose.puzzleCardConfiscated)
        }
    }

    /// The ladder is square-local like the card and the slit, so it is gated the
    /// same way. `climb` needs reach, which makes the rule below a formality;
    /// `examine` does not, so what the ladder *looks* like has to be a rule
    /// reading the grid rather than a static line that would claim rungs in
    /// every square of the puzzle.
    @RuleBuilder fileprivate var ladderRules: Rules {
        ladder.reach(otherwise: Prose.puzzleNoLadderHere) {
            grid.ladderInReach != nil
        }

        // `examine` needs no reach, so this has to answer for a square with no
        // ladder beside it as well — otherwise the description claims rungs in
        // all sixty-four.
        ladder.describe {
            guard let standing = grid.ladderInReach else { return Prose.puzzleNoLadderHere }
            return standing.works ? Prose.puzzleLadderExamined : Prose.puzzleLadderExaminedBad
        }

        // The other spelling of "leave by the ladder". The `up` exit does the
        // travelling for that one; `enter(_:)` is how a rule asks for the same
        // walk, so the two spellings now arrive the same way instead of one of
        // them teleporting.
        ladder.before(.climb) {
            guard grid.canClimbOut else { try refuse(Prose.puzzleHeadOnTheCeiling) }
            say(Prose.puzzleClimbOut)
            try enter(anteroom)
            try handled()
        }
    }
}

// MARK: - The push, and the card under the floor

extension DungeonRoyalPuzzle {
    /// Each compass wall against the direction it stands in, so the four
    /// `before(.push)` rules and the grid agree by construction.
    fileprivate var wallsBySide: [(Item, Direction)] {
        [(northWall, .north), (southWall, .south), (eastWall, .east), (westWall, .west)]
    }

    /// The two substances. They name no side of their own, so they teach the
    /// syntax on a bare `push` and lean on the direction the player typed when
    /// there is one.
    fileprivate var materialWalls: [Item] { [marbleWall, sandstoneWall] }

    /// Every noun `push <something> <direction>` will accept. Derived from the
    /// two rosters the rules already use, so a wall added to the region cannot
    /// be pushable by one spelling and not the other.
    fileprivate var pushableWalls: [Item] {
        wallsBySide.map(\.0) + materialWalls
    }

    /// One shove, from either spelling of the verb.
    ///
    /// - Parameter direction: which side of the square to lean on.
    /// - Throws: always — every branch answers.
    fileprivate func shove(_ direction: Direction) throws -> Never {
        var state = grid
        switch state.push(direction) {
        case .notPushable:
            // A diagonal or a vertical. The source models no wall on those
            // sides, so the answer is the same one a bare `push` gets.
            try refuse(Prose.puzzlePushWhichWay)
        case .onlyAPassage:
            try refuse(Prose.puzzleOnlyAPassage)
        case .doesNotBudge:
            try refuse(Prose.puzzleWallDoesNotBudge)
        case .moved(let filled):
            say(Prose.puzzleWallSlides)

            // The legend, once, on the push that turns the descriptions into
            // diagrams.
            if !hasPushed {
                hasPushed = true
                say(Prose.puzzleDiagramLegend)
            }

            // `CPBLOCK`. One-way, and the source never clears it. No guard on
            // the flag: a wall can only be pushed into open floor, so the entry
            // square cannot be filled twice.
            if filled == RoyalPuzzleGrid.entrySquare {
                entranceBlocked = true
                say(Prose.puzzleEntranceSealed)
            }

            try settle(state)
        }
    }

    /// How a step and a push both end: commit the grid, pick up the card if the
    /// player has just landed on it, redraw, and finish the turn.
    ///
    /// Nothing in the engine rolls a turn back, so a body that mutated the grid
    /// and then fell through would print "You can't do that." over a world that
    /// had already moved. Ending both movers in one `Never`-returning call makes
    /// "every path replies or refuses" structural rather than a comment.
    ///
    /// - Parameter state: the grid as it now stands.
    /// - Throws: always.
    fileprivate func settle(_ state: RoyalPuzzleGrid) throws -> Never {
        grid = state
        uncoverTheCard(at: state.playerSquare)
        // Still in the same room: the heading would claim an arrival that never
        // happened.
        describeSurroundings(withRoomName: false)
        try handled()
    }

    /// The refusals for going `up`, and the line that goes with succeeding.
    ///
    /// The exit itself is conditional and does the moving; what it cannot do is
    /// say *which* of the two reasons it said no, because an `otherwise:` is one
    /// string fixed at declaration.
    ///
    /// - Parameter state: the grid, already decoded by the caller.
    /// - Throws: unless the climb is on, in which case it returns and the exit
    ///   takes over.
    fileprivate func announceTheClimb(_ state: RoyalPuzzleGrid) throws {
        guard state.playerSquare == RoyalPuzzleGrid.entrySquare else {
            try refuse(Prose.puzzleNoWayUp)
        }
        guard state.canClimbOut else { try refuse(Prose.puzzleCeilingTooHigh) }
        say(Prose.puzzleClimbOut)
    }

    /// The card joins the room's contents the first time the player stands in
    /// its square. The source keeps an object list per square and this engine
    /// keeps one per room, so arrival is where the two are reconciled.
    ///
    /// - Parameter square: where the player has just landed. Passed in rather
    ///   than read back off the global, which both callers have just written:
    ///   re-reading it would decode sixty-four cells to recover one `Int` they
    ///   are already holding.
    fileprivate func uncoverTheCard(at square: Int) {
        guard !cardUncovered, square == RoyalPuzzleGrid.cardSquare else { return }
        cardUncovered = true
        goldCard.move(to: puzzle)
    }
}
