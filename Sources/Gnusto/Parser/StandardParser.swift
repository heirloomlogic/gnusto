/// A parsed command in ID form; `GameWorld` converts it to the author-facing
/// `Command` by attaching canonical proxies.
struct ParsedCommand: Equatable {
    /// A multi-object marker in the direct slot: "take all", "drop them".
    /// The parser only flags it; expansion needs world state, so it happens
    /// in `GameWorld`.
    enum MultiObject: Equatable {
        case all
        case them

        init?(phrase: [String]) {
            switch phrase {
            case ["all"], ["everything"]: self = .all
            case ["them"]: self = .them
            default: return nil
            }
        }
    }

    var intent: Intent
    var directObject: EntityID?
    var indirectObject: EntityID?
    var multiple: MultiObject?
    var preposition: String?
    var direction: Direction?
    var verbPhrase: String
    var rawInput: String
}

/// What the player can currently refer to: the *visible* item set. You can
/// name what you can see (even through a shut glass jar); the actions enforce
/// reachability separately.
struct Scope: Sendable {
    let visibleItems: Set<EntityID>
    /// What "it" currently refers to, if anything.
    var pronounIt: EntityID?
}

/// Pure-function parser: tokenize → noise strip → candidate rules by leading
/// verb words (most specific first) → pattern fit → scoped noun resolution.
struct StandardParser {
    let vocabulary: Vocabulary
    /// Sorted by specificity (descending) once here, so per-parse candidate
    /// selection is a stable filter rather than a sort. The sort itself is
    /// made stable by hand — `sorted(by:)` doesn't guarantee it — so rows of
    /// equal specificity keep their table order.
    let syntaxRules: [SyntaxRule]

    init(vocabulary: Vocabulary, syntaxRules: [SyntaxRule]) {
        self.vocabulary = vocabulary
        self.syntaxRules =
            syntaxRules
            .enumerated()
            .sorted { lhs, rhs in
                lhs.element.specificity == rhs.element.specificity
                    ? lhs.offset < rhs.offset
                    : lhs.element.specificity > rhs.element.specificity
            }
            .map(\.element)
    }

    func parse(_ input: String, scope: Scope) -> Result<ParsedCommand, ParseError> {
        parse(tokens: tokenize(input), rawInput: input, scope: scope)
    }

    /// The token-level entry: `perform` re-parses augmented token lists when
    /// the player answers a clarifying question, without re-tokenizing.
    func parse(
        tokens: [String], rawInput: String, scope: Scope
    ) -> Result<ParsedCommand, ParseError> {
        guard !tokens.isEmpty else {
            return .failure(.empty)
        }

        // Bare direction: "n", "south".
        if tokens.count == 1, let direction = vocabulary.directions[tokens[0]] {
            return .success(
                ParsedCommand(
                    intent: .go, direction: direction, verbPhrase: tokens[0],
                    rawInput: rawInput))
        }

        // Candidate rules: those whose leading verb words prefix the tokens.
        // The table is pre-sorted most-specific-first.
        let candidates = syntaxRules.filter { tokens.starts(with: $0.leadingWords) }

        guard !candidates.isEmpty else {
            let first = tokens[0]
            if !vocabulary.knows(first) {
                return .failure(.unknownWord(first))
            }
            return .failure(.notAVerb(first))
        }

        // Try each candidate rule; remember the most specific near-miss.
        var bestFailure: ParseError?
        for rule in candidates {
            switch fit(rule, tokens: tokens, rawInput: rawInput, scope: scope) {
            case .command(let parsed):
                return .success(parsed)
            case .mismatch:
                continue
            case .nearMiss(let error):
                bestFailure = bestFailure ?? error
                continue
            }
        }

        return .failure(bestFailure ?? .unmatchedSyntax)
    }

    // MARK: - Pattern fitting

    /// How one rule relates to one token list: it matches, it's structurally
    /// wrong (try the next rule silently), or it's a near-miss worth telling
    /// the player about if nothing matches.
    private enum FitOutcome {
        case command(ParsedCommand)
        case mismatch
        case nearMiss(ParseError)
    }

