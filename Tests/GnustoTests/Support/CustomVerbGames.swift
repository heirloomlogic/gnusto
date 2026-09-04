import Gnusto

// Custom verbs, declared once. Each #verb yields a typed intent constant
// (`.ring`) carrying its rows; the games below list the intents they teach in
// their `verbs` blocks and key rules on the same constants.
extension Intent {
    #verb("ring", ["ring", .directObject])
    #verb("polish", ["polish", .directObject, "with", .indirectObject])
    // Deliberately a word the engine's stub table doesn't own, and deliberately
    // wired to nothing: this verb's job is to prove the *unhandled* path
    // answers the fall-back line for free, and warns about itself at bootstrap.
    // A stub verb would answer its own line instead, and cost a turn doing it.
    #verb("hum")
    // Same verb token and slot shape as the built-in `take`, so listing this
    // row reclaims it (last-wins) and emits `.steal` instead.
    #verb("steal", ["take", .directObject])
    // Answered by a rule on one entity and left to the fall-back for every
    // other noun — the documented pattern, and the one that used to spend a
    // turn saying the parser had failed.
    #verb("salute", ["salute", .directObject])
}

/// Exercises vocabulary extension: a game that teaches the parser new
/// player-typeable verbs by listing `#verb`-declared intents in its `verbs`
/// block, with the behavior living in ordinary `before` rules keyed on the
/// same intents.
struct CustomVerbGame: Game {
    let title = "Custom Verbs"
    let intro = "A small chapel for trying out new words."

    let chapel = Location {
        name("Chapel")
        description("A small stone chapel.")
    }

    let bell = Item {
        name("bronze bell")
        adjectives("bronze")
        description("A heavy bronze bell.")
    }

    let cloth = Item {
        name("soft cloth")
        adjectives("soft")
        description("A soft polishing cloth.")
    }

    var map: WorldMap {
        player.starts(in: chapel)
        bell.starts(in: chapel)
        cloth.starts(in: chapel)
    }

    /// Three new verbs: a plain transitive verb, a verb with a preposition
    /// shape (proving the preposition is harvested into the vocabulary), and a
    /// verb with no handling rule (proving the unhandled path falls through to
    /// the fall-back line).
    var verbs: [SyntaxRule] {
        [.ring, .polish, .hum]
    }

    var rules: Rules {
        bell.before(.ring) {
            try reply("The bell chimes sweetly.")
        }
        bell.before(.polish) {
            try reply("You polish the bell to a warm shine.")
        }
        // No rule handles `hum`: the parser still emits the intent, and stage
        // 4 has nothing to answer it with.
    }
}

/// A game whose custom verb deliberately collides with a built-in: the row
/// `take <thing>` is reclaimed to mean "steal" rather than the built-in take.
/// Proves last-wins override and the non-fatal collision warning.
struct VerbOverrideGame: Game {
    let title = "Override"
    let intro = "A vault with a single coin."

    let vault = Location {
        name("Vault")
        description("A cramped stone vault.")
    }

    let coin = Item {
        name("gold coin")
        adjectives("gold")
        description("A single gold coin.")
    }

    var map: WorldMap {
        player.starts(in: vault)
        coin.starts(in: vault)
    }

    var verbs: [SyntaxRule] {
        .steal
    }

    var rules: Rules {
        coin.before(.steal) {
            try reply("You pocket the coin with a guilty glance.")
        }
    }
}

/// The `GnustoMeleeCombat` verbs block in miniature: an engine intent listed by
/// name for the rows the engine already ships, with the plugin's own rows spelled
/// beside it. Only its `verbs` block is under test — nothing here is played, and
/// the merged table would supply those rows either way.
struct EngineIntentVerbGame: Game {
    let title = "Practice Yard"
    let intro = "A yard for weapons drill."

    let yard = Location {
        name("Practice Yard")
        description("A packed-dirt yard for weapons drill.")
    }

    var map: WorldMap {
        player.starts(in: yard)
    }

    var verbs: [SyntaxRule] {
        .attack
        SyntaxRule("stab", .directObject, "with", .indirectObject, intent: .attack)
        SyntaxRule("strike", .directObject, "with", .indirectObject, intent: .attack)
    }
}

/// A game that reclaims the built-in `take <thing>` row for `.steal`, then puts
/// it back by listing `.take`. Last-wins means the restoration only lands if
/// listing an engine intent actually splices its rows — so this is where the
/// fallback is visible in a transcript rather than in a table.
struct RestoredCoreVerbGame: Game {
    let title = "Restored"
    let intro = "A counting house, and one penny left in it."

    let countingHouse = Location {
        name("Counting House")
        description("A narrow room of empty ledgers.")
    }

    let penny = Item {
        name("silver penny")
    }

    var map: WorldMap {
        player.starts(in: countingHouse)
        penny.starts(in: countingHouse)
    }

    /// Spelled `Intent.take` rather than `.take`: a bare leading dot on the line
    /// after another statement would parse as a member access on it.
    var verbs: [SyntaxRule] {
        .steal
        Intent.take
    }
}

/// A game that keys a rule on a `#verb` intent but forgets to list it in a
/// `verbs` block — the mistake the dead-intent bootstrap warning names.
struct ForgottenVerbGame: Game {
    let title = "Forgotten"
    let intro = "A chapel where the bell can't be rung."

