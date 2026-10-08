/// A compass or vertical direction of travel between locations.
public enum Direction: String, CaseIterable, Sendable, Codable {
    case north, south, east, west
    case northeast, northwest, southeast, southwest
    case up, down
    case `in`, out
}

/// One statement in a `map` block: an exit, a blocked exit, an initial item
/// placement, or the player's starting location.
public struct MapEntry: Sendable {
    enum Kind: Sendable {
        case exit(from: RefToken, direction: Direction, to: RefToken)
        case blockedExit(from: RefToken, direction: Direction, message: String)
        case doorExit(from: RefToken, direction: Direction, to: RefToken, door: RefToken)
        case conditionalExit(
            from: RefToken, direction: Direction, to: RefToken,
            condition: @Sendable () -> Bool, blocked: String)
        /// An exit whose *destination* is chosen at `go` time. The other four
        /// kinds name their destination up front; this one names a closure,
        /// which is what a non-Euclidean passage needs.
        case dynamicExit(
            from: RefToken, direction: Direction,
            destination: @Sendable () -> Location)
        case placement(item: RefToken, target: PlacementTarget)
        case playerStart(RefToken)
        /// Wires an item to its lock key. Confers lockability on the item
        /// (which then starts locked unless `startsUnlocked`) and resolves the
        /// key by reference — exactly parallel to a door exit's `via:`.
        case lockKey(item: RefToken, key: RefToken)
    }

    enum PlacementTarget: Sendable {
        case location(RefToken)
        case on(RefToken)
        case inside(RefToken)
        case worn
        case held
        /// In an actor's inventory. `.heldBy(.player)` stays spelled
        /// `startsHeld`.
        case heldBy(RefToken)
    }

    let kind: Kind

    /// Whether a map leaves this exit undrawn until the player has gone through it. Set by ``secret``.
    var isSecret = false

    /// This exit, kept off a map until the player has gone through it.
    ///
    /// For an exit that is always open but should still be a surprise: a passage behind a waterfall, a gap in a hedge. Most games never need it. A door the game declares `hidden` is already left off a map until it is revealed, and a conditional exit is left off while its condition is false.
    ///
    /// ```swift
    /// var map: WorldMap {
    ///     behindFalls.west(hiddenCave).secret
    ///     hiddenCave.east(behindFalls)
    /// }
    /// ```
    ///
    /// It changes nothing about how the exit is walked. Written after anything that is not an exit, or after a blocked exit, it is a bootstrap error.
    public var secret: MapEntry {
        var entry = self
        entry.isSecret = true
        return entry
    }

    /// The room a map draws this dynamic exit to. Set by ``mapsTo(_:)``.
    var mapDestination: RefToken?

    /// This dynamic exit, drawn on a map as a passage to `room`.
    ///
    /// A dynamic exit names no room until it is walked, so a tool that lays out the whole map before play has nowhere to draw it. Name the room it belongs next to on the finished map:
    ///
    /// ```swift
    /// var map: WorldMap {
    ///     slideRoom.down { ropeRigged ? chute : cellar }.mapsTo(chute)
    /// }
    /// ```
    ///
    /// ``DeclaredMap`` reports `room` as the exit's destination. Nothing else reads it. Walking the exit still goes wherever the closure says. The room is not added to the rooms the engine treats as reachable or adjacent, and ``GameWorld/mapView()`` still reports the exit's ``MapExit`` kind as `unknownDestination`.
    ///
    /// Written after anything that is not a dynamic exit, it is a bootstrap error.
    ///
    /// - Parameter room: the room the exit leads to on the map.
    /// - Returns: this entry with its map destination set.
    public func mapsTo(_ room: Location) -> MapEntry {
        var entry = self
        entry.mapDestination = room.token
        return entry
    }
}

/// The geography and initial placements of a game, declared in one block:
///
/// ```swift
/// var map: WorldMap {
///     foyer.south(bar)
///     foyer.west(cloakroom)
///     bar.north(foyer)
///
///     player.starts(in: foyer)
///     cloak.startsWorn
/// }
/// ```
///
/// Every reference is an ordinary property access, so renaming a location
/// breaks its exits at compile time.
public struct WorldMap: Sendable {
    let entries: [MapEntry]
}
