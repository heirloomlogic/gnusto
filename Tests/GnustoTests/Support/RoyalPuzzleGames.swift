import Gnusto

// The spike verb for issue #131. `["push", .direction]` is the shape the
// Dungeon charter predicted. The rest are the discovery: a direction slot is
// barred from sharing a pattern with an *object* slot, but not with a literal
// word, so mainframe Zork's `PUSH THE SANDSTONE WALL NORTH` can be bought back
// one spelling at a time. What cannot be bought back is the binding — a
// literal is not a resolved object, so `Command.directObject` stays nil and
// the rule below cannot tell which wall the player named. It pushes whatever
// is in that direction. `pushMarbleWall` in a square with sandstone to the
// north pushes the sandstone; see `theNounInALiteralRowIsDecorative`.
//
// The Swift name cannot be `push`: `Intent.push` is already a core constant.
extension Intent {
    #verb(
        "pushWall",
        ["push", .direction],
        ["push", "wall", .direction],
        ["push", "sandstone", "wall", .direction],
        ["push", "marble", "wall", .direction])
}

/// What stands in one square of the puzzle floor.
enum PuzzleCell: String, Codable, Sendable {
    /// Walkable, and the only thing a block can be pushed into.
    case floor
    /// Pushable one square at a time.
    case sandstone
    /// Bedrock in all but name.
    case marble
    /// The sandstone block with the ladder cut into it — pushable, and the
    /// only one that reaches the ceiling.
    case ladder
}

/// The Royal Puzzle's geometry, and where the player stands inside it.
///
/// A wrapper struct rather than a bare array so the `GlobalValue` conformance
/// is owned here instead of declared retroactively on a standard-library type,
/// and flat rather than nested because every read of a `@Global` decodes and
/// every write encodes.
struct PuzzleGrid: Codable, Sendable, GlobalValue {
    static let width = 4
    static let height = 4

    /// The only directions the grid models, clockwise — which is also the
    /// order the room description reads them out in. `Direction` is
    /// `CaseIterable` over all twelve, so the subset has to be named
    /// somewhere; it is named once.
    static let cardinals: [Direction] = [.north, .east, .south, .west]

    /// Under the ceiling hole the ladder block has to reach.
    static let daylightSquare = 0
    /// Where the slot and the low door are cut into the outer wall.
    static let doorSquare = 7
    /// The square the brass card lies in, once its block is pushed off it.
    static let cardSquare = 10
    /// Where the niche and the hatch are cut into the outer wall.
    static let hatchSquare = 12
    /// Where the player lands, coming down through the anteroom floor.
    static let entrySquare = 14

    static let initialCells: [PuzzleCell] = [
        .floor, .floor, .floor, .floor,
        .floor, .marble, .ladder, .floor,
        .marble, .floor, .sandstone, .floor,
        .floor, .floor, .floor, .floor,
    ]

    var cells = PuzzleGrid.initialCells
    var playerSquare = PuzzleGrid.entrySquare

    init() {}

