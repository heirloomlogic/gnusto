/// One piece of game logic: a phase, an owner, the intents it watches, and a
/// synchronous body that reads and writes the world through proxies.
public struct Rule: Sendable {
    enum Scope: Sendable {
        case item(RefToken)
        case location(RefToken)
        case world
    }

    enum Phase: Sendable {
        /// Runs before the default action; may `refuse`/`reply` to stop it.
        case before
        /// Runs after the default action succeeded.
        case after
        /// Runs at the start of every turn spent in the location.
        case beforeEachTurn
        /// Runs at the end of every turn spent in the location — even turns
        /// that were refused (world time still passes).
        case afterEachTurn
        /// Runs when the player enters the location.
        case onEnter
        /// Supplies a live description via `describe { … }`. Unlike every other
        /// phase, its work is in `describeBody` (which returns the text), not
        /// `body`; Bootstrap files it into the rule table's describe slots.
        case describe
        /// Supplies a live room-listing paragraph via `presence { … }`. Same
        /// shape as `.describe` — the work is in `describeBody` — but it feeds
        /// the room description's mention of the entity rather than its
        /// examine text.
        case presence
        /// Answers "can the player put a hand on this from where they are
        /// standing" via `reach { … }`. Its work is in `reachRule`, not `body`.
        case reach
    }

    let scope: Scope
    let phase: Phase
    /// Empty means "any intent".
    let intents: Set<Intent>
    let body: @Sendable () throws -> Void
    /// The text-returning body of a `.describe` or `.presence` rule; `nil` for
    /// every other phase.
    var describeBody: (@Sendable () -> String)? = nil
    /// The predicate of a `.reach` rule, and the line it refuses with; `nil` for
    /// every other phase.
    var reachRule: Reach.Rule? = nil

    func matches(_ intent: Intent) -> Bool {
        intents.isEmpty || intents.contains(intent)
    }

    /// A copy of this rule whose body runs with `namespace` bound as the
    /// owning bundle (``Ctx/owned(_:_:)``), so timer helpers inside resolve
    /// bare timer names against the owner's declarations. The game's own
    /// rules (`nil`) come back unchanged.
    func owned(by namespace: String?) -> Rule {
        guard let namespace else { return self }
        let body = self.body
        return Rule(
            scope: scope, phase: phase, intents: intents,
            body: { try Ctx.owned(namespace, body) },
            describeBody: describeBody, reachRule: reachRule)
    }
}

/// The collected rules of a game, declared in one `rules` block. Large games
/// compose: `var rules: Rules { cloakRules; barRules }`.
public struct Rules: Sendable {
    let rules: [Rule]
}
