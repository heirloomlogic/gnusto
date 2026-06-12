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
    }

    let scope: Scope
    let phase: Phase
    /// Empty means "any intent".
    let intents: Set<Intent>
    let body: @Sendable () throws -> Void

    func matches(_ intent: Intent) -> Bool {
        intents.isEmpty || intents.contains(intent)
    }
}

/// The collected rules of a game, declared in one `rules` block. Large games
/// compose: `var rules: Rules { cloakRules; barRules }`.
public struct Rules: Sendable {
    let rules: [Rule]
}

@resultBuilder
public enum RuleBuilder {
    public static func buildExpression(_ rule: Rule) -> [Rule] {
        [rule]
    }

    public static func buildExpression(_ rules: Rules) -> [Rule] {
        rules.rules
    }

    public static func buildBlock(_ rules: [Rule]...) -> Rules {
        Rules(rules: rules.flatMap(\.self))
    }

    public static func buildOptional(_ rules: [Rule]?) -> [Rule] {
        rules ?? []
    }

    public static func buildEither(first rules: [Rule]) -> [Rule] {
        rules
    }

    public static func buildEither(second rules: [Rule]) -> [Rule] {
        rules
    }

    public static func buildArray(_ rules: [[Rule]]) -> [Rule] {
        rules.flatMap(\.self)
    }
}
