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
/// it gets the object's rendered name and the `yourself`/`somebodyElse` guards,
/// which a closure cannot have. The reach guard both forms declare the same
/// way, with `reach:`. See ``action(_:reach:say:)`` for why the rest of that
/// difference is the point.
public struct IntentAction: Sendable {
    /// What the row answers with, and the whole of the difference between the
    /// two doors.
    ///
    /// `body` is arbitrary behavior and stage 4 runs it once the reach guard
    /// has passed. `line` is a sentence, the same `reach:` column and one flag —
    /// everything ``StubVerb`` holds except the rows, which a custom verb
    /// already declared for itself in `verbs`. Keeping the reach beside the
    /// behavior rather than inside it is what lets stage 0 read the column too:
    /// `DefaultActions.reachRequirement(of:in:)` needs the answer before any
    /// rule runs, and a closure that guards internally could only answer at
    /// stage 4.
    ///
    /// `requiresObject` is ``StubVerb/namesObject``'s question asked from the
    /// other side. `naming:` builds a sentence out of the object's name and has
    /// nothing to say without one, so a row using it under a verb that also
    /// parses bare would answer `hoot` with the *parser's* failure and charge a
    /// turn for it. The engine's own table forbids that shape by review; a
    /// game's is checked at bootstrap, which is the only place both the row and
    /// the verb's rows are in scope.
    enum Kind: Sendable {
        case body(reach: Reach, @Sendable () throws -> Void)
        case line(
            reach: Reach, requiresObject: Bool, render: @Sendable (GameText, Command) -> String)
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
    ///   - reach: which object slots the player has to be able to touch before
    ///     the body runs. See ``action(_:reach:perform:)``.
    ///   - body: the action's behavior.
    public init(
        _ intent: Intent,
        reach: Reach = .notNeeded,
        perform body: @escaping @Sendable () throws -> Void
    ) {
        self.intent = intent
        self.kind = .body(reach: reach, body)
    }

    /// Builds a stage-4 default *line* for `intent` — the door the three
    /// `action(…)` line factories come through, and not one a game opens
    /// directly: the guard cascades live in ``StubVerb`` and each factory picks
    /// the one its shape implies.
    ///
    /// - Parameters:
    ///   - intent: the intent this line answers.
    ///   - reach: which object slots the player has to be able to touch.
    ///   - requiresObject: whether the sentence has anything to say about a
    ///     command that named nothing.
    ///   - render: the sentence, given the game's text table and the command.
    init(
        _ intent: Intent,
        reach: Reach,
        requiresObject: Bool = false,
        render: @escaping @Sendable (GameText, Command) -> String
    ) {
        self.intent = intent
        self.kind = .line(reach: reach, requiresObject: requiresObject, render: render)
    }

