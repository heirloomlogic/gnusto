import GnustoTestSupport
import Testing

@testable import Gnusto

/// The question a verb typed on its own is owed (#480).
///
/// `take` and `open` end their patterns in the object slot, so the row ran out
/// of line where the slot was and asked for it. Every other shape — a
/// preposition behind the object (`put <object> in <second object>`), a
/// trailing particle (`pick <object> up`) — declined instead, and `parse` fell
/// through to "That sentence isn't one I recognize." about a verb the game
/// knows perfectly well.
struct BareVerbTests {
    /// Every verb in the standard tables whose only one-word candidate rows put
    /// something behind the object slot. Measured off the shipped table rather
    /// than off the issue, which named eight of the eleven.
    static let barePatterns = [
        "give", "hand", "hang", "insert", "lock", "pick", "place", "put", "switch", "throw",
        "unlock",
    ]

    /// The class, and the question's price: each verb asks what to do it to,
    /// and none of the eleven lines became a turn — a parse failure is free,
    /// so the move counter has not moved.
    ///
    /// Driven through the world rather than through `play` so both halves are
    /// read off one run.
    @Test func everyBareVerbAsksWhatToDoItToAndCostsNoTurn() async throws {
        let world = try cachedWorld(AuditLab(), seed: 1)
        _ = await world.begin()

        for verb in Self.barePatterns {
            let turn = await world.perform(verb)
            #expect(turn.output.contains("What do you want to \(verb)?"), "\(verb)")
        }
        #expect(await world.snapshot().moves == 0)
    }

    /// The answer splices in where the row said it would, and the spliced line
    /// is read by the ordinary path — so the two shapes finish the sentence in
    /// the two ways they always did: the preposition row asks its second
    /// question, the particle row reads the particle as understood and acts.
    @Test func theAnswerToTheQuestionFinishesTheSentence() async throws {
        let transcript = try await play(AuditLab(), ["put", "coin", "pick", "sack"])
        #expect(
            turnOutput(of: "coin", in: transcript)
                .contains("What do you want to put the gold coin on?"))
        #expect(turnOutput(of: "sack", in: transcript).contains("Taken."))
    }

    /// **A line that reached the slot is untouched.** One command per shape the
    /// check now stands in front of: the preposition row, the row whose literal
    /// closes a variable-width slot, and the trailing particle. Each keeps the
    /// answer it had, and none of them is the object question.
    @Test func aVerbWithSomethingAfterItAnswersAsBefore() async throws {
        let transcript = try await play(AuditLab(), ["put coin in", "hang cloak", "pick sack"])
        #expect(
            turnOutput(of: "put coin in", in: transcript)
                .contains("What do you want to put the gold coin in?"))
        #expect(
            turnOutput(of: "hang cloak", in: transcript)
                .contains("What do you want to hang the velvet cloak on?"))
        #expect(turnOutput(of: "pick sack", in: transcript).contains("Taken."))
    }

    /// **The mirror shape is not this bug and keeps its answer.** A verb whose
    /// every row leads with two words — `peer through`, `point at`, `speak to`,
    /// `step through`, `say hello to` — names no candidate row at all on its
    /// own, so there is no slot to be short of and no question to ask. Bare SAY
    /// is deliberately nobody's verb (`CoreVerbs`, `.greet`), and the other
    /// four go the same way.
    @Test func aVerbWhoseRowsAllNeedASecondWordStillDeclines() async throws {
        let words = ["peer", "point", "say", "speak", "step"]
        let transcript = try await play(AuditLab(), words)
        for word in words {
            #expect(turnOutput(of: word, in: transcript).contains("understand"), "\(word)")
        }
    }
}
