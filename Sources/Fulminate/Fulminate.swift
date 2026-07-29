import Gnusto
import GnustoClock
import GnustoConversation

extension Intent {
    /// Put a name in the record: `accuse mrs. vane`. There is no taking it
    /// back — an accusation you can take back costs nothing, and a clock you
    /// can outlast is scenery.
    #verb("accuse", ["accuse", .directObject])
}

/// What the player has worked out, in the order the case wants it worked out:
/// the cook's testimony kills the alibi, the receipt breaks the boarder, the
/// boarder gives up the lie he told the mother, and the glove breaks her.
/// The ledger and the letters retire the two lurid explanations on the way.
extension Fact {
    /// Mrs. Kettle saw Teague come through her kitchen — the drugstore alibi
    /// is dead.
    static let kettleSawTeague = Fact("kettleSawTeague")
    /// The receipt is stamped 6:05: he went to the drugstore *after*, to buy
    /// the alibi, and he has admitted it.
    static let teagueRecanted = Fact("teagueRecanted")
    /// The keystone: Teague told Constance her son had gone out. Knowing this
    /// is what separates the full ending from the partial one.
    static let teagueLied = Fact("teagueLied")
    /// The ledger's last four pages: notebooks were going up the arroyo a few
    /// pages at a time.
    static let notebooksSold = Fact("notebooksSold")
    /// The glove has been shown to Constance, and she has stopped trying.
    static let constanceBroke = Fact("constanceBroke")
    /// The letters have been read in front of Delphine; the red herring dies.
    static let delphineCleared = Fact("delphineCleared")
}

/// A one-evening mystery on a wall clock: a rocketry man dies in his own
/// carriage house at 5:46, the county coroner is due at 6:50, and what he
/// writes down is what happened.
///
/// This is the demo game for the engine's mystery-genre work (issue #40). It
/// proves the parts an exploration adventure never needed — a time-of-day
/// clock, NPCs who keep a timetable, and conversation about abstract subjects
/// — by making each of them load-bearing rather than decorative. The story
/// and its mechanics contract live in `docs/games/fulminate.md`; read that
/// before rewriting any of the prose here, since several beats are carrying a
/// tested engine behavior.
///
/// The evening is complete: the house, the clock, five suspects on their
/// rounds, the interrogation, the evidence chain, and an accusation that ends
/// the game one of three ways.
///
/// Original: Julian Vane is fictional. The setting borrows the shape of a real
/// 1952 Pasadena explosion; the crime, the household, and every person in it
/// are invented, and no accusation here is made of anyone who lived. Every
/// character is a type of the period, never a portrait of a person.
@main
struct Fulminate: Game, GameMain {
    let title = "Fulminate"
    let tagline = "Pasadena, June 1952."
    let intro = """
        The letter said somebody had been in his lab and nothing had been taken, and that the second part was what \
        worried him. It was signed with a fountain pen that had been going dry.

        The streetcar puts you on Orange Grove at half past five. Millionaire's Row, they used to call it, back when \
        the money was still here. The house is the fourth one down, and it was somebody's idea of a palace once.

        Mrs. Vane lets you in without asking who you are, which tells you something about the number of people who \
        come to this door.
        """

    /// Two minutes a turn, from half past five. Every alibi in this house is
    /// stated as a time, so the clock is not scenery — it is the instrument
    /// the case is measured with.
    let clock = Clock(
        startingAt: TimeOfDay(17, 30),
        minutesPerTurn: 2,
        timeIs: { "Your watch says \($0)." }
    )

    /// The interrogation layer. Its defaults prefix names with "The", which
    /// suits a butler and not a household of proper names.
    let talk = Conversation(
        nothingToSay: { "\($0) has nothing to say about that." },
        noInterest: { "\($0) looks at it and looks away." }
    )

    /// Whether the carriage house has gone up. Rooms and props read this to
    /// describe themselves on the right side of the evening.
    @Global var blastHappened = false

    /// Whether Teague is back from the drugstore. The receipt is in his coat
    /// pocket only after he has been out and bought the thing — searching the
    /// coat before ten past six turns up an empty pocket, which is the honest
    /// answer and also the more interesting one.
    @Global var teagueIsBack = false

    /// Both ways out of the front hall refuse in the same words. A `static`
    /// rather than a stored property so the bootstrap's reflection walk, which
    /// looks for entities, doesn't have to step over it.
    private static let streetRefusal = """
        You came out here on a Tuesday because a man wrote you a letter. Walking back down the path now would make \
        that the last thing you ever did for him.
        """

    // MARK: - Rooms

    let frontHall = Location {
        name("Front Hall")
        description(
            """
            Black and white tile, worn through to the grout along the line people walk. A hat stand with one coat on \
            it, a half-moon table with the telephone, and a longcase clock in the corner that keeps better time than \
            the household does. The front door is east, the parlour west, the kitchen passage south, and the stairs \
            go up.
            """)
    }

    let parlour = Location {
        name("Parlour")
        description(
            """
            Furniture too big for the room and too good to sell, arranged around a cold grate. The lamp is not lit. \
            Mrs. Vane does not light it until it is properly dark, and her opinion of when that is differs from \
            everyone else's.
            """)
    }

