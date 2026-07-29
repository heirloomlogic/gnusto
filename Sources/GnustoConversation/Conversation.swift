import Gnusto

extension Intent {
    /// Draw a subject out of somebody: `ask the butler about the murder`.
    #verb("ask", ["ask", .directObject, "about", .topic])
    /// Volunteer a subject to somebody: `tell the butler about the letter`.
    #verb("tell", ["tell", .directObject, "about", .topic])
    /// Put a thing in front of somebody: `show the letter to the butler`.
    ///
    /// An ordinary two-object row — a thing is a thing, so this needs no
    /// topic slot. Note the dative (`show butler the letter`) is not
    /// expressible: two object slots can't sit side by side.
    #verb("show", ["show", .directObject, "to", .indirectObject])
    /// Open a conversation: `talk to the butler`. Distinct from the engine's
    /// ``Intent/greet`` — GREET is the hello, TALK is settling in for one —
    /// though ``Conversation/greeting(of:for:learning:reply:)`` answers both
    /// by default, so the player never has to guess which word the game wanted.
    ///
    /// Note `Sources/Lighthouse` mints an `Intent("talk")` of its own for the
    /// same word, on purpose: it is the worked example of a game reclaiming a
    /// verb. The two are the same intent by identity but live in modules that
    /// never meet in one game — don't import both into one file.
    #verb(
        "talk",
        ["talk", "to", .directObject],
        ["talk", "with", .directObject],
        ["talk", .directObject],
        ["speak", "to", .directObject],
        ["speak", "with", .directObject])
}

/// A topic-driven conversation layer: per-actor tables of subjects the player
/// can raise, gated on and feeding a saved set of *facts* — what the player
/// has worked out so far.
///
/// The knowledge lives in a `@Global`, so it survives save, restore and UNDO
/// with no work from the game. What the layer is really for is the shape
/// every mystery needs and nothing in the engine offered: an actor who says
/// one thing until you can prove otherwise, and something else afterwards.
///
/// ```swift
/// let talk = Conversation()
///
/// extension Fact {
///     static let sawTheLetter = Fact("sawTheLetter")
///     static let butlerConfessed = Fact("butlerConfessed")
/// }
///
/// var content: GameContents { talk }
/// var rules: Rules {
///     talk.topics(of: butler, fallback: "\"I couldn't say, sir.\"") {
///         topic("murder", "body", reply: "\"A dreadful business, sir.\"")
///
///         // The lie, and the confession that replaces it.
///         topic("alibi", "evening", unless: .sawTheLetter,
///               reply: "\"I was in the pantry all evening, sir.\"")
///         topic("alibi", "evening", knowing: .sawTheLetter, learning: .butlerConfessed,
///               reply: "\"…Very well. I was in the study.\"")
///     }
///     talk.shows(letter, to: butler, learning: .sawTheLetter,
///                reply: "He reads it, and his colour goes.")
/// }
/// ```
///
/// **Composing with `GnustoActors`.** `reaction(of:to:reply:)` is this one
/// level cruder — a before-rule that always says the same thing — and this
/// subsumes it. Both are before-rules on the same actor, so declaration order
/// decides: put a `reaction` *after* a `topics` table and it becomes the
/// catch-all; put it before and it shadows the table entirely.
public struct Conversation: GameContent {
    /// Everything the player has learned. A wrapper struct so the
    /// `GlobalValue` conformance is owned here rather than declared on a
    /// standard-library type.
    struct Knowledge: Codable, Sendable, GlobalValue {
        var facts: Set<String> = []
    }

    /// Which topic rows each actor has already given.
    ///
    /// A second `@Global` rather than a field on ``Knowledge`` on purpose: an
    /// older save simply has no entry under this ID and restores into the
    /// empty default, where a new *field* on `Knowledge` would decode-fail and
    /// trap — `Global`'s getter falls back to the default only when the ID is
    /// absent, not when a stored value fails to decode.
    struct Heard: Codable, Sendable, GlobalValue {
        var rows: Set<String> = []
    }

