import Testing

@testable import Gnusto

/// The question family, pinned as a family.
///
/// A *question* error is one the next input line answers: it carries the tokens
/// an answer completes, and it survives being re-anchored on the person an order
/// was aimed at. Three properties have to agree about which errors those are,
/// and the ones that go wrong go wrong silently — a question that forgets its
/// answer context parses the player's reply as a fresh command, and one that
/// forgets to be re-anchored turns the rest of an order into the player's own
/// move.
///
/// So rather than a test per case written whenever somebody remembers, the whole
/// enum is enumerated once here and every case is asked both questions.
struct ParseErrorTests {
    /// The tokens an order puts back on the front.
    static let address = ["gnome"]

    /// One question case: the error, the answer context it must report, and
    /// what it must become when an order re-anchors it. `addressed` is written
    /// out longhand on purpose — it is what catches a re-anchoring that rebuilds
    /// the right shape while dropping a payload.
    struct Question {
        let error: ParseError
        let prefix: [String]
        var suffix: [String] = []
        let addressed: ParseError
    }

    static let questions: [Question] = [
        Question(
            error: .missingObject(verb: "take", prefix: ["take"]),
            prefix: ["take"],
            addressed: .missingObject(verb: "take", prefix: ["gnome", ",", "take"])
        ),
        Question(
            error: .missingIndirect(
                verb: "hang", objectName: "the velvet cloak", preposition: "on",
                prefix: ["hang", "cloak", "on"]),
            prefix: ["hang", "cloak", "on"],
            addressed: .missingIndirect(
                verb: "hang", objectName: "the velvet cloak", preposition: "on",
                prefix: ["gnome", ",", "hang", "cloak", "on"])
        ),
        Question(
            error: .missingTopic(
                verb: "ask", objectName: "the butler", preposition: "about",
                prefix: ["ask", "butler", "about"]),
            prefix: ["ask", "butler", "about"],
            addressed: .missingTopic(
                verb: "ask", objectName: "the butler", preposition: "about",
                prefix: ["gnome", ",", "ask", "butler", "about"])
        ),
        // The objectless topic row — `think about` — keeps its nil object
        // across the round trip.
        Question(
            error: .missingTopic(
                verb: "think about", objectName: nil, preposition: "",
                prefix: ["think", "about"]),
            prefix: ["think", "about"],
            addressed: .missingTopic(
                verb: "think about", objectName: nil, preposition: "",
                prefix: ["gnome", ",", "think", "about"])
        ),
        Question(
            error: .missingDirection(
                verb: "shift", objectName: "the wooden crate", prefix: ["shift", "box"]),
            prefix: ["shift", "box"],
            addressed: .missingDirection(
                verb: "shift", objectName: "the wooden crate",
                prefix: ["gnome", ",", "shift", "box"])
        ),
        // The one question whose answer goes in the *middle* of the line: the
        // adjective belongs ahead of the phrase it narrows.
        Question(
            error: .ambiguous(
                names: ["the wooden crate", "the iron crate"], prefix: ["shift"],
                suffix: ["crate", "north"]),
            prefix: ["shift"],
            suffix: ["crate", "north"],
            addressed: .ambiguous(
                names: ["the wooden crate", "the iron crate"],
                prefix: ["gnome", ",", "shift"], suffix: ["crate", "north"])
        ),
    ]

    /// Every error that is not a question. These have nowhere to put an answer
    /// and nothing to re-anchor, so the next line is a fresh command.
    static let refusals: [ParseError] = [
        .empty,
        .unknownWord("frotz"),
        .notInScope,
        .notAVerb("crate"),
        .noReferent("it"),
        .unmatchedSyntax,
        .multipleNotAllowed,
        .notTakingOrders(GameText.Noun("the butler")),
    ]

    // MARK: - The answer context

    @Test(arguments: questions)
    func aQuestionReportsWhereItsAnswerGoes(_ expected: Question) {
        guard let context = expected.error.clarification else {
            Issue.record("\(expected.error) asks a question but offers nowhere to answer it")
            return
        }
        #expect(context.prefix == expected.prefix)
        #expect(context.suffix == expected.suffix)
    }

    @Test(arguments: refusals)
    func aRefusalIsNotAnswerable(_ error: ParseError) {
        #expect(error.clarification == nil, "\(error) should not hold the next line open")
    }

    // MARK: - Re-anchoring on an order

    @Test(arguments: questions)
    func anOrderCarriesItsQuestionBackToTheAddressee(_ expected: Question) {
        #expect(expected.error.addressed(to: Self.address) == expected.addressed)
    }

    /// Re-anchoring moves the answer context and nothing else — the question the
    /// player reads is the same one either way. `gnome, shift box` and
    /// `shift box` both ask which way.
    @Test(arguments: questions)
    func addressingAQuestionDoesNotChangeHowItReads(_ expected: Question) {
        let text = GameText()
        #expect(
            expected.error.addressed(to: Self.address).playerMessage(text)
                == expected.error.playerMessage(text))
    }

    /// An order that fails on something other than a question fails the same way
    /// unaddressed. "I don't know the word" doesn't get a comma glued to it.
    @Test(arguments: refusals)
    func addressingARefusalIsANoOp(_ error: ParseError) {
        #expect(error.addressed(to: Self.address) == error)
    }

    // MARK: - The round trip, end to end

    /// The invariant the whole family exists for: `prefix + answer + suffix`
    /// reparses as the command the player meant, and it still does after an
    /// order has re-anchored it.
    @Test(arguments: questions)
    func theAnswerContextRebuildsTheWholeLine(_ expected: Question) throws {
        let addressed = expected.error.addressed(to: Self.address)
        let context = try #require(addressed.clarification)
        #expect(context.prefix == Self.address + [","] + expected.prefix)
        #expect(context.suffix == expected.suffix)
    }
}
