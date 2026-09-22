/// Rules that apply everywhere, declared through the `world` identifier in a
/// `rules` block:
///
/// ```swift
/// world.beforeEachTurn { lanternFuel -= 1 }
/// ```
///
/// World `before` rules run before any location or item `before` rules; world
/// `after` rules run after the item and location `after` rules, and are skipped
/// on a turn those are skipped on. World `afterEachTurn` rules run after the
/// location's `afterEachTurn` rules.
public struct World: Sendable {
    /// Runs at the start of every turn, anywhere.
    ///
    /// - Parameter body: the rule body.
    /// - Returns: the assembled rule.
    public func beforeEachTurn(
        perform body: @escaping @Sendable () throws -> Void
    ) -> Rule {
        Rule(scope: .world, phase: .beforeEachTurn, intents: [], body: body)
    }

    /// Runs at the end of every turn, anywhere — including refused turns.
    ///
    /// - Parameter body: the rule body.
    /// - Returns: the assembled rule.
    public func afterEachTurn(
        perform body: @escaping @Sendable () throws -> Void
    ) -> Rule {
        Rule(scope: .world, phase: .afterEachTurn, intents: [], body: body)
    }

    /// Runs before the default action whenever the named intents are
    /// attempted, anywhere.
    ///
    /// - Parameters:
    ///   - intents: the intents this rule reacts to.
    ///   - body: the rule body.
    /// - Returns: the assembled rule.
    public func before(
        _ intents: Intent...,
        perform body: @escaping @Sendable () throws -> Void
    ) -> Rule {
        Rule(scope: .world, phase: .before, intents: Set(intents), body: body)
    }

    /// Runs after the default action whenever the named intents succeed,
    /// anywhere.
    ///
    /// - Parameters:
    ///   - intents: the intents this rule reacts to.
    ///   - body: the rule body.
    /// - Returns: the assembled rule.
    public func after(
        _ intents: Intent...,
        perform body: @escaping @Sendable () throws -> Void
    ) -> Rule {
        Rule(scope: .world, phase: .after, intents: Set(intents), body: body)
    }
}