    /// Walks the rule's elements over the tokens: literal words must appear
    /// where the pattern puts them, object slots swallow the tokens in
    /// between, a direction slot takes one direction token.
    private func fit(
        _ rule: SyntaxRule, tokens: [String], rawInput: String, scope: Scope
    ) -> FitOutcome {
        let leadingWords = rule.leadingWords
        let verbPhrase = leadingWords.joined(separator: " ")
        var cursor = leadingWords.count

        var directPhrase: [String]?
        var indirectPhrase: [String]?
        /// Where each phrase begins in `tokens` — a clarifying answer is
        /// inserted there (`prefix + answer + suffix`).
        var directStart = 0
        var indirectStart = 0
        var direction: Direction?
        var preposition: String?
        /// An object slot waiting for the next literal word to close it.
        var openSlot: SyntaxElement?

        for (index, element) in rule.elements.enumerated().dropFirst(leadingWords.count) {
            switch element {
            case .word(let word):
                if let slot = openSlot {
                    // The literal closes the open object slot: the tokens up
                    // to its first occurrence are the slot's phrase.
                    guard
                        let split = tokens[cursor...].firstIndex(of: word),
                        split > cursor
                    else {
                        // "hang cloak" — an object phrase with the preposition
                        // missing. If the phrase resolves, ask for the rest;
                        // the answer belongs after the never-typed preposition.
                        if slot == .directObject, cursor < tokens.count,
                            case .success(let id) = resolve(
                                Array(tokens[cursor...]), in: scope)
                        {
                            return .nearMiss(
                                .missingIndirect(
                                    verb: verbPhrase,
                                    objectName: displayName(of: id),
                                    preposition: word,
                                    prefix: tokens + [word]))
                        }
                        return .mismatch
                    }
                    let phrase = Array(tokens[cursor..<split])
                    if slot == .directObject {
                        directPhrase = phrase
                        directStart = cursor
                        // The word sealing the direct object ahead of a second
                        // object is the command's preposition.
                        if rule.elements.contains(.indirectObject) {
                            preposition = word
                        }
                    } else {
                        indirectPhrase = phrase
                        indirectStart = cursor
                    }
                    cursor = split + 1
                    openSlot = nil
                } else {
                    guard cursor < tokens.count, tokens[cursor] == word else {
                        return .mismatch
                    }
                    cursor += 1
                }

            case .directObject, .indirectObject:
                if index == rule.elements.count - 1 {
                    // A slot ending the pattern takes everything left.
                    guard cursor < tokens.count else {
                        return missingSlotOutcome(
                            element, verbPhrase: verbPhrase, tokens: tokens,
                            directPhrase: directPhrase, preposition: preposition,
                            scope: scope)
                    }
                    let phrase = Array(tokens[cursor...])
                    if element == .directObject {
                        directPhrase = phrase
                        directStart = cursor
                    } else {
                        indirectPhrase = phrase
                        indirectStart = cursor
                    }
                    cursor = tokens.count
                } else {
                    // Mid-pattern: the next literal word closes it. (Bootstrap
                    // validation guarantees a literal follows.)
                    openSlot = element
                }

            case .direction:
                guard cursor < tokens.count else {
                    // "go" alone: the default action asks "Which way?"
                    return .command(
                        ParsedCommand(
                            intent: rule.intent, verbPhrase: verbPhrase,
                            rawInput: rawInput))
                }
                guard let matched = vocabulary.directions[tokens[cursor]] else {
                    return .mismatch
                }
                direction = matched
                cursor += 1
            }
        }

        guard openSlot == nil, cursor == tokens.count else {
            return .mismatch
        }

        // Structure fits; resolve the noun phrases against scope. Multi-object
        // keywords are flagged in the direct slot and refused in the indirect.
        var directID: EntityID?
        var multiple: ParsedCommand.MultiObject?
        if let phrase = directPhrase {
            if let keyword = ParsedCommand.MultiObject(phrase: phrase) {
                multiple = keyword
            } else {
                switch resolve(phrase, in: scope) {
                case .success(let id): directID = id
                case .failure(let error):
                    return .nearMiss(positioned(error, tokens: tokens, phraseStart: directStart))
                }
            }
        }
        var indirectID: EntityID?
        if let phrase = indirectPhrase {
            guard ParsedCommand.MultiObject(phrase: phrase) == nil else {
                return .nearMiss(.multipleNotAllowed)
            }
            switch resolve(phrase, in: scope) {
            case .success(let id): indirectID = id
            case .failure(let error):
                return .nearMiss(positioned(error, tokens: tokens, phraseStart: indirectStart))
            }
        }

        return .command(
            ParsedCommand(
                intent: rule.intent,
                directObject: directID,
                indirectObject: indirectID,
                multiple: multiple,
                preposition: preposition,
                direction: direction,
                verbPhrase: verbPhrase,
                rawInput: rawInput))
    }

