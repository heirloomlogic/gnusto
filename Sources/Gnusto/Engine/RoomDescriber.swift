enum DescribeMode {
    /// Entering the room: verbose on first visit, brief on revisits.
    case entry
    /// An explicit LOOK: always verbose.
    case look
}

/// Composes room descriptions per classic IF conventions.
enum RoomDescriber {
    static func describeCurrentLocation(mode: DescribeMode, frame: TurnFrame) {
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

        guard !isDark else {
            frame.say(frame.definition.text.pitchBlack)
            return
        }

        let location = definition.locations[locationID]
        let verbose = mode == .look || !wasVisited

        let roomName = location?.name ?? locationID.raw
        if let vehicle {
            frame.say(
                frame.definition.text.locationInVehicle(
                    roomName, definition.items[vehicle]?.name ?? vehicle.raw))
        } else {
            frame.say(roomName)
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

        for itemID in roomItems {
            guard let item = definition.items[itemID] else { continue }
            if !touched.contains(itemID), let firstSight = item.firstSight {
                frame.say(firstSight)
            } else if !item.isScenery {
                frame.say(frame.definition.text.itemHere(item.name ?? itemID.raw))
            }

            // One level of "On the X is a Y." for surfaces in the room.
            if item.isSurface {
                let onTop = (index.onSurface[itemID] ?? [])
                    .filter { Visibility.isPerceivable($0, definition: definition, state: state) }
                for topID in onTop {
                    let topName = definition.items[topID]?.name ?? topID.raw
                    frame.say(frame.definition.text.itemOnSurface(topName, item.name ?? itemID.raw))
                }
            }

            // "In the X is a Y." for containers whose contents are visible —
            // open containers and closed transparent ones. Closed opaque
            // containers stay silent, so their contents never leak into the
            // room description.
            if item.isContainer, contentsVisible(itemID, definition: definition, state: state) {
                let inside = (index.inContainer[itemID] ?? [])
                    .filter { Visibility.isPerceivable($0, definition: definition, state: state) }
                for insideID in inside {
                    let insideName = definition.items[insideID]?.name ?? insideID.raw
                    frame.say(frame.definition.text.itemInContainer(insideName, item.name ?? itemID.raw))
                }
            }
        }

        // Actor paragraphs. An actor's `firstSight` is its standing
        // presence line — printed every time, not gated on `touched` the
        // way an item's is (people aren't props; handling them doesn't
        // wear off their entrance). What an actor carries is not listed.
        for actorID in present where definition.items[actorID]?.isActor == true {
            guard let actor = definition.items[actorID] else { continue }
            if let presence = actor.firstSight {
                frame.say(presence)
            } else {
                frame.say(frame.definition.text.actorHere(actor.name ?? actorID.raw))
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
