/// Why an input line couldn't become a command. Parse errors never enter the
/// turn pipeline and never consume a turn.
enum ParseError: Error, Equatable {
    case empty
    case unknownWord(String)
    /// Every word is in the game's vocabulary, but nothing in scope matches.
    case notInScope
    case notAVerb(String)
    /// A pronoun with nothing bound to it yet ("x it" before naming anything).
    case noReferent(String)
    case unmatchedSyntax
    /// The question cases carry where the player's answer belongs: the next
    /// input line can complete the command as `prefix + answer + suffix`.
    /// ``question`` is where a new one says so, and the compiler will ask.
    case missingObject(verb: String, prefix: [String])
    case missingIndirect(verb: String, objectName: String, preposition: String, prefix: [String])
    /// A conversation verb whose topic slot got nothing: "ask butler about".
    /// Carries the object when the row had one, so the question can read
    /// "What do you want to ask the butler about?"
    case missingTopic(verb: String, objectName: String?, preposition: String, prefix: [String])
    /// A row of the shape `<verb> <object> <direction>` whose noun resolved and
    /// whose direction was left off: "push the sandstone wall". The direction
    /// slot ends its pattern, so the answer appends like any other.
    case missingDirection(verb: String, objectName: String, prefix: [String])
    case ambiguous(names: [String], prefix: [String], suffix: [String])
    /// Several objects where the slot holds one: "all"/"them" or a conjunction
    /// list in the indirect slot, or a keyword standing among the members of a
    /// list ("take the coin and all"). Only the direct slot is multiple, and
    /// only as a whole.
    case multipleNotAllowed
    /// `butler, take the letter` — addressing a person with anything other
    /// than a greeting. The engine has no way for one character to act on
    /// another's word, so this is a refusal rather than a question.
    case notTakingOrders(GameText.Noun)

    func playerMessage(_ text: GameText) -> String {
        switch self {
        case .empty:
            text.beg()
        case .unknownWord(let word):
            text.unknownWord(word)
        case .notInScope:
            text.cantSeeAnySuchThing()
        case .notAVerb, .unmatchedSyntax:
            text.didntUnderstand()
        case .noReferent(let word):
            text.noReferent(word)
        case .missingObject(let verb, _):
            text.missingObject(verb)
        case .missingIndirect(let verb, let objectName, let preposition, _):
            text.missingIndirect(verb, objectName, preposition)
        case .missingTopic(let verb, let objectName, let preposition, _):
            text.missingTopic(verb, objectName, preposition)
        case .missingDirection(let verb, let objectName, _):
            text.missingDirection(verb, objectName)
        case .ambiguous(let names, _, _):
            text.ambiguous(names)
        case .multipleNotAllowed:
            text.multipleNotAllowedThere()
        case .notTakingOrders(let name):
            text.notTakingOrders(name)
        }
    }

    /// A question's answer context, and how to write a different one back.
    ///
    /// Everything downstream of a question wants one of two things — where the
    /// answer goes, or the same question anchored somewhere else — so both are
    /// carried here and nobody else has to know the case names.
    struct Question {
        /// The tokens before the answer and the tokens after it:
        /// `prefix + answer + suffix` reparses as the full command. Most
        /// questions are answered at the end of the line, so `suffix` is empty
        /// unless the answer belongs in the middle of it.
        let prefix: [String]
        let suffix: [String]
        /// The same question with `prefix` replaced. Every other payload rides
        /// along, so a re-anchored question still reads the way it did.
        let reanchored: @Sendable ([String]) -> ParseError

        init(
            prefix: [String], suffix: [String] = [],
            reanchored: @escaping @Sendable ([String]) -> ParseError
        ) {
            self.prefix = prefix
            self.suffix = suffix
            self.reanchored = reanchored
        }
    }

    /// The answer context of every question case, or `nil` for an error the
    /// next line can't answer.
    ///
    /// Exhaustive on purpose. Whether an error is answerable, and where its
    /// answer goes, used to be spelled out separately in `clarification` and
    /// `addressed(to:)`, both ending in a `default:` — so a new question case
    /// that missed one compiled clean and then dropped the player's answer, or
    /// read the rest of an order as the player's own move. Saying it once here
    /// makes the omission a build error, and classifying a new case is the only
    /// thing the compiler asks for.
    var question: Question? {
        switch self {
        case .empty, .unknownWord, .notInScope, .notAVerb, .noReferent, .unmatchedSyntax,
            .multipleNotAllowed, .notTakingOrders:
            nil
        case .missingObject(let verb, let prefix):
            Question(prefix: prefix) { .missingObject(verb: verb, prefix: $0) }
        case .missingIndirect(let verb, let objectName, let preposition, let prefix):
            Question(prefix: prefix) {
                .missingIndirect(
                    verb: verb, objectName: objectName, preposition: preposition, prefix: $0)
            }
        case .missingTopic(let verb, let objectName, let preposition, let prefix):
            Question(prefix: prefix) {
                .missingTopic(
                    verb: verb, objectName: objectName, preposition: preposition, prefix: $0)
            }
        case .missingDirection(let verb, let objectName, let prefix):
            Question(prefix: prefix) {
                .missingDirection(verb: verb, objectName: objectName, prefix: $0)
            }
        case .ambiguous(let names, let prefix, let suffix):
            Question(prefix: prefix, suffix: suffix) {
                .ambiguous(names: names, prefix: $0, suffix: suffix)
            }
        }
    }

    /// ``question``'s answer context alone, as a value the engine can hold
    /// across the turn boundary — the closure stays here.
    var clarification: (prefix: [String], suffix: [String])? {
        question.map { ($0.prefix, $0.suffix) }
    }

    /// The same error, re-anchored on the person it was really about.
    ///
    /// An order is parsed from the tokens *after* the comma, so a question it
    /// raises carries only those — and the player's answer would come back as
    /// their own command. Putting the address back on the front keeps
    /// `robot, push` / `the button` an order to the robot. Nothing to do for
    /// the errors that aren't questions.
    ///
    /// - Parameter address: the tokens naming the addressee.
    /// - Returns: the error with its answer context re-anchored.
    func addressed(to address: [String]) -> ParseError {
        guard let question else { return self }
        return question.reanchored(address + [","] + question.prefix)
    }
}
