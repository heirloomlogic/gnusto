import Gnusto

extension Intent {
    /// Point a dial at a number. `set`, `turn` and `spin` are three spellings
    /// of the sundial's one job; the source's own vocabulary has all of them,
    /// and the Dungeon Master is told to do it in whichever the player reaches
    /// for.
    ///
    /// `knock` is not declared here and does not need to be: the engine already
    /// carries it as a stub verb, and overriding a stub is silent.
    #verb(
        "setTo",
        ["set", .directObject, "to", .indirectObject],
        ["turn", .directObject, "to", .indirectObject],
        ["spin", .directObject, "to", .indirectObject])

    /// The one order the Dungeon Master takes that the engine has no word for.
    /// `follow` it already has, as a core intent.
    #verb("stay", ["stay"], ["stay", "here"], ["wait", "here"])
}

// MARK: - The Tomb

extension DungeonEndgame {
    @VerbBuilder var verbs: [SyntaxRule] {
        [
            .setTo, .stay,
            .quizTemple, .quizForest, .quizZorkmids, .quizFlask,
            .quizRub, .quizSkeleton, .quizKnife, .quizNowhere,
        ]
    }

    /// `knock` as this game answers it, everywhere but at the wooden door.
    ///
    /// An `action`, not a `world.before` rule: a world rule pre-empts every other
    /// rule in the game, so knocking would have been this bundle's business
    /// forever and no later door could ever have answered its own. Stage 4 is
    /// where a verb's default belongs, and it leaves the door rule in
    /// ``DungeonEndgame/quizRules`` free to override it. The engine's own stub
    /// line is "Nobody answers.", which is true but says nothing about knocking.
    ///
    /// `reply`, not `say`: stage 4 uses `say`, so a rule that only said would
    /// print both lines.
    @ActionBuilder var actions: [IntentAction] {
        action(.knock) { try reply(Prose.knockNoAnswer) }
    }

    /// The two clocks the box runs on, and the two daemons the Dungeon Master
    /// and his examination run on. The endgame's other three timers are the
    /// host's, because each of them touches an item or a counter in another
    /// bundle — see `Dungeon+Endgame.swift`.
    @TimerBuilder var timers: [TimedEvent] {
        // Seven turns of an open mirror, which is the whole of the time you
        // have to walk from the Stone Room to the box and step into it.
        fuse("endgame.mirror", after: 7) {
            var state = box
            guard state.mirrorOpen else { return }
            state.mirrorOpen = false
            box = state
            if player.location == insideMirror || angleOnTheBox(state) != nil {
                say(Prose.boxMirrorSwingsShut)
            }
        }

        fuse("endgame.pine", after: 5) {
            var state = box
            guard state.pineOpen else { return }
            state.pineOpen = false
            box = state
            if player.location == insideMirror { say(Prose.boxPineSwingsShut) }
        }

        // He asks again every second turn until he is answered, which is the
        // source's own patience.
        daemon("endgame.quiz") {
            guard currentQuestion >= 0, player.location == dungeonEntrance else { return }
            guard quizWaitedATurn else {
                quizWaitedATurn = true
                return
            }
            quizWaitedATurn = false
            say(Prose.quizAsksAgain)
            say(Prose.quizQuestion(currentQuestion))
        }

        // He follows you from the Narrow Corridor onward, and into no cell.
        daemon("endgame.master", autostart: true) {
            guard !masterStaying, dungeonMaster.location != nil else { return }
            let here = player.location
            guard masterRoams.contains(where: { $0 == here }), !dungeonMaster.isIn(here) else {
                return
            }
            dungeonMaster.move(to: here)
            say(Prose.masterArrives)
        }
    }

    @RuleBuilder var rules: Rules {
        tombRules
        cryptRules
        beamRules
        hallwayRules
        boxDescriptionRules
        boxPushRules
        boxPoleRules
        quizRules
        prisonRules
        masterRules
    }

