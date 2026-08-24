import Gnusto

/// The well, the tea party and the robot — the nine rooms `dung.355` gathers
/// under one heading of its own, built here with the same boundary.
///
/// The shape of it: the Pearl Room opens east onto the bottom of a brick well,
/// and the only way up the well is to sit in the bucket and pour water into it.
/// At the top is a mad tea party, and beyond that a room too low to stand up in
/// with a robot standing in it, a Machine Room with three unlabelled buttons,
/// and a closet with a crystal sphere on a pedestal and a steel cage in the
/// ceiling above it. Under the tea table — reached by eating the cake that says
/// to — are two more rooms at mouse scale.
///
/// **None of this reached Zork I, and the Zork II versions are a different
/// game.** The comparison document files `BWELL`, `TWELL`, `BUCKE`, `ROBOT` and
/// `RBTLB` as `identical`, so those five lines are the trilogy's verbatim;
/// `ALICE`, `ALISM` and `CAGED` as `minor`; `ALITR` and `CAGER` as
/// `substantial`. Everything else is written fresh. See `Prose+Alice.swift`.
///
/// Two things worth knowing before changing anything here:
///
/// - **There are two rooms called Machine Room in this game**, and they are not
///   the same room. `MACHI` is the coal mine's, with the lid and the switch,
///   and milestone 3 built it in ``DungeonCoalMine``. `CMACH` is this one, with
///   the three buttons, and the atlas's *in `Sources/Zork1/`* column points at
///   the coal mine's file for it because that column matches on display name.
/// - **The Alice area has exactly one way in and out**, the well, so the bucket
///   has to work in both directions. It does: the water stays in the bucket,
///   and emptying it sends the bucket back down.
///
/// The seams the host wires are the Pearl Room's east door in (a
/// ``DungeonRiddle`` room), the bottle of water that raises the bucket (a
/// ``DungeonHouse`` item), and the triangular button, which stops the machinery
/// under a ``DungeonRoundRoom`` room a long way from here.
struct DungeonAlice: GameContent {
    // MARK: - Rooms

    /// `BWELL`. The bottom of the well: west to the Pearl Room, and up only in
    /// the bucket.
    let circularRoom = Location {
        name("Circular Room")
        description(Prose.circularRoom)
        dark
    }

    /// `TWELL`. Worth ten points on arrival — the mainframe's `RVAL`, and the
    /// only room value in this milestone. The host pays it from an
    /// `afterEachTurn` rule rather than `scoring.visit`, because the usual way
    /// in is riding the bucket up and a vehicle's move runs no `onEnter`.
    let topOfWell = Location {
        name("Top of Well")
        description(Prose.topOfWell)
        dark
    }

    /// `ALICE`.
    let teaRoom = Location {
        name("Tea Room")
        description(Prose.teaRoom)
        dark
    }

    /// `ALISM`. The floor under the tea table, seen by somebody four inches
    /// high. Reached by eating, never by walking.
    let postsRoom = Location {
        name("Posts Room")
        description(Prose.postsRoom)
        dark
    }

    /// `ALITR`. Always described: whether the depression still holds the goop
    /// is a fact the long description carries, and a brief re-entry would hide
    /// the change the player just made.
    let poolRoom = Location {
        name("Pool Room")
        alwaysDescribed
        dark
    }

    /// `MAGNE`. Nine ways out, five of which are the same room.
    let lowRoom = Location {
        name("Low Room")
        description(Prose.lowRoom)
        dark
    }

    /// `CMACH` — the robot's Machine Room, not the coal mine's.
    let machineRoom = Location {
        name("Machine Room")
        description(Prose.machineRoomWithButtons)
        dark
    }

    /// `CAGER`. Lit in the source (`RLIGHTBIT`), and the alarm sticker is what
    /// the room is for.
    let dingyCloset = Location {
        name("Dingy Closet")
        description(Prose.dingyCloset)
    }

    /// `CAGED`. No exits at all, and the source declares it dark. Lit here,
    /// because it is a cage standing on the floor of a lit closet — see
    /// `FIDELITY.md`. What gets you out is the robot; what happens if it
    /// doesn't is the gas.
    let cage = Location {
        name("Cage")
        alwaysDescribed
    }

    // MARK: - State

    /// Whether the player is currently four inches high.
    @Global var shrunk = false

