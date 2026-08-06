/// The endgame's working lines — every refusal, every report of a thing that
/// moved, and the Dungeon Master's examination.
///
/// `Prose+Endgame.swift` holds the rooms and the objects; this holds what
/// happens to them. The split is the same one `Prose+Systems.swift` makes
/// against `Prose.swift`, and it exists here for a second reason: hazard #174
/// wants small declaration bodies, and one four-hundred-line `extension Prose`
/// is not one of those.
///
/// **Case 3 throughout — written fresh.** The whole region is mainframe-only:
/// no room and no object of it appears in any bucket of
/// `docs/games/dungeon-prose-comparison.md`. The three-way rule is stated on
/// ``Prose``; the caveat about Zork III is stated in `Prose+Endgame.swift` and
/// in `FIDELITY.md`, and is not repeated here.
extension Prose {
    // MARK: - The box, from outside

    static let boxNoWayIn = """
        There is no opening in the side facing you.
        """

    static let boxNotBesideIt = """
        The box is not within reach from here.
        """

    static let swordStopsGlowing = """
        The blue light goes out of the sword.
        """

    static let boxIsNotInSight = """
        The box is somewhere else along the hallway, out of sight from here.
        """

    /// The word for whichever part of the box is turned toward you. `nil` is a
    /// box standing at an angle, with a corner rather than a face to the
    /// hallway.
    ///
    /// - Parameter face: the part facing the reader.
    /// - Returns: the noun phrase for it.
    static func boxFaceName(_ face: BoxFace?) -> String {
        switch face {
        case .mahogany: "a wall of dark mahogany"
        case .pine: "a wall of pale pine"
        case .mirror, .farMirror: "a mirror the height of the hallway"
        case .none: "one of its corners"
        }
    }

    /// The sentence a hallway room adds when the box is standing in the next
    /// room along it.
    ///
    /// - Parameters:
    ///   - northward: whether the box is up the hallway rather than down it.
    ///   - face: the part of it turned this way.
    ///   - intact: whether both mirrors are still whole.
    /// - Returns: the paragraph.
    static func boxInTheHallway(northward: Bool, face: BoxFace?, intact: Bool) -> String {
        let side = northward ? "north" : "south"
        let glass = intact ? "" : " Broken glass lies along the foot of it."
        return """
            An enormous box fills the hallway to the \(side), floor to ceiling \
            and wall to wall. What faces you is \(boxFaceName(face)).\(glass)
            """
    }

    /// And the sentence a narrow room adds, where the box is not up the hallway
    /// but a hand's breadth from your shoulder.
    ///
    /// - Parameters:
    ///   - face: the part of it turned this way.
    ///   - open: whether that part is the mirror, standing open.
    /// - Returns: the paragraph.
    static func boxBesideYou(face: BoxFace?, open: Bool) -> String {
        open
            ? """
            The side of the box stands beside you, and the mirror in it is \
            swung open on a dark space within.
            """
            : """
            The side of the box stands beside you, close enough to touch: \
            \(boxFaceName(face)).
            """
    }

    /// Examining the box from any of the eleven rooms it can be seen from.
    ///
    /// - Parameters:
    ///   - face: the part of it turned this way.
    ///   - open: whether that part is the mirror, standing open.
    /// - Returns: the description.
    static func boxFromOutside(face: BoxFace?, open: Bool) -> String {
        let opening =
            open ? " The mirror on this side is swung open." : ""
        return """
            A rectangular box the full height of the hallway, longer than it is \
            wide. The side toward you is \(boxFaceName(face)).\(opening)
            """
    }

    // MARK: - The box, from inside

    static let boxMirrorStandsOpen = """
        One of the mirrors stands open, and the hallway shows through the gap.
        """

    static let boxPineStandsOpen = """
        The pine wall stands swung open on its hinges.
        """

    static let boxPineAlreadyOpen = """
        The pine wall is already open.
        """

    static let boxPineAlreadyShut = """
        The pine wall is already shut.
        """

    static let cryptDoorAlreadyOpen = """
        The crypt door already stands open.
        """

    static let boxNoWayOut = """
        The walls of the box are shut on every side of you.
        """

    static let boxWillNotTurnWithThePoleDown = """
        Nothing gives. Whatever the pole is resting in is holding the box where
        it stands.
        """

    static let boxWillNotSlideCrosswise = """
        The box is standing across the hallway. It will not go anywhere until it
        is square to the channel.
        """

    static let boxAtTheEndOfTheChannel = """
        The box comes up hard against the end of the channel and stops.
        """

    static let boxSlides = """
        The box slides smoothly along the channel and comes to rest.
        """

    /// Which way the box came round, so a player working a compass by feel can
    /// tell one panel from another.
    ///
    /// - Parameter clockwise: whether it turned that way.
    /// - Returns: the line.
    static func boxTurns(clockwise: Bool) -> String {
        clockwise
            ? "The box swings round to the right and settles."
            : "The box swings round to the left and settles."
    }

