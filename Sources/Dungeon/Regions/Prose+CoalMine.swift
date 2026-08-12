/// Prose for the coal mine (``DungeonCoalMine``): the Mine Entrance and its
/// bat, the Shaft Room and the basket on its chain, the Wooden Tunnel and the
/// Gas Room, the seven rooms of the coal maze, the ladder, the Timber Room and
/// the crack past it, the Lower Shaft and the Machine Room.
///
/// The three-way rule, and the rule for which file a line goes in, are stated
/// once on ``Prose``.
extension Prose {
    // MARK: - The way in

    /// Adapted. `ENTRA` is `substantial`: the trilogy's mine has one shaft in
    /// the west wall, and the mainframe's has two entrances — northeast and
    /// northwest — besides the way back south.
    static let mineEntrance = """
        You are standing at the entrance of what might have been a coal mine.
        To the northeast and the northwest are entrances to the mine, and
        there is another exit on the south end of the room.
        """

    static let mineEntrances = """
        Two black openings in the rock, propped with timber that has not been
        looked at in a very long time.
        """

    /// Adapted. `SQUEE` is bucketed `minor`, and the few characters between
    /// the two lines are the compass: the squeaking is west of the mainframe's
    /// room and north of the trilogy's, and the way out is south rather than
    /// east.
    static let squeakyRoom = """
        You are in a small room. Strange squeaky sounds may be heard coming
        from the passage at the west end. You may also escape to the south.
        """

    static let squeakySounds = """
        A thin, dry, unpleasant squeaking, and a good deal of it, from
        somewhere past the west end of the room.
        """

    /// Adapted from the trilogy's Bat Room, which has two doors where the
    /// mainframe's has one.
    static let batRoom = """
        You are in a small room which has a door only to the east.
        """

    static let batHangsThere = """
        In the corner of the room on the ceiling is a large vampire bat who is
        obviously deranged and holding his nose.
        """

    static let bat = """
        A vampire bat the size of a dog, hanging upside down and, at present,
        entirely occupied with the smell of you.
        """

    static let batGrabsYou = """
        A deranged giant vampire bat (a reject from WUMPUS) swoops down from
        his belfry and lifts you away....
        """

    /// Verbatim — `JADE` is in the comparison's `identical` bucket.
    static let jadeFirstSight = "There is an exquisite jade figurine here."

    static let jade = """
        A figurine of jade, carved by somebody with a great deal of patience
        into something with a great deal of teeth.
        """

    // MARK: - The Shaft Room

    /// Verbatim — `TSHAF` is in the comparison's `identical` bucket, which
    /// means the trilogy copied the mainframe's room and its exits word for
    /// word.
    static let shaftRoom = """
        This is a large room, in the middle of which is a small shaft
        descending through the floor into darkness below. To the west and
        the north are exits from this room. Constructed over the top of the
        shaft is a metal framework to which a heavy iron chain is attached.
        """

    static let shaftTooNarrow = """
        You wouldn't fit and would die if you could.
        """

    static let ironChain = """
        A heavy iron chain running over the framework and away down the shaft,
        with a basket made fast to the end of it.
        """

    static let chainNotClimbable = "The chain is not climbable."

    /// Verbatim — `TBASK` is in the comparison's `identical` bucket. It is the
    /// listing line, which is where the mainframe puts it.
    static let basket = "At the end of the chain is a basket."

    static let basketExamined = """
        A wicker basket the size of a wheelbarrow, wired to the end of the
        chain and meant for sending things up and down a shaft nobody could
        fit through.
        """

    static let basketFarEnd = "The basket is at the other end of the chain."

    static let basketFarEndExamined = """
        The basket hangs at the far end of the chain, too distant to be worth
        shouting at.
        """

    static let basketFastened = "The cage is securely fastened to the iron chain."

    static let basketLowered = "The basket is lowered to the bottom of the shaft."

    static let basketRaised = "The basket is raised to the top of the shaft."

    static let basketAlreadyLowered = """
        The basket already hangs at the bottom of the shaft.
        """

    static let basketAlreadyRaised = """
        The basket is already here at the top of the shaft.
        """

    static let itIsNowPitchBlack = "It is now pitch black."