    /// The heads, the bottles and the listings.
    @RuleBuilder var tombRules: Rules {
        // `RUB` is a synonym of `touch` and `feel` in this engine as it is in
        // the source, so `touch heads` is on this list without being spelled
        // out — which is the whole trap.
        heads.before(.take, .touch, .attack, .burn, .open, .push, .pull) {
            try robTheAdventurer()
        }

        listings.before(.read) { try reply(Prose.tombListingsText) }

        cokeBottles.before(.throwAt) {
            guard let hurled = command.directObject, hurled != cokeBottles else { return }
            hurled.vanish()
            cokeBottles.vanish()
            try reply(Prose.tombBottlesSmash(hurled.definiteName))
        }
        cokeBottles.before(.attack) {
            cokeBottles.vanish()
            try reply(Prose.tombBottlesSmash(cokeBottles.definiteName))
        }
    }

    /// Everything the heads take, and what taking it costs. The case they put
    /// it in appears in the Living Room, which is a ``DungeonHouse`` room — so
    /// the host owns the case and this calls out to it.
    ///
    /// - Throws: always. The last thing it does is kill you.
    func robTheAdventurer() throws -> Never {
        try die(Prose.tombHeadsCurse)
    }

    /// The marble door, which is the endgame's front door and, before the
    /// herald has been, its front doorman.
    @RuleBuilder var cryptRules: Rules {
        // The one sentence in the Tomb that changes: what the crypt to the
        // north is shut off by, once it is no longer shut.
        tomb.describe {
            "\(Prose.tomb)\n\n\(cryptDoor.isOpen ? Prose.tombCryptOpen : Prose.tombCryptShut)"
        }

        cryptDoor.describe {
            cryptDoor.isOpen ? Prose.cryptDoorOpen : Prose.cryptDoorClosed
        }

        // `HEAD-FUNCTION`: every verb on this door falls through to the heads
        // until `END-GAME!-FLAG` is set, and the heads kill you. A game stalled
        // short of the full six hundred and sixteen can never get in.
        cryptDoor.before(.open, .push, .pull, .attack, .unlock, .touch) {
            guard !endgameBegun else { return }
            say(Prose.cryptDoorRefuses)
            try robTheAdventurer()
        }

        cryptDoor.before(.open) {
            guard !cryptDoor.isOpen else { try refuse(Prose.cryptDoorAlreadyOpen) }
            cryptDoor.isOpen = true
            try reply(Prose.cryptDoorOpens)
        }

        // Shut the door on yourself and the endgame starts counting.
        //
        // **And the grue goes out with the light.** This is the one room in the
        // game whose solution is to stand in the dark on purpose, and the
        // plugin's schedule would start rolling dice on the third dark turn —
        // against a three-turn fuse that re-arms if the room is lit when it
        // fires, so a player who shut the door with the lamp still burning
        // could be eaten while doing exactly the right thing. There are no
        // grues in the Crypt. It comes straight back on if the door is opened
        // again on this side of the transition, so the main dungeon's dark is
        // as dangerous as it ever was.
        cryptDoor.after(.close) {
            guard player.location == crypt else { return }
            stopDaemon("grue")
            startFuse("endgame.crypt")
        }
        cryptDoor.after(.open) {
            guard !pastTheCrypt else { return }
            stopFuse("endgame.crypt")
            startDaemon("grue")
        }
    }

    /// The beam that crosses the Small Room, and the button three rooms away
    /// that answers to it.
    @RuleBuilder var beamRules: Rules {
        // `Prose.smallRoom` is the Bank of Zork's, which was declared first and
        // keeps the name; this room's is `endgameSmallRoom`.
        smallRoom.describe {
            beamIsBroken
                ? "\(Prose.endgameSmallRoom)\n\n\(Prose.redBeamBroken)"
                : Prose.endgameSmallRoom
        }

        redBeam.describe { beamIsBroken ? Prose.redBeamBroken : Prose.redBeam }

        redButton.before(.push, .turnOn) {
            guard beamIsBroken else { try reply(Prose.buttonPressedBeamIntact) }
            var state = box
            state.mirrorOpen = true
            box = state
            startFuse("endgame.mirror")
            try reply(Prose.buttonPressedBeamBroken)
        }
    }

    /// Whether anything is lying on the floor of the Small Room. The source
    /// tests the room's object list; this tests the same thing, less whatever
    /// is scenery — the beam itself is in the room and does not break itself.
    var beamIsBroken: Bool {
        smallRoom.contents.contains { $0 != redBeam && $0.isTakable }
    }
}

// MARK: - Walking the hallway

