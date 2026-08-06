import Gnusto

/// The palantir wing's seams, and the free brochure's one.
///
/// ``DungeonPalantir`` owns seven rooms and everything inside them. What is
/// here is everything about those rooms that names another bundle, which is
/// most of the way in and all of the way down:
///
/// - the **Tiny Room's east passage**, which is the Torch Room's west doorway —
///   the seam milestone 3 declared and named at `Temple.swift`;
/// - the **chute**, whose head is the Slide Room (``DungeonMirror``), whose
///   foot is the Cellar (``DungeonHouse``), and whose rope and anchors are
///   ``DungeonHouse``'s coil and either ``DungeonCoalMine``'s broken timber or
///   ``DungeonTemple``'s gold coffin;
/// - the **welcome mat**, which is ``DungeonAboveGround``'s and is the only
///   thing in the game flat enough to go under the oak door;
/// - the **skeleton keys**, which fit the oak door's keyhole and will not turn
///   its lock;
/// - the **scrying cycle**, which runs blue → red → **white** → blue, and the
///   white one is ``DungeonAlice``'s;
/// - and the **brochure's clock**, which is armed by walking into the Kitchen,
///   a ``DungeonHouse`` room.
///
/// Its own file rather than more of `Dungeon.swift`, for `Dungeon+Thief.swift`'s
/// reason exactly: the host is eleven hundred lines before this arrives, and
/// that is long enough without a seventeenth region's worth on the end of it.
extension Dungeon {
    // MARK: - Map

    /// Milestone 8 — the way into the palantir wing, and the way down the
    /// chute.
    @MapBuilder var milestoneEightMap: WorldMap {
        // The Torch Room's west doorway. Milestone 3 built the room with the
        // doorway in its description and said the room behind it was a later
        // milestone's; this is that milestone.
        templeQuarter.torchRoom.west(palantirWing.tinyRoom)
        palantirWing.tinyRoom.east(templeQuarter.torchRoom)

        // `SLIDE-EXIT`. The chute always takes you; what the rope decides is
        // where you land. A dynamic exit rather than a conditional one for
        // exactly that reason — there is no refusal here, only two
        // destinations.
        mirrors.slideRoom.exit(
            .down,
            toward: { palantirWing.chuteRopeRigged ? palantirWing.slideOne : house.cellar })

        // Up out of the top stretch is the Slide Room again; down out of the
        // bottom stretch and off the ledge is the Cellar, both one-way.
        palantirWing.slideOne.up(mirrors.slideRoom)
        palantirWing.slideThree.down(house.cellar)
        palantirWing.slideLedge.down(house.cellar)
    }

    // MARK: - Rules

    /// Milestone 8 — everything about the wing that names another bundle.
    @RuleBuilder var palantirRules: Rules {
        palantirDoorRules
        palantirChuteRules
        palantirScryingRules

        // The brochure's three-turn clock. The order can be placed anywhere;
        // what starts the postman is going home, and the Kitchen is a
        // ``DungeonHouse`` room while the brochure is ``DungeonAboveGround``'s.
        house.kitchen.onEnter { aboveGround.armTheBrochureClock() }
    }

    /// The oak door's two cross-bundle clauses: the mat that goes under it and
    /// the keys that will not turn it.
    @RuleBuilder private var palantirDoorRules: Rules {
        // `put mat under door`. The mat is the direct object and the door the
        // indirect one, and indirect-object rules run first — so this fires
        // before anything the mat itself might have to say.
        palantirWing.oakDoor.before(.putUnder) {
            try require(
                command.directObject == aboveGround.welcomeMat, else: Prose.matWontFit)
            try palantirWing.slideMatUnderTheDoor(aboveGround.welcomeMat)
        }

        // And taking it back, which is what gets the key off it. A `before`
        // rule that does not throw, so the take completes and the key lands on
        // the sentence after "Taken."
        aboveGround.welcomeMat.before(.take) { palantirWing.liftTheMat() }

        // The skeleton keys punch the far key out perfectly well and will not
        // turn this lock, and the mainframe has a line about it. On the keys
        // rather than on the door because they are the indirect object, and so
        // are heard first.
        aboveGround.skeletonKeys.before(.unlock) {
            guard command.directObject == palantirWing.oakDoor else { return }
            try refuse(Prose.wrongKeys)
        }
    }

