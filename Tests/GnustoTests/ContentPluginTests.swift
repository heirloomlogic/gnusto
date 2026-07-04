import GnustoTestSupport
import Testing

@testable import Gnusto

/// Phase 4b — content-bearing plugins with entity-ID namespacing. Proves a
/// single unit (``ShrineContent``) can both own its region (rooms/items/`@Global`,
/// auto-namespaced by the bundle) and expose a host-facing rule factory, and
/// that the namespacing lets the plugin drop into a host without colliding.
struct ContentPluginTests {
    // MARK: - End to end

    @Test func regionAndHostFactoryComposeAcrossTheNamespaceBoundary() async throws {
        // "north" crosses the host→plugin exit into the plugin's own room, firing
        // its onEnter rule (which `say`s a line and lets the room describe); then
        // "donate coin" fires the host-spliced factory over the host coin,
        // crediting the host merit with the coin's value (0 → 7).
        let transcript = try await play(PilgrimGame(), ["north", "donate coin"])
        expectInOrder(
            transcript,
            [
                "[shrine] Incense drifts past; this is visit #1.",
                "Stone Shrine",
                "You lay the brass coin in the offering bowl. Your merit rises to 7.",
            ])
    }

    // MARK: - Namespacing

    @Test func bundleEntitiesAreNamespacedWhileHostStaysBare() throws {
        let (definition, _) = try Bootstrap.build(PilgrimGame())

        // The plugin's own entities carry the namespaced ID …
        #expect(definition.locations[EntityID("ShrineContent.shrine")] != nil)
        #expect(definition.items[EntityID("ShrineContent.offeringBowl")] != nil)
        // … the plugin's private @Global is namespaced too …
        #expect(definition.globalDefaults[EntityID("ShrineContent.visits")] != nil)
        // … while the host's own entities and global keep their bare names.
        #expect(definition.locations[EntityID("plaza")] != nil)
        #expect(definition.items[EntityID("coin")] != nil)
        #expect(definition.globalDefaults[EntityID("merit")] != nil)
    }

    @Test func hostAndBundleShareALabelWithoutColliding() throws {
        // Both the host and the plugin declare a property named `bell`. Before
        // namespacing this was a fatal collision; now they coexist as distinct
        // IDs, which is what makes a content plugin genuinely drop-in.
        let (definition, _) = try Bootstrap.build(PilgrimGame())
        #expect(definition.items[EntityID("bell")] != nil)
        #expect(definition.items[EntityID("ShrineContent.bell")] != nil)
    }

    @Test func crossNamespacePlacementAndExitResolve() throws {
        let (definition, state) = try Bootstrap.build(PilgrimGame())

        // A host item placed into the plugin's room resolves to the namespaced
        // room ID (both references are token-based, so the namespace is
        // invisible at the authoring site).
        #expect(state.placements[EntityID("coin")] == .room(EntityID("ShrineContent.shrine")))
        // The host→plugin exit resolved to the namespaced room.
        if case .to(let target) = definition.exits[EntityID("plaza")]?[.north] {
            #expect(target == EntityID("ShrineContent.shrine"))
        } else {
            Issue.record("expected plaza's north exit to resolve to the shrine")
        }
    }
}
