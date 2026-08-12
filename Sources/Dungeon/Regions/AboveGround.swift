import Gnusto

extension Intent {
    /// Order the free brochure by post. The word is spelled into its rows
    /// rather than parsed as a free noun, which is ``Intent/answerWell``'s
    /// shape exactly and for its reason: the brochure is nowhere at all until
    /// it is asked for, so an object slot would answer the one sentence that
    /// starts the whole business with "You can't see any such thing."
    ///
    /// Declared here because this bundle owns the mailbox it arrives in and the
    /// leaflet that advertises it, and a verb lives with the region that
    /// answers it.
    #verb(
        "sendForBrochure",
        ["send", "for", "brochure"],
        ["send", "for", "free", "brochure"],
        ["send", "away", "for", "brochure"],
        ["order", "brochure"],
        ["order", "free", "brochure"])
}

/// Everything above ground: the white house's four sides, the forest that
/// wraps around them, the clearing with the grating in it, and the Great
/// Canyon east of the wood.
///
/// **The map here is the mainframe's, not Zork I's**, and the differences are
/// load-bearing rather than cosmetic:
///
/// - there is **no Forest Path** — ``forestTree`` is an ordinary forest room
///   that happens to have the climbable tree standing in it;
/// - there is **one clearing**, not two, and it is the hub the whole wood
///   drains into;
/// - **Behind House opens east onto that clearing**, not onto forest;
/// - the **Canyon View stands on the canyon's south wall**, reached east from
///   ``forestCanyonEdge`` and southeast from ``forestNorth``;
/// - several forest exits **lead back into the room they left** (north and west
///   of ``forestDeep``, north and east of ``clearing``), which is how the
///   mainframe makes the wood feel like a wood.
///
/// Seams this bundle leaves for later milestones: the grating's way down into
/// the Grating Room (the maze), and Canyon Bottom's path north to the End of
/// Rainbow (the river and the rainbow). Both are recorded in `FIDELITY.md`.
struct DungeonAboveGround: GameContent {
    // MARK: - The house exterior

    let westOfHouse = Location {
        name("West of House")
        description(Prose.westOfHouse)
    }

    let northOfHouse = Location {
        name("North of House")
        description(Prose.northOfHouse)
    }

    let southOfHouse = Location {
        name("South of House")
        description(Prose.southOfHouse)
    }

    let behindHouse = Location {
        name("Behind House")
        description(Prose.behindHouse)
    }

    // A single `Item` occupies one place, so "the house is examinable from
    // every side of it" needs one scenery item per room. All four share a name
    // and a description, so they read as the same house.

    let whiteHouseAtWest = Item {
        name("white house")
        adjectives("white", "colonial")
        description(Prose.whiteHouse)
        scenery
    }

    let whiteHouseAtNorth = Item {
        name("white house")
        adjectives("white", "colonial")
        description(Prose.whiteHouse)
        scenery
    }

    let whiteHouseAtSouth = Item {
        name("white house")
        adjectives("white", "colonial")
        description(Prose.whiteHouse)
        scenery
    }

    let whiteHouseAtBehind = Item {
        name("white house")
        adjectives("white", "colonial")
        description(Prose.whiteHouse)
        scenery
    }

    /// Barred, and named at both the north and south sides, because both
    /// descriptions mention them.
    let barredWindowsAtNorth = Item {
        name("barred windows")
        adjectives("barred")
        synonyms("window", "windows", "bars")
        description(Prose.barredWindows)
        scenery
    }

    let barredWindowsAtSouth = Item {
        name("barred windows")
        adjectives("barred")
        synonyms("window", "windows", "bars")
        description(Prose.barredWindows)
        scenery
    }

    /// Locked, with no key anywhere in the game — the mainframe's joke. The
    /// east exit out of ``westOfHouse`` refuses with the same line.
    let frontDoor = Item {
        name("front door")
        adjectives("front", "boarded", "oak")
        description(Prose.frontDoor)
        scenery
    }

    let mailbox = Item {
        name("small mailbox")
        adjectives("small")
        synonyms("box")
        firstSight(Prose.mailboxInPlace)
        description(Prose.mailbox)
        container
        openable
    }

    let leaflet = Item {
        name("leaflet")
        synonyms("pamphlet", "booklet", "mail")
        description(Prose.leaflet)
        trait(.weight, 2)
        trait(.burnable, true)
    }

