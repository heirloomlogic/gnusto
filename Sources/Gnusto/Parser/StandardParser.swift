/// A parsed command in ID form; `GameWorld` converts it to the author-facing
/// `Command` by attaching canonical proxies.
struct ParsedCommand: Equatable {
    /// Several objects in the direct slot. The keywords are a *marker*: what
    /// "all" stands for needs world state, so expansion happens in `GameWorld`.
    /// A conjunction list is already resolved — the player named each thing, so
    /// there is nothing left to expand.
    enum MultiObject: Equatable {
        /// Everything eligible, minus what the player excepted:
        /// `take all but the sword`. The exclusion rides with the keyword
        /// because only a keyword can take one — it is the marker whose
        /// meaning isn't settled yet, so what it stands for *minus the sword*
        /// isn't settled either.
        case all(excluding: [EntityID])
        case them(excluding: [EntityID])
        /// `take the bottle and the sack`, in the order the player wrote it.
        /// Already resolved, so there is nothing left to except.
        case list([EntityID])

        /// The keyword the phrase spells, if it spells one, carrying whatever
        /// the player excepted from it. Not an initializer, because it can't
        /// reach ``list(_:)`` — a list has no spelling to recognize, it is
        /// what the parser builds when a phrase splits on a conjunction — and
        /// most callers use this as the question "is this phrase a keyword?"
        /// rather than as a way to make one.
        ///
        /// It is the *spelling* alone. `them` spells a keyword and does not
        /// always mean one — bound to a single plural thing it is a noun
        /// phrase — so no slot asks this directly; they all go through
        /// ``StandardParser/spellsKeyword(_:in:)``, which has the scope to
        /// tell the two apart. (#403)
        static func keyword(phrase: [String], excluding: [EntityID] = []) -> MultiObject? {
            switch phrase {
            // `all of them` is a row rather than a pre-pass that strips the
            // tail, so this stays the flat table it says it is. It is the one
            // place `of` is read at all: the word belongs to the tables and to
            // the games — `get out of the car`, an item called `cup of tea` —
            // so it is not line noise, and stripping it from the line would
            // have left `all them` behind, which spells no keyword either.
            // Issue #445.
            case ["all"], ["everything"], ["all", "of", "them"]: .all(excluding: excluding)
            case ["them"]: .them(excluding: excluding)
            default: nil
            }
        }

