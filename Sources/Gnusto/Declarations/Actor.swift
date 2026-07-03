/// A character in the world — a troll, a thief, a parrot.
///
/// An `Actor` is declared like an ``Item`` and *stored* like one: the same
/// placements, visibility, save format, and rule table apply, so nothing
/// else in the engine needs a second entity kind. What the engine adds is
/// perception and manners — actors are listed as people rather than
/// objects, and can't be picked up. Everything behavioral (roaming, combat,
/// theft) belongs to rules and plugins, not the engine.
///
/// ```swift
/// let troll = Actor {
///     name("surly troll")
///     description("All muscle and grudge.")
/// }
///
/// var map: WorldMap {
///     troll.starts(in: trollRoom)
/// }
/// ```
///
/// The builder takes the *item* trait vocabulary: the descriptive traits
/// (`name`, `description`, `adjectives`, `synonyms`, `firstSight`,
/// `hidden`, custom `trait(_:_:)` values, even `lightSource`) all mean what
/// they mean on items — with one twist: an actor's `firstSight` is its
/// standing presence line, printed on *every* look, not just the first.
/// Mechanical item traits (`container`, `surface`, `wearable`, …) are legal
/// but almost never what you want on a person; the bootstrap leaves them in
/// place and records a warning.
///
/// There is deliberately no built-in alive/dead flag: the engine has no
/// behavior that would branch on one. A combat plugin composes death from
/// the pieces the actor does have — `dropAll()`, `vanish()`, a custom
/// trait, a corpse `Item` of the game's own voice.
public struct Actor: Sendable, Equatable {
    let token: RefToken
    let traits: [ItemTrait]

    /// Declares an actor from a block of traits (`Actor { name(…) }`).
    public init(@ItemBuilder _ traits: () -> [ItemTrait] = { [] }) {
        self.token = RefToken()
        self.traits = traits()
    }

    /// Two actors are equal when they share the same declaration identity.
    public static func == (lhs: Actor, rhs: Actor) -> Bool {
        lhs.token === rhs.token
    }

    /// The item-shaped view of this actor: same token, same traits. Actors
    /// are stored in the item registry, so every live read goes through the
    /// one implementation `Item` already has.
    var asItem: Item {
        Item(token: token, traits: traits)
    }

    // MARK: - Live state

    /// The actor's display name.
    public var name: String {
        asItem.name
    }

    /// The actor's examine text. Assigning replaces it for the rest of the
    /// game.
    public var description: String {
        get { asItem.description }
        nonmutating set { asItem.description = newValue }
    }

    /// True if a `hidden` actor has been revealed. Always true for an actor
    /// that was never declared `hidden`.
    public var isRevealed: Bool {
        asItem.isRevealed
    }

    /// Reveals a `hidden` actor. A no-op for one that isn't `hidden`.
    public func reveal() {
        asItem.reveal()
    }

    /// The room the actor is in, or nil while offstage.
    public var location: Location? {
        let (frame, id) = asItem.resolved
        guard case .room(let roomID)? = frame.with({ $0.state.placements[id] }) else {
            return nil
        }
        return frame.definition.registry.locations[roomID]
    }

    /// True if the actor is in the location.
    public func isIn(_ location: Location) -> Bool {
        asItem.isIn(location)
    }

    /// Moves the actor to a location, bypassing the usual actions.
    public func move(to location: Location) {
        asItem.move(to: location)
    }

    /// Removes the actor from play. Its inventory goes with it — still
    /// `heldBy` the actor, offstage. Call ``dropAll()`` first for the
    /// classic "the troll's axe clatters to the floor" death.
    public func vanish() {
        asItem.vanish()
    }

    /// True if the actor is carrying the item.
    public func holds(_ item: Item) -> Bool {
        let (frame, myID) = asItem.resolved
        let itemID = item.id
        return frame.with { $0.state.placements[itemID] == .heldBy(myID) }
    }

    /// The items the actor is carrying, sorted by ID for stable iteration.
    public var inventory: [Item] {
        let (frame, myID) = asItem.resolved
        let held = frame.with { scratch in
            scratch.state.placements
                .filter { $0.value == .heldBy(myID) }
                .keys.sorted()
        }
        return held.compactMap { frame.definition.registry.items[$0] }
    }

    /// Moves everything the actor carries onto the floor of the actor's
    /// room. A no-op for an offstage actor.
    public func dropAll() {
        let (frame, myID) = asItem.resolved
        frame.with { scratch in
            guard case .room(let roomID)? = scratch.state.placements[myID] else { return }
            for (id, placement) in scratch.state.placements
            where placement == .heldBy(myID) {
                scratch.state.placements[id] = .room(roomID)
            }
        }
    }

    // MARK: - Map factories

    /// The actor starts the game in a location — the only placement an
    /// actor accepts.
    public func starts(in location: Location) -> MapEntry {
        MapEntry(kind: .placement(item: token, target: .location(location.token)))
    }

    // MARK: - Rule factories

    /// Runs before the default action when the named intents target this
    /// actor.
    public func before(
        _ intents: Intent...,
        perform body: @escaping @Sendable () throws -> Void
    ) -> Rule {
        Rule(scope: .item(token), phase: .before, intents: Set(intents), body: body)
    }

    /// Runs after the default action when the named intents succeeded
    /// against this actor.
    public func after(
        _ intents: Intent...,
        perform body: @escaping @Sendable () throws -> Void
    ) -> Rule {
        Rule(scope: .item(token), phase: .after, intents: Set(intents), body: body)
    }
}
