/// Prose for the Endgame: the Tomb of the Unknown Implementer and the crypt
/// behind it, the stair and the stone room below, the small room with the beam
/// across it, the mirror box and the hallway it rides, the Guardians of Zork,
/// the Dungeon Master's door, the rotating prison, and the Treasury of Zork.
///
/// The three-way rule, and the rule for which file a line goes in, are stated
/// once on ``Prose``.
///
/// **Nearly every line here is written fresh, under case 3 of that rule**, and
/// four are not. Which four is a question this file used to get wrong.
///
/// The atlas paired nothing whatever against Zork III until #184 — the string
/// did not appear once in the generated document — so this region read as having
/// no trilogy counterpart, and said so. It has one: Zork III is where the
/// trilogy put its endgame, its mirror box and its Dungeon Master. With the
/// generator fixed, ten of these rooms and fifteen of their objects pair.
///
/// Most of them still change nothing. A pair only reaches the prose rule if
/// **both** sources carry text to set side by side, and for the corridors' twins,
/// the mirror box, the sundial and the panels only one does — the mainframe keeps
/// that text in a room function rather than in `dung.355`. Those stay case 3, and
/// the mainframe's own wording stays unavailable to borrow regardless, because no
/// licence grant has been located for the 1981 MDL. What crosses over is what each
/// string has to *mean*: which exits a room has, which state an object is in, and
/// which of them kills you.
///
/// The four that do reach the rule are ``dungeonMasterFirstSight`` (case 1,
/// verbatim), ``eastCorridor`` and ``westCorridor`` (case 2), and ``treasury``
/// (case 2). Each says so where it stands. The corridors also cost this file a
/// correction: all four of them called the walls bare stone, and both sources
/// call them marble. See `FIDELITY.md`, the Dungeon section.
extension Prose {
    // MARK: - The Tomb of the Unknown Implementer

    static let tomb = """
        This is a tomb. Four poles stand upright in the floor of it, and on the
        top of each pole a head has been mounted. A bunch of empty Coke bottles
        and a stack of line-printer listings lie about the floor between them.
        A passage leads west.
        """

    /// The Tomb's one changing sentence. The crypt to the north is the whole
    /// reason to be in this room, and what stands in the way of it does not
    /// stay standing.
    static let tombCryptShut = """
        To the north is a crypt, shut off by a slab of marble with no handle on
        it anywhere.
        """

    static let tombCryptOpen = """
        To the north is a crypt, and the marble door of it stands open.
        """

    static let tombHeads = """
        Four heads, one to a pole, and each of them belonged to somebody who
        had a hand in the building of this dungeon. They look down at you
        without much interest.
        """

    static let tombCokeBottles = """
        Empty Coke bottles, a great many of them, standing where they were last
        set down. They are the sediment of a programming session that went on
        for years.
        """

    static let tombListings = """
        A thick stack of line-printer output, fanfold and unburst, printed
        close in a code that nobody is ever going to read again.
        """

    static let tombListingsText = """
        You turn up a page of listing so dense that the lines have run together
        into grey. One line near the middle of it is still faintly legible, and
        it means nothing whatever.
        """

    /// The death the heads deal for any liberty taken with them. The source
    /// sweeps the player's valuables and the room's into a case in the living
    /// room; that fact crosses over, the sentences do not.
    /// The death the heads deal. It does **not** name the large case the
    /// mainframe conjures in the Living Room: no such object is declared here,
    /// and a line that promises one sends a resurrected player to look for
    /// something that is not there.
    static let tombHeadsCurse = """
        The heads turn on their poles, all four together, and take you in. A
        low sound starts somewhere under the floor and does not stop. Everything
        of any worth you were carrying, and everything of any worth lying about
        this tomb, is lifted quietly away and gone. The sound goes on after you
        have stopped hearing it.
        """

    /// Takes an already-rendered noun phrase, article and all, the way every
    /// other prose function in this game does. It is used in the middle of the
    /// sentence, so no capitalisation is wanted at the call site.
    static func tombBottlesSmash(_ what: String) -> String {
        """
        The bottles shatter, and \(what) shatters with them. There is glass
        over everything.
        """
    }

