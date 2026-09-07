/// A replacement or new stage-4 default action for one intent — the seam
/// that lets a game or plugin give a custom verb real behavior instead of
/// "I didn't understand", or replace a built-in's default entirely.
///
/// Declared through the `action(…)` factories and collected in a game's,
/// bundle's, or plugin's `actions` block, exactly like `verbs`:
///
/// ```swift
/// var actions: [IntentAction] {
///     action(Intent("ring")) {
///         say("The bell chimes sweetly.")
///     }
/// }
/// ```
///
/// An override runs at stage 4 exactly like a built-in: before rules have
/// already run, after rules still run, and `refuse`/`reply` inside it behave
/// identically to inside a built-in.
///
/// A row that is only a *sentence* takes one of the line factories instead —
/// ``action(_:reach:say:)``, ``action(_:reach:naming:)``,
/// ``action(_:orBare:reach:guardsActors:naming:)``. Those are not shorthand for
/// the closure: they route the verb through the same path a stub verb takes, so
/// it gets the reach guard, the object's rendered name and the
/// `yourself`/`somebodyElse` guards, none of which a closure can have. See
/// ``action(_:reach:say:)`` for why that difference is the point.
public struct IntentAction: Sendable {
    /// What the row answers with, and the whole of the difference between the
    /// two doors.
    ///
    /// `body` is arbitrary behavior and stage 4 simply runs it. `line` is a
    /// sentence and a `reach:` column — everything ``StubVerb`` holds except
    /// the rows, which a custom verb already declared for itself in `verbs`.
    /// Keeping the reach beside the renderer rather than inside it is what lets
    /// stage 0 read the column too: `DefaultActions.reachRequirement(of:in:)`
    /// needs the answer before any rule runs, and a closure that guards
    /// internally could only answer at stage 4.
    enum Kind: Sendable {
        case body(@Sendable () throws -> Void)
        case line(reach: Reach, render: @Sendable (GameText, Command) -> String)
    }

    let intent: Intent
    let kind: Kind

    /// Builds a stage-4 default action for `intent`. A row whose intent
    /// matches a built-in reclaims it (last-wins, with a non-fatal warning);
    /// a row whose intent matches no built-in gives that custom intent
    /// default behavior for the first time.
    ///
    /// - Parameters:
    ///   - intent: the intent this action handles.
    ///   - body: the action's behavior.
    public init(_ intent: Intent, perform body: @escaping @Sendable () throws -> Void) {
        self.intent = intent
        self.kind = .body(body)
    }

    /// Builds a stage-4 default *line* for `intent` — the door the three
    /// `action(…)` line factories come through, and not one a game opens
    /// directly: the guard cascades live in ``StubVerb`` and each factory picks
    /// the one its shape implies.
    ///
    /// - Parameters:
    ///   - intent: the intent this line answers.
    ///   - reach: which object slots the player has to be able to touch.
    ///   - render: the sentence, given the game's text table and the command.
    init(
        _ intent: Intent,
        reach: Reach,
        render: @escaping @Sendable (GameText, Command) -> String
    ) {
        self.intent = intent
        self.kind = .line(reach: reach, render: render)
    }

    /// A copy of this action whose body runs with `namespace` bound as the
    /// owning bundle (``Ctx/owned(_:_:)``), so timer helpers inside resolve
    /// bare timer names against the owner's declarations. The game's own
    /// actions (`nil`) come back unchanged, and so does a line: a sentence
    /// starts no timers and names no declarations, so there is no owner for it
    /// to be read against.
    func owned(by namespace: String?) -> IntentAction {
        guard let namespace, case .body(let body) = kind else { return self }
        return IntentAction(intent) { try Ctx.owned(namespace, body) }
    }
}

/// Builds a stage-4 default action for `intent` — shorthand for
/// `IntentAction(_:perform:)` that reads naturally in an `actions` block.
///
/// - Parameters:
///   - intent: the intent this action handles.
///   - body: the action's behavior.
/// - Returns: the intent action.
public func action(
    _ intent: Intent,
    perform body: @escaping @Sendable () throws -> Void
) -> IntentAction {
    IntentAction(intent, perform: body)
}

