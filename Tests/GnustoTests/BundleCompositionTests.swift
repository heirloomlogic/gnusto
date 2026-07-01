import Testing

@testable import Gnusto

/// Phase 2 — declaration modularity. Proves a game can be composed from
/// independent content bundles: each bundle's rooms, items, rules, and verbs
/// register and take effect, cross-bundle geography resolves, `EntityID`s are
/// the bare property names, and a name claimed by two bundles is a fatal error.
struct BundleCompositionTests {
    @Test func rulesFromEveryBundleFire() async throws {
        let transcript = try await play(
            BundleGame(),
            ["examine trunk", "down", "examine coin"])

        // The attic bundle's rule, the move down into the cellar (the
        // cross-bundle exit), and the cellar bundle's rule all fire, in order.
        expectInOrder(transcript, ["[attic]", "Cellar Vault", "[cellar]"])
    }

    @Test func crossBundleExitTraversesBothWays() async throws {
        let transcript = try await play(BundleGame(), ["down", "up"])

        // Down reaches the cellar, up returns to the attic.
        expectInOrder(transcript, ["Cellar Vault", "Attic Hall"])
    }

    @Test func bundleVerbParsesAndItsRuleFires() async throws {
        // `rummage` is taught by the attic bundle, not the game.
        let transcript = try await play(BundleGame(), ["rummage trunk"])
        expectInOrder(transcript, ["[attic] You rummage through the trunk"])
    }

    @Test func bundleEntitiesUseBarePropertyNameIDs() throws {
        let (definition, state) = try Bootstrap.build(BundleGame())

        // Rooms and items keep their bare property names as IDs, regardless of
        // which bundle declared them.
        #expect(definition.locations[EntityID("hall")] != nil)
        #expect(definition.locations[EntityID("vault")] != nil)
        #expect(definition.items[EntityID("trunk")] != nil)
        #expect(definition.items[EntityID("coin")] != nil)

        // The cross-bundle exit resolved, and each bundle's placement applied.
        #expect(definition.exits[EntityID("hall")]?[.down] != nil)
        #expect(definition.exits[EntityID("vault")]?[.up] != nil)
        #expect(state.placements[EntityID("trunk")] == .room(EntityID("hall")))
        #expect(state.placements[EntityID("coin")] == .room(EntityID("vault")))
    }

    @Test func collidingEntityIDIsFatalAndNamesBothBundles() throws {
        do {
            _ = try Bootstrap.build(CollidingBundleGame())
            Issue.record("expected a BootstrapError for the colliding EntityID")
        } catch let error as BootstrapError {
            #expect(
                error.diagnostics.contains {
                    $0.contains("declared by both")
                        && $0.contains("AlphaBundle")
                        && $0.contains("BetaBundle")
                })
        }
    }
}
