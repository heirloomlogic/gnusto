import GnustoTestSupport
import Testing

@testable import Gnusto

/// Live proxy reads and writes round-trip through the turn frame into
/// committed state, observed through subsequent turns.
struct ProxyFrameTests {
    @Test func proxiesReadAndWriteLiveState() async throws {
        let transcript = try await play(
            ProxyProbeGame(),
            ["take candle", "examine candle", "score", "look"])

        // Inside the take turn: reads of isLit, player.location equality,
        // and the @Global increment all see live values. `isHeld` reflects
        // `Placement.heldBy(.player)`: false before the take, true after.
        expectInOrder(
            transcript,
            [
                "lit=true here=true counter=3 heldBefore=false",
                "Taken.",
                "held=true worn=false",
            ])

        // The description override committed and is visible next turn.
        #expect(transcript.contains("Now dusted with fingerprints."))
        #expect(!transcript.contains("Plain wax."))

        // player.score += 5 committed.
        #expect(transcript.contains("Your score is 5 of a possible 10"))

        // porch.isLit = false committed: the later "look" is pitch black.
        #expect(turnOutput(of: "look", in: transcript).contains("pitch black"))
    }

    @Test func globalsPersistAcrossTurns() async throws {
        // Each refused take increments `blunders` before refusing; the
        // pre-refusal mutation must persist into committed state.
        let transcript = try await play(
            OrderProbeGame(),
            ["drop widget", "take widget", "take widget", "examine widget"])
        #expect(transcript.contains("blunders=2"))
    }

    // MARK: - What outliving a turn looks like from in process

    /// The mechanism the "outlived its turn" trap below rests on: a retired
    /// frame is dead, and says so. Asserted here at a millisecond so the child
    /// process is spent on the wording alone.
    @Test func retiringAFrameKillsIt() throws {
        let (definition, state) = try Bootstrap.buildCore(MiniGame())
        let frame = TurnFrame(definition: definition, state: state)
        #expect(frame.isAlive)

        let scratch = frame.retire()
        #expect(!frame.isAlive)
        #expect(!scratch.isLive)
    }

    /// What the trap must *not* condemn, and the reason it names a `Task` rather
    /// than the escaping closure it used to also blame.
    ///
    /// A closure stashed in one turn and called in the next resolves against the
    /// turn that *calls* it: `Ctx.frame` is a `@TaskLocal` and proxies re-read it
    /// at use time, so the closure reads live state and reports the second turn's
    /// tally, not the first's. Wrong, and invisible to the engine — which is why
    /// the exit test below needs a `Task` to reach the guard at all.
    @Test("a closure stashed in one turn and called in the next reads the calling turn")
    func staleClosuresReadTheCallingTurn() async throws {
        defer { StashGame.stashed = nil }
        let transcript = try await play(StashGame(), ["pull rope", "examine rope"])
        #expect(transcript.contains("the stashed closure reads tally=2"))
    }

    // The platform policy for exit tests is in `Package.swift`.
    #if GNUSTO_EXIT_TESTS

    /// Every proxy read above goes through the turn frame. Ask for one where
    /// there is no turn — from `main`, from a `map` block, from a `Task` an
    /// author spawned — and there is no state to read and no sensible value to
    /// invent, so it traps. What makes the trap useful is that it says which
    /// properties are turn-only, since the author is holding a `Game` value
    /// that looks perfectly alive. Issue #227.
    @Test("reading live state with no turn running traps, and names the turn-only properties")
    func readingStateOutsideATurnTraps() async throws {
        let result = await #expect(
            processExitsWith: .failure, observing: [\.standardErrorContent]
        ) {
            _ = MiniGame().player.score
        }
        expectTrap(
            result,
            says: "live world state was accessed outside a game turn",
            "only available inside rule bodies")
    }

    /// The second of `Ctx.current`'s two guards, and the harder of the pair to
    /// diagnose: the frame is *there*, it is just dead. An author who hands a
    /// rule's work to a `Task` gets a stack trace pointing into their own
    /// closure with nothing in it to say the turn ended two lines above, so this
    /// trap's wording is the whole of the diagnosis. Issue #229.
    ///
    /// The `Task` is what makes the guard reachable at all — see
    /// ``AfterthoughtGame``, which spells out why every other way of arriving
    /// late lands somewhere else.
    @Test("state read from a task that outlived its turn traps, and says so")
    func readingStateAfterTheTurnCommittedTraps() async throws {
        let result = await #expect(
            processExitsWith: .failure, observing: [\.standardErrorContent]
        ) {
            _ = try await play(AfterthoughtGame(), ["push lever"])
            // `play` has returned, so `GameWorld.commit(_:)` has retired the
            // frame. Only now is the escaped task let go, which is what makes
            // the trap a certainty rather than a race — the thing #229 was
            // waiting for.
            AfterthoughtGame.latch.continuation.finish()
            guard let afterwards = AfterthoughtGame.afterwards else {
                // A fixture that spawned no task would exit 0, which already
                // fails the expectation — but it fails it as "no result", which
                // reads like a harness problem. Trapping here says which.
                fatalError("Gnusto test: the fixture spawned no task; nothing ran.")
            }
            await afterwards.value
        }
        // Needles the sibling above cannot match. Both messages contain "rule
        // body", so a needle either could satisfy would let a regression that
        // swapped the two guards pass.
        expectTrap(result, says: "outlived its turn", "do all their work synchronously")
    }

    /// The engine's most consequential authoring rule — entities must be stored
    /// properties, because the bootstrap finds them by reflection — has no
    /// compile-time enforcement, so the trap is the whole of the teaching. An
    /// inline `Item` is valid Swift, fully formed, and every property on it
    /// compiles; only the registry knows it isn't real. Issue #229.
    @Test("an entity built inside a rule body traps, and says where entities must live")
    func inlineEntitiesTrap() async throws {
        let result = await #expect(
            processExitsWith: .failure, observing: [\.standardErrorContent]
        ) {
            _ = try await play(InlineEntityGame(), ["examine ledger"])
        }
        // The advice half is the half that does the work: "not part of the
        // running game" alone leaves an author staring at a value that plainly
        // exists.
        expectTrap(
            result,
            says: "not part of the running game",
            "stored properties of your Game type")
    }

    /// `command` is available in every rule body and every live-text closure
    /// the engine evaluates. This includes the opening look, which #395
    /// deliberately reversed from #229: the opening, UNDO and RESTORE looks
    /// used to build a command-less frame whose `command` accessor trapped, so
    /// a describer that worked for every LOOK the player typed died on the
    /// game's first look. They now describe as a LOOK — in fiction what they
    /// are — and the trap is left only for reads outside the engine.
    @Test("a describer reading command sees the opening look as a look")
    func theOpeningLookHasACommandToRead() async throws {
        // No commands at all: the read happens during `GameWorld.begin()`
        // describing the starting room.
        let transcript = try await play(OpeningCommandGame(), [])
        #expect(transcript.contains("Bare boards, and an echo of look."))
    }

    #endif
}
