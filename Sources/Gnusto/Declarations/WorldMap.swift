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
        case placement(item: RefToken, target: PlacementTarget)
        case playerStart(RefToken)
    }

    enum PlacementTarget: Sendable {
        case location(RefToken)
        case on(RefToken)
        case inside(RefToken)
        case worn
        case held
    }

    let kind: Kind
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