    /// A stale save has to degrade rather than trap: `Global`'s getter
    /// `fatalError`s when a stored value fails to decode instead of falling
    /// back to the declared default, and save validation only checks that a
    /// `.data` case is a `.data` case — it cannot tell one payload from
    /// another. So every field decodes leniently and keeps its default.
    init(from decoder: any Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        if let decoded = try? box.decode([PuzzleCell].self, forKey: .cells),
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
    func cell(at square: Int) -> PuzzleCell {
        cells.indices.contains(square) ? cells[square] : .marble
    }

    /// The square one step in `direction`, or `nil` at the puzzle's outer wall.
    ///
    /// The column arithmetic is checked rather than assumed: a bare
    /// `square - 1` from column zero wraps onto the end of the previous row
    /// instead of leaving the grid.
    func neighbour(of square: Int, _ direction: Direction) -> Int? {
        let row = square / Self.width
        let column = square % Self.width
        switch direction {
        case .north: return row > 0 ? square - Self.width : nil
        case .south: return row < Self.height - 1 ? square + Self.width : nil
        case .west: return column > 0 ? square - 1 : nil
        case .east: return column < Self.width - 1 ? square + 1 : nil
        default: return nil
        }
    }

    /// Whether two squares share an edge.
    func isAdjacent(_ square: Int, _ other: Int) -> Bool {
        Self.cardinals.contains { neighbour(of: square, $0) == other }
    }

    /// What the player can see from where they stand, one label per cardinal,
    /// in the order `cardinals` lists them. `nil` is the outer wall.
    var surroundings: [PuzzleCell?] {
        Self.cardinals.map { neighbour(of: playerSquare, $0).map(cell(at:)) }
    }

    /// Whether the player is standing in the grid's top row.
    var isOnTopRow: Bool {
        playerSquare / Self.width == 0
    }

    /// Whether the ladder block stands under the ceiling hole with the player
    /// beside it — the whole win condition, read by a conditional exit.
    var ladderIsClimbable: Bool {
        cell(at: Self.daylightSquare) == .ladder
            && isAdjacent(playerSquare, Self.daylightSquare)
    }

    /// What happened when the player tried to walk one square.
    enum StepOutcome: Equatable {
        case moved
        case outerWall
        case blocked(by: PuzzleCell)
        case notCardinal
    }

    /// What happened when the player tried to push what was in front of them.
    ///
    /// `.moved` carries the square the block came *from* — which is where the
    /// player now stands — and the square it went *to*, because both matter to
    /// the card lying under one of them.
    enum PushOutcome: Equatable {
        case moved(from: Int, to: Int)
        case outerWall
        case nothingThere
        case immovable
        case blockedByWall
        case blockedByOuterWall
        case notCardinal
    }

    /// Walks the player one square. The puzzle's rule, enforced here rather
    /// than in the code that picks which sentence to print.
    mutating func step(_ direction: Direction) -> StepOutcome {
        guard Self.cardinals.contains(direction) else { return .notCardinal }
        guard let target = neighbour(of: playerSquare, direction) else { return .outerWall }
        let standing = cell(at: target)
        guard standing == .floor else { return .blocked(by: standing) }
        playerSquare = target
        return .moved
    }

    /// Pushes whatever stands one square away in `direction`. A block moves
    /// only into open floor, and the player always ends on the square it left
    /// — the two invariants that define the puzzle.
    mutating func push(_ direction: Direction) -> PushOutcome {
        guard Self.cardinals.contains(direction) else { return .notCardinal }
        guard let target = neighbour(of: playerSquare, direction) else { return .outerWall }
        let block = cell(at: target)
        switch block {
        case .floor: return .nothingThere
        case .marble: return .immovable
        case .sandstone, .ladder:
            guard let beyond = neighbour(of: target, direction) else {
                return .blockedByOuterWall
            }
            guard cell(at: beyond) == .floor else { return .blockedByWall }
            cells[target] = .floor
            cells[beyond] = block
            playerSquare = target
            return .moved(from: target, to: beyond)
        }
    }
}

/// Every player-facing string in one place, the way `Sources/Zork1/Regions/`
/// keeps its `Prose+*.swift` files — the transcript tests are dense substring
/// checks, so they have exactly one thing to point at.
private enum Prose {
    static let anteroomOpen = """
        A small square room, swept bare, with sand drifted into the corners. A hole gapes in \
        the middle of the floor, and at the far end a second opening looks down into shadow.
        """
    static let anteroomSealed = """
        A small square room, swept bare. Where the hole was there is packed sand without a \
        seam in it. At the far end the second opening still looks down into shadow.
        """
    static let sideRoom = """
        A cell hollowed out behind the puzzle's east wall, no deeper than a cupboard. The low \
        door is the only way in or out.
        """

    static let dropIn = """
        You lower yourself through and land badly. Above you the sand runs shut over the hole \
        with a sound like a held breath.
        """
    static let holeSealed = """
        The sand has run shut over the hole, and it is packed as hard as the floor around it.
        """
    static let climbOut = """
        You come up through the ceiling hole hand over hand, and the puzzle goes back to being \
        a square of sand.
        """

