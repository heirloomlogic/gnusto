import GnustoTestSupport
import Testing

@testable import Gnusto

/// The `while:` aggression gate on `MeleeCombat.aggression`: a closed gate is
/// a quiet turn — the villain doesn't counter-attack and, crucially, draws no
/// randomness, so a scoped fight (the thief only swings in his lair) leaves
/// every other seeded draw sequence intact.
struct AggressionGateTests {
    @Test func aClosedGateSuppressesTheCounterAttack() async throws {
        // Gate starts closed: the heckler never swings, however long we wait
        // in the ring with him.
        let transcript = try await play(
            GatedArenaGame(),
            ["wait", "wait", "wait", "quit"],
            seed: 1)
        #expect(!transcript.contains("The heckler jabs and misses."))
        #expect(!transcript.contains("The heckler cuffs you."))
        // The wait line still prints — it was a normal turn, just a quiet one.
        #expect(transcript.contains("Time passes."))
    }

    @Test func openingTheGateResumesTheDrawExactlyWhereItLeftOff() async throws {
        // The whole point of gating *before* the draw: turns spent with the
        // gate closed burn no randomness. So the heckler's first roll after
        // being provoked must be identical whether or not the player idled
        // first — the closed turns didn't advance the stream.
        let seed: UInt64 = 3
        let idleFirst = try await play(
            GatedArenaGame(),
            ["wait", "wait", "provoke", "wait", "quit"],
            seed: seed)
        let straightIn = try await play(
            GatedArenaGame(),
            ["provoke", "wait", "quit"],
            seed: seed)
        // The first post-provoke aggression line is the same in both runs.
        let idleLine = firstHecklerLine(in: turnOutputAfterProvoke(idleFirst))
        let directLine = firstHecklerLine(in: turnOutputAfterProvoke(straightIn))
        #expect(idleLine != nil)
        #expect(idleLine == directLine)
    }

    /// Everything the game printed after the `provoke` command.
    private func turnOutputAfterProvoke(_ transcript: String) -> String {
        guard let range = transcript.range(of: "You provoke the heckler.") else { return "" }
        return String(transcript[range.upperBound...])
    }

    /// The first heckler aggression line in a slice of transcript.
    private func firstHecklerLine(in slice: String) -> String? {
        for line in slice.split(separator: "\n") where line.contains("heckler") {
            return String(line)
        }
        return nil
    }
}
