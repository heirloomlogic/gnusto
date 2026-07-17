/// Original Zork I prose for the maze region (``ZorkMaze``): the twisting passages
/// and dead ends, the dead adventurer's remains in Maze-5, the Grating Room, and
/// the Cyclops Room with its stair up to the Treasure Room and the Strange
/// Passage home. Also the host-wired seams' lines (the grating opening from
/// below, the nailed door, and the cyclops's feeding). Text transcribed verbatim
/// from the MIT-licensed Zork I source (see THIRD_PARTY_NOTICES at the repo
/// root). See `Prose.swift` for the names-vs-prose ledger rule.
extension Prose {
    // MARK: - Rooms

    /// The shared description every maze passage shows — the sameness is the
    /// whole point.
    static let maze = """
        This is part of a maze of twisty little passages, all alike.
        """

    /// Maze-5 adds the dead adventurer to the same description.
    static let maze5 = """
        This is part of a maze of twisty little passages, all alike. A skeleton,
        probably the remains of a luckless adventurer, lies here.
        """

    static let deadEnd = """
        You have come to a dead end in the maze.
        """

    static let gratingRoom = """
        You are in a small room near the maze. There are twisty passages in the
        immediate vicinity.
        """

    static let cyclopsRoom = """
        This room has an exit on the northwest, and a staircase leading up.
        """

    static let treasureRoom = """
        This is a large room, whose east wall is solid granite. A number of
        discarded bags, which crumble at your touch, are scattered about on the
        floor. There is an exit down a staircase.
        """

    static let strangePassage = """
        This is a long passage. To the west is one entrance. On the east there is
        an old wooden door, with a large opening in it (about cyclops sized).
        """

    // MARK: - The cyclops

    static let cyclops = """
        A hungry cyclops is standing at the foot of the stairs.
        """

    static let cyclopsPresence = """
        A cyclops, who looks prepared to eat horses (much less mere adventurers),
        blocks the staircase. From his state of health, and the bloodstains on the
        walls, you gather that he is not very friendly, though he likes people.
        """

    static let cyclopsBlocksStairs = "The cyclops doesn't look like he'll let you past."

    static let eastWallSolid = "The east wall is solid rock."

    static let cyclopsFlees = """
        The cyclops, hearing the name of his father's deadly nemesis, flees the
        room by knocking down the wall on the east of the room.
        """

    static let cyclopsAlreadyGone = "Wasn't he a sailor?"

    static let cyclopsShrugsOffAttack = """
        The cyclops shrugs but otherwise ignores your pitiful attempt.
        """

    /// The escalating menace shown once his hunger is roused — the original's
    /// `CYCLOMAD` table, one line per rising turn of `CYCLOWRATH`.
    static let cyclomad = [
        "The cyclops seems somewhat agitated.",
        "The cyclops appears to be getting more agitated.",
        "The cyclops is moving about the room, looking for something.",
        """
        The cyclops was looking for salt and pepper. No doubt they are
        condiments for his upcoming snack.
        """,
        "The cyclops is moving toward you in an unfriendly manner.",
        "You have two choices: 1. Leave  2. Become dinner.",
    ]

    static let cyclopsEatsYou = """
        The cyclops, tired of all of your games and trickery, grabs you firmly.
        As he licks his chops, he says "Mmm. Just like Mom used to make 'em."
        It's nice to be appreciated.
        """

    // MARK: - The maze's finds

    static let skeleton = """
        The bones of some earlier, less fortunate adventurer. There is nothing
        here for you but a lesson.
        """

    static let skeletonLeaveItBe = """
        A ghost appears in the room and is appalled at your desecration of the
        remains of a fellow adventurer. He casts a curse on your valuables and
        banishes them to the Land of the Living Dead. The ghost leaves, muttering
        obscenities.
        """

    static let bagOfCoins = "There are lots of coins in there."

    static let bagOfCoinsFirstSight = "An old leather bag, bulging with coins, is here."

    static let silverChalice = "It looks pretty much like a chalice."

    static let silverChaliceFirstSight = "There is a silver chalice, intricately engraved, here."

    static let rustyKnife = "Beside the skeleton is a rusty knife."

    static let rustyKnifeFirstSight = "Beside the skeleton is a rusty knife."

    static let burnedOutLantern = "The deceased adventurer's useless lantern is here."

    static let burnedOutLanternFirstSight = "The deceased adventurer's useless lantern is here."

    // MARK: - Host-wired seams

    /// Opening the grating from below (see ``Zork1``'s grating rule).
    static let gratingOpensFromBelow = """
        The grating opens to reveal trees above you. A pile of leaves falls onto
        your head and to the ground.
        """

    /// The Living Room's west door before the cyclops smashes it open.
    static let doorNailedShut = "The door is nailed shut."

    // MARK: - Feeding the cyclops (host-wired — the food is a ``ZorkHouse`` item)

    static let cyclopsEatsLunch = """
        The cyclops says "Mmm Mmm. I love hot peppers! But oh, could I use a drink.
        Perhaps I could drink the blood of that thing."  From the gleam in his eye,
        it could be surmised that you are "that thing".
        """

    static let cyclopsDrinksAndSleeps = """
        The cyclops takes the bottle, checks that it's open, and drinks the water.
        A moment later, he lets out a yawn that nearly blows you over, and then
        falls fast asleep (what did you put in that drink, anyway?).
        """

    static let cyclopsNotThirsty = "The cyclops apparently is not thirsty and refuses your generous offer."

    static let cyclopsWontEatThat = "The cyclops is not so stupid as to eat THAT!"
}
