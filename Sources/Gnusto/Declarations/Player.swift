/// The player character, available as `player` inside any computed property
/// of a `Game` type.
public struct Player: Sendable {
    init() {}

    /// Where the player is. Assigning teleports without describing the
    /// destination; normal movement happens through the `go` action.
    public var location: Location {
        get {
            let frame = Ctx.current
            let id = frame.with { $0.state.playerLocation }
            return frame.location(for: id)
        }
        nonmutating set {
            let id = newValue.id
            Ctx.current.with { $0.state.playerLocation = id }
        }
    }

    /// The `enterable` the player is currently in, or nil on foot.
    /// Read-only: board and disembark are actions, so their refusal logic
    /// can't be bypassed by assignment. This is the gate terrain rules key
    /// on:
    ///
    /// ```swift
    /// world.before(.go) {
    ///     if player.vehicle == boat, command.direction == .up {
    ///         try refuse("The boat declines the stairs.")
    ///     }
    /// }
    /// ```
    public var vehicle: Item? {
        let frame = Ctx.current
        let id = frame.with {
            Visibility.boardedVehicle(definition: frame.definition, state: $0.state)
        }
        guard let id else { return nil }
        return frame.definition.registry.items[id]
    }

    /// The player's current score.
    public var score: Int {
        get { Ctx.current.with { $0.state.score } }
        nonmutating set { Ctx.current.with { $0.state.score = newValue } }
    }

    /// The number of turns taken so far.
    public var moves: Int {
        Ctx.current.with { $0.state.moves }
    }

    /// The items the player is carrying (including worn items), sorted by ID
    /// for stable iteration.
    public var inventory: [Item] {
        let frame = Ctx.current
        let held = frame.with { scratch in
            scratch.state.containment().held[.player] ?? []
        }
        return held.compactMap { frame.definition.registry.items[$0] }
    }

    /// True if the player is carrying the item (including worn items).
    ///
    /// - Parameter item: the item to test.
    /// - Returns: true if the player is carrying it.
    public func isCarrying(_ item: Item) -> Bool {
        item.isHeld
    }

    /// True if the player is wearing the item.
    ///
    /// - Parameter item: the item to test.
    /// - Returns: true if the player is wearing it.
    public func isWearing(_ item: Item) -> Bool {
        item.isWorn
    }

    /// The player's starting location, declared in the `map` block.
    ///
    /// - Parameter location: where the player begins.
    /// - Returns: the map entry declaring the start.
    public func starts(in location: Location) -> MapEntry {
        MapEntry(kind: .playerStart(location.token))
    }
}
