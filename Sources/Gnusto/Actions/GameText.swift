/// Every stock player-facing line the engine can say, as one overridable
/// value — so a game can speak in its own voice without touching behavior.
///
/// Assign to `text` in a `Game` to re-skin any subset of lines:
///
/// ```swift
/// var text: GameText {
///     var text = GameText()
///     text.taken = "Snagged."
///     return text
/// }
/// ```
///
/// Fixed lines are plain strings; lines built around names are `@Sendable`
/// closures taking those names.
public struct GameText: Sendable {
    /// Creates the default table: the engine's classic voice.
    public init() {}

    public var beg = "I beg your pardon?"
    public var taken = "Taken."
    public var dropped = "Dropped."
    public var alreadyHave = "You already have that."
    public var cantTake = "You can't take that."
    public var notCarrying = "You aren't carrying that."
    public var notHolding = "You aren't holding that."
    public var alreadyWearing = "You're already wearing that."
    public var notWearing = "You're not wearing that."
    public var cantWear = "You can't wear that."
    public var cantPutOnThat = "You can't put things on that."
    public var cantPutOnItself = "You can't put something on itself."
    public var cantGoThatWay = "You can't go that way."
    public var whichWay = "Which way?"
    public var pitchBlack = "It is pitch black. You can't see a thing."
    public var emptyHanded = "You are empty-handed."
    public var carrying = "You are carrying:"
    public var nothingWritten = "There's nothing written on that."

    // MARK: - Containers

    public var opened = "Opened."
    public var closed = "Closed."
    public var lockedMessage = "Locked."
    public var unlockedMessage = "Unlocked."
    public var cantOpenThat = "You can't open that."
    public var cantCloseThat = "You can't close that."
    public var alreadyOpen = "That's already open."
    public var alreadyClosed = "That's already closed."
    public var cantLockThat = "You can't lock that."
    public var cantUnlockThat = "You can't unlock that."
    public var alreadyLocked = "That's already locked."
    public var alreadyUnlocked = "That's already unlocked."
    public var wrongKey = "That doesn't fit the lock."
    public var cantPutInThat = "You can't put things in that."
    public var cantPutInItself = "You can't put something in itself."
    public var noRoom = "There's no room."
    public var cantMoveThat = "You can't move that."

    /// The item resolved (it was visible to the parser), but a reachability
    /// guard failed — you can see it, you just can't touch it (e.g. through a
    /// shut glass jar). Distinct from `cantSeeAnySuchThing`, which is for a
    /// noun that isn't in scope at all.
    public var cantReach: @Sendable (_ name: String) -> String = {
        "You can't reach the \($0)."
    }

    /// Refusal for putting a container into something it (transitively)
    /// contains — the ancestor-chain cycle case, distinct from putting an item
    /// directly into itself.
    public var cantPutInsideOwnContents: @Sendable (_ name: String) -> String = {
        "You can't put the \($0) inside something it contains."
    }

    /// The `putOn` counterpart to `cantPutInsideOwnContents`.
    public var cantPutOntoOwnContents: @Sendable (_ name: String) -> String = {
        "You can't put the \($0) onto something it contains."
    }

    public var locked: @Sendable (_ name: String) -> String = {
        "The \($0) is locked."
    }

    public var closedContainer: @Sendable (_ name: String) -> String = {
        "The \($0) is closed."
    }

    public var emptyContainer: @Sendable (_ name: String) -> String = {
        "The \($0) is empty."
    }

    public var keyNotHeld: @Sendable (_ name: String) -> String = {
        "You aren't holding the \($0)."
    }

    public var putItemIn: @Sendable (_ name: String, _ container: String) -> String = {
        "You put the \($0) in the \($1)."
    }

    public var openingReveals: @Sendable (_ name: String, _ contentNames: [String]) -> String = {
        "Opening the \($0) reveals \(GameText.indefiniteList($1))."
    }

