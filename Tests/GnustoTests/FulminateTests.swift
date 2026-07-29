import Foundation
import Gnusto
import GnustoClock
import GnustoTestSupport
import Testing

@testable import Fulminate

/// End-to-end play of the mystery demo: the schedule — the blast lands at
/// 5:46 whatever the player is doing, the house reads differently on either
/// side of it, the coroner closes the file at ten to seven — and the case,
/// from the first lie through the evidence chain to the accusation that ends
/// the game one of three ways.
///
/// Two minutes to the turn from 5:30 pm, so turn *n* reads `17:30 + 2(n-1)`
/// and an alarm fires at the end of the first turn on or after its time: the
/// blast ends turn 9, the radio car turn 12, the telephone turn 26, the
/// coroner turn 41.
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

    // MARK: - The radio car

    /// 5:52, the end of turn 12: the radio car, and — for the first time
    /// anywhere in the game — the deadline. Nobody standing in the hall at
    /// half past five knows the county's schedule; it is learned in play.
    @Test func theDeadlineIsLearnedWhenTheRadioCarComes() async throws {
        let before = try await play(Fulminate(), Array(repeating: "z", count: 11))
        #expect(!before.contains("ten of seven"))

        let transcript = try await play(
            Fulminate(), Array(repeating: "z", count: 11) + ["time"])
        let twelfth = turnOutput(of: "time", in: transcript)
        #expect(twelfth.contains("Your watch says 5:52 pm."))
        #expect(twelfth.contains("due by ten of seven"))
    }

    /// He is posted at the wreckage from 5:52 on, answers exactly one useful
    /// subject, and the debris stays off limits — the case will not be
    /// solved by sifting.
    @Test func thePatrolmanKnowsExactlyOneUsefulThing() async throws {
        let commands =
            Array(repeating: "z", count: 12)
            + [
                "south", "west", "north",
                "ask patrolman about the coroner",
                "ask patrolman about the lodge",
                "search wreckage",
            ]
        let transcript = try await play(Fulminate(), commands)
        #expect(transcript.contains("A patrolman is posted at the wreckage"))
        #expect(
            turnOutput(of: "ask patrolman about the coroner", in: transcript)
                .contains("ten of seven"))
        #expect(
            turnOutput(of: "ask patrolman about the lodge", in: transcript)
                .contains("Best keep back from there."))
        #expect(
            turnOutput(of: "search wreckage", in: transcript)
                .contains("puts a shoulder where you were going"))
    }

    // MARK: - The victim

    /// Julian is alive and askable for the first eight turns. A player who
    /// spends them talking to the victim learns things a player who wanders
    /// the garden does not — and the blast, not a gate, is what closes the
    /// window: conversation and the alarm know nothing about each other.
    @Test func julianIsAskableUntilTheBlastTakesHim() async throws {
        let transcript = try await play(
            Fulminate(),
            [
                "south", "west", "north",
                "ask julian about the letter",
                "ask julian about pike",
            ])
        #expect(transcript.contains("A man who takes nothing is coming back."))
        #expect(transcript.contains("Tell Pike I said so."))
    }

    // MARK: - The interrogation

    /// Teague's alibi dies in the right order: the drugstore speech, the
    /// cook's testimony, and the speech gone — retired, not repeated.
    @Test func teaguesAlibiDiesWhenKettleContradictsIt() async throws {
        let commands =
            Array(repeating: "z", count: 21)  // Teague is home at the end of turn 21
            + [
                "ask teague about the drugstore",
                "south",
                "ask kettle about teague",
                "north",
                "ask teague about his alibi",
            ]
        let transcript = try await play(Fulminate(), commands)
        expectInOrder(
            transcript,
            [
                "Ask them, they know me.",
                "hat already on",
                "check her arithmetic",
            ])
        #expect(!turnOutput(of: "ask teague about his alibi", in: transcript).contains("Coca-Cola"))
    }

    /// Mrs. Kettle's testimony is not a written line: the room she names is
    /// read out of Teague's timetable, so a schedule edit changes what she
    /// says with it. This is the demonstration the whole game exists to make.
    @Test func kettlesTestimonyIsReadFromTheTimetable() async throws {
        let game = Fulminate()
        #expect(game.teagueDay.location(at: TimeOfDay(17, 42)) == game.kitchen)

        // "kitchen" below is the name of the room the lookup returns,
        // interpolated into her line — not a word anybody typed into it.
        let transcript = try await play(Fulminate(), ["south", "ask kettle about teague"])
        #expect(
            turnOutput(of: "ask kettle about teague", in: transcript)
                .contains("into the kitchen at eighteen minutes to six"))
    }

    /// The receipt breaks Teague, and what he told Constance — the keystone
    /// the full ending turns on — only comes out after it.
    @Test func theReceiptBreaksTeagueAndTheKeystoneFollows() async throws {
        let commands =
            Array(repeating: "z", count: 21)
            + [
                "ask teague about mrs vane",  // stonewalled: he hasn't broken
                "search coat",
                "take receipt",
                "show receipt to teague",
                "ask teague about mrs vane",
            ]
        let transcript = try await play(Fulminate(), commands)
        expectInOrder(
            transcript,
            [
                "Keeps to her parlour.",
                "\"Six-oh-five,\" he says.",
                "I told the old lady he'd gone out.",
            ])
    }

    /// Constance's table is nearly all refusals until the glove, and the
    /// glove is the one thing that breaks her.
    @Test func constanceBreaksOnlyOnceYouHaveTheGlove() async throws {
        let commands =
            ["south", "open drawer", "take flashlight", "turn on flashlight", "down", "take glove", "up", "north"]
            + Array(repeating: "z", count: 4)  // the blast ends turn 9, the radio car turn 12
            + [
                "west",
                "ask mrs. vane about the evening",
                "show glove to mrs. vane",
                "ask mrs. vane about the evening",
            ]
        let transcript = try await play(Fulminate(), commands)
        expectInOrder(
            transcript,
            [
                "I have been in the parlour all evening.",
                "trying to remember whether I put it back",
                "I put it where the heat would find it",
            ])
    }

    /// The two lurid explanations die in the study: the letters clear
    /// Delphine, and the ledger gets Pike to give up the earlier visit.
    @Test func theLettersAndTheLedgerRetireTheRedHerrings() async throws {
        let commands =
            Array(repeating: "z", count: 16)
            + [
                "up", "west",  // Delphine reaches the study at the end of turn 17
                "take letters",
                "show letters to delphine",
                "ask delphine about the letters",
                "take ledger",
                "z",  // Pike reaches the study at the end of turn 23
                "show ledger to pike",
                "ask pike about his visit",
            ]
        let transcript = try await play(Fulminate(), commands)
        expectInOrder(
            transcript,
            [
                "you know what they are not",
                "dress it in robes",
                "I paid for those.",
                "I have been here before.",
            ])
    }

    // MARK: - The accusation

    /// The winning walkthrough, whole: testimony, receipt, keystone, glove,
    /// accusation — and the fuller ending, in which the county man writes
    /// down two names instead of one.
    @Test func accusingConstanceKnowingTheKeystoneIsTheFullWin() async throws {
        let commands =
            [
                "south",  // the kitchen
                "ask kettle about teague",  // the alibi dies
                "open drawer", "take flashlight", "turn on flashlight",
                "down", "take glove", "up",  // the cellar gives up the glove
                "north",  // back to the hall; the blast ends this turn
            ]
            + Array(repeating: "z", count: 12)  // the radio car; Teague home at the end of turn 21
            + [
                "search coat", "take receipt",
                "show receipt to teague",  // he recants
                "ask teague about mrs vane",  // the keystone
                "west",
                "show glove to mrs. vane",  // the confession
                "accuse mrs. vane",
            ]
        let transcript = try await play(Fulminate(), commands)
        expectInOrder(
            transcript,
            [
                "hat already on",
                "\"Six-oh-five,\" he says.",
                "I told the old lady he'd gone out.",
                "trying to remember whether I put it back",
                "two names in it",
            ])
    }

    /// Accuse her without the keystone and you still win, but the county man
    /// does not ask why — the case is solved without being understood.
    @Test func accusingConstanceWithoutTheKeystoneIsThePartialWin() async throws {
        let transcript = try await play(
            Fulminate(),
            Array(repeating: "z", count: 12) + ["west", "accuse mrs. vane"])
        #expect(transcript.contains("an answer that would fit in the space provided"))
        #expect(!transcript.contains("two names in it"))
    }

    /// A wrong name ends the run — the deadline's teeth. The deputy coroner
    /// does not argue with you; the stamp comes down anyway.
    @Test func accusingTheWrongPersonEndsTheGame() async throws {
        let transcript = try await play(
            Fulminate(),
            Array(repeating: "z", count: 12) + ["south", "west", "accuse pike"])
        #expect(transcript.contains("writes *accidental* in the box marked cause"))
    }

    /// And there is nothing to accuse anybody of before the blast.
    @Test func accusationsBeforeTheBlastAreRefused() async throws {
        let transcript = try await play(Fulminate(), ["west", "accuse mrs. vane"])
        #expect(transcript.contains("There is nothing to accuse anybody of."))
        #expect(!transcript.contains("space provided"))
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
