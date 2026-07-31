/// The one shared computation of "which items can the player see or reach
/// here" — used by the parser's scope, the room describer, and any default
/// action that needs to walk placements. Pure functions over a definition and
/// a state snapshot; callers hold whatever lock they need before calling in.
///
/// The two `…(_:frame:)` helpers are the one exception: they ask the same
/// question of a live turn and take the frame lock themselves. They back both
/// the default actions' reach gate and the public ``Item/isReachable`` /
/// ``Item/isVisible``, so there is one walk and not four.
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
        state: WorldState,
        index: ContainmentIndex
    ) -> Set<EntityID> {
        collect(
            at: location, definition: definition, state: state, index: index,
            descendClosedTransparent: true)
    }

    /// Items the player can currently manipulate: like `visibleItems`, but a
    /// container's contents count only while it is open — a transparent-but-shut
    /// jar shows its contents without letting the player touch them.
    static func reachableItems(
        at location: EntityID,
        definition: GameDefinition,
        state: WorldState,
        index: ContainmentIndex
    ) -> Set<EntityID> {
        collect(
            at: location, definition: definition, state: state, index: index,
            descendClosedTransparent: false)
    }

    /// Whether the player can reach `id` from where they are standing right
    /// now — `reachableItems` asked about one item, against the live turn.
    static func isReachable(_ id: EntityID, frame: TurnFrame) -> Bool {
        inScope(id, frame: frame, descendClosedTransparent: false)
    }

    /// Whether the player can see `id` from where they are standing right now —
    /// `visibleItems` asked about one item, against the live turn.
    static func isVisible(_ id: EntityID, frame: TurnFrame) -> Bool {
        inScope(id, frame: frame, descendClosedTransparent: true)
    }

    /// Takes the frame lock, so it must never be called from inside a
    /// `frame.with { … }` closure — the `Mutex` is not reentrant.
    private static func inScope(
        _ id: EntityID,
        frame: TurnFrame,
        descendClosedTransparent: Bool
    ) -> Bool {
        let definition = frame.definition
        return frame.with { scratch in
            collect(
                at: scratch.state.playerLocation,
                definition: definition,
                state: scratch.state,
                index: scratch.state.containment(),
                descendClosedTransparent: descendClosedTransparent
            )
            .contains(id)
        }
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
        index: ContainmentIndex,
        descendClosedTransparent: Bool
    ) -> Set<EntityID> {
        // The player is always to hand — in the dark too, exactly like the
        // things they are carrying. Their item is placed `.nowhere`, so this
        // is the only way it enters scope, and being in no room is what keeps
        // it out of room listings and a location's contents. `TAKE ALL` reads
        // this set, and is kept off the player by `isTakable`, which is false
        // for people.
        var result: Set<EntityID> = [.player]
        // Guards against a runtime-created placement cycle (e.g. a container
        // moved inside its own contents) sending this walk into an infinite
        // recursion — the containment graph should never have cycles, but the
        // walk must not trust that invariant blindly.
        var visited: Set<EntityID> = []

        /// Adds `id` and, if it is a surface or a see-through/open container,
        /// its qualifying descendants.
        func descend(into id: EntityID) {
            guard visited.insert(id).inserted else { return }
            for child in index.children(of: id) where isPerceivable(child, definition: definition, state: state) {
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
        for id in index.held[.player] ?? [] where isPerceivable(id, definition: definition, state: state) {
            result.insert(id)
            if shouldDescend(into: id) { descend(into: id) }
        }

        guard !isDark(at: location, definition: definition, state: state) else {
            return result
        }

        for id in index.inRoom[location] ?? [] where isPerceivable(id, definition: definition, state: state) {
            result.insert(id)
            if shouldDescend(into: id) { descend(into: id) }
        }

        // What an actor in the room is holding is visible — the player can
        // see the axe in the troll's hands, name it, examine it — but never
        // reachable: taking from those hands is a plugin's job (stealing),
        // and the default refusal is `cantReach`, exactly like the contents
        // of a shut glass jar.
        if descendClosedTransparent {
            for holderID in index.inRoom[location] ?? [] {
                guard definition.items[holderID]?.isActor == true,
                    isPerceivable(holderID, definition: definition, state: state)
                else { continue }
                for id in index.held[holderID] ?? []
                where isPerceivable(id, definition: definition, state: state) {
                    result.insert(id)
                    if shouldDescend(into: id) { descend(into: id) }
                }
            }
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

    /// The vehicle the player is effectively in: `playerVehicle`, but only
    /// while that item is still placed in the player's room. A rule that
    /// teleports the player (or moves the vehicle out from under them)
    /// silently strands the vehicle — the player is then on foot. A
    /// self-healing read; nothing ever writes here.
    static func boardedVehicle(
        definition: GameDefinition,
        state: WorldState
    ) -> EntityID? {
        guard let vehicle = state.playerVehicle,
            state.placements[vehicle] == .room(state.playerLocation)
        else { return nil }
        return vehicle
    }

    /// Every actor currently standing in a room other than `location`.
    ///
    /// **This is not a visibility set.** Nobody can see these people. It is
    /// the naming reach of FOLLOW and nothing else: the verb has to be able to
    /// hear the name of somebody who walked out one turn ago, which is exactly
    /// when `visibleItems` no longer contains them. The parser consults it
    /// only for a far-sighted intent, and only after the visible set has
    /// failed — see `Intent.farSightedIntents`.
    ///
    /// Actors held or contained by something (a familiar in a pocket, a body
    /// in a crate) are deliberately excluded: you cannot walk to a placement
    /// that isn't a room. So are actors standing in a room no exit leads to —
    /// a game's off-map holding pen. Naming those would be a spoiler: an
    /// unmet character's own name coming back in a refusal is how a player
    /// learns there is a policeman in this story before one arrives.
    ///
    /// - Parameters:
    ///   - location: the room to exclude — where the player is standing.
    ///   - definition: the static game definition.
    ///   - state: the current world state.
    /// - Returns: the perceivable actors standing elsewhere.
    static func actorsElsewhere(
        excluding location: EntityID,
        definition: GameDefinition,
        state: WorldState
    ) -> Set<EntityID> {
        definition.castIDs.filter { id in
            guard case .room(let room)? = state.placements[id], room != location,
                definition.reachableRooms.contains(room)
            else {
                return false
            }
            return isPerceivable(id, definition: definition, state: state)
        }
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
    /// scope, and the perception defaults. A room has light when it is lit
    /// itself (`litRooms`: inherent light or author code) or when a lit
    /// `lightSource` item's light reaches it.
    static func isDark(
        at location: EntityID,
        definition: GameDefinition,
        state: WorldState
    ) -> Bool {
        if state.litRooms.contains(location) { return false }
        return !state.litItems.contains {
            lightReaches(location, from: $0, definition: definition, state: state)
        }
    }

    /// Whether a lit item's light reaches the given room. A pure placement
    /// walk UP from the item — deliberately independent of the visibility
    /// sets, which themselves depend on darkness (no circularity). A `hidden`
    /// lit item still counts: it is the light that matters, not whether the
    /// player has noticed the item. Light escapes surfaces and open
    /// containers, passes through closed `transparent` ones (glass works both
    /// ways, symmetric with the visibility walk), and is swallowed by a
    /// closed opaque container.
    private static func lightReaches(
        _ location: EntityID,
        from id: EntityID,
        definition: GameDefinition,
        state: WorldState
    ) -> Bool {
        var current = id
        // Guards against a runtime-created placement cycle, same rationale
        // as `collect`'s visited set.
        var visited: Set<EntityID> = []
        while visited.insert(current).inserted {
            switch state.placements[current] {
            case .room(let room):
                return room == location
            case .heldBy(.player):
                // A carried light lights only the room the player is in.
                return location == state.playerLocation
            case .heldBy(let holder):
                // An actor's lantern lights the room the actor is in: keep
                // walking up through the holder.
                current = holder
            case .on(let parent):
                current = parent
            case .inside(let parent):
                guard let container = definition.items[parent],
                    isOpen(parent, definition: definition, state: state)
                        || container.isTransparent
                else { return false }
                current = parent
            case .nowhere, nil:
                return false
            }
        }
        return false
    }
}
