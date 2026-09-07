/// A one-way Bool: it starts down, something trips it, and it stays up for
/// the rest of the game.
///
/// ```swift
/// @Latch var crawlBeatDone
/// // … in a rule body:
/// guard $crawlBeatDone.trips() else { return }
/// ```
///
/// It is a ``Global`` in every way that matters — the value lives in
/// `WorldState` under an ID inferred from the property name, so it commits,
/// rolls back, and saves on the same path. What it adds is the direction:
/// ``wrappedValue`` is get-only, so `crawlBeatDone = false` does not compile,
/// and ``trips()`` is the only way the value changes.
@propertyWrapper
public struct Latch: Sendable, AnyGlobal {
    let token = RefToken()

    /// Declares a latch. It starts down; that is what being a latch means,
    /// so there is no initial value to write.
    public init() {}

    var defaultStateValue: StateValue { .bool(false) }

    /// The restore-time gate. It is the ``Global`` question — can this box be
    /// read as a `Bool` — rather than the narrower one ``wrappedValue`` asks,
    /// and that is what lets the read below be a comparison: a save carrying
    /// anything else under this key is refused as a file, so the only values
    /// that ever reach a latch are `.bool` or nothing at all.
    var accepts: @Sendable (StateValue) -> Bool {
        { Bool(stateValue: $0) != nil }
    }

    /// Whether the latch has been tripped, and true from then on.
    ///
    /// A latch has two states and stores one of them, so this asks the same
    /// question ``trips()`` asks, in the same words. ``Global`` has to unbox
    /// because its `Value` is anything; this does not.
    public var wrappedValue: Bool {
        let frame = Ctx.current
        let id = frame.id(for: token, describing: "@Latch")
        return frame.with { $0.state.globals[id] == .bool(true) }
    }

    /// The latch itself, so `$flag` reaches ``trips()`` without naming a
    /// second type.
    public var projectedValue: Latch { self }

    /// Trips the latch, and reports whether this call is the one that did it.
    ///
    /// One expression rather than a guard and an assignment, which is the
    /// point: with no setter to separate them, the two halves of the
    /// hand-rolled `guard !flag` / `flag = true` pair cannot come apart.
    ///
    /// A call that changes nothing writes nothing. `WorldState.globals` is
    /// shared with the turn's UNDO snapshot until something writes to it, so
    /// storing `true` over `true` would copy the whole dictionary — and the
    /// bare `$flag.trips()` idiom is meant to be free to sit in a rule that
    /// runs every turn.
    ///
    /// - Returns: `true` if the latch was down before this call.
    @discardableResult
    public func trips() -> Bool {
        let frame = Ctx.current
        let id = frame.id(for: token, describing: "@Latch")
        return frame.with { scratch in
            guard scratch.state.globals[id] != .bool(true) else { return false }
            scratch.state.globals[id] = .bool(true)
            return true
        }
    }
}
