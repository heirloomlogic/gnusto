/// Original Zork I prose for the Coal Mine region (``ZorkCoalMine``): the mine
/// entrance and its bat, the shaft and its basket, the gas room, the coal maze,
/// and the crack that guards the machine which turns coal to diamond. Text
/// transcribed verbatim from the MIT-licensed Zork I source (see
/// THIRD_PARTY_NOTICES at the repo root). See `Prose.swift` for the
/// names-vs-prose ledger rule.
extension Prose {
    // MARK: - Rooms

    static let mineEntrance = """
        You are standing at the entrance of what might have been a coal mine. The
        shaft enters the west wall, and there is another exit on the south end of
        the room.
        """

    static let squeakyRoom = """
        You are in a small room. Strange squeaky sounds may be heard coming from
        the passage at the north end. You may also escape to the east.
        """

    static let batRoom = """
        You are in a small room which has doors only to the east and south.
        """

    static let shaftRoom = """
        This is a large room, in the middle of which is a small shaft descending
        through the floor into darkness below. To the west and the north are exits
        from this room. Constructed over the top of the shaft is a metal framework
        to which a heavy iron chain is attached.
        """

    static let smellyRoom = """
        This is a small nondescript room. However, from the direction of a small
        descending staircase a foul odor can be detected. To the south is a narrow
        tunnel.
        """

    static let gasRoom = """
        This is a small room which smells strongly of coal gas. There is a short
        climb up some stairs and a narrow tunnel leading east.
        """

    static let coalMine = """
        This is a nondescript part of a coal mine.
        """

    static let ladderTop = """
        This is a very small room. In the corner is a rickety wooden ladder,
        leading downward. It might be safe to descend. There is also a staircase
        leading upward.
        """

    static let ladderBottom = """
        This is a rather wide room. On one side is the bottom of a narrow wooden
        ladder. To the west and the south are passages leaving the room.
        """

    static let coalDeadEnd = """
        You have come to a dead end in the mine.
        """

    static let timberRoom = """
        This is a long and narrow passage, which is cluttered with broken timbers.
        A wide passage comes from the east and turns at the west end of the room
        into a very narrow passageway. From the west comes a strong draft.
        """

    static let draftyRoom = """
        This is a small drafty room in which is the bottom of a long shaft. To the
        south is a passageway and to the east a very narrow passage. In the shaft
        can be seen a heavy iron chain.
        """

    static let machineRoom = """
        This is a large, cold room whose sole exit is to the north. In one corner
        there is a machine which is reminiscent of a clothes dryer. On its face is
        a switch which is labelled "START". The switch does not appear to be
        manipulable by any human hand (unless the fingers are about 1/16 by 1/4
        inch). On the front of the machine is a large lid, which is closed.
        """

    // MARK: - Items

    static let jade = """
        There is an exquisite jade figurine here.
        """

    static let sapphireBracelet = """
        A heavy bracelet, thick with sapphires that catch what little light
        there is and throw it back blue.
        """

    static let coal = """
        It is an ordinary small pile of coal — black, dusty, and unremarkable,
        whatever a machine might make of it.
        """

    static let diamond = """
        There is an enormous diamond (perfectly cut) here.
        """

    static let basket = """
        At the end of the chain is a basket.
        """

    static let basketFarEnd = """
        The basket is at the other end of the chain.
        """

    static let machine = """
        The machine is a squat iron box, much like a clothes dryer, with a heavy
        lid on the front and a switch — far too small for a finger — on its face.
        """

    static let machineSwitch = """
        The switch is a tiny thing, no wider than a coin's edge, and would need
        some slender tool to throw it.
        """

    // MARK: - First sights

    static let jadeFirstSight = "There is an exquisite jade figurine here."
    static let sapphireBraceletFirstSight = "A sapphire-encrusted bracelet lies here."
    static let coalFirstSight = "A small pile of coal is heaped against the wall."
    static let diamondFirstSight = "There is an enormous diamond (perfectly cut) here."

    // MARK: - Mechanics

    static let shaftTooNarrow = """
        You wouldn't fit and would die if you could.
        """

    static let crackTooNarrow = """
        You cannot fit through this passage with that load.
        """

    static let batGrabsYou = """
        The bat grabs you by the scruff of your neck and lifts you away....
        """

    static let basketFastened = "The cage is securely fastened to the iron chain."

    static let basketReachFromShaft = """
        There is no working the chain from here — you would have to stand in the
        Shaft Room, at the top, to raise or lower the basket.
        """

    static let basketLowered = "The basket is lowered to the bottom of the shaft."
    static let basketRaised = "The basket is raised to the top of the shaft."
    static let basketAlreadyLowered = "The basket already hangs at the bottom of the shaft."
    static let basketAlreadyRaised = "The basket is already here at the top of the shaft."

    static let machineTooBig = "It is far too large to carry."

    static let switchNeedsTool = """
        It's not clear how to turn it on with your bare hands.
        """

    static let machineLidOpen = """
        The machine doesn't seem to want to do anything.
        """

    static let machineMakesDiamond = """
        The machine comes to life (figuratively) with a dazzling display of
        colored lights and bizarre noises. After a few moments, the excitement
        abates.
        """

    static let machineWhirsToNoEffect = """
        The machine comes to life (figuratively) with a dazzling display of
        colored lights and bizarre noises. After a few moments, the excitement
        abates.
        """

    static let machineGrindsToGunk = """
        The machine comes to life (figuratively) with a dazzling display of
        colored lights and bizarre noises. After a few moments, the excitement
        abates.
        """

    static let gasExplosion = """
        Oh dear. It appears that the smell coming from this room was coal gas. I
        would have thought twice about carrying flaming objects in here.

              ** BOOOOOOOOOOOM **
        """
}