    static let puzzleBody = """
        You are inside the puzzle, standing in one square of it. Sand grits underfoot and the \
        blocks stand higher than your head.
        """
    static let daylightOutOfReach = """
        Above the northwest square a hole of daylight shows in the ceiling, well out of reach.
        """
    static let daylightReachable = """
        The block with the ladder stands under the daylight, and the rungs go up into it.
        """
    static let doorWallShut = """
        The outer wall is at your shoulder. A narrow slot is cut into it at waist height, and \
        under the slot a low door, shut.
        """
    static let doorWallOpen = """
        The outer wall is at your shoulder. The low door under the slot stands open on the dark.
        """
    static let hatchWallShut = """
        The outer wall is at your shoulder. A niche the width of a card is cut into it, and \
        beside the niche a hatch, shut.
        """
    static let hatchWallOpen = """
        The outer wall is at your shoulder. The hatch beside the niche stands open on a crawlway.
        """

    /// The four labels the room description reads off the grid. This is the
    /// geometry the player navigates by, so it is the thing that must change.
    static func label(_ cell: PuzzleCell?) -> String {
        switch cell {
        case nil: "the outer wall"
        case .floor: "open floor"
        case .sandstone: "a sandstone wall"
        case .marble: "a marble wall"
        case .ladder: "the sandstone wall with the ladder cut into it"
        }
    }

    /// The four labels, in `PuzzleGrid.cardinals` order.
    static func surroundings(_ cells: [PuzzleCell?]) -> String {
        let clauses = zip(PuzzleGrid.cardinals, cells).map { "the \($0.rawValue), \(label($1))" }
        return "To \(clauses.joined(separator: "; to "))."
    }

    // Movement refusals. Each names the material — see the type comment on
    // `RoyalPuzzleGame` for why that rules out a conditional exit.
    static let outerWallInTheWay = """
        That is the outer wall of the puzzle, and it goes down to bedrock.
        """
    static let marbleInTheWay = """
        A marble wall stands in the way. Marble does not move.
        """
    static let sandstoneInTheWay = """
        A sandstone wall stands in the way. It might move, if you pushed it.
        """
    static let ladderInTheWay = """
        The wall with the ladder cut into it stands in the way.
        """
    static let noDiagonals = """
        The squares of the puzzle meet edge to edge. You can go north, south, east or west.
        """
    static let floorIsBedrock = """
        The floor is a hand's depth of sand over bedrock.
        """

    // Push refusals.
    static let pushWhichWay = """
        Push which way? North, south, east or west.
        """
    static let pushNeedsADirection = """
        In here a wall is pushed by direction: push north, or push wall north.
        """
    static let nothingButOuterWall = """
        There is nothing to push that way but the outer wall.
        """
    static let nothingInThatSquare = """
        There is nothing in that square to push.
        """
    static let marbleUnimpressed = """
        You set your shoulder to the marble. The marble is unimpressed.
        """
    static let blockedByWall = """
        The wall shifts an inch and stops. There is another wall hard behind it.
        """
    static let blockedByOuterWall = """
        The wall shifts an inch and stops. There is nowhere left for it to go.
        """

    static func wallGrinds(_ direction: Direction) -> String {
        "The wall grinds a full square \(direction.rawValue) and settles. You step into the gap."
    }

    // The card.
    static let cardRevealed = """
        Under where the wall stood, pressed flush into the sand, lies a thin brass card.
        """
    static let cardCrushed = """
        The wall settles into the square with a dry snap. Whatever was under it is under it now.
        """
    static let cardAtYourFeet = """
        A thin brass card lies at your feet, pressed into the sand.
        """
    static let cardAcrossTheFloor = """
        A thin brass card lies in the square the sandstone wall used to stand in.
        """
    static let cardOutOfReach = """
        The card is squares away from you, across the sand.
        """

