import Gnusto

/// The mainframe's verb vocabulary that the engine does not already carry.
///
/// The list is deliberately short. Most of what Zork's player types — `dig`,
/// `pray`, `tie`, `touch`, `smell`, `climb`, `xyzzy` — is an engine stub verb,
/// so every game gets the word for free and a game only has to give it a voice.
/// What remains here is vocabulary that is genuinely this game's, and it grows
/// one milestone at a time rather than all at once: a verb declared before the
/// mechanism that needs it is a word the player can type and get nothing from.
extension Intent {
    /// Wind a mechanism. The clockwork canary is the only one above ground;
    /// the mirror box and the Endgame add their own.
    #verb("wind", ["wind", .directObject], ["wind", "up", .directObject])

    /// Ask how you are doing. The mainframe answers with the damage you have
    /// taken and the deaths you have already spent; this game answers with the
    /// deaths, since the troll is the only thing swinging at you so far.
    /// Handled in ``Dungeon`` — it reads the host's death counter.
    #verb("diagnose", ["diagnose"])
}

/// The game-wide verb layer: the vocabulary above, plus a courteous default in
/// the Infocom register for every verb this game cares about — its own and the
/// engine's stubs alike.
///
/// The `actions` block is longer than `verbs` on purpose. An engine stub needs
/// no `verbs` entry (the word is already in the vocabulary) and shadows no
/// behavior, so re-voicing one is a single line that warns about nothing.
struct DungeonSystems: GameContent {
    var verbs: [SyntaxRule] {
        [.wind, .diagnose]
    }

    var actions: [IntentAction] {
        action(.wind) { try reply(Prose.verbWindNothing) }
        action(.give) { try reply(Prose.verbGiveNoTaker) }
        action(.dig) { try reply(Prose.verbDigFutile) }
        action(.wave) { try reply(Prose.verbWave) }
        action(.touch) { try reply(Prose.verbTouch) }
        action(.smell) { try reply(Prose.verbSmell) }
        action(.pray) { try reply(Prose.verbPray) }
        action(.climb) { try reply(Prose.verbClimbNothing) }
        action(.tie) { try reply(Prose.verbTieNothing) }
        action(.untie) { try reply(Prose.verbUntieNothing) }
        action(.drink) { try reply(Prose.nothingToDrink) }
        action(.pour) { try reply(Prose.nothingToPour) }
        action(.fill) { try reply(Prose.noWaterSource) }
        // One row covers `xyzzy` and `plugh` both — the engine puts them on a
        // single intent, and in the mainframe neither does anything.
        action(.xyzzy) { try reply(Prose.verbMagicWordInert) }
        // `.diagnose` has no default here: the host answers it, because the
        // report reads the host's death counter.
    }
}