    /// The mainframe's `LOW-TIDE`: whether the depression in the Pool Room has
    /// been boiled dry.
    @Global var poolEvaporated = false

    /// The mainframe's `CAGE-TOP`: whether the alarm has already fired. Read
    /// off the cage rather than saved beside it — the cage is offstage until
    /// it drops, and one of the two of them standing in the closet *is* the
    /// alarm having fired.
    var cageSprung: Bool {
        steelCage.isIn(dingyCloset) || mangledCage.isIn(dingyCloset)
    }

    /// The mainframe's `BUCKET-TOP`, read off the bucket for the same reason.
    var bucketAtTop: Bool { bucket.isIn(topOfWell) }

    // MARK: - The well

    /// `BUCKE`. A vehicle in the source (`VEHBIT`), and the only lift in the
    /// game. It holds the water that raises it, which is what makes the trip
    /// reversible.
    let bucket = Item {
        name("wooden bucket")
        adjectives("wooden")
        synonyms("bucket", "pail")
        firstSight(Prose.bucketFirstSight)
        description(Prose.bucket)
        enterable
        container
        startsOpen
        trait(.weight, 100)
    }

    /// `ETCH1` and the `WELL` global together: one item answers *well*,
    /// *wall*, *walls* and *etchings* at the bottom of the shaft, where the
    /// source has a global and a room object doing the same two jobs.
    let etchingsBelow = Item {
        name("wall with etchings")
        adjectives("brick", "damp")
        synonyms("etchings", "etching", "walls", "wall", "well", "brickwork", "mortar")
        description(Prose.etchingsBelow)
        scenery
    }

    /// `ETCH2` and the same global at the top. The `crack` and the `floor` are
    /// not the ring of letters and stopped being synonyms for it: the room puts
    /// them across the doorway east, which is somewhere to walk and not
    /// something to read. (#286)
    let etchingsAbove = Item {
        name("wall with etchings")
        adjectives("carved")
        synonyms("etchings", "etching", "walls", "wall", "well")
        description(Prose.etchingsAbove)
        scenery
    }

    /// The crack the Top of Well's own last sentence is about, which the
    /// etchings were answering for. (#286)
    let crackAtTopOfWell = Item {
        name("crack")
        adjectives("small")
        synonyms("crack", "floor")
        description(Prose.topOfWellCrack)
        scenery
    }

    // MARK: - The Tea Room

    /// `ATABL`.
    let teaTable = Item {
        name("large oblong table")
        adjectives("large", "oblong", "long")
        synonyms("table", "tea", "objects", "setting")
        description(Prose.teaTable)
        scenery
        surface
    }

    let mouseHole = Item {
        name("small hole")
        adjectives("small", "eastern")
        synonyms("hole", "corner")
        description(Prose.mouseHole)
        scenery
    }

    /// `ECAKE`. Eating it in the Tea Room drops you to mouse scale under the
    /// table.
    let eatMeCake = Item {
        name("piece of 'Eat-Me' cake")
        adjectives("eatme", "eat")
        synonyms("cake", "piece", "food")
        firstSight(Prose.eatMeCakeFirstSight)
        description(Prose.eatMeCake)
        trait(.weight, 10)
    }

    /// `BLICE`. The source's own adjective for it is *ecch*.
    let blueCake = Item {
        name("piece of cake with blue icing")
        adjectives("blue", "ecch")
        synonyms("cake", "icing", "piece", "food")
        firstSight(Prose.icedCakeFirstSight("blue (ecch)"))
        description(Prose.icedCake("blue"))
        trait(.weight, 4)
    }

    /// `ORICE`. The way back to your own size.
    let orangeCake = Item {
        name("piece of cake with orange icing")
        adjectives("orange")
        synonyms("cake", "icing", "piece", "food")
        firstSight(Prose.icedCakeFirstSight("orange"))
        description(Prose.icedCake("orange"))
        trait(.weight, 4)
    }

    /// `RDICE`. The one that goes in the pool.
    let redCake = Item {
        name("piece of cake with red icing")
        adjectives("red")
        synonyms("cake", "icing", "piece", "food")
        firstSight(Prose.icedCakeFirstSight("red"))
        description(Prose.icedCake("red"))
        trait(.weight, 4)
    }

    // MARK: - Under the table

    /// `POSTS`. The table's legs, from four inches up.
    let posts = Item {
        name("group of wooden posts")
        adjectives("wooden", "four")
        synonyms("posts", "post", "roof", "area")
        description(Prose.posts)
        scenery
        plural
    }

