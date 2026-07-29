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

    @Global var knowledge = Knowledge()

    /// What an actor with no matching row and no fallback says.
    private let nothingToSayLine: @Sendable (String) -> String
    /// The refusal for trying to talk to something inanimate.
    private let cantTalkToLine: String
    /// What an actor says about a thing shown to them that no row covers.
    private let noInterestLine: @Sendable (String) -> String

    /// Creates a conversation layer.
    ///
    /// - Parameters:
    ///   - nothingToSay: what an actor with no matching row and no fallback
    ///     says, given their name.
    ///   - cantTalkTo: the refusal for addressing something inanimate.
    ///   - noInterest: what an actor says about a thing shown to them that no
    ///     `shows(_:to:)` row covers, given their name.
    public init(
        nothingToSay: @escaping @Sendable (_ name: String) -> String = {
            "The \($0) has nothing to say about that."
        },
        cantTalkTo: String = "You can only talk to something animate.",
        noInterest: @escaping @Sendable (_ name: String) -> String = {
            "The \($0) shows no interest."
        }
    ) {
        self.nothingToSayLine = nothingToSay
        self.cantTalkToLine = cantTalkTo
        self.noInterestLine = noInterest
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
    ///   - entries: the rows, most specific first.
    /// - Returns: the before-phase rules, for the host's `rules` block.
    @RuleBuilder
    public func topics(
        of actor: Actor,
        for intents: [Intent] = [.ask, .tell],
        fallback: String? = nil,
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
                if let taught = row.taught { learn(taught) }
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

    // MARK: - GameContent

    /// The verbs the layer contributes: `ask`, `tell` and `show`.
    public var verbs: [SyntaxRule] { [.ask, .tell, .show] }

    /// The layer's default actions — what happens when no table answered.
    public var actions: [IntentAction] {
        action(.ask) { try shrug() }
        action(.tell) { try shrug() }
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
