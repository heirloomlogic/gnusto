import Foundation
import Gnusto
import GnustoClock
import GnustoTestSupport
import Testing

@testable import Fulminate

/// End-to-end play of the mystery demo. This slice of the game is the house,
/// the clock, and the three fixed points of the evening — the case can be
/// walked but not yet solved, so these pin the *schedule* rather than a
/// solution: that the blast lands at 5:46 whatever the player is doing, that
/// the house reads differently on either side of it, and that the coroner
/// closes the file at ten to seven.
///
/// Two minutes to the turn from 5:30 pm, so turn *n* reads `17:30 + 2(n-1)`
/// and an alarm fires at the end of the first turn on or after its time: the
/// blast ends turn 9, the telephone turn 26, the coroner turn 41.
struct FulminateTests {
    // MARK: - The clock

    @Test func theWatchReadsHalfPastFiveOnArrival() async throws {
        let transcript = try await play(Fulminate(), ["time"])
        #expect(transcript.contains("Your watch says 5:30 pm."))
    }

    @Test func theHallClockAgreesWithYourWatch() async throws {
        let transcript = try await play(Fulminate(), ["examine clock", "time"])
        expectInOrder(transcript, ["The clock says 5:30 pm.", "Your watch says 5:32 pm."])
    }

    // MARK: - The blast

    @Test func theCarriageHouseGoesUpAtFiveFortySix() async throws {
        let transcript = try await play(
            Fulminate(), Array(repeating: "look", count: 8) + ["time"])
        let ninth = turnOutput(of: "time", in: transcript)
        #expect(ninth.contains("Your watch says 5:46 pm."))
        #expect(ninth.contains("loose sash in the place shivers"))
    }

    /// From the yard you get the whole thing; from indoors, a flat thump and
    /// the windows. Same alarm, two vantage points.
    @Test func theBlastIsSeenFromTheYardAndOnlyHeardIndoors() async throws {
        let fromYard = try await play(
            Fulminate(), ["south", "west"] + Array(repeating: "z", count: 7))
        #expect(fromYard.contains("The carriage house comes apart."))

        let fromHall = try await play(Fulminate(), Array(repeating: "z", count: 9))
        #expect(!fromHall.contains("The carriage house comes apart."))
        #expect(fromHall.contains("goes off with a flat, unimpressive thump"))
    }

    /// Being in the room when it goes up is a way to end the evening, and the
    /// player is given eight turns of standing in it to think better of that.
    @Test func standingInTheLabWhenItGoesUpIsFatal() async throws {
        let transcript = try await play(
            Fulminate(),
            ["south", "west", "north"] + Array(repeating: "z", count: 6))
        expectInOrder(
            transcript,
            [
                "Vane says \"hold this a moment\" and you never learn what.",
                "*** You have died ***",
            ])
    }

    @Test func theYardAndTheLabReadDifferentlyAfterTheBlast() async throws {
        let commands =
            Array(repeating: "z", count: 9)  // the blast, from the front hall
            + ["south", "west", "look", "north", "look"]
        let transcript = try await play(Fulminate(), commands)
        expectInOrder(
            transcript,
            [
                "shorter at the north end than the south",  // the yard, after
                "The roof is in the yard.",  // the lab, after
            ])
    }

    @Test func vaneIsAtHisBenchBeforeTheBlastAndGoneAfterIt() async throws {
        let commands =
            ["south", "west", "north", "south"]  // look in on him, then step out
            + Array(repeating: "z", count: 5)  // the blast, from the yard
            + ["north", "look"]
        let transcript = try await play(Fulminate(), commands)
        #expect(transcript.contains("Julian Vane is at the bench with his back to the door."))

        let afterwards = turnOutput(of: "look", in: transcript)
        #expect(afterwards.contains("The roof is in the yard."))
        #expect(!afterwards.contains("Julian Vane is at the bench"))
    }

    // MARK: - The deadline

    @Test func theTelephoneRingsAtTwentyPastSix() async throws {
        let transcript = try await play(Fulminate(), Array(repeating: "z", count: 26))
        #expect(transcript.contains("he is the night desk up at the lab"))
    }

    @Test func theCoronerClosesTheCaseAtTenToSeven() async throws {
        let transcript = try await play(Fulminate(), Array(repeating: "z", count: 41))
        #expect(transcript.contains("The county man comes up the path at ten to seven"))
        #expect(transcript.contains("writes *accidental* in the box marked cause"))
    }

    // MARK: - The house

    @Test func theCellarIsDarkUntilYouFetchTheFlashlight() async throws {
        let dark = try await play(Fulminate(), ["south", "down", "look"])
        #expect(dark.contains("pitch black"))

        let lit = try await play(
            Fulminate(),
            ["south", "open drawer", "take flashlight", "turn on flashlight", "down", "look"])
        #expect(lit.contains("It smells like a cellar."))
        #expect(lit.contains("scorched glove"))
    }

    /// The receipt turns up only when the player decides to go through
    /// somebody else's pockets — and only once there is a receipt to find. A
    /// slip stamped 6:05 cannot be in that coat at half past five, so the
    /// search comes back empty until Teague is home from the drugstore.
    @Test func theReceiptIsNotInTheCoatUntilTeagueIsBackFromTheDrugstore() async throws {
        let early = try await play(Fulminate(), ["look", "search coat"])
        #expect(!turnOutput(of: "look", in: early).contains("receipt"))
        #expect(!turnOutput(of: "search coat", in: early).contains("register paper"))

        // Teague is back at 6:10, which is the end of turn 21.
        let late = try await play(
            Fulminate(),
            Array(repeating: "z", count: 21) + ["search coat", "take receipt", "read receipt"])
        let search = turnOutput(of: "search coat", in: late)
        #expect(search.contains("a slip of register paper, folded once"))
        #expect(!search.contains("is empty"))
        #expect(late.contains("6:05"))
    }

