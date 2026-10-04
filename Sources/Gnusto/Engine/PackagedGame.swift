/// A presentation-independent factory for fresh instances of an importable game.
///
/// Game libraries export one value, keeping their concrete game type internal:
///
/// ```swift
/// public let game = PackagedGame { MyGame() }
/// ```
/// A front end prepares the game or constructs a ``GameWorld`` from
/// ``makeGame()``. The factory holds no mutable world or executable entry point.
public struct PackagedGame: Sendable {
    private let make: @Sendable () -> any Game

    /// Wraps a factory that constructs a fresh game for every call.
    ///
    /// - Parameter make: a factory for the library's concrete game type.
    public init<G: Game>(_ make: @escaping @Sendable () -> G) {
        self.make = make
    }

    /// The game's display title, read from a fresh game instance.
    public var title: String { make().title }

    /// Constructs a fresh game without bootstrapping a world or launching IO.
    ///
    /// - Returns: a new game instance for a front end to prepare or play.
    public func makeGame() -> any Game { make() }
}
