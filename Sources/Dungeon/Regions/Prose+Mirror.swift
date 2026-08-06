/// Prose for the mirror rooms and the passages around them (``DungeonMirror``):
/// two Mirror Rooms, two Caves, two crawlways, the Cold and Winding Passages,
/// the drowned Atlantis Room, and the Slide Room at the head of the chute back
/// down to the Cellar.
///
/// The three-way rule, and the rule for which file a line goes in, are stated
/// once on ``Prose``.
extension Prose {
    // MARK: - The Mirror Rooms

    /// Verbatim, and the same line for both rooms — as it is in the mainframe,
    /// where one `MIRR-DESC` serves them both. The trilogy's wording fits
    /// either room's exit table exactly: the mirror fills one wall and the
    /// other three are ways out.
    static let mirrorRoom = """
        You are in a large square room with tall ceilings. On the south wall
        is an enormous mirror which fills the entire wall. There are exits
        on the other three sides of the room.
        """

    static let mirrorShattered = """
        Unfortunately, the mirror has been destroyed by your recklessness.
        """

    static let mirror = "There is an ugly person staring back at you."

    static let mirrorBroken = "The mirror is broken into many pieces."

    static let mirrorRumble = """
        There is a rumble from deep within the earth and the room shakes.
        """

    static let mirrorBreaks = """
        You have broken the mirror. I hope you have a seven years supply of
        good luck handy.
        """

    static let mirrorAlreadyBroken = "Haven't you done enough already?"

    static let mirrorTakeRefused = """
        Nobody but a greedy surgeon would allow you to attempt that trick.
        """

    static let mirrorRoomCeiling = """
        The ceiling is a long way up, and square, and gives nothing away about
        who cut this room or why.
        """

    // MARK: - The Caves

    /// Adapted from the trilogy's tiny cave, which has an entrance west that
    /// the mainframe's `CAVE1` does not: this one is reached from the Mirror
    /// Room north of it and drops to Atlantis.
    static let caveNorth = """
        This is a tiny cave with an entrance to the north, and a staircase
        leading down.
        """

    /// Verbatim. `CAVE2` is the trilogy's tiny cave down to the last comma —
    /// west, north, and a dark staircase — because it is the same room.
    static let caveSouth = """
        This is a tiny cave with entrances west and north, and a dark,
        forbidding staircase leading down.
        """

    static let caveStairway = """
        A stairway cut into the rock, going down out of the reach of any light
        you are carrying.
        """

    // MARK: - The crawlways

    /// Written fresh. `CRAW2` has no trilogy counterpart; Zork I threads the
    /// Round Room to the Mirror Rooms through a Narrow Passage instead.
    static let steepCrawlway = """
        This is a steep and narrow crawlway. Two ways out lie close together
        here, one south and one southwest.
        """

    /// Written fresh. `CRAW3` has no trilogy counterpart either.
    static let narrowCrawlway = """
        This is a narrow crawlway running north to south. At its southern end
        it divides, one branch bearing south and the other southwest.
        """

    static let crawlwayWalls = """
        Rock, close on both sides, and worn smooth at shoulder height by
        whoever used to come this way.
        """

    // MARK: - The passages

    /// Adapted. The comparison buckets `PASS3` `minor` — the two lines are a
    /// few characters apart — but the few characters are the exits: the
    /// trilogy's corridor turns *south* and the mainframe's crosses a path
    /// running *north*. The table wins over the character count.
    static let coldPassage = """
        This is a cold and damp corridor where a long east-west passageway
        crosses a path running north.
        """

    /// Adapted. `PASS4` is `substantial`, and the reason is the map: the
    /// trilogy gives the passage a north exit, and the mainframe gives it only
    /// the sound of one.
    static let windingPassage = """
        This is a winding passage. The only way out of it appears to be east,
        although a faint whirring — the round room, somewhere off to the north
        — carries through the rock.
        """

    static let windingPassageWhirring = """
        Machinery, by the sound of it, and a good deal of it, turning
        somewhere north of here behind a wall with no door in it.
        """

    static let noEntranceToTheRoundRoom = """
        You hear the whir from the round room but can find no entrance.
        """

    // MARK: - The Atlantis Room

    /// Adapted. `ATLAN` is `substantial` on one word: the trilogy's exit runs
    /// south and the mainframe's runs southeast, down the tunnel to the
    /// reservoir's north shore.
    static let atlantisRoom = """
        This is an ancient room, long under water. There is an exit to the
        southeast and a staircase leading up.
        """

    static let atlantisWalls = """
        Stone laid by hands, and every joint of it silted pale where the water
        stood for however long the water stood.
        """

    static let crystalTrident = """
        It is a three-pronged fork wrought all of clear crystal, cold and
        faintly ringing to the touch — a king's own, by the look of it.
        """

    static let crystalTridentFirstSight = """
        On the shore lies Poseidon's own crystal trident.
        """

    // MARK: - The Slide Room

    /// Verbatim. `SLIDE` prints from a routine in the mainframe, but the
    /// trilogy's Slide Room is the same room with the same three ways out —
    /// east, north, and the chute — and the same joke etched on the wall.
    static let slideRoom = """
        This is a small chamber, which appears to have been part of a
        coal mine. On the south wall of the chamber the letters "Granite
        Wall" are etched in the rock. To the east is a long passage, and
        there is a steep metal slide twisting downward. To the north is
        a small opening.
        """

    /// The paragraph the room gains once a rope has been tied off at the head
    /// of the chute. Written fresh; the trilogy's Slide Room has no rope,
    /// because it has nothing at the bottom of its slide to climb down to.
    /// ``Dungeon/palantirRules`` supplies it, because what it reports is
    /// ``DungeonPalantir``'s state.
    static let slideRoomRopeRigged = """
        A rope is tied off at the head of the slide, and its far end has gone
        down into the dark out of sight.
        """

    static let graniteWallLettering = """
        The words "Granite Wall" are cut into the rock in letters a foot high.
        The wall itself is nothing of the sort.
        """

    static let metalSlide = """
        A chute of sheet metal, twisting down into the dark at an angle no
        one would climb back up.
        """
}
