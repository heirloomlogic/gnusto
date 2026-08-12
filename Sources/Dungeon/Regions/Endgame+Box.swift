import Gnusto

/// The inside of the mirror box: what it says about itself, and the six things
/// that can be done to it.
extension DungeonEndgame {
    /// The room's own description and the descriptions of everything in it.
    /// Almost none of these can be static: what the pole looks like, which way
    /// the arrow points and whether a mirror is whole are all questions about
    /// the state of the box.
    @RuleBuilder var boxDescriptionRules: Rules {
        insideMirror.describe {
            let state = box
            var paragraphs = [Prose.insideMirror]
            paragraphs.append(Prose.boxCompassReading(MirrorBox.name(of: state.bearing)))
            if state.mirrorOpen {
                paragraphs.append(Prose.boxMirrorStandsOpen(onto: mirrorOpensOnto(state)))
            }
            if state.pineOpen { paragraphs.append(Prose.boxPineStandsOpen) }
            return paragraphs.joined(separator: "\n\n")
        }

        compassArrow.describe { Prose.boxCompassReading(MirrorBox.name(of: box.bearing)) }

        pole.describe {
            switch box.pole {
            case .raised: Prose.poleRaised
            case .onFloor: Prose.poleOnFloor
            case .inChannel: Prose.poleInChannel
            case .inHole: Prose.poleInHole
            }
        }

        mirrorOne.describe {
            let state = box
            if !state.mirrorIntact { return Prose.mirrorPanelBroken }
            guard state.mirrorOpen else { return Prose.mirrorPanelIntact }
            return Prose.mirrorPanelOpen(onto: mirrorOpensOnto(state))
        }
        mirrorTwo.describe {
            box.farMirrorIntact ? Prose.mirrorPanelIntact : Prose.mirrorPanelBroken
        }

        // The pine end's own text is a claim about whether it stands open, so it
        // is a rule for the same reason the mirror's is. (#233)
        pineEnd.describe { box.pineOpen ? Prose.pineEndOpen : Prose.pineEnd }

        for (item, colour) in panelsByColour {
            item.describe { Prose.colouredPanel(colour) }
        }

        // Either mirror, broken, loses the game outright — so it is refused
        // nowhere and reported plainly, which is the source's own answer.
        mirrorOne.before(.attack, .smash, .cut) { try shatter(mirrorOne) }
        mirrorTwo.before(.attack, .smash, .cut) { try shatter(mirrorTwo) }
    }

    /// The four coloured panels against the way each of them turns the box.
    /// Red and yellow clockwise, white and black counterclockwise.
    var panelsByColour: [(Item, String)] {
        [
            (redPanel, "red"), (yellowPanel, "yellow"),
            (whitePanel, "white"), (blackPanel, "black"),
        ]
    }

    /// Breaks a mirror, which is one of the two ways to make the game
    /// unwinnable without dying.
    ///
    /// - Parameter glass: which of the two took the blow.
    /// - Throws: always.
    func shatter(_ glass: Item) throws -> Never {
        var state = box
        if glass == mirrorOne {
            guard state.mirrorIntact else { try refuse(Prose.boxMirrorAlreadyBroken) }
            state.mirrorIntact = false
            state.mirrorOpen = false
        } else {
            guard state.farMirrorIntact else { try refuse(Prose.boxMirrorAlreadyBroken) }
            state.farMirrorIntact = false
        }
        box = state
        try reply(Prose.mirrorShatters)
    }

    // MARK: - Pushing

    /// The panels, the two ends, and the way out.
    @RuleBuilder var boxPushRules: Rules {
        for (panel, colour) in panelsByColour {
            panel.before(.push, .turn) {
                try rotate(clockwise: colour == "red" || colour == "yellow")
            }
        }

        mahoganyEnd.before(.push) { try slideAlongTheChannel() }

        pineEnd.before(.push, .open) { try swingThePineEndOpen() }
        pineEnd.before(.close) {
            var state = box
            guard state.pineOpen else { try refuse(Prose.boxPineAlreadyShut) }
            state.pineOpen = false
            box = state
            stopFuse("endgame.pine")
            try reply(Prose.boxPineSwingsShut)
        }

        insideMirror.before(.go) { try leaveTheBox() }
    }

    /// Turning the box a step. Only with the pole up, never in the Guardians'
    /// own room, and it slams the pine end shut whatever else it does.
    ///
    /// - Parameter clockwise: which way the panel turns it.
    /// - Throws: always.
    func rotate(clockwise: Bool) throws -> Never {
        var state = box
        try require(state.pole.isRaised, else: Prose.boxWillNotTurnWithThePoleDown)
        guard state.berth != MirrorBox.guardedBerth else { try die(Prose.guardiansCrush) }
        state.bearing = (state.bearing + (clockwise ? 45 : 315)) % 360
        let slammed = state.pineOpen
        state.pineOpen = false
        box = state
        if slammed { stopFuse("endgame.pine") }
        if slammed { say(Prose.boxPineSlamsShut) }
        say(Prose.boxTurns(clockwise: clockwise))
        describeSurroundings(withRoomName: false)
        try handled()
    }