    /// "In the X is a Y." / "In the X are a Y and a Z." — verb agreement
    /// follows the content count.
    public var inTheContainer: @Sendable (_ name: String, _ contentNames: [String]) -> String = {
        let verb = $1.count == 1 ? "is" : "are"
        return "In the \($0) \(verb) \(GameText.indefiniteList($1))."
    }

    public var firstTakingOff: @Sendable (_ name: String) -> String = {
        "(first taking off the \($0))"
    }

    public var putOn: @Sendable (_ name: String) -> String = {
        "You put on the \($0)."
    }

    public var takeOff: @Sendable (_ name: String) -> String = {
        "You take off the \($0)."
    }

    public var putItemOn: @Sendable (_ name: String, _ surface: String) -> String = {
        "You put the \($0) on the \($1)."
    }

    public var nothingSpecial: @Sendable (_ name: String) -> String = {
        "You see nothing special about the \($0)."
    }

    public var itemHere: @Sendable (_ name: String) -> String = {
        "There is \(GameText.indefinite($0)) here."
    }

    public var itemOnSurface: @Sendable (_ name: String, _ surface: String) -> String = {
        "On the \($1) is \(GameText.indefinite($0))."
    }

    public var itemInContainer: @Sendable (_ name: String, _ container: String) -> String = {
        "In the \($1) is \(GameText.indefinite($0))."
    }

    public var inventoryLine: @Sendable (_ name: String, _ isWorn: Bool) -> String = {
        "  \(GameText.indefinite($0))\($1 ? " (being worn)" : "")"
    }

    public var banner: @Sendable (_ title: String, _ tagline: String) -> String = {
        $1.isEmpty ? $0 : "\($0)\n\($1)"
    }

    public var scoreLine: @Sendable (_ score: Int, _ maxScore: Int, _ moves: Int) -> String = {
        let possible = $1 > 0 ? " of a possible \($1)" : ""
        return "Your score is \($0)\(possible), in \($2) \($2 == 1 ? "turn" : "turns")."
    }

    // MARK: - Parser replies

    public var unknownWord: @Sendable (_ word: String) -> String = {
        "I don't know the word \"\($0)\"."
    }

    public var noReferent: @Sendable (_ word: String) -> String = {
        "I don't know what \"\($0)\" refers to."
    }

    public var cantSeeAnySuchThing = "You can't see any such thing."
    public var didntUnderstand = "I didn't understand that sentence."

    public var missingObject: @Sendable (_ verb: String) -> String = {
        "What do you want to \($0)?"
    }

    public var missingIndirect:
        @Sendable (_ verb: String, _ objectName: String, _ preposition: String) -> String = {
            "What do you want to \($0) the \($1) \($2)?"
        }

    public var ambiguous: @Sendable (_ names: [String]) -> String = {
        "Which do you mean: \($0.map { "the \($0)" }.joined(separator: " or "))?"
    }

    // MARK: - Multi-object commands

    public var multipleNotAllowedThere = "You can't use multiple objects there."
    public var nothingToTakeHere = "There is nothing here to take."
    public var notCarryingAnything = "You aren't carrying anything."

    public var multipleNotAllowedWith: @Sendable (_ verb: String) -> String = {
        "You can't use multiple objects with \"\($0)\"."
    }

    // MARK: - Formatting helpers

    /// The name with its indefinite article, for listings ("a velvet cloak",
    /// "an apple"). Standard action lines use "the" instead. A formatting
    /// utility, not a skinnable line — custom closures can call it too.
    public static func indefinite(_ name: String) -> String {
        if let first = name.lowercased().first, "aeiou".contains(first) {
            "an \(name)"
        } else {
            "a \(name)"
        }
    }

    /// Joins names with their indefinite articles into an English list ("a Y",
    /// "a Y and a Z", "a Y, a Z, and a W") for contents listings.
    public static func indefiniteList(_ names: [String]) -> String {
        let articled = names.map(indefinite)
        guard let last = articled.last else { return "" }
        switch articled.count {
        case 1: return last
        case 2: return "\(articled[0]) and \(last)"
        default:
            let allButLast = articled.dropLast().joined(separator: ", ")
            return "\(allButLast), and \(last)"
        }
    }
}
