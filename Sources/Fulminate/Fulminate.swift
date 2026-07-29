import Gnusto
import GnustoClock

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
/// This first slice is the house, the clock, and the three alarms that bracket
/// the evening. The suspects and their rounds arrive with the timetable work,
/// and the interrogation with the conversation work; until then the case can
/// be walked but not solved.
///
/// Original: Julian Vane is fictional. The setting borrows the shape of a real
/// 1952 Pasadena explosion; the crime, the household, and every person in it
/// are invented, and no accusation here is made of anyone who lived.
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
            Forty-ish, in a jacket that was pressed this morning by somebody. He is the most helpful person in this \
            house, which is a thing worth noticing about a house where a man has just died.
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
        julian.starts(in: carriageHouse)

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
