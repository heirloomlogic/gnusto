/// Original Zork I prose for the house interior (``ZorkHouse``): kitchen,
/// living room, attic, and the cellar the trap door drops into, plus the
/// lantern's fuel-state lines. Transcribed from the MIT-licensed historical
/// Zork source — see `THIRD_PARTY_NOTICES` at the repo root.
extension Prose {
    // MARK: - House: interior

    static let kitchen = """
        You are in the kitchen of the white house. A table seems to have
        been used recently for the preparation of food. A passage leads to
        the west and a dark staircase can be seen leading upward. A dark
        chimney leads down and to the east is a small window which is
        slightly ajar.
        """

    static let kitchenWindow = """
        The window is slightly ajar, but not enough to allow entry.
        """

    static let sack = "On the table is an elongated brown sack, smelling of hot peppers."

    static let garlic = "A single clove of garlic, papery and pungent."

    static let lunch = "A hot pepper sandwich is here."

    static let bottle = """
        A bottle is sitting on the table.
        """

    static let water = "A quantity of ordinary water."

    static let livingRoom = """
        You are in the living room. There is a doorway to the east, a
        wooden door with strange gothic lettering to the west, which
        appears to be nailed shut, a trophy case, and a large oriental rug
        in the center of the room.
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

    static let lanternDies = "You'd better have more light than from the brass lantern."

    static let lanternSpent = """
        A burned-out lamp won't light.
        """

    static let sword = """
        Above the trophy case hangs an elvish sword of great antiquity.
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

    static let trapDoor = "A stout wooden trap door, set into the floorboards."

    static let trapDoorSlam = "The trap door crashes shut, and you hear someone barring it."

    static let trophyCaseEmpty = "A glass-fronted trophy case, empty for now."

    static func trophyCaseHolding(_ contents: String) -> String {
        "A glass-fronted trophy case, holding \(contents)."
    }

    static let attic = """
        This is the attic. The only exit is a stairway leading down.
        """

    static let rope = "A large coil of rope is lying in the corner."

    static let knife = "On a table is a nasty-looking knife."

    static let cellar = """
        You are in a dark and damp cellar with a narrow passageway leading
        north, and a crawlway to the south. On the west is the bottom of a
        steep metal ramp which is unclimbable.
        """
}