    /// `BROCH`. Mainframe-only, free, and slow. It starts nowhere at all: the
    /// only way to get one is to ask for one, and then to go home and wait for
    /// the knock. No static description — while the stamp is still on it, the
    /// prospectus has an extra line.
    let brochure = Item {
        name("free brochure")
        adjectives("free", "mit", "tech")
        // `pages` because the brochure describes itself as going on "for
        // several hundred further pages", and nothing answered the word. (#233)
        synonyms("brochure", "prospectus", "pamphlet", "mail", "pages", "page")
        // A container, and open, because that is how the source affixes the
        // stamp. No `capacity(_:)`: the rule below refuses every insertion
        // outright, and two mechanisms aimed at one behaviour is one too many.
        container
        startsOpen
        trait(.weight, 30)
        trait(.burnable, true)
    }

    /// `DSTMP`. The only treasure in the game worth **nothing** to find and
    /// something to case, and the stamp's own face is the joke: one lousy
    /// point, and it says so.
    ///
    /// Named *postage stamp* rather than *Don Woods stamp*, with the name in
    /// the adjectives, for milestone 6's reason and one of its own: a
    /// capitalised display name warns at bootstrap unless it is `properName`,
    /// and a stamp is not a person — and the Library's Flathead stamp is
    /// already called *stamp*, so two treasures under one display name would
    /// have the parser asking which stamp you meant every time both were in the
    /// trophy case.
    let donWoodsStamp = Item {
        name("postage stamp")
        adjectives("don", "woods", "donald", "postage", "small", "green")
        synonyms("stamp", "stamps")
        description(Prose.donWoodsStamp)
        trait(.weight, 1)
        trait(.takeValue, 0)
        trait(.depositValue, 1)
    }

    /// Mainframe-only: the trilogy dropped the welcome mat. Milestone 8 gives
    /// it back the one trick it was built for — sliding under the oak door in
    /// the Tiny Room, which is what a punched-out key lands on. The door is
    /// ``DungeonPalantir``'s, so ``Dungeon`` wires the two together.
    let welcomeMat = Item {
        name("welcome mat")
        adjectives("welcome", "rubber")
        synonyms("mat")
        firstSight(Prose.welcomeMatInPlace)
        description(Prose.welcomeMat)
        trait(.weight, 12)
    }

    // MARK: - The forest

    /// The deep wood west and north of the house: its own north and west exits
    /// come back here, which is the mainframe's way of saying you are lost.
    let forestDeep = Location {
        name("Forest")
        description(Prose.forestDeep)
    }

    /// South of the house. East of here the trees open into the clearing, so
    /// this is the one forest room that can honestly promise sunlight.
    let forestSouth = Location {
        name("Forest")
        description(Prose.forestSouth)
    }

    /// The forest north of the house, with the great climbable tree in it.
    /// Zork I promoted this room to a Forest Path; the mainframe leaves it
    /// forest.
    let forestTree = Location {
        name("Forest")
        description(Prose.forestTree)
    }

    /// The forest at the canyon's edge — east of here the ground gives out.
    let forestCanyonEdge = Location {
        name("Forest")
        description(Prose.forestCanyonEdge)
    }

    /// The northernmost wood. Its own north exit comes back here.
    let forestNorth = Location {
        name("Forest")
        description(Prose.forestNorth)
    }

    let upATree = Location {
        name("Up a Tree")
        description(Prose.upATree)
    }

    /// The mainframe answers "tree" in every forest room — with a refusal
    /// where there is nothing worth climbing — so each room gets its own
    /// scenery stand of trees. A factory rather than eight copies of one
    /// declaration: presence is room-granular and an `Item` lives in one place,
    /// so the wood is paid for a room at a time.
    private static func forestStand() -> Item {
        Item {
            name("trees")
            adjectives("large", "tall")
            synonyms("tree", "forest", "woods")
            description(Prose.forestTrees)
            scenery
            plural
        }
    }

    let treesDeep = forestStand()
    let treesSouth = forestStand()
    let treesCanyonEdge = forestStand()
    let treesNorth = forestStand()

    /// The Clearing is not a forest room, but its description says a forest
    /// surrounds it on all sides, so the wall of trees answers there too.
    let treesAroundClearing = forestStand()