    let kitchen = Location {
        name("Kitchen")
        description(
            """
            Scrubbed pine and a stove that has been going since before you got here. The back stairs come down along \
            the far wall, which means anyone who uses them comes through here, whether they meant to or not. The yard \
            door is west and the cellar steps go down.
            """)
    }

    /// Unlit on purpose. It is where the case's least convenient piece of
    /// evidence ends up, and it is the room that proves an NPC crossing a dark
    /// room does it in silence.
    let cellar = Location {
        name("Cellar")
        description("Cold, and low enough that you walk it at a stoop. It smells like a cellar.")
        dark
    }

    let backYard = Location {
        name("Back Yard")
    }

    let carriageHouse = Location {
        name("Carriage House")
    }

    let landing = Location {
        name("Upstairs Landing")
        description("A runner going bald down the middle. The study is west, the boarder's room east.")
    }

    let study = Location {
        name("Vane's Study")
        description(
            """
            A desk with a green shade over the lamp, and every drawer standing open. Not ransacked. Searched by \
            somebody who fully intended to put it all back.
            """)
    }

    let boardersRoom = Location {
        name("Boarder's Room")
        description(
            """
            A typewriter with a sheet still in it, and a suitcase on the bed packed for a longer trip than anybody \
            has mentioned.
            """)
    }

    /// Off the map: no exit leads here and the player never sees it. It is
    /// where Teague is between a quarter to six and ten past, which is the
    /// point — there are questions you can only put to him inside a window.
    let street = Location {
        name("Orange Grove Avenue")
        description("Not a place you get to tonight.")
    }

    // MARK: - The hall

    /// The house's timepiece. The player has a watch, but the clock is what
    /// everyone in this house means when they say a time — so it is the thing
    /// to examine when an account needs checking.
    let hallClock = Item {
        name("longcase clock")
        adjectives("longcase", "hall", "grandfather", "tall")
        synonyms("clock", "case")
        scenery
    }

    let telephone = Item {
        name("telephone")
        adjectives("black")
        synonyms("phone", "receiver")
        description("A black telephone on a half-moon table, with a pad beside it and nothing written on the pad.")
        scenery
    }

    let coat = Item {
        name("overcoat")
        adjectives("grey", "gray")
        synonyms("coat", "overcoat")
        description(
            """
            A grey overcoat on the hat stand, good once and not lately. It is nobody's idea of June wear, which is \
            presumably why it is still hanging here.
            """)
        container
    }

    /// Time-stamped 6:05. In this slice it is only a slip of paper; it becomes
    /// the case's hinge once there is somebody to put it in front of. Hidden
    /// until the coat is searched — a receipt you are handed on arrival is not
    /// evidence, it is a signpost.
    let receipt = Item {
        name("drugstore receipt")
        adjectives("drugstore", "paper", "small")
        synonyms("receipt", "slip", "ticket")
        description(
            """
            A register slip from the drugstore on Colorado. One Coca-Cola, five cents, and the time printed along \
            the bottom in that smeared purple ink they all use: 6:05.
            """)
        hidden
    }

    // MARK: - The kitchen and the cellar

    let stove = Item {
        name("stove")
        adjectives("iron", "black")
        synonyms("stove", "range")
        description("Cast iron, lit, and putting out more heat than the evening asked for.")
        scenery
    }

    let drawer = Item {
        name("kitchen drawer")
        adjectives("kitchen", "counter")
        synonyms("drawer")
        description("The drawer under the counter, where a house keeps the things it needs twice a year.")
        scenery
        container
        openable
    }

    let flashlight = Item {
        name("flashlight")
        adjectives("dented", "tin")
        synonyms("flashlight", "torch", "lamp", "light")
        description("A dented tin flashlight. Shake it and it rattles, but it lights.")
        lightSource
    }

    /// A workman's glove with the fingers burned, in a cellar nobody has any
    /// business in. The evidence the case turns on, and the reason the
    /// flashlight exists.
    let glove = Item {
        name("scorched glove")
        adjectives("scorched", "burned", "canvas", "work")
        synonyms("glove")
        description(
            """
            A canvas work glove, left-handed, with the fingertips burned back to the lining. It is a small hand's \
            glove. It has been pushed behind the coal bin rather than dropped there.
            """)
    }

    // MARK: - The yard and the lab

    let gardenWall = Item {
        name("garden wall")
        adjectives("garden", "brick", "low")
        synonyms("wall", "brick")
        scenery
    }

    let workbench = Item {
        name("workbench")
        adjectives("long", "scarred")
        synonyms("bench", "workbench")
        scenery
    }

    /// The coroner's answer, sitting in plain sight where the stove's heat can
    /// reach it. It goes up with the carriage house.
    let can = Item {
        name("sealed can")
        adjectives("sealed", "paper", "unmarked")
        synonyms("can", "tin")
        description(
            """
            A paper-wrapped can about the size of a coffee tin, sealed and unlabelled, sitting on the bench end \
            nearest the stove pipe. Whatever is in it, that is not where it goes.
            """)
    }

    /// What the carriage house becomes. Hidden until the blast puts it there,
    /// and off limits once the patrolman is standing over it — the case will
    /// not be solved by sifting.
    let debris = Item {
        name("wreckage")
        adjectives("burned", "burnt", "charred")
        synonyms("wreckage", "debris", "rubble", "ruins")
        description(
            """
            Roof slates, black timber, and a smell with chemistry in it. If the evening has an answer, some of it is \
            in there, and none of it is coming out tonight.
            """)
        scenery
        hidden
    }

