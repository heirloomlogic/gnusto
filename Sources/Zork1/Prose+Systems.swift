/// Prose for the systems layer (``ZorkSystems``, ``ZorkBurden``, the liquid
/// rules, and the score ranks).
///
/// **Not all of it is the source's, and the file used to say it was.** The
/// header here claimed *"These are the authentic Zork I texts, reused under
/// license"* while most of the verb constants beneath it were modern inventions
/// — `verbSmell` was "You smell nothing you could put a name to." where
/// `V-SMELL` (`gverbs.zil:1279`) is "It smells like a X." Provenance is now
/// stated per constant: a line reproduced from the source cites its ZIL routine,
/// and a line this game wrote says nothing, because it has nothing to cite.
/// Reused source text is under the MIT grant THIRD_PARTY_NOTICES records. (#242)
///
/// The engine's **stub** verbs are next door in ``Prose/stubFloor``. The split
/// follows the mechanism: a line here backs an `action(…)` row on a verb this
/// game owns, and a line there is assigned into `text.stubs` for a verb the
/// engine already answers.
extension Prose {
    // MARK: - Verb pack: stage-4 defaults
    //
    // Each of these is the "nothing happens here" fallback for a verb of Zork's
    // own whose real mechanics arrive with a later region (the canary `wind`
    // winds, the boat `inflate` inflates). Until then the verb parses and
    // answers politely instead of "I didn't understand that."

    /// This game's own. `V-WIND` (`gverbs.zil:1608`) names the thing, and an
    /// `action(…)` row is handed no name to put in it.
    static let verbWindNothing = "That isn't something you can wind."

    /// `V-INFLATE` (`gverbs.zil:758`).
    static let verbInflateNothing = "How can you inflate that?"

    /// `V-DEFLATE` (`gverbs.zil:403`).
    static let verbDeflateNothing = "Come on, now!"

    /// `V-LAUNCH` (`gverbs.zil:805`).
    static let verbLaunchNothing = "That's pretty weird."

    /// This game's own: `V-RAISE` routes to `V-LOWER`'s `HACK-HACK`
    /// (`gverbs.zil:1132`), which names the thing and draws one of three.
    static let verbRaiseNothing = "Nothing here rises to the occasion."

    /// This game's own, for the same reason as ``verbRaiseNothing``.
    static let verbLowerNothing = "There's nothing here to lower."

    /// This game's own: the source folds `turn … with …` into `V-TURN`.
    static let verbTurnWithNothing = "Nothing here turns with that."

    /// This game's own: `V-RING` (`gverbs.zil:1163`) is a bell puzzle branch
    /// with no general refusal.
    static let verbRingNothing = "How, exactly, can you ring that?"

    /// This game's own: `V-ECHO` (`gverbs.zil:526`) is the Loud Room mechanic,
    /// which answers everywhere else by doing nothing at all.
    static let verbEcho = "Your voice comes back to you, thinner each time, and fades."

    /// `V-ADVENT` (`gverbs.zil:154`), which `xyzzy` and `plugh` both route to
    /// (`gsyntax.zil:352`). Also the stub floor's `xyzzy`.
    static let verbMagicWordInert = "A hollow voice says \"Fool.\""

    /// This game's own: `V-HELLO` (`gverbs.zil:734`) draws one of four
    /// (`HELLOS`, `:2198`), which an `action(…)` row has no stream to draw from.
    static let verbHello = "Nobody here returns your greeting."

    /// This game's own: the source has no `FIX`.
    static let verbFixNothing = "That doesn't need fixing, or can't be."

    // MARK: - Liquids

    static let waterSlipsAway = "The water slips through your fingers."

    static let bottleNeedsToBeOpen = "The bottle is closed."

    /// This game's own, for the bottle's rule. The stub floor's `fill` carries
    /// `V-FILL`'s own words (`gverbs.zil:673`).
    static let noWaterSource = "There's no water here to fill it from."

    static let bottleFilled = "The bottle is now full of water."

    static let bottleAlreadyFull = "The bottle is already full."

    static let bottleEmptied = "The water spills out and soaks away into the ground."

    /// This game's own, for the bottle's rule.
    static let nothingToPour = "There's nothing in it to pour."

    /// `HIT-SPOT` (`gverbs.zil:1321`), first person and all.
    static let drinkWater = "Thank you very much. I was rather thirsty (from all this talking, probably)."

    /// `V-EAT`'s no-water branch (`gverbs.zil:504`). Also the stub floor's
    /// `drink`.
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
