/// Prose for the Frigid River and the country it drains into (``DungeonRiver``):
/// the five stretches of water below Flood Control Dam #3, the White Cliffs
/// beaches on the east bank, the sandy beach and the shore on the west, Aragain
/// Falls and its rainbow, the End of Rainbow at the bottom of the canyon, and
/// the rocky western approach — Rocky Shore, the Small Cave and the Ancient
/// Chasm — that reaches the water on foot from the Loud Room.
///
/// The three-way rule (trilogy verbatim / trilogy adapted / written fresh) is
/// stated once on ``Prose``; each constant below says which of the three it is.
///
/// The mainframe river is not Zork I's river, and the prose has to say so:
/// **the White Cliffs stand on the east bank and the beaches on the west**,
/// exactly reversed from the trilogy, so every line that names a bank is
/// adapted rather than lifted. There is also no Sandy Cave and no buried
/// scarab: the shovel lies in the Small Cave on the western approach, and what
/// the sand on the beach gives up is a statue.
extension Prose {
    // MARK: - The five stretches

    /// Trilogy verbatim (`minor`). The landing on the west shore is the Dam
    /// Base, which is where the mainframe puts it too.
    static let river1 = """
        You are on the Frigid River in the vicinity of the Dam. The river flows
        quietly here. There is a landing on the west shore.
        """

    /// Trilogy verbatim (`identical`). Both sources put the cliffs east.
    static let river2 = """
        The river turns a corner here making it impossible to see the Dam. The
        White Cliffs loom on the east bank and large rocks prevent landing on the
        west.
        """

    /// Trilogy adapted (`substantial`). Zork I has one beach, on the west below
    /// the cliffs; the mainframe has a beach **east** under the cliffs and open
    /// shore **west**, and both are exits here.
    static let river3 = """
        The river descends here into a valley. There is a narrow beach on the
        east below the cliffs, and some shore on the west which may be suitable.
        In the distance a faint rumbling can be heard.
        """

    /// Trilogy adapted (`substantial`). The banks are swapped: the sandy beach
    /// is west and the cliffs' strip of beach east.
    static let river4 = """
        The river is running faster here and the sound ahead appears to be that
        of rushing water. On the west shore is a sandy beach. A small area of
        beach can also be seen below the cliffs.
        """

    /// Trilogy adapted (`minor`, and the bucket is wrong about it). The two
    /// lines differ by one compass point, and that point is the landing this
    /// game's only exit off River-5 leads to — the west shore, not the east.
    static let river5 = """
        The sound of rushing water is nearly unbearable here. On the west shore
        is a large landing area.
        """

    /// Written fresh. The mainframe blocks upstream travel from every stretch.
    static let noRowingUpstream = "You cannot go upstream against so strong a current."

    /// Written fresh. River-1 and River-2 refuse the east bank outright.
    static let cliffsPreventLanding = "The White Cliffs prevent your landing here."

    /// Written fresh. River-3 and River-4 have a bank on either side, so a bare
    /// `land` has nothing to choose between.
    static let landWhichWay = "There are banks on both sides. Say which one you mean."

    /// Written fresh. The one thing downstream of River-5.
    static let overTheFalls = """
        The boat is swept over the lip of Aragain Falls and drops four hundred
        and fifty feet onto the rocks below, taking you with it. The view on the
        way down is said to be magnificent.
        """

    // MARK: - The banks

    /// Trilogy adapted (`substantial`). Zork I bores a passage west through the
    /// cliffs into the Damp Cave; the mainframe leaves the wall solid, so the
    /// only ways off this beach are the path south and the water.
    static let whiteCliffsNorth = """
        You are on a narrow strip of beach which runs along the base of the White
        Cliffs. The only path here is a narrow one, heading south along the
        Cliffs.
        """

    /// Trilogy verbatim. Same beach, same one path, in both.
    static let whiteCliffsSouth = """
        You are on a rocky, narrow strip of beach beside the Cliffs. A narrow
        path leads north along the shore.
        """

    /// Written fresh. The mainframe gates the cliff path on the boat being
    /// packed away rather than on your being out of it, so a player standing on
    /// the sand with a firm boat in hand is refused.
    static let cliffPathTooNarrow = """
        The path is too narrow to take the boat along it.
        """

    /// Trilogy adapted (`substantial`). The trilogy's beach is on the east
    /// shore and has a passage buried in the sand to the northeast; the
    /// mainframe's is west and has neither.
    static let sandyBeach = """
        You are on a large sandy beach at the shore of the river, which is
        flowing quickly by. A path runs beside the river to the south here.
        """

