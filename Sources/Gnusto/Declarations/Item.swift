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
    var resolved: (frame: TurnFrame, id: EntityID) {
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

    /// True if the item is a container (things can be put inside it).
    public var isContainer: Bool {
        let (frame, id) = resolved
        return frame.definition.items[id]?.isContainer == true
    }

    /// Whether the item is open. A container without the `openable` trait is
    /// always open; assigning to it is a no-op. An openable item reflects and
    /// updates the current open state.
    public var isOpen: Bool {
        get {
            let (frame, id) = resolved
            let definition = frame.definition
            return frame.with {
                Visibility.isOpen(id, definition: definition, state: $0.state)
            }
        }
        nonmutating set {
            let (frame, id) = resolved
            // Only openable items track an open flag; for anything else the
            // set is a no-op (a bare container is permanently open).
            guard frame.definition.items[id]?.isOpenable == true else { return }
            frame.with { scratch in
                if newValue {
                    scratch.state.openItems.insert(id)
                } else {
                    scratch.state.openItems.remove(id)
                }
            }
        }
    }

    /// Whether a `lightSource` item is currently lit. Reads false — and
    /// assigning is a no-op — for anything that isn't a light source. The
    /// raw setter changes only the light itself; it never describes the room
    /// or announces the change (the `turn on`/`turn off` default actions do
    /// that).
    public var isLit: Bool {
        get {
            let (frame, id) = resolved
            return frame.with { $0.state.litItems.contains(id) }
        }
        nonmutating set {
            let (frame, id) = resolved
            guard frame.definition.items[id]?.isLightSource == true else { return }
            frame.with { scratch in
                if newValue {
                    scratch.state.litItems.insert(id)
                } else {
                    scratch.state.litItems.remove(id)
                }
            }
        }
    }

    /// Whether the item is locked. Assigning to a non-lockable item is a no-op.
    public var isLocked: Bool {
        get {
            let (frame, id) = resolved
            return frame.with { $0.state.lockedItems.contains(id) }
        }
        nonmutating set {
            let (frame, id) = resolved
            guard frame.definition.items[id]?.isLockable == true else { return }
            frame.with { scratch in
                if newValue {
                    scratch.state.lockedItems.insert(id)
                } else {
                    scratch.state.lockedItems.remove(id)
                }
            }
        }
    }

    /// True if the player has ever picked up or moved the item.
    public var isTouched: Bool {
        let (frame, id) = resolved
        return frame.with { $0.state.touched.contains(id) }
    }

    /// True if a `hidden` item has been revealed. Always true for an item
    /// that was never declared `hidden`.
    public var isRevealed: Bool {
        let (frame, id) = resolved
        guard frame.definition.items[id]?.isHidden == true else { return true }
        return frame.with { $0.state.revealedItems.contains(id) }
    }

    /// Reveals a `hidden` item: it becomes perceivable in visibility and room
    /// descriptions from now on. A no-op for an item that isn't `hidden`.
    public func reveal() {
        let (frame, id) = resolved
        frame.with { _ = $0.state.revealedItems.insert(id) }
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

    /// Moves the item directly to a location, bypassing the usual actions.
    public func move(to location: Location) {
        let (frame, id) = resolved
        let locationID = location.id
        frame.with { $0.state.placements[id] = .room(locationID) }
    }

    /// Moves the item inside a container, bypassing the usual actions. Traps if
    /// the target is not a container.
    public func move(inside container: Item) {
        let (frame, id) = resolved
        let containerID = container.id
        guard frame.definition.items[containerID]?.isContainer == true else {
            fatalError(
                "Gnusto: move(inside:) target \"\(containerID)\" is not a container.")
        }
        frame.with { $0.state.placements[id] = .inside(containerID) }
    }

    /// Moves the item onto a surface, bypassing the usual actions. Traps if the
    /// target is not a surface.
    public func move(onto surface: Item) {
        let (frame, id) = resolved
        let surfaceID = surface.id
        guard frame.definition.items[surfaceID]?.isSurface == true else {
            fatalError(
                "Gnusto: move(onto:) target \"\(surfaceID)\" is not a surface.")
        }
        frame.with { $0.state.placements[id] = .on(surfaceID) }
    }

    /// Moves the item into an entity's inventory, bypassing the usual actions.
    public func move(heldBy holder: Item) {
        let (frame, id) = resolved
        let holderID = holder.id
        frame.with { $0.state.placements[id] = .heldBy(holderID) }
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
