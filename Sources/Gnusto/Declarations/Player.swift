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

    /// The player's current score.
    public var score: Int {
        get { Ctx.current.with { $0.state.score } }
        nonmutating set { Ctx.current.with { $0.state.score = newValue } }
    }

    /// The number of turns taken so far.
    public var moves: Int {
        Ctx.current.with { $0.state.moves }
    }

    /// True if the player is carrying the item (including worn items).
    public func isCarrying(_ item: Item) -> Bool {
        item.isHeld
    }

    /// True if the player is wearing the item.
    public func isWearing(_ item: Item) -> Bool {
        item.isWorn
    }

    /// The player's starting location, declared in the `map` block.
    public func starts(in location: Location) -> MapEntry {
        MapEntry(kind: .playerStart(location.token))
    }
}