    /// Trilogy adapted (`minor`, and the bucket is wrong about it again). The
    /// trilogy says "east shore"; in this game the shore is the west one.
    static let shore = """
        You are on the shore of the river. The water here seems somewhat
        treacherous. A path travels from north to south here, the south end
        quickly turning around a sharp corner.
        """

    // MARK: - The falls and the rainbow

    /// Trilogy verbatim, for the part of Aragain Falls that never changes. The
    /// rainbow's own line follows from ``fallsRainbowSolid`` /
    /// ``fallsRainbowVapor``.
    static let aragainFalls = """
        You are at the top of Aragain Falls, an enormous waterfall with a drop of
        about 450 feet. The only path here is on the north end.
        """

    /// Written fresh. The stub floor's `listen` reports on the listener — "You
    /// listen, and learn nothing you did not already know." — which is the
    /// right sentence in 195 rooms and the wrong one at the top of a 450-foot
    /// waterfall. Same repair the Loud Room already has: where the room really
    /// does own the answer, the room takes the verb back.
    static let fallsSound = """
        Four hundred and fifty feet of water arriving at the bottom. Anything else in this room would have to
        shout.
        """

    /// Trilogy verbatim.
    static let fallsRainbowSolid = "A solid rainbow spans the falls."

    /// Trilogy adapted. The trilogy's rainbow reaches west from the falls; this
    /// one reaches east, because the End of Rainbow is east of here.
    static let fallsRainbowVapor = """
        A beautiful rainbow can be seen over the falls and to the east.
        """

    /// Trilogy verbatim (`minor`). The mainframe adds a joke about an NBC
    /// commissary standing on the rainbow, which is 1981 text and not
    /// reproduced.
    static let rainbowRoom = """
        You are on top of a rainbow (I bet you never thought you would walk on a
        rainbow), with a magnificent view of the Falls. The rainbow travels
        east-west here.
        """

    /// Trilogy adapted (`minor`, exits again). The trilogy's rainbow crosses to
    /// the east and its path continues southwest; here the falls are west and
    /// the path to Canyon Bottom runs southeast.
    static let endOfRainbow = """
        You are on a small, rocky beach on the continuation of the Frigid River
        past the Falls. The beach is narrow due to the presence of the White
        Cliffs. The river canyon opens here and sunlight shines in from above. A
        rainbow crosses over the falls to the west and a narrow path continues to
        the southeast.
        """

    /// Trilogy verbatim. Waving the stick at either end wakes the rainbow.
    static let rainbowSolidifies = """
        Suddenly, the rainbow appears to become solid and, I venture, walkable (I
        think the giveaway was the stairs and bannister).
        """

    /// Trilogy verbatim.
    static let rainbowFades = "The rainbow seems to have become somewhat run-of-the-mill."

    /// Written fresh. Waving the stick while standing on the rainbow takes the
    /// rainbow away from under you, which the mainframe finds funny and fatal.
    static let rainbowWaveFatal = """
        The rainbow loses whatever it was that held it up, and so, four hundred
        and fifty feet above the river, do you.
        """

    /// Written fresh. The rainbow is not solid, and stepping onto it knows it.
    static let rainbowNotSolid = "You cannot walk on water vapor."

    /// Written fresh. Two hundred feet of falling water is not an exit.
    static let fallsAreALongWayDown = "It is a very long way down."

    /// Written fresh. Every other room takes a wave with a shrug; these two do
    /// not, and the stick has to say so somewhere.
    static let stickWavedIdly = "The stick whistles through the air and nothing answers it."

    // MARK: - The broken sharp stick

    /// Written fresh — mainframe-only, and this game's sceptre. The trilogy
    /// splits the two jobs between a sceptre and a whole class of sharp things;
    /// here one stick does both.
    static let stick = """
        A stick about as long as your forearm, snapped off short at one end and
        left with a point on it. Somebody once thought it was worth breaking.
        """

    /// Written fresh.
    static let stickInPlace = "There is a broken sharp stick here."

    // MARK: - The western approach

    /// Written fresh — mainframe-only. The shore the Loud Room's crawl comes
    /// out on, and the only launching point on the west bank.
    static let rockyShore = """
        You are on the west shore of the river. The shore is very rocky here,
        and the mouth of a cave opens to the northwest.
        """

    /// Written fresh — mainframe-only.
    static let smallCave = """
        This is a small cave, low and dry, whose exits are to the south and the
        northwest.
        """

