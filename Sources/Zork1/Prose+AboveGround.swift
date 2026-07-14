/// Placeholder prose for the above-ground region (``ZorkAboveGround``): the
/// White House exterior, the forest and clearings, and the canyon. See
/// `Prose.swift` for the names-vs-prose ledger rule these all follow.
extension Prose {
    // MARK: - AboveGround: house exterior

    static let westOfHouse = """
        You stand on the west lawn of a white house, its front door boarded
        over and unwelcoming. A mailbox stands by the path. The lawn
        continues north and south, and a forest begins to the west.
        """

    static let northOfHouse = """
        You are at the north edge of the house's lawn, a bare stretch of
        wall with no doors or windows on this side. The lawn runs west and
        east around the house, and a worn path leads off into the trees to
        the north.
        """

    static let southOfHouse = """
        You are at the south edge of the house's lawn. Like the north
        side, this wall is blank. The lawn continues west and east around
        the house.
        """

    static let behindHouse = """
        You are in the small yard behind the house. A narrow window looks
        into the house here, its lower sash sitting unevenly in the frame.
        The yard opens north and south along the house, and a forest lies
        to the east.
        """

    static let whiteHouse = """
        The house is a plain two-story clapboard building, its paint
        peeling and its front door boarded shut. It looks as though nobody
        has used the front entrance in years.
        """

    static let frontDoor = """
        A heavy oak door, planked over from the inside. It hasn't opened
        in a long time.
        """

    static let frontDoorRefusal = "The door is boarded shut and won't budge."

    static let mailbox = "A small mailbox, its flag long since rusted in place."

    static let mailboxEmbellishment = "A leaflet sits inside, waiting to be read."

    static let leaflet = """
        A single typed page, the ink faded but legible: a welcome to
        visitors and a warning that treasure and danger both lie
        underground.
        """

    // MARK: - AboveGround: forest & clearings

    static let forestWest = """
        You are among close-set pines west of the house. The trees crowd
        in on every side; the lawn is visible back to the east, and a
        path winds north.
        """

    static let forestEast = """
        You are in a stretch of forest east of the house, the trees here
        a little sparser. The yard behind the house is west, a clearing
        opens north, and the ground slopes down toward a canyon to the
        east.
        """

    static let forestNortheast = """
        The forest continues here, a tangle of low branches and old
        leaves underfoot. Paths lead back south and west through the
        trees.
        """

    static let forestPath = """
        A trail winds between the trees here, running south toward the
        house and continuing north to a clearing. A large tree beside the
        path looks climbable.
        """

    static let tree = """
        A tall, gnarled tree with branches low enough to reach. Something
        pale is tucked into a nest high up among the leaves.
        """

    static let upATree = """
        You are perched in the branches of the large tree, well above the
        forest floor. A nest here holds something. The ground is a climb
        back down.
        """

    static let nest = "A crude nest wedged into the fork of the branches."

    static let egg = """
        A jewel-encrusted egg, its enamel shell inlaid with tiny gems.
        It looks both delicate and valuable.
        """

    static let canary = """
        A golden clockwork canary, exquisitely made. A tiny key in its side
        suggests it might be wound.
        """

    static let brokenCanary = """
        A clockwork canary, once golden and lovely, now a mangled ruin of
        bent gears and snapped springs. Whatever it once did, it will never
        do again.
        """

    static let eggForcedRuinsCanary = """
        You force the egg's delicate mechanism, and it springs open with an
        ugly crunch — the fine clockwork bird inside crushed by your clumsy
        haste.
        """

    static let bauble = """
        A small brass bauble, beautifully worked, that catches the light with
        a warm glow. It is the sort of trinket a songbird might treasure.
        """

    static let songbirdDropsBauble = """
        The canary trills a bright, intricate melody. From the surrounding
        trees a songbird answers, alighting on a branch just overhead. As its
        song joins the canary's, a brass bauble tumbles from its beak, glances
        off your head, and comes to rest glinting in the grass. The tune winds
        down, and the songbird flits away.
        """

    static let canaryChirps = """
        The canary chirps a short, tinny little tune and falls silent. Nothing
        else stirs.
        """

    static let brokenCanaryWinds = """
        The ruined canary manages only an ugly grinding of stripped gears. No
        song comes out of it.
        """

    static let clearingGrating = """
        You are in a small clearing in the forest. Half-buried in a pile
        of dead leaves in one corner, something metal glints. The forest
        path leads south, and the clearing continues east.
        """

    static let leaves = """
        A deep pile of dead leaves, heaped in the corner of the clearing.
        """

    static let leavesMoveEmbellishment = "Underneath the leaves, a metal grating is revealed."

    static let leavesAlreadyMoved = "The leaves have already been pushed aside."

    static let grating = """
        A sturdy iron grating, set into the ground and fastened with a
        heavy lock. Cool air drifts up from whatever lies beneath it.
        """

    static let clearingEast = """
        This clearing sits east of the grating clearing, ringed by trees.
        The forest continues west and south, and the trees thin out to
        the east.
        """

    // MARK: - AboveGround: canyon

    static let canyonView = """
        You stand at the lip of a steep canyon, the forest at your back.
        A narrow ledge switchbacks down the canyon wall below you.
        """

    static let rockyLedge = """
        You are on a rocky ledge partway down the canyon wall, with
        room enough to stand. The ledge continues down toward the canyon
        floor.
        """

    static let canyonBottom = """
        You stand on the floor of the canyon, steep walls rising on both
        sides. A brightly colored mist hangs in the air to the north,
        where a faint rainbow arcs over the ground.
        """

    static let endOfRainbow = """
        You are at the foot of a shimmering rainbow that seems to end
        squarely in the canyon floor here. The colors ripple faintly, as
        though the rainbow itself were somehow solid.
        """

    // MARK: - AboveGround: endgame

    static let ancientMap = """
        The map is old and hand-drawn, its ink faded to a soft brown. It
        marks a path leading southwest from the white house to a low mound
        of earth and stone — a barrow, its entrance sketched as a dark
        doorway in the hillside.
        """

    static let ancientMapAppears = """
        As the last treasure settles into place, the air above the trophy
        case shivers. When it stills, an ancient map lies among the
        riches, drawn in a hand long turned to dust. It shows the way
        southwest from the house.
        """

    static let stoneBarrow = """
        You stand before a low barrow of turf-covered stone, its dark
        entrance yawning to the west. This is the resting place you were
        meant to find.
        """

    static let stoneBarrowEpilogue = """
        You step through the entrance of the barrow, and the darkness
        folds gently around you. Your work is done: every treasure of the
        Great Underground Empire is gathered and safe, and your name is
        set among the Master Adventurers who came before. The barrow
        receives you, and the tale is complete.
        """

    static let barrowPathBlocked = """
        There is no path southwest from here — only the forest, and the
        house at your back.
        """
}
