/// Original Zork I prose for the house interior (``ZorkHouse``): kitchen,
/// living room, attic, and the cellar the trap door drops into, plus the
/// lantern's fuel-state lines. Transcribed from the MIT-licensed historical
/// Zork source — see `THIRD_PARTY_NOTICES` at the repo root.
extension Prose {
    // MARK: - House: interior

    /// `KITCHEN-FCN` (`1actions.zil:389-397`) ends this paragraph with a branch
    /// on the window's `OPENBIT`, and only the shut half had been reproduced —
    /// so the room called the window ajar to a player who had climbed through
    /// it. One function rather than two constants, because the source branches
    /// one clause and not the paragraph.
    ///
    /// - Parameter windowOpen: whether the window stands open.
    /// - Returns: the paragraph.
    static func kitchen(windowOpen: Bool) -> String {
        """
        You are in the kitchen of the white house. A table seems to have been
        used recently for the preparation of food. A passage leads to the west
        and a dark staircase can be seen leading upward. A dark chimney leads
        down and to the east is a small window which is
        \(windowOpen ? "open." : "slightly ajar.")
        """
    }

    /// `KITCHEN-WINDOW-F` (`1actions.zil:246-266`) prints this only while
    /// `KITCHEN-WINDOW-FLAG` is clear — that is, until the player has opened or
    /// closed the window — and falls through to `V-EXAMINE`'s stock line
    /// afterwards. The flag is approximated here by the window's own open
    /// state, which is the state the sentence is a claim about: a window you
    /// have opened and climbed through is not one that will not admit you.
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
        With a great effort, the rug is moved to one side of the room,
        revealing the dusty cover of a closed trap door.
        """

    static let rugAlreadyMoved = """
        Having moved the carpet previously, you find it impossible to move
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

    // MARK: - House: (#407) scenery examine lines

    static let kitchenTable = """
        A sturdy kitchen table, dusted with flour and marked with knife
        scores.
        """

    static let kitchenStaircase = """
        A dark staircase, climbing up out of the kitchen's light.
        """

    static let kitchenPassage = """
        A passage leading west, toward the front of the house.
        """

    static let kitchenChimney = """
        A dark chimney leading down — the flue from the fireplace above.
        Too narrow to climb back up.
        """

    static let livingRoomDoorway = """
        A doorway opening east, into the kitchen.
        """

    static let livingRoomDoor = """
        A wooden door, with strange gothic lettering on it. It appears to
        be nailed shut.
        """

    static let gothicLettering = """
        Strange gothic lettering, in a language you cannot read — though
        the letters look old, and somehow important.
        """

    static let atticStairway = """
        The stairway down to the kitchen, the attic's only way out.
        """

    static let cellarPassageway = """
        A narrow passageway leading north, into darkness.
        """

    static let cellarCrawlway = """
        A crawlway to the south, low enough to walk through bent double.
        """

    static let cellarRamp = """
        The bottom of a steep metal ramp, rising up out of reach. It
        cannot be climbed.
        """
}
