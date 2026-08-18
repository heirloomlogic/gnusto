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
/// **Every line is a ``Line``.** What differs between them is what the line is
/// *about* — its subject — and that is a type conforming to ``LineSubject``
/// rather than a shape written down in prose. The bullets below describe the
/// subjects the engine ships; the authority is the conformance, so a subject
/// added tomorrow is swept and classified without an edit here:
///
/// - **A line about nothing in particular is a `Line<Nothing>`.** Nothing in it
///   is about a particular thing, so there is nothing to hand it — but there
///   is still a turn to write it in, so a game that wants one assembled while
///   the player stands there reaches for ``Line/live(_:)``. Those are the two
///   axes a line can be widened along: naming its object, and consulting the
///   turn.
/// - **A line about one thing is a ``Line``,** either `Line<Noun>` where every
///   parser row behind it carries an object or `Line<Noun?>` where the verb
///   also answers bare. A game writes it as a plain string literal or as
///   ``Line/naming(_:)``, and which of the two is the game's business.
/// - **A line about *two* things is a `Line` over a role struct** —
///   ``Holding``, ``Gift``, ``Aboard``. The roles are a type rather than a
///   pair so that the API can answer the question an author actually asks:
///   `\($0.holder)` says which one is the container where `\($1)` does not.
/// - **A line about *several* things is a line about one.** ``Noun/list(_:)``
///   joins them and carries the number the whole phrase has, so "In the hamper
///   are some scales" is written the same way "In the box is a coin" is, and the
///   agreement rule lives in the type rather than in each template.
///   ``inventorySentence`` is the exception, over the ``Carried`` role struct:
///   it has something to say about *each* thing — which of them is being worn —
///   so it cannot have them joined before the game has had its say.
/// - **A line about something that is not a thing in the world is a `Line` too,
///   over a subject it may not drop.** A word quoted back at the player
///   (``Word``: ``unknownWord``, ``noReferent``, ``multipleNotAllowedWith``),
///   the part of a sentence the parser is still waiting for (``Prompt``: the
///   `missing…` family), the things one phrase matched (``Choices``:
///   ``ambiguous``), the title (``Banner``) or the score (``Score``). These
///   five are ``LineSubject``s and deliberately not ``DroppableSubject``s, so
///   ``Line`` is *not* `ExpressibleByStringLiteral` over them: `text.unknownWord
///   = "Eh?"` does not compile, because it would silently drop the word that is
///   the whole content of the line. Every other subject may be dropped — a
///   two-object line that prints `"Done."` is a legitimate thing for a game to
///   want — and the difference is a conformance rather than a convention.
///
/// The object arrives as a ``Noun`` — a *rendered noun phrase* ("the troll",
/// "a troll", "Mrs. Vane") that also knows its number — and never as a bare
/// name. Both halves of that are the engine's to know and not the template's:
/// the article comes from the `properName` trait, so a line that writes its own
/// says "the Mrs. Vane", and the number comes from `plural`, so a line that
/// hard-codes its verb says "The rails is locked." Open on
/// ``Noun/sentenceCased`` rather than capitalizing by hand, and reach for
/// ``Noun/verb(_:_:)`` wherever a verb has to agree.
///
/// The parser's own lines are the one place a name arrives as a `String`:
/// ``ambiguous`` and the `missing…` family are written before any entity is
/// resolved, from ``Vocabulary`` rather than from the turn frame. None of them
/// carries a verb that agrees with the noun, so none of them has a number to
/// get wrong. ``notTakingOrders`` did, and the vocabulary carries the plural
/// set for its sake.
public struct GameText: Sendable {
    /// Creates the default table: the engine's classic voice.
    public init() {}

    /// A rendered noun phrase that also knows its own number, for the lines
    /// whose verb has to agree with it.
    ///
    /// Most stock lines can take the phrase alone, because English nouns cost
    /// their sentence nothing until a verb turns up. The handful that carry one
    /// take this instead, so "The rails is not food." — a game's real noun made
    /// ungrammatical by a template's assumption — cannot be written.
    public struct Noun: Sendable, Equatable, CustomStringConvertible {
        /// The rendered phrase, article and all: "the rails", "Mrs. Vane".
        public let phrase: String
        /// Whether the phrase is grammatically plural.
        public let isPlural: Bool

        /// Creates a noun phrase.
        ///
        /// - Parameters:
        ///   - phrase: the rendered phrase, article and all.
        ///   - plural: whether it is grammatically plural.
        public init(_ phrase: String, plural: Bool = false) {
            self.phrase = phrase
            self.isPlural = plural
        }

        /// The phrase, so that a line with no verb to agree with interpolates
        /// the noun and says nothing about number: `"You can't burn \($0)."` is
        /// the same sentence it was when these lines were handed a `String`. A
        /// line that *does* carry a verb reaches for ``verb(_:_:)`` instead,
        /// and one that opens on the noun reaches for ``sentenceCased``.
        public var description: String { phrase }

        /// The phrase with its first letter capitalized, for a line that opens
        /// on it. See ``GameText/sentenceCase(_:)``.
        public var sentenceCased: String { GameText.sentenceCase(phrase) }

