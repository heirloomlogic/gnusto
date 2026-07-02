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
    case missingObject(verb: String)
    case missingIndirect(verb: String, objectName: String, preposition: String)
    case ambiguous(names: [String])

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
        case .missingObject(let verb):
            Messages.missingObject(verb)
        case .missingIndirect(let verb, let objectName, let preposition):
            Messages.missingIndirect(verb, objectName, preposition)
        case .ambiguous(let names):
            Messages.ambiguous(names)
        }
    }
}
