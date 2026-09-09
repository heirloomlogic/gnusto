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

    /// The cache keys on the game's *type*, so a fixture whose declarations
    /// vary per instance has to come through `play(fresh:)` — and a `fresh`
    /// world takes the same `saveDirectory:` the cached one does, or a
    /// per-instance fixture that saves writes into the real slot directory.
    @Test func aFreshWorldSavesWhereItIsTold() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gnusto-fresh-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let transcript = try await play(
            fresh: TwoStateGame(compact: true),
            ["take lamp", "save", "held", "drop lamp", "restore", "held", "inventory"],
            seed: 0, saveDirectory: dir)

        #expect(turnOutput(of: "inventory", in: transcript).contains("brass lamp"))
        let saved = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        #expect(!saved.isEmpty)
    }

    /// `turnOutput(of:)` is the first time a command ran and
    /// `turnOutput(ofLast:)` the last, so a route that repeats a command can
    /// ask about either end of it.
    @Test func turnOutputSlicesFirstOrLastOccurrence() async throws {
        let transcript = try await play(
            Zork1(), ["look", "open mailbox", "look"], seed: 0)
        let first = turnOutput(of: "look", in: transcript)
        let last = turnOutput(ofLast: "look", in: transcript)
        #expect(first != last)
        #expect(!first.contains("leaflet"))
        #expect(last.contains("leaflet"))
        #expect(turnOutput(ofLast: "frotz", in: transcript) == "")
    }
}
