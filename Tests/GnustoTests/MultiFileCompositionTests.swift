import GnustoTestSupport
import Testing

@testable import Gnusto

/// Proves the Phase 0 claim: one game can be authored across several files.
/// `SplitGame` declares its entities in `SplitGame.swift` but composes its
/// `map` and `rules` from fragments defined in `SplitGame+Garden.swift` and
/// `SplitGame+House.swift`. These tests confirm that map entries and rules
/// from *every* file take effect at runtime.
struct MultiFileCompositionTests {
    @Test func rulesFromEveryFileFire() async throws {
        let transcript = try await play(
            SplitGame(),
            ["examine rose", "east", "examine key"])

        // The garden rule (SplitGame+Garden.swift), the move into the cottage
        // (geography from both fragments), and the house rule
        // (SplitGame+House.swift) all fire, in order.
        expectInOrder(transcript, ["[garden]", "snug stone cottage", "[house]"])
    }

    @Test func mapFragmentsFromEveryFileApply() throws {
        let (definition, state) = try Bootstrap.build(SplitGame())

        // Exit declared in the garden fragment.
        #expect(definition.exits[EntityID("garden")]?[.east] != nil)
        // Exit declared in the house fragment.
        #expect(definition.exits[EntityID("cottage")]?[.west] != nil)
        // Placements contributed by each fragment.
        #expect(state.placements[EntityID("rose")] == .room(EntityID("garden")))
        #expect(state.placements[EntityID("key")] == .room(EntityID("cottage")))
    }
}