    let julian = Actor {
        name("Julian Vane")
        adjectives("julian", "mr", "mister")
        synonyms("vane", "julian", "man")
        description(
            """
            Forty-one and looks it from the side. Shirtsleeves, ink on two fingers, and the particular calm of a man \
            who has decided that whatever is wrong is now somebody else's to prove.
            """)
        firstSight("Julian Vane is at the bench with his back to the door.")
    }

    // MARK: - The household

    let constance = Actor {
        name("Mrs. Vane")
        adjectives("mrs", "missus", "old", "constance")
        synonyms("vane", "constance", "mother", "woman")
        description(
            """
            Seventy-one, upright in a chair that has taken the shape of her. She has the stillness of someone who \
            stopped expecting anything some years ago and has been managing on the arrangement since.
            """)
        firstSight("Mrs. Vane is in her chair with the lamp unlit.")
    }

    let delphine = Actor {
        name("Delphine Marsh")
        adjectives("delphine", "miss", "young")
        synonyms("marsh", "delphine", "woman", "painter")
        description(
            """
            Thirty-four, in a man's shirt with paint on the cuff. She looks back at you a beat longer than most \
            people do, and it is not a challenge, it is arithmetic.
            """)
        firstSight("Delphine Marsh is here, not doing much.")
    }

    let teague = Actor {
        name("Howard Teague")
        adjectives("howard", "mr", "mister")
        synonyms("teague", "howard", "boarder", "man")
        description(
            """
            Fifty-six, Navy the first time around, in a jacket that was pressed this morning by somebody. He is the \
            most helpful person in this house, which is a thing worth noticing about a house where a man has just \
            died.
            """)
        firstSight("Howard Teague is here, being helpful.")
    }

    let pike = Actor {
        name("Dr. Pike")
        adjectives("dr", "doctor", "aldous")
        synonyms("pike", "aldous", "man")
        description(
            """
            Fifty, and wearing his hat indoors because taking it off would mean he had arrived somewhere. He would \
            like very much to be back up the arroyo.
            """)
        firstSight("Dr. Pike is standing about with his hat on.")
    }

    let kettle = Actor {
        name("Mrs. Kettle")
        adjectives("mrs", "missus", "iris", "cook")
        synonyms("kettle", "iris", "cook", "housekeeper", "woman")
        description(
            """
            Sixty-two, and the only person here who has looked at the wreckage and then gone back to what she was \
            doing. She misses nothing and says most of it.
            """)
        firstSight("Mrs. Kettle is here, keeping busy.")
    }

    /// Unscheduled, and stays that way — scenery with a topic table rather
    /// than a sixth timetable. He is why the player cannot dig the answer out
    /// of the debris, and he knows exactly one useful thing.
    let patrolman = Actor {
        name("patrolman")
        adjectives("young", "police")
        synonyms("patrolman", "officer", "policeman", "police", "cop")
        description(
            """
            Young enough to stand at attention beside a burned-down building. He has the wreckage, his orders, and a \
            notebook with everyone's name in it, and he is keeping all three.
            """)
        firstSight("A patrolman is posted at the wreckage, keeping everybody out of it.")
    }

    // MARK: - Upstairs

    let desk = Item {
        name("desk")
        adjectives("writing", "oak")
        synonyms("desk", "drawers")
        scenery
        surface
    }

    let ledger = Item {
        name("ledger")
        adjectives("green", "cloth")
        synonyms("ledger", "book", "accounts")
        description(
            """
            A green cloth accounts book kept in a small hand. Most of it is the ordinary arithmetic of a man with no \
            money. The last four pages are a list of dates against page numbers, and page numbers are not money.
            """)
    }

    let letters = Item {
        name("bundle of letters")
        adjectives("lodge", "tied", "bundle")
        synonyms("letters", "letter", "bundle", "correspondence")
        description(
            """
            A dozen letters in three different hands, tied with grocer's string. They arrange meetings, they argue \
            about money, and they use a vocabulary that would look very bad read aloud in a courtroom and means \
            almost nothing in a parlour. Somebody has read them recently; the string is tied the wrong way round.
            """)
    }

    let typewriter = Item {
        name("typewriter")
        adjectives("portable", "royal")
        synonyms("typewriter", "machine")
        description(
            """
            A portable with a sheet still in it, stopped mid-sentence in the middle of a word. Whatever took him away \
            from it, he did not expect it to take long.
            """)
        scenery
    }

    let suitcase = Item {
        name("suitcase")
        adjectives("brown", "packed")
        synonyms("suitcase", "case", "bag", "luggage")
        description("Brown, scuffed at the corners, and packed. The strap is buckled. It has been packed a while.")
        container
    }

    // MARK: - The evening, written down

    // These five timetables are the case. Everything the household later says
    // about where it was is checked against them rather than against prose —
    // `clock.location(of:at:)` reads the same data that drove the movement, so
    // a schedule edit cannot leave a lie standing by accident.
    //
    // Computed rather than stored because a stored property initializer cannot
    // see `self`, and these have to name the rooms above.

