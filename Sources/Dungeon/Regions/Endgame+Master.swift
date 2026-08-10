import Gnusto

extension Intent {
    /// The eight answers to the Dungeon Master's eight questions, one intent
    /// apiece.
    ///
    /// **They are `answer X` and `say X`, not bare words**, which is
    /// ``Intent/answerWell``'s shape exactly and is a deliberate narrowing of
    /// what the issue proposed. A bare `["skeleton"]` row would put *skeleton*
    /// into the verb vocabulary, where the maze already has a skeleton and the
    /// forest above ground a set of skeleton keys; `["forest"]`, `["flask"]`
    /// and `["knife"]` are the same problem. The riddle at the Riddle Room
    /// already answers to `answer well`, so this is the game's own established
    /// spelling rather than a concession.
    ///
    /// The cost the issue names is real and unchanged: an answer outside the
    /// eight is a **parse failure** rather than a wrong answer, and a parse
    /// failure costs no turn. It is recorded in `FIDELITY.md` rather than left
    /// to be discovered.
    #verb("quizTemple", ["answer", "temple"], ["say", "temple"])
    #verb("quizForest", ["answer", "forest"], ["say", "forest"])
    #verb("quizZorkmids", ["answer", "30003"], ["say", "30003"])
    #verb("quizFlask", ["answer", "flask"], ["say", "flask"])
    #verb("quizRub", ["answer", "rub"], ["say", "rub"])
    #verb("quizSkeleton", ["answer", "skeleton"], ["say", "skeleton"])
    #verb(
        "quizKnife",
        ["answer", "knife"], ["say", "knife"],
        ["answer", "rusty", "knife"], ["say", "rusty", "knife"])
    #verb(
        "quizNowhere",
        ["answer", "nowhere"], ["say", "nowhere"],
        ["answer", "none"], ["say", "none"])
}

/// The three questions this run drew, in the order they will be asked.
///
/// A wrapper struct rather than a bare `[Int]` so the `GlobalValue`
/// conformance is owned here instead of declared retroactively on a
/// standard-library type — ``RoyalPuzzleGrid``'s reason exactly.
struct QuizPaper: Codable, Sendable, GlobalValue {
    var questions: [Int] = []

    init(questions: [Int] = []) { self.questions = questions }

    init(from decoder: any Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        questions = (try? box.decode([Int].self, forKey: .questions)) ?? []
    }
}

// MARK: - The quiz

extension DungeonEndgame {
    /// How many of the eight the source has, how many are asked, and how many
    /// wrong answers to one of them end it for good.
    static let quizQuestionCount = 8
    static let quizQuestionsAsked = 3
    static let quizWrongAnswersAllowed = 5

    /// Each question against the intent that answers it, indexed the way
    /// ``Prose/quizQuestion(_:)`` indexes them.
    var quizAnswers: [Intent] {
        [
            .quizTemple, .quizForest, .quizZorkmids, .quizFlask,
            .quizRub, .quizSkeleton, .quizKnife, .quizNowhere,
        ]
    }

    /// Knocking at the wooden door, the questions behind it, and the eight
    /// answers.
    @RuleBuilder var quizRules: Rules {
        woodenDoor.describe { woodenDoor.isOpen ? Prose.woodenDoorOpen : Prose.woodenDoorClosed }

        // The one door in the game that answers. Everything else in the game
        // gets the bundle's `action(.knock)`, which is the game's default rather
        // than an interception — see ``DungeonEndgame/actions``.
        woodenDoor.before(.knock) { try knockAtTheWoodenDoor() }

        // The door does not open to hands. It opens to three right answers —
        // and once it has opened it stays open, because `quizWon` and
        // `woodenDoor.isOpen` are two records of one fact and `close door`
        // would otherwise part them: `knock` would then answer "The door
        // already stands open" at a door that is shut.
        woodenDoor.before(.open, .push, .pull, .attack) {
            guard !quizWon else { return }
            try refuse(Prose.woodenDoorWillNotBeForced)
        }
        woodenDoor.before(.close) { try refuse(Prose.woodenDoorWillNotBeShut) }

        for (index, answer) in quizAnswers.enumerated() {
            world.before(answer) { try answerTheQuestion(with: index) }
        }
    }

    /// Starting the quiz, or being told it is over.
    ///
    /// - Throws: always.
    func knockAtTheWoodenDoor() throws -> Never {
        try require(!quizWon, else: Prose.quizAlreadyWon)
        try require(!quizIsLost, else: Prose.quizIsOver)
        guard quizAsked < 0 else { try reply(Prose.quizQuestion(currentQuestion)) }

        // Three drawn from eight without replacement, which is what makes a
        // second attempt at the door a different examination.
        var drawn: [Int] = []
        while drawn.count < Self.quizQuestionsAsked {
            let pick = random(0...(Self.quizQuestionCount - 1))
            if !drawn.contains(pick) { drawn.append(pick) }
        }
        quizPaper = QuizPaper(questions: drawn)
        quizAsked = 0
        quizWrong = 0
        quizWaitedATurn = false
        startDaemon("endgame.quiz")
        say(Prose.quizBegins)
        try reply(Prose.quizQuestion(currentQuestion))
    }