    /// The near-miss for a pattern whose final object slot got no tokens:
    /// "take" asks for an object; "put cloak on" asks what to put it on.
    /// Either way the answer belongs after everything already typed.
    private func missingSlotOutcome(
        _ slot: SyntaxElement, verbPhrase: String, tokens: [String],
        directPhrase: [String]?, preposition: String?, scope: Scope
    ) -> FitOutcome {
        if slot == .directObject {
            return .nearMiss(.missingObject(verb: verbPhrase, prefix: tokens))
        }
        if let directPhrase,
            case .success(let id) = resolve(directPhrase, in: scope)
        {
            return .nearMiss(
                .missingIndirect(
                    verb: verbPhrase,
                    objectName: displayName(of: id),
                    preposition: preposition ?? "",
                    prefix: tokens))
        }
        return .mismatch
    }

    /// Fills an `ambiguous` error's answer-insertion context: the reply's
    /// adjectives belong just ahead of the phrase that was ambiguous.
    private func positioned(
        _ error: ParseError, tokens: [String], phraseStart: Int
    ) -> ParseError {
        guard case .ambiguous(let names, _, _) = error else { return error }
        return .ambiguous(
            names: names,
            prefix: Array(tokens[..<phraseStart]),
            suffix: Array(tokens[phraseStart...]))
    }

    // MARK: - Pieces

    /// Splits an input line into lowercased, alphanumeric-only tokens, dropping
    /// noise words. Any run of letters or digits is a token; every other
    /// character — whitespace, punctuation, symbols — is a separator, so
    /// `"don't"` yields `["don", "t"]` and `"north-west"` yields
    /// `["north", "west"]`. Splitting straight on the alphanumeric predicate
    /// skips the intermediate cleaned `String` and `[Character]` array a
    /// map-to-spaces pass would allocate per line.
    func tokenize(_ input: String) -> [String] {
        input.lowercased()
            .split(whereSeparator: { !($0.isLetter || $0.isNumber) })
            .map(String.init)
            .filter { !vocabulary.noiseWords.contains($0) }
    }

    /// Resolves a noun phrase against scope: every token must be one of the
    /// item's words, and the final token must be a noun.
    private func resolve(_ tokens: [String], in scope: Scope) -> Result<EntityID, ParseError> {
        // Pronouns resolve ahead of any item lexicon: "it" is whatever the
        // player last named — if it's still in sight.
        if tokens == ["it"] {
            guard let referent = scope.pronounIt else {
                return .failure(.noReferent("it"))
            }
            guard scope.visibleItems.contains(referent) else {
                return .failure(.notInScope)
            }
            return .success(referent)
        }

        let matches = scope.visibleItems.filter { id in
            vocabulary.itemLexicons[id]?.matches(tokens) == true
        }

        if matches.count > 1 {
            let names = matches.map { displayName(of: $0) }.sorted()
            // The caller (`fit`) fills the answer-insertion context via
            // `positioned` — only it knows the phrase's place in the line.
            return .failure(.ambiguous(names: names, prefix: [], suffix: []))
        }
        guard let match = matches.first else {
            if let unknown = tokens.first(where: { !vocabulary.knows($0) }) {
                return .failure(.unknownWord(unknown))
            }
            return .failure(.notInScope)
        }
        return .success(match)
    }

    private func displayName(of id: EntityID) -> String {
        vocabulary.displayNames[id] ?? id.raw
    }
}