    @Global var knowledge = Knowledge()

    @Global var heard = Heard()

    /// What an actor with no matching row and no fallback says.
    private let nothingToSayLine: @Sendable (String) -> String
    /// The refusal for trying to talk to something inanimate.
    private let cantTalkToLine: String
    /// What an actor says about a thing shown to them that no row covers.
    private let noInterestLine: @Sendable (String) -> String
    /// What an actor with no authored greeting does when a conversation opens.
    private let nothingToTalkAboutLine: @Sendable (String) -> String

    /// Creates a conversation layer.
    ///
    /// - Parameters:
    ///   - nothingToSay: what an actor with no matching row and no fallback
    ///     says, given their name.
    ///   - cantTalkTo: the refusal for addressing something inanimate.
    ///   - noInterest: what an actor says about a thing shown to them that no
    ///     `shows(_:to:)` row covers, given their name.
    ///   - nothingToTalkAbout: what an actor with no `greeting(of:)` row does
    ///     when the player opens a conversation, given their name.
    public init(
        nothingToSay: @escaping @Sendable (_ name: String) -> String = {
            "The \($0) has nothing to say about that."
        },
        cantTalkTo: String = "You can only talk to something animate.",
        noInterest: @escaping @Sendable (_ name: String) -> String = {
            "The \($0) shows no interest."
        },
        nothingToTalkAbout: @escaping @Sendable (_ name: String) -> String = {
            "The \($0) waits for you to come to the point."
        }
    ) {
        self.nothingToSayLine = nothingToSay
        self.cantTalkToLine = cantTalkTo
        self.noInterestLine = noInterest
        self.nothingToTalkAboutLine = nothingToTalkAbout
    }

    // MARK: - Knowledge

    /// Whether the player has learned a fact. Call it from a rule body.
    ///
    /// - Parameter fact: the fact to test.
    /// - Returns: whether it has been learned.
    public func knows(_ fact: Fact) -> Bool {
        knowledge.facts.contains(fact.raw)
    }

    /// Records a fact as learned. Idempotent.
    ///
    /// - Parameter fact: the fact the player has worked out.
    public func learn(_ fact: Fact) {
        knowledge.facts.insert(fact.raw)
    }

    /// Un-learns a fact, for a game where something can be forgotten or
    /// disproved. Idempotent.
    ///
    /// - Parameter fact: the fact to take back.
    public func forget(_ fact: Fact) {
        knowledge.facts.remove(fact.raw)
    }

    // MARK: - What has already been said

    /// Whether an actor has already given the row declared with this `id:`.
    ///
    /// Rows are addressable only by `id:` — a derived key is not something an
    /// author can name — which is the third reason to give one to a row that
    /// matters.
    ///
    /// - Parameters:
    ///   - id: the row's `id:`.
    ///   - actor: whose table it is in.
    /// - Returns: whether they have given it.
    public func hasHeard(_ id: String, from actor: Actor) -> Bool {
        heard.rows.contains(Self.heardKey(id, actorName: actor.name))
    }

    /// Marks the row declared with this `id:` unheard, so the actor gives it
    /// in full the next time it is raised. Idempotent.
    ///
    /// - Parameters:
    ///   - id: the row's `id:`.
    ///   - actor: whose table it is in.
    public func unhear(_ id: String, from actor: Actor) {
        heard.rows.remove(Self.heardKey(id, actorName: actor.name))
    }

    /// Forgets everything an actor has already said, so their whole table
    /// answers in full again. Idempotent.
    ///
    /// - Parameter actor: whose memory to clear.
    public func unhearEverything(from actor: Actor) {
        let prefix = "\(actor.name)\u{1F}"
        heard.rows = heard.rows.filter { !$0.hasPrefix(prefix) }
    }