/// A custom verb's own default line: the sentence it answers with when no rule
/// of the game's has anything better to say.
///
/// This is what `action(.wind) { try reply(Prose.cannotWind) }` was reaching
/// for, and it is not the same thing. A closure is dispatched out of
/// `actionOverrides`, which returns *before* `requireReach` — and a custom
/// intent is in neither half of the standard table, so ``Reach`` says
/// `notNeeded` for it at stage 0 as well. A verb answered by a closure
/// therefore **cannot have a reach guard at either stage**, however much it
/// wants one: `wind the clock` through the glass of a shut cabinet answers as
/// though the player were holding it, and there is nowhere to say otherwise. A
/// verb answered by a line takes the path a stub verb takes, and `reach:` is
/// the column that path reads.
///
/// ```swift
/// var actions: [IntentAction] {
///     action(.wind, reach: .directObject, say: Prose.verbWindNothing)
///     action(.temple, say: Prose.graniteWordInert)
/// }
/// ```
///
/// The line is a **floor**, not a refusal. It is spoken with `say` rather than
/// `reply`, exactly as a stub verb's is, so `after` rules still get their turn
/// and the world clock advances — winding a clock that will not wind still
/// takes time. Anything that wants to answer *instead* promotes itself the
/// ordinary way, in a `before` rule.
///
/// This form names nothing, so it is the one for a verb whose sentence never
/// mentions what the player pointed at. Where the sentence does, use
/// ``action(_:reach:naming:)``, which hands the line the object's rendered name
/// and answers `wind me` and `wind the troll` in the engine's own words.
///
/// - Parameters:
///   - intent: the intent this line answers.
///   - reach: which object slots the player has to be able to touch. Defaults
///     to ``Reach/notNeeded``, which is what a custom intent has today, so
///     adopting this spelling never silently tightens a verb. It is a real
///     question and the engine cannot guess it: `wind the clock` wants
///     ``Reach/directObject``, and `raise the basket` — a chain hoist worked
///     from the far end of a shaft — does not.
///   - line: the sentence.
/// - Returns: the intent action.
public func action(
    _ intent: Intent,
    reach: Reach = .notNeeded,
    say line: String
) -> IntentAction {
    IntentAction(intent, reach: reach) { _, _ in line }
}

/// A custom verb's own default line, for a sentence that **names what the
/// player pointed at**.
///
/// Everything ``action(_:reach:say:)`` says about the reach guard holds here,
/// and this form adds the three a closure also can't have: the object arrives
/// as a ``GameText/Noun``, so a line whose verb has to agree conjugates itself
/// rather than hard-coding the singular; the player gets
/// ``GameText/StubReplies/yourself`` instead of "the yourself"; and anybody
/// else gets ``GameText/StubReplies/somebodyElse`` instead of being spoken
/// about as furniture.
///
/// ```swift
/// action(.harness, naming: {
///     "\($0.sentenceCased) \($0.verb("is", "are")) not harness enough."
/// })
/// ```
///
/// Open on ``GameText/Noun/sentenceCased`` rather than writing `"The \($0)"` —
/// the article is already in the phrase, chosen from the `properName` trait.
///
/// A verb whose rows don't all carry an object, or whose sentence reads
/// perfectly well with the name left out, wants
/// ``action(_:orBare:reach:guardsActors:naming:)`` instead: this form has no
/// answer for a command that named nothing.
///
/// - Parameters:
///   - intent: the intent this line answers.
///   - reach: which object slots the player has to be able to touch.
///   - line: the sentence, given the object's rendered name.
/// - Returns: the intent action.
public func action(
    _ intent: Intent,
    reach: Reach = .notNeeded,
    naming line: @escaping @Sendable (GameText.Noun) -> String
) -> IntentAction {
    IntentAction(intent, reach: reach, render: StubVerb.naming { _, noun in line(noun) })
}

/// A custom verb's own default line, for a verb the player may use **with an
/// object or without one**.
///
/// `ring` and `ring the bell` are one intent, and one declaration answers both:
/// the nameless command takes `bare`, the named one takes the closure. Both
/// halves are required for the reason ``GameText/Line/naming(orBare:_:)`` gives
/// — a game that wrote only the naming half would leave the other command
/// answered by somebody else's words.
///
/// ```swift
/// action(.raise, orBare: Prose.playingWithIt("it"), guardsActors: true) {
///     Prose.playingWithIt("\($0)")
/// }
/// ```
///
/// The player takes the nameless half too, since "You wave yourself." is not a
/// sentence and a line that owns a bare half already has the better answer.
/// Everybody *else* is a per-verb question, so it is a parameter: `ring the
/// bellhop` may well want the line, where `harness the ferryman` wants
/// ``GameText/StubReplies/somebodyElse``.
///
/// - Parameters:
///   - intent: the intent this line answers.
///   - bare: the sentence for a command that named nothing.
///   - reach: which object slots the player has to be able to touch.
///   - guardsActors: whether naming somebody else gets
///     ``GameText/StubReplies/somebodyElse`` rather than the line.
///   - line: the sentence, given the object's rendered name.
/// - Returns: the intent action.
public func action(
    _ intent: Intent,
    orBare bare: String,
    reach: Reach = .notNeeded,
    guardsActors: Bool = false,
    naming line: @escaping @Sendable (GameText.Noun) -> String
) -> IntentAction {
    IntentAction(
        intent,
        reach: reach,
        render: StubVerb.optionallyNaming(guardsActors: guardsActors) { _, noun in
            noun.map(line) ?? bare
        })
}

/// The result builder for `actions` blocks.
public typealias ActionBuilder = GnustoBuilder<IntentAction>
