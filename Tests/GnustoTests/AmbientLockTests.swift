import GnustoTestSupport
import Testing

@testable import Gnusto

/// Issue #402, side two: `text.scoreLine` is an author closure, and it was being
/// called from inside `frame.with { }`.
///
/// The frame's `Mutex` exists to satisfy `@TaskLocal`'s `Sendable` requirement
/// and is not reentrant, so any `scoreLine` that read a `@Global` or an item
/// property took the same lock twice and the process stopped — SCORE at the
/// prompt, and the end-of-game epilogue on the way out. Nothing warned, and no
/// test could have caught it: `GameTextTests` calls `scoreLine` directly with no
/// frame bound, so the second acquisition never happens there.
///
/// Both tests below are about the *lock*, not the wording. What they assert is
/// that a turn which reads state from inside the line comes back at all.
struct AmbientLockTests {
    @Test("a score line that reads a global answers the SCORE verb")
    func scoreLineReadingAGlobalAnswersScore() async throws {
        let output = try await play(
            RankedScoreGame(),
            ["score", "promote", "score"])

        // The default rank, then the promoted one: the closure is reading live
        // state through the frame, which is the whole hazard.
        #expect(output.contains("Rank: Novice."))
        #expect(output.contains("Rank: Adept."))
    }

    @Test("a score line that reads a global answers the end-of-game epilogue")
    func scoreLineReadingAGlobalAnswersTheEpilogue() async throws {
        // The second caller of `DefaultActions.score`, and the one a game
        // reaches without typing SCORE at all.
        let output = try await play(
            RankedScoreGame(),
            ["promote", "bow"])

        #expect(output.contains("Rank: Adept."))
    }
}