    // MARK: - The household's rounds

    /// The opening tableau is read out of the five timetables rather than
    /// written down twice, so where everyone starts and where the schedule
    /// says they start cannot disagree.
    @Test func everyoneStartsWhereTheirTimetableSaysAtHalfPastFive() async throws {
        let game = Fulminate()
        let start = game.clock.start
        #expect(game.teagueDay.location(at: start) == game.boardersRoom)
        #expect(game.constanceDay.location(at: start) == game.parlour)
        #expect(game.kettleDay.location(at: start) == game.kitchen)
        #expect(game.delphineDay.location(at: start) == game.backYard)
        #expect(game.pikeDay.location(at: start) == game.parlour)

        let transcript = try await play(Fulminate(), ["west", "east", "south"])
        expectInOrder(
            transcript,
            [
                "Mrs. Vane is in her chair with the lamp unlit.",  // parlour
                "Mrs. Kettle is here, keeping busy.",  // kitchen
            ])
    }

    /// The whole of Teague's trip to the lab happens in front of the cook.
    /// This is the crossing the player can witness.
    @Test func teaguesCrossingToTheLabIsVisibleFromTheKitchen() async throws {
        let transcript = try await play(Fulminate(), ["south"] + Array(repeating: "z", count: 7))
        expectInOrder(
            transcript,
            [
                "Mrs. Kettle is here, keeping busy.",
                "Teague comes down the back stairs with his hat already on.",  // 5:36
                "Teague lets himself out the yard door.",  // 5:38
                "Teague comes back through the kitchen",  // 5:42
            ])
    }

    /// And this is the crossing the player can miss. Spend the same eight
    /// turns upstairs and the evening's most useful fact goes past unseen.
    @Test func theSameCrossingIsMissedEntirelyFromUpstairs() async throws {
        let transcript = try await play(Fulminate(), ["up", "west"] + Array(repeating: "z", count: 6))
        #expect(!transcript.contains("Teague lets himself out the yard door."))
        #expect(!transcript.contains("Teague comes back through the kitchen"))
    }

    /// The mystery's payoff: where he was is a lookup, not a line of prose
    /// somebody has to keep in step with the schedule. Both minutes below
    /// fall inside the half hour he will later place himself at a drugstore
    /// on Colorado.
    @Test func theTimetableAnswersWhereTeagueWasMinuteByMinute() {
        let game = Fulminate()
        #expect(game.teagueDay.location(at: TimeOfDay(17, 36)) == game.kitchen)
        #expect(game.teagueDay.location(at: TimeOfDay(17, 40)) == game.carriageHouse)
    }

    /// Off the map from 5:44 to 6:10 — there are questions that can only be
    /// put to him inside a window.
    @Test func teagueIsOffTheMapBetweenAQuarterToSixAndTenPast() async throws {
        let game = Fulminate()
        #expect(game.teagueDay.location(at: TimeOfDay(18, 0)) == game.street)

        // Fifteen turns in, at six o'clock, he is not anywhere the player can
        // reach — including the hall he walked out of.
        let transcript = try await play(
            Fulminate(), Array(repeating: "z", count: 15) + ["examine teague"])
        #expect(turnOutput(of: "examine teague", in: transcript).contains("can't see any such thing"))
    }

    /// Four of the five come out to the yard two minutes after it happens,
    /// which is both the natural thing and the first chance the player gets
    /// to see the whole household in one place. The fifth is on Colorado.
    @Test func theHouseholdConvergesOnTheYardAfterTheBlast() async throws {
        let transcript = try await play(
            Fulminate(), ["south", "west"] + Array(repeating: "z", count: 8))
        expectInOrder(
            transcript,
            [
                "The carriage house comes apart.",
                "Mrs. Vane comes out as far as the step",
            ])
        #expect(transcript.contains("Mrs. Kettle comes out drying her hands"))
        #expect(transcript.contains("Dr. Pike arrives in the yard"))
    }

    /// She goes down without a light at 6:26, and the dark is what hides her:
    /// the arrival line exists, so the same wait with the flashlight burning
    /// catches her and without it does not. Testing only the dark half would
    /// pass just as well against a stop that had nothing to say.
    @Test func theDarkIsWhatHidesDelphineInTheCellar() async throws {
        // 6:26 is the end of turn 29. Two turns are spent getting down there.
        let inTheDark = try await play(
            Fulminate(), ["south", "down"] + Array(repeating: "z", count: 27))
        #expect(inTheDark.contains("pitch black"))
        #expect(!inTheDark.contains("Delphine comes down the cellar steps"))

        let withALight = try await play(
            Fulminate(),
            ["south", "open drawer", "take flashlight", "turn on flashlight", "down"]
                + Array(repeating: "z", count: 24))
        #expect(withALight.contains("Delphine comes down the cellar steps"))
    }

    /// Nothing in the evening draws from the seeded stream. Five suspects on
    /// timetables is five suspects whose alibis mean something.
    @Test func theEveningIsIdenticalUnderAnySeed() async throws {
        let commands = Array(repeating: "z", count: 35)
        let one = try await play(Fulminate(), commands, seed: 1)
        let other = try await play(Fulminate(), commands, seed: 999)
        #expect(one == other)
    }

    /// You came out here because a man wrote you a letter. Leaving is the one
    /// thing the game won't let you do.
    @Test func theStreetIsNotAnOption() async throws {
        let transcript = try await play(Fulminate(), ["east"])
        #expect(transcript.contains("Walking back down the path now"))
    }
}
