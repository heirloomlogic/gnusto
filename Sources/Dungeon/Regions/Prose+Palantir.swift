/// Prose for the palantir wing (``DungeonPalantir``): the Tiny Room west of the
/// Torch Room, the Dreary Room behind the oak door, the coal chute climbed on a
/// rope, the Slide Ledge and the Sooty Room hanging off it.
///
/// The three-way rule, and the rule for which file a line goes in, are stated
/// once on ``Prose``.
///
/// **Almost all of it is case 3.** None of the seven rooms appears in any
/// bucket of `docs/games/dungeon-prose-comparison.md`, and neither does the
/// door, the window, either lid, either keyhole, the table, either crack, the
/// stove or the chute. That document carries only entities present in both
/// sources, so the absence is its way of saying there is nothing to pair — and
/// the mainframe's own wording is not available to borrow, because no licence
/// grant has been located for the 1981 MDL. Every refusal and every event line
/// below is therefore this project's, said in its own words. What crosses over
/// is what each line has to *mean*.
///
/// **The two exceptions are the two treasures**, and they are worth naming
/// because the issue that specified this region assumed there were none. `PAL3`
/// and `PALAN` are filed `substantial`, so case 2 applies: take the trilogy
/// line after checking it against the atlas. Zork II's blue-sphere line puts the
/// sphere on a table, and `PTABL` is in `PALAN`; its red-sphere line names
/// nothing at all. Neither contradicts anything, so both are taken as they
/// stand — which is also what settles the mainframe's missing article ("There
/// is blue crystal sphere here.") from the committed policy rather than by
/// taste.
extension Prose {
    // MARK: - The Tiny Room

    static let tinyRoom = """
        This is a tiny room, bare to the walls. In the north wall is a door made
        of oak, and beside the door a small barred window. Set into the door at
        waist height is a keyhole under a metal lid. A passage leads east.
        """

    static let tinyRoomWalls = """
        Bare rock on three sides, swept clean by nothing in particular, and a
        floor with a century of dust on it and not one footprint.
        """

    // MARK: - The door, the window and the fittings

    static func oakDoor(matUnderIt: Bool) -> String {
        matUnderIt
            ? """
            A massive door of oak, hung so close to the floor that it clears the
            flags by the thickness of a coin. The edge of a welcome mat is
            visible under the door.
            """
            : """
            A massive door of oak, hung so close to the floor that it clears the
            flags by the thickness of a coin.
            """
    }

    static let barredWindow = """
        A window a hand's breadth across, barred with iron, set into the wall
        beside the door. Whatever is on the other side of it, you are not going
        through this.
        """

    static let windowNotAWay = "Not unless somebody dices you first."

    static func metalLid(open: Bool) -> String {
        open
            ? """
            A small hinged plate of metal, swung up and away from the keyhole it
            covers.
            """
            : """
            A small hinged plate of metal, lying flat over the keyhole it
            covers.
            """
    }

    static let lidOpens = "The lid swings up."

    static let lidCloses = "The lid drops back over the keyhole."

    static let lidFalls = "The lid drops, and the keyhole is covered again."

    static let lidInTheWay = "The lid is over it."

    /// Two wordings for one state, keyed to two verbs: this one answers a lid
    /// being closed over a keyhole that has something in it, and
    /// ``keyholeBlocked`` answers a keyhole being asked to take a second thing
    /// or to turn a lock over the first.
    static let keyholeOccupied = "Not with something standing in the keyhole."

    static func keyhole(holding: String?) -> String {
        guard let holding else {
            return """
                A keyhole of the old pattern, wide enough to put a finger through
                and see nothing whatever for your trouble.
                """
        }
        return "A keyhole of the old pattern. There is \(holding) in it."
    }

    static let keyholeBlocked = "There is something in the keyhole already."

    /// Takes an already-rendered, already-capitalised phrase, the way every
    /// other prose function in this game does. The article is the engine's.
    static func doesntFitTheKeyhole(_ thing: String) -> String {
        "\(thing) will not go in."
    }

    static let keyholeLit = """
        You can just make out a lit room at the far end of it.
        """

    static let keyholeDark = """
        No light comes through the keyhole at all.
        """

    static let doorPunched = """
        There is a faint noise from the far side of the door, and a small cloud
        of dust lifts from under it.
        """

    static let doorNothingToPunch = """
        Nothing happens, which is about what the far side of a locked door
        usually offers.
        """

    static let matSlidesUnder = "The mat goes under the door with room to spare."

    static let matAlreadyUnder = "The mat is already under the door."

    static let matWontFit = """
        There is nothing here flat enough to go under a door.
        """

    static let matNowhereToPutIt = """
        There is nothing here you could slide it under.
        """

    static let matTakenWithKey = """
        As the mat comes up, a rusty iron key slides off it and onto the floor.
        """

    static let doorUnlocked = """
        Something turns over inside the door, and the lock gives.
        """

    static let doorIsLocked = "The door is locked."

    /// The game-wide answer for `look through <anything>`. Written to be true
    /// of everything the game already has a window or a mirror for, since the
    /// verb is in the vocabulary everywhere the moment this region declares it.
    static let nothingToLookThrough = """
        You see nothing through it that you could not see without it.
        """

