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
    case ambiguous(names: [String], prefix: [String], suffix: [String])
    /// "all"/"them" in the indirect slot — only the direct slot is multiple.
    case multipleNotAllowed

    var playerMessage: String {
        switch self {
        case .empty:
            Messages.beg
        case .unknownWord(let word):
            Messages.unknownWord(word)
        case .notInScope:
            Messages.cantSeeAnySuchThing
        case .notAVerb, .unmatchedSyntax:
            Messages.didntUnderstand
        case .noReferent(let word):
            Messages.noReferent(word)
        case .missingObject(let verb, _):
            Messages.missingObject(verb)
        case .missingIndirect(let verb, let objectName, let preposition, _):
            Messages.missingIndirect(verb, objectName, preposition)
        case .ambiguous(let names, _, _):
            Messages.ambiguous(names)
        case .multipleNotAllowed:
            Messages.multipleNotAllowedThere
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
        case .ambiguous(_, let prefix, let suffix):
            (prefix, suffix)
        default:
            nil
        }
    }
}
