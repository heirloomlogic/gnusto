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
    /// The player has died. Over, but not final: the world's time has
    /// stopped, yet the program keeps reading — the death prompt offers
    /// RESTART / RESTORE / UNDO / QUIT.
    case dead

    /// Whether the program should stop reading input. `dead` is deliberately
    /// not final — the death prompt is still a conversation.
    var isFinal: Bool {
        self == .won || self == .lost || self == .quit
    }
}

/// Everything that changes during play, as a single value.
///
/// The immutable side of the world (names, descriptions, exits, rules,
/// vocabulary) lives in `GameDefinition`. Because `WorldState` is one
/// `Codable` value, save/restore *is* a serialization call — see `SaveFile`.
struct WorldState: Sendable, Codable {
    var placements: [EntityID: Placement] = [:]
    var playerLocation: EntityID
    var litRooms: Set<EntityID> = []
    /// `lightSource` items that are currently lit. Only light sources ever
    /// appear here; the `Item.isLit` setter and Bootstrap both guard on the
    /// trait.
    var litItems: Set<EntityID> = []
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
    /// The `enterable` the player has boarded, or nil on foot. The player
    /// still never appears in `placements`; `playerLocation` stays the
    /// room. Read through `Visibility.boardedVehicle`, which also demands
    /// the vehicle be placed in the player's room — a rule that teleports
    /// the player (or moves the vehicle without them) strands it, and the
    /// player is simply on foot again.
    var playerVehicle: EntityID?
    var score = 0
    var moves = 0
    var touched: Set<EntityID> = []
    var visited: Set<EntityID> = []
    var descriptionOverrides: [EntityID: String] = [:]
    var globals: [EntityID: StateValue] = [:]
    /// Running fuses: name → end-of-turn ticks left before firing. Names
    /// re-bind to the declared `TimedEvent` bodies; the closures themselves
    /// are code, not data, and never serialize.
    var activeFuses: [String: Int] = [:]
    /// Names of the daemons currently running each turn.
    var activeDaemons: Set<String> = []
    var status: GameStatus = .playing
    /// The random stream's position. Part of the saved state, so a restored
    /// game replays the exact same randomness it would have had.
    var rngState: UInt64 = 0
}

extension WorldState {
    /// Whether this state is referentially consistent with `definition` — every
    /// ID it names is declared, every trait-gated set holds only entities with
    /// the trait, the containment graph is acyclic, and the scalar counters are
    /// in range. A restored save that fails any check is refused whole rather
    /// than silently repaired: a crafted or corrupt file must never reach the
    /// engine, where an unknown EntityID or a mistyped global would trap the
    /// process. Never mutates; `score` and `rngState` are accepted as-is (any
    /// value is legal for both).
    ///
    /// - Parameter definition: the bootstrapped game to validate against.
    /// - Returns: `true` when every check passes; `false` on the first failure.
    func isConsistent(with definition: GameDefinition) -> Bool {
        let items = definition.items
        let locations = definition.locations

        func isItem(_ id: EntityID) -> Bool { items[id] != nil }
        func isLocation(_ id: EntityID) -> Bool { locations[id] != nil }
        func isEntity(_ id: EntityID) -> Bool { isItem(id) || isLocation(id) }

        // The player must stand in a declared room.
        guard isLocation(playerLocation) else { return false }

        // Every placement's key is a declared item, and its target resolves to
        // an entity of the right kind (surfaces hold, containers contain).
        for (key, placement) in placements {
            guard isItem(key) else { return false }
            switch placement {
            case .room(let id):
                guard isLocation(id) else { return false }
            case .heldBy(let id):
                guard id == .player || isItem(id) else { return false }
            case .on(let id):
                guard let def = items[id], def.isSurface else { return false }
            case .inside(let id):
                guard let def = items[id], def.isContainer else { return false }
            case .nowhere:
                break
            }
        }

        // The containment graph must be acyclic: walking each item's parent
        // chain (on / inside / held-by another item) must terminate.
        func parentItem(of placement: Placement) -> EntityID? {
            switch placement {
            case .on(let id), .inside(let id): return id
            case .heldBy(let id): return id == .player ? nil : id
            case .room, .nowhere: return nil
            }
        }
        for start in placements.keys {
            var seen: Set<EntityID> = [start]
            var current = start
            while let parent = placements[current].flatMap(parentItem) {
                guard seen.insert(parent).inserted else { return false }
                current = parent
            }
        }

        // Trait-gated and existence sets: each holds only declared entities of
        // the required kind.
        guard litRooms.allSatisfy(isLocation) else { return false }
        guard litItems.allSatisfy({ items[$0]?.isLightSource == true }) else { return false }
        guard wornItems.allSatisfy({ items[$0]?.isWearable == true }) else { return false }
        guard openItems.allSatisfy({ items[$0]?.isOpenable == true }) else { return false }
        guard lockedItems.allSatisfy({ items[$0]?.isLockable == true }) else { return false }
        guard revealedItems.allSatisfy(isItem) else { return false }
        guard visited.allSatisfy(isLocation) else { return false }
        guard touched.allSatisfy(isEntity) else { return false }
        guard descriptionOverrides.keys.allSatisfy(isEntity) else { return false }

        // Pronouns name items; a boarded vehicle is an enterable item.
        if let it = pronounIt, !isItem(it) { return false }
        guard pronounThem.allSatisfy(isItem) else { return false }
        if let vehicle = playerVehicle, items[vehicle]?.isEnterable != true { return false }

        // Every global is declared, and its stored value's case matches the
        // declared default's case — a scalar mismatch would trap when a rule
        // reads it back through `@Global`. The type-erased `.data` case matches
        // any `.data` regardless of its `typeName`; the decode there is already
        // fallible and handled at read time.
        for (id, value) in globals {
            guard let expected = definition.globalDefaults[id] else { return false }
            guard StateValue.sameCase(value, expected) else { return false }
        }

        // Live fuses count down; a non-positive count would already have fired.
        guard activeFuses.values.allSatisfy({ $0 > 0 }) else { return false }

        // A save is taken mid-play, with a non-negative move count.
        guard status == .playing else { return false }
        guard moves >= 0 else { return false }

        return true
    }
}

extension StateValue {
    /// Whether two boxed values share the same case, ignoring their payloads —
    /// the check a restored global needs so a rule reading it back through
    /// `@Global` never unboxes the wrong scalar. `.data` matches `.data`
    /// regardless of `typeName`.
    static func sameCase(_ lhs: StateValue, _ rhs: StateValue) -> Bool {
        switch (lhs, rhs) {
        case (.bool, .bool), (.int, .int), (.double, .double),
            (.string, .string), (.data, .data):
            return true
        default:
            return false
        }
    }
}
