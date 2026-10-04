/// What a map may show of the room the player is standing in.
///
/// It names exits and never says where they lead: a map knows a way out exists, and learns where it goes when the player walks it. What it leaves out is what the player could not know is there. Built by ``GameWorld/mapView()``.
public struct RoomMapView: Sendable, Equatable {
    /// The room, by the ID the game declared it under.
    public let id: EntityID
    /// The room's name, as the status line shows it.
    public let name: String
    /// The ``mapRegion(_:)`` label the room declares, if any.
    public let region: String?
    /// The exits a map may draw, by direction. Empty in a dark room.
    public let exits: [Direction: MapExit]
}

/// One way out of a room, as a map may draw it.
public struct MapExit: Sendable, Equatable {
    /// What kind of way out it is.
    public enum Kind: Sendable, Equatable {
        /// An exit the player can try: a plain exit, a door that is not hidden (open or shut), or a conditional exit whose condition holds.
        case open
        /// A declared dead end: it refuses with a message every time.
        case blocked
        /// An exit whose destination is chosen when it is walked, so even a map that has walked it once cannot say where it leads next time.
        case unknownDestination
    }

    /// What kind of way out it is.
    public let kind: Kind
    /// Whether the game declared it ``MapEntry/secret``. A map leaves a secret exit undrawn until the player has gone through it.
    public let isSecret: Bool
}

extension GameWorld {
    /// What a map may show of the room the player is standing in.
    ///
    /// Left out: a door that is `hidden` and not yet revealed, and a conditional exit whose condition is false right now. In a dark room, every exit is left out. Each condition reads the same current world in its own throwaway frame; its writes are discarded and cannot affect another exit. It reads the world and changes nothing, so a front end may ask after every turn.
    ///
    /// - Returns: the room's map view.
    public func mapView() -> RoomMapView {
        let here = state.playerLocation
        let location = definition.locations[here]
        let name = location?.name ?? here.raw
        guard !Visibility.isDark(at: here, definition: definition, state: state) else {
            return RoomMapView(id: here, name: name, region: location?.mapRegion, exits: [:])
        }

        let secret = definition.secretExits[here] ?? []
        var exits: [Direction: MapExit] = [:]
        for (direction, target) in definition.exits[here] ?? [:] {
            guard let kind = mapKind(of: target) else { continue }
            exits[direction] = MapExit(kind: kind, isSecret: secret.contains(direction))
        }
        return RoomMapView(id: here, name: name, region: location?.mapRegion, exits: exits)
    }

    /// How a map draws one declared exit, or `nil` when it does not draw it at all. Conditional predicates run outside the frame's lock in an isolated scratch snapshot.
    private func mapKind(of target: ExitTarget) -> MapExit.Kind? {
        switch target {
        case .to:
            return .open
        case .blocked:
            return .blocked
        case .door(_, let door):
            return Visibility.isPerceivable(door, definition: definition, state: state) ? .open : nil
        case .conditional(_, let condition, _):
            // A gate reads through Ctx.current. Start from the live baseline for
            // every gate so unordered exits cannot share a predicate's writes.
            let scratch = TurnFrame(
                definition: definition, state: state, descriptionMode: .brief)
            defer { _ = scratch.retire() }
            return Ctx.$frame.withValue(scratch) { condition() ? .open : nil }
        case .dynamic:
            // Its destination is learned only when the player walks it.
            return .unknownDestination
        }
    }
}
