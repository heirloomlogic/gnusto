/// A complete game: declarations, geography, and rules.
///
/// Locations, items, and `@Global` state are declared as stored properties;
/// the bootstrap discovers them by reflection and names each after its
/// property. Geography and initial placement live in the `map` block; all
/// game logic lives in the `rules` block.
public protocol Game: Sendable {
    /// Creates the game with every declaration at its starting value.
    ///
    /// Conforming types normally get this for free: when all stored
    /// properties have defaults — the usual case, since locations, items,
    /// and `@Global` state are declared with initializers — Swift
    /// synthesizes the empty `init()` that satisfies this requirement. The
    /// requirement guarantees a game is always constructible from its type
    /// alone, with no external input.
    init()

    /// The game's title, shown in the startup banner.
    var title: String { get }

    /// The opening text printed when play begins, ahead of the title banner
    /// and the first room description.
    var intro: String { get }

    /// A one-line subtitle printed beneath the title in the banner.
    ///
    /// Defaults to empty, in which case the banner shows only the title.
    var tagline: String { get }

    /// The maximum achievable score, rendered in the score line as
    /// "…of a possible N".
    ///
    /// Defaults to zero, which omits the "of a possible" suffix.
    var maxScore: Int { get }

    /// The engine's stock player-facing lines, re-skinnable per game.
    ///
    /// Defaults to the classic voice; override any subset by mutating a
    /// fresh ``GameText`` value.
    var text: GameText { get }

    /// The game's geography and initial entity placement: room exits,
    /// blocked directions, and where the player, items, and scenery start.
    ///
    /// The bootstrap reads this once to build the initial world state.
    @MapBuilder var map: WorldMap { get }

    /// All game logic: the before/after hooks and per-turn rules that react
    /// to what the player does.
    ///
    /// Games without custom behavior can omit it; the default is an empty
    /// rule set.
    @RuleBuilder var rules: Rules { get }

    /// Player-typeable verbs this game adds on top of the built-in table.
    ///
    /// Each row teaches the parser a verb and the sentence shape it accepts,
    /// producing a custom `Intent` that a `before` rule then handles with
    /// `reply(…)`/`refuse(…)`. Defaults to empty. A row whose verb and shape
    /// match a built-in reclaims it (last-wins, with a non-fatal warning).
    @VerbBuilder var verbs: [SyntaxRule] { get }

    /// Content bundles this game composes itself from: each carries its own
    /// rooms, items, `@Global` state, rules, and verbs.
    ///
    /// List the bundles the game stores as properties — `var content { attic;
    /// cellar }` — so the bootstrap discovers those exact instances. Defaults
    /// to empty, in which case the game's own declarations are all there is.
    @ContentBuilder var content: GameContents { get }

    /// The game's fuses and daemons: named timed events whose bodies run at
    /// the end of turns.
    ///
    /// A fuse fires once, N turns after a rule starts it (or from turn one
    /// with `autostart`); a daemon runs every turn while active. Only the
    /// schedule lives in the world's state — the bodies declared here are
    /// re-bound by name on restore. Defaults to empty. Timer names must be
    /// unique across the game and its bundles.
    @TimerBuilder var timers: [TimedEvent] { get }

    /// Stage-4 default actions this game replaces or adds, keyed by intent.
    ///
    /// Each row gives an intent its default behavior — new, for a custom
    /// intent the built-in switch doesn't know; or replacing a built-in's own
    /// default. Defaults to empty. A row whose intent matches a built-in
    /// reclaims it (last-wins, with a non-fatal warning).
    @ActionBuilder var actions: [IntentAction] { get }
}

extension Game {
    /// Defaults to an empty tagline.
    public var tagline: String { "" }

    /// Defaults to a maximum score of zero.
    public var maxScore: Int { 0 }

    /// Defaults to the engine's classic voice.
    public var text: GameText { GameText() }

    /// Games without custom logic can omit the `rules` block.
    public var rules: Rules { Rules(rules: []) }

    /// Games that add no verbs of their own can omit the `verbs` block.
    public var verbs: [SyntaxRule] { [] }

    /// Games authored as a single struct can omit the `content` block.
    public var content: GameContents { GameContents(modules: []) }

    /// Games with no timed events can omit the `timers` block.
    public var timers: [TimedEvent] { [] }

    /// Games that replace or add no default actions can omit the `actions`
    /// block.
    public var actions: [IntentAction] { [] }

    /// The player character — usable as a bare identifier in `map` and
    /// `rules` blocks.
    public var player: Player { Player() }

    /// The whole world — for rules that apply everywhere, like daemons.
    public var world: World { World() }

    /// The command currently being performed — usable as a bare identifier
    /// in rule bodies.
    public var command: Command { Ctx.current.command }
}
