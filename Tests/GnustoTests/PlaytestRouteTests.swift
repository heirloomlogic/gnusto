import Foundation
import Testing

@testable import Gnusto

/// The routes this checkout ships, read as data rather than as code.
///
/// A deep start used to be `.gnusto` bytes under gitignored `.context/`, which is
/// why a focus file describing nine saved games and a checkout holding none of
/// them looked identical — and why four real defects were discarded as
/// `not-reproducible` in one round. Routes are committed text instead, and the
/// property that buys back is that a test can simply read them.
///
/// So this suite guards the files, not the loader: ``PlaytestSessionTests`` covers
/// what `load` does with a bad manifest, and what is left to go wrong is a route
/// file that is deleted, renamed, or committed in a state no session could open.
/// Each of those is silent until a round is dispatched, which is the worst moment
/// to find out.
struct PlaytestRouteTests {
    /// The package's `.playtest/` directory, found relative to this file rather
    /// than to the working directory, which a test process does not control.
    private static let playtestDirectory =
        URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // GnustoTests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // the package
        .appendingPathComponent(".playtest", isDirectory: true)

    /// The environment that points the loader at the committed routes rather than
    /// at whatever `.playtest/` the working directory happens to hold.
    private static let environment = ["GNUSTO_PLAYTEST_ROUTES": playtestDirectory.path]

    /// Every game with a routes directory, and the route names in it — asked of
    /// ``PlaytestRoute`` both times, so a change to where routes live or what
    /// counts as one moves this suite with it instead of leaving it asserting the
    /// old layout.
    private static func committedRoutes() -> [(game: String, names: [String])] {
        let games =
            ((try? FileManager.default.contentsOfDirectory(atPath: playtestDirectory.path))
            ?? []).sorted()
        return games.compactMap { game in
            let names = PlaytestRoute.names(
                in: PlaytestRoute.root(game: game, environment: environment))
            return names.isEmpty ? nil : (game, names)
        }
    }

    private static func load(_ name: String, of game: String) throws -> PlaytestRoute {
        try PlaytestRoute.load(named: name, game: game, environment: environment)
    }

    @Test func everyCommittedRouteLoadsAndSaysWhereItLands() throws {
        let all = Self.committedRoutes()
        #expect(!all.isEmpty, "this package ships routes; finding none means the path is wrong")
        for (game, names) in all {
            for name in names {
                // The one field a person choosing between deep starts reads, and the
                // one `bin/playtest-routes verify` holds a replay to. A route with no
                // landing is replayed and not checked, which is a fine state for a
                // hand-written file and not one to commit.
                #expect(
                    try Self.load(name, of: game).landingRoom?.isEmpty == false,
                    "\(game)/\(name) declares no landing room")
            }
        }
    }

    /// A round pins one seed for every seat, and `open` refuses a session whose
    /// seed is not the route's — so two routes of one game under two seeds cannot
    /// both be handed out in one round. `bin/playtest-preflight` derives the
    /// round's seed from these manifests for that reason, and a disagreement here
    /// is a round that would refuse half its testers at `open`.
    @Test func allOfAGamesRoutesAgreeOnOneSeed() throws {
        for (game, names) in Self.committedRoutes() {
            let seeds = try Set(names.map { try Self.load($0, of: game).seed })
            #expect(seeds.count == 1, "\(game)'s routes declare seeds \(seeds.sorted())")
        }
    }

    /// Dungeon's map outruns any round's turn budget, so its regions are written
    /// to be reached from a deep start rather than walked to. These nine are the
    /// starts `docs/games/dungeon-playtest-focus.md` sends testers to by name.
    ///
    /// The list is written here rather than derived from the focus file because
    /// the focus file is prose a person edits between rounds: deleting a route it
    /// names costs nothing until a round is dispatched, and then it costs the
    /// region. This is the only thing that notices.
    @Test func dungeonShipsTheNineDeepStartsItsRegionsNameByName() {
        let shipped = Set(Self.committedRoutes().first { $0.game == "Dungeon" }?.names ?? [])
        let named: Set = ["z-1", "z-2", "d-1", "m-1", "m-2", "c-1", "c-2", "p-1", "p-2"]
        #expect(
            shipped.isSuperset(of: named),
            "Dungeon routes not committed: \(named.subtracting(shipped).sorted())")
    }
}
