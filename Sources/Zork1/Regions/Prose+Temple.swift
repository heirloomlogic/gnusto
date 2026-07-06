/// Placeholder prose for the Temple & Hades region (``ZorkTemple``): the
/// Engravings Cave and the Dome Room's rope descent, the Torch Room, the Temple
/// and its Altar, the Egyptian Room with the coffin, and the dark way down past
/// a draughty cave to the Entrance to Hades and the Land of the Dead. Original
/// text — the verbatim Infocom descriptions arrive later, one constant at a
/// time. See `Prose.swift` for the names-vs-prose ledger rule.
extension Prose {
    // MARK: - Rooms

    static let engravingsCave = """
        You are in a low cave whose walls are covered close with engravings —
        the work of some patient, long-dead hand. The cave narrows to a
        passage east, and the way you came lies back to the west.
        """

    static let domeRoom = """
        You stand at the lip of a great domed chamber. A stone railing rings
        the edge, and below it the floor drops away into darkness — far too
        far to climb down unaided. The only walking-way out is west.
        """

    static let torchRoom = """
        This is a small room, empty but for the pedestal at its center. A dark
        shaft rises overhead, a rope hanging out of reach at the top of it.
        Steps lead down, and a passage runs south.
        """

    static let temple = """
        You are in the nave of an ancient temple, its columns rising into
        shadow. A dark staircase leads down to the east, a smaller way opens
        south, and steps climb north toward the room above.
        """

    static let egyptRoom = """
        This is a cramped chamber in the old Egyptian style, its walls painted
        with figures in profile. The only way out is back to the west and up.
        """

    static let altar = """
        Before you stands a plain stone altar, worn smooth by the hands of
        worshippers gone to dust. Steps lead north to the temple; a narrow
        crack in the floor drops away to the south.
        """

    static let templeCave = """
        You are in a small cave, little more than a widening of the passage. A
        cold draught blows up from a staircase spiralling down into the dark,
        and the way back up leads to the altar. Rough openings lead off north
        and west, though neither goes anywhere you can reach from here yet.
        """

    static let entranceToHades = """
        You have come to the gateway of Hades. A wall of restless spirits bars
        the way south, jeering and moaning, and their cold hands hold you back
        from the gate. Steps climb up behind you.
        """

    static let landOfDead = """
        You are in the land of the dead, a still and lightless waste where the
        empire's fallen have been laid. The gate out lies back to the north.
        """

    // MARK: - Items

    static let ivoryTorch = """
        An ivory torch, carved and old, burns here with a clean white flame
        that never seems to gutter.
        """

    static let templeRailing = """
        A stone railing runs around the rim of the dome — the kind of thing a
        rope might be made fast to.
        """

    static let bell = """
        A small brass hand-bell, of the sort once rung to call the faithful.
        """

    static let redHotBell = """
        The brass bell glows a dull, angry red, far too hot to lay a hand on.
        """

    static let book = """
        A slim black book, its pages closely printed with prayers in a script
        gone brown with age. One passage, marked with a ribbon, seems meant to
        be read aloud.
        """

    static let candles = """
        A pair of white candles, half burned down. Unlit, they are only so
        much cold wax.
        """

    static let coffin = """
        A magnificent coffin of solid gold, worked all over with the likeness
        of a king at rest. It is heavy beyond reason and would tax anyone who
        tried to carry it far.
        """

    static let sceptre = """
        An ornate sceptre, its haft banded with gold and its head set with a
        single sharp point, fit for a buried king.
        """

    static let crystalSkull = """
        A skull cut whole from a block of clear crystal, the empty sockets
        catching what little light there is.
        """

    static let burningMatch = "A match burns in your fingers, its small flame already eating down the stick."

    // MARK: - First sights

    static let coffinFirstSight = "A gold coffin rests upon the floor."

    static let crystalSkullFirstSight = "A crystal skull lies among the bones of the dead."

    // MARK: - Rope & the dome descent

    static let domeNoRope = """
        It is far too great a drop to climb without a rope, and nothing here
        offers a handhold.
        """

    static let torchNoRope = "The rope hangs high above the shaft, well out of your reach."

    static let ropeTied = """
        You make the rope fast to the stone railing, and its free end falls
        away into the dome below. A climb down is possible now.
        """

    static let ropeUntied = "You loose the rope from the railing and coil it back up."

    static let ropeTakeUnties = "You untie the rope from the railing before taking it."

    static let ropeNeedsRailing = "You can only tie the rope to the railing here."

    static let ropeNothingToTie = "There is nothing here worth tying the rope to."

    // MARK: - Torch

    static let torchWontExtinguish = "The ivory torch burns with a steady flame and will not be put out."

    // MARK: - The altar & the coffin

    static let coffinTooHeavy = """
        The crack in the floor is far too narrow to squeeze through with so
        great a load. You haven't a prayer of getting it down there.
        """

    static let prayerAnswered = """
        You bow your head at the altar, and the temple dissolves around you.
        When the world settles again you are standing in open forest, whatever
        you carried still in your hands.
        """

    // MARK: - The bell

    static let bellRingsHollow = "The bell rings out, a small clear note that fades to nothing."

    static let bellRingRedHot = """
        The bell tolls once, and the sound hangs in the air like a struck
        nerve. The spirits at the gate freeze mid-jeer — and the bell, glowing
        suddenly red hot, drops from your hand to the ground.
        """

    static let bellAlreadyRung = "The bell lies red hot upon the ground; there is no ringing it now."

    static let bellCools = "The brass bell has cooled enough to handle again."

    static let bellTooHotToTake = "The bell is still glowing red hot — you would burn your hand to the bone."

    // MARK: - The candles

    static let candlesNeedFlame = "You have nothing to light the candles with."

    static let candlesLit = "The candles catch and burn with a steady yellow light."

    static let candlesLitForRitual = """
        The candles catch and burn, and their light seems to hold the frozen
        spirits fast where they stand.
        """

    static let candlesSpent = "The candles have burned away to stubs; there is nothing left to light."

    static let candlesDim = "The candles have burned low, their flames grown small and blue."

    static let candlesDie = "With a last thread of smoke, the candles gutter out for good."

    static let candlesSnuffedByDraft = "The cold draught in the cave snuffs your candles out."

    // MARK: - The exorcism

    static let spiritsBanished = """
        You read the marked prayer aloud. Word by word the spirits thin and
        fray, and with a final wail the whole host of them is gone. The way
        south stands open.
        """

    static let exorcismLapses = """
        The moment slips away. The spirits stir, shake off their stillness,
        and take up their jeering at the gate once more.
        """

    static let hadesGateBlocked = """
        The wall of spirits holds you back; some cold force at the gate will
        not let you pass.
        """

    // MARK: - The matches

    static let matchStrikes = "One of the matches flares alight in your hand."

    static let matchesGone = "The matchbook is empty; not a single match is left."

    static let matchBurnsOut = "The match burns down to your fingers and goes out."
}
