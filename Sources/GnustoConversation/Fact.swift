/// One thing the player has learned — a key into the conversation layer's
/// saved knowledge.
///
/// Modelled on ``Intent``: an opaque string identity that a game extends with
/// its own constants, so that a mistyped fact is a compile error rather than
/// a topic that silently never unlocks.
///
/// ```swift
/// extension Fact {
///     static let sawTheLetter = Fact("sawTheLetter")
///     static let butlerConfessed = Fact("butlerConfessed")
/// }
/// ```
public struct Fact: Hashable, Sendable, CustomStringConvertible {
    /// The fact's stable identifier.
    public let raw: String

    /// Creates a fact.
    ///
    /// - Parameter raw: the fact's stable identifier.
    public init(_ raw: String) {
        self.raw = raw
    }

    /// The identifier, for interpolation and diagnostics.
    public var description: String { raw }
}
