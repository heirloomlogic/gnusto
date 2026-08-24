/// Prose for the well, the tea party and the robot (``DungeonAlice``) — the
/// nine rooms `dung.355` gathers under one heading: the Circular Room at the
/// bottom of the well, the Top of Well, the Tea Room, the Posts Room and the
/// Pool Room beneath the table, the Low Room, the Machine Room, the Dingy
/// Closet and the Cage.
///
/// The three-way rule, and the rule for which file a line goes in, are stated
/// once on ``Prose``.
///
/// `BWELL`, `TWELL`, `BUCKE`, `ROBOT` and `RBTLB` are `identical` entries in
/// `docs/games/dungeon-prose-comparison.md`, so those five are the trilogy's
/// lines verbatim. `ALICE`, `ALISM` and `CAGED` are `minor`; the first two are
/// adapted anyway, for the reason milestones 3 and 4 both hit — the bucket
/// measures string distance and not whether the room is the same room, and both
/// of those rooms enumerate exits in prose. `CAGED`'s one sentence is taken as
/// it stands. `ALITR` and `CAGER` are `substantial` and differ because the
/// puzzle differs, so each keeps the voice and loses the wrong facts. Everything
/// else here is written fresh.
extension Prose {
    // MARK: - The well

    /// Verbatim — `BWELL` is `identical`, exits and all.
    static let circularRoom = """
        This is a damp circular room, whose walls are made of brick and mortar.
        The roof of this room is not visible, but there appear to be some
        etchings on the walls. There is a passageway to the west.
        """

    /// Verbatim — `TWELL` is `identical`. The pun is the source's.
    static let topOfWell = """
        You are at the top of the well. Well done. There are etchings on the
        side of the well. There is a small crack across the floor at the
        entrance to a room on the east, but it can be crossed easily.
        """

    /// The etchings at the bottom of the shaft: a ring of letters with the
    /// damp through most of it. Written fresh — the source's own figure is a
    /// piece of 1981 MDL typography, and this game reproduces none of those —
    /// but it says what the source's says, because what it says is a hint and
    /// a hint is structure.
    static let etchingsBelow = """
        Letters are cut round the brickwork in a ring, and the damp has had the
        better half of them:

            . . . o r o z . . .
            .                 .
            .    ? A G I ?    .
            .    ? E ? L ?    .
            .                 .
            . . . m p a n . . .
        """

    /// And the same ring at the top of the shaft, where the air is dry and the
    /// whole of it can be read.
    static let etchingsAbove = """
        The same ring of letters, and up here in the dry air every one of them
        holds:

            f r o b o z z i c a
            a                 n
            l    M A G I C    d
            l    W E L L      c
            e                 o
            r a m p a n t l y m
        """

    /// Written fresh. The Top of Well's last sentence puts a crack across the
    /// floor at the east doorway, and the ring of letters was answering for
    /// both words. (#286)
    static let topOfWellCrack = """
        A hairline in the stone, running the width of the doorway east. You
        could step over it without noticing you had.
        """

    /// Verbatim — `BUCKE` is `identical`.
    static let bucketFirstSight = """
        There is a wooden bucket here, 3 feet in diameter and 3 feet high.
        """

    static let bucket = """
        A wooden bucket, banded with iron, big enough to sit in and heavy
        enough that nothing you could do would lift it.
        """

    static let bucketAlreadyUp = "The bucket is already at the top of the well."

    static let bucketRises = """
        The bucket rises, smoothly and without any fuss at all, and stops level
        with the lip of the well.
        """

    static let bucketDescends = """
        The water drains away through the boards, and the bucket sinks gently
        back to the bottom of the well.
        """

    static let bucketBoardFirst = """
        Whatever the bucket is going to do, it will do with you in it or not at
        all — and you would rather be in it.
        """

    static let bucketGoesNowhereElse = """
        The bucket goes up and it goes down, and those are the only two things
        it has ever done.
        """

    static let bucketNeedsWater = """
        Nothing happens. Whatever raises the bucket, it is not hope.
        """

    static let bucketRefusesToBeTaken = """
        The bucket is fixed to whatever it is that lifts it.
        """

    static let bucketDown = """
        It is a long way down, and the bucket is the only way anyone has ever
        gone.
        """

    static let bucketWalls = "The walls cannot be climbed."

    // MARK: - The Tea Room

