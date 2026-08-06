/// Prose for Flood Control Dam #3 (``DungeonDam``): the dam and its lobby, the
/// Maintenance Room and its four buttons, the Dam Base, the three reservoir
/// rooms, and the stream that drains them.
///
/// The three-way rule, and the rule for which file a line goes in, are stated
/// once on ``Prose``.
extension Prose {
    // MARK: - The Dam

    /// Adapted. The trilogy's line lists "paths to the north, south, and west,
    /// and a scramble down". The mainframe's fourth path runs **east**, into
    /// the Damp Cave, and there is no way west from here at all — the
    /// reservoir's south shore is reached from Deep Canyon or the Deep Ravine.
    /// One word changed; the voice is the trilogy's.
    static let dam = """
        You are standing on the top of the Flood Control Dam #3, which was
        quite a tourist attraction in times far distant. There are paths to
        the north, south, and east, and a scramble down.
        """

    /// Verbatim, from the trilogy's `LOW-TIDE`-and-open branch. The mainframe
    /// has only two states where Zork I has four, because there is no drain
    /// delay to be halfway through.
    static let damGatesOpen = """
        The water level behind the dam is low: The sluice gates have been
        opened. Water rushes through the dam and downstream.
        """

    /// Verbatim, from the trilogy's shut branch — which already says
    /// "reservoir", the word this game uses throughout.
    static let damGatesShut = """
        The sluice gates on the dam are closed. Behind the dam, there can be
        seen a wide reservoir. Water is pouring over the top of the now
        abandoned dam.
        """

    static let damControlPanel = """
        There is a control panel here, on which a large metal bolt is mounted.
        Directly above the bolt is a small green plastic bubble.
        """

    /// Verbatim, less the trilogy's trailing comma splice: the bubble is
    /// reported by the same sentence there, and here it is its own line.
    static let damBubbleGlowing = "The green bubble is glowing serenely."

    static let damReservoirView = """
        From up here the reservoir is a grey sheet reaching back into the dark,
        and there is a great deal more of it than the dam looks equal to.
        """

    static let privateDoorways = """
        Two doorways marked "Private", standing open, and nobody left to mind
        either of them.
        """

    static let buttonPanel = """
        Four buttons on the wall in front of you — blue, yellow, brown, red —
        each of them wired to something you cannot see.
        """

    static let buttonLabels = "They're greek to you."

    static let damItem = """
        Flood Control Dam #3, two hundred and fifty-six feet of concrete and
        civic pride, with a sluice gate at the bottom of it that somebody left
        a bolt in charge of.
        """

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

    // MARK: - Dam Lobby

    /// Verbatim. `LOBBY` is in the comparison's `substantial` bucket, but the
    /// check the bucket asks for comes out clean: both rooms have the same
    /// three ways out — north and east into the Maintenance Room, south to the
    /// dam. The difference is wording, so the trilogy's wording stands.
    static let damLobby = """
        This room appears to have been the waiting room for groups touring
        the dam. There are open doorways here to the north and east marked
        "Private", and there is a path leading south over the top of the dam.
        """

    static let receptionDesk = """
        A reception desk, swept clean of everything but the guidebooks nobody
        came to collect.
        """

    static let guidebookInPlace = """
        Some guidebooks entitled "Flood Control Dam #3" are on the reception
        desk.
        """

    /// Verbatim. The mainframe's brochure differs in four places — its concrete
    /// is measured in whole cubic feet, its reservoir holds 37 billion of them,
    /// the grant comes from the Central Bureaucracy, and the correspondence
    /// school in the matchbook is MIT rather than GUE — and every one of those
    /// is 1981 text with no located grant behind it. The trilogy's brochure is
    /// the same brochure, licensed, so it is the one printed here.
    static let guidebook = """
        Flood Control Dam #3

        FCD#3 was constructed in year 783 of the Great Underground Empire to
        harness the mighty Frigid River. This work was supported by a grant of
        37 million zorkmids from your omnipotent local tyrant Lord Dimwit
        Flathead the Excessive. This impressive structure is composed of
        370,000 cubic feet of concrete, is 256 feet tall at the center, and 193
        feet wide at the top. The reservoir created behind the dam has a volume
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

    static let matchbookInPlace = """
        There is a matchbook whose cover says "Visit Beautiful FCD#3" here.
        """

    /// Verbatim, for the same reason as the guidebook above.
    static let matchbook = """
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

    // MARK: - The matches

    static let matchStrikes = "One of the matches starts to burn."

    static let matchesGone = "I'm afraid that you have run out of matches."

    static let matchIsOut = "The match is out."

    static let matchBurnsOut = "The match has gone out."

    // MARK: - Maintenance Room

