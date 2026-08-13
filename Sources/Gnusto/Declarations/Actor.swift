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
///
/// ``isUnconscious`` is the one condition that *is* stored, and for a reason
/// that isn't about the engine at all: two independent plugins have to agree
/// on it. A villain knocked senseless by `GnustoMeleeCombat` must stop
/// stealing under `GnustoActors`, and neither library can see the other. The
/// engine still branches on nothing — it holds the flag, and the plugins read
/// it.
public struct Actor: Sendable, Equatable {
    let token: RefToken
    let traits: [ItemTrait]

    /// Declares an actor from a block of traits (`Actor { name(…) }`).
    ///
    /// - Parameter traits: the trait block describing the actor.
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

    /// The actor-shaped view of an item the engine already knows is a person —
    /// how ``Command/actor`` is minted from the registry. Identity is the
    /// shared token, so the result compares equal to the declaration.
    init(_ item: Item) {
        self.token = item.token
        self.traits = item.traits
    }

    var id: EntityID {
        asItem.id
    }

    // MARK: - Live state

    /// The actor's display name.
    public var name: String {
        asItem.name
    }

    /// The name behind its definite article — "the surly troll", or
    /// "Mrs. Vane" for an actor declared `properName`.
    public var definiteName: String {
        asItem.definiteName
    }

    /// The name behind its indefinite article — "a surly troll", or
    /// "Mrs. Vane" for an actor declared `properName`.
    public var indefiniteName: String {
        asItem.indefiniteName
    }

    /// True if the actor's name is a proper name, so no article precedes it.
    public var isProperName: Bool {
        asItem.isProperName
    }

    /// True if the actor's name is grammatically plural, so the verbs in a line
    /// about them agree in the plural.
    public var isPlural: Bool {
        asItem.isPlural
    }

    /// The definite name paired with its number, for a line whose verb has to
    /// agree with it.
    public var definiteNoun: GameText.Noun {
        asItem.definiteNoun
    }

    /// The indefinite name paired with its number, for a line that generalizes
    /// rather than points.
    public var indefiniteNoun: GameText.Noun {
        asItem.indefiniteNoun
    }

    /// The actor's examine text. Assigning replaces it for the rest of the
    /// game.
    public var description: String {
        get { asItem.description }
        nonmutating set { asItem.description = newValue }
    }

