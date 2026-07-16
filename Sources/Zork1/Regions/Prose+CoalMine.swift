/// Placeholder prose for the Coal Mine region (``ZorkCoalMine``): the mine
/// entrance and its bat, the shaft and its basket, the gas room, the coal maze,
/// and the crack that guards the machine which turns coal to diamond. Original
/// text — the verbatim Infocom descriptions arrive later, one constant at a
/// time. See `Prose.swift` for the names-vs-prose ledger rule.
extension Prose {
    // MARK: - Rooms

    static let mineEntrance = """
        You stand at the mouth of what must once have been a coal mine. The
        shaft runs on into the west wall, and the way you came lies south.
        """

    static let squeakyRoom = """
        This is a cramped room. Thin, squeaking sounds carry down the passage
        at its north end, and a way out lies to the east.
        """

    static let batRoom = """
        This is a low, close room with openings to the east and south. Something
        stirs on the ceiling overhead.
        """

    static let shaftRoom = """
        This is a broad room. At its centre a narrow shaft drops away into the
        dark below, and over it stands an iron framework from which a heavy chain
        hangs. Passages leave west and north.
        """

    static let smellyRoom = """
        This is a plain, close room. A foul reek drifts up a short flight of
        stairs descending from it, and a narrow tunnel runs south.
        """

    static let gasRoom = """
        This is a small chamber, and the reek of coal gas hangs heavy in it. A
        few stairs climb up, and a cramped tunnel leads east.
        """

    static let coalMine = """
        This is a dim, nondescript stretch of the coal mine, indistinguishable
        from a dozen others just like it.
        """

    static let ladderTop = """
        This is a tiny room. A rickety wooden ladder runs down through the floor
        from here, and a staircase climbs away above.
        """

    static let ladderBottom = """
        This is a wide room at the foot of a narrow wooden ladder. Passages leave
        to the west and the south, and the ladder climbs back up.
        """

    static let coalDeadEnd = """
        You have come to a dead end in the mine. The only way on is back the way
        you came, to the north.
        """

    static let timberRoom = """
        This is a long, narrow passage strewn with broken timbers. A wide way
        comes in from the east; at the west end the passage pinches to a crack,
        and a cold draught blows through it.
        """

    static let draftyRoom = """
        This is a small, draughty room at the foot of a long shaft, down which a
        heavy chain hangs. A passage leaves south, and the crack you came through
        opens east.
        """

    static let machineRoom = """
        This is a large, cold room. In one corner squats a machine much like an
        overgrown clothes dryer, its lid on the front and a small switch on its
        face. The only way out is north.
        """

    // MARK: - Items

    static let jade = """
        The figurine is carved from a single piece of deep-green jade, cool and
        smooth and worth a small fortune.
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
        It is an enormous diamond, perfectly cut, throwing back the light in a
        hundred hard bright points.
        """

    static let basket = """
        It is a sturdy wicker basket, hung on the end of the great iron chain and
        large enough to carry a fair load up or down the shaft.
        """

    static let basketFarEnd = """
        The basket hangs at the far end of the chain, out of reach — you would
        have to work the chain from the Shaft Room to bring it back.
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

    static let jadeFirstSight = "A delicate jade figurine rests here."
    static let sapphireBraceletFirstSight = "A sapphire-encrusted bracelet lies here."
    static let coalFirstSight = "A small pile of coal is heaped against the wall."
    static let diamondFirstSight = "There is an enormous diamond here."

    // MARK: - Mechanics

    static let shaftTooNarrow = """
        The shaft is far too narrow to climb down — you would only wedge fast and
        never come up again.
        """

    static let crackTooNarrow = """
        The crack is too narrow to squeeze through with anything in your hands.
        You will have to leave your load behind.
        """

    static let batGrabsYou = """
        Fweep! A great vampire bat drops from the ceiling, fastens on the scruff
        of your neck, and carries you off into the dark before dropping you
        somewhere else entirely.
        """

    static let basketFastened = "The basket is fastened securely to the iron chain."

    static let basketReachFromShaft = """
        There is no working the chain from here — you would have to stand in the
        Shaft Room, at the top, to raise or lower the basket.
        """

    static let basketLowered = "The basket drops away down the shaft to the bottom."
    static let basketRaised = "The chain draws the basket back up to the top of the shaft."
    static let basketAlreadyLowered = "The basket already hangs at the bottom of the shaft."
    static let basketAlreadyRaised = "The basket is already here at the top of the shaft."

    static let machineTooBig = "The machine is far too large and heavy to carry."

    static let switchNeedsTool = """
        The switch is far too small to throw with your bare fingers, and that is
        no help at all — it wants some slender tool.
        """

    static let machineLidOpen = """
        The machine hums and shudders, but with its lid standing open nothing
        much seems to come of it.
        """

    static let machineMakesDiamond = """
        The machine comes to life with a dazzle of coloured light and a racket of
        grinding and hissing. When it falls quiet and the lid clicks, the coal is
        gone — and something hard and bright rattles inside.
        """

    static let machineWhirsToNoEffect = """
        The machine comes to life with a dazzle of coloured light and a racket of
        grinding and hissing. When it falls quiet, nothing whatever has changed.
        """

    static let machineGrindsToGunk = """
        The machine comes to life with a dazzle of coloured light and a racket of
        grinding and hissing. When it falls quiet and the lid clicks, whatever you
        put inside is gone — ground to a worthless grey slag and not worth scraping
        out.
        """

    static let gasExplosion = """
        The flame meets the coal gas, and the whole chamber goes up in a single
        white roar. There is, at least, no time to regret it.
        """
}
