/// A place in the world.
///
/// A `Location` value is both the declaration (`let bar = Location { … }`)
/// and the live reference used in rule bodies (`bar.isLit = true`). Live
/// properties read and write the current turn's state; outside a turn they
/// trap with an explanation.
public struct Location: Sendable, Equatable {
    let token: RefToken
    let traits: [LocationTrait]

    /// Declares a location from a block of traits (`Location { name(…) }`).
    public init(@LocationBuilder _ traits: () -> [LocationTrait] = { [] }) {
        self.token = RefToken()
        self.traits = traits()
    }

    /// Two locations are equal when they share the same declaration identity.
    public static func == (lhs: Location, rhs: Location) -> Bool {
        lhs.token === rhs.token
    }

    var id: EntityID {
        Ctx.current.id(for: token, describing: "Location")
    }

    /// Binds the frame once per access. `id` resolution itself takes the
    /// frame lock, so it must never be evaluated inside a `with` closure.
    private var resolved: (frame: TurnFrame, id: EntityID) {
        let frame = Ctx.current
        return (frame, frame.id(for: token, describing: "Location"))
    }

    // MARK: - Live state

    /// Whether the location currently has light. Locations declared `dark`
    /// start unlit; all others start lit.
    public var isLit: Bool {
        get {
            let (frame, id) = resolved
            return frame.with { $0.state.litRooms.contains(id) }
        }
        nonmutating set {
            let (frame, id) = resolved
            frame.with { scratch in
                if newValue {
                    scratch.state.litRooms.insert(id)
                } else {
                    scratch.state.litRooms.remove(id)
                }
            }
        }
    }

    /// Whether the player has seen this location (set on the first lit visit).
    public var isVisited: Bool {
        let (frame, id) = resolved
        return frame.with { $0.state.visited.contains(id) }
    }

    /// The location's long description. Assigning replaces it for the rest
    /// of the game.
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

    /// The location's display name.
    public var name: String {
        let (frame, id) = resolved
        return frame.displayName(of: id)
    }

    /// True if the item is directly in this location.
    public func contains(_ item: Item) -> Bool {
        let (frame, locationID) = resolved
        let itemID = item.id
        return frame.with { $0.state.placements[itemID] == .room(locationID) }
    }

    /// Reads a custom trait declared with `trait("key", value)`, or `nil` if
    /// the location has no trait by that key or it was stored as a different type.
    public func trait<T: GlobalValue>(_ key: String, as type: T.Type) -> T? {
        let (frame, id) = resolved
        guard let stored = frame.customTrait(key, of: id) else { return nil }
        return T(stateValue: stored)
    }

    // MARK: - Map factories

    /// An exit leading north to `to`.
    public func north(_ to: Location) -> MapEntry { exit(.north, to) }
    /// An exit leading south to `to`.
    public func south(_ to: Location) -> MapEntry { exit(.south, to) }
    /// An exit leading east to `to`.
    public func east(_ to: Location) -> MapEntry { exit(.east, to) }
    /// An exit leading west to `to`.
    public func west(_ to: Location) -> MapEntry { exit(.west, to) }
    /// An exit leading northeast to `to`.
    public func northeast(_ to: Location) -> MapEntry { exit(.northeast, to) }
    /// An exit leading northwest to `to`.
    public func northwest(_ to: Location) -> MapEntry { exit(.northwest, to) }
    /// An exit leading southeast to `to`.
    public func southeast(_ to: Location) -> MapEntry { exit(.southeast, to) }
    /// An exit leading southwest to `to`.
    public func southwest(_ to: Location) -> MapEntry { exit(.southwest, to) }
    /// An exit leading up to `to`.
    public func up(_ to: Location) -> MapEntry { exit(.up, to) }
    /// An exit leading down to `to`.
    public func down(_ to: Location) -> MapEntry { exit(.down, to) }
    /// An exit leading in to `to`.
    public func `in`(_ to: Location) -> MapEntry { exit(.in, to) }
    /// An exit leading out to `to`.
    public func out(_ to: Location) -> MapEntry { exit(.out, to) }

