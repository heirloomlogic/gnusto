import Foundation
import Testing

@testable import Dungeon
@testable import Gnusto

/// Issue #174: the bootstrap runs on a stack this package sizes, and how much of it
/// a game uses is a number rather than a guess.
///
/// The failure these replace named nothing. A game whose declarations outgrew the
/// 512 KB a Swift Testing cooperative thread gives killed the whole test process
/// with `signal 10` — no game, no bundle, no declaration, and no way to tell how
/// close the next one was. Every assertion below exists so that a game approaching
/// the limit says so in a sentence.
struct BootstrapStackTests {
    /// The measured figures this suite is calibrated against, from a debug build on
    /// macOS arm64. Release is roughly a quarter of each.
    static let dungeonMeasured = 355 << 10
    static let initMeasured = 70 << 10

    /// What a Swift Testing cooperative thread actually gives a test body. Every
    /// budget below is a fraction of this, because this is the number that was
    /// killing the suite.
    static let cooperativeStack = 512 << 10

    /// Eleven times the largest bootstrap ever measured, and half the ladder — a
    /// reading at ``StackProbe/ladderDepth`` is a floor, not a measurement, so the
    /// two assertions cannot both be live at once unless this stays under it. Far
    /// enough from 355 KB that build mode, platform and address-space layout cannot
    /// flake it; close enough that an order-of-magnitude regression fails here
    /// rather than in a signal.
    static let ceiling = StackProbe.ladderDepth / 2

    @Test("the worker is granted the stack it asks for")
    func workerGetsTheStackItAsksFor() throws {
        let granted = try DeepStack.run { Thread.current.stackSize }.value
        #expect(
            granted >= DeepStack.stackSize,
            """
            The worker asked for \(DeepStack.stackSize) bytes and was given \
            \(granted). A silently capped or rounded stack presents as "the fix \
            didn't work", with no other symptom.
            """)
    }

    @Test("a @TaskLocal binding resolves on the worker")
    func taskLocalResolvesOnTheWorker() throws {
        // `Bootstrap.buildCore` binds `Ctx.frame` around rule registration, and a
        // task-local is bound to the *task* — of which a raw thread has none. The
        // runtime's thread-local fallback carries it instead. If that ever stops
        // being true, every `describe {}` and `ScoreDeclaring` body traps, so this
        // asserts it directly rather than inferring it from a green suite.
        let resolved = try DeepStack.run { () -> Bool in
            let (definition, state) = try Bootstrap.buildCore(MiniGame())
            let frame = TurnFrame(definition: definition, state: state)
            let inside = Ctx.$frame.withValue(frame) { Ctx.frame != nil }
            return inside && Ctx.frame == nil
        }.value
        #expect(resolved, "@TaskLocal did not resolve on the bootstrap worker")
    }

    @Test("Dungeon's bootstrap stays well inside the budget")
    func dungeonStaysInsideTheBudget() throws {
        let reading = try #require(
            DeepStack.run(measuringStack: true) { try Bootstrap.buildCore(Dungeon()) }.reading)

        #expect(
            reading.highWater < reading.laddered,
            """
            The ladder ran out at \(reading.laddered / 1024) KB, so \
            \(reading.highWater / 1024) KB is a floor and not a measurement. Raise \
            StackProbe.ladderDepth before reading anything into it.
            """)
        #expect(
            reading.highWater < Self.ceiling,
            """
            Dungeon's bootstrap used \(reading.highWater / 1024) KB of stack, over \
            the \(Self.ceiling / 1024) KB this test allows and against \
            \(Self.dungeonMeasured / 1024) KB when it was calibrated. The budget is \
            \(DeepStack.stackSize / 1024) KB, so nothing is broken yet — but \
            something grew by an order of magnitude, and that is worth knowing \
            before it is worth crashing over.
            """)
    }

    @Test("Game.init() is measured against the budget it actually runs on")
    func gameInitIsMeasuredAgainstTheCallersBudget() throws {
        // Construction happens on the *caller's* stack — `Dungeon()` is evaluated as
        // an argument before `build` is entered — so it is the one term the hop does
        // not cover. It was a fifth of the bootstrap's cost when measured, which is
        // why the hop stops at `build`.
        //
        // So this measures it where it runs: a worker sized to the 512 KB a
        // cooperative thread gives, not the bootstrap's 16 MB. Measuring on the big
        // worker would pass a `Dungeon()` that had grown to 600 KB, and reintroduce
        // the exact unattributed signal this issue was about.
        let budget = Self.cooperativeStack
        let reading = try #require(
            DeepStack.run(stackSize: budget, measuringStack: true) { _ = Dungeon() }.reading)
        #expect(
            reading.highWater < budget / 2,
            """
            Constructing Dungeon() used \(reading.highWater / 1024) KB of the \
            \(budget / 1024) KB a cooperative thread gives, against \
            \(Self.initMeasured / 1024) KB when it was calibrated. This runs on the \
            caller's stack, not the bootstrap worker's, so that is the whole budget \
            for it — and if it is approaching half, construction has to be deferred \
            onto the worker too.
            """)
    }

    @Test("a bootstrap error survives the hop to the worker and back")
    func bootstrapErrorsSurviveTheHop() {
        // The ~34 files that assert on `BootstrapError` cover this incidentally;
        // this one says out loud that crossing a thread is not allowed to swallow,
        // wrap or reorder a diagnostic.
        #expect {
            try Bootstrap.build(BrokenGame())
        } throws: { error in
            guard let bootstrapError = error as? BootstrapError else { return false }
            return bootstrapError.diagnostics.count >= 4
                && bootstrapError.description.contains("player.starts(in:)")
        }
    }

    @Test("the report says what it knows and no more")
    func theReportSaysWhatItKnows() {
        // A reading that reached the end of the ladder is a floor, not a
        // measurement, and the line has to say so rather than imply a precision it
        // does not have.
        let measured = StackProbe.Reading(highWater: 360 << 10, laddered: 4 << 20)
        let exhausted = StackProbe.Reading(highWater: 4 << 20, laddered: 4 << 20)

        #expect(
            StackReport.line(for: measured, game: "Dungeon")
                == "Gnusto: Dungeon bootstrapped using 360 KB of the 16384 KB bootstrap stack.")
        #expect(
            StackReport.line(for: exhausted, game: "Dungeon")
                == """
                Gnusto: Dungeon bootstrapped using at least 4096 KB of the 16384 KB \
                bootstrap stack.
                """)
        // No reading is silence, not a zero.
        #expect(StackReport.line(for: nil, game: "Dungeon") == nil)
    }

    @Test("the report is off unless it is asked for")
    func theReportIsOffUnlessAskedFor() {
        #expect(StackReport.isEnabled(environment: [:]) == false)
        // A flag, not a setting, in the manner of GNUSTO_PLAIN: any value counts.
        #expect(StackReport.isEnabled(environment: ["GNUSTO_STACK_REPORT": ""]))
        #expect(StackReport.isEnabled(environment: ["GNUSTO_STACK_REPORT": "1"]))
    }
}