    /// Shoving the mahogany end, which slides the box one room along the
    /// channel — and takes it past the Guardians, if the Guardians allow it.
    ///
    /// - Throws: always.
    func slideAlongTheChannel() throws -> Never {
        var state = box
        try require(state.slidesAlongTheChannel, else: Prose.boxWillNotSlideCrosswise)
        guard let target = state.berthAhead else { try refuse(Prose.boxAtTheEndOfTheChannel) }
        guard target != MirrorBox.guardedBerth || state.isSafeToPassTheGuardians else {
            try die(Prose.guardiansCrush)
        }
        state.berth = target
        box = state
        say(Prose.boxSlides)
        describeSurroundings(withRoomName: false)
        try handled()
    }

    /// Swinging the pine end open, which is how you get out when the mirror is
    /// shut — and which is fatal anywhere the Guardians can see that end.
    ///
    /// - Throws: always.
    func swingThePineEndOpen() throws -> Never {
        var state = box
        guard !state.pineOpen else { try refuse(Prose.boxPineAlreadyOpen) }
        guard !state.pineOpensInTheirView else { try die(Prose.guardiansCrush) }
        state.pineOpen = true
        box = state
        startFuse("endgame.pine")
        // Which room is beyond the pine end is a question about the bearing:
        // at the opening one it faces east, into a narrow room, not along the
        // hallway.
        let beyond = roomOutside(state.berth, at: state.angle(of: .pine))
        try reply(Prose.boxPineSwingsOpen(onto: beyond?.name))
    }

    /// Stepping out. Either opening will do it — `MIROUT` recognises both, where
    /// `MIRIN` recognises only the mirror — and which room you land in is the
    /// compass direction that opening faces.
    ///
    /// **The pine end shuts behind you as you go**, which is the source's own
    /// line (`3actions.zil:955-959`) and the half this game was missing. Without
    /// it the wooden end stayed swung open in a hallway nobody could re-enter
    /// through, which is the contradiction the 2026-08-11 round filed: an
    /// opening you had just walked through, refusing to be one. (#233)
    ///
    /// - Throws: always — the box owns every direction from inside it.
    func leaveTheBox() throws -> Never {
        let state = box
        guard let direction = command.direction else { try refuse(Prose.boxNoWayOut) }

        // Both ends can stand open at once, so the direction chooses between
        // them: a bare `out` takes the mirror, which is also the way back in,
        // and a named direction takes the opening facing that way. Choosing by
        // declaration order instead made an open mirror unreachable whenever
        // the pine end was open too.
        let unqualified = direction == .out || direction == .in
        let asked = MirrorBox.angle(of: direction)
        guard
            let opening = [state.angle(of: .mirror), state.angle(of: .pine)].first(where: {
                state.openFace(at: $0) != nil && (unqualified || asked == $0)
            })
        else { try refuse(Prose.boxNoWayOut) }

        guard let landing = roomOutside(state.berth, at: opening) else {
            try refuse(Prose.boxNoWayOut)
        }
        if state.face(at: opening) == .pine {
            var next = state
            next.pineOpen = false
            box = next
            stopFuse("endgame.pine")
            say(Prose.boxPineSwingsShutBehindYou)
        }
        try enterTheHallway(at: landing)
    }

    /// The name of the room the openable mirror faces, for the two lines that
    /// say what shows through it. `nil` on a diagonal, where it opens on a
    /// corner.
    ///
    /// - Parameter state: the box as it stands.
    /// - Returns: the room's name, or `nil`.
    func mirrorOpensOnto(_ state: MirrorBox) -> String? {
        roomOutside(state.berth, at: state.angle(of: .mirror))?.name
    }

    /// The room on a given side of a berth, or `nil` for a side of the hallway
    /// there is nothing on.
    ///
    /// - Parameters:
    ///   - berth: where the box is standing.
    ///   - angle: the compass angle of the side being stepped out of.
    /// - Returns: the room, or `nil` on a diagonal.
    func roomOutside(_ berth: Int, at angle: Int) -> Location? {
        switch angle {
        case 0: roomNorth(of: berth)
        case 180: roomSouth(of: berth)
        case 90: flankingRooms[berth].east
        case 270: flankingRooms[berth].west
        default: nil
        }
    }

    // MARK: - The pole

    /// `raise pole` and `lower pole`, and the T-bar that is the handle for
    /// both. Where the pole settles is a question about where the box is
    /// standing, which is why lowering it has three different answers.
    @RuleBuilder var boxPoleRules: Rules {
        for handle in [pole, tBar] {
            handle.before(.raise, .pull) { try raiseThePole() }
            handle.before(.lower, .push) { try lowerThePole() }
        }
    }

    /// - Throws: always.
    func raiseThePole() throws -> Never {
        var state = box
        guard !state.pole.isRaised else { try refuse(Prose.poleAlreadyRaised) }
        state.pole = .raised
        box = state
        try reply(Prose.poleRises)
    }

    /// - Throws: always.
    func lowerThePole() throws -> Never {
        var state = box
        guard state.pole.isRaised else { try refuse(Prose.poleAlreadyDown) }
        state.pole = state.restingPlace
        box = state
        switch state.pole {
        case .inHole: try reply(Prose.poleDropsIntoTheHole)
        case .inChannel: try reply(Prose.poleDropsIntoTheChannel)
        default: try reply(Prose.poleRestsOnTheFloor)
        }
    }
}
