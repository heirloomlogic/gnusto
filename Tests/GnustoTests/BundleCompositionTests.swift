import Testing

@testable import Gnusto

/// Phase 2 — declaration modularity. Proves a game can be composed from
/// independent content bundles: each bundle's rooms, items, rules, and verbs
/// register and take effect, cross-bundle geography resolves, each bundle's
/// `EntityID`s are namespaced by the bundle (Phase 4b), and two bundles that
/// share a namespace *and* a property name are a fatal collision.
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

    @Test func bundleEntitiesAreNamespacedByBundleType() throws {
        let (definition, state) = try Bootstrap.build(BundleGame())

        // Each bundle's rooms and items are namespaced by the bundle's type, so
        // a reusable bundle can't collide with the host or another bundle.
        #expect(definition.locations[EntityID("AtticContent.hall")] != nil)
        #expect(definition.locations[EntityID("CellarContent.vault")] != nil)
        #expect(definition.items[EntityID("AtticContent.trunk")] != nil)
        #expect(definition.items[EntityID("CellarContent.coin")] != nil)

        // The cross-bundle exit and each bundle's placement still resolve — the
        // authoring site references tokens, so the namespace is transparent.
        #expect(definition.exits[EntityID("AtticContent.hall")]?[.down] != nil)
        #expect(definition.exits[EntityID("CellarContent.vault")]?[.up] != nil)
        #expect(
            state.placements[EntityID("AtticContent.trunk")]
                == .room(EntityID("AtticContent.hall")))
        #expect(
            state.placements[EntityID("CellarContent.coin")]
                == .room(EntityID("CellarContent.vault")))
    }

    @Test func sameNamespaceCollisionIsFatal() throws {
        // Two instances of the same bundle type share the default (type-name)
        // namespace, so their identical property names collide — the backstop a
        // host escapes by overriding `namespace` per instance.
        do {
            _ = try Bootstrap.build(CollidingBundleGame())
            Issue.record("expected a BootstrapError for the colliding EntityID")
        } catch let error as BootstrapError {
            #expect(
                error.diagnostics.contains {
                    $0.contains("declared by both")
                        && $0.contains("AlphaBundle.foyer")
                })
        }
    }
}
