/// Prose for the above-ground region (``DungeonAboveGround``): the white house
/// exterior, the forest and its clearing, and the Great Canyon.
///
/// The three-way rule — verbatim trilogy, adapted trilogy, or freshly written —
/// is stated once on ``Prose``. Each line below is marked where which of the
/// three it is would not otherwise be obvious.
extension Prose {
    // MARK: - The house exterior

    /// Verbatim Zork I. The mainframe's West of House has the same four exits
    /// the trilogy's does, so nothing needed fixing.
    static let westOfHouse = """
        You are standing in an open field west of a white house, with a
        boarded front door.
        """

    /// Adapted. The trilogy ends "To the north a narrow path winds through the
    /// trees" — but the mainframe has no Forest Path: north of here is plain
    /// forest, with the climbable tree standing in it. The windows are *barred*
    /// rather than boarded, here and at the south side both, which is the
    /// mainframe's fact.
    static let northOfHouse = """
        You are facing the north side of a white house. There is no door here,
        and all the windows are barred. North of you the forest begins.
        """

    /// Adapted from the trilogy's near-identical line — "barred", as at the
    /// north side, and the forest lies south.
    static let southOfHouse = """
        You are facing the south side of a white house. There is no door here,
        and all the windows are barred. A path leads south into the trees.
        """

    /// Adapted. The trilogy's path east "into the forest" runs into a forest
    /// room; the mainframe's runs into the Clearing, so the sentence names what
    /// is actually there. The window clause is the trilogy's, unchanged.
    static let behindHouse = """
        You are behind the white house. A path leads east through the trees
        toward a clearing. In one corner of the house there is a small window
        which is slightly ajar.
        """

    /// Verbatim Zork I.
    static let whiteHouse = """
        The house is a beautiful colonial house which is painted white. It
        is clear that the owners must have been extremely wealthy.
        """

    static let frontDoor = """
        A heavy oak door, planked over from the inside. It has not opened in a
        long time, and there is evidently no key.
        """

    /// One line for two jobs, as in the mainframe: it is both West of House's
    /// blocked east exit and the answer to `open front door`.
    static let frontDoorRefusal = "The door is locked, and there is evidently no key."

    static let barredWindows = "The windows are all barred."

    static let mailboxInPlace = "There is a small mailbox here."

    static let mailbox = "A small mailbox, its flag long since rusted in place."

    static let mailboxEmbellishment = "A leaflet sits inside, waiting to be read."

    /// Verbatim Zork I. The mainframe leaflet says the same thing at greater
    /// length and addresses a PDP-10; the trilogy's is the licensed one, and it
    /// contradicts nothing about this world.
    static let leaflet = """
        "WELCOME TO ZORK!

        ZORK is a game of adventure, danger, and low cunning. In it you
        will explore some of the most amazing territory ever seen by
        mortals. No computer should be without one!"
        """

    /// Written fresh, both of them. The welcome mat is mainframe-only — the
    /// trilogy dropped it — so the words here are this project's own.
    static let welcomeMatInPlace = """
        A rubber mat saying 'Welcome to Zork!' lies by the door.
        """

    static let welcomeMat = """
        A rubber mat, worn thin down its middle by boots that stopped coming.
        Across it, in letters once cheerful, is stamped: WELCOME TO ZORK.
        """

    // MARK: - The forest

    /// Written fresh. The mainframe's deep forest is a place you go round in:
    /// north and west of here are here again. The trilogy's Forest lines
    /// promise sunlight to the east, which is a promise this room cannot keep.
    static let forestDeep = """
        This is a forest, with trees standing close on every side. The light
        that reaches the ground is green and dim, and one direction looks very
        much like another.
        """

    /// Adapted from the trilogy's Forest. East of this one really is the
    /// Clearing, so the sunlight clause is true here and kept.
    static let forestSouth = """
        This is a dimly lit forest, with large trees all around. To the east,
        there appears to be sunlight.
        """

    /// Adapted from the trilogy's Forest Path — the mainframe has no path
    /// room, only forest with the great tree standing in it, so the path
    /// sentence goes and the tree stays.
    static let forestTree = """
        This is a dimly lit forest, with large trees all around. One
        particularly large tree, with branches low enough to reach, stands
        here.
        """

    /// Written fresh — mainframe-only room. East of here the ground falls
    /// away into the Great Canyon.
    static let forestCanyonEdge = """
        This is a large forest. The trees shut out every view but the one
        eastward, where the ground gives out and the light opens up.
        """

    /// Written fresh — mainframe-only room.
    static let forestNorth = """
        This is a forest, with trees in every direction. Somewhere to the
        southeast the trees thin and the ground begins to fall away.
        """

    static let forestTrees = """
        Tall trees, close-grown, with nothing about them worth a second look.
        """

    static let noTreeToClimb = "There is no tree here suitable for climbing."

    static let greatTree = """
        A tall, gnarled tree with branches low enough to reach. Something pale
        is tucked into a nest high up among the leaves.
        """

    /// Verbatim Zork I — the perch is the same perch in both games.
    static let upATree = """
        You are about 10 feet above the ground nestled among some large
        branches. The nearest branch above you is above your reach.
        """

    static let cannotClimbHigher = "You cannot climb any higher."

    static let nest = "Beside you on the branch is a small bird's nest."

