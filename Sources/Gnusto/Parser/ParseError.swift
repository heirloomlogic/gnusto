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
        case .ambiguous(let names, _, _):
            text.ambiguous(names)
        case .multipleNotAllowed:
            text.multipleNotAllowedThere
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