    /// Written fresh — mainframe-only. The chasm this cave is cut by is not
    /// the Chasm of milestone 1, and the room says which one it is.
    static let ancientChasm = """
        A chasm cut by some river long since gone runs through the cave here.
        Passages lead off in every direction.
        """

    /// Written fresh — mainframe-only. These two dead ends are nowhere near the
    /// maze, so they do not borrow the maze's line.
    static let chasmDeadEnd = """
        The passage narrows and then stops altogether against blank rock.
        """

    // MARK: - The boat

    /// Trilogy verbatim.
    static let pileOfPlastic = """
        There is a folded pile of plastic here which has a small valve attached.
        """

    /// Trilogy verbatim.
    static let magicBoat = """
        It is a small plastic boat, taut and seaworthy, easily large enough to
        carry you and a fair load of cargo down the river.
        """

    /// Written fresh.
    static let puncturedBoat = """
        It is a sorry, sagging ruin of a boat, whistling gently through the hole
        somebody put in it.
        """

    /// Trilogy verbatim.
    static let tanLabelInBoat = "A tan label is lying inside the boat."

    /// Written fresh, for the label the puncture tipped onto the bank.
    static let tanLabelOnGround = "There is a tan label here."

    /// Written fresh, in the voice of the trilogy's own boat label — the
    /// manufacturer's warnings, one of which is the puzzle.
    static let tanLabel = """
        !!!! FROBOZZ MAGIC BOAT COMPANY !!!!

        Hello, Sailor!

        Instructions for use:

           To get into a body of water, say "Launch".
           To get to shore, say "Land" or the direction in which you want
           to maneuver the boat.

        Warranty: This boat is guaranteed against all defects for a period of
        76 milliseconds from date of purchase or until first used, whichever
        comes first.

        Warning: This boat is made of thin plastic. Keep sharp objects, such as
        broken sticks, out of the boat at all times.
        """

    /// Trilogy verbatim.
    static let boatInflates = "The boat inflates and appears seaworthy."

    /// Trilogy verbatim.
    static let inflateNotOnGround = "The boat must be on the ground to be inflated."

    /// Trilogy verbatim.
    static let boatAlreadyFirm = "Inflating it further would probably burst it."

    /// Trilogy verbatim — the mainframe's answer to blowing into the valve.
    static let inflateNeedsPump = "You don't have enough lung power to inflate it."

    /// Written fresh, for anything else offered as a pump.
    static func inflateWithWrongThing(_ thing: String) -> String {
        "With \(thing)? Surely you jest!"
    }

    /// Trilogy verbatim.
    static let boatDeflates = "The boat deflates."

    /// Trilogy verbatim.
    static let deflateWhileAboard = "You can't deflate the boat while you're in it."

    /// Trilogy verbatim.
    static let deflateNotOnGround = "The boat must be on the ground to be deflated."

    /// Written fresh. The broken sharp stick is the only thing in this game
    /// that holes the boat, and it does it on the way in rather than by
    /// shifting against the hull.
    static let boatHissesFlat = "There is a hissing sound and the boat deflates."

    /// Trilogy verbatim.
    static let boatPatched = "Well done. The boat is repaired."

    /// Written fresh. The gunk in the tube is the only thing that patches it.
    static let boatNeedsPutty = "That will not close a hole in plastic."

    /// Trilogy verbatim.
    static let boatWillNotInflate = """
        This boat will not inflate since some moron put a hole in it.
        """

    /// Trilogy verbatim.
    static let launchNotAboard = "You're not in the boat!"

    /// Written fresh.
    static let launchNoWater = "There is no water here to launch it into."

    /// Written fresh. The End of Rainbow is the one shore the source refuses to
    /// let a boat off.
    static let launchRocksTooSharp = "The sharp rocks endanger your boat."

    /// Written fresh.
    static let boatLaunches = "The boat slips off the bank and out onto the moving water."

    /// Written fresh.
    static let nothingToLaunch = "You have nothing here that floats."

    /// Written fresh.
    static let landNoBoat = "You are not in anything that needs landing."

    /// Trilogy verbatim.
    static let disembarkOntoWater = "You realize that getting out here would be fatal."

    /// Written fresh. The mainframe declines the swim everywhere in the game,
    /// so this line is filed with the water that provokes it most.
    static let noSwimming = "Swimming would be a brief and unrewarding career."

