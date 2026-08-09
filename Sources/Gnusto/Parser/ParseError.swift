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
    /// "all"/"them" in the indirect slot — only the direct slot is multiple.
    case multipleNotAllowed
    /// `butler, take the letter` — addressing a person with anything other
    /// than a greeting. The engine has no way for one character to act on
    /// another's word, so this is a refusal rather than a question.
    case notTakingOrders(String)

    func playerMessage(_ text: GameText) -> String {
        switch self {
        case .empty:
            text.beg
        case .unknownWord(let word):
            text.unknownWord(word)
        case .notInScope:
            text.cantSeeAnySuchThing
        case .notAVerb, .unmatchedSyntax:
            text.didntUnderstand
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
            text.multipleNotAllowedThere
        case .notTakingOrders(let name):
            text.notTakingOrders(name)
        }
    }

    /// For the question cases, the token context an answer completes:
    /// `prefix + answer + suffix` reparses as the full command. `nil` for
    /// errors that aren't questions.
    var clarification: (prefix: [String], suffix: [String])? {
        switch self {
        case .missingObject(_, let prefix):
            (prefix, [])
        case .missingIndirect(_, _, _, let prefix):
            (prefix, [])
        case .missingTopic(_, _, _, let prefix):
            (prefix, [])
        case .missingDirection(_, _, let prefix):
            (prefix, [])
        case .ambiguous(_, let prefix, let suffix):
            (prefix, suffix)
        default:
            nil
        }
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
        let anchor = address + [","]
        switch self {
        case .missingObject(let verb, let prefix):
            return .missingObject(verb: verb, prefix: anchor + prefix)
        case .missingIndirect(let verb, let objectName, let preposition, let prefix):
            return .missingIndirect(
                verb: verb, objectName: objectName, preposition: preposition,
                prefix: anchor + prefix)
        case .missingTopic(let verb, let objectName, let preposition, let prefix):
            return .missingTopic(
                verb: verb, objectName: objectName, preposition: preposition,
                prefix: anchor + prefix)
        case .missingDirection(let verb, let objectName, let prefix):
            return .missingDirection(verb: verb, objectName: objectName, prefix: anchor + prefix)
        case .ambiguous(let names, let prefix, let suffix):
            return .ambiguous(names: names, prefix: anchor + prefix, suffix: suffix)
        default:
            return self
        }
    }
}
