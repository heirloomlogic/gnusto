/// Original Zork I prose for the cellar region (``ZorkCellar``): East of Chasm,
/// the Gallery and its painting, the Studio and its chimney, the Troll Room,
/// and the two villains who work the region — the troll and the thief. These
/// are the authentic Zork I texts, reused under license; see THIRD_PARTY_NOTICES
/// at the repo root.
extension Prose {
    // MARK: - Cellar region

    static let eastOfChasm = """
        You are on the east edge of a chasm, the bottom of which cannot be
        seen. A narrow passage goes north, and the path you are on continues
        to the east.
        """

    static let chasm = """
        The chasm's far wall is barely visible. Nothing thrown in has
        ever been heard to land.
        """

    static let gallery = """
        This is an art gallery. Most of the paintings have been stolen by
        vandals with exceptional taste. The vandals left through either the
        north or west exits.
        """

    static let paintingFirstSight = """
        Fortunately, there is still one chance for you to be a vandal, for on
        the far wall is a painting of unparalleled beauty.
        """

    static let painting = """
        A painting by a neglected genius is here.
        """

    static let studio = """
        This appears to have been an artist's studio. The walls and floors are
        splattered with paints of 69 different colors. Strangely enough, nothing
        of value is hanging here. At the south end of the room is an open door
        (also covered with paint). A dark and narrow chimney leads up from a
        fireplace; although you might be able to get up it, it seems unlikely
        you could get back down.
        """

    static let chimney = """
        The chimney leads upward, and looks climbable.
        """

    // MARK: - The Troll Room
    //
    // Original prose only, as ever: the troll's name and his room's name
    // are fair game; Infocom's sentences are not.

    static let trollRoom = """
        This is a small room with passages to the east and south and a
        forbidding hole leading west. Bloodstains and deep scratches
        (perhaps made by an axe) mar the walls.
        """

    static let troll = """
        A nasty-looking troll, brandishing a bloody axe, blocks all passages
        out of the room.
        """

    static let trollPresence = """
        A nasty-looking troll, brandishing a bloody axe, blocks all passages
        out of the room.
        """

    static let trollBlocksTheWay = """
        The troll fends you off with a menacing gesture.
        """

    static let trollMiss1 = "Your sword misses the troll by an inch."
    static let trollMiss2 = "A good slash, but it misses the troll by a mile."
    static let trollWound1 = "The troll is struck on the arm; blood begins to trickle down."
    static let trollWound2 = "The troll receives a deep gash in his side."
    static let trollKnockout = """
        The troll is battered into unconsciousness.
        """
    static let trollDeath = """
        The troll takes a fatal blow and slumps to the floor dead.
        """

    static let axe = """
        A heavy war axe, its edge notched from long use and its head
        still dark with the troll's last argument.
        """

    static let trollSwipeMiss = "The troll swings his axe, but it misses."
    static let trollSwipeWound = "The axe gets you right in the side. Ouch!"
    static let trollKillsYou = """
        The troll neatly removes your head.
        """

    // MARK: - The thief
    //
    // Full-strength this phase: he roams the whole underground, lifts any
    // treasure, ferries it back to the Treasure Room, defends that lair to
    // the death with his stiletto, opens the egg for you if you give it to
    // him, and bars the trap door from below. See `FIDELITY.md`.

    static let thief = """
        The thief is a slippery character with beady eyes that flit back
        and forth. He carries, along with an unmistakable arrogance, a large bag
        over his shoulder and a vicious stiletto, whose blade is aimed
        menacingly in your direction. I'd watch out if I were you.
        """

    static let thiefPresence = """
        There is a suspicious-looking individual, holding a large bag, leaning
        against one wall. He is armed with a deadly stiletto.
        """

    static let thiefArrives = "A shadowy figure slips into the room."
    static let thiefLeaves = "The shadowy figure melts away into the dark."

    static func thiefSteals(_ name: String) -> String {
        "You suddenly notice that the \(name) vanished."
    }

    static let trapDoorBarred = """
        The trap door crashes shut, and you hear someone barring it.
        """

    static let thiefMiss1 = "Your sword misses the thief by an inch."
    static let thiefMiss2 = "A good slash, but it misses the thief by a mile."
    static let thiefWound1 = "The thief is struck on the arm; blood begins to trickle down."
    static let thiefWound2 = "The thief receives a deep gash in his side."
    static let thiefKnockout = """
        The thief is battered into unconsciousness.
        """
    static let thiefDeath = """
        The thief takes a fatal blow and slumps to the floor dead.
        """

    static let thiefLootScatters = """
        As the thief dies, the power of his magic decreases, and his
        treasures reappear:
        """

    // The thief's own weapon and, in his lair, his counter-attacks — he fights
    // back only there (evasive everywhere else).

    static let stiletto = """
        A vicious little blade, thin as a whisper and honed to a wicked
        point — the thief's own, and quick.
        """

    static let thiefSwipeMiss = "The thief stabs nonchalantly with his stiletto and misses."
    static let thiefSwipeWound = "A quick thrust pinks your left arm, and blood starts to trickle down."
    static let thiefKillsYou = """
        Finishing you off, the thief inserts his blade into your heart.
        """

    // Giving things to the thief.

    static let thiefTakesGift = """
        The thief takes it with a mocking little bow, appraises it, and makes
        it vanish somewhere about his person.
        """
    static let thiefTakesEgg = """
        The thief is taken aback by your unexpected generosity, but accepts the
        jewel-encrusted egg and stops to admire its beauty.
        """

    // Guarding the hoard.

    static let chaliceGuarded = """
        You'd be stabbed in the back first.
        """
}
