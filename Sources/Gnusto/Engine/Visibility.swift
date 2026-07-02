/// The one shared computation of "which items can the player see or reach
/// here" — used by the parser's scope, the room describer, and any default
/// action that needs to walk placements. Pure functions over a definition and
/// a state snapshot; callers hold whatever lock they need before calling in.
enum Visibility {
    /// Items the player can currently perceive: carried items always, plus —
    /// with light — the room's direct contents and everything reachable by
    /// descending through surfaces (always) and containers (when open, or
    /// while closed if transparent). An item seen through the glass of a shut
    /// jar is visible but not reachable — that is where this diverges from
    /// `reachableItems`.
    static func visibleItems(
        at location: EntityID,
        definition: GameDefinition,
        state: WorldState
    ) -> Set<EntityID> {
        collect(
            at: location, definition: definition, state: state,
            descendClosedTransparent: true)
    }

    /// Items the player can currently manipulate: like `visibleItems`, but a
    /// container's contents count only while it is open — a transparent-but-shut
    /// jar shows its contents without letting the player touch them.
    static func reachableItems(
        at location: EntityID,
        definition: GameDefinition,
        state: WorldState
    ) -> Set<EntityID> {
        collect(
            at: location, definition: definition, state: state,
            descendClosedTransparent: false)
    }

    /// Shared walk for both sets. Held items are always included. With light,
    /// the room's direct contents are included, and each surface/open-container
    /// is descended into to any depth. `descendClosedTransparent` decides
    /// whether a closed transparent container's contents come along (visible)
    /// or not (reachable).
    private static func collect(
        at location: EntityID,
        definition: GameDefinition,
        state: WorldState,
        descendClosedTransparent: Bool
    ) -> Set<EntityID> {
        // Group placements by their container/surface parent for O(1) descent.
        var childrenOf: [EntityID: [EntityID]] = [:]
        for (id, placement) in state.placements {
            switch placement {
            case .on(let parent), .inside(let parent):
                childrenOf[parent, default: []].append(id)
            default:
                break
            }
        }

        var result: Set<EntityID> = []
        // Guards against a runtime-created placement cycle (e.g. a container
        // moved inside its own contents) sending this walk into an infinite
        // recursion — the containment graph should never have cycles, but the
        // walk must not trust that invariant blindly.
        var visited: Set<EntityID> = []

        /// Adds `id` and, if it is a surface or a see-through/open container,
        /// its qualifying descendants.
        func descend(into id: EntityID) {
            guard visited.insert(id).inserted else { return }
            for child in childrenOf[id] ?? [] where isPerceivable(child, definition: definition, state: state) {
                result.insert(child)
                if shouldDescend(into: child) {
                    descend(into: child)
                }
            }
        }

        /// Whether an item exposes its contents to the current walk.
        func shouldDescend(into id: EntityID) -> Bool {
            guard let item = definition.items[id] else { return false }
            if item.isSurface { return true }
            guard item.isContainer else { return false }
            if isOpen(id, definition: definition, state: state) { return true }
            // Closed container: only a transparent one exposes contents, and
            // only to the visibility walk.
            return descendClosedTransparent && item.isTransparent
        }

        // Held items are always perceivable, and we descend into what they hold.
        for (id, placement) in state.placements where placement == .heldBy(.player) {
            guard isPerceivable(id, definition: definition, state: state) else { continue }
            result.insert(id)
            if shouldDescend(into: id) { descend(into: id) }
        }

        guard !isDark(at: location, definition: definition, state: state) else {
            return result
        }

        for (id, placement) in state.placements where placement == .room(location) {
            guard isPerceivable(id, definition: definition, state: state) else { continue }
            result.insert(id)
            if shouldDescend(into: id) { descend(into: id) }
        }

        // Doors are referenced by exits, not placed in the room — but the
        // player can examine/open/close/lock/unlock them from either side, so
        // fold every door on the current room's exits into scope. A `hidden`
        // door stays out until revealed (isPerceivable), which is also what
        // keeps `go` treating it as no exit at all.
        for target in definition.exits[location]?.values ?? [:].values {
            guard case .door(_, let doorID) = target,
                isPerceivable(doorID, definition: definition, state: state)
            else { continue }
            result.insert(doorID)
        }

        return result
    }

    /// Whether an item should be included in any visibility/description walk
    /// at all: it exists and, if `hidden`, has been revealed. Shared by this
    /// module's own walks and `RoomDescriber`'s listings.
    static func isPerceivable(
        _ id: EntityID,
        definition: GameDefinition,
        state: WorldState
    ) -> Bool {
        guard let item = definition.items[id] else { return false }
        return !item.isHidden || state.revealedItems.contains(id)
    }

    /// Whether an openable thing is currently open. An `openable` item (a
    /// container or a door) is open exactly when it is in `openItems`. A
    /// container that isn't `openable` is permanently open; any other
    /// non-openable item has no open state and reads closed.
    static func isOpen(
        _ id: EntityID,
        definition: GameDefinition,
        state: WorldState
    ) -> Bool {
        guard let item = definition.items[id] else { return false }
        if item.isOpenable { return state.openItems.contains(id) }
        return item.isContainer
    }

    /// The one darkness predicate, shared by the room describer, the parser
    /// scope, and the perception defaults.
    /// Seam: when light-providing items exist, check their presence here.
    static func isDark(
        at location: EntityID,
        definition: GameDefinition,
        state: WorldState
    ) -> Bool {
        !state.litRooms.contains(location)
    }
}
