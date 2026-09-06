import Gnusto

/// Issue #402, side two: a `scoreLine` that reads state.
///
/// The stock line and both demo games that touch this seam read only the `Score`
/// subject they are handed, which is exactly the pressure the subject creates —
/// it carries score, max and moves and nothing else, so a game wanting a rank, a
/// title or a tally of anything reaches outside it. This one does, and reaching
/// outside is what used to hang: `@Global`'s getter goes `Ctx.current` then
/// `frame.with`, and `scoreLine` was being called from inside a `frame.with`
/// already.
///
/// Both callers matter and they are the same function, so the game supplies both
/// — `score` for the verb, `bow` for the end-of-game epilogue.
struct RankedScoreGame: Game {
    let title = "Ranked"
    let intro = "A game that grades you."

    /// The state the score line reaches for. A rank is the ordinary reason to
    /// want one: it is a function of the score, but the mapping is the game's.
    @Global var rank = "Novice"

    let dais = Location {
        name("Dais")
        description("A raised floor, with a scoreboard above it.")
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("promote", intent: Intent("promote"))
        SyntaxRule("bow", intent: Intent("bow"))
    }

    var text: GameText {
        var text = GameText()
        text.scoreLine = .naming { score in
            // The read that deadlocked: inside the closure, under the caller's
            // lock, asking the frame for a global.
            "Rank: \(self.rank). \(score.score) of \(score.maxScore), in \(score.moves)."
        }
        return text
    }

    var rules: Rules {
        world.before(Intent("promote")) {
            rank = "Adept"
            player.score += 5
            try reply("You are promoted.")
        }

        // The epilogue's route to the same function.
        world.before(Intent("bow")) {
            try end(won: true)
        }
    }

    var map: WorldMap {
        player.starts(in: dais)
    }
}

/// Issue #402, side three: a `reach { … }` rule that asks a reach question.
///
/// The mirror of ``LoopCellGame`` for the one seam that was not counted. The
/// closure already runs outside the frame lock — `Visibility.reachRuleAllows`
/// takes the lock for the placement read and releases it first, deliberately —
/// so this is not a deadlock. It is the other failure: nothing counted the
/// nesting, so the recursion ran until the stack did, with the unattributed
/// `signal 10` that ``Reentry`` exists to replace.
///
/// **This game cannot be played.** Touching the plinth recurses until
/// ``Reentry/reach``'s cap stops it, so the only legal way to run it is inside an
/// exit test — see `ReentryGuardTests`.
struct MirrorReachGame: Game {
    let title = "Mirror"
    let intro = "A plinth that cannot decide whether you can touch it."

    let vestry = Location { name("Vestry") }

    let plinth = Item {
        name("plinth")
    }

    var rules: Rules {
        // Asking whether the plinth is reachable is what this closure is being
        // asked to answer. Nothing breaks the cycle but the cap.
        plinth.reach { plinth.isReachable }
    }

    var map: WorldMap {
        player.starts(in: vestry)
        plinth.starts(in: vestry)
    }
}

/// The half of the reach counter that must *not* fire: a reach rule consulted
/// over and over, turn after turn, and one that legitimately asks about a
/// *different* item.
///
/// The same distinction ``EchoGame`` draws for live text — nesting versus
/// frequency. The lid's gate is written in terms of the latch's, so every touch
/// of the lid enters the seam twice: depth 2, legitimate, and consulted by every
/// verb that has to reach the thing. A counter measuring calls per turn rather
/// than depth would condemn an ordinary game within a few turns.
struct LatchedLidGame: Game {
    let title = "Latched"
    let intro = "A lid, a latch, and a long reach."

    @Global var nearBench = true

    let workshop = Location {
        name("Workshop")
        description("A bench under a window, and a crate against the far wall.")
    }

    let latch = Item {
        name("latch")
    }

    /// Reaches through another item's rule — one level down, every time, and
    /// never more.
    let lid = Item {
        name("lid")
        openable
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("cross", intent: Intent("cross"))
    }

    var rules: Rules {
        world.before(Intent("cross")) {
            nearBench.toggle()
            try reply(nearBench ? "You step back to the bench." : "You cross to the crate.")
        }

        latch.reach(otherwise: "The latch is over by the crate.") { !nearBench }
        // Depth 2: legitimate nesting, consulted on every touch of the lid.
        lid.reach(otherwise: "The lid is as far off as its latch.") { latch.isReachable }
    }

    var map: WorldMap {
        player.starts(in: workshop)
        latch.starts(in: workshop)
        lid.starts(in: workshop)
    }
}
