import Gnusto

extension TraitKey<Bool> {
    /// An item carrying a live, naked flame — the ivory torch, the lit candles,
    /// a struck match. The Gas Room reads it to tell a safe light from one that
    /// sets the air alight, and the glacier reads it to tell what will melt ice.
    /// The electric lantern carries no flame and so never sets it. Three
    /// bundles set it and a fourth reads it, so it is declared here with the
    /// rest of the game-wide vocabulary.
    public static let openFlame = Self("openFlame", default: false)

    /// An item that will take a flame and go on burning — the source's
    /// `BURNBIT`, which its parser uses to decide what `BURN` may even be said
    /// about. Only the balloon's receptacle reads it so far, and what it reads
    /// it for is which of the things a player might drop in the pan will lift
    /// a balloon and which will simply sit there being gold.
    public static let burnable = Self("burnable", default: false)

    /// An item long and thin enough to go into the oak door's keyhole — the
    /// source's `PALOBJS`, which is a list of exactly four: the screwdriver, the
    /// skeleton keys, the broken sharp stick and the rusty iron key itself.
    ///
    /// A trait rather than a list, for ``TraitKey/openFlame``'s reason exactly:
    /// the four live in four different bundles and the puzzle that reads them
    /// lives in a fifth, so a list would have to be the host's and the whole
    /// door would follow it there.
    public static let keyholeTool = Self("keyholeTool", default: false)
}

extension Player {
    /// The lit flame in your hands, if there is one — the flame you named, or
    /// the first one you have. The mainframe's `BURN` syntax demands a
    /// `FLAMEBIT` object in hand, and this game has three: the matchbook, the
    /// pair of candles and the ivory torch.
    ///
    /// Declared beside the trait it reads, the way ``burdenWeight(of:)`` is
    /// declared beside ``TraitKey/weight``: three region bundles were asking
    /// this question in their own words before there was one place to ask it.
    ///
    /// - Parameter named: the flame the sentence named, if it named one.
    /// - Returns: the flame, or `nil` when there isn't one.
    func heldFlame(named: Item? = nil) -> Item? {
        let lit = inventory.filter { $0[default: .openFlame] && $0.isLit }
        guard let named else { return lit.first }
        return lit.contains(named) ? named : nil
    }
}

/// What somebody standing somewhere else can make out lying loose in a room,
/// joined into an English list — or `nil` when the floor is bare.
///
/// Two things ask it, and they are in two different bundles: the barred window
/// between the Tiny Room and the Dreary Room (``DungeonPalantir``), and one
/// palantir looking at the next (``Dungeon/palantirRules``). One answer, so
/// *loose* cannot come to mean two things. Declared here beside
/// ``Player/heldFlame(named:)`` for that helper's reason exactly.
///
/// - Parameter room: the room being looked into.
/// - Returns: the list, or `nil` for an empty one.
func remoteView(of room: Location) -> String? {
    let loose = room.contents.filter(\.isTakable).map(\.indefiniteName)
    return loose.isEmpty ? nil : GameText.list(loose)
}

/// The mainframe's verb vocabulary that the engine does not already carry.
///
/// The list is deliberately short. Most of what Zork's player types — `dig`,
/// `pray`, `tie`, `touch`, `smell`, `climb`, `xyzzy` — is an engine stub verb,
/// so every game gets the word for free and a game only has to give it a voice.
/// What remains here is vocabulary that is genuinely this game's, and it grows
/// one milestone at a time rather than all at once: a verb declared before the
/// mechanism that needs it is a word the player can type and get nothing from.
///
/// **A verb lives with the region that answers it.** Milestone 2 flagged this
/// file as "becoming the verb dumping ground"; milestone 4 settles it, because
/// `GameContent` carries `verbs` and `actions` of its own exactly as `Clock` and
/// `MeleeCombat` do. So ``DungeonRiver`` owns the boat's words and
/// ``DungeonMaze`` owns the cyclops's, and what stays here is what belongs to no
/// one region: the words that cross two bundles, and the ones the whole game
/// answers.
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
    ///
    /// `lift` is the same intent, and it is not decoration: the robot's own
    /// instruction sheet tells the player to say `ROBOT, LIFT THE CAGE`, so the
    /// word has to be in the vocabulary or the sheet is a lie.
    #verb("raise", ["raise", .directObject], ["lift", .directObject])
    #verb("lower", ["lower", .directObject])

    /// Put air into something, and let it back out. One thing in the game
    /// takes either, and the destinations of `launch` and `land` cross from
    /// ``DungeonRiver`` into ``DungeonDam``, so all four stay here.
    #verb(
        "inflate",
        ["inflate", .directObject],
        ["inflate", .directObject, "with", .indirectObject])
    #verb("deflate", ["deflate", .directObject])

    /// Put a vessel on the water, and take it off again. The mainframe spells
    /// these as pseudo-directions in its exit tables; in this engine they are
    /// verbs, and the host owns their tables because one shore is the dam's.
    #verb("launch", ["launch"], ["launch", .directObject])
    #verb("land", ["land"])

    /// The two words that use the granite wall the Temple and the Treasure
    /// Room share. Each takes you to the other room and nowhere else.
    #verb("temple", ["temple"])
    #verb("treasure", ["treasure"])
}

/// The game-wide verb layer: the vocabulary above, plus a courteous default in
/// the Infocom register for each of **this game's own** verbs.
///
/// The two blocks line up almost one to one, and that is the point. Every verb
/// here is one this game minted, so it needs a `verbs` entry to exist and an
/// `actions` row to answer when nothing more specific does. The engine's stub
/// verbs are **not** here — a stub already has the word and already has a line,
/// so re-voicing one is an assignment rather than a claim on the verb. That is
/// ``Prose/stubFloor``, and the reason is in this file's `actions` block. (#233)
struct DungeonSystems: GameContent {
    var verbs: [SyntaxRule] {
        [
            .wind, .diagnose, .echo, .turnWith, .plug, .ring, .melt, .exorcise,
            .raise, .lower, .inflate, .deflate, .launch, .land, .temple,
            .treasure,
        ]
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
        action(.inflate) { try reply(Prose.verbInflateNothing) }
        action(.deflate) { try reply(Prose.verbDeflateNothing) }
        // Both magic words fall through to the same shrug; the host answers
        // them in the two rooms that share the granite wall.
        action(.temple) { try reply(Prose.graniteWordInert) }
        action(.treasure) { try reply(Prose.graniteWordInert) }
        // `.diagnose` has no default here: the host answers it, because the
        // report reads the host's death counter.
        //
        // Nothing else belongs in this block. Every **engine stub** this game
        // re-voices — the seventeen that used to sit here, and the thirty that
        // never had a line at all — is now `text.stubs` in ``Dungeon``, which
        // is ``Prose/stubFloor``. An `action(…)` row on a stub intent claims
        // the verb outright: `DefaultActions.run` returns from the override
        // before `requireReach`, so the row silently gave up the engine's reach
        // guard, the object's name, its number agreement and the
        // `yourself`/`somebodyElse` guards, none of which this game meant to
        // trade away for a change of voice. (#233)
    }
}
