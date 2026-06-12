import Testing

@testable import Gnusto

struct PipelineTests {
    @Test func stagesRunInOrder() async throws {
        let transcript = try await play(OrderProbeGame(), ["take widget"])
        expectInOrder(
            transcript,
            [
                "[locEachBefore]",
                "[locBefore]",
                "[itemBefore]",
                "Taken.",
                "[itemAfter]",
                "[locAfter]",
                "[locEachAfter]",
            ])
    }

    @Test func refuseSkipsDefaultAndAftersButNotEachTurn() async throws {
        let transcript = try await play(OrderProbeGame(), ["drop widget", "take widget"])
        let refusedTurn = turnOutput(of: "take widget", in: transcript)

        expectInOrder(refusedTurn, ["[itemBefore]", "[refused]", "[locEachAfter]"])
        #expect(!refusedTurn.contains("Taken."))
        #expect(!refusedTurn.contains("[itemAfter]"))
        #expect(!refusedTurn.contains("[locAfter]"))
        // World time still passes on refused turns.
        #expect(refusedTurn.contains("[locEachAfter]"))
    }

    @Test func metaIntentsSkipRulesAndClock() async throws {
        let transcript = try await play(OrderProbeGame(), ["score", "score"])
        let scoreTurn = turnOutput(of: "score", in: transcript)
        #expect(!scoreTurn.contains("[locEachBefore]"))
        #expect(!scoreTurn.contains("[locEachAfter]"))
        // The clock didn't advance: both score reports say 0 turns.
        #expect(transcript.contains("in 0 turns"))
        #expect(!transcript.contains("in 1 turn"))
    }

    @Test func parseErrorsDoNotConsumeATurn() async throws {
        let transcript = try await play(
            OrderProbeGame(), ["frotz", "take grue", "score"])
        let frotzTurn = turnOutput(of: "frotz", in: transcript)
        #expect(!frotzTurn.contains("[locEachBefore]"))
        #expect(transcript.contains("in 0 turns"))
    }

    @Test func replyPreemptsTheDefaultAction() async throws {
        let transcript = try await play(OrderProbeGame(), ["examine widget"])
        let turn = turnOutput(of: "examine widget", in: transcript)
        #expect(turn.contains("blunders=0"))
        #expect(!turn.contains("You see nothing special"))
    }
}
