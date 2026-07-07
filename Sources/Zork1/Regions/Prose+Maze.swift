/// Placeholder prose for the maze region (``ZorkMaze``): the twisting passages
/// and dead ends, the dead adventurer's remains in Maze-5, the Grating Room, and
/// the Cyclops Room with its stair up to the Treasure Room and the Strange
/// Passage home. Also the host-wired seams' lines (the grating opening from
/// below, the nailed door, and the cyclops's feeding). Original text; the
/// verbatim Infocom descriptions arrive later, one constant at a time. See
/// `Prose.swift` for the names-vs-prose ledger rule.
extension Prose {
    // MARK: - Rooms

    /// The shared description every maze passage shows — the sameness is the
    /// whole point.
    static let maze = """
        This is part of a maze of twisting passages, all alike. Openings lead off
        in several directions, and you have already lost track of which way you
        came in.
        """

    /// Maze-5 adds the dead adventurer to the same description.
    static let maze5 = """
        This is part of a maze of twisting passages, all alike. The skeleton of a
        luckless adventurer who came this way before you lies sprawled against one
        wall, picked clean and long past helping.
        """

    static let deadEnd = """
        You have come to a dead end in the maze. The only way on is the way you
        came.
        """

    static let gratingRoom = """
        This is a small room near the maze's edge. A grating is set into the
        ceiling overhead, and a passage leads off to the southwest.
        """

    static let cyclopsRoom = """
        This room has a forbidding air about it. An opening leads off to the
        northwest, and a broad staircase climbs into the dark above.
        """

    static let treasureRoom = """
        This is a large chamber whose east wall is solid granite. Discarded bags,
        crumbling at a touch, are strewn across the floor, and a staircase leads
        back down.
        """

    static let strangePassage = """
        This is a long passage. One entrance stands at the west end; at the east
        is a heavy wooden door with an opening in it about the size of a cyclops.
        """

    // MARK: - The cyclops

    static let cyclops = """
        The cyclops is a mountain of muscle and appetite, with a single
        bloodshot eye and a jaw built for grinding bones. He is eyeing you the
        way a starving man eyes a roast.
        """

    static let cyclopsPresence = "A hungry cyclops blocks the foot of the staircase."

    static let cyclopsBlocksStairs = "The cyclops doesn't look like he'll let you past."

    static let eastWallSolid = "The east wall is solid rock."

    static let cyclopsFlees = """
        The cyclops, hearing the name of his father's deadly nemesis, bellows in
        terror and flees the room — straight through the east wall, which gives
        way before him in a shower of rock and dust.
        """

    static let cyclopsAlreadyGone = "The cyclops is beyond reach now — you've already dealt with him."

    static let cyclopsShrugsOffAttack = """
        The cyclops shrugs off your pitiful attack and goes on watching you,
        licking his lips.
        """

    // MARK: - The maze's finds

    static let skeleton = """
        The bones of some earlier, less fortunate adventurer. There is nothing
        here for you but a lesson.
        """

    static let skeletonLeaveItBe = "Grave-robbing the dead is beneath even you. Leave the bones be."

    static let bagOfCoins = "An old leather bag, cracked with age and bulging with coins."

    static let bagOfCoinsFirstSight = "An old leather bag, bulging with coins, lies among the bones."

    static let rustyKnife = "A wicked-looking knife, its blade eaten through with rust."

    static let rustyKnifeFirstSight = "Beside the skeleton lies a rusty knife."

    static let burnedOutLantern = "The dead adventurer's lantern, burned out and useless."

    static let burnedOutLanternFirstSight = "The deceased adventurer's useless lantern lies nearby."

    // MARK: - Host-wired seams

    /// Opening the grating from below (see ``Zork1``'s grating rule).
    static let gratingOpensFromBelow = """
        The grating swings open, and a shower of dead leaves rains down onto your
        head from the forest above. Daylight — and a way out — pours in through
        the opening.
        """

    /// The Living Room's west door before the cyclops smashes it open.
    static let doorNailedShut = "The door is nailed shut."

    // MARK: - Feeding the cyclops (host-wired — the food is a ``ZorkHouse`` item)

    static let cyclopsEatsLunch = """
        The cyclops wolfs down the lunch in a single gulp, smacks his lips, and
        rumbles: "Tasty — but now I could murder a drink."
        """

    static let cyclopsDrinksAndSleeps = """
        The cyclops drains the bottle dry, lets out a yawn that nearly knocks you
        flat, and slumps to the floor, fast asleep. The staircase is clear.
        """

    static let cyclopsNotThirsty = "The cyclops isn't thirsty yet — he'd sooner eat than drink."

    static let cyclopsWontEatThat = "The cyclops sniffs at your offering and turns up his nose. That's not food."
}
