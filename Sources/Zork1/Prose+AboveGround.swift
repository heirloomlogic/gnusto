/// Original Zork I prose for the above-ground region (``ZorkAboveGround``):
/// the White House exterior, the forest and clearings, and the canyon.
/// Transcribed from the MIT-licensed historical Zork source — see
/// `THIRD_PARTY_NOTICES` at the repo root.
extension Prose {
    // MARK: - AboveGround: house exterior

    static let westOfHouse = """
        You are standing in an open field west of a white house, with a
        boarded front door.
        """

    static let northOfHouse = """
        You are facing the north side of a white house. There is no door
        here, and all the windows are boarded up. To the north a narrow
        path winds through the trees.
        """

    static let southOfHouse = """
        You are facing the south side of a white house. There is no door
        here, and all the windows are boarded.
        """

    static let behindHouse = """
        You are behind the white house. A path leads into the forest to
        the east. In one corner of the house there is a small window which
        is slightly ajar.
        """

    static let whiteHouse = """
        The house is a beautiful colonial house which is painted white. It
        is clear that the owners must have been extremely wealthy.
        """

    static let frontDoor = """
        A heavy oak door, planked over from the inside. It hasn't opened
        in a long time.
        """

    static let frontDoorRefusal = "The door cannot be opened."

    static let mailbox = "A small mailbox, its flag long since rusted in place."

    static let mailboxEmbellishment = "A leaflet sits inside, waiting to be read."

    static let leaflet = """
        "WELCOME TO ZORK!

        ZORK is a game of adventure, danger, and low cunning. In it you
        will explore some of the most amazing territory ever seen by
        mortals. No computer should be without one!"
        """

    // MARK: - AboveGround: forest & clearings

    static let forestWest = """
        This is a forest, with trees in all directions. To the east, there
        appears to be sunlight.
        """

    static let forestEast = """
        This is a dimly lit forest, with large trees all around.
        """

    static let forestNortheast = """
        This is a dimly lit forest, with large trees all around.
        """

    static let forestPath = """
        This is a path winding through a dimly lit forest. The path heads
        north-south here. One particularly large tree with some low
        branches stands at the edge of the path.
        """

    static let tree = """
        A tall, gnarled tree with branches low enough to reach. Something
        pale is tucked into a nest high up among the leaves.
        """

    static let upATree = """
        You are about 10 feet above the ground nestled among some large
        branches. The nearest branch above you is above your reach.
        """

    static let nest = "Beside you on the branch is a small bird's nest."

    static let egg = """
        In the bird's nest is a large egg encrusted with precious jewels,
        apparently scavenged by a childless songbird. The egg is covered
        with fine gold inlay, and ornamented in lapis lazuli and
        mother-of-pearl. Unlike most eggs, this one is hinged and closed
        with a delicate looking clasp. The egg appears extremely fragile.
        """

    static let canary = """
        There is a golden clockwork canary nestled in the egg. It has ruby
        eyes and a silver beak. Through a crystal window below its left
        wing you can see intricate machinery inside. It appears to have
        wound down.
        """

    static let brokenCanary = """
        There is a golden clockwork canary nestled in the egg. It seems to
        have recently had a bad experience. The mountings for its jewel-like
        eyes are empty, and its silver beak is crumpled. Through a cracked
        crystal window below its left wing you can see the remains of
        intricate machinery. It is not clear what result winding it would
        have, as the mainspring seems sprung.
        """

    static let eggForcedRuinsCanary = """
        The egg is now open, but the clumsiness of your attempt has
        seriously compromised its esthetic appeal.
        """

    static let bauble = """
        A small brass bauble, beautifully worked, that catches the light with
        a warm glow. It is the sort of trinket a songbird might treasure.
        """

    static let songbirdDropsBauble = """
        The canary chirps, slightly off-key, an aria from a forgotten opera.
        From out of the greenery flies a lovely songbird. It perches on a
        limb just over your head and opens its beak to sing. As it does so
        a beautiful brass bauble drops from its mouth, bounces off the top
        of your head, and lands glimmering in the grass. As the canary winds
        down, the songbird flies away.
        """

