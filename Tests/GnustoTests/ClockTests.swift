import Foundation
import Gnusto
import GnustoClock
import GnustoTestSupport
import Testing

/// Library behavior of `GnustoClock`'s wall clock, exercised through tiny
/// synthetic games so each test isolates one rule about when time moves.
///
/// The clock is derived from the engine's `moves` counter rather than ticked
/// by a daemon of its own, and most of what follows is a consequence of that
/// choice: which turns cost time is the engine's answer, not the clock's, and
/// every reader inside a turn — including the timer tick that ends it — sees
/// the same minute.
struct ClockTests {
    // MARK: - Reading the clock

    /// The opening room description runs before any turn has been taken, so
    /// it must read the start time exactly. A clock seeded a tick early or
    /// late shows up here first.
    @Test func theOpeningReadsTheStartTime() async throws {
        let transcript = try await play(ClockLab(), [])
        #expect(transcript.contains("The clock says 20:00."))
    }

    @Test func theTimeVerbReportsTheClockAndCostsATurn() async throws {
        let transcript = try await play(ClockLab(), ["time", "time", "time"])
        expectInOrder(transcript, ["It is 8:00 pm.", "It is 8:01 pm.", "It is 8:02 pm."])
    }

    @Test func minutesPerTurnScalesTheStep() async throws {
        let transcript = try await play(SlowClockLab(), ["time", "time", "time"])
        expectInOrder(transcript, ["It is 8:00 pm.", "It is 8:15 pm.", "It is 8:30 pm."])
    }

    // MARK: - Which turns cost time

    @Test func theClockDoesNotAdvanceOnAParseError() async throws {
        // `frotz` is nonsense, not a stub verb — a stub costs a turn and moves
        // the clock, which is the very line this test draws.
        let transcript = try await play(ClockLab(), ["frotz", "time"])
        #expect(transcript.contains("It is 8:00 pm."))
    }

    @Test func theClockAdvancesOnAStubVerb() async throws {
        let transcript = try await play(ClockLab(), ["sing", "time"])
        #expect(transcript.contains("It is 8:01 pm."))
    }

    @Test func theClockDoesNotAdvanceOnMetaCommands() async throws {
        let transcript = try await play(ClockLab(), ["score", "version", "time"])
        #expect(transcript.contains("It is 8:00 pm."))
    }

    /// A refused turn still spends world time — you tried, and the minute
    /// went by regardless.
    @Test func theClockAdvancesOnARefusedTurn() async throws {
        let transcript = try await play(ClockLab(), ["take boulder", "time"])
        #expect(transcript.contains("It is 8:01 pm."))
    }

    /// `take all` is one command and costs one minute, not one per item.
    @Test func aMultiObjectTurnAdvancesTheClockOnce() async throws {
        let transcript = try await play(ClockLab(), ["take all", "time"])
        #expect(transcript.contains("It is 8:01 pm."))
    }

    // MARK: - The tick-order fences

    /// Everything inside one turn reads the same minute, including the timer
    /// tick that closes it. Were the clock advanced by a daemon, the tick
    /// would report a different time from the action that preceded it.
    @Test func theClockIsConstantForAWholeTurnIncludingTheTimerTick() async throws {
        let turn = turnOutput(of: "time", in: try await play(ProbeLab(), ["time"]))
        #expect(turn.contains("It is 8:00 pm."))
        #expect(turn.contains("aaa says 20:00"))
        #expect(turn.contains("zzz says 20:00"))
    }

    /// Daemons run in name order, so a clock ticked by a daemon of its own
    /// would be read differently by daemons sorting before and after it — the
    /// time would depend on other timers' *names*. These two probes bracket
    /// any plausible name and must always agree.
    @Test func daemonsSortingBeforeAndAfterAnyNameAgreeOnTheTime() async throws {
        let transcript = try await play(ProbeLab(), ["look", "look"])
        for minute in ["20:00", "20:01"] {
            #expect(transcript.contains("aaa says \(minute)"))
            #expect(transcript.contains("zzz says \(minute)"))
        }
    }

    // MARK: - Moving the clock by hand

    @Test func advanceBySkipsTimeWithinTheSameTurnAndAfterIt() async throws {
        let transcript = try await play(ClockLab(), ["skip", "time"])
        expectInOrder(transcript, ["Skipped to 20:45.", "It is 8:46 pm."])
    }

    @Test func setToMovesForwardToTheNextOccurrence() async throws {
        let transcript = try await play(ClockLab(), ["jump"])
        #expect(transcript.contains("Jumped to 22:00, day 1."))
    }

