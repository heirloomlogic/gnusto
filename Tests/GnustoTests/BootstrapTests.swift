import Testing

@testable import CloakOfDarkness
@testable import Gnusto

struct BootstrapTests {
    @Test func operaHouseBoots() throws {
        // Constructs directly, not via the shared-definition cache: the point
        // of this test is that bootstrap itself runs and validates cleanly.
        _ = try GameWorld(game: OperaHouse())
    }

    @Test func idsAreInferredFromPropertyNames() throws {
        let (definition, _) = try Bootstrap.build(MiniGame())
        #expect(definition.locations.keys.contains(EntityID("den")))
        #expect(definition.locations.keys.contains(EntityID("cellar")))
        #expect(definition.items.keys.contains(EntityID("book")))
        #expect(definition.items.keys.contains(EntityID("hat")))
        #expect(definition.playerStart == EntityID("den"))
    }

    @Test func globalsAreDiscoveredWithUnderscoreStripped() throws {
        let (definition, _) = try Bootstrap.build(OrderProbeGame())
        #expect(definition.globalDefaults[EntityID("armed")] == .bool(false))
        #expect(definition.globalDefaults[EntityID("blunders")] == .int(0))
    }

    @Test func declaredTraitsReachTheDefinition() throws {
        let (definition, state) = try Bootstrap.build(MiniGame())
        #expect(definition.locations[EntityID("cellar")]?.inherentlyLit == false)
        #expect(definition.items[EntityID("hat")]?.isWearable == true)
        #expect(definition.items[EntityID("table")]?.isScenery == true)
        #expect(definition.items[EntityID("table")]?.isSurface == true)
        #expect(state.litRooms.contains(EntityID("den")))
        #expect(!state.litRooms.contains(EntityID("cellar")))
        #expect(state.placements[EntityID("coin")] == .on(EntityID("table")))
        #expect(state.placements[EntityID("hat")] == .heldBy(.player))
    }

