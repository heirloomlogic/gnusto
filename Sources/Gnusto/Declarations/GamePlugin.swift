/// A reusable game system — commerce, combat, dialog, magic — packaged as an
/// importable unit of *verbs* and *rules*, that a host game opts into.
///
/// A plugin bundles the player-typeable vocabulary a system needs (`buy`,
/// `attack`, `ask`) with the logic that reacts to it, so the system can be
/// shipped once and reused instead of hand-copied into every game.
///
/// ```swift
/// struct CommercePlugin: GamePlugin {
///     static let buy = Intent("buy")
///
///     var verbs: [SyntaxRule] {
///         SyntaxRule("buy", slots: .direct, intent: Self.buy)
///     }
/// }
/// ```
///
/// ## Logic-only: a plugin owns no state
///
/// Unlike a ``GameContent`` bundle, a plugin is **not** reflected by the
/// bootstrap, so it declares no rooms, items, or `@Global` state of its own. It
/// operates entirely over entities and globals the **host** declares, receiving
/// what it needs as parameters. That keeps a plugin portable: it makes no
/// assumptions about the host's world beyond the traits and intents it agrees
/// on. A plugin that genuinely needs to ship its own content is a
/// ``GameContent`` bundle instead (list it in the game's `content`).
///
/// ## The host opts in by splicing
///
/// The host stores the plugin as a plain property and splices its vocabulary,
/// default actions, and rules into its own blocks. `verbs` and `actions` each
/// merge just like a game's own, and the plugin's rule factories return
/// ``Rules`` the host composes in. Together, `verbs` + `actions` let a plugin
/// ship a whole verb behavior — vocabulary and stage-4 default — without any
/// host rules at all; a host only needs its own rules to embellish or
/// override that default for specific entities.
///
/// ```swift
/// struct LampShop: Game {
///     let commerce = CommercePlugin()
///     @Global var purse = Purse(coins: 10)
///     let lantern = Item { name("brass lantern"); trait("price", 5) }
///
///     var verbs: [SyntaxRule] { commerce.verbs }
///     var rules: Rules {
///         commerce.purchase(of: lantern,
///                           balance: { purse.coins },
///                           charge:  { purse.coins -= $0 })
///     }
/// }
/// ```
///
/// The protocol's own ``rules`` requirement carries only self-contained,
/// world-scoped rules that need nothing from the host. Rules that must reference
/// host entities are exposed as **parameterized methods** returning ``Rules``
/// (`purchase(of:balance:charge:)` above), which the host calls with its own
/// declarations — every line still readable in the host's source.
public protocol GamePlugin: Sendable {
    /// Player-typeable verbs the plugin contributes, in the same form as a
    /// game's `verbs`. Defaults to empty. Merged with the host's verbs and the
    /// built-in table under the same last-wins policy.
    @VerbBuilder var verbs: [SyntaxRule] { get }

    /// Stage-4 default actions the plugin contributes, in the same form as a
    /// game's `actions`. Defaults to empty. Merged with the host's actions and
    /// the built-in switch under the same last-wins policy — this is what
    /// lets a plugin's verbs (like Phase 8's combat `attack`) actually do
    /// something by default, not just parse.
    @ActionBuilder var actions: [IntentAction] { get }

    /// Self-contained, world-scoped rules the plugin adds without needing
    /// anything from the host. Defaults to empty. Rules that must reference the
    /// host's own entities are exposed as parameterized methods instead.
    @RuleBuilder var rules: Rules { get }
}

extension GamePlugin {
    /// Plugins that add no verbs of their own can omit the `verbs` block.
    public var verbs: [SyntaxRule] { [] }

    /// Plugins that replace or add no default actions can omit the `actions`
    /// block.
    public var actions: [IntentAction] { [] }

    /// Plugins with no self-contained rules can omit the `rules` block.
    public var rules: Rules { Rules(rules: []) }
}