    /// Whether five wrong answers have ended the examination for good. Not a
    /// flag of its own: a right answer is the only thing that puts `quizWrong`
    /// back, and after the fifth wrong one nothing can.
    var quizIsLost: Bool { quizWrong >= Self.quizWrongAnswersAllowed }

    /// Which of the eight is on the table, or `-1` when none is.
    var currentQuestion: Int {
        let paper = quizPaper.questions
        guard quizAsked >= 0, paper.indices.contains(quizAsked) else { return -1 }
        return paper[quizAsked]
    }

    /// One answer, right or wrong.
    ///
    /// - Parameter given: which of the eight answers was spoken.
    /// - Throws: always.
    func answerTheQuestion(with given: Int) throws -> Never {
        let asked = currentQuestion
        guard asked >= 0 else { try reply(Prose.quizNobodyAsked) }
        guard given == asked else {
            quizWrong += 1
            guard !quizIsLost else {
                quizAsked = -1
                stopDaemon("endgame.quiz")
                try reply(Prose.quizFailedForGood)
            }
            try reply(Prose.quizWrongAnswer)
        }

        quizWrong = 0
        quizAsked += 1
        guard quizAsked >= Self.quizQuestionsAsked else {
            // The clock starts again on the new question, or he would put it a
            // second time in the same breath he first put it in.
            quizWaitedATurn = false
            say(Prose.quizRightAnswer)
            try reply(Prose.quizQuestion(currentQuestion))
        }

        quizAsked = -1
        quizWon = true
        stopDaemon("endgame.quiz")
        woodenDoor.isOpen = true
        try reply(Prose.quizWonAndTheDoorOpens)
    }
}

// MARK: - The prison

extension DungeonEndgame {
    /// The cell with the bronze door in it. Cell four, and the whole of the
    /// puzzle is that you have to be inside it when it leaves the slot.
    static let cellWithTheBronzeDoor = 4

    /// How many cells are on the carousel.
    static let cellCount = 8

    /// The sundial, the button, the slot, and the ride out of it.
    @RuleBuilder var prisonRules: Rules {
        southCorridor.describe { "\(Prose.southCorridor)\n\n\(throughTheSouthDoorway)" }
        northCorridor.describe {
            dockedCell == 0
                ? "\(Prose.northCorridor)\n\n\(Prose.cellSlotEmpty)"
                : Prose.northCorridor
        }
        prisonCell.describe {
            dockedCell == Self.cellWithTheBronzeDoor ? Prose.prisonCellBronze : Prose.prisonCell
        }

        southSlot.describe { throughTheSouthDoorway }
        northSlot.describe {
            dockedCell == 0 ? Prose.cellSlotEmpty : Prose.cellSlotFilled
        }
        sundial.describe { Prose.sundialReading(Self.numberWord(dialSetting)) }
        bronzeDoor.describe { bronzeDoor.isOpen ? Prose.bronzeDoorOpen : Prose.bronzeDoorClosed }

        sundial.before(.setTo) { try setTheDial() }
        sundial.before(.turn, .push, .pull, .turnOn) { try turnTheDial() }
        parapetButton.before(.push, .turnOn) { try pressTheParapetButton() }

        // A slot with nothing in it is a hole in the floor, not a room.
        northCorridor.before(.go) {
            guard command.direction == .south || command.direction == .in else { return }
            try require(dockedCell != 0, else: Prose.cellSlotEmptyRefusal)
        }

        treasury.onEnter {
            say(Prose.treasuryDoorCloses)
        }
    }

    /// What the South Corridor's doorway shows. Three answers, not two: the
    /// shaft with no cell in it at all, the blank back of one of the seven
    /// ordinary cells, and cell four's bronze door.
    var throughTheSouthDoorway: String {
        switch dockedCell {
        case 0: Prose.cellSlotEmpty
        case Self.cellWithTheBronzeDoor: Prose.bronzeDoorInTheSlot
        default: Prose.cellSlotFilled
        }
    }

    /// The word for a dial setting, so the sundial reads in English.
    ///
    /// - Parameter number: a setting from one to eight.
    /// - Returns: the word for it.
    static func numberWord(_ number: Int) -> String {
        ["one", "two", "three", "four", "five", "six", "seven", "eight"][
            max(1, min(8, number)) - 1]
    }

    /// `set dial to four`, the source's own spelling, from the player's own
    /// hands or from an order.
    ///
    /// The number is an object, because this engine hands a rule the *item* a
    /// noun resolved to and never the word the player typed. `set dial to
    /// sword` reaches here too — the parser resolved a noun, just not one on
    /// the face — so an unusable one is refused rather than silently rounded.
    ///
    /// - Throws: always.
    func setTheDial() throws -> Never {
        try require(atTheParapet, else: Prose.masterIsNotAtTheParapet)
        guard let named = command.indirectObject,
            let setting = numerals.firstIndex(of: named).map({ $0 + 1 })
        else {
            try refuse(Prose.sundialNeedsANumber)
        }
        try settleDial(on: setting)
    }

