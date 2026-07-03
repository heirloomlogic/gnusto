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