    // MARK: - The crypt door

    static let cryptDoorClosed = """
        A slab of marble set into the north wall, taller than you are and a
        great deal heavier. There is no handle on it of any kind.
        """

    static let cryptDoorOpen = """
        The marble slab stands away from the wall, and the crypt is open behind
        it.
        """

    static let cryptDoorOpens = """
        The door must weigh a ton, but it opens easily.
        """

    /// Printed the instant before the tomb kills the player for trying the door
    /// early. It is the heads objecting, not the engine refusing.
    static let cryptDoorRefuses = """
        The door is not yours to open yet, and this tomb knows it. On their
        poles, all four heads come around to look at you at once.
        """

    // MARK: - The crypt

    static let crypt = """
        This is a small crypt, empty of everything but air that has not moved
        in a long while. The door to the south is the only way out.
        """

    static let cryptDark = """
        The dark closes over the crypt, and you have the distinct sense of
        having been noticed.
        """

    // MARK: - The entry sequence

    static let heraldArrives = """
        A cloaked figure is standing beside you. There is no face inside the
        hood, and it made no sound whatever coming in.

        "You are one of the chosen of Zork," it says. "What is left to have is
        not kept in this dungeon, and the way to the Dungeon Master lies
        through the Tomb." It moves off without walking, and then it is not
        there.
        """

    /// The long paragraph three turns after the crypt is shut and dark. The
    /// source hands the player a word here that will bring them back; **this
    /// game has no way back at all.** The crypt is one-way, `temple` and
    /// `treasure` answer ``Prose/graniteWordInert`` everywhere past it, and the
    /// endgame's map has no route into the main dungeon — so the line used to
    /// promise a return the game cannot keep, which is the same defect as
    /// naming a word the parser does not answer. It now says the thing the
    /// game does keep: the dungeon behind them is finished with. (#286)
    static let cryptTransition = """
        A voice that belongs to nobody speaks out of the dark. "You have passed
        the first test," it says. "The dungeon behind you has nothing further
        to teach, and what remains is not kept there. You will not be going
        back to it, and you will not want to." The floor is not under you for a
        moment. When it is again, you are standing somewhere else entirely,
        with a lantern in one hand and a sword in the other and nothing else
        about you at all.
        """

    static let cryptFuseRearms = """
        Whatever was about to happen does not happen in this light.
        """

    // MARK: - Top of Stairs and Stone Room

    static let topOfStairs = """
        This is a rough landing at the head of a long flight of stairs. The
        stairs run down and to the north, into a dark the light here does not
        reach the bottom of.
        """

    static let stoneRoom = """
        This is a room of dressed stone, laid so well that the joints hardly
        show. Set into one wall at the height of your chest is a large red
        button. A passage leads north, and the stairs go up to the south.
        """

    static let endgameStairs = """
        A long flight of stone steps, worn hollow in the middle of each tread by
        feet that are not yours.
        """

    static let stoneRoomButton = """
        A large button of red enamel, set flush into the stone and worn smooth
        in the middle.
        """

    static let buttonPressedBeamBroken = """
        The button clicks, and somewhere north of you something heavy begins to
        move.
        """

    static let buttonPressedBeamIntact = """
        The button goes in and comes straight back out again.
        """

    // MARK: - The Small Room and the beam

    /// `MREYE`. Named `endgameSmallRoom` rather than `smallRoom` because the
    /// Bank of Zork has a Small Room too, and ``Prose/smallRoom`` is already
    /// that one.
    static let endgameSmallRoom = """
        This is a small room, bare to the walls. A red beam of light crosses it
        just above the floor, from one wall to the other. A passage leads
        north, and stairs go up to the south.
        """

    static let redBeam = """
        A thread of red light no thicker than a wire, running wall to wall a
        hand's breadth above the floor. It gives nothing to see by.
        """

    static let redBeamBroken = """
        The beam stops short against what is lying on the floor, and does not
        reach the far wall.
        """

    // MARK: - The hallway and the narrow rooms

