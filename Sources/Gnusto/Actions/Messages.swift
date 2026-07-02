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

    // MARK: - Containers

    static let opened = "Opened."
    static let closed = "Closed."
    static let lockedMessage = "Locked."
    static let unlockedMessage = "Unlocked."
    static let cantOpenThat = "You can't open that."
    static let cantCloseThat = "You can't close that."
    static let alreadyOpen = "That's already open."
    static let alreadyClosed = "That's already closed."
    static let cantLockThat = "You can't lock that."
    static let cantUnlockThat = "You can't unlock that."
    static let alreadyLocked = "That's already locked."
    static let alreadyUnlocked = "That's already unlocked."
    static let wrongKey = "That doesn't fit the lock."
    static let cantPutInThat = "You can't put things in that."
    static let cantPutInItself = "You can't put something in itself."
    static let noRoom = "There's no room."
    static let cantMoveThat = "You can't move that."

    /// The item resolved (it was visible to the parser), but a reachability
    /// guard failed — you can see it, you just can't touch it (e.g. through a
    /// shut glass jar). Distinct from `cantSeeAnySuchThing`, which is for a
    /// noun that isn't in scope at all.
    static func cantReach(_ name: String) -> String {
        "You can't reach the \(name)."
    }

    /// Refusal for putting a container into something it (transitively)
    /// contains — the ancestor-chain cycle case, distinct from putting an item
    /// directly into itself.
    static func cantPutInsideOwnContents(_ name: String) -> String {
        "You can't put the \(name) inside something it contains."
    }

    /// The `putOn` counterpart to `cantPutInsideOwnContents`.
    static func cantPutOntoOwnContents(_ name: String) -> String {
        "You can't put the \(name) onto something it contains."
    }

    static func locked(_ name: String) -> String {
        "The \(name) is locked."
    }

    static func closedContainer(_ name: String) -> String {
        "The \(name) is closed."
    }

    static func emptyContainer(_ name: String) -> String {
        "The \(name) is empty."
    }

    static func keyNotHeld(_ name: String) -> String {
        "You aren't holding the \(name)."
    }

    static func putItemIn(_ name: String, _ container: String) -> String {
        "You put the \(name) in the \(container)."
    }

    static func openingReveals(_ name: String, _ contentNames: [String]) -> String {
        "Opening the \(name) reveals \(indefiniteList(contentNames))."
    }

    /// "In the X is a Y." / "In the X are a Y and a Z." — verb agreement
    /// follows the content count.
    static func inTheContainer(_ name: String, _ contentNames: [String]) -> String {
        let verb = contentNames.count == 1 ? "is" : "are"
        return "In the \(name) \(verb) \(indefiniteList(contentNames))."
    }

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
        "There is \(indefinite(name)) here."
    }

    static func itemOnSurface(_ name: String, _ surface: String) -> String {
        "On the \(surface) is \(indefinite(name))."
    }

    static func itemInContainer(_ name: String, _ container: String) -> String {
        "In the \(container) is \(indefinite(name))."
    }

    static func inventoryLine(_ name: String, isWorn: Bool) -> String {
        "  \(indefinite(name))\(isWorn ? " (being worn)" : "")"
    }

    static func banner(title: String, tagline: String) -> String {
        tagline.isEmpty ? title : "\(title)\n\(tagline)"
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

    /// The name with its indefinite article, for listings ("a velvet cloak",
    /// "an apple"). Standard action messages use "the" instead.
    static func indefinite(_ name: String) -> String {
        if let first = name.lowercased().first, "aeiou".contains(first) {
            "an \(name)"
        } else {
            "a \(name)"
        }
    }

    /// Joins names with their indefinite articles into an English list ("a Y",
    /// "a Y and a Z", "a Y, a Z, and a W") for contents listings.
    static func indefiniteList(_ names: [String]) -> String {
        let articled = names.map(indefinite)
        switch articled.count {
        case 0: return ""
        case 1: return articled[0]
        case 2: return "\(articled[0]) and \(articled[1])"
        default:
            let allButLast = articled.dropLast().joined(separator: ", ")
            return "\(allButLast), and \(articled.last!)"
        }
    }
}
