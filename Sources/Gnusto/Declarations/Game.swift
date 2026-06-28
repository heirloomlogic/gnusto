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
}

extension Game {
    /// Defaults to an empty tagline.
    public var tagline: String { "" }

    /// Defaults to a maximum score of zero.
    public var maxScore: Int { 0 }

    /// Games without custom logic can omit the `rules` block.
    public var rules: Rules { Rules(rules: []) }

    /// The player character — usable as a bare identifier in `map` and
    /// `rules` blocks.
    public var player: Player { Player() }

    /// The whole world — for rules that apply everywhere, like daemons.
    public var world: World { World() }

    /// The command currently being performed — usable as a bare identifier
    /// in rule bodies.
    public var command: Command { Ctx.current.command }
}
