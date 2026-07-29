import Gnusto

/// A time on a 24-hour wall clock, with no date attached: 8:15 in the evening
/// is `TimeOfDay(20, 15)`, and it is the same value tomorrow.
///
/// Arithmetic wraps at midnight in both directions, so
/// `TimeOfDay(23, 50).advanced(by: 20)` is ten past twelve. Ordering, though,
/// is *within the day* — one in the morning sorts before eleven at night,
/// which is what a timetable wants and not what "later that evening" means.
/// For questions that span midnight use ``isBetween(_:and:)`` and
/// ``minutesUntil(_:)``, which are wrap-aware.
///
/// ```swift
/// let curfew = TimeOfDay(22, 0)
/// if clock.now.isBetween(curfew, and: TimeOfDay(6, 0)) {
///     say("The gates are shut for the night.")
/// }
/// ```
public struct TimeOfDay: Sendable, Hashable, Comparable, Codable, CustomStringConvertible {
    /// Minutes elapsed since midnight, always in `0..<1440`.
    public let minutesSinceMidnight: Int

    /// The hour on a 24-hour clock, `0...23`.
    public var hour: Int { minutesSinceMidnight / 60 }

    /// The minute within the hour, `0...59`.
    public var minute: Int { minutesSinceMidnight % 60 }

    /// Minutes in a day — the modulus every wrap in this type and the clock
    /// built on it comes back to.
    public static let minutesPerDay = 24 * 60

    /// Midnight — the start of the day, and the point arithmetic wraps at.
    public static let midnight = TimeOfDay(0, 0)

    /// Noon.
    public static let noon = TimeOfDay(12, 0)

    /// Creates a time from an hour and a minute, wrapping anything out of
    /// range: `TimeOfDay(25, 70)` is ten past two in the morning. Wrapping
    /// rather than trapping is what lets a caller write `start.hour - 1`
    /// without guarding midnight by hand.
    ///
    /// - Parameters:
    ///   - hour: the hour, normally `0...23`.
    ///   - minute: the minute, normally `0...59`.
    public init(_ hour: Int, _ minute: Int) {
        self.init(minutesSinceMidnight: hour * 60 + minute)
    }

    /// Creates a time from minutes since midnight, wrapping into `0..<1440`.
    /// Negative values count backwards from midnight.
    ///
    /// - Parameter minutesSinceMidnight: the offset from midnight, any value.
    public init(minutesSinceMidnight: Int) {
        let day = TimeOfDay.minutesPerDay
        self.minutesSinceMidnight = ((minutesSinceMidnight % day) + day) % day
    }

    /// This time moved forward (or, for a negative amount, back) by some
    /// minutes, wrapping at midnight.
    ///
    /// - Parameter minutes: how far to move; may be negative.
    /// - Returns: the resulting time of day.
    public func advanced(by minutes: Int) -> TimeOfDay {
        TimeOfDay(minutesSinceMidnight: minutesSinceMidnight + minutes)
    }

    /// How many minutes forward from this time to `other`, in `0..<1440`.
    /// Going "backwards" within the day means tomorrow: from six in the
    /// evening to half past five is 23 hours and 30 minutes, not `-30`.
    ///
    /// - Parameter other: the time to measure to.
    /// - Returns: the forward distance in minutes.
    public func minutesUntil(_ other: TimeOfDay) -> Int {
        let delta = other.minutesSinceMidnight - minutesSinceMidnight
        return delta >= 0 ? delta : delta + TimeOfDay.minutesPerDay
    }

    /// Whether this time falls in the half-open window `[start, end)`,
    /// counting a window that runs past midnight — `isBetween(22:00, and:
    /// 06:00)` is true at two in the morning.
    ///
    /// The window includes its start and excludes its end, so adjacent
    /// windows tile without overlapping. A window whose start and end are the
    /// same is **empty**, not all day.
    ///
    /// - Parameters:
    ///   - start: the first time inside the window.
    ///   - end: the first time after it.
    /// - Returns: whether this time is inside.
    public func isBetween(_ start: TimeOfDay, and end: TimeOfDay) -> Bool {
        if start == end { return false }
        if start < end { return self >= start && self < end }
        return self >= start || self < end
    }

    /// This time rendered for the player.
    ///
    /// - Parameter style: twelve-hour (`"5:46 pm"`) or twenty-four-hour
    ///   (`"17:46"`).
    /// - Returns: the formatted time.
    public func formatted(_ style: TimeFormat) -> String {
        let paddedMinute = minute < 10 ? "0\(minute)" : "\(minute)"
        switch style {
        case .twelveHour:
            let clockHour = hour % 12 == 0 ? 12 : hour % 12
            return "\(clockHour):\(paddedMinute) \(hour < 12 ? "am" : "pm")"
        case .twentyFourHour:
            let paddedHour = hour < 10 ? "0\(hour)" : "\(hour)"
            return "\(paddedHour):\(paddedMinute)"
        }
    }

    /// The twenty-four-hour form, for diagnostics and test failure messages.
    public var description: String { formatted(.twentyFourHour) }

    /// Orders times within the day. See the note on the type: this is not a
    /// wrap-aware "comes after" — that is ``minutesUntil(_:)``.
    ///
    /// - Parameters:
    ///   - lhs: the first time.
    ///   - rhs: the second time.
    /// - Returns: whether `lhs` falls earlier in the day than `rhs`.
    public static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }

    /// Decodes a time stored as a plain minute count, normalizing it — so a
    /// hand-edited save can't produce a 25 o'clock.
    ///
    /// - Parameter decoder: the decoder to read from.
    /// - Throws: whatever the underlying single-value container throws.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(minutesSinceMidnight: try container.decode(Int.self))
    }

    /// Encodes as a plain minute count.
    ///
    /// - Parameter encoder: the encoder to write to.
    /// - Throws: whatever the underlying single-value container throws.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(minutesSinceMidnight)
    }
}

extension TimeOfDay: GlobalValue {
    /// Boxed as an `Int` rather than through the default JSON blob. Only the
    /// scalar `StateValue` cases are type-checked when a save is restored, so
    /// a blob-boxed value that stops decoding reverts to its default in
    /// silence; an `.int` round-trips honestly and can't drift.
    public var stateValue: StateValue { .int(minutesSinceMidnight) }

    /// Unboxes a time from global storage, or `nil` if the stored case isn't
    /// an `.int`.
    ///
    /// - Parameter stateValue: the boxed value from global storage.
    public init?(stateValue: StateValue) {
        guard case .int(let minutes) = stateValue else { return nil }
        self.init(minutesSinceMidnight: minutes)
    }
}

/// How a ``TimeOfDay`` is spelled for the player.
public enum TimeFormat: Sendable {
    /// `"5:46 pm"` — no leading zero on the hour, `am`/`pm` suffix.
    case twelveHour
    /// `"17:46"` — both fields zero-padded.
    case twentyFourHour
}
