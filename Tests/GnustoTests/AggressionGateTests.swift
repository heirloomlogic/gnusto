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
        // gate closed burn no randomness. So the heckler's rolls after being
        // provoked must be identical whether or not the player idled first —
        // the closed turns didn't advance the stream.
        //
        // Every line, not just the first, and three turns rather than one: the
        // heckler's `strikesFirst` is 25, so each of those turns now costs a
        // strike-first draw as well as an outcome draw until he is engaged. A
        // first-line-only comparison could miss a misplaced strike-first roll
        // that only shows up in the second turn's alignment.
        //
        // Seed 0, recorded: he starts one on the provoked turn and lands three
        // lines in the three turns after it, so the comparison has something to
        // compare.
        let seed: UInt64 = 0
        let idleFirst = try await play(
            GatedArenaGame(),
            ["wait", "wait", "provoke", "wait", "wait", "wait", "quit"],
            seed: seed)
        let straightIn = try await play(
            GatedArenaGame(),
            ["provoke", "wait", "wait", "wait", "quit"],
            seed: seed)
        let idled = lines(mentioning: "heckler", in: output(after: "You provoke the heckler.", in: idleFirst))
        let direct = lines(mentioning: "heckler", in: output(after: "You provoke the heckler.", in: straightIn))
        #expect(idled.count >= 2)
        #expect(idled == direct)
    }
}