    /// The heard-set key for an explicitly identified row. Shares its shape
    /// with `TopicEntry.key(inTableOf:)` so the two cannot drift.
    private static func heardKey(_ id: String, actorName: String) -> String {
        "\(actorName)\u{1F}#\(id)"
    }

    // MARK: - Tables

    /// An actor's topic table: what they will say about what, and what they
    /// say about everything else.
    ///
    /// One rule is registered per intent, each scanning the whole table. That
    /// is what makes `fallback:` expressible at all — a per-row rule cannot
    /// know that no later row matched.
    ///
    /// - Parameters:
    ///   - actor: whose table this is. Rows fire only when this actor is the
    ///     one being addressed.
    ///   - intents: the conversation intents the table answers. Defaults to
    ///     ASK and TELL; pass a game's own verb to reuse one table for it.
    ///   - fallback: what the actor says when nothing matches. Pass `nil` (the
    ///     default) to stay quiet and let the next rule — another table, a
    ///     `GnustoActors` reaction, or this layer's own default — answer
    ///     instead.
    ///   - again: what the actor says when the player raises a subject they
    ///     have already been given in full. Opt-in and per-row overridable:
    ///     see the rules below.
    ///   - entries: the rows, most specific first.
    /// - Returns: the before-phase rules, for the host's `rules` block.
    ///
    /// ## Saying it once
    ///
    /// A row with no `again:` — neither its own nor the table's — repeats
    /// forever and records nothing, exactly as before this parameter existed.
    /// A game that never writes `again:` produces byte-identical saves.
    ///
    /// The table's `again:` retires **`reply:` rows only**. A `perform:` row
    /// opts in by naming a line of its own, because its body can move the
    /// world and adding a default to a table must never change what the world
    /// *does*, only what is *said*. A `perform:` row that does name one runs
    /// its body once; the repeat is the line alone.
    ///
    /// A row that has been heard still **matches** and still owns its keyword.
    /// It never falls through to a later row or to `fallback:` — an actor who
    /// demonstrably has an answer should not sound blank about the subject.
    /// Gating composes for free: a lie and the confession that replaces it are
    /// different rows with different keys, tracked apart.
    ///
    /// A repeat costs a turn, like any other answer.
    @RuleBuilder
    public func topics(
        of actor: Actor,
        for intents: [Intent] = [.ask, .tell],
        fallback: String? = nil,
        again: String? = nil,
        @TopicBuilder _ entries: () -> [TopicEntry]
    ) -> Rules {
        let rows = entries()
        for intent in intents {
            actor.before(intent) {
                guard let asked = command.topic else { return }
                let known = knowledge.facts
                guard
                    let row = rows.first(where: {
                        $0.answers(asked, for: intent, knowing: known)
                    })
                else {
                    if let fallback { try reply(fallback) }
                    return
                }
                // Teaching happens on every hearing, repeat or not. `learn` is
                // idempotent, so this matters only to a game that has called
                // `forget` in between, where re-teaching is the least
                // surprising thing to do.
                if let taught = row.taught { learn(taught) }
                if let line = row.again ?? (row.inheritsTableAgain ? again : nil) {
                    let key = row.key(inTableOf: actor.name)
                    // Marked *before* the body, not after: `reply` throws, so
                    // for a `reply:` row there is no "after". Moving this
                    // below `row.body()` silently disables the feature.
                    if heard.rows.contains(key) { try reply(line) }
                    heard.rows.insert(key)
                }
                try row.body()
            }
        }
    }

