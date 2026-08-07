import Foundation
import Testing

@testable import Gnusto
@testable import GnustoTestSupport
@testable import Lighthouse

/// `GNUSTO_SEED` pins the suite the way it pins a built binary: a `play` call
/// that passes no `seed:` of its own takes the environment's, so a whole run
/// replays and a sweep across seeds can find a test that only passes because
/// the dice were kind.
///
/// `SeedRequestTests` covers the parsing and that a pinned seed reaches the
/// transcript. What is left to prove here is the precedence — the argument
/// beats the environment beats a fresh draw — asserted against `rngState` on
/// the real boot path, because a fallback that silently failed to apply would
/// make a green sweep mean nothing at all.
struct TestSeedFallbackTests {
    /// The load-bearing case. A sweep is looking for tests that pass by luck,
    /// so it has to vary only the unpinned ones; if `GNUSTO_SEED` overrode an
    /// explicit `seed:`, the sweep would re-fail every test that pinned a seed
    /// on purpose and say nothing about the ones that didn't.
    @Test func anExplicitSeedBeatsTheEnvironment() async throws {
        let world = try cachedWorld(
            Lighthouse(), seed: 11, saveDirectory: nil, request: .pinned(12345))
        #expect(await world.state.rngState == 11)
    }

    /// Zero has to survive the fallback as a seed rather than an absence — the
    /// same trap `SeedRequest` avoids at parse time.
    @Test(arguments: [UInt64(12345), 0])
    func anUnpinnedBootTakesTheEnvironmentsSeed(seed: UInt64) async throws {
        let world = try cachedWorld(
            Lighthouse(), seed: nil, saveDirectory: nil, request: .pinned(seed))
        #expect(await world.state.rngState == seed)
    }

    /// Nothing pinned means a fresh draw, which is the pre-existing default and
    /// the only answer that keeps an unswept run genuinely random. A typo does
    /// not get to quietly pin the suite either.
    ///
    /// Two worlds boot from one cached `PreparedGame`, so this also pins that
    /// the cache hands back pristine state rather than a world already stepped.
    @Test(arguments: [SeedRequest.unset, .invalid("banana")])
    func nothingPinnedLeavesTheStreamFresh(request: SeedRequest) async throws {
        let first = try cachedWorld(
            Lighthouse(), seed: nil, saveDirectory: nil, request: request)
        let second = try cachedWorld(
            Lighthouse(), seed: nil, saveDirectory: nil, request: request)
        #expect(await first.state.rngState != (await second.state.rngState))
    }
}
