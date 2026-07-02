/// One element of a verb pattern: a literal word the player must type, or a
/// slot the parser fills from the rest of the sentence. String literals in a
/// pattern are `.word`s, so rows read the way they're typed:
///
/// ```swift
/// SyntaxRule("give", .directObject, "to", .indirectObject, intent: Intent("give"))
/// ```
public enum SyntaxElement: Sendable, Hashable, ExpressibleByStringLiteral {
    /// A literal token: the verb word itself, a particle, or a preposition.
    case word(String)
    /// The primary noun phrase.
    case directObject
    /// The secondary noun phrase.
    case indirectObject
    /// A compass direction.
    case direction

    /// A string literal in a pattern is a literal word.
    public init(stringLiteral value: String) {
        self = .word(value)
    }
}

/// One row of the verb table: a pattern of literal words and slots, and the
/// intent a match produces. Data, not code — games can add rows through their
/// `verbs` block to teach the parser new player-typeable verbs.
public struct SyntaxRule: Sendable {
    let elements: [SyntaxElement]
    let intent: Intent

    /// Builds a verb row from its pattern. The pattern must start with a
    /// literal word; the bootstrap validates custom rows and reports
    /// malformed patterns as fatal diagnostics.
    public init(_ elements: SyntaxElement..., intent: Intent) {
        self.elements = elements
        self.intent = intent
    }

    /// Identifies a row by what the player types — the full pattern — so the
    /// merged table can dedupe and a game can reclaim a built-in verb
    /// (last-wins). Independent of the intent produced.
    struct Key: Hashable {
        let elements: [SyntaxElement]
    }

    var key: Key { Key(elements: elements) }

    /// The row's leading run of literal words: what identifies the verb when
    /// filtering candidates, and the `verbPhrase` shown in messages.
    var leadingWords: [String] {
        var words: [String] = []
        for element in elements {
            guard case .word(let word) = element else { break }
            words.append(word)
        }
        return words
    }

    /// Every literal word in the pattern, in order.
    var literalWords: [String] {
        elements.compactMap { element in
            if case .word(let word) = element { word } else { nil }
        }
    }

    /// Specificity for rule-selection order: rows with more literal structure
    /// are tried first, and among those, rows that consume more slots. Ties
    /// keep their table order (the parser's sort is stable by construction).
    var specificity: Int {
        let literals = literalWords.count
        return literals * 10 + (elements.count - literals)
    }

    /// The pattern rendered for diagnostics: `give <object> to <second object>`.
    var patternDescription: String {
        elements.map { element in
            switch element {
            case .word(let word): word
            case .directObject: "<object>"
            case .indirectObject: "<second object>"
            case .direction: "<direction>"
            }
        }.joined(separator: " ")
    }

    /// The ways a pattern can be malformed, reported all at once by the
    /// bootstrap for each custom row. The standard table is covered by the
    /// parser test suite instead.
    var patternProblems: [String] {
        var problems: [String] = []
        let pattern = "verb pattern \"\(patternDescription)\""

        guard case .word = elements.first else {
            problems.append("\(pattern) must start with a literal word.")
            return problems
        }

        func count(of element: SyntaxElement) -> Int {
            elements.filter { $0 == element }.count
        }

        let objectSlots = elements.filter { $0 == .directObject || $0 == .indirectObject }
        if count(of: .directObject) > 1 {
            problems.append("\(pattern) has more than one <object> slot.")
        }
        if count(of: .indirectObject) > 1 {
            problems.append("\(pattern) has more than one <second object> slot.")
        }
        if objectSlots.first == .indirectObject {
            problems.append("\(pattern) puts the <second object> slot before <object>.")
        }
        if elements.contains(.direction) {
            if !objectSlots.isEmpty {
                problems.append("\(pattern) combines a direction slot with an object slot.")
            }
            if elements.last != .direction {
                problems.append("\(pattern) must end with its direction slot.")
            }
            if count(of: .direction) > 1 {
                problems.append("\(pattern) has more than one direction slot.")
            }
        }
        for (index, element) in elements.enumerated()
        where element == .directObject || element == .indirectObject {
            guard index < elements.count - 1 else { continue }
            guard case .word = elements[index + 1] else {
                problems.append(
                    "\(pattern) needs a literal word between an object slot "
                        + "and whatever follows it.")
                continue
            }
        }
        return problems
    }
}

extension SyntaxRule {
    /// The default verb table. Ordering within the table doesn't matter;
    /// the parser sorts candidate rules by specificity.
    static let standardTable: [SyntaxRule] = [
        // take
        .init("take", .directObject, intent: .take),
        .init("get", .directObject, intent: .take),
        .init("grab", .directObject, intent: .take),
        .init("hold", .directObject, intent: .take),
        .init("carry", .directObject, intent: .take),
        .init("pick", "up", .directObject, intent: .take),
        .init("pick", .directObject, "up", intent: .take),

        // drop
        .init("drop", .directObject, intent: .drop),
        .init("discard", .directObject, intent: .drop),
        .init("put", "down", .directObject, intent: .drop),
        .init("put", .directObject, "down", intent: .drop),

        // examine
        .init("examine", .directObject, intent: .examine),
        .init("x", .directObject, intent: .examine),
        .init("inspect", .directObject, intent: .examine),
        .init("look", "at", .directObject, intent: .examine),
        .init("l", "at", .directObject, intent: .examine),

        // read
        .init("read", .directObject, intent: .read),

        // wear
        .init("wear", .directObject, intent: .wear),
        .init("don", .directObject, intent: .wear),
        .init("put", "on", .directObject, intent: .wear),

        // doff
        .init("remove", .directObject, intent: .doff),
        .init("doff", .directObject, intent: .doff),
        .init("take", "off", .directObject, intent: .doff),
        .init("take", .directObject, "off", intent: .doff),

        // putOn
        .init("put", .directObject, "on", .indirectObject, intent: .putOn),
        .init("put", .directObject, "onto", .indirectObject, intent: .putOn),
        .init("hang", .directObject, "on", .indirectObject, intent: .putOn),
        .init("place", .directObject, "on", .indirectObject, intent: .putOn),

        // putIn
        .init("put", .directObject, "in", .indirectObject, intent: .putIn),
        .init("put", .directObject, "into", .indirectObject, intent: .putIn),

        // open / close
        .init("open", .directObject, intent: .open),
        .init("close", .directObject, intent: .close),
        .init("shut", .directObject, intent: .close),

        // lock / unlock
        .init("lock", .directObject, "with", .indirectObject, intent: .lock),
        .init("unlock", .directObject, "with", .indirectObject, intent: .unlock),

        // lookIn / search
        .init("look", "in", .directObject, intent: .lookIn),
        .init("search", .directObject, intent: .lookIn),

        // push
        .init("push", .directObject, intent: .push),
        .init("move", .directObject, intent: .push),

        // movement
        .init("go", .direction, intent: .go),
        .init("walk", .direction, intent: .go),
        .init("run", .direction, intent: .go),

        // perception & meta
        .init("look", intent: .look),
        .init("l", intent: .look),
        .init("inventory", intent: .inventory),
        .init("inv", intent: .inventory),
        .init("i", intent: .inventory),
        .init("score", intent: .score),
        .init("quit", intent: .quit),
        .init("q", intent: .quit),
        .init("version", intent: .version),
    ]
}
