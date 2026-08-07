enum DescribeMode {
    /// Entering the room: verbose on first visit, brief on revisits.
    case entry
    /// An explicit LOOK: always verbose.
    case look
}

/// Composes room descriptions per classic IF conventions.
enum RoomDescriber {
    /// - Parameters:
    ///   - mode: entering the room, or an explicit LOOK.
    ///   - withRoomName: whether to open with the room's name. See
    ///     ``describeSurroundings(withRoomName:)``, which is where an author
    ///     reaches this.
    ///   - frame: the live turn.
    static func describeCurrentLocation(
        mode: DescribeMode,
        withRoomName: Bool = true,
        frame: TurnFrame
    ) {
        let definition = frame.definition

        // One snapshot of everything this function reads; the visited mark
        // (lit visits only) is the one write and happens in the same lock.
        let (locationID, isDark, wasVisited, vehicle, index, touched, state) = frame.with {
            scratch -> (
                EntityID, Bool, Bool, EntityID?, ContainmentIndex, Set<EntityID>, WorldState
            ) in
            let id = scratch.state.playerLocation
            let dark = Visibility.isDark(at: id, definition: definition, state: scratch.state)
            let visited = scratch.state.visited.contains(id)
            if !dark {
                scratch.state.visited.insert(id)
            }
            return (
                id, dark, visited,
                Visibility.boardedVehicle(definition: definition, state: scratch.state),
                scratch.state.containment(),
                scratch.state.touched,
                scratch.state
            )
        }

        // Outside the scratch lock above, deliberately: `pitchBlack` is a
        // closure, and a game's dark line typically reads the world (is the
        // companion still here?), which re-enters the frame via `Ctx.current`
        // and would deadlock if called while holding it. Same reason
        // `describedText` waits until line 55.
        guard !isDark else {
            frame.say(frame.definition.text.pitchBlack())
            return
        }

        let location = definition.locations[locationID]
        // A revisit is brief — the player has read the room already — unless the
        // room's description is the state they are changing, in which case
        // withholding it withholds the only readout there is.
        let verbose = mode == .look || !wasVisited || location?.isAlwaysDescribed == true

        if withRoomName {
            let roomName = location?.name ?? locationID.raw
            if let vehicle {
                frame.say(
                    frame.definition.text.locationInVehicle(
                        roomName, frame.definiteName(of: vehicle)))
            } else {
                frame.say(roomName)
            }
        }
        if verbose {
            // Reads outside the lock above: `describedText` may call a
            // `describe { … }` rule closure, which typically re-enters the
            // frame via `Ctx.current` (proxies, `@Global`s) and would
            // deadlock if called while still holding the scratch lock.
            let text = frame.describedText(of: locationID)
            if !text.isEmpty {
                frame.say(text)
            }
        }

        // Item paragraphs: firstSight text until touched (even for scenery),
        // then a standard mention for non-scenery items. Actors are held
        // back for their own paragraphs below — people close the scene. The
        // boarded vehicle is skipped entirely: its presence is the title
        // suffix, and "There is a red boat here." under "…, in the red
        // boat" is noise (its cargo answers to `look in`, not the room).
        let present = (index.inRoom[locationID] ?? [])
            .filter {
                $0 != vehicle
                    && Visibility.isPerceivable($0, definition: definition, state: state)
            }
        let roomItems = present.filter { definition.items[$0]?.isActor != true }

        // The one line any listed thing earns, wherever it is standing: its
        // presence paragraph until the player touches it, else the stock
        // sentence, else nothing. `scenery` is what withholds the *stock*
        // sentence and only that — a fixed fitting is no more a room's news
        // inside a container than on a floor, but a fitting the author gave a
        // line of its own still gets it. `stock` is lazy, so the templates and
        // their string building are skipped whenever a presence line wins.
        func sayListing(of id: EntityID, stock: () -> String) {
            if !touched.contains(id), let presence = frame.presenceText(of: id) {
                frame.say(presence)
            } else if definition.items[id]?.isScenery != true {
                frame.say(stock())
            }
        }

        // What a thing standing in the room holds — and one level only. The
        // walk covers the room's own things and their contents, never what
        // *those* contents hold, so a listing line declared two levels down
        // has nowhere to print.
        func listContents(
            _ ids: [EntityID]?,
            of holder: EntityID,
            as line: (_ item: String, _ holder: String) -> String
        ) {
            for id in ids ?? []
            where Visibility.isPerceivable(id, definition: definition, state: state) {
                sayListing(of: id) {
                    line(frame.indefiniteName(of: id), frame.definiteName(of: holder))
                }
            }
        }

        for itemID in roomItems {
            guard let item = definition.items[itemID] else { continue }
            sayListing(of: itemID) { definition.text.itemHere(frame.indefiniteName(of: itemID)) }

            // "On the X is a Y." for a surface standing in the room.
            if item.isSurface {
                listContents(index.onSurface[itemID], of: itemID, as: definition.text.itemOnSurface)
            }

            // "In the X is a Y." for a container whose contents are visible —
            // an open one, or a closed transparent one. A closed opaque
            // container stays silent, so its contents never leak into the room
            // description.
            if item.isContainer, contentsVisible(itemID, definition: definition, state: state) {
                listContents(
                    index.inContainer[itemID], of: itemID, as: definition.text.itemInContainer)
            }
        }

        // Actor paragraphs. An actor's presence line — `firstSight`, or the
        // live `presence { … }` rule that supersedes it — is printed every
        // time, not gated on `touched` the way an item's is (people aren't
        // props; handling them doesn't wear off their entrance). What an
        // actor carries is not listed.
        for actorID in present where definition.items[actorID]?.isActor == true {
            if let presence = frame.presenceText(of: actorID) {
                frame.say(presence)
            } else {
                frame.say(frame.definition.text.actorHere(frame.indefiniteName(of: actorID)))
            }
        }
    }

    /// Whether a container's direct contents are perceivable in a room
    /// description: an open container, or a closed transparent one.
    private static func contentsVisible(
        _ id: EntityID,
        definition: GameDefinition,
        state: WorldState
    ) -> Bool {
        if Visibility.isOpen(id, definition: definition, state: state) { return true }
        return definition.items[id]?.isTransparent == true
    }
}
