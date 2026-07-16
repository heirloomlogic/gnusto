/// Original Zork I prose for the Dam & Reservoir region (``ZorkDam``): the
/// Flood Control Dam and its lobby, the Maintenance Room with the control
/// buttons, the Dam Base, the three reservoir rooms, and the stream. These are
/// the verbatim Infocom descriptions (see THIRD_PARTY_NOTICES at the repo
/// root). See `Prose.swift` for the names-vs-prose ledger rule.
extension Prose {
    // MARK: - Rooms

    static let dam = """
        You are standing on the top of the Flood Control Dam #3, which was
        quite a tourist attraction in times far distant. There are paths to
        the north, south, and west, and a scramble down.
        """

    static let damLobby = """
        This room appears to have been the waiting room for groups touring
        the dam. There are open doorways here to the north and east marked
        "Private", and there is a path leading south over the top of the dam.
        """

    static let maintenanceRoom = """
        This is what appears to have been the maintenance room for Flood
        Control Dam #3. Apparently, this room has been ransacked recently, for
        most of the valuable equipment is gone. On the wall in front of you is
        a group of buttons colored blue, yellow, brown, and red. There are
        doorways to the west and south.
        """

    static let damBase = """
        You are at the base of Flood Control Dam #3, which looms above you
        and to the north. The river Frigid is flowing by here. Along the
        river are the White Cliffs which seem to form giant walls stretching
        from north to south along the shores of the river as it winds its
        way downstream.
        """

    static let reservoirSouth = """
        You are in a long room on the south shore of a large lake, far
        too deep and wide for crossing. There is a path along the stream to
        the east or west, a steep pathway climbing southwest along the edge of
        a chasm, and a path leading into a canyon to the southeast.
        """

    static let reservoir = """
        You are on what used to be a large lake, but which is now a large
        mud pile. There are "shores" to the north and south.
        """

    static let reservoirNorth = """
        You are in a large cavernous room, north of a large lake. There is a
        slimy stairway leaving the room to the north.
        """

    static let streamView = """
        You are standing on a path beside a gently flowing stream. The path
        follows the stream, which flows from west to east.
        """

    static let stream = """
        You are on the gently flowing stream. The upstream route is too narrow
        to navigate, and the downstream route is invisible due to twisting
        walls. There is a narrow beach to land on.
        """

    // MARK: - Dam controls (Dam Room)

    static let bolt = """
        A great metal bolt is set into the control panel, the kind meant to be
        turned by a proper tool and no hand alone.
        """

    static let bubble = """
        A small green bubble of plastic sits in the panel, the sort that lights
        when a circuit is live.
        """

    static let controlPanel = """
        A control panel studded with dials and fittings, all of it built around
        the single great bolt at its center.
        """

    // MARK: - Dam Lobby items

    static let guidebook = """
        Some guidebooks entitled "Flood Control Dam #3" are on the reception
        desk.
        """

    static let guidebookText = """
        Flood Control Dam #3

        FCD#3 was constructed in year 783 of the Great Underground Empire to
        harness the mighty Frigid River. This work was supported by a grant of
        37 million zorkmids from your omnipotent local tyrant Lord Dimwit
        Flathead the Excessive. This impressive structure is composed of
        370,000 cubic feet of concrete, is 256 feet tall at the center, and 193
        feet wide at the top. The lake created behind the dam has a volume
        of 1.7 billion cubic feet, an area of 12 million square feet, and a
        shore line of 36 thousand feet.

        The construction of FCD#3 took 112 days from ground breaking to
        the dedication. It required a work force of 384 slaves, 34 slave
        drivers, 12 engineers, 2 turtle doves, and a partridge in a pear
        tree. The work was managed by a command team composed of 2345
        bureaucrats, 2347 secretaries (at least two of whom could type),
        12,256 paper shufflers, 52,469 rubber stampers, 245,193 red tape
        processors, and nearly one million dead trees.

        We will now point out some of the more interesting features
        of FCD#3 as we conduct you on a guided tour of the facilities:

        1) You start your tour here in the Dam Lobby. You will notice
        on your right that....
        """

