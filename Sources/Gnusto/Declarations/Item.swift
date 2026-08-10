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

    /// The name behind its definite article — "the brass lantern", or
    /// "Mrs. Vane" for an item declared `properName`. The form the engine's
    /// stock lines are given, and the one a rule's own prose usually wants.
    public var definiteName: String {
        let (frame, id) = resolved
        return frame.definiteName(of: id)
    }

    /// The name behind its indefinite article — "a brass lantern", or
    /// "Mrs. Vane" for an item declared `properName`. The form the room and
    /// inventory listings use.
    public var indefiniteName: String {
        let (frame, id) = resolved
        return frame.indefiniteName(of: id)
    }

    /// True if the item's name is a proper name, so no article precedes it.
    public var isProperName: Bool {
        let (frame, id) = resolved
        return frame.isProperName(id)
    }

    /// True if the item's name is grammatically plural, so the verbs in a line
    /// about it agree in the plural.
    public var isPlural: Bool {
        let (frame, id) = resolved
        return frame.isPlural(id)
    }

    /// The definite name paired with its number, for a line whose verb has to
    /// agree with it — "the rails" plus the fact that they are plural.
    public var definiteNoun: GameText.Noun {
        let (frame, id) = resolved
        return frame.definiteNoun(of: id)
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

    /// True if the player could put a hand on the item from where they are
    /// standing: carried, lying in the room, or on or inside something open
    /// here — **to any depth**. This is the set the default actions gate on, so
    /// a rule that guards with it refuses exactly where `take` would. In the
    /// dark it is only what the player is carrying.
    ///
    /// Ask this rather than rebuilding it from ``isHeld``, ``isIn(_:)`` and
    /// ``holds(_:)``; <doc:ContainersDoorsAndLocks> says why.
    public var isReachable: Bool {
        let (frame, id) = resolved
        return Visibility.isReachable(id, frame: frame)
    }

    /// True if `actor` could put a hand on the item from the room they are
    /// standing in: in their own hands, lying in that room, or on or inside
    /// something open there — **to any depth**, as ``isReachable``.
    ///
    /// Two things differ from the player's own reach. Darkness does not gate
    /// it: an unlit room stops the player's eyes, not somebody else's arm. And
    /// what the *player* is holding is not in it — lifting from those hands is
    /// stealing, which is a plugin's job, the same rule that keeps another
    /// actor's hands out of ``isReachable``. A thief wants both sets:
    ///
    /// ```swift
    /// let loot = treasures.filter { $0.isReachable || $0.isReachable(from: thief) }
    /// ```
    ///
    /// An actor who is in no room at all — held, contained, or ``Actor/vanish()``ed
    /// — reaches only what they are carrying.
    public func isReachable(from actor: Actor) -> Bool {
        let (frame, id) = resolved
        return Visibility.isReachable(id, from: actor.asItem.id, frame: frame)
    }

    /// True if the player could see the item from where they are standing:
    /// everything ``isReachable``, plus what's behind the glass of a closed
    /// `transparent` container, plus whatever an actor in the room is holding.
    ///
    /// This one is about what the player can *watch*; ``isReachable`` is about
    /// what they can *touch*.
    public var isVisible: Bool {
        let (frame, id) = resolved
        return Visibility.isVisible(id, frame: frame)
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

    /// True if the item can be picked up — anything that isn't scenery or an
    /// actor. The inverse of "a fixture," useful for telling loose floor items
    /// from the furniture.
    public var isTakable: Bool {
        let (frame, id) = resolved
        return frame.definition.items[id]?.isTakable == true
    }

    /// True if this is a person — declared as an ``Actor`` rather than an
    /// ``Item``. Actors are stored in the item registry and reach rules
    /// through the same object slots, so this is what tells "ask the butler"
    /// from "ask the lamp."
    public var isActor: Bool {
        let (frame, id) = resolved
        return frame.definition.items[id]?.isActor == true
    }

    /// True if this is the player themselves. ``isActor`` is true for them
    /// too — they are a person — so any rule or plugin that means *somebody
    /// else* has to say so:
    ///
    /// ```swift
    /// try require(addressee.isActor && !addressee.isPlayer, else: "Nobody to tell.")
    /// ```
    public var isPlayer: Bool {
        self == Player().item
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
            scratch.state.containment().children(of: myID).sorted()
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

    /// The room the item is ultimately in, or nil while it is offstage.
    ///
    /// The answer walks up the containment chain rather than reading one link,
    /// so it is the room in every case: an item lying on the floor answers the
    /// room it lies in, and a coin inside a sack on a table in the Hall answers
    /// the Hall too. Something in the player's hands answers wherever the player
    /// is standing, and something in an actor's hands answers wherever *they*
    /// are — which is the distinction ``Player/location`` cannot make on an
    /// item's behalf.
    ///
    /// `nil` means no room is at the top of that chain: the item has been
    /// ``vanish()``ed, or it is shut inside a container that has, or the hands
    /// carrying it belong to somebody who has left play.
    ///
    /// Note that this is not a scope or visibility question. An item locked in
    /// a closed box still answers the box's room, and so does one in the dark.
    /// For what the player can see or touch, ask ``isVisible`` or
    /// ``isReachable``; for direct containment only, ask ``isIn(_:)``.
    public var location: Location? {
        let (frame, id) = resolved
        guard let roomID = frame.with({ $0.state.room(of: id) }) else { return nil }
        return frame.definition.registry.locations[roomID]
    }

    /// Moves the item directly to a location, bypassing the usual actions.
    ///
    /// Moving the vehicle the player has boarded moves its passenger — the
    /// river-current pattern; call `describeSurroundings()` after if the
    /// player should see the new banks. (`move(inside:)`, `move(onto:)`,
    /// and `vanish()` deliberately do NOT carry the player: a vehicle that
    /// leaves the room any other way strands its passenger on foot.)
    ///
    /// "Boarded" here is ``Player/vehicle``'s answer, not the raw flag — so a
    /// player teleported out from under their vehicle stays where they are
    /// rather than being dragged back in from another room.
    ///
    /// - Parameter location: the room to move the item into.
    public func move(to location: Location) {
        let (frame, id) = resolved
        let locationID = location.id
        frame.with { scratch in
            // Asked before `place`, which would otherwise satisfy the pairing
            // itself. Through the same funnel every read uses, so there is one
            // definition of "boarded" rather than a second copy here.
            let carriesPassenger =
                Visibility.boardedVehicle(
                    definition: frame.definition, state: scratch.state) == id
            scratch.state.place(id, .room(locationID))
            if carriesPassenger {
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
        frame.with { $0.state.place(id, .inside(containerID)) }
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
        frame.with { $0.state.place(id, .on(surfaceID)) }
    }

    /// Moves the item into an entity's inventory, bypassing the usual actions.
    ///
    /// - Parameter holder: the entity to hold the item.
    public func move(heldBy holder: Item) {
        let (frame, id) = resolved
        let holderID = holder.id
        frame.with { $0.state.place(id, .heldBy(holderID)) }
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
            scratch.state.place(id, .heldBy(.player))
            scratch.state.wornItems.remove(id)
        }
    }

    /// Removes the item from play.
    public func vanish() {
        let (frame, id) = resolved
        frame.with { scratch in
            scratch.state.place(id, .nowhere)
            scratch.state.wornItems.remove(id)
        }
    }

    /// Puts `other` exactly where this item is — the same room, hands,
    /// container or surface — and takes this one out of play. One thing
    /// becoming another: the boat for the punctured boat, the coal for the
    /// diamond, the gnome for the hole he left.
    ///
    /// Prefer it over `vanish()` plus a `move`, which cannot do the same job.
    /// ``location`` answers the *room* an item is in, which is all a `move(to:)`
    /// can aim at — so a hand-rolled swap drops the replacement on the floor
    /// when the original was sitting in a sack. The placement itself is what
    /// carries across here, hands and containers included.
    ///
    /// `other` inherits the placement and nothing else. It does not inherit
    /// worn state, so replacing something you are wearing leaves you holding
    /// the replacement rather than wearing it. Contents do not come across
    /// either: whatever was inside this item leaves play with it, so a caller
    /// meaning to salvage cargo moves it out first.
    ///
    /// Like `vanish()`, and unlike ``Item/move(to:)``, this does not carry a
    /// boarded player — a vehicle swapped out from under its passenger leaves
    /// them standing where they were.
    ///
    /// Replacing an item with itself does nothing.
    ///
    /// - Parameter other: the item to put in this one's place.
    public func replace(with other: Item) {
        let (frame, id) = resolved
        let otherID = other.id
        guard otherID != id else { return }
        // Read the placement before `vanish()` overwrites it, and let `vanish()`
        // stay the one definition of leaving play.
        let placement = frame.with { $0.state.placements[id] ?? .nowhere }
        vanish()
        frame.with { $0.state.place(otherID, placement) }
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
    /// A holder that is not declared a `surface` is a fatal bootstrap
    /// diagnostic, and so is a chain of placements that closes a loop — two
    /// things placed in each other are in no room, so neither can ever be
    /// listed, reached, taken or seen.
    ///
    /// - Parameter item: the surface the item begins on.
    /// - Returns: the map entry declaring the start.
    public func starts(on item: Item) -> MapEntry {
        MapEntry(kind: .placement(item: token, target: .on(item.token)))
    }

    /// The item starts the game inside a container.
    ///
    /// A holder that is not declared a `container` is a fatal bootstrap
    /// diagnostic, and so is a chain of placements that closes a loop —
    /// including an item placed inside itself.
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

    /// The item is locked and unlocked with the given key.
    ///
    /// The entry itself makes the item lockable — there is no separate trait
    /// to declare — and it starts locked unless it also declares
    /// `startsUnlocked`. The key is an ordinary property access, so renaming
    /// the key is compiler-checked; a key that is not a stored property is a
    /// fatal bootstrap diagnostic, and two `lockedBy` entries for one item
    /// likewise.
    ///
    /// - Parameter key: the item that locks and unlocks this one.
    /// - Returns: the map entry declaring the lock/key relationship.
    public func lockedBy(_ key: Item) -> MapEntry {
        MapEntry(kind: .lockKey(item: token, key: key.token))
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

    /// A live description recomputed every time the item is described, so it
    /// can react to world state — including its own:
    ///
    /// ```swift
    /// lantern.describe { lantern.isLit ? Prose.lanternOn : Prose.lanternOff }
    /// ```
    ///
    /// Declared in a `rules` block. A runtime override
    /// (`item.description = "…"`) still wins over it; a static
    /// `description(…)` trait on the same item, or a second `describe` rule
    /// for it, is a fatal bootstrap diagnostic.
    ///
    /// - Parameter body: the closure recomputing the description on each read.
    /// - Returns: the assembled describe rule.
    public func describe(_ body: @escaping @Sendable () -> String) -> Rule {
        Rule(scope: .item(token), phase: .describe, intents: [], body: {}, describeBody: body)
    }

    /// A live standing-presence line, recomputed every time the room is
    /// described — the dynamic form of the ``firstSight(_:)`` trait:
    ///
    /// ```swift
    /// bench.presence { blastHappened ? Prose.benchBurnt : Prose.benchWhole }
    /// ```
    ///
    /// On an item this is the paragraph shown until the player touches it — in
    /// place of whichever stock listing sentence the room would otherwise have
    /// printed, including *"In the X is a Y."* for something one level down
    /// inside a container. On an ``Actor`` it is the presence line shown on
    /// every look. Declared in a `rules` block. A static `firstSight(…)` trait
    /// on the same entity, or a second `presence` rule for it, is a fatal
    /// bootstrap diagnostic.
    ///
    /// One level is as deep as the room listing goes, so this rule on an item
    /// the map buries two levels down has nowhere to print. The bootstrap warns
    /// about that rather than letting a live-looking rule stay silent.
    ///
    /// - Parameter body: the closure recomputing the line on each read.
    /// - Returns: the assembled presence rule.
    public func presence(_ body: @escaping @Sendable () -> String) -> Rule {
        Rule(scope: .item(token), phase: .presence, intents: [], body: {}, describeBody: body)
    }

    /// Whether the player can put a hand on this from where they are standing —
    /// asked by the engine on top of containment, wherever a verb needs to
    /// *touch* the thing:
    ///
    /// ```swift
    /// card.reach(otherwise: "The card is squares away from you, across the sand.") {
    ///     grid.playerSquare == grid.cardSquare
    /// }
    /// ```
    ///
    /// Containment is room-granular: a thing lying in one square of a floor the
    /// map models as a single room is "in the room" from every square, and so
    /// reachable from every square. This is where a game says otherwise, once,
    /// instead of guarding `take`, `open` and `put in` one verb at a time.
    ///
    /// It narrows reach and nothing else. The item stays **visible** — the
    /// player can still name it, examine it and read about it in the room
    /// description — which is what makes `take` answer "it's across the sand"
    /// rather than "you can't see any such thing".
    ///
    /// Two things the engine settles so the closure doesn't have to. What the
    /// asker is **holding** always passes, so a rule keyed to a square can't
    /// stop the player opening a box they are carrying. And the rule is
    /// consulted **before any `before` rule runs**, so an item's own rules never
    /// fire for something out of reach.
    ///
    /// Declared in a `rules` block; a second `reach` rule for the same entity is
    /// a fatal bootstrap diagnostic. Locations don't take one.
    ///
    /// - Parameters:
    ///   - refusal: the line shown when the closure says no. Defaults to the
    ///     stock ``GameText/cantReach``.
    ///   - body: the closure answering "can they touch it from here".
    /// - Returns: the assembled reach rule.
    public func reach(
        otherwise refusal: String? = nil,
        _ body: @escaping @Sendable () -> Bool
    ) -> Rule {
        Rule(
            scope: .item(token), phase: .reach, intents: [], body: {},
            reachRule: Reach.Rule(allows: body, refusal: refusal))
    }
}