    /// Adapted. `ALICE` is `minor`, and the trilogy's version drops the exits;
    /// the mainframe's names both of them and the mouse hole, which is the
    /// whole point of the room.
    static let teaRoom = """
        This is a small square room, in the center of which is a large oblong
        table, no doubt set for afternoon tea. It is clear from the objects on
        the table that the users were indeed mad. In the eastern corner of the
        room is a small hole, no more than four inches high. Passageways lead
        away to the west and the northwest.
        """

    static let teaTable = """
        A long table laid for a great many more guests than ever came, and laid
        by somebody who had lost the thread of what a table is for.
        """

    static let mouseHole = """
        A hole four inches high at the foot of the eastern wall. Only a mouse
        could get in there.
        """

    static let mouseHoleRefused = "Only a mouse could get in there."

    // MARK: - The cakes

    static let eatMeCakeFirstSight = """
        There is a piece of cake here with the words 'Eat-Me' on it.
        """

    static let eatMeCake = """
        A piece of cake the size of a fist, with EAT-ME piped across it in a
        confident hand.
        """

    static let icedCakeTooSmallToRead = """
        There is writing on the icing, but it is far too small to make out.
        """

    static func icedCake(_ colour: String) -> String {
        "A piece of cake with \(colour) icing, and something written on it."
    }

    static func icedCakeFirstSight(_ colour: String) -> String {
        "There is a piece of cake with \(colour) icing here."
    }

    static let blueIcingWriting = """
        Now that you are the size of a mouse, the icing is a signboard. It
        reads: EVAPORATE.
        """

    static let orangeIcingWriting = """
        The icing reads, in the same confident hand: ENLARGE.
        """

    static let redIcingWriting = """
        The icing reads: EVAPORATE ME — and beneath, smaller: NOT YOU.
        """

    static let eatMeShrinks = """
        You take a bite, and the room heaves upward around you. The table
        becomes a roof, its legs become posts, and you are standing on a floor
        that has grown into a plain.
        """

    static let eatMeNotHere = """
        You take a bite. It is very good cake, and nothing else happens.
        """

    static let orangeCakeGrows = """
        The floor drops away beneath you, the posts shrink to table legs, and
        you are standing in the Tea Room at your proper size, feeling faintly
        ridiculous.
        """

    static let orangeCakeNoRoom = """
        Something tells you that growing to full size in here would be the last
        thing you ever did. You put the cake away.
        """

    static let blueCakeKills = """
        The blue icing tastes of nothing at all for a moment, and then of every
        chemistry set ever sold. You have time to regret it.
        """

    static let cakeThrownNowhere = """
        The cake lands, and lies there being cake.
        """

    static let poolEvaporates = """
        The cake strikes the surface and vanishes. The whole depressed half of
        the room goes up at once in a column of steam, and when it clears the
        floor is bare, cracked, and not quite empty.
        """

    static let poolAlreadyGone = """
        There is nothing left in the depression to evaporate.
        """

    // MARK: - The Posts Room and the Pool Room

    /// Adapted. `ALISM` is `minor` and the two versions run together for a
    /// sentence and a half; the mainframe's names the passage east and the
    /// drop on two sides, and this room's exit table is the mainframe's.
    static let postsRoom = """
        This is an enormous room, in the center of which are four wooden posts
        delineating a rectangular area, above which is what appears to be a
        wooden roof. In fact, all objects in this room appear to be abnormally
        large. To the east is a passageway. There is a large chasm on the west
        and the northwest.
        """

    static let posts = """
        Four posts of dressed wood, each the thickness of an old tree, holding
        up a roof you could not see the far edge of.
        """

    static let postsChasm = """
        The floor simply stops, and a long way below it starts again.
        """

    static let postsChasmRefused = "There is a chasm too large to jump across."

    /// Adapted. `ALITR` is `substantial`, and the comparison names this as the
    /// worked example of why: the trilogy changed what leaks from the ceiling.
    /// The mainframe's is the tea, gone over, and the room is the mainframe's.
    static let poolRoom = """
        This is a large room, one half of which is depressed. A steady brown
        rope of goop falls from a leak in the ceiling into the depression. The
        only exit is to the west.
        """

    static let poolRoomDrained = """
        This is a large room, one half of which is depressed. The steam took the
        leak with it, and the depression under the dry crack in the ceiling is
        bare and cracked and empty. The only exit is to the west.
        """

    static let poolOfSewage = """
        A brown pool, thick and slow, with a skin on it. Whatever it was once,
        it was warm and it was served in cups.
        """

