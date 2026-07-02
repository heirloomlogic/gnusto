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
    /// Openable containers that are currently open. A container without the
    /// `openable` trait is always open and never appears here.
    var openItems: Set<EntityID> = []
    /// Lockable items that are currently locked.
    var lockedItems: Set<EntityID> = []
    /// Hidden items that have been revealed and are now perceivable normally.
    var revealedItems: Set<EntityID> = []
    /// What "it" currently refers to: the last direct object the player
    /// named (naming binds, even when the action then refuses).
    var pronounIt: EntityID?
    /// What "them" currently refers to: the group the last multi-object
    /// command expanded to.
    var pronounThem: [EntityID] = []
    var score = 0
    var moves = 0
    var touched: Set<EntityID> = []
    var visited: Set<EntityID> = []
    var descriptionOverrides: [EntityID: String] = [:]
    var globals: [EntityID: StateValue] = [:]
    var status: GameStatus = .playing
    /// The random stream's position. Part of the saved state, so a restored
    /// game replays the exact same randomness it would have had.
    var rngState: UInt64 = 0
}