    /// Written fresh, filed here for ``noSwimming``'s reason, and deliberately
    /// the same *shape* of sentence: a claim about the diver, not about the
    /// room. `.dive` is `.swim`'s twin and had no row in ``DungeonSystems`` at
    /// all, so it answered on the engine's stub — "There's nothing here to dive
    /// into." — which is a claim about the room, and which the 2026-08-11 round
    /// caught standing on top of a dam holding back a reservoir. (#233)
    static let noDiving = "Diving in would end the expedition rather than advance it."

    /// Written fresh. River-2 runs between rocks on one side and the White
    /// Cliffs on the other, and has no bank at all.
    static let landNowhereHere = "There is nowhere here to put in."

    // MARK: - The buoy and what is in it

    /// Trilogy verbatim — the listing line, and only the listing line. It used
    /// to be the examine channel too, which had `x buoy` answering "There is a
    /// red buoy here" about a buoy in the player's hands.
    static let buoy = "There is a red buoy here (probably a warning)."

    /// Written fresh, because the trilogy has no separate examine line to take.
    static let buoyExamined = """
        A red plastic buoy the size of a small barrel, of the kind that is
        probably a warning about something.
        """

    /// Trilogy verbatim — the nudge that stops the buoy being scenery.
    static let buoyFeelsFunny = "You notice something funny about the feel of the buoy."

    /// Written fresh.
    static let emerald = """
        The emerald is enormous and deep green, and it has been cut by somebody
        who knew exactly what they were doing.
        """

    /// Written fresh.
    static let emeraldInPlace = "There is a large emerald here."

    // MARK: - The sand, the shovel and the statue

    /// Written fresh.
    static let sand = "It is sand: fine, pale, and deep."

    /// Trilogy verbatim.
    static let shovelInPlace = "There is a shovel here."

    /// Written fresh.
    static let shovel = """
        It is a plain, sturdy shovel, its blade still keen enough to bite into
        packed sand.
        """

    /// Trilogy verbatim, adapted only to take the thing named.
    static func digSilly(_ tool: String) -> String {
        "Digging with \(tool) is silly."
    }

    /// Written fresh.
    static let digWithoutTool = "Digging with your bare hands accomplishes nothing."

    /// Trilogy verbatim — the three lines before the sand gives anything up.
    static let beachDigs = [
        "You seem to be digging a hole here.",
        "The hole is getting deeper, but that's about it.",
        "You are surrounded by a wall of sand on all sides.",
    ]

    /// Trilogy verbatim.
    static let digRevealsStatue = "You can see a small statue here in the sand."

    /// Trilogy verbatim.
    static let digCollapses = "The hole collapses, smothering you."

    /// Written fresh.
    static let statue = """
        A small statue of a robed figure, carved from something pale and heavy.
        Whoever buried it took some trouble over it.
        """

    /// Written fresh.
    static let statueInPlace = "There is a beautiful statue here."

    /// Written fresh — mainframe-only. Three futile digs and then the game
    /// says so plainly.
    static let guanoDigs = [
        "You dig into the guano and find more guano.",
        "The guano yields, reluctantly, to more guano.",
        "There is a great deal of guano here, and it is all the same.",
    ]

    /// Written fresh.
    static let guanoDigsPointless = "This is getting you nowhere."

    /// Written fresh.
    static let guano = """
        A hunk of bat guano, dropped here by generations of the Bat Room's
        tenant and no more use to you than to it.
        """

    /// Written fresh.
    static let guanoInPlace = "There is a hunk of bat guano here."

    // MARK: - The barrel

    /// Written fresh — mainframe-only. A man-sized barrel at the lip of the
    /// falls, which exists so that somebody can get into it.
    static let barrelInPlace = """
        There is a man-sized barrel here which you might be able to enter.
        """

    /// Written fresh.
    static let barrel = """
        It is a stout wooden barrel, big enough to hold a person, and somebody
        has cut a word into the staves: 'Geronimo!'
        """

    /// Written fresh — the view from inside it.
    static let barrelInside = """
        You are inside a barrel. Congratulations. From where you are sitting you
        cannot see the falls at all.
        """

    /// Written fresh. What Aragain Falls answers about anything outside the
    /// barrel while the player is down inside it. ``barrelInside`` says the
    /// falls cannot be seen from in there and the falls, the rainbow over them
    /// and the path off the ledge were plain scenery with no guard, so each of
    /// them answered in full one command after the room said they could not be
    /// seen. This is an ``Item/reach(otherwise:)`` refusal, which runs at stage
    /// 0 and so arrives ahead of any verb's own complaint. (#286)
    static let barrelBlocksTheView = """
        Not from in here. There is a good deal of barrel between you and the
        rest of Aragain Falls.
        """

