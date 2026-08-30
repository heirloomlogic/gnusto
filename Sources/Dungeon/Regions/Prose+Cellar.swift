/// Prose for the cellar region (``DungeonCellar``): the Troll Room, the
/// North-South Crawlway, West of Chasm, the Gallery and the Studio, plus the
/// troll who holds the middle of it.
///
/// The three-way rule, and the rule for which file a line goes in, are stated
/// once on ``Prose``.
extension Prose {
    // MARK: - The Troll Room

    /// Adapted. The trilogy names the Troll Room's exits — "passages to the
    /// east and south and a forbidding hole leading west" — because Zork I cut
    /// the room down. The mainframe's Troll Room really does open in all four
    /// directions: west to the Cellar, east to the crawlway, north to the
    /// East-West Passage, south into the maze. The second sentence is the
    /// trilogy's, unchanged.
    static let trollRoom = """
        This is a small room with passages leading off in every direction.
        Bloodstains and deep scratches (perhaps made by an axe) mar the walls.
        """

    /// One line for both channels: the troll blocking every exit is what the
    /// room lists *and* what examining him reports, because that is the whole
    /// of what he does.
    static let troll = """
        A nasty-looking troll, brandishing a bloody axe, blocks all passages
        out of the room.
        """

    /// The same troll knocked down. Both his channels were one constant, and
    /// that constant claims he *blocks all passages* — which he does not do
    /// face down in the dirt, as the greeting two screens below has known all
    /// along. The thief's listing line had the identical fault and is the
    /// reason this one was looked at. (#329)
    static let trollOnTheFloor = """
        The nasty-looking troll is face down in the dirt, the bloody axe still
        in his fist and every way out of the room clear.
        """

    static let trollBlocksTheWay = """
        The troll fends you off with a menacing gesture.
        """

    /// Written fresh, and *not* a departure — which it briefly was. `V-HELLO`
    /// (`gverbs.zil:176`) answers a greeting to any villain with a bow, and both
    /// sources carry it; the engine's placeholder, "The troll nods, and says
    /// nothing.", is the same courtesy flattened, and the 2026-08-11 round
    /// (#233) filed the flatness as the defect. #236 replaced it with a hostile
    /// line, on the argument that a bow reads oddly from a creature that swings
    /// at you every single turn you stand in the room.
    ///
    /// That argument was about *this game's* troll and not the source's, and
    /// #237 has since removed it: `I-FIGHT` gives him a `PROB 33` of striking
    /// first and he spends the other two turns in three doing exactly what his
    /// listing line says he does, which is block — and so does ours now. A troll
    /// who blocks can be civil about it, so the courtesy comes back, in this
    /// game's own words rather than the ZIL's and with the blocking in the same
    /// breath.
    static let trollGreeted = """
        The troll inclines his head to you, and goes on blocking every way
        out of the room.
        """

    /// The second state, which is the source's own count — `TROLL-FUNCTION`
    /// gates a `HELLO` branch on `TROLL-FLAG`, the troll being down. He is on
    /// the floor for the two turns after a knockout, and that is the whole
    /// window this line has.
    static let trollGreetedOnTheFloor = """
        The troll is face down in the dirt and hears nothing at all.
        """

    static let trollMiss1 = "Your sword misses the troll by an inch."
    static let trollMiss2 = "A good slash, but it misses the troll by a mile."
    static let trollWound1 = "The troll is struck on the arm; blood begins to trickle down."
    static let trollWound2 = "The troll receives a deep gash in his side."
    static let trollKnockout = """
        The troll is battered into unconsciousness.
        """
    /// Verbatim (Zork I) for the blow, and the mechanism's fog after it —
    /// `VILLAIN-RESULT` is one routine for every villain and the troll goes the
    /// same way the thief does. See ``Prose/carcassVanishes(_:)``. (#350)
    static let trollDeath = """
        The troll takes a fatal blow and slumps to the floor dead.

        \(Prose.carcassVanishes("the troll"))
        """

    static let trollSwipeMiss = "The troll swings his axe, but it misses."
    static let trollSwipeWound = "The axe gets you right in the side. Ouch!"
    static let trollKillsYou = """
        The troll neatly removes your head.
        """

    static let bloodstains = """
        Old blood, dried nearly black, and beneath it the scratches — long,
        parallel, and about the width of an axe.
        """

