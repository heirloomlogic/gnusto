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
    /// somebody else's pockets — and the search doesn't first report the coat
    /// empty and then contradict itself.
    @Test func theReceiptTurnsUpOnlyWhenTheCoatIsSearched() async throws {
        let transcript = try await play(
            Fulminate(), ["look", "search coat", "take receipt", "read receipt"])

        let arrival = turnOutput(of: "look", in: transcript)
        #expect(!arrival.contains("receipt"))

        let search = turnOutput(of: "search coat", in: transcript)
        #expect(search.contains("a slip of register paper, folded once"))
        #expect(!search.contains("is empty"))

        #expect(transcript.contains("6:05"))
    }

    /// You came out here because a man wrote you a letter. Leaving is the one
    /// thing the game won't let you do.
    @Test func theStreetIsNotAnOption() async throws {
        let transcript = try await play(Fulminate(), ["east"])
        #expect(transcript.contains("Walking back down the path now"))
    }
}
