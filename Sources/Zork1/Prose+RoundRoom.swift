/// Placeholder prose for the Round Room hub (``ZorkRoundRoom``): the East-West
/// Passage, the Round Room and its radiating passages, the Chasm, Deep Canyon,
/// Damp Cave, and the Loud Room with its platinum bar. Original text — the
/// verbatim Infocom descriptions arrive later, one constant at a time. See
/// `Prose.swift` for the names-vs-prose ledger rule.
extension Prose {
    // MARK: - Rooms

    static let eastWestPassage = """
        A cramped passage runs straight east and west, low enough that you
        stoop as you go. At its north end the floor gives way to a narrow
        stair dropping into darkness.
        """

    static let roundRoom = """
        You stand at the center of a perfectly circular chamber. Passages open
        from it in every direction, though rubble and old cave-ins have sealed
        more than a few of them.
        """

    static let nsPassage = """
        A tall passage runs north and south here, its ceiling lost overhead. A
        second way branches off to the northeast.
        """

    static let chasmRoom = """
        A chasm cuts across the floor from southwest to northeast, and the path
        clings to its southern lip. A crack in the wall widens into a passage;
        below, there is only dark and a long, patient silence.
        """

    static let deepCanyon = """
        You are on the south rim of a canyon that falls away far beneath you.
        Ledges and passages lead off in several directions, and a stair winds
        down out of sight.
        """

    static let dampCave = """
        The walls of this cave glisten with damp, and the air hangs heavy and
        wet. Ways lead off east and west, and to the south the cave pinches
        down to a crack too tight to follow.
        """

    static let loudRoom = """
        This is a wide chamber whose ceiling is lost in the dark above. A
        passage runs east to west, and a stone stair climbs upward.
        """

    // MARK: - The platinum bar

    static let platinumBarFirstSight = "A large bar of platinum lies on the ground."

    static let platinumBar = """
        A single bar of platinum, dense and improbably heavy, its surface
        catching what little light there is.
        """

    // MARK: - Loud Room acoustics

    static let loudRoomGarble = """
        The din swallows your words whole. Whatever you meant is lost in the
        roar before it can amount to anything.
        """

    static let loudRoomAcousticsFixed = """
        Your voice rings out and comes back to you, and as it does the roar
        seems to fold in on itself. The room settles into an uneasy quiet.
        """

    static let loudRoomEjects = """
        The noise here is past bearing — an enormous rushing that pounds behind
        your eyes until you can do nothing but stumble blindly away from it.
        """

    // MARK: - Blocked exits

    static let chasmDownRefusal = "That way lies a very long fall and a very short future."

    static let dampCaveTooNarrow = "The crack narrows to nothing a body could hope to pass."
}