    /// The chute: rigging it, riding it, and everything you can lose down it.
    @RuleBuilder private var palantirChuteRules: Rules {
        // What the Slide Room says about its own chute. A rule rather than a
        // static trait because the rope changes the answer, and the two are
        // mutually exclusive — so ``DungeonMirror`` declares the room
        // `alwaysDescribed` and this supplies the text.
        mirrors.slideRoom.describe {
            guard palantirWing.chuteRopeRigged else { return Prose.slideRoom }
            return "\(Prose.slideRoom)\n\n\(Prose.slideRoomRopeRigged)"
        }

        // `SLIDE-EXIT`'s clock, set at the moment of the descent and not on
        // arrival: climbing back up into the top stretch from below must not
        // re-arm it.
        mirrors.slideRoom.before(.go) {
            guard command.direction == .down, palantirWing.chuteRopeRigged else { return }
            startFuse("slideGrip", after: palantirWing.gripTurns)
        }

        // Rigging the chute. The dome's railing already owns `tie rope`, and
        // the two guards are disjoint by room, so this is a second clause on
        // the same item rather than a rule that has to run in a particular
        // order: see ``Dungeon/coreRules``.
        house.rope.before(.tie) {
            guard command.directObject == house.rope else { return }
            guard player.location == mirrors.slideRoom else { return }
            try rigTheChute()
        }
        house.rope.before(.untie) {
            guard palantirWing.chuteRopeRigged, player.location == mirrors.slideRoom else {
                return
            }
            palantirWing.chuteRopeRigged = false
            try reply(Prose.chuteUnrigged)
        }

        // The rope is what is holding you up, and letting go of it is a
        // decision rather than an accident.
        let chute = palantirWing.chuteRooms
        for room in chute {
            room.before(.take) {
                guard command.directObject == house.rope else { return }
                try refuse(Prose.ropeSuspendsYou)
            }
            room.before(.drop) { try loseDownTheChute() }
        }
    }

    /// The one-way cycle blue → red → white → blue. Nothing else happens: no
    /// teleport, no score, no combination, and no third-sphere effect. The
    /// white sphere is ``DungeonAlice``'s, so all three rules are the host's.
    @RuleBuilder private var palantirScryingRules: Rules {
        let cycle = [
            (palantirWing.blueSphere, palantirWing.redSphere),
            (palantirWing.redSphere, alice.sphere),
            (alice.sphere, palantirWing.blueSphere),
        ]
        // Bound once here rather than read inside `scry`, which is
        // ``Dungeon/thiefRules``' idiom for the treasure roster and for the
        // same reason: the set never changes and rebuilding a hundred-odd
        // rooms per sentence buys nothing.
        let searchable = scryableRooms
        for (sphere, next) in cycle {
            sphere.before(.lookIn) { try scry(next, in: searchable) }
            sphere.before(.lookThrough) { try scry(next, in: searchable) }
        }
    }

    // MARK: - The helpers those rules delegate to

