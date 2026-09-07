import Gnusto

/// The Zork verb vocabulary that isn't built into the engine. Each `#verb`
/// declares one intent plus the rows the player can type to reach it. The
/// rows are spliced into the parser by ``ZorkSystems``'s `verbs` block, and
/// each intent gets a polite stage-4 default in that bundle's `actions`.
///
/// Most of these do nothing *yet*: the mechanics that make `wind`, `inflate`,
/// `raise`/`lower`, and `turn … with …` matter arrive with the regions that
/// need them (the canary, the plastic pile, the dam controls). Declaring the
/// verbs now means the parser understands them from the start — a later region
/// only has to add an item-scoped rule, never teach the game a new word.
///
/// The generic half of this list used to live here too — `dig`, `give`, `tie`,
/// `touch`, `smell`, `climb`, `pray`, `xyzzy` and the rest. Those are engine
/// stub verbs now, so every game gets them; what remains below is the vocabulary
/// that is actually *Zork's*. Zork keeps its own voice for the shared ones in
/// ``Prose/stubFloor``, which is `text.stubs` rather than a row apiece.
extension Intent {
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
    /// this a specificity of 22, one above the built-in `turn … on` (21) and
    /// well above the engine's bare `turn …` stub (11), so "turn bolt with
    /// wrench" resolves here and never to the light switch.
    #verb("turnWith", ["turn", .directObject, "with", .indirectObject])

    /// Ring a bell (later).
    #verb("ring", ["ring", .directObject])

    /// Shout into a space and hear it come back.
    #verb("echo", ["echo"])

    /// The Cyclops's magic word — inert until he's met (later).
    #verb("odysseus", ["odysseus"], ["ulysses"])

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

/// The game-wide verb layer: it teaches the parser Zork's own verbs and gives
/// each of them a courteous default in the original's voice. Item- and
/// room-scoped rules elsewhere (the canary's `wind`, the boat's `inflate`) run
/// first and take over when a verb actually does something; anything they don't
/// claim falls through to these defaults.
///
/// The `verbs` and `actions` blocks now list the same intents, which is the
/// point. A row here is a claim that **this game owns the verb** — a word the
/// engine had never heard until the line above taught it. The engine's own stub
/// verbs are not that, and re-skinning one with a row costs the whole default
/// it was standing on; their words live in ``Prose/stubFloor`` instead. (#242)
struct ZorkSystems: GameContent {
    /// This game's own verbs, plus the two bare greeting rows the engine leaves
    /// to games. `hello` used to be an intent of Zork's, answering "Nobody here
    /// returns your greeting." from a row that could not see who was in the
    /// room. The engine's ``Intent/greet`` already owns `hello <object>` and
    /// reads the frame both ways; it leaves the bare words out only so a game
    /// may keep the *word* without a launch warning, not so it must keep a flat
    /// line. Zork keeps the words and takes the branching. (#325, FIDELITY.md)
    var verbs: [SyntaxRule] {
        [
            .wind, .inflate, .deflate, .launch, .raise, .lower, .turnWith,
            .ring, .echo, .odysseus, .fix, .diagnose,
        ]
        SyntaxRule("hello", intent: .greet)
        SyntaxRule("hi", intent: .greet)
    }

    var actions: [IntentAction] {
        action(.wind, say: Prose.verbWindNothing)
        action(.inflate, say: Prose.verbInflateNothing)
        action(.deflate, say: Prose.verbDeflateNothing)
        action(.launch, say: Prose.verbLaunchNothing)
        // `V-RAISE` is `V-LOWER` (`gverbs.zil:1131`), which names the thing;
        // both rows used to survey a room instead. (#325) `naming:` is where
        // the two guards that repair needed come from — the player gets
        // `yourself` and everybody else gets `somebodyElse`, so the sentence
        // never says "Playing in this way with yourself has no effect." The
        // game used to write that cascade out by hand, twice, because a row
        // was the only door a custom verb had. (#404)
        action(.raise, naming: { Prose.playingWithIt("\($0)") })
        action(.lower, naming: { Prose.playingWithIt("\($0)") })
        // `TURN OBJECT WITH OBJECT` routes to `V-TURN` in the source
        // (`gsyntax.zil:505`), whose whole body is the line the stub floor's
        // `turn` already carries (`gverbs.zil:1506`). (#325)
        action(.turnWith, say: Prose.verbTurnNoEffect)
        action(.ring, say: Prose.verbRingNothing)
        action(.echo, say: Prose.verbEcho)
        action(.odysseus, say: Prose.verbMagicWordInert)
        action(.fix, say: Prose.verbFixNothing)

        // `.diagnose` has no stage-4 default here — the host answers it, since
        // the report reads the host's death counter (see ``Zork1.actions``).
        //
        // Nothing else belongs in this block. Every **engine stub** this game
        // re-voices — the thirteen that used to sit here, and the thirty-four
        // that never had a line at all — is now `text.stubs` in ``Zork1``, which
        // is ``Prose/stubFloor``. An `action(…)` *closure* on a stub intent
        // claims the verb outright: `DefaultActions.run` returns from the
        // override before `requireReach`, so the row silently gave up the
        // engine's reach guard, the object's name, its number agreement and the
        // `yourself`/`somebodyElse` guards, none of which this game meant to
        // trade away for a change of voice. (#242) The `say:` and `naming:`
        // rows above keep all four — that is what the spelling is for — and
        // bootstrap now warns for one written on a stub intent, where
        // `text.stubs` is still the shorter road. (#404)
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
