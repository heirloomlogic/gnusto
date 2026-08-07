/// Prose for the white house's interior (``DungeonHouse``): kitchen, living
/// room, attic, and the Cellar the trap door drops into.
///
/// The three-way rule, and the rule for which file a line goes in, are stated
/// once on ``Prose``.
extension Prose {
    // MARK: - Kitchen

    /// Verbatim Zork I. Every fact in it holds: west to the living room, the
    /// stair up to the attic, the chimney down (refused), the window east.
    static let kitchen = """
        You are in the kitchen of the white house. A table seems to have
        been used recently for the preparation of food. A passage leads to
        the west and a dark staircase can be seen leading upward. A dark
        chimney leads down and to the east is a small window which is
        slightly ajar.
        """

    static let kitchenTable = """
        A plain wooden table, its surface scarred by a good deal of chopping.
        """

    static let kitchenStaircase = """
        A dark staircase, climbing steeply out of the lamplight.
        """

    static let kitchenChimney = """
        A dark chimney, dropping away out of the fireplace and much too narrow
        to be worth the try.
        """

    static let kitchenWindow = """
        The window is slightly ajar, but not enough to allow entry.
        """

    static let chimneyDownRefusal = "Only Santa Claus climbs down chimneys."

    /// Verbatim Zork I — the listing line, for the sack where it lies.
    static let sackOnTable = "On the table is an elongated brown sack, smelling of hot peppers."

    static let sack = "A brown sack of coarse cloth, smelling strongly of hot peppers."

    static let garlic = "A single clove of garlic, papery and pungent."

    static let lunch = "A hot pepper sandwich, and a generous one."

    /// Verbatim Zork I — the listing line.
    static let bottleOnTable = """
        A bottle is sitting on the table.
        """

    static let bottle = "A clear glass bottle, stoppered and quite ordinary."

    static let water = "A quantity of ordinary water."

    // MARK: - Living room

    /// Verbatim Zork I. The mainframe living room has exactly these three
    /// ways out: the doorway east, the gothic door west (nailed shut until
    /// the cyclops opens it), and the trap door under the rug.
    static let livingRoom = """
        You are in the living room. There is a doorway to the east, a
        wooden door with strange gothic lettering to the west, which
        appears to be nailed shut, a trophy case, and a large oriental rug
        in the center of the room.
        """

    static let woodenDoor = """
        A heavy wooden door in the west wall, lettered over in a cramped
        gothic hand and nailed fast.
        """

    /// Written fresh. The mainframe's engraving is a joke at the reader's
    /// expense; this one is the same joke in this project's own words.
    static let woodenDoorLettering = """
        The gothic lettering, painstakingly worked, translates as: "This
        space intentionally left blank."
        """

    static let woodenDoorNailedShut = "The door is nailed shut."

    static let lanternOnCase = """
        A battery-powered brass lantern is on the trophy case.
        """

    static let lanternOff = """
        The lamp is turned off.
        """

    static let lanternOn = """
        The lamp is on.
        """

    static let lanternDim = """
        The lamp appears a bit dimmer.
        """

    static let lanternLastGasp = """
        The lamp is nearly out.
        """

    static let lanternDies = "You'd better have more light than from the brass lantern."

    static let lanternSpent = """
        A burned-out lamp won't light.
        """

    /// Adapted. The trilogy hangs the sword above the trophy case; the
    /// mainframe hangs it on hooks above the mantelpiece, which is where it
    /// hangs here.
    static let swordOnHooks = """
        On hooks above the mantelpiece hangs an elvish sword of great
        antiquity.
        """

    static let sword = """
        A long elvish blade, plain in the grip and very far from plain in the
        edge. It is old enough to have opinions.
        """

    static let mantelpiece = """
        A broad stone mantelpiece, and above it a pair of iron hooks.
        """

    static let rug = "A thick, dusty oriental rug, heavy enough to take some effort to move."

    static let rugMoveEmbellishment = """
        With a great effort, the rug is moved to one side of the room, \
        revealing the dusty cover of a closed trap door.
        """

