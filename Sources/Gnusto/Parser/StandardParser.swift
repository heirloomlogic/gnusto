/// A parsed command in ID form; `GameWorld` converts it to the author-facing
/// `Command` by attaching canonical proxies.
struct ParsedCommand: Equatable {
    var intent: Intent
    var directObject: EntityID?
    var indirectObject: EntityID?
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
}

/// Pure-function parser: tokenize → noise strip → verb match (longest first)
/// → syntax-rule fit by specificity → scoped noun resolution.
struct StandardParser {
    let vocabulary: Vocabulary
    /// Sorted by specificity (descending) once here, so per-parse candidate
    /// selection is a stable filter rather than a sort.
    let syntaxRules: [SyntaxRule]

    init(vocabulary: Vocabulary, syntaxRules: [SyntaxRule]) {
        self.vocabulary = vocabulary
        self.syntaxRules = syntaxRules.sorted { $0.specificity > $1.specificity }
    }

    func parse(_ input: String, scope: Scope) -> Result<ParsedCommand, ParseError> {
        let tokens = tokenize(input)
        guard !tokens.isEmpty else {
            return .failure(.empty)
        }

        // Bare direction: "n", "south".
        if tokens.count == 1, let direction = vocabulary.directions[tokens[0]] {
            return .success(
                ParsedCommand(
                    intent: .go, direction: direction, verbPhrase: tokens[0],
                    rawInput: input))
        }

        // Verb match; the table is pre-sorted most-specific-first.
        let candidates = syntaxRules.filter { tokens.starts(with: $0.verb) }

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
            let rest = Array(tokens.dropFirst(rule.verb.count))
            let verbPhrase = rule.verb.joined(separator: " ")

            switch rule.slots {
            case .none:
                guard rest.isEmpty else { continue }
                return .success(
                    ParsedCommand(intent: rule.intent, verbPhrase: verbPhrase, rawInput: input))

            case .direction:
                if rest.isEmpty {
                    // "go" alone: the default action asks "Which way?"
                    return .success(
                        ParsedCommand(
                            intent: rule.intent, verbPhrase: verbPhrase, rawInput: input))
                }
                guard rest.count == 1, let direction = vocabulary.directions[rest[0]] else {
                    continue
                }
                return .success(
                    ParsedCommand(
                        intent: rule.intent, direction: direction, verbPhrase: verbPhrase,
                        rawInput: input))

            case .direct:
                guard !rest.isEmpty else {
                    bestFailure = bestFailure ?? .missingObject(verb: verbPhrase)
                    continue
                }
                switch resolve(rest, in: scope) {
                case .success(let id):
                    return .success(
                        ParsedCommand(
                            intent: rule.intent, directObject: id, verbPhrase: verbPhrase,
                            rawInput: input))
                case .failure(let error):
                    bestFailure = bestFailure ?? error
                    continue
                }

            case .directThenParticle(let particle):
                guard rest.count >= 2, rest.last == particle else { continue }
                switch resolve(Array(rest.dropLast()), in: scope) {
                case .success(let id):
                    return .success(
                        ParsedCommand(
                            intent: rule.intent, directObject: id, verbPhrase: verbPhrase,
                            rawInput: input))
                case .failure(let error):
                    bestFailure = bestFailure ?? error
                    continue
                }

            case .directPrepIndirect(let preposition):
                guard !rest.isEmpty else {
                    bestFailure = bestFailure ?? .missingObject(verb: verbPhrase)
                    continue
                }
                guard let split = rest.firstIndex(of: preposition), split > 0 else {
                    // "hang cloak" — resolvable object but no preposition.
                    if case .success(let id) = resolve(rest, in: scope) {
                        bestFailure =
                            bestFailure
                            ?? .missingIndirect(
                                verb: verbPhrase,
                                objectName: displayName(of: id),
                                preposition: preposition)
                    }
                    continue
                }
                let directTokens = Array(rest[..<split])
                let indirectTokens = Array(rest[(split + 1)...])
                guard !indirectTokens.isEmpty else {
                    if case .success(let id) = resolve(directTokens, in: scope) {
                        bestFailure =
                            bestFailure
                            ?? .missingIndirect(
                                verb: verbPhrase,
                                objectName: displayName(of: id),
                                preposition: preposition)
                    }
                    continue
                }
                switch (resolve(directTokens, in: scope), resolve(indirectTokens, in: scope)) {
                case (.success(let directID), .success(let indirectID)):
                    return .success(
                        ParsedCommand(
                            intent: rule.intent, directObject: directID,
                            indirectObject: indirectID, preposition: preposition,
                            verbPhrase: verbPhrase, rawInput: input))
                case (.failure(let error), _), (_, .failure(let error)):
                    bestFailure = bestFailure ?? error
                    continue
                }
            }
        }

        return .failure(bestFailure ?? .unmatchedSyntax)
    }

    // MARK: - Pieces

    func tokenize(_ input: String) -> [String] {
        let cleaned = String(
            input.lowercased().map { character in
                character.isLetter || character.isNumber ? character : " "
            })
        return
            cleaned
            .split(separator: " ")
            .map(String.init)
            .filter { !vocabulary.noiseWords.contains($0) }
    }

    /// Resolves a noun phrase against scope: every token must be one of the
    /// item's words, and the final token must be a noun.
    private func resolve(_ tokens: [String], in scope: Scope) -> Result<EntityID, ParseError> {
        let matches = scope.visibleItems.filter { id in
            vocabulary.itemLexicons[id]?.matches(tokens) == true
        }

        if matches.count > 1 {
            let names = matches.map { displayName(of: $0) }.sorted()
            return .failure(.ambiguous(names: names))
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
