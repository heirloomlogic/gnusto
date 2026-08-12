/// Prose for the Royal Puzzle (``DungeonRoyalPuzzle``): the Small Square Room
/// above it, the Room in a Puzzle itself, and the Side Room behind its steel
/// door.
///
/// The three-way rule, and the rule for which file a line goes in, are stated
/// once on ``Prose``.
///
/// **Every line here is written fresh.** `CP`, `CPANT` and `CPOUT` appear in no
/// bucket of `docs/games/dungeon-prose-comparison.md`, and neither do any of the
/// region's eleven objects. That document carries only entities present in
/// *both* sources, so the absence is its way of saying there is nothing to pair.
/// The whole region is therefore case 3 of the rule: mainframe-only content, in
/// the Infocom register, this project's own words.
///
/// There is more text here to not reproduce than in earlier regions.
/// `dung.355`'s Chinese Puzzle is wordy by mainframe standards: the card carries
/// a full framed pass, the note a signed letter, the diagram a legend.
/// `THIRD_PARTY_NOTICES` limits the 1981 source to structure, so what crosses
/// over is the *fact* each string carries — that the pass is a museum door pass,
/// that the note warns you cannot get out, that the legend explains two rock
/// types — and the sentences are written here.
///
/// That caveat used to be carried here as an open question — the atlas paired
/// nothing at all against Zork III, and Zork III is where the trilogy put its
/// Royal Puzzle, so "no counterpart" might only have meant "no counterpart was
/// looked for". #184 settled it. The generator was reading a stale second
/// generation of that checkout and could pair nothing; it now pairs `CP`,
/// `CPANT`, `CPOUT` and the ladder. The region's prose is unchanged, and for a
/// better reason than before: Zork III describes those rooms from a room
/// function, so there is still no trilogy line to weigh against the mainframe's.
/// Case 3 holds, checked rather than merely unrefuted. See `FIDELITY.md`,
/// milestone 7.
///
/// The room's own description is assembled rather than stored, because it *is*
/// the state of the grid. ``puzzleDiagram(_:)`` builds the 3×3 the source
/// switches to after the first push.
extension Prose {
    // MARK: - The Small Square Room

    /// `CPANT` while the hole is still open.
    static let puzzleAnteroom = """
        This is a small square room, and in the middle of its floor is a hole
        somebody has cut recently and roughly. Ten feet down you can just make
        out sand. It does not look like a climb you could reverse. There are
        exits west and south.
        """

    /// The same room once a wall has been shoved into the cell below the hole.
    /// The source's `CPBLOCK` is one-way and is never cleared, so this is a
    /// permanent state and the description says so plainly.
    static let puzzleAnteroomBlocked = """
        This is a small square room, and in the middle of its floor is a hole
        somebody has cut recently and roughly. A face of smooth sandstone has
        come up flush against the underside of it, and the hole now goes
        nowhere. There are exits west and south.
        """

    /// The sand ten feet under the anteroom's floor, in the two states the
    /// room's own paragraph has always had. The word is printed three times in
    /// here and nothing in the room answered it — the game's `sand` stands in
    /// the cell *below*, which is exactly the far-thing-near-thing split this
    /// round is about, seen through a hole. (#233)
    static let anteroomSand = """
        Pale sand, ten feet down through the hole and not much to be made out
        from up here.
        """

    static let anteroomSandBlocked = """
        A face of smooth sandstone, come up flush under the lip of the hole.
        Whatever sand was down there is behind it now.
        """

    static let puzzleHole = """
        A hole cut through the floor, wide enough for a man and rough at the
        edges. Sand has drifted to the lip of it.
        """

    static let puzzleHoleBlocked = """
        A hole cut through the floor, and a foot below the lip a face of
        sandstone stopping it completely.
        """

    static let puzzleWayDownBlocked = """
        The way down is blocked by sandstone.
        """