        /// The form of a verb that agrees with this noun.
        ///
        /// ```swift
        /// "\($0.sentenceCased) \($0.verb("is", "are")) not food."
        /// ```
        ///
        /// - Parameters:
        ///   - singular: the form for a singular noun.
        ///   - plural: the form for a plural one.
        /// - Returns: whichever agrees.
        public func verb(_ singular: String, _ plural: String) -> String {
            isPlural ? plural : singular
        }

        /// Several nouns as one — "a sword, a lamp, and some scales" — carrying
        /// the number the whole phrase has rather than the number any one of
        /// them has.
        ///
        /// That number is the reason this is here and not at the call site.
        /// English agrees with the *list*, and a list is plural two ways: when
        /// it holds more than one thing, **or** when the only thing it holds is
        /// itself plural. Counting alone gets the second wrong, and the engine
        /// got it wrong — one plural thing in a box printed "In the hamper is
        /// some scales." A game re-voicing that line would have had to re-derive
        /// the rule from scratch and could have made the same mistake; this is
        /// the rule written once, in the type that exists to own it.
        ///
        /// An empty list is plural ("none of them are here") and renders as the
        /// empty phrase. No stock line calls one with nothing in it — the
        /// callers all branch on empty first, with a line of their own — but a
        /// game's might, and silently reading as singular would be the same
        /// defect one case further out.
        ///
        /// - Parameter nouns: the phrases to join, in the order they should
        ///   read.
        /// - Returns: one noun standing for all of them.
        public static func list(_ nouns: [Noun]) -> Noun {
            Noun(
                GameText.list(nouns.map(\.phrase)),
                plural: nouns.count != 1 || nouns.first?.isPlural == true)
        }
    }

    /// The reply to an empty input line.
    public var beg: Line<Nothing> = "I beg your pardon?"
    /// A successful `take`.
    public var taken: Line<Nothing> = "Taken."
    /// A successful `drop`.
    public var dropped: Line<Nothing> = "Dropped."
    /// Taking something already carried.
    public var alreadyHave: Line<Nothing> = "You already have that."
    /// Taking something that isn't takable (scenery).
    public var cantTake: Line<Nothing> = "You can't take that."
    /// Taking a person.
    public var cantTakeActor: Line<Noun> = .naming {
        "\($0.sentenceCased) would take exception to that."
    }
    /// Dropping (or otherwise handling) something not carried.
    public var notCarrying: Line<Nothing> = "You aren't carrying that."
    /// Wearing or placing something not in hand.
    public var notHolding: Line<Nothing> = "You aren't holding that."
    /// Wearing something already worn.
    public var alreadyWearing: Line<Nothing> = "You're already wearing that."
    /// Taking off something not worn.
    public var notWearing: Line<Nothing> = "You're not wearing that."
    /// Wearing something without the `wearable` trait.
    public var cantWear: Line<Nothing> = "You can't wear that."
    /// Putting something onto a non-surface.
    public var cantPutOnThat: Line<Nothing> = "You can't put things on that."
    /// Putting something onto itself.
    public var cantPutOnItself: Line<Nothing> = "You can't put something on itself."
    /// Moving where no exit leads.
    public var cantGoThatWay: Line<Nothing> = "You can't go that way."
    /// Entering something that is neither a door on the way out of this room nor
    /// `enterable`.
    public var cantEnterThat: Line<Noun> = .naming {
        "You can't get into \($0)."
    }
    /// Entering an enterable the player is carrying.
    public var cantEnterCarried: Line<Nothing> = "You can't get into something you're carrying."
    /// Entering the vehicle the player is already in.
    public var alreadyInVehicle: Line<Noun> = .naming {
        "You're already in \($0)."
    }
    /// Entering a second enterable without leaving the first.
    public var mustExitFirst: Line<Noun> = .naming {
        "You'll have to get out of \($0) first."
    }
    /// A successful board.
    public var boarded: Line<Noun> = .naming {
        "You are now in \($0)."
    }
    /// A successful disembark.
    public var disembarked: Line<Noun> = .naming {
        "You get out of \($0)."
    }
    /// Disembarking while on foot.
    public var notInVehicle: Line<Nothing> = "You aren't in anything."
    /// Disembarking from something other than the boarded vehicle.
    public var notInThat: Line<Noun> = .naming {
        "You aren't in \($0)."
    }
    /// The room title while the player is in a vehicle. The place is a plain
    /// `String` and not a ``Noun`` — see ``Aboard``.
    public var locationInVehicle: Line<Aboard> = .naming {
        "\($0.place), in \($0.vehicle)"
    }
    /// Taking (or otherwise relocating) the vehicle the player is inside.
    public var notWhileInside: Line<Noun> = .naming {
        "Not while you're in \($0)."
    }
    /// A bare `go` with no direction.
    public var whichWay: Line<Nothing> = "Which way?"
    /// Looking around a dark room. The line most likely to want
    /// ``Line/live(_:)``: it prints on every dark turn, in every dark room, and
    /// a game whose darkness has anything in it — a companion, a sound, a smell
    /// — has to check that the thing is still there before saying so.
    public var pitchBlack: Line<Nothing> = "It is pitch black. You can't see a thing."
    /// An `inventory` with nothing carried.
    public var emptyHanded: Line<Nothing> = "You are empty-handed."
    /// Reading something with no description to read.
    public var nothingWritten: Line<Nothing> = "There's nothing written on that."
    /// A `wait` turn — a beat passes while fuses and daemons tick.
    public var timePasses: Line<Nothing> = "Time passes."

