enum DescribeMode {
    /// Entering the room: verbose on first visit, brief on revisits.
    case entry
    /// An explicit LOOK: always verbose.
    case look
}

/// Composes room descriptions per classic IF conventions.
enum RoomDescriber {
    static func isDark(_ locationID: EntityID, frame: TurnFrame) -> Bool {
        // Seam: when light-providing items exist, check presence here.
        !frame.with { $0.state.litRooms.contains(locationID) }
    }

    static func describeCurrentLocation(mode: DescribeMode, frame: TurnFrame) {
        let locationID = frame.with { $0.state.playerLocation }

        guard !isDark(locationID, frame: frame) else {
            frame.say(Messages.pitchBlack)
            return
        }

        let definition = frame.definition
        let location = definition.locations[locationID]
        let verbose = mode == .look || !frame.with { $0.state.visited.contains(locationID) }

        frame.say(location?.name ?? locationID.raw)
        if verbose, let text = frame.with({ $0.state.descriptionOverrides[locationID] })
            ?? location?.description
        {
            frame.say(text)
        }

        // Item paragraphs: firstSight text until touched (even for scenery),
        // then a standard mention for non-scenery items.
        let placements = frame.with { $0.state.placements }
        let touched = frame.with { $0.state.touched }
        let roomItems = definition.items.keys
            .filter { placements[$0] == .room(locationID) }
            .sorted { $0.raw < $1.raw }

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
                    .sorted { $0.raw < $1.raw }
                for topID in onTop {
                    let topName = definition.items[topID]?.name ?? topID.raw
                    frame.say(Messages.itemOnSurface(topName, item.name ?? itemID.raw))
                }
            }
        }

        frame.with { _ = $0.state.visited.insert(locationID) }
    }
}
