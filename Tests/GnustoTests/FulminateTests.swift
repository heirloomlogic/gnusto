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
        #expect(!transcript.contains("I don't know the word"))
        #expect(!transcript.contains("can't see any such thing"))
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
        #expect(!upstairs.contains("I don't know the word"))
        #expect(!upstairs.contains("can't see any such thing"))

        let lab = try await play(
            Fulminate(),
            ["south", "west", "north", "x bench", "x tool rack", "x cot", "x stove pipe"])
        #expect(!lab.contains("I don't know the word"))
        #expect(!lab.contains("can't see any such thing"))

        // And the cellar's coal bin, which the glove's own description names.
        let cellar = try await play(
            Fulminate(),
            ["south", "open drawer", "take flashlight", "turn on flashlight", "down", "x coal bin"])
        #expect(turnOutput(of: "x coal bin", in: cellar).contains("three winters of coal dust"))
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
                "one long run of breakage",
                "The house holds still for a count of three.",
                "the note in your ears steps down one",
            ])
        #expect(!fromHall.contains("There is grass in your cuff"))
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
                "\"I've given you that.\" The hat brim does not move.",
                "He does not give you the hat, the hand, or the rest of the name.",
                "The hat comes down a degree, which is the whole of it.",
            ])
    }

    /// Mrs. Kettle is the exception, and deliberately: her answers are read
    /// out of the timetables rather than authored, so they go on answering
    /// however often they are asked. A table's repeat line retires prose, not
    /// behavior.
    @Test func mrsKettlesTestimonyIsAlwaysAvailable() async throws {
        let transcript = try await play(
            Fulminate(),
            ["south", "ask kettle about pike", "ask kettle about pike"])
        #expect(
            occurrencesInFulminate(of: "The doctor sat in the parlour", in: transcript) == 2)
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
}

/// How many times `needle` appears in `haystack` — the suite has
/// `expectInOrder` for sequence, but "exactly twice" needs a count.
private func occurrencesInFulminate(of needle: String, in haystack: String) -> Int {
    haystack.components(separatedBy: needle).count - 1
}