    // MARK: - Following

    /// The aside printed as the player sets off after somebody.
    public var following: Line<Noun> = .naming {
        "(after \($0))"
    }
    /// Following somebody who is standing right here.
    public var alreadyFollowing: Line<Noun> = .naming {
        "\($0.sentenceCased) \($0.verb("is", "are")) right here."
    }
    /// Following something that isn't a person.
    public var cantFollowThat: Line<Noun> = .naming {
        "\($0.sentenceCased) \($0.verb("isn't", "aren't")) going anywhere."
    }
    /// Following somebody who has gone somewhere no exit from here leads. The
    /// search is one exit deep, so this is also the answer for a quarry who is
    /// two rooms away — see `DefaultActions.follow`.
    public var lostThem: Line<Noun> = .naming {
        "You have no idea which way \($0) went."
    }

    // MARK: - Greeting

    /// Saying hello to somebody who has nothing of their own to say.
    public var greets: Line<Noun> = .naming {
        "\($0.sentenceCased) \($0.verb("nods", "nod")), and \($0.verb("says", "say")) nothing."
    }
    /// Greeting something that isn't a person.
    public var cantGreetThat: Line<Noun> = .naming {
        "\($0.sentenceCased) \($0.verb("is", "are")) unlikely to answer."
    }
    /// A bare hello with nobody about.
    public var nobodyToGreet: Line<Nothing> = "There's nobody here to greet."
    /// A bare hello where several people could have been meant.
    public var greetsTheRoom: Line<Nothing> = "You say hello to the room in general."

    // MARK: - Containers

    /// A successful `open` of an empty container.
    public var opened: Line<Nothing> = "Opened."
    /// A successful `close`.
    public var closed: Line<Nothing> = "Closed."
    /// A successful `lock`.
    public var lockedMessage: Line<Nothing> = "Locked."
    /// A successful `unlock`.
    public var unlockedMessage: Line<Nothing> = "Unlocked."
    /// Opening something without the `openable` trait.
    public var cantOpenThat: Line<Nothing> = "You can't open that."
    /// Closing something without the `openable` trait.
    public var cantCloseThat: Line<Nothing> = "You can't close that."
    /// Opening something already open.
    public var alreadyOpen: Line<Nothing> = "That's already open."
    /// Closing something already closed.
    public var alreadyClosed: Line<Nothing> = "That's already closed."
    /// Locking something without the `lockable` trait.
    public var cantLockThat: Line<Nothing> = "You can't lock that."
    /// Unlocking something without the `lockable` trait.
    public var cantUnlockThat: Line<Nothing> = "You can't unlock that."
    /// Locking something already locked.
    public var alreadyLocked: Line<Nothing> = "That's already locked."
    /// Unlocking something already unlocked.
    public var alreadyUnlocked: Line<Nothing> = "That's already unlocked."
    /// Locking or unlocking with an item that isn't this lock's key.
    public var wrongKey: Line<Nothing> = "That doesn't fit the lock."
    /// Putting something into a non-container.
    public var cantPutInThat: Line<Nothing> = "You can't put things in that."
    /// Putting something into itself.
    public var cantPutInItself: Line<Nothing> = "You can't put something in itself."
    /// Putting something into a container that is at capacity.
    public var noRoom: Line<Nothing> = "There's no room."
    /// Pushing something the default action won't move.
    public var cantMoveThat: Line<Nothing> = "You can't move that."

    // MARK: - Light

    /// A successful `turn on` of a light source.
    public var nowOn: Line<Noun> = .naming {
        "\($0.sentenceCased) \($0.verb("is", "are")) now on."
    }
    /// A successful `turn off`.
    public var nowOff: Line<Noun> = .naming {
        "\($0.sentenceCased) \($0.verb("is", "are")) now off."
    }
    /// Turning on something already lit.
    public var alreadyOn: Line<Nothing> = "It's already on."
    /// Turning off something already unlit.
    public var alreadyOff: Line<Nothing> = "It's already off."
    /// Turning on something without the `lightSource` trait.
    public var cantTurnOnThat: Line<Nothing> = "You can't turn that on."
    /// Turning off something without the `lightSource` trait.
    public var cantTurnOffThat: Line<Nothing> = "You can't turn that off."
    /// Extinguishing the only light in a dark place.
    public var nowDark: Line<Nothing> = "It is now pitch black."

    // MARK: - Undo & restart

    /// A successful `undo`.
    public var undone: Line<Nothing> = "Previous turn undone."
    /// An `undo` with no snapshot to rewind to.
    public var cantUndo: Line<Nothing> = "There's nothing to undo."

    // MARK: - Save & restore

