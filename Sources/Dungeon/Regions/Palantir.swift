import Gnusto

extension Intent {
    /// Slide a flat thing into a gap. The mainframe spells the mat-under-the-
    /// oak-door move this way and the engine carries no row for it, so the word
    /// lives with the one door in the game that has a gap under it.
    #verb(
        "putUnder",
        ["put", .directObject, "under", .indirectObject],
        ["slide", .directObject, "under", .indirectObject],
        ["push", .directObject, "under", .indirectObject])

    /// Look through a hole rather than into a container. `look in` is already
    /// the engine's `.lookIn` and means *search*, which is the wrong question
    /// to ask a keyhole; this is the right one, and the barred window answers
    /// it too.
    #verb(
        "lookThrough",
        ["look", "through", .directObject],
        ["peer", "through", .directObject])
}

/// The palantir wing — seven rooms, two crystal spheres, and the last thirty
/// points the main dungeon has to pay.
///
/// The shape of it: the Torch Room opens **west** on the Tiny Room (the seam
/// milestone 3 left and named at its declaration site), and the Tiny Room's
/// north wall is `PDOOR`, an oak door with a keyhole on each side of it and the
/// key in the far one. Behind the door is the Dreary Room and the blue sphere.
/// The rest of the wing hangs off the Slide Room's chute: a rope rigged at the
/// top turns milestone 3's one-way drop into a climb, three stretches down the
/// chute is a ledge, and south of the ledge is the Sooty Room and the red
/// sphere.
///
/// **The oak-door puzzle, in one sentence.** Open the near lid, slide the
/// welcome mat under the door, put something long into the near keyhole to
/// punch the key out of the far one, take the mat to get the key off it, empty
/// the near keyhole, and unlock the door. Two ways to lose: the lid falls back
/// over the keyhole the second time you take a tool while it stands open
/// (`PCHECK`), and punching the key out with no mat under the door removes it
/// from the game for good.
///
/// **There is no trap on entering the Dreary Room.** No slam, no timer, no
/// death. The room is `RSACREDBIT`, so the thief can never follow you in or
/// lift the sphere off the table.
///
/// **The three palantirs do not combine.** It is the obvious guess and it is
/// wrong. `look in <sphere>` shows the room the *next* sphere is in, on a fixed
/// one-way cycle blue → red → white → blue, and does nothing else: no teleport,
/// no score, no third-sphere effect. The cycle crosses into ``DungeonAlice``,
/// so ``Dungeon`` wires it.
///
/// **`PWIND` is not an exit.** The source files the barred window in both rooms
/// under `#!#!#`, a direction atom no player input can produce — it gives the
/// window scope on both sides without giving it a walkable direction. Here that
/// is simply a scenery item in each room, the way ``DungeonMirror`` already
/// carries two mirrors for one passage.
///
/// The seams the host wires are the Tiny Room's east passage into the Torch
/// Room (``DungeonTemple``), the whole of the chute — its top is the Slide Room
/// (``DungeonMirror``) and its bottom the Cellar (``DungeonHouse``) — the
/// welcome mat (``DungeonAboveGround``), the skeleton keys' refusal, and the
/// scrying cycle. See `Dungeon+Palantir.swift` and `FIDELITY.md`.
struct DungeonPalantir: GameContent {
    // MARK: - Rooms

    /// `PRM`. Dark, and the only room in the wing the thief may walk into: it
    /// is the one the source does not mark `RSACREDBIT`.
    let tinyRoom = Location {
        name("Tiny Room")
        description(Prose.tinyRoom)
        dark
    }

    /// `PALAN`. Lit — by a red glow through a crack in the wall, which is the
    /// matched half of the Sooty Room's stove. The two rooms are **not**
    /// connected; the pair of descriptions is a hint and nothing more.
    let drearyRoom = Location {
        name("Dreary Room")
        description(Prose.drearyRoom)
    }

