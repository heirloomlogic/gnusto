/// The endgame's working lines — every refusal, every report of a thing that
/// moved, and the Dungeon Master's examination.
///
/// `Prose+Endgame.swift` holds the rooms and the objects; this holds what
/// happens to them. The split is the same one `Prose+Systems.swift` makes
/// against `Prose.swift`: one four-hundred-line `extension Prose` is a wall of
/// string constants, and two subjects read as two.
///
/// **Written fresh, all of it.** Every line in this file is case 3 of the
/// three-way rule: these are refusals and reports, and the trilogy has no
/// counterpart to any of them. The rule itself is stated on ``Prose``, and which
/// of the region's *rooms and objects* now pair with Zork III — four of them do,
/// since #184 — is settled in `Prose+Endgame.swift` and not repeated here.
extension Prose {
    // MARK: - The box, from outside

    /// `MIRIN`'s three refusals (`3actions.zil:994-1003`; `act4.231:425-429`
    /// has two of them), each a claim about the side that is actually in the
    /// way rather than about the box.
    ///
    /// The line this replaces — *"There is no opening in the side facing you."*
    /// — was printed to a player who had stepped out through the open pine end
    /// one turn earlier, which is what the 2026-08-11 round caught. The box's
    /// model is the source's and is unchanged: **the mirror is the way in**,
    /// and the pine end is a way out that shuts behind you. What was wrong was
    /// a refusal that denied the whole box had an opening while one stood
    /// open. (#233)
    ///
    /// - Parameters:
    ///   - face: the part of the box turned toward the player.
    ///   - glassIntact: whether *that* face's glass is unbroken, which decides
    ///     whether they are looking at a mirror or at the panel behind one.
    /// - Returns: the refusal.
    static func boxNoWayIn(face: BoxFace?, glassIntact: Bool) -> String {
        switch face {
        case .mirror, .farMirror:
            glassIntact ? "A mirror blocks your way." : "The panel is closed."
        case .mahogany, .pine, .none:
            "The structure blocks your way."
        }
    }

    /// One state, one line. There were two of these — one for looking at the
    /// box from a room it is not standing beside, one for trying to step into
    /// it from the same place — and they said the same thing in different
    /// words. The state is `angleOnTheBox(_:) == nil`, and every verb that
    /// meets it meets it for the same reason.
    static let boxNotBesideIt = """
        The box is somewhere else along the hallway, out of reach from here.
        """