    /// The filename question after `save`.
    public var savePrompt: Line<Nothing> = "Save to what file?"
    /// The filename question after `restore`.
    public var restorePrompt: Line<Nothing> = "Restore from what file?"
    /// A successful `save`.
    public var saved: Line<Nothing> = "Saved."
    /// A `save` whose file couldn't be written.
    public var saveFailed: Line<Nothing> = "Save failed."
    /// A successful `restore`.
    public var restored: Line<Nothing> = "Restored."
    /// A `restore` whose file is missing, unreadable, or not a save.
    public var restoreFailed: Line<Nothing> = "Restore failed."
    /// A `restore` from a save that belongs to a different game.
    public var wrongGameSave: Line<Nothing> = "That save file is from a different game."
    /// An empty answer to a filename prompt.
    public var cancelled: Line<Nothing> = "Cancelled."

    // MARK: - Death

    /// The banner printed right after a `die(_:)` message.
    public var deathBanner: Line<Nothing> = "*** You have died ***"
    /// The interactive prompt offered after death (and re-offered after a
    /// failed restore or an unrecognized answer).
    public var deathPrompt: Line<Nothing> =
        "Would you like to RESTART, RESTORE a saved game, UNDO your last turn, or QUIT?"
    /// The nudge for any other input at the death prompt.
    public var deathChoiceUnrecognized: Line<Nothing> = "Please type RESTART, RESTORE, UNDO, or QUIT."

    /// The item resolved (it was visible to the parser), but a reachability
    /// guard failed — you can see it, you just can't touch it (e.g. through a
    /// shut glass jar). Distinct from `cantSeeAnySuchThing`, which is for a
    /// noun that isn't in scope at all.
    public var cantReach: Line<Noun> = .naming {
        "You can't reach \($0)."
    }

    /// Refusal for putting a container into something it (transitively)
    /// contains — the ancestor-chain cycle case, distinct from putting an item
    /// directly into itself.
    public var cantPutInsideOwnContents: Line<Noun> = .naming {
        "You can't put \($0) inside something it contains."
    }

    /// The `putOn` counterpart to `cantPutInsideOwnContents`.
    public var cantPutOntoOwnContents: Line<Noun> = .naming {
        "You can't put \($0) onto something it contains."
    }

    /// Opening something that is locked.
    public var locked: Line<Noun> = .naming {
        "\($0.sentenceCased) \($0.verb("is", "are")) locked."
    }

    /// Reaching into (or moving through) something that is closed.
    public var closedContainer: Line<Noun> = .naming {
        "\($0.sentenceCased) \($0.verb("is", "are")) closed."
    }

    /// Looking into a container with nothing in it.
    public var emptyContainer: Line<Noun> = .naming {
        "\($0.sentenceCased) \($0.verb("is", "are")) empty."
    }

    /// Searching something that has no inside to search: the noun resolved and
    /// the player can reach it, it simply isn't a `container`. Deliberately not
    /// ``cantSeeAnySuchThing``, which is only ever for a noun that isn't in
    /// scope — the player can see this perfectly well, and SEARCH GRASS
    /// answering "You can't see any such thing" about grass the game will
    /// happily describe is the defect this line exists to retire.
    public var nothingToSearch: Line<Noun> = .naming {
        "You find nothing of interest in \($0)."
    }

    /// Searching a person. Distinct from ``nothingToSearch`` because "you find
    /// nothing of interest in the cook" claims you frisked her and came up
    /// empty, which is a good deal more than happened.
    public var cantSearchActor: Line<Noun> = .naming {
        "\($0.sentenceCased) would have something to say about that."
    }

    /// Locking or unlocking with a key that isn't in hand.
    public var keyNotHeld: Line<Noun> = .naming {
        "You aren't holding \($0)."
    }

    /// A successful `putIn`.
    public var putItemIn: Line<Holding> = .naming {
        "You put \($0.item) in \($0.holder)."
    }

    /// Opening a container with visible contents. The contents arrive as one
    /// ``Noun/list(_:)``, so `$0.item` is everything that was in there.
    public var openingReveals: Line<Holding> = .naming {
        "Opening \($0.holder) reveals \($0.item)."
    }

    /// "In the X is a Y." / "In the X are a Y and a Z." — the answer to
    /// `search`.
    ///
    /// It ships the same sentence as ``itemInContainer`` and is deliberately a
    /// second slot, because the two print at different moments and from
    /// different callers. This one answers a question the player asked, once,
    /// about everything in the container. That one is a paragraph of the room
    /// description, printed per item, unasked, on every look — and any single
    /// one of them can be superseded by that item's own `firstSight`. A game
    /// that wants its room paragraphs terser than its search answers needs the
    /// two apart; merging them would be reuse bought with an authorial choice.
    ///
    /// The verb agrees with the *contents*, and ``Noun/list(_:)`` is what knows
    /// their number: plural when there are several **or** when the only one is
    /// itself plural. That rule used to live in this line's body, where a game
    /// re-voicing it would have had to re-derive it — and could have got it
    /// wrong the way the engine did, printing "In the hamper is some scales."
    public var inTheContainer: Line<Holding> = .naming {
        "In \($0.holder) \($0.item.verb("is", "are")) \($0.item)."
    }

    /// The aside printed when handling a worn item removes it first.
    public var firstTakingOff: Line<Noun> = .naming {
        "(first taking off \($0))"
    }

    /// A successful `wear`.
    public var putOn: Line<Noun> = .naming {
        "You put on \($0)."
    }

