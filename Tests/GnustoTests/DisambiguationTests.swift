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

    /// A phrase with no noun in it describes rather than names. One that
    /// describes exactly one thing in view is answered outright — `take
    /// velvet` is the velvet cloak, where it used to be "You can\'t see any
    /// such thing." with the cloak on the player\'s shoulders. Issue #445.
    @Test func aBareAdjectiveThatPicksOutOneThingIsAnswered() async throws {
        let transcript = try await play(LanternShopGame(), ["drop cloak", "take velvet", "i"])
        expectInOrder(transcript, ["Dropped.", "Taken.", "velvet cloak"])
    }

    /// One that describes two things asks which — and the question is
    /// answerable, because a phrase missing its *noun* is answered behind the
    /// adjectives rather than in front of them. Spliced the other way, the
    /// line would come back as `take lantern brass`.
    @Test func aBareAdjectiveOverTwoThingsAsksAnAnswerableQuestion() async throws {
        let transcript = try await play(
            LanternShopGame(), ["take brass", "lantern", "small", "i"])
        expectInOrder(
            transcript,
            [
                "Which do you mean: the brass lantern or the small brass lantern?",
                // The noun answered, and left the same two things standing.
                "Which do you mean: the brass lantern or the small brass lantern?",
                "Taken.",
                "small brass lantern",
            ])
    }

    /// Courtesy is filler: `please` is dropped from the line the way `the` is,
    /// so the sentence in front of it runs as it always did. Issue #445.
    @Test func aPoliteCommandIsTheCommand() async throws {
        let transcript = try await play(LanternShopGame(), ["drop cloak please", "i"])
        #expect(turnOutput(of: "drop cloak please", in: transcript).contains("Dropped."))
        expectEveryNounAnswered(transcript)
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

    /// #445 round 3: a possessive is dropped inside `resolveNoun`, but the
    /// slot's `phraseStart` stayed on the dropped word — so an answer to a
    /// question raised behind one spliced in front of the possessive rather
    /// than in front of the noun. `x her door` + `wooden` became `x wooden her
    /// door`, which parses as nothing; `x door` + `wooden` always worked.
    @Test func anAmbiguityBehindAPossessiveCanBeAnswered() async throws {
        let transcript = try await play(DoorGiftGame(), ["x her door", "wooden"])
        expectInOrder(
            transcript,
            [
                "Which do you mean: the trap door or the wooden door?",
                "You see nothing special about the wooden door.",
            ])
        #expect(!transcript.contains("isn't one I recognize"))
    }
}
