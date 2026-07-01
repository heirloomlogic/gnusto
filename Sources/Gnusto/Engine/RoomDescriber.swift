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
        let (locationID, isDark, wasVisited, override, placements, touched, state) = frame.with {
            scratch -> (
                EntityID, Bool, Bool, String?, [EntityID: Placement], Set<EntityID>, WorldState
            ) in
            let id = scratch.state.playerLocation
            let dark = Visibility.isDark(at: id, definition: definition, state: scratch.state)
            let visited = scratch.state.visited.contains(id)
            if !dark {
                scratch.state.visited.insert(id)
            }
            return (
                id, dark, visited,
                scratch.state.descriptionOverrides[id],
                scratch.state.placements,
                scratch.state.touched,
                scratch.state
            )
        }

        guard !isDark else {
            frame.say(Messages.pitchBlack)
            return
        }

        let location = definition.locations[locationID]
        let verbose = mode == .look || !wasVisited

        frame.say(location?.name ?? locationID.raw)
        if verbose, let text = override ?? location?.description {
            frame.say(text)
        }

        // Item paragraphs: firstSight text until touched (even for scenery),
        // then a standard mention for non-scenery items.
        let roomItems = definition.items.keys
            .filter { placements[$0] == .room(locationID) }
            .sorted()

        for itemID in roomItems {
            guard let item = definition.items[itemID] else { continue }
            if !touched.contains(itemID), let firstSight = item.firstSight {
                frame.say(firstSight)
            } else if !item.isScenery {
                frame.say(Messages.itemHere(item.name ?? itemID.raw))
            }

            // One level of "On the X is a Y." for surfaces in the room.
            if item.isSurface {
                let onTop = definition.items.keys
                    .filter { placements[$0] == .on(itemID) }
                    .sorted()
                for topID in onTop {
                    let topName = definition.items[topID]?.name ?? topID.raw
                    frame.say(Messages.itemOnSurface(topName, item.name ?? itemID.raw))
                }
            }

            // "In the X is a Y." for containers whose contents are visible —
            // open containers and closed transparent ones. Closed opaque
            // containers stay silent, so their contents never leak into the
            // room description.
            if item.isContainer, contentsVisible(itemID, definition: definition, state: state) {
                let inside = definition.items.keys
                    .filter { placements[$0] == .inside(itemID) }
                    .sorted()
                for insideID in inside {
                    let insideName = definition.items[insideID]?.name ?? insideID.raw
                    frame.say(Messages.itemInContainer(insideName, item.name ?? itemID.raw))
                }
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