        /// What the player excepted from the group, if anything.
        var exclusions: [EntityID] {
            switch self {
            case .all(let excluded), .them(let excluded): excluded
            case .list: []
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
    /// Actors standing in some *other* room that the player may name: the ones
    /// they have met, and whoever is next door. Consulted only by a far-sighted
    /// intent (FOLLOW), and only after the visible set has failed, so a phrase
    /// that already names something here can never change meaning.
    let distantActors: Set<EntityID>
    /// Every actor standing in another room, in reach or not — the superset
    /// ``distantActors`` is drawn from.
    ///
    /// A phrase is judged against this and answered from that, so narrowing
    /// who can be followed never turns a description into a name: `follow man`
    /// in a house with three of them still picks out three, and so names
    /// nobody, even when only the one next door could have been the answer.
    /// (#332)
    let elsewhereActors: Set<EntityID>
    /// What "it" currently refers to, if anything.
    var pronounIt: EntityID?
    /// What "them" currently refers to: the group the last multi-object
    /// command expanded to, or the one plural thing the player last named.
    /// Both live in the same slot because the word does not distinguish
    /// them and the last one named wins either way.
    var pronounThem: [EntityID]
    /// What "him" currently refers to, if anything. `GameWorld.referent(of:in:)`
    /// settles which person that is, because only it can see the room.
    var pronounHim: EntityID?
    /// What "her" currently refers to, on the same terms as ``pronounHim``.
    var pronounHer: EntityID?
    /// The one thing "them" names, when it names one thing. `nil` for a real
    /// group and for a word bound to nothing — the two cases where "them"
    /// is not a noun phrase.
    var soleThem: EntityID? {
        pronounThem.count == 1 ? pronounThem[0] : nil
    }

    /// The same scope seen from somebody else's place: what *they* can name,
    /// and the pronouns as they stand, which are the player's words and travel
    /// with the line rather than with the person carrying it out.
    ///
    /// The order reading needs this twice, and a hand-copied `Scope` in two
    /// places is a pronoun that comes to be carried across one of them and not
    /// the other.
    ///
    /// - Parameter items: what the addressee can name from where it stands.
    /// - Returns: a scope over those items, with no actors and no order-takers,
    ///   so an order can never be an order to somebody else.
    func narrowed(to items: Set<EntityID>) -> Scope {
        Scope(
            visibleItems: items,
            pronounIt: pronounIt,
            pronounThem: pronounThem,
            pronounHim: pronounHim,
            pronounHer: pronounHer)
    }
    /// For each actor declared `takesOrders` the player could make hear them —
    /// here, met, or next door — what *that* actor could name from where it
    /// stands, keyed by the ones the player could make hear them. The parser has no world
    /// to walk, so `GameWorld` hands these down alongside the player's own set
    /// and the parser stays a pure function of its inputs. Item sets rather
    /// than whole scopes, so `Scope` doesn't become a type that contains
    /// itself: an order is never an order to somebody else, and the scope the
    /// order is read in is built at the one place that needs it.
    let orderTakers: [EntityID: Set<EntityID>]
    /// Every order-taker standing in a room, in reach or not. The same job
    /// ``elsewhereActors`` does, for the address slot.
    let allOrderTakers: Set<EntityID>

    init(
        visibleItems: Set<EntityID>,
        visibleActors: Set<EntityID> = [],
        distantActors: Set<EntityID> = [],
        elsewhereActors: Set<EntityID> = [],
        pronounIt: EntityID? = nil,
        pronounThem: [EntityID] = [],
        pronounHim: EntityID? = nil,
        pronounHer: EntityID? = nil,
        orderTakers: [EntityID: Set<EntityID>] = [:],
        allOrderTakers: Set<EntityID> = []
    ) {
        self.visibleItems = visibleItems
        self.visibleActors = visibleActors
        self.distantActors = distantActors
        self.elsewhereActors = elsewhereActors
        self.pronounIt = pronounIt
        self.pronounThem = pronounThem
        self.pronounHim = pronounHim
        self.pronounHer = pronounHer
        self.orderTakers = orderTakers
        self.allOrderTakers = allOrderTakers
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
            let rest = Array(tokens[(comma + 1)...])
            let addressed = resolveAddressee(address, in: scope)
            if case .success(let addressee) = addressed {
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
                case .success(let addressee) = resolveAddressee(
                    address, in: scope, alsoConsidering: Set(scope.orderTakers.keys)),
                let theirs = scope.orderTakers[addressee]
            {
                // Calling after somebody carries an order and not a hello: you
                // can shout "push the button" through a doorway, but greeting
                // a person you can't see is simply not seeing them.
                guard !rest.isEmpty,
                    !isGreeting(
                        rest, at: addressee, address: address,
                        scope: scope.narrowed(to: theirs))
                else {
                    return .failure(.notInScope)
                }
                return order(rest, to: addressee, address: address, scope: scope, rawInput: rawInput)
            }
            // `her, hello` addressed to a word bound to nobody, or bound to
            // somebody a room away. It is an address either way — the pronoun
            // can only ever have been one — so the reason it named nobody is
            // the answer, and falling through to the verb table instead
            // reports the grammar of a sentence the player did not write.
            // Free, like every parse failure. A *name* still falls through:
            // `cup, of tea` is not a form of address, and a phrase that names
            // nobody may yet name something.
            if isPronounAddress(address), case .failure(let error) = addressed {
                return .failure(error)
            }
        }
        // Not an address, or not to a person: every comma left on the line is
        // then the conjunction the player wrote instead of "and" — `take the
        // bottle, the sack and the lamp` (#276). Only one with words on both
        // sides of it separates anything, and the address reading was the last
        // thing a lone comma could have meant, so the rest go back to being
        // noise. `,,` is then an empty line, and has to be caught a second
        // time: everything below assumes a first token.
        let tokens = Array(tokens.split(separator: ",").joined(separator: [","]))
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

        // Try each candidate rule; remember the most specific near-miss, the
        // most specific row whose only unfilled slot was a direction, and the
        // rows that would fit if the player had typed their trailing particle.
        var bestFailure: ParseError?
        var emptyDirection: ParsedCommand?
        /// Rows whose trailing particle is missing, with the words to write in.
        /// Recorded rather than re-fitted here: that reading loses to any near
        /// miss, so on a line something near-misses the work would be thrown
        /// away — and `put the cloak` is exactly such a line.
        var implied: [(rule: SyntaxRule, particles: [String])] = []
        for rule in candidates {
            switch fit(rule, tokens: tokens, rawInput: rawInput, scope: scope) {
            case .command(let parsed):
                return .success(parsed)
            case .emptyDirection(let parsed):
                emptyDirection = emptyDirection ?? parsed
                continue
            case .mismatch:
                continue
            case .nearMiss(let error):
                bestFailure = bestFailure ?? error
                continue
            case .impliedSuffix(let particles):
                implied.append((rule, particles))
                continue
            }
        }

        // Ahead of the near-miss, behind every real match — see
        // ``FitOutcome/emptyDirection``.
        if let emptyDirection { return .success(emptyDirection) }
        // Behind the near-miss as well, and that is the ordering the shape
        // needs: `put the cloak` is owed "What do you want to put the velvet
        // cloak on?" from the row that has somewhere to put it, not a silent
        // WEAR from the row that reads the particle as understood.
        if let bestFailure { return .failure(bestFailure) }
        return impliedReading(implied, tokens: tokens, rawInput: rawInput, scope: scope)
    }

    /// The last reading tried: a row with the words the player left off written
    /// in — `pick the lamp` as `pick the lamp up`.
    ///
    /// Re-fitting is the whole of it, so every phrase is placed, resolved and
    /// positioned by the ordinary path: `pick the lantern` in a room with two
    /// of them still asks which, and the answer splices ahead of a particle
    /// that is by then on the line.
    ///
    /// - Parameters:
    ///   - implied: the rows that came up short of their particle, most
    ///     specific first, each with the words to write in.
    ///   - tokens: the line as typed.
    ///   - rawInput: the line as the player typed it.
    ///   - scope: what the player can see.
    /// - Returns: the first row that fits with its particle written in, or the
    ///   first reason one had for declining — which beats `unmatchedSyntax`,
    ///   because `pick the gramophone` is about the gramophone.
    private func impliedReading(
        _ implied: [(rule: SyntaxRule, particles: [String])],
        tokens: [String], rawInput: String, scope: Scope
    ) -> Result<ParsedCommand, ParseError> {
        var failure: ParseError?
        for (rule, particles) in implied {
            switch fit(rule, tokens: tokens + particles, rawInput: rawInput, scope: scope) {
            case .command(let parsed):
                return .success(parsed)
            case .nearMiss(let error):
                failure = failure ?? error
            case .emptyDirection, .impliedSuffix, .mismatch:
                continue
            }
        }
        return .failure(failure ?? .unmatchedSyntax)
    }

    /// The words after the comma, read as a command in the addressee's own
    /// scope and stamped with them as its agent.
    ///
    /// The words keep any comma among them, so `robot, take the wrench, the
    /// lever` reads its list exactly as `… wrench and the lever` does.
    ///
    /// Recursion is bounded the same way ``isGreeting(_:at:address:scope:)``'s
    /// is: a strictly shorter token list every time, and an inner scope with no
    /// visible actors and no order-takers — so the address reading can never
    /// succeed a second time, and an order can never be an order to somebody
    /// else.
    ///
    /// A failure is re-anchored on the address, so that the question an
    /// incomplete order asks ("What do you want to push?") is answered as an
    /// order too, and not as the player's own next move.
    private func order(
        _ rest: [String], to addressee: EntityID, address: [String],
        scope: Scope, rawInput: String
    ) -> Result<ParsedCommand, ParseError> {
        let theirs = scope.narrowed(to: scope.orderTakers[addressee] ?? [])
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
    /// Recursion is bounded: each inner parse gets a strictly shorter list, in
    /// a scope with nobody in it to address.
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
        /// A match whose direction slot the player left empty — bare `go`, and
        /// the branch that lets it ask "Which way?". It is a match, but the
        /// weakest kind: it yields to any row that actually matched, so one
        /// verb word can be a walk with a direction on it and something else
        /// without. CLIMB is the word that needs that — `climb up` is a walk
        /// and bare `climb` is the stub verb a game has voiced for itself.
        case emptyDirection(ParsedCommand)
        /// A row whose object phrase is on the line but whose **trailing
        /// particle** is not: `pick the lamp` against `pick <object> up`. The
        /// payload is the words the player left off, and ``parse`` re-fits the
        /// row with them written in.
        ///
        /// Only ever a run of literal words. The branch that raises it is the
        /// one where everything behind the object slot has a fixed width, and
        /// a second object slot has no width — so a row that reaches here can
        /// never have one, and the question the shape used to ask ("What do you
        /// want to pick the oil lamp up?") named a slot that was not in the
        /// pattern and could not be filled by any answer.
        ///
        /// Weaker than every other outcome, near misses included: the row is
        /// reading a word the player did not type, so anything that read what
        /// they *did* type wins.
        case impliedSuffix([String])
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
        let verbPhrase = rule.leadingPhrase
        // What a *question* about this row calls the verb. Separate from
        // `verbPhrase`, which is the row as the player typed it and rides on
        // the command for rules to read — `DefaultActions` tells FIND from
        // SEARCH by it, and two games word a refusal off it.
        let displayVerb = rule.displayVerb
        var cursor = leadingWords.count

        // The one shape the loop below cannot place, handled whole ahead of it
        // — and ahead of `distant`, which it has no use for.
        if rule.isRecipientFirst {
            return fitRecipientFirst(
                rule, tokens: tokens, from: cursor, verbPhrase: verbPhrase, rawInput: rawInput,
                scope: scope)
        }

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
                    slot, displayVerb: displayVerb, tokens: tokens, directPhrase: directPhrase,
                    preposition: preposition, lastLiteral: lastLiteral, scope: scope,
                    distant: distant)
            }
            if next == .direction, suffix.count == 1 {
                return missingHalfOfANounAndADirection(
                    displayVerb: displayVerb, tokens: tokens, cursor: cursor, scope: scope,
                    distant: distant)
            }
            if case .word(let word) = next {
                // A suffix measured by width is literal words and directions
                // and nothing else, so where the player has typed the noun and
                // left off the rest, one of two things is missing. A direction
                // still behind the word is a slot they can fill, and the row
                // asks for it in the words it always did — `turn the dial to`
                // wants a bearing. Words alone are a **particle**, and there is
                // nothing to ask: the sentence is complete except for a word
                // the pattern was always going to supply, so the row reads it
                // as understood rather than asking a question whose answer has
                // nowhere to go. Issue #445.
                guard suffix.contains(.direction) else {
                    guard cursor < tokens.count else { return .mismatch }
                    return .impliedSuffix(
                        suffix.compactMap {
                            if case .word(let particle) = $0 { particle } else { nil }
                        })
                }
                return missingTheWordThatClosesTheSlot(
                    slot, word: word, displayVerb: displayVerb, tokens: tokens, cursor: cursor,
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
                            slot, word: word, displayVerb: displayVerb, tokens: tokens,
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
                    return .emptyDirection(
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
                        element, displayVerb: displayVerb, tokens: tokens,
                        directPhrase: directPhrase, preposition: preposition,
                        lastLiteral: lastLiteral, scope: scope, distant: distant)
                }
                // The comma joins object phrases, but a topic is words and
                // never a list, so here it goes back to being punctuation.
                // That is what keeps `ask the butler about the war, and the
                // king` matching a keyword the author declared with the same
                // comma in it: `Topic.normalize` reads it through the splitter
                // that drops one outright.
                topicWords = tokens[cursor...].filter { $0 != "," }
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
            if let split = keywordSplit(of: phrase, in: scope) {
                // `all`, or `all but the sword`. Only the exclusion resolves
                // here; what the keyword stands for needs world state.
                switch excludedObjects(
                    split.exclusion, at: directStart, in: tokens, scope: scope, distant: distant)
                {
                case .success(let ids):
                    multiple = .keyword(phrase: split.group, excluding: ids)
                case .failure(let error):
                    return .nearMiss(error)
                }
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
            // `put the coin in all`, and `put the coin in all but the sack`
            // with it: a keyword names a group either way, and only the direct
            // slot is several.
            guard keywordSplit(of: phrase, in: scope) == nil else {
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
                guard listSegments(of: phrase[...]) == nil else {
                    return .nearMiss(.multipleNotAllowed)
                }
                return .nearMiss(
                    positioned(error, tokens: tokens, phrase: phrase, at: indirectStart))
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

    /// Places the two touching noun phrases of a recipient-first row.
    ///
    /// The cut is found rather than measured: every split of the remaining
    /// tokens is tried left to right, and the first one whose *both* halves
    /// resolve in scope wins. Leftmost rather than longest because the
    /// recipient is a person the player is looking at and names in a word or
    /// two, where the gift is the phrase that carries the adjectives — and
    /// because a resolver that has to succeed twice is a far tighter filter
    /// than any rule about phrase length.
    ///
    /// A split nothing satisfies reports the *first* reason a split had for
    /// declining, as a near miss. It used to be a ``FitOutcome/mismatch``, on
    /// the grounds that the `give <object> to <second object>` row is more
    /// specific and owns the question an incomplete GIVE asks — which it still
    /// does, because `parse` keeps the first near miss and that row is tried
    /// first. What the mismatch cost was the case where the TO row never fires
    /// at all: `give troll leaflet` with no troll in the room has no `to` on
    /// the line, so nothing else was left to talk, and a plain scope failure
    /// came out as "That sentence isn't one I recognize." It says what `give
    /// leaflet to troll` says.
    ///
    /// The gift half goes through ``resolveDirect(_:at:in:scope:distant:)``,
    /// the same resolver the ordinary direct slot uses, so `give the troll the
    /// sword and the coin` answers in the words `give the sword and the coin to
    /// the troll` does rather than falling out as a sentence nobody recognizes.
    /// It reads a multi-object keyword there too, and for the same reason:
    /// `give the troll all` is the direct slot's `all`, and a row that only
    /// asked the resolver would have made it the one spelling of GIVE the
    /// keyword did not reach. The recipient half does neither: one person is
    /// being handed one armful, and a list — or an `all` — there names two
    /// places for it.
    ///
    /// - Parameters:
    ///   - rule: the recipient-first row.
    ///   - tokens: the line as typed.
    ///   - cursor: the first token after the row's leading words.
    ///   - verbPhrase: those leading words, for the command it builds.
    ///   - rawInput: the line as the player typed it.
    ///   - scope: what the player can see.
    /// - Returns: the command, the first split's reason for declining, or
    ///   `.mismatch` where there was no split to try.
    private func fitRecipientFirst(
        _ rule: SyntaxRule, tokens: [String], from cursor: Int, verbPhrase: String,
        rawInput: String, scope: Scope
    ) -> FitOutcome {
        guard tokens.count - cursor >= 2 else { return .mismatch }

        /// One gift half placed, whichever door it came through.
        func placed(
            _ recipient: EntityID, _ multiple: ParsedCommand.MultiObject?, _ gift: EntityID?
        )
            -> FitOutcome
        {
            .command(
                ParsedCommand(
                    intent: rule.intent,
                    directObject: gift,
                    indirectObject: recipient,
                    multiple: multiple,
                    verbPhrase: verbPhrase,
                    rawInput: rawInput))
        }

        var firstFailure: ParseError?
        for split in (cursor + 1)..<tokens.count {
            let recipient: EntityID
            switch resolve(Array(tokens[cursor..<split]), in: scope) {
            case .success(let id): recipient = id
            case .failure(let error):
                firstFailure =
                    firstFailure
                    ?? positioned(
                        error, tokens: tokens, phrase: Array(tokens[cursor..<split]), at: cursor)
                continue
            }
            let phrase = Array(tokens[split...])
            if let keyword = keywordSplit(of: phrase, in: scope) {
                switch excludedObjects(
                    keyword.exclusion, at: split, in: tokens, scope: scope, distant: [])
                {
                case .success(let excluded):
                    return placed(recipient, .keyword(phrase: keyword.group, excluding: excluded), nil)
                case .failure(let error):
                    firstFailure = firstFailure ?? error
                    continue
                }
            }
            switch resolveDirect(phrase, at: split, in: tokens, scope: scope, distant: []) {
            case .success(let gifts) where gifts.count == 1:
                return placed(recipient, nil, gifts[0])
            case .success(let gifts):
                return placed(recipient, .list(gifts), nil)
            case .failure(let error):
                firstFailure = firstFailure ?? error
                continue
            }
        }
        guard let firstFailure else { return .mismatch }
        return .nearMiss(firstFailure)
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
        _ slot: SyntaxElement, word: String, displayVerb: String, tokens: [String],
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
                verb: displayVerb,
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
        displayVerb: String, tokens: [String], cursor: Int,
        scope: Scope, distant: Set<EntityID>
    ) -> FitOutcome {
        guard cursor < tokens.count else {
            // The answer `missingSlotOutcome` gives a final object slot; the
            // direction half cannot be asked for until there is a noun to name.
            return .nearMiss(.missingObject(verb: displayVerb, prefix: tokens))
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
                verb: displayVerb, objectName: definiteName(of: id), prefix: tokens))
    }

    /// The near-miss for a pattern whose final object slot got no tokens:
    /// "take" asks for an object; "put cloak on" asks what to put it on.
    /// Either way the answer belongs after everything already typed.
    private func missingSlotOutcome(
        _ slot: SyntaxElement, displayVerb: String, tokens: [String],
        directPhrase: [String]?, preposition: String?, lastLiteral: String?,
        scope: Scope, distant: Set<EntityID>
    ) -> FitOutcome {
        if slot == .directObject {
            return .nearMiss(.missingObject(verb: displayVerb, prefix: tokens))
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
                    verb: displayVerb,
                    objectName: objectName,
                    preposition: lastLiteral ?? "",
                    prefix: tokens))
        }
        if let directPhrase,
            case .success(let id) = resolve(directPhrase, in: scope, alsoConsidering: distant)
        {
            return .nearMiss(
                .missingIndirect(
                    verb: displayVerb,
                    objectName: definiteName(of: id),
                    preposition: preposition ?? "",
                    prefix: tokens))
        }
        return .mismatch
    }

    /// Fills an `ambiguous` error's answer-insertion context: the reply's
    /// adjectives belong just ahead of the phrase that was ambiguous.
    ///
    /// Ahead of the *noun*, that is, and a possessive the resolver dropped is
    /// no longer part of it — so the insertion point skips exactly the words
    /// ``possessivePrefix(of:)`` says were dropped. The phrase is passed rather
    /// than sliced out of `tokens`, because that check reads the whole phrase
    /// and a slot's phrase can end short of the line's last word.
    ///
    /// - Parameters:
    ///   - error: the resolver's answer, positioned only when it is ambiguous.
    ///   - tokens: the line as typed.
    ///   - phrase: the slot's tokens, the ones that named nothing on their own.
    ///   - phraseStart: where the phrase begins in `tokens`.
    /// - Returns: the error, with the answer's place in the sentence filled in.
    private func positioned(
        _ error: ParseError, tokens: [String], phrase: [String], at phraseStart: Int
    ) -> ParseError {
        guard case .ambiguous(let names, _, _) = error else { return error }
        // A phrase with no noun in it — `x velvet` over two velvet things — is
        // answered with the noun, and a noun belongs *behind* the adjectives
        // that qualify it. Spliced in front, the way an adjective answer is,
        // it would re-parse as `x cloak velvet`. Asked of the whole lexicon
        // rather than of the candidates, because that is the same question the
        // second pass in `matches(_:among:)` asked to raise this: no item
        // anywhere is called by this word. Issue #445.
        let insertion =
            namesNothing(phrase)
            ? phraseStart + phrase.count
            : phraseStart + possessivePrefix(of: phrase)
        return .ambiguous(
            names: names,
            prefix: Array(tokens[..<insertion]),
            suffix: Array(tokens[insertion...]))
    }

    /// Whether the phrase ends in a word no item in the game answers to as a
    /// noun — the mark of a phrase that describes rather than names.
    ///
    /// Asked of the whole lexicon rather than of the candidates that were
    /// ambiguous, and the asymmetry is deliberate: a *true* answer proves the
    /// description pass raised this question, because a name match would have
    /// required the last word to be somebody's noun. A false one may be either,
    /// and takes the splice every ambiguity took before there was a description
    /// pass at all — so the rule can only ever move a question that would
    /// otherwise be unanswerable.
    private func namesNothing(_ phrase: [String]) -> Bool {
        guard let last = phrase.last else { return false }
        return !vocabulary.itemNouns.contains(last)
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
    /// changes what a sentence means, and it means two things: the first one on
    /// the line may address somebody (`butler, open the door`), and every comma
    /// ``parse(tokens:rawInput:scope:)`` does not spend that way separates
    /// object phrases (`take the bottle, the sack and the lamp`). Splitting the
    /// line on commas is what keeps it: inside a segment it is just another
    /// separator.
    ///
    /// Every comma is kept here, including one standing beside nothing —
    /// `usher,` is a bare greeting, and only the address reading knows that.
    /// The rest are dropped in ``parse(tokens:rawInput:scope:)``, once that
    /// reading has had its turn.
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

    /// Resolves the direct slot: one thing, or several the player listed.
    ///
    /// **The comma separates more strongly than the conjunction does**, which
    /// is how English reads `bread and butter, jam, and tea` — so the phrase is
    /// cut at its commas first and each group is then offered to
    /// ``resolveGroup(_:at:in:scope:distant:)`` as a name in its own right.
    /// One group is the whole phrase, which is every line that has no comma in
    /// it, so nothing without one changed.
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
        let groups = phrase.split(separator: ",")
        guard !groups.isEmpty else {
            // Nothing but separators names nothing. Hand the phrase over
            // whole and let the ordinary answer say so.
            return resolveGroup(
                phrase[...], at: start, in: tokens, scope: scope, distant: distant)
        }

        var ids: [EntityID] = []
        for group in groups {
            switch resolveGroup(group, at: start, in: tokens, scope: scope, distant: distant) {
            case .success(let found):
                // One id can come back from several groups or pieces — one
                // thing named twice, or a trailing separator with nothing
                // behind it. The caller reads a single id as one object and
                // takes the ordinary path.
                for id in found where !ids.contains(id) { ids.append(id) }
            case .failure(let error):
                return .failure(error)
            }
        }
        return .success(ids)
    }

    /// Resolves one comma-separated group: one thing, or several joined by a
    /// conjunction.
    ///
    /// The conjunction split is a **second pass**, tried only once the group
    /// has failed to name anything entire. That ordering is the whole safety
    /// argument: an item declared `name("cup and saucer")` answers to its own
    /// words before the conjunction is ever read as punctuation, so adding the
    /// word to the parser cannot change the meaning of a phrase that already
    /// worked — and `take cup and saucer, the coin` keeps that name while
    /// standing in a list, because the group is offered whole first.
    ///
    /// - Parameters:
    ///   - group: the group's tokens, as a slice keeping its place in the
    ///     slot's phrase.
    ///   - start: where the phrase begins in `tokens`.
    ///   - tokens: the line as typed.
    ///   - scope: what the player can name.
    ///   - distant: the far-sighted fallback set.
    /// - Returns: the objects this group named, at least one, or the error.
    private func resolveGroup(
        _ group: ArraySlice<String>, at start: Int, in tokens: [String],
        scope: Scope, distant: Set<EntityID>
    ) -> Result<[EntityID], ParseError> {
        // `take the coin, all` asks for one thing and everything at once. Only
        // a whole phrase may be a keyword, and `fit` has already read that one.
        guard !spellsKeyword(Array(group), in: scope) else {
            return .failure(.multipleNotAllowed)
        }
        let whole = resolve(Array(group), in: scope, alsoConsidering: distant)
        guard case .failure(let wholeError) = whole else {
            return whole.map { [$0] }
        }
        // Nothing answers to the group entire — so it may be several phrases
        // joined by "and".
        guard let pieces = listSegments(of: group) else {
            return .failure(
                positioned(
                    wholeError, tokens: tokens, phrase: Array(group),
                    at: start + group.startIndex))
        }

        var ids: [EntityID] = []
        for piece in pieces {
            guard !spellsKeyword(Array(piece), in: scope) else {
                return .failure(.multipleNotAllowed)
            }
            switch resolve(Array(piece), in: scope, alsoConsidering: distant) {
            case .success(let id):
                ids.append(id)
            case .failure(let error):
                // A resolved list member followed by a fresh command is not a
                // second noun: `take cloak and go east` is one malformed
                // sentence, rather than a thing the player cannot see.
                if !ids.isEmpty,
                    case .notInScope = error,
                    let first = piece.first,
                    isSyntaxWord(first),
                    !isKnownNounPhrase(Array(piece))
                {
                    return .failure(.unmatchedSyntax)
                }
                // `piece.startIndex` is its offset within the slot's phrase,
                // since every slice here indexes the same zero-based array.
                return .failure(
                    positioned(
                        error, tokens: tokens, phrase: Array(piece),
                        at: start + piece.startIndex))
            }
        }
        return .success(ids)
    }

    /// The phrase's separated pieces, or `nil` when it is no kind of list: no
    /// separator in it, or nothing but separators.
    ///
    /// The one definition of "does this phrase name several things", so the
    /// direct slot (which accepts a list) and the indirect slot (which refuses
    /// one) can never come to disagree about what a list is. Each piece keeps
    /// its place, as a slice over the slot's phrase: a clarifying question
    /// about one member has to be answerable in that member's own position.
    ///
    /// Splitting drops empty pieces, which is what makes the Oxford comma of
    /// `take the coin, the feather, and the idol` one separator and not two.
    ///
    /// - Parameter phrase: the slot's tokens, or a comma-separated group of
    ///   them.
    /// - Returns: the pieces, at least one and never empty, or `nil`.
    private func listSegments(of phrase: ArraySlice<String>) -> [ArraySlice<String>]? {
        guard phrase.contains(where: Self.separators.contains) else { return nil }
        let pieces = phrase.split(whereSeparator: Self.separators.contains)
        return pieces.isEmpty ? nil : pieces
    }

    /// What stands between two object phrases rather than inside one: the
    /// conjunctions, and the comma the player wrote in place of one.
    private static let separators = Vocabulary.conjunctions.union([","])

    /// Whether the phrase spells a multi-object keyword *as things stand*.
    ///
    /// `all` and `everything` always do: what they stand for needs world
    /// state, which is the definition of a marker. `them` does only while it
    /// names a group of two or more. A "them" standing for one plural thing —
    /// the stairs, the gloves — is a noun phrase and wants
    /// ``resolve(_:in:alsoConsidering:)``, which is what lets `x them` answer
    /// for a verb that takes no group at all; a "them" standing for nothing is
    /// an unbound pronoun, and gets the same "I don't know what that refers
    /// to" that an unbound `it` gets, from every verb rather than only from
    /// the four that expand groups. (#403)
    ///
    /// - Parameters:
    ///   - phrase: a whole slot phrase, or one comma-separated piece of one.
    ///   - scope: what the player can name this turn, pronouns included.
    /// - Returns: whether the group machinery should claim this phrase.
    private func spellsKeyword(_ phrase: [String], in scope: Scope) -> Bool {
        guard ParsedCommand.MultiObject.keyword(phrase: phrase) != nil else { return false }
        return phrase != ["them"] || scope.pronounThem.count > 1
    }

    /// The multi-object keyword a phrase spells and the exclusion trimming it:
    /// `all but the sword` is the keyword `all` and the phrase `sword`, and a
    /// bare `all` is the keyword and nothing.
    ///
    /// The exclusion is claimed **only behind a keyword**, which is what makes
    /// the word safe to read as punctuation — and does it structurally, where
    /// the conjunction needs a second pass. A keyword is a reserved word no
    /// item can answer to (``Vocabulary/exclusions`` argues this out), so
    /// `take last but one ticket` spells no keyword, never reaches the split,
    /// and resolves as the one object it names.
    ///
    /// - Parameters:
    ///   - phrase: the slot's tokens.
    ///   - scope: what the player can name this turn, which is what decides
    ///     whether a bare `them` is a keyword or a noun.
    /// - Returns: the keyword's own words and the exclusion phrase — an
    ///   `ArraySlice`, so it keeps its place in the line and a question about
    ///   it is answered there — or nil when the phrase spells no keyword.
    private func keywordSplit(
        of phrase: [String], in scope: Scope
    ) -> (group: [String], exclusion: ArraySlice<String>)? {
        if spellsKeyword(phrase, in: scope) {
            return (phrase, [])
        }
        // Behind an exclusion the bare spelling is enough, and deliberately:
        // `take them but the sword` is the player saying they meant a group,
        // whatever the word happens to stand for this turn.
        guard let mark = phrase.firstIndex(where: Vocabulary.exclusions.contains),
            ParsedCommand.MultiObject.keyword(phrase: Array(phrase[..<mark])) != nil
        else { return nil }
        return (Array(phrase[..<mark]), phrase[(mark + 1)...])
    }

    /// What an exclusion phrase names.
    ///
    /// Resolved through ``resolveDirect(_:at:in:scope:distant:)``, so
    /// `take all except the sword and the lamp` excepts two things without a
    /// second splitter existing to disagree with the first one — and
    /// `take all except the sword, the lamp` excepts two for the same reason,
    /// the comma being that one splitter's business as much as the
    /// conjunction is.
    ///
    /// - Returns: the objects excepted, possibly none — a trailing `but` with
    ///   nothing behind it is forgiven exactly as a trailing `and` is.
    private func excludedObjects(
        _ phrase: ArraySlice<String>, at start: Int, in tokens: [String],
        scope: Scope, distant: Set<EntityID>
    ) -> Result<[EntityID], ParseError> {
        guard !phrase.isEmpty else { return .success([]) }
        let words = Array(phrase)
        // `take all but everything` asks for the group and then for the group.
        guard !spellsKeyword(words, in: scope) else {
            return .failure(.multipleNotAllowed)
        }
        return resolveDirect(
            words, at: start + phrase.startIndex, in: tokens, scope: scope, distant: distant)
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
    /// Internal rather than private because the play-test seam asks exactly
    /// this question and must not answer it twice: ``GameWorld/resolve(_:)``
    /// reports *which entity answers to this noun from where the player is
    /// standing*, and a copy of this body beside it would agree on the day it
    /// was written and drift afterwards — silently, since that tool's whole
    /// job is to agree with the parser. It is this reach and not
    /// ``matches(_:among:)`` because the pronoun branch below is part of the
    /// answer: `it` is a reserved word the vocabulary knows and no lexicon
    /// holds, so a seam one level down reports that nothing answers to it.
    func resolve(
        _ tokens: [String], in scope: Scope, alsoConsidering distant: Set<EntityID> = []
    ) -> Result<EntityID, ParseError> {
        let resolved = resolveNoun(tokens, in: scope, alsoConsidering: distant)
        guard case .failure(.notInScope) = resolved,
            hasSyntaxTail(afterNounIn: tokens, scope: scope, distant: distant)
        else {
            return resolved
        }
        return .failure(.unmatchedSyntax)
    }

    /// Resolves only the noun, without interpreting any trailing sentence
    /// structure. Prefix checks use this layer so diagnosis never recurses.
    private func resolveNoun(
        _ tokens: [String], in scope: Scope, alsoConsidering distant: Set<EntityID>
    ) -> Result<EntityID, ParseError> {
        // Pronouns resolve ahead of any item lexicon, and each takes the same
        // two questions: is the word bound, and is what it names still
        // nameable. "it" is whatever the player last named; "him" and "her"
        // are whoever of that gender they last named, or the one person in
        // view who answers to the word, settled in `GameWorld`. "them" reaches
        // here only when it names one thing — a plural item, or a group come
        // down to one — because `spellsKeyword(_:in:)` keeps a real group away
        // from this branch, and every slot asks that question first. (#403)
        func pronoun(_ word: String, _ referent: EntityID?) -> Result<EntityID, ParseError> {
            guard let referent else { return .failure(.noReferent(word)) }
            guard scope.visibleItems.contains(referent) || distant.contains(referent) else {
                return .failure(.notInScope)
            }
            return .success(referent)
        }
        if tokens == ["it"] { return pronoun("it", scope.pronounIt) }
        if tokens == ["them"] { return pronoun("them", scope.soleThem) }
        if tokens == ["him"] { return pronoun("him", scope.pronounHim) }
        if tokens == ["her"] { return pronoun("her", scope.pronounHer) }
        // A possessive belongs to the phrase behind it: `x her leg` is whatever
        // answers to `leg` — which, on a person whose own description names it,
        // is that person — and `take her lamp` is the lamp. See
        // ``Vocabulary/possessives`` for why the word is dropped here rather
        // than stripped as noise. A phrase that names something on its own is
        // left alone, so a game may still call a thing `his lordship`.
        let dropped = possessivePrefix(of: tokens)
        if dropped > 0 {
            return resolveNoun(
                Array(tokens.dropFirst(dropped)), in: scope, alsoConsidering: distant)
        }

        let first = matches(tokens, among: scope.visibleItems)
        guard case .failure(.notInScope) = first, !distant.isEmpty else { return first }
        return outOfSight(tokens, among: scope.elsewhereActors, answerableIn: distant)
    }

    /// Whether a phrase starts by naming something and then continues as
    /// sentence structure: `cloak with key`, `cloak open door`, or `cloak e`.
    /// A complete name anywhere in the game's lexicon wins first, even when it
    /// is out of scope, so a name such as `cup of tea` keeps the scope error.
    private func hasSyntaxTail(
        afterNounIn tokens: [String], scope: Scope, distant: Set<EntityID>
    ) -> Bool {
        // A complete noun name wins even when its first word also belongs to
        // grammar, and even when that noun is presently out of scope.
        guard !isKnownNounPhrase(tokens) else { return false }
        guard let first = tokens.first else { return false }
        if tokens.count == 1 { return isSyntaxWord(first) }

        for split in tokens.indices.dropFirst() where isSyntaxWord(tokens[split]) {
            if case .success = resolveNoun(
                Array(tokens[..<split]), in: scope, alsoConsidering: distant)
            {
                return true
            }
        }
        return false
    }

    /// Whether the complete phrase names any item in the game's lexicon,
    /// regardless of whether the item is currently in scope.
    private func isKnownNounPhrase(_ tokens: [String]) -> Bool {
        vocabulary.itemLexicons.values.contains { $0.matches(tokens) }
    }

    /// How many leading words ``resolveNoun(_:in:alsoConsidering:)`` drops as
    /// possessives before the phrase names anything.
    ///
    /// The one place that question is answered, because two callers ask it and
    /// they must not come to disagree: the resolver drops the words, and
    /// ``positioned(_:tokens:phrase:at:)`` skips the same ones so a clarifying
    /// question raised behind a possessive is answerable. `x her door` over two
    /// doors asks which, and the answer belongs in front of `door` — spliced in
    /// front of `her` it reads `x wooden her door`, which is no sentence at all.
    ///
    /// - Parameter phrase: a slot's tokens.
    /// - Returns: how many of its leading words are dropped, possibly none.
    private func possessivePrefix(of phrase: [String]) -> Int {
        var rest = phrase[...]
        while rest.count > 1, Vocabulary.possessives.contains(rest[rest.startIndex]),
            !isKnownNounPhrase(Array(rest))
        {
            rest = rest.dropFirst()
        }
        return phrase.count - rest.count
    }

    /// A word that belongs to sentence grammar rather than a noun phrase.
    private func isSyntaxWord(_ word: String) -> Bool {
        vocabulary.prepositions.contains(word)
            || vocabulary.verbWords.contains(word)
            || vocabulary.directions[word] != nil
    }

    /// Whether the words before the comma are the bare gendered pronoun —
    /// the one address that cannot be anything else, and so the one whose
    /// failure ``parse(tokens:rawInput:scope:)`` may report as its own.
    private func isPronounAddress(_ tokens: [String]) -> Bool {
        tokens.count == 1 && (tokens[0] == "him" || tokens[0] == "her")
    }

    /// Resolves the words to the left of a comma — which can only ever name a
    /// person, and so are matched against people alone.
    ///
    /// It is a separate entry rather than `resolve` with a filter after it.
    /// Resolving the address against every visible *item* and only then asking
    /// whether the winner is an actor meant a scenery noun that happened to
    /// share somebody's name won the match, failed the test, and took the whole
    /// addressing reading down with it — silently, and with the second pass
    /// shadowed too. Matching people from the start costs nothing and cannot
    /// shadow anybody. (#332)
    ///
    /// The `it` pronoun branch is deliberately absent: "it, take the sword" is
    /// not a sentence, and `pronounIt` names a thing far more often than a
    /// person. `him` and `her` are the opposite case and are read here — they
    /// name a person by construction, so `her, take the lamp` is a sentence —
    /// and they are judged against the people in view, exactly as a name is.
    ///
    /// - Parameters:
    ///   - tokens: the words before the comma.
    ///   - scope: what the player can refer to this turn.
    ///   - distant: the addressable order-takers standing out of sight.
    /// - Returns: the person addressed, or why nobody was.
    private func resolveAddressee(
        _ tokens: [String], in scope: Scope, alsoConsidering distant: Set<EntityID> = []
    ) -> Result<EntityID, ParseError> {
        if isPronounAddress(tokens) {
            let word = tokens[0]
            guard let referent = word == "him" ? scope.pronounHim : scope.pronounHer else {
                return .failure(.noReferent(word))
            }
            guard scope.visibleActors.contains(referent) || distant.contains(referent) else {
                return .failure(.notInScope)
            }
            return .success(referent)
        }
        let first = matches(tokens, among: scope.visibleActors)
        guard case .failure(.notInScope) = first, !distant.isEmpty else { return first }
        return outOfSight(tokens, among: scope.allOrderTakers, answerableIn: distant)
    }

    /// The second pass both naming reaches make: judge the phrase over everyone
    /// it could possibly have meant, and answer only from those within reach.
    ///
    /// **Calling somebody out of sight answers only an unambiguous phrase.**
    /// A phrase that picks out several people the player cannot see has named
    /// nobody, and listing them would hand over a cast they have not met —
    /// `follow man` in an empty hall must not enumerate everyone in the house.
    /// Which is why the two sets are separate: judging over `reach` alone, one
    /// man next door out of three in the house would stop being ambiguous and
    /// start being an answer. (#332)
    ///
    /// The phrase itself may be a description rather than a name — ``matches``
    /// falls back to one when nothing answers as a name (#445), so `follow
    /// tall` can reach the one tall man next door. That costs the player
    /// nothing they could not already have had: the two guards below are about
    /// *how many* people a phrase picks out and *where they stand*, not about
    /// how it picked them.
    ///
    /// - Parameters:
    ///   - tokens: the noun phrase.
    ///   - candidates: everybody the phrase could have meant.
    ///   - reach: the ones close enough to be an answer.
    /// - Returns: the person named, or why nobody was.
    private func outOfSight(
        _ tokens: [String], among candidates: Set<EntityID>, answerableIn reach: Set<EntityID>
    ) -> Result<EntityID, ParseError> {
        let match = matches(tokens, among: candidates)
        if case .failure(.ambiguous) = match { return .failure(.notInScope) }
        // Unambiguous, but out of reach: never met and not next door, so the
        // player has named somebody the story has not put in front of them.
        if case .success(let id) = match, !reach.contains(id) { return .failure(.notInScope) }
        return match
    }

    /// The lexicon match itself, over one candidate set.
    ///
    /// **Two passes, and the second one only when the first found nothing.**
    /// A phrase that ends in a noun is a name and is matched as one. A phrase
    /// that doesn't — `x velvet`, `take brass` — is a *description*, and the
    /// player is owed the thing it picks out when it picks out one thing and
    /// the question when it picks out several. Second pass rather than one
    /// relaxed test, so that no phrase which already named something can
    /// change meaning: a description never beats a name. Issue #445.
    private func matches(
        _ tokens: [String], among candidates: Set<EntityID>
    ) -> Result<EntityID, ParseError> {
        let named = candidates.filter { id in
            vocabulary.itemLexicons[id]?.matches(tokens) == true
        }
        let matches =
            named.isEmpty
            ? candidates.filter { id in vocabulary.itemLexicons[id]?.describes(tokens) == true }
            : named

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
        vocabulary.displayName(of: id)
    }

    /// The entity's name behind its definite article, or bare if it is a
    /// proper name. The parser's counterpart to `TurnFrame.definiteName(of:)`.
    func definiteName(of id: EntityID) -> String {
        vocabulary.definiteName(of: id)
    }

    /// The same phrase, carrying its number, for the one parser line whose verb
    /// has to agree with the person it names. The parser's counterpart to
    /// `TurnFrame.definiteNoun(of:)`.
    private func definiteNoun(of id: EntityID) -> GameText.Noun {
        GameText.Noun(definiteName(of: id), plural: vocabulary.plurals.contains(id))
    }
}
