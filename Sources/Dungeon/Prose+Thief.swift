import Gnusto

/// Prose for the thief (``DungeonThief``): the man himself, his stiletto, and
/// every line the dungeon prints while he is at work in it.
///
/// The three-way rule, and the rule for which file a line goes in, are stated
/// once on ``Prose``. He belongs to no region — he walks through all of them —
/// so his lines sit beside his declaration rather than in a `Regions/` file.
///
/// `docs/games/dungeon-prose-comparison.md` files `THIEF` as **minor**: the
/// mainframe has him holding "a bag" and the trilogy "a large bag", and nothing
/// else between the two differs. Policy for `minor` is to take the trilogy
/// line, so his presence line and his examine text are Zork I's, verbatim and
/// MIT-licensed. The event lines below — arrival, theft, the fight, the death —
/// are Zork I's where Zork I has one, since the mainframe and the trilogy run
/// the same thief through the same encounter.
extension Prose {
    // MARK: - The thief

    /// Verbatim (Zork I).
    static let thief = """
        The thief is a slippery character with beady eyes that flit back
        and forth. He carries, along with an unmistakable arrogance, a large bag
        over his shoulder and a vicious stiletto, whose blade is aimed
        menacingly in your direction. I'd watch out if I were you.
        """

    /// Verbatim (Zork I), and the line the comparison document buckets as
    /// *minor*: the mainframe's is the same sentence with a plain bag.
    static let thiefPresence = """
        There is a suspicious-looking individual, holding a large bag, leaning
        against one wall. He is armed with a deadly stiletto.
        """

    static let thiefArrives = "A shadowy figure slips into the room."
    static let thiefLeaves = "The shadowy figure melts away into the dark."

    /// Written fresh, for ``Prose/trollGreeted``'s reason: the engine's
    /// placeholder — "The thief nods, and says nothing." — is a courtesy in a
    /// flat voice, and this is the one villain in the game whose courtesy is the
    /// point of him. He is not silent, he is unhurried, and the stiletto never
    /// stops being aimed the way ``thief`` says it is.
    static let thiefGreeted = """
        The thief inclines his head a fraction, without ever once taking the
        point of the stiletto off you.
        """

    /// The second state, and the source's own: `ROBBER-FUNCTION` gates a
    /// `HELLO` branch on his unconscious description being the one in place.
    static let thiefGreetedOnTheFloor = """
        The thief, being temporarily unable to hear anything at all, declines
        to be gracious about it.
        """

    static func thiefSteals(_ name: String) -> String {
        "You suddenly notice that the \(name) vanished."
    }

    // MARK: - His weapon

    /// Written fresh. The mainframe gives `STILL` a size and nothing else — no
    /// value, no description worth the name — so the line is this project's.
    static let stiletto = """
        A vicious little blade, thin as a whisper and honed to a wicked point.
        It is the thief's own, and it is quick.
        """

    // MARK: - The fight in the lair

    static let thiefMiss1 = "Your blow misses the thief by an inch."
    static let thiefMiss2 = "A good slash, but it misses the thief by a mile."
    static let thiefWound1 = "The thief is struck on the arm; blood begins to trickle down."
    static let thiefWound2 = "The thief receives a deep gash in his side."
    static let thiefKnockout = """
        The thief is battered into unconsciousness.
        """
    static let thiefDeath = """
        The thief takes a fatal blow and slumps to the floor dead.
        """

    static let thiefSwipeMiss = "The thief stabs nonchalantly with his stiletto and misses."
    static let thiefSwipeWound = "A quick thrust pinks your left arm, and blood starts to trickle down."
    static let thiefKillsYou = """
        Finishing you off, the thief inserts his blade into your heart.
        """

    /// Adapted (Zork I). The trilogy's line ends on a colon and leaves the
    /// listing to whatever the player types next, which is a promise the turn
    /// does not keep; this one names what fell. What it must not say is anything
    /// about the trap door, which in this game the thief never touched — see
    /// `FIDELITY.md`.
    ///
    /// - Parameter loot: the rendered names of everything but the stiletto.
    /// - Returns: the line, with or without the hoard.
    static func thiefLootScatters(_ loot: [String]) -> String {
        guard !loot.isEmpty else {
            return """
                As the thief dies, the power of his magic decreases. His stiletto
                clatters to the floor beside him.
                """
        }
        // One logical line: the list is as long as the bag was, so a hard wrap
        // written here would land in a different place every time.
        return "As the thief dies, the power of his magic decreases, and his treasures reappear: "
            + "\(GameText.list(loot)). His stiletto clatters to the floor beside him."
    }

    // MARK: - Giving him things

    /// Verbatim (Zork I).
    static let thiefTakesGift = """
        The thief takes it with a mocking little bow, appraises it, and makes
        it vanish somewhere about his person.
        """

    /// Verbatim (Zork I).
    static let thiefTakesEgg = """
        The thief is taken aback by your unexpected generosity, but accepts the
        jewel-encrusted egg and stops to admire its beauty.
        """
}