extension DungeonEndgame {
    /// Movement in the five hallway rooms and the six narrow rooms that can be
    /// walked out of, plus the Dungeon Entrance's one step back south.
    ///
    /// A location `before(.go)` rule runs at stage 3, ahead of stage 4's exit
    /// lookup, which is what lets the box own directions the exit table never
    /// declares — the mainframe's `FROBOZZ` rows, exactly as `FCHMP` does it in
    /// the Royal Puzzle.
    @RuleBuilder var hallwayRules: Rules {
        // Five rooms under one name and one description, plus the one sentence
        // that is different in each of them: whether the box is standing in the
        // next room up the hallway, or the next one down, and which of its four
        // sides is turned toward you.
        // Only the three hallway rooms that carry a box object say anything
        // about the box. The Guardians' room kills you before its description
        // prints, and `MRD` is only ever passed through inside the box — so
        // neither has one, and neither may print a noun nothing answers.
        let hallwaysThatCanSeeIt = Set(
            boxesSeenFromOutside.compactMap { seen, room in
                channelRooms.firstIndex(where: { $0 == room })
            })
        for (index, room) in channelRooms.enumerated() {
            room.describe {
                let state = box
                guard hallwaysThatCanSeeIt.contains(index),
                    state.berth == index + 1 || state.berth == index - 1
                else {
                    return Prose.mirrorHallway
                }
                let northward = state.berth == index + 1
                return """
                    \(Prose.mirrorHallway)

                    \(Prose.boxInTheHallway(
                        northward: northward,
                        face: state.face(at: northward ? 180 : 0),
                        intact: state.mirrorIntact && state.farMirrorIntact))
                    """
            }
        }

        // And the same sentence from a narrow room, where the box is not up the
        // hallway but against your shoulder. Only the rooms a player can stand
        // in — see ``DungeonEndgame/standableFlankingRooms``.
        for (index, flanks) in standableFlankingRooms.enumerated() {
            for (room, side) in [(flanks.east, 90), (flanks.west, 270)] {
                room.describe {
                    let state = box
                    guard state.berth == index else { return Prose.narrowRoom }
                    return """
                        \(Prose.narrowRoom)

                        \(Prose.boxBesideYou(
                            face: state.face(at: side),
                            open: state.isOpenToward(side)))
                        """
                }
            }
        }

        // What the box looks like from wherever you are standing next to it —
        // or the plain answer that it is not in this stretch of hallway at all.
        for (seen, _) in boxesSeenFromOutside {
            seen.describe {
                let state = box
                guard let side = angleOnTheBox(state) else { return Prose.boxIsNotInSight }
                return Prose.boxFromOutside(
                    face: state.face(at: side), open: state.isOpenToward(side))
            }
        }

        for room in guardedRooms {
            room.onEnter { try die(Prose.guardiansKill) }
        }

        guardians.before(.attack) { try die(Prose.guardiansStatueAttack) }

        for (index, room) in channelRooms.enumerated() {
            room.before(.go) { try walkTheHallway(from: index) }
        }

        for (index, flanks) in standableFlankingRooms.enumerated() {
            flanks.east.before(.go) { try stepOutOfTheNarrowRoom(beside: index, from: 90) }
            flanks.west.before(.go) { try stepOutOfTheNarrowRoom(beside: index, from: 270) }
        }

        // The two rooms at the ends of the hallway that are not part of it. The
        // atlas files `MREYE`'s three northward rows and `FDOOR`'s three
        // southward ones as `FROBOZZ` too, so the box owns them the same way.
        smallRoom.before(.go) {
            guard let heading = MirrorBox.angle(of: command.direction ?? .down),
                [0, 45, 315].contains(heading)
            else { return }
            try walkTowardTheBox(into: 0, heading: 180, diagonal: heading != 0)
        }

        dungeonEntrance.before(.go) {
            guard let heading = MirrorBox.angle(of: command.direction ?? .up),
                [180, 135, 225].contains(heading)
            else { return }
            try walkTowardTheBox(
                into: MirrorBox.berthCount - 1, heading: 0, diagonal: heading != 180)
        }
    }

