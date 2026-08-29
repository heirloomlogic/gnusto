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
        #expect(ninth.contains("everything in the place shivers at once"))
    }

    /// From the yard you get the whole thing; from indoors, a flat thump and a
    /// house going quiet. Same alarm, two vantage points.
    @Test func theBlastIsSeenFromTheYardAndOnlyHeardIndoors() async throws {
        let fromYard = try await play(
            Fulminate(), ["south", "west"] + Array(repeating: "z", count: 7))
        #expect(fromYard.contains("The carriage house comes apart."))

        let fromHall = try await play(Fulminate(), Array(repeating: "z", count: 9))
        #expect(!fromHall.contains("The carriage house comes apart."))
        #expect(fromHall.contains("goes off with a flat, unimpressive thump"))
    }

    /// The blast and the turn after it are written in doors and breakage going
    /// off above and below the man hearing them, and that is a claim about
    /// which floor he is standing on. The branch used to be indoors/outdoors,
    /// which put a run of breakage below a player in the Cellar — the lowest
    /// room in the house — and a door above one on the top floor.
    @Test func theBlastNarratesTheFloorThePlayerIsStandingOn() async throws {
        let cellar = try await play(
            Fulminate(),
            ["south", "open drawer", "take flashlight", "turn on flashlight", "down"]
                + Array(repeating: "z", count: 5))
        #expect(cellar.contains("Above you a long run of breakage"))
        #expect(!cellar.contains("Below you a long run of breakage"))
        #expect(cellar.contains("a door goes above you, and another one above that"))

        let upstairs = try await play(Fulminate(), ["up"] + Array(repeating: "z", count: 9))
        #expect(upstairs.contains("Below you a long run of breakage starts and finishes, floor after floor"))
        #expect(upstairs.contains("a door goes close by, and another one below"))

        // The ground floor is the one the paragraph was always written from,
        // and there it still reads exactly as it did.
        let hall = try await play(Fulminate(), Array(repeating: "z", count: 10))
        #expect(hall.contains("Something lets go above you"))
        #expect(hall.contains("Below you a long run of breakage"))
        #expect(hall.contains("a door goes above you, and another one below"))
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

    /// The walk has to reach the lab before 5:52, because after that the
    /// patrolman is standing in the way of it.
    @Test func theYardAndTheLabReadDifferentlyAfterTheBlast() async throws {
        let commands =
            Array(repeating: "z", count: 9)  // the blast, from the front hall
            + ["south", "west", "north", "look"]
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

    /// **A telephone is heard from the rooms off the hall, and answered only in
    /// it.** The parlour is one room away through a doorway; it gets the rings
    /// and not the voice.
    @Test func theTelephoneIsHeardFromTheRoomsOffTheHall() async throws {
        let transcript = try await play(
            Fulminate(), ["west"] + Array(repeating: "z", count: 25))
        #expect(transcript.contains("It rings eleven times."))
        #expect(!transcript.contains("he is the night desk up at the lab"))
    }

    /// **And not from the cellar, which is under the kitchen behind a shut
    /// door.** #306: the else-branch had no gate on it at all, so a man sitting
    /// in the dark two floors down was told a telephone was ringing eleven
    /// times somewhere he could not have heard it.
    ///
    /// The coroner is the control. He arrives at ten to seven whatever the
    /// player was told at twenty past six, which is the whole contract of a
    /// gated `say`: the clock does not wait to be listened to.
    @Test func theTelephoneIsNotHeardFromTheCellar() async throws {
        let transcript = try await play(
            Fulminate(), ["south", "down"] + Array(repeating: "z", count: 39))
        #expect(!transcript.contains("It rings eleven times."))
        #expect(!transcript.contains("he is the night desk up at the lab"))
        #expect(transcript.contains("The county man comes up the path at ten to seven"))
    }

    @Test func theCoronerClosesTheCaseAtTenToSeven() async throws {
        let transcript = try await play(Fulminate(), Array(repeating: "z", count: 41))
        #expect(transcript.contains("The county man comes up the path at ten to seven"))
        #expect(transcript.contains("writes *accidental* in the box marked cause"))
    }

    // MARK: - The radio car

    /// 5:52, the end of turn 12: the radio car. He arrives with a notebook and
    /// nothing to volunteer. The deadline reaches the page only when somebody
    /// puts the question to him — learned in play, not stated in the opening,
    /// and not dumped on arrival either.
    @Test func theDeadlineIsAskedForRatherThanAnnounced() async throws {
        // Turn 12 brings the car, heard from indoors, and no deadline with it.
        let indoors = try await play(
            Fulminate(), Array(repeating: "z", count: 11) + ["time"])
        let twelfth = turnOutput(of: "time", in: indoors)
        #expect(twelfth.contains("Your watch says 5:52 pm."))
        #expect(twelfth.contains("A patrolman works through the house taking names"))
        #expect(!indoors.contains("ten of seven"))

        // Nor does standing in the yard and watching him post himself at it.
        let inTheYard = try await play(
            Fulminate(), ["south", "west"] + Array(repeating: "z", count: 12))
        #expect(inTheYard.contains("posts himself where the door used to be"))
        #expect(!inTheYard.contains("ten of seven"))

        // It costs a question.
        let asked = try await play(
            Fulminate(),
            Array(repeating: "z", count: 12)
                + ["south", "west", "ask patrolman about the coroner"])
        #expect(
            turnOutput(of: "ask patrolman about the coroner", in: asked)
                .contains("Due by ten of seven"))
    }

    /// He is posted at the wreckage from 5:52 on, has three answers and only
    /// one that matters, and the debris stays off limits — the case will not
    /// be solved by sifting. He stands in the yard, at the gap where the door
    /// was, which is where a man keeping people out of a building stands.
    @Test func thePatrolmanKnowsExactlyOneUsefulThing() async throws {
        let commands =
            Array(repeating: "z", count: 12)
            + [
                "south", "west",
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
                "check her figures",
            ])
        #expect(!turnOutput(of: "ask teague about his alibi", in: transcript).contains("Coca-Cola"))
    }

    /// Mrs. Kettle's testimony is not a written line: the rooms she names are
    /// read out of Teague's timetable, so a schedule edit changes what she
    /// says with it. This is the demonstration the whole game exists to make.
    ///
    /// She watches two crossings from the stove and testifies to both. The row
    /// used to describe the **first** — the back stairs, the hat already on —
    /// and quote the minute of the **second**. Both stops are the kitchen, so
    /// the timetable read could not see the error: it only ever supplied the
    /// room.
    @Test func kettlesTestimonyIsReadFromTheTimetable() async throws {
        let game = Fulminate()
        #expect(game.teagueDay.location(at: Fulminate.teagueCameDown) == game.kitchen)
        #expect(game.teagueDay.location(at: Fulminate.sawTeague) == game.kitchen)

        // Both "kitchen"s below are the name of the room a lookup returns,
        // interpolated into her line — not a word anybody typed into it. Asked
        // at 5:42, which is the later of the two minutes she is quoting: the
        // row used to answer in the past tense from 5:32, ten minutes before
        // Teague came down.
        let transcript = try await play(
            Fulminate(), ["south"] + Array(repeating: "z", count: 5) + ["ask kettle about teague"])
        let testimony = turnOutput(of: "ask kettle about teague", in: transcript)
        #expect(testimony.contains("down my back stairs into the kitchen at twenty-four minutes to six"))
        #expect(testimony.contains("come back into the kitchen at eighteen minutes to"))

        // The defect, pinned: the descent and the hat belong to 5:36, and the
        // row may not hang them on 5:42.
        #expect(!testimony.contains("back stairs into the kitchen at eighteen minutes to six"))
    }

    /// The other half of the same mechanic. Her rows read a hard-coded minute
    /// out of somebody's timetable, and a row that quotes 5:46 has no business
    /// answering at 5:32 — the lookup is right and the tense is not. Worse, the
    /// Teague row carries `learning:`, so the fact that kills his alibi was
    /// taught fourteen minutes before the event that teaches it.
    @Test func nobodyTestifiesInThePastTenseAboutTheFuture() async throws {
        let early = try await play(
            Fulminate(),
            [
                "south", "ask kettle about teague", "ask kettle about constance",
                "ask kettle about delphine", "ask kettle about pike", "time",
            ])
        #expect(turnOutput(of: "time", in: early).contains("5:40 pm"))
        #expect(!early.contains("when it went"))
        // Neither minute the testimony quotes, not just the later one — the row
        // names 5:36 as well now, and 5:36 is also in the future at 5:32.
        #expect(!early.contains("at eighteen minutes to"))
        #expect(!early.contains("at twenty-four minutes to six"))
        #expect(
            turnOutput(of: "ask kettle about teague", in: early)
                .contains("Ask me again once the pot's on"))

        // And the fact goes with the testimony: asking early must not teach
        // that she saw him, because she has not seen him yet.
        let stillLying = try await play(
            Fulminate(),
            ["south", "ask kettle about teague"] + Array(repeating: "z", count: 19)
                + ["north", "ask teague about drugstore"])
        #expect(
            turnOutput(of: "ask teague about drugstore", in: stillLying)
                .contains("Ask them, they know me"))
        #expect(!stillLying.contains("I'd check her figures"))

        // Asking early must not spend the answer. The two rows are tracked
        // apart, so the testimony still lands at 5:42 — and the early row keeps
        // its invitation open rather than taking it back with the table's
        // "I've said my piece on that one."
        let askedTwice = try await play(
            Fulminate(),
            [
                "south", "ask kettle about teague",  // 5:32, too early
                "z", "z", "ask kettle about teague",  // 5:38, still too early
                "z", "ask kettle about teague",  // 5:42, the minute she quotes
            ])
        #expect(askedTwice.contains("I'll not guess for you before then."))
        #expect(!askedTwice.contains("I've said my piece on that one."))
        #expect(askedTwice.contains("come back into the kitchen at eighteen minutes to"))

        // Teague's own alibi has the same shape and the same repair: at 5:34,
        // standing in his own room, he used to say he had walked down and
        // walked back — ten minutes before he goes.
        let earlyTeague = try await play(
            Fulminate(), ["up", "east", "ask teague about drugstore"])
        #expect(
            turnOutput(of: "ask teague about drugstore", in: earlyTeague)
                .contains("Nothing to tell yet"))
        #expect(!earlyTeague.contains("walked down, had a Coca-Cola, walked back"))
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

    /// The accusation is spent once. Naming yourself is refused rather than
    /// written down, since the ending it would buy is a joke the deadline
    /// can't afford.
    @Test func accusingYourselfIsRefusedRatherThanTakenDown() async throws {
        let transcript = try await play(
            Fulminate(), Array(repeating: "z", count: 12) + ["accuse me"])
        #expect(transcript.contains("The coroner would take the name down. Give him a better one."))
        #expect(!transcript.contains("writes *accidental* in the box marked cause"))
    }

    /// The player has a history, and `X ME` is where a player asks for it.
    @Test func examiningYourselfGivesThisGamesOwnLine() async throws {
        let transcript = try await play(Fulminate(), ["x me"])
        #expect(
            turnOutput(of: "x me", in: transcript)
                .contains("The same man who took statements in that front hall in 1948, four years older."))
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

    // MARK: - The house answers to its own descriptions

    /// The first thing a play-tester typed in this house was `X TILE`, and the
    /// house did not know the word — for a noun its own opening paragraph puts
    /// on the page. This walks the ground floor asking for each of them.
    @Test func theGroundFloorAnswersToItsOwnDescriptions() async throws {
        let transcript = try await play(
            Fulminate(),
            [
                "x tile", "x grout", "x hat stand", "x half moon table",
                "x front door", "x staircase",
                "west", "x furniture", "x grate", "x lamp", "x wallpaper",
                "east", "south", "x pine table", "x back stairs", "x cellar steps",
                "x yard door", "x drawer", "x stove",
            ])
        expectEveryNounAnswered(transcript)
    }

    /// The same walk one level down: not the things a room lists, but the
    /// things the *examine* text of those things names in passing. Every word
    /// here was a `I don't know the word` or a `You can't see any such thing`
    /// before the 2026-07-31 round, several of them because the word was
    /// declared as an adjective and so could never be typed on its own.
    @Test func theGroundFloorAnswersToItsOwnExamineText() async throws {
        let hall = try await play(
            Fulminate(),
            [
                "x corner", "x passage", "x diamond", "x treads", "x rods",
                "x carpet", "x marble", "x ring", "x pad", "x fanlight", "x hat",
                "west", "x bulb", "x fringe", "x rectangle", "x roses",
                "east", "south", "x pine", "x grain", "x counter", "x switch", "x pot",
            ])
        expectEveryNounAnswered(hall)

        // The cellar's is the one that hurt most: the search refusal ends "the
        // dust is the interesting part" and pointed the player at a word the
        // vocabulary did not contain.
        let cellar = try await play(
            Fulminate(),
            [
                "south", "open drawer", "take flashlight", "turn on flashlight", "down",
                "x dust", "search coal bin",
            ])
        expectEveryNounAnswered(cellar)
        #expect(turnOutput(of: "x dust", in: cellar).contains("three winters of coal dust"))
    }

    /// The gap the suite itself left: this walk never fired a timed event, so
    /// every word the blast and its aftermath put on the page went unchecked —
    /// which is exactly where the round found the most of them. This one waits
    /// for 5:46 and then asks the yard for what it has just described.
    @Test func theYardAnswersForWhatTheBlastPutInIt() async throws {
        let transcript = try await play(
            Fulminate(),
            ["south", "west"] + Array(repeating: "z", count: 7)
                + [
                    "look", "x fire", "x flames", "x wreckage", "x roof", "x slates",
                    "x timber", "x body", "x step", "x wall", "x grass",
                ])
        expectEveryNounAnswered(transcript)
        #expect(turnOutput(of: "x fire", in: transcript).contains("where the roof came down"))
    }

    /// The yard's two-sided props. Answering a noun is not enough on its own —
    /// the lamp the pre-blast description is written around stops existing at
    /// 5:46, and a synonym hung on the building would have gone on describing
    /// the building to a player asking about a lamp in the grass.
    @Test func theYardsPropsReadDifferentlyOnTheTwoSidesOfTheBlast() async throws {
        let before = try await play(Fulminate(), ["south", "west", "x lamp", "x wall"])
        #expect(turnOutput(of: "x lamp", in: before).contains("burning at half past five in June"))
        #expect(turnOutput(of: "x wall", in: before).contains("losing an argument with the ivy"))

        let after = try await play(
            Fulminate(), ["south", "west"] + Array(repeating: "z", count: 8) + ["x lamp", "x wall"])
        #expect(turnOutput(of: "x lamp", in: after).contains("In the grass with everything else"))
        #expect(turnOutput(of: "x wall", in: after).contains("The ivy is holding up what is left"))
    }

    /// **`window` was printed by two declarations and known to no vocabulary.**
    /// The lab lamp's pre-blast line put one in the carriage house and Teague's
    /// confession put one in the Front Hall, a room that has none; neither is a
    /// word this game answers. Both sentences say what they said without it.
    /// (#280, C7)
    @Test func nothingPrintsAWindowThisGameDoesNotHave() async throws {
        let yard = try await play(Fulminate(), ["south", "west", "x lamp"])
        let lamp = turnOutput(of: "x lamp", in: yard)
        #expect(lamp.contains("works to the bench and forgets the rest"))
        #expect(!lamp.contains("window"))

        let hall = try await play(
            Fulminate(),
            Array(repeating: "z", count: 21)
                + ["search coat", "take receipt", "show receipt to teague", "ask teague about mrs vane"])
        let keystone = turnOutput(of: "ask teague about mrs vane", in: hall)
        #expect(keystone.contains("I told the old lady he'd gone out."))
        #expect(keystone.contains("He looks past you."))
        #expect(!keystone.contains("window"))
    }

    /// And the lab from inside, which calls itself somebody's workshop and
    /// somebody else's chapel and then puts its own roof in the yard.
    @Test func theCarriageHouseAnswersForTheWordsItCallsItselfBy() async throws {
        let transcript = try await play(
            Fulminate(),
            [
                "south", "west", "north",
                "x workshop", "x chapel", "x walls", "x roof", "x rafters",
                "x vice", "x nail", "x board", "x outline", "x blanket", "x corner",
            ])
        expectEveryNounAnswered(transcript)
    }

    /// Dr. Pike's hat is named in five sentences across three rooms and was a
    /// word none of them knew, because it was declared as an adjective on a
    /// coat stand in a fourth room he never enters. It travels with him now.
    @Test func theHatGoesWhereTheDoctorGoes() async throws {
        let parlour = try await play(Fulminate(), ["west", "x pike", "x hat", "x doctor"])
        #expect(turnOutput(of: "x hat", in: parlour).contains("Grey felt"))
        #expect(turnOutput(of: "x doctor", in: parlour).contains("has not had the hat off"))

        // And in the yard, where he arrives holding it against his chest.
        let yard = try await play(
            Fulminate(), ["south", "west"] + Array(repeating: "z", count: 9) + ["x hat"])
        #expect(turnOutput(of: "x hat", in: yard).contains("Grey felt"))

        // The hall's own hat stand keeps the word where he is not.
        let hall = try await play(Fulminate(), ["x hat"])
        #expect(turnOutput(of: "x hat", in: hall).contains("six hooks"))
    }

    /// And upstairs, and the lab. Separately, because the walk is long enough
    /// that the blast would land in the middle of one trip.
    @Test func theUpstairsAndTheLabAnswerToo() async throws {
        let upstairs = try await play(
            Fulminate(),
            [
                "up", "x runner", "west", "x desk", "x drawer", "x lamp",
                "east", "east", "x typewriter", "x sheet", "x bed", "x suitcase",
            ])
        expectEveryNounAnswered(upstairs)

        let lab = try await play(
            Fulminate(),
            ["south", "west", "north", "x bench", "x tool rack", "x cot", "x stove pipe"])
        expectEveryNounAnswered(lab)

        // And the cellar's coal bin, which the glove's own description names.
        let cellar = try await play(
            Fulminate(),
            ["south", "open drawer", "take flashlight", "turn on flashlight", "down", "x coal bin"])
        #expect(turnOutput(of: "x coal bin", in: cellar).contains("three winters of coal dust"))
    }

    /// The study is a paragraph about a desk whose drawers are standing open,
    /// and all three of the ways a player asks about that used to answer with
    /// the engine's shrug.
    @Test func theStudyDeskGivesUpItsDrawers() async throws {
        let transcript = try await play(
            Fulminate(), ["up", "west", "x desk", "x drawers", "search desk"])
        #expect(turnOutput(of: "x desk", in: transcript).contains("Every drawer is standing open"))
        #expect(turnOutput(of: "x drawers", in: transcript).contains("square to the fronts"))
        #expect(
            turnOutput(of: "search desk", in: transcript)
                .contains("Somebody has done this before you"))
        #expect(!transcript.contains("You see nothing special"))
        #expect(!transcript.contains("You find nothing of interest"))
    }

    /// The patrolman is the one actor in this house without `properName`, so he
    /// is the one who exposed a template that interpolated a rendered phrase at
    /// sentence-initial position. It printed "the patrolman looks at it and
    /// looks away." The five proper-named actors capitalise themselves and hid
    /// it for the whole of the game's life.
    @Test func theOneActorWithoutAProperNameStillGetsACapitalLetter() async throws {
        let transcript = try await play(
            Fulminate(), ["south", "west"] + Array(repeating: "z", count: 10) + ["show watch to patrolman"])
        let answer = turnOutput(of: "show watch to patrolman", in: transcript)
        #expect(answer.contains("The patrolman looks at it and looks away."))
        #expect(!answer.contains("the patrolman looks at it"))
    }

    /// The same fault, in the two lines the fix above missed. `greets` and
    /// `notTakingOrders` were written the same way and went on printing "the
    /// patrolman hears you out" for as long as the sibling did — invisible for
    /// the same reason, and found by the source sweep in
    /// ``ProseConventionTests`` rather than by anybody reading a transcript.
    ///
    /// Only `notTakingOrders` is asserted, because only it can be reached:
    /// every actor in this house carries a conversation, so `GnustoConversation`
    /// answers a greeting before ``GameText/greets`` is consulted and the line
    /// is unreachable in Fulminate. It was fixed anyway — a line that is right
    /// only because nothing calls it is a trap for whoever adds the sixth
    /// actor.
    @Test func theOrderRefusalThatOpensOnHisNameGetsACapitalLetterToo() async throws {
        let approach = ["south", "west"] + Array(repeating: "z", count: 10)
        let transcript = try await play(Fulminate(), approach + ["patrolman, go north"])

        let ordered = turnOutput(of: "patrolman, go north", in: transcript)
        #expect(ordered.contains("The patrolman hears you out"))
        #expect(!ordered.contains("the patrolman hears you out"))
    }

    // MARK: - Frames the stock lines were never told about

    /// Fulminate set five `text` keys and no `text.stubs.*` at all, so the
    /// engine's room-blind and state-blind defaults answered in frames the game
    /// had just built. `stand` is the sharpest of them: the game models being
    /// knocked flat, so there is exactly one turn on which "You're already
    /// standing." contradicts the sentence printed directly above it.
    @Test func theStubVerbsKnowWhatTheGameHasJustSaid() async throws {
        // STAND's own three frames moved to
        // `standReadsTheWholeEveningAndNotOneTurnOfIt`, which plays a superset
        // of the route this used to. What is left is the engine's line never
        // reaching the player at all.
        let flat = try await play(
            Fulminate(), ["south", "west"] + Array(repeating: "z", count: 7) + ["stand"])
        #expect(!flat.contains("You're already standing."))

        // `climb stairs` was disproved by `up` on the very next command; now it
        // *is* `up`, so the flight the front hall names takes the verb.
        let stairs = try await play(Fulminate(), ["climb stairs", "down", "up"])
        #expect(!stairs.contains("You can't climb that."))
        #expect(!stairs.contains("You go up in this house by going up."))
        expectInOrder(stairs, ["Upstairs Landing", "Front Hall", "Upstairs Landing"])

        // And the parlour is built out of armchairs with a woman sitting in one.
        let parlour = try await play(Fulminate(), ["west", "sit"])
        #expect(!parlour.contains("There's nothing comfortable to sit on."))
        #expect(turnOutput(of: "sit", in: parlour).contains("every person this house used to hold"))
    }

    /// **C10, as corrected.** The issue said `text.stubs.stand` was one string
    /// with no read of the state the game set; there was a read, and its window
    /// was one turn wide. `knockedFlat` is set by the 5:46 alarm and cleared by
    /// the `blast.after` fuse on the next turn, so by 5:52 — the frame the round
    /// actually reported — the stub's "and have been since the streetcar" was
    /// getting through to a man the garden wall had come down on top of.
    ///
    /// Three frames, and the third is the one that used to lie.
    @Test func standReadsTheWholeEveningAndNotOneTurnOfIt() async throws {
        let yard = try await play(
            Fulminate(),
            ["south", "west", "stand"] + Array(repeating: "z", count: 6)
                + ["stand", "z", "z", "stand"])

        // 5:34, before anything has happened: the ordinary line is true.
        #expect(
            turnOutput(of: "stand", in: yard).contains("have been since the streetcar"))
        // 5:48, flat on the grass: the one-turn arm, unchanged by this pass.
        expectInOrder(
            yard,
            [
                "the ground hits you in the back",
                "You get an elbow under you and stop there.",
                "You get up.",
                // 5:56, several turns past the clear — where the flat literal used
                // to reappear.
                "when the carriage house put you on your back",
            ])

        // The control, and the reason the second arm reads
        // `wasInTheYardForTheBlast` rather than the clock: a player who spent
        // 5:46 on the landing was never put on his back, so nothing about his
        // evening disproves the streetcar.
        let indoors = try await play(
            Fulminate(), ["up"] + Array(repeating: "z", count: 9) + ["stand"])
        let upstairs = turnOutput(of: "stand", in: indoors)
        #expect(upstairs.contains("have been since the streetcar"))
        #expect(!upstairs.contains("put you down once already"))
    }

    /// **C11.** The CLIMB line said "in this house" while the player stood
    /// outdoors against a brick garden wall, in a room with no `up` at all — and
    /// it said it about whatever noun had been pointed at, since the line named
    /// nothing. Both halves are answered: the naming half reports on the thing,
    /// and the three flights the house does have walk their own exits.
    @Test func climbIsAboutTheThingAndNotAboutTheHouse() async throws {
        let outdoors = try await play(Fulminate(), ["south", "west", "climb wall", "climb"])
        #expect(!outdoors.contains("You go up in this house by going up."))
        #expect(
            turnOutput(of: "climb wall", in: outdoors)
                .contains("You put a hand on the garden wall and think better of it."))
        #expect(
            turnOutput(of: "climb", in: outdoors)
                .contains("You would have to say what you meant to climb."))

        // The back stairs refuse in the words `up` refuses in, and the cellar
        // steps go down, which is what `climb down` means about a cellar.
        let kitchen = try await play(
            Fulminate(), ["south", "climb back stairs", "climb cellar steps"])
        #expect(
            turnOutput(of: "climb back stairs", in: kitchen)
                .contains("The back stairs are the household's."))
        // Down, and the cellar is unlit, so the proof it walked is the dark.
        #expect(turnOutput(of: "climb cellar steps", in: kitchen).contains("It is pitch black."))
    }

    /// Swept rather than filed, and C11's defect one room over: the carriage
    /// house is a detached outbuilding, so the stub floor's "The house is doing
    /// what a house does" and "The stove, and the dust a house like this keeps
    /// between the wars" were both being said by a man standing inside it. The
    /// yard already had this pair of rules; its twin did not.
    @Test func theCarriageHouseIsNotTheHouse() async throws {
        let standing = try await play(
            Fulminate(), ["south", "west", "listen", "smell", "north", "listen", "smell"])
        #expect(standing.contains("Carriage House"))
        #expect(!standing.contains("The house is doing what a house does"))
        #expect(!standing.contains("the dust a house like this keeps between the wars"))
        // Four outdoor frames, in order: the yard before the blast, then the lab.
        expectInOrder(
            standing,
            [
                "somebody at a bench in the carriage house",
                "a thin chemical edge coming down the yard",
                "The stove pipe ticks as the kitchen feeds it.",
                "Vane works in here with the door shut.",
            ])

        // And the cellar, which has no stove in it and says so.
        let below = try await play(Fulminate(), ["south", "down", "smell"])
        #expect(
            turnOutput(of: "smell", in: below).contains("Nothing has been cooked down here in fifty years."))
        #expect(!below.contains("the dust a house like this keeps between the wars"))

        // And afterwards, in the three turns before the patrolman clears it.
        let wrecked = try await play(
            Fulminate(),
            ["south", "west"] + Array(repeating: "z", count: 7) + ["north", "listen", "smell"])
        #expect(turnOutput(of: "listen", in: wrecked).contains("a piece of metal ticks as it lets go of the heat"))
        #expect(turnOutput(of: "smell", in: wrecked).contains("That last is what a chemist would ask you about."))
    }

    /// **C12.** TOUCH was never re-skinned at all, so a lit cast-iron range
    /// answered the engine's "You feel nothing out of the ordinary." — as did
    /// the flue carrying its heat, and the fire in the wreckage afterwards.
    @Test func touchKnowsWhichThingsInThisHouseAreHot() async throws {
        let kitchen = try await play(Fulminate(), ["south", "touch stove", "touch drawer"])
        #expect(!kitchen.contains("You feel nothing out of the ordinary."))
        #expect(turnOutput(of: "touch stove", in: kitchen).contains("Cast iron with a fire under it."))
        // And the floor under it still answers for an ordinary thing, naming it.
        #expect(
            turnOutput(of: "touch drawer", in: kitchen)
                .contains("You put a hand on the kitchen drawer and learn nothing a hand can tell you."))

        let yard = try await play(
            Fulminate(),
            ["south", "west", "north", "touch pipe", "south"] + Array(repeating: "z", count: 8)
                + ["touch fire"])
        #expect(!yard.contains("You feel nothing out of the ordinary."))
        #expect(turnOutput(of: "touch pipe", in: yard).contains("all of it comes up this pipe"))
        #expect(
            turnOutput(of: "touch fire", in: yard)
                .contains("Nobody is going to get closer to it tonight."))
    }

    /// Thirty feet from a building the game has just said took the hair off the
    /// back of your hand, "You hear nothing out of the ordinary." and "You smell
    /// nothing out of the ordinary." are both false.
    @Test func theYardSoundsAndSmellsLikeWhatIsInIt() async throws {
        let transcript = try await play(
            Fulminate(), ["south", "west"] + Array(repeating: "z", count: 8) + ["listen", "smell"])
        #expect(turnOutput(of: "listen", in: transcript).contains("ticking as it cools"))
        #expect(turnOutput(of: "smell", in: transcript).contains("It is not a smell that came out of a stove."))
        #expect(!transcript.contains("nothing out of the ordinary"))
    }

    /// The naming stubs rendered a witness as furniture — "Mrs. Kettle is not
    /// food." — one line after `cantSearchActor` had refused to let the player
    /// lay a hand on her, and `touch` reported a completed act of contact on
    /// her. Two adjacent commands, opposite rulings.
    @Test func theStubVerbsTreatThePeopleInThisHouseAsPeople() async throws {
        let transcript = try await play(
            Fulminate(),
            [
                "south", "search mrs. kettle", "touch mrs. kettle", "eat mrs. kettle",
                "pull mrs. kettle", "break mrs. kettle", "touch stove",
            ])
        #expect(
            turnOutput(of: "search mrs. kettle", in: transcript)
                .contains("You are not putting a hand on Mrs. Kettle tonight."))
        for command in ["touch mrs. kettle", "eat mrs. kettle", "pull mrs. kettle", "break mrs. kettle"] {
            #expect(
                turnOutput(of: command, in: transcript)
                    .contains("Mrs. Kettle is a person, and this is not 1948."))
        }
        // And a stove is not a witness. The line it gets is C12's business, and
        // `touchKnowsWhichThingsInThisHouseAreHot` owns it; all this test wants
        // is that the person guard did not spread to the furniture.
        #expect(
            !turnOutput(of: "touch stove", in: transcript)
                .contains("is a person, and this is not 1948."))
    }

    /// Four faults on one object: `container` with nothing in it, so the stock
    /// empty line answered a question three sentences of prose had answered the
    /// other way and deleted one of the game's three character tells doing it;
    /// takeable, so `TAKE ALL` lifted a boarder's packed case out of his rented
    /// room while he stood downstairs being helpful; and named inline by the
    /// room description, which went on asserting a position the world no longer
    /// held.
    @Test func theSuitcaseStaysPackedAndStaysOnTheBed() async throws {
        let transcript = try await play(
            Fulminate(), ["up", "east", "search suitcase", "open suitcase", "take suitcase", "take all", "i"])
        #expect(!transcript.contains("The suitcase is empty."))
        #expect(!transcript.contains("You can't open that."))
        #expect(turnOutput(of: "search suitcase", in: transcript).contains("you leave it buckled"))
        #expect(
            turnOutput(of: "take suitcase", in: transcript).contains("belongs to a man who is somewhere in this house"))
        #expect(!turnOutput(of: "i", in: transcript).contains("suitcase"))
    }

    /// The can is the coroner's answer sitting where the stove's heat can reach
    /// it, and it was pocketable in the first five turns — which put a static
    /// description of a bench sixty feet away into the front hall and then had
    /// the blast take it out of the player's hands with no line of prose.
    @Test func theSealedCanStaysOnTheBench() async throws {
        let transcript = try await play(
            Fulminate(), ["south", "west", "north", "take can", "i"])
        #expect(turnOutput(of: "take can", in: transcript).contains("Ask him about it at six."))
        #expect(!turnOutput(of: "i", in: transcript).contains("can"))
    }

    /// The only timed event with no branch on where the player has been, so it
    /// credited a man who spent the evening in the front hall — or at the bottom
    /// of a pitch-black cellar — with having looked at the wreckage.
    @Test func theCoronerDoesNotCreditYouWithSomethingYouDidNotDo() async throws {
        let neverWent = try await play(Fulminate(), Array(repeating: "z", count: 41))
        #expect(!neverWent.contains("rather less time than you did"))
        #expect(neverWent.contains("which is more than you managed"))

        let went = try await play(
            Fulminate(), ["south", "west"] + Array(repeating: "z", count: 39))
        #expect(went.contains("rather less time than you did"))
    }

    /// This game declares no `Scoring`, so every ending — the win included —
    /// closed on an engine-voice line asserting nothing had been achieved,
    /// directly under the paragraph saying it had.
    @Test func noEndingReportsAScoreThisGameDoesNotKeep() async throws {
        let win = try await play(
            Fulminate(), ["west"] + Array(repeating: "z", count: 8) + ["accuse mrs. vane"])
        #expect(!win.contains("Your score is"))
        #expect(win.contains("You were in that house for"))

        let deadline = try await play(Fulminate(), Array(repeating: "z", count: 41))
        #expect(!deadline.contains("Your score is"))
    }

    /// `docs/games/fulminate.md` reserves one word to Constance's shock, and the
    /// code spent it twice elsewhere first — Teague at 5:38, the ledger from the
    /// first time it is read, against a branch of hers gated on the blast.
    @Test func arithmeticIsSpentOnlyWhereTheDocReservesIt() async throws {
        let transcript = try await play(
            Fulminate(),
            ["south", "ask kettle about teague"] + Array(repeating: "z", count: 19)
                + ["north", "up", "west", "x ledger", "east", "down", "west", "x mrs. vane"])
        #expect(occurrencesInFulminate(of: "arithmetic", in: transcript) == 1)
        #expect(turnOutput(of: "x mrs. vane", in: transcript).contains("doing arithmetic"))
    }

    /// The coat is a container with the case's hinge in it, not luggage. You
    /// cannot take it and you cannot wear it, and going through the pockets
    /// goes on working, which is the only thing it was ever for.
    @Test func theOvercoatStaysOnTheStand() async throws {
        let transcript = try await play(
            Fulminate(),
            Array(repeating: "z", count: 21)
                + ["take coat", "wear coat", "search coat", "take receipt", "inventory"])
        #expect(turnOutput(of: "take coat", in: transcript).contains("Leave it on the stand."))
        #expect(turnOutput(of: "wear coat", in: transcript).contains("It is June"))
        #expect(
            turnOutput(of: "search coat", in: transcript)
                .contains("a slip of register paper, folded once"))
        let inventory = turnOutput(of: "inventory", in: transcript)
        #expect(inventory.contains("drugstore receipt"))
        #expect(!inventory.contains("overcoat"))
    }

    /// The TIME verb has been reading a watch since turn one. It is on the
    /// player's wrist now, it agrees with the hall clock because he set it by
    /// the hall clock, and there is no way to put it down.
    @Test func theWatchIsOnYourWristAndStaysThere() async throws {
        let transcript = try await play(
            Fulminate(), ["inventory", "x watch", "remove watch", "drop watch", "time"])
        #expect(turnOutput(of: "inventory", in: transcript).contains("wristwatch (being worn)"))
        #expect(turnOutput(of: "x watch", in: transcript).contains("it says 5:32 pm"))
        #expect(turnOutput(of: "remove watch", in: transcript).contains("straight back on"))
        #expect(turnOutput(of: "drop watch", in: transcript).contains("since 1943"))
        #expect(turnOutput(of: "time", in: transcript).contains("Your watch says 5:38 pm."))
    }

    /// The kitchen names all three of its exits, names the drawer the dark
    /// cellar needs, and refuses the back stairs in its own words rather than
    /// the engine's.
    @Test func theKitchenNamesItsExitsAndRefusesTheBackStairs() async throws {
        let transcript = try await play(Fulminate(), ["south", "up"])
        let arrival = turnOutput(of: "south", in: transcript)
        #expect(arrival.contains("There is a drawer under the counter."))
        #expect(arrival.contains("The hall is north"))
        let refused = turnOutput(of: "up", in: transcript)
        #expect(refused.contains("The back stairs are the household's."))
        #expect(!refused.contains("can't go that way"))
    }

    /// The play-tester went down in the dark, got the pitch-black line, and
    /// never found the light. The cellar says where it is — once, because a
    /// player who ignores it is making a choice.
    @Test func theCellarSaysWhereTheLightIs() async throws {
        let dark = try await play(Fulminate(), ["south", "down", "z"])
        #expect(dark.contains("pitch black"))
        #expect(dark.contains("houses like this keep a light in it"))
        #expect(!turnOutput(of: "z", in: dark).contains("houses like this keep a light in it"))

        let lit = try await play(
            Fulminate(),
            ["south", "open drawer", "take flashlight", "turn on flashlight", "down"])
        #expect(!lit.contains("houses like this keep a light in it"))
    }

    // MARK: - Shock

    /// A building came down on the player, and the two turns after it should
    /// know that. The understatement is the voice; the force is the event.
    @Test func theBlastLeavesYouOnTheGrassForATurn() async throws {
        let fromYard = try await play(
            Fulminate(), ["south", "west"] + Array(repeating: "z", count: 9))
        expectInOrder(
            fromYard,
            [
                "The carriage house comes apart.",
                "the ground hits you in the back",
                "There is grass in your cuff",
                "the note in your ears steps down one",
            ])

        let fromHall = try await play(Fulminate(), Array(repeating: "z", count: 11))
        expectInOrder(
            fromHall,
            [
                "a long run of breakage",
                "The house holds still for a count of three.",
                "everybody who was in them is out on the grass",
                "the house hears it and holds still for it",
            ])
        #expect(!fromHall.contains("There is grass in your cuff"))
        // The ringing ear belongs to whoever was knocked flat, not to whoever
        // happens to be standing outside two turns later. Indoors at sixty feet
        // through two walls, nobody's ears are singing.
        #expect(!fromHall.contains("the note in your ears"))
    }

    /// The aftermath lands a turn after the blast, by which time the player
    /// may have walked somewhere else. What happened to *them* follows them —
    /// a man knocked flat in the yard still has grass in his cuff in the
    /// kitchen — but what is happening in the yard stays in the yard.
    @Test func theAftermathFollowsThePlayerRatherThanTheRoom() async throws {
        // Knocked down in the yard, then indoors before the beat lands.
        let outThenIn = try await play(
            Fulminate(), ["south", "west"] + Array(repeating: "z", count: 7) + ["east"])
        let indoorTurn = turnOutput(of: "east", in: outThenIn)
        #expect(indoorTurn.contains("There is grass in your cuff"))
        #expect(!indoorTurn.contains("Delphine Marsh is standing where she was standing"))

        // And a player who was indoors gets the indoor beat wherever in the
        // house they have got to by then.
        let indoors = try await play(
            Fulminate(), Array(repeating: "z", count: 9) + ["south"])
        let kitchenTurn = turnOutput(of: "south", in: indoors)
        #expect(kitchenTurn.contains("The house holds still for a count of three."))
        #expect(!kitchenTurn.contains("There is grass in your cuff"))

        // The case the fuse used to get wrong. Indoors when it went, out on the
        // lawn a turn later: the house is a thing you are now standing outside
        // of, and doors are not going above and below a man in a garden.
        let inThenOut = try await play(
            Fulminate(),
            ["south"] + Array(repeating: "z", count: 8) + ["west"])
        let lawnTurn = turnOutput(of: "west", in: inThenOut)
        #expect(!lawnTurn.contains("a door goes above you, and another one below"))
        #expect(!lawnTurn.contains("Dust comes along behind all of it"))
        #expect(lawnTurn.contains("the house is emptying itself into the garden"))
        // And he was not knocked down, so he is not getting up.
        #expect(!lawnTurn.contains("There is grass in your cuff"))
    }

    /// The wreckage lands in the yard at 5:46 and the yard starts describing it
    /// on the same turn. It used to stay in the room next door until 5:52, so
    /// for three turns the settling fuse named a thing that `X WRECKAGE`
    /// answered for with the line reserved for a noun that isn't there.
    @Test func theWreckageIsInTheYardTheMomentItLands() async throws {
        let transcript = try await play(
            Fulminate(), ["south", "west"] + Array(repeating: "z", count: 7) + ["x wreckage"])
        let answer = turnOutput(of: "x wreckage", in: transcript)
        #expect(answer.contains("Roof slates, black timber"))
        #expect(!answer.contains("can't see any such thing"))

        // And it is still his to guard once he is posted over it.
        let later = try await play(
            Fulminate(), ["south", "west"] + Array(repeating: "z", count: 11) + ["search wreckage"])
        #expect(turnOutput(of: "search wreckage", in: later).contains("Best keep back from there"))
    }

    /// She is not a woman with nothing to say about her son being dead; she is
    /// a woman who has said it once already. And before 5:46 the question
    /// means something else entirely — the row used to answer "My son is dead
    /// in the garden" from turn one, with Julian alive at his bench.
    @Test func constanceAndDelphineReactBeforeTheySettle() async throws {
        let early = try await play(Fulminate(), ["west", "ask mrs. vane about julian"])
        #expect(
            turnOutput(of: "ask mrs. vane about julian", in: early)
                .contains("Julian is in the shed."))

        // She reaches the yard step at the end of turn 10 and goes back in at
        // the end of turn 13.
        let after = try await play(
            Fulminate(),
            ["south", "west"] + Array(repeating: "z", count: 8)
                + ["ask mrs. vane about julian", "ask mrs. vane about her son"])
        expectInOrder(
            after,
            [
                "long enough that you consider asking it again",
                "That is all she has on the subject.",
            ])

        let delphine = try await play(
            Fulminate(),
            ["south", "west"] + Array(repeating: "z", count: 8)
                + ["ask delphine about julian", "ask delphine about julian"])
        expectInOrder(
            delphine,
            [
                "You came out on the wrong Tuesday.",
                "That was you, I take it.",
            ])
    }

    /// Her fallback used to read like the parser had failed. It is a decision
    /// now, and the player is shown her making it — and she has an answer to
    /// the obvious question about where she was standing.
    @Test func delphineDeclinesRatherThanFailing() async throws {
        let transcript = try await play(
            Fulminate(),
            [
                "south", "west",
                "ask delphine about the yard",
                "ask delphine about zeppelins",
                "ask delphine about the weather",
            ])
        #expect(
            turnOutput(of: "ask delphine about the yard", in: transcript)
                .contains("if you want it written down somewhere"))
        #expect(
            turnOutput(of: "ask delphine about zeppelins", in: transcript)
                .contains("lets you watch her decide not to answer it"))
        #expect(
            turnOutput(of: "ask delphine about the weather", in: transcript)
                .contains("She goes on looking at whatever she was looking at."))
    }

    /// The reported defect, in one transcript: the same question twice used to
    /// return the identical paragraph.
    @Test func nobodyGivesTheSameAnswerTwice() async throws {
        let transcript = try await play(
            Fulminate(),
            ["west", "ask pike about julian", "ask pike about julian", "hello pike", "hello pike"])
        expectInOrder(
            transcript,
            [
                "Capable stopped being a defence some years ago.",
                "\"I've given you that.\" Nothing in his face moves.",
                "He does not give you the hat, the hand, or the rest of the name.",
                "The hat comes down a degree, which is the whole of it.",
            ])
    }

    /// Mrs. Kettle is the exception, and deliberately: her answers are read
    /// out of the timetables rather than authored, so they go on answering
    /// however often they are asked. A table's repeat line retires prose, not
    /// behavior.
    @Test func mrsKettlesTestimonyIsAlwaysAvailable() async throws {
        // In the yard at 5:50, which is where she is and after the minute her
        // answer quotes.
        let transcript = try await play(
            Fulminate(),
            ["south", "west"] + Array(repeating: "z", count: 8)
                + ["ask kettle about pike", "ask kettle about pike"])
        #expect(
            occurrencesInFulminate(of: "The doctor sat in the parlour", in: transcript) == 2)
    }

    /// The four paragraphs the case turns on are the four a player is most
    /// likely to try twice, and `Conversation.shows` had no `again:` at all
    /// where `greeting` and `topic` both did — so all four recited word for
    /// word. The contract's one exception is Mrs. Kettle, who has no row here.
    @Test func theEvidenceDoesNotReciteItself() async throws {
        let transcript = try await play(
            Fulminate(),
            [
                "south", "open drawer", "take flashlight", "turn on flashlight", "down",
                "take glove", "up", "north", "west",
            ] + Array(repeating: "z", count: 4)
                + ["show glove to constance", "show glove to constance", "i"])
        #expect(
            occurrencesInFulminate(of: "trying to remember whether I put it back", in: transcript) == 1)
        #expect(transcript.contains("The glove is in her lap."))

        // And the line says she takes it, so she has it and you do not. That is
        // also what stops you handing her the same glove all evening.
        #expect(!turnOutput(of: "i", in: transcript).contains("scorched glove"))
    }

    /// Teague's 5:44 stop carried an *arrival* string whose content was a
    /// departure, and the 5:46 stop that takes him off the map carried nothing,
    /// so he was narrated out the front door and then listed in the hall on the
    /// next turn. Constance's 5:54 stop was the mirror image.
    @Test func everyCrossingIsNarratedByTheStopThatPerformsIt() async throws {
        let hall = try await play(Fulminate(), Array(repeating: "z", count: 7) + ["look", "time"])
        expectInOrder(
            hall,
            [
                "Teague comes through from the kitchen passage",
                "Your watch says 5:46 pm.",
                "the front door goes behind him",
            ])

        // The crossing a player can position themself to witness. She leaves
        // the parlour at 5:48 and comes back at 5:54, and both are said out
        // loud in the room the player is sitting in.
        let parlour = try await play(Fulminate(), ["west"] + Array(repeating: "z", count: 13))
        expectInOrder(
            parlour,
            [
                "puts both hands on the arms of her chair and gets up",
                "Mrs. Vane comes in from the passage, sits down",
            ])
    }

    /// Her presence rule always knew that six minutes of her evening are spent
    /// out of that chair. Her greeting, her alibi row and her fallback did not,
    /// and staged themselves at the parlour grate and the parlour wallpaper
    /// while she stood in the back garden watching the fire.
    @Test func mrsVaneSpeaksFromTheRoomSheIsStandingIn() async throws {
        let yard = try await play(
            Fulminate(),
            ["south", "west"] + Array(repeating: "z", count: 8)
                + ["greet mrs. vane", "ask mrs. vane about rockets", "ask mrs. vane about parlour"])
        #expect(turnOutput(of: "greet mrs. vane", in: yard).contains("goes on looking at the fire"))
        #expect(
            turnOutput(of: "ask mrs. vane about rockets", in: yard)
                .contains("looks past you at the end of the garden"))
        #expect(
            turnOutput(of: "ask mrs. vane about parlour", in: yard)
                .contains("She says it without turning round"))
        #expect(!yard.contains("looking at the grate"))
        #expect(!yard.contains("at the wallpaper"))

        // And in the parlour, where the grate and the wallpaper are, she goes
        // on saying what she always said.
        let parlour = try await play(
            Fulminate(), ["west", "greet mrs. vane", "ask mrs. vane about rockets"])
        #expect(turnOutput(of: "greet mrs. vane", in: parlour).contains("looking at the grate"))
        #expect(
            turnOutput(of: "ask mrs. vane about rockets", in: parlour).contains("at the wallpaper"))
    }

    // MARK: - Being described in the right place at the right time

    /// The reported defect, and the class the whole pass was about: she was
    /// described as the one person who had looked at the wreckage and gone back
    /// to work, nine turns before there was any wreckage to look at.
    @Test func nobodyIsDescribedByAnEveningTheyHaveNotHadYet() async throws {
        let early = try await play(Fulminate(), ["south", "x kettle"])
        let before = turnOutput(of: "x kettle", in: early)
        #expect(before.contains("longer than the son has had his shed"))
        #expect(!before.contains("wreckage"))

        // She is out in the yard with the rest of them from 5:48 to six.
        let late = try await play(
            Fulminate(), ["south", "west"] + Array(repeating: "z", count: 10) + ["x kettle"])
        #expect(turnOutput(of: "x kettle", in: late).contains("looked at the wreckage"))
    }

    /// Teague's was the one description in the household `7c92508` did not key
    /// on the blast, so the clause that makes him — the most helpful man in a
    /// house where somebody has died — printed from 5:38, six minutes before
    /// there was a death, with Dr. Pike alive in the Parlour. It also front-ran
    /// the 6:20 telephone, which is the game's own first word that Pike is
    /// gone. (#280 C2)
    @Test func teagueSaysNothingAboutADeathUntilThereHasBeenOne() async throws {
        // He comes down the back stairs at 5:36 and is examinable in the
        // kitchen at 5:38; he is off the map from 5:46 and back in the front
        // hall at 6:10.
        let transcript = try await play(
            Fulminate(),
            ["south", "z", "z", "z", "x teague", "north"]
                + Array(repeating: "z", count: 15) + ["x howard"])

        let early = turnOutput(of: "x teague", in: transcript)
        #expect(early.contains("the most helpful person in this house"))
        #expect(!early.contains("has just died"))

        let late = turnOutput(of: "x howard", in: transcript)
        #expect(late.contains("a house where a man has just died"))
    }

    /// And the refusal that guards his case put him in the house for the whole
    /// evening, including the twenty-four minutes he spends on the far side of
    /// the front door. Where he is comes off the same timetable that moved him.
    /// (#280 C4)
    @Test func theSuitcaseRefusalReadsItsOwnersTimetable() async throws {
        let transcript = try await play(
            Fulminate(),
            ["up", "east", "take suitcase"] + Array(repeating: "z", count: 7) + ["take case"])

        // 5:34, and he is two floors down being helpful.
        #expect(
            turnOutput(of: "take suitcase", in: transcript)
                .contains("belongs to a man who is somewhere in this house"))

        // 5:50, four minutes after the front door went behind him.
        let late = turnOutput(of: "take case", in: transcript)
        #expect(late.contains("a man who has stepped out and will want it when he gets back"))
        #expect(!late.contains("somewhere in this house"))
    }

    /// She spends six minutes of the evening out of her chair, and a woman
    /// standing in the back garden is not in her chair with the lamp unlit.
    @Test func mrsVaneIsDescribedByTheRoomSheIsStandingIn() async throws {
        // She reaches the step at the end of turn 10 and is back in the chair
        // at the end of turn 13, so the yard look is turn 11 and the parlour
        // look is turn 15.
        let transcript = try await play(
            Fulminate(),
            ["south", "west"] + Array(repeating: "z", count: 8)
                + ["l", "east", "north", "west", "look"])
        #expect(turnOutput(of: "l", in: transcript).contains("Mrs. Vane is on the step and no further"))
        #expect(turnOutput(of: "look", in: transcript).contains("in her chair with the lamp unlit"))
    }

    /// Hers said "not doing much" beside a burning building, and then the
    /// aftermath beat contradicted it in the same breath.
    @Test func delphinesPresenceLineKnowsAboutTheFire() async throws {
        let transcript = try await play(
            Fulminate(), ["south", "west", "look"] + Array(repeating: "z", count: 8) + ["look"])
        expectInOrder(
            transcript,
            [
                "Delphine Marsh is here, not doing much.",
                "Delphine Marsh did not go down when it went.",
                "Delphine Marsh is on her feet with her arms at her sides, looking at the fire.",
            ])
    }

    /// The same defect as Mrs. Vane's chair, caught a second time: keying her
    /// line on the blast alone had her watching the fire from the bottom of the
    /// coal cellar at 6:26. A presence line has to know the room as well as the
    /// hour.
    @Test func delphineStopsWatchingTheFireWhenSheLeavesIt() async throws {
        let transcript = try await play(
            Fulminate(),
            ["south", "open drawer", "take flashlight", "turn on flashlight"]
                + Array(repeating: "z", count: 26) + ["down", "look"])
        let cellar = turnOutput(of: "look", in: transcript)
        #expect(cellar.contains("Delphine Marsh"))
        #expect(!cellar.contains("looking at the fire"))
    }

    /// Both of the coat's refusals point the player at the pockets, so the
    /// pockets have to be a word — and FIND has to be a verb, because a player
    /// standing in a burned-out lab types it.
    @Test func thePocketsAndFindAreWordsTheGameKnows() async throws {
        let transcript = try await play(
            Fulminate(),
            Array(repeating: "z", count: 21) + ["x pockets", "search pockets", "find receipt"])
        #expect(!transcript.contains("I don't know the word"))
        #expect(turnOutput(of: "x pockets", in: transcript).contains("A grey overcoat"))
        #expect(
            turnOutput(of: "search pockets", in: transcript)
                .contains("a slip of register paper, folded once"))
    }

    /// Adding FIND put a new way to reach an old wrong answer: searching
    /// something with no inside used to deny the thing existed. In a house
    /// where the whole game is whether the narration tells the truth, FIND
    /// GRASS must not say the grass isn't there — and the suspects get a
    /// refusal that doesn't imply you frisked them.
    @Test func searchingTheSceneryAndTheSuspectsAnswersHonestly() async throws {
        let transcript = try await play(
            Fulminate(),
            ["south", "west", "find grass", "search wall", "search delphine", "find zeppelins"])
        #expect(
            turnOutput(of: "find grass", in: transcript)
                .contains("You find nothing of interest in the dry grass."))
        #expect(!turnOutput(of: "search wall", in: transcript).contains("can't see any such thing"))
        #expect(
            turnOutput(of: "search delphine", in: transcript)
                .contains("You are not putting a hand on Delphine Marsh tonight."))
        // And a word the game has never heard is still met with the truth.
        #expect(turnOutput(of: "find zeppelins", in: transcript).contains("I don't know the word"))
    }

    /// He keeps everybody out of it, which has to mean something. The lab is
    /// open for the three turns between the blast and the radio car, and the
    /// police own it after that — including a player who was standing in it.
    @Test func theWreckageIsSealedOnceThePatrolmanIsPosted() async throws {
        // In it at 5:52: he takes the name and walks you out.
        let cleared = try await play(
            Fulminate(), Array(repeating: "z", count: 9) + ["south", "west", "north", "look"])
        let arrival = turnOutput(of: "north", in: cleared)
        #expect(arrival.contains("walks you out of the wreckage"))
        #expect(arrival.contains("Back Yard"))
        #expect(turnOutput(of: "look", in: cleared).contains("A patrolman is posted at the wreckage"))

        // And afterwards the way in is shut, in his words rather than the
        // engine's.
        let refused = try await play(
            Fulminate(), Array(repeating: "z", count: 12) + ["south", "west", "north"])
        let blocked = turnOutput(of: "north", in: refused)
        #expect(blocked.contains("Nobody past me till the county man's been."))
        #expect(!blocked.contains("can't go that way"))
        #expect(!blocked.contains("The roof is in the yard."))
    }

    // MARK: - Gestures the speaker does not have where they are standing

    /// A topic reply prints wherever the actor happens to be, and these named
    /// the furniture of the room the actor is *usually* in. Mrs. Vane spends
    /// six minutes of the evening on the back step, and her chair does not go
    /// with her.
    @Test func mrsVanesGesturesLeaveTheChairInTheParlour() async throws {
        // She reaches the step at the end of turn 10 and is back in the chair
        // at the end of turn 13.
        let yard = try await play(
            Fulminate(),
            ["south", "west"] + Array(repeating: "z", count: 8) + ["ask mrs. vane about julian"])
        let onTheStep = turnOutput(of: "ask mrs. vane about julian", in: yard)
        #expect(onTheStep.contains("He is dead in the garden."))
        #expect(onTheStep.contains("Her hands close on each other and stay that way."))
        #expect(!onTheStep.contains("arms of the chair"))

        // And in the parlour, where the chair is, the gesture is the one it
        // always was.
        let parlour = try await play(
            Fulminate(),
            Array(repeating: "z", count: 13) + ["west", "ask mrs. vane about julian"])
        #expect(
            turnOutput(of: "ask mrs. vane about julian", in: parlour)
                .contains("Her hands go back to the arms of the chair and stay there."))
    }

    /// The confession has the same problem one row over, and it is reachable in
    /// the garden because `talk.shows` puts no room and no minute on the glove:
    /// a player who lights the cellar early can break her on the step, where
    /// "in this chair since" is false of the sentence and of the woman saying
    /// it. The unlit lamp beside it is the parlour's; the only lamp in the back
    /// garden is burning.
    @Test func theBrokenConfessionKnowsWhichRoomItIsToldIn() async throws {
        // The walk that breaks her on the back step: light the cellar, fetch
        // the glove, and be standing on the grass when she comes out at 5:48.
        let breakHerInTheGarden = [
            "south", "open drawer", "take flashlight", "turn on flashlight", "down",
            "take glove", "up", "west", "z", "z", "show glove to mrs. vane",
        ]

        let onTheStep = try await play(
            Fulminate(),
            breakHerInTheGarden + ["ask mrs. vane about evening", "ask mrs. vane about julian"])
        #expect(onTheStep.contains("I did not get out of it again until the noise."))
        #expect(onTheStep.contains("She looks at what is left of it."))
        #expect(!onTheStep.contains("I have been in this chair since"))
        #expect(!onTheStep.contains("the lamp she has not lit"))

        // The same two rows in the parlour, after she has gone back in at 5:54.
        let inTheChair = try await play(
            Fulminate(),
            breakHerInTheGarden
                + [
                    "east", "north", "west",
                    "ask mrs. vane about evening", "ask mrs. vane about julian",
                ])
        #expect(inTheChair.contains("I have been in this chair since."))
        #expect(inTheChair.contains("She looks at the lamp she has not lit."))
    }

    /// Delphine's presence line was taught to stop watching the fire when she
    /// leaves it. Two of her topic rows were written the same evening and were
    /// missed: one looks at wreckage she is two floors away from, and one says
    /// "out here" from indoors and from the bottom of a dark cellar.
    @Test func delphinesTopicRowsFollowHerIndoors() async throws {
        let cellar = try await play(
            Fulminate(),
            ["south", "open drawer", "take flashlight", "turn on flashlight"]
                + Array(repeating: "z", count: 26)
                + ["down", "ask delphine about yard", "ask delphine about julian"])
        #expect(cellar.contains("\"I was out in the yard.\""))
        #expect(cellar.contains("She stops looking at you."))
        #expect(!cellar.contains("\"I was out here.\""))
        #expect(!cellar.contains("She looks at the wreckage."))

        // In the garden, where the wreckage is and "here" means the yard, both
        // rows say what they always said.
        let yard = try await play(
            Fulminate(),
            ["south", "west"] + Array(repeating: "z", count: 8)
                + ["ask delphine about yard", "ask delphine about julian"])
        #expect(yard.contains("\"I was out here.\""))
        #expect(yard.contains("She looks at the wreckage."))
    }

    /// Mrs. Kettle is at the stove until 5:48 and out on the grass until six.
    /// Her Julian row stirred a pot from the garden, and the table's repeat line
    /// stirred it again — a `String` fixed where the rules are declared, which
    /// is why that one had to stop naming the pot rather than learn to read the
    /// room.
    @Test func mrsKettleStirsThePotOnlyWhereThePotIs() async throws {
        let kitchen = try await play(
            Fulminate(), ["south", "ask mrs. kettle about julian"])
        #expect(
            turnOutput(of: "ask mrs. kettle about julian", in: kitchen)
                .contains("The pot gets a stir it does not need."))

        let yard = try await play(
            Fulminate(),
            ["south"] + Array(repeating: "z", count: 8)
                + ["west", "ask mrs. kettle about julian", "ask mrs. kettle about julian"])
        let onTheGrass = turnOutput(of: "ask mrs. kettle about julian", in: yard)
        #expect(onTheGrass.contains("She dries her hands again on the same apron."))
        #expect(!onTheGrass.contains("The pot gets a stir"))

        // The repeat has to travel too, and a table-level `again:` cannot read
        // the room, so this row carries its own.
        #expect(yard.contains("\"He had his supper and he went out. That is the whole of it.\""))
        #expect(!yard.contains("The pot gets another stir."))
    }

    /// Teague does not sit down anywhere until half past six, and the alibi row
    /// that recrossed his legs is most often asked while he is standing in a
    /// kitchen. Rewritten rather than branched: a man can take his time over a
    /// sentence on his feet.
    @Test func teagueDoesNotSitDownToTellTheLie() async throws {
        let transcript = try await play(
            Fulminate(),
            ["south"] + Array(repeating: "z", count: 5)
                + ["ask kettle about teague"] + Array(repeating: "z", count: 13)
                + ["north", "ask teague about drugstore"])
        let lie = turnOutput(of: "ask teague about drugstore", in: transcript)
        #expect(lie.contains("I'd check her figures."))
        #expect(lie.contains("He takes his time over it."))
        #expect(!transcript.contains("He recrosses his legs."))
    }

    /// Showing Dr. Pike the ledger takes his hat off — and seven sentences went
    /// on saying it had never been off, one of them the `again:` of the very
    /// reply that removed it. The state to branch on was already in the file:
    /// the show sets `learning: .notebooksSold`, and the row two above the
    /// julian topic is already gated `unless:` it.
    ///
    /// The two `again:` lines are not gated, because `again:` is a `String?`
    /// and has nowhere to read state from. They are rewritten to a gesture the
    /// man has in both halves of the evening instead.
    @Test func theHatIsOffInEverySentenceThatNamesItAfterTheLedger() async throws {
        // He is in the study from 6:14; the ledger is in its desk from the
        // start. Show, then ask everything that has ever mentioned the hat.
        let shown = try await play(
            Fulminate(),
            ["up", "west", "take ledger"] + Array(repeating: "z", count: 20)
                + [
                    "show ledger to pike", "x pike", "x hat", "look",
                    "ask pike about julian", "ask pike about julian",
                    "show ledger to pike",
                ])

        #expect(turnOutput(of: "show ledger to pike", in: shown).contains("takes his hat off at last"))
        #expect(turnOutput(of: "x pike", in: shown).contains("with the hat in his hand"))
        #expect(turnOutput(of: "x hat", in: shown).contains("the band has gone dark where it sat"))
        #expect(turnOutput(of: "look", in: shown).contains("Dr. Pike is standing about with the hat in his hand."))
        #expect(turnOutput(of: "ask pike about julian", in: shown).contains("He turns the hat once by its brim"))

        // Nothing anywhere in that play may put it back on his head.
        #expect(!shown.contains("has not had the hat off"))
        #expect(!shown.contains("has not been off his head"))
        #expect(!shown.contains("with his hat on"))
        #expect(!shown.contains("The hat brim comes down a degree"))
        #expect(!shown.contains("The hat brim does not move"))
        #expect(!shown.contains("from under the brim"))
    }

    /// And before the ledger, every one of those sentences is the one it always
    /// was. The fix is a branch, not a deletion: a man who has not taken his hat
    /// off is the whole of Pike's characterisation until the moment he does.
    @Test func theHatIsStillOnUntilTheLedgerTakesItOff() async throws {
        let parlour = try await play(
            Fulminate(),
            [
                "west", "x pike", "x hat", "look",
                "ask pike about julian", "ask pike about julian",
                "ask pike about visit",
            ])

        #expect(turnOutput(of: "x pike", in: parlour).contains("he has not had the hat off since he came"))
        #expect(turnOutput(of: "x hat", in: parlour).contains("It has not been off his head since he came"))
        #expect(turnOutput(of: "look", in: parlour).contains("Dr. Pike is standing about with his hat on."))
        #expect(turnOutput(of: "ask pike about julian", in: parlour).contains("The hat brim comes down a degree"))
        #expect(turnOutput(of: "ask pike about visit", in: parlour).contains("He adjusts the hat he has not taken off"))
        #expect(!parlour.contains("the hat in his hand"))
    }

    /// Mrs. Kettle's own line about the doctor carried the claim too, and hers
    /// is reachable before the blast: the ledger starts in the study drawer and
    /// Pike is in the parlour from half past five, so a player can take it up,
    /// show it, and come down to a cook still saying he has never had it off.
    /// The `room(pikeDay, at:)` lookup is untouched — it proves the room and
    /// nothing else in the sentence.
    @Test func theCookDoesNotPutTheHatBackOn() async throws {
        let told = try await play(
            Fulminate(),
            ["up", "west", "take ledger", "east", "down", "west", "show ledger to pike"]
                + ["east", "south", "ask kettle about pike"])
        let row = turnOutput(of: "ask kettle about pike", in: told)
        #expect(row.contains("with his hat in his hand, which is new"))
        #expect(!row.contains("he has not had it off since he come"))

        // And before the ledger, she says what she always said.
        let early = try await play(Fulminate(), ["south", "ask kettle about pike"])
        #expect(
            turnOutput(of: "ask kettle about pike", in: early)
                .contains("with his hat on, and he has not had it off since he come"))
    }

    // MARK: - A deictic with no frame to read

    /// `X ME` prints in all ten rooms and said the player took statements "in
    /// this hall", which is true in exactly one of them and worst on the
    /// Upstairs Landing — the map table's "Upstairs hall" — where it reads as a
    /// positive claim that the 1948 statements were taken on that landing.
    ///
    /// The engine forecloses the branch the round's first repair suggested:
    /// `text.selfDescription` is a `Line<Nothing>`, whose body is
    /// `@Sendable (Object) -> String` with no turn frame, so it cannot read the
    /// player's room. The deictic goes instead, which fixes all ten rooms at
    /// once rather than the one.
    @Test func theSelfDescriptionNamesNoRoomItMightBeReadIn() async throws {
        let transcript = try await play(
            Fulminate(), ["x me", "up", "x me", "east", "x me", "down", "south", "x me"])
        #expect(transcript.contains("took statements in that front hall in 1948"))
        #expect(!transcript.contains("in this hall"))
    }

    // MARK: - The rooms a crossing passes through

    /// The kitchen narrates him leaving and the carriage house narrates him
    /// arriving, and the grass between them said nothing at all, twice. A
    /// player who follows him out of the kitchen stands in the one room on the
    /// route that did not know he went past.
    ///
    /// The third line rides on the two stops that already narrate the crossing,
    /// as a `perform:` closure saying `say(_:from: backYard)` — so it fires on
    /// the same turn its two neighbours do, prints in one room, and costs
    /// nothing on a turn nobody is standing there. A `backYard` stop of its own
    /// was the documented idiom and is wrong here on arithmetic: the clock
    /// samples even minutes only, so a yard stop has to take one off either
    /// leg, and `sawTeague` is anchored on the end of the second.
    @Test func theBackYardNarratesTheCrossingsItIsTheMiddleOf() async throws {
        let transcript = try await play(
            Fulminate(), ["south", "west"] + Array(repeating: "z", count: 6))
        expectInOrder(
            transcript,
            [
                "Teague comes past you across the grass with his hat on and does not stop.",
                "Teague comes back across the grass, not hurrying, and goes in past you.",
            ])

        // And the two ends still narrate their own halves, unchanged: the
        // crossing is now told three times over three rooms, not moved.
        let kitchen = try await play(
            Fulminate(), ["south"] + Array(repeating: "z", count: 7))
        expectInOrder(
            kitchen,
            [
                "Teague comes down the back stairs with his hat already on.",
                "Teague lets himself out the yard door.",
                "Teague comes back through the kitchen and says nothing to anybody.",
            ])
        #expect(!kitchen.contains("across the grass"))
    }

    /// A `Stop(departure:)` prints in exactly one room — the one being left,
    /// read off `actor.location` before the move — so the co-located frame is
    /// not one frame among several, it is the *only* frame the sentence will
    /// ever have. Both of these were written for a listener somewhere else.
    ///
    /// Teague's 5:36 narrated his own door and the stairs beyond it to a player
    /// standing in the room with him. The overheard version was never lost: it
    /// is the paired `arrival:`, which prints in the kitchen, which is where it
    /// was always true.
    @Test func aDepartureIsWrittenForTheOneRoomItCanPrintIn() async throws {
        // He leaves the boarder's room at the end of turn 3.
        let hisRoom = try await play(Fulminate(), ["up", "east", "z", "look"])
        #expect(hisRoom.contains("Teague puts his hat on and goes out to the back stairs."))
        #expect(!hisRoom.contains("Teague's door goes"))
        #expect(!hisRoom.contains("feet on the back stairs"))

        // And the kitchen, one floor down, still hears him arrive.
        let kitchen = try await play(Fulminate(), ["south", "z", "z", "z"])
        #expect(kitchen.contains("Teague comes down the back stairs with his hat already on."))
    }

    /// Delphine's 6:26 is the plainer of the two. Her 6:02 stop pins the
    /// printing room to Vane's Study for the rest of the evening, so this
    /// sentence can only ever print upstairs, in a room whose description names
    /// a desk, drawers and a lamp and no stair — and it named the fixture
    /// "cellar stairs", which is not what this game calls it anywhere else. The
    /// arrival line keeps the steps, because the cellar has them.
    @Test func sheGoesOutAndDownFromARoomWithNoStairInIt() async throws {
        // She leaves the study at the end of turn 28.
        let study = try await play(
            Fulminate(), ["up", "west"] + Array(repeating: "z", count: 26) + ["look"])
        #expect(study.contains("Delphine goes out and down, and does not take a light."))
        #expect(!study.contains("takes the cellar stairs down"))
    }

    // MARK: - Nouns the prose prints and the parser has to know

    /// The rule is CLAUDE.md's, unqualified: every noun the prose prints must be
    /// answerable. These walks type each room's own words back at it, upstairs
    /// and out back, where no previous walk went. The two the round named are
    /// here — `papers`, which the study desk's arrangement clue depends on, and
    /// `chain`, which `9caa400` introduced while closing an unanswerable-noun
    /// defect on the very same object.
    @Test func theUpstairsRoomsAnswerToEveryNounTheyPrint() async throws {
        let transcript = try await play(
            Fulminate(),
            [
                "up", "west", "x desk", "x papers", "x paper", "x drawers", "x lamp", "x shade",
                "east", "east", "x light", "x chain", "x cord", "x bulb", "x shade", "x strap",
            ])
        expectEveryNounAnswered(transcript)
        #expect(turnOutput(of: "x papers", in: transcript).contains("square to the fronts"))
        #expect(turnOutput(of: "x paper", in: transcript).contains("square to the fronts"))
        #expect(turnOutput(of: "x chain", in: transcript).contains("wiped where a hand goes"))
    }

    /// The yard rewrites itself at a quarter to six and prints four nouns it
    /// then denied: the scorch the grass describes, the path worn across it,
    /// the mortar the wall is losing to the ivy, and the sky the lab is open to.
    @Test func theYardAnswersToWhatTheBlastLeftInIt() async throws {
        let after = try await play(
            Fulminate(),
            ["south", "west"] + Array(repeating: "z", count: 7)
                + ["x grass", "x half-circle", "x wall", "x mortar", "search wreckage", "x soot"])
        expectEveryNounAnswered(after)

        // The shell is only enterable in the six minutes between the blast and
        // the patrolman posting himself at the gap.
        let shell = try await play(
            Fulminate(),
            ["south", "west"] + Array(repeating: "z", count: 7) + ["north", "x shell", "x sky"])
        expectEveryNounAnswered(shell)

        // And before it, the same grass names the path and answers for it.
        let before = try await play(Fulminate(), ["south", "west", "x grass", "x path"])
        expectEveryNounAnswered(before)
        #expect(turnOutput(of: "x path", in: before).contains("from the kitchen door to the carriage house"))
    }

    /// The aftermath declares dust settled on every flat top in the house, and
    /// the word answered in exactly one room — the cellar, where it is a coal
    /// bin synonym and has nothing to do with the blast. It is a real thing now,
    /// and it arrives in the room the sentence is read in.
    @Test func theDustTheBlastBringsDownIsAThingYouCanLookAt() async throws {
        let hall = try await play(Fulminate(), Array(repeating: "z", count: 11) + ["x dust"])
        #expect(hall.contains("settles on everything with a flat top"))
        #expect(turnOutput(of: "x dust", in: hall).contains("eighty years of ceiling"))

        // And it is on every flat top in the *house*, which is what the
        // paragraph claims, so it is still there one room over.
        let parlour = try await play(
            Fulminate(), Array(repeating: "z", count: 11) + ["west", "x dust"])
        #expect(turnOutput(of: "x dust", in: parlour).contains("eighty years of ceiling"))

        // Before the blast there is no such thing to look at, and the word
        // still belongs to the coal bin downstairs.
        let early = try await play(Fulminate(), ["x dust"])
        #expect(!turnOutput(of: "x dust", in: early).contains("eighty years of ceiling"))
    }

    /// Delphine's 6:26 arrival names the cellar steps in the cellar, and the
    /// steps were declared in the kitchen — so the word left scope at the exact
    /// moment the prose used it. A staircase is a thing in both rooms it joins.
    @Test func theCellarStepsAnswerFromTheBottomAsWellAsTheTop() async throws {
        let transcript = try await play(
            Fulminate(),
            [
                "south", "x cellar steps", "open drawer", "take flashlight", "turn on flashlight",
                "down", "x cellar steps", "x stairs",
            ])
        expectEveryNounAnswered(transcript)
        #expect(turnOutput(of: "x stairs", in: transcript).contains("Eight of them"))
    }

    /// A word that travels with a person goes `heldBy` them — the design doc's
    /// rule, written for Dr. Pike's hat and never applied to the jacket Teague's
    /// own description dresses him in, or the apron Mrs. Kettle dries her hands
    /// on twice. The glove's lining and Julian's clamp and file are the same
    /// defect on things that do not move.
    @Test func thePeopleAnswerForTheClothesTheirOwnProseGivesThem() async throws {
        // She is at her stove all evening; he is in his own room until 5:36 and
        // then on the move for the rest of it, so the sleeve is asked for where
        // he starts.
        let kitchen = try await play(Fulminate(), ["south", "x kettle", "x apron"])
        expectEveryNounAnswered(kitchen)
        #expect(turnOutput(of: "x apron", in: kitchen).contains("damp across the front"))

        let boarder = try await play(Fulminate(), ["up", "east", "x teague", "x sleeve"])
        expectEveryNounAnswered(boarder)
        #expect(turnOutput(of: "x sleeve", in: boarder).contains("There is nothing on the sleeve"))

        let lab = try await play(
            Fulminate(), ["south", "west", "north", "x julian", "x bench", "x clamp", "x file"])
        expectEveryNounAnswered(lab)

        let cellar = try await play(
            Fulminate(),
            [
                "south", "open drawer", "take flashlight", "turn on flashlight", "down",
                "x glove", "x lining",
            ])
        expectEveryNounAnswered(cellar)
    }

    // MARK: - Two channels for two facts

    /// The placement clause is the clue — somebody hid the glove rather than
    /// dropping it — and it was the last sentence of a static `description`, so
    /// it was invisible to a player who took the glove before examining it and
    /// false for one who examined it after. `firstSight` is where it was found;
    /// `description` is what it is.
    @Test func theGloveStopsClaimingTheCoalBinOnceYouAreHoldingIt() async throws {
        let transcript = try await play(
            Fulminate(),
            [
                "south", "open drawer", "take flashlight", "turn on flashlight", "down",
                "look", "x glove", "take glove", "x glove", "i",
            ])
        // The listing paragraph carries the clue, in place of the stock line,
        // and every player who lights the cellar reads it.
        let listed = turnOutput(of: "look", in: transcript)
        #expect(listed.contains("A scorched glove has been pushed in behind the coal bin"))
        #expect(!listed.contains("There is a scorched glove here"))

        // And examining it names the glove rather than the bin, before and
        // after it changes hands.
        #expect(!turnOutput(of: "x glove", in: transcript).contains("coal bin"))
        #expect(turnOutput(of: "x glove", in: transcript).contains("fingertips burned back to the lining"))
        #expect(turnOutput(of: "i", in: transcript).contains("scorched glove"))
    }

    // MARK: - A noun the room prints and can answer

    /// Teague's half past six arrival says he "does not put the light on", and
    /// the room declared no lamp. The word either failed outright or bound the
    /// flashlight in the player's own pocket, and the second answer is the
    /// worse of the two: it replies as though the room had one.
    @Test func theBoardersRoomHasTheLightItsOwnProseNames() async throws {
        let transcript = try await play(
            Fulminate(), ["up", "east", "x light", "turn on light", "x bulb"])
        let examined = turnOutput(of: "x light", in: transcript)
        #expect(examined.contains("A bulb on a cord with a pull chain"))
        #expect(!examined.contains("can't see any such thing"))
        #expect(!examined.contains("dented tin flashlight"))

        // The same line advertises the verb, so the room answers it in its own
        // voice rather than with the engine's flat refusal.
        let switched = turnOutput(of: "turn on light", in: transcript)
        #expect(switched.contains("You leave Mr. Teague's light alone."))
        #expect(!switched.contains("You can't turn that on."))

        // And it is still there to be named when the line that names it prints.
        let evening = try await play(
            Fulminate(), ["up", "east"] + Array(repeating: "z", count: 29) + ["x light"])
        #expect(evening.contains("does not put the light on"))
        #expect(turnOutput(of: "x light", in: evening).contains("pull chain"))
    }

    // MARK: - Following, and saying hello

    /// The engine's FOLLOW searches one exit deep, which is honest and safe;
    /// Teague's crossing is two, so the game buys that one pursuit itself.
    @Test func followingTeagueOutOfTheKitchen() async throws {
        // He lets himself out the yard door at the end of turn 5 and is in the
        // carriage house until 5:42.
        let transcript = try await play(
            Fulminate(), ["south", "z", "z", "z", "z", "follow teague"])
        let followed = turnOutput(of: "follow teague", in: transcript)
        #expect(followed.contains("(after Teague, out through the yard door)"))
        #expect(followed.contains("Back Yard"))

        // And the stock refusals wear proper names rather than "the".
        let refused = try await play(Fulminate(), ["follow clock", "follow kettle"])
        #expect(turnOutput(of: "follow clock", in: refused).contains("isn't going anywhere"))
        #expect(
            turnOutput(of: "follow kettle", in: refused).contains("(after Mrs. Kettle)"))
    }

    /// Three of this cast answer to "man" and three to "woman". FOLLOW can
    /// name somebody who has left the room, so the danger is that `follow man`
    /// on turn one reads the whole cast list out of an empty hall.
    @Test func followingAnAmbiguousNameNeverReadsOutTheCast() async throws {
        let transcript = try await play(Fulminate(), ["follow man", "follow woman"])
        #expect(!transcript.contains("Which do you mean"))
        #expect(!transcript.contains("Dr. Pike"))
        #expect(!transcript.contains("Delphine Marsh"))
        #expect(turnOutput(of: "follow man", in: transcript).contains("can't see any such thing"))
    }

    /// Four ways of opening with somebody, all reaching the one line she has.
    @Test(arguments: [
        "talk to delphine", "greet delphine", "hello delphine", "delphine, hello",
    ])
    func everyWayOfSayingHelloReachesHer(_ command: String) async throws {
        let transcript = try await play(Fulminate(), ["south", "west", command])
        #expect(turnOutput(of: command, in: transcript).contains("You'd be the letter"))
    }

    /// And an order is heard and declined, rather than carried out by the
    /// player under somebody else's name.
    @Test func nobodyInThisHouseTakesOrders() async throws {
        let transcript = try await play(
            Fulminate(), ["south", "west", "delphine, take the glove"])
        #expect(
            turnOutput(of: "delphine, take the glove", in: transcript)
                .contains("hears you out and goes on doing exactly what"))
    }

    // MARK: - The acts the prose offers

    /// Every stock refusal the engine has for an act this game's own prose
    /// invites. A room that describes a switch and then answers "You can't turn
    /// that on." is denying what it just offered, and the principle was already
    /// written in the file — above `ceilingLight.before(.turnOn, .turnOff)` —
    /// against a game that broke it in fourteen places. (#334)
    ///
    /// The lines rather than their words: `expectNoStockRefusal` renders each
    /// one, so rewording the engine cannot quietly turn this guard green.
    static let engineRefusals: [any StockLine] = {
        let text = GameText()
        return [
            text.cantTurnOnThat, text.cantTurnOffThat, text.cantOpenThat, text.cantCloseThat,
            text.cantMoveThat, text.cantWear, text.cantEnterThat, text.nothingToSearch,
            text.stubs.pull,
        ]
    }()

    /// The longcase clock is the one noun in the house that is making a sound
    /// you could take down, and the game's own re-voiced LISTEN line said it was
    /// not. Not the engine's voice, but the same sentence-denies-its-own-prose
    /// shape, and one line to fix.
    @Test func theHallClockIsHeardSayingWhatItsDescriptionClaims() async throws {
        let transcript = try await play(Fulminate(), ["listen to clock"])
        expectNoStockRefusal(transcript, Self.engineRefusals, "Front Hall.")
        #expect(transcript.contains("time a statement by it"))
    }

    /// A lit range, a pot filled for a count that is the evidence, and a door
    /// described entirely by the worn place where people push it open.
    @Test func theKitchenAnswersTheActsItsProseOffers() async throws {
        let transcript = try await play(
            Fulminate(),
            [
                "south", "turn off stove", "open stove", "search pot", "open yard door",
                "close yard door", "push door", "enter yard door",
            ])
        expectNoStockRefusal(transcript, Self.engineRefusals, "Kitchen.")
        #expect(turnOutput(of: "turn off stove", in: transcript).contains("damps down a cook's fire"))
        #expect(turnOutput(of: "search pot", in: transcript).contains("the arithmetic"))
        #expect(turnOutput(of: "open yard door", in: transcript).contains("worn place at knee height"))

        // ENTER on the yard door is the one act on this list that works: a door
        // whose whole description is people going through it should go through.
        #expect(turnOutput(of: "enter yard door", in: transcript).contains("Back Yard"))
    }

    /// The coal bin two separate sentences say something went in behind, and
    /// the glove whose entire clue is whose hand it fits.
    @Test func theCellarAnswersTheActsItsProseOffers() async throws {
        let transcript = try await play(
            Fulminate(),
            [
                "south", "open drawer", "take flashlight", "turn on flashlight", "down",
                "push bin", "wear glove", "take glove", "wear it",
            ])
        expectNoStockRefusal(transcript, Self.engineRefusals, "Cellar.")
        #expect(turnOutput(of: "push bin", in: transcript).contains("on the floor behind it"))
        #expect(turnOutput(of: "wear it", in: transcript).contains("cut for a smaller hand than yours"))

        // A `before` rule pre-empts stage 4, so the refusal had quietly taken
        // over the engine's `notHolding` guard and put two fingers into a glove
        // still lying on the floor.
        #expect(!turnOutput(of: "wear glove", in: transcript).contains("two fingers"))
    }

    /// Three lamps, three rooms, and the same defect on each: a description that
    /// asserts a switch state and then draws a deduction from it, over an engine
    /// that says the switch isn't there. None of the three becomes a device —
    /// the study's is evidence of how the room was searched, the parlour's is
    /// Mrs. Vane's to decide, and the comment above the boarder's room's says
    /// why a switchable bulb would put Teague's arrival line in the wrong.
    @Test func everyLampInTheHouseRefusesInTheHousesVoice() async throws {
        let parlour = try await play(Fulminate(), ["west", "turn on lamp"])
        expectNoStockRefusal(parlour, Self.engineRefusals, "Parlour.")
        #expect(turnOutput(of: "turn on lamp", in: parlour).contains("belongs to Mrs. Vane"))

        let study = try await play(Fulminate(), ["up", "west", "turn on lamp"])
        expectNoStockRefusal(study, Self.engineRefusals, "Vane's Study.")
        #expect(turnOutput(of: "turn on lamp", in: study).contains("leave the switch where you found it"))

        // PULL was the filed site: the description hands the player a chain and
        // the stub floor answered that the light doesn't budge.
        let boarders = try await play(Fulminate(), ["up", "east", "pull chain", "turn on light"])
        expectNoStockRefusal(boarders, Self.engineRefusals, "Boarder's Room.")
        #expect(turnOutput(of: "pull chain", in: boarders).contains("leave Mr. Teague's light alone"))
    }

    /// The yard's two lamps and its fire, on both sides of the blast. The lab
    /// lamp is only an invitation while it is burning, so the sentence has to
    /// change when the wall it was screwed to does.
    @Test func theYardsLightsAndItsFireAnswerForTheirOwnFrame() async throws {
        let before = try await play(
            Fulminate(), ["south", "west", "turn off yard lamp", "north", "open can"])
        expectNoStockRefusal(before, Self.engineRefusals, "Back Yard and lab, before.")
        #expect(turnOutput(of: "turn off yard lamp", in: before).contains("reach past him to save a bulb"))

        // The can is the coroner's answer sitting sealed on a bench, and OPEN is
        // the move its last sentence asks for. It refuses in the same voice the
        // existing TAKE refusal uses, and for the same reason.
        #expect(turnOutput(of: "open can", in: before).contains("Ask him about it at six"))

        let after = try await play(
            Fulminate(),
            ["south", "west"] + Array(repeating: "z", count: 7)
                + ["turn off yard lamp", "extinguish fire"])
        expectNoStockRefusal(after, Self.engineRefusals, "Back Yard, after.")
        #expect(turnOutput(of: "turn off yard lamp", in: after).contains("stopped being a wall"))
        #expect(turnOutput(of: "extinguish fire", in: after).contains("goes out when it has finished"))
    }

    /// `north` walks into the lab until the patrolman closes it, so ENTER
    /// refusing in the engine's voice had the map and the parser disagreeing
    /// about one doorway — forbidding while the way was open, and permissive in
    /// a different set of words once it was shut. Both nouns for the building
    /// take the exit now, and both refuse in the patrolman's own words.
    ///
    /// MOVE rides the same two voices: the wreckage's own answer to SEARCH
    /// advertises turning it over, and the engine answered "You can't move
    /// that." to the exact act it describes.
    @Test func theBuildingIsAWayInByNameForExactlyAsLongAsTheMapSaysItIs() async throws {
        let before = try await play(Fulminate(), ["south", "west", "enter carriage house"])
        expectNoStockRefusal(before, Self.engineRefusals, "Back Yard, before the blast.")
        #expect(before.contains("Somebody's workshop and somebody else's chapel."))

        // The three turns between the blast and the radio car, entered by the
        // word the blast itself put in the yard.
        let open = try await play(
            Fulminate(),
            ["south", "west"] + Array(repeating: "z", count: 8) + ["move wreckage", "enter wreckage"])
        expectNoStockRefusal(open, Self.engineRefusals, "Back Yard, lab open.")
        #expect(turnOutput(of: "move wreckage", in: open).contains("soot to the elbow"))
        #expect(turnOutput(of: "enter wreckage", in: open).contains("The roof is in the yard."))

        // And once he is posted, every spelling refuses in the words `north`
        // already uses, rather than in three different voices.
        let sealed = try await play(
            Fulminate(),
            ["south", "west"] + Array(repeating: "z", count: 10)
                + ["move wreckage", "enter wreckage", "enter carriage house", "north"])
        expectNoStockRefusal(sealed, Self.engineRefusals, "Back Yard, sealed.")
        #expect(turnOutput(of: "move wreckage", in: sealed).contains("Best keep back from there"))
        #expect(occurrences(of: "Nobody past me till the county man's been.", in: sealed) == 3)
    }

    // MARK: - The stub floor

    /// The scope question the 2026-08-26 round asked and no rater answered:
    /// which of the engine's stubs does this game mean to voice? The design doc
    /// carries the rule — **the verbs a body in a room has** — and this pins the
    /// set it produces, in both directions.
    ///
    /// Fulminate does not claim the whole floor the way Zork 1 and Dungeon do,
    /// so `expectNoEngineStubLineSurvives` is the wrong assertion for it: `dig`
    /// wants a hole and `xyzzy` wants a magic word, and a house-voiced refusal
    /// of a mechanic implies the mechanic exists — which is the invited-act
    /// defect above, running backwards. Naming the set instead means a stub
    /// re-voiced without the doc rule fails here, and so does a stub the engine
    /// adds tomorrow, until somebody adjudicates it.
    static let voicedStubs: Set<String> = [
        "listen", "smell", "touch", "climb", "stand", "sit", "somebodyElse",
        "sing", "jump", "sleep", "swim", "yell", "wave",
    ]

    @Test func theStubFloorCoversTheVerbsABodyInARoomHas() throws {
        let stubs = Fulminate().text.stubs
        let everyLine = Set(Mirror(reflecting: stubs).children.compactMap(\.label))
        let engineVoiced = Set(engineVoicedStubLines(in: stubs))
        #expect(everyLine.subtracting(engineVoiced) == Self.voicedStubs)
    }

    /// And the six new ones actually reach the player, in a room that holds
    /// none of the things they might otherwise have bound to.
    @Test func theSixBodyVerbsAnswerInTheHousesVoice() async throws {
        let transcript = try await play(
            Fulminate(), ["sing", "jump", "sleep", "swim", "yell", "wave"])
        expectInOrder(
            transcript,
            [
                "singing for the drive home",
                "jumping on the spot",
                "sleep for a week",
                "one suit with you",
                "arranging their story",
                "hands where people can see them",
            ])
    }
}

/// How many times `needle` appears in `haystack` — the suite has
/// `expectInOrder` for sequence, but "exactly twice" needs a count.
private func occurrencesInFulminate(of needle: String, in haystack: String) -> Int {
    haystack.components(separatedBy: needle).count - 1
}
