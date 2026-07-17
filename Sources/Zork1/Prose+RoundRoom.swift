/// Original Zork I prose for the Round Room hub (``ZorkRoundRoom``): the
/// East-West Passage, the Round Room and its radiating passages, the Chasm,
/// Deep Canyon, Damp Cave, and the Loud Room with its platinum bar. These are
/// the verbatim Infocom descriptions (see THIRD_PARTY_NOTICES at the repo
/// root). See `Prose.swift` for the names-vs-prose ledger rule.
extension Prose {
    // MARK: - Rooms

    static let eastWestPassage = """
        This is a narrow east-west passageway. There is a narrow stairway
        leading down at the north end of the room.
        """

    static let roundRoom = """
        This is a circular stone room with passages in all directions. Several
        of them have unfortunately been blocked by cave-ins.
        """

    static let nsPassage = """
        This is a high north-south passage, which forks to the northeast.
        """

    static let chasmRoom = """
        A chasm runs southwest to northeast and the path follows it. You are
        on the south side of the chasm, where a crack opens into a passage.
        """

    static let deepCanyon = """
        You are on the south edge of a deep canyon. Passages lead off to the
        east, northwest and southwest. A stairway leads down.
        """

    static let dampCave = """
        This cave has exits to the west and east, and narrows to a crack toward
        the south. The earth is particularly damp here.
        """

    static let loudRoom = """
        This is a large room with a ceiling which cannot be detected from
        the ground. There is a narrow passage from east to west and a stone
        stairway leading upward.
        """

    // MARK: - The platinum bar

    static let platinumBarFirstSight = "On the ground is a large platinum bar."

    static let platinumBar = "On the ground is a large platinum bar."

    /// The bar is sacred while the room roars — the original's SACREDBIT.
    /// Reaching for it in the din, the acoustics beat it out of your hands.
    static let platinumBarTooLoud = """
        The room's ear-splitting roar shakes the bar from your grip; you
        cannot get hold of it while the acoustics rage.
        """

    // MARK: - Loud Room acoustics

    /// The room's read-loop: your voice booms and the walls fling the last
    /// word of your command back at you (the original's echo garble).
    static func loudRoomEcho(_ word: String) -> String {
        "The acoustics of the room cause your words to echo: \u{201C}\(word)... \(word)... \(word)...\u{201D}"
    }

    static let loudRoomAcousticsFixed = """
        The acoustics of the room change subtly.
        """

    static let loudRoomEjects = """
        It is unbearably loud here, with an ear-splitting roar seeming to
        come from all around you. There is a pounding in your head which won't
        stop. With a tremendous effort, you scramble out of the room.
        """

    // MARK: - Blocked exits

    static let chasmDownRefusal = "Are you out of your mind?"

    static let dampCaveTooNarrow = "It is too narrow for most insects."
}