    /// True while the actor is out cold — set by whatever knocked them down
    /// and cleared when they come round.
    ///
    /// The engine reads it nowhere. It exists so that two plugins with no
    /// knowledge of each other can agree on one fact about a person: a villain
    /// `GnustoMeleeCombat` has just battered into unconsciousness stops taking
    /// his own turn under `GnustoActors` — no roaming, no picking pockets —
    /// until he wakes. A game that knocks an actor down by its own means
    /// should set and clear it too; anything consulting the flag will then
    /// behave.
    public var isUnconscious: Bool {
        get {
            let (frame, id) = asItem.resolved
            return frame.with { $0.state.unconsciousActors.contains(id) }
        }
        nonmutating set {
            let (frame, id) = asItem.resolved
            frame.with { scratch in
                if newValue {
                    scratch.state.unconsciousActors.insert(id)
                } else {
                    scratch.state.unconsciousActors.remove(id)
                }
            }
        }
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

    /// True if the player could see the actor from where they are standing —
    /// ``Item/isVisible``, and the one a rule about a person usually wants:
    /// "does he watch you do it" is a question about being seen, not touched.
    public var isVisible: Bool {
        asItem.isVisible
    }

    /// True if the player could put a hand on the actor — ``Item/isReachable``.
    /// Reaching a person is what `give`, `attack` and `show` need; seeing one
    /// is ``isVisible``.
    public var isReachable: Bool {
        asItem.isReachable
    }

    /// True if `other` could put a hand on this actor — ``Item/isReachable(from:)``,
    /// which is to say they are standing in the same room.
    public func isReachable(from other: Actor) -> Bool {
        asItem.isReachable(from: other)
    }

    /// The room the actor is in — the read-back for ``starts(in:)``, and the
    /// answer ``move(to:)`` and ``vanish()`` rewrite. `nil` means offstage,
    /// which is the state a summoning gate keys on.
    ///
    /// ```swift
    /// daemon("houndFetches") {
    ///     guard let here = hound.location, here != player.location else { return }
    ///     hound.move(to: player.location)
    ///     say("The hound trots back in from the \(here.name).")
    /// }
    /// ```
    ///
    /// This is not ``Player/location``. The two coincide whenever the actor
    /// is being handed something, and diverge the moment one of them walks —
    /// a companion who fetches, a thief who leaves loot in a room you are not
    /// standing in.
    ///
    /// To leave something behind in the actor's room as they go, reach for
    /// ``replace(with:)`` rather than reading this and then calling
    /// ``vanish()`` — the placement is gone by the time `vanish()` returns.
    ///
    /// This is ``Item/location``, which walks up a containment chain to the
    /// room at the top of it. ``starts(in:)`` and ``move(to:)`` are the only
    /// placements an actor is given, so for every ordinary actor that walk is
    /// a single step. A game that has tucked one *inside* something — the
    /// familiar in the pocket — gets the enclosing room rather than nil, which
    /// is deliberately not the answer `Visibility.standing` gives: an actor who
    /// is in no room of his own reaches only his own hands, however well the
    /// pocket carrying him knows where it is.
    public var location: Location? {
        asItem.location
    }

    /// True if the actor is in the location.
    ///
    /// - Parameter location: the room to test.
    /// - Returns: true if the actor is there.
    public func isIn(_ location: Location) -> Bool {
        asItem.isIn(location)
    }

    /// Moves the actor to a location, bypassing the usual actions.
    ///
    /// - Parameter location: the room to move the actor into.
    public func move(to location: Location) {
        asItem.move(to: location)
    }

    /// Removes the actor from play. Its inventory goes with it — still
    /// `heldBy` the actor, offstage. Call ``dropAll()`` first for the
    /// classic "the troll's axe clatters to the floor" death.
    public func vanish() {
        asItem.vanish()
    }

    /// Puts `other` in the room the actor is standing in and takes the actor
    /// out of play — ``Item/replace(with:)``, and the gnome for the hole he
    /// left. One call, so a rule never has to read ``location`` before
    /// ``vanish()`` empties it.
    ///
    /// The mover mirror is otherwise partial on purpose: an actor's placement
    /// is only ever a room or nowhere, which is why there is no
    /// `move(inside:)` here. This one belongs anyway, because it never places
    /// the *actor* — it places `other` where the actor stood.
    ///
    /// - Parameter other: the item to leave in the actor's place.
    public func replace(with other: Item) {
        asItem.replace(with: other)
    }

    /// True if the actor is carrying the item.
    ///
    /// - Parameter item: the item to test.
    /// - Returns: true if the actor holds it.
    public func holds(_ item: Item) -> Bool {
        let (frame, myID) = asItem.resolved
        let itemID = item.id
        return frame.with { $0.state.placements[itemID] == .heldBy(myID) }
    }

    /// True if the item is anywhere in the actor's possession: in their hands,
    /// or on or inside something they are carrying — **to any depth**.
    ///
    /// ``holds(_:)`` tests one level, which is the wrong question the moment
    /// somebody carries a bag: a coin in a purse in a satchel over his shoulder
    /// is his, and `holds(coin)` says no.
    ///
    /// - Parameter item: the item to test.
    /// - Returns: true if the item is somewhere under the actor.
    public func possesses(_ item: Item) -> Bool {
        let (frame, myID) = asItem.resolved
        let itemID = item.id
        return frame.with { $0.state.isPossession(itemID, of: myID) }
    }

    /// The items the actor is carrying, sorted by ID for stable iteration.
    public var inventory: [Item] {
        let (frame, myID) = asItem.resolved
        let held = frame.with { scratch in
            scratch.state.containment().held[myID] ?? []
        }
        return held.compactMap { frame.definition.registry.items[$0] }
    }

    /// Moves everything the actor carries onto the floor of the actor's
    /// room. A no-op for an offstage actor.
    public func dropAll() {
        let (frame, myID) = asItem.resolved
        frame.with { scratch in
            guard case .room(let roomID)? = scratch.state.placements[myID] else { return }
            // Capture the bucket before the loop: the first `place` invalidates
            // the cache, so re-reading it mid-loop would rebuild it each time.
            let carried = scratch.state.containment().held[myID] ?? []
            for id in carried {
                scratch.state.place(id, .room(roomID))
            }
        }
    }

    // MARK: - Map factories

    /// The actor starts the game in a location — the only placement an
    /// actor accepts.
    ///
    /// - Parameter location: where the actor begins.
    /// - Returns: the map entry declaring the start.
    public func starts(in location: Location) -> MapEntry {
        MapEntry(kind: .placement(item: token, target: .location(location.token)))
    }

    // MARK: - Rule factories

    /// Runs before the default action when the named intents target this
    /// actor.
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

    /// Runs after the default action when the named intents succeeded
    /// against this actor.
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

    /// A live examine text, recomputed every time the actor is described.
    ///
    /// - Parameter body: the closure recomputing the description on each read.
    /// - Returns: the assembled describe rule.
    public func describe(_ body: @escaping @Sendable () -> String) -> Rule {
        asItem.describe(body)
    }

    /// A live standing-presence line, recomputed every time the actor's room is
    /// described — the dynamic form of the ``firstSight(_:)`` trait, and the way
    /// a person on a schedule says something different in each room they stand
    /// in:
    ///
    /// ```swift
    /// constance.presence {
    ///     constance.isIn(parlour) ? Prose.inHerChair : Prose.onTheStep
    /// }
    /// ```
    ///
    /// - Parameter body: the closure recomputing the line on each read.
    /// - Returns: the assembled presence rule.
    public func presence(_ body: @escaping @Sendable () -> String) -> Rule {
        asItem.presence(body)
    }

    /// Whether the player can put a hand on this person from where they are
    /// standing — ``Item/reach(otherwise:_:)``, asked of an actor.
    ///
    /// - Parameters:
    ///   - refusal: the line shown when the closure says no. Defaults to the
    ///     stock ``GameText/cantReach``.
    ///   - body: the closure answering "can they touch him from here".
    /// - Returns: the assembled reach rule.
    public func reach(
        otherwise refusal: String? = nil,
        _ body: @escaping @Sendable () -> Bool
    ) -> Rule {
        asItem.reach(otherwise: refusal, body)
    }
}
