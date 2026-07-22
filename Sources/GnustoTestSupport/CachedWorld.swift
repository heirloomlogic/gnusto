import Foundation
import Gnusto
import Synchronization

/// Per-game-type cache of prepared games. `Bootstrap.build` is a pure function
/// of the game type, and its dominant cost — `Mirror` reflection over the game
/// and every content bundle — runs ~15× longer than a turn. The suite boots the
/// same handful of game types thousands of times, so building each type once and
/// reusing the prepared definition removes bootstrap as the suite's dominant
/// cost. Guarded by a `Mutex` because Swift Testing runs suites in parallel;
/// `PreparedGame` is `Sendable`, safe to share once built.
private let preparedGames = Mutex<[ObjectIdentifier: PreparedGame]>([:])

/// Builds a `GameWorld` from a per-type-cached `PreparedGame`, so repeated boots
/// of the same game across the suite pay `Bootstrap.build` only once. The world
/// is otherwise identical to `GameWorld(game:seed:saveDirectory:)`: it copies the
/// shared value-type definition and pristine state and applies its own seed, so
/// worlds never share mutable state.
///
/// - Parameters:
///   - game: the game to boot.
///   - seed: pins the random stream; a fresh stream when nil.
///   - saveDirectory: where bare `save`/`restore` names resolve; nil uses the
///     engine default.
/// - Throws: rethrows any bootstrap error, on the first build of a given type.
/// - Returns: a fresh world sharing the cached definition and pristine state.
public func cachedWorld(
    _ game: some Game,
    seed: UInt64? = nil,
    saveDirectory: URL? = nil
) throws -> GameWorld {
    let key = ObjectIdentifier(type(of: game))
    let prepared = try preparedGames.withLock { cache in
        if let hit = cache[key] { return hit }
        let built = try PreparedGame(game)
        cache[key] = built
        return built
    }
    return GameWorld(
        prepared: prepared,
        seed: seed ?? UInt64.random(in: .min ... .max),
        saveDirectory: saveDirectory)
}
