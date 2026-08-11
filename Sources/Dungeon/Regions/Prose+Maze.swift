/// Prose for the great maze and what it opens onto (``DungeonMaze``): fifteen
/// identical twisting passages, four dead ends, the dead adventurer in Maze-5,
/// the Grating Room under the forest Clearing, the Cyclops Room, the Treasure
/// Room above it, and the Strange Passage the fleeing cyclops opens back to the
/// Living Room.
///
/// The three-way rule (trilogy verbatim / trilogy adapted / written fresh) is
/// stated once on ``Prose``; each constant below says which of the three it is.
///
/// The maze is the one region where the trilogy's *words* survive almost whole
/// and its *map* does not — the passages read the same in both and connect
/// differently in six places — so most of what follows is trilogy verbatim and
/// the adaptations are all compass points: the cyclops leaves by the **north**
/// wall rather than the east, the Strange Passage's one entrance is to the
/// **south**, and the Treasure Room's granite wall is its **north** one,
/// because its east wall is the door into the Royal Puzzle.
extension Prose {
    // MARK: - The maze proper

    /// Trilogy verbatim (`identical`). The sameness is the puzzle.
    static let maze = """
        This is part of a maze of twisty little passages, all alike.
        """

    /// Trilogy verbatim (`substantial`, and the difference is the skeleton
    /// sentence the trilogy folds into the room). Maze-5 is where the last
    /// adventurer stopped.
    static let maze5 = """
        This is part of a maze of twisty little passages, all alike. A skeleton,
        probably the remains of a luckless adventurer, lies here.
        """

    /// Trilogy verbatim (`substantial`). The mainframe's own line for these
    /// four rooms is the two-word room name repeated into the description
    /// slot, which is a source slip rather than a design; the trilogy wrote the
    /// sentence the slip was meant to be.
    static let deadEnd = """
        You have come to a dead end in the maze.
        """

    /// Written fresh.
    static let mazeWalls = """
        Twisting passages, all of them alike, and none of them telling you
        anything.
        """

    /// Written fresh.
    static let deadEndWalls = """
        The passage stops. There is nothing here but the rock it stops against.
        """

    // MARK: - The Grating Room

    /// Trilogy verbatim. The grating's own line follows from the three below.
    static let gratingRoom = """
        You are in a small room near the maze. There are twisty passages in the
        immediate vicinity.
        """

    /// Trilogy verbatim.
    static let gratingAboveOpen = """
        Above you is an open grating with sunlight pouring in.
        """

    /// Trilogy verbatim.
    static let gratingAboveUnlocked = "Above you is a grating."

    /// Trilogy verbatim.
    static let gratingAboveLocked = """
        Above you is a grating locked with a skull-and-crossbones lock.
        """

    /// Trilogy verbatim.
    static let gratingUnlocked = "The grate is unlocked."

    /// Trilogy verbatim.
    static let gratingOpensFromBelow = """
        The grating opens to reveal trees above you.
        """

    /// Trilogy verbatim.
    static let gratingOpensFromAbove = "The grating opens."

    /// Trilogy verbatim.
    static let gratingCloses = "The grating is closed."

    // MARK: - The maze's finds

    /// Trilogy verbatim.
    static let skeleton = """
        The bones of some earlier, less fortunate adventurer. There is nothing
        here for you but a lesson.
        """

    /// Trilogy verbatim.
    static let skeletonCurse = """
        A ghost appears in the room and is appalled at your desecration of the
        remains of a fellow adventurer. He casts a curse on your valuables and
        banishes them to the Land of the Living Dead. The ghost leaves, muttering
        obscenities.
        """

    /// Trilogy verbatim.
    static let bagOfCoins = "There are lots of coins in there."

    /// Trilogy verbatim.
    static let bagOfCoinsInPlace = "An old leather bag, bulging with coins, is here."

    /// Written fresh. The trilogy's examine text is its listing line over
    /// again, which stops being true the moment the knife is in your hand.
    ///
    /// It used to call the knife "older than anything else you are carrying",
    /// which the elvish sword — "of great antiquity", "old enough to have
    /// opinions" — makes false in the one frame the game itself stages: taking
    /// the knife with the sword in hand is what fires ``rustyKnifeBluePulse``.
    /// The coffin, the trident and the egg make it false too, so the repair is
    /// to stop comparing rather than to branch on one of them. Age is the
    /// knife's own property now. (#233)
    static let rustyKnife = """
        A long knife, pitted with rust and old past guessing. It sits badly in
        the hand.
        """

