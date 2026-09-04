// Gated on the `Playtest` package trait. See `Package.swift`.
#if Playtest

import Foundation

/// A JSON value, exactly as the wire carries it.
///
/// The play-test server hand-rolls JSON-RPC (see ``MCPServer`` for why), and
/// hand-rolling it means the ids, params and results have to be held as
/// *values* rather than as some particular Swift type: a request id is
/// whatever the client chose — a number, a string, or absent — and must be
/// echoed back unchanged, and a tool's input schema is a literal JSON document
/// rather than anything Swift models.
///
/// Codable rather than `JSONSerialization`, on purpose. `JSONSerialization`
/// hands back `NSNumber`, and `NSNumber(1) as? Bool` is `true`, so the obvious
/// bridge turns a request `"id": 1` into `"id": true` and the client stops
/// recognising its own replies. `JSONDecoder` distinguishes the two correctly
/// on every platform, and `JSONEncoder` is already in the dependency graph
/// (`SaveFile`), so this costs nothing new.
///
/// The literal conformances below are what let a tool's schema be written as
/// the JSON it is:
///
/// ```swift
/// let schema: JSONValue = ["type": "object", "properties": [:]]
/// ```
enum JSONValue: Hashable, Sendable {
    case null
    case bool(Bool)
    case integer(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])
}

// MARK: - Reading a value apart

extension JSONValue {
    /// The string this is, or `nil` if it is anything else.
    var stringValue: String? {
        guard case .string(let value) = self else { return nil }
        return value
    }

    /// The whole number this is, or `nil` if it is anything else.
    var intValue: Int? {
        guard case .integer(let value) = self else { return nil }
        return value
    }

    /// The members of the object this is, or `nil` if it is anything else.
    var objectValue: [String: JSONValue]? {
        guard case .object(let value) = self else { return nil }
        return value
    }

    /// The elements of the array this is, or `nil` if it is anything else.
    var arrayValue: [JSONValue]? {
        guard case .array(let value) = self else { return nil }
        return value
    }

    /// Whether this is JSON `null`. Distinct from *absent*, which is a `nil`
    /// `JSONValue?` — a distinction JSON-RPC cares about, since a request with
    /// no id is a notification.
    var isNull: Bool {
        self == .null
    }

    /// One member of the object this is, absent if this isn't an object.
    ///
    /// - Parameter key: the member name to look up.
    /// - Returns: the member, or `nil` when it isn't there.
    subscript(key: String) -> JSONValue? {
        objectValue?[key]
    }
}

// MARK: - The wire

extension JSONValue {
    /// Parses one JSON document.
    ///
    /// - Parameter text: the document, as received.
    /// - Throws: a `DecodingError` when the text isn't JSON. The server turns
    ///   that into a `-32700`; nothing here traps.
    init(text: String) throws {
        self = try Self.decoder.decode(JSONValue.self, from: Data(text.utf8))
    }

    /// The one decoder, and below it the one encoder.
    ///
    /// A coder is stateless once configured, and both are built on every frame
    /// otherwise — a server's whole life is frames. `static let` rather than a
    /// computed `static var`, on the constant-table rule this repo states for
    /// prose in `CLAUDE.md`: a `var` would rebuild the thing on every read,
    /// which is the cost this is here to stop paying.
    private static let decoder = JSONDecoder()

    /// The encoder ``text`` renders through, configured once.
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    /// This value as compact JSON on a single line — the frame format the
    /// transport writes, and the text a structured tool result is rendered to.
    ///
    /// Keys are sorted so that a response is a function of its value alone:
    /// Swift dictionaries are unordered, and a frame whose text changed run to
    /// run would make every protocol test a guess.
    ///
    /// Non-throwing by design, and by the no-trap rule at the top of
    /// ``MCPServer``. The only value `JSONEncoder` refuses is a non-finite
    /// double, which cannot be parsed out of JSON and is never built here; the
    /// fallback is `null`, which is at least a legal frame.
    var text: String {
        guard
            let data = try? Self.encoder.encode(self),
            let text = String(data: data, encoding: .utf8)
        else {
            return "null"
        }
        return text
    }
}

extension JSONValue: Codable {
    /// Decodes whichever of the seven shapes the document holds.
    ///
    /// Order matters at exactly one place: `Bool` is tried before `Int`, and
    /// `Int` before `Double`, so `true` stays a boolean and `1` stays a whole
    /// number rather than becoming `1.0` in an echoed request id.
    ///
    /// - Parameter decoder: the decoder to read from.
    /// - Throws: `DecodingError.dataCorrupted` for a value that is none of
    ///   them, which the standard decoders cannot actually produce.
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "not a JSON value"))
        }
    }

    /// Writes the value back out in its own shape.
    ///
    /// - Parameter encoder: the encoder to write to.
    /// - Throws: whatever the encoder throws.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .integer(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}

// MARK: - Written as the JSON it is

extension JSONValue: ExpressibleByNilLiteral {
    /// JSON `null`.
    init(nilLiteral: ()) {
        self = .null
    }
}

extension JSONValue: ExpressibleByBooleanLiteral {
    /// A JSON boolean.
    ///
    /// - Parameter value: the literal.
    init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension JSONValue: ExpressibleByIntegerLiteral {
    /// A JSON whole number.
    ///
    /// - Parameter value: the literal.
    init(integerLiteral value: Int) {
        self = .integer(value)
    }
}

extension JSONValue: ExpressibleByFloatLiteral {
    /// A JSON number with a fractional part.
    ///
    /// - Parameter value: the literal.
    init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension JSONValue: ExpressibleByStringLiteral {
    /// A JSON string.
    ///
    /// - Parameter value: the literal.
    init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension JSONValue: ExpressibleByArrayLiteral {
    /// A JSON array.
    ///
    /// - Parameter elements: the literal's elements.
    init(arrayLiteral elements: JSONValue...) {
        self = .array(elements)
    }
}

extension JSONValue: ExpressibleByDictionaryLiteral {
    /// A JSON object. A repeated key keeps the last one written, rather than
    /// trapping the way `Dictionary`'s own literal would — the no-trap rule
    /// again, and a schema with a duplicated key is a typo, not a crash.
    ///
    /// - Parameter elements: the literal's members.
    init(dictionaryLiteral elements: (String, JSONValue)...) {
        self = .object(Dictionary(elements) { _, last in last })
    }
}

#endif