    /// `SLID1`–`SLID3`. Three stretches of the same chute under the same name,
    /// entered only on a rope and dark all the way down.
    private static func slideStretch() -> Location {
        Location {
            name("Slide")
            description(Prose.slideStretch)
            dark
        }
    }

    let slideOne = slideStretch()
    let slideTwo = slideStretch()
    let slideThree = slideStretch()

    /// `SLEDG`. Reaching it cancels the grip fuse outright, so the ledge is safe
    /// and the climb back up is untimed. Its `up` goes to `SLID2` and not to
    /// `SLID3` — the source's own asymmetry, kept.
    let slideLedge = Location {
        name("Slide Ledge")
        description(Prose.slideLedge)
        dark
    }

    /// `SPAL`. Lit by the stove, and the red sphere is here.
    let sootyRoom = Location {
        name("Sooty Room")
        description(Prose.sootyRoom)
    }

    /// The three rooms the grip fuse can fire in — everywhere in the chute but
    /// the ledge, which is the safe step off it.
    var chuteRooms: [Location] { [slideOne, slideTwo, slideThree] }

    // MARK: - State

    /// Whether the welcome mat is lying under the oak door. The door's own
    /// paragraph reports it, and it is the difference between a key you can
    /// pick up and a key that has left the game.
    @Global var matUnderDoor = false

    /// Whether the punched-out key is lying on the mat rather than on the
    /// floor. Cleared when the mat is moved, which is what drops the key.
    @Global var keyOnMat = false

    /// `PCHECK`'s counter: how many times a keyhole tool has been taken while
    /// the near lid stood open. The second one shuts it.
    @Global var keyholeToolTakes = 0

    /// Which of the two anchors took the knot. There are only two — the broken
    /// timber and the gold coffin — so one flag says which, and it is read only
    /// while ``Dungeon/chuteRopeRigged``. A `Bool` rather than the anchor's `EntityID`
    /// because `GlobalValue` covers the scalars.
    @Global var chuteAnchorIsTheCoffin = false

    // MARK: - The oak door and its fittings

    /// `PDOOR`. No static description: whether the mat is under it is a fact
    /// the paragraph carries.
    let oakDoor = Item {
        name("door made of oak")
        adjectives("oak", "oaken", "massive", "wooden")
        synonyms("door", "doors")
        openable
        scenery
    }

    /// `PWIND`, filed in both rooms. Two items, one window — the shape
    /// ``DungeonMirror`` already uses for its pair of mirrors.
    private static func barredWindow() -> Item {
        Item {
            name("barred window")
            adjectives("barred", "small", "iron")
            synonyms("window", "windows", "bars", "bar", "grille")
            description(Prose.barredWindow)
            scenery
        }
    }

    let tinyRoomWindow = barredWindow()
    let drearyRoomWindow = barredWindow()

    /// `PLID1` and `PLID2`. The near one starts **closed** and the far one
    /// open, which is what makes the punch possible at all. No static
    /// description: which way it is hinged is the whole of what it says.
    private static func metalLid(startsOpen open: Bool) -> Item {
        Item {
            name("metal lid")
            adjectives("metal", "small", "hinged")
            synonyms("lid", "cover", "plate")
            openable
            scenery
            if open { startsOpen }
        }
    }

    let lidTiny = metalLid(startsOpen: false)
    let lidDreary = metalLid(startsOpen: true)

    /// `PKH1` and `PKH2`. Containers, because what is in one is the puzzle; no
    /// static description, because what is in one changes.
    private static func keyhole() -> Item {
        Item {
            name("keyhole")
            synonyms("hole", "lock", "keyholes")
            container
            scenery
        }
    }

    let keyholeTiny = keyhole()
    let keyholeDreary = keyhole()

    /// `PKEY`. Starts in the far keyhole, and the only thing that turns this
    /// lock. One of the four `PALOBJS` that fit a keyhole at all.
    let rustyIronKey = Item {
        name("rusty iron key")
        adjectives("rusty", "iron")
        // No `keys`: there is one of it, and the maze's set of skeleton keys
        // answers to that word already. A player standing in this room with
        // both would otherwise be asked which they meant every time.
        synonyms("key")
        description(Prose.rustyIronKey)
        trait(.keyholeTool, true)
    }

