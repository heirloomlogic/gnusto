import GnustoTestSupport
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
                "Which do you mean: the brass lantern or the rusty lantern or the small brass lantern?",
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
                "Which do you mean: the brass lantern or the rusty lantern or the small brass lantern?",
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

    /// #445 round 2: the recipient-first GIVE row (`give <recipient>
    /// <gift>`, no "to") lost the answer-insertion context on the recipient
    /// half. `give door lamp` asks "Which do you mean" over the two doors,
    /// but the raw scope error went unpositioned, so the clarifying question
    /// carried an empty prefix/suffix and a one-word answer could not splice
    /// back into the sentence — it parsed alone and failed. The `to` spelling
    /// (`give lamp to door`) never had this bug, because that slot always ran
    /// its error through `positioned(_:tokens:phraseStart:)`.
    @Test func recipientFirstAmbiguityAnswerSplices() async throws {
        let transcript = try await play(
            DoorGiftGame(), ["give door lamp", "wooden"])
        expectInOrder(
            transcript,
            [
                "Which do you mean: the trap door or the wooden door?",
                "You can't give the lamp to the wooden door.",
            ])
        #expect(!transcript.contains("isn't one I recognize"))
    }
}