    /// Three more stands, for the three house sides whose paragraphs name the
    /// wood and could not answer for it: *the trees* south and behind, *the
    /// forest* north. (#233)
    let treesAtNorthOfHouse = forestStand()
    let treesAtSouthOfHouse = forestStand()
    let treesAtBehindHouse = forestStand()

    /// Four paths going four different places, so the text is the parameter and
    /// only the shape is shared. The Clearing's goes home, Canyon Bottom's runs
    /// north under the wall, and Behind House's is the one that answers
    /// *clearing* as well — the clearing east is what that path is for, and the
    /// only true thing to say about it from here is that you cannot see it yet.
    /// (#233)
    private static func pathScenery(_ text: String, _ nouns: ItemTrait) -> Item {
        Item {
            name("path")
            adjectives("beaten", "narrow")
            nouns
            description(text)
            scenery
        }
    }

    let pathAtSouthOfHouse = pathScenery(Prose.pathAtSouth, synonyms("path", "track", "trail"))
    let pathAtBehindHouse = pathScenery(Prose.pathAtBehind, synonyms("path", "track", "trail"))
    let pathAtClearing = pathScenery(Prose.pathAtClearing, synonyms("path", "track", "trail"))
    let pathAtCanyonBottom = pathScenery(
        Prose.pathAtCanyonBottom, synonyms("path", "track", "trail"))

    /// The game's opening room names a field and nothing in it answered for
    /// one. (#233)
    let openField = Item {
        name("field")
        adjectives("open")
        synonyms("field", "grass", "ground")
        description(Prose.openField)
        scenery
    }

    /// The clearing named from Behind House, one room short of it. Its own item
    /// and not a synonym on the path: a track and the place the track goes are
    /// two things, which is the whole argument of this repair.
    let clearingFromBehindHouse = Item {
        name("clearing")
        synonyms("clearing")
        description(Prose.clearingFromBehindHouse)
        scenery
    }

    /// And the clearing the whole wood is arranged around. No `trees` —
    /// ``treesAroundClearing`` owns those, and it is the item about them.
    let clearingGround = Item {
        name("clearing")
        adjectives("open")
        synonyms("clearing", "ground")
        description(Prose.clearingGround)
        scenery
    }

    /// The one tree worth climbing, and the only one the parser prefers to the
    /// stand of scenery around it (it is the sole `tree` in its room).
    let greatTree = Item {
        name("large tree")
        adjectives("large", "gnarled", "particularly")
        synonyms("tree", "trees", "branches", "branch")
        description(Prose.greatTree)
        scenery
    }

    /// The tree seen from the perch. Same tree, other end — and its own line,
    /// because ``Prose/greatTree`` offers the branches as a way up and points
    /// at an egg that up here is listed beside the player.
    let treeFromAbove = Item {
        name("large tree")
        adjectives("large", "gnarled")
        synonyms("tree", "trees", "branches", "branch")
        description(Prose.greatTreeFromAbove)
        scenery
    }

    let nest = Item {
        name("birds nest")
        adjectives("small", "birds")
        synonyms("nest")
        description(Prose.nest)
        surface
        scenery
    }

    /// The mainframe's values, which are not always the trilogy's: 5 to find,
    /// 5 to case. It is a container, sealed by a mechanism too fine for brute
    /// fingers — forcing it wrecks the bird inside (a host rule, since the
    /// canary lives in ``DungeonHouse``).
    let egg = Item {
        name("jewel-encrusted egg")
        adjectives("jewel", "encrusted", "jeweled", "birds")
        description(Prose.egg)
        trait(.takeValue, 5)
        trait(.depositValue, 5)
        container
        openable
    }

    /// What is left of the egg once brute fingers have been at it — the
    /// atlas's `BEGG`, which the mainframe swaps in for `EGG` the moment the
    /// clasp gives. It carries no `OFVAL` and no `OTVAL`, so a player who
    /// forces the egg forfeits the shell's ten points along with the bird's:
    /// there is nothing here the trophy case will pay for. Starts offstage
    /// with the ruined canary already inside it.
    let brokenEgg = Item {
        name("broken jewel-encrusted egg")
        adjectives("broken", "ruined", "jewel", "encrusted", "jeweled", "birds")
        description(Prose.brokenEgg)
        firstSight(Prose.brokenEggHere)
        container
    }

