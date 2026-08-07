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

/// What `GNUSTO_SEED` asked of the suite, read once per process — `cachedWorld`
/// runs thousands of times in a suite, and a typo deserves one complaint rather
/// than thousands.
private let environmentSeedRequest: SeedRequest = {
    let request = SeedRequest(environment: ProcessInfo.processInfo.environment)
    if let complaint = request.complaint { writeToStandardError(complaint) }
    return request
}()

/// Builds a `GameWorld` from a per-type-cached `PreparedGame`, so repeated boots
/// of the same game across the suite pay `Bootstrap.build` only once. The world
/// is otherwise identical to `GameWorld(game:seed:saveDirectory:)`: it copies the
/// shared value-type definition and pristine state and applies its own seed, so
/// worlds never share mutable state.
///
/// A boot that pins no seed takes `GNUSTO_SEED`'s, when the environment sets one,
/// and a fresh random seed otherwise. That is what makes `GNUSTO_SEED=7 swift test`
/// replay identically, and a sweep across seeds able to find a test that only
/// passes because the dice were kind.
///
/// - Parameters:
///   - game: the game to boot.
///   - seed: pins the random stream; `GNUSTO_SEED` or a fresh stream when nil.
///   - saveDirectory: where bare `save`/`restore` names resolve; nil uses the
///     engine default.
/// - Throws: rethrows any bootstrap error, on the first build of a given type.
/// - Returns: a fresh world sharing the cached definition and pristine state.
public func cachedWorld(
    _ game: some Game,
    seed: UInt64? = nil,
    saveDirectory: URL? = nil
) throws -> GameWorld {
    try cachedWorld(
        game, seed: seed, saveDirectory: saveDirectory, request: environmentSeedRequest)
}

/// The body of `cachedWorld(_:seed:saveDirectory:)`, with the environment's seed
/// request injected so the fallback can be tested without setting a variable in
/// the running process — `setenv` mid-suite would race, Swift Testing runs suites
/// in parallel.
///
/// The `seed:` argument beating `request` is deliberate. A sweep across seeds is
/// looking for tests that pass *by luck*, so it must vary only the unpinned ones:
/// a sweep that overrode `play(…, seed: 11)` would re-fail every test that pinned
/// a seed on purpose and say nothing about the ones that didn't.
///
/// - Parameters:
///   - game: the game to boot.
///   - seed: pins the random stream; `request`'s seed or a fresh stream when nil.
///   - saveDirectory: where bare `save`/`restore` names resolve; nil uses the
///     engine default.
///   - request: what `GNUSTO_SEED` asked for.
/// - Throws: rethrows any bootstrap error, on the first build of a given type.
/// - Returns: a fresh world sharing the cached definition and pristine state.
func cachedWorld(
    _ game: some Game,
    seed: UInt64?,
    saveDirectory: URL?,
    request: SeedRequest
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
        seed: seed ?? request.value ?? UInt64.random(in: .min ... .max),
        saveDirectory: saveDirectory)
}