    static let swordStopsGlowing = """
        The blue light goes out of the sword.
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

    /// The clause a face standing open adds to the three sentences below, or an
    /// empty string for a face that is shut.
    ///
    /// Both ends can stand open, and only one of them was ever described that
    /// way: `open` used to be `MIRIN`'s mirror-only question rather than
    /// ``MirrorBox/openFace(at:)``, so a pine end swung wide was reported as
    /// "a wall of pale pine". It is a fleeting state — the pine end shuts as
    /// you step out through it, and the five-turn fuse shuts it otherwise — but
    /// it is reachable by leaving through the mirror with both open, and while
    /// it lasts the room has to say so. (#233)
    ///
    /// - Parameters:
    ///   - face: the part of the box turned toward the reader.
    ///   - open: whether that part is standing open.
    /// - Returns: the clause, with a leading space, or `""`.
    private static func openFaceClause(_ face: BoxFace?, open: Bool) -> String {
        open ? " The \(openingName(face)) on this side is swung open." : ""
    }

    /// The noun for whichever part of the box is the opening, article-free so a
    /// sentence can put it where it likes. ``boxFaceName(_:)``'s sibling, and
    /// there for the same reason: the mirror-or-pine choice is one decision, and
    /// two copies of it drift.
    ///
    /// - Parameter face: the part of the box standing open.
    /// - Returns: the noun.
    private static func openingName(_ face: BoxFace?) -> String {
        face == .pine ? "pine wall" : "mirror"
    }

    /// The sentence a hallway room adds when the box is standing in the next
    /// room along it.
    ///
    /// An end-on box faces the hallway with mahogany or pine and never with a
    /// mirror, so this is the one channel an open *pine* end is seen through —
    /// and it was the one with no notion of an opening at all.
    ///
    /// - Parameters:
    ///   - northward: whether the box is up the hallway rather than down it.
    ///   - face: the part of it turned this way.
    ///   - open: whether that part is standing open.
    ///   - intact: whether both mirrors are still whole.
    /// - Returns: the paragraph.
    static func boxInTheHallway(
        northward: Bool, face: BoxFace?, open: Bool, intact: Bool
    ) -> String {
        let side = northward ? "north" : "south"
        let glass = intact ? "" : " Broken glass lies along the foot of it."
        return """
            An enormous box fills the hallway to the \(side), floor to ceiling
            and wall to wall. What faces you is
            \(boxFaceName(face)).\(openFaceClause(face, open: open))\(glass)
            """
    }

    /// And the sentence a narrow room adds, where the box is not up the hallway
    /// but a hand's breadth from your shoulder.
    ///
    /// - Parameters:
    ///   - face: the part of it turned this way.
    ///   - open: whether that part is standing open.
    /// - Returns: the paragraph.
    static func boxBesideYou(face: BoxFace?, open: Bool) -> String {
        guard open else {
            return """
                The side of the box stands beside you, close enough to touch:
                \(boxFaceName(face)).
                """
        }
        return """
            The side of the box stands beside you, and the \(openingName(face)) in it
            is swung open on a dark space within.
            """
    }

    /// Examining the box from any of the eleven rooms it can be seen from.
    ///
    /// - Parameters:
    ///   - face: the part of it turned this way.
    ///   - open: whether that part is standing open.
    /// - Returns: the description.
    static func boxFromOutside(face: BoxFace?, open: Bool) -> String {
        """
        A rectangular box the full height of the hallway, longer than it is
        wide. The side toward you is
        \(boxFaceName(face)).\(openFaceClause(face, open: open))
        """
    }

    // MARK: - The box, from inside

    /// The mirror standing open, naming what shows through it.
    ///
    /// The same repair as ``boxPineSwingsOpen(onto:)`` and for the same reason:
    /// "the hallway" is a constant, and the mirror faces a narrow room whenever
    /// the box stands square to the channel. (#233)
    ///
    /// - Parameter room: the name of the room beyond the gap, or `nil` for a
    ///   diagonal, where it opens on a corner.
    /// - Returns: the line.
    static func boxMirrorStandsOpen(onto room: String?) -> String {
        "One of the mirrors stands open, and the \(beyond(room)) shows through the gap."
    }

    /// What is on the far side of an opening: the room it faces, or the corner a
    /// diagonally-standing box presents instead. Three lines say this, and they
    /// used to spell the corner out three times.
    ///
    /// - Parameter room: the room's name, or `nil` on a diagonal.
    /// - Returns: the noun phrase, article-free.
    static func beyond(_ room: String?) -> String {
        room ?? "corner where two walls meet"
    }

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

    /// One end stands open and the player asked for the other. See
    /// ``boxNoWayOut``, which is the line for a box that really is shut.
    static let boxThatSideIsShut = """
        That wall of the box is shut.
        """

    /// The wall is open and the box is standing on a diagonal, so the gap gives
    /// on a corner. ``boxPineSwingsOpen(onto:)`` says the same thing one turn
    /// earlier, with the same noun phrase.
    static let boxOpensOnACorner = """
        The opening gives on the \(beyond(nil)), and there is no floor beyond it
        to step out onto.
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

    /// The pine end coming open, naming what is actually on the far side of it.
    ///
    /// It used to say "the hallway" whatever the box was standing across: at
    /// the opening bearing the pine end faces *east*, into a narrow room, which
    /// is where the 2026-08-11 round caught it. The mahogany end points along
    /// the channel and the pine end opposite it, so which room the pine end
    /// faces is a question about ``MirrorBox/bearing``, not a constant.
    ///
    /// - Parameter room: the name of the room the pine end faces, or `nil` when
    ///   the box sits at a diagonal and it faces a corner rather than a room.
    /// - Returns: the line.
    static func boxPineSwingsOpen(onto room: String?) -> String {
        // The corner branch keeps a clause of its own — there is no way past a
        // corner, and a player who has just opened a wall onto one wants telling.
        let past = room == nil ? ", and no way past them" : ""
        return "The pine wall swings out on its hinges. Beyond it is the \(beyond(room))\(past)."
    }

    static let boxPineSwingsShut = """
        The pine wall swings to and the wooden bar drops across it.
        """

    /// Trilogy-verbatim (`3actions.zil:958`), and the half of `MIROUT` this game
    /// did not have. Without it the pine end stayed open behind the player, so
    /// the box could be stood next to with a wooden wall swung wide that would
    /// not let anybody back in — the state the 2026-08-11 round found and the
    /// source never reaches. (#233)
    static let boxPineSwingsShutBehindYou = """
        As you leave, the door swings shut.
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

    static let treasuryMap = """
        The Great Underground Empire drawn whole, in a hand that had all the
        time it needed. Every trove is on it. So is every place worth standing
        to look at something, which is the part somebody cared about.
        """

    static let treasuryDesk = """
        A writing desk with a controlling interest in FrobozzCo International
        squared up on it, the boat company and all the rest of it underneath.
        """
}