    let postsChasm = Item {
        name("large chasm")
        adjectives("large")
        synonyms("chasm", "edge", "floor")
        description(Prose.postsChasm)
        scenery
    }

    /// `POOL`. Goes up in steam when the red cake goes in.
    let poolOfSewage = Item {
        name("pool of sewage")
        adjectives("large", "brown")
        synonyms("pool", "sewage", "goop", "depression")
        description(Prose.poolOfSewage)
        scenery
    }

    /// `PLEAK`. Out of reach from down here, which `reach(otherwise:)` says
    /// once instead of four times.
    let leak = Item {
        name("leak")
        adjectives("large")
        synonyms("ceiling", "crack", "drip")
        description(Prose.poolLeak)
        scenery
    }

    /// `FLASK`. A trap: the liquid is not for drinking and the stopper is not
    /// for pulling.
    let flask = Item {
        name("glass flask filled with liquid")
        adjectives("glass", "stoppered")
        synonyms("flask", "bottle", "liquid", "label")
        firstSight(Prose.flaskFirstSight)
        description(Prose.flask)
        trait(.weight, 10)
    }

    /// `SAFFR`. Declared in the Pool Room's own contents and invisible until
    /// the pool goes — the source withholds its `OVISON`. Five to find and
    /// five to case.
    let spices = Item {
        name("tin of spices")
        adjectives("rare")
        synonyms("tin", "spices", "spice", "saffron")
        firstSight(Prose.spicesFirstSight)
        description(Prose.spices)
        hidden
        trait(.weight, 8)
        trait(.takeValue, 5)
        trait(.depositValue, 5)
    }

    // MARK: - The robot

    /// `ROBOT`. The one thing in the game that takes an order, and the reason
    /// #130 was engine work before this milestone could start.
    let robot = Actor {
        name("robot")
        synonyms("robby", "machine")
        firstSight(Prose.robotFirstSight)
        description(Prose.robot)
        takesOrders
    }

    /// `RBTLB`. The instruction sheet, and the game's only hint that an actor
    /// can be addressed at all.
    let robotPaper = Item {
        name("green piece of paper")
        adjectives("green")
        synonyms("paper", "piece", "sheet", "instructions")
        firstSight(Prose.robotPaperFirstSight)
        description(Prose.robotPaper)
        trait(.weight, 3)
    }

    let lowRoomCeiling = Item {
        name("low ceiling")
        adjectives("low", "very")
        synonyms("ceiling", "rock", "walls", "wall", "ways", "way", "exits", "exit")
        description(Prose.lowRoomCeiling)
        scenery
    }

    // MARK: - The buttons

    /// `RNBUT`, `SQBUT`, `TRBUT`. Three objects in the source, three here, and
    /// only one of the three has an effect this project can establish.
    ///
    /// All three used to carry `machinery`, `controls` and `bank`, so the
    /// room's own sentence — a bank of controls with a great deal of machinery
    /// *behind* them — could only be answered by asking which button you meant,
    /// and none of the three was the answer. Those three words now belong to
    /// the two things the sentence is actually about. (#286)
    private static func buttonScenery(_ shape: String) -> Item {
        Item {
            name("\(shape) button")
            adjectives(shape)
            synonyms("button", "buttons")
            description(Prose.button(shape))
            scenery
        }
    }

    let roundButton = buttonScenery("round")
    let squareButton = buttonScenery("square")
    let triangularButton = buttonScenery("triangular")

    /// The bank the three buttons are set in. (#286)
    let controlBank = Item {
        name("controls")
        adjectives("unlabelled")
        synonyms("controls", "control", "bank", "panel")
        description(Prose.controlBank)
        scenery
        plural
    }

    /// And what is running behind it, which is the half of the sentence no
    /// button could ever have answered for. (#286)
    let machineRoomMachinery = Item {
        name("machinery")
        adjectives("running")
        // Not `machine`: the robot answers to that word and the puzzle walks it
        // into this room, so claiming it here would re-open the disambiguation
        // the trim above closes. The paragraph prints "machinery" and never
        // "machine".
        synonyms("machinery")
        description(Prose.machineRoomMachinery)
        scenery
    }

    // MARK: - The closet, the sphere and the cage

    let alarmSticker = Item {
        name("small sticker")
        adjectives("small")
        synonyms("sticker", "wall", "walls", "label")
        description(Prose.alarmSticker)
        scenery
    }

