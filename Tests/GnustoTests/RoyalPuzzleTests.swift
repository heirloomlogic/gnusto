import Foundation
import GnustoTestSupport
import Testing

@testable import Gnusto

/// The Royal Puzzle spike (issue #131) — a room whose geometry the player
/// rewrites, and the evidence that it needs no engine change to build.
///
/// The fixture is `RoyalPuzzleGame` in `Support/RoyalPuzzleGames.swift`. Its
/// grid, the squares it names, and the solution these tests walk are laid out
/// in that file's doc comment.
/// The nineteen-move solve, written once because three tests walk it and a
/// stale copy of a grid walkthrough still passes an assertion about counts.
private let scriptedSolution = [
    // Down into the puzzle, round to the card's block, push it off.
    "down", "east", "north", "push west", "take card",
    // Round to the slot, spend the card, collect the book.
    "east", "north", "put card in slot", "east", "take book", "west",
    // Walk the ladder block three squares to the ceiling hole.
    "south", "west", "push north", "east", "north",
    "push west", "push west",
    "up",
]

/// The same climb out, minus the detour for the book — so the player leaves
/// empty-handed and the game does not end.
private let climbOutWithoutTheBook = [
    "down", "east", "north", "push west",
    "push north", "east", "north", "push west", "push west",
    "up",
]

struct RoyalPuzzleTests {
    // MARK: - The mechanism

    /// The whole geometry is one opaque `@Global`; and the custom `push` rows
    /// share a verb word with the core intent but not a shape, so the
    /// bootstrap has nothing to complain about — no override warning, and no
    /// unanswered-intent warning either, since a rule names `.pushWall`.
    @Test func theGridIsOneOpaqueGlobalAndTheVerbRowsCollideWithNothing() throws {
        let (definition, _) = try Bootstrap.build(RoyalPuzzleGame())
        guard case .data(let typeName, _)? = definition.globalDefaults[EntityID("grid")] else {
            Issue.record("the grid should be boxed into the .data case")
            return
        }
        #expect(typeName.contains("PuzzleGrid"))
        #expect(definition.warnings.isEmpty, "\(definition.warningReport ?? "no report")")
    }

    /// Walking from square to square never leaves the room, and every step
    /// costs a turn exactly as a real move would — a `before` rule that
    /// replies is not `unhandled`, so the pipeline still finishes the turn.
    /// (Four commands, four turns; SCORE is meta and free.)
    @Test func everyStepAndEveryPushCostsATurn() async throws {
        let transcript = try await play(
            RoyalPuzzleGame(), ["down", "east", "north", "push west", "score"])
        #expect(turnOutput(of: "score", in: transcript).contains("in 4 turns"))
    }

    // MARK: - The geometry the player navigates by

    @Test func theRoomDescribesItselfFromTheGrid() async throws {
        let transcript = try await play(RoyalPuzzleGame(), ["down"])
        // Square 14: sandstone north, floor east and west, outer wall south.
        // `surroundings` joins its four clauses into one line, so the two
        // halves are asserted separately rather than as one long literal.
        #expect(transcript.contains("To the north, a sandstone wall; to the east, open floor;"))
        #expect(transcript.contains("to the south, the outer wall; to the west, open floor."))
    }

    @Test func pushingABlockRewritesTheDescription() async throws {
        let transcript = try await play(
            RoyalPuzzleGame(), ["down", "east", "north", "look", "push west", "l"])
        // Standing on square 11, the sandstone block is to the west.
        #expect(turnOutput(of: "look", in: transcript).contains("to the west, a sandstone wall."))
        #expect(transcript.contains("The wall grinds a full square west and settles."))
        // The player ends on the square the block left, so the block is west
        // of them again — and the ladder block, invisible from square 11, is
        // now due north.
        let after = turnOutput(of: "l", in: transcript)
        #expect(after.contains("To the north, the sandstone wall with the ladder cut into it"))
        #expect(after.contains("to the west, a sandstone wall."))
    }

    // MARK: - Movement refusals, each naming its material

