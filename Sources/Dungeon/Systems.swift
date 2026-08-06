import Gnusto

extension TraitKey<Bool> {
    /// An item carrying a live, naked flame — the ivory torch, the lit candles,
    /// a struck match. The Gas Room reads it to tell a safe light from one that
    /// sets the air alight, and the glacier reads it to tell what will melt ice.
    /// The electric lantern carries no flame and so never sets it. Three
    /// bundles set it and a fourth reads it, so it is declared here with the
    /// rest of the game-wide vocabulary.
    public static let openFlame = Self("openFlame", default: false)
}

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

    /// Say a word to a room that is listening. Only the Loud Room is, and only
    /// this one word settles it.
    #verb("echo", ["echo"])

    /// Turn a thing with a tool. The engine's `turn` takes no instrument, and
    /// the dam's great bolt is the whole reason the wrench exists.
    #verb("turnWith", ["turn", .directObject, "with", .indirectObject])

    /// Stop something up. The mainframe's verb for the dam's leak, and the
    /// only thing in the game it works on.
    #verb("plug", ["plug", .directObject], ["plug", .directObject, "with", .indirectObject])

    /// Ring a bell. One bell, and one place where ringing it matters.
    #verb("ring", ["ring", .directObject])

    /// Melt a thing, optionally with another. The mainframe answers it in one
    /// place, and the answer there is fatal.
    #verb("melt", ["melt", .directObject], ["melt", .directObject, "with", .indirectObject])

    /// Ask the game whether you are equipped for an exorcism. The mainframe's
    /// own hint verb: it never performs the ceremony, it only tells you
    /// whether you are carrying the three things it takes.
    #verb("exorcise", ["exorcise"], ["exorcism"])

    /// Work the chain over the coal mine's shaft. Two verbs for one mechanism,
    /// because a basket at the bottom is raised and one at the top is lowered.
    #verb("raise", ["raise", .directObject])
    #verb("lower", ["lower", .directObject])
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
        [.wind, .diagnose, .echo, .turnWith, .plug, .ring, .melt, .exorcise, .raise, .lower]
    }

    var actions: [IntentAction] {
        action(.wind) { try reply(Prose.verbWindNothing) }
        action(.echo) { try reply(Prose.verbEcho) }
        action(.turnWith) { try reply(Prose.verbTurnWithNothing) }
        action(.plug) { try reply(Prose.verbPlugNothing) }
        action(.ring) { try reply(Prose.verbRingNothing) }
        action(.melt) { try reply(Prose.verbMeltNothing) }
        action(.exorcise) { try reply(Prose.verbExorciseNothing) }
        action(.raise) { try reply(Prose.verbRaiseNothing) }
        action(.lower) { try reply(Prose.verbLowerNothing) }
        action(.squeeze) { try reply(Prose.verbSqueezeNothing) }
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
