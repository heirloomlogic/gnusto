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
    /// The raw words of a topic slot, kept at the same level as the object
    /// phrases; `GameWorld` mints the author-facing `Topic` from them.
    var topic: [String]?
    /// Who was told to do this, when the line was `<actor>, <words>` and that
    /// actor takes orders. `nil` — overwhelmingly the common case — means the
    /// player is acting on their own account.
    var actor: EntityID?
    var verbPhrase: String
    var rawInput: String
}

/// What the player can currently refer to: the *visible* item set. You can
/// name what you can see (even through a shut glass jar); the actions enforce
/// reachability separately.
struct Scope: Sendable {
    let visibleItems: Set<EntityID>
    /// The people among ``visibleItems``. The parser needs to tell
    /// `delphine, hello` from `lamp, hello`.
    let visibleActors: Set<EntityID>
    /// Actors standing in some *other* room. Consulted only by a far-sighted
    /// intent (FOLLOW), and only after the visible set has failed, so a phrase
    /// that already names something here can never change meaning.
    let distantActors: Set<EntityID>
    /// What "it" currently refers to, if anything.
    var pronounIt: EntityID?
    /// For each actor declared `takesOrders` who is standing in a room, what
    /// *that* actor could name from where it stands. The parser has no world
    /// to walk, so `GameWorld` hands these down alongside the player's own set
    /// and the parser stays a pure function of its inputs. Item sets rather
    /// than whole scopes, so `Scope` doesn't become a type that contains
    /// itself: an order is never an order to somebody else, and the scope the
    /// order is read in is built at the one place that needs it.
    let orderTakers: [EntityID: Set<EntityID>]

    init(
        visibleItems: Set<EntityID>,
        visibleActors: Set<EntityID> = [],
        distantActors: Set<EntityID> = [],
        pronounIt: EntityID? = nil,
        orderTakers: [EntityID: Set<EntityID>] = [:]
    ) {
        self.visibleItems = visibleItems
        self.visibleActors = visibleActors
        self.distantActors = distantActors
        self.pronounIt = pronounIt
        self.orderTakers = orderTakers
    }
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

        // "delphine, hello" — addressing somebody. A greeting is the one thing
        // anybody answers; anything else is an order, and only an actor
        // declared `takesOrders` has a way to act on another's word. The rest
        // are heard and declined, exactly as they always were.
        if let comma = tokens.firstIndex(of: ","), comma > 0 {
            let address = Array(tokens[..<comma])
            let rest = tokens[(comma + 1)...].filter { $0 != "," }
            if case .success(let addressee) = resolve(address, in: scope),
                scope.visibleActors.contains(addressee)
            {
                if rest.isEmpty || isGreeting(rest, at: addressee, address: address, scope: scope) {
                    return .success(
                        ParsedCommand(
                            intent: .greet, directObject: addressee,
                            verbPhrase: "greet", rawInput: rawInput))
                }
                guard scope.orderTakers[addressee] != nil else {
                    return .failure(.notTakingOrders(definiteName(of: addressee)))
                }
                return order(rest, to: addressee, address: address, scope: scope, rawInput: rawInput)
            }
            // Nobody in sight answers to that name — but somebody you sent out
            // of the room might. An order-taker is nameable while out of sight
            // the way FOLLOW's quarry is: you call after the robot through the
            // doorway, which is the whole point of sending it where you can't
            // go. Second pass, so no phrase that already resolves in the room
            // can change meaning.
            if !scope.orderTakers.isEmpty,
                case .success(let addressee) = resolve(
                    address, in: scope, alsoConsidering: Set(scope.orderTakers.keys)),
                let theirs = scope.orderTakers[addressee]
            {
                // Calling after somebody carries an order and not a hello: you
                // can shout "push the button" through a doorway, but greeting
                // a person you can't see is simply not seeing them.
                guard !rest.isEmpty,
                    !isGreeting(
                        rest, at: addressee, address: address,
                        scope: Scope(visibleItems: theirs, pronounIt: scope.pronounIt))
                else {
                    return .failure(.notInScope)
                }
                return order(rest, to: addressee, address: address, scope: scope, rawInput: rawInput)
            }
        }
        // Not an address, or not to a person: the comma goes back to being
        // noise before anything downstream — a clarification prefix, a topic
        // slot — can see it. A line that was *only* commas is then empty, and
        // has to be caught again: everything below assumes a first token.
        let tokens = tokens.filter { $0 != "," }
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

