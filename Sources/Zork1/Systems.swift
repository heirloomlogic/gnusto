import Gnusto

/// The Zork verb vocabulary that isn't built into the engine. Each `#verb`
/// declares one intent plus the rows the player can type to reach it. The
/// rows are spliced into the parser by ``ZorkSystems``'s `verbs` block, and
/// each intent gets a polite stage-4 default in that bundle's `actions`.
///
/// Most of these do nothing *yet*: the mechanics that make `dig`, `wind`,
/// `inflate`, `tie`, `raise`/`lower`, and `turn … with …` matter arrive with
/// the regions that need them (the shovel, the canary, the plastic pile, the
/// dam controls). Declaring the verbs now means the parser understands them
/// from the start — a later region only has to add an item-scoped rule, never
/// teach the game a new word.
extension Intent {
    /// Hand an object to someone.
    #verb(
        "give",
        ["give", .directObject, "to", .indirectObject],
        ["hand", .directObject, "to", .indirectObject])

    /// Tie something to something else (the rope, later).
    #verb(
        "tie",
        ["tie", .directObject],
        ["tie", .directObject, "to", .indirectObject])

    /// Undo a tie.
    #verb(
        "untie",
        ["untie", .directObject],
        ["untie", .directObject, "from", .indirectObject])

    /// Dig — bare-handed (futile) or with a tool (the shovel, later).
    #verb(
        "dig",
        ["dig"],
        ["dig", .directObject],
        ["dig", .directObject, "with", .indirectObject])

    /// Wave something about (the sceptre, later).
    #verb(
        "wave",
        ["wave"],
        ["wave", .directObject])

    /// Touch or rub a thing.
    #verb(
        "touch",
        ["touch", .directObject],
        ["rub", .directObject])

    /// Wind a mechanism (the clockwork canary, later).
    #verb("wind", ["wind", .directObject])

    /// Inflate something (the plastic boat, later).
    #verb(
        "inflate",
        ["inflate", .directObject],
        ["inflate", .directObject, "with", .indirectObject])

    /// Let the air back out.
    #verb("deflate", ["deflate", .directObject])

    /// Launch a vessel onto water (the boat, later).
    #verb("launch", ["launch", .directObject])

    /// Raise something (the dam's control gate, later).
    #verb("raise", ["raise", .directObject])

    /// Lower something.
    #verb("lower", ["lower", .directObject])

    /// Turn a fixture *with* a tool. Two literals plus two object slots give
    /// this a specificity of 22, one above the built-in `turn … on` (21), so
    /// "turn bolt with wrench" resolves here and never to the light switch.
    #verb("turnWith", ["turn", .directObject, "with", .indirectObject])

    /// Pray (at the altar, later).
    #verb("pray", ["pray"])

    /// Ring a bell (later).
    #verb("ring", ["ring", .directObject])

    /// Shout into a space and hear it come back.
    #verb("echo", ["echo"])

    /// The Cyclops's magic word — inert until he's met (later).
    #verb("odysseus", ["odysseus"], ["ulysses"])

    /// Cavern-crawler magic words — inert here, but the parser knows them.
    #verb("xyzzy", ["xyzzy"])
    #verb("plugh", ["plugh"])

    /// Say hello.
    #verb("hello", ["hello"], ["hi"])

    /// Smell the room or a thing.
    #verb(
        "smell",
        ["smell"],
        ["smell", .directObject],
        ["sniff"],
        ["sniff", .directObject])

    /// Drink a liquid (water from the bottle).
    #verb("drink", ["drink", .directObject])

    /// Fill a container at a water source.
    #verb(
        "fill",
        ["fill", .directObject],
        ["fill", .directObject, "with", .indirectObject])

    /// Empty a container out.
    #verb(
        "pour",
        ["pour", .directObject],
        ["pour", .directObject, "in", .indirectObject],
        ["pour", .directObject, "on", .indirectObject])

    /// Climb a thing (the tree). `climb X` and `climb up/on X` all reach here;
    /// a climbable object's own rule takes over, anything else gets the default.
    #verb(
        "climb",
        ["climb", .directObject],
        ["climb", "up", .directObject],
        ["climb", "on", .directObject])

    /// Repair something (the punctured boat, sealed with the tube's gunk).
    #verb(
        "fix",
        ["fix", .directObject],
        ["fix", .directObject, "with", .indirectObject],
        ["repair", .directObject],
        ["repair", .directObject, "with", .indirectObject],
        ["patch", .directObject],
        ["patch", .directObject, "with", .indirectObject])

    /// Ask for a report on your condition — how many times you've died, and how
    /// many times you may yet be brought back. Handled in ``Zork1`` (it reads the
    /// host's death counter).
    #verb("diagnose", ["diagnose"])
}