    static let boxPineSwingsOpen = """
        The pine wall swings out on its hinges. Beyond it is the hallway.
        """

    static let boxPineSwingsShut = """
        The pine wall swings to and the wooden bar drops across it.
        """

    static let boxPineSlamsShut = """
        The pine wall slams to as the box comes round.
        """

    static let boxMirrorSwingsShut = """
        The open mirror swings quietly back into line and is a mirror again.
        """

    // MARK: - The mirrors

    static let mirrorShatters = """
        The glass goes down in a sheet and breaks across the floor. Whatever the
        mirrors were for, they are not for it now.
        """

    static let boxMirrorAlreadyBroken = """
        There is nothing left of it to break.
        """

    // MARK: - The pole

    static let poleRises = """
        The pole comes up out of the floor and hangs in its collar.
        """

    static let poleAlreadyRaised = """
        The pole is already up.
        """

    static let poleAlreadyDown = """
        The pole is already down.
        """

    static let poleDropsIntoTheHole = """
        The pole drops and seats itself in a round hole in the floor.
        """

    static let poleDropsIntoTheChannel = """
        The pole drops and seats itself in the stone channel.
        """

    static let poleRestsOnTheFloor = """
        The pole comes down and rests on the floor, holding nothing.
        """

    // MARK: - The examination

    static let quizBegins = """
        A voice on the far side of the door says that three questions stand
        between you and the Dungeon Master, and that it will hear an answer
        spoken plainly.
        """

    /// The eight questions, indexed the way ``DungeonEndgame/quizAnswers``
    /// indexes their answers.
    ///
    /// - Parameter index: which of the eight is being put.
    /// - Returns: the question.
    static func quizQuestion(_ index: Int) -> String {
        switch index {
        case 0:
            """
            "From which room can one enter the robber's hideaway without
            passing through the Cyclops Room?"
            """
        case 1:
            """
            "Beside the Temple, to which room is it possible to go from the
            Altar?"
            """
        case 2:
            """
            "What is the absolute minimum specified value of the treasures of
            Zork, in zorkmids?"
            """
        case 3:
            """
            "What object is of use in determining the function of the iced
            cakes?"
            """
        case 4:
            """
            "What can be done to the mirror that is useful?"
            """
        case 5:
            """
            "The taking of which object offends the ghosts?"
            """
        case 6:
            """
            "What object in the dungeon is haunted?"
            """
        default:
            """
            "In which room is 'Hello, Sailor!' useful?"
            """
        }
    }

    static let quizAsksAgain = """
        The voice waits, and then puts the question again.
        """

    static let quizRightAnswer = """
        "Correct," says the voice.
        """

    static let quizWrongAnswer = """
        "That is not the answer," says the voice.
        """

    static let quizNobodyAsked = """
        Nobody has asked you anything.
        """

    static let quizFailedForGood = """
        "You have had answers enough," says the voice, and does not speak again.
        The door stays shut, and nothing you do to it after this will matter.
        """

    static let quizIsOver = """
        Nothing answers. Whoever was behind this door has finished with you.
        """

    static let quizAlreadyWon = """
        The door already stands open.
        """

    static let quizWonAndTheDoorOpens = """
        "Correct," says the voice. "You may pass." The wooden door swings back
        on itself, and beyond it a corridor runs north.
        """

    static let woodenDoorWillNotBeShut = """
        The door was not opened by you and does not close for you.
        """

    static let woodenDoorWillNotBeForced = """
        The door does not move, and nothing behind it seems impressed.
        """

    // MARK: - The prison

    static let bronzeDoorInTheSlot = """
        Set in the north wall, where the cell stands against it, is a door of
        bronze.
        """

    static let cellSlotEmptyRefusal = """
        There is no cell in the slot. Through the doorway is a shaft going down
        further than you can see.
        """

    static let sundialNeedsANumber = """
        The dial takes a number from one to eight, and nothing else.
        """

    // MARK: - The Dungeon Master

    static let masterIsNotAtTheParapet = """
        Nobody is standing at the parapet to do it.
        """

    static let masterStays = """
        The Dungeon Master nods and stands where he is.
        """

    static let masterFollows = """
        The Dungeon Master nods and falls in behind you.
        """

    static let masterArrives = """
        The Dungeon Master comes in and waits.
        """

    static let masterWalksOff = """
        The Dungeon Master walks away and is gone.
        """

    static let masterNeedsADirection = """
        The Dungeon Master waits to be told which way.
        """

    static let masterWillNotGoThatWay = """
        The Dungeon Master looks at you and does not move.
        """

    static let masterSaysNothing = """
        The Dungeon Master says nothing at all.
        """

    static let masterKillsYou = """
        The Dungeon Master does not appear to move. You are dead all the same.
        """

    // MARK: - The Treasury

    static let treasuryHoard = """
        Every treasure the dungeon ever held, and a good many it did not: coin
        and plate and stone heaped up the walls and going back further than the
        light reaches.
        """
}
