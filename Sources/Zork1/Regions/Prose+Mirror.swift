/// Placeholder prose for the Mirror Rooms region (``ZorkMirror``): the two
/// Mirror Rooms and the passages that thread them to the Round Room hub, the
/// drowned Atlantis Room and the reservoir beyond, and the one-way slide down to
/// the Cellar. Original text — the verbatim Infocom descriptions arrive later,
/// one constant at a time. See `Prose.swift` for the names-vs-prose ledger rule.
extension Prose {
    // MARK: - Rooms

    static let narrowPassage = """
        The corridor pinches in to either side here, so that a long
        north-south passage is for a few paces scarcely shoulder-wide before it
        opens out again. The way runs north and south.
        """

    static let mirrorRoomNorth = """
        This is a square room, oddly bright, its far wall filled entirely by an
        enormous mirror. Passages leave to the north, the west, and the east.
        """

    static let windingPassage = """
        The passage doubles back and forth on itself so many times you soon lose
        your bearings. As far as you can tell, the only ways out are east and
        north.
        """

    static let mirrorRoomSouth = """
        This is a square room, its far wall filled entirely by an enormous
        mirror that swallows the light. Passages leave to the north, the west,
        and the east.
        """

    static let coldPassage = """
        This is a cold, damp corridor. A long passage runs east and west, and a
        colder path bends away to the south.
        """

    static let twistingPassage = """
        The passage twists and turns without pattern. As far as you can make
        out, the only ways onward are east and north.
        """

    static let smallCave = """
        This is a cramped little cave. Openings lead off to the west and north,
        and a stone staircase winds down into the dark.
        """

    static let atlantisRoom = """
        This is a high, ancient room that spent long ages beneath the water; the
        walls still weep with it. A passage leads south, and a worn staircase
        climbs up out of the room.
        """

    static let slideRoom = """
        This is a small chamber that seems to have been cut for a coal mine long
        abandoned. The words "Granite Wall" are chiselled into the south wall. A
        passage runs east, and a steep metal slide corkscrews away downward.
        """

    // MARK: - Items

    static let crystalTrident = """
        It is a three-pronged fork wrought all of clear crystal, cold and
        faintly ringing to the touch — a king's own, by the look of it.
        """

    static let mirror = """
        The mirror is enormous — many times your height — and set so smoothly
        into the wall that you cannot tell where the glass ends and the stone
        begins.
        """

    // MARK: - First sights

    static let crystalTridentFirstSight = "A crystal trident lies here on the old stone floor."

    // MARK: - Mechanics

    static let mirrorRumble = """
        A rumble sounds from deep within the earth, and the room shudders around
        you.
        """
}