    /// The boarder's evening, and the only one that goes near the lab. Down
    /// the back stairs at 5:36, into the carriage house at 5:38, back through
    /// the kitchen at 5:42 where Mrs. Kettle is standing over her pot, out the
    /// front door at 5:44 — and off the map until ten past six.
    var teagueDay: Timetable {
        Timetable(stops: [
            Stop(at: TimeOfDay(17, 30), in: boardersRoom),
            Stop(
                at: TimeOfDay(17, 36), in: kitchen,
                departure: "Teague's door goes, and there are feet on the back stairs.",
                arrival: "Teague comes down the back stairs with his hat already on."),
            Stop(
                at: TimeOfDay(17, 38), in: carriageHouse,
                departure: "Teague lets himself out the yard door.",
                arrival: "Teague puts his head round the carriage house door and says something short."),
            Stop(
                at: TimeOfDay(17, 42), in: kitchen,
                departure: "Teague comes back out of the carriage house, not hurrying.",
                arrival: "Teague comes back through the kitchen and says nothing to anybody."),
            Stop(
                at: TimeOfDay(17, 44), in: frontHall,
                arrival: "Teague crosses the hall, says he is going for cigarettes, and goes."),
            Stop(at: TimeOfDay(17, 46), in: street),
            Stop(
                at: TimeOfDay(18, 10), in: frontHall,
                arrival: "The front door goes. Teague is back, with a paper bag and a great deal to say."
            ) {
                teagueIsBack = true
            },
            Stop(
                at: TimeOfDay(18, 30), in: boardersRoom,
                departure: "Teague goes up, saying he needs to sit down."),
        ])
    }

    /// The mother's evening: the parlour, six minutes in the yard after the
    /// blast, and the parlour again.
    var constanceDay: Timetable {
        Timetable(stops: [
            Stop(at: TimeOfDay(17, 30), in: parlour),
            Stop(
                at: TimeOfDay(17, 48), in: backYard,
                arrival: "Mrs. Vane comes out as far as the step and stops there."),
            Stop(
                at: TimeOfDay(17, 54), in: parlour,
                departure: "Mrs. Vane goes back inside without having said anything at all."),
        ])
    }

    /// The cook's evening: her kitchen, the yard, her kitchen. She is the one
    /// person here whose account will match the schedule.
    var kettleDay: Timetable {
        Timetable(stops: [
            Stop(at: TimeOfDay(17, 30), in: kitchen),
            Stop(
                at: TimeOfDay(17, 48), in: backYard,
                arrival: "Mrs. Kettle comes out drying her hands and does not stop drying them."),
            Stop(
                at: TimeOfDay(18, 0), in: kitchen,
                departure: "Mrs. Kettle goes back to her kitchen, on the grounds that somebody has to."
            ),
        ])
    }

    /// The partner's evening: the yard when it happens, then the study, then
    /// the cellar — where the dark makes her the one person whose movements
    /// the player can genuinely lose.
    var delphineDay: Timetable {
        Timetable(stops: [
            Stop(at: TimeOfDay(17, 30), in: backYard),
            Stop(
                at: TimeOfDay(18, 2), in: study,
                departure: "Delphine goes inside.",
                arrival: "Delphine comes into the study and starts on the desk drawers."),
            // The arrival line is written even though the cellar is unlit, so
            // that the dark is doing the hiding rather than the prose being
            // absent. A player standing down there with the flashlight on
            // sees her; a player standing down there without it does not.
            Stop(
                at: TimeOfDay(18, 26), in: cellar,
                departure: "Delphine takes the cellar stairs down, and does not take a light.",
                arrival: "Delphine comes down the cellar steps and stops when she sees you."),
        ])
    }

    /// The visitor's evening: the parlour, the yard, and then the study, where
    /// what he wants is.
    var pikeDay: Timetable {
        Timetable(stops: [
            Stop(at: TimeOfDay(17, 30), in: parlour),
            Stop(
                at: TimeOfDay(17, 48), in: backYard,
                arrival: "Dr. Pike arrives in the yard holding his hat against his chest."),
            Stop(
                at: TimeOfDay(18, 14), in: study,
                departure: "Dr. Pike goes back into the house.",
                arrival: "Dr. Pike lets himself into the study and is not pleased to find company."),
        ])
    }

    // MARK: - Composition

    var content: GameContents {
        clock
        talk
    }

    var verbs: [SyntaxRule] {
        [.accuse]
    }

    /// The accusation is the deadline's teeth: a wrong name ends the run. The
    /// deputy coroner does not argue — you spent your credibility, and the
    /// stamp comes down anyway. This is the default: the right name is a
    /// `before` rule on Constance, in the rules block.
    var actions: [IntentAction] {
        action(.accuse) {
            guard let accused = command.directObject else { return }
            try require(accused.isActor, else: "The record wants a name, and that is not one.")
            if !blastHappened {
                try reply("There is nothing to accuse anybody of. Not yet.")
            }
            say(
                """

                He hears you out. Then he writes *accidental* in the box marked cause, and the case is a page in a \
                drawer in a building in Los Angeles.
                """)
            try end(won: false)
        }
    }

