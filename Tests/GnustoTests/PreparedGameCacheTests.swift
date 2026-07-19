import Foundation
import Gnusto
import GnustoTestSupport
import Testing

@testable import Zork1

/// The suite shares one `PreparedGame` per game type across every `play()`
/// (issue #62): the definition and pristine state are built once and reused.
/// These guard the one real hazard of that sharing — that a reused definition
/// (whose rule/`onDeath` closures were captured from the first booted instance)
/// might leak state from one world into the next.
struct PreparedGameCacheTests {
    /// Two worlds built from the same cached prepared game, same seed, same
    /// commands, must produce byte-identical transcripts. If the shared
    /// definition or pristine state carried mutation between worlds, the second
    /// run would drift.
    @Test func sameSeedRunsAreByteIdenticalAcrossCachedBoots() async throws {
        let commands = [
            "open mailbox", "read leaflet", "north", "north", "open window",
            "enter", "west", "take lantern", "turn on lantern", "inventory",
        ]
        let first = try await play(Zork1(), commands, seed: 424_242)
        let second = try await play(Zork1(), commands, seed: 424_242)
        #expect(first == second)
    }
}
