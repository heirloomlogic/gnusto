/// Placeholder prose for the Frigid River region (``ZorkRiver``): the river run
/// below the dam and the boat that makes it passable, the White Cliffs on the
/// west bank, the sandy east bank with its buried scarab, Aragain Falls, and the
/// rainbow that — waved solid with the sceptre — links the falls to the End of
/// Rainbow at the bottom of the canyon. Original text; the verbatim Infocom
/// descriptions arrive later, one constant at a time. See `Prose.swift` for the
/// names-vs-prose ledger rule.
extension Prose {
    // MARK: - Rooms

    static let river1 = """
        You are on the Frigid River, close under the dam. The water slides by
        quietly here, and there is a landing on the west shore.
        """

    static let river2 = """
        The river bends here, and the dam is lost from sight behind you. White
        cliffs rise from the east bank, and jagged rocks guard the west.
        """

    static let river3 = """
        The river drops into a deepening valley. A narrow beach runs along the
        foot of the cliffs on the west shore, and a distant rumble carries on
        the air.
        """

    static let river4 = """
        The river quickens, and the rumble ahead has become the roar of rushing
        water. A sandy beach lies along the east shore, and a smaller strip of
        beach shows below the cliffs to the west.
        """

    static let river5 = """
        The roar of water is almost unbearable here. A wide landing beach opens
        on the east shore — the last before the falls.
        """

    static let whiteCliffsNorth = """
        You are on a narrow strip of beach at the foot of the White Cliffs. A
        thin path runs south along the base of the cliffs, and a tight passage
        squeezes west into the rock.
        """

    static let whiteCliffsSouth = """
        This is a rocky, cramped strip of beach hard against the cliffs. A
        narrow path leads north along the shore.
        """

    static let shore = """
        You stand on the east shore of the river, where the water runs fast and
        treacherous. A path follows the bank from north to south, its south end
        bending sharply out of sight.
        """

    static let sandyBeach = """
        This is a broad sandy beach on the east shore, the river sliding swiftly
        past. A path runs south along the water, and a passage half-choked with
        sand opens to the northeast.
        """

    static let sandyCave = """
        This is a low cave, its floor deep in drifted sand. The only way out is
        back to the southwest.
        """

    static let aragainFalls = """
        You are at the lip of Aragain Falls, where the whole river pitches over a
        drop of some hundreds of feet. The only path out lies north.
        """

    static let onRainbow = """
        You are standing on top of a rainbow — improbable, but there it is —
        with a dizzying view of the falls below. The rainbow runs east and west
        from here.
        """

    // MARK: - Items

    static let pileOfPlastic = """
        It is a folded pile of tough plastic with a small valve set into one
        corner — an inflatable boat, waiting for air.
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
        It is a fat red buoy of the kind moored to warn of danger. It is hollow,
        and something shifts inside when you turn it over.
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
        It is a small iron pot, brim-full of gold coins — the storied prize at
        the rainbow's end.
        """

    // MARK: - First sights

    static let pileOfPlasticFirstSight = "There is a folded pile of plastic here, a valve at one corner."
    static let buoyFirstSight = "A red buoy bobs on the water within easy reach."
    static let shovelFirstSight = "A shovel has been left lying in the sand."
    static let scarabFirstSight = "A jewelled scarab lies half-buried in the sand."
    static let potOfGoldFirstSight = "At the very end of the rainbow sits a pot of gold."

    // MARK: - Boat mechanics

    static let boatInflates = """
        You work the pump, and with a long wheeze the pile of plastic swells into
        a taut little boat.
        """

    static let inflateNeedsPump = "You could huff into the valve all day and get nowhere. It wants a pump."

    static let inflateNotOnGround = "The boat must be laid out on the ground before you can inflate it."

    static let boatAlreadyFirm = "Inflating it any further would only burst it."

    static let boatDeflates = "The air sighs out of the boat, and it folds back into a pile of plastic."

    static let fixNeedsGunk = """
        It wants sealing, and your bare hands won't do it. You'll need something to plug the rip.
        """

    static let boatPatched = """
        You smear the tube's viscous gunk thickly over the rip and hold it until
        it sets. The seal holds — the boat is whole and seaworthy again, and the
        tube is squeezed empty.
        """

    static let deflateWhileAboard = "You can hardly deflate the boat while you are sitting in it."

    static let deflateNotOnGround = "The boat must be on the ground to be deflated."

    static let launchNotAboard = "You're not in the boat."

    static let launchNotHere = "There is no water here to launch onto."

    static let boatLaunches = "The boat slips off the bank and out onto the moving water."

    static let alreadyAfloat = "You are already on the water, or had you forgotten?"

    static let currentCarriesYou = "The current takes hold of the boat and carries you downstream."

    static let overTheFalls = """
        The current is too strong now to fight. The boat sweeps over the lip of
        Aragain Falls and drops away beneath you, and the rocks at the bottom
        finish what the fall began.
        """

    static let boatPuncturedOnLand = """
        Something sharp shifts against the hull, and with a loud hiss and a
        pathetic sputter the boat deflates around you — leaving you, at least,
        on dry land.
        """

    static let boatPuncturedAfloat = """
        Something sharp shifts against the hull and opens it with a hiss. The
        boat folds up beneath you, and the fierce cold current does the rest.
        """

    static let noSwimming = """
        The river is wide, fast, and studded with half-hidden rocks. Wading in
        without a boat would be a very short adventure.
        """

    static let disembarkOntoWater = """
        There is nothing here but rushing water — better to stay in the boat until
        you can land.
        """

    // MARK: - White Cliffs

    static let cliffPathTooNarrow = """
        The path along the cliffs is far too narrow to manage while you are in
        the boat. You would have to be on foot — and the boat deflated.
        """

    // MARK: - Sand & digging

    static let digWithoutShovel = "You scrabble at the sand with your hands and accomplish nothing."

    static let digProgress = "You dig, and the hole deepens. Sand keeps sliding back into it."

    static let digRevealsScarab = """
        Your shovel strikes something hard. You clear the sand away — and there, in
        the bottom of the hole, lies a jewelled scarab.
        """

    static let digCollapses = """
        You drive the shovel in one more time, and the walls of the hole give way
        all at once, pouring in over you. The sand closes above your head.
        """

    static let nothingToDigHere = "The ground here is too hard to dig."

    // MARK: - Rainbow

    static let rainbowSolidifies = """
        A shiver runs through the rainbow, and all at once it turns solid — quite
        solid enough, by the look of the stairs and the bannister, to walk upon.
        """

    static let potAppears = "A shimmering pot of gold winks into being at the rainbow's end."

    static let rainbowFades = "The rainbow shimmers and thins back to ordinary, unwalkable light."

    static let rainbowNotSolid = "The rainbow is a lovely thing to look at, but you can hardly walk on light."

    static let rainbowWaveFatal = """
        The rainbow you are standing on wavers, thins, and lets go. You have just
        time to regret it before the falls take you.
        """

    static let sceptreSparkles = "A dazzle of colour runs briefly along the sceptre, and nothing else happens."
}