    /// `PTABL`. The blue sphere sits on it, which is what Zork II's line for
    /// that sphere says, so the surface has to be real.
    let dustyTable = Item {
        name("dusty table")
        adjectives("dusty", "wooden", "plain")
        synonyms("table", "tables", "dust", "floor")
        description(Prose.dustyTable)
        surface
        scenery
    }

    /// `PCRAK`, and a second one the source does not have. `SPAL`'s description
    /// names "a very narrow crack in the north wall" and the only crack object
    /// in the source is filed in `PALAN`, so `examine crack` in the Sooty Room
    /// would find nothing there. Every printed noun must answer, so the Sooty
    /// Room gets a crack of its own.
    /// The `glow` synonym belongs to the Dreary Room's crack and not to the
    /// Sooty Room's, because in the Sooty Room the glow is the stove's and the
    /// stove is standing right there. Two rooms, one noun, two answers.
    private static func narrowCrack(_ text: String, alsoTheGlow: Bool) -> Item {
        Item {
            name("narrow crack")
            adjectives("narrow", "very", "small")
            synonyms("crack", "cracks", "fissure", "chink")
            if alsoTheGlow { synonyms("glow", "light", "wall") }
            description(text)
            scenery
        }
    }

    let drearyCrack = narrowCrack(Prose.drearyCrack, alsoTheGlow: true)
    let sootyCrack = narrowCrack(Prose.sootyCrack, alsoTheGlow: false)

    /// `STOVE`. Mainframe-only, and the source of the light in two rooms that
    /// are nowhere near each other.
    let coalStove = Item {
        name("old coal stove")
        adjectives("old", "coal", "iron", "squat")
        synonyms("stove", "fire", "coals", "embers", "glow", "soot", "ceiling", "floor")
        description(Prose.coalStove)
        scenery
    }

    // MARK: - The chute's furniture

    /// `SLIDE` the object, which the source gives to all five chute rooms
    /// through `SLIDEBIT`. The Slide Room's own is ``DungeonMirror``'s
    /// `metalSlide`; these four are the rooms below it.
    private static func chuteWall() -> Item {
        Item {
            name("metal chute")
            adjectives("metal", "steep", "sheet")
            synonyms("chute", "shaft", "walls", "wall")
            description(Prose.chute)
            scenery
        }
    }

    let slideOneChute = chuteWall()
    let slideTwoChute = chuteWall()
    let slideThreeChute = chuteWall()
    let slideLedgeChute = chuteWall()

    /// `SROPE`, and it **is** here now. It used to be left out on the ground
    /// that "the coil is in your hands the whole way down and a held item is
    /// always in scope" — and the premise was false: ``Dungeon/rigTheChute()``
    /// set a flag and never moved ``DungeonHouse/rope``, so the coil stayed
    /// wherever it had been dropped in the Slide Room and `x rope` in the
    /// chute answered *"You can't see any such thing."* under a paragraph
    /// beginning *"You are hanging on a rope."* Two rules that assumed the
    /// rope was down here were dead for the same reason — the `take` guard
    /// and the let-go-and-fall branch. (#329)
    ///
    /// Five fittings, offstage until the knot is tied: one per stretch, one on
    /// the ledge, and one at the head of the chute in the Slide Room, which is
    /// where the knot actually is and so is where the state lives.
    let slideOneRope = hangingRope(Prose.ropeInTheChute)
    let slideTwoRope = hangingRope(Prose.ropeInTheChute)
    let slideThreeRope = hangingRope(Prose.ropeInTheChute)
    let slideLedgeRope = hangingRope(Prose.ropeFromTheLedge)
    let chuteHeadRope = hangingRope(Prose.ropeAtTheChuteHead)