/// The game-wide verb layer: it teaches the parser every custom verb above
/// and gives each a courteous "nothing happens" default. Item- and
/// room-scoped rules elsewhere (the bottle's `fill`/`drink`/`pour`, a future
/// shovel's `dig`) run first and take over when a verb actually does
/// something; anything they don't claim falls through to these defaults.
struct ZorkSystems: GameContent {
    var verbs: [SyntaxRule] {
        [
            .give, .tie, .untie, .dig, .wave, .touch, .wind, .inflate, .deflate,
            .launch, .raise, .lower, .turnWith, .pray, .ring, .echo, .odysseus,
            .xyzzy, .plugh, .hello, .smell, .drink, .fill, .pour, .climb, .fix,
            .diagnose,
        ]
    }

    var actions: [IntentAction] {
        action(.give) { try reply(Prose.verbGiveNoTaker) }
        action(.tie) { try reply(Prose.verbTieNothing) }
        action(.untie) { try reply(Prose.verbUntieNothing) }
        action(.dig) { try reply(Prose.verbDigFutile) }
        action(.wave) { try reply(Prose.verbWave) }
        action(.touch) { try reply(Prose.verbTouch) }
        action(.wind) { try reply(Prose.verbWindNothing) }
        action(.inflate) { try reply(Prose.verbInflateNothing) }
        action(.deflate) { try reply(Prose.verbDeflateNothing) }
        action(.launch) { try reply(Prose.verbLaunchNothing) }
        action(.raise) { try reply(Prose.verbRaiseNothing) }
        action(.lower) { try reply(Prose.verbLowerNothing) }
        action(.turnWith) { try reply(Prose.verbTurnWithNothing) }
        action(.pray) { try reply(Prose.verbPray) }
        action(.ring) { try reply(Prose.verbRingNothing) }
        action(.echo) { try reply(Prose.verbEcho) }
        action(.odysseus) { try reply(Prose.verbMagicWordInert) }
        action(.xyzzy) { try reply(Prose.verbMagicWordInert) }
        action(.plugh) { try reply(Prose.verbMagicWordInert) }
        action(.hello) { try reply(Prose.verbHello) }
        action(.smell) { try reply(Prose.verbSmell) }
        action(.drink) { try reply(Prose.nothingToDrink) }
        action(.fill) { try reply(Prose.noWaterSource) }
        action(.pour) { try reply(Prose.nothingToPour) }
        action(.climb) { try reply(Prose.verbClimbNothing) }
        action(.fix) { try reply(Prose.verbFixNothing) }
        // `.diagnose` has no stage-4 default here — the host answers it, since
        // the report reads the host's death counter (see ``Zork1.actions``).
    }
}

/// The score-rank ladder shown after the score line — Zork's own titles and
/// thresholds, verbatim from the original's `V-SCORE` routine (see
/// `THIRD_PARTY_NOTICES`). Zork tests each tier with a strict `>`, so the
/// minimums here are the original's boundary plus one (e.g. "more than 25"
/// becomes `min: 26`); the top tier is the exact 350-point finish.
enum ZorkRank {
    /// Ascending `(minimum score, rank name)` tiers. The last tier at or
    /// below the current score wins.
    static let ladder: [(min: Int, name: String)] = [
        (Int.min, "Beginner"),
        (26, "Amateur Adventurer"),
        (51, "Novice Adventurer"),
        (101, "Junior Adventurer"),
        (201, "Adventurer"),
        (301, "Master"),
        (331, "Wizard"),
        (350, "Master Adventurer"),
    ]

    /// The rank name for a given score — the highest tier the score reaches.
    ///
    /// - Parameter score: the player's current score (may be negative).
    /// - Returns: the earned rank name.
    static func name(for score: Int) -> String {
        var earned = ladder[0].name
        for tier in ladder where score >= tier.min {
            earned = tier.name
        }
        return earned
    }
}
