/// Pure identity for a declared entity (location, item, or global).
///
/// Created when an author writes `Location { … }`, `Item { … }`, or `@Global`.
/// Carries no data; proxy equality is reference identity on this token, which
/// survives copy-on-write of the surrounding value types. The bootstrap maps
/// each token to an ``EntityID`` derived from the property name it was stored in.
final class RefToken: Sendable {}

/// A stable, human-readable entity name derived from the Swift property label
/// at registration time (`let bar = Location { … }` → `EntityID("bar")`).
public struct EntityID: Hashable, Comparable, Sendable, Codable, CustomStringConvertible {
    /// The underlying identifier string.
    public let raw: String

    init(_ raw: String) {
        self.raw = raw
    }

    /// The identifier string, used as the textual description.
    public var description: String { raw }

    /// Orders entity IDs lexicographically by their raw string.
    public static func < (lhs: EntityID, rhs: EntityID) -> Bool {
        lhs.raw < rhs.raw
    }
}

/// A value that can live in `WorldState`'s global storage. Cases exist only
/// for types with a `GlobalValue` conformance — add both together.
public enum StateValue: Hashable, Sendable, Codable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
}

/// Types usable with the `@Global` property wrapper.
public protocol GlobalValue: Sendable, Codable {
    var stateValue: StateValue { get }
    init?(stateValue: StateValue)
}

extension Bool: GlobalValue {
    /// This value boxed for global storage.
    public var stateValue: StateValue { .bool(self) }
    /// Unboxes a global value, or `nil` if it isn't a `Bool`.
    public init?(stateValue: StateValue) {
        guard case .bool(let value) = stateValue else { return nil }
        self = value
    }
}

extension Int: GlobalValue {
    /// This value boxed for global storage.
    public var stateValue: StateValue { .int(self) }
    /// Unboxes a global value, or `nil` if it isn't an `Int`.
    public init?(stateValue: StateValue) {
        guard case .int(let value) = stateValue else { return nil }
        self = value
    }
}

extension Double: GlobalValue {
    /// This value boxed for global storage.
    public var stateValue: StateValue { .double(self) }
    /// Unboxes a global value, or `nil` if it isn't a `Double`.
    public init?(stateValue: StateValue) {
        guard case .double(let value) = stateValue else { return nil }
        self = value
    }
}

extension String: GlobalValue {
    /// This value boxed for global storage.
    public var stateValue: StateValue { .string(self) }
    /// Unboxes a global value, or `nil` if it isn't a `String`.
    public init?(stateValue: StateValue) {
        guard case .string(let value) = stateValue else { return nil }
        self = value
    }
}
