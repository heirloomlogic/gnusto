/// The player character, available as `player` inside any computed property
/// of a `Game` type.
public struct Player: Sendable {
    init() {}

    /// The identity token the player's item answers to. One token for the
    /// whole process, because `player` is vended as a fresh value on every
    /// access and item identity is reference identity on this token — a
    /// per-access token would make `player.item == player.item` false and
    /// leave every rule attached to a stranger.
    static let itemToken = RefToken()

    /// The traits the bootstrap builds the player's item from. Nouns only:
    /// no `description(…)`, so a game is free to attach `describe { }`
    /// without tripping the trait-and-rule conflict. The stock examine text
    /// comes from ``GameText/selfDescription`` instead.
    static let itemTraits: [ItemTrait] = [
        name("yourself"),
        synonyms("me", "myself", "self"),
    ]

    /// The player as a thing in the world — what `X ME` resolves to, and
    /// where per-game text and rules about the player's own body hang:
    ///
    /// ```swift
    /// player.item.describe {
    ///     player.isCarrying(lantern) ? "Lit from below, and grubby." : "Grubby."
    /// }
    /// player.item.before(.take) { try refuse("You have quite enough of yourself.") }
    /// ```
    ///
    /// The engine synthesizes it; no game declares it. It is always in scope
    /// and never in a room, so it appears in no room description, no
    /// inventory, and no `TAKE ALL`.
    public var item: Item {
        Item(token: Player.itemToken, traits: Player.itemTraits)
    }

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
            Ctx.current.with { $0.state.teleportPlayer(to: id) }
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
        guard let id = frame.with({ $0.state.playerVehicle }) else { return nil }
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
