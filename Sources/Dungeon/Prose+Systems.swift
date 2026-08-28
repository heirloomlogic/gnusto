import Gnusto

/// The systems layer's prose: the game's own front matter, the defaults for the
/// verbs this game minted, the liquid lines, and the handful of stock engine
/// messages this game re-voices.
///
/// The engine's **stub** verbs are next door in ``Prose/stubFloor``. The split
/// follows the mechanism: a line here backs an `action(…)` row on a verb this
/// game owns, and a line there is assigned into `text.stubs` for a verb the
/// engine already answers. (#233)
///
/// The three-way rule, and the rule for which file a line goes in, are stated
/// once on ``Prose``.
extension Prose {
    // MARK: - Front matter

    static let intro = """
        Somewhere under a white house on a forgotten lawn lies the Great
        Underground Empire — a dam, a temple, a coal mine, a river, a volcano,
        a bank, and a maze that was old when the Empire fell. There are
        treasures down there, and a trophy case up here to put them in, and a
        good many things between the two that would rather you did not.
        """

    // MARK: - Verb defaults

    static let verbWindNothing = "You cannot wind that up."

    static let verbWave = "You wave. Nothing happens."

    static let verbTouch = "You feel nothing unexpected."

    /// Said anywhere nothing is asking a question — which, until the endgame,
    /// is everywhere. It is the same line for every word, so `answer skeleton`
    /// and `answer banana` are indistinguishable and the Dungeon Master's
    /// answer key cannot be read off the parser.
    static let verbAnswerNothingListening = """
        Nothing here is waiting on an answer.
        """

    /// Re-voiced. This constant used to be the engine's `GameText.stubs.smell`
    /// character for character, so the row installing it in ``DungeonSystems``
    /// re-voiced nothing at all while the survey counted `smell` as done. The
    /// two rooms in the game whose descriptions are *about* a smell answer for
    /// themselves in ``DungeonCoalMine``; this is what is left over. (#233)
    ///
    /// **Re-voiced again for the 2026-08-18 round's D9**, and this time the
    /// subject moved. It used to read "Nothing here smells of anything in
    /// particular." — a claim about the room, printed unchanged in ~194 of
    /// them, so the two rooms with rules were the only two it could ever be
    /// true of by inspection. A bare command has no object to be about, so the
    /// line has to be about the player instead; that is the same move
    /// `stubs.climb`'s bare half makes, and for the same reason.
    static let verbSmell = "You smell nothing worth reporting."

    static let verbPray = "Nothing in particular answers."

    /// `V-KNOCK`'s door branch (`gverbs.zil:766`), adapted. The source says
    /// "Nobody's home."; this game is played mostly below ground, where nobody
    /// was ever home and the joke is the wrong one, so the door answers for its
    /// own emptiness instead. Read from the game-wide `.knock` rule and from
    /// the stub floor's bare half, so it is a constant rather than a literal in
    /// either.
    static let verbKnockDoor = "You knock, and nobody answers."

    static let verbMagicWordInert = "A hollow voice says nothing at all."

    static let verbEcho = "The word bounces off the walls and comes back unchanged."

    static let verbTurnWithNothing = "You cannot turn that with that."

    static let verbPlugNothing = "That is not leaking."

    static let verbRingNothing = "There is no ringing that."

    static let verbMeltNothing = "You can't melt that."

    static let verbExorciseNothing = "There is nothing here that needs banishing."

    static let verbRaiseNothing = "You can't raise that."

    static let verbLowerNothing = "You can't lower that."

    static let verbInflateNothing = "You can't inflate that."

    static let verbDeflateNothing = "You can't deflate that."

    /// `V-THROUGH`'s last line, trilogy-verbatim (`gverbs.zil:1438`; the
    /// mainframe's is `act3.199:450`). One verb answers `enter` and `go
    /// through` both, so its refusal has to be true of a thing that is no
    /// vehicle *and* no doorway — which is what this is, and what the Bank's
    /// old "It is solid, and you are not." was not, since it went with a
    /// private `walkThrough` verb that only ever met walls. (#233)
    static func cantEnterThat(_ thing: GameText.Noun) -> String {
        "You hit your head against \(thing) as you attempt this feat."
    }

    // MARK: - Liquids

    static let waterSlipsAway = "The water slips through your fingers."

    /// The two lines the bottle's own rules fall to, where they are true: they
    /// answer for the *water*, and the water is only ever in the bottle. Not to
    /// be confused with ``cantDrinkThat`` and ``cantPourThat`` below, which are
    /// ``DungeonSystems``' game-wide last resort and had to stop being claims
    /// about the room.
    static let nothingToDrink = "There is nothing here to drink."

    static let nothingToPour = "There is nothing here to pour."

    /// The three game-wide refusals, re-voiced as claims about the **thing
    /// named** rather than about the room. They are ``DungeonSystems``'
    /// stage-4 answers, printed in all 196 rooms — and "There is nothing here
    /// to drink." printed in the twenty this game flags ``TraitKey/waterSource``,
    /// where the bottle fills in the same breath because `bottle.before(.fill)`
    /// already reads the predicate.
    ///
    /// This is ``Prose/noSwimming``'s repair generalised: a sentence about the
    /// swimmer survives every room, and a sentence about the room does not.
    /// What *is* drinkable, pourable or fillable claims the command at stage 3,
    /// ahead of these. (#233)
    static let cantDrinkThat = "That is not something you could drink."

    static let cantPourThat = "That is not something you could pour."

    /// ``DungeonHouse/bottle`` claims every `fill bottle` at stage 3, held or on
    /// the table, so the only thing that reaches this line is something that
    /// does not hold liquid — and telling its owner there is no water here,
    /// standing on top of the dam, answered the wrong question wrongly.
    static let cantFillThat = "That is not something you could fill."

    static let bottleNeedsToBeOpen = "The bottle is closed."

    static let bottleAlreadyFull = "The bottle is already full of water."

    static let drinkWater = "Thank you very much. It really hit the spot."

    static let bottleEmptied = "The water spills out and is quickly gone."

    static let noWaterSource = "There is no water here to fill it from."

    static let bottleFilled = "The bottle is now full of water."

    // MARK: - Burden

    static let handsFull = """
        Your load is too great for that. You will have to put something down
        first.
        """

    // MARK: - Diagnose

    /// Wounds are not modelled — the melee plugin tracks the villain's health,
    /// not yours — so the report counts deaths, and this is the answer before
    /// there are any.
    static let diagnoseUnscathed = """
        You have not been killed yet, which is more than most of your
        predecessors managed.
        """

    static func diagnoseDeaths(_ deaths: Int, resurrectionsLeft: Int) -> String {
        let toll =
            deaths == 1
            ? "You have been killed once."
            : "You have been killed \(deaths) times."
        let mercy =
            resurrectionsLeft > 0
            ? "You may expect to be put back together once more, and no oftener."
            : "Whatever has been putting you back together is out of patience."
        return "\(toll) \(mercy)"
    }

    // MARK: - Death and resurrection

    /// Adapted. The mainframe's resurrection dumps you back among the trees,
    /// lighter by ten points and by everything you were carrying.
    static let resurrection = """
        As you take your last breath, you feel relieved of your burdens. The
        feeling passes as a peculiar sensation of falling overtakes you, and
        you find yourself standing among the trees with the daylight on your
        face, and nothing at all in your hands.
        """
}