    /// Trilogy verbatim.
    static let rustyKnifeInPlace = "Beside the skeleton is a rusty knife."

    /// Trilogy verbatim.
    static let rustyKnifeBluePulse = """
        As you pick up the rusty knife, your sword gives a single pulse of
        blinding blue light.
        """

    /// Written fresh. The knife is haunted, and swinging it is the last thing
    /// its owner did too.
    static let rustyKnifeTurns = """
        As the knife leaves your hand it twists round and buries itself in you,
        which is very likely what happened to the last owner as well.
        """

    /// Trilogy verbatim. One line does for the listing and the examine both,
    /// because in the trilogy they are the same line.
    static let burnedOutLantern = "The deceased adventurer's useless lantern is here."

    /// Written fresh.
    static let skeletonKeys = """
        A ring of thin, bent keys, of the sort that opens locks it was never
        cut for.
        """

    /// Written fresh.
    static let skeletonKeysInPlace = "There is a set of skeleton keys here."

    // MARK: - The Cyclops Room

    /// Trilogy adapted. The trilogy's exit out of this room is northwest and
    /// its cyclops leaves by the east wall; here the exit is **west** and the
    /// wall he goes through is the **north** one.
    static let cyclopsRoom = """
        This room has an exit on the west side, and a staircase leading up.
        """

    /// Trilogy adapted — the hole is in the north wall here.
    static let cyclopsHoleInWall = """
        The north wall, previously solid, now has a cyclops-sized opening in it.
        """

    /// Trilogy verbatim.
    static let cyclopsAsleep = """
        The cyclops is sleeping blissfully at the foot of the stairs.
        """

    /// Trilogy verbatim.
    static let cyclopsBlocksStairs = """
        A cyclops, who looks prepared to eat horses (much less mere adventurers),
        blocks the staircase. From his state of health, and the bloodstains on
        the walls, you gather that he is not very friendly, though he likes
        people.
        """

    /// Trilogy verbatim.
    static let cyclopsEyeingYou = """
        The cyclops is standing in the corner, eyeing you closely. I don't think
        he likes you very much. He looks extremely hungry, even for a cyclops.
        """

    /// Trilogy verbatim.
    static let cyclopsGasping = """
        The cyclops, having eaten the hot peppers, appears to be gasping. His
        enflamed tongue protrudes from his man-sized mouth.
        """

    /// Trilogy adapted — north, not east.
    static let cyclopsWontLetYouPast = "The cyclops doesn't look like he'll let you past."

    /// Trilogy adapted — the wall he has not yet gone through is the north one.
    static let northWallSolid = "The north wall is solid rock."

    /// Written fresh — the same wall, looked at rather than walked into.
    static let northWallExamined = """
        Solid rock, and a good deal of it. Nothing is getting through that.
        """

    /// Written fresh — and the same wall once something has.
    static let northWallBroken = """
        A hole in the rock the size and shape of a departing cyclops. Beyond it
        a passage runs away north.
        """

    /// Written fresh. They are not the cyclops's, and he is in no hurry to say
    /// whose they are.
    static let cyclopsBloodstains = """
        Dried, dark, and at about the height of a person's throat.
        """

    /// Trilogy adapted — he knocks down the **north** wall.
    static let cyclopsFlees = """
        The cyclops, hearing the name of his father's deadly nemesis, flees the
        room by knocking down the wall on the north of the room.
        """

    /// Trilogy verbatim.
    static let odysseusElsewhere = "Wasn't he a sailor?"

    /// Written fresh.
    static let cyclopsShrugsOffAttack = """
        The cyclops ignores all injury to his body with a shrug.
        """

    /// Written fresh.
    static let cyclopsStaircase = """
        A broad stone staircase going up, and a cyclops in front of it more
        often than not.
        """

    /// Trilogy verbatim.
    static let cyclopsWakes = """
        The cyclops yawns and stares at the thing that woke him up.
        """

    /// Trilogy verbatim.
    static let cyclopsGrabbed = "The cyclops doesn't take kindly to being grabbed."

