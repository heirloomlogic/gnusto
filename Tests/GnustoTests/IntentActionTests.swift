import Testing

@testable import Gnusto

/// Phase 5 Task 5 — the intent-override table and `proceed()`. Proves a
/// custom intent can get real stage-4 behavior through `actions` (no more
/// falling through to "I didn't understand"), that a game's action can
/// override a built-in's default with a recorded warning, that a plugin can
/// ship a whole verb (vocabulary + default) a host splices in with no rules
/// of its own, and that `proceed()` lets a `before` rule run the default
/// action early and embellish its result.
struct IntentActionTests {
    // MARK: - Custom intent gets a default via `actions`

    @Test func customActionGivesACustomIntentDefaultBehavior() async throws {
        let transcript = try await play(CustomActionGame(), ["ring bell"])
        expectInOrder(transcript, ["The bell chimes sweetly."])
        #expect(!transcript.contains("I didn't understand"))
    }

    // MARK: - Game action overrides a built-in

    @Test func gameActionOverridesABuiltinDefault() async throws {
        // If the override failed, the built-in `take` would print "Taken.".
        let transcript = try await play(ThemedTakeGame(), ["take coin"])
        expectInOrder(transcript, ["You pocket the gold coin with a guilty glance."])
        #expect(!transcript.contains("Taken."))
    }

    @Test func overridingABuiltinActionRecordsANonFatalWarning() throws {
        let (definition, _) = try Bootstrap.build(ThemedTakeGame())
        #expect(definition.warnings.contains { $0.contains("take") })
        // The override, not the built-in, is what's registered.
        #expect(definition.actionOverrides[.take] != nil)
    }

    @Test func gamesWithoutCustomActionsRecordNoActionWarnings() throws {
        let (definition, _) = try Bootstrap.build(CustomActionGame())
        #expect(definition.warnings.isEmpty)
    }

    // MARK: - Plugin-provided action, spliced by the host

    @Test func pluginProvidedActionSplicedByHostWorks() async throws {
        let transcript = try await play(GreeterGame(), ["greet statue"])
        expectInOrder(transcript, ["You wave and offer a warm greeting."])
    }

    // MARK: - `proceed()` embellish flow

    @Test func proceedRunsTheBuiltInThenLetsTheRuleEmbellish() async throws {
        let transcript = try await play(MailboxGame(), ["open mailbox"])
        expectInOrder(
            transcript,
            [
                "Opening the small mailbox reveals a city map.",
                "A city map is tucked inside the lid.",
            ])
    }

    @Test func proceedPropagatesATurnInterruptFromTheDefaultAction() async throws {
        // The built-in `open` refuses because the mailbox is locked;
        // `proceed()` must surface that refusal and the rule's own
        // embellishment line must never run.
        let transcript = try await play(LockedMailboxGame(), ["open mailbox"])
        #expect(transcript.contains("locked"))
        #expect(!transcript.contains("This line must never print."))
    }

    // MARK: - `proceed()` from an early phase skips later before-phases

    @Test func proceedFromWorldBeforeSkipsLaterItemBeforeGuard() async throws {
        // `world.before(.take)` calls `proceed()`, running the built-in take
        // immediately. The `item.before(.take)` guard on the wrench runs
        // later in the stage 1-3 sequence and would normally refuse the
        // take — but since the default already ran, the pipeline must skip
        // it entirely: no "GUARD RAN" marker, no refusal message, and the
        // take's own success text still appears.
        let transcript = try await play(EarlyProceedSkipsLaterGuardsGame(), ["take wrench"])
        expectInOrder(transcript, ["The world itself lets you take it."])
        #expect(transcript.contains("Taken."))
        #expect(!transcript.contains("GUARD RAN"))
        #expect(!transcript.contains("bolted down"))
    }

    // MARK: - `proceed()` misuse traps
    //
    // `proceed()`'s misuse paths (calling it twice, or from an `after`/
    // each-turn rule) are documented `fatalError` traps, consistent with
    // `Ctx.current`'s own misuse style (see TurnFrame.swift). The suite has
    // no precondition-testing/exit-code harness (no `#expect(exitsWith:)` or
    // equivalent elsewhere in GnustoTests), so per the task brief these traps
    // are documented here rather than exercised: a second `proceed()` call in
    // the same turn, or a `proceed()` call from an `after`/each-turn rule,
    // crashes the process with a message naming the misuse — never a
    // player-facing failure.
}
