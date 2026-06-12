/// Rules that apply everywhere, declared through the `world` identifier in a
/// `rules` block:
///
/// ```swift
/// world.beforeEachTurn { lanternFuel -= 1 }
/// ```
///
/// World `before` rules run before any location or item rules; world `after`
/// rules run at the very end of the turn, after location each-turn rules.
public struct World: Sendable {
    init() {}

    /// Runs at the start of every turn, anywhere.
    public func beforeEachTurn(
        perform body: @escaping @Sendable () throws -> Void
    ) -> Rule {
        Rule(scope: .world, phase: .beforeEachTurn, intents: [], body: body)
    }

    /// Runs at the end of every turn, anywhere — including refused turns.
    public func afterEachTurn(
        perform body: @escaping @Sendable () throws -> Void
    ) -> Rule {
        Rule(scope: .world, phase: .afterEachTurn, intents: [], body: body)
    }

    /// Runs before the default action whenever the named intents are
    /// attempted, anywhere.
    public func before(
        _ intents: Intent...,
        perform body: @escaping @Sendable () throws -> Void
    ) -> Rule {
        Rule(scope: .world, phase: .before, intents: Set(intents), body: body)
    }

    /// Runs after the default action whenever the named intents succeed,
    /// anywhere.
    public func after(
        _ intents: Intent...,
        perform body: @escaping @Sendable () throws -> Void
    ) -> Rule {
        Rule(scope: .world, phase: .after, intents: Set(intents), body: body)
    }
}
