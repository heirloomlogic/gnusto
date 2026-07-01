/// Where an item currently is.
public enum Placement: Hashable, Sendable, Codable {
    case room(EntityID)
    /// Carried by the entity with this ID — the player today; an NPC once
    /// characters gain inventories of their own.
    case heldBy(EntityID)
    case on(EntityID)
    case inside(EntityID)
    /// Offstage — declared but not yet in play.
    case nowhere
}

/// Whether the game is in progress or how it ended.
public enum GameStatus: Hashable, Sendable, Codable {
    case playing
    case won
    case lost
    case quit
}

/// Everything that changes during play, as a single value.
///
/// The immutable side of the world (names, descriptions, exits, rules,
/// vocabulary) lives in `GameDefinition`. Because `WorldState` is one
/// `Codable` value, save/restore later is a serialization call away.
struct WorldState: Sendable, Codable {
    var placements: [EntityID: Placement] = [:]
    var playerLocation: EntityID
    var litRooms: Set<EntityID> = []
    var wornItems: Set<EntityID> = []
    var score = 0
    var moves = 0
    var touched: Set<EntityID> = []
    var visited: Set<EntityID> = []
    var descriptionOverrides: [EntityID: String] = [:]
    var globals: [EntityID: StateValue] = [:]
    var status: GameStatus = .playing

    /// The one darkness predicate, shared by the room describer, the parser
    /// scope, and the perception defaults.
    /// Seam: when light-providing items exist, check their presence here.
    func isDark(at locationID: EntityID) -> Bool {
        !litRooms.contains(locationID)
    }
}