    /// Verbatim Zork I.
    static let egg = """
        In the bird's nest is a large egg encrusted with precious jewels,
        apparently scavenged by a childless songbird. The egg is covered
        with fine gold inlay, and ornamented in lapis lazuli and
        mother-of-pearl. Unlike most eggs, this one is hinged and closed
        with a delicate looking clasp. The egg appears extremely fragile.
        """

    /// Verbatim Zork I.
    static let canary = """
        There is a golden clockwork canary nestled in the egg. It has ruby
        eyes and a silver beak. Through a crystal window below its left
        wing you can see intricate machinery inside. It appears to have
        wound down.
        """

    /// Verbatim Zork I.
    static let brokenCanary = """
        There is a golden clockwork canary nestled in the egg. It seems to
        have recently had a bad experience. The mountings for its jewel-like
        eyes are empty, and its silver beak is crumpled. Through a cracked
        crystal window below its left wing you can see the remains of
        intricate machinery. It is not clear what result winding it would
        have, as the mainspring seems sprung.
        """

    /// Verbatim Zork I.
    static let eggForcedRuinsCanary = """
        The egg is now open, but the clumsiness of your attempt has
        seriously compromised its esthetic appeal.
        """

    static let bauble = """
        A small brass bauble, beautifully worked, that catches the light with
        a warm glow. It is the sort of trinket a songbird might treasure.
        """

    /// Verbatim Zork I. The mainframe pays the same trick — wind the canary
    /// anywhere among the trees and the songbird answers.
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

    static let songbirdHeard = """
        You hear in the distance the chirping of a song bird.
        """

    static let songbirdNotHere = """
        The songbird is not here, but is probably nearby.
        """

    // MARK: - The clearing

    /// Adapted. The trilogy's grating clearing says "A path leads south"; the
    /// mainframe's single clearing is the hub of the whole wood, and the way
    /// home is southwest.
    static let clearing = """
        You are in a clearing, with a forest surrounding you on all sides. A
        path leads southwest, back toward the house.
        """

    static let leaves = """
        On the ground is a pile of leaves.
        """

    static let leavesMoveEmbellishment = "In disturbing the pile of leaves, a grating is revealed."

    static let leavesAlreadyMoved = "The leaves have already been pushed aside."

    static let grating = """
        A sturdy iron grating, set into the ground and fastened with a heavy
        lock. Cool air drifts up from whatever lies beneath it.
        """

    /// The same grating, seen from the room it is the ceiling of. Milestone 4
    /// built that room, and the line above is written from the wrong side of
    /// it.
    static let gratingFromBelow = """
        A sturdy iron grating overhead, set into the roof of the room and
        fastened on this side with a heavy lock.
        """

    /// Trilogy verbatim — what the Clearing says once the leaves are off.
    static let gratingInClearing = """
        There is a grating securely fastened into the ground.
        """

    /// Trilogy verbatim — and once it is open.
    static let gratingOpenInClearing = """
        There is an open grating, descending into darkness.
        """

    static let gratingLocked = "The grating is locked."

    /// The grating has no keyhole on the forest side; the lock is underneath.
    static let gratingLockNotReachable = """
        You cannot reach the lock from up here.
        """

    // MARK: - The Great Canyon

    /// Adapted. The trilogy stands its Canyon View on the canyon's *west* wall
    /// and leads a path northwest; the mainframe stands on the **south** wall,
    /// with the forest west and south and nothing but the climb down. The
    /// characterful middle — the falls, the rainbow, the dam far off — is the
    /// mainframe's own geography and is kept.
    static let canyonView = """
        You are at the top of the Great Canyon on its south wall. From here
        there is a marvelous view of the canyon and parts of the Frigid River
        upstream. Across the canyon, the walls of the White Cliffs still seem
        to loom far above. Following the canyon upstream, Aragain Falls may be
        seen, complete with rainbow, and beyond it, very far north, the top of
        the Flood Control Dam. To the west and south lies an immense forest,
        stretching for miles around. It is possible to climb down into the
        canyon from here.
        """

    /// Verbatim Zork I, up and down between the same two rooms in both games.
    static let rockyLedge = """
        You are on a ledge about halfway up the wall of the river canyon.
        You can see from here that the main flow from Aragain Falls twists
        along a passage which it is impossible for you to enter. Below you
        is the canyon bottom. Above you is more cliff, which appears
        climbable.
        """

    /// Verbatim Zork I — the room and its two exits are the same in both. The
    /// path north reaches the End of Rainbow, which the river-and-rainbow
    /// milestone builds; the sentence stays, because a milestone does not get
    /// to edit the world to cover its own seams (`docs/games/dungeon.md`,
    /// "Seams between milestones").
    static let canyonBottom = """
        You are beneath the walls of the river canyon which may be climbable
        here. The lesser part of the runoff of Aragain Falls flows by below.
        To the north is a narrow path.
        """

    static let cliff = """
        Rough rock, split and shelved, offering hand-holds to anyone with the
        nerve to use them.
        """

    static let distantView = """
        Miles of it, and all of it too far off to make out more than the shape:
        white cliff, falling water, the colours of a rainbow standing in the
        spray, and beyond them the country going on and on.
        """

    static let canyonStream = """
        A shallow, quick stream — what is left of the falls by the time it
        reaches the bottom of the canyon.
        """
}
