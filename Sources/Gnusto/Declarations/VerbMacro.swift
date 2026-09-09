/// Declares a custom player-typeable verb in one place: a typed intent
/// constant plus the verb rows that produce it.
///
/// Use it inside an `extension Intent` — that's what makes the leading-dot
/// spelling work everywhere an `Intent` is expected:
///
/// ```swift
/// extension Intent {
///     #verb("ring", ["ring", .directObject])
///     #verb("barter",
///           ["barter", .directObject],
///           ["barter", .directObject, "for", .indirectObject],
///           ["haggle", "over", .directObject])
///     #verb("chime")                           // pattern defaults to ["chime"]
///     #verb("steal", ["take", .directObject])  // reclaim a built-in verb
/// }
/// ```
///
/// Pick a name the engine doesn't already ship. The macro mints
/// `Intent.<name>`, so a second declaration of a name the engine owns — a core
/// verb, or a stub verb like `dig`, `attack` or `sing` — makes `.<name>`
/// ambiguous in every file that imports both modules. Reclaiming the *word*
/// under a name of your own is always safe:
/// `#verb("excavate", ["dig", .directObject])`.
///
/// Each pattern is a complete row: literal words the player types plus
/// `.directObject` / `.indirectObject` / `.direction` / `.topic` slots. Patterns are
/// validated at compile time with the same rules the bootstrap applies to
/// hand-built rows.
///
/// The rows still need to reach the parser: list the intents in a `verbs`
/// block, which splices everything they carry. (List several as one array —
/// bare `.ring` statements on consecutive lines would parse as a single
/// chained member access.)
///
/// ```swift
/// var verbs: [SyntaxRule] { [.ring, .barter] }
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
///
/// `displayVerb:` is what a prompt calls the verb — "What do you want to
/// **wind**?" — and is needed by one shape only: a row that leads with an
/// abbreviation, where the row's own words are not a word.
///
/// ```swift
/// #verb("wind", ["wind", .directObject], ["w", .directObject], displayVerb: "wind")
/// ```
///
/// Left off, each row asks in its own leading words, which is right wherever
/// they are words: `["haggle", "over", .directObject]` asks what you want to
/// haggle over. See ``SyntaxRule/displayVerb``.
@freestanding(declaration, names: arbitrary)
public macro verb(
    _ intentName: String, _ patterns: [SyntaxElement]..., displayVerb: String? = nil
) = #externalMacro(module: "GnustoMacros", type: "VerbMacro")
