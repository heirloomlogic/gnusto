import GnustoTestSupport
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

    /// Two instances of the same bundle type share the default (type-name)
    /// namespace, so every property name they have in common collides — the
    /// backstop a host escapes by overriding `namespace` per instance. All four
    /// entity kinds travel through one `declaredBy` map, so locations, items,
    /// actors and `@Global`s are shadowed alike, and each is named.
    @Test func sameNamespaceCollisionIsFatal() throws {
        do {
            _ = try Bootstrap.build(CollidingBundleGame())
            Issue.record("expected a BootstrapError for the colliding EntityIDs")
        } catch let error as BootstrapError {
            // `arrivals` is the `@Global`: its wrapper storage is `_arrivals`,
            // and the bootstrap strips the underscore, so the ID collides under
            // the author's own spelling.
            for id in [
                "AlphaBundle.foyer", "AlphaBundle.umbrella", "AlphaBundle.porter",
                "AlphaBundle.arrivals",
            ] {
                #expect(
                    error.diagnostics.contains {
                        $0.contains("declared by both") && $0.contains(id)
                    },
                    "no collision diagnostic named \(id)")
            }
        }
    }

    /// The shared namespace is named once, up front, with both declaring types
    /// and the remedy — the per-entity lines above say which IDs were lost, but
    /// on their own they read "declared by both AlphaBundle and AlphaBundle",
    /// which names the mistake twice and the cure not at all.
    @Test func sharedNamespaceIsReportedOnceWithBothTypesAndTheRemedy() throws {
        do {
            _ = try Bootstrap.build(CollidingBundleGame())
            Issue.record("expected a BootstrapError for the shared namespace")
        } catch let error as BootstrapError {
            let shared = error.diagnostics.filter { $0.contains("share the namespace") }
            #expect(shared.count == 1)
            #expect(shared.first?.contains("\"AlphaBundle\"") == true)
            #expect(shared.first?.contains("AlphaBundle and AlphaBundle") == true)
            #expect(shared.first?.contains("var namespace") == true)
        }
    }

    /// The regression for issue #162. Two bundles of *different* types may both
    /// declare a `lamp`: each namespaces its entities under its own type name,
    /// so neither can shadow the other and each answers with its own text.
    @Test func twoBundlesMayShareAPropertyName() async throws {
        let (definition, state) = try Bootstrap.build(BundleGame())

        #expect(definition.items[EntityID("AtticContent.lamp")] != nil)
        #expect(definition.items[EntityID("CellarContent.lamp")] != nil)
        #expect(
            state.placements[EntityID("AtticContent.lamp")]
                == .room(EntityID("AtticContent.hall")))
        #expect(
            state.placements[EntityID("CellarContent.lamp")]
                == .room(EntityID("CellarContent.vault")))

        // And in play each room's lamp answers with its own description rather
        // than one bundle's text turning up in the other's room.
        let transcript = try await play(BundleGame(), ["examine lamp", "down", "x lamp"])
        expectInOrder(
            transcript,
            [
                "[attic] A sooty oil lamp, long dry.",
                "Cellar Vault",
                "[cellar] A miner's lamp on a hook, still faintly warm.",
            ])
    }

    /// A bundle the game stores but never lists in `content` is registered by
    /// nothing, so its whole region would quietly not exist. Fatal, and it names
    /// the property and the type.
    @Test func storedButUnlistedBundleIsFatal() throws {
        do {
            _ = try Bootstrap.build(UnlistedBundleGame())
            Issue.record("expected a BootstrapError for the unlisted bundle")
        } catch let error as BootstrapError {
            #expect(
                error.diagnostics.contains {
                    $0.contains("\"cellar\"") && $0.contains("CellarContent")
                        && $0.contains("content")
                })
            // The listed bundle is not accused of anything.
            #expect(!error.diagnostics.contains { $0.contains("AtticContent") })
        }
    }
}