    /// `SPHER`. Six to find and six to case, and the alarm is on the pedestal
    /// rather than on the sphere.
    let sphere = Item {
        name("white crystal sphere")
        adjectives("white", "crystal", "beautiful")
        synonyms("sphere", "ball", "stone", "glass")
        firstSight(Prose.sphereFirstSight)
        description(Prose.sphere)
        trait(.weight, 10)
        trait(.takeValue, 6)
        trait(.depositValue, 6)
    }

    let pedestal = Item {
        name("low pedestal")
        adjectives("low", "stone")
        synonyms("pedestal", "dish", "stand")
        description(Prose.spherePedestal)
        scenery
    }

    /// `RCAGE`. The cage as it looks from *outside* — from the Dingy Closet,
    /// which is where the robot has to be able to see it. Offstage until the
    /// alarm fires.
    let steelCage = Item {
        name("steel cage")
        adjectives("steel")
        synonyms("cage", "bars", "bar")
        description(Prose.cageBars)
        scenery
    }

    /// The same cage from inside it, which is a different room.
    let cageBars = Item {
        name("steel bars")
        adjectives("steel", "thick")
        synonyms("bars", "bar", "cage", "floor")
        description(Prose.cageBars)
        scenery
        plural
    }

    /// The gas the fuse announces on the turn the cage lands, and the vent it
    /// comes in through. Both were words the game printed and the parser denied
    /// — `x vent` did not even get as far as a refusal, it got *"I don't know
    /// the word"*. Neither is hidden: the only frame in which a player can be
    /// standing in this room is the frame in which the gas is arriving. (#286)
    let gasInCage = Item {
        name("colorless gas")
        adjectives("colorless", "odorless")
        synonyms("gas", "vapor", "fumes")
        description(Prose.cageGasItself)
        scenery
    }

    let ventInCage = Item {
        name("vent")
        adjectives("floor")
        synonyms("vent", "grille", "grate")
        description(Prose.cageVent)
        scenery
    }

    /// `CAGE`. What is left once the robot has had it up off the floor.
    let mangledCage = Item {
        name("mangled steel cage")
        adjectives("mangled", "steel", "ruined")
        synonyms("cage", "wreck", "ruin")
        firstSight(Prose.cageMangledFirstSight)
        description(Prose.cageMangled)
        trait(.weight, 60)
    }

    // MARK: - Verbs

    /// One extra row on a stub verb, which the bootstrap allows silently. The
    /// engine's `throw` parses `throw <thing> at <thing>`; the sentence this
    /// region needs is `throw the red cake in the pool`, and *at* a pool is not
    /// what anybody means. One row is enough for both spellings — `in` answers
    /// to `into` wherever a pattern puts it (issue #269).
    var verbs: [SyntaxRule] {
        SyntaxRule("throw", .directObject, "in", .indirectObject, intent: .throwAt)
    }

    // MARK: - Map