    let chapel = Location {
        name("Chapel")
        description("A small stone chapel.")
    }

    let bell = Item {
        name("bronze bell")
        adjectives("bronze")
        description("A heavy bronze bell.")
    }

    var map: WorldMap {
        player.starts(in: chapel)
        bell.starts(in: chapel)
    }

    var rules: Rules {
        bell.before(.ring) {
            try reply("The bell chimes sweetly.")
        }
    }
}

/// The Lighthouse shape, reduced to its bones: one custom verb, answered by a
/// rule on one actor and by nothing else, in a room where a daemon is counting.
/// `salute sentry` is a turn; `salute banner` reaches stage 4 with nothing to
/// answer it and must therefore cost nothing — the bug that drowned a
/// play-tester on the jetty.
struct SentryPostGame: Game {
    let title = "Sentry Post"
    let intro = "A gate, a sentry, and a bell that keeps the watch."

    let gate = Location {
        name("Gate")
        description("A stone arch over a road going nowhere.")
    }

    let sentry = Actor {
        name("weathered sentry")
        adjectives("weathered")
        description("Straight-backed, and bored past caring.")
    }

    /// The noun the rule doesn't cover — and the one carrying the `after` rule,
    /// so a skipped stage 5 is observable.
    let banner = Item {
        name("faded banner")
        adjectives("faded")
        description("A regimental banner, sun-bleached to no colour at all.")
    }

    @Global var strokes = 0

    var map: WorldMap {
        player.starts(in: gate)
        sentry.starts(in: gate)
        banner.starts(in: gate)
    }

    var verbs: [SyntaxRule] {
        .salute
    }

    var timers: [TimedEvent] {
        daemon("watch", autostart: true) {
            strokes += 1
            say("The watch bell strikes \(strokes).")
        }
    }

    var rules: Rules {
        sentry.before(.salute) {
            try reply("The sentry returns your salute, crisply.")
        }
        banner.after(.salute) {
            say("The banner stirs.")
        }
    }
}

/// The rollback contract for a free turn, reduced to its bones: one noun whose
/// `salute` rule mutates a `@Global` and answers nothing (so stage 4 throws
/// `unhandled`), one whose rule answers, and a dial that reports the count.
/// `examine it` is the pronoun half: an unhandled turn that names a thing must
/// not steal `it` from the turn before it.
struct UnhandledRollbackGame: Game {
    let title = "Rollback"
    let intro = "A gate where almost nothing answers."

    let gate = Location {
        name("Gate")
        description("A stone arch over a road going nowhere.")
    }

    /// The noun the rule mutates state for but doesn't cover — the unhandled
    /// path, whose mutations and pronoun binding must both be rolled back.
    let banner = Item {
        name("faded banner")
        adjectives("faded")
        description("A regimental banner, sun-bleached to no colour at all.")
    }

    let dial = Item {
        name("brass dial")
        adjectives("brass")
        description("A dial of brushed brass.")
    }

    @Global var flips = 0

    var map: WorldMap {
        player.starts(in: gate)
        banner.starts(in: gate)
        dial.starts(in: gate)
    }

    var verbs: [SyntaxRule] {
        [.salute, .ring]
    }

    var rules: Rules {
        banner.before(.salute) {
            flips += 1
        }
        dial.before(.salute) {
            flips += 1
            try reply("You salute the dial. It reads \(flips).")
        }
        dial.before(.ring) {
            try reply("The dial reads \(flips).")
        }
    }
}

/// The mistake #283 names, in the shape Dungeon carried it: two rows for one
/// pattern, differing only in how the preposition is spelled. `in` already
/// answers to `into`, so the second row is dead — and the bootstrap has to say
/// so without refusing to start the game, because a dead row breaks nothing.
struct RespeltVerbGame: Game {
    let title = "Respelt"
    let intro = "A well, and a coin to throw into it."

    let wellhead = Location {
        name("Wellhead")
        description("A mossy wellhead over a dark shaft.")
    }

    let well = Item {
        name("well")
        container
    }

    let coin = Item {
        name("copper coin")
        adjectives("copper")
    }

    var map: WorldMap {
        player.starts(in: wellhead)
        well.starts(in: wellhead)
        coin.starts(in: wellhead)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("toss", .directObject, "in", .indirectObject, intent: .throwAt)
        SyntaxRule("toss", .directObject, "into", .indirectObject, intent: .throwAt)
    }
}

/// The same mistake against a row the *engine* declares: nothing in this game
/// spells `put <object> in <second object>`, but the built-in table does, so the
/// row below can never fire either. Proves the check reads the merged table
/// rather than the game's own block. Nothing here is played — the `verbs` block
/// is the fixture, and the room exists so the game can start.
struct RespeltBuiltInVerbGame: Game {
    let title = "Respelt Built-In"
    let intro = "A shelf and a box."

    let pantry = Location {
        name("Pantry")
        description("A narrow pantry lined with shelves.")
    }

    var map: WorldMap {
        player.starts(in: pantry)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("put", .directObject, "into", .indirectObject, intent: .putIn)
    }
}