    /// `WARNI`. Written fresh; the source's letter is 1981 MDL text. What
    /// crosses over is what it does — it is signed by the thief, it says the
    /// treasure is a rumour, and it says you will not get out again.
    static let warningNote = """
        A sheet of paper, much worn, covered in a very elegant copperplate
        written with what must have been a badly used pencil.
        """

    static let warningNoteInPlace = """
        There is a piece of paper on the ground here.
        """

    static let warningNoteText = """
        To Whom It May Concern:

            I am sorry to report that the stories about treasure in the
            chamber below have nothing behind them. Should you be foolhardy
            enough to go down there in spite of me, I should add that you
            will not be able to get out again.

                                            Yours sincerely,
                                            The Thief
        """

    // MARK: - Going down, and coming up

    static let puzzleDropIn = """
        You lower yourself through the hole and land on packed sand ten feet
        below.
        """

    static let puzzleClimbOut = """
        With the ladder under you, you get a hand over the lip of the opening
        and haul yourself out of the puzzle.
        """

    static let puzzleNoWayUp = """
        There is no way up from here.
        """

    static let puzzleCeilingTooHigh = """
        The opening is a good deal too far above your head.
        """

    static let puzzleHeadOnTheCeiling = """
        You get two rungs up, crack your head on the ceiling, and come off the
        ladder.
        """

    static let puzzleNoLadderHere = """
        There is no ladder here.
        """

    // MARK: - The Room in a Puzzle

    /// The entry cell, described in prose. The source prints this only until
    /// the first successful push, after which every look is a diagram — so this
    /// line is allowed to hardcode the geometry of cell 10, which is where the
    /// player always starts.
    static let puzzleRoomAtEntry = """
        This is a small square room, walled to the north and west in marble and
        to the east and south in sandstone.
        """

    /// Appended to the above once the player has read the thief's note.
    static let puzzleThiefWasRight = """
        It appears the thief was telling the truth.
        """

    /// Written fresh: the source's legend is MDL text. The fact it carries is
    /// that the descriptions are about to become diagrams and what the four
    /// tokens mean.
    static let puzzleDiagramLegend = """
        The architecture here is getting complicated, so from now on the room
        will be drawn as a diagram of the nine squares around you:

            ..  = where you are standing
            MM  = marble wall
            SS  = sandstone wall
            ??  = out of sight behind the walls
        """

    /// The three squares that have anything to say for themselves.
    static let puzzleCeilingOpening = """
        In the ceiling above you is a large circular opening.
        """

    /// Examined from the one square it stands over. The doc comment here used
    /// to say this was the only place it could be examined from; the item is
    /// placed in the room, and the room is all sixty-four squares.
    ///
    /// Not the same sentence as the hole in the anteroom floor: that one is
    /// looked down into and this one is looked up at.
    static let puzzleCeilingOpeningExamined = """
        A circle of darkness in the ceiling, the underside of the hole you came
        down through. It is a long way above your head.
        """

    /// And from the other sixty-three, where `up` answers ``puzzleNoWayUp`` and
    /// the ceiling really is solid. One fixed line rather than an interpolated
    /// distance: nothing in the engine re-wraps prose, and a hand-wrapped
    /// literal with a number in it comes out ragged in some of its states.
    static let puzzleCeilingOpeningAcrossTheRoom = """
        A circle of darkness in the ceiling, away across the room above the
        square the hole comes down into. Over your own head there is nothing
        but stone.
        """

    static let puzzleFloorDepressed = """
        The middle of the floor here is noticeably depressed.
        """

    /// Two separately wrapped variants rather than one interpolation. Nothing
    /// in the engine re-wraps prose, and "opening" and "steel door" are
    /// different lengths, so a single hand-wrapped literal comes out ragged in
    /// one of its two states — which is what a play-test caught.
    static func puzzleDoorWall(open: Bool) -> String {
        open
            ? """
            The west wall here has a large opening at its centre. To one side of
            it is a small slit.
            """
            : """
            The west wall here has a large steel door at its centre. To one side
            of it is a small slit.
            """
    }

