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

    /// The reply to an empty input line.
    public var beg = "I beg your pardon?"
    /// A successful `take`.
    public var taken = "Taken."
    /// A successful `drop`.
    public var dropped = "Dropped."
    /// Taking something already carried.
    public var alreadyHave = "You already have that."
    /// Taking something that isn't takable (scenery).
    public var cantTake = "You can't take that."
    /// Dropping (or otherwise handling) something not carried.
    public var notCarrying = "You aren't carrying that."
    /// Wearing or placing something not in hand.
    public var notHolding = "You aren't holding that."
    /// Wearing something already worn.
    public var alreadyWearing = "You're already wearing that."
    /// Taking off something not worn.
    public var notWearing = "You're not wearing that."
    /// Wearing something without the `wearable` trait.
    public var cantWear = "You can't wear that."
    /// Putting something onto a non-surface.
    public var cantPutOnThat = "You can't put things on that."
    /// Putting something onto itself.
    public var cantPutOnItself = "You can't put something on itself."
    /// Moving where no exit leads.
    public var cantGoThatWay = "You can't go that way."
    /// A bare `go` with no direction.
    public var whichWay = "Which way?"
    /// Looking around a dark room.
    public var pitchBlack = "It is pitch black. You can't see a thing."
    /// An `inventory` with nothing carried.
    public var emptyHanded = "You are empty-handed."
    /// The header above the inventory listing.
    public var carrying = "You are carrying:"
    /// Reading something with no description to read.
    public var nothingWritten = "There's nothing written on that."

    // MARK: - Containers

    /// A successful `open` of an empty container.
    public var opened = "Opened."
    /// A successful `close`.
    public var closed = "Closed."
    /// A successful `lock`.
    public var lockedMessage = "Locked."
    /// A successful `unlock`.
    public var unlockedMessage = "Unlocked."
    /// Opening something without the `openable` trait.
    public var cantOpenThat = "You can't open that."
    /// Closing something without the `openable` trait.
    public var cantCloseThat = "You can't close that."
    /// Opening something already open.
    public var alreadyOpen = "That's already open."
    /// Closing something already closed.
    public var alreadyClosed = "That's already closed."
    /// Locking something without the `lockable` trait.
    public var cantLockThat = "You can't lock that."
    /// Unlocking something without the `lockable` trait.
    public var cantUnlockThat = "You can't unlock that."
    /// Locking something already locked.
    public var alreadyLocked = "That's already locked."
    /// Unlocking something already unlocked.
    public var alreadyUnlocked = "That's already unlocked."
    /// Locking or unlocking with an item that isn't this lock's key.
    public var wrongKey = "That doesn't fit the lock."
    /// Putting something into a non-container.
    public var cantPutInThat = "You can't put things in that."
    /// Putting something into itself.
    public var cantPutInItself = "You can't put something in itself."
    /// Putting something into a container that is at capacity.
    public var noRoom = "There's no room."
    /// Pushing something the default action won't move.
    public var cantMoveThat = "You can't move that."

    // MARK: - Light

    /// A successful `turn on` of a light source.
    public var nowOn: @Sendable (_ name: String) -> String = {
        "The \($0) is now on."
    }
    /// A successful `turn off`.
    public var nowOff: @Sendable (_ name: String) -> String = {
        "The \($0) is now off."
    }
    /// Turning on something already lit.
    public var alreadyOn = "It's already on."
    /// Turning off something already unlit.
    public var alreadyOff = "It's already off."
    /// Turning on something without the `lightSource` trait.
    public var cantTurnOnThat = "You can't turn that on."
    /// Turning off something without the `lightSource` trait.
    public var cantTurnOffThat = "You can't turn that off."
    /// Extinguishing the only light in a dark place.
    public var nowDark = "It is now pitch black."

    // MARK: - Undo & restart

    /// A successful `undo`.
    public var undone = "Previous turn undone."
    /// An `undo` with no snapshot to rewind to.
    public var cantUndo = "There's nothing to undo."

    // MARK: - Save & restore

    /// The filename question after `save`.
    public var savePrompt = "Save to what file?"
    /// The filename question after `restore`.
    public var restorePrompt = "Restore from what file?"
    /// A successful `save`.
    public var saved = "Saved."
    /// A `save` whose file couldn't be written.
    public var saveFailed = "Save failed."
    /// A successful `restore`.
    public var restored = "Restored."
    /// A `restore` whose file is missing, unreadable, or not a save.
    public var restoreFailed = "Restore failed."
    /// A `restore` from a save that belongs to a different game.
    public var wrongGameSave = "That save file is from a different game."
    /// An empty answer to a filename prompt.
    public var cancelled = "Cancelled."

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

    /// Opening something that is locked.
    public var locked: @Sendable (_ name: String) -> String = {
        "The \($0) is locked."
    }

    /// Reaching into (or moving through) something that is closed.
    public var closedContainer: @Sendable (_ name: String) -> String = {
        "The \($0) is closed."
    }

    /// Looking into a container with nothing in it.
    public var emptyContainer: @Sendable (_ name: String) -> String = {
        "The \($0) is empty."
    }

    /// Locking or unlocking with a key that isn't in hand.
    public var keyNotHeld: @Sendable (_ name: String) -> String = {
        "You aren't holding the \($0)."
    }

    /// A successful `putIn`.
    public var putItemIn: @Sendable (_ name: String, _ container: String) -> String = {
        "You put the \($0) in the \($1)."
    }

    /// Opening a container with visible contents.
    public var openingReveals: @Sendable (_ name: String, _ contentNames: [String]) -> String = {
        "Opening the \($0) reveals \(GameText.indefiniteList($1))."
    }

    /// "In the X is a Y." / "In the X are a Y and a Z." — verb agreement
    /// follows the content count.
    public var inTheContainer: @Sendable (_ name: String, _ contentNames: [String]) -> String = {
        let verb = $1.count == 1 ? "is" : "are"
        return "In the \($0) \(verb) \(GameText.indefiniteList($1))."
    }

    /// The aside printed when handling a worn item removes it first.
    public var firstTakingOff: @Sendable (_ name: String) -> String = {
        "(first taking off the \($0))"
    }

    /// A successful `wear`.
    public var putOn: @Sendable (_ name: String) -> String = {
        "You put on the \($0)."
    }

    /// A successful `doff`.
    public var takeOff: @Sendable (_ name: String) -> String = {
        "You take off the \($0)."
    }

    /// A successful `putOn` (placing onto a surface).
    public var putItemOn: @Sendable (_ name: String, _ surface: String) -> String = {
        "You put the \($0) on the \($1)."
    }

    /// Examining something with no description of its own.
    public var nothingSpecial: @Sendable (_ name: String) -> String = {
        "You see nothing special about the \($0)."
    }

    /// A room description's line for a loose item.
    public var itemHere: @Sendable (_ name: String) -> String = {
        "There is \(GameText.indefinite($0)) here."
    }

    /// A room description's line for an item resting on a surface.
    public var itemOnSurface: @Sendable (_ name: String, _ surface: String) -> String = {
        "On the \($1) is \(GameText.indefinite($0))."
    }

    /// A room description's line for an item visible inside a container.
    public var itemInContainer: @Sendable (_ name: String, _ container: String) -> String = {
        "In the \($1) is \(GameText.indefinite($0))."
    }

    /// One carried item in the inventory listing.
    public var inventoryLine: @Sendable (_ name: String, _ isWorn: Bool) -> String = {
        "  \(GameText.indefinite($0))\($1 ? " (being worn)" : "")"
    }

    /// The title banner shown at startup and by `version`.
    public var banner: @Sendable (_ title: String, _ tagline: String) -> String = {
        $1.isEmpty ? $0 : "\($0)\n\($1)"
    }

    /// The `score` report, also printed as the end-of-game epilogue.
    public var scoreLine: @Sendable (_ score: Int, _ maxScore: Int, _ moves: Int) -> String = {
        let possible = $1 > 0 ? " of a possible \($1)" : ""
        return "Your score is \($0)\(possible), in \($2) \($2 == 1 ? "turn" : "turns")."
    }

    // MARK: - Parser replies

    /// A word outside the game's whole vocabulary.
    public var unknownWord: @Sendable (_ word: String) -> String = {
        "I don't know the word \"\($0)\"."
    }

    /// A pronoun ("it", "them") with nothing bound to it yet.
    public var noReferent: @Sendable (_ word: String) -> String = {
        "I don't know what \"\($0)\" refers to."
    }

    /// Known words that name nothing currently in view.
    public var cantSeeAnySuchThing = "You can't see any such thing."
    /// A line no verb pattern fits.
    public var didntUnderstand = "I didn't understand that sentence."

    /// A verb missing its object — answerable on the next line.
    public var missingObject: @Sendable (_ verb: String) -> String = {
        "What do you want to \($0)?"
    }

    /// A verb missing its second object — answerable on the next line.
    public var missingIndirect: @Sendable (_ verb: String, _ objectName: String, _ preposition: String) -> String = {
        "What do you want to \($0) the \($1) \($2)?"
    }

    /// A noun phrase matching several things — answerable on the next line.
    public var ambiguous: @Sendable (_ names: [String]) -> String = {
        "Which do you mean: \($0.map { "the \($0)" }.joined(separator: " or "))?"
    }

    // MARK: - Multi-object commands

    /// "all"/"them" in the indirect slot, where only one object fits.
    public var multipleNotAllowedThere = "You can't use multiple objects there."
    /// "take all" with nothing eligible to take.
    public var nothingToTakeHere = "There is nothing here to take."
    /// "drop all" (or "put all …") with nothing carried.
    public var notCarryingAnything = "You aren't carrying anything."

    /// "all"/"them" with a verb that only handles one object at a time.
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