    /// A successful `doff`.
    public var takeOff: Line<Noun> = .naming {
        "You take off \($0)."
    }

    /// A successful `putOn` (placing onto a surface).
    public var putItemOn: Line<Holding> = .naming {
        "You put \($0.item) on \($0.holder)."
    }

    /// Examining something with no description of its own.
    public var nothingSpecial: Line<Noun> = .naming {
        "You see nothing special about \($0)."
    }

    /// A room description's line for a loose item.
    public var itemHere: Line<Noun> = .naming {
        "There \($0.verb("is", "are")) \($0) here."
    }
    /// A room description's line for an actor with no `firstSight` presence
    /// line of its own.
    public var actorHere: Line<Noun> = .naming {
        "\($0.sentenceCased) \($0.verb("is", "are")) here."
    }

    /// A room description's line for an item resting on a surface.
    ///
    /// The verb agrees with the **item**, which the stock wording names second:
    /// "On the table are the rails." That inversion is why this line deals in
    /// nouns rather than strings — while it was a pair of `String`s the engine
    /// said "On the table is the rails." about every plural thing a game left
    /// on a table, and no re-skinning could fix it without hard-coding the
    /// other agreement instead.
    public var itemOnSurface: Line<Holding> = .naming {
        "On \($0.holder) \($0.item.verb("is", "are")) \($0.item)."
    }

    /// A room description's line for an item visible inside a container.
    /// Agrees with the item, for the reason ``itemOnSurface`` gives.
    public var itemInContainer: Line<Holding> = .naming {
        "In \($0.holder) \($0.item.verb("is", "are")) \($0.item)."
    }

    /// The `inventory` listing, as one sentence ("You are carrying a brass
    /// lantern, an apple, and a velvet cloak (being worn)."). The names arrive
    /// already articled, since only the caller knows which are proper names.
    /// Only called with at least one item; `emptyHanded` covers the rest.
    ///
    /// The one line about several things that does **not** take them as a single
    /// ``Noun/list(_:)``: it has something to say about each of them, so
    /// ``Carried`` keeps them apart until the game has had its say.
    public var inventorySentence: Line<Carried> = .naming {
        let phrases = $0.entries.map { $0.noun.phrase + ($0.isWorn ? " (being worn)" : "") }
        return "You are carrying \(GameText.list(phrases))."
    }

    /// The title banner shown at startup and by `version`. The `<br>` keeps the
    /// title on its own line above the tagline (a hard break) rather than
    /// letting the full-screen renderer fold the two together; plain output
    /// turns it back into a newline.
    public var banner: Line<Banner> = .naming {
        $0.tagline.isEmpty ? $0.title : "\($0.title)\(TextWrap.lineBreak)\($0.tagline)"
    }

    /// The `score` report, also printed as the end-of-game epilogue.
    public var scoreLine: Line<Score> = .naming {
        let possible = $0.maxScore > 0 ? " of a possible \($0.maxScore)" : ""
        let turns = $0.moves == 1 ? "turn" : "turns"
        return "Your score is \($0.score)\(possible), in \($0.moves) \(turns)."
    }

    // MARK: - Yourself

    /// Examining yourself, when the game has neither set a description on
    /// `player.item` nor given it a `describe { }` rule.
    public var selfDescription: Line<Nothing> = "You look much as you always do."

    /// Taking yourself. The stock person's refusal reads as though somebody
    /// else were involved, so the player gets their own line.
    public var cantTakeSelf: Line<Nothing> = "You have yourself well in hand already."

    /// Searching yourself. Nothing is turned out, because the player's
    /// pockets are the inventory and `i` already reports them.
    public var cantSearchSelf: Line<Nothing> = "You pat yourself down and find only what you're carrying."

    /// Greeting yourself.
    public var cantGreetSelf: Line<Nothing> = "You and yourself have already met."

    /// Following yourself.
    public var cantFollowSelf: Line<Nothing> = "You are already right here."

    // MARK: - Stub verbs

    /// The stock replies for the verbs the parser knows as words but the engine
    /// gives no mechanic. Re-skin one with `text.stubs.dig = "…"`; give one real
    /// behavior with a rule or an `actions` row.
    public var stubs = StubReplies()

    // MARK: - Parser replies

    /// A word outside the game's whole vocabulary.
    public var unknownWord: Line<Word> = .naming {
        "I don't know the word \"\($0)\"."
    }

    /// A pronoun ("it", "them") with nothing bound to it yet.
    public var noReferent: Line<Word> = .naming {
        "I don't know what \"\($0)\" refers to."
    }

    /// Known words that name nothing currently in view.
    public var cantSeeAnySuchThing: Line<Nothing> = "You can't see any such thing."
    /// A line no verb pattern fits.
    public var didntUnderstand: Line<Nothing> = "I didn't understand that sentence."

    /// Stage 4's last resort: a verb row matched, so the parser understood the
    /// sentence, but nothing in the game answers this intent — no action, no
    /// rule, no stub line. Distinct from ``didntUnderstand``, which is the
    /// parser's own failure, and free for the same reason: nothing happened.
    public var cantDoThat: Line<Nothing> = "You can't do that."

