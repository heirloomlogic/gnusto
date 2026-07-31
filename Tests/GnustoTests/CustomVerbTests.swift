import GnustoTestSupport
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
        // `hum` parses to a custom intent, but no rule handles it and it is not
        // a stub verb, so stage 4 has nothing to answer it with. The line says
        // so — and is emphatically *not* the parser's own failure message, which
        // would be a lie: a verb row matched, or stage 4 was never reached.
        let transcript = try await play(CustomVerbGame(), ["hum"])
        #expect(transcript.contains("You can't do that."))
        #expect(!transcript.contains("I didn't understand that sentence."))
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
            $0.elements == [.word("take"), .directObject]
        }
        #expect(takeRows.count == 1)
        #expect(takeRows.first?.intent == Intent("steal"))
    }

    /// The mirror of `aWatchedButUnlistedVerbIntentWarns`: a row the parser can
    /// match whose intent nothing answers. `.hum` is listed and wired to
    /// nothing, so it warns; `.ring` and `.polish` are answered by rules on the
    /// bell and stay silent.
    @Test func aListedButUnansweredVerbIntentWarns() throws {
        let (definition, _) = try Bootstrap.build(CustomVerbGame())
        #expect(
            definition.warnings == [
                "a verb row produces intent \"hum\", but nothing answers it; give it "
                    + "an action(.hum) or a rule, or the verb just prints the engine's "
                    + "fall-back line."
            ],
            "\(definition.warningReport ?? "no report")")
    }

    /// The threshold, stated as a test: answering a custom verb with a rule on
    /// one entity and leaving every other noun to the fall-back is the
    /// documented pattern, not a mistake. Nothing about it may warn.
    @Test func aVerbAnsweredOnOneEntityWarnsNothing() throws {
        let (definition, _) = try Bootstrap.build(SentryPostGame())
        #expect(definition.warnings.isEmpty, "\(definition.warningReport ?? "no report")")
    }

    // MARK: - An unhandled verb costs nothing

    /// The regression test for the drowning. Three commands nothing answers
    /// must not move the world three turns — and `score` is meta, so probing
    /// the count costs nothing either. The daemon never runs at all and the
    /// move counter never leaves zero; `theAnsweredNounStillCostsATurn` is the
    /// positive control that both would otherwise fire.
    @Test func anUnhandledVerbDoesNotTickTheClock() async throws {
        let transcript = try await play(
            SentryPostGame(),
            ["salute banner", "salute banner", "salute banner", "score"])

        #expect(!transcript.contains("The watch bell strikes"))
        #expect(turnOutput(of: "score", in: transcript).contains("in 0 turns."))
    }

    /// The other half of the contract: the noun the rule *does* cover is an
    /// ordinary turn, and pays for itself.
    @Test func theAnsweredNounStillCostsATurn() async throws {
        let transcript = try await play(SentryPostGame(), ["salute sentry", "score"])
        #expect(transcript.contains("The sentry returns your salute, crisply."))
        #expect(transcript.contains("The watch bell strikes 1."))
        #expect(turnOutput(of: "score", in: transcript).contains("in 1 turn."))
    }

    /// Stage 5 reacts to a default action that ran. Nothing ran, so the
    /// banner's `after` rule doesn't fire — the same unwind `refuse` uses.
    @Test func anUnhandledVerbSkipsAfterRules() async throws {
        let transcript = try await play(SentryPostGame(), ["salute banner"])
        #expect(transcript.contains("You can't do that."))
        #expect(!transcript.contains("The banner stirs."))
    }

    /// A free turn must not spend the player's UNDO on a non-event: the
    /// snapshot still points at the last command that actually did something.
    @Test func anUnhandledVerbLeavesTheUndoSnapshotAlone() async throws {
        let transcript = try await play(
            SentryPostGame(),
            ["take banner", "salute banner", "undo", "inventory"])

        #expect(turnOutput(of: "undo", in: transcript).contains("Previous turn undone."))
        // The take is what got rewound, so the banner is back on the ground.
        #expect(turnOutput(of: "inventory", in: transcript).contains("empty-handed"))
    }

    // MARK: - #verb

    @Test func verbMacroIntentsMatchTheirStringlyTwins() {
        // Rules keyed on `Intent("ring")` must keep matching a #verb-minted
        // `.ring`: the rows an intent carries are not part of its identity.
        #expect(Intent.ring == Intent("ring"))
        #expect(Intent.ring.hashValue == Intent("ring").hashValue)
        #expect(Intent.ring.syntax.count == 1)
        #expect(Intent("ring").syntax.isEmpty)
    }

    @Test func listingAnIntentSplicesItsRows() throws {
        // The `verbs` block above lists `.ring`, `.polish`, and `.hum` by
        // name only; the resolved table must contain each carried row.
        let (definition, _) = try Bootstrap.build(CustomVerbGame())
        let customIntents = definition.syntaxRules.map(\.intent)
        #expect(customIntents.contains(.ring))
        #expect(customIntents.contains(.polish))
        #expect(customIntents.contains(.hum))
    }

    @Test func aWatchedButUnlistedVerbIntentWarns() throws {
        // ForgottenVerbGame keys a rule on `.ring` but never lists it, so no
        // row produces the intent — the bootstrap names the likely fix.
        let (definition, _) = try Bootstrap.build(ForgottenVerbGame())
        #expect(
            definition.warnings.contains { warning in
                warning.contains("ring") && warning.contains("verbs block")
            })
    }
}
