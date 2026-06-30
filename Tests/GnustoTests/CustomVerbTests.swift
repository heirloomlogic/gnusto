import Testing

@testable import Gnusto

/// Phase 1 — vocabulary extension. Proves a game can add player-typeable verbs
/// through its `verbs` block, that custom intents reach `before` rules, that
/// preposition shapes are parsed, that unhandled custom verbs fall through to
/// the default response, and that a verb colliding with a built-in overrides
/// it (last-wins) with a non-fatal warning.
struct CustomVerbTests {
    @Test func customVerbParsesAndRuleFires() async throws {
        let transcript = try await play(CustomVerbGame(), ["ring bell"])
        expectInOrder(transcript, ["The bell chimes sweetly."])
    }

    @Test func customVerbWithPrepositionShapeParses() async throws {
        // Proves the "with" preposition is harvested into the vocabulary and
        // the indirect object resolves, so the bell's `polish` rule fires.
        let transcript = try await play(CustomVerbGame(), ["polish bell with cloth"])
        expectInOrder(transcript, ["You polish the bell to a warm shine."])
    }

    @Test func parsedButUnhandledCustomVerbFallsThrough() async throws {
        // `sing` parses to a custom intent, but no rule handles it, so the
        // default action reports that it didn't understand.
        let transcript = try await play(CustomVerbGame(), ["sing"])
        #expect(transcript.contains("I didn't understand that sentence."))
    }

    @Test func customVerbsDoNotDisturbBuiltins() async throws {
        // Built-in verbs still work alongside the added ones.
        let transcript = try await play(CustomVerbGame(), ["take bell", "inventory"])
        expectInOrder(transcript, ["Taken.", "bronze bell"])
    }

    @Test func collidingVerbOverridesBuiltin() async throws {
        // If the override failed, the built-in `take` would print "Taken.".
        let transcript = try await play(VerbOverrideGame(), ["take coin"])
        expectInOrder(transcript, ["You pocket the coin with a guilty glance."])
        #expect(!transcript.contains("Taken."))
    }

    @Test func collidingVerbRecordsWarningAndDedupesTable() throws {
        let (definition, _) = try Bootstrap.build(VerbOverrideGame())

        // A non-fatal warning names the overridden verb.
        #expect(definition.warnings.contains { $0.contains("take") })

        // The resolved table holds exactly one `take <thing>` row, and it is
        // the game's (intent "steal"), not the built-in (intent "take").
        let takeRows = definition.syntaxRules.filter {
            $0.verb == ["take"] && $0.slots == .direct
        }
        #expect(takeRows.count == 1)
        #expect(takeRows.first?.intent == Intent("steal"))
    }

    @Test func gamesWithoutCustomVerbsRecordNoWarnings() throws {
        let (definition, _) = try Bootstrap.build(CustomVerbGame())
        #expect(definition.warnings.isEmpty)
    }
}