    static let canaryChirps = """
        The canary chirps blithely, if somewhat tinnily, for a short time.
        """

    static let brokenCanaryWinds = """
        There is an unpleasant grinding noise from inside the canary.
        """

    static let clearingGrating = """
        You are in a clearing, with a forest surrounding you on all sides.
        A path leads south.
        """

    static let leaves = """
        On the ground is a pile of leaves.
        """

    static let leavesMoveEmbellishment = "In disturbing the pile of leaves, a grating is revealed."

    static let leavesAlreadyMoved = "The leaves have already been pushed aside."

    static let grating = """
        A sturdy iron grating, set into the ground and fastened with a
        heavy lock. Cool air drifts up from whatever lies beneath it.
        """

    static let clearingEast = """
        You are in a small clearing in a well marked forest path that
        extends to the east and west.
        """

    // MARK: - AboveGround: canyon

    static let canyonView = """
        You are at the top of the Great Canyon on its west wall. From here
        there is a marvelous view of the canyon and parts of the Frigid
        River upstream. Across the canyon, the walls of the White Cliffs
        join the mighty ramparts of the Flathead Mountains to the east.
        Following the Canyon upstream to the north, Aragain Falls may be
        seen, complete with rainbow. The mighty Frigid River flows out from
        a great dark cavern. To the west and south can be seen an immense
        forest, stretching for miles around. A path leads northwest. It is
        possible to climb down into the canyon from here.
        """

    static let rockyLedge = """
        You are on a ledge about halfway up the wall of the river canyon.
        You can see from here that the main flow from Aragain Falls twists
        along a passage which it is impossible for you to enter. Below you
        is the canyon bottom. Above you is more cliff, which appears
        climbable.
        """

    static let canyonBottom = """
        You are beneath the walls of the river canyon which may be climbable
        here. The lesser part of the runoff of Aragain Falls flows by below.
        To the north is a narrow path.
        """

    static let endOfRainbow = """
        You are on a small, rocky beach on the continuation of the Frigid
        River past the Falls. The beach is narrow due to the presence of
        the White Cliffs. The river canyon opens here and sunlight shines
        in from above. A rainbow crosses over the falls to the east and a
        narrow path continues to the southwest.
        """

    // MARK: - AboveGround: endgame

    static let ancientMap = """
        The map shows a forest with three clearings. The largest clearing
        contains a house. Three paths leave the large clearing. One of
        these paths, leading southwest, is marked "To Stone Barrow".
        """

    static let ancientMapAppears = """
        An almost inaudible voice whispers in your ear, "Look to your
        treasures for the final secret."
        """

    static let stoneBarrow = """
        You are standing in front of a massive barrow of stone. In the east
        face is a huge stone door which is open. You cannot see into the
        dark of the tomb.
        """

    /// The final room's own description. In normal play it is never rendered —
    /// the host's `onEnter` win throws before the room is auto-described, and
    /// ``stoneBarrowEpilogue`` stands in — but a room needs a description, and
    /// this is what the tomb interior looks like the instant before the door
    /// seals behind you.
    static let insideBarrow = """
        This is the inside of the great barrow. It is dark, but ahead lies an
        enormous cavern, brightly lit, into which the way leads on.
        """

    static let stoneBarrowEpilogue = """
        As you enter the barrow, the door closes inexorably behind you.
        Around you it is dark, but ahead is an enormous cavern, brightly
        lit. Through its center runs a wide stream. Spanning the stream is a
        small wooden footbridge, and beyond a path leads into a dark tunnel.
        Above the bridge, floating in the air, is a large sign. It reads:
        All ye who stand before this bridge have completed a great and
        perilous adventure which has tested your wit and courage. You have
        mastered ZORK: The Great Underground Empire.
        """

    static let barrowPathBlocked = """
        There is no path southwest from here — only the forest, and the
        house at your back.
        """
}
