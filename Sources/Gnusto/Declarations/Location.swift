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
    var resolved: (frame: TurnFrame, id: EntityID) {
        let frame = Ctx.current
        return (frame, frame.id(for: token, describing: "Location"))
    }

    // MARK: - Live state

    /// Whether the location currently has light — its own (locations declared
    /// `dark` start unlit; all others start lit) or a lit `lightSource` item
    /// shining here. Read and write are deliberately asymmetric: the getter
    /// answers "is there light here", the setter gives or removes the room's
    /// *inherent* light and never touches any item's lit state.
    public var isLit: Bool {
        get {
            let (frame, id) = resolved
            let definition = frame.definition
            return frame.with {
                !Visibility.isDark(at: id, definition: definition, state: $0.state)
            }
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

    // MARK: - Map factories

    // Per-direction sugar (`north`, `down`, `west`, …) lives in
    // `LocationExits.swift`, generated from one private helper per exit kind so
    // the direction names stay a single family and this file stays lean. All of
    // it funnels into the four general `exit(_:…)` forms below.

    /// The general destination exit, for directions chosen dynamically
    /// (e.g. built in a loop).
    public func exit(_ direction: Direction, to destination: Location) -> MapEntry {
        MapEntry(kind: .exit(from: token, direction: direction, to: destination.token))
    }

    /// The general blocked exit.
    public func exit(_ direction: Direction, blocked message: String) -> MapEntry {
        MapEntry(kind: .blockedExit(from: token, direction: direction, message: message))
    }

    /// The general door exit: passable only while `door` (an `openable` item
    /// shared between both rooms) is open.
    public func exit(_ direction: Direction, to destination: Location, via door: Item) -> MapEntry {
        MapEntry(
            kind: .doorExit(
                from: token, direction: direction, to: destination.token, door: door.token))
    }

    /// The general conditional exit: `condition` is evaluated at `go` time, and
    /// the player is refused with `blocked` while it is false.
    public func exit(
        _ direction: Direction,
        to destination: Location,
        when condition: @escaping @Sendable () -> Bool,
        otherwise blocked: String
    ) -> MapEntry {
        MapEntry(
            kind: .conditionalExit(
                from: token, direction: direction, to: destination.token,
                condition: condition, blocked: blocked))
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
