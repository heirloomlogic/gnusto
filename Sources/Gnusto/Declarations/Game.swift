/// A complete game: declarations, geography, and rules.
///
/// Locations, items, and `@Global` state are declared as stored properties;
/// the bootstrap discovers them by reflection and names each after its
/// property. Geography and initial placement live in the `map` block; all
/// game logic lives in the `rules` block.
public protocol Game: Sendable {
    init()

    var title: String { get }
    var intro: String { get }
    var tagline: String { get }
    var maxScore: Int { get }

    @MapBuilder var map: WorldMap { get }
    @RuleBuilder var rules: Rules { get }
}

extension Game {
    public var tagline: String { "" }
    public var maxScore: Int { 0 }

    /// Games without custom logic can omit the `rules` block.
    public var rules: Rules { Rules(rules: []) }

    /// The player character — usable as a bare identifier in `map` and
    /// `rules` blocks.
    public var player: Player { Player() }

    /// The command currently being performed — usable as a bare identifier
    /// in rule bodies.
    public var command: Command { Ctx.current.command }
}
