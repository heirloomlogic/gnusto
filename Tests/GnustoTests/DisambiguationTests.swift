import Testing

@testable import Gnusto

/// Phase 6 disambiguation: the parser's clarifying questions accept an
/// answer on the next line — adjectives, a fuller phrase, or the missing
/// object — or a fresh command that abandons the question.
struct DisambiguationTests {
    @Test func anAdjectiveAnswersTheQuestion() async throws {
        let transcript = try await play(
            LanternShopGame(), ["take lantern", "rusty", "score"])
        expectInOrder(
            transcript,
            [
                "Which do you mean: the brass lantern or the rusty lantern "
                    + "or the small brass lantern?",
                "Taken.",
                // The question was free: only the completed take counted.
                "in 1 turn",
            ])
    }

    @Test func aFullPhraseAnswersTheQuestion() async throws {
        let transcript = try await play(
            LanternShopGame(), ["take lantern", "the rusty lantern", "i"])
        expectInOrder(transcript, ["Which do you mean", "Taken.", "rusty lantern"])
    }

    @Test func narrowingCanTakeTwoRounds() async throws {
        let transcript = try await play(
            LanternShopGame(), ["take lantern", "brass", "small", "i"])
        expectInOrder(
            transcript,
            [
                "Which do you mean: the brass lantern or the rusty lantern "
                    + "or the small brass lantern?",
                "Which do you mean: the brass lantern or the small brass lantern?",
                "Taken.",
                "small brass lantern",
            ])
    }

    @Test func aMissingObjectCanBeSupplied() async throws {
        let transcript = try await play(
            LanternShopGame(), ["take", "rusty lantern"])
        expectInOrder(transcript, ["What do you want to take?", "Taken."])
    }

    @Test func aMissingIndirectObjectCanBeSupplied() async throws {
        let transcript = try await play(
            LanternShopGame(), ["hang cloak", "hook"])
        expectInOrder(
            transcript,
            [
                "What do you want to hang the velvet cloak on?",
                "You put the velvet cloak on the iron hook.",
            ])
    }

    @Test func aFreshCommandAbandonsTheQuestion() async throws {
        let transcript = try await play(
            LanternShopGame(), ["take lantern", "look", "brass"])
        expectInOrder(
            transcript,
            [
                "Which do you mean",
                // "look" runs as its own command…
                "Shelves of lanterns.",
                // …and the pending question is gone: a stray "brass" now
                // parses fresh instead of completing anything.
                "I didn't understand that sentence.",
            ])
        let brassTurn = turnOutput(of: "brass", in: transcript)
        #expect(!brassTurn.contains("Taken."))
    }
}