    /// The three stretches' fittings, beside the rooms they stand in. These are
    /// the ones a player can be hanging on, which is what ``isChuteRope(_:)``
    /// asks and what the let-go-and-fall branch answers.
    var chuteStretchRopes: [(Item, Location)] {
        [(slideOneRope, slideOne), (slideTwoRope, slideTwo), (slideThreeRope, slideThree)]
    }

    /// Every fitting the knot puts onstage, beside the room each stands in.
    /// Derived from ``chuteStretchRopes`` rather than written out again, so a
    /// fourth stretch cannot be added to one list and forgotten in the other —
    /// which is the failure this whole repair exists to stop.
    var chuteRopeFittings: [(Item, Location)] {
        chuteStretchRopes + [(slideLedgeRope, slideLedge)]
    }

    /// Whether the named thing is the rope in a stretch of chute — which is
    /// what a player who types `take rope` while hanging on it has named.
    ///
    /// - Parameter named: what the command's direct object resolved to.
    /// - Returns: `true` for a stretch's fitting; the ledge's is out of reach
    ///   and answers at stage 0 instead.
    func isChuteRope(_ named: Item) -> Bool {
        chuteStretchRopes.contains { $0.0 == named }
    }

    let slideLedgeOpening = Item {
        name("low opening")
        adjectives("low", "narrow")
        synonyms("opening", "gap", "doorway", "soot", "ledge")
        description(Prose.slideLedgeOpening)
        scenery
    }

    /// The Tiny Room is bare, and *bare* is a thing a player will look at.
    let tinyRoomWalls = Item {
        name("bare walls")
        adjectives("bare", "empty")
        synonyms("wall", "walls", "passage", "floor", "room", "dust")
        description(Prose.tinyRoomWalls)
        scenery
        plural
    }

    // MARK: - The treasures

    /// `PALAN` the object, which shares its name with the room it starts in.
    /// Ten to find and five to case.
    let blueSphere = Item {
        name("blue crystal sphere")
        adjectives("blue", "crystal", "beautiful")
        synonyms("sphere", "ball", "palantir", "globe")
        firstSight(Prose.blueSphereFirstSight)
        description(Prose.blueSphere)
        trait(.weight, 10)
        trait(.takeValue, 10)
        trait(.depositValue, 5)
    }

    /// `PAL3`. Ten to find and five to case, the same as the blue one.
    let redSphere = Item {
        name("red crystal sphere")
        adjectives("red", "crystal", "beautiful")
        synonyms("sphere", "ball", "palantir", "globe")
        firstSight(Prose.redSphereFirstSight)
        description(Prose.redSphere)
        trait(.weight, 10)
        trait(.takeValue, 10)
        trait(.depositValue, 5)
    }

    // MARK: - Verbs

    var verbs: [SyntaxRule] { [.putUnder, .lookThrough] }

    var actions: [IntentAction] {
        action(.putUnder) { try reply(Prose.matNowhereToPutIt) }
        action(.lookThrough) { try reply(Prose.nothingToLookThrough) }
    }

    // MARK: - Map

    var map: WorldMap {
        palantirExits
        palantirPlacements
        chutePlacements
    }

    /// Split from the placements for the reason `docs/games/dungeon.md` records
    /// as its eighth seam lesson: peak bootstrap stack depth scales with the
    /// largest single declaration body, and this is the seventeenth bundle.
    @MapBuilder private var palantirExits: WorldMap {
        // The Tiny Room. East is the Torch Room, a ``DungeonTemple`` room —
        // host-wired. North and in are the same doorway.
        tinyRoom.north(drearyRoom, via: oakDoor)
        tinyRoom.in(drearyRoom, via: oakDoor)

        // The Dreary Room, which has the one door and nothing else.
        drearyRoom.south(tinyRoom, via: oakDoor)
        drearyRoom.out(tinyRoom, via: oakDoor)

        // The chute. `SLID1`'s up is the Slide Room and `SLID3`'s and the
        // ledge's down is the Cellar; all three cross a bundle and are the
        // host's.
        slideOne.down(slideTwo)
        slideTwo.down(slideThree)
        slideTwo.up(slideOne)
        slideThree.up(slideTwo)
        slideThree.east(slideLedge)

        // The ledge, whose `up` skips a stretch. The source's asymmetry.
        slideLedge.up(slideTwo)
        slideLedge.south(sootyRoom)

        sootyRoom.north(slideLedge)
    }

