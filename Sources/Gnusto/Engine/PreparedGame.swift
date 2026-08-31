/// A game booted once — the immutable `GameDefinition` and its pristine initial
/// `WorldState` — ready to spin up any number of `GameWorld`s without re-running
/// `Bootstrap.build`.
///
/// `Bootstrap.build` is a pure function of the game *type*: `Game.init()` takes
/// no input, every declaration is reflected from the type, and the random seed
/// is applied per world afterward — never baked into the definition or the
/// pristine state. Its dominant cost is `Mirror` reflection over the game and
/// every content bundle. Preparing a game once and seeding many worlds from it
/// therefore pays that cost a single time; each world copies the value-type
/// definition and state and applies its own seed. `Sendable`, so a prepared
/// game is safe to share across concurrently-running worlds.
public struct PreparedGame: Sendable {
    let definition: GameDefinition
    let state: WorldState
    /// The parser, built once from the definition's vocabulary and (sorted)
    /// syntax rules. Like the definition it is a pure function of the game type,
    /// so it is prepared here and shared rather than re-sorted per world.
    let parser: StandardParser

    /// The game type's own name — `Dungeon`, `OperaHouse` — as spelled in the
    /// source.
    ///
    /// Not the title. A title is prose the author is free to rewrite (`Zork I:
    /// The Great Underground Empire`), and it has to survive being a directory
    /// name, which that one does not. The type name is a Swift identifier by
    /// construction, so it is the key ``PlaytestRoute`` files deep starts under
    /// and the reason a package building seven games keeps their routes apart
    /// while a package building one needs no configuration at all.
    let typeName: String

    /// Boots `game` through the full validation and bootstrap pipeline.
    ///
    /// - Parameter game: the game to build.
    /// - Throws: if the game definition is invalid.
    public init(_ game: some Game) throws {
        (definition, state) = try Bootstrap.build(game)
        parser = StandardParser(
            vocabulary: definition.vocabulary,
            syntaxRules: definition.syntaxRules)
        // `type(of:)` rather than the generic parameter: the dynamic type is
        // the one the author wrote, and it is what a route directory has to be
        // named after whatever static type this was called through.
        typeName = String(describing: type(of: game))
    }
}
