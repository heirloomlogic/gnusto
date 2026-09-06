import GnustoTestSupport
import Testing

@testable import Gnusto

/// Issue #223: the author's code can re-enter the engine that is calling it, and
/// before this guard the process died with an unattributed `signal 10` — no test
/// name, no game, no room.
///
/// The guard sits at the seams where the engine calls author code rather than at
/// the entry points that reach them, which is what makes it cover more than the
/// issue listed. ``TurnFrame/describedText(of:)`` and
/// ``TurnFrame/presenceText(of:)`` invoke `describe { }` and `presence { }` from
/// inside the call producing the text, so everything a closure might call to get
/// back there is counted at one line: `describeSurroundings()`, `arrive(at:)`, and
/// a plain read of the entity's own `description` — the last of which reaches
/// neither the room describer nor `enter`, and so would have survived a guard
/// placed on those. ``DefaultActions/enter(_:frame:announcing:)`` is the second
/// seam, for an `onEnter` rule that enters its own room, and
/// ``Visibility/reachRuleAllows(_:for:frame:)`` the third, for a `reach { }` rule
/// that asks a reach question (issue #402). That last one never held the lock —
/// what it lacked was the count.
///
/// ## How the crash itself is exercised
///
/// The guard traps, because it cannot do anything else:
/// `describeSurroundings()` is a non-throwing `public func` and the rule tables it
/// reaches are `[EntityID: @Sendable () -> String]`, so a catchable `TurnInterrupt`
/// out of a `describe` closure is not expressible without making a public API
/// throwing at 63 call sites.
///
/// So the *decision* is split from the *trap*: ``Reentry/diagnostic(depth:entity:)``
/// is a pure function returning the message or nil, and both thresholds, both
/// wordings and the named entity are asserted against it directly below, in
/// process. The `fatalError` it feeds is then run for real, in a child process, by
/// the exit tests at the end — because a cap is worth nothing if the stack gets
/// there first, and only a real run can tell you it doesn't. Issue #227.
struct ReentryGuardTests {
    // MARK: - The diagnostic's threshold and wording

    @Test("each seam is silent up to and including its own cap")
    func eachSeamIsSilentUpToItsCap() {
        for seam in [Reentry.liveText, .walk, .reach] {
            #expect(seam.diagnostic(depth: 1, entity: "Cell") == nil)
            #expect(seam.diagnostic(depth: seam.cap, entity: "Cell") == nil)
        }
    }

    @Test("past the cap it names the entity and the shape that caused it")
    func diagnosticNamesTheEntityAndTheShape() throws {
        let live = try #require(
            Reentry.liveText.diagnostic(depth: Reentry.liveText.cap + 1, entity: "oak chest"))
        // The whole point of the issue: the failure used to name nothing.
        #expect(live.contains("oak chest"))
        #expect(live.hasPrefix("Gnusto: "))
        // All three ways into this seam, since any of them may be the culprit.
        #expect(live.contains("describe"))
        #expect(live.contains("presence"))
        #expect(live.contains("describeSurroundings()"))
        #expect(live.contains("arrive(at:)"))
        #expect(live.contains("description"))

