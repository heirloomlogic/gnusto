/// A thing in the world.
///
/// Like ``Location``, an `Item` value is both the declaration
/// (`let cloak = Item { … }`) and the live reference used in rule bodies
/// (`hook.holds(cloak)`).
public struct Item: Sendable, Equatable {
    let token: RefToken
    let traits: [ItemTrait]

    /// Declares an item from a block of traits (`Item { name(…) }`).
    ///
    /// - Parameter traits: the trait block describing the item.
    public init(@ItemBuilder _ traits: () -> [ItemTrait] = { [] }) {
        self.token = RefToken()
        self.traits = traits()
    }

    /// The item-shaped view of an existing declaration — `Actor` uses this
    /// to share one token (and so one identity) with its item storage. No
    /// new token is minted.
    init(token: RefToken, traits: [ItemTrait]) {
        self.token = token
        self.traits = traits
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
    ///
    /// - Parameter item: the item to test.
    /// - Returns: true if it rests on or inside this one.
    public func holds(_ item: Item) -> Bool {
        let (frame, myID) = resolved
        let itemID = item.id
        return frame.with { scratch in
            scratch.state.placements[itemID] == .on(myID)
                || scratch.state.placements[itemID] == .inside(myID)
        }
    }

    /// The items resting on or inside this item, sorted by ID for stable
    /// iteration.
    public var contents: [Item] {
        let (frame, myID) = resolved
        let children = frame.with { scratch in
            scratch.state.placements
                .filter { $0.value == .on(myID) || $0.value == .inside(myID) }
                .keys.sorted()
        }
        return children.compactMap { frame.definition.registry.items[$0] }
    }

    /// True if the item is directly in the location.
    ///
    /// - Parameter location: the room to test.
    /// - Returns: true if the item is directly there.
    public func isIn(_ location: Location) -> Bool {
        location.contains(self)
    }

    /// Moves the item directly to a location, bypassing the usual actions.
    ///
    /// Moving the vehicle the player has boarded moves its passenger — the
    /// river-current pattern; call `describeSurroundings()` after if the
    /// player should see the new banks. (`move(inside:)`, `move(onto:)`,
    /// and `vanish()` deliberately do NOT carry the player: a vehicle that
    /// leaves the room any other way strands its passenger on foot.)
    ///
    /// - Parameter location: the room to move the item into.
    public func move(to location: Location) {
        let (frame, id) = resolved
        let locationID = location.id
        frame.with { scratch in
            scratch.state.placements[id] = .room(locationID)
            if scratch.state.playerVehicle == id {
                scratch.state.playerLocation = locationID
            }
        }
    }

    /// Moves the item inside a container, bypassing the usual actions. Traps if
    /// the target is not a container.
    ///
    /// - Parameter container: the container to move the item into.
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
    ///
    /// - Parameter surface: the surface to move the item onto.
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
    ///
    /// - Parameter holder: the entity to hold the item.
    public func move(heldBy holder: Item) {
        let (frame, id) = resolved
        let holderID = holder.id
        frame.with { $0.state.placements[id] = .heldBy(holderID) }
    }

    /// Moves the item into an actor's inventory, bypassing the usual
    /// actions — how theft happens.
    ///
    /// - Parameter holder: the actor to hold the item.
    public func move(heldBy holder: Actor) {
        move(heldBy: holder.asItem)
    }

    /// Moves the item into the player's hands, bypassing the usual actions —
    /// the "you're suddenly holding this" moment (a lit match handed over, a
    /// summoned object). Clears any worn state, since a held item isn't worn.
    public func moveToPlayer() {
        let (frame, id) = resolved
        frame.with { scratch in
            scratch.state.placements[id] = .heldBy(.player)
            scratch.state.wornItems.remove(id)
        }
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
    ///
    /// - Parameter location: where the item begins.
    /// - Returns: the map entry declaring the start.
    public func starts(in location: Location) -> MapEntry {
        MapEntry(kind: .placement(item: token, target: .location(location.token)))
    }

    /// The item starts the game on a surface.
    ///
    /// - Parameter item: the surface the item begins on.
    /// - Returns: the map entry declaring the start.
    public func starts(on item: Item) -> MapEntry {
        MapEntry(kind: .placement(item: token, target: .on(item.token)))
    }

    /// The item starts the game inside a container.
    ///
    /// - Parameter item: the container the item begins in.
    /// - Returns: the map entry declaring the start.
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

    /// The item starts the game in an actor's inventory.
    ///
    /// - Parameter actor: the actor holding the item at the start.
    /// - Returns: the map entry declaring the start.
    public func starts(heldBy actor: Actor) -> MapEntry {
        MapEntry(kind: .placement(item: token, target: .heldBy(actor.token)))
    }

    // MARK: - Rule factories

    /// Runs before the default action when the named intents target this item.
    ///
    /// - Parameters:
    ///   - intents: the intents this rule reacts to.
    ///   - body: the rule body.
    /// - Returns: the assembled rule.
    public func before(
        _ intents: Intent...,
        perform body: @escaping @Sendable () throws -> Void
    ) -> Rule {
        Rule(scope: .item(token), phase: .before, intents: Set(intents), body: body)
    }

    /// Runs after the default action when the named intents succeeded against
    /// this item.
    ///
    /// - Parameters:
    ///   - intents: the intents this rule reacts to.
    ///   - body: the rule body.
    /// - Returns: the assembled rule.
    public func after(
        _ intents: Intent...,
        perform body: @escaping @Sendable () throws -> Void
    ) -> Rule {
        Rule(scope: .item(token), phase: .after, intents: Set(intents), body: body)
    }
}