    /// Advancing the dial one number, for `turn dial` and its spellings — which
    /// name no number, so there is only one thing they can mean.
    ///
    /// - Throws: always.
    func turnTheDial() throws -> Never {
        try require(atTheParapet, else: Prose.masterIsNotAtTheParapet)
        try settleDial(on: dialSetting % Self.cellCount + 1)
    }

    /// Where both ways of moving the dial end: the pointer comes to rest, and
    /// whose hand did it decides the sentence — the whole prison turns on the
    /// Dungeon Master doing it from a room the player is not standing in.
    ///
    /// - Parameter setting: the number the pointer lands on.
    /// - Throws: always.
    func settleDial(on setting: Int) throws -> Never {
        dialSetting = setting
        try reply(
            Prose.sundialSet(
                Self.numberWord(setting), byHand: command.actor != dungeonMaster))
    }

    /// The button that turns the carousel. Pressed with the player inside the
    /// docked cell, it takes the player with it — which is the solve.
    ///
    /// - Throws: always.
    func pressTheParapetButton() throws -> Never {
        try require(atTheParapet, else: Prose.masterIsNotAtTheParapet)
        let riding = player.location == prisonCell
        let departing = dockedCell
        dockedCell = dialSetting
        bronzeDoor.isOpen = false

        if dockedCell == Self.cellWithTheBronzeDoor {
            bronzeDoor.reveal()
            bronzeDoor.move(to: southCorridor)
        } else {
            bronzeDoor.vanish()
        }

        guard riding else {
            try reply(player.location == parapet ? Prose.carouselTurns : Prose.carouselTurnsUnseen)
        }

        // The cell you are standing in leaves the slot with you in it. Which
        // cell it was decides everything.
        let landing =
            departing == Self.cellWithTheBronzeDoor ? winningCell : lostCell
        lockedCellDoor.move(to: landing)
        if landing == winningCell {
            bronzeDoor.reveal()
            bronzeDoor.move(to: winningCell)
            bronzeDoor.isOpen = false
        }
        say(Prose.cellRidesOut)
        try enterTheHallway(at: landing)
    }

    /// Whether whoever is working the parapet's instruments is standing on it.
    /// The Dungeon Master executes an order in his own room, so this asks about
    /// him when he is the one being told.
    var atTheParapet: Bool {
        command.actor == dungeonMaster
            ? dungeonMaster.isIn(parapet) : player.location == parapet
    }
}

// MARK: - The Dungeon Master

extension DungeonEndgame {
    /// The rooms he will walk into. He follows you everywhere in the prison and
    /// refuses to set foot in a cell, which is what makes the solve possible:
    /// you can be somewhere he will not go and still be heard.
    var masterRoams: [Location] {
        [narrowCorridor, southCorridor, northCorridor, eastCorridor, westCorridor, parapet]
    }

    /// What he does, and the two things he will not do.
    @RuleBuilder var masterRules: Rules {
        dungeonMaster.before(.attack, .smash, .cut) { try die(Prose.masterKillsYou) }

        dungeonMaster.before(.stay) {
            masterStaying = true
            try reply(Prose.masterStays)
        }
        dungeonMaster.before(.follow) {
            masterStaying = false
            try reply(Prose.masterFollows)
        }

        dungeonMaster.before(.go) {
            guard let heading = command.direction else { try refuse(Prose.masterNeedsADirection) }
            guard let destination = masterStep(heading) else {
                try refuse(Prose.masterWillNotGoThatWay)
            }
            masterStaying = true
            let watching = player.location
            dungeonMaster.move(to: destination)
            try reply(watching == destination ? Prose.masterArrives : Prose.masterWalksOff)
        }

        dungeonMaster.before(.greet, .give, .lookIn) { try reply(Prose.masterSaysNothing) }
    }

    /// Where a step in `heading` would take him, or `nil` for the directions he
    /// declines — every one of which is into a cell.
    ///
    /// - Parameter heading: the direction he was told to walk.
    /// - Returns: the room, or `nil`.
    func masterStep(_ heading: Direction) -> Location? {
        let here = dungeonMaster.location
        let routes: [(Location, Direction, Location)] = [
            (narrowCorridor, .north, southCorridor),
            (southCorridor, .south, narrowCorridor),
            (southCorridor, .east, eastCorridor),
            (southCorridor, .west, westCorridor),
            (eastCorridor, .north, northCorridor),
            (eastCorridor, .south, southCorridor),
            (westCorridor, .north, northCorridor),
            (westCorridor, .south, southCorridor),
            (northCorridor, .east, eastCorridor),
            (northCorridor, .west, westCorridor),
            (northCorridor, .north, parapet),
            (parapet, .south, northCorridor),
        ]
        return routes.first { $0.0 == here && $0.1 == heading }?.2
    }
}