    /// Giving an order to somebody who doesn't take them — `butler, open the
    /// door`. Obeying is a mechanic a game writes, one character at a time
    /// (see ``takesOrders``), so anybody who hasn't opted in hears you out and
    /// declines. `butler, hello` is the one addressed form that always does
    /// something, and it becomes a GREET.
    public var notTakingOrders: Line<Noun> = .naming {
        "\($0.sentenceCased) \($0.verb("has", "have")) no intention of taking orders from you."
    }

    /// An order to somebody who *does* take them that nothing in the game
    /// answers — ``cantDoThat`` in the third person. The engine's own default
    /// actions are all written for the player and never run for somebody else,
    /// so an order happens only where a rule makes it happen. Free, for the
    /// same reason `cantDoThat` is: nothing happened.
    public var doesNotKnowHow: Line<Noun> = .naming {
        "\($0.sentenceCased) \($0.verb("does", "do")) not know how to do that."
    }

    /// A verb missing its object — answerable on the next line.
    public var missingObject: Line<Prompt> = .naming {
        "What do you want to \($0.verb)?"
    }

    /// A verb missing its second object — answerable on the next line.
    public var missingIndirect: Line<Prompt> = .naming {
        "What do you want to \($0.verb) \($0.object ?? "") \($0.preposition)?"
    }

    /// A verb missing its topic — answerable on the next line. The object and
    /// the word introducing the subject are both optional, so one line covers
    /// "ask the butler about", "think about", and a bare "mutter".
    public var missingTopic: Line<Prompt> = .naming {
        let object = $0.object.map { " \($0)" } ?? ""
        let about = $0.preposition.isEmpty ? "" : " \($0.preposition)"
        return "What do you want to \($0.verb)\(object)\(about)?"
    }

    /// A verb that takes a noun and a direction, given only the noun —
    /// answerable on the next line, because the direction ends the pattern.
    public var missingDirection: Line<Prompt> = .naming {
        "Which way do you want to \($0.verb) \($0.object ?? "")?"
    }

    /// A noun phrase matching several things — answerable on the next line.
    public var ambiguous: Line<Choices> = .naming {
        "Which do you mean: \($0.names.joined(separator: " or "))?"
    }

    // MARK: - Multi-object commands

    /// "all"/"them" in the indirect slot, where only one object fits.
    public var multipleNotAllowedThere: Line<Nothing> = "You can't use multiple objects there."
    /// "take all" with nothing eligible to take.
    public var nothingToTakeHere: Line<Nothing> = "There is nothing here to take."
    /// "drop all" (or "put all …") with nothing carried.
    public var notCarryingAnything: Line<Nothing> = "You aren't carrying anything."
    /// The group had things in it and the subtraction emptied it — `take all
    /// but the coin` where the coin was the only thing on offer, or `put all in
    /// the sack` where the sack is all you are carrying. Neither line above is
    /// true of where that player is standing.
    public var nothingLeftOfTheGroup: Line<Nothing> = "That leaves nothing at all."

    /// "all"/"them" with a verb that only handles one object at a time.
    public var multipleNotAllowedWith: Line<Word> = .naming {
        "You can't use multiple objects with \"\($0)\"."
    }

    // MARK: - Formatting helpers

    /// The name with its definite article ("the velvet cloak"), or the name
    /// alone when it is a proper name ("Mrs. Vane").
    ///
    /// The engine calls this — and ``indefinite(_:proper:)`` — *before* it
    /// reaches a line's closure, which is why every template above interpolates
    /// a finished phrase rather than putting an article in front of a bare
    /// name. A custom closure receives the same finished phrase; these statics
    /// are here for lines that build a phrase of their own.
    ///
    /// - Parameters:
    ///   - name: the bare name to article.
    ///   - proper: whether the name is a proper name, in which case it is
    ///     returned unchanged.
    /// - Returns: the rendered noun phrase.
    public static func definite(_ name: String, proper: Bool = false) -> String {
        proper ? name : "the \(name)"
    }

    /// The name with its indefinite article, for listings ("a velvet cloak",
    /// "an apple", "some rails"), or the name alone when it is a proper name
    /// ("Mrs. Vane").
    ///
    /// - Parameters:
    ///   - name: the bare name to article.
    ///   - proper: whether the name is a proper name, in which case it is
    ///     returned unchanged.
    ///   - plural: whether the name is grammatically plural, which takes
    ///     "some" — English has no plural indefinite article of its own.
    /// - Returns: the rendered noun phrase.
    public static func indefinite(
        _ name: String, proper: Bool = false, plural: Bool = false
    )
        -> String
    {
        if proper {
            name
        } else if plural {
            "some \(name)"
        } else if let first = name.lowercased().first, "aeiou".contains(first) {
            "an \(name)"
        } else {
            "a \(name)"
        }
    }

    /// Joins already-rendered phrases into an English list ("a Y", "a Y and a
    /// Z", "a Y, a Z, and a W"). The articles are the caller's, since only the
    /// caller knows which of them are proper names.
    ///
    /// This one returns a `String` and so forgets what number the list came out
    /// as. Reach for ``Noun/list(_:)`` instead wherever a verb has to agree with
    /// the result — that is the whole difference between them, and the reason
    /// "In the hamper is some scales." was ever printed.
    ///
    /// - Parameter phrases: the rendered phrases to join.
    /// - Returns: the phrases joined into an English list.
    public static func list(_ phrases: [String]) -> String {
        guard let last = phrases.last else { return "" }
        switch phrases.count {
        case 1: return last
        case 2: return "\(phrases[0]) and \(last)"
        default:
            let allButLast = phrases.dropLast().joined(separator: ", ")
            return "\(allButLast), and \(last)"
        }
    }