    /// Trilogy verbatim.
    static let cyclopsTied = """
        You cannot tie the cyclops, though he is fit to be tied.
        """

    /// Trilogy verbatim.
    static let cyclopsStomach = "You can hear his stomach rumbling."

    /// Written fresh, for ``Prose/trollGreeted``'s reason: the source has no
    /// `HELLO` branch for the cyclops, so he falls to `V-HELLO`'s villain bow,
    /// and the engine's placeholder is the same courtesy flattened. A giant
    /// waiting for you to be lunch does not exchange greetings.
    static let cyclopsGreeted = """
        The cyclops looks at you the way a man looks at a small meal.
        """

    /// Asleep at the foot of the stairs, which is the only other state he can
    /// be greeted in — once he goes through the wall he is gone from the room.
    static let cyclopsGreetedAsleep = """
        The cyclops sleeps on. It would be a poor idea to wake him for this.
        """

    /// Trilogy verbatim — the mainframe's `CYCLOMAD`, one line per rising turn.
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

    /// Trilogy verbatim.
    static let cyclopsEatsYou = """
        The cyclops, tired of all of your games and trickery, grabs you firmly.
        As he licks his chops, he says "Mmm. Just like Mom used to make 'em."
        It's nice to be appreciated.
        """

    /// Trilogy verbatim — feeding him the lunch (host-wired; the food is a
    /// ``DungeonHouse`` item).
    static let cyclopsEatsLunch = """
        The cyclops says "Mmm Mmm. I love hot peppers! But oh, could I use a
        drink. Perhaps I could drink the blood of that thing." From the gleam in
        his eye, it could be surmised that you are "that thing".
        """

    /// Trilogy verbatim.
    static let cyclopsDrinksAndSleeps = """
        The cyclops takes the bottle, checks that it's open, and drinks the
        water. A moment later, he lets out a yawn that nearly blows you over, and
        then falls fast asleep (what did you put in that drink, anyway?).
        """

    /// Trilogy verbatim.
    static let cyclopsNotThirsty = """
        The cyclops apparently is not thirsty and refuses your generosity.
        """

    /// Trilogy verbatim.
    static let cyclopsWontEatThat = "The cyclops is not so stupid as to eat THAT!"

    /// Written fresh — the garlic is beneath even a starving cyclops.
    static let cyclopsWontEatGarlic = """
        The cyclops may be hungry, but there is a limit.
        """

    // MARK: - The Treasure Room

    /// Trilogy adapted (`minor`, and the bucket is wrong about it). The
    /// trilogy's granite wall is the **east** one and its only exit is down;
    /// here the granite is **north**, because the east wall is the passage
    /// somebody has recently cut into the Royal Puzzle.
    static let treasureRoom = """
        This is a large room, whose north wall is solid granite. A number of
        discarded bags, which crumble at your touch, are scattered about on the
        floor. There is an exit down, and what appears to be a newly created
        passage to the east.
        """

    /// Written fresh.
    static let treasureRoomBags = """
        The bags are old past mending, and they crumble at a touch. Whatever was
        in them went elsewhere long ago.
        """

    /// Trilogy verbatim.
    static let chalice = "It looks pretty much like a chalice."

    /// Trilogy verbatim.
    static let chaliceInPlace = "There is a silver chalice, intricately engraved, here."

    /// Written fresh — mainframe-only. The two rooms that share a granite wall
    /// share rather more than that.
    static let graniteWallCarriesYou = """
        The granite wall shivers, and for a moment there is nothing between you
        and the room on the other side of it.
        """

    /// Written fresh — mainframe-only. The magic word said anywhere the
    /// granite wall is not.
    static let graniteWordInert = "Nothing happens."

    // MARK: - The Strange Passage

    /// Trilogy adapted (`minor`, exits again). The trilogy's entrance is west;
    /// here it is south, back into the Cyclops Room.
    static let strangePassage = """
        This is a long passage. To the south is one entrance. On the east there
        is an old wooden door, with a large hole in it (about cyclops sized).
        """

    /// Written fresh.
    static let strangePassageWalls = """
        A long passage, cut by somebody in a hurry and cut a very long time ago.
        """

    /// Written fresh.
    static let cyclopsSizedHole = """
        A hole in an old wooden door, roughly the shape of a cyclops who did not
        stop to open it.
        """
}
