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
    ///
    /// `observer` is the player unless a game has somebody else doing the
    /// looking — an actor declared ``takesOrders``, whose own scope is what
    /// `robot, push the button` resolves against.
    static func visibleItems(
        for observer: EntityID = .player,
        at location: EntityID,
        definition: GameDefinition,
        state: WorldState,
        index: ContainmentIndex
    ) -> Set<EntityID> {
        collect(
            observer: observer, at: location, definition: definition, state: state,
            index: index, descendClosedTransparent: true)
    }

    /// Items the player can currently manipulate: like `visibleItems`, but a
    /// container's contents count only while it is open — a transparent-but-shut
    /// jar shows its contents without letting the player touch them.
    ///
    /// **Containment only.** A `reach { … }` rule is a closure that reads the
    /// live world, so it needs a turn frame and cannot be asked of a bare state
    /// snapshot; ``isReachable(_:frame:)`` is the form that asks both.
    static func reachableItems(
        at location: EntityID,
        definition: GameDefinition,
        state: WorldState,
        index: ContainmentIndex
    ) -> Set<EntityID> {
        collect(
            observer: .player, at: location, definition: definition, state: state,
            index: index, descendClosedTransparent: false)
    }

    /// Where an observer is standing. `nil` for an actor who is in no room at
    /// all — held, contained, or `vanish()`ed — who reaches only their own
    /// hands. The player's item is placed `.nowhere`, so they are the one
    /// entity whose room is tracked separately.
    ///
    /// Not `WorldState.room(of:)`, which walks the chain the whole way up and
    /// so answers the enclosing room for a contained observer. The two part
    /// company on exactly that case, and this is the one to ask about reach:
    /// being carried through a room is not standing in it.
    static func standing(_ observer: EntityID, in state: WorldState) -> EntityID? {
        if observer == .player { return state.playerLocation }
        if case .room(let here)? = state.placements[observer] { return here }
        return nil
    }

    /// Whether the player can reach `id` from where they are standing right
    /// now — `reachableItems` asked about one item, against the live turn, plus
    /// whatever `reach { … }` rule the item declared.
    static func isReachable(_ id: EntityID, frame: TurnFrame) -> Bool {
        // The rule first: it is a dictionary lookup that almost always finds
        // nothing, where the walk below builds a whole scope set.
        reachRuleAllows(id, for: .player, frame: frame)
            && inScope(id, observer: .player, frame: frame, descendClosedTransparent: false)
    }

    /// Whether an item's `reach { … }` rule lets `observer` touch it. True when
    /// there is no such rule, which is every item of every game that has not
    /// opted in.
    ///
    /// What the observer is **holding** always passes without asking. A rule
    /// keyed to a square of a sliding-block floor answers "is this within arm's
    /// reach of where I stand", and a thing already in the hand is not a
    /// question — vetoing it would stop the player opening a box they carry.
    ///
    /// Takes the frame lock for the placement read and then calls the closure
    /// *outside* it: a rule body re-enters the frame through `Ctx.current`, and
    /// the `Mutex` is not reentrant.
    static func reachRuleAllows(_ id: EntityID, for observer: EntityID, frame: TurnFrame) -> Bool {
        // `isEmpty` before the subscript: a dictionary lookup hashes the key
        // even when there is nothing to find, and for every game that declares
        // no reach rule there never is.
        let declared = frame.definition.rules.itemReach
        guard !declared.isEmpty, let rule = declared[id] else { return true }
        if frame.with({ $0.state.placements[id] == .heldBy(observer) }) { return true }
        return rule.allows()
    }

    /// Whether `actor` can reach `id` from the room they are standing in —
    /// their own hands always, plus that room's contents and everything under a
    /// surface or an open container there, to any depth.
    ///
    /// Two deliberate departures from the player's own set. Darkness does not
    /// gate it — the dark is the player's problem, not an NPC's arm — and what
    /// *other* people are holding stays out, the player included: lifting from
    /// those hands is stealing, which is a plugin's job, exactly as it is for
    /// the player's own reach set.
    /// A `reach { … }` rule gates this too, and is not told who is asking. The
    /// rule models a room the map keeps as one place and the game divides by
    /// hand; a sub-room position the game tracks for the player is the only one
    /// it tracks, so a thing out of the player's reach is out of everybody's.
    static func isReachable(_ id: EntityID, from actor: EntityID, frame: TurnFrame) -> Bool {
        inScope(id, observer: actor, frame: frame, descendClosedTransparent: false)
            && reachRuleAllows(id, for: actor, frame: frame)
    }

    /// Whether the player can see `id` from where they are standing right now —
    /// `visibleItems` asked about one item, against the live turn.
    static func isVisible(_ id: EntityID, frame: TurnFrame) -> Bool {
        inScope(id, observer: .player, frame: frame, descendClosedTransparent: true)
    }

    /// Takes the frame lock, so it must never be called from inside a
    /// `frame.with { … }` closure — the `Mutex` is not reentrant.
    private static func inScope(
        _ id: EntityID,
        observer: EntityID,
        frame: TurnFrame,
        descendClosedTransparent: Bool
    ) -> Bool {
        let definition = frame.definition
        return frame.with { scratch in
            collect(
                observer: observer,
                at: standing(observer, in: scratch.state),
                definition: definition,
                state: scratch.state,
                index: scratch.state.containment(),
                descendClosedTransparent: descendClosedTransparent
            )
            .contains(id)
        }
    }

    /// Shared walk for every set. `observer`'s held items are always included.
    /// With light — or from anybody but the player, in the dark too —
    /// `location`'s direct contents are included, and each surface/open-container
    /// is descended into to any depth. `descendClosedTransparent` decides whether
    /// a closed transparent container's contents come along (visible) or not
    /// (reachable). A `nil` `location` is an observer standing in no room at
    /// all, and stops the walk at their own hands.
    private static func collect(
        observer: EntityID,
        at location: EntityID?,
        definition: GameDefinition,
        state: WorldState,
        index: ContainmentIndex,
        descendClosedTransparent: Bool
    ) -> Set<EntityID> {
        // The observer is always to hand — in the dark too, exactly like the
        // things they are carrying.
        var result: Set<EntityID> = [observer]
        // …and so is the player, who is placed `.nowhere` and so is never found
        // by the room walk below. That placement is what keeps them out of room
        // listings and a location's contents; this line is the only way they
        // enter scope, whether the walk is their own or somebody else's asking
        // "can I get at him". `TAKE ALL` reads the *reachable* form of this
        // set, and is kept off the player by `isTakable`, which is false for
        // people.
        if location == state.playerLocation { result.insert(.player) }
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
        for id in index.held[observer] ?? []
        where isPerceivable(id, definition: definition, state: state) {
            result.insert(id)
            if shouldDescend(into: id) { descend(into: id) }
        }

        // Darkness gates the player's walk and nobody else's: these sets are
        // also the parser's scope, and you cannot refer to what you cannot see.
        // An NPC has no parser, so an unlit room stops their eyes and not their
        // arm (#119).
        guard let location,
            observer != .player || !isDark(at: location, definition: definition, state: state)
        else {
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
            func absorbWhatIsHeld(by holderID: EntityID) {
                guard definition.items[holderID]?.isActor == true,
                    isPerceivable(holderID, definition: definition, state: state)
                else { return }
                for id in index.held[holderID] ?? []
                where isPerceivable(id, definition: definition, state: state) {
                    result.insert(id)
                    if shouldDescend(into: id) { descend(into: id) }
                }
            }
            for holderID in index.inRoom[location] ?? [] {
                absorbWhatIsHeld(by: holderID)
            }
            // The player's hands belong to that rule too, and the room walk
            // can never find them: the player is placed `.nowhere`. Only
            // somebody else's walk needs the line — the player's own set
            // already has everything they carry.
            if observer != .player, location == state.playerLocation {
                absorbWhatIsHeld(by: .player)
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

    /// The actors standing in some other room, and which of them the player may
    /// still *name*: the ones they have met, plus whoever is next door.
    ///
    /// **This is not a visibility set.** Nobody can see these people. It is
    /// the naming reach of FOLLOW and nothing else: the verb has to be able to
    /// hear the name of somebody who walked out one turn ago, which is exactly
    /// when `visibleItems` no longer contains them. The parser consults it
    /// only for a far-sighted intent, and only after the visible set has
    /// failed — see `Intent.farSightedIntents`.
    ///
    /// **Both terms of the reach are load-bearing, and neither carries it
    /// alone.** Acquaintance alone is too narrow: the person who is one room
    /// off has not been met on the turn the player first walks after them, and
    /// `follow porter` on turn one is a reasonable thing to type. Adjacency
    /// alone is too narrow the other way: FOLLOW's whole job is naming
    /// somebody who has *gone*, and a quarry two rooms away must still be
    /// nameable so the verb can admit it has lost them. Without the reach the
    /// set was every actor in every reachable room, which on a map the size of
    /// Dungeon meant `follow troll` on turn one, standing in an open field,
    /// answered with a departure that never happened. (#332)
    ///
    /// Actors held or contained by something (a familiar in a pocket, a body
    /// in a crate) are excluded from both halves: you cannot walk to a
    /// placement that isn't a room. So are actors standing in a room no exit
    /// leads to — a game's off-map holding pen. Naming those would be a
    /// spoiler: an unmet character's own name coming back in a refusal is how
    /// a player learns there is a policeman in this story before one arrives.
    /// The reach is the same argument carried the rest of the way.
    ///
    /// - Parameters:
    ///   - location: the room to exclude — where the player is standing.
    ///   - nextDoor: the rooms one exit of `location` leads to, from
    ///     ``adjacentRooms(to:definition:state:)``. Passed in rather than
    ///     recomputed: the caller needs it for the order-takers too.
    ///   - definition: the static game definition.
    ///   - state: the current world state.
    /// - Returns: the perceivable actors standing elsewhere, and the subset the
    ///   player may name.
    static func actorsElsewhere(
        excluding location: EntityID,
        nextDoor: Set<EntityID>,
        definition: GameDefinition,
        state: WorldState
    ) -> ActorsElsewhere {
        guard !definition.castIDs.isEmpty else { return ActorsElsewhere(all: [], withinReach: []) }
        var all: Set<EntityID> = []
        var withinReach: Set<EntityID> = []
        for id in definition.castIDs {
            guard case .room(let room)? = state.placements[id], room != location,
                definition.reachableRooms.contains(room),
                isPerceivable(id, definition: definition, state: state)
            else {
                continue
            }
            all.insert(id)
            if isNameable(id, standingIn: room, nextDoor: nextDoor, state: state) {
                withinReach.insert(id)
            }
        }
        return ActorsElsewhere(all: all, withinReach: withinReach)
    }

    /// The off-room cast, and the part of it the player may name.
    ///
    /// `all` is not dead weight: the phrase is judged over it and answered from
    /// `withinReach`, so narrowing the reach cannot turn a description into a
    /// name. `StandardParser.outOfSight(_:among:answerableIn:)` is where that
    /// argument is made. (#332)
    struct ActorsElsewhere: Sendable {
        /// Everybody standing in another room the player could walk to.
        let all: Set<EntityID>
        /// Met, or standing next door: the people FOLLOW may resolve.
        let withinReach: Set<EntityID>
    }

    /// Whether somebody standing in `there` is close enough for the player to
    /// name: met, or next door.
    ///
    /// **The one place the rule is written.** Both naming reaches consult it —
    /// FOLLOW's quarry through ``actorsElsewhere(excluding:nextDoor:definition:state:)``
    /// and an order-taker's name through `GameWorld.orderTakerScopes` — and a
    /// rule spelled out twice is a rule that will be narrowed once. (#332)
    ///
    /// - Parameters:
    ///   - id: the actor in question.
    ///   - there: the room they are standing in.
    ///   - nextDoor: the rooms one exit of the player's room leads to.
    ///   - state: the current world state.
    /// - Returns: whether the player may name them from where they stand.
    static func isNameable(
        _ id: EntityID,
        standingIn there: EntityID,
        nextDoor: Set<EntityID>,
        state: WorldState
    ) -> Bool {
        state.metActors.contains(id) || nextDoor.contains(there)
    }

    /// The rooms one exit of `location` leads to.
    ///
    /// Used for the naming reaches, never for movement: `travel` reads the
    /// exit table itself and a gate that is shut still refuses. A conditional
    /// exit counts here even when its gate is closed, because a shut gate is
    /// something you can be heard through and something you can walk up to;
    /// what it stops is the walking, and FOLLOW refuses in the gate's own
    /// words a moment later.
    ///
    /// **A `.dynamic` exit is deliberately not walked.** Its destination is
    /// author code, and this runs on every parse rather than on every FOLLOW —
    /// so consulting it would turn a closure the author wrote to be asked once
    /// a turn into one asked on every line the player types. A dynamic exit
    /// therefore widens nothing: whoever stands at the far end of it is
    /// nameable if they have been met, and not otherwise.
    ///
    /// - Parameters:
    ///   - location: the room to look out of.
    ///   - definition: the static game definition.
    ///   - state: the current world state.
    /// - Returns: the rooms next door.
    static func adjacentRooms(
        to location: EntityID,
        definition: GameDefinition,
        state: WorldState
    ) -> Set<EntityID> {
        guard let exits = definition.exits[location] else { return [] }
        var rooms: Set<EntityID> = []
        for target in exits.values {
            switch target {
            case .to(let destination), .conditional(let destination, _, _):
                rooms.insert(destination)
            case .door(let destination, let doorID):
                // A hidden door is not an exit yet, exactly as `go` sees it.
                guard isPerceivable(doorID, definition: definition, state: state) else { continue }
                rooms.insert(destination)
            case .blocked, .dynamic:
                continue
            }
        }
        return rooms
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
