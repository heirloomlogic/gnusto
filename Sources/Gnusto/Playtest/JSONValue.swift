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
    /// How many containers deep a document may nest before it is refused.
    ///
    /// This type is recursive and its input comes from a remote party, so
    /// without a cap the recursion below is the client's to choose: a frame of
    /// a few hundred nested brackets overflowed the cooperative pool thread's
    /// stack and killed the process, taking every open session with it and
    /// telling the client nothing — the precise outcome the no-trap rule at
    /// the top of ``MCPServer`` exists to forbid. `JSONDecoder` has a limit of
    /// its own, but it is 512, which is well past where this overflowed.
    ///
    /// Depth and length are separate properties and want separate caps:
    /// `LineBuffer.maxPendingBytes` is 64 MiB, and nesting costs two bytes a
    /// level, so the frame that killed the process was under a thousandth of a
    /// percent of what that one allows. It defends the buffer, not the stack.
    ///
    /// 32 is far above any frame this protocol carries. The deepest measured
    /// is `survey`'s `outputSchema` in the `tools/list` response, where a
    /// room's exits carry an enum of kind strings nested under properties of
    /// properties: 14 containers deep, 18 short of this cap. The deepest
    /// `inputSchema` measured, `vocabulary`'s, is 8. A real frame therefore
    /// cannot come near this, which is the property that makes the cap safe
    /// to state as a constant rather than tune.
    static let maxDepth = 32

    /// Decodes whichever of the seven shapes the document holds.
    ///
    /// Order matters at exactly one place: `Bool` is tried before `Int`, and
    /// `Int` before `Double`, so `true` stays a boolean and `1` stays a whole
    /// number rather than becoming `1.0` in an echoed request id.
    ///
    /// The ``maxDepth`` check sits on the first branch that would *descend*
    /// rather than at the top, so a scalar never reads `codingPath` at all —
    /// and `codingPath` is built on demand, so where it is read is a question
    /// worth asking. Scalars are almost everything in a frame: the array of
    /// commands a `replay` carries is one container holding thousands of
    /// strings, and a `tools/list` response is the densest in containers
    /// anything here sends. Decoding both 2,000 times, with the check and
    /// without it, put the two inside each other's run-to-run noise and not
    /// always in the same order, so the placement is the cheap one and the
    /// remaining cost does not measure.
    ///
    /// A note on the message, which is deliberately not load-bearing: the
    /// cascade of `try?` above swallows whatever a nested value threw, so the
    /// error that finally leaves a too-deep document is the generic one below
    /// rather than the depth complaint. That costs nothing, because
    /// ``MCPServer/handle(line:)`` renders every decoding failure as the same
    /// `-32700`, and a remote party is told no more about why its frame was
    /// refused either way.
    ///
    /// - Parameter decoder: the decoder to read from.
    /// - Throws: `DecodingError.dataCorrupted` for a value that is none of the
    ///   seven, and for a document nested past ``maxDepth``.
    init(from decoder: any Decoder) throws {
        func notAValue(_ why: String) -> DecodingError {
            DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: why))
        }

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
        } else if decoder.codingPath.count >= Self.maxDepth {
            throw notAValue("JSON nested deeper than \(Self.maxDepth) containers")
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            throw notAValue("not a JSON value")
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