    static let poolLeak = """
        A crack in the ceiling far overhead, letting the goop through a drop at
        a time and never quite stopping.
        """

    /// The same crack once the steam has taken the leak with it, which is what
    /// ``poolRoomDrained`` says the room now looks like.
    static let poolLeakDry = """
        A crack in the ceiling far overhead, dry now, with a brown stain
        running away from it in both directions.
        """

    static let poolLeakOutOfReach = """
        The ceiling here is a very long way up.
        """

    static let flaskFirstSight = """
        A stoppered glass flask with a skull-and-crossbones marking is here.
        The flask is filled with some clear liquid.
        """

    static let flask = """
        A heavy glass flask, stoppered and sealed with wax. The label is a skull
        and crossbones, and nothing else.
        """

    static let flaskOpened = """
        The stopper comes away, the clear liquid goes to vapour in a breath, and
        the vapour goes into you.
        """

    static let spicesFirstSight = "There is a tin of rare spices here."

    static let spices = """
        A flat tin, sealed, and still holding whatever was worth sealing it for.
        It smells, faintly and through metal, of somewhere hot.
        """

    // MARK: - The Low Room and the robot

    static let lowRoom = """
        This is a room with a very low ceiling, so low that walking upright is
        out of the question. Ways out lead off in every direction, all of them
        the same height and all of them the same dark.
        """

    static let lowRoomCeiling = """
        Rock, four feet off the floor, and no seam or joint anywhere in it.
        """

    /// Verbatim — `ROBOT` is `identical`.
    static let robotFirstSight = "There is a robot here."

    static let robot = """
        A robot rather taller than the ceiling should allow, standing with the
        patience of something that has been standing a long time. Its treads
        are clean. Whoever unpacked it never got round to reading the sheet
        that came with it.
        """

    /// Verbatim — `RBTLB` is `identical`.
    static let robotPaperFirstSight = "There is a green piece of paper here."

    static let robotPaper = """
        A green sheet, printed on one side.
        """

    /// The instruction sheet. Written fresh: the mainframe's own sheet is MDL
    /// prose, and its example syntax is not this engine's anyway.
    static let robotPaperText = """
            !!!!  FROBOZZ MAGIC ROBOT COMPANY  !!!!

        Hello, Master!

        I am a late-model robot, trained to perform simple household duties
        and one or two that are not.

        To set me a task, address me by name and say what you want done:

            ROBOT, GO NORTH
            ROBOT, LIFT THE CAGE

        I am not warranted for any purpose whatsoever.

                                       At your service!
        """

    static let robotWalks = """
        The robot turns on its treads and clanks away.
        """

    static let robotArrives = """
        The robot clanks in and stops, waiting.
        """

    static let robotCannotGoThatWay = """
        The robot's treads grind against the rock, and it stays where it is.
        """

    static let robotNeedsADirection = """
        The robot waits to be told which way.
        """

    static let robotIsOutOfEarshot = """
        Nothing answers. Wherever the robot is, it is nowhere near enough to
        have heard you.
        """

    static let robotIdles = """
        The robot idles, ticking.
        """

    /// Written fresh, and the only one of the four greetings that is not about
    /// hostility: the engine's placeholder has the robot *nod*, and a machine
    /// that nods is a machine pretending to be a person. It takes orders and it
    /// does not converse, which is the whole of what the green paper says
    /// about it. One state — it has no second one to be in.
    static let robotGreeted = """
        The robot does not answer. It was not built to be talked to; it was
        built to be told.
        """

    static let robotCannotDoThat = """
        The robot considers the request at some length and does nothing.
        """

    // MARK: - The Machine Room and its buttons

    static let machineRoomWithButtons = """
        This is a room with a bank of controls along one wall — three buttons,
        no labels, and a great deal of machinery behind them that is plainly
        still running. Ways out lead west and south.
        """

    static func button(_ shape: String) -> String {
        "A \(shape) button, worn smooth in the middle."
    }

    /// Written fresh. The room's one sentence names three things — a bank of
    /// controls, the buttons in it, and the machinery behind them — and only
    /// the buttons were declared, so the other two words were answered by
    /// asking which button you meant. (#286)
    static let controlBank = """
        A plate of dull metal let into the wall with three buttons in a row on
        it, and nothing written anywhere to say what any of them does.
        """

