/// Every standard response in one place, for tone consistency and later
/// re-skinning.
enum Messages {
    static let beg = "I beg your pardon?"
    static let taken = "Taken."
    static let dropped = "Dropped."
    static let alreadyHave = "You already have that."
    static let cantTake = "You can't take that."
    static let notCarrying = "You aren't carrying that."
    static let notHolding = "You aren't holding that."
    static let alreadyWearing = "You're already wearing that."
    static let notWearing = "You're not wearing that."
    static let cantWear = "You can't wear that."
    static let cantPutOnThat = "You can't put things on that."
    static let cantPutOnItself = "You can't put something on itself."
    static let cantGoThatWay = "You can't go that way."
    static let whichWay = "Which way?"
    static let pitchBlack = "It is pitch black. You can't see a thing."
    static let emptyHanded = "You are empty-handed."
    static let carrying = "You are carrying:"
    static let nothingWritten = "There's nothing written on that."

    static func firstTakingOff(_ name: String) -> String {
        "(first taking off the \(name))"
    }

    static func putOn(_ name: String) -> String {
        "You put on the \(name)."
    }

    static func takeOff(_ name: String) -> String {
        "You take off the \(name)."
    }

    static func putItemOn(_ name: String, _ surface: String) -> String {
        "You put the \(name) on the \(surface)."
    }

    static func nothingSpecial(_ name: String) -> String {
        "You see nothing special about the \(name)."
    }

    static func itemHere(_ name: String) -> String {
        "There is a \(article(for: name)) here."
    }

    static func itemOnSurface(_ name: String, _ surface: String) -> String {
        "On the \(surface) is a \(article(for: name))."
    }

    static func scoreLine(score: Int, maxScore: Int, moves: Int) -> String {
        let possible = maxScore > 0 ? " of a possible \(maxScore)" : ""
        return "Your score is \(score)\(possible), in \(moves) \(moves == 1 ? "turn" : "turns")."
    }

    static func unknownWord(_ word: String) -> String {
        "I don't know the word \"\(word)\"."
    }

    static let cantSeeAnySuchThing = "You can't see any such thing."
    static let didntUnderstand = "I didn't understand that sentence."

    static func missingObject(_ verb: String) -> String {
        "What do you want to \(verb)?"
    }

    static func missingIndirect(_ verb: String, _ objectName: String, _ preposition: String) -> String {
        "What do you want to \(verb) the \(objectName) \(preposition)?"
    }

    static func ambiguous(_ names: [String]) -> String {
        "Which do you mean: \(names.map { "the \($0)" }.joined(separator: " or "))?"
    }

    /// Just the name; articles in standard messages are uniformly "the"
    /// except listings, which read better indefinite.
    private static func article(for name: String) -> String {
        name
    }
}