    /// What an actor does when a particular thing is put in front of them.
    ///
    /// - Parameters:
    ///   - item: the thing shown.
    ///   - actor: who it is shown to.
    ///   - fact: a fact the player learns by showing it — the usual way a
    ///     `knowing:` row gets unlocked.
    ///   - line: the actor's reaction. Ends the turn.
    /// - Returns: the before-phase rule, for the host's `rules` block.
    public func shows(
        _ item: Item,
        to actor: Actor,
        learning fact: Fact? = nil,
        reply line: String
    ) -> Rule {
        // Scoped on the actor rather than the item because item `before`
        // rules run indirect-object first, so this fires ahead of any rule
        // the shown item has of its own.
        actor.before(.show) {
            guard command.directObject == item else { return }
            if let fact { learn(fact) }
            try reply(line)
        }
    }

    /// What an actor says when the player opens with them — `hello butler`,
    /// `talk to the butler`, `butler, hello`.
    ///
    /// Registered as a before-rule, so it runs ahead of this layer's stage-4
    /// default and ahead of a `GnustoActors` reaction declared after it.
    ///
    /// - Parameters:
    ///   - actor: whose greeting this is.
    ///   - intents: which openings it answers. Defaults to GREET and TALK,
    ///     which is the point — the player shouldn't have to work out which
    ///     word the game wanted.
    ///   - fact: a fact the player learns by being greeted.
    ///   - again: what they say on being greeted a second time. Nobody
    ///     introduces themselves twice, and there are four ways to say hello,
    ///     so an opening line without one of these gets worn out fast.
    ///   - line: what the actor says. Ends the turn.
    /// - Returns: the before-phase rules, for the host's `rules` block.
    @RuleBuilder
    public func greeting(
        of actor: Actor,
        for intents: [Intent] = [.greet, .talk],
        learning fact: Fact? = nil,
        again: String? = nil,
        reply line: String
    ) -> Rules {
        // One key for the whole greeting, not one per intent: GREET and TALK
        // are two ways of saying the same thing, and having said it once by
        // either is having said it. `!` rather than the `#` an author-supplied
        // `id:` gets, so a row declared `id: "greeting"` doesn't retire the
        // hello and vice versa.
        let key = "\(actor.name)\u{1F}!greeting"
        for intent in intents {
            actor.before(intent) {
                if let fact { learn(fact) }
                if let again {
                    if heard.rows.contains(key) { try reply(again) }
                    heard.rows.insert(key)
                }
                try reply(line)
            }
        }
    }

    // MARK: - GameContent

    /// The verbs the layer contributes: `ask`, `tell`, `show`, `talk`, and the
    /// greeting rows the engine deliberately leaves to a conversation system —
    /// a bare hello, and the long-winded "say hello to X". (`greet <object>`,
    /// `hello <object>` and `hi <object>` are built in; bare `hello` is not,
    /// so a game can own that word outright without a launch warning.)
    public var verbs: [SyntaxRule] {
        [.ask, .tell, .show, .talk]
        SyntaxRule("hello", intent: .greet)
        SyntaxRule("hi", intent: .greet)
        SyntaxRule("say", "hello", "to", .directObject, intent: .greet)
        SyntaxRule("say", "hi", "to", .directObject, intent: .greet)
    }

    /// The layer's default actions — what happens when no table answered.
    ///
    /// Note there is no `action(.greet)`: the engine's own default is already
    /// right, and a plugin overriding a built-in intent makes every host warn
    /// at launch.
    public var actions: [IntentAction] {
        action(.ask) { try shrug() }
        action(.tell) { try shrug() }
        action(.talk) {
            guard let addressee = command.directObject else { return }
            try require(addressee.isActor, else: cantTalkToLine)
            try reply(nothingToTalkAboutLine(addressee.name))
        }
        action(.show) {
            guard let addressee = command.indirectObject else { return }
            try require(addressee.isActor, else: cantTalkToLine)
            try reply(noInterestLine(addressee.name))
        }
    }

    /// The reply when a conversation verb reached stage 4 — nobody's table
    /// had anything, and nobody had a fallback.
    private func shrug() throws {
        guard let addressee = command.directObject else { return }
        try require(addressee.isActor, else: cantTalkToLine)
        try reply(nothingToSayLine(addressee.name))
    }
}