    @Test func brokenGameReportsAllProblemsAtOnce() {
        #expect {
            try Bootstrap.build(BrokenGame())
        } throws: { error in
            guard let bootstrapError = error as? BootstrapError else { return false }
            let text = bootstrapError.description
            return text.contains("not a stored property")  // inline exit target
                && text.contains("not declared as a surface")  // pebble on nameless
                && text.contains("player.starts(in:)")  // missing start
                && text.contains("no name(…) trait")  // nameless item
                && bootstrapError.diagnostics.count >= 4
        }
    }

    @Test func warningReportSummarizesPendingWarnings() throws {
        // ForgottenVerbGame keys a rule on an unlisted `#verb` intent, so the
        // bootstrap records a dead-intent warning; the report renders it.
        let (definition, _) = try Bootstrap.build(ForgottenVerbGame())
        let report = try #require(definition.warningReport)
        #expect(report.contains("warning(s) (play continues)"))
        #expect(report.contains("•"))
        #expect(report.contains("ring"))  // the offending intent
        #expect(report.contains("verbs block"))  // the suggested fix
    }

    @Test func alwaysDescribedWithNothingToPrintWarns() throws {
        let (definition, _) = try Bootstrap.build(EmptyStateRoomGame())
        let report = try #require(definition.warningReport)
        #expect(report.contains("\"alcove\" declares alwaysDescribed"))
        #expect(report.contains("nothing to print"))
        // The landing has a description and no trait, so it is not implicated.
        #expect(!report.contains("landing"))
    }

    /// The item-side twin. ``alwaysListed`` keeps a listing paragraph printing
    /// past the first touch, so an item with no listing paragraph has nothing
    /// for it to keep — and the transcript reads the same with the trait and
    /// without it, which is the silence the warning exists to break. (#329)
    @Test func alwaysListedWithNothingToKeepWarns() throws {
        let (definition, _) = try Bootstrap.build(MuteAlwaysListedGame())
        let report = try #require(definition.warningReport)
        #expect(report.contains("\"sconce\" declares alwaysListed"))
        #expect(report.contains("nothing to keep"))
        // The lantern has a `firstSight` line, so it is not implicated.
        #expect(!report.contains("lantern"))
    }

    /// A room description lists what stands in it and what those things hold,
    /// and goes no deeper. `NestedListingGame` declares a line below that on
    /// purpose — the thimble, inside a sack that is itself on the bench — and
    /// pins in `ContainerTests` that it never prints. This is the sentence that
    /// says so at bootstrap, instead of leaving the author to notice the
    /// silence in a transcript.
    @Test func aListingLineBelowTheDescribersReachWarns() throws {
        let (definition, _) = try Bootstrap.build(NestedListingGame())
        let report = try #require(definition.warningReport)

        #expect(report.contains("\"thimble\" declares firstSight(…)"))
        #expect(report.contains("2 levels below the room"))
        #expect(report.contains("inside \"sack\", on \"bench\""))

        // Everything else in that fixture is one level down or standing in the
        // room, where the channel works — and the warning must not chill it.
        #expect(definition.warnings.count == 1, "\(definition.warnings)")
    }

    /// The boundaries around it: the rule channel warns as the trait does, the
    /// count is the walk's own, and an item with no static room position is
    /// nobody's mistake yet.
    @Test func theBuriedListingWarningCountsLevelsAndSparesTheUnplaced() throws {
        let (definition, _) = try Bootstrap.build(BuriedListingGame())
        let report = try #require(definition.warningReport)

        // `presence { … }` is a listing line exactly as `firstSight(…)` is.
        #expect(report.contains("\"napkin\" declares a presence { … } rule"))
        #expect(report.contains("2 levels below the room"))
        #expect(report.contains("inside \"hamper\", on \"shelf\""))

        // Three deep, so the chain is walked rather than flagged at two.
        #expect(report.contains("\"locket\" declares firstSight(…)"))
        #expect(report.contains("3 levels below the room"))
        #expect(report.contains("inside \"casket\", inside \"hamper\", on \"shelf\""))

        // Those two and nothing else: the ledger is one level down and prints,
        // the pin has no line to strand, and the stub and the receipt have no
        // static room position to be wrong about.
        #expect(definition.warnings.count == 2, "\(definition.warnings)")
        for spared in ["\"ledger\"", "\"pin\"", "\"stub\"", "\"receipt\""] {
            #expect(!report.contains(spared))
        }
    }

    /// Every neighbouring placement mistake is already fatal — on a non-surface,
    /// inside a non-container, heldBy a non-actor. A cycle is the same class of
    /// mistake with the worst failure mode of the lot: both items resolve, the
    /// game boots, and neither is in any room. And unlike a listing line buried
    /// too deep, there is no runtime rescue — play cannot move what was never
    /// anywhere.
    @Test func aPlacementCycleIsFatal() {
        #expect {
            try Bootstrap.build(PlacementCycleGame())
        } throws: { error in
            guard let bootstrapError = error as? BootstrapError else { return false }
            let text = bootstrapError.description
            return text.contains("closes a placement cycle")
                && text.contains("\"box\" inside \"sack\", \"sack\" inside \"box\"")
                && bootstrapError.diagnostics.count == 1
        }
    }

    /// The whole loop is spelled out, link by link, the way the buried-listing
    /// warning spells out a holder chain — so the author sees which declarations
    /// close it rather than which item happened to be walked first.
    @Test func aPlacementCycleNamesEveryLinkInTheLoop() {
        #expect {
            try Bootstrap.build(TangledPlacementGame())
        } throws: { error in
            guard let bootstrapError = error as? BootstrapError else { return false }
            // Both link kinds, and anchored on the lowest ID in the loop so the
            // sentence reads the same on every build.
            return bootstrapError.description.contains(
                "\"basket\" on \"trolley\", \"trolley\" inside \"crate\", "
                    + "\"crate\" inside \"basket\"")
        }
    }

    @Test func anItemPlacedInsideItselfIsAPlacementCycle() {
        #expect {
            try Bootstrap.build(TangledPlacementGame())
        } throws: { error in
            guard let bootstrapError = error as? BootstrapError else { return false }
            return bootstrapError.description.contains("\"barrel\" inside \"barrel\"")
        }
    }

    /// Walking from every item finds the same loop once per member, and again
    /// from everything hanging off it. The report is one sentence per loop.
    @Test func aLoopIsReportedOnceHoweverManyThingsReachIt() {
        #expect {
            try Bootstrap.build(TangledPlacementGame())
        } throws: { error in
            guard let bootstrapError = error as? BootstrapError else { return false }
            // The three-item loop and the barrel — not three plus one, and not a
            // fifth for the apple, which merely sits in a crate that is lost.
            return bootstrapError.diagnostics.count == 2
                && !bootstrapError.description.contains("\"apple\"")
        }
    }

    /// The check must not chill ordinary nesting. A chain that reaches a room,
    /// one that reaches nobody, and one that reaches the player all terminate.
    @Test func legitimatePlacementsAreNotMistakenForCycles() {
        #expect {
            try Bootstrap.build(TangledPlacementGame())
        } throws: { error in
            guard let bootstrapError = error as? BootstrapError else { return false }
            let text = bootstrapError.description
            return ["\"chest\"", "\"coin\"", "\"ghost\"", "\"key\""].allSatisfy {
                !text.contains($0)
            }
        }
    }

    @Test func warningReportIsNilForACleanGame() throws {
        let (definition, _) = try Bootstrap.build(MiniGame())
        #expect(definition.warnings.isEmpty)
        #expect(definition.warningReport == nil)
    }

    @Test func danglingExitSourceNamesItsDirection() {
        #expect {
            try Bootstrap.build(DanglingExitSourceGame())
        } throws: { error in
            guard let bootstrapError = error as? BootstrapError else { return false }
            let text = bootstrapError.description
            return text.contains("the source of a north exit")  // the direction anchor
                && text.contains("not a stored property")
        }
    }

    @Test func aDirectionClaimedTwiceIsADiagnosticEvenForADynamicExit() {
        #expect {
            try Bootstrap.build(TwoNorthExitsGame())
        } throws: { error in
            guard let bootstrapError = error as? BootstrapError else { return false }
            return bootstrapError.description.contains(
                "declares its north exit more than once")
        }
    }

    @Test func danglingRuleAttachmentNamesItsPhase() {
        #expect {
            try Bootstrap.build(DanglingRuleGame())
        } throws: { error in
            guard let bootstrapError = error as? BootstrapError else { return false }
            let text = bootstrapError.description
            return text.contains("before rule")  // the phase anchor
                && text.contains("is attached to an item that is not a stored property")
        }
    }

    @Test func storedPropertyNamedPlayerIsRejected() {
        #expect {
            try Bootstrap.build(PlayerIDCollisionGame())
        } throws: { error in
            guard let bootstrapError = error as? BootstrapError else { return false }
            return bootstrapError.description.contains("\"player\" is a reserved entity ID")
        }
    }

    @Test func noiseWordCollidingWithAnItemWordIsRejected() {
        #expect {
            try Bootstrap.build(NoiseWordCollisionGame())
        } throws: { error in
            guard let bootstrapError = error as? BootstrapError else { return false }
            return bootstrapError.description.contains("noise word \"spell\"")
                && bootstrapError.description.contains("untypeable")
        }
    }

    @Test func vocabularyIsAssembledFromDeclarations() throws {
        let (definition, _) = try Bootstrap.build(OperaHouse())
        let cloak = definition.vocabulary.itemLexicons[EntityID("cloak")]
        #expect(cloak?.nouns.contains("cloak") == true)
        #expect(cloak?.nouns.contains("cape") == true)
        #expect(cloak?.adjectives.contains("velvet") == true)
        #expect(cloak?.adjectives.contains("satin") == true)
        let hook = definition.vocabulary.itemLexicons[EntityID("hook")]
        #expect(hook?.nouns.contains("peg") == true)
        #expect(hook?.adjectives.contains("brass") == true)
        #expect(definition.vocabulary.verbWords.contains("hang"))
        #expect(definition.vocabulary.prepositions.contains("on"))
    }
}
