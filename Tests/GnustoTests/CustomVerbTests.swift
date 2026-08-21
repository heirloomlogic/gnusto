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

    // MARK: - Engine intents in a verbs block

    @Test func anEngineIntentCarriesTheStandardRowsThatProduceIt() {
        // A `#verb` intent carries its rows; an engine intent's live in the
        // standard table instead. `verbRows` is what makes both spell the same
        // way at a `verbs` block — without it, `.attack` spliced nothing.
        #expect(Intent.ring.verbRows.count == Intent.ring.syntax.count)
        #expect(Intent.attack.syntax.isEmpty)
        let attackWords = Set(Intent.attack.verbRows.flatMap(\.leadingWords))
        #expect(attackWords == ["attack", "kill", "hit", "fight"])
        #expect(Intent.take.verbRows.allSatisfy { $0.intent == .take })
        #expect(Intent("nonesuch").verbRows.isEmpty)
    }

    @Test func listingAnEngineIntentSplicesItsRowsAlongsideNewOnes() {
        // The MeleeCombat case, checked where it's visible: at the block, not
        // in the merged table, which supplies the engine's rows either way.
        // That is why `.attack` splicing zero went unnoticed for so long.
        let verbs = EngineIntentVerbGame().verbs
        let words = Set(verbs.flatMap(\.leadingWords))
        #expect(words == ["attack", "kill", "hit", "fight", "stab", "strike"])
        #expect(verbs.allSatisfy { $0.intent == .attack })
    }

    @Test func reclaimingACoreRowForItsOwnIntentRestoresIt() async throws {
        // The splice reaching the parser, in a transcript. `.steal` takes
        // `take <thing>`, then `.take` takes it back — last-wins, so the
        // built-in answers. If listing `.take` spliced nothing, the `.steal`
        // row would stand and the unhandled intent would report that it didn't
        // understand.
        let transcript = try await play(RestoredCoreVerbGame(), ["take penny"])
        #expect(transcript.contains("Taken."))
        #expect(!transcript.contains("I didn't understand that sentence."))
    }

    @Test func reclaimingACoreRowForItsOwnIntentDoesNotWarn() throws {
        // One warning, for the `.steal` row that genuinely changes what
        // `take <thing>` means. The seven rows `.take` splices match built-in
        // keys too, but they reclaim each shape for the intent that already
        // held it, which is no override at all.
        let (definition, _) = try Bootstrap.build(RestoredCoreVerbGame())
        #expect(definition.warnings.count == 1)
        #expect(definition.warnings.first?.contains("take <object>") == true)
    }

    // MARK: - A row that is another row respelled

    @Test func aGameRowThatRespellsItsOwnNeighbourWarns() async throws {
        // Two rows, one pattern. The parser canonicalizes both sides of the
        // candidate filter, and equal specificity keeps table order, so the
        // `into` row can never fire — but the game plays exactly as it would
        // without it, which is why this is a warning and not a diagnostic.
        let (definition, _) = try Bootstrap.build(RespeltVerbGame())
        #expect(
            definition.warnings.contains { warning in
                warning.contains("\"toss <object> into <second object>\"")
                    && warning.contains("\"toss <object> in <second object>\"")
                    && warning.contains("respelled")
            }, "\(definition.warnings)")

        let transcript = try await play(RespeltVerbGame(), ["toss coin into well"])
        #expect(!transcript.contains("I didn't understand that sentence."))
    }

    @Test func aGameRowThatRespellsABuiltInWarns() throws {
        // Nothing in this game spells `put <object> in <second object>`; the
        // engine's table does. The check runs over the merged table, so the
        // collision is caught across that seam and not only inside one block.
        let (definition, _) = try Bootstrap.build(RespeltBuiltInVerbGame())
        #expect(
            definition.warnings.contains { warning in
                warning.contains("\"put <object> into <second object>\"")
                    && warning.contains("\"put <object> in <second object>\"")
            }, "\(definition.warnings)")

        // Not the *override* warning: the shapes differ, so nothing was
        // reclaimed, and reporting it as an override would be a second wrong
        // explanation of one mistake.
        #expect(!definition.warnings.contains { $0.contains("overrides a built-in verb") })
    }

    @Test func anExactRepeatIsNotReportedAsARespelling() throws {
        // `RestoredCoreVerbGame` lists `.steal` and then `.take`, splicing the
        // same shapes twice. `dedupedLastWins` collapses those before the
        // respelling check reads the table, so the one warning it earns is the
        // override — not eight complaints about rows being respellings of
        // themselves.
        let (definition, _) = try Bootstrap.build(RestoredCoreVerbGame())
        #expect(!definition.warnings.contains { $0.contains("respelled") })
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
