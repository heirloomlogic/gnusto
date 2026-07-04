/// Declares a custom player-typeable verb in one place: a typed intent
/// constant plus the verb rows that produce it.
///
/// Use it inside an `extension Intent` — that's what makes the leading-dot
/// spelling work everywhere an `Intent` is expected:
///
/// ```swift
/// extension Intent {
///     #verb("ring", ["ring", .directObject])
///     #verb("attack",
///           ["attack", .directObject],
///           ["attack", .directObject, "with", .indirectObject],
///           ["kill", .directObject])
///     #verb("sing")                            // pattern defaults to ["sing"]
///     #verb("steal", ["take", .directObject])  // reclaim a built-in verb
/// }
/// ```
///
/// Each pattern is a complete row: literal words the player types plus
/// `.directObject` / `.indirectObject` / `.direction` slots. Patterns are
/// validated at compile time with the same rules the bootstrap applies to
/// hand-built rows.
///
/// The rows still need to reach the parser: list the intents in a `verbs`
/// block, which splices everything they carry. (List several as one array —
/// bare `.ring` statements on consecutive lines would parse as a single
/// chained member access.)
///
/// ```swift
/// var verbs: [SyntaxRule] { [.ring, .attack] }
/// var rules: Rules {
///     bell.before(.ring) { try reply("The bell chimes sweetly.") }
/// }
/// ```
///
/// The first argument is the intent's identifier — the generated constant's
/// name and its `raw` value — so it must be a plain string literal that is a
/// valid Swift identifier. It doesn't have to match the typed verb word:
/// `#verb("steal", ["take", .directObject])` reclaims the built-in `take`
/// row under a new intent.
@freestanding(declaration, names: arbitrary)
public macro verb(_ intentName: String, _ patterns: [SyntaxElement]...) =
    #externalMacro(module: "GnustoMacros", type: "VerbMacro")
