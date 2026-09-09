import Foundation
import Gnusto
import GnustoClock
import GnustoTestSupport
import Testing

/// Deterministic NPC timetables: an actor who *is* somewhere at a given
/// minute, as against `GnustoActors`' wanderer who merely might be.
///
/// `ManorLab` runs a minute to the turn from eight o'clock, so turn *n* reads
/// `20:00 + (n-1)` and the butler's stops — hall, dining at :03, study at :06,
/// cellar at :09, study at :12 and again at :15 — land on turns 1, 4, 7, 10,
/// 13 and 16. The last two stops share a room deliberately: that is the case
/// where nothing visibly happens and the stop's action must still fire.
struct TimetableTests {
    // MARK: - The lookup, which needs no game at all

    /// The whole point of the type: where he was is a function of the
    /// timetable, not of prose somebody remembered to keep in sync. Pure, so
    /// it answers without a turn in progress.
    @Test func locationAtResolvesTheLatestStopAtOrBeforeTheTime() {
        let manor = ManorLab()
        #expect(manor.butlerDay.location(at: TimeOfDay(20, 0)) == manor.hall)  // exactly at
        #expect(manor.butlerDay.location(at: TimeOfDay(20, 4)) == manor.dining)  // between
        #expect(manor.butlerDay.location(at: TimeOfDay(20, 20)) == manor.study)  // after the last
    }

    /// A time before the first stop belongs to the previous day's last stop,
    /// so an overnight timetable reads the same on both sides of midnight.
    @Test func locationAtWrapsAtMidnightToTheLastStopOfTheDay() {
        let manor = ManorLab()
        #expect(manor.butlerDay.location(at: TimeOfDay(19, 0)) == manor.study)
        #expect(manor.butlerDay.location(at: TimeOfDay(3, 0)) == manor.study)
    }

    @Test func theClockForwardsTheLookupForTheGameToUse() async throws {
        let transcript = try await play(ManorLab(), ["alibi"])
        #expect(transcript.contains("At 8:04 he was in the Dining Room."))
    }

    // MARK: - What the player sees

    @Test func theDepartureLineIsPrintedInTheRoomBeingLeft() async throws {
        let transcript = try await play(ManorLab(), Array(repeating: "z", count: 5))
        #expect(transcript.contains("The butler leaves for the dining room."))
        #expect(!transcript.contains("The butler comes in with a tray."))
    }

    @Test func theArrivalLineIsPrintedInTheRoomBeingEntered() async throws {
        let transcript = try await play(ManorLab(), ["north"] + Array(repeating: "z", count: 4))
        #expect(transcript.contains("The butler comes in with a tray."))
        #expect(!transcript.contains("The butler leaves for the dining room."))
    }

    @Test func movementIsSilentWhenThePlayerIsInNeitherRoom() async throws {
        let transcript = try await play(ManorLab(), ["up"] + Array(repeating: "z", count: 3))
        #expect(!transcript.contains("The butler leaves for the dining room."))
        #expect(!transcript.contains("The butler comes in with a tray."))
    }

    /// Standing in the room he walks into is no good if you can't see it.
    @Test func movementIsSilentInAnUnlitRoom() async throws {
        let transcript = try await play(ManorLab(), ["down"] + Array(repeating: "z", count: 10))
        #expect(transcript.contains("pitch black"))
        #expect(!transcript.contains("The butler comes down the cellar steps."))
    }

    /// He is already in the study at :15, so there is nothing to narrate — a
    /// stop that doesn't move him says nothing.
    @Test func anActorAlreadyInPositionMovesInSilence() async throws {
        let transcript = try await play(ManorLab(), ["up"] + Array(repeating: "z", count: 17))
        #expect(occurrences(of: "The butler returns to the study.", in: transcript) == 1)
    }

    // MARK: - Stop actions

    @Test func aStopActionRunsOnceWhenTheStopComesRound() async throws {
        let transcript = try await play(ManorLab(), Array(repeating: "z", count: 20))
        #expect(occurrences(of: "The butler winds the clock.", in: transcript) == 1)
    }

    /// The stop in force when the game opens has not come round: a game that
    /// opens at eight in the evening does not ring a nine-in-the-morning bell
    /// on turn one. The first tick only takes the actor's place in the day;
    /// the next stop still fires on its minute.
    @Test func theOpeningStopDoesNotRunItsActionOnTurnOne() async throws {
        let transcript = try await play(LateOpeningLab(), ["z", "z", "z"])
        #expect(!transcript.contains("The bell rings for nine."))
        #expect(occurrences(of: "The bell rings for two past.", in: transcript) == 1)
        expectInOrder(transcript, ["The butler goes up.", "The bell rings for two past."])
    }