    /// The words after the comma, read as a command in the addressee's own
    /// scope and stamped with them as its agent.
    ///
    /// Recursion is bounded the same way ``isGreeting(_:at:address:scope:)``'s
    /// is: a strictly shorter token list, the first comma already consumed, and
    /// an inner scope carrying no order-takers — so an order can never be an
    /// order to somebody else.
    ///
    /// A failure is re-anchored on the address, so that the question an
    /// incomplete order asks ("What do you want to push?") is answered as an
    /// order too, and not as the player's own next move.
    private func order(
        _ rest: [String], to addressee: EntityID, address: [String],
        scope: Scope, rawInput: String
    ) -> Result<ParsedCommand, ParseError> {
        let theirs = Scope(
            visibleItems: scope.orderTakers[addressee] ?? [], pronounIt: scope.pronounIt)
        return parse(tokens: rest, rawInput: rawInput, scope: theirs)
            .map { parsed in
                var parsed = parsed
                parsed.actor = addressee
                return parsed
            }
            .mapError { $0.addressed(to: address) }
    }

    /// Whether the words after the comma are a greeting aimed at `addressee`.
    ///
    /// Re-parses rather than keeping a list of hello-words here, so a game that
    /// teaches `.greet` a new row gets `<actor>, <that word>` for free. Two
    /// tries: the remainder alone (a bare `hello` row, which the conversation
    /// plugin supplies), then the remainder with the name put back on the end,
    /// which is how core's `hello <object>` row sees it. Both must come out as
    /// GREET, which is what keeps `butler, take the lamp` from becoming
    /// anything at all.
    ///
    /// Recursion is bounded: each inner parse gets a strictly shorter list with
    /// the first comma already consumed.
    private func isGreeting(
        _ rest: [String], at addressee: EntityID, address: [String], scope: Scope
    ) -> Bool {
        if case .success(let inner) = parse(tokens: rest, rawInput: "", scope: scope),
            inner.intent == .greet, inner.directObject == nil
        {
            return true
        }
        if case .success(let inner) = parse(tokens: rest + address, rawInput: "", scope: scope),
            inner.intent == .greet, inner.directObject == addressee
        {
            return true
        }
        return false
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
        /// The far-sighted fallback set, empty for every ordinary intent.
        let distant = rule.intent.isFarSighted ? scope.distantActors : []

        var directPhrase: [String]?
        var indirectPhrase: [String]?
        /// Where each phrase begins in `tokens` — a clarifying answer is
        /// inserted there (`prefix + answer + suffix`).
        var directStart = 0
        var indirectStart = 0
        var direction: Direction?
        var preposition: String?
        var topicWords: [String]?
        /// The literal word most recently matched — "about" in `ask <object>
        /// about <topic>`. Used only to word the question an empty topic slot
        /// asks; deliberately not promoted to `preposition`, which would
        /// change what existing games see for `turn lamp on` and its like.
        var lastLiteral: String?
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
                                Array(tokens[cursor...]), in: scope,
                                alsoConsidering: distant)
                        {
                            return .nearMiss(
                                .missingIndirect(
                                    verb: verbPhrase,
                                    objectName: definiteName(of: id),
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
                    lastLiteral = word
                } else {
                    guard cursor < tokens.count, tokens[cursor] == word else {
                        return .mismatch
                    }
                    cursor += 1
                    lastLiteral = word
                }

            case .directObject, .indirectObject:
                if index == rule.elements.count - 1 {
                    // A slot ending the pattern takes everything left.
                    guard cursor < tokens.count else {
                        return missingSlotOutcome(
                            element, verbPhrase: verbPhrase, tokens: tokens,
                            directPhrase: directPhrase, preposition: preposition,
                            lastLiteral: lastLiteral, scope: scope, distant: distant)
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
                } else if rule.elements[index + 1] == .direction {
                    // `push <object> <direction>`. A direction slot takes one
                    // token and ends its pattern, so the noun phrase is
                    // everything up to the last token — no literal needed to
                    // split on. Validation guarantees this arrangement is the
                    // only one that reaches here. Issue #151.
                    guard tokens.count - cursor >= 2,
                        vocabulary.directions[tokens[tokens.count - 1]] != nil
                    else {
                        return missingHalfOfANounAndADirection(
                            verbPhrase: verbPhrase, tokens: tokens, cursor: cursor,
                            scope: scope, distant: distant)
                    }
                    directPhrase = Array(tokens[cursor..<(tokens.count - 1)])
                    directStart = cursor
                    // The direction token is deliberately left for the
                    // `.direction` case below: consuming it here would land on
                    // the empty-direction branch, which succeeds with nothing
                    // filled in.
                    cursor = tokens.count - 1
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

            case .topic:
                // Validation guarantees a topic slot ends its pattern, so it
                // takes every remaining token — and, unlike an object slot,
                // never looks them up. An abstract subject is not a thing in
                // the room, and refusing one the game hasn't heard of would
                // make every conversation a guessing game about vocabulary.
                guard cursor < tokens.count else {
                    return missingSlotOutcome(
                        element, verbPhrase: verbPhrase, tokens: tokens,
                        directPhrase: directPhrase, preposition: preposition,
                        lastLiteral: lastLiteral, scope: scope, distant: distant)
                }
                topicWords = Array(tokens[cursor...])
                cursor = tokens.count
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
                switch resolve(phrase, in: scope, alsoConsidering: distant) {
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
            switch resolve(phrase, in: scope, alsoConsidering: distant) {
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
                topic: topicWords,
                verbPhrase: verbPhrase,
                rawInput: rawInput))
    }

    /// What a `<verb> <object> <direction>` row does when the line does not end
    /// in a direction, so the two slots cannot both be filled. Which half the
    /// player left off decides the answer:
    ///
    /// - nothing left at all: the same "What do you want to push?" that core's
    ///   `push <object>` asks, so the shape displaces nothing.
    /// - one token, and it is a direction (`push north`): decline silently, so
    ///   a bare `["push", .direction]` row for the same verb still wins. That
    ///   is what lets the two shapes share an intent.
    /// - a phrase that names something here (`push the sandstone wall`): ask
    ///   which way, and the answer appends, because a direction slot ends its
    ///   pattern.
    /// - anything else: decline, and let the next rule or the scope error talk.
    private func missingHalfOfANounAndADirection(
        verbPhrase: String, tokens: [String], cursor: Int,
        scope: Scope, distant: Set<EntityID>
    ) -> FitOutcome {
        guard cursor < tokens.count else {
            // The answer `missingSlotOutcome` gives a final object slot; the
            // direction half cannot be asked for until there is a noun to name.
            return .nearMiss(.missingObject(verb: verbPhrase, prefix: tokens))
        }
        if tokens.count - cursor == 1, vocabulary.directions[tokens[cursor]] != nil {
            return .mismatch
        }
        guard
            case .success(let id) = resolve(
                Array(tokens[cursor...]), in: scope, alsoConsidering: distant)
        else {
            return .mismatch
        }
        return .nearMiss(
            .missingDirection(
                verb: verbPhrase, objectName: definiteName(of: id), prefix: tokens))
    }

    /// The near-miss for a pattern whose final object slot got no tokens:
    /// "take" asks for an object; "put cloak on" asks what to put it on.
    /// Either way the answer belongs after everything already typed.
    private func missingSlotOutcome(
        _ slot: SyntaxElement, verbPhrase: String, tokens: [String],
        directPhrase: [String]?, preposition: String?, lastLiteral: String?,
        scope: Scope, distant: Set<EntityID>
    ) -> FitOutcome {
        if slot == .directObject {
            return .nearMiss(.missingObject(verb: verbPhrase, prefix: tokens))
        }
        if slot == .topic {
            // A topic row need not have an object at all ("think about"). One
            // that has an object it can't resolve stays quiet and lets the
            // next rule — or the scope error — do the talking.
            var objectName: String?
            if let directPhrase {
                guard
                    case .success(let id) = resolve(
                        directPhrase, in: scope, alsoConsidering: distant)
                else {
                    return .mismatch
                }
                objectName = definiteName(of: id)
            }
            return .nearMiss(
                .missingTopic(
                    verb: verbPhrase,
                    objectName: objectName,
                    preposition: lastLiteral ?? "",
                    prefix: tokens))
        }
        if let directPhrase,
            case .success(let id) = resolve(directPhrase, in: scope, alsoConsidering: distant)
        {
            return .nearMiss(
                .missingIndirect(
                    verb: verbPhrase,
                    objectName: definiteName(of: id),
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

    /// Splits an input line into lowercased tokens, dropping noise words.
    /// ``Vocabulary/words(in:)`` does the splitting and documents the rule —
    /// it is the same call the bootstrap makes of every declared name,
    /// adjective and synonym, so what the author writes and what the player
    /// types are one word or two by the same rule.
    ///
    /// **The one exception is the comma**, which survives as a token of its
    /// own (`"delphine,hello"` yields three tokens). It is the only mark that
    /// changes what a sentence means — `butler, open the door` is addressed at
    /// somebody — so `parse` reads it and then strips it. Everywhere else it
    /// goes straight back to being noise. Splitting the line on commas first is
    /// what keeps it: inside a segment it is just another separator.
    func tokenize(_ input: String) -> [String] {
        var tokens: [String] = []
        for (index, segment)
            in input
            .split(separator: ",", omittingEmptySubsequences: false)
            .enumerated()
        {
            if index > 0 { tokens.append(",") }
            tokens += Vocabulary.words(in: String(segment))
                .filter { !vocabulary.noiseWords.contains($0) }
        }
        return tokens
    }

    /// Resolves a noun phrase against scope: every token must be one of the
    /// item's words, and the final token must be a noun.
    ///
    /// `distant` is the far-sighted fallback — the actors standing elsewhere,
    /// passed only for an intent in `Intent.farSightedIntents`. It is a second
    /// pass rather than a widened first pass on purpose: only a clean "nothing
    /// here answers to that" falls through to it, so an ambiguity in the room
    /// is still an ambiguity and no phrase that already resolves can change
    /// meaning.
    private func resolve(
        _ tokens: [String], in scope: Scope, alsoConsidering distant: Set<EntityID> = []
    ) -> Result<EntityID, ParseError> {
        // Pronouns resolve ahead of any item lexicon: "it" is whatever the
        // player last named — if it's still in sight, or still nameable.
        if tokens == ["it"] {
            guard let referent = scope.pronounIt else {
                return .failure(.noReferent("it"))
            }
            guard scope.visibleItems.contains(referent) || distant.contains(referent) else {
                return .failure(.notInScope)
            }
            return .success(referent)
        }

        let first = matches(tokens, among: scope.visibleItems)
        guard case .failure(.notInScope) = first, !distant.isEmpty else { return first }
        let second = matches(tokens, among: distant)
        // The far-sighted pass answers a *name*, never a description. A phrase
        // that picks out several people out of sight has named nobody, and
        // listing them would hand the player a cast they haven't met — `follow
        // man` in an empty hall must not enumerate everyone in the house.
        if case .failure(.ambiguous) = second { return .failure(.notInScope) }
        return second
    }

    /// The lexicon match itself, over one candidate set.
    private func matches(
        _ tokens: [String], among candidates: Set<EntityID>
    ) -> Result<EntityID, ParseError> {
        let matches = candidates.filter { id in
            vocabulary.itemLexicons[id]?.matches(tokens) == true
        }

        if matches.count > 1 {
            // Sorted by the bare name and articled after: an order the player
            // reads as alphabetical shouldn't file every common noun under
            // "the" and leave the people on their own.
            let names =
                matches
                .sorted { displayName(of: $0) < displayName(of: $1) }
                .map { definiteName(of: $0) }
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

    /// The entity's name behind its definite article, or bare if it is a
    /// proper name. The parser's counterpart to `TurnFrame.definiteName(of:)`.
    private func definiteName(of id: EntityID) -> String {
        GameText.definite(displayName(of: id), proper: vocabulary.properNames.contains(id))
    }
}
