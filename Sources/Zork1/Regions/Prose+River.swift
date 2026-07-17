/// Original Zork I prose for the Frigid River region (``ZorkRiver``): the river run
/// below the dam and the boat that makes it passable, the White Cliffs on the
/// west bank, the sandy east bank with its buried scarab, Aragain Falls, and the
/// rainbow that — waved solid with the sceptre — links the falls to the End of
/// Rainbow at the bottom of the canyon. Text transcribed verbatim from the
/// MIT-licensed Zork I source (see THIRD_PARTY_NOTICES at the repo root). See
/// `Prose.swift` for the names-vs-prose ledger rule.
extension Prose {
    // MARK: - Rooms

    static let river1 = """
        You are on the Frigid River in the vicinity of the Dam. The river flows
        quietly here. There is a landing on the west shore.
        """

    static let river2 = """
        The river turns a corner here making it impossible to see the Dam. The
        White Cliffs loom on the east bank and large rocks prevent landing on the
        west.
        """

    static let river3 = """
        The river descends here into a valley. There is a narrow beach on the west
        shore below the cliffs. In the distance a faint rumbling can be heard.
        """

    static let river4 = """
        The river is running faster here and the sound ahead appears to be that of
        rushing water. On the east shore is a sandy beach. A small area of beach
        can also be seen below the cliffs on the west shore.
        """

    static let river5 = """
        The sound of rushing water is nearly unbearable here. On the east shore is
        a large landing area.
        """

    static let whiteCliffsNorth = """
        You are on a narrow strip of beach which runs along the base of the White
        Cliffs. There is a narrow path heading south along the Cliffs and a tight
        passage leading west into the cliffs themselves.
        """

    static let whiteCliffsSouth = """
        You are on a rocky, narrow strip of beach beside the Cliffs. A narrow path
        leads north along the shore.
        """

    static let shore = """
        You are on the east shore of the river. The water here seems somewhat
        treacherous. A path travels from north to south here, the south end
        quickly turning around a sharp corner.
        """

    static let sandyBeach = """
        You are on a large sandy beach on the east shore of the river, which is
        flowing quickly by. A path runs beside the river to the south here, and a
        passage is partially buried in sand to the northeast.
        """

    static let sandyCave = """
        This is a sand-filled cave whose exit is to the southwest.
        """

    static let aragainFalls = """
        You are at the top of Aragain Falls, an enormous waterfall with a drop of
        about 450 feet. The only path here is on the north end.
        """

    static let onRainbow = """
        You are on top of a rainbow (I bet you never thought you would walk on a
        rainbow), with a magnificent view of the Falls. The rainbow travels
        east-west here.
        """

    // MARK: - Items

    static let pileOfPlastic = """
        There is a folded pile of plastic here which has a small valve attached.
        """

    static let magicBoat = """
        It is a small plastic boat, taut and seaworthy, easily large enough to
        carry you and a fair load of cargo down the river.
        """

    static let puncturedBoat = """
        It is a sad, deflated ruin of a boat, hissing softly through the hole
        some fool put in it. It will float nobody anywhere.
        """

    static let buoy = """
        There is a red buoy here (probably a warning).
        """

    static let emerald = """
        The emerald is enormous, deep green, and flawless — a stone fit for a
        crown.
        """

    static let shovel = """
        It is a plain, sturdy shovel, its blade still keen enough to bite into
        packed sand.
        """

    static let scarab = """
        The scarab is a beetle carved from a single jewel, its facets throwing
        back the light in a dozen colours.
        """

    static let potOfGold = """
        At the end of the rainbow is a pot of gold.
        """

    // MARK: - First sights

    static let pileOfPlasticFirstSight = "There is a folded pile of plastic here which has a small valve attached."
    static let buoyFirstSight = "There is a red buoy here (probably a warning)."
    static let shovelFirstSight = "A shovel has been left lying in the sand."
    static let scarabFirstSight = "You can see a scarab here in the sand."
    static let potOfGoldFirstSight = "At the end of the rainbow is a pot of gold."

    // MARK: - Boat mechanics

    static let boatInflates = """
        The boat inflates and appears seaworthy.
        """

    static let inflateNeedsPump = "You don't have enough lung power to inflate it."

    static let inflateNotOnGround = "The boat must be on the ground to be inflated."

    static let boatAlreadyFirm = "Inflating it further would probably burst it."

    static let boatDeflates = "The boat deflates."

    static let fixNeedsGunk = """
        It wants sealing, and your bare hands won't do it. You'll need something to plug the rip.
        """

    static let boatPatched = """
        Well done. The boat is repaired.
        """

    static let deflateWhileAboard = "You can't deflate the boat while you're in it."

    static let deflateNotOnGround = "The boat must be on the ground to be deflated."

    static let launchNotAboard = "You're not in the boat!"

    static let launchNotHere = "You can't launch it here."

    static let boatLaunches = "The boat slips off the bank and out onto the moving water."

    static let alreadyAfloat = "You are on the river, or have you forgotten?"

    static let currentCarriesYou = "The flow of the river carries you downstream."

    static let overTheFalls = """
        Unfortunately, the magic boat doesn't provide protection from the rocks and
        boulders one meets at the bottom of waterfalls. Including this one.
        """

    static let boatPuncturedOnLand = """
        Oops! Something sharp seems to have slipped and punctured the boat. The
        boat deflates to the sounds of hissing, sputtering, and cursing.
        """

    static let boatPuncturedAfloat = """
        Something sharp shifts against the hull and opens it with a hiss. The
        boat folds up beneath you, and the fierce cold current does the rest.
        """

    static let noSwimming = """
        A look before leaping reveals that the river is wide and dangerous, with
        swift currents and large, half-hidden rocks. You decide to forgo your swim.
        """

    static let disembarkOntoWater = """
        You realize that getting out here would be fatal.
        """

    // MARK: - White Cliffs

    static let cliffPathTooNarrow = """
        The path is too narrow.
        """

    // MARK: - Sand & digging

    static let digWithoutShovel = "Digging with your hands is silly."

    static let digProgress = "You seem to be digging a hole here."

    static let digRevealsScarab = """
        You can see a scarab here in the sand.
        """

    static let digCollapses = """
        The hole collapses, smothering you.
        """

    static let nothingToDigHere = "There's no reason to be digging here."

    // MARK: - Rainbow

    static let rainbowSolidifies = """
        Suddenly, the rainbow appears to become solid and, I venture, walkable (I
        think the giveaway was the stairs and bannister).
        """

    static let potAppears = "A shimmering pot of gold appears at the end of the rainbow."

    static let rainbowFades = "The rainbow seems to have become somewhat run-of-the-mill."

    static let rainbowNotSolid = "Can you walk on water vapor?"

    static let rainbowWaveFatal = """
        The structural integrity of the rainbow is severely compromised, leaving
        you hanging in midair, supported only by water vapor. Bye.
        """

    static let sceptreSparkles = "A dazzling display of color briefly emanates from the sceptre."
}
