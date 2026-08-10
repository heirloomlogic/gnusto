import GnustoTestSupport
import Testing

@testable import Gnusto

/// Issue #223: the author's code can re-enter the engine that is calling it, and
/// before this guard the process died with an unattributed `signal 10` — no test
/// name, no game, no room.
///
/// The guard sits at the two seams where the engine calls author code rather than
/// at the entry points that reach them, which is what makes it cover more than the
/// issue listed. ``TurnFrame/describedText(of:)`` and
/// ``TurnFrame/presenceText(of:)`` invoke `describe { }` and `presence { }` from
/// inside the call producing the text, so everything a closure might call to get
/// back there is counted at one line: `describeSurroundings()`, `arrive(at:)`, and
/// a plain read of the entity's own `description` — the last of which reaches
/// neither the room describer nor `enter`, and so would have survived a guard
/// placed on those. ``DefaultActions/enter(_:frame:announcing:)`` is the second
/// seam, for an `onEnter` rule that enters its own room.
///
/// ## Why the crash itself is not exercised here
///
/// The guard traps, because it cannot do anything else:
/// `describeSurroundings()` is a non-throwing `public func` and the rule tables it
/// reaches are `[EntityID: @Sendable () -> String]`, so a catchable `TurnInterrupt`
/// out of a `describe` closure is not expressible without making a public API
/// throwing at 63 call sites. A `fatalError` cannot be caught in-process and the
/// suite has no exit-code harness — the same position `IntentActionTests` records
/// for `proceed()`'s misuse traps.
///
/// So the *decision* is split from the *trap*: ``Reentry/diagnostic(depth:entity:)``
/// is a pure function returning the message or nil, and it is asserted directly
/// below — both thresholds, both wordings and the named entity all covered
/// in-process. Only the `fatalError` it feeds is taken on trust, which is the shape
/// `StackReport.line(for:game:)` and `BootstrapStackTests` already use.
struct ReentryGuardTests {
    // MARK: - The diagnostic's threshold and wording

    @Test("each seam is silent up to and including its own cap")
    func eachSeamIsSilentUpToItsCap() {
        for seam in [Reentry.liveText, .walk] {
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
    }

    /// The depths at which each seam exhausts the 512 KB a Swift Testing
    /// cooperative thread gives, measured in a debug build on macOS arm64. A cap
    /// at or above these never fires — which is what the issue's proposed 32 did
    /// on the describer, and how these came to be measured at all.
    static let cliffs: [Reentry: Int] = [.liveText: 10, .walk: 216]

    /// The deepest nesting any game in the suite was observed to reach, from
    /// instrumenting every `nested` call across all 1,479 tests.
    static let deepestObserved = 2

    @Test("every cap fires above real content and below the stack")
    func capsAreBracketedByMeasurement() throws {
        for seam in [Reentry.liveText, .walk] {
            let cliff = try #require(Self.cliffs[seam])
            // Both bounds, because either alone permits a useless number: a cap
            // over the cliff never fires, and a cap under real content condemns
            // games that were doing nothing wrong.
            #expect(seam.cap > Self.deepestObserved)
            #expect(seam.cap < cliff)
        }
        // And the two are genuinely different numbers — a walk level costs a
        // twentieth of a describer level, so one cap for both would ration the
        // cheap seam by the expensive one's ceiling.
        #expect(Reentry.walk.cap > Reentry.liveText.cap)
    }

    // MARK: - The counter

    @Test("nesting is counted per seam, and unwinds")
    func nestingIsCountedPerSeamAndUnwinds() throws {
        let frame = try Self.freshFrame()

        let depths = frame.nested(.liveText, within: .player) { () -> [Int] in
            let outer = frame.depth(of: .liveText)
            // A walk inside live text must not consume the describer's budget.
            let walk = frame.nested(.walk, within: .player) { frame.depth(of: .walk) }
            let inner = frame.nested(.liveText, within: .player) { frame.depth(of: .liveText) }
            return [outer, walk, inner]
        }

        #expect(depths == [1, 1, 2])
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

    @Test("a chain of rooms may pass the player along")
    func aChainOfRoomsMayPassThePlayerAlong() async throws {
        // Four nested `enter(_:)` calls — the deepest legitimate walk shape, and
        // the reason the walk cap is not the describer's.
        let transcript = try await play(SlideGame(), ["north"])

        #expect(transcript.contains("You come to rest."))
        #expect(transcript.contains("Sump"))
        #expect(transcript.contains("Level ground, and a smell of standing water."))
    }

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