    static let machineRoomMachinery = """
        Behind the plate, and going on with it. You can hear the size of it and
        you cannot see a foot of it.
        """

    static let triangularButtonStopsTheCarousel = """
        Click. Somewhere a long way off, a great deal of machinery slows and
        stops, and the silence afterwards is startling.
        """

    static let triangularButtonAgain = """
        Click. Nothing answers; the machinery it spoke to has already stopped.
        """

    /// The round and the square button. Their effects live in `BUTTONS`, a
    /// routine `dung.355` does not carry, so this game declines to invent one
    /// and reports only what the player can honestly observe.
    static func buttonNoAnswer(_ shape: String) -> String {
        """
        Click. The machinery behind the wall takes note of the \(shape) button
        and, so far as anything here shows, thinks better of it.
        """
    }

    // MARK: - The Dingy Closet, the sphere and the cage

    /// Adapted. `CAGER` is `substantial`; the trilogy's version renames the
    /// room to the north and adds a joke about the footpad. The mainframe's
    /// room is next to the Machine Room and the sticker is the mainframe's.
    static let dingyCloset = """
        This is a dingy closet adjacent to the machine room. On one wall is a
        small sticker which says

                Protected by
                  FROBOZZ
             Magic Alarm Company
              (Hello, footpad!)
        """

    static let alarmSticker = """
        A small printed sticker, curling at one corner, from a company that no
        longer answers its telephone.
        """

    static let sphereFirstSight = """
        There is a beautiful white crystal sphere here.
        """

    static let sphere = """
        A sphere of white crystal, cold to the eye, resting on a low pedestal
        as if it had been put down a moment ago.
        """

    /// The same sphere once the dish under it is empty. The placement clause is
    /// a claim about the pedestal, and `cageSprung` is the pedestal having been
    /// emptied — by whichever of you did it.
    static let sphereOffThePedestal = """
        A sphere of white crystal, cold to the eye, and lighter in the hand
        than a thing that size has any business being.
        """

    static let spherePedestal = """
        A low stone pedestal with a shallow dish cut in the top of it.
        """

    static let cageFallsOnYou = """
        As you lift the sphere from its dish there is a shriek of alarm bells,
        and a steel cage falls from the ceiling and lands around you with a
        clang that goes on for some while.
        """

    static let cageRoom = """
        You are trapped inside a solid steel cage.
        """

    static let cageRobotOutside = """
        Through the bars, a foot or so away, the robot stands exactly where you
        left it, waiting to be told something.
        """

    static let cageNobodyOutside = """
        Through the bars you can see the closet, the pedestal and the sticker.
        There is nobody out there at all.
        """

    static let cageBars = """
        Steel bars, an inch thick and set two inches apart. The floor of the
        cage is the floor of the closet, which is no help at all.
        """

    static let cageWontBudge = """
        The cage does not move, and you are not going to be the one who moves
        it.
        """

    static let cageNoWayOut = """
        There is no way out of the cage. There is barely a way to turn round.
        """

    static let cageGas = """
        A colorless gas begins to enter the cage through a vent in the floor.
        It has no smell, which is somehow worse.
        """

    static let cageGasKills = """
        The gas does what the gas was installed to do.
        """

    /// Written fresh. Both nouns of ``cageGas`` were printed and neither was
    /// declared, so the sentence that starts the six-turn clock named two
    /// things the parser then denied. (#286)
    static let cageGasItself = """
        There is nothing to look at. The alarm company thought about this.
        """

    static let cageVent = """
        A slot in the floor plate, no wider than a finger, with the gas coming
        up out of it.
        """

    static let robotLiftsTheCage = """
        The robot takes hold of the bars, sets its treads, and lifts. The cage
        comes away from the floor with a scream of tearing steel, and the robot
        drops the ruin of it to one side.
        """

    static let cageMangledFirstSight = """
        There is a mangled steel cage here.
        """

    static let cageMangled = """
        A steel cage, or what a steel cage looks like after a robot has had an
        opinion about it.
        """

    static let robotSpringsTheCage = """
        The robot lifts the sphere from its dish. The alarm shrieks, the cage
        falls — and lands on the robot, which does not appear to have noticed.
        The robot straightens up, the ruined cage slides off it, and the sphere
        is still in its hand.
        """

    static let cageAlreadySprung = """
        The alarm has already had its one moment.
        """

    static let robotIsNotHere = """
        Nothing answers. Whatever might have lifted it is somewhere else.
        """
}
