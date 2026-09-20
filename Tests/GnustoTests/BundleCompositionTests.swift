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

    /// Issue #474. `content` is the *game's* block, so a bundle stored by
    /// another bundle is registered by nothing when the game lists only its
    /// holder — and that used to be silent, because the walk looking for
    /// unlisted bundles only ever read the game's own stored properties.
    @Test func unlistedNestedBundleIsFatalAndNamesItsHolderPath() throws {
        do {
            _ = try Bootstrap.build(UnlistedNestedBundleGame())
            Issue.record("expected a BootstrapError for the unlisted nested bundle")
        } catch let error as BootstrapError {
            let unlisted = error.diagnostics.filter { $0.contains("BuriedContent") }
            #expect(unlisted.count == 1)
            // The holder is named, the path is the expression that reaches the
            // bundle, and that same path is the cure.
            #expect(unlisted.first?.contains("the content bundle LedgeContent stores") == true)
            #expect(unlisted.first?.contains("\"outer.buried\"") == true)
            #expect(unlisted.first?.contains("Add outer.buried to `var content`") == true)
            // The holder itself is listed, so it is not accused.
            #expect(!error.diagnostics.contains { $0.contains("LedgeContent stores \"outer\"") })
        }
    }

    /// The valid spelling the diagnostic above prescribes: the game lists both
    /// the holder and the bundle it holds, and the nested bundle's room, item,
    /// placement, exit and rule all work.
    @Test func explicitlyListedNestedBundleRegistersAndRuns() async throws {
        let (definition, state) = try Bootstrap.build(NestedBundleHost())

        // A nested bundle namespaces under its own type, not its holder's.
        #expect(definition.locations[EntityID("BuriedContent.cave")] != nil)
        #expect(definition.items[EntityID("BuriedContent.pebble")] != nil)
        #expect(definition.locations[EntityID("LedgeContent.ledge")] != nil)
        #expect(
            state.placements[EntityID("BuriedContent.pebble")]
                == .room(EntityID("BuriedContent.cave")))

        let transcript = try await play(NestedBundleHost(), ["down", "examine pebble"])
        expectInOrder(
            transcript,
            ["[buried] The cave swallows the light.", "A smooth grey pebble."])
    }

    /// The walk does not stop at the level the game listed. Here the game
    /// lists its holder and the bundle that holder stores, and the bundle
    /// *that* one stores — three levels down — is still named, with the whole
    /// path from the game to it.
    @Test func unlistedBundleThreeLevelsDownIsFatalAndNamesItsFullPath() throws {
        do {
            _ = try Bootstrap.build(DeeplyNestedBundleGame())
            Issue.record("expected a BootstrapError for the bundle three levels down")
        } catch let error as BootstrapError {
            let unlisted = error.diagnostics.filter { $0.contains("BuriedContent") }
            #expect(unlisted.count == 1)
            #expect(unlisted.first?.contains("the content bundle LedgeContent stores") == true)
            #expect(unlisted.first?.contains("\"outer.ledge.buried\"") == true)
            #expect(unlisted.first?.contains("Add outer.ledge.buried to `var content`") == true)
            // Neither listed level is accused.
            #expect(!error.diagnostics.contains { $0.contains("KeepContent stores") })
            #expect(!error.diagnostics.contains { $0.contains("(LedgeContent)") })
        }
    }

    /// `GameContent` requires only `Sendable`, so a bundle may be a class, and
    /// a class can hold itself. The walk remembers the class instances it has
    /// already descended into, so this bootstraps instead of recursing until
    /// the stack runs out.
    @Test func aBundleHoldingItselfTerminatesTheWalk() throws {
        let (definition, _) = try Bootstrap.build(SelfHoldingBundleGame())
        #expect(definition.locations[EntityID("SelfHoldingContent.crypt")] != nil)
    }

    /// A bundle that declares nothing mints no reference token, so one
    /// instance listed twice and two instances under one namespace are the
    /// same picture. Say so, with both cures, rather than guessing.
    @Test func twiceListedBundleWithNoDeclarationsIsReportedAsUndecidable() throws {
        do {
            _ = try Bootstrap.build(DoubleListedEmptyBundleGame())
            Issue.record("expected a BootstrapError for the doubled empty bundle")
        } catch let error as BootstrapError {
            let undecidable = error.diagnostics.filter { $0.contains("cannot tell") }
            #expect(undecidable.count == 1)
            #expect(
                undecidable.first?.contains(
                    "content lists 2 WeatherContent bundles under the namespace "
                        + "\"WeatherContent\"") == true)
            #expect(undecidable.first?.contains("remove the extra listing") == true)
            #expect(undecidable.first?.contains("override `var namespace`") == true)
            // The two readings are one line, not that line plus the flat
            // duplicate-listing line and a shared-namespace line as well.
            #expect(!error.diagnostics.contains { $0.contains("one and the same") })
            #expect(!error.diagnostics.contains { $0.contains("share the namespace") })
        }
    }

    /// Issue #478. Identity comes from the reference tokens a bundle's
    /// declarations mint, so a fresh instance of a stored bundle's type is
    /// caught even though its namespace matches — where matching on the
    /// namespace alone passed it and left the author with a map diagnostic
    /// claiming `attic.hall` was not a stored property, which it is.
    @Test func freshInstanceInContentIsNamedForWhatItIs() throws {
        do {
            _ = try Bootstrap.build(FreshInstanceBundleGame())
            Issue.record("expected a BootstrapError for the freshly constructed bundle")
        } catch let error as BootstrapError {
            let fresh = error.diagnostics.filter {
                $0.contains("yields a different AtticContent instance")
            }
            #expect(fresh.count == 1)
            #expect(fresh.first?.contains("\"attic\"") == true)
            #expect(fresh.first?.contains("`var content { attic }`") == true)
            // And it is not reported as a bundle that was left out entirely.
            #expect(!error.diagnostics.contains { $0.contains("never lists in its content") })
        }
    }

    /// Issue #482. One instance listed twice is a duplicate listing, not two
    /// bundles sharing a namespace: overriding `namespace` cannot fix it, and
    /// deleting the second listing can. The repeat is dropped before
    /// registration, so the per-entity collisions it used to cause are gone
    /// too.
    @Test func oneInstanceListedTwiceIsReportedAsADuplicateListing() throws {
        do {
            _ = try Bootstrap.build(DoubleListedBundleGame())
            Issue.record("expected a BootstrapError for the doubled listing")
        } catch let error as BootstrapError {
            #expect(
                error.diagnostics.contains {
                    $0.contains("content lists one and the same AtticContent instance 2 times")
                        && $0.contains("Remove the extra listing")
                })
            #expect(!error.diagnostics.contains { $0.contains("share the namespace") })
            #expect(!error.diagnostics.contains { $0.contains("declared by both") })
            #expect(!error.diagnostics.contains { $0.contains("declares its placement more than once") })
        }
    }
}