    /// One description for all five hallway rooms, as the source has one for
    /// all five. It names nothing that would be true of only one of them.
    static let mirrorHallway = """
        This is a long hallway, narrow, running north and south. A channel is
        cut down the middle of the floor along the whole length of it, and
        nothing else in it at all.
        """

    static let narrowRoom = """
        This is a cramped space off the side of the hallway, barely wide enough
        to stand in and not wide enough to turn around in with any comfort.
        """

    static let stoneChannel = """
        A groove cut in the stone, running the length of the floor, straight
        and about as wide as your hand.
        """

    // MARK: - The mirror box, from outside

    static let boxWoodenWall = """
        A wall of wood blocks your way.
        """

    static let boxMirrorWall = """
        A large mirror blocks your way.
        """

    static let boxBrokenMirrorWall = """
        A large mirror, broken to pieces, blocks your way.
        """

    static let boxSlipsPast = """
        You get past the end of the box with an inch to spare, and come out in
        the narrow room beside it.
        """

    static let boxFromOutside = """
        An enormous rectangular box stands in the hallway, filling it wall to
        wall and standing a good deal taller than you do. Its ends and its
        sides are not made of the same thing.
        """

    // MARK: - Inside the mirror box

    static let insideMirror = """
        You are inside the box. One end of it is mahogany and the other is
        pine. The two long sides are mirrors, floor to ceiling, and set into
        the frame between them are four panels, coloured red, yellow, white and
        black.

        A pole hangs in a bracket overhead. Below the pole a short bar of iron
        in the shape of a T is fixed to the floor, and beside that a bar of
        plain wood. Mounted where it can be seen from anywhere in the box is an
        arrow, which turns as the box turns.
        """

    static let mahoganyEnd = """
        The end wall of the box, panelled in mahogany, dark and close-grained.
        There is no opening in it.
        """

    /// The shut half. "There is no opening in it." is a claim about
    /// ``MirrorBox/pineOpen``, and this was a static trait — so the wall the
    /// player had just swung open described itself as solid, which is the class
    /// #235 repaired seven other sites of. See ``pineEndOpen``. (#233)
    static let pineEnd = """
        The end wall of the box, panelled in pine, pale and full of knots.
        There is no opening in it.
        """

    /// The open half of ``pineEnd``.
    static let pineEndOpen = """
        The end wall of the box, panelled in pine, pale and full of knots. It
        stands swung open on its hinges, and there is a way through.
        """

    static let mirrorPanelIntact = """
        A mirror the height of the box and the length of one side of it,
        without a mark anywhere on it. You look tired.
        """

    static let mirrorPanelBroken = """
        The mirror is in pieces, and what is left in the frame gives back
        nothing you would care to recognise.
        """

    /// The mirror standing open, naming the room on the other side of it rather
    /// than always "the hallway" — the box faces a narrow room whenever it
    /// stands square to the channel. Same repair as
    /// ``boxPineSwingsOpen(onto:)``. (#233)
    ///
    /// - Parameter room: the name of the room beyond it, or `nil` for a
    ///   diagonal.
    /// - Returns: the description.
    static func mirrorPanelOpen(onto room: String?) -> String {
        """
        The mirror stands open on its hinge, and the \(beyond(room)) is on the
        other side of it.
        """
    }

    /// The colour arrives as a bare word, so the sentence supplies its own
    /// article.
    static func colouredPanel(_ colour: String) -> String {
        """
        A panel of \(colour) enamel set into the frame of the box, a hand's
        breadth square and standing a little proud of the wood.
        """
    }

    static let poleRaised = """
        The pole is up in its bracket, well clear of the floor.
        """

    static let poleOnFloor = """
        The pole is down, its foot standing on the floor of the box with
        nothing under it.
        """

    static let poleInChannel = """
        The pole is down, and its foot has gone into the channel cut in the
        floor.
        """

    static let poleInHole = """
        The pole is down, and its foot has gone into the hole in the floor and
        sits firm there.
        """

    static let tBar = """
        A short bar of iron in the shape of a T, fixed to the floor of the box
        and polished where hands have been on it.
        """

    static let woodenBar = """
        A bar of plain wood, fixed across the frame at the height of your
        chest. It does not give at all.
        """