    /// The five rounds, and the evening's three fixed points. Everything in
    /// the house moves except the three alarms, and those are what the player
    /// is racing.
    var timers: [TimedEvent] {
        clock.schedule(teague, daemonName: "teague.day", teagueDay)
        clock.schedule(constance, daemonName: "constance.day", constanceDay)
        clock.schedule(kettle, daemonName: "kettle.day", kettleDay)
        clock.schedule(delphine, daemonName: "delphine.day", delphineDay)
        clock.schedule(pike, daemonName: "pike.day", pikeDay)

        // 5:46. The inciting event, and the reason there is a case at all.
        clock.at(TimeOfDay(17, 46), named: "clock.blast") {
            blastHappened = true
            can.vanish()
            julian.vanish()
            debris.reveal()

            // Shock, from here to the end, and her shock looks like nothing
            // at all. She is not grieving like a woman surprised by a death.
            constance.description = """
                Seventy-one, upright, flat, terribly still. She is holding still the way a woman holds still when \
                she is doing arithmetic.
                """

            // Standing in the carriage house when it goes up is a way to end
            // the evening, though not the intended one.
            if player.location == carriageHouse {
                try die(
                    """
                    Vane says "hold this a moment" and you never learn what. The bench, the roof, and the better part \
                    of the garden wall arrive in the yard ahead of you.
                    """)
            }

            say(
                player.location == backYard
                    ? """

                    The carriage house comes apart. There is no bang, particularly — more the sound of a door \
                    slamming in a cave — and then the roof is in the yard with you and the heat arrives all at once.
                    """
                    : """

                    Somewhere out behind the house something goes off with a flat, unimpressive thump, and every \
                    window and pane and loose sash in the place shivers at once, and then is still.
                    """)
        }

        // 5:52. The radio car. Not one of the evening's three fixed points —
        // an errand between them — but it is the turn the deadline lands on
        // the page. Nobody standing in the hall at half past five knows the
        // county's schedule, so it is learned here, not stated in the opening.
        clock.at(TimeOfDay(17, 52), named: "clock.radioCar") {
            patrolman.move(to: carriageHouse)
            say(
                player.location == backYard || player.location == carriageHouse
                    ? """

                    A radio car pulls up out front, and a patrolman comes through the house and out to the wreckage. \
                    He takes names, all of them, yours included, and posts himself where the door used to be. \
                    Downtown told him the deputy coroner is on his way out — due by ten of seven, and what the county \
                    man writes down is what happened.
                    """
                    : """

                    A car door goes out front. A patrolman works through the house taking names, yours included, and \
                    goes out back to stand at the wreckage. What downtown told him gets passed along with the pencil \
                    still moving: the deputy coroner is on his way out, due by ten of seven. What the county man \
                    writes down is what happened.
                    """)
        }

        // 6:20. A voice from the lab's night desk, for a player who happens to
        // be standing near the telephone when it rings.
        clock.at(TimeOfDay(18, 20), named: "clock.telephone") {
            say(
                player.location == frontHall
                    ? """

                    The telephone rings. A man who does not give his name says he is the night desk up at the lab, \
                    that Dr. Pike signed out a car this afternoon and has not signed it back in, and that he would \
                    rather you heard it from him. Then he hangs up, having heard something in his own voice he did \
                    not care for.
                    """
                    : """

                    The telephone starts ringing in the front hall. It rings eleven times. Nobody in this house is \
                    answering telephones tonight.
                    """)
        }

        // 6:50. The deadline. The county man writes down what he is given,
        // and tonight he is being given nothing.
        clock.at(TimeOfDay(18, 50), named: "clock.coroner") {
            say(
                """

                The county man comes up the path at ten to seven, and he is not in a hurry, because nobody has given \
                him a reason to be. He looks at the wreckage for rather less time than you did. Then he writes \
                *accidental* in the box marked cause, and the whole of tonight becomes a page in a drawer in a \
                building in Los Angeles.
                """)
            try end(won: false)
        }
    }

