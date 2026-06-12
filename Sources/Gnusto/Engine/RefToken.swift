/// Pure identity for a declared entity (location, item, or global).
///
/// Created when an author writes `Location { … }`, `Item { … }`, or `@Global`.
/// Carries no data; proxy equality is reference identity on this token, which
/// survives copy-on-write of the surrounding value types. The bootstrap maps
/// each token to an ``EntityID`` derived from the property name it was stored in.
final class RefToken: Sendable {}

/// A stable, human-readable entity name derived from the Swift property label
/// at registration time (`let bar = Location { … }` → `EntityID("bar")`).
public struct EntityID: Hashable, Sendable, Codable, CustomStringConvertible {
    public let raw: String

    init(_ raw: String) {
        self.raw = raw
    }

    public var description: String { raw }
}

/// A value that can live in `WorldState`'s global storage.
public enum StateValue: Hashable, Sendable, Codable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case id(EntityID)
}

/// Types usable with the `@Global` property wrapper.
public protocol GlobalValue: Sendable, Codable {
    var stateValue: StateValue { get }
    init?(stateValue: StateValue)
}

extension Bool: GlobalValue {
    public var stateValue: StateValue { .bool(self) }
    public init?(stateValue: StateValue) {
        guard case .bool(let value) = stateValue else { return nil }
        self = value
    }
}

extension Int: GlobalValue {
    public var stateValue: StateValue { .int(self) }
    public init?(stateValue: StateValue) {
        guard case .int(let value) = stateValue else { return nil }
        self = value
    }
}

extension Double: GlobalValue {
    public var stateValue: StateValue { .double(self) }
    public init?(stateValue: StateValue) {
        guard case .double(let value) = stateValue else { return nil }
        self = value
    }
}

extension String: GlobalValue {
    public var stateValue: StateValue { .string(self) }
    public init?(stateValue: StateValue) {
        guard case .string(let value) = stateValue else { return nil }
        self = value
    }
}
