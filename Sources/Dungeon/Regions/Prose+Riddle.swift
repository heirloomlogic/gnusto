/// Prose for the two rooms between the Engravings Cave and the well
/// (``DungeonRiddle``): the Riddle Room, its stone door, and the former broom
/// closet behind it where the pearls are.
///
/// The three-way rule, and the rule for which file a line goes in, are stated
/// once on ``Prose``.
///
/// `MPEAR` and `PEARL` are `identical` entries in
/// `docs/games/dungeon-prose-comparison.md`, so those two lines are the
/// trilogy's verbatim. `RIDDL` is filed `substantial` and its trilogy column is
/// **empty** — the room has no counterpart at all — so the Riddle Room, its
/// door and its verse are written fresh: new lines in the folk register the
/// mainframe borrowed from, with the same answer, because the answer is the
/// puzzle and the puzzle is structure.
extension Prose {
    // MARK: - The Riddle Room

    static let riddleRoom = """
        This is a bare room, four square, with nothing in it but a way down
        and, in the east wall, a great door of dressed stone. Words are cut
        into the lintel above it.
        """

    /// The word the door is listening for, written once. Compared against
    /// what the player typed, so the answer lives here as a string and never
    /// as a row in the verb table — which is what stopped the parser knowing
    /// it. See ``Intent/answer``.
    static let riddleWord = "well"

    /// The lintel. Fresh verse, and the answer is the same object the
    /// mainframe's riddle names — which is the whole of what the source
    /// settles here, since the room east of it is the well.
    static let riddleInscription = """
        Cut deep into the stone, in a hand that had time to spare:

            No one passes who cannot say
            what stands as tall as a house,
            is round as the mouth of a cup,
            holds a coin of sky in the dark,
            and cannot be drawn up
            by all the King's horses at once.

        Beneath, smaller: ANSWER <WORD>.
        """

    static let riddleDoorShut = """
        The stone door is shut, and no seam in it will take a finger.
        """

    static let riddleDoorOpen = """
        The stone door stands open on a passage running east.
        """

    static let riddleBarred = """
        Something you cannot see stands between you and the doorway, and it
        does not move.
        """

    static let riddleAnswered = """
        There is a grinding of stone on stone, and the great door swings back
        into the wall. The way east is open.
        """

    static let riddleAlreadyAnswered = """
        The door is open. You have already had the better of it once.
        """

    /// Said in the Riddle Room to any word but the one cut over the door.
    /// Not a parse error: since ``Intent/answer`` took a topic slot, every
    /// word costs the same turn, and the door's silence has to be the answer
    /// rather than the vocabulary's.
    static let riddleWrongWord = """
        Nothing happens. Whatever the door is waiting for, that was not it.
        """

    // MARK: - The Pearl Room

    /// Verbatim. `MPEAR` is one of the comparison's `identical` entries — the
    /// trilogy kept the line and the room, exits and all.
    static let pearlRoom = """
        This is a former broom closet. The exits are to the east and west.
        """

    /// Verbatim — `PEARL` is `identical` too.
    static let pearlNecklaceFirstSight = """
        There is a pearl necklace here with hundreds of large pearls.
        """

    static let pearlNecklace = """
        Hundreds of pearls, each the size of a thumbnail, strung on a wire
        that has outlasted whoever wore it.
        """

    static let pearlRoomShelves = """
        Bare shelves, and the brackets where more shelves used to be.
        """
}