    /// Takes the rendered compass word, not a `Direction`: this file declares no
    /// imports, the way every `Prose+*.swift` does, so the engine's types stop
    /// at its door. The model side stays typed — ``RoyalPuzzleGrid/ladderInReach``
    /// returns a `Direction` — and the single call site renders it.
    static func puzzleLadderOnWall(_ side: String) -> String {
        "There is a ladder here, firmly attached to the \(side) wall."
    }

    /// Two characters for one square. Every glyph the diagram can draw is
    /// chosen here, next to the legend above that explains them, so the two
    /// cannot drift apart.
    static func puzzleGlyph(_ cell: RoyalPuzzleCell?) -> String {
        switch cell {
        case nil: "??"
        case .floor: "  "
        case .marble: "MM"
        case .sandstone, .goodLadder, .badLadder: "SS"
        }
    }

    /// The 3×3 the source switches to after the first push, with the player at
    /// its centre. `ring` is the eight squares around them, clockwise from the
    /// north-west, as ``RoyalPuzzleGrid/diagramRing`` reports them.
    static func puzzleDiagram(_ ring: [RoyalPuzzleCell?]) -> String {
        let box = ring.map(puzzleGlyph)
        return """
                  |\(box[0]) \(box[1]) \(box[2])|
            West  |\(box[3]) .. \(box[4])|  East
                  |\(box[5]) \(box[6]) \(box[7])|
            """
    }

    // MARK: - Walking the grid

    static let puzzleWallThere = """
        There is a wall there.
        """

    /// The diagonal refusal. The source allows a diagonal step only when at
    /// least one of the two squares you would pass between is clear.
    static let puzzleCannotCutTheCorner = """
        The two walls meet at the corner, and you cannot squeeze between them.
        """

    static let puzzleFloorIsBedrock = """
        The floor is a hand's depth of sand over bedrock.
        """

    // MARK: - Pushing the walls

    static let puzzlePushWhichWay = """
        Push which way? North, south, east or west.
        """

    /// Stated on the walls themselves rather than on the room, so `push card`
    /// still gets the engine's stock answer.
    static let puzzlePushNeedsADirection = """
        In here a wall is pushed by direction: push north, or push north wall.
        """

    /// For `push sand north` — a direction the room understands, aimed at
    /// something that is not a side. Written fresh: the phrasing does not
    /// parse in the source at all, so there is no line to reproduce. It names
    /// the noun as the problem rather than reusing the syntax lesson above,
    /// which would answer a question the player did not ask.
    static let puzzlePushOnlyWalls = """
        Only a wall can be pushed in here.
        """

    static let puzzleOnlyAPassage = """
        There is only a passage in that direction.
        """

    static let puzzleWallDoesNotBudge = """
        The wall does not budge.
        """

    static let puzzleWallSlides = """
        The wall slides forward and you follow it.
        """

    /// The moment the ceiling exit is destroyed. One-way, and the source never
    /// clears it, so the sentence is allowed to be final.
    static let puzzleEntranceSealed = """
        The wall grinds into the square below the opening and stops there. The
        way you came in is now a ceiling like any other.
        """

    // MARK: - The gold card

    /// `GCARD`. Ten to find and fifteen to case, and the whole of what the
    /// puzzle is worth.
    static let goldCard = """
        A card of solid gold with a milled edge, engraved on one face.
        """

    static let goldCardInPlace = """
        There is a solid gold engraved card here.
        """

    /// The half a reach rule cannot answer: which line the room listing prints.
    /// Containment is room-granular and the puzzle is one room, so from any
    /// other square the card has to be described as being elsewhere in it.
    static let goldCardAcrossTheFloor = """
        A solid gold card lies in one of the other squares of the puzzle.
        """

    static let goldCardOutOfReach = """
        The card is squares away from you, across the sand.
        """

