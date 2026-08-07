/// How deep one piece of work drove the stack, measured rather than guessed.
///
/// A thread's stack below the current frame is memory the thread already owns and
/// nothing is using, so it can be painted with a sentinel before the work runs and
/// read back afterward: whatever no longer holds the sentinel was written over by a
/// frame. That turns "how much room is left?" — the question issue #174 spent four
/// milestones unable to answer, and paid eleven declarations to guess at — into a
/// number.
///
/// Nothing on the play path calls this. ``DeepStack/run(stackSize:measuringStack:_:)``
/// leaves it off unless asked, because every rung dirties a page that the
/// reservation would otherwise never cost.
enum StackProbe {
    /// One measurement of one thread's stack.
    struct Reading: Sendable {
        /// How far below the probe's own frame the deepest overwritten rung sat.
        /// Resolution is ``rungSpacing``, and so is the smallest figure reportable:
        /// the true peak lies between this and one rung shallower.
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

    /// Arbitrary, and unlikely to arrive by accident in eight aligned bytes.
    private static let sentinel: UInt64 = 0x5354_4143_4B_5F_4750

    /// Clearance left alone at the bottom of the stack, so nothing is ever written
    /// near the guard page.
    ///
    /// A sixteenth of the budget, and never less than 64 KB. That is orders of
    /// magnitude more than the few kilobytes of thread-entry frames sitting between
    /// the mapping's top and this probe's anchor, which is the only slack the
    /// arithmetic in ``measure(within:_:)`` has to absorb.
    ///
    /// - Parameter stackSize: the worker's whole stack.
    /// - Returns: how much of the bottom to leave untouched.
    private static func margin(of stackSize: Int) -> Int {
        max(64 << 10, stackSize / 16)
    }

    /// Runs `work` on the current thread and reports how far down the stack it went.
    ///
    /// **Sound only on a thread ``DeepStack`` created**, which is the only place it
    /// is called from. That is what lets the bounds be arithmetic rather than a
    /// question for the OS: the caller sized the stack itself, and this frame sits a
    /// few kilobytes below the thread's first, so everything from here down to
    /// `stackSize` less ``margin(of:)`` is certainly inside the thread's own
    /// mapping. On an arbitrary thread the same arithmetic would be a guess, and a
    /// wrong guess walks into the guard page.
    ///
    /// - Parameters:
    ///   - stackSize: the worker's whole stack, as it was requested of the thread.
    ///   - work: the work to measure. Its frames are what the reading counts.
    /// - Returns: what `work` returned, and how deep it drove the stack — with a nil
    ///   reading when the stack is too small to ladder at all.
    static func measure<Value>(
        within stackSize: Int,
        _ work: () -> Value
    ) -> (value: Value, reading: Reading?) {
        var anchor: UInt64 = 0
        let top = withUnsafeMutablePointer(to: &anchor) { UInt(bitPattern: $0) }

        // A rung's width of clearance below this frame; nothing is measured in it.
        let ceiling = (top - UInt(rungSpacing)) & ~UInt(7)
        let reach = min(ladderDepth, stackSize - margin(of: stackSize))
        guard reach > rungSpacing, ceiling > UInt(reach) else { return (work(), nil) }
        let floor = ceiling - UInt(reach)

        let rungs = reach / rungSpacing + 1
        for index in 0..<rungs {
            rung(index, below: ceiling)?.storeBytes(of: sentinel, as: UInt64.self)
        }

        let value = work()

        // The deepest overwritten rung, not the shallowest surviving one: a frame
        // holding a large uninitialized buffer can step over a rung without writing
        // it, and stopping at the first survivor would believe that gap.
        let deepest =
            (0..<rungs).last {
                rung($0, below: ceiling)?.loadUnaligned(as: UInt64.self) != sentinel
            } ?? 0

        return (
            value,
            Reading(
                highWater: deepest * rungSpacing + Int(top - ceiling),
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