    /// The songbird that answers a wound canary is never quite present. The
    /// mainframe answers for it anyway, in every forest room, rather than
    /// letting "You can't see any such thing" stand against a bird the game
    /// keeps mentioning.
    let songbirdDeep = Item {
        name("songbird")
        adjectives("song")
        synonyms("bird")
        description(Prose.songbirdNotHere)
        scenery
    }

    let songbirdSouth = Item {
        name("songbird")
        adjectives("song")
        synonyms("bird")
        description(Prose.songbirdNotHere)
        scenery
    }

    let songbirdTree = Item {
        name("songbird")
        adjectives("song")
        synonyms("bird")
        description(Prose.songbirdNotHere)
        scenery
    }

    let songbirdCanyonEdge = Item {
        name("songbird")
        adjectives("song")
        synonyms("bird")
        description(Prose.songbirdNotHere)
        scenery
    }

    let songbirdNorth = Item {
        name("songbird")
        adjectives("song")
        synonyms("bird")
        description(Prose.songbirdNotHere)
        scenery
    }

    let songbirdAloft = Item {
        name("songbird")
        adjectives("song")
        synonyms("bird")
        description(Prose.songbirdNotHere)
        scenery
    }

    // MARK: - The clearing

    /// The mainframe has exactly one Clearing, and everything in the wood
    /// eventually arrives at it. Its own north and east exits come back here.
    /// Always described, because what the ground here says about the grating
    /// is the only report of it from this side, and a brief re-entry would
    /// print a bare room name over an open hole.
    let clearing = Location {
        name("Clearing")
        alwaysDescribed
    }

    /// Two channels, not one. "On the ground is a pile of leaves." is a
    /// sentence about *where the pile is* — the trilogy's `LDESC`, which is
    /// this engine's `firstSight` — and it was declared as the examine text
    /// instead, so the Clearing listed nothing at all and `x leaves` answered a
    /// question nobody had asked. It is also the only thing that tells a player
    /// there is something here to push, and the grating is under it. (#233)
    ///
    /// `scenery` is kept: it withholds the *engine's* stock listing line and
    /// never the author's, so the pile still announces itself and still cannot
    /// be picked up. Nothing in the game marks the leaves touched, so the line
    /// prints on every look, which is what the source does.
    let leaves = Item {
        name("pile of leaves")
        adjectives("dead")
        synonyms("leaves", "leaf", "pile")
        firstSight(Prose.leaves)
        description(Prose.leavesExamined)
        scenery
    }

    /// Locked by a key this milestone does not place — the maze holds it. Down
    /// through it is the Grating Room, which arrives with the maze.
    let grating = Item {
        name("iron grating")
        adjectives("iron", "metal")
        synonyms("grate", "grating")
        container
        openable
        scenery
        hidden
    }

    /// The grating's key. Declared here and placed by the maze milestone; an
    /// unplaced item is legal and resolves to `.nowhere`.
    let skeletonKeys = Item {
        name("set of skeleton keys")
        adjectives("skeleton")
        synonyms("keys", "key")
        firstSight(Prose.skeletonKeysInPlace)
        description(Prose.skeletonKeys)
        trait(.weight, 10)
        // One of the source's four `PALOBJS`. They will punch the oak door's
        // key out of the far keyhole and they will not turn its lock — the
        // mainframe answers that with its own line. See ``DungeonPalantir``.
        trait(.keyholeTool, true)
    }

    // MARK: - The Great Canyon

    let canyonView = Location {
        name("Canyon View")
        description(Prose.canyonView)
    }

    let rockyLedge = Location {
        name("Rocky Ledge")
        description(Prose.rockyLedge)
    }

    let canyonBottom = Location {
        name("Canyon Bottom")
        description(Prose.canyonBottom)
    }

    /// Canyon View names a great deal that is miles away — the White Cliffs,
    /// Aragain Falls and its rainbow, the top of the dam, the forest. One item
    /// answers for all of it rather than letting the parser deny things the
    /// room has just pointed at.
    let distantViewAtTop = Item {
        name("view")
        adjectives("distant", "marvelous")
        synonyms(
            "cliffs", "falls", "rainbow", "dam", "river", "forest", "water",
            "aragain")
        description(Prose.distantView)
        scenery
    }

    /// No *passage* here, unlike its two siblings' catch-alls: the Rocky Ledge
    /// puts a passage directly below the player and the distant view is about
    /// the miles beyond, so the one noun that is not far away gets
    /// ``rockyLedgePassage`` instead.
    let distantViewAtLedge = Item {
        name("view")
        adjectives("distant")
        synonyms("falls", "river", "water", "aragain", "flow")
        description(Prose.distantView)
        scenery
    }