    // The two slots, and the one card that can only feed one of them.
    static let slotOutOfReach = """
        The slot is cut into the east wall, and the east wall is not within reach from here.
        """
    static let nicheOutOfReach = """
        The niche is cut into the west wall, and the west wall is not within reach from here.
        """
    static let slotTakesOnlyTheCard = """
        The slot is a card's width and no more.
        """
    static let nicheTakesOnlyTheCard = """
        The niche is a card's width and no more.
        """
    static let mustHoldTheCard = """
        You would have to be holding it.
        """
    static let doorOpens = """
        The card goes into the slot to the hilt and does not come back out. Under it, the low \
        door swings inward.
        """
    static let hatchOpens = """
        The card goes into the niche to the hilt and does not come back out. Beside it, the \
        hatch swings inward on a crawlway going up.
        """

    // The conditional exits. Each of these is one string covering every case
    // that reaches it, so each has to stay true in all of them.
    static let nothingReachesTheCeiling = """
        Nothing within reach will take you as high as the ceiling.
        """
    static let lowDoorShut = """
        The low door is shut, and there is no handle on this side.
        """
    static let hatchShut = """
        The hatch is shut, and it is a slab of the same stone as the wall.
        """
}

/// The Royal Puzzle spike (issue #131): a room whose geometry the player
/// rewrites, built entirely out of things the engine already has.
///
/// The whole 4×4 grid is **one `Location`**. The player's square within it
/// lives in a `@Global` struct alongside the cell states; walking from square
/// to square is a `before(.go)` rule, not the exit table. No exit kind fits:
/// there is no destination to compute, since every step stays in this room,
/// and a blocked step has to name *which material* is in the way — where a
/// conditional exit's `otherwise:` is one string fixed at declaration and a
/// `toward:` exit cannot refuse at all. The three ways *out* of the room — the
/// ladder, the low door, the hatch — are genuine conditional exits whose
/// `when:` closures read the grid.
///
/// ```
///        c0            c1            c2            c3
/// r0   0 daylight    1 floor       2 floor       3 floor
/// r1   4 floor       5 MARBLE      6 LADDER      7 floor  ← slot, low door
/// r2   8 MARBLE      9 floor      10 SAND/card  11 floor
/// r3  12 floor      13 floor      14 START      15 floor
///      ↑ niche, hatch
/// ```
///
/// Every step and every push calls `describeSurroundings()`, so the room name
/// reprints on each one. That is deliberate — the description *is* the state —
/// and not something a play-test should file.
///
/// Only one starting grid exists, because `cachedWorld` keys its cache on the
/// game's *type*: a second `RoyalPuzzleGame` configured differently would
/// silently be handed the first one's world.
struct RoyalPuzzleGame: Game {
    let title = "The Royal Puzzle"
    let intro = "A spike, not a game: one room, and the room moves."

    @Global var grid = PuzzleGrid()
    @Global var holeSealed = false
    @Global var cardRevealed = false
    @Global var lowDoorOpen = false
    @Global var hatchOpen = false

    let anteroom = Location {
        name("Small Square Room")
    }
    let puzzle = Location {
        name("Room in a Puzzle")
    }
    let sideRoom = Location {
        name("Side Room")
        description(Prose.sideRoom)
    }

    let book = Item {
        name("black book")
        description("A slim black book, its boards warped by three centuries of sand.")
    }
    let card = Item {
        name("brass card")
        adjectives("thin")
        description("A card of thin brass, cut square, with no marking on either face.")
    }

