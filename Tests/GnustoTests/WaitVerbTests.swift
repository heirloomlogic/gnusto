import GnustoTestSupport
import Testing

@testable import Gnusto

/// The built-in `wait` verb (`wait`, `z`): a normal turn that prints the
/// `timePasses` line and — the whole point — lets fuses and daemons tick.
struct WaitVerbTests {
    @Test func waitPrintsTheTimePassesLine() async throws {
        let transcript = try await play(KettleGame(), ["wait", "quit"])
        #expect(turnOutput(of: "wait", in: transcript).contains("Time passes."))
    }

    @Test func zIsAnAliasForWait() async throws {
        let transcript = try await play(KettleGame(), ["z", "quit"])
        #expect(turnOutput(of: "z", in: transcript).contains("Time passes."))
    }

    @Test func waitTicksFusesUntilTheyFire() async throws {
        // The kettle fuse is armed for 3 ticks. Two waits aren't enough; the
        // third boils it — proving wait is a normal, time-passing turn.
        let transcript = try await play(
            KettleGame(),
            ["wait", "wait", "wait", "quit"])
        let waits = transcript.components(separatedBy: "> wait")
        #expect(!waits[1].contains("The kettle boils."))
        #expect(!waits[2].contains("The kettle boils."))
        #expect(waits[3].contains("The kettle boils."))
    }

    @Test func theWaitLineIsReskinnable() async throws {
        let transcript = try await play(QuietKettleGame(), ["wait", "quit"])
        let wait = turnOutput(of: "wait", in: transcript)
        #expect(wait.contains("A moment slips by."))
        #expect(!wait.contains("Time passes."))
    }
}
