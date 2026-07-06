/// Placeholder prose for the systems layer (``ZorkSystems``, ``ZorkBurden``,
/// the liquid rules, and the score ranks). Same ledger rule as everywhere
/// else: the verb *words* the player types are the iconic ones, but every
/// response line below is original text — Infocom's joke responses ("A hollow
/// voice says 'Fool.'", "You feel a wave of nausea") are deliberately not
/// reproduced. Region tasks replace these generic defaults with item-scoped
/// rules where a verb actually does something.
extension Prose {
    // MARK: - Verb pack: stage-4 defaults
    //
    // Each of these is the "nothing happens here" fallback for a verb whose
    // real mechanics arrive with a later region (the shovel that makes `dig`
    // work, the canary `wind` winds, and so on). Until then the verb parses
    // and answers politely instead of "I didn't understand that."

    static let verbGiveNoTaker = "There's no one here who wants that."

    static let verbTieNothing = "There's nothing here worth tying it to."

    static let verbUntieNothing = "It isn't tied to anything."

    static let verbDigFutile = "You scrabble at the ground and turn up nothing but dirt."

    static let verbWave = "You wave it about. The air is unimpressed."

    static let verbTouch = "Touching it accomplishes nothing in particular."

    static let verbWindNothing = "That isn't something you can wind."

    static let verbInflateNothing = "There's nothing here to inflate — and nothing to inflate it with."

    static let verbDeflateNothing = "Nothing here is inflated."

    static let verbLaunchNothing = "You can't launch that."

    static let verbRaiseNothing = "Nothing here rises to the occasion."

    static let verbLowerNothing = "There's nothing here to lower."

    static let verbTurnWithNothing = "Nothing here turns with that."

    static let verbPray = "Your prayers echo unanswered off the cold stone."

    static let verbRingNothing = "There's nothing here to ring."

    static let verbEcho = "Your voice comes back to you, thinner each time, and fades."

    static let verbMagicWordInert = "The word hangs in the air a moment, then means nothing at all."

    static let verbHello = "Nobody here returns your greeting."

    static let verbSmell = "You smell nothing you could put a name to."

    // MARK: - Liquids

    static let waterSlipsAway = "The water slips between your fingers. You'll need something to hold it."

    static let bottleNeedsToBeOpen = "The bottle is closed."

    static let noWaterSource = "There's no water here to fill it from."

    static let bottleFilled = "The bottle is now full of water."

    static let bottleAlreadyFull = "The bottle is already full."

    static let bottleEmptied = "The water spills out and soaks away into the ground."

    static let nothingToPour = "There's nothing in it to pour."

    static let drinkWater = "You drink the water. The bottle is empty now."

    static let nothingToDrink = "There's nothing here to drink."

    // MARK: - Burden

    static let handsFull = """
        Your load is already as much as you can manage; you'll have to drop
        something first.
        """

    static let chimneyTooBurdened = """
        The chimney is too tight to climb with your hands this full. You can
        take no more than a couple of things up it.
        """

    // MARK: - Lantern (third fuse)

    static let lanternLastGasp = """
        The lantern's light gutters down to a dull ember. Whatever you mean
        to do by its glow, do it now.
        """

    // MARK: - Death & resurrection

    static let resurrection = """
        As the darkness closes in, an unseen power takes pity on you. The
        world lurches, the cold recedes, and you find yourself standing once
        more beneath the open sky, your belongings strewn about the grounds.
        """

    // MARK: - Score ranks

    static func rankLine(_ rank: String) -> String {
        "This earns you the rank of \(rank)."
    }
}
