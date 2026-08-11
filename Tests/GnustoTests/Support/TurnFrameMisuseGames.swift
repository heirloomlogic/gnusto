import Gnusto

// Games that ask the turn frame for something it cannot give, one fixture per
// guard in `TurnFrame.swift`. Most of them cannot be played: the verb they
// answer traps, which is the point. `ProxyFrameTests` runs each in a child
// process. Issue #229.

/// Issue #229: the mistake the second half of `Ctx.current`'s guard exists for —
/// a rule body that hands its work to a `Task` and lets it read the world after
/// the turn has committed.
///
/// **This game cannot be played.** Pushing the lever spawns a task that outlives
/// the turn, and the first thing it reads traps. `ProxyFrameTests` runs it in a
/// child process; nothing in the suite may boot it in process.
///
/// ## Why a `Task`, and why the trap names one
///
/// `Ctx/frame` is a `@TaskLocal` and every proxy re-reads `Ctx.current` at use
/// time, so what an author captures is never a frame — it is a lookup that
/// happens later, against whatever the *calling* task has bound. That leaves
/// exactly one shape that carries a dead frame into a live read: an unstructured
/// `Task { }`, which copies the binding at creation and keeps it after the
/// parent's `Ctx.$frame.withValue` block has popped. `Task.detached` and a
/// dispatch queue inherit nothing and reach the sibling trap instead; a plain
/// escaping closure called from a later turn reads that turn's live frame and
/// does not trap at all, which is what ``StashGame`` below pins down.
///
/// ## Why there is a latch in it
///
/// The `Task` is the author's mistake; the latch is not. An unstructured task
/// runs as soon as it is scheduled, so left alone it races the rest of the turn:
/// read early enough and the frame is still live, the read succeeds, and the
/// test that wanted the trap watches a clean exit. Parking the task until the
/// test opens the latch moves the read to a point where the turn is provably
/// over — `play` has returned, so `GameWorld.commit(_:)` has retired the frame.
struct AfterthoughtGame: Game {
    let title = "Afterthought"
    let intro = "A lever, and a lamp that means to catch up later."

    let cellar = Location {
        name("Cellar")
        description("Cold, and one lever on the wall.")
    }

    let lever = Item {
        name("brass lever")
        description("Stiff, but it moves.")
    }

    var rules: Rules {
        lever.before(.push) {
            // The mistake, in the shape an author writes it: the work that
            // belonged here is handed to a task, which gets to it after the
            // turn that spawned it has committed.
            Self.afterwards = Task {
                for await _ in Self.latch.stream {}
                say("The lamp catches, hours late.")
            }
            say("The lever goes over with a clunk.")
        }
    }

    var map: WorldMap {
        player.starts(in: cellar)
        lever.starts(in: cellar)
    }

    // MARK: - The test's hold on the escaped task

    // Statics, not stored properties: the bootstrap finds entities by `Mirror`
    // over the game's instance storage, which these must stay out of.

    /// The escaped task, kept so the test can wait on it rather than hope.
    nonisolated(unsafe) static var afterwards: Task<Void, Never>?

    /// The gate the task parks on, opened by the test once the turn has
    /// committed.
    ///
    /// An `AsyncStream` that never yields: the task's `for await` suspends until
    /// the stream finishes, and finishing it *before* anyone waits ends the loop
    /// just as promptly. That order-independence is the whole requirement — a
    /// test cannot lose the handshake by being early, and no arrangement of the
    /// two deadlocks.
    static let latch = AsyncStream<Void>.makeStream()
}

/// The companion ``AfterthoughtGame``'s guard must *not* condemn, and the reason
/// that fixture needs a `Task` at all: a closure stashed in one turn and called
/// in the next resolves against the turn that calls it.
///
/// Playable, and played in process. Pulling the rope sets the tally to 1 and
/// stashes a closure that reads it; examining the rope sets the tally to 2 and
/// calls the closure, which reports 2. Wrong — the closure was written about the
/// first turn — but live, and so invisible to the engine. That is the fact that
/// makes the trap over in ``AfterthoughtGame`` reachable only through a `Task`.
struct StashGame: Game {
    let title = "Stash"
    let intro = "A bell rung now and answered later."

    @Global var tally = 0

    let vestry = Location {
        name("Vestry")
        description("A bell rope, and a slate for keeping count.")
    }

    let rope = Item { name("bell rope") }

    var rules: Rules {
        rope.before(.pull) {
            tally = 1
            Self.stashed = { say("the stashed closure reads tally=\(tally)") }
            try reply("The bell rings.")
        }
        rope.before(.examine) {
            tally = 2
            Self.stashed?()
            try handled()
        }
    }

    var map: WorldMap {
        player.starts(in: vestry)
        rope.starts(in: vestry)
    }

    /// Written by the first turn, called by the second. Cleared by the test that
    /// installs it, so a second run in one process starts from nothing rather
    /// than finding the first run's closure already here.
    nonisolated(unsafe) static var stashed: (@Sendable () -> Void)?
}

/// The first bold rule in `CLAUDE.md`, broken on purpose: an entity built inside
/// a rule body rather than declared as a stored property of the game.
///
/// The bootstrap finds entities by reflecting over the game's own storage, so
/// one constructed here was never seen, never named, and has no identity in the
/// world — the `RefToken` it minted resolves to nothing. What makes the trap
/// worth a child process is that the mistake looks like ordinary Swift: the
/// value is right there, fully formed, and every property on it compiles.
///
/// **This game cannot be played.** Examining the ledger traps.
struct InlineEntityGame: Game {
    let title = "Inline"
    let intro = "A study, and a ledger someone keeps adding to."

    let study = Location {
        name("Study")
        description("Books to the ceiling, and one ledger open on the desk.")
    }

    let ledger = Item {
        name("ledger")
        description("Columns of figures in a small hand.")
    }

    var rules: Rules {
        ledger.before(.examine) {
            // Declared here, so the bootstrap never saw it. Reading any
            // property asks the registry for an id it does not have.
            let quill = Item { name("ghost quill") }
            say("A \(quill.name) rests in the gutter.")
        }
    }

    var map: WorldMap {
        player.starts(in: study)
        ledger.starts(in: study)
    }
}

/// A describer that reads `command`, which works every time the player types
/// LOOK and dies on the opening look.
///
/// `GameWorld.begin()` builds its frame with no command — there was no input to
/// parse — and then describes the starting room, so this closure is asked for
/// its text before the game has a first turn. The same hole opens under any
/// daemon or each-turn rule reached that way. The trap's job is to say that the
/// property is turn-only, since nothing at the call site suggests it.
///
/// **This game cannot be played.** It traps on the opening banner, before the
/// player has typed anything.
struct OpeningCommandGame: Game {
    let title = "Opening"
    let intro = "A hall that would like to know what you asked for."

    let hall = Location {
        name("Hall")
    }

    var rules: Rules {
        hall.describe {
            "Bare boards, and an echo of \(command.verbPhrase)."
        }
    }

    var map: WorldMap {
        player.starts(in: hall)
    }
}