    var map: WorldMap {
        // The well. West is the Pearl Room, a ``DungeonRiddle`` room —
        // host-wired. Up is brickwork.
        circularRoom.up(blocked: Prose.bucketWalls)
        topOfWell.east(teaRoom)
        topOfWell.down(blocked: Prose.bucketDown)

        // The Tea Room. East is four inches high and stays that way whatever
        // size you are: the way under the table is the cake, not the hole.
        teaRoom.west(topOfWell)
        teaRoom.northwest(lowRoom)
        teaRoom.east(blocked: Prose.mouseHoleRefused)

        // Under the table. The Posts Room has one way out and three drops.
        postsRoom.east(poolRoom)
        postsRoom.northwest(blocked: Prose.postsChasmRefused)
        postsRoom.west(blocked: Prose.postsChasmRefused)
        postsRoom.down(blocked: Prose.postsChasmRefused)
        poolRoom.west(postsRoom)
        poolRoom.out(postsRoom)

        // The Low Room's nine ways out, five of which are the Machine Room and
        // four of which are the Tea Room. The source gates every one of them on
        // `MAGNET-ROOM-EXIT`, a routine `dung.355` does not carry; the
        // destinations are the table's and the gate is not built, which is the
        // seam convention's second rule.
        for direction in Self.lowRoomToMachineRoom {
            lowRoom.exit(direction, to: machineRoom)
        }
        for direction in Self.lowRoomToTeaRoom {
            lowRoom.exit(direction, to: teaRoom)
        }

        machineRoom.west(lowRoom)
        machineRoom.south(dingyCloset)
        dingyCloset.north(machineRoom)

        // The Cage has no exits, which is the point of it.
        cage.north(blocked: Prose.cageNoWayOut)

        bucket.starts(in: circularRoom)
        etchingsBelow.starts(in: circularRoom)
        etchingsAbove.starts(in: topOfWell)

        teaTable.starts(in: teaRoom)
        mouseHole.starts(in: teaRoom)
        eatMeCake.starts(on: teaTable)
        blueCake.starts(on: teaTable)
        orangeCake.starts(on: teaTable)
        redCake.starts(on: teaTable)

        posts.starts(in: postsRoom)
        postsChasm.starts(in: postsRoom)
        poolOfSewage.starts(in: poolRoom)
        leak.starts(in: poolRoom)
        flask.starts(in: poolRoom)
        spices.starts(in: poolRoom)

        robot.starts(in: lowRoom)
        robotPaper.starts(in: lowRoom)
        lowRoomCeiling.starts(in: lowRoom)

        roundButton.starts(in: machineRoom)
        squareButton.starts(in: machineRoom)
        triangularButton.starts(in: machineRoom)
        controlBank.starts(in: machineRoom)
        machineRoomMachinery.starts(in: machineRoom)
        crackAtTopOfWell.starts(in: topOfWell)

        alarmSticker.starts(in: dingyCloset)
        sphere.starts(in: dingyCloset)
        pedestal.starts(in: dingyCloset)
        cageBars.starts(in: cage)
        gasInCage.starts(in: cage)
        ventInCage.starts(in: cage)
    }

    // MARK: - Rules

    var rules: Rules {
        wellRules
        teaRoomRules
        poolRoomRules
        robotRules
        cageRules
    }

    // MARK: - Timers

    var timers: [TimedEvent] {
        // The gas. Six turns inside the cage, and the alarm company's other
        // product does the rest.
        fuse("cageGas", after: 6) {
            guard player.location == cage else { return }
            try die(Prose.cageGasKills)
        }
    }

    // MARK: - The well

    @RuleBuilder private var wellRules: Rules {
        bucket.before(.take, .push, .pull) { try refuse(Prose.bucketRefusesToBeTaken) }

        // The bucket is a lift, not a wheelbarrow. Without this the engine
        // carries a boarded vehicle wherever its passenger walks — which is
        // right for the boat and the balloon, and would let a player wheel the
        // well's only lift into the Round Room and shut the Alice area behind
        // them for good. Two location rules rather than a world one, because
        // the bucket is only ever in these two rooms.
        for room in [circularRoom, topOfWell] {
            room.before(.go) {
                guard player.vehicle == bucket else { return }
                try refuse(Prose.bucketGoesNowhereElse)
            }
        }
    }

    /// Send the bucket up, with whoever is sitting in it. Called by the host,
    /// because the water that does it is a ``DungeonHouse`` item.
    func raiseBucket() throws -> Never {
        guard !bucketAtTop else { try reply(Prose.bucketAlreadyUp) }
        try sendBucket(to: topOfWell, saying: Prose.bucketRises)
    }

    /// And send it back down again when the water goes.
    func lowerBucket() throws -> Never {
        try sendBucket(to: circularRoom, saying: Prose.bucketDescends)
    }

    /// The move both ends of the trip make. Moving the bucket rather than the
    /// player is what carries a passenger — and their load — along with it.
    private func sendBucket(to room: Location, saying line: String) throws -> Never {
        bucket.move(to: room)
        say(line)
        if player.location == room { describeSurroundings() }
        try handled()
    }

    // MARK: - The Tea Room

