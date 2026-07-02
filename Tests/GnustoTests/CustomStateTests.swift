import Foundation
import Testing

@testable import Gnusto

/// Phase 3 — extensible state & traits. Proves a `@Global` can carry a whole
/// custom `Codable` struct (boxed into the type-erased `StateValue.data` case)
/// that survives save/restore, and that items/locations can declare custom
/// traits read back through a typed accessor — all without the engine ever
/// branching on the new open cases.
struct CustomStateTests {
    // MARK: - Custom struct globals

    @Test func customStructGlobalDefaultIsBoxedAsData() throws {
        let (definition, _) = try Bootstrap.build(ShopGame())
        guard case .data(let typeName, _)? = definition.globalDefaults[EntityID("purse")]
        else {
            Issue.record("purse default should be boxed into the .data case")
            return
        }
        #expect(typeName.contains("Purse"))
    }

    @Test func customStructGlobalRoundTripsThroughSave() throws {
        // Start from a real initial WorldState, store a mutated Purse, then
        // encode and decode the whole state as save/restore would.
        let (_, initialState) = try Bootstrap.build(ShopGame())
        var state = initialState
        let purse = Purse(coins: 3)
        state.globals[EntityID("purse")] = purse.stateValue

        let data = try JSONEncoder().encode(state)
        let restored = try JSONDecoder().decode(WorldState.self, from: data)

        let stored = try #require(restored.globals[EntityID("purse")])
        #expect(Purse(stateValue: stored) == purse)
    }

    @Test func customStructGlobalIsReadAndWrittenDuringPlay() async throws {
        // First buy debits the purse (10 → 5); the second, still affordable,
        // debits again (5 → 0), proving the mutated struct persists across turns.
        let transcript = try await play(ShopGame(), ["buy lantern", "buy lantern"])
        expectInOrder(
            transcript,
            [
                "You buy the brass lantern for 5 coins. You have 5 left.",
                "You buy the brass lantern for 5 coins. You have 0 left.",
            ])
    }

    @Test func customStructGlobalGatesBehaviorWhenExhausted() async throws {
        // Three buys at 5 coins from a 10-coin purse: the third is refused.
        let transcript = try await play(
            ShopGame(), ["buy lantern", "buy lantern", "buy lantern"])
        #expect(transcript.contains("You can't afford the brass lantern; it costs 5 coins."))
    }

    // MARK: - Custom traits

    @Test func customTraitIsStoredOnTheDefinition() throws {
        let (definition, _) = try Bootstrap.build(ShopGame())
        #expect(definition.items[EntityID("lantern")]?.customTraits["price"] == .int(5))
    }

    @Test func customTraitReadsBackThroughTypedAccessor() async throws {
        // The buy rule reads the price via `lantern[.price]`; the "5 coins"
        // in the reply is that read-back value.
        let transcript = try await play(ShopGame(), ["buy lantern"])
        expectInOrder(transcript, ["for 5 coins"])
    }

    @Test func absentOrWrongTypeCustomTraitReturnsNil() async throws {
        // The sign has a `weight` (Int) trait but no `price`. Reading a missing
        // key and reading `weight` as the wrong type both yield nil.
        let transcript = try await play(TraitProbeGame(), ["examine sign"])
        #expect(transcript.contains("missing=nil wrongType=nil"))
    }
}
