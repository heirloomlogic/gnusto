import Foundation

/// Pure identity for a declared entity (location, item, or global).
///
/// Created when an author writes `Location { … }`, `Item { … }`, or `@Global`.
/// Carries no data; proxy equality is reference identity on this token, which
/// survives copy-on-write of the surrounding value types. The bootstrap maps
/// each token to an ``EntityID`` derived from the property name it was stored in.
final class RefToken: Sendable {}

/// A stable, human-readable entity name derived from the Swift property label
/// at registration time (`let bar = Location { … }` → `EntityID("bar")`).
///
/// Entities owned by a content bundle are namespaced by the bundle to keep them
/// from colliding with the host, so their `raw` is dotted
/// (`EntityID("AtticContent.hall")`); a game's own entities stay bare. The raw
/// string is internal — display and parsing use the entity's `name(…)`, not this
/// ID — so the namespace never reaches the player.
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

/// A value that can live in `WorldState`'s global storage. The scalar cases
/// each pair with a dedicated `GlobalValue` conformance; ``data(typeName:bytes:)``
/// is the type-erased case that carries any other `Codable` value, so custom
/// state structs and custom traits need no new case of their own.
public enum StateValue: Hashable, Sendable, Codable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case data(typeName: String, bytes: Data)
}

/// Types usable with the `@Global` property wrapper.
///
/// A conformance is a boxing pair: ``stateValue`` packs the value into a
/// ``StateValue`` case for storage in the world state, and
/// ``init(stateValue:)`` unpacks it again. The built-in cases (`Bool`,
/// `Int`, `Double`, `String`) already conform.
public protocol GlobalValue: Sendable, Codable {
    /// This value boxed into its ``StateValue`` case for global storage.
    var stateValue: StateValue { get }

    /// Unboxes a value from global storage, returning `nil` if the stored
    /// case doesn't match this type.
    init?(stateValue: StateValue)
}

extension GlobalValue {
    /// Default boxing for any `Codable` type without a dedicated ``StateValue``
    /// case: JSON-encode into the type-erased ``StateValue/data(typeName:bytes:)``
    /// case. A bare `struct Wallet: Codable, Sendable, GlobalValue {}` picks
    /// this up; the scalar conformances below override it with their own case.
    public var stateValue: StateValue {
        let bytes: Data
        do {
            bytes = try JSONEncoder().encode(self)
        } catch {
            fatalError(
                "Gnusto: @Global value of type \(Self.self) is not encodable: \(error)")
        }
        return .data(typeName: String(reflecting: Self.self), bytes: bytes)
    }

    /// Default unboxing: decode the JSON stored in the type-erased `.data`
    /// case. Returns `nil` if the stored case isn't `.data` or the bytes no
    /// longer decode as this type (e.g. a plugin changed its state struct).
    public init?(stateValue: StateValue) {
        guard case .data(_, let bytes) = stateValue else { return nil }
        guard let value = try? JSONDecoder().decode(Self.self, from: bytes) else {
            return nil
        }
        self = value
    }
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
