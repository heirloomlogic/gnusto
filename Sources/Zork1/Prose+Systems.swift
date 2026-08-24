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

    /// This game's own. `V-WIND` (`gverbs.zil:1608`) is "You cannot wind up a
    /// X.", which a row **can** now name — ``ZorkSystems/playWith(_:)`` does
    /// exactly that for `raise` and `lower` — but only at the cost of the
    /// source's indefinite article, which no named line in the engine deals in.
    /// `raise` and `lower` paid it because their lines were false in a room with
    /// a rope in it; this one is about the thing already and the canary claims
    /// the verb wherever winding is the puzzle, so the reproduction would buy a
    /// departure and reach nobody. #325 corrected the reason, which used to be
    /// that a row is handed no name.
    static let verbWindNothing = "That isn't something you can wind."

    /// `V-INFLATE` (`gverbs.zil:758`).
    static let verbInflateNothing = "How can you inflate that?"

    /// `V-DEFLATE` (`gverbs.zil:403`).
    static let verbDeflateNothing = "Come on, now!"

    /// `V-LAUNCH` (`gverbs.zil:805`).
    static let verbLaunchNothing = "That's pretty weird."

    /// `V-LOWER` (`gverbs.zil:902`), which `V-RAISE` calls outright (`:1131`):
    /// `HACK-HACK "Playing in this way with the "`, finished by one of
    /// `HO-HUM`'s three (`:2035`). This takes the third, as `touch` and `wave`
    /// do in the stub floor; the draw is recorded in `FIDELITY.md`.
    ///
    /// A `raise`/`lower` row is handed the object, so the sentence is about the
    /// thing rather than about the room — which is the whole repair. The two
    /// invented lines it replaces claimed there was nothing here to raise or
    /// lower while the rope hung over the Dome Room rail. (#325)
    static func playingWithIt(_ name: String) -> String {
        "Playing in this way with \(name) has no effect."
    }

    /// `V-TURN` (`gverbs.zil:1506`). `TURN OBJECT WITH OBJECT` is one of the six
    /// syntax rows that reach it (`gsyntax.zil:505`), so `turn bolt with wrench`
    /// away from the dam answers in the source's words rather than in an
    /// invented claim about the room. Also the stub floor's `turn`.
    static let verbTurnNoEffect = "This has no effect."

    /// This game's own: `V-RING` (`gverbs.zil:1163`) is a bell puzzle branch
    /// with no general refusal.
    static let verbRingNothing = "How, exactly, can you ring that?"

    /// This game's own: `V-ECHO` (`gverbs.zil:526`) is the Loud Room mechanic,
    /// which answers everywhere else by doing nothing at all.
    static let verbEcho = "Your voice comes back to you, thinner each time, and fades."

    /// `V-ADVENT` (`gverbs.zil:154`), which `xyzzy` and `plugh` both route to
    /// (`gsyntax.zil:352`). Also the stub floor's `xyzzy`.
    static let verbMagicWordInert = "A hollow voice says \"Fool.\""

    /// `V-KNOCK`'s door branch (`gverbs.zil:767`). Read from two places — the
    /// game-wide `.knock` rule, which is what knows a door from a bench, and
    /// the stub floor's bare half — so it is a constant rather than a literal
    /// in either.
    static let verbKnockDoor = "Nobody's home."

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