        let walk = try #require(
            Reentry.walk.diagnostic(depth: Reentry.walk.cap + 1, entity: "Loop"))
        #expect(walk.contains("Loop"))
        #expect(walk.contains("onEnter"))
        #expect(walk.contains("enter(_:)"))
        // The two seams say different things; a shared message would send an
        // author reading about `onEnter` to look at a `describe` closure.
        #expect(!walk.contains("describeSurroundings()"))

        let reach = try #require(
            Reentry.reach.diagnostic(depth: Reentry.reach.cap + 1, entity: "plinth"))
        #expect(reach.contains("plinth"))
        #expect(reach.contains("reach { }"))
        #expect(reach.contains("isReachable"))
        // Third seam, third wording, for the same reason.
        #expect(!reach.contains("onEnter"))
        #expect(!reach.contains("describeSurroundings()"))
    }

    /// The deepest nesting any game in the suite was observed to reach, from
    /// instrumenting every `nested` call across all 1,479 tests.
    static let deepestObserved = 2

    @Test("every cap fires above real content")
    func capsClearRealContent() {
        // The floor half of the bracket. The ceiling half — that each cap is
        // still under the depth at which the stack gives out — is not assertable
        // between constants, and is the exit tests at the end.
        for seam in [Reentry.liveText, .walk, .reach] {
            #expect(seam.cap > Self.deepestObserved)
        }
        // And the expensive seam is rationed harder than the cheap ones: a
        // describer level costs twenty times a walk level, so a single cap for
        // all three would have to be the describer's and would ration the other
        // two by a ceiling that is not theirs. `walk` and `reach` share 32 —
        // they are not distinct from each other, only from `liveText`.
        #expect(Reentry.walk.cap > Reentry.liveText.cap)
        #expect(Reentry.reach.cap > Reentry.liveText.cap)
    }

    // MARK: - The counter

    @Test("nesting is counted per seam, and unwinds")
    func nestingIsCountedPerSeamAndUnwinds() throws {
        let frame = try Self.freshFrame()

        let depths = frame.nested(.liveText, within: .player) {
            let outer = frame.depth(of: .liveText)
            // A walk inside live text must not consume the describer's budget.
            let walk = frame.nested(.walk, within: .player) { frame.depth(of: .walk) }
            // Nor may a reach question asked from inside a describer, which is
            // an ordinary thing for one to do.
            let reach = frame.nested(.reach, within: .player) { frame.depth(of: .reach) }
            let inner = frame.nested(.liveText, within: .player) { frame.depth(of: .liveText) }
            return (outer: outer, walk: walk, reach: reach, inner: inner)
        }

        // Named rather than positional: three seams and two depths in one
        // literal is a mapping the reader has to hold, and holding it wrong is
        // how a swapped keypath passes.
        #expect(depths.outer == 1)
        #expect(depths.walk == 1, "a walk inside live text consumed the describer's budget")
        #expect(depths.reach == 1, "a reach inside live text consumed the describer's budget")
        #expect(depths.inner == 2)
        #expect(frame.depth(of: .reach) == 0, "the reach counter did not unwind")
        #expect(frame.depth(of: .liveText) == 0, "the live-text counter did not unwind")
        #expect(frame.depth(of: .walk) == 0, "the walk counter did not unwind")
    }

    @Test("the counter unwinds when the body throws")
    func theCounterUnwindsOnAThrow() throws {
        let frame = try Self.freshFrame()
        struct Boom: Error {}

        #expect(throws: Boom.self) {
            try frame.nested(.walk, within: .player) { throw Boom() }
        }
        // A `defer`, not a happy-path decrement: a throwing `onEnter` — a `die`
        // or a `refuse` from inside `enter(_:)` — is ordinary, and leaving the
        // depth raised would trap a later turn for something that already ended.
        #expect(frame.depth(of: .walk) == 0)
    }

    // MARK: - What the guard must not condemn

    @Test("a rule that looks every turn is nesting of one, forever")
    func lookingEveryTurnIsNeverNesting() async throws {
        // Twenty turns, each describing the gallery twice through its live
        // `describe { }` — once for the command, once from `afterEachTurn`. That
        // is forty entries into the guarded seam against a cap of eight, so a
        // counter that measured calls per turn, or one that never decremented,
        // traps long before the end. Both bugs die here.
        let turns = 20
        let transcript = try await play(EchoGame(), Array(repeating: "look", count: turns))

        #expect(occurrences(of: "The gallery answers.", in: transcript) == turns)
        #expect(occurrences(of: "Hung with nothing at all.", in: transcript) >= turns)
    }

    @Test("a reach rule may ask about another item's reach, every turn, forever")
    func aReachRuleMayAskAboutAnotherItemEveryTurn() async throws {
        // Two things at once, because one command proves both. The lid's gate is
        // written in terms of the latch's, so every `open lid` enters the seam
        // twice — legitimate depth 2, the reach seam's `SlideGame`. Twenty of
        // them is forty entries against a cap of 32, so a counter that measured
        // calls per turn, or one that never decremented, traps well before the
        // crossing. Both bugs die here, as they do for live text in
        // `lookingEveryTurnIsNeverNesting`.
        let turns = 20
        let transcript = try await play(
            LatchedLidGame(),
            Array(repeating: "open lid", count: turns) + ["cross", "open lid"])

        // Refused every turn while the latch is out of reach, and the count is
        // what makes this about frequency rather than one lucky turn.
        #expect(
            occurrences(of: "The lid is as far off as its latch.", in: transcript) == turns)
        #expect(transcript.contains("You cross to the crate."))
        // Past the crossing both gates open and the verb answers — the one line
        // here that a trap could not have produced, since the trap is a
        // `fatalError` and would have taken the process with it.
        #expect(transcript.contains("Opened."))
    }

    @Test("a chain of rooms may pass the player along")
    func aChainOfRoomsMayPassThePlayerAlong() async throws {
        // Four nested `enter(_:)` calls — the deepest legitimate walk shape, and
        // the reason the walk cap is not the describer's.
        let transcript = try await play(SlideGame(), ["north"])

        #expect(transcript.contains("You come to rest."))
        #expect(transcript.contains("Sump"))
        #expect(transcript.contains("Level ground, and a smell of standing water."))
    }

    // MARK: - The trap, run for real

    // The platform policy for exit tests is in `Package.swift`.
    #if GNUSTO_EXIT_TESTS

    /// Each cap has to sit under the depth at which the stack runs out, and that
    /// is not a fact two constants can state. ``Reentry/cap``'s table records
    /// where the ceiling was when it was hand-measured — but a measurement
    /// written down is a comment, and the thing it measures moves. Fatten a
    /// describer level and the real ceiling drops; the cap stays where it is, the
    /// guard never fires, and #223's crash comes back as an unattributed
    /// `signal 10`.
    ///
    /// So these run the runaway for real, in a child process, on the same
    /// cooperative thread the caps are sized against, and read what it printed
    /// on the way out. Asserting the *depth* in the message is what makes them
    /// about the margin rather than the wording: `cap + 1` levels means the cap
    /// ended the recursion, where silence would mean the stack did.
    @Test("the live-text cap fires before the stack does")
    func liveTextCapFiresBeforeTheStackDoes() async throws {
        let result = await #expect(
            processExitsWith: .failure, observing: [\.standardErrorContent]
        ) {
            _ = try await play(LoopCellGame(), ["look"])
        }
        // Two needles, both of which only a live run can show: the entity name
        // proves `displayName(of:)` is threaded through `nested`, and the depth
        // proves the cap ended the recursion. The message's *shape* sentence is
        // asserted in process by `diagnosticNamesTheEntityAndTheShape` above —
        // re-asserting it here would break this test for a wording edit that has
        // nothing to do with the margin.
        expectTrap(result, says: "Cell", "\(Reentry.liveText.cap + 1) levels deep")
    }

    @Test("the walk cap fires before the stack does")
    func walkCapFiresBeforeTheStackDoes() async throws {
        let result = await #expect(
            processExitsWith: .failure, observing: [\.standardErrorContent]
        ) {
            _ = try await play(KnotGame(), ["north"])
        }
        expectTrap(result, says: "Knot", "\(Reentry.walk.cap + 1) levels deep")
    }

    @Test("the reach cap fires before the stack does")
    func reachCapFiresBeforeTheStackDoes() async throws {
        let result = await #expect(
            processExitsWith: .failure, observing: [\.standardErrorContent]
        ) {
            _ = try await play(MirrorReachGame(), ["take plinth"])
        }
        expectTrap(result, says: "plinth", "\(Reentry.reach.cap + 1) levels deep")
    }

    #endif

    // MARK: - Support

    /// A live frame over a one-room game, for asserting on the counters
    /// directly.
    private static func freshFrame() throws -> TurnFrame {
        let (definition, state) = try Bootstrap.buildCore(MiniGame())
        return TurnFrame(definition: definition, state: state)
    }
}

extension TurnFrame {
    /// One seam's current depth. Test-only sugar over `with`, which is where
    /// the counters actually live.
    fileprivate func depth(of seam: Reentry) -> Int {
        with { $0[keyPath: seam.depth] }
    }
}