    let distantViewAtBottom = Item {
        name("stream")
        adjectives("lesser")
        synonyms("falls", "runoff", "river", "water", "aragain", "flow")
        description(Prose.canyonStream)
        scenery
    }

    /// The passage the Rocky Ledge places directly below the player, which the
    /// falls go into and nobody follows. Its own item because the three views
    /// above answer for what is miles off, and this is not.
    let rockyLedgePassage = Item {
        name("passage")
        adjectives("impassable")
        synonyms("passage", "passageway")
        description(Prose.rockyLedgePassage)
        scenery
    }

    let cliffAtTop = Item {
        name("cliff")
        adjectives("rocky", "sheer")
        synonyms("ledge", "wall", "walls", "canyon")
        description(Prose.cliff)
        scenery
    }

    let cliffAtLedge = Item {
        name("cliff")
        adjectives("rocky", "sheer")
        synonyms("ledge", "wall", "walls", "canyon")
        description(Prose.cliff)
        scenery
    }

    let cliffAtBottom = Item {
        name("cliff")
        adjectives("rocky", "sheer")
        synonyms("ledge", "wall", "walls", "canyon")
        description(Prose.cliff)
        scenery
    }

    // MARK: - The post

    /// Whether the brochure has been asked for. The source's `BROCHURE-FLAG`.
    @Global var brochureOrdered = false

    /// Whether it has come. Asked for again after that, the clerk is sarcastic
    /// rather than helpful.
    @Global var brochureDelivered = false

    // MARK: - Verbs

    var verbs: [SyntaxRule] { [.sendForBrochure] }

    /// `send for brochure`, from anywhere in the Empire. The order goes out at
    /// once; what starts the three-turn clock is walking into the Kitchen, and
    /// the Kitchen is a ``DungeonHouse`` room, so ``Dungeon`` arms it.
    var actions: [IntentAction] {
        action(.sendForBrochure) {
            guard !brochureDelivered else { try reply(Prose.brochureAgain) }
            guard !brochureOrdered else { try reply(Prose.brochureOnItsWay) }
            brochureOrdered = true
            try reply(Prose.brochureOrdered)
        }
    }

    /// Called from ``Dungeon`` on every entry into the Kitchen. Re-arms until
    /// it fires, so a player who orders one and then goes underground gets it
    /// on their next visit home.
    func armTheBrochureClock() {
        guard brochureOrdered, !brochureDelivered else { return }
        startFuse("brochureArrives", after: 3)
    }

    // MARK: - Map

    /// Split into exits and placements for the reason `docs/games/dungeon.md`
    /// records as its eighth seam lesson: peak bootstrap stack depth scales
    /// with the largest single declaration body, and milestone 8's seventeenth
    /// bundle put the whole suite over the edge again. This one was the biggest
    /// body in the game after the split of milestone 7's.
    var map: WorldMap {
        aboveGroundExits
        aboveGroundPlacements
    }