    /// A phrase with its first letter capitalized, for a line that opens on
    /// one. "the troll" becomes "The troll"; "Mrs. Vane" is already right.
    ///
    /// - Parameter phrase: the rendered phrase to capitalize.
    /// - Returns: the phrase, sentence-cased.
    public static func sentenceCase(_ phrase: String) -> String {
        phrase.prefix(1).uppercased() + phrase.dropFirst()
    }
}

extension GameText {
    /// The stock replies for stub verbs — the words the parser knows even where
    /// the game has no mechanic behind them. Reached as `text.stubs.dig`.
    ///
    /// These are the engine's floor, not its ceiling. Overriding a line re-skins
    /// it; a rule or an `actions` row replaces it with behavior. Both are
    /// expected, and neither warns.
    ///
    /// A line with an object to name is a ``GameText/Line``, which takes a bare
    /// string as readily as a naming closure — so whether a stub says what the
    /// player was pointing at is the game's call rather than a shape the engine
    /// picked. `Line<Noun>` where every row carries an object, `Line<Noun?>`
    /// where the line owns a nameless half as well, `Line<Nothing>` for a verb with
    /// no object slot on any row — that last one has no name to be handed, but
    /// it still prints in a turn, so ``GameText/Line/live(_:)`` is open to it
    /// like any other line.
    ///
    /// A `Line` is handed a ``GameText/Noun`` and never a bare name, so a line
    /// whose verb agrees with the object can conjugate for itself. A template
    /// that hard-codes the agreement makes a game's honest plural noun
    /// ungrammatical — "The rails is not food." — and the game's only escape
    /// would be to rename the thing, which is a mine lying about itself to make
    /// a stub line scan. See the `plural` trait. Interpolating a `Noun` prints
    /// its phrase, so a line with no verb to agree pays nothing for this.
    ///
    /// ``give`` is the one line about *two* objects, and takes a ``Gift``.
    public struct StubReplies: Sendable {
        /// The classic replies. Build one and mutate the lines you want to
        /// change; ``GameText`` already holds a default instance.
        public init() {}

        /// A stub verb aimed at yourself, where the verb's own line would have
        /// named its object. The player item is called "yourself", so those
        /// lines would read "The yourself is not food." — one line covers all of
        /// them rather than fifteen self-specific variants.
        public var yourself: Line<Nothing> = "Best leave yourself out of it."

        /// A stub verb aimed at somebody else, where the verb would otherwise
        /// have reported a completed act on a person — "The cook is not food.",
        /// "You feel nothing out of the ordinary." about a witness. Every stub
        /// that has to *reach* its object goes through this, so one line covers
        /// all of them, the way ``yourself`` does.
        ///
        /// It is deliberately close in shape to ``GameText/cantTakeActor`` and
        /// ``GameText/cantSearchActor``, which have always refused this way: a
        /// game that re-skins one usually wants all three in the same voice.
        public var somebodyElse: Line<Noun> = .naming {
            "\($0.sentenceCased) \($0.verb("is", "are")) a person, and would rather you didn't."
        }

        // MARK: Violence and force

        /// Attacking something with no combat behind it. Names the object,
        /// because the refusal is about the thing swung at and a line that
        /// only says "things" reads as a house rule rather than an answer.
        public var attack: Line<Noun> = .naming {
            "Attacking \($0) rarely improves matters."
        }
        /// Breaking, smashing or destroying something.
        public var smash: Line<Noun> = .naming {
            "\($0.sentenceCased) \($0.verb("is", "are")) sturdier than that."
        }
        /// Setting fire to something.
        public var burn: Line<Noun> = .naming {
            "You have no way to set fire to \($0)."
        }
        /// Cutting or slicing something.
        public var cut: Line<Noun> = .naming {
            "You have nothing to cut \($0) with."
        }
        /// Digging, with or without a tool. The bare `dig` names nothing.
        public var dig: Line<Noun?> = "You have nothing to dig with."
        /// Pulling or dragging something.
        public var pull: Line<Noun> = .naming {
            "\($0.sentenceCased) \($0.verb("doesn't", "don't")) budge."
        }
        /// Turning something that doesn't turn. Names the object so the reply
        /// doesn't read as a failed `turn on`.
        public var turn: Line<Noun> = .naming {
            "\($0.sentenceCased) \($0.verb("doesn't", "don't")) turn."
        }
        /// Squeezing something.
        public var squeeze: Line<Noun> = .naming {
            "Squeezing \($0) changes nothing."
        }
        /// Shaking something.
        public var shake: Line<Noun> = .naming {
            "You shake \($0). Nothing rattles loose."
        }
        /// Knocking on something.
        public var knock: Line<Noun?> = "Nobody answers."
        /// Throwing something at something else. Offered the *projectile's*
        /// name; see the row for why not the target's.
        public var throwAt: Line<Noun?> = "Throwing things about achieves nothing."

