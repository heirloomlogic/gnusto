/// A place in the world.
///
/// A `Location` value is both the declaration (`let bar = Location { … }`)
/// and the live reference used in rule bodies (`bar.isLit = true`). Live
/// properties read and write the current turn's state; outside a turn they
/// trap with an explanation.
public struct Location: Sendable, Equatable {
    let token: RefToken
    let traits: [LocationTrait]

    public init(@LocationBuilder _ traits: () -> [LocationTrait] = { [] }) {
        self.token = RefToken()
        self.traits = traits()
    }

    public static func == (lhs: Location, rhs: Location) -> Bool {
        lhs.token === rhs.token
    }

    var id: EntityID {
        Ctx.current.id(for: token, describing: "Location")
    }

    // MARK: - Live state

    /// Whether the location currently has light. Locations declared `dark`
    /// start unlit; all others start lit.
    public var isLit: Bool {
        get {
            // `id` resolves through the frame, so it must be evaluated
            // before entering the lock (here and in every accessor below).
            let id = self.id
            return Ctx.current.with { $0.state.litRooms.contains(id) }
        }
        nonmutating set {
            let id = self.id
            Ctx.current.with { scratch in
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
        let id = self.id
        return Ctx.current.with { $0.state.visited.contains(id) }
    }

    /// The location's long description. Assigning replaces it for the rest
    /// of the game.
    public var description: String {
        get {
            let id = self.id
            let frame = Ctx.current
            return frame.with { $0.state.descriptionOverrides[id] }
                ?? frame.definition.locations[id]?.description
                ?? ""
        }
        nonmutating set {
            let id = self.id
            Ctx.current.with { $0.state.descriptionOverrides[id] = newValue }
        }
    }

    /// The location's display name.
    public var name: String {
        let id = self.id
        return Ctx.current.definition.locations[id]?.name ?? id.raw
    }

    /// True if the item is directly in this location.
    public func contains(_ item: Item) -> Bool {
        let locationID = id
        let itemID = item.id
        return Ctx.current.with { $0.state.placements[itemID] == .room(locationID) }
    }

    // MARK: - Map factories

    public func north(_ to: Location) -> MapEntry { exit(.north, to) }
    public func south(_ to: Location) -> MapEntry { exit(.south, to) }
    public func east(_ to: Location) -> MapEntry { exit(.east, to) }
    public func west(_ to: Location) -> MapEntry { exit(.west, to) }
    public func northeast(_ to: Location) -> MapEntry { exit(.northeast, to) }
    public func northwest(_ to: Location) -> MapEntry { exit(.northwest, to) }
    public func southeast(_ to: Location) -> MapEntry { exit(.southeast, to) }
    public func southwest(_ to: Location) -> MapEntry { exit(.southwest, to) }
    public func up(_ to: Location) -> MapEntry { exit(.up, to) }
    public func down(_ to: Location) -> MapEntry { exit(.down, to) }
    public func `in`(_ to: Location) -> MapEntry { exit(.in, to) }
    public func out(_ to: Location) -> MapEntry { exit(.out, to) }

    public func north(blocked message: String) -> MapEntry { blockedExit(.north, message) }
    public func south(blocked message: String) -> MapEntry { blockedExit(.south, message) }
    public func east(blocked message: String) -> MapEntry { blockedExit(.east, message) }
    public func west(blocked message: String) -> MapEntry { blockedExit(.west, message) }
    public func northeast(blocked message: String) -> MapEntry { blockedExit(.northeast, message) }
    public func northwest(blocked message: String) -> MapEntry { blockedExit(.northwest, message) }
    public func southeast(blocked message: String) -> MapEntry { blockedExit(.southeast, message) }
    public func southwest(blocked message: String) -> MapEntry { blockedExit(.southwest, message) }
    public func up(blocked message: String) -> MapEntry { blockedExit(.up, message) }
    public func down(blocked message: String) -> MapEntry { blockedExit(.down, message) }
    public func `in`(blocked message: String) -> MapEntry { blockedExit(.in, message) }
    public func out(blocked message: String) -> MapEntry { blockedExit(.out, message) }

    private func exit(_ direction: Direction, _ to: Location) -> MapEntry {
        MapEntry(kind: .exit(from: token, direction: direction, to: to.token))
    }

    private func blockedExit(_ direction: Direction, _ message: String) -> MapEntry {
        MapEntry(kind: .blockedExit(from: token, direction: direction, message: message))
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

    /// Runs when the player enters this location.
    public func onEnter(
        perform body: @escaping @Sendable () throws -> Void
    ) -> Rule {
        Rule(scope: .location(token), phase: .onEnter, intents: [], body: body)
    }
}