    static let compassArrow = """
        An arrow mounted so that it turns as the box turns, and points steadily
        at one wall of it.
        """

    /// The bearing arrives as a word, "north" or "northwest".
    static func boxCompassReading(_ bearing: String) -> String {
        "The arrow is pointing \(bearing)."
    }

    // MARK: - The Guardians of Zork

    /// The view from one room south, which is the only frame this line can ever
    /// print in. ``DungeonEndgame/guardians`` stands in `hallwayC`, the statues
    /// themselves are a room further up, and `hallwayG` and the narrow rooms
    /// beside it are all ``DungeonEndgame/guardedRooms`` — every one of them
    /// kills on arrival. So a living player looks north at them and never once
    /// stands between them, and the sentence says where they are rather than
    /// putting the reader in the middle of them. (#286)
    static let guardians = """
        Two statues stand in the hallway to the north of you, one at either side
        of it, and each of them is twice your height. Each holds a weapon.
        Neither is stone and neither is alive, and from this far down the
        hallway they have taken no notice of you at all.
        """

    static let guardiansKill = """
        You are not two steps between them before the nearer statue moves. It
        is very quick for its size.
        """

    static let guardiansCrush = """
        The statues take hold of the box as it comes level with them and close
        their hands. The box goes to splinters, and so do you.
        """

    static let guardiansStatueAttack = """
        You strike the statue. The statue attends to you, briefly.
        """

    /// The two rungs of the warning, as the daemon announces them. Neither says
    /// "in your hand" any more: the daemon reports a sword the player can
    /// *see*, which includes one lying on the floor of the room they are
    /// standing in. See ``Dungeon/endgameTimers``.
    static let swordGlowsBrightly = """
        The sword has come up to a fierce blue light.
        """

    static let swordGlowsFaintly = """
        The sword shows a faint blue edge.
        """

    /// And the same two rungs in the examine channel, which is a description
    /// rather than an event and so is not the same sentence. Appended to
    /// ``Prose/sword`` by ``Dungeon/swordGlowRules``, because the blade is
    /// ``DungeonHouse``'s and the glow is this region's.
    ///
    /// Written fresh, but the channel is the source's: `SWORD-FCN`
    /// (`1actions.zil:2437`) answers EXAMINE with the glow too. It *replaces*
    /// the description with it; this appends, because the mainframe's blade has
    /// a description worth keeping.
    static let swordExaminedBright = """
        It is burning with a fierce blue light.
        """

    static let swordExaminedFaint = """
        A faint blue edge runs the length of it.
        """

    // MARK: - The Dungeon Entrance and the Narrow Corridor

    static let dungeonEntrance = """
        This is a large room, bare and square. In the north wall is a massive
        wooden door. Passages lead away to the south.
        """

    static let woodenDoorClosed = """
        A door of heavy wooden planks, shut fast. There is no lock on it that
        you can see, and no handle either.
        """

    static let woodenDoorOpen = """
        The wooden door stands open, and a corridor runs away north beyond it.
        """

    static let narrowCorridor = """
        This is a narrow corridor running north. The wooden door is behind you
        to the south.
        """

    /// `MASTE`. **Case 1 — the trilogy's line, verbatim.** The one string in this
    /// region where the two sources are `identical`, so there is nothing to
    /// decide: `dung.355` and Zork III's `DUNGEON-MASTER` write it the same way,
    /// word for word.
    ///
    /// It also happens to be the right shape. An actor's listing paragraph prints
    /// on **every** look, forever, so it has to be true of the turn he walks in
    /// behind you as well as of the turn you first see him — and a man leaning on
    /// his staff is as true the fifth time as the first. The staff is a noun this
    /// prints, so he answers to it.
    static let dungeonMasterFirstSight = """
        The dungeon master is quietly leaning on his staff here.
        """

    /// The *examine* channel, which stays case 3: ZIL gives `DUNGEON-MASTER` no
    /// text but the listing line above, so there is no counterpart to weigh.
    static let dungeonMaster = """
        An old man in a robe of no particular colour. He is in no hurry at all,
        and gives every sign of never having been.
        """

    // MARK: - The prison corridors

