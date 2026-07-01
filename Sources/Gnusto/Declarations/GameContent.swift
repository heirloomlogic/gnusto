/// A self-contained slice of a game's world: its own rooms, items, and
/// `@Global` state, plus the geography, rules, and verbs that go with them.
///
/// A bundle lets a large game split its declarations across many types — and
/// even many SPM packages — instead of cramming every `let room = Location { … }`
/// into one struct. The game stores bundle instances as properties and lists
/// them in its `content` block; the bootstrap discovers each bundle's
/// declarations by reflection, exactly as it does the game's own.
///
/// ```swift
/// struct Attic: GameContent {
///     let landing = Location { name("Attic Landing") }
///     let trunk = Item { name("steamer trunk") }
///
///     var map: WorldMap { trunk.starts(in: landing) }
///     var rules: Rules { trunk.before(.open) { try reply("It's locked.") } }
/// }
/// ```
///
/// A bundle must be stored by the game and yielded from `content` as that same
/// instance (`var content { attic }`), never freshly constructed inside the
/// block. Each `Location`/`Item`/`@Global` mints a reference token at creation,
/// and the bootstrap matches the tokens it discovers against the tokens the
/// `map`/`rules` reference; a fresh instance would carry different tokens and
/// fail to resolve.
public protocol GameContent: Sendable {
    /// The bundle's geography and initial placements, in the same form as a
    /// game's `map`. Defaults to empty.
    @MapBuilder var map: WorldMap { get }

    /// The bundle's rules. Defaults to empty.
    @RuleBuilder var rules: Rules { get }

    /// Player-typeable verbs the bundle adds, in the same form as a game's
    /// `verbs`. Defaults to empty. Merged with the game's verbs and the
    /// built-in table under the same last-wins policy.
    @VerbBuilder var verbs: [SyntaxRule] { get }
}

extension GameContent {
    /// Bundles with no geography of their own can omit the `map` block.
    public var map: WorldMap { WorldMap(entries: []) }

    /// Bundles with no logic of their own can omit the `rules` block.
    public var rules: Rules { Rules(rules: []) }

    /// Bundles that add no verbs of their own can omit the `verbs` block.
    public var verbs: [SyntaxRule] { [] }
}

/// The collected content bundles a game declares, in declaration order.
public struct GameContents: Sendable {
    let modules: [any GameContent]
}
