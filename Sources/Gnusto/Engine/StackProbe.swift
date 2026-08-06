#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// How deep one piece of work drove the stack, measured rather than guessed.
///
/// A thread's stack below the current frame is memory the thread already owns and
/// nothing is using, so it can be painted with a sentinel before the work runs and
/// read back afterward: whatever no longer holds the sentinel was written over by a
/// frame. That turns "how much room is left?" — the question issue #174 spent four
/// milestones unable to answer, and paid eleven declarations to guess at — into a
/// number.
///
/// Nothing on the play path calls this. ``DeepStack/run(measuringStack:_:)`` leaves
/// it off unless asked, because every rung dirties a page that the reservation would
/// otherwise never cost.
enum StackProbe {
    /// One measurement of one thread's stack.
    struct Reading: Sendable {
        /// How far below the probe's own frame the deepest overwritten rung sat.
        /// Resolution is ``rungSpacing``: the true peak lies between this figure and
        /// one rung deeper. Zero means the work stayed above the first rung.
        let highWater: Int

        /// How far the ladder reached. A ``highWater`` equal to this is a floor
        /// rather than a measurement — the work went at least that deep and the
        /// ladder ran out before it did.
        let laddered: Int
    }

    /// 4 KB rungs — one page each, and fine enough to resolve the hundreds of
    /// kilobytes a real bootstrap uses. Coarser rungs would bucket Dungeon's whole
    /// debug peak into single digits.
    static let rungSpacing = 4 << 10

    /// How far down to paint. Four megabytes covers an order of magnitude more than
    /// any measured bootstrap, and costs 1,024 dirtied pages while a reading is
    /// being taken.
    static let ladderDepth = 4 << 20

    /// Clearance left above the mapping's guard page. Sixteen pages on every page
    /// size this package runs on, and nothing is painted or measured inside it.
    private static let guardBand = 64 << 10

    /// Arbitrary, and unlikely to arrive by accident in eight aligned bytes.
    private static let sentinel: UInt64 = 0x5354_4143_4B_5F_4750

    /// The lowest address of the calling thread's own stack, or nil if the OS will
    /// not say.
    ///
    /// Asked of the thread rather than inferred from the address of a local: the
    /// mapping ends in a guard page, and arithmetic that guesses where walks into it.
    private static func lowestAddress() -> UInt? {
        #if canImport(Darwin)
        // Darwin reports the *high* address, the stack growing down from it.
        let high = UInt(bitPattern: pthread_get_stackaddr_np(pthread_self()))
        return high - UInt(pthread_get_stacksize_np(pthread_self()))
        #elseif canImport(Glibc)
        var attributes = pthread_attr_t()
        guard pthread_getattr_np(pthread_self(), &attributes) == 0 else { return nil }
        defer { pthread_attr_destroy(&attributes) }
        var low: UnsafeMutableRawPointer?
        var size = 0
        // Glibc reports the *low* address, which is the one wanted here.
        guard pthread_attr_getstack(&attributes, &low, &size) == 0 else { return nil }
        return UInt(bitPattern: low)
        #else
        return nil
        #endif
    }

    /// Runs `work` and reports how far down the stack it went.
    ///
    /// - Parameter work: the work to measure. Its frames are what the reading counts.
    /// - Returns: what `work` returned, and how deep it drove the stack — or a nil
    ///   reading when the OS would not name the thread's bounds, since a made-up
    ///   number would be worse than none.
    static func measure<Value>(_ work: () -> Value) -> (value: Value, reading: Reading?) {
        var anchor: UInt64 = 0
        let top = withUnsafeMutablePointer(to: &anchor) { UInt(bitPattern: $0) }

        // A rung's width of clearance below this frame, and the guard band above the
        // guard page. Nothing is measured in either, and nothing is written to them.
        let ceiling = (top - UInt(rungSpacing)) & ~UInt(7)
        guard let low = lowestAddress(), ceiling > low + UInt(guardBand) else {
            return (work(), nil)
        }
        let floor = max(low + UInt(guardBand), ceiling - UInt(min(ladderDepth, Int(ceiling))))

        let rungs = Int((ceiling - floor) / UInt(rungSpacing)) + 1
        for rung in 0..<rungs {
            Self.rung(rung, below: ceiling)?.storeBytes(of: sentinel, as: UInt64.self)
        }

        let value = work()

        // The deepest overwritten rung, not the shallowest surviving one: a frame
        // holding a large uninitialized buffer can step over a rung without writing
        // it, and stopping at the first survivor would believe that gap.
        let deepest =
            (0..<rungs).last { Self.rung($0, below: ceiling)?.loadUnaligned(as: UInt64.self) != sentinel } ?? 0

        return (
            value,
            Reading(
                highWater: deepest == 0 ? 0 : Int(top - (ceiling - UInt(deepest * rungSpacing))),
                laddered: Int(top - floor))
        )
    }

    /// The address of one rung of the ladder.
    ///
    /// - Parameters:
    ///   - index: which rung, counting down from the ceiling.
    ///   - ceiling: the ladder's highest address.
    /// - Returns: a pointer to the rung.
    private static func rung(_ index: Int, below ceiling: UInt) -> UnsafeMutableRawPointer? {
        UnsafeMutableRawPointer(bitPattern: ceiling - UInt(index * rungSpacing))
    }
}