    // MARK: - The Wooden Tunnel and the Gas Room

    /// Written fresh. `TUNNE` has no trilogy counterpart at all — Zork I runs
    /// its Shaft Room straight into the Smelly Room and never builds the
    /// junction that puts the coal maze on its own branch.
    static let woodenTunnel = """
        This is a narrow tunnel with large wooden beams running across the
        ceiling and around the walls. A path from the south splits into paths
        running west and northeast.
        """

    static let woodenBeams = """
        Beams of old timber, black with age and carrying more weight than any
        of them was cut for.
        """

    /// Adapted. `SMELL` is bucketed `minor`, and the few characters are again
    /// the exits: the mainframe's narrow path runs east, not south.
    static let smellyRoom = """
        This is a small nondescript room. However, from the direction of a
        small descending staircase a foul odor can be detected. To the east is
        a narrow path.
        """

    static let foulOdor = """
        Something down the staircase that a coal mine ought to know better
        than to smell of.
        """

    /// Written fresh. The room's own description points at these, and the odor
    /// is what comes up them rather than what they are — which is why the two
    /// are separate items now.
    static let smellyRoomStairs = """
        Narrow steps cut into the rock, dropping away into the dark. Whatever
        is down there is what you can smell.
        """

    /// Written fresh. From below, the same staircase is simply the way out.
    static let gasRoomStairs = """
        A short flight of steps back up to the room above, and the only way out
        of this one.
        """

    /// Written fresh, both of them. ``DungeonSystems`` answers `smell`
    /// game-wide, and its one line told the player, in the two rooms in the
    /// game whose descriptions are *about* a smell, that there was nothing to
    /// smell — a contradiction two lines apart. (#233)
    ///
    /// The flame is deliberately not mentioned below. What the Gas Room does to
    /// an open flame is the puzzle; a `smell` that warned about it would make
    /// the room easier, which is a mechanics change and not a prose repair.
    static let smellyRoomSmelled = """
        It comes up the staircase in slow waves — sweetish, and wrong, and not
        the smell of a coal mine.
        """

    static let gasRoomSmelled = """
        Coal gas, and a great deal of it. Every breath is thicker than the one
        before it.
        """

    /// Adapted. `BOOM` is `substantial` because the trilogy gave the Gas Room
    /// a second exit east into its own coal maze. The mainframe's has one way
    /// out, and it is back up the stairs.
    static let gasRoom = """
        This is a small room which smells strongly of coal gas. There is a
        short climb up some stairs.
        """

    static let coalGas = """
        The air here is thick enough to lean on, and it is not air.
        """

    static let sapphireBraceletFirstSight = """
        A sapphire-encrusted bracelet lies here.
        """

    static let sapphireBracelet = """
        A heavy bracelet, thick with sapphires that catch what little light
        there is and throw it back blue.
        """

    /// Written fresh from the mainframe's two `BOOM-ROOM` endings: one for
    /// walking in with a flame, one for striking one where you stand.
    static let gasExplosionCarried = """
        Oh dear. It appears that the smell coming from this room was coal gas.
        I would have thought twice about carrying flaming objects in here.

              ** BOOOOOOOOOOOM **
        """

    static let gasExplosionStruck = """
        I didn't realize that adventurers are stupid enough to light a flame
        in a room which reeks of coal gas. Fortunately, there is justice in
        the world.

              ** BOOOOOOOOOOOM **
        """

    // MARK: - The coal maze

    /// Verbatim, and one line for all seven rooms, exactly as the mainframe
    /// gives all seven the same `MINDESC`. The sameness is the puzzle.
    static let coalMine = "This is a nondescript part of a coal mine."

    static let coalMineWalls = """
        Coal, and the props holding the coal up, and no way of telling this
        stretch of it from any other.
        """

    /// Verbatim — the trilogy's Ladder Top is the mainframe's, exits and all.
    static let ladderTop = """
        This is a very small room. In the corner is a rickety wooden ladder,
        leading downward. It might be safe to descend. There is also a
        staircase leading upward.
        """

    /// Adapted. The trilogy's Ladder Bottom leaves west and south; the
    /// mainframe's leaves northeast and south.
    static let ladderBottom = """
        This is a rather wide room. On one side is the bottom of a narrow
        wooden ladder. To the northeast and the south are passages leaving the
        room.
        """