    var rules: Rules {
        // Going through the pockets is what turns the receipt up. Searching a
        // coat in somebody else's hall is the sort of thing the player should
        // have to decide to do.
        // Before, not after: the default action would otherwise report the
        // pockets empty and then the rule would contradict it. And nothing is
        // there to find until Teague has been out and come back — a receipt
        // stamped 6:05 cannot be in a pocket at half past five.
        coat.before(.lookIn) {
            guard teagueIsBack, !receipt.isRevealed else { return }
            receipt.reveal()
            try reply("In the inside pocket there is a slip of register paper, folded once.")
        }

        // Rooms that read differently on the two sides of 5:46.
        backYard.describe {
            blastHappened
                ? """
                Dry grass, and a garden wall that is now shorter at the north end than the south. What is left of the \
                carriage house is standing in pieces, and some of it is still burning quietly because nobody has \
                thought to stop it.
                """
                : """
                Dry grass and a low brick wall that used to be taller. The carriage house stands at the north end \
                with its lamp burning and its door ajar.
                """
        }

        carriageHouse.describe {
            blastHappened
                ? """
                The roof is in the yard. Down one side there is the black stub of a bench, and down the other there \
                is not much worth naming. It is quieter in here than it should be.
                """
                : """
                Somebody's workshop and somebody else's chapel. A long scarred bench down one side under a rack of \
                tools, a cot down the other, and the stove pipe from the house running up through the corner, which \
                is a thing you notice and then stop noticing.
                """
        }

        hallClock.describe {
            // Reads the clock's own format, so the house clock and the
            // player's watch can never disagree about how to say a time.
            "The clock says \(clock.now.formatted(clock.format)). It has the confident tick of a clock that is right."
        }

        gardenWall.describe {
            blastHappened
                ? "Four courses of brick where there were nine, and the missing five are distributed across the grass."
                : "Low brick, and losing an argument with the ivy."
        }

        workbench.describe {
            blastHappened
                ? "Charcoal in the shape of a bench."
                : """
                Tools laid out in the order a careful man uses them, and a scorch mark near the vice that is older \
                than tonight.
                """
        }

        // The patrolman's one job. Some of the answer is literally in the
        // debris, which is why nobody gets to sift it.
        debris.before(.lookIn) {
            if patrolman.location == carriageHouse {
                try reply(
                    "\"Best keep back from there,\" the patrolman says, and puts a shoulder where you were going.")
            }
            try reply(
                """
                You turn over what the heat will let you touch and get soot to the elbow for it. Whatever the answer \
                is, it is not the kind you sift out.
                """)
        }

        // MARK: The interrogation

        // Julian is askable for the first eight turns, and only there — the
        // blast takes him out of scope, so the table needs no gate. A player
        // who spends the opening with the victim learns things a player who
        // wanders the garden does not.
        talk.topics(
            of: julian, fallback: "\"Later,\" he says, without turning round. \"You'll have all of it after six.\""
        ) {
            topic(
                "letter", "lab", "break in", "intruder", "somebody",
                reply: """
                    "Nothing taken." He lets that sit. "A thief takes. A man who takes nothing is coming back."
                    """)
            topic(
                "six", "appointment", "show", "tonight",
                reply: """
                    "At six." He nods at the bench. "You'll want to be sitting down for it, and I want better light \
                    than this."
                    """)
            topic(
                "delphine", "marsh",
                reply: """
                    "Delphine keeps her own counsel." He tightens a clamp. "It was the counsel I liked first."
                    """)
            topic(
                "teague", "boarder", "howard",
                reply: """
                    "Howard borrows things. They come back a little different." He almost smiles. "Most things don't \
                    come back at all."
                    """)
            topic(
                "pike", "arroyo", "notebooks", "fired", "associations",
                reply: """
                    "They let me go over the company I keep, and now they send a man out about the company I kept." \
                    He files at something small. "The notebooks are mine. Tell Pike I said so."
                    """)
            topic(
                "mother", "constance",
                reply: """
                    "My mother thinks this place took something from her." He sets the file down. "She's not wrong. \
                    We disagree about what."
                    """)
        }

        // Constance's table is nearly all refusals until the glove — every
        // investigative habit the player owns slides off a seventy-one-year-old
        // woman in an unlit parlour, which is why she is the answer.
        talk.topics(of: constance, fallback: "Mrs. Vane looks past you at the wallpaper.") {
            // The lie. Note it matches her timetable exactly: the timetable is
            // where she was seen, and the can was placed before half past five.
            topic(
                "evening", "parlour", "alibi", "where",
                unless: .constanceBroke,
                reply: """
                    "I have been in the parlour all evening." She says it to the cold grate, in the voice of a woman \
                    reading a timetable.
                    """)
            topic(
                "evening", "parlour", "alibi", "where",
                knowing: .constanceBroke,
                reply: """
                    "I went out before you came. He was in the house at his supper." Her hands are still. "I put it \
                    where the heat would find it and I came back to my chair, and I have been in this chair since."
                    """)
            topic(
                "julian", "son",
                unless: .constanceBroke,
                reply: "\"My son is dead in the garden.\" That is all she has on the subject.")
            topic(
                "julian", "son",
                knowing: .constanceBroke,
                reply: """
                    "That shed had him twenty years before it killed him." She looks at the lamp she has not lit. "I \
                    meant to take it back. I believed he had gone out."
                    """)
            topic(
                "lab", "carriage house", "workshop", "shed",
                unless: .constanceBroke,
                reply: "\"I never went into it.\" It has the finish of a sentence said many times.")
            topic(
                "glove", "cellar",
                knowing: .constanceBroke,
                reply: "\"It is my glove,\" she says. \"You knew that when you carried it up the stairs.\"")
            topic(
                "teague", "boarder",
                knowing: .teagueLied,
                reply: """
                    "Mr. Teague told me Julian had gone out." She folds her hands. "So you see it mattered, what he \
                    said. It mattered more than he will ever let himself work out."
                    """)
        }

        // Everything about Delphine invites the wrong conclusion, and the
        // table lets the player reach it before the letters retire it.
        talk.topics(of: delphine, fallback: "She goes on looking at whatever she was looking at.") {
            // Her lie — that she doesn't know what's in the letters.
            topic(
                "letters", "lodge", "correspondence", "bundle",
                unless: .delphineCleared,
                reply: "\"Julian kept letters. Men keep letters.\" She shrugs. \"I wouldn't know what's in them.\"")
            topic(
                "letters", "lodge", "correspondence", "bundle",
                knowing: .delphineCleared,
                reply: """
                    "They argue about money and dress it in robes." She almost laughs, and doesn't. "The neighbors \
                    would be so disappointed."
                    """)
            topic(
                "desert", "rites", "sunday",
                reply: """
                    "We went out for the air," she says, and gives you the first half of a phrase, and waits. You \
                    know the second half. You keep it.
                    """)
            topic(
                "julian", "vane",
                reply: """
                    "He wrote to somebody last week and slept better after." A beat. "That was you, I take it."
                    """)
        }

        // Teague's alibi dies in three stages: the cook's testimony kills it,
        // the receipt breaks him, and what he told Constance is the keystone
        // the full ending turns on.
        talk.topics(of: teague, fallback: "\"Couldn't tell you, friend.\"") {
            topic(
                "drugstore", "alibi", "evening", "colorado", "where",
                unless: .kettleSawTeague,
                reply: """
                    "Drugstore on Colorado. Left here about half past, walked down, had a Coca-Cola, walked back. \
                    Ask them, they know me."
                    """)
            topic(
                "drugstore", "alibi", "evening", "colorado", "where", "kitchen",
                knowing: .kettleSawTeague, unless: .teagueRecanted,
                reply: """
                    "Mrs. Kettle keeps a good kitchen and a better clock." He recrosses his legs. "A man can pass \
                    through a kitchen on his way to the drugstore. I'd check her arithmetic."
                    """)
            topic(
                "drugstore", "alibi", "evening", "colorado", "where", "kitchen",
                knowing: .teagueRecanted,
                reply: "\"You've got the slip,\" he says. \"I'm done selling you the drugstore.\"")
            topic(
                "constance", "vane", "old lady", "mother", "told",
                knowing: .teagueRecanted, learning: .teagueLied,
                reply: """
                    "I told the old lady he'd gone out. That's all I told her. I wanted half an hour in that lab and \
                    I didn't want her watching the yard while I had it." He looks at the window. "It wasn't a lie \
                    that was supposed to do anything."
                    """)
            topic(
                "constance", "vane", "old lady", "mother",
                unless: .teagueRecanted,
                reply: "\"The old lady? Keeps to her parlour.\" He finds something on his sleeve to straighten.")
            topic(
                "notebooks", "pages", "ledger",
                knowing: .notebooksSold,
                reply: """
                    "Call it salvage," he says, before you have put a name to it. "The lab wanted those pages once \
                    and wants them now, and the mails in between were me."
                    """)
            topic(
                "notebooks", "pages",
                reply: "\"Vane's notebooks? Wouldn't know. I write my own pages.\"")
            topic(
                "julian", "vane",
                knowing: .teagueRecanted,
                reply:
                    "\"He was all right. Let me alone, let the rent ride.\" He looks at his hands. \"He was all right.\""
            )
        }

        // Pike's lie has a second floor — the earlier visit was not about
        // notebooks — and the ledger only opens the first one.
        talk.topics(of: pike, fallback: "\"I don't see how that concerns me.\"") {
            topic(
                "visit", "house", "before", "first",
                unless: .notebooksSold,
                reply:
                    "\"My first time at the house. I had the address only this week.\" He adjusts the hat he has not taken off."
            )
            topic(
                "visit", "house", "before", "first",
                knowing: .notebooksSold,
                reply: """
                    "I have been here before." He says it like a man initialling a correction. "Not for notebooks. \
                    You were in that trade once. You can imagine the shape of the report I filed."
                    """)
            topic(
                "notebooks", "pages", "papers", "lab",
                reply: """
                    "The men we have now prefer the notebooks in order. I was sent to put them in order." He starts \
                    a surname, gets as far as the first vowel, and files it back where he keeps it.
                    """)
            topic(
                "julian", "vane",
                reply: """
                    "A capable man. Indiscreet." The hat brim comes down a degree. "Capable stopped being a defence \
                    some years ago."
                    """)
        }

        // Mrs. Kettle is the mechanism by which the schedule becomes
        // testimony. Her answers are not authored prose: each one reads the
        // person's timetable, so a schedule edit changes what she says with
        // it. This is the demonstration the whole game exists to make — see
        // the mechanics contract in `docs/games/fulminate.md`.
        talk.topics(of: kettle, fallback: "\"That I couldn't say.\"") {
            topic("teague", "boarder", "howard", learning: .kettleSawTeague) {
                let room = clock.location(of: teagueDay, at: TimeOfDay(17, 42))
                try reply(
                    """
                    "Mr. Teague come down my back stairs into the \(room.name.lowercased()) at eighteen minutes to \
                    six with his hat already on. I know because the pot goes on at a quarter to, and I was standing \
                    right there getting it ready."
                    """)
            }
            topic("constance", "mrs vane", "mother", "old lady") {
                let then = clock.location(of: constanceDay, at: TimeOfDay(17, 46))
                let after = clock.location(of: constanceDay, at: TimeOfDay(17, 50))
                try reply(
                    """
                    "Mrs. Vane was in the \(then.name.lowercased()) when it went, and stood out in the \
                    \(after.name.lowercased()) after with the rest of us. Then back in, without a word said."
                    """)
            }
            topic("delphine", "marsh", "miss") {
                let room = clock.location(of: delphineDay, at: TimeOfDay(17, 46))
                try reply(
                    """
                    "Miss Marsh was in the \(room.name.lowercased()) when it went. I'll say that for her, and she \
                    can do with it what she likes."
                    """)
            }
            topic("pike", "doctor", "visitor") {
                let then = clock.location(of: pikeDay, at: TimeOfDay(17, 46))
                let after = clock.location(of: pikeDay, at: TimeOfDay(17, 50))
                try reply(
                    """
                    "The doctor sat in the \(then.name.lowercased()) with his hat on from the minute he come. He was \
                    out in the \(after.name.lowercased()) after, holding it."
                    """)
            }
            // Julian keeps no timetable, so this one is hers alone.
            topic(
                "julian", "vane", "son",
                reply: """
                    "Mr. Julian had his supper at five and carried a plate of it out to the shed." The pot gets a \
                    stir it does not need. "I have fed that boy since he was eleven."
                    """)
        }

        // He stands at the wreckage from 5:52 on and knows exactly one useful
        // thing.
        talk.topics(of: patrolman, fallback: "\"Best keep back from there.\"") {
            topic(
                "coroner", "county", "deputy", "downtown", "deadline",
                reply: """
                    "County man's on his way out from downtown. Due by ten of seven, they said." He looks at the \
                    wreckage rather than at you. "He writes it up and that's what it is. If you've got something for \
                    him, have it ready."
                    """)
        }

        // The four pieces of physical evidence, each of which flips a story.
        talk.shows(
            receipt, to: teague, learning: .teagueRecanted,
            reply: """
                He looks at it for a while. "Six-oh-five," he says. "Yeah." He sits down on the arm of the chair, \
                which is not his chair. "I went after. I needed to have been somewhere."
                """)
        talk.shows(
            glove, to: constance, learning: .constanceBroke,
            reply: """
                She takes it out of your hand, which you were not expecting, and turns it over once. "I have been \
                sitting here," she says, "trying to remember whether I put it back."
                """)
        talk.shows(
            ledger, to: pike, learning: .notebooksSold,
            reply: """
                He reads the last four pages without touching the book. "Dates and page numbers," he says, and sits \
                down, and takes his hat off at last. "I paid for those. I never asked whose hand did the copying."
                """)
        talk.shows(
            letters, to: delphine, learning: .delphineCleared,
            reply: """
                She unties the string and reads the top one through, all the way, before she hands it back. "Now \
                you've read them," she says. "So you know what they are not."
                """)

        // `ACCUSE CONSTANCE` wins the game. The two endings differ by one
        // learned fact — the keystone — because a player who never finds out
        // why she believed the lab was empty has solved the case without
        // understanding it. Every other name falls through to the default
        // action, which is the losing one.
        constance.before(.accuse) {
            if !blastHappened {
                try reply("There is nothing to accuse anybody of. Not yet.")
            }
            say(
                talk.knows(.teagueLied)
                    ? """

                    The county man writes for a long time. When he is finished he reads it back, and there are two \
                    names in it, and only one of them meant anything by it.
                    """
                    : """

                    The county man writes down her name and closes the book. He does not ask why, and you do not \
                    have an answer that would fit in the space provided.
                    """)
            try end(won: true)
        }
    }

