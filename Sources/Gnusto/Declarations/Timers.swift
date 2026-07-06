/// A named timed event, declared in a game or bundle `timers` block: a fuse
/// (fires once, N turns after it is started) or a daemon (runs at the end of
/// every turn while active). The body is registered at bootstrap and never
/// serialized; only the schedule — name → turns remaining, or the active
/// flag — lives in `WorldState`, so it saves and restores like any other
/// state and a restore re-binds it to the declared body by name.
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
    let (frame, event) = declaredTimer(name, in: "startFuse")
    guard case .fuse(let declared) = event.kind else {
        fatalError(
            "Gnusto: startFuse(\"\(name)\") names a daemon; use startDaemon(_:).")
    }
    let count = turns ?? declared
    frame.with { $0.state.activeFuses[name] = count }
}

/// Stops the named fuse; it will not fire. A no-op if it isn't running.
///
/// - Parameter name: the fuse to stop.
public func stopFuse(_ name: String) {
    let (frame, event) = declaredTimer(name, in: "stopFuse")
    guard case .fuse = event.kind else {
        fatalError("Gnusto: stopFuse(\"\(name)\") names a daemon; use stopDaemon(_:).")
    }
    frame.with { $0.state.activeFuses[name] = nil }
}

/// How many end-of-turn ticks remain before the named fuse fires — `nil`
/// when it isn't running.
///
/// - Parameter name: the fuse to query.
/// - Returns: end-of-turn ticks remaining, or `nil` when not running.
public func fuseRemaining(_ name: String) -> Int? {
    let (frame, event) = declaredTimer(name, in: "fuseRemaining")
    guard case .fuse = event.kind else {
        fatalError("Gnusto: fuseRemaining(\"\(name)\") names a daemon.")
    }
    return frame.with { $0.state.activeFuses[name] }
}

/// Starts the named daemon; it first runs at the end of the current turn.
///
/// - Parameter name: the daemon to start.
public func startDaemon(_ name: String) {
    let (frame, event) = declaredTimer(name, in: "startDaemon")
    guard case .daemon = event.kind else {
        fatalError("Gnusto: startDaemon(\"\(name)\") names a fuse; use startFuse(_:after:).")
    }
    frame.with { _ = $0.state.activeDaemons.insert(name) }
}

/// Stops the named daemon. A no-op if it isn't running.
///
/// - Parameter name: the daemon to stop.
public func stopDaemon(_ name: String) {
    let (frame, event) = declaredTimer(name, in: "stopDaemon")
    guard case .daemon = event.kind else {
        fatalError("Gnusto: stopDaemon(\"\(name)\") names a fuse; use stopFuse(_:).")
    }
    frame.with { _ = $0.state.activeDaemons.remove(name) }
}

/// Whether the named daemon is currently active.
///
/// - Parameter name: the daemon to query.
/// - Returns: `true` while the daemon is active.
public func isDaemonActive(_ name: String) -> Bool {
    let (frame, event) = declaredTimer(name, in: "isDaemonActive")
    guard case .daemon = event.kind else {
        fatalError("Gnusto: isDaemonActive(\"\(name)\") names a fuse; use fuseRemaining(_:).")
    }
    return frame.with { $0.state.activeDaemons.contains(name) }
}

/// Resolves a helper's timer name against the declared table, trapping on an
/// unknown name — a wiring error, matching the `proceed()` policy.
private func declaredTimer(_ name: String, in function: String) -> (TurnFrame, TimedEvent) {
    let frame = Ctx.current
    guard let event = frame.definition.timers[name] else {
        fatalError(
            "Gnusto: \(function)(\"\(name)\") — no timer with that name is declared "
                + "in any timers block.")
    }
    return (frame, event)
}
