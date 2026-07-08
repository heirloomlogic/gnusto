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
    }

    let scope: Scope
    let phase: Phase
    /// Empty means "any intent".
    let intents: Set<Intent>
    let body: @Sendable () throws -> Void
    /// The text-returning body of a `.describe` rule; `nil` for every other
    /// phase.
    var describeBody: (@Sendable () -> String)? = nil

    func matches(_ intent: Intent) -> Bool {
        intents.isEmpty || intents.contains(intent)
    }
}

/// The collected rules of a game, declared in one `rules` block. Large games
/// compose: `var rules: Rules { cloakRules; barRules }`.
public struct Rules: Sendable {
    let rules: [Rule]
}