    @MapBuilder private var palantirPlacements: WorldMap {
        oakDoor.lockedBy(rustyIronKey)

        oakDoor.starts(in: drearyRoom)
        tinyRoomWindow.starts(in: tinyRoom)
        tinyRoomWalls.starts(in: tinyRoom)
        lidTiny.starts(in: tinyRoom)
        keyholeTiny.starts(in: tinyRoom)

        drearyRoomWindow.starts(in: drearyRoom)
        lidDreary.starts(in: drearyRoom)
        keyholeDreary.starts(in: drearyRoom)
        rustyIronKey.starts(inside: keyholeDreary)
        dustyTable.starts(in: drearyRoom)
        drearyCrack.starts(in: drearyRoom)
        // On the floor of the room rather than `starts(on: dustyTable)`, and
        // the difference is prose rather than physics. The engine lists a
        // surface's contents itself — "On the dusty table is a blue crystal
        // sphere." — which would replace the trilogy line the prose policy
        // directed us to take, and that line already says where the sphere is
        // sitting. The table is right there to be examined either way.
        blueSphere.starts(in: drearyRoom)
    }

    @MapBuilder private var chutePlacements: WorldMap {
        slideOneChute.starts(in: slideOne)
        slideTwoChute.starts(in: slideTwo)
        slideThreeChute.starts(in: slideThree)
        slideLedgeChute.starts(in: slideLedge)
        slideLedgeOpening.starts(in: slideLedge)

        coalStove.starts(in: sootyRoom)
        sootyCrack.starts(in: sootyRoom)
        redSphere.starts(in: sootyRoom)
    }

    // MARK: - Rules

    var rules: Rules {
        doorRules
        lidRules(lidTiny, over: keyholeTiny)
        lidRules(lidDreary, over: keyholeDreary)
        keyholeRules
        windowRules
        chuteRules
    }
}

// MARK: - The oak door

extension DungeonPalantir {
    @RuleBuilder fileprivate var doorRules: Rules {
        oakDoor.describe { Prose.oakDoor(matUnderIt: matUnderDoor) }

        // The game-wide line names whatever it is refusing to open, and this
        // door's full name — "the door made of oak" — reads badly in it.
        oakDoor.before(.open) {
            try require(!oakDoor.isLocked, else: Prose.doorIsLocked)
        }

        // Unlocking. `lockedBy` already knows which key fits; what this adds is
        // the one thing the engine cannot know — a tool left in the near
        // keyhole is in the way of the wards, and the source will not turn the
        // lock over it. The wrong-key refusal is the game's, not this rule's,
        // so the skeleton keys get the same answer here as they get at the
        // grating. (#263)
        oakDoor.before(.unlock) {
            try require(command.indirectObject == rustyIronKey, else: gameText.wrongKey())
            try require(keyholeTiny.contents.isEmpty, else: Prose.keyholeBlocked)
            try require(oakDoor.isLocked, else: gameText.alreadyUnlocked())
            oakDoor.isLocked = false
            try reply(Prose.doorUnlocked)
        }
    }

    /// Sliding the welcome mat under the door. The mat is a
    /// ``DungeonAboveGround`` item, so ``Dungeon`` owns the clause that names
    /// it and calls this.
    ///
    /// - Parameter mat: the mat, which ends up on this room's floor.
    /// - Throws: always — a `TurnInterrupt`, since every path here either
    ///   refuses or replies.
    func slideMatUnderTheDoor(_ mat: Item) throws -> Never {
        try require(player.location == tinyRoom, else: Prose.matNowhereToPutIt)
        try require(!matUnderDoor, else: Prose.matAlreadyUnder)
        matUnderDoor = true
        mat.move(to: tinyRoom)
        try reply(Prose.matSlidesUnder)
    }