    /// The reason movement inside the grid is a rule and not the exit table:
    /// these are the same direction from different squares, and each needs a
    /// different sentence.
    @Test func everyBlockedStepSaysWhatIsBlockingIt() async throws {
        let transcript = try await play(
            RoyalPuzzleGame(),
            ["down", "south", "northeast", "down", "north", "west", "north", "west", "north"])
        expectInOrder(
            transcript,
            [
                "That is the outer wall of the puzzle, and it goes down to bedrock.",
                "The squares of the puzzle meet edge to edge.",
                "The floor is a hand's depth of sand over bedrock.",
                // Square 14's north neighbour is the sandstone over the card.
                "A sandstone wall stands in the way. It might move, if you pushed it.",
                // Square 9 has marble to its north and marble to its west.
                "A marble wall stands in the way. Marble does not move.",
            ])
        #expect(
            occurrences(of: "A marble wall stands in the way. Marble does not move.", in: transcript)
                == 2)
    }

    // MARK: - Pushing

    @Test func everyRefusedPushSaysWhyItWasRefused() async throws {
        let transcript = try await play(
            RoyalPuzzleGame(),
            ["down", "push south", "push west", "push north", "west", "north", "push north"])
        expectInOrder(
            transcript,
            [
                "There is nothing to push that way but the outer wall.",
                "There is nothing in that square to push.",
                // Square 14's sandstone has the ladder block hard behind it.
                "The wall shifts an inch and stops. There is another wall hard behind it.",
                "You set your shoulder to the marble. The marble is unimpressed.",
            ])
    }

    /// Adding a `.direction` row makes the bare verb *parse* rather than ask:
    /// core `push <object>` near-misses on the missing noun, the loop carries
    /// on, and the direction slot's empty case returns a command with a nil
    /// direction. The rule has to answer it, or the player gets nothing.
    @Test func pushWithNoDirectionIsAnsweredByTheRuleNotTheCore() async throws {
        let transcript = try await play(RoyalPuzzleGame(), ["down", "push"])
        #expect(transcript.contains("Push which way? North, south, east or west."))
        #expect(!transcript.contains("What do you want to push?"))
    }

    /// A literal word may sit beside a direction slot even though an object
    /// slot may not, so the mainframe's wordier phrasings can be bought back
    /// one spelling at a time.
    @Test func literalWordRowsBuyBackTheNoun() async throws {
        let transcript = try await play(
            RoyalPuzzleGame(),
            ["down", "push wall north", "push sandstone wall north", "push the stone north"])
        #expect(
            occurrences(
                of: "The wall shifts an inch and stops. There is another wall hard behind it.",
                in: transcript) == 2)
        // What is *not* bought back: anything not spelled out as a row. A
        // literal is matched, not resolved, so a synonym the item would have
        // answered to is not even a word the parser knows here.
        #expect(transcript.contains("I don't know the word \"stone\"."))
    }

    /// The sharp edge behind that workaround. A literal is not a resolved
    /// object, so `Command.directObject` is nil and the rule cannot tell which
    /// wall was named — it pushes whatever lies in that direction. Here the
    /// player names the marble and moves the sandstone.
    @Test func theNounInALiteralRowIsDecorative() async throws {
        let transcript = try await play(
            RoyalPuzzleGame(), ["down", "east", "north", "push marble wall west", "look"])
        #expect(transcript.contains("The wall grinds a full square west and settles."))
        #expect(!transcript.contains("The marble is unimpressed."))
        #expect(turnOutput(of: "look", in: transcript).contains("to the west, a sandstone wall."))
    }

    /// `push sandstone` still reaches the core `.push` intent, whose default
    /// says "You can't move that" — of the one thing in the game that plainly
    /// does move. A rule on the walls themselves teaches the syntax instead.
    @Test func pushingAWallByNameTeachesTheSyntax() async throws {
        let transcript = try await play(RoyalPuzzleGame(), ["down", "push sandstone"])
        #expect(
            transcript.contains(
                "In here a wall is pushed by direction: push north, or push wall north."))
        #expect(!transcript.contains("You can't move that"))
    }

    // MARK: - The ways out, which are genuine conditional exits

    /// The half of the issue's expected shape that holds: a real exit reads
    /// the grid. `up` opens only when the ladder block stands under the
    /// ceiling hole with the player beside it.
    @Test func theWayOutIsAConditionalExitReadingTheGrid() async throws {
        let transcript = try await play(RoyalPuzzleGame(), ["down", "up"])
        #expect(transcript.contains("Nothing within reach will take you as high as the ceiling."))
    }

    @Test func theLowDoorOpensOnlyForTheCardAndOnlyFromItsSquare() async throws {
        let transcript = try await play(
            RoyalPuzzleGame(),
            [
                "down", "east", "north", "north", "east",
                "south", "push west", "take card", "put card in slot",
                "east", "north", "put card in slot", "east",
            ])
        expectInOrder(
            transcript,
            [
                // Standing on the door's own square, with nothing to feed it.
                "The low door is shut, and there is no handle on this side.",
                // Card in hand, but two squares from the wall it goes into.
                """
                The slot is cut into the east wall, and the east wall is not within
                reach from here.
                """,
                "The card goes into the slot to the hilt and does not come back out.",
                "Side Room",
            ])
    }

    // MARK: - The card, and the one correct order

    @Test func theCardIsUncoveredByPushingItsBlockOffIt() async throws {
        let transcript = try await play(
            RoyalPuzzleGame(), ["down", "east", "north", "push west", "take card", "i"])
        expectInOrder(
            transcript,
            [
                """
                Under where the wall stood, pressed flush into the sand, lies a thin
                brass card.
                """,
                "Taken.",
            ])
        #expect(turnOutput(of: "i", in: transcript).contains("brass card"))
    }

    /// Containment is room-granular: the card is in the room from the moment
    /// it is uncovered, so reach across the grid has to be faked by hand.
    @Test func theCardCannotBeTakenFromAcrossTheGrid() async throws {
        let transcript = try await play(
            RoyalPuzzleGame(), ["down", "east", "north", "push west", "east", "take card"])
        #expect(transcript.contains("The card is squares away from you, across the sand."))
    }

    /// One card, two slots. Spending it on the hatch opens a way out and
    /// strands the book behind a door that can now never open.
    @Test func spendingTheCardOnTheHatchLosesTheBookForGood() async throws {
        let transcript = try await play(
            RoyalPuzzleGame(),
            [
                "down", "east", "north", "push west", "take card",
                "south", "west", "west", "put card in niche",
                "east", "east", "east", "north", "north",
                "put card in slot", "east",
            ])
        expectInOrder(
            transcript,
            [
                "The card goes into the niche to the hilt and does not come back out.",
                "the hatch swings inward on a crawlway going up",
                // Back at the low door with nothing left to feed the slot.
                "You can't see any such thing.",
                "The low door is shut, and there is no handle on this side.",
            ])
    }

    /// The other wrong order. The sandstone that uncovered the card is boxed
    /// in by marble on both sides and can never move again, so the ladder
    /// block is the only thing that can re-enter the card's square — the one
    /// block the player cannot afford to misuse.
    @Test func aBlockPushedOntoTheLooseCardDestroysIt() async throws {
        let transcript = try await play(
            RoyalPuzzleGame(),
            [
                "down", "east", "north", "push west",
                "east", "north", "north", "west", "push south",
                "take card",
            ])
        expectInOrder(
            transcript,
            [
                """
                The wall settles into the square with a dry snap. Whatever was under
                it is under it now.
                """,
                "You can't see any such thing.",
            ])
    }

    // MARK: - The whole thing, end to end

    @Test func theScriptedSolutionWalksTheGridAndClimbsOutWithTheBook() async throws {
        let transcript = try await play(RoyalPuzzleGame(), scriptedSolution)
        expectInOrder(
            transcript,
            [
                "You lower yourself through and land badly.",
                """
                Under where the wall stood, pressed flush into the sand, lies a thin
                brass card.
                """,
                "The card goes into the slot to the hilt and does not come back out.",
                "Side Room",
                """
                The block with the ladder stands under the daylight, and the rungs go
                up into it.
                """,
                "You come up through the ceiling hole hand over hand",
                "in 19 turns",
            ])
    }

    /// Climbing out is one-way, because the sand ran shut on the way in.
    @Test func theDropInSealsBehindThePlayer() async throws {
        let transcript = try await play(
            RoyalPuzzleGame(), climbOutWithoutTheBook + ["down", "look"])
        expectInOrder(
            transcript,
            [
                """
                The sand has run shut over the hole, and it is packed as hard as the
                floor around it.
                """,
                """
                Where the hole was there is packed
                sand without a seam in it.
                """,
            ])
        // Out without the book: the puzzle keeps it.
        #expect(!transcript.contains("You come up through the ceiling hole"))
    }

    // MARK: - The grid as saved state

    /// A `.data` global carries the whole grid through both rewind paths.
    @Test func theGridSurvivesUndoAndSaveAndRestore() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gnusto-royal-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let transcript = try await play(
            RoyalPuzzleGame(),
            [
                "down", "east", "north", "push west",
                "save", "grid",
                "east", "north",
                "restore", "grid",
                "look",
                "undo",
                "l",
            ],
            saveDirectory: dir)
        expectInOrder(transcript, ["Saved.", "Restored."])
        // Restored onto the card's square with the block still moved.
        let restored = turnOutput(of: "look", in: transcript)
        #expect(restored.contains("to the west, a sandstone wall."))
        #expect(restored.contains("A thin brass card lies at your feet"))
        // UNDO rewinds the restore's own turn, not the push.
        #expect(turnOutput(of: "l", in: transcript).contains("to the west, a sandstone wall."))
    }

    /// The room's own description is the state, so `alwaysDescribed` makes the
    /// brief `.entry` a rewind produces print the geometry anyway — the player
    /// gets the board back with the move, not one turn later on an explicit
    /// LOOK. Issue #149.
    @Test func aRewindReprintsTheGeometryItRewound() async throws {
        let transcript = try await play(
            RoyalPuzzleGame(), ["down", "east", "north", "push west", "undo"])
        let rewind = turnOutput(of: "undo", in: transcript)
        #expect(rewind.contains("Room in a Puzzle"))
        // Back on square 11, before the push: sandstone to the west again.
        #expect(rewind.contains("To the north, open floor; to the east, the outer wall;"))
        #expect(rewind.contains("to the west, a sandstone wall."))
    }

    /// The control for the trait: the anteroom declares no `alwaysDescribed`,
    /// so its `describe { … }` still obeys the ordinary brief-on-revisit rule.
    /// Climbing back out prints its name and not its description.
    @Test func aRoomWithoutTheTraitIsStillBriefOnARevisit() async throws {
        let transcript = try await play(RoyalPuzzleGame(), climbOutWithoutTheBook)
        let reentry = turnOutput(of: "up", in: transcript)
        #expect(reentry.contains("Small Square Room"))
        #expect(!reentry.contains("A small square room, swept bare"))
    }

    /// The other half of #149. Every step and every push re-describes, but the
    /// player never leaves the room, so the heading is printed only by the
    /// three descriptions that really are arrivals: the drop in, and the two
    /// LOOKs. Nineteen moves, three headings — not nineteen.
    @Test func stepsInsideTheRoomDoNotReprintTheHeading() async throws {
        let transcript = try await play(RoyalPuzzleGame(), scriptedSolution)
        // Entering the puzzle, and re-entering it from the Side Room.
        #expect(occurrences(of: "Room in a Puzzle", in: transcript) == 2)
        // The geometry, meanwhile, printed on every one of those moves.
        #expect(occurrences(of: "To the north,", in: transcript) > 10)
    }

    // MARK: - Vocabulary

    @Test func everyNounTheGridPrintsIsAnswerable() async throws {
        let transcript = try await play(
            RoyalPuzzleGame(),
            [
                "down", "examine sandstone wall", "examine marble wall", "examine ladder",
                "examine outer wall", "examine sand", "examine daylight",
                "east", "north", "examine slot", "examine low door",
            ])
        expectEveryNounAnswered(transcript, "the nouns the grid paragraph prints")
    }
}
