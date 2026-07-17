/// Original Zork I prose for the Mirror Rooms region (``ZorkMirror``): the two
/// Mirror Rooms and the passages that thread them to the Round Room hub, the
/// drowned Atlantis Room and the reservoir beyond, and the one-way slide down to
/// the Cellar. These are the verbatim Infocom descriptions (see
/// THIRD_PARTY_NOTICES at the repo root). See `Prose.swift` for the
/// names-vs-prose ledger rule.
extension Prose {
    // MARK: - Rooms

    static let narrowPassage = """
        This is a long and narrow corridor where a long north-south passageway
        briefly narrows even further.
        """

    static let mirrorRoomNorth = """
        You are in a large square room with tall ceilings. On the south wall
        is an enormous mirror which fills the entire wall. There are exits
        on the other three sides of the room.
        """

    static let windingPassage = """
        This is a winding passage. It seems that there are only exits
        on the east and north.
        """

    static let mirrorRoomSouth = """
        You are in a large square room with tall ceilings. On the south wall
        is an enormous mirror which fills the entire wall. There are exits
        on the other three sides of the room.
        """

    static let coldPassage = """
        This is a cold and damp corridor where a long east-west passageway
        turns into a southward path.
        """

    static let twistingPassage = """
        This is a winding passage. It seems that there are only exits
        on the east and north.
        """

    static let smallCave = """
        This is a tiny cave with entrances west and north, and a staircase
        leading down.
        """

    static let atlantisRoom = """
        This is an ancient room, long under water. There is an exit to
        the south and a staircase leading up.
        """

    static let slideRoom = """
        This is a small chamber, which appears to have been part of a
        coal mine. On the south wall of the chamber the letters "Granite
        Wall" are etched in the rock. To the east is a long passage, and
        there is a steep metal slide twisting downward. To the north is
        a small opening.
        """

    // MARK: - Items

    static let crystalTrident = """
        It is a three-pronged fork wrought all of clear crystal, cold and
        faintly ringing to the touch — a king's own, by the look of it.
        """

    static let mirror = "There is an ugly person staring back at you."

    // MARK: - First sights

    static let crystalTridentFirstSight = "On the shore lies Poseidon's own crystal trident."

    // MARK: - Mechanics

    static let mirrorRumble = """
        There is a rumble from deep within the earth and the room shakes.
        """
}
