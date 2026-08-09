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
    /// An abstract subject of conversation — "ask the butler about **the
    /// murder**". Unlike the object slots, a topic is never resolved against
    /// the world: it takes the rest of the line as typed, so a subject the
    /// game has never heard of still reaches the rules instead of dying as
    /// "You can't see any such thing."
    case topic

    /// A string literal in a pattern is a literal word.
    ///
    /// - Parameter value: the literal token as typed.
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

    /// The row's leading run of literal words: what identifies the verb when
    /// filtering candidates, and the `verbPhrase` shown in messages.
    ///
    /// Stored rather than computed: the parser filters the whole table by
    /// `leadingWords` on every command, and the bootstrap reads it once per row
    /// per game. Both were allocating a fresh array per access.
    let leadingWords: [String]

    /// Every literal word in the pattern, in order.
    let literalWords: [String]

    /// Specificity for rule-selection order: rows with more literal structure
    /// are tried first, and among those, rows that consume more slots. Ties
    /// keep their table order (the parser's sort is stable by construction).
    let specificity: Int

    /// Builds a verb row from its pattern. The pattern must start with a
    /// literal word; the bootstrap validates custom rows and reports
    /// malformed patterns as fatal diagnostics.
    ///
    /// - Parameters:
    ///   - elements: the pattern of literal words and slots.
    ///   - intent: the intent a match produces.
    public init(_ elements: SyntaxElement..., intent: Intent) {
        self.init(elements, intent: intent)
    }

    /// The array-taking form, for callers that already hold a pattern — the
    /// stub table builds its rows this way.
    ///
    /// - Parameters:
    ///   - elements: the pattern of literal words and slots.
    ///   - intent: the intent a match produces.
    init(_ elements: [SyntaxElement], intent: Intent) {
        self.elements = elements
        self.intent = intent

        var leading: [String] = []
        var literals: [String] = []
        var stillLeading = true
        for element in elements {
            guard case .word(let word) = element else {
                stillLeading = false
                continue
            }
            literals.append(word)
            if stillLeading { leading.append(word) }
        }
        self.leadingWords = leading
        self.literalWords = literals
        self.specificity = literals.count * 10 + (elements.count - literals.count)
    }

    /// Identifies a row by what the player types — the full pattern — so the
    /// merged table can dedupe and a game can reclaim a built-in verb
    /// (last-wins). Independent of the intent produced.
    struct Key: Hashable {
        let elements: [SyntaxElement]
    }

    var key: Key { Key(elements: elements) }

    /// The pattern rendered for diagnostics: `give <object> to <second object>`.
    var patternDescription: String {
        elements.map { element in
            switch element {
            case .word(let word): word
            case .directObject: "<object>"
            case .indirectObject: "<second object>"
            case .direction: "<direction>"
            case .topic: "<topic>"
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
        // A direction slot takes exactly one token and ends its pattern, so an
        // <object> slot sitting *immediately* before one splits at a fixed
        // place: the noun phrase is everything up to the last token. That is
        // the only object-and-direction shape the parser can place, and it is
        // how a verb takes a noun and a direction at once. Issue #151.
        let objectSlotClosedByDirection =
            elements.last == .direction && elements.dropLast().last == .directObject
        if elements.contains(.direction) {
            if !objectSlots.isEmpty, !objectSlotClosedByDirection {
                problems.append(
                    "\(pattern) may put an <object> slot beside a direction slot "
                        + "only immediately before it.")
            }
            if elements.last != .direction {
                problems.append("\(pattern) must end with its direction slot.")
            }
            if count(of: .direction) > 1 {
                problems.append("\(pattern) has more than one direction slot.")
            }
        }
        // A topic swallows the rest of the line without a scope check to fall
        // back on, so it may only end a pattern: a mid-pattern topic would
        // mis-split on the first occurrence of whatever closed it, silently.
        if elements.contains(.topic) {
            if elements.last != .topic {
                problems.append("\(pattern) must end with its topic slot.")
            }
            if count(of: .topic) > 1 {
                problems.append("\(pattern) has more than one topic slot.")
            }
            if elements.contains(.indirectObject) {
                problems.append("\(pattern) combines a topic slot with a <second object> slot.")
            }
            if elements.contains(.direction) {
                problems.append("\(pattern) combines a topic slot with a direction slot.")
            }
        }
        for (index, element) in elements.enumerated()
        where element == .directObject || element == .indirectObject {
            guard index < elements.count - 1 else { continue }
            // The trailing direction slot closes an <object> slot by itself —
            // see above. Everything else needs a literal word to split on.
            if objectSlotClosedByDirection, index == elements.count - 2 { continue }
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
    /// Every verb the engine ships: the mechanically load-bearing rows, then
    /// the stub rows that are words without mechanics. Ordering within the
    /// table doesn't matter; the parser sorts candidate rules by specificity.
    static let standardTable: [SyntaxRule] = coreTable + stubTable

    /// The standard rows that reach one intent, for a `verbs` block that lists
    /// an engine intent rather than re-spelling its rows — see
    /// ``Intent/verbRows``. Reads the two stage-4 lookups instead of grouping
    /// the table again: `cores` and `stubs` already hold their rows per intent.
    ///
    /// - Parameter intent: the intent whose standard rows to fetch.
    /// - Returns: the rows that produce it, or none if the engine ships no verb
    ///   for it.
    static func standardRows(producing intent: Intent) -> [SyntaxRule] {
        DefaultActions.coresByIntent[intent]?.rows
            ?? DefaultActions.stubsByIntent[intent]?.rows
            ?? []
    }
}