    /// A copy of this action whose body runs with `namespace` bound as the
    /// owning bundle (``Ctx/owned(_:_:)``), so timer helpers inside resolve
    /// bare timer names against the owner's declarations. The game's own
    /// actions (`nil`) come back unchanged, and so does a line: a sentence
    /// starts no timers and names no declarations, so there is no owner for it
    /// to be read against.
    func owned(by namespace: String?) -> IntentAction {
        guard let namespace, case .body(let reach, let body) = kind else { return self }
        return IntentAction(intent, reach: reach) { try Ctx.owned(namespace, body) }
    }
}

/// Builds a stage-4 default action for `intent` — shorthand for
/// `IntentAction(_:reach:perform:)` that reads naturally in an `actions` block.
///
/// `reach:` is the same column a line row declares, read at the same two
/// places: stage 0, where a `reach { … }` rule is settled ahead of every rule,
/// and stage 4, where the engine's `cantReach` refuses a slot the player can
/// see and not touch before the body runs. It defaults to ``Reach/notNeeded``,
/// which is what a custom intent had before the column existed, so no closure
/// tightens silently — and, as with a line, it is read only for a verb the
/// *game* invented, since a built-in keeps its own physics whoever writes the
/// behavior.
///
/// ```swift
/// action(.show, reach: .bothObjects) {
///     guard let addressee = command.indirectObject else { return }
///     try reply(text.noInterest(addressee.definiteNoun))
/// }
/// ```
///
/// - Parameters:
///   - intent: the intent this action handles.
///   - reach: which object slots the player has to be able to touch.
///   - body: the action's behavior.
/// - Returns: the intent action.
public func action(
    _ intent: Intent,
    reach: Reach = .notNeeded,
    perform body: @escaping @Sendable () throws -> Void
) -> IntentAction {
    IntentAction(intent, reach: reach, perform: body)
}

/// A custom verb's own default line: the sentence it answers with when no rule
/// of the game's has anything better to say.
///
/// This is what `action(.wind) { try reply(Prose.cannotWind) }` was reaching
/// for, and it is not the same thing. A closure runs whatever it was written
/// to run; a line takes the path a stub verb takes, which renders the object's
/// name, agrees with its number and answers `wind me` and `wind the troll` in
/// the engine's own words. The reach guard is not the difference any more:
/// both forms declare it with `reach:`, and a custom intent has no column
/// anywhere else — it is in neither half of the standard table, so without
/// one `wind the clock` through the glass of a shut cabinet answers as though
/// the player were holding it.
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
/// **Choosing this form for a verb whose rows carry a `.directObject` is a
/// choice, and it has a cost.** The engine forbids the same shape in its own
/// table — `StubVerb.namesObject` and the `everyStubWithAnObjectSlotCanNameIt`
/// test are #245 — because a line that cannot say what the player pointed at
/// looks correct from both sides and is wrong from neither. A game is allowed
/// it, because a game may be reproducing a source whose answer is genuinely
/// nameless: Zork's `V-WIND` is "You cannot wind up a X." and `Sources/Zork1/`
/// declines the reproduction for a reason it writes down. What you are
/// accepting is that the sentence is aimed at the player too — `ring me`
/// answers whatever `ring the bell` answers, where a `naming:` line would have
/// said ``GameText/StubReplies/yourself``. Take the cost knowingly or take the
/// other form.
///
/// The sentence is a `String` and not a ``GameText/Line``, which is the type
/// the engine's own stub lines are held in, and the difference is deliberate:
/// a `Line` is not convertible from a `String` constant, so every row would
/// read `say: .init(Prose.cannotWind)` to say what `say: Prose.cannotWind`
/// says. The one thing the `Line` spelling would add is
/// ``GameText/Line/live(_:)`` — a nameless sentence assembled when it prints —
/// and the closure form already covers that with more power, since it runs in
/// the live turn frame rather than being handed nothing.
///
/// - Parameters:
///   - intent: the intent this line answers.
///   - reach: which object slots the player has to be able to touch. Defaults
///     to ``Reach/notNeeded``, which is what a custom intent has today, so
///     adopting this spelling never silently tightens a verb. It is a real
///     question and the engine cannot guess it: `wind the clock` wants
///     ``Reach/directObject``, and `raise the basket` — a chain hoist worked
///     from the far end of a shaft — does not. It is read only for a verb the
///     *game* invented. A row reclaiming a built-in or a stub reclaims that
///     verb's answer and not its physics, so the standard table's column
///     stands: `take` has to reach what it takes whoever writes the sentence.
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
    IntentAction(
        intent, reach: reach, requiresObject: true,
        render: StubVerb.nameCascade { _, noun in line(noun) })
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
/// action(.whistle, orBare: "You whistle at nobody in particular.", guardsActors: true) {
///     "You whistle at \($0), which changes nothing."
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
    // The two halves are joined by the same factory a `text.stubs` assignment
    // uses, rather than by a second copy of its one-line body, so "both halves
    // or neither" stays one rule with one implementation.
    let both = GameText.Line<GameText.Noun?>.naming(orBare: bare, line)
    return IntentAction(
        intent,
        reach: reach,
        render: StubVerb.optionalNameCascade(guardsActors: guardsActors) { _, noun in both(noun) })
}

/// The result builder for `actions` blocks.
public typealias ActionBuilder = GnustoBuilder<IntentAction>