    @MapBuilder private var aboveGroundExits: WorldMap {
        // The house exterior. East out of West of House is the locked front
        // door; north and south out of the side rooms are the barred windows.
        westOfHouse.north(northOfHouse)
        westOfHouse.south(southOfHouse)
        westOfHouse.west(forestDeep)
        westOfHouse.east(blocked: Prose.frontDoorRefusal)

        northOfHouse.west(westOfHouse)
        northOfHouse.east(behindHouse)
        northOfHouse.north(forestTree)
        northOfHouse.south(blocked: Prose.barredWindows)

        southOfHouse.west(westOfHouse)
        southOfHouse.east(behindHouse)
        southOfHouse.south(forestSouth)
        southOfHouse.north(blocked: Prose.barredWindows)

        behindHouse.north(northOfHouse)
        behindHouse.south(southOfHouse)
        behindHouse.east(clearing)
        // West and `in` are the kitchen window — a door into ``DungeonHouse``,
        // so the host wires them.

        // The forest. The self-referential exits are the mainframe's own.
        forestDeep.north(forestDeep)
        forestDeep.west(forestDeep)
        forestDeep.east(forestTree)
        forestDeep.south(forestSouth)
        forestDeep.up(blocked: Prose.noTreeToClimb)

        forestSouth.north(southOfHouse)
        forestSouth.east(clearing)
        forestSouth.south(forestCanyonEdge)
        forestSouth.west(forestDeep)
        forestSouth.up(blocked: Prose.noTreeToClimb)

        forestTree.north(forestSouth)
        forestTree.east(clearing)
        forestTree.south(clearing)
        forestTree.west(northOfHouse)
        forestTree.up(upATree)

        upATree.down(forestTree)
        upATree.up(blocked: Prose.cannotClimbHigher)

        forestCanyonEdge.east(canyonView)
        forestCanyonEdge.north(forestNorth)
        forestCanyonEdge.south(forestCanyonEdge)
        forestCanyonEdge.west(forestSouth)
        forestCanyonEdge.up(blocked: Prose.noTreeToClimb)

        forestNorth.north(forestNorth)
        forestNorth.southeast(canyonView)
        forestNorth.south(forestCanyonEdge)
        forestNorth.west(forestSouth)
        forestNorth.up(blocked: Prose.noTreeToClimb)

        // The clearing. Southwest is the way home; down is the grating, whose
        // room the maze milestone builds.
        clearing.southwest(behindHouse)
        clearing.southeast(forestNorth)
        clearing.north(clearing)
        clearing.east(clearing)
        clearing.west(forestTree)
        clearing.south(forestSouth)

        // The canyon, climbable in both directions. North out of the bottom
        // reaches the End of Rainbow, which the river milestone builds.
        canyonView.down(rockyLedge)
        canyonView.south(forestCanyonEdge)
        canyonView.west(forestNorth)
        rockyLedge.up(canyonView)
        rockyLedge.down(canyonBottom)
        canyonBottom.up(rockyLedge)
    }

    @MapBuilder private var aboveGroundPlacements: WorldMap {
        whiteHouseAtWest.starts(in: westOfHouse)
        whiteHouseAtNorth.starts(in: northOfHouse)
        whiteHouseAtSouth.starts(in: southOfHouse)
        whiteHouseAtBehind.starts(in: behindHouse)
        barredWindowsAtNorth.starts(in: northOfHouse)
        barredWindowsAtSouth.starts(in: southOfHouse)
        frontDoor.starts(in: westOfHouse)
        mailbox.starts(in: westOfHouse)
        leaflet.starts(inside: mailbox)
        welcomeMat.starts(in: westOfHouse)

        // The brochure starts nowhere and the stamp starts in the brochure,
        // which is what the atlas records for both: `BROCH` "by code", `DSTMP`
        // "in `BROCH`".
        donWoodsStamp.starts(inside: brochure)

        treesDeep.starts(in: forestDeep)
        treesSouth.starts(in: forestSouth)
        treesCanyonEdge.starts(in: forestCanyonEdge)
        treesNorth.starts(in: forestNorth)
        treesAroundClearing.starts(in: clearing)
        treesAtNorthOfHouse.starts(in: northOfHouse)
        treesAtSouthOfHouse.starts(in: southOfHouse)
        treesAtBehindHouse.starts(in: behindHouse)

        openField.starts(in: westOfHouse)
        clearingGround.starts(in: clearing)
        pathAtSouthOfHouse.starts(in: southOfHouse)
        pathAtBehindHouse.starts(in: behindHouse)
        clearingFromBehindHouse.starts(in: behindHouse)
        pathAtClearing.starts(in: clearing)
        pathAtCanyonBottom.starts(in: canyonBottom)
        greatTree.starts(in: forestTree)
        treeFromAbove.starts(in: upATree)
        nest.starts(in: upATree)
        egg.starts(on: nest)

        songbirdDeep.starts(in: forestDeep)
        songbirdSouth.starts(in: forestSouth)
        songbirdTree.starts(in: forestTree)
        songbirdCanyonEdge.starts(in: forestCanyonEdge)
        songbirdNorth.starts(in: forestNorth)
        songbirdAloft.starts(in: upATree)

        leaves.starts(in: clearing)
        grating.starts(in: clearing)
        grating.lockedBy(skeletonKeys)

        distantViewAtTop.starts(in: canyonView)
        distantViewAtLedge.starts(in: rockyLedge)
        rockyLedgePassage.starts(in: rockyLedge)
        distantViewAtBottom.starts(in: canyonBottom)
        cliffAtTop.starts(in: canyonView)
        cliffAtLedge.starts(in: rockyLedge)
        cliffAtBottom.starts(in: canyonBottom)
    }

