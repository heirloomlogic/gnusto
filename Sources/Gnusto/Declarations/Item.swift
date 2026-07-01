/// A thing in the world.
///
/// Like ``Location``, an `Item` value is both the declaration
/// (`let cloak = Item { … }`) and the live reference used in rule bodies
/// (`hook.holds(cloak)`).
public struct Item: Sendable, Equatable {
    let token: RefToken
    let traits: [ItemTrait]

    /// Declares an item from a block of traits (`Item { name(…) }`).
    public init(@ItemBuilder _ traits: () -> [ItemTrait] = { [] }) {
        self.token = RefToken()
        self.traits = traits()
    }

    /// Two items are equal when they share the same declaration identity.
    public static func == (lhs: Item, rhs: Item) -> Bool {
        lhs.token === rhs.token
    }

    var id: EntityID {
        Ctx.current.id(for: token, describing: "Item")
    }

    /// Binds the frame once per access. `id` resolution itself takes the
    /// frame lock, so it must never be evaluated inside a `with` closure.
    private var resolved: (frame: TurnFrame, id: EntityID) {
        let frame = Ctx.current
        return (frame, frame.id(for: token, describing: "Item"))
    }

    // MARK: - Live state

    /// The item's display name.
    public var name: String {
        let (frame, id) = resolved
        return frame.displayName(of: id)
    }

    /// The item's examine/read text. Assigning replaces it for the rest of
    /// the game.
    public var description: String {
        get {
            let (frame, id) = resolved
            return frame.describedText(of: id)
        }
        nonmutating set {
            let (frame, id) = resolved
            frame.with { $0.state.descriptionOverrides[id] = newValue }
        }
    }

    /// True if the player is carrying the item (including worn items).
    public var isHeld: Bool {
        let (frame, id) = resolved
        return frame.with { $0.state.placements[id] == .heldBy(.player) }
    }

    /// True if the player is wearing the item.
    public var isWorn: Bool {
        let (frame, id) = resolved
        return frame.with { $0.state.wornItems.contains(id) }
    }

    /// True if the player has ever picked up or moved the item.
    public var isTouched: Bool {
        let (frame, id) = resolved
        return frame.with { $0.state.touched.contains(id) }
    }

    /// True if the other item is on or inside this one.
    public func holds(_ item: Item) -> Bool {
        let (frame, myID) = resolved
        let itemID = item.id
        return frame.with { scratch in
            scratch.state.placements[itemID] == .on(myID)
                || scratch.state.placements[itemID] == .inside(myID)
        }
    }

    /// True if the item is directly in the location.
    public func isIn(_ location: Location) -> Bool {
        location.contains(self)
    }

    /// Reads a custom trait declared with `trait("key", value)`, or `nil` if
    /// the item has no trait by that key or it was stored as a different type.
    public func trait<T: GlobalValue>(_ key: String, as type: T.Type) -> T? {
        let (frame, id) = resolved
        guard let stored = frame.customTrait(key, of: id) else { return nil }
        return T(stateValue: stored)
    }

    /// Moves the item directly to a location, bypassing the usual actions.
    public func move(to location: Location) {
        let (frame, id) = resolved
        let locationID = location.id
        frame.with { $0.state.placements[id] = .room(locationID) }
    }

    /// Removes the item from play.
    public func vanish() {
        let (frame, id) = resolved
        frame.with { scratch in
            scratch.state.placements[id] = .nowhere
            scratch.state.wornItems.remove(id)
        }
    }

    // MARK: - Map factories

    /// The item starts the game in a location.
    public func starts(in location: Location) -> MapEntry {
        MapEntry(kind: .placement(item: token, target: .location(location.token)))
    }

    /// The item starts the game on a surface.
    public func starts(on item: Item) -> MapEntry {
        MapEntry(kind: .placement(item: token, target: .on(item.token)))
    }

    /// The item starts the game inside a container.
    public func starts(inside item: Item) -> MapEntry {
        MapEntry(kind: .placement(item: token, target: .inside(item.token)))
    }

    /// The item starts the game worn by the player.
    public var startsWorn: MapEntry {
        MapEntry(kind: .placement(item: token, target: .worn))
    }

    /// The item starts the game in the player's hands.
    public var startsHeld: MapEntry {
        MapEntry(kind: .placement(item: token, target: .held))
    }

    // MARK: - Rule factories

    /// Runs before the default action when the named intents target this item.
    public func before(
        _ intents: Intent...,
        perform body: @escaping @Sendable () throws -> Void
    ) -> Rule {
        Rule(scope: .item(token), phase: .before, intents: Set(intents), body: body)
    }

    /// Runs after the default action when the named intents succeeded against
    /// this item.
    public func after(
        _ intents: Intent...,
        perform body: @escaping @Sendable () throws -> Void
    ) -> Rule {
        Rule(scope: .item(token), phase: .after, intents: Set(intents), body: body)
    }
}