    static let matchbook = """
        There is a matchbook whose cover says "Visit Beautiful FCD#3" here.
        """

    static let matchbookText = """
        (Close cover before striking)

        YOU too can make BIG MONEY in the exciting field of PAPER SHUFFLING!

        Mr. Anderson of Muddle, Mass. says: "Before I took this course I
        was a lowly bit twiddler. Now with what I learned at GUE Tech
        I feel really important and can obfuscate and confuse with the best."

        Dr. Blank had this to say: "Ten short days ago all I could look
        forward to was a dead-end job as a doctor. Now I have a promising
        future and make really big Zorkmids."

        GUE Tech can't promise these fantastic results to everyone. But when
        you earn your degree from GUE Tech, your future will be brighter.
        """

    // MARK: - Maintenance Room items

    static let blueButton = "A blue button, marked with a symbol for water."

    static let redButton = "A red button, marked with a symbol for light."

    static let brownButton = "A brown button, unlabelled and worn smooth."

    static let yellowButton = "A yellow button, unlabelled and worn smooth."

    static let wrench = "A heavy adjustable wrench, the right size for a great bolt."

    static let screwdriver = "An ordinary screwdriver."

    static let tube = """
        There is an object which looks like a tube of toothpaste here.
        """

    // MARK: - Reservoir items

    static let handPump = "A small hand-held air pump, of the kind used to inflate a boat."

    static let trunkFirstSight = "Lying half buried in the mud is an old trunk, bulging with jewels."

    static let trunk = """
        There is an old trunk here, bulging with assorted jewels.
        """

    // MARK: - Button replies

    static let yellowButtonPush = "Click."

    static let brownButtonPush = "Click."

    static let redButtonLightsOn = "The lights within the room come on."

    static let redButtonLightsOff = "The lights within the room shut off."

    static let blueButtonPush = """
        There is a rumbling sound and a stream of water appears to burst
        from the east wall of the room (apparently, a leak has occurred in a
        pipe).
        """

    static let blueButtonAgain = "The blue button appears to be jammed."

    // MARK: - Bolt / gates

    static let boltNeedsWrench = "You can't turn the bolt with that."

    static let boltWontTurn = "The bolt won't turn with your best effort."

    static let gatesOpen = """
        The sluice gates open and water pours through the dam.
        """

    static let gatesClose = """
        The sluice gates close and water starts to collect behind the dam.
        """

    static let reservoirEmpties = """
        The last of the water drains from the reservoir, leaving a bed of slick
        mud behind. The rushing in the depths dies to silence.
        """

    static let reservoirRefills = """
        The reservoir fills to the brim once more, its surface settling flat and
        grey, and the noise of moving water fades away.
        """

    static let reservoirRefillDrowns = """
        You are lifted up by the rising river! You try to swim, but the
        currents are too strong. You come closer, closer to the awesome
        structure of Flood Control Dam #3. The dam beckons to you.
        The roar of the water nearly deafens you, but you remain conscious
        as you tumble over the dam toward your certain doom among the rocks
        at its base.
        """

    // MARK: - Flood (Maintenance Room)

    static let floodAnkle = "The water level here is now up to your ankles."

    static let floodWaist = "The water level here is now up to your waist."

    static let floodNeck = "The water level here is now up to your neck."

    static let floodDrowns = """
        I'm afraid you have done drowned yourself.
        """

    // MARK: - Blocked & conditional exits

    static let reservoirWouldDrown = "You would drown."

    static let damBlocksWay = "The dam blocks your way."

    static let streamTooSmall = "The stream emerges from a spot too small for you to enter."

    static let channelTooNarrow = "The channel is too narrow."
}
