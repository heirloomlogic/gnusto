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

    /// Boots `game` through the full validation and bootstrap pipeline.
    ///
    /// - Parameter game: the game to build.
    /// - Throws: if the game definition is invalid.
    public init(_ game: some Game) throws {
        (definition, state) = try Bootstrap.build(game)
        parser = StandardParser(
            vocabulary: definition.vocabulary,
            syntaxRules: definition.syntaxRules)
    }
}