    static let woodenLadder = """
        A wooden ladder, rickety enough that you would rather not think about
        it while you are on it.
        """

    static let coalDeadEnd = "You have come to a dead end in the mine."

    static let coalFirstSight = """
        There is a small pile of coal here.
        """

    static let coal = """
        An ordinary small pile of coal — black, dusty and unremarkable,
        whatever a machine might make of it.
        """

    // MARK: - The Timber Room and the crack

    /// Adapted. The trilogy's Timber Room turns west into the narrow passage;
    /// the mainframe's turns at the southwest corner, and the wide passage
    /// comes from the north.
    static let timberRoom = """
        This is a long and narrow passage, which is cluttered with broken
        timbers. A wide passage comes from the north and turns at the
        southwest corner of the room into a very narrow passageway.
        """

    static let brokenTimber = """
        A broken timber, longer than you are and heavier than it looks.
        """

    static let brokenTimberFirstSight = "A broken timber is lying here."

    static let crackTooNarrow = """
        You cannot fit through this passage with that load.
        """

    /// Adapted. The trilogy's Drafty Room is the mainframe's Lower Shaft, and
    /// the two narrow ways out of it are east and northeast rather than south
    /// and east.
    static let lowerShaft = """
        This is a small square room which is at the bottom of a long shaft. To
        the east is a passageway and to the northeast a very narrow passage.
        In the shaft can be seen a heavy iron chain.
        """

    /// Written fresh. The Lower Shaft names the shaft it is at the bottom of,
    /// the chain hanging in it and two passages out, and none of the three
    /// answered: ``ironChain`` carries `chain` and `shaft` and stands in the
    /// Shaft Room, a hundred feet up. One chain, two ends, two items — the
    /// staircase's repair applied again. (#233)
    static let lowerShaftChain = """
        The chain comes down the middle of the shaft out of a dark that swallows
        its far end, with the basket somewhere up there on it.
        """

    static let lowerShaftPassages = """
        Two ways out of the bottom of the shaft, and neither of them wide.
        """

    // MARK: - The Machine Room

    /// Adapted. The trilogy's Machine Room has its sole exit north; the
    /// mainframe's has it northwest. The machine, its lid and its impossible
    /// switch are the same in both.
    static let machineRoom = """
        This is a large, cold room whose sole exit is to the northwest. In one
        corner there is a machine which is reminiscent of a clothes dryer. On
        its face is a switch which is labelled "START". The switch does not
        appear to be manipulable by any human hand (unless the fingers are
        about 1/16 by 1/4 inch). On the front of the machine is a large lid,
        which is
        """

    static let machineLidOpen = "open."

    static let machineLidClosed = "closed."

    static let machine = """
        The machine is a squat iron box, much like a clothes dryer, with a
        heavy lid on the front and a switch — far too small for a finger — on
        its face.
        """

    static let machineSwitch = """
        The switch is a tiny thing, no wider than a coin's edge, and would
        need some slender tool to throw it.
        """

    static let machineTooBig = "It is far too large to carry."

    static let switchNeedsTool = """
        It's not clear how to turn it on with your bare hands.
        """

    static let switchWrongTool = "It seems that that won't do."

    static let machineDoesNothing = """
        The machine doesn't seem to want to do anything.
        """

    static let machineRuns = """
        The machine comes to life (figuratively) with a dazzling display of
        colored lights and bizarre noises. After a few moments, the excitement
        abates.
        """

    /// Verbatim — `DIAMO` is in the comparison's `identical` bucket.
    static let diamondFirstSight = """
        There is an enormous diamond (perfectly cut) here.
        """

    static let diamond = """
        An enormous diamond, perfectly cut, and a great deal harder to explain
        than it is to carry.
        """

    static let slag = """
        A piece of vitreous slag, which is what the machine makes of anything
        that was not coal.
        """

    static let slagFirstSight = "There is a piece of vitreous slag here."

    static let slagCrumbles = """
        The slag turns out to be rather insubstantial, and crumbles into dust
        at your touch. It must not have been very valuable.
        """
}
