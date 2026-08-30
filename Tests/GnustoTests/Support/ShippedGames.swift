import Testing

@testable import CloakOfDarkness
@testable import Dungeon
@testable import Fulminate
@testable import Gnusto
@testable import Gramarye
@testable import KindlyDeep
@testable import Lighthouse
@testable import Zork1

/// Every game this package ships, bootstrapped, for the sweeps that have to ask
/// their question of all of them.
///
/// It exists because the list was written out twice and the two copies had
/// already drifted: `VocabularyTests` named six games and omitted **Dungeon**,
/// the largest of them, so the word-is-typeable sweep was silently not covering
/// the game with the most words in it. A sweep that names its own games will
/// miss the next one added, and nothing fails when it does.
enum ShippedGames {
    /// The seven, each with the title a failure message should print.
    ///
    /// `Bootstrap.build` rather than `cachedWorld`, which would reuse builds
    /// other suites have already paid for: `GameWorld.definition` is
    /// actor-isolated, so reading it from a synchronous helper does not compile.
    static func definitions() throws -> [(String, GameDefinition)] {
        [
            ("CloakOfDarkness", try Bootstrap.build(OperaHouse()).0),
            ("Dungeon", try Bootstrap.build(Dungeon()).0),
            ("Fulminate", try Bootstrap.build(Fulminate()).0),
            ("Gramarye", try Bootstrap.build(Gramarye()).0),
            ("KindlyDeep", try Bootstrap.build(KindlyDeep()).0),
            ("Lighthouse", try Bootstrap.build(Lighthouse()).0),
            ("Zork1", try Bootstrap.build(Zork1()).0),
        ]
    }
}
