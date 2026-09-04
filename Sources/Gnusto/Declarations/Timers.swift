/// A named timed event, declared in a game or bundle `timers` block: a fuse
/// (fires once, N turns after it is started) or a daemon (runs at the end of
/// every turn while active). The body is registered at bootstrap and never
/// serialized; only the schedule — name → turns remaining, or the active
/// flag — lives in `WorldState`, so it saves and restores like any other
/// state and a restore re-binds it to the declared body by name.
///
/// Timer names are bare strings wherever they are unambiguous. Two owners
/// (the game and a bundle, or two bundles) may both declare one name: the
/// bootstrap moves each bundle-owned declaration into its namespace
/// (`"Clock.roam"`) while the game's own stays bare, and a body running for
/// its owner resolves the bare literal it declared against that owner first
/// (see ``startFuse(_:after:)`` and friends). A host game addresses a bundle's
/// collided timer by the qualified name.
///
/// Timers tick once per typed command, at the very end of the turn (after
/// the world's `after`/each-turn rules): fuses first, then daemons, each
/// group in name order. They tick on refused turns (world time passes) but
/// not on parse errors, meta commands, or once the game has ended. A timer
/// started during a turn ticks at the end of that same turn — so a
/// `fuse(after: 1)` started by a rule fires as that very turn ends.
public struct TimedEvent: Sendable {
    enum Kind: Sendable {
        case fuse(turns: Int)
        case daemon
    }

    let name: String
    let kind: Kind
    let autostart: Bool
    let body: @Sendable () throws -> Void
}

extension TimedEvent {
    /// A copy of this timer whose body runs with `namespace` bound as the
    /// owning bundle (``Ctx/owned(_:_:)``), so timer helpers inside resolve
    /// bare timer names against the owner's declarations. The game's own
    /// timers (`nil`) come back unchanged.
    func owned(by namespace: String?) -> TimedEvent {
        guard let namespace else { return self }
        let body = self.body
        return TimedEvent(name: name, kind: kind, autostart: autostart) {
            try Ctx.owned(namespace, body)
        }
    }
}

/// Declares a fuse: `body` runs once, `turns` turns after the fuse is
/// started — by `startFuse(_:after:)` in a rule, or from turn one with
/// `autostart`. Starting a running fuse resets its count.
///
/// - Parameters:
///   - name: the fuse's name.
///   - turns: turns until it fires once started.
///   - autostart: whether it starts from turn one.
///   - body: what runs when it fires.
/// - Returns: the declared timed event.
public func fuse(
    _ name: String,
    after turns: Int,
    autostart: Bool = false,
    perform body: @escaping @Sendable () throws -> Void
) -> TimedEvent {
    TimedEvent(name: name, kind: .fuse(turns: turns), autostart: autostart, body: body)
}

/// Declares a daemon: `body` runs at the end of every turn while the daemon
/// is active — from `startDaemon(_:)` in a rule, or from turn one with
/// `autostart`.
///
/// - Parameters:
///   - name: the daemon's name.
///   - autostart: whether it runs from turn one.
///   - body: what runs each active turn.
/// - Returns: the declared timed event.
public func daemon(
    _ name: String,
    autostart: Bool = false,
    perform body: @escaping @Sendable () throws -> Void
) -> TimedEvent {
    TimedEvent(name: name, kind: .daemon, autostart: autostart, body: body)
}

// MARK: - Rule-body helpers

/// Starts (or restarts, resetting the count of) the named fuse. `turns`
/// overrides the declared count for this run. Naming an undeclared timer, or
/// a daemon, is a programmer error and traps.
///
/// - Parameters:
///   - name: the fuse to start.
///   - turns: overrides the declared count for this run.
public func startFuse(_ name: String, after turns: Int? = nil) {
    let (frame, key, declared) = declaredFuse(name, in: "startFuse", else: "startDaemon(_:)")
    let count = turns ?? declared
    frame.with { $0.state.activeFuses[key] = count }
}

/// Stops the named fuse; it will not fire. A no-op if it isn't running.
///
/// - Parameter name: the fuse to stop.
public func stopFuse(_ name: String) {
    let (frame, key, _) = declaredFuse(name, in: "stopFuse", else: "stopDaemon(_:)")
    frame.with { $0.state.activeFuses[key] = nil }
}