    /// Picking the mat back up, which is what gets the key off it. Does not
    /// throw: the take completes, and the key lands on the sentence after
    /// "Taken."
    func liftTheMat() {
        guard matUnderDoor else { return }
        matUnderDoor = false
        guard keyOnMat else { return }
        keyOnMat = false
        rustyIronKey.move(to: tinyRoom)
        say(Prose.matTakenWithKey)
    }
}

// MARK: - The two lids

extension DungeonPalantir {
    /// One lid over one keyhole, both sides of the door. Two identical pairs,
    /// so one function rather than eight rules written twice.
    ///
    /// - Parameters:
    ///   - lid: the hinged plate.
    ///   - keyhole: what it covers.
    /// - Returns: the pair's four rules.
    @RuleBuilder fileprivate func lidRules(_ lid: Item, over keyhole: Item) -> Rules {
        lid.describe { Prose.metalLid(open: lid.isOpen) }

        lid.before(.open) {
            try require(!lid.isOpen, else: gameText.alreadyOpen())
            lid.isOpen = true
            try reply(Prose.lidOpens)
        }

        // A lid will not close over an occupied keyhole, which is the source's
        // own refusal and the reason a screwdriver left in the lock is a
        // problem rather than a convenience.
        lid.before(.close) {
            try require(lid.isOpen, else: gameText.alreadyClosed())
            try require(keyhole.contents.isEmpty, else: Prose.keyholeOccupied)
            lid.isOpen = false
            try reply(Prose.lidCloses)
        }

        keyhole.describe {
            Prose.keyhole(holding: keyhole.contents.first?.indefiniteName)
        }

        // `search keyhole` is the engine's `.lookIn`, and a container answers it
        // by listing what is inside. With the lid down there is nothing to
        // look into, so the lid answers first.
        keyhole.before(.lookIn) {
            try require(lid.isOpen, else: Prose.lidInTheWay)
        }
    }
}

// MARK: - The keyholes, and the punch

extension DungeonPalantir {
    @RuleBuilder fileprivate var keyholeRules: Rules {
        // The near keyhole: the one the punch is made through.
        keyholeTiny.before(.putIn) {
            guard let tool = command.directObject else { return }
            try admit(tool, into: keyholeTiny, under: lidTiny)
            // No "has it been punched already" flag: the punch takes the key
            // out of the far keyhole and nothing anywhere puts it back, so
            // `holds` is the flag.
            guard lidDreary.isOpen, keyholeDreary.holds(rustyIronKey) else {
                try reply(Prose.doorNothingToPunch)
            }
            keyOnMat = matUnderDoor
            // Either way it leaves the far keyhole. With the mat under the door
            // it is lying on the mat and comes back when the mat is lifted;
            // without it, it is gone for good and the wing is unwinnable.
            rustyIronKey.vanish()
            try reply(Prose.doorPunched)
        }

        // The far one, which has nothing on its far side to punch.
        keyholeDreary.before(.putIn) {
            guard let tool = command.directObject else { return }
            try admit(tool, into: keyholeDreary, under: lidDreary)
            try reply(Prose.doorNothingToPunch)
        }

        // Peering through. Both lids open, both keyholes empty, and light on
        // the far side — which the Tiny Room never has, so the view is one-way.
        // One loop over the two sides, so the near and far halves of each rule
        // cannot be crossed against the wrong pair.
        let sides = [
            (keyholeTiny, lidTiny, tinyRoom),
            (keyholeDreary, lidDreary, drearyRoom),
        ]
        for (near, far) in [(sides[0], sides[1]), (sides[1], sides[0])] {
            near.0.before(.lookThrough) {
                try require(near.1.isOpen, else: Prose.lidInTheWay)
                try require(near.0.contents.isEmpty, else: Prose.keyholeBlocked)
                let clear = far.1.isOpen && far.0.contents.isEmpty && far.2.isLit
                try reply(clear ? Prose.keyholeLit : Prose.keyholeDark)
            }
        }

        // `PCHECK`. It runs every turn in the source; here it hangs off the one
        // room it can matter in, and counts the same takes. One decode and one
        // encode rather than two of each: a `@Global` read is a JSON round trip.
        tinyRoom.after(.take) {
            guard let taken = command.directObject, taken[default: .keyholeTool] else { return }
            guard lidTiny.isOpen else { return }
            let takes = keyholeToolTakes + 1
            keyholeToolTakes = takes
            guard takes == 2 else { return }
            lidTiny.isOpen = false
            say(Prose.lidFalls)
        }
    }