    @RuleBuilder private var teaRoomRules: Rules {
        // The three iced cakes carry writing, and the writing is the size of
        // the icing. Only somebody four inches high can read it.
        for (cake, writing) in [
            (blueCake, Prose.blueIcingWriting),
            (orangeCake, Prose.orangeIcingWriting),
            (redCake, Prose.redIcingWriting),
        ] {
            cake.before(.read) {
                try reply(shrunk ? writing : Prose.icedCakeTooSmallToRead)
            }
        }

        // The cake that says to. It works in the Tea Room and nowhere else,
        // because the Tea Room is the only room with a floor underneath it.
        eatMeCake.before(.eat) {
            guard player.location == teaRoom, !shrunk else {
                try reply(Prose.eatMeNotHere)
            }
            shrunk = true
            say(Prose.eatMeShrinks)
            arrive(at: postsRoom)
            try handled()
        }

        // And the one that undoes it. Only under the table, where the roof is
        // a tabletop and there is somewhere for you to go.
        orangeCake.before(.eat) {
            guard shrunk else { try reply(Prose.eatMeNotHere) }
            try require(player.location == postsRoom, else: Prose.orangeCakeNoRoom)
            shrunk = false
            say(Prose.orangeCakeGrows)
            arrive(at: teaRoom)
            try handled()
        }

        // The blue one is a mistake, and the source's own adjective for it says
        // so before you make it.
        // The cakes survive being bitten. The source has one of each and the
        // way out of the small world is the orange one, so a cake eaten to
        // nothing would strand a player under their own tea table — see the
        // note in the PR that landed this milestone.
        blueCake.before(.eat) { try die(Prose.blueCakeKills) }

        mouseHole.before(.board, .climb) { try refuse(Prose.mouseHoleRefused) }
    }

    // MARK: - The Pool Room

    @RuleBuilder private var poolRoomRules: Rules {
        poolRoom.describe { poolEvaporated ? Prose.poolRoomDrained : Prose.poolRoom }

        // The ceiling is a very long way up when you are four inches high, and
        // one reach rule says so to `take`, `open`, `plug` and the rest alike.
        leak.reach(otherwise: Prose.poolLeakOutOfReach) { false }

        // The red cake in the pool. `throw cake in pool` and `put cake in pool`
        // are the two sentences a player reaches for, and the location owns the
        // rule so it fires ahead of anything the cake or the pool would do.
        poolRoom.before(.throwAt, .putIn) {
            guard command.directObject == redCake else { return }
            try require(
                command.indirectObject == nil || command.indirectObject == poolOfSewage,
                else: Prose.cakeThrownNowhere)
            try require(!poolEvaporated, else: Prose.poolAlreadyGone)
            redCake.vanish()
            poolOfSewage.vanish()
            poolEvaporated = true
            spices.reveal()
            try reply(Prose.poolEvaporates)
        }

        // The flask. Opening it is the last thing you do; drinking it does not
        // get that far.
        flask.before(.open, .drink, .eat) { try die(Prose.flaskOpened) }
    }

    // MARK: - The robot

    /// Where the robot may walk, and by which bearing. The engine runs no
    /// default action for somebody else, so an ordered `go` is this table and
    /// nothing else — see `ActorsAndVehicles.md`.
    private var robotRoutes: [(from: Location, direction: Direction, to: Location)] {
        Self.lowRoomToMachineRoom.map { (lowRoom, $0, machineRoom) }
            + Self.lowRoomToTeaRoom.map { (lowRoom, $0, teaRoom) }
            + [
                (machineRoom, .west, lowRoom), (machineRoom, .south, dingyCloset),
                (dingyCloset, .north, machineRoom),
                (teaRoom, .west, topOfWell), (teaRoom, .northwest, lowRoom),
                (topOfWell, .east, teaRoom),
            ]
    }

    /// The Low Room's nine bearings, split by where they come out. The map
    /// declares the exits from these and the robot walks them, so a change to
    /// `MAGNE` is one edit.
    private static let lowRoomToMachineRoom: [Direction] = [
        .north, .south, .west, .northeast, .east,
    ]
    private static let lowRoomToTeaRoom: [Direction] = [
        .northwest, .southwest, .southeast, .out,
    ]