    // The four of them are marble, and until #184 all four said bare stone.
    // Nothing was checked wrongly; the check could not be made. `ECORR` and
    // `WCORR` carry their text in `dung.355`, which calls the walls polished
    // marble, and Zork III agrees — but the atlas paired nothing against Zork III,
    // so that line was never set against these and the rooms went into the world
    // in a stone the source does not use. `NCORR` and `SCORR` are described from
    // a room function instead (`act4.231`, `SCORR-ROOM`: *the walls of the
    // corridor are marble*), which is why they are still case 3 — but they are
    // the same four walls, and they read as one place.

    static let southCorridor = """
        This is a marble corridor running east and west. A passage leads south,
        and there is a doorway cut in the wall to the north.
        """

    static let northCorridor = """
        This is a marble corridor running east and west. A passage leads north
        to a parapet, and there is a doorway cut in the wall to the south.
        """

    /// **Case 2 — the trilogy's line, checked against the exit table.** Zork III
    /// says it widens as it turns west at its northern and southern ends, and the
    /// mainframe's table agrees: `ECORR`'s only exits are north to `NCORR` and
    /// south to `SCORR`, and both of those run east–west, so both ends do turn
    /// west. Nothing to adapt.
    static let eastCorridor = """
        This is a hall with polished marble walls. It widens slightly as it
        turns west at its northern and southern ends.
        """

    /// **Case 2**, and `eastCorridor`'s mirror image in both sources — the same
    /// sentence with the compass reversed, checked the same way.
    static let westCorridor = """
        This is a hall with polished marble walls. It widens slightly as it
        turns east at its northern and southern ends.
        """

    static let prisonMarble = """
        Polished to a face that gives your own back to you, dimly, and joined so
        well you cannot find where one slab stops. Whoever cut them was not in a
        hurry either.
        """

    // MARK: - The parapet and the machinery under it

    static let parapet = """
        This is a ledge over a great pit, and nothing shows at the bottom of
        it. Set into a block of stone at the edge is a sundial, and beside the
        sundial a large button. A stair leads down to the south.
        """

    static let parapetPit = """
        A shaft going down out of the light, wider than the room you are
        standing in and showing no bottom at all. Something in it turns from
        time to time.
        """

    static let sundial = """
        A dial with a single pointer, and the numbers one through eight set
        around the face of it.
        """

    /// One numeral, examined. All eight share it: there is nothing to say about
    /// the four that is not equally true of the seven.
    static let sundialNumeral = """
        A numeral cut into the stone of the dial's face, worn shallow and still
        legible.
        """

    /// The number arrives as a word, "four" rather than "4".
    static func sundialReading(_ number: String) -> String {
        "The pointer stands at \(number)."
    }

    /// Turning the dial. Whose hand it is matters: the whole prison turns on
    /// the Dungeon Master doing it from a room the player is not standing in,
    /// and "under your hand" would be false in exactly the sentence the puzzle
    /// is solved by.
    ///
    /// - Parameters:
    ///   - number: the setting, as a word.
    ///   - byHand: whether the player turned it themselves.
    /// - Returns: the line.
    static func sundialSet(_ number: String, byHand: Bool) -> String {
        byHand
            ? """
            The dial turns stiffly under your hand, and the pointer comes to
            rest at \(number).
            """
            : """
            Somewhere above you the dial turns stiffly, and the pointer comes
            to rest at \(number).
            """
    }

    static let parapetButton = """
        A large button beside the sundial, set into the same block of stone and
        worn down in the middle of it.
        """

    static let carouselTurns = """
        Below the parapet a great deal of machinery begins to turn. It runs,
        and slows, and stops, and somewhere under you a cell has come around
        into the slot.
        """

    static let carouselTurnsUnseen = """
        The walls shake, machinery runs somewhere very close, and then
        everything is still again.
        """

    /// What the doorway shows when the cell in the slot is one of the seven
    /// without a bronze door in it: the blank back of it, and no way on.
    static let cellSlotFilled = """
        Through the doorway is the back wall of a cell, dressed stone, with
        nothing in it.
        """