    var map: WorldMap {
        frontHall.west(parlour)
        parlour.east(frontHall)

        frontHall.south(kitchen)
        kitchen.north(frontHall)

        kitchen.west(backYard)
        backYard.east(kitchen)

        kitchen.down(cellar)
        cellar.up(kitchen)

        backYard.north(carriageHouse)
        carriageHouse.south(backYard)

        frontHall.up(landing)
        landing.down(frontHall)

        landing.west(study)
        study.east(landing)

        landing.east(boardersRoom)
        boardersRoom.west(landing)

        // The street is not an option. A man wrote to you and is now dead in
        // his mother's back garden; leaving is the one thing you can't do.
        frontHall.east(blocked: Fulminate.streetRefusal)
        frontHall.out(blocked: Fulminate.streetRefusal)

        player.starts(in: frontHall)

        hallClock.starts(in: frontHall)
        telephone.starts(in: frontHall)
        coat.starts(in: frontHall)
        receipt.starts(inside: coat)

        stove.starts(in: kitchen)
        drawer.starts(in: kitchen)
        flashlight.starts(inside: drawer)

        glove.starts(in: cellar)

        gardenWall.starts(in: backYard)

        workbench.starts(in: carriageHouse)
        can.starts(in: carriageHouse)
        debris.starts(in: carriageHouse)
        julian.starts(in: carriageHouse)

        // Off the map until the radio car brings him at 5:52.
        patrolman.starts(in: street)

        // Everyone starts where their own timetable says they are at 5:30, so
        // the opening tableau and the schedule can't disagree.
        teague.starts(in: teagueDay.location(at: clock.start))
        constance.starts(in: constanceDay.location(at: clock.start))
        kettle.starts(in: kettleDay.location(at: clock.start))
        delphine.starts(in: delphineDay.location(at: clock.start))
        pike.starts(in: pikeDay.location(at: clock.start))

        desk.starts(in: study)
        ledger.starts(in: study)
        letters.starts(in: study)

        typewriter.starts(in: boardersRoom)
        suitcase.starts(in: boardersRoom)
    }
}
