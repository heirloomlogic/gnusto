import Gnusto

extension Intent {
    /// Read the time: `time`, or `what time is it`. Owned by the clock, so any
    /// game that adds one gets the verb for free.
    ///
    /// Note the pattern spells the question without its article — the parser
    /// strips noise words from what the player types but not from a rule's
    /// literal words, so `["what", "is", "the", "time"]` could never match.
    #verb("time", ["time"], ["what", "time", "is", "it"], ["check", "time"])
}

/// A wall clock over the turn counter: a game where it is twenty to six, and
/// ten to six four turns later.
///
/// The clock is **derived, not ticked**. `now` is a pure function of the
/// engine's `moves` counter, which means every rule, action, fuse and daemon
/// in a turn reads the same time — including the timer tick at the end of it.
/// A clock advanced by its own daemon would instead be read differently by
/// daemons sorting before and after it in the tick order, making the time
/// depend on other timers' *names*. Deriving also inherits the engine's notion
/// of world time for free: the clock already doesn't move on a parse error or
/// a meta command, and `take all` already costs one turn, not four.
///
/// ```swift
/// let clock = Clock(startingAt: TimeOfDay(17, 30), minutesPerTurn: 2)
///
/// var content: GameContents { clock }        // registers the verb and the state
/// var timers: [TimedEvent] {
///     clock.at(TimeOfDay(17, 46), named: "blast") {
///         say("The carriage house goes up with a sound like a door slamming in a cave.")
///     }
/// }
/// ```
///
/// Reading `now` needs a live turn, so it belongs in rule bodies, `describe`
/// blocks and actions — not in a `map` block, which is evaluated at bootstrap.
///
/// **Not provided: `wait until <time>`.** The parser has no numeric slot and
/// requires every token to be consumed, so `wait until 8 15` can never match a
/// pattern; and jumping the clock inside one turn would run a single timer
/// tick, silently skipping any alarm in between. Waiting a named number of
/// turns is the honest version, and the engine already does it.
public struct Clock: GameContent {
    /// Minutes the host has added or removed by hand, on top of the turn
    /// count. Written by ``advance(by:)`` and ``set(to:)``.
    @Global var offsetMinutes = 0

    /// The `moves` reading the clock is frozen at, or `-1` while running.
    @Global var pausedSinceMoves = -1

    /// Which stop each scheduled actor was last seen keeping, by daemon name.
    /// It belongs here rather than on ``Timetable`` so a timetable can stay
    /// stateless plain data — see that type for why that matters.
    @Global var stopIndices = StopIndices()

    /// The scheduled actors' places in their days. A wrapper struct so the
    /// `GlobalValue` conformance is owned here rather than declared on a
    /// standard-library type.
    struct StopIndices: Codable, Sendable, GlobalValue {
        var byDaemon: [String: Int] = [:]
    }

    /// The time the game opens at.
    public let start: TimeOfDay

    /// How much wall-clock time one turn costs.
    public let minutesPerTurn: Int

    /// How the time is spelled for the player.
    public let format: TimeFormat

    /// The `time` verb's reply, given the formatted time.
    private let timeIsLine: @Sendable (String) -> String

    /// Creates a clock.
    ///
    /// - Parameters:
    ///   - start: the time the game opens at (default nine in the morning).
    ///   - minutesPerTurn: wall-clock minutes one turn costs (default 1).
    ///   - format: how times are spelled for the player (default twelve-hour).
    ///   - timeIs: the `time` verb's reply, given the formatted time.
    public init(
        startingAt start: TimeOfDay = TimeOfDay(9, 0),
        minutesPerTurn: Int = 1,
        format: TimeFormat = .twelveHour,
        timeIs: @escaping @Sendable (String) -> String = { "It is \($0)." }
    ) {
        precondition(minutesPerTurn >= 1, "Gnusto: a clock needs at least a minute per turn.")
        self.start = start
        self.minutesPerTurn = minutesPerTurn
        self.format = format
        self.timeIsLine = timeIs
    }

    // MARK: - Reading the clock

    /// The turn count the clock is running against — frozen while paused.
    private var effectiveMoves: Int {
        let paused = pausedSinceMoves
        return paused >= 0 ? paused : player.moves
    }

    /// Minutes of game time since the opening, counting the host's own
    /// adjustments. Monotone unless the host rewinds.
    public var elapsedMinutes: Int {
        effectiveMoves * minutesPerTurn + offsetMinutes
    }

    /// What time it is now.
    public var now: TimeOfDay {
        start.advanced(by: elapsedMinutes)
    }

    /// Which day it is, counting the opening day as 1. Crosses to 2 the first
    /// time the clock passes midnight.
    public var day: Int {
        // Floor division, not truncating: Swift's `%` takes the dividend's
        // sign, so a rewound clock would otherwise round towards day 1.
        let total = start.minutesSinceMidnight + elapsedMinutes
        let borrow = total % TimeOfDay.minutesPerDay < 0 ? 1 : 0
        return 1 + total / TimeOfDay.minutesPerDay - borrow
    }

