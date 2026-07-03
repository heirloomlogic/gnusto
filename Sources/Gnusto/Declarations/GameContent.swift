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
    /// `verbs`. Defaults to empty. Precedence runs built-ins < bundles/plugins
    /// < host game, so a host verb of the same shape beats this one.
    @VerbBuilder var verbs: [SyntaxRule] { get }

    /// Stage-4 default actions the bundle replaces or adds, in the same form
    /// as a game's `actions`. Defaults to empty. Precedence runs built-ins <
    /// bundles/plugins < host game, so a host action for the same intent beats
    /// this one.
    @ActionBuilder var actions: [IntentAction] { get }

    /// The bundle's fuses and daemons, in the same form as a game's `timers`.
    /// Defaults to empty. Timer names are global — NOT namespaced, since the
    /// bundle's own rules start them by the literal name — so a name shared
    /// with the host or another bundle is a fatal bootstrap diagnostic.
    @TimerBuilder var timers: [TimedEvent] { get }

    /// Prefixes this bundle's entity IDs so its rooms/items/`@Global`s can't
    /// collide with the host game's or another bundle's. A bundle entity stored
    /// as `let hall = Location { … }` becomes `EntityID("\(namespace).hall")`,
    /// while the game's own entities stay bare. This is what lets a reusable
    /// content-bearing plugin be dropped into any host without name clashes.
    ///
    /// Defaults to the bundle's type name (`AtticContent`). A host that stores
    /// **two instances of the same bundle type** must override this to give each
    /// a distinct namespace, since two instances would otherwise derive the same
    /// prefix and collide.
    var namespace: String { get }
}

extension GameContent {
    /// Bundles with no geography of their own can omit the `map` block.
    public var map: WorldMap { WorldMap(entries: []) }

    /// Bundles with no logic of their own can omit the `rules` block.
    public var rules: Rules { Rules(rules: []) }

    /// Bundles that add no verbs of their own can omit the `verbs` block.
    public var verbs: [SyntaxRule] { [] }

    /// Bundles that replace or add no default actions can omit the `actions`
    /// block.
    public var actions: [IntentAction] { [] }

    /// Bundles with no timed events can omit the `timers` block.
    public var timers: [TimedEvent] { [] }

    /// By default a bundle namespaces its entities under its own type name, so
    /// each distinct bundle type gets a distinct prefix automatically.
    public var namespace: String { String(describing: type(of: self)) }
}

/// The collected content bundles a game declares, in declaration order.
public struct GameContents: Sendable {
    let modules: [any GameContent]
}