    /// Written fresh. The mainframe's own line here names a historical person
    /// as a punchline; this one keeps the joke and drops the person.
    ///
    /// It also makes no claim about where it is being shouted. The `action(…)`
    /// row that prints it is game-wide, so the sentence has to be true in all
    /// 196 rooms — and the version that stood here said *"there is nothing here
    /// to leap from"* in the one room in the game that is a 450-foot drop, with
    /// the word cut into the staves of the barrel standing beside the player.
    /// The joke is that a cry is all it is; the joke does not need a place.
    static let geronimoNotInBarrel = """
        A fine battle cry, and that is the whole of it.
        """

    /// Written fresh.
    static let barrelGoesOver = """
        The barrel tips over the lip of the falls, and for about six seconds it
        is the finest ride in the Great Underground Empire.
        """

    /// Written fresh.
    static let barrelTooHeavy = "The barrel is far too heavy to move."

    /// Written fresh.
    static let barrelTooDamp = "The barrel is damp and will not burn."

    // MARK: - The pot of gold

    /// Trilogy verbatim.
    static let potOfGoldInPlace = "At the end of the rainbow is a pot of gold."

    /// Written fresh.
    static let potOfGold = """
        A pot of gold, filled to the brim, exactly as advertised. The rainbow
        appears to have been telling the truth.
        """

    // MARK: - Scenery

    /// Written fresh.
    static let frigidRiverHere = """
        The Frigid River lives up to its name, and it is in a hurry.
        """

    /// Written fresh.
    static let whiteCliffsFromBelow = """
        The White Cliffs go up and up, pale as bone, and there is no climbing
        them from here.
        """

    /// Written fresh.
    static let aragainFallsItself = """
        Four hundred and fifty feet of the Frigid River going somewhere else in
        a great deal of hurry.
        """

    /// Written fresh — an ordinary rainbow, which is what it is until the
    /// stick has been waved at it.
    static let rainbowItself = """
        A rainbow over the falls, and nothing more remarkable than that.
        """

    /// Written fresh — and what it is afterwards.
    static let rainbowSolidItself = """
        A rainbow over the falls, and the light in it is doing something light
        does not usually do. There are stairs in it, and a bannister.
        """

    /// Written fresh.
    static let riverCanyonHere = """
        The canyon walls open here and let the daylight down.
        """

    /// Written fresh.
    static let caveMouth = """
        A dark opening in the rock, about the size of a person who wants to get
        out of the rain.
        """

    /// Written fresh. The same mouth from the shore below it, where the river
    /// used to answer for the word. (#286)
    static let caveMouthFromTheShore = """
        A low opening at the top of the rocks, dark a foot inside and out of
        the weather, which is more than the shore is.
        """

    /// Written fresh. The ground the End of Rainbow puts under the player, and
    /// the reason there is so little of it. (#286)
    static let endOfRainbowBeach = """
        A rind of wet shingle between the water and the cliffs, wide enough to
        stand on and not much wider.
        """

    /// The six bank paths, one line each. Every one of them is a beaten track
    /// and the whole of what differs is where it goes, which is what an examine
    /// of the word is asking. (#286)
    static let pathAtNorthBeach = """
        A single narrow track along the foot of the cliffs, going south. There
        is no other way off this beach on foot.
        """

    static let pathAtSouthBeach = """
        A single narrow track along the foot of the cliffs, going north above
        the waterline.
        """

    static let pathAtSandyBeach = """
        A track pressed into the sand beside the water, running south out of
        the beach.
        """

    static let pathAtShore = """
        A track along the shore, north to the sand and south around a corner
        sharp enough to hide whatever is past it.
        """

    static let pathAtFalls = """
        A track leaving by the north end of the ledge, which is the only way
        off it that does not involve the falls.
        """

    static let pathAtEndOfRainbow = """
        A narrow track leaving the shingle to the southeast, climbing as it
        goes.
        """

    /// The hole in the beach, in its two states. Written fresh; the mainframe
    /// prints the digging and models nothing to look at afterwards. (#286)
    static let beachHoleShallow = """
        A scoop out of the wet sand, and the sides of it coming back in almost
        as fast as you take them out.
        """

    static let beachHoleDeep = """
        Deep enough now that the sand stands over your head on every side, and
        none of it looks like staying there.
        """

    /// Written fresh.
    static let ancientChasmItself = """
        The chasm is deep, dry and old. Whatever cut it has been gone a long
        time.
        """

    /// Written fresh.
    static let deadEndWall = "Rock, and more rock behind it."
}
