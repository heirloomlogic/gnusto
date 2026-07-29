import Foundation
import Gnusto
import GnustoClock
import Testing

/// Arithmetic and rendering for ``TimeOfDay`` — a pure value type, so these
/// need no game world. They pin the two things a clock-driven game leans on
/// hardest: that minute arithmetic wraps at midnight in both directions, and
/// that a window spanning midnight is still a window.
struct TimeOfDayTests {
    // MARK: - Construction

    @Test func componentInitNormalizesOutOfRangeValues() {
        #expect(TimeOfDay(25, 70) == TimeOfDay(2, 10))
        #expect(TimeOfDay(24, 0) == TimeOfDay(0, 0))
        #expect(TimeOfDay(-1, 0) == TimeOfDay(23, 0))
        #expect(TimeOfDay(0, -1) == TimeOfDay(23, 59))
    }

    @Test func minutesInitWrapsInBothDirections() {
        #expect(TimeOfDay(minutesSinceMidnight: 1_440) == .midnight)
        #expect(TimeOfDay(minutesSinceMidnight: 1_441) == TimeOfDay(0, 1))
        #expect(TimeOfDay(minutesSinceMidnight: -1) == TimeOfDay(23, 59))
        #expect(TimeOfDay(minutesSinceMidnight: -1_441) == TimeOfDay(23, 59))
    }

    @Test func componentsReadBack() {
        let time = TimeOfDay(20, 15)
        #expect(time.hour == 20)
        #expect(time.minute == 15)
        #expect(time.minutesSinceMidnight == 1_215)
    }

    @Test func namedConstantsAreWhereTheySay() {
        #expect(TimeOfDay.midnight == TimeOfDay(0, 0))
        #expect(TimeOfDay.noon == TimeOfDay(12, 0))
    }

    // MARK: - Ordering

    /// `Comparable` is *within-day* ordering — one o'clock in the morning
    /// sorts before eleven at night, which is the wrong answer for "later
    /// that evening" and the right one for sorting a timetable. Wrap-aware
    /// questions go through `isBetween(_:and:)` and `minutesUntil(_:)`.
    @Test func comparableOrdersWithinTheDay() {
        #expect(TimeOfDay(1, 0) < TimeOfDay(23, 0))
        #expect(TimeOfDay(17, 30) < TimeOfDay(17, 31))
        #expect(!(TimeOfDay(12, 0) < TimeOfDay(12, 0)))
    }

    // MARK: - Arithmetic

    @Test func advancedWrapsForwardAcrossMidnight() {
        #expect(TimeOfDay(23, 50).advanced(by: 20) == TimeOfDay(0, 10))
        #expect(TimeOfDay(8, 0).advanced(by: 1_440) == TimeOfDay(8, 0))
        #expect(TimeOfDay(8, 0).advanced(by: 1_441) == TimeOfDay(8, 1))
    }

    @Test func advancedWrapsBackwardAcrossMidnight() {
        #expect(TimeOfDay(0, 10).advanced(by: -20) == TimeOfDay(23, 50))
        #expect(TimeOfDay(8, 0).advanced(by: -1_440) == TimeOfDay(8, 0))
    }

    @Test func minutesUntilIsTheForwardDistance() {
        #expect(TimeOfDay(23, 50).minutesUntil(TimeOfDay(0, 10)) == 20)
        #expect(TimeOfDay(17, 30).minutesUntil(TimeOfDay(18, 0)) == 30)
        // A time is zero minutes from itself, not a full day.
        #expect(TimeOfDay(9, 0).minutesUntil(TimeOfDay(9, 0)) == 0)
        // Backwards within the day means "tomorrow".
        #expect(TimeOfDay(18, 0).minutesUntil(TimeOfDay(17, 30)) == 1_410)
    }

    // MARK: - Windows

    @Test func isBetweenIsHalfOpenWithinTheDay() {
        let window = { (t: TimeOfDay) in t.isBetween(TimeOfDay(17, 0), and: TimeOfDay(19, 0)) }
        #expect(window(TimeOfDay(17, 0)))  // the start is inside
        #expect(window(TimeOfDay(18, 0)))
        #expect(!window(TimeOfDay(19, 0)))  // the end is not
        #expect(!window(TimeOfDay(16, 59)))
    }