    /// Written fresh. The source engraves a full framed Frobozz Magic Security
    /// Systems pass; what crosses over is that it is a museum door pass, that
    /// it expired long ago, and that using it will get it confiscated.
    static let goldCardText = """
        Engraved in a fine hand, inside a ruled border:

            FROBOZZ MAGIC SECURITY SYSTEMS
            Door Pass — Royal Zork Puzzle Museum

            USE BY UNAUTHORIZED PERSONS, OR AFTER THE EXPIRY DATE,
            WILL RESULT IN IMMEDIATE CONFISCATION OF THIS PASS.

            Expires 792 G.U.E.
        """

    // MARK: - The slit and the steel door

    static let puzzleSlit = """
        A slit in the wall beside the door, a card's width across and no deeper
        than a finger.
        """

    static let puzzleSlitTooSmall = """
        The slit is a card's width and no more.
        """

    static let puzzleSlitOutOfReach = """
        The slit is cut into the wall beside the steel door, and neither is
        within reach from here.
        """

    /// The line the region turns on, and the reason the card is a choice rather
    /// than a step: the slit keeps whatever it is given.
    static let puzzleCardConfiscated = """
        The card slides easily into the slit and is gone. The steel door slides
        open on a passage west, and a sign you had not noticed lights up above
        it:

            UNAUTHORIZED USE OF PASS CARD — CARD CONFISCATED
        """

    static let puzzleSlitEatsIt = """
        The slit takes it, and a sign you had not noticed lights up above the
        door: GARBAGE IN, GARBAGE OUT. Of your property there is no further
        sign.
        """

    static let puzzleSteelDoor = """
        A slab of steel set flush into the marble, with no handle on this side.
        """

    static let puzzleSteelDoorBars = """
        The steel door bars the way.
        """

    // MARK: - The Side Room

    static func puzzleSideRoom(open: Bool) -> String {
        """
        You are in a small room with an exit north and \
        \(open ? "a passage" : "a steel door") to the east.
        """
    }

    static let puzzleSideRoomDoor = """
        The same slab of steel, and on this side of it there is a handle.
        """

    // MARK: - Scenery

    /// The materials in general, for `examine marble wall` and `examine
    /// sandstone wall` — which name a substance and so cannot name a square.
    static let puzzleWallExamined = """
        Rock, cut square and set on end. Some of it is marble and some of it is
        sandstone, and only one of those will move.
        """

    /// What is actually on one side of the square the player is standing in.
    /// The four compass walls are the only things in the region that can answer
    /// this, because they are the only ones that name a direction.
    /// Hand-wrapped in each branch, because nothing in the engine re-wraps
    /// prose and the compass word is a different length in each of the four.
    static func puzzleWallOnSide(_ side: String, _ cell: RoyalPuzzleCell) -> String {
        switch cell {
        case .floor:
            """
            There is no wall to the \(side) of you. The square stands open.
            """
        case .marble:
            """
            The wall to the \(side) is marble, white and veined with grey.
            It has not moved in three hundred years.
            """
        case .sandstone:
            """
            The wall to the \(side) is sandstone, cut square and set on end.
            It would move, if it were pushed.
            """
        case .goodLadder, .badLadder:
            """
            The wall to the \(side) is sandstone, and somebody has cut a line
            of rungs into the face of it.
            """
        }
    }

    static let puzzleLadderExamined = """
        Rungs cut into the face of a sandstone block, going up past your head.
        """

    /// The decoy. The source will not tell you which is which — both draw as
    /// sandstone in the diagram — so neither does this, and the difference is
    /// only ever felt by climbing.
    static let puzzleLadderExaminedBad = """
        Rungs cut into the face of a sandstone block, going up past your head.
        They look no different from any other rungs.
        """

    static let puzzleSandExamined = """
        Sand, a hand's depth of it, drifted into the angles of the blocks.
        """
}
