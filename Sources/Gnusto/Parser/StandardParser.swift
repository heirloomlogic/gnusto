/// A parsed command in ID form; `GameWorld` converts it to the author-facing
/// `Command` by attaching canonical proxies.
struct ParsedCommand: Equatable {
    /// Several objects in the direct slot. The keywords are a *marker*: what
    /// "all" stands for needs world state, so expansion happens in `GameWorld`.
    /// A conjunction list is already resolved — the player named each thing, so
    /// there is nothing left to expand.
    enum MultiObject: Equatable {
        case all
        case them
        /// `take the bottle and the sack`, in the order the player wrote it.
        case list([EntityID])

        /// The keyword the phrase spells, if it spells one. Not an initializer,
        /// because it can't reach ``list(_:)`` — a list has no spelling to
        /// recognize, it is what the parser builds when a phrase splits on a
        /// conjunction — and every caller uses this as the question "is this
        /// phrase a keyword?" rather than as a way to make one.
        static func keyword(phrase: [String]) -> MultiObject? {
            switch phrase {
            case ["all"], ["everything"]: .all
            case ["them"]: .them
            default: nil
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
                    return .failure(.notTakingOrders(definiteNoun(of: addressee)))
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
        //
        // A row's verb-identifying run may end in a preposition — `look in`,
        // `get in`, `turn on`, `blow out` — and the player is owed its
        // synonyms, so the comparison is between canonical spellings. Both
        // sides are folded in advance rather than per comparison: the rows once
        // at bootstrap, the line once here, which keeps the filter itself the
        // single prefix test it has always been.
        let canonical = tokens.map(Vocabulary.canonical)
        let candidates = syntaxRules.filter { canonical.starts(with: $0.canonicalLeadingWords) }

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

        /// A slot's phrase and where it began, recorded together — a clarifying
        /// answer is spliced back in at that index.
        func record(_ phrase: [String], for slot: SyntaxElement, from start: Int) {
            if slot == .directObject {
                directPhrase = phrase
                directStart = start
            } else {
                indirectPhrase = phrase
                indirectStart = start
            }
        }

        /// What the row says when an object slot cannot be placed — either
        /// nothing is left for it, or the fixed-width suffix it measures itself
        /// against is not on the line. The arithmetic generalizes; what to
        /// *say* does not, so each shape keeps the answer it had.
        func shortOfTheSlot(
            _ slot: SyntaxElement, suffix: ArraySlice<SyntaxElement>
        ) -> FitOutcome {
            guard let next = suffix.first else {
                return missingSlotOutcome(
                    slot, verbPhrase: verbPhrase, tokens: tokens, directPhrase: directPhrase,
                    preposition: preposition, lastLiteral: lastLiteral, scope: scope,
                    distant: distant)
            }
            if next == .direction, suffix.count == 1 {
                return missingHalfOfANounAndADirection(
                    verbPhrase: verbPhrase, tokens: tokens, cursor: cursor, scope: scope,
                    distant: distant)
            }
            if case .word(let word) = next {
                return missingTheWordThatClosesTheSlot(
                    slot, word: word, verbPhrase: verbPhrase, tokens: tokens, cursor: cursor,
                    scope: scope, distant: distant)
            }
            return .mismatch
        }

        for (index, element) in rule.elements.enumerated().dropFirst(leadingWords.count) {
            switch element {
            case .word(let word):
                if let slot = openSlot {
                    // The literal closes the open object slot: the tokens up
                    // to its first occurrence are the slot's phrase.
                    guard
                        let split = firstOccurrence(of: word, in: tokens, from: cursor),
                        split > cursor
                    else {
                        return missingTheWordThatClosesTheSlot(
                            slot, word: word, verbPhrase: verbPhrase, tokens: tokens,
                            cursor: cursor, scope: scope, distant: distant)
                    }
                    record(Array(tokens[cursor..<split]), for: slot, from: cursor)
                    // The word sealing the direct object ahead of a second
                    // object is the command's preposition.
                    if slot == .directObject, rule.elements.contains(.indirectObject) {
                        preposition = word
                    }
                    cursor = split + 1
                    openSlot = nil
                    lastLiteral = word
                } else {
                    guard cursor < tokens.count,
                        Vocabulary.literal(word, matches: tokens[cursor])
                    else {
                        return .mismatch
                    }
                    cursor += 1
                    lastLiteral = word
                }

            case .directObject, .indirectObject:
                // Where the phrase ends is arithmetic whenever the rest of the
                // pattern has a fixed width: it stops that many tokens from the
                // end of the line. Width 0 is the slot that ends the pattern
                // and takes everything left; width 1 is the trailing direction
                // `push <object> <direction>` needs; a particle or a run of
                // them is any other number. Only a variable-width slot behind
                // this one leaves nothing to count back from, and then a
                // literal word has to close it. Issue #215.
                guard let suffixWidth = rule.fixedSuffixWidth(after: index) else {
                    // Mid-pattern: the next literal word closes it. (Bootstrap
                    // validation guarantees a literal follows.)
                    openSlot = element
                    continue
                }
                let suffix = rule.elements[(index + 1)...]
                let split = tokens.count - suffixWidth
                // Measuring against a suffix means checking the suffix is
                // really there. The cases below would make the same
                // comparisons walking on, but by then the split has happened
                // and the row can only decline — where a row that finds out
                // now still knows which half the player left off.
                guard split > cursor, fixedSuffix(suffix, standsAt: split, in: tokens) else {
                    return shortOfTheSlot(element, suffix: suffix)
                }
                record(Array(tokens[cursor..<split]), for: element, from: cursor)
                // The suffix is deliberately left to the cases below: consuming
                // a direction here would land on the empty-direction branch,
                // which succeeds with nothing filled in.
                cursor = split

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
        // keywords are flagged in the direct slot and refused in the indirect;
        // so is a conjunction list, which only the direct slot accepts.
        var directID: EntityID?
        var multiple: ParsedCommand.MultiObject?
        if let phrase = directPhrase {
            if let keyword = ParsedCommand.MultiObject.keyword(phrase: phrase) {
                multiple = keyword
            } else {
                switch resolveDirect(
                    phrase, at: directStart, in: tokens, scope: scope, distant: distant)
                {
                case .success(let ids) where ids.count == 1: directID = ids[0]
                case .success(let ids): multiple = .list(ids)
                case .failure(let error): return .nearMiss(error)
                }
            }
        }
        var indirectID: EntityID?
        if let phrase = indirectPhrase {
            guard ParsedCommand.MultiObject.keyword(phrase: phrase) == nil else {
                return .nearMiss(.multipleNotAllowed)
            }
            switch resolve(phrase, in: scope, alsoConsidering: distant) {
            case .success(let id): indirectID = id
            case .failure(let error):
                // `put the coin in the box and the sack` names two places for
                // one thing. Only the direct slot is several, and saying so
                // beats reporting the joined phrase as a thing nobody can see.
                // Second pass, the same way the direct slot's is: a name that
                // has "and" among its own words resolved above and never got
                // here.
                guard listSegments(of: phrase) == nil else {
                    return .nearMiss(.multipleNotAllowed)
                }
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

    /// Where the literal `word` stands on the line at or after `cursor` — the
    /// split that closes an open object slot.
    ///
    /// **Exact before synonym, and that ordering is the whole point.** Both
    /// halves of `put the inside pocket in the box` can close a slot the
    /// pattern spells `in`, and the phrase has to end at the `in` the player
    /// typed. One pass looking for either word would stop at `inside`, hand the
    /// slot nothing, and make the row decline a sentence it can place. Widening
    /// a literal is only safe while the row's own word still wins.
    ///
    /// - Parameters:
    ///   - word: the literal as the pattern spells it.
    ///   - tokens: the line as typed.
    ///   - cursor: where the open slot's phrase begins.
    /// - Returns: the index of the closing literal, or nil if the line has no
    ///   spelling of it left.
    private func firstOccurrence(of word: String, in tokens: [String], from cursor: Int) -> Int? {
        tokens[cursor...].firstIndex(of: word)
            ?? tokens[cursor...].firstIndex { Vocabulary.literal(word, matches: $0) }
    }

    /// Whether a fixed-width run of pattern elements is on the line at `start`
    /// — a literal where the literal goes, a direction word where the direction
    /// goes. The same comparisons the element cases make as the loop walks on,
    /// made early, so that an object slot measuring itself against a suffix
    /// knows the suffix is there before it splits.
    ///
    /// - Parameters:
    ///   - suffix: the elements behind an object slot. Every one of them has a
    ///     fixed ``SyntaxElement/tokenWidth``; a variable one answers false,
    ///     since nothing about it can be checked in advance.
    ///   - start: where the suffix would begin.
    ///   - tokens: the line as typed.
    /// - Returns: whether the line really says what the suffix requires.
    private func fixedSuffix(
        _ suffix: ArraySlice<SyntaxElement>, standsAt start: Int, in tokens: [String]
    ) -> Bool {
        for (offset, element) in suffix.enumerated() {
            let position = start + offset
            guard position < tokens.count else { return false }
            switch element {
            case .word(let word):
                guard Vocabulary.literal(word, matches: tokens[position]) else { return false }
            case .direction:
                guard vocabulary.directions[tokens[position]] != nil else { return false }
            case .directObject, .indirectObject, .topic:
                return false
            }
        }
        return true
    }

    /// What a row does when the literal word that marks the end of an object
    /// slot is not on the line — `hang cloak`, or `wind lamp` where the row is
    /// `wind <object> up`. If the phrase names something here, ask for the
    /// rest; the answer belongs after the word the player never typed.
    /// Anything else declines and lets the next rule talk.
    private func missingTheWordThatClosesTheSlot(
        _ slot: SyntaxElement, word: String, verbPhrase: String, tokens: [String],
        cursor: Int, scope: Scope, distant: Set<EntityID>
    ) -> FitOutcome {
        guard slot == .directObject, cursor < tokens.count,
            case .success(let id) = resolve(
                Array(tokens[cursor...]), in: scope, alsoConsidering: distant)
        else {
            return .mismatch
        }
        return .nearMiss(
            .missingIndirect(
                verb: verbPhrase,
                objectName: definiteName(of: id),
                preposition: word,
                prefix: tokens + [word]))
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
    ///   which way, and the answer appends, because the direction is the last
    ///   thing this pattern wants.
    /// - anything else: decline, and let the next rule or the scope error talk.
    ///
    /// Only reached where the direction genuinely ends the pattern. A row that
    /// puts something behind it has more missing than one question can name, so
    /// `fit`'s `shortOfTheSlot` declines that shape instead.
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

    /// Resolves the direct slot: one thing, or several joined by a conjunction.
    ///
    /// The split is a **second pass**, tried only once the whole phrase has
    /// failed to name anything. That ordering is the whole safety argument: an
    /// item declared `name("cup and saucer")` answers to its own words before
    /// the conjunction is ever read as punctuation, so adding the word to the
    /// parser cannot change the meaning of a phrase that already worked.
    ///
    /// - Parameters:
    ///   - phrase: the slot's tokens.
    ///   - start: where the phrase begins in `tokens` — a question about one
    ///     member of the list is answered in *that member's* place.
    ///   - tokens: the line as typed.
    ///   - scope: what the player can name.
    ///   - distant: the far-sighted fallback set.
    /// - Returns: the objects the player named, at least one, in the order they
    ///   named them; or the error to report.
    private func resolveDirect(
        _ phrase: [String], at start: Int, in tokens: [String],
        scope: Scope, distant: Set<EntityID>
    ) -> Result<[EntityID], ParseError> {
        let whole = resolve(phrase, in: scope, alsoConsidering: distant)
        guard case .failure(let wholeError) = whole else {
            return whole.map { [$0] }
        }
        // Nothing answers to the phrase entire — so it may be several phrases
        // joined by "and".
        guard let pieces = listSegments(of: phrase) else {
            return .failure(positioned(wholeError, tokens: tokens, phraseStart: start))
        }

        var ids: [EntityID] = []
        for piece in pieces {
            // `take the coin and all` asks for one thing and everything at
            // once. Only a whole phrase may be a keyword.
            guard ParsedCommand.MultiObject.keyword(phrase: Array(piece)) == nil else {
                return .failure(.multipleNotAllowed)
            }
            switch resolve(Array(piece), in: scope, alsoConsidering: distant) {
            case .success(let id):
                if !ids.contains(id) { ids.append(id) }
            case .failure(let error):
                // `piece.startIndex` is its offset within `phrase`, since
                // `phrase` is a zero-based array.
                return .failure(
                    positioned(error, tokens: tokens, phraseStart: start + piece.startIndex))
            }
        }
        // One id can come back from several pieces — one thing named twice, or
        // a trailing `and` with nothing behind it. The caller reads that as a
        // single object and takes the ordinary path.
        return .success(ids)
    }

    /// The phrase's conjunction-separated pieces, or `nil` when it is no kind
    /// of list: no conjunction in it, or nothing but conjunctions.
    ///
    /// The one definition of "does this phrase name several things", so the
    /// direct slot (which accepts a list) and the indirect slot (which refuses
    /// one) can never come to disagree about what a list is. Each piece keeps
    /// its place, as an `ArraySlice` over `phrase`: a clarifying question about
    /// one member has to be answerable in that member's own position.
    ///
    /// - Parameter phrase: the slot's tokens.
    /// - Returns: the pieces, at least one and never empty, or `nil`.
    private func listSegments(of phrase: [String]) -> [ArraySlice<String>]? {
        guard phrase.contains(where: Vocabulary.conjunctions.contains) else { return nil }
        let pieces = phrase.split(whereSeparator: Vocabulary.conjunctions.contains)
        return pieces.isEmpty ? nil : pieces
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

    /// The same phrase, carrying its number, for the one parser line whose verb
    /// has to agree with the person it names. The parser's counterpart to
    /// `TurnFrame.definiteNoun(of:)`.
    private func definiteNoun(of id: EntityID) -> GameText.Noun {
        GameText.Noun(definiteName(of: id), plural: vocabulary.plurals.contains(id))
    }
}
