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
        let (locationID, isDark, wasVisited, override, placements, touched) = frame.with {
            scratch -> (EntityID, Bool, Bool, String?, [EntityID: Placement], Set<EntityID>) in
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
                scratch.state.touched
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
        }
    }
}