    /// The other room entire, which is the whole trick of the window: the table
    /// and the sphere on it are visible a long time before they are reachable.
    ///
    /// Takes an already-joined phrase rather than the list, so the joining is
    /// ``GameText/list(_:)``'s everywhere and this file goes on declaring no
    /// imports.
    static func seenThroughTheWindow(_ description: String, _ listed: String?) -> String {
        guard let listed else { return description }
        return """
            \(description)

            You can make out \(listed) in there.
            """
    }

    static let rustyIronKey = """
        A key of black iron, furred all over with rust, and still, by the look
        of it, the only thing that will turn this lock.
        """

    // MARK: - The Dreary Room

    static let drearyRoom = """
        This is a dreary room, lit by a red glow that comes through a narrow
        crack in the wall from somewhere a long way off. In the south wall is a
        door made of oak, and beside it a small barred window. In the middle of
        the floor stands a dusty table.
        """

    static let dustyTable = """
        A plain wooden table under a hand's depth of dust, standing exactly
        where somebody set it down and never came back for it.
        """

    static let drearyCrack = """
        A crack in the wall no wider than a finger. The red glow comes through
        it and nothing else does.
        """

    /// Zork II, verbatim. `PALAN` is a `substantial` entry; the trilogy's line
    /// puts the sphere on a table, and the mainframe's `PTABL` is in this room,
    /// so it agrees with the atlas and stands as written.
    static let blueSphereFirstSight = """
        In the center of the table sits a blue crystal sphere.
        """

    static let blueSphere = """
        A sphere of blue crystal, and the light that lives in it is not the
        light in this room.
        """

    // MARK: - Scrying

    static func sphereShows(_ roomName: String, _ listed: String?) -> String {
        guard let listed else {
            return """
                A room swims up in the depths of the crystal: \(roomName).
                There is nothing in it.
                """
        }
        return """
            A room swims up in the depths of the crystal: \(roomName). You can
            make out \(listed).
            """
    }

    static let sphereShowsDarkness = "You see nothing in it but dark."

    // MARK: - The chute

    static let slideStretch = """
        You are hanging on a rope in a chute of sheet metal, wide enough to
        fall down and too smooth to stand in. The rope goes up into the dark
        and down into more of it.
        """

    static let chute = """
        Sheet metal, laid down a shaft at an angle that was never meant to be
        climbed, and polished by a century of coal.
        """

    /// One rope, one knot. Said at whichever end the second knot was tried at.
    static let ropeAlreadyTied = """
        It is tied at the other end of it, and there is only so much rope.
        """

    static let chuteNeedsAnAnchor = """
        Tie it to what? There is nothing here that would take the weight.
        """

    static let chuteWrongAnchor = """
        That would not hold a bucket, let alone you.
        """

    static let chuteAnchorNotOnTheGround = """
        You would have to put it down first, and then stay behind holding it,
        and neither of those is going to help.
        """

    static let chuteAlreadyRigged = """
        The rope is already tied off and hanging down the chute.
        """

    static let chuteRigged = """
        The rope is tied fast, and its loose end goes over the lip of the chute
        and out of sight.
        """

    static let chuteUnrigged = """
        The rope comes free, and what was a way down is a hole again.
        """

    /// Written fresh. ``chuteAnchorNotOnTheGround`` already refuses to tie the
    /// rope to something in your hands, on the grounds that a rope tied to what
    /// you are carrying holds nothing; picking the anchor back up is the same
    /// fact arriving from the other side, so it gets the same answer.
    static let chuteKnotComesUndone = """
        The rope goes slack as the weight comes off it, and the knot slips free
        of the chute.
        """

    static let ropeSuspendsYou = """
        And what do you imagine is holding you up?
        """

    static let ropeReleased = """
        You let go, and the chute has you.
        """

    static let gripFails = """
        Your grip goes, and the chute takes the rest.
        """

    static func lostDownTheChute(_ thing: String) -> String {
        "\(thing) goes bouncing away down the chute, and is gone."
    }

    static let nothingToLoseDownTheChute = """
        You can't do that while hanging onto a rope in a chute.
        """

    // MARK: - The Slide Ledge

    static let slideLedge = """
        You are standing on a narrow ledge cut into the side of the chute. The
        rope hangs past it and on down. A low opening leads south, and the
        chute itself goes both up and down from here.
        """

    static let slideLedgeOpening = """
        A gap in the chute wall barely worth calling a doorway, with soot
        drifted along the bottom of it.
        """

    // MARK: - The Sooty Room

    static let sootyRoom = """
        This is a small room, black with soot from floor to ceiling. Against
        one wall stands an old coal stove, and the fire in it has not gone out.
        In the north wall is a very narrow crack, with a red glow coming
        through it. The only way out is north.
        """

    static let coalStove = """
        A squat iron stove with its door ajar and a bed of coals inside still
        working away at a fire nobody has fed in a very long time. Everything
        within reach of it is black.
        """

    static let stoveWontMove = """
        The stove is a great deal heavier than it looks, and it looks heavy.
        """

    static let sootyCrack = """
        A crack in the wall no wider than a finger. The stove's light goes out
        through it, to wherever it is that light goes.
        """

    /// Zork II, verbatim. `PAL3` is a `substantial` entry and the trilogy's
    /// line names nothing this room contradicts, so it stands as written.
    static let redSphereFirstSight = """
        There is a beautiful red crystal sphere here.
        """

    static let redSphere = """
        A sphere of red crystal, warm to the hand, and the warmth is not the
        stove's.
        """
}