    /// A north exit blocked with the given refusal message.
    public func north(blocked message: String) -> MapEntry { blockedExit(.north, message) }
    /// A south exit blocked with the given refusal message.
    public func south(blocked message: String) -> MapEntry { blockedExit(.south, message) }
    /// An east exit blocked with the given refusal message.
    public func east(blocked message: String) -> MapEntry { blockedExit(.east, message) }
    /// A west exit blocked with the given refusal message.
    public func west(blocked message: String) -> MapEntry { blockedExit(.west, message) }
    /// A northeast exit blocked with the given refusal message.
    public func northeast(blocked message: String) -> MapEntry { blockedExit(.northeast, message) }
    /// A northwest exit blocked with the given refusal message.
    public func northwest(blocked message: String) -> MapEntry { blockedExit(.northwest, message) }
    /// A southeast exit blocked with the given refusal message.
    public func southeast(blocked message: String) -> MapEntry { blockedExit(.southeast, message) }
    /// A southwest exit blocked with the given refusal message.
    public func southwest(blocked message: String) -> MapEntry { blockedExit(.southwest, message) }
    /// An up exit blocked with the given refusal message.
    public func up(blocked message: String) -> MapEntry { blockedExit(.up, message) }
    /// A down exit blocked with the given refusal message.
    public func down(blocked message: String) -> MapEntry { blockedExit(.down, message) }
    /// An in exit blocked with the given refusal message.
    public func `in`(blocked message: String) -> MapEntry { blockedExit(.in, message) }
    /// An out exit blocked with the given refusal message.
    public func out(blocked message: String) -> MapEntry { blockedExit(.out, message) }

    /// The general form behind the per-direction sugar, for exits chosen
    /// dynamically (e.g. built in a loop).
    public func exit(_ direction: Direction, to destination: Location) -> MapEntry {
        MapEntry(kind: .exit(from: token, direction: direction, to: destination.token))
    }

    /// The general form of a blocked exit.
    public func exit(_ direction: Direction, blocked message: String) -> MapEntry {
        MapEntry(kind: .blockedExit(from: token, direction: direction, message: message))
    }

    private func exit(_ direction: Direction, _ to: Location) -> MapEntry {
        exit(direction, to: to)
    }

    private func blockedExit(_ direction: Direction, _ message: String) -> MapEntry {
        exit(direction, blocked: message)
    }

    // MARK: - Rule factories

    /// Runs before the default action when the named intents are attempted
    /// in this location.
    public func before(
        _ intents: Intent...,
        perform body: @escaping @Sendable () throws -> Void
    ) -> Rule {
        Rule(scope: .location(token), phase: .before, intents: Set(intents), body: body)
    }

    /// Runs after the default action when the named intents succeed in this
    /// location.
    public func after(
        _ intents: Intent...,
        perform body: @escaping @Sendable () throws -> Void
    ) -> Rule {
        Rule(scope: .location(token), phase: .after, intents: Set(intents), body: body)
    }

    /// Runs at the start of every turn the player spends in this location.
    public func beforeEachTurn(
        perform body: @escaping @Sendable () throws -> Void
    ) -> Rule {
        Rule(scope: .location(token), phase: .beforeEachTurn, intents: [], body: body)
    }

    /// Runs at the end of every turn the player spends in this location —
    /// including turns that were refused, because world time still passes.
    public func afterEachTurn(
        perform body: @escaping @Sendable () throws -> Void
    ) -> Rule {
        Rule(scope: .location(token), phase: .afterEachTurn, intents: [], body: body)
    }

    /// Runs when the player enters this location, just before the room is
    /// automatically described.
    ///
    /// Use `say(_:)` to add a line of ambiance and still let the room's name and
    /// description print. Use `reply(_:)`/`refuse(_:)` only to *replace* the
    /// automatic description entirely (a cutscene, blacking out, a room too dark
    /// to see) — they end the turn before the room is described.
    public func onEnter(
        perform body: @escaping @Sendable () throws -> Void
    ) -> Rule {
        Rule(scope: .location(token), phase: .onEnter, intents: [], body: body)
    }
}