    let floorHole = Item {
        name("hole")
        synonyms("opening")
        description("A hole in the floor, and sand at the lip of it running slowly in.")
        scenery
    }
    // The material is a synonym on both walls, not just the adjective a
    // multi-word `name` already derives: a noun phrase's last word has to be
    // a noun, so without it `push sandstone` resolves to nothing and answers
    // "You can't see any such thing" about the block the room just described.
    let sandstoneWall = Item {
        name("sandstone wall")
        synonyms("sandstone")
        description("Sandstone, cut square and set on end. It would move, if it were pushed.")
        scenery
    }
    let marbleWall = Item {
        name("marble wall")
        synonyms("marble")
        description("White marble veined with grey. It has not moved in three hundred years.")
        scenery
    }
    let ladderBlock = Item {
        name("ladder")
        synonyms("rungs")
        description("Rungs cut into the face of a sandstone block, going up past your head.")
        scenery
    }
    let outerWall = Item {
        name("outer wall")
        description("The wall the whole puzzle sits inside. It goes down to bedrock.")
        scenery
    }
    let daylight = Item {
        name("daylight")
        synonyms("ceiling")
        description("A square of daylight in the ceiling, above the northwest square.")
        scenery
    }
    let slot = Item {
        name("slot")
        description("A slot cut into the east wall at waist height, a card's width across.")
        scenery
    }
    let lowDoor = Item {
        name("low door")
        description("A door under the slot, low enough that you would have to stoop.")
        scenery
    }
    let niche = Item {
        name("niche")
        description("A niche cut into the west wall, a card's width across.")
        scenery
    }
    let hatch = Item {
        name("hatch")
        description("A hatch beside the niche, cut from the same stone as the wall.")
        scenery
    }
    let sand = Item {
        name("sand")
        synonyms("floor")
        description("Sand, a hand's depth of it, drifted into the angles of the blocks.")
        scenery
    }

    var verbs: [SyntaxRule] {
        [.pushWall]
    }

    var map: WorldMap {
        // The drop in is one-way: the sand runs shut behind you.
        anteroom.down(puzzle, when: { !holeSealed }, otherwise: Prose.holeSealed)

        // The three ways out, all of them conditional exits reading the grid
        // or the state the grid produced. This is the half of the issue's
        // expected shape that holds: a real exit *can* read the grid. What it
        // cannot do is change where it leads, or vary why it said no.
        puzzle.up(anteroom, when: { grid.ladderIsClimbable }, otherwise: Prose.nothingReachesTheCeiling)
        puzzle.east(sideRoom, when: { lowDoorOpen }, otherwise: Prose.lowDoorShut)
        puzzle.west(anteroom, when: { hatchOpen }, otherwise: Prose.hatchShut)
        sideRoom.west(puzzle)

        player.starts(in: anteroom)
        book.starts(in: sideRoom)

        floorHole.starts(in: anteroom)
        sandstoneWall.starts(in: puzzle)
        marbleWall.starts(in: puzzle)
        ladderBlock.starts(in: puzzle)
        outerWall.starts(in: puzzle)
        daylight.starts(in: puzzle)
        slot.starts(in: puzzle)
        lowDoor.starts(in: puzzle)
        niche.starts(in: puzzle)
        hatch.starts(in: puzzle)
        sand.starts(in: puzzle)
    }

