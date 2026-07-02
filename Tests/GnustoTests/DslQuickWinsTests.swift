import Testing

@testable import Gnusto

/// Task 7 — four small DSL ergonomic wins: `require`, `TraitKey`, closure
/// descriptions, and `GameMain`.
struct DslQuickWinsTests {
    // MARK: - require

    @Test func requireAllowsTheActionWhenTheConditionHolds() async throws {
        // Dropping the cloak while in the cloakroom is not refused.
        let transcript = try await play(RequireGame(), ["drop velvet cloak"])
        #expect(!transcript.contains("This isn't the best place"))
        #expect(transcript.contains("Dropped."))
    }

    @Test func requireRefusesWithTheMessageWhenTheConditionFails() async throws {
        let transcript = try await play(RequireGame(), ["east", "drop velvet cloak"])
        #expect(transcript.contains("This isn't the best place to leave a smart cloak lying around."))
        #expect(!transcript.contains("Dropped."))
    }

    // MARK: - TraitKey

    @Test func traitKeyReadsAPresentTraitAndFallsBackToADefault() async throws {
        let transcript = try await play(TraitKeyGame(), ["examine lantern"])
        #expect(transcript.contains("price=Optional(5) weight=1"))
    }

    @Test func traitKeyReadsNilForAnAbsentTrait() async throws {
        let transcript = try await play(TraitKeyGame(), ["examine sign"])
        #expect(transcript.contains("price=nil"))
    }

    @Test func traitKeyIsStoredOnTheDefinitionUnderItsName() throws {
        let (definition, _) = try Bootstrap.build(TraitKeyGame())
        #expect(definition.items[EntityID("lantern")]?.customTraits["bulkPrice"] == .int(5))
    }

    // MARK: - Closure descriptions

    @Test func closureDescriptionReflectsLiveStateAcrossTurns() async throws {
        // Before taking the egg, the case reports it present; after, empty.
        // The same "examine" wording must change between the two turns,
        // proving the closure re-runs rather than baking in a value at
        // declaration time.
        let transcript = try await play(
            TrophyCaseGame(), ["examine trophy case", "take egg", "examine trophy case"])
        let before = turnOutput(of: "examine trophy case", in: transcript)
        expectInOrder(transcript, ["holding a jeweled egg", "Taken.", "stands empty"])
        #expect(before.contains("holding a jeweled egg"))
    }

    @Test func closureDescriptionOnALocationIsLiveAcrossTurnsViaGlobal() async throws {
        let transcript = try await play(
            LampGame(), ["examine lamp", "light lamp", "examine lamp", "douse lamp", "examine lamp"])
        expectInOrder(
            transcript,
            [
                "sits unlit",
                "The lamp is now lit.",
                "burning brightly",
                "The lamp is now dark.",
                "sits unlit",
            ])
    }

    @Test func runtimeOverrideBeatsClosureDescription() async throws {
        let transcript = try await play(
            TrophyCaseGame(), ["seal trophy case", "examine trophy case"])
        expectInOrder(transcript, ["You seal the case.", "The case has been sealed shut."])
        #expect(!turnOutput(of: "examine trophy case", in: transcript).contains("jeweled egg"))
    }

    @Test func staticDescriptionAndClosureOnTheSameEntityIsABootstrapDiagnostic() {
        #expect(throws: BootstrapError.self) {
            try Bootstrap.build(AmbiguousDescriptionGame())
        }
    }

    @Test func staticAndClosureDescriptionConflictDiagnosticNamesTheItem() {
        do {
            _ = try Bootstrap.build(AmbiguousDescriptionGame())
            Issue.record("expected a BootstrapError")
        } catch let error as BootstrapError {
            #expect(error.diagnostics.contains { $0.contains("widget") && $0.contains("description") })
        } catch {
            Issue.record("expected a BootstrapError, got \(error)")
        }
    }

    // MARK: - GameMain

    @Test func gameMainCompilesAndDrivesAScriptedIOHandler() async throws {
        // Compile-level: `MainableGame: Game, GameMain` in the fixture file
        // is the real assertion. Here, exercise the factored `run` function
        // (what `main()` calls after bootstrap) with a ScriptedIOHandler,
        // since invoking `main()` itself needs a live console.
        let world = try GameWorld(game: MainableGame())
        let io = ScriptedIOHandler(lines: ["look", "quit"])
        await MainableGame.run(world: world, io: io)
        #expect(io.transcript.contains("Welcome."))
        #expect(io.transcript.contains("Room"))
    }
}