    @RuleBuilder private var robotRules: Rules {
        robotPaper.before(.read) { try reply(Prose.robotPaperText) }

        // The engine lets an order-taker be *named* out of sight, which is the
        // whole point of this puzzle — the robot goes where you cannot. What
        // the engine deliberately does not decide is how far out of sight, so
        // the game does: one room. A world rule, because it has to catch an
        // order aimed at anything at all, and world rules run first.
        world.before {
            guard command.actor == robot, !robotIsWithinEarshot else { return }
            try refuse(Prose.robotIsOutOfEarshot)
        }

        let routes = robotRoutes
        robot.before(.go) {
            guard let heading = command.direction else {
                try refuse(Prose.robotNeedsADirection)
            }
            // Ask him where he is once and match the table on it, the shape
            // `masterStep` uses for the dungeon master's identical walk. An
            // offstage robot matches no row and lands on the same refusal.
            let there = robot.location
            guard
                let route = routes.first(where: {
                    $0.direction == heading && $0.from == there
                })
            else {
                try refuse(Prose.robotCannotGoThatWay)
            }
            let watching = player.location
            robot.move(to: route.to)
            try reply(watching == route.to ? Prose.robotArrives : Prose.robotWalks)
        }

        robot.before(.wait) { try reply(Prose.robotIdles) }

        // And a greeting, which reached the engine's placeholder: "The robot
        // nods, and says nothing." It does not nod. `reply` because the
        // `.greet` default is a `say`.
        robot.before(.greet) { try reply(Prose.robotGreeted) }

        // The other two buttons. Their effects live in `BUTTONS`, a routine
        // `dung.355` does not carry, so this game declines to invent one: the
        // button is real, it is pressed, and what it spoke to is out of sight.
        // The triangular one is the host's, because what *it* stops is in
        // another bundle.
        roundButton.before(.push, .turnOn) { try reply(Prose.buttonNoAnswer("round")) }
        squareButton.before(.push, .turnOn) { try reply(Prose.buttonNoAnswer("square")) }

        // Everything else it is told. `take` is deliberately **not** in this
        // list: the addressee's own rules run ahead of the rules on the thing
        // the order names, so a catch-all here would answer `robot, take the
        // sphere` before the pedestal's alarm ever heard about it.
        robot.before(.push, .pull, .attack, .open) {
            try reply(Prose.robotCannotDoThat)
        }
    }

    // MARK: - The cage

    /// Whether the robot could plausibly have heard the order: it is in this
    /// room, or in the next one along a passage it knows.
    private var robotIsWithinEarshot: Bool {
        let here = player.location
        if robot.isIn(here) { return true }
        // The Cage is not on the robot's map — nothing walks into it — but it
        // stands on the floor of the Dingy Closet, and the whole puzzle is
        // shouting through its bars at something a foot away.
        if here == cage, robot.isIn(dingyCloset) { return true }
        return robotRoutes.contains { $0.from == here && robot.isIn($0.to) }
    }

    @RuleBuilder private var cageRules: Rules {
        // The pedestal is the trap. Whoever lifts the sphere off it springs the
        // alarm — and which of the two of you it is decides whether the cage
        // lands on a person or on a machine that does not mind.
        // Ordered to fetch it, the robot springs the trap on itself, and a
        // steel cage is no more to a robot than weather. An order never reaches
        // stage 4, so this half has to be a `before` rule.
        sphere.before(.take) {
            guard command.actor == robot else { return }
            try require(!cageSprung, else: Prose.cageAlreadySprung)
            mangledCage.move(to: dingyCloset)
            try reply(Prose.robotSpringsTheCage)
        }

        // And taking it yourself. An `after` rule that does not throw, so the
        // take completes, the treasure's six points are paid by the scoring
        // plugin's own `after(.take)`, and the cage lands on the sentence
        // after "Taken."
        sphere.after(.take) {
            guard !cageSprung else { return }
            steelCage.move(to: dingyCloset)
            player.location = cage
            startFuse("cageGas")
            say(Prose.cageFallsOnYou)
            describeSurroundings()
            say(Prose.cageGas)
        }

        // The one order that matters, and the whole reason the robot exists.
        // The cage the robot can see is the one standing in the closet, not the
        // one you are standing inside.
        steelCage.before(.take, .raise, .push, .pull, .open) {
            guard command.actor == robot, robot.isIn(dingyCloset) else {
                try refuse(Prose.robotIsNotHere)
            }
            stopFuse("cageGas")
            steelCage.replace(with: mangledCage)
            say(Prose.robotLiftsTheCage)
            arrive(at: dingyCloset)
            try handled()
        }

        cageBars.before(.take, .push, .pull, .open, .attack, .raise) {
            try reply(Prose.cageWontBudge)
        }

        // What you can see from inside the cage, which is the whole of the
        // hint: the robot is standing three feet away on the other side of the
        // bars, and it is the only thing here that can lift anything.
        cage.describe {
            robot.isIn(dingyCloset)
                ? "\(Prose.cageRoom)\n\n\(Prose.cageRobotOutside)"
                : "\(Prose.cageRoom)\n\n\(Prose.cageNobodyOutside)"
        }
    }
}