    /// Setting the clock to an earlier time lands on tomorrow's occurrence,
    /// so the day count never runs backwards and a fired alarm stays fired.
    @Test func setToAnEarlierTimeLandsTomorrow() async throws {
        let transcript = try await play(ClockLab(), ["rewind"])
        #expect(transcript.contains("Wound to 19:00, day 2."))
    }

    @Test func pauseFreezesTheClockWhileTurnsKeepPassing() async throws {
        let transcript = try await play(
            ClockLab(),
            ["freeze", "look", "look", "time", "thaw", "look", "time"])
        expectInOrder(
            transcript,
            [
                "Frozen at 20:00.",
                "It is 8:00 pm.",  // three turns later, still eight o'clock
                "Thawed at 20:00.",  // resumes where it stopped
                "It is 8:02 pm.",  // and runs on from there
            ])
    }

    @Test func theDayCountRollsOverAtMidnight() async throws {
        let transcript = try await play(
            OvernightLab(), ["today", "today", "today", "today", "today"])
        expectInOrder(
            transcript,
            [
                "Day 1, 20:00.",
                "Day 1, 21:00.",
                "Day 1, 22:00.",
                "Day 1, 23:00.",
                "Day 2, 00:00.",
            ])
    }

    // MARK: - Alarms

    @Test func anAlarmFiresExactlyOnce() async throws {
        let transcript = try await play(AlarmLab(), Array(repeating: "look", count: 8))
        #expect(occurrences(of: "The bell rings.", in: transcript) == 1)
    }

    /// A clock stepping a quarter hour at a time never lands on 20:07, so the
    /// alarm fires on the first tick past it rather than not at all.
    @Test func anAlarmFiresOnTheFirstTickPastItWhenTheStepOversteps() async throws {
        let transcript = try await play(SlowClockLab(), ["look", "look"])
        #expect(transcript.contains("The bell rings at 20:15."))
    }

    @Test func anAlarmFiresWhenTheHostAdvancesTimePastItByHand() async throws {
        let transcript = try await play(AlarmLab(), ["skip"])
        #expect(transcript.contains("The late bell rings at 20:45."))
    }

    /// An alarm set for a time earlier in the day than the game opens means
    /// *tomorrow* — which is what an overnight game wants.
    @Test func anAlarmEarlierInTheDayThanTheStartFiresTomorrow() async throws {
        let transcript = try await play(OvernightLab(), Array(repeating: "look", count: 7))
        #expect(transcript.contains("The small hours arrive at 02:00."))
        // Six hours of silence first, not an immediate misfire.
        let beforeFiring = transcript.components(separatedBy: "The small hours")[0]
        #expect(!beforeFiring.contains("small hours"))
    }

    @Test func aHushedAlarmNeverFires() async throws {
        let transcript = try await play(AlarmLab(), ["hush"] + Array(repeating: "look", count: 8))
        #expect(occurrences(of: "The bell rings.", in: transcript) == 0)
    }

    @Test func aReArmedAlarmFiresAgain() async throws {
        let transcript = try await play(
            AlarmLab(), Array(repeating: "look", count: 8) + ["rearm"])
        #expect(occurrences(of: "The bell rings.", in: transcript) == 2)
    }

    // MARK: - Persistence

    @Test func theClockSurvivesSaveAndRestore() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gnusto-clock-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let transcript = try await play(
            ClockLab(),
            [
                "skip",  // one turn taken, plus 45 minutes by hand
                "save", "slot",
                "look", "look", "look",  // three more minutes
                "restore", "slot",
                "time",  // back to the saved reading, not the later one
            ],
            saveDirectory: dir)
        expectInOrder(transcript, ["Restored.", "It is 8:46 pm."])
    }

    /// An alarm's armed-or-spent state is ordinary daemon state, so it rides
    /// the save file with everything else: restore to before it fired and it
    /// is waiting again.
    @Test func alarmArmingSurvivesSaveAndRestore() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gnusto-alarm-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let transcript = try await play(
            AlarmLab(),
            ["save", "slot"]
                + Array(repeating: "look", count: 8)  // the bell rings
                + ["restore", "slot"]
                + Array(repeating: "look", count: 8),  // and rings again
            saveDirectory: dir)
        #expect(occurrences(of: "The bell rings.", in: transcript) == 2)
    }

    @Test func undoRewindsTheClock() async throws {
        let straight = try await play(ClockLab(), ["look", "look", "time"])
        #expect(straight.contains("It is 8:02 pm."))

        let undone = try await play(ClockLab(), ["look", "look", "undo", "time"])
        #expect(undone.contains("It is 8:01 pm."))
    }

    // MARK: - Helpers

    private func occurrences(of needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }
}