    /// Tying the rope at the head of the chute. The source will take either of
    /// two anchors — the broken timber or the gold coffin — and insists the
    /// anchor be on the ground rather than in your hands, because a rope tied
    /// to something you are carrying holds nothing at all.
    private func rigTheChute() throws -> Never {
        try require(!palantirWing.chuteRopeRigged, else: Prose.chuteAlreadyRigged)
        guard let anchor = command.indirectObject else { try reply(Prose.chuteNeedsAnAnchor) }
        try require(
            anchor == mine.brokenTimber || anchor == templeQuarter.coffin,
            else: Prose.chuteWrongAnchor)
        try require(anchor.isIn(mirrors.slideRoom), else: Prose.chuteAnchorNotOnTheGround)
        // One rope, one knot. The railing's has to come off first, which also
        // shuts the Dome Room's drop — so the wing's two halves are done in the
        // order the map already forces: down the rope to the Tiny Room, and
        // only then round to the chute.
        try require(!templeQuarter.ropeTiedToRailing, else: Prose.ropeAlreadyTied)
        palantirWing.chuteRopeRigged = true
        try reply(Prose.chuteRigged)
    }

    /// Letting go of something in the chute. The rope is the one thing you can
    /// drop that takes you with it; everything else simply goes, and turns up
    /// in the Cellar with the rest of what the chute has swallowed.
    private func loseDownTheChute() throws {
        guard let dropped = command.directObject else { return }
        if dropped == house.rope {
            stopFuse("slideGrip")
            say(Prose.ropeReleased)
            player.location = house.cellar
            describeSurroundings()
            try reply("")
        }
        try require(dropped.isHeld, else: Prose.nothingToLoseDownTheChute)
        let gone = GameText.sentenceCase(dropped.definiteName)
        dropped.move(to: house.cellar)
        try reply(Prose.lostDownTheChute(gone))
    }

    /// What one palantir shows of the next. Failure is one line — the source's
    /// own, for a sphere with no room, a dark room, a thief's pocket or a
    /// closed container.
    ///
    /// - Parameters:
    ///   - target: the next sphere on the cycle.
    ///   - rooms: where to look for it. See ``Dungeon/scryableRooms``.
    /// - Throws: always — a `TurnInterrupt`, since both paths reply.
    private func scry(_ target: Item, in rooms: [Location]) throws -> Never {
        let room =
            target.isHeld ? player.location : rooms.first(where: { $0.contains(target) })
        guard let room, room.isLit else { try reply(Prose.sphereShowsDarkness) }
        // The target sphere is listed with everything else, because seeing it
        // is the whole point of looking: a scry that hid the thing it was aimed
        // at would say "there is nothing in it" of a room with a palantir
        // sitting in the middle of it.
        try reply(Prose.sphereShows(room.name, remoteView(of: room)))
    }

    /// Where a palantir can be found by another palantir.
    ///
    /// The source asks an object which room it is in and gets an answer; this
    /// engine has no such accessor, so the lookup is a search over a named set.
    /// The thief's prowl is every walkable room the built dungeon has, including
    /// the one room of this wing he is allowed into; to it this adds the six the
    /// source keeps him out of, the Dingy Closet where the white sphere starts
    /// (his prowl excludes the shrunken world), the Cage, and the Living Room,
    /// where the trophy case stands. A sphere anywhere else reads as darkness —
    /// the source's own answer for a sphere with no room, and what a sphere shut
    /// in the case gives too, since `contains` is direct containment.
    private var scryableRooms: [Location] {
        thiefProwl + palantirWing.sacredRooms
            + [alice.dingyCloset, alice.cage, house.livingRoom]
    }

    // MARK: - Timers

    /// Milestone 8 — the grip clock. Its length is set where the descent starts
    /// (`100 / carried weight`, floored at two); where it drops you is the
    /// Cellar, which is why it is the host's and not the wing's.
    ///
    /// The declared length is the floor, so the two numbers cannot drift: an
    /// unarmed fuse and the shortest armed one are the same two turns.
    @TimerBuilder var palantirTimers: [TimedEvent] {
        let chute = palantirWing.chuteRooms
        fuse("slideGrip", after: DungeonPalantir.shortestGrip) {
            guard chute.contains(player.location) else { return }
            say(Prose.gripFails)
            player.location = house.cellar
            describeSurroundings()
        }
    }
}