    /// Adapted. The trilogy's line is the skeleton; the mainframe keeps two
    /// details it dropped — the tool chests the room is named for, still
    /// standing around the walls, and the fact that the buttons carry labels
    /// nobody alive can read. Both additions are this game's own words. The
    /// doorways are the same two in both.
    static let maintenanceRoom = """
        This is what appears to have been the maintenance room for Flood
        Control Dam #3. Apparently, this room has been ransacked recently, for
        most of the valuable equipment is gone, though the tool chests it was
        kept in still stand around the walls. On the wall in front of you is a
        group of buttons colored blue, yellow, brown, and red, labelled in a
        script no living person reads. There are doorways to the west and
        south.
        """

    static let toolChests = """
        The chests are empty, and bolted to the wall besides — which together
        suggest that whoever ransacked this room was thorough and in no hurry.
        """

    /// All four buttons look the same and say the same thing; only the colour
    /// changes, and the labels above them are the joke.
    static func plainButton(_ color: String) -> String {
        "A \(color) button, worn smooth, with a label above it you cannot read."
    }

    /// The mainframe answers the yellow and brown buttons with a single word
    /// apiece, and leaves you to read the result off the bubble at the dam.
    static let buttonClick = "Click."

    static let lightsOn = "The lights within the room come on."

    static let lightsOff = "The lights within the room shut off."

    static let blueButtonPush = """
        There is a rumbling sound and a stream of water appears to burst
        from the east wall of the room (apparently, a leak has occurred in a
        pipe).
        """

    static let blueButtonJammed = "The blue button appears to be jammed."

    static let leak = """
        Water is coming out of the east wall faster than the wall can be said
        to have a hole in it.
        """

    static let leakStopped = """
        A grey plug of hardened gunk in the east wall, and not a drop getting
        past it.
        """

    static let wrenchInPlace = "A wrench lies among the wreckage."

    static let wrench = "A heavy adjustable wrench, the right size for a great bolt."

    static let screwdriverInPlace = "A screwdriver has been left on one of the chests."

    static let screwdriver = "An ordinary screwdriver."

    static let tubeInPlace = """
        There is an object which looks like a tube of toothpaste here.
        """

    static let tube = """
        The tube is labelled: "Frobozz Magic Gunk Company — All-Purpose Gunk".
        """

    static let tubeClosed = "The tube is closed."

    static let tubeEmpty = "The tube is apparently empty."

    static let putty = """
        A wad of viscous grey material that would hold two halves of anything
        together, and possibly your fingers as well.
        """

    static let puttyOozes = "The viscous material oozes into your hand."

    static let nothingLeaking = "Nothing here is leaking."

    static let plugNeedsGunk = "You will need something to plug it with."

    /// Written fresh. Zork I has no plug at all — the trilogy dropped the
    /// putty along with the verb — so there is no licensed line to take, and
    /// the mainframe's own is 1981 text.
    static let leakPlugged = """
        You work the gunk into the break in the pipe. It sets hard almost
        before your hand is clear, and the water stops as if it had been
        switched off.
        """

    static let maintenanceRoomFull = """
        The room is full of water and cannot be entered.
        """

    /// The ladder, verbatim — both versions carry the same nine rungs. The
    /// water climbs one of them a turn, and when it has gone past the last the
    /// room is finished and so is anyone in it. The mainframe raises its
    /// counter every turn and *halves* it to index the ladder, which skips
    /// "ankles" outright and prints "over your head" twice before drowning
    /// you; this game walks the rungs straight. See `FIDELITY.md`.
    static let floodLadder = [
        "up to your ankles.", "up to your shin.", "up to your knees.",
        "up to your hips.", "up to your waist.", "up to your chest.",
        "up to your neck.", "over your head.", "high in your lungs.",
    ]

    static func floodRises(_ level: String) -> String {
        "The water level here is now \(level)"
    }

    static let floodDrowns = """
        I'm afraid you have done drowned yourself.
        """

    // MARK: - Dam Base

    /// Adapted. The trilogy has the White Cliffs "along the river ... along the
    /// shores", which makes them both banks; the mainframe puts them squarely
    /// **across** it, on the east shore alone, and that is the geography the
    /// river milestone will need when it comes to land a boat between them.
    /// Two clauses changed; the rest is the trilogy's.
    static let damBase = """
        You are at the base of Flood Control Dam #3, which looms above you
        and to the north. The river Frigid is flowing by here. Across the
        river the White Cliffs seem to form a giant wall stretching from north
        to south along the far shore as the river winds its way downstream.
        """

    static let frigidRiver = """
        The Frigid River, going past at a speed that suggests it has somewhere
        to be and no interest in your company.
        """

    static let whiteCliffs = """
        A wall of white stone on the far shore, running north and south as far
        as the light goes.
        """

    // MARK: - Reservoir South