    static let cellSlotEmpty = """
        Through the doorway there is nothing at all: no floor, no walls, and no
        bottom to it.
        """

    // MARK: - The cells

    static let prisonCell = """
        This is a bare cell, stone on every side of you. There is a doorway in
        the north wall. The wall to the south is solid.
        """

    static let prisonCellBronze = """
        This is a bare cell, stone on every side of you. There is a doorway in
        the north wall, and set into the wall to the south is a door of bronze.
        """

    static let bronzeDoorClosed = """
        A door of bronze, green with age, with no handle on it and no keyhole.
        """

    static let bronzeDoorOpen = """
        The bronze door stands open, and there is light on the other side of
        it.
        """

    static let cellDoor = """
        A heavy door of plain iron, hung in the doorway of the cell. It swings
        freely enough.
        """

    static let cellRidesOut = """
        The floor takes hold and the whole cell begins to move. The doorway
        swings off the slot, and there is rock on the other side of it going
        past. The cell turns for a while, and slows, and comes to a stop.
        """

    /// Reworded. This was written for the source's arrangement, where the
    /// bronze door appears only after the ride, and it announced as a
    /// revelation — *"where there was stone before"* — a door the game had
    /// been describing in that same wall for as long as cell four sat in the
    /// slot. It also called the north doorway "the doorway you came in by",
    /// and the player may well have come in through the bronze one.
    ///
    /// The **door** is where the source puts it and stays there: `ODOOR`
    /// starts in `SCORR` with `CELL SOUTH → SCORR` and `SCORR NORTH → CELL`
    /// both running through it (`dungeon-atlas.md`), and
    /// ``throughTheSouthDoorway``'s bronze branch is the prison's only clue
    /// for which of the eight cells is cell four. Gating the door on the ride
    /// would have contradicted the atlas twice and deleted the puzzle's one
    /// hint to make a sentence true. The sentence is what moves. (#329)
    static let winningCell = """
        The cell has come to rest. The north doorway is a locked door now, with
        the rock of the shaft hard against the back of it, and the only way out
        of here is the door of bronze in the south wall.
        """

    /// The losing rest position. It says what is true and leaves the player to
    /// draw the conclusion, which is the register the rest of the region keeps.
    static let lostCell = """
        The cell has come to rest against solid rock. Where the doorway was
        there is stone, and the door behind you has locked itself. There is
        nothing here to open, nothing to push, and no way on.
        """

    static let lockedCellDoor = """
        The door is locked, and there is nothing on this side of it to work
        with.
        """

    // MARK: - The Treasury of Zork

    static let treasuryDoorCloses = """
        The bronze door swings to behind you and settles into its frame.
        """

    /// **Case 2 — the trilogy's line, adapted.** Both sources furnish this room
    /// rather than heaping it: chests of jewels, mountains of zorkmids, paintings,
    /// statuary, curios, an annotated map of the Empire on one wall, and FrobozzCo
    /// stock certificates on a desk. The version written before #184 had an
    /// undifferentiated pile, which is a poorer image and is not what either source
    /// says. Nothing in the trilogy line contradicts the mainframe map — `NIRVA` has
    /// nought exits in both — so it is taken, with Zork III's paragraph markers
    /// dropped and the sealed-room beat kept, since that is this game's ending and
    /// not the trilogy's.
    static let treasury = """
        This is a large room, richly appointed in a style that bespeaks exquisite
        taste. To judge from its contents, it is the ultimate storehouse of the
        wealth of the Great Underground Empire. There are chests containing
        precious jewels, mountains of zorkmids, rare paintings, ancient statuary
        and beguiling curios. On one wall is an annotated map of the Empire,
        showing the locations of various troves of treasure and of many superior
        scenic views. On a desk at the far end of the room are stock certificates
        representing a controlling interest in FrobozzCo International.

        There is no door in any wall, no passage, no stair, and no opening of
        any kind.
        """

    static let treasuryEnding = """
        "It is yours," says the Dungeon Master, who is not in the room. "All of
        it, and the place it came out of, and the keeping of both." The light
        in this room is coming from nowhere you can point to, and has been all
        along. You are Master of the Dungeon.
        """
}