    /// A clock that samples every fifteen minutes steps over stops five
    /// minutes apart. Each one's action runs on the tick that passes it, in
    /// order, and only the stop actually landed on narrates a move.
    @Test func everyStopACoarseTickStepsOverRunsItsAction() async throws {
        let transcript = try await play(CoarseClockLab(), ["z", "z"])
        // Turn 1 is 9:00, the seed; turn 2 is 9:15, three stops on.
        expectInOrder(
            turnOutput(ofLast: "z", in: transcript),
            ["The butler goes down.", "Five past.", "Ten past.", "Quarter past."])
        #expect(occurrences(of: "Five past.", in: transcript) == 1)
    }

    /// The place-keeper travels in the save file: restoring to after a stop
    /// came round does not run its action again.
    @Test func aRestoredStopDoesNotRunItsActionAgain() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gnusto-timetable-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let transcript = try await play(
            ManorLab(),
            Array(repeating: "z", count: 16) + ["save", "slot", "z", "z", "restore", "slot", "z", "z"],
            saveDirectory: dir)
        #expect(occurrences(of: "The butler winds the clock.", in: transcript) == 1)
    }

    // MARK: - Coming off the rounds, and going back on

    /// Offstage he idles without losing his place, so putting him back down
    /// resumes his day rather than restarting it.
    @Test func anOffstageActorIdlesAndResumesWhenPutBack() async throws {
        let transcript = try await play(
            ManorLab(),
            ["abduct"] + Array(repeating: "z", count: 8) + ["recall", "z"])
        // Vanished before his first move, so none of the early prose ran.
        #expect(!transcript.contains("The butler leaves for the dining room."))
        // Put back at 8:09, he goes straight to where the day says he should be.
        expectInOrder(transcript, ["Back.", "The butler goes down to the cellar."])
    }

    /// A timetable means he goes where he is supposed to be, so moving him
    /// off his route is undone on the next tick. This is the documented
    /// divergence from `roams`, which idles outside its room set.
    @Test func anActorMovedOffScheduleWalksBackOnTheNextTick() async throws {
        let scheduled = try await play(ManorLab(), ["fetch", "look"])
        #expect(turnOutput(of: "look", in: scheduled).contains("The butler is here."))

        // And the daemon is what does it: take him off his rounds first and
        // he stays where he was put.
        let dismissed = try await play(ManorLab(), ["dismiss", "fetch", "look"])
        #expect(!turnOutput(of: "look", in: dismissed).contains("The butler is here."))
    }

    @Test func stopDaemonTakesHimOffHisRoundsForGood() async throws {
        let transcript = try await play(ManorLab(), ["dismiss"] + Array(repeating: "z", count: 20))
        #expect(!transcript.contains("The butler leaves for the dining room."))
        #expect(!transcript.contains("The butler winds the clock."))
    }

    // MARK: - Determinism and persistence

    @Test func midScheduleSaveAndRestoreResumesTheSameRounds() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gnusto-timetable-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let transcript = try await play(
            ManorLab(),
            ["save", "slot"]
                + Array(repeating: "z", count: 6)  // he leaves for the dining room
                + ["restore", "slot"]
                + Array(repeating: "z", count: 6),  // and leaves for it again
            saveDirectory: dir)
        #expect(occurrences(of: "The butler leaves for the dining room.", in: transcript) == 2)
    }

    @Test func twoIdenticalRunsAreByteIdentical() async throws {
        let commands = Array(repeating: "z", count: 20)
        let first = try await play(ManorLab(), commands)
        let second = try await play(ManorLab(), commands)
        #expect(first == second)
    }

    /// Nothing here draws from the seeded stream — a suspect whose movements
    /// are a coin flip has no alibi worth checking — so the seed cannot
    /// change a single line.
    @Test func differentSeedsProduceIdenticalTranscripts() async throws {
        let commands = Array(repeating: "z", count: 20)
        let one = try await play(ManorLab(), commands, seed: 1)
        let other = try await play(ManorLab(), commands, seed: 999)
        #expect(one == other)
    }

    // MARK: - Helpers

    private func occurrences(of needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }
}