    static let rugAlreadyMoved = """
        Having moved the carpet previously, you find it impossible to move \
        it again.
        """

    static let rugTooHeavy = "The rug is extremely heavy and cannot be carried."

    static let trapDoor = "A stout wooden trap door, set into the floorboards."

    static let trapDoorOpens = """
        The door reluctantly opens to reveal a rickety staircase descending
        into darkness.
        """

    /// Verbatim Zork I, and word for word what the mainframe does at this
    /// moment too — the bar goes across whether or not anyone is about.
    static let trapDoorSlam = "The trap door crashes shut, and you hear someone barring it."

    /// Adapted. In the mainframe the bar is not the thief's doing and there is
    /// no negotiating with it: from below, the door is simply locked from
    /// above, and the chimney is the way out.
    static let trapDoorBarred = "The door is locked from above."

    static let trophyCaseEmpty = "A glass-fronted trophy case, empty for now."

    static func trophyCaseHolding(_ contents: String) -> String {
        "A glass-fronted trophy case, holding \(contents)."
    }

    static let trophyCaseFastened = """
        The trophy case is securely fastened to the wall (perhaps to foil any
        attempt by robbers to remove it).
        """

    /// Written fresh — the newspaper is mainframe-only, and its own text is
    /// 1981 MDL, so both the shelf line and what it says are this project's.
    static let newspaperInPlace = """
        There is an issue of the US NEWS & DUNGEON REPORT here.
        """

    static let newspaper = """
        An issue of the US NEWS & DUNGEON REPORT, its date some weeks gone and
        its paper already yellowing.
        """

    static let newspaperText = """
        US NEWS & DUNGEON REPORT — Last G.U.E. Edition

        This edition of the Great Underground Empire's paper of record carries,
        beneath the usual notices, one item of interest to the visitor: that
        the Empire's holdings below this house are no longer maintained, that
        the last of its surveyors did not come back up, and that persons
        entering do so on their own account. The remainder of the page is
        given over to advertisements for lanterns.
        """

    // MARK: - Attic

    /// Verbatim Zork I. Down is the only way out of it in both games — but
    /// this attic is **dark** (the mainframe gives it no light bit), so the
    /// lamp has to come up the stairs with you.
    static let attic = """
        This is the attic. The only exit is a stairway leading down.
        """

    /// Verbatim Zork I — the listing lines, for the coil and the blade where
    /// they lie.
    static let ropeInCorner = "A large coil of rope is lying in the corner."

    static let rope = "A long coil of stout hemp rope, well made and hardly used."

    static let knifeOnTable = "On a table is a nasty-looking knife."

    static let knife = "A plain, unrusted knife with an unpleasantly business-like edge."

    static let atticTable = """
        A rickety table, pushed against the wall and thick with dust.
        """

    /// Verbatim; `BRICK` is an `identical` entry, so the trilogy carries this
    /// line word for word. (Milestone 1 filed it as written fresh, on the
    /// assumption that the brick was mainframe-only. It is not.)
    static let brickInPlace = """
        There is a square brick here which feels like clay.
        """

    static let brick = """
        A square brick, the size of two fists, that yields a little under the
        thumb like clay. It is hollow, and something has been hollowed out of
        it deliberately.
        """

    // MARK: - Cellar

    /// Adapted. The trilogy's Cellar sends its narrow passageway **north**; the
    /// mainframe's sends it **east**, to the Troll Room. The crawlway south and
    /// the unclimbable ramp west are the same in both.
    static let cellar = """
        You are in a dark and damp cellar with a narrow passageway leading
        east, and a crawlway to the south. On the west is the bottom of a
        steep metal ramp which is unclimbable.
        """

    static let cellarRamp = """
        A steep metal ramp rising into the dark, far too smooth to climb.
        """

    static let cellarRampRefusal = """
        You try to ascend the ramp, but it is impossible, and you slide back
        down.
        """
}