    /// Written fresh. The room's first sentence is about them and the troll's
    /// own line says he blocks all of them, and the word went unanswered. (#233)
    static let trollRoomPassages = """
        Four low ways out, one in each wall, and something has been dragged
        through more than one of them.
        """

    static let axe = """
        A heavy war axe, its edge notched from long use and its head still
        dark with the troll's last argument.
        """

    // MARK: - North-South Crawlway

    /// Written fresh — mainframe-only room, with no trilogy counterpart to
    /// lean on. North to West of Chasm, south to the Studio, east to the
    /// Troll Room, and a hole overhead that goes nowhere.
    static let crawlway = """
        The crawlway runs north and south, low enough that you go the length
        of it on hands and knees. A passage opens off to the east. There is a
        hole in the rock above, but nothing in it a climber could use.
        """

    static let crawlwayHole = """
        A ragged hole in the roof of the crawlway. Not even a human fly could
        get up it.
        """

    static let crawlwayHoleRefusal = "Not even a human fly could get up it."

    // MARK: - West of Chasm

    /// Written fresh — mainframe-only room. Zork I's East of Chasm stands on
    /// the other lip of a chasm this game keeps whole.
    static let westOfChasm = """
        You stand at the west lip of a chasm, the bottom of which cannot be
        seen. The far wall is sheer rock and offers nothing to cross to. A
        narrow passage goes west, and the path you are on continues north and
        south.
        """

    static let chasm = """
        The chasm's far wall is barely visible. Nothing thrown in has ever
        been heard to land.
        """

    static let chasmDownRefusal = """
        The chasm probably leads straight to the infernal regions.
        """

    // MARK: - Gallery

    /// Adapted. The trilogy's vandals leave "through either the north or west
    /// exits"; the mainframe's Gallery has three ways out, and the third — west
    /// — is the front hall of the Bank of Zork, which arrives with its own
    /// milestone.
    static let gallery = """
        This is an art gallery. Most of the paintings have been stolen by
        vandals with exceptional taste. The vandals left through the north,
        south, or west exits.
        """

    /// The room says "vandals" twice in three sentences and the painting's
    /// own listing line says it a third time, and the parser did not know the
    /// word — the round's one game-printed *"I don't know the word"*, which is
    /// the harsher of the two failures. Not a synonym on ``painting``: the
    /// vandals are the people who took the others. This is
    /// ``maintenanceWreckage``'s shape, an item for what is gone. (#329)
    static let galleryVandals = """
        Long gone, and thorough while they were here. Whoever they were, they
        left the one painting on the far wall, which tells you rather more
        about their taste than about their haste.
        """

    /// The three the same sentence names, and the third of them is a bank.
    static let galleryExits = """
        Three ways out, and the vandals are said to have used all of them:
        north, south, and west.
        """

    static let paintingFirstSight = """
        Fortunately, there is still one chance for you to be a vandal, for on
        the far wall is a work of unparalleled beauty.
        """

    static let painting = """
        A masterpiece by a neglected genius, in a frame worth rather less than
        the canvas.
        """

    // MARK: - Studio

    /// Adapted. The trilogy's Studio has one painted door, at the south end;
    /// the mainframe's has two, north and northwest. The chimney sentence is
    /// the trilogy's, and true of both.
    static let studio = """
        This appears to have been an artist's studio. The walls and floors are
        splattered with paints of 69 different colors. Strangely enough,
        nothing of value is hanging here. At the north and northwest of the
        room are open doors, also covered with paint. A dark and narrow
        chimney leads up from a fireplace; although you might be able to get
        up it, it seems unlikely you could get back down.
        """

    static let paints = """
        Every color the artist owned, and by the look of the walls he owned
        sixty-nine of them.
        """

    static let chimney = """
        The chimney leads upward, and looks climbable.
        """

    static let fireplace = """
        A cold hearth, its back wall streaked with a century of soot.
        """

    /// Adapted from the mainframe's rule rather than its words: the climb is
    /// possible only with the lamp and at most one other thing in hand.
    static let chimneyTooBurdened = """
        The chimney is too narrow for you and all of your baggage.
        """

    static let chimneyEmptyHanded = """
        Going up empty-handed is a bad idea.
        """
}