    /// Whether the clock is running — `false` between ``pause()`` and
    /// ``resume()``.
    public var isRunning: Bool { pausedSinceMoves < 0 }

    // MARK: - Moving the clock

    /// Moves the clock by some minutes without the player spending turns —
    /// for an interlude the prose skips over. Negative values rewind, but an
    /// alarm that has already fired stays fired.
    ///
    /// - Parameter minutes: how far to move; may be negative.
    public func advance(by minutes: Int) {
        offsetMinutes += minutes
    }

    /// Moves the clock **forward** to the next occurrence of a time, at or
    /// after now. Setting it to the current time does nothing; setting it to
    /// an earlier one lands tomorrow, so the day count never runs backwards.
    ///
    /// - Parameter time: the time to move to.
    public func set(to time: TimeOfDay) {
        advance(by: now.minutesUntil(time))
    }

    /// Stops the clock: turns still pass, but the time stops moving. A no-op
    /// if it is already paused.
    public func pause() {
        guard isRunning else { return }
        pausedSinceMoves = player.moves
    }

    /// Restarts a paused clock from the time it stopped at. A no-op if it is
    /// already running.
    public func resume() {
        let paused = pausedSinceMoves
        guard paused >= 0 else { return }
        offsetMinutes -= (player.moves - paused) * minutesPerTurn
        pausedSinceMoves = -1
    }

    // MARK: - Alarms

    /// Something that happens at a time rather than after a count of turns:
    /// the blast, the last train, the coroner at the door.
    ///
    /// The alarm fires **once**, at the end of the first turn on or after its
    /// time — so a clock running several minutes per turn that steps over the
    /// target still fires, and so does one the host jumps forward by hand. A
    /// time earlier in the day than the clock's start means *tomorrow*, which
    /// is what an overnight game wants.
    ///
    /// Firing once is enforced by the alarm stopping its own daemon, so the
    /// arming state is ordinary daemon state: it saves and restores for free,
    /// `stopDaemon(_:)` cancels an alarm that hasn't fired, and
    /// `startDaemon(_:)` re-arms one that has.
    ///
    /// Timer names are global across a game, so prefix yours — the clock's own
    /// convention is `"clock.<something>"`.
    ///
    /// - Parameters:
    ///   - time: when it goes off.
    ///   - name: the daemon's name, unique across the whole game.
    ///   - body: what happens.
    /// - Returns: the timed event, for the game's `timers` block.
    public func at(
        _ time: TimeOfDay,
        named name: String,
        perform body: @escaping @Sendable () throws -> Void
    ) -> TimedEvent {
        // Fixed at declaration, so it is computed once rather than every
        // tick — and it puts the wrap where an author can see it: a time
        // earlier in the day than the start means tomorrow, and no alarm can
        // be set more than 24 hours out.
        let dueAfter = start.minutesUntil(time)
        return daemon(name, autostart: true) {
            guard elapsedMinutes >= dueAfter else { return }
            stopDaemon(name)
            try body()
        }
    }

    // MARK: - GameContent

    /// The verb the clock contributes: `time`, and the ways players ask for it.
    public var verbs: [SyntaxRule] { [.time] }

    /// The clock's default action: reading the time back to the player.
    ///
    /// Checking the time costs a turn. That is deliberate rather than an
    /// oversight — the engine's meta commands are a closed set, and in a game
    /// running against a deadline, glancing at your watch should cost you the
    /// same minute it costs anyone.
    public var actions: [IntentAction] {
        action(.time) {
            say(timeIsLine(now.formatted(format)))
        }
    }

    /// The hour, for the play-test status footer — `time=5:46 pm`.
    ///
    /// The engine's own status line is three fields (room, score, moves) and
    /// the engine cannot reach this type: `GnustoClock` depends on `Gnusto`,
    /// not the other way round. So the clock hands its field up rather than the
    /// engine reaching down for it.
    ///
    /// Worth the wiring because a timed game's every defect is a defect about
    /// *when*: a line that is true at half past five and false at six reads
    /// identically in a transcript that never says which it was. Read-only, as
    /// the contract requires — ``now`` derives the time from the move counter
    /// and writes nothing.
    ///
    /// It derives it from the counter **as the turn closed**, because that is
    /// where the engine samples a contributed field: the same reading the
    /// turn's `.time` action, its `describe` blocks, and the alarms and
    /// scheduled moves in its timer phase all took. Until #280 the field was
    /// read one increment later, so every cost turn's footer stood one
    /// ``minutesPerTurn`` ahead of every hour the game itself had just
    /// printed — and because a free turn advances no counter, the offset was
    /// not constant and so could not be corrected by habit. Nothing here
    /// changed to fix it; the sampling point did.
    public var statusFields: [(String, String)] {
        [("time", now.formatted(format))]
    }
}