/// How many end-of-turn ticks remain before the named fuse fires — `nil`
/// when it isn't running.
///
/// - Parameter name: the fuse to query.
/// - Returns: end-of-turn ticks remaining, or `nil` when not running.
public func fuseRemaining(_ name: String) -> Int? {
    let (frame, key, _) = declaredFuse(name, in: "fuseRemaining", else: "isDaemonActive(_:)")
    return frame.with { $0.state.activeFuses[key] }
}

/// Starts the named daemon; it first runs at the end of the current turn.
///
/// - Parameter name: the daemon to start.
public func startDaemon(_ name: String) {
    let (frame, key) = declaredDaemon(name, in: "startDaemon", else: "startFuse(_:after:)")
    frame.with { _ = $0.state.activeDaemons.insert(key) }
}

/// Stops the named daemon. A no-op if it isn't running.
///
/// - Parameter name: the daemon to stop.
public func stopDaemon(_ name: String) {
    let (frame, key) = declaredDaemon(name, in: "stopDaemon", else: "stopFuse(_:)")
    frame.with { _ = $0.state.activeDaemons.remove(key) }
}

/// Whether the named daemon is currently active.
///
/// - Parameter name: the daemon to query.
/// - Returns: `true` while the daemon is active.
public func isDaemonActive(_ name: String) -> Bool {
    let (frame, key) = declaredDaemon(name, in: "isDaemonActive", else: "fuseRemaining(_:)")
    return frame.with { $0.state.activeDaemons.contains(key) }
}

/// Resolves a fuse helper's name against the declared table, trapping if it
/// names a daemon or nothing at all, and handing back the declared count.
///
/// - Parameters:
///   - name: the timer name the rule body passed.
///   - function: the helper doing the asking, quoted back in the trap.
///   - advice: the helper the author meant, named in the trap. Required, not
///     optional, because the half of the message that says what to do instead
///     is the half that does the work — one of these six once said only
///     "names a daemon" and left the author to guess. See `TimerTests`.
/// - Returns: the live frame, the resolved schedule key, and the fuse's
///   declared count.
private func declaredFuse(
    _ name: String, in function: String, else advice: String
) -> (TurnFrame, String, Int) {
    let (frame, key, event) = declaredTimer(name, in: function)
    guard case .fuse(let declared) = event.kind else {
        fatalError("Gnusto: \(function)(\"\(name)\") names a daemon; use \(advice).")
    }
    return (frame, key, declared)
}

/// The daemon half of ``declaredFuse(_:in:else:)``. A daemon has no count, so
/// this hands back the frame alone.
///
/// - Parameters:
///   - name: the timer name the rule body passed.
///   - function: the helper doing the asking, quoted back in the trap.
///   - advice: the helper the author meant, named in the trap.
/// - Returns: the live frame and the resolved schedule key.
private func declaredDaemon(
    _ name: String, in function: String, else advice: String
) -> (TurnFrame, String) {
    let (frame, key, event) = declaredTimer(name, in: function)
    guard case .daemon = event.kind else {
        fatalError("Gnusto: \(function)(\"\(name)\") names a fuse; use \(advice).")
    }
    return (frame, key)
}

/// Resolves a helper's timer name against the declared table, trapping on an
/// unknown name — a wiring error, matching the `proceed()` policy.
///
/// A bare name resolves in two steps: the running body's own bundle first
/// (`Ctx.namespace`) — which is how a bundle's rules start its timers by the
/// bare literal they declared even when another bundle or the host uses the
/// same name — then the declared table's exact key (the game's own names,
/// any unambiguous name, and a qualified `"Namespace.name"` spelled out
/// deliberately).
private func declaredTimer(_ name: String, in function: String) -> (TurnFrame, String, TimedEvent) {
    let frame = Ctx.current
    if let namespace = Ctx.namespace,
        let event = frame.definition.timers["\(namespace).\(name)"]
    {
        return (frame, "\(namespace).\(name)", event)
    }
    if let event = frame.definition.timers[name] {
        return (frame, name, event)
    }
    fatalError(
        "Gnusto: \(function)(\"\(name)\") — no timer with that name is declared "
            + "in any timers block.")
}