    // MARK: - Rules

    var rules: Rules {
        groundRules
        brochureRules
    }

    @RuleBuilder private var groundRules: Rules {
        // The source's own `CLEARING` routine: one line for a grating that has
        // been uncovered, another once it is open, and nothing at all while the
        // leaves are still over it.
        clearing.describe {
            guard grating.isRevealed else { return Prose.clearing }
            let underfoot = grating.isOpen ? Prose.gratingOpenInClearing : Prose.gratingInClearing
            return "\(Prose.clearing)\n\n\(underfoot)"
        }

        frontDoor.before(.open) {
            try refuse(Prose.frontDoorRefusal)
        }

        // Run the built-in open, then say what is inside.
        mailbox.before(.open) {
            try proceed()
            say(Prose.mailboxEmbellishment)
        }

        // `reply` rather than `require`: "already moved" owns the whole turn's
        // answer, it does not merely block a default with a complaint.
        leaves.before(.push) {
            guard !grating.isRevealed else { try reply(Prose.leavesAlreadyMoved) }
            grating.reveal()
            try reply(Prose.leavesMoveEmbellishment)
        }

        // The grating's lock, its opening and its light are the host's as of
        // milestone 4: the keys lie in the maze and the room below it belongs
        // to another bundle.

        // `climb tree` reaches the same perch `up` does, and `enter(_:)` is what
        // makes that true of the arrival as well as the destination: the exit
        // describes the perch as an entry, so the rule has to too.
        greatTree.before(.climb) {
            try enter(upATree)
            try handled()
        }

        // Everywhere else in the wood, the trees refuse the climb in the
        // mainframe's own words — the same line the blocked `up` exit gives.
        for stand in [treesDeep, treesSouth, treesCanyonEdge, treesNorth] {
            stand.before(.climb) {
                try refuse(Prose.noTreeToClimb)
            }
        }
    }

    /// The prospectus, and the stamp on it.
    @RuleBuilder private var brochureRules: Rules {
        // The stamp's own line, printed only while it is still affixed. The
        // engine's `read` prints the item's description, so this is a `describe`
        // rule and not an `after(.read)` embellishment: the two would otherwise
        // both be true of one object and the second would be a static trait the
        // first is forbidden to sit beside.
        brochure.describe {
            guard brochure.holds(donWoodsStamp) else { return Prose.brochure }
            return "\(Prose.brochure)\n\n\(Prose.brochureStampAffixed)"
        }

        // Taking the stamp is the whole of what the brochure is a container
        // for, so once it is out the brochure stops behaving as one. Nothing
        // else in the game fits in it anyway; what this stops is `put the coffin
        // in the brochure`.
        brochure.before(.putIn) { try refuse(Prose.brochureHoldsNothing) }
    }

    // MARK: - The wood

    /// Whether `here` is somewhere the songbird can hear you — the mainframe's
    /// `BIRDBIT` set: the five Forest rooms and the perch above one of them,
    /// but not the Clearing.
    ///
    /// Internal rather than private because the host's canary trick needs the
    /// same set, and one list in one place is what stops a later milestone from
    /// adding a forest room to only half of them.
    ///
    /// - Parameter here: the room to test.
    /// - Returns: true when the songbird is within earshot.
    func isInTheWood(_ here: Location) -> Bool {
        here == forestDeep || here == forestSouth || here == forestTree
            || here == forestCanyonEdge || here == forestNorth || here == upATree
    }

    var timers: [TimedEvent] {
        // The mainframe's forest ambience: roughly one turn in ten among the
        // trees, a songbird is heard off in the distance. It guards before it
        // draws, so a turn spent anywhere else burns no randomness.
        daemon("forestSongbird", autostart: true) {
            guard isInTheWood(player.location) else { return }
            guard chance(10) else { return }
            say(Prose.songbirdHeard)
        }

        // The postal service, three turns after you last walked into the
        // Kitchen. The knock is heard wherever you are — the source prints it
        // unconditionally, and a player who orders one and then goes down the
        // trap door hears it from the cellar.
        fuse("brochureArrives", after: 3) {
            brochureDelivered = true
            brochure.move(inside: mailbox)
            say(Prose.brochureKnock)
        }
    }
}