    /// One step taken in a hallway room. North and south may be blocked by the
    /// box; the diagonals squeeze past it; `in` steps through the mirror.
    ///
    /// - Parameter index: which hallway room the player is standing in.
    /// - Throws: whenever the box owns the direction. Returns for the
    ///   directions the declared exit table handles.
    func walkTheHallway(from index: Int) throws {
        guard let direction = command.direction else { return }
        if direction == .in { try stepIntoTheBox() }
        guard let heading = MirrorBox.angle(of: direction) else { return }

        // North and south run along the hallway; the four diagonals are those
        // same two journeys taken past the end of whatever is standing in the
        // way. Nothing else in this room is a direction at all.
        let northward = [0, 45, 315].contains(heading)
        let southward = [180, 135, 225].contains(heading)
        guard northward || southward else { return }

        try walkTowardTheBox(
            into: northward ? index + 1 : index - 1,
            heading: northward ? 180 : 0,
            diagonal: heading % 90 != 0)
    }

    /// The move into the next room along the hallway, which the box may be
    /// standing in.
    ///
    /// - Parameters:
    ///   - target: the berth being walked into.
    ///   - heading: the angle of the box's face the walker would meet.
    ///   - diagonal: whether the step was taken on a diagonal, which is what
    ///     squeezes a walker past an end-on box rather than stopping them.
    /// - Throws: when the box is in the way, or when the Guardians are.
    func walkTowardTheBox(into target: Int, heading: Int, diagonal: Bool = false) throws {
        let state = box
        let inTheHallway = (0..<MirrorBox.berthCount).contains(target)
        guard state.berth == target, inTheHallway else {
            // Nothing in the way. Every north-south row inside the hallway is
            // one of the atlas's `FROBOZZ` rows and so is not a declared exit,
            // which means this rule has to do the walking as well as the
            // refusing. Off either end of the run — south of the first room,
            // north of the last — there *are* declared exits, and they own it.
            guard inTheHallway else { return }
            try arrive(at: channelRooms[target])
        }

        // Mirror #1 standing open is a doorway rather than a wall, whichever
        // way you were going.
        if state.isOpenToward(heading) { try stepIntoTheBox() }

        guard diagonal, state.isEndOn else {
            switch state.face(at: heading) {
            case .mahogany, .pine:
                try refuse(Prose.boxWoodenWall)
            case .mirror:
                try refuse(state.mirrorIntact ? Prose.boxMirrorWall : Prose.boxBrokenMirrorWall)
            case .farMirror:
                try refuse(state.farMirrorIntact ? Prose.boxMirrorWall : Prose.boxBrokenMirrorWall)
            case .none:
                try refuse(Prose.boxMirrorWall)
            }
        }

        // End-on, and taken at an angle: you get past it into the narrow room
        // on the side you leaned. `NE`/`SE` east, `NW`/`SW` west.
        let east = command.direction == .northeast || command.direction == .southeast
        let flanks = flankingRooms[target]
        say(Prose.boxSlipsPast)
        try arrive(at: east ? flanks.east : flanks.west)
    }

    /// Stepping out of a narrow room, which is only ever done toward the box.
    ///
    /// - Parameters:
    ///   - index: the berth the narrow room flanks.
    ///   - side: the angle of the box's face this room looks at.
    /// - Throws: when the step is into the box. Returns otherwise, so the two
    ///   declared plain exits north and south do their own work.
    func stepOutOfTheNarrowRoom(beside index: Int, from side: Int) throws {
        guard let direction = command.direction else { return }
        let inward: Direction = side == 90 ? .west : .east
        guard direction == inward || direction == .in else { return }
        let state = box
        guard state.berth == index, state.isOpenToward(side) else {
            try refuse(Prose.boxNoWayIn)
        }
        try stepIntoTheBox()
    }

    /// Through the open mirror and into the box.
    ///
    /// - Throws: always — either the arrival or the refusal.
    func stepIntoTheBox() throws -> Never {
        let state = box
        guard let side = angleOnTheBox(state) else { try refuse(Prose.boxNotBesideIt) }
        guard state.isOpenToward(side) else { try refuse(Prose.boxNoWayIn) }
        try arrive(at: insideMirror)
    }

    /// Moves the player and describes where they have got to. Assigning
    /// `player.location` fires no `onEnter`, so the Guardians' rooms are
    /// checked here as well as there.
    ///
    /// - Parameter room: where they end up.
    /// - Throws: always.
    func arrive(at room: Location) throws -> Never {
        if guardedRooms.contains(where: { $0 == room }) { try die(Prose.guardiansKill) }
        player.location = room
        describeSurroundings()
        try reply("")
    }
}
