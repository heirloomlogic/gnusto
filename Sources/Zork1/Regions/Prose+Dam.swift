/// Placeholder prose for the Dam & Reservoir region (``ZorkDam``): the Flood
/// Control Dam and its lobby, the Maintenance Room with the control buttons,
/// the Dam Base, the three reservoir rooms, and the stream. Original text —
/// the verbatim Infocom descriptions arrive later, one constant at a time. See
/// `Prose.swift` for the names-vs-prose ledger rule.
extension Prose {
    // MARK: - Rooms

    static let dam = """
        You stand atop the great bulk of Flood Control Dam #3, a relic of the
        old empire's engineers. A path runs north to a low building, and the
        ground falls away to a scramble down on the far side. To the west the
        held-back water stretches flat and grey.
        """

    static let damLobby = """
        This is the lobby of the dam's works, its walls hung with the faded
        notices of a public long gone. Ways lead on to the north and east, and
        the dam itself lies back to the south.
        """

    static let maintenanceRoom = """
        A cramped workroom crowded with the dam's machinery. A row of coloured
        buttons is set into one wall, and the tools of the trade lie where they
        were left. The only way out is back to the southwest.
        """

    static let damBase = """
        You are at the foot of the dam, where the wall of it rises sheer at
        your back. The ground is littered and damp, and a path climbs up and
        north to the top again.
        """

    static let reservoirSouth = """
        You are on the southern shore of a wide reservoir. The dam holds its
        water to the east; a stream feeds it from the west, and rough ways run
        off to the southeast and southwest along the shore.
        """

    static let reservoir = """
        You are on the bed of the reservoir, its water drained away to either
        side. Slick mud stretches north and south, and a small stream runs in
        from up above to the west.
        """

    static let reservoirNorth = """
        You stand on the northern shore of the reservoir. A dark opening leads
        away to the north, and the drained bed of the reservoir falls off to
        the south.
        """

    static let streamView = """
        You are beside a stream that flows in from the west, out of a cleft too
        small to enter. The reservoir shore lies back to the east.
        """

    static let stream = """
        You are on a narrow stream, its water running gently past. The channel
        widens to the east where it meets the reservoir; upstream it pinches to
        nothing.
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
        A tour guidebook for the dam, its cover proud with a picture of the
        works in their working days.
        """

    static let guidebookText = """
        "Welcome to Flood Control Dam #3! Marvel at the sluice gates, the great
        bolt, and the four-button control station of the Maintenance Room —
        yellow to charge the works, brown to shut them down, blue for the
        emergency drain, and red for the lights. Turn the bolt (a wrench is
        provided) to open or close the gates."
        """

    static let matchbook = """
        A book of matches, mostly full, from a house of some ill repute in a
        town whose name has worn away.
        """

    static let matchbookText = """
        "Visit beautiful FCD#3! You too can be a Flood Control operator! Send
        for our free brochure today." A few matches remain inside.
        """

    // MARK: - Maintenance Room items

    static let blueButton = "A blue button, marked with a symbol for water."

    static let redButton = "A red button, marked with a symbol for light."

    static let brownButton = "A brown button, unlabelled and worn smooth."

    static let yellowButton = "A yellow button, unlabelled and worn smooth."

    static let wrench = "A heavy adjustable wrench, the right size for a great bolt."

    static let screwdriver = "An ordinary screwdriver."

    static let tube = """
        A metal tube, its label boasting: "---> FROBOZZ MAGIC GUNK COMPANY <---
        All-Purpose Gunk." It is nearly full of a viscous grey material.
        """

    // MARK: - Reservoir items

    static let handPump = "A small hand-held air pump, of the kind used to inflate a boat."

    static let trunkFirstSight = "An old trunk, half-buried in the mud, lies here where the water left it."

    static let trunk = """
        An old steamer trunk, its lid sprung, spilling a glitter of jewels
        across the reservoir bed.
        """

    // MARK: - Button replies

    static let yellowButtonPush = """
        There is a hum from the control panel, and the little green bubble on
        the dam lights and begins to glow.
        """

    static let brownButtonPush = """
        The hum from the control panel dies away, and the green bubble on the
        dam goes dark.
        """

    static let redButtonLightsOn = "The lights in the room come on."

    static let redButtonLightsOff = "The lights in the room go out."

    static let blueButtonPush = """
        There is a rumble, and a stream of water bursts from a crack in the
        wall and begins to pool across the floor.
        """

    static let blueButtonAgain = "The water is already coming in; the button does nothing more."

    // MARK: - Bolt / gates

    static let boltNeedsWrench = "You can't turn the bolt with that."

    static let boltWontTurn = "The bolt won't budge — nothing on the panel is live."

    static let gatesOpen = """
        The bolt turns, and with a groan the sluice gates open. Somewhere below,
        water begins to rush through, and the reservoir starts to fall.
        """

    static let gatesClose = """
        The bolt turns the other way, and the sluice gates grind shut. The
        water backs up, and the reservoir begins to fill again.
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
        The rising water closes over the bed of the reservoir — and over you.
        You have drowned.
        """

    // MARK: - Flood (Maintenance Room)

    static let floodAnkle = "The water has risen to your ankles."

    static let floodWaist = "The water is now at your waist, and rising steadily."

    static let floodNeck = "The water is at your neck. You had best leave, and quickly."

    static let floodDrowns = """
        The water closes over your head, and the last of the air with it. You
        have drowned in the Maintenance Room.
        """

    // MARK: - Blocked & conditional exits

    static let reservoirWouldDrown =
        "The reservoir is full to the brim; you would drown before you were halfway across."

    static let damBlocksWay = "The dam blocks your way."

    static let streamTooSmall = "The stream comes out of a cleft in the rock far too small for you to enter."

    static let channelTooNarrow = "The channel narrows to nothing that way."
}
