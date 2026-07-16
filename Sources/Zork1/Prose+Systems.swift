/// Original Zork I prose for the systems layer (``ZorkSystems``, ``ZorkBurden``,
/// the liquid rules, and the score ranks). These are the authentic Zork I
/// texts, reused under license; see THIRD_PARTY_NOTICES at the repo root.
/// Region tasks replace these generic defaults with item-scoped rules where a
/// verb actually does something.
extension Prose {
    // MARK: - Verb pack: stage-4 defaults
    //
    // Each of these is the "nothing happens here" fallback for a verb whose
    // real mechanics arrive with a later region (the shovel that makes `dig`
    // work, the canary `wind` winds, and so on). Until then the verb parses
    // and answers politely instead of "I didn't understand that."

    static let verbGiveNoTaker = "There's no one here who wants that."

    static let verbTieNothing = "There's nothing here worth tying it to."

    static let verbUntieNothing = "This cannot be tied, so it cannot be untied!"

    static let verbDigFutile = "You scrabble at the ground and turn up nothing but dirt."

    static let verbWave = "You wave it about. The air is unimpressed."

    static let verbTouch = "Touching it accomplishes nothing in particular."

    static let verbWindNothing = "That isn't something you can wind."

    static let verbInflateNothing = "How can you inflate that?"

    static let verbDeflateNothing = "Come on, now!"

    static let verbLaunchNothing = "That's pretty weird."

    static let verbRaiseNothing = "Nothing here rises to the occasion."

    static let verbLowerNothing = "There's nothing here to lower."

    static let verbTurnWithNothing = "Nothing here turns with that."

    static let verbPray = "If you pray enough, your prayers may be answered."

    static let verbRingNothing = "How, exactly, can you ring that?"

    static let verbEcho = "Your voice comes back to you, thinner each time, and fades."

    static let verbMagicWordInert = "A hollow voice says \"Fool.\""

    static let verbHello = "Nobody here returns your greeting."

    static let verbSmell = "You smell nothing you could put a name to."

    static let verbClimbNothing = "There's nothing here worth climbing. Try up or down."

    static let verbFixNothing = "That doesn't need fixing, or can't be."

    // MARK: - Liquids

    static let waterSlipsAway = "The water slips through your fingers."

    static let bottleNeedsToBeOpen = "The bottle is closed."

    static let noWaterSource = "There's no water here to fill it from."

    static let bottleFilled = "The bottle is now full of water."

    static let bottleAlreadyFull = "The bottle is already full."

    static let bottleEmptied = "The water spills out and soaks away into the ground."

    static let nothingToPour = "There's nothing in it to pour."

    static let drinkWater = "Thank you very much. I was rather thirsty (from all this talking, probably)."

    static let nothingToDrink = "There isn't any water here."

    // MARK: - Burden

    static let handsFull = """
        You're holding too many things already!
        """

    static let chimneyTooBurdened = """
        You can't get up there with what you're carrying.
        """

    // MARK: - Lantern (third fuse)

    static let lanternLastGasp = """
        The lamp is nearly out.
        """

    // MARK: - Death & resurrection

    static let resurrection = """
        Now, let's take a look here... Well, you probably deserve another
        chance. I can't quite fix you up completely, but you can't have
        everything.
        """

    // MARK: - Diagnose

    static let diagnoseUnscathed = """
        You are in perfect health.
        """

    /// A report on how many times the adventurer has been killed and how many
    /// resurrections the unseen power will still grant. `deaths` is at least 1.
    static func diagnoseDeaths(_ deaths: Int, resurrectionsLeft: Int) -> String {
        let times = deaths == 1 ? "once" : "\(deaths) times"
        let left =
            resurrectionsLeft == 0
            ? "You sense you will not be spared a next time."
            : resurrectionsLeft == 1
                ? "You feel you could survive being killed one more time."
                : "You feel you could survive being killed \(resurrectionsLeft) more times."
        return "You have been killed \(times). \(left)"
    }

    // MARK: - Score ranks

    static func rankLine(_ rank: String) -> String {
        "This gives you the rank of \(rank)."
    }
}