    @Test func isBetweenHandlesAWindowSpanningMidnight() {
        let curfew = { (t: TimeOfDay) in t.isBetween(TimeOfDay(22, 0), and: TimeOfDay(6, 0)) }
        #expect(curfew(TimeOfDay(23, 0)))
        #expect(curfew(TimeOfDay(2, 0)))
        #expect(curfew(TimeOfDay(22, 0)))
        #expect(!curfew(TimeOfDay(6, 0)))
        #expect(!curfew(TimeOfDay(12, 0)))
    }

    /// An empty window is empty. The alternative reading — that
    /// `isBetween(x, and: x)` means "all day" — is a footgun waiting for
    /// somebody's off-by-one.
    @Test func anEmptyWindowContainsNothing() {
        #expect(!TimeOfDay(9, 0).isBetween(TimeOfDay(9, 0), and: TimeOfDay(9, 0)))
        #expect(!TimeOfDay(3, 0).isBetween(TimeOfDay(9, 0), and: TimeOfDay(9, 0)))
    }

    // MARK: - Rendering

    @Test func twelveHourFormattingCoversMidnightAndNoon() {
        #expect(TimeOfDay(0, 0).formatted(.twelveHour) == "12:00 am")
        #expect(TimeOfDay(0, 5).formatted(.twelveHour) == "12:05 am")
        #expect(TimeOfDay(11, 59).formatted(.twelveHour) == "11:59 am")
        #expect(TimeOfDay(12, 0).formatted(.twelveHour) == "12:00 pm")
        #expect(TimeOfDay(12, 30).formatted(.twelveHour) == "12:30 pm")
        #expect(TimeOfDay(13, 5).formatted(.twelveHour) == "1:05 pm")
        #expect(TimeOfDay(17, 46).formatted(.twelveHour) == "5:46 pm")
    }

    @Test func twentyFourHourFormattingZeroPadsBothFields() {
        #expect(TimeOfDay(0, 5).formatted(.twentyFourHour) == "00:05")
        #expect(TimeOfDay(9, 0).formatted(.twentyFourHour) == "09:00")
        #expect(TimeOfDay(20, 15).formatted(.twentyFourHour) == "20:15")
    }

    @Test func descriptionIsTheTwentyFourHourForm() {
        #expect("\(TimeOfDay(20, 15))" == "20:15")
    }

    // MARK: - Conformances

    @Test func hashableWorksAsADictionaryKey() {
        let bell: [TimeOfDay: String] = [
            TimeOfDay(12, 0): "noon",
            TimeOfDay(18, 0): "vespers",
        ]
        #expect(bell[TimeOfDay(12, 0)] == "noon")
        #expect(bell[TimeOfDay(minutesSinceMidnight: 1_080)] == "vespers")
    }

    @Test func codableRoundTripsThroughJson() throws {
        let time = TimeOfDay(20, 15)
        let bytes = try JSONEncoder().encode(time)
        #expect(try JSONDecoder().decode(TimeOfDay.self, from: bytes) == time)
    }

    @Test func decodingNormalizesAnOutOfRangeValue() throws {
        let bytes = Data("1441".utf8)
        #expect(try JSONDecoder().decode(TimeOfDay.self, from: bytes) == TimeOfDay(0, 1))
    }

    /// The `GlobalValue` conformance is hand-written to box as `.int` rather
    /// than inheriting the JSON-blob default. That matters: only the scalar
    /// cases are type-checked when a save is restored, so a boxed struct that
    /// stops decoding reverts to its default *silently*. Deleting the
    /// conformance would still compile, and would still appear to work until
    /// somebody loaded an old save — so this test is the guard.
    @Test func globalValueBoxesAsAnIntNotAJsonBlob() {
        #expect(TimeOfDay(20, 15).stateValue == .int(1_215))
        #expect(TimeOfDay(stateValue: .int(1_215)) == TimeOfDay(20, 15))
        #expect(TimeOfDay(stateValue: .string("20:15")) == nil)
    }
}