    var rules: Rules {
        anteroom.describe {
            holeSealed ? Prose.anteroomSealed : Prose.anteroomOpen
        }

        // Climbing out with the book is the win. Without it, the sand has run
        // shut and the puzzle keeps the book — exactly one correct order.
        anteroom.onEnter {
            guard book.isHeld else { return }
            say(Prose.climbOut)
            try end(won: true)
        }

        // The room the player never leaves while solving it. `.entry` mode is
        // brief on a revisited room, which would print the room's name and
        // none of its geometry when the player walks back in from the Side
        // Room — so the description is replaced outright with a verbose one.
        puzzle.onEnter {
            if !holeSealed {
                holeSealed = true
                say(Prose.dropIn)
            }
            describeSurroundings()
            try reply("")
        }

        puzzle.describe {
            let state = grid
            var paragraphs = [Prose.puzzleBody, Prose.surroundings(state.surroundings)]
            if state.isOnTopRow {
                paragraphs.append(
                    state.ladderIsClimbable ? Prose.daylightReachable : Prose.daylightOutOfReach)
            }
            if state.playerSquare == PuzzleGrid.doorSquare {
                paragraphs.append(lowDoorOpen ? Prose.doorWallOpen : Prose.doorWallShut)
            }
            if state.playerSquare == PuzzleGrid.hatchSquare {
                paragraphs.append(hatchOpen ? Prose.hatchWallOpen : Prose.hatchWallShut)
            }
            return paragraphs.joined(separator: "\n\n")
        }

        // Walking the grid. Location `before` rules run at stage 3, ahead of
        // stage 4's exit lookup, so this intercepts movement without touching
        // the exit table — and falls through, plainly, at the three places
        // where a real exit owns the direction. The grid is not read at all on
        // those paths: each read of a struct `@Global` is a JSON decode.
        puzzle.before(.go) {
            guard let direction = command.direction else { return }
            switch direction {
            case .up: return
            case .down: try refuse(Prose.floorIsBedrock)
            default: break
            }
            var state = grid
            if direction == .east, state.playerSquare == PuzzleGrid.doorSquare { return }
            if direction == .west, state.playerSquare == PuzzleGrid.hatchSquare { return }
            switch state.step(direction) {
            case .notCardinal: try refuse(Prose.noDiagonals)
            case .outerWall: try refuse(Prose.outerWallInTheWay)
            case .blocked(.marble): try refuse(Prose.marbleInTheWay)
            case .blocked(.sandstone): try refuse(Prose.sandstoneInTheWay)
            case .blocked: try refuse(Prose.ladderInTheWay)
            case .moved:
                grid = state
                describeSurroundings()
                try reply("")
            }
        }

        // Pushing. Every path out of this rule replies or refuses: nothing in
        // the engine rolls a turn back, so a body that mutated the grid and
        // then fell through would print "You can't do that." over a world that
        // had already moved, and leave the UNDO snapshot a turn stale.
        puzzle.before(.pushWall) {
            guard let direction = command.direction else { try refuse(Prose.pushWhichWay) }
            var state = grid
            switch state.push(direction) {
            case .notCardinal: try refuse(Prose.noDiagonals)
            case .outerWall: try refuse(Prose.nothingButOuterWall)
            case .nothingThere: try refuse(Prose.nothingInThatSquare)
            case .immovable: try refuse(Prose.marbleUnimpressed)
            case .blockedByWall: try refuse(Prose.blockedByWall)
            case .blockedByOuterWall: try refuse(Prose.blockedByOuterWall)
            case .moved(let vacated, let filled):
                grid = state
                say(Prose.wallGrinds(direction))
                if filled == PuzzleGrid.cardSquare, card.isIn(puzzle) {
                    card.vanish()
                    say(Prose.cardCrushed)
                } else if vacated == PuzzleGrid.cardSquare, !cardRevealed {
                    cardRevealed = true
                    card.move(to: puzzle)
                    say(Prose.cardRevealed)
                }
                describeSurroundings()
                try reply("")
            }
        }

        // `push sandstone` reaches the core `.push` intent, whose default says
        // "You can't move that" — of the one thing in this game that plainly
        // does move. Stated on the walls themselves rather than on the room,
        // so `push card` still gets the stock answer. Refusing rather than
        // saying keeps stage 4 from printing its line underneath this one.
        for wall in [sandstoneWall, marbleWall, ladderBlock] {
            wall.before(.push) {
                try refuse(Prose.pushNeedsADirection)
            }
        }

        // Containment is room-granular: the card is "in the room" from the
        // moment it is uncovered, so its listing line and its reach both have
        // to be faked against the player's square by hand.
        card.presence {
            grid.playerSquare == PuzzleGrid.cardSquare
                ? Prose.cardAtYourFeet : Prose.cardAcrossTheFloor
        }
        card.before(.take) {
            try require(grid.playerSquare == PuzzleGrid.cardSquare, else: Prose.cardOutOfReach)
        }

        slot.before(.putIn) {
            try require(command.directObject == card, else: Prose.slotTakesOnlyTheCard)
            try require(grid.playerSquare == PuzzleGrid.doorSquare, else: Prose.slotOutOfReach)
            try require(card.isHeld, else: Prose.mustHoldTheCard)
            card.vanish()
            lowDoorOpen = true
            try reply(Prose.doorOpens)
        }

        niche.before(.putIn) {
            try require(command.directObject == card, else: Prose.nicheTakesOnlyTheCard)
            try require(grid.playerSquare == PuzzleGrid.hatchSquare, else: Prose.nicheOutOfReach)
            try require(card.isHeld, else: Prose.mustHoldTheCard)
            card.vanish()
            hatchOpen = true
            try reply(Prose.hatchOpens)
        }
    }
}
