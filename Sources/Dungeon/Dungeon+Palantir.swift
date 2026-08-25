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
            toward: { chuteRopeRigged ? palantirWing.slideOne : house.cellar })

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
    }

    /// The chute: rigging it, riding it, and everything you can lose down it.
    @RuleBuilder private var palantirChuteRules: Rules {
        // What the Slide Room says about its own chute. A rule rather than a
        // static trait because the rope changes the answer, and the two are
        // mutually exclusive — so ``DungeonMirror`` declares the room
        // `alwaysDescribed` and this supplies the text.
        mirrors.slideRoom.describe {
            guard chuteRopeRigged else { return Prose.slideRoom }
            return "\(Prose.slideRoom)\n\n\(Prose.slideRoomRopeRigged)"
        }

        // `SLIDE-EXIT`'s clock, set at the moment of the descent and not on
        // arrival: climbing back up into the top stretch from below must not
        // re-arm it.
        mirrors.slideRoom.before(.go) {
            guard command.direction == .down, chuteRopeRigged else { return }
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
        // Coming off again. `take` hands the coil back; `untie` leaves it on
        // the floor of the Slide Room, which is the split
        // ``DungeonTemple/ropeOnTheRailing`` already writes at the other knot.
        // No arm on `house.rope` any more: while the knot is tied the coil is
        // offstage, so it cannot be the object of either command.
        palantirWing.chuteHeadRope.before(.take) {
            unrigTheChute()
            house.rope.moveToPlayer()
            say(Prose.chuteUnrigged)
            try reply(gameText.taken())
        }
        palantirWing.chuteHeadRope.before(.untie) {
            unrigTheChute()
            house.rope.move(to: mirrors.slideRoom)
            try reply(Prose.chuteUnrigged)
        }
        palantirWing.chuteHeadRope.before(.tie) { try refuse(Prose.chuteAlreadyRigged) }

        // Lifting the anchor unties the knot. `rigTheChute()` refuses to tie
        // the rope to something in your hands because "a rope tied to something
        // you are carrying holds nothing at all"; nothing re-checked it
        // afterwards, so the Slide Room went on describing a rope tied off at
        // the head of the slide while the player carried the timber it was tied
        // to down the chute.
        for anchor in [mine.brokenTimber, templeQuarter.coffin] {
            anchor.after(.take) {
                guard command.directObject == anchor, chuteAnchor == anchor else { return }
                unrigTheChute()
                house.rope.move(to: mirrors.slideRoom)
                say(Prose.chuteKnotComesUndone)
            }
        }

        // The rope is what is holding you up, and letting go of it is a
        // decision rather than an accident.
        let chute = palantirWing.chuteRooms
        for room in chute {
            // This guard used to name only the coil, and the coil was never
            // down here to be named — so it never fired, and neither did the
            // let-go branch below it. Both read the fitting now. (#329)
            room.before(.take) {
                guard let named = command.directObject, palantirWing.isChuteRope(named)
                else { return }
                try refuse(Prose.ropeSuspendsYou)
            }
            room.before(.drop) { try loseDownTheChute() }
        }

        // On the ledge the player is standing on rock rather than hanging, so
        // the rope is simply out of reach over the lip. `reach` settles at
        // stage 0, so it answers `tie`, `touch` and `pull` as well as `take`,
        // and leaves EXAMINE — `reach: .notNeeded` — to answer the noun. The
        // shape ``DungeonTemple/ropeAboveTheTorchRoom`` already uses.
        palantirWing.slideLedgeRope.reach(otherwise: Prose.ropeOutOfReachFromTheLedge) { false }
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
        for (sphere, next) in cycle {
            sphere.before(.lookIn) { try scry(next) }
            sphere.before(.lookThrough) { try scry(next) }
        }
    }

    // MARK: - The helpers those rules delegate to

    /// Tying the rope at the head of the chute. The source will take either of
    /// two anchors — the broken timber or the gold coffin — and insists the
    /// anchor be on the ground rather than in your hands, because a rope tied
    /// to something you are carrying holds nothing at all.
    private func rigTheChute() throws -> Never {
        try require(!chuteRopeRigged, else: Prose.chuteAlreadyRigged)
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
        palantirWing.chuteAnchorIsTheCoffin = anchor == templeQuarter.coffin
        // The coil goes offstage and five fittings come on, one per room the
        // rope is now in — which is the whole of the repair. A rope hung down
        // a chute is in five rooms at once and an item is in one. (#329)
        house.rope.vanish()
        palantirWing.chuteHeadRope.move(to: mirrors.slideRoom)
        for (fitting, room) in palantirWing.chuteRopeFittings { fitting.move(to: room) }
        try reply(Prose.chuteRigged)
    }

    /// Taking the knot out of the chute: every fitting offstage, and the
    /// caller says where the coil lands.
    private func unrigTheChute() {
        for fitting in palantirWing.chuteRopeFittings.map(\.0) + [palantirWing.chuteHeadRope] {
            fitting.vanish()
        }
    }

    /// Whether a rope has been rigged at the head of the chute.
    ///
    /// Not a flag: the knot *is* ``DungeonPalantir/chuteHeadRope`` standing in
    /// the Slide Room, so the fact has one representation instead of two — the
    /// shape #286 gave ``DungeonTemple/ropeTiedToRailing`` for the other knot.
    /// The host's, because the room the fitting stands in is
    /// ``DungeonMirror``'s and `isIn(_:)` is one placement read where
    /// `location != nil` is a containment walk — and this is read from an
    /// `alwaysDescribed` room's describer and from a dynamic exit, so it is
    /// asked on every entry. (#329)
    var chuteRopeRigged: Bool { palantirWing.chuteHeadRope.isIn(mirrors.slideRoom) }

    /// The thing the chute's rope is tied to, while it is tied to anything.
    var chuteAnchor: Item? {
        guard chuteRopeRigged else { return nil }
        return palantirWing.chuteAnchorIsTheCoffin ? templeQuarter.coffin : mine.brokenTimber
    }

    /// Letting go of something in the chute. The rope is the one thing you can
    /// drop that takes you with it; everything else simply goes, and turns up
    /// in the Cellar with the rest of what the chute has swallowed.
    private func loseDownTheChute() throws {
        guard let dropped = command.directObject else { return }
        // The coil is offstage while the knot is tied, so `drop rope` in the
        // chute names the stretch's fitting. This branch tested the coil and
        // could never have fired — the let-go-and-fall mechanic was
        // unreachable for as long as the rope was a flag. (#329)
        if palantirWing.isChuteRope(dropped) {
            stopFuse("slideGrip")
            say(Prose.ropeReleased)
            arrive(at: house.cellar)
            try handled()
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
    /// The source asks an object which room it is in and gets an answer, and so
    /// does this: ``Item/location`` in place of the search over a named room set
    /// this used to run, which was O(rooms) and silently showed darkness for any
    /// room nobody had remembered to list.
    ///
    /// The second half of the guard is what keeps the failure line honest. A
    /// sphere shut in the trophy case or riding in the thief's pocket has a room
    /// — the walk finds it — but the source shows neither, so the sphere has to
    /// be lying loose in that room or in the player's own hands.
    ///
    /// - Parameter target: the next sphere on the cycle.
    /// - Throws: always — a `TurnInterrupt`, since both paths reply.
    private func scry(_ target: Item) throws -> Never {
        guard let room = target.location, room.isLit,
            target.isHeld || target.isIn(room)
        else { try reply(Prose.sphereShowsDarkness) }
        // The target sphere is listed with everything else, because seeing it
        // is the whole point of looking: a scry that hid the thing it was aimed
        // at would say "there is nothing in it" of a room with a palantir
        // sitting in the middle of it.
        try reply(Prose.sphereShows(room.name, remoteView(of: room)))
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
            arrive(at: house.cellar)
        }
    }
}
