import Dispatch
import Foundation

/// Runs one piece of work on a thread whose stack this package sizes itself.
///
/// `Bootstrap.build` evaluates every declaration a game and its content bundles
/// make, and the stack that costs scales with the whole declaration surface. Where
/// it runs decides whether that is affordable: a shipped game boots on the main
/// thread's 8 MB and is always fine, while a Swift Testing body runs on a
/// cooperative thread with **512 KB**, and the overflow arrives as an unattributed
/// `signal 10` or `signal 11` that kills the whole test process without naming a
/// game, a bundle or a declaration.
///
/// Issue #174 is four milestones of paying for that gap. Dungeon reached 355 KB of
/// the 512 in a debug build — 69% — and the last three milestones each bought their
/// margin by deleting content, eleven declarations in all, one of them a real piece
/// of the source. Owning the thread makes the budget one number, written down here
/// and the same everywhere, instead of a cliff whose position nobody could measure.
enum DeepStack {
    /// The worker's stack: reserved, not resident. A thread stack is mapped lazily,
    /// so an untouched reservation costs address space and nothing else — which is
    /// why this can be generous. It is 45× the largest bootstrap yet measured, and
    /// the size issue #174 had already proved sufficient by hand.
    static let stackSize = 16 << 20

    /// Runs `work` on a fresh worker and returns what it returned.
    ///
    /// The caller blocks until the worker finishes. That is safe from a cooperative
    /// thread, and safe under the lock `cachedWorld` holds, because the worker is a
    /// thread rather than a task: it needs nothing from the blocked caller to make
    /// progress, so the wait always ends.
    ///
    /// - Parameters:
    ///   - stackSize: how much stack to give the worker. Defaults to the budget
    ///     above; a test measuring what some *other* thread's budget would afford
    ///     passes that thread's size instead.
    ///   - measuringStack: paint the worker's stack and report how deep the work
    ///     went. Off by default — every rung dirties a page the reservation would
    ///     not otherwise cost.
    ///   - work: the work to run.
    /// - Throws: whatever `work` threw, on the calling thread.
    /// - Returns: the work's value, and its high-water mark when measured.
    static func run<Value: Sendable>(
        stackSize: Int = Self.stackSize,
        measuringStack: Bool = false,
        _ work: @escaping @Sendable () throws -> Value
    ) throws -> (value: Value, reading: StackProbe.Reading?) {
        let outcome = Outcome<Value>()
        let finished = DispatchSemaphore(value: 0)

        let worker = Thread {
            guard measuringStack else {
                outcome.result = Result(catching: work)
                finished.signal()
                return
            }
            let measured = StackProbe.measure(within: stackSize) { Result(catching: work) }
            outcome.result = measured.value
            outcome.reading = measured.reading
            finished.signal()
        }
        worker.name = "gnusto.bootstrap"
        // Both of these are read when the thread starts and ignored if set after.
        worker.stackSize = stackSize
        #if canImport(Darwin)
        // `DispatchSemaphore.wait()` donates no priority, and the `os_unfair_lock`
        // behind a `Mutex` boosts its holder but cannot boost across to this thread
        // — so the worker takes the caller's band rather than the default. Darwin
        // only: `qualityOfService` is not part of swift-corelibs-foundation's
        // `Thread`, and the inversion it guards against is a Darwin lock's.
        worker.qualityOfService = Thread.current.qualityOfService
        #endif
        worker.start()
        finished.wait()

        guard let result = outcome.result else {
            fatalError("Gnusto: the bootstrap worker finished without a result.")
        }
        return (try result.get(), outcome.reading)
    }

    /// A class rather than a `Mutex` because a non-copyable mutex cannot be captured
    /// by the escaping thread body. The semaphore's signal and wait supply the
    /// ordering, which is what makes the unchecked conformance honest: the worker's
    /// write happens before the caller's read, with nothing racing in between.
    private final class Outcome<Value>: @unchecked Sendable {
        var result: Result<Value, any Error>?
        var reading: StackProbe.Reading?
    }
}

/// The `GNUSTO_STACK_REPORT` switch: what a bootstrap actually used of
/// ``DeepStack/stackSize``, on stderr, one line per game booted.
///
/// This is the author-facing half of issue #174. The budget it reports against is
/// large enough that no game is likely to meet it, but "likely" is what the last
/// four milestones each believed — so the number is available for the asking rather
/// than only after a crash. It does not go through `GameDefinition.warnings`:
/// stack usage varies with build mode, platform and address-space layout, and a
/// machine-dependent figure in an author-facing list would fire on some machines
/// and not others.
enum StackReport {
    /// Whether the report was asked for, in the manner of `GNUSTO_PLAIN`: a flag,
    /// so any value counts, including an empty one.
    ///
    /// - Parameter environment: the environment to read, injectable for tests.
    /// - Returns: whether to measure and report.
    static func isEnabled(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        environment["GNUSTO_STACK_REPORT"] != nil
    }

    /// One reading, rendered in kilobytes against the budget.
    ///
    /// - Parameters:
    ///   - reading: the measurement, or nil when none was taken.
    ///   - game: the game the reading is of, named so a suite booting several says
    ///     which is which.
    /// - Returns: the line to write, or nil when there is nothing to say.
    static func line(for reading: StackProbe.Reading?, game: String) -> String? {
        guard let reading else { return nil }
        // A high-water that reached the end of the ladder is a floor, not a
        // measurement, and the line has to say so rather than imply precision.
        let exhausted = reading.highWater >= reading.laddered
        return """
            Gnusto: \(game) bootstrapped using \(exhausted ? "at least " : "")\
            \(reading.highWater / 1024) KB of the \(DeepStack.stackSize / 1024) KB \
            bootstrap stack.
            """
    }
}