        // MARK: Senses

        /// Touching, feeling or rubbing something. The one sense verb that
        /// still defers about a person: laying hands on somebody is not the
        /// same as listening to them.
        public var touch: Line<Noun?> = "You feel nothing out of the ordinary."
        /// Smelling the room or something in it. The bare `smell` names nothing.
        public var smell: Line<Noun?> = "You smell nothing out of the ordinary."
        /// Listening to the room or something in it. The bare `listen` names
        /// nothing.
        public var listen: Line<Noun?> = "You hear nothing out of the ordinary."
        /// Tasting or licking something.
        public var taste: Line<Noun?> = "You'd rather not."

        // MARK: Body

        /// Eating something inedible.
        public var eat: Line<Noun> = .naming {
            "\($0.sentenceCased) \($0.verb("is", "are")) not food."
        }
        /// Drinking something undrinkable.
        public var drink: Line<Noun?> = "There's nothing here worth drinking."
        /// Going to sleep.
        public var sleep: Line<Nothing> = "You're not sleepy."
        /// Waking, or waking somebody who isn't asleep. The bare `wake` and
        /// `wake up` name nothing.
        public var wake: Line<Noun?> = "There's no sleeping to be interrupted."

        // MARK: Social

        /// Kissing or hugging somebody. Offered their name, unlike everywhere
        /// else a stub reaches a person, because kissing somebody is what the
        /// verb is for; the engine's own wording declines it.
        public var kiss: Line<Noun?> = "That would be presumptuous."
        /// Handing something to somebody who doesn't want it. Names both, since
        /// every row carries both slots.
        public var give: Line<Gift> = .naming {
            let who = $0.recipient
            return "\(who.sentenceCased) \(who.verb("doesn't", "don't")) want \($0.gift)."
        }
        /// Yelling, shouting or screaming.
        public var yell: Line<Nothing> = "You shout. Nothing shouts back."
        /// Waving, with or without something in hand. The bare `wave` names
        /// nothing.
        public var wave: Line<Noun?> = "You wave. Nothing comes of it."
        /// Pointing at something.
        public var point: Line<Noun?> = "Pointing at things accomplishes little."

        // MARK: Motion

        /// Climbing something unclimbable. The bare `climb` names nothing.
        public var climb: Line<Noun?> = "You can't climb that."
        /// Jumping, on the spot or over something. The bare `jump` names
        /// nothing.
        public var jump: Line<Noun?> = "You jump on the spot. Nothing is achieved."
        /// Swimming with no water to swim in.
        public var swim: Line<Nothing> = "There's nothing here to swim in."
        /// Diving with nothing to dive into.
        public var dive: Line<Nothing> = "There's nothing here to dive into."
        /// Standing when already upright.
        public var stand: Line<Nothing> = "You're already standing."
        /// Sitting with nowhere to sit. The bare `sit` and `sit down` name
        /// nothing.
        public var sit: Line<Noun?> = "There's nothing comfortable to sit on."
        /// Lying down.
        public var lie: Line<Nothing> = "The floor doesn't look inviting."
        /// Kneeling.
        public var kneel: Line<Nothing> = "You kneel. Nothing takes notice."

        // MARK: Liquids and containers

        /// Filling something with nothing to fill it from.
        public var fill: Line<Noun> = .naming {
            "There's nothing here to fill \($0) from."
        }
        /// Pouring something that holds nothing.
        public var pour: Line<Noun> = .naming {
            "There's nothing in \($0) to pour."
        }
        /// Emptying something that holds nothing.
        public var empty: Line<Noun> = .naming {
            "There's nothing in \($0) to empty out."
        }
        /// Tying something with nothing to tie it to.
        public var tie: Line<Noun> = .naming {
            "There's nothing here to tie \($0) to."
        }
        /// Untying something that isn't tied.
        public var untie: Line<Noun> = .naming {
            "\($0.sentenceCased) \($0.verb("isn't", "aren't")) tied to anything."
        }

        // MARK: Ritual and flavor

        /// Praying.
        public var pray: Line<Nothing> = "Your prayers go unanswered."
        /// Singing.
        public var sing: Line<Nothing> = "Your singing is better kept to yourself."
        /// Cursing or swearing.
        public var curse: Line<Nothing> = "Nobody here is offended."
        /// The magic words, `xyzzy` and `plugh`, where they mean nothing.
        public var xyzzy: Line<Nothing> = "Nothing happens."
        /// Counting something.
        public var count: Line<Noun?> = "You lose count."
        /// Thinking.
        public var think: Line<Nothing> = "You think. Nothing occurs to you."
        /// Wishing.
        public var wish: Line<Nothing> = "Wishing doesn't make it so."

        // MARK: Commerce

        /// Buying where nothing is sold.
        public var buy: Line<Noun?> = "Nothing here is for sale."
        /// Selling where nobody buys.
        public var sell: Line<Noun?> = "Nobody here is buying."

        // MARK: Fixtures

        /// Blowing on something. Distinct from `blow out`, which is `turnOff`.
        public var blow: Line<Noun> = .naming {
            "Blowing on \($0) has no effect."
        }
    }
}