    /// The three refusals every keyhole shares, and the placement if none of
    /// them fires.
    ///
    /// - Parameters:
    ///   - tool: what the sentence offered.
    ///   - keyhole: the keyhole it was offered to.
    ///   - lid: the lid over that keyhole.
    /// - Throws: a `TurnInterrupt` when any of the three refusals fires.
    private func admit(_ tool: Item, into keyhole: Item, under lid: Item) throws {
        try require(lid.isOpen, else: Prose.lidInTheWay)
        try require(keyhole.contents.isEmpty, else: Prose.keyholeOccupied)
        // `guard`/`refuse` rather than `require`, because `require` takes a
        // plain `String` and would render the name on every success too.
        guard tool[default: .keyholeTool] else {
            try refuse(
                Prose.doesntFitTheKeyhole(GameText.sentenceCase(tool.definiteName)))
        }
        tool.move(inside: keyhole)
    }
}

// MARK: - The barred window

extension DungeonPalantir {
    @RuleBuilder fileprivate var windowRules: Rules {
        seeThroughWindow(tinyRoomWindow, into: drearyRoom)
        seeThroughWindow(drearyRoomWindow, into: tinyRoom)
    }

    /// The window's whole trick: it shows you the other room in full, contents
    /// and all, so the table and the blue sphere are visible long before they
    /// are reachable. Going through it is not on offer.
    ///
    /// - Parameters:
    ///   - window: the window on this side.
    ///   - room: the room on the other.
    /// - Returns: the window's two rules.
    @RuleBuilder fileprivate func seeThroughWindow(_ window: Item, into room: Location) -> Rules {
        window.before(.lookThrough) {
            // Its own line, not the keyhole's. The two apertures are separate
            // declarations with separate rules and they shared one dark
            // branch, so `look through window` in the Dreary Room — whose
            // description prints an oak door and a small barred window and no
            // keyhole at all — answered "No light comes through the keyhole at
            // all." about a fitting the room never named. (#350)
            guard room.isLit else { try reply(Prose.windowDark) }
            // The same "what can be made out in there" the palantirs use, so
            // *loose* means one thing in both. Deliberately nothing nested: the
            // far keyhole is a container with the key in it, and a window that
            // reported the key would hand over the whole puzzle from the wrong
            // side of the door.
            try reply(
                Prose.seenThroughTheWindow(room.description, remoteView(of: room)))
        }

        window.before(.board, .climb) { try refuse(Prose.windowNotAWay) }
    }
}

// MARK: - The chute

extension DungeonPalantir {
    @RuleBuilder fileprivate var chuteRules: Rules {
        // Stepping onto the ledge is what makes the climb safe. `onEnter` runs
        // after the move, which is exactly when the grip stops mattering.
        slideLedge.onEnter { stopFuse("slideGrip") }

        coalStove.before(.take, .push, .pull) { try refuse(Prose.stoveWontMove) }
    }

    /// The shortest a grip ever lasts, which is also the length the fuse is
    /// declared at so the two cannot drift.
    static let shortestGrip = 2

    /// How long a grip lasts: the source's `100 / carried weight`, floored, and
    /// a player carrying nothing at all still gets the floor rather than a
    /// division by zero.
    var gripTurns: Int {
        max(100 / max(player.carriedWeight(), 1), Self.shortestGrip)
    }
}