    /// Adapted. The trilogy carries four states here because its gates take
    /// eight turns to move; the mainframe has two, so its shut state is the
    /// trilogy's `T` branch and its open state the trilogy's
    /// `LOW-TIDE`-and-open branch, both verbatim but for "lake", which this
    /// game calls a reservoir throughout — as the room names already do. The
    /// exits sentence is this game's own: the mainframe's Reservoir South has
    /// six ways out where Zork I's has four, and none of the trilogy's lines
    /// name the right ones.
    static let reservoirSouthFull = """
        You are in a long room on the south shore of a large reservoir, far
        too deep and wide for crossing.

        There is a western exit, a passageway south, and a steep path climbing
        up along the edge of a cliff.
        """

    static let reservoirSouthDrained = """
        You are in a long room, to the north of which was formerly a
        reservoir. However, with the water level lowered, there is merely a
        wide stream running through the center of the room.

        There is a western exit, a passageway south, and a steep path climbing
        up along the edge of a cliff.
        """

    // MARK: - The reservoir

    /// Verbatim from the trilogy's two branches, "lake" put back to
    /// "reservoir".
    static let reservoirFull = """
        You are on the reservoir. Beaches can be seen north and south.
        Upstream a small stream enters the reservoir through a narrow cleft
        in the rocks. The dam can be seen downstream.
        """

    static let reservoirDrained = """
        You are on what used to be a large reservoir, but which is now a large
        mud pile. There are "shores" to the north and south.
        """

    static let reservoirWater = """
        A billion and a half cubic feet of it, according to the guidebook, and
        every one of them between you and the north shore.
        """

    static let reservoirFromShore = """
        Whether it is a reservoir or a mud flat depends entirely on what the
        bolt at the top of the dam was last told to do.
        """

    /// Verbatim as above, except that the mainframe's way north is a tunnel
    /// rather than the trilogy's slimy stairway.
    static let reservoirNorthFull = """
        You are in a large cavernous room, north of a large reservoir.

        There is a tunnel leaving the room to the north.
        """

    static let reservoirNorthDrained = """
        You are in a large cavernous room, the south of which was formerly
        a reservoir. However, with the water level lowered, there is merely
        a wide stream running through there.

        There is a tunnel leaving the room to the north.
        """

    static let handPumpInPlace = "A small hand-held pump has been left on the shore."

    static let handPump = "A small hand-held air pump, of the kind used to inflate a boat."

    static let trunkFirstSight = "Lying half buried in the mud is an old trunk, bulging with jewels."

    static let trunk = """
        An old trunk, bulging with assorted jewels, and heavy enough that you
        will be making the climb home in one trip and one trip only.
        """

    // MARK: - Stream View and the stream

    /// Adapted. The trilogy has the path following the stream west to east;
    /// the mainframe's runs **north and east** — north being the Glacier Room,
    /// which arrives with a later milestone. First sentence the trilogy's,
    /// second this game's.
    static let streamView = """
        You are standing on a path beside a gently flowing stream. The path
        leaves north, away from the water, and east along it.
        """

    /// Verbatim. `INSTR` is in the comparison's `minor` bucket and the room is
    /// unchanged between the two.
    static let stream = """
        You are on the gently flowing stream. The upstream route is too narrow
        to navigate, and the downstream route is invisible due to twisting
        walls. There is a narrow beach to land on.
        """

    static let streamWater = """
        The runoff from the reservoir, going quietly about its business between
        two banks of wet stone.
        """

    static let streamChannel = """
        The walls twist away downstream and there is a strip of beach on one
        side, wide enough to stand a boat on if you had one.
        """

    static let wireCoilInPlace = "A coil of thin shiny wire lies on the bank."

    static let wireCoil = """
        A coil of thin shiny wire, the sort that burns rather than conducts.
        Somebody meant it to reach something at one end of it.
        """

    // MARK: - Bolt, gates, and blocked ways

    /// Adapted from the mainframe's rule rather than its words: the source has
    /// no bare `turn` for the bolt at all, and a dead end there would be
    /// unkind when the wrench is two rooms away.
    static let boltBareHanded = "Your bare hands aren't enough. The bolt needs a tool."

    static let boltNeedsWrench = "You can't turn the bolt with that."

    static let boltWontTurn = "The bolt won't turn with your best effort."

    static let gatesOpen = """
        The sluice gates open and water pours through the dam.
        """

    static let gatesClose = """
        The sluice gates close and water starts to collect behind the dam.
        """

    /// Written fresh. The mainframe's refusal here is 1981 text and Zork I
    /// blocked the crossing differently, so this is this game's own.
    static let notEquippedToSwim = """
        The water is far too deep and far too wide, and you are dressed for
        burglary rather than for swimming.
        """

    static let damBlocksWay = "The dam blocks your way."

    static let streamTooNarrow = "The channel is too narrow."
}
