import GnustoTestSupport
import Testing

@testable import Gnusto

/// The `.topic` slot: a pattern position that takes the rest of the line as
/// an abstract subject rather than looking it up in the room.
///
/// The behavior everything else here exists to protect is the second test.
/// Object slots resolve against scope, so a subject routed through one would
/// make every conversation a guessing game about the game's noun list — you
/// could only ask about things that happened to be standing in front of you.
/// A topic deliberately skips that, which is why it needs its own slot rather
/// than a scenery item pretending to be one.
struct TopicSlotTests {
    static func makeParser() throws -> StandardParser {
        let (definition, _) = try Bootstrap.build(ManorParserGame())
        return StandardParser(
            vocabulary: definition.vocabulary,
            syntaxRules: definition.syntaxRules)
    }

    static let scope = Scope(visibleItems: [EntityID("butler"), EntityID("lamp")])

    // MARK: - Filling the slot

    @Test func aTopicFollowsAnObjectAndItsIntroducingWord() throws {
        let parser = try Self.makeParser()
        let parsed = try parser.parse("ask butler about the murder", scope: Self.scope).get()
        #expect(parsed.intent == Intent("ask"))
        #expect(parsed.directObject == EntityID("butler"))
        #expect(parsed.topic == ["murder"])
        // "about" is fixed by the pattern, so it tells a rule nothing the
        // intent doesn't. Promoting it would change what existing games see
        // for "turn lamp on" and its like.
        #expect(parsed.preposition == nil)
    }

    /// The headline: a subject the game has never heard of still reaches the
    /// rules. Anything that routes topics through scope resolution breaks
    /// here first.
    @Test func aSubjectTheGameHasNeverHeardOfStillParses() throws {
        let parser = try Self.makeParser()
        let parsed = try parser.parse("ask butler about zeppelins", scope: Self.scope).get()
        #expect(parsed.topic == ["zeppelins"])
    }

    @Test func aTopicTakesEveryRemainingWord() throws {
        let parser = try Self.makeParser()
        let parsed = try parser.parse("ask butler about the dead body", scope: Self.scope).get()
        #expect(parsed.topic == ["dead", "body"])
    }

    /// The object slot closes on the *first* "about", so the rest — including
    /// a second "about" — belongs to the topic.
    @Test func theObjectSlotClosesOnTheFirstIntroducingWord() throws {
        let parser = try Self.makeParser()
        let parsed = try parser.parse(
            "ask butler about the letter about mary", scope: Self.scope
        ).get()
        #expect(parsed.directObject == EntityID("butler"))
        #expect(parsed.topic == ["letter", "about", "mary"])
    }

    @Test func punctuationIsStrippedLikeAnywhereElse() throws {
        let parser = try Self.makeParser()
        let parsed = try parser.parse("ask butler about Mr. Quivers!", scope: Self.scope).get()
        #expect(parsed.topic == ["mr", "quivers"])
    }

    @Test func aTopicCanFollowTheVerbWithNoObjectAtAll() throws {
        let parser = try Self.makeParser()
        let parsed = try parser.parse("think about mary", scope: Self.scope).get()
        #expect(parsed.directObject == nil)
        #expect(parsed.topic == ["mary"])
        #expect(parsed.verbPhrase == "think about")
    }

    @Test func aTopicCanFollowTheVerbWordDirectly() throws {
        let parser = try Self.makeParser()
        let parsed = try parser.parse("mutter hello there", scope: Self.scope).get()
        #expect(parsed.topic == ["hello", "there"])
    }

    // MARK: - An empty slot

    @Test func anEmptyTopicAsksWhatAbout() throws {
        let parser = try Self.makeParser()
        let result = parser.parse("ask butler about", scope: Self.scope)
        #expect(
            result
                == .failure(
                    .missingTopic(
                        verb: "ask", objectName: "butler", preposition: "about",
                        prefix: ["ask", "butler", "about"])))
    }

    /// Here "about" is part of the verb phrase rather than a word closing an
    /// object slot, so the introducing word comes back empty — which is what
    /// keeps the question from reading "think about about?".
    @Test func anEmptyTopicOnAnObjectlessRowStillAsks() throws {
        let parser = try Self.makeParser()
        let result = parser.parse("think about", scope: Self.scope)
        #expect(
            result
                == .failure(
                    .missingTopic(
                        verb: "think about", objectName: nil, preposition: "",
                        prefix: ["think", "about"])))
    }

    @Test(arguments: [
        ("ask butler about", "What do you want to ask the butler about?"),
        ("think about", "What do you want to think about?"),
        ("mutter", "What do you want to mutter?"),
    ])
    func theQuestionReadsNaturallyForEveryShapeOfTopicRow(
        _ input: String, _ expected: String
    ) throws {
        let parser = try Self.makeParser()
        guard case .failure(let error) = parser.parse(input, scope: Self.scope) else {
            Issue.record("expected \"\(input)\" to ask a question")
            return
        }
        #expect(error.playerMessage(GameText()) == expected)
    }

    /// Filler collapses to nothing, so this is the empty case in disguise —
    /// pinned as known behavior rather than a surprise. It matches what a
    /// bare "take" already does.
    @Test func aTopicOfNothingButFillerIsAnEmptyTopic() throws {
        let parser = try Self.makeParser()
        let result = parser.parse("ask butler about that", scope: Self.scope)
        guard case .failure(.missingTopic) = result else {
            Issue.record("expected a missing-topic question, got \(result)")
            return
        }
    }

    /// The object still has to resolve. A topic row whose addressee isn't
    /// here fails on the addressee, not on the subject.
    @Test func anObjectThatIsNotHereStillFails() throws {
        let parser = try Self.makeParser()
        let result = parser.parse("ask footman about the murder", scope: Self.scope)
        #expect(result == .failure(.notInScope))
    }

    // MARK: - Reaching the game

    @Test func theTopicReachesARuleBody() async throws {
        let transcript = try await play(ManorParserGame(), ["ask butler about the dead body"])
        #expect(transcript.contains("The butler considers \"dead body\"."))
    }

    /// The question and its answer reparse as one command, the same
    /// round-trip a missing object gets.
    @Test func theQuestionCanBeAnsweredOnTheNextLine() async throws {
        let transcript = try await play(ManorParserGame(), ["ask butler about", "the murder"])
        expectInOrder(
            transcript,
            [
                "What do you want to ask the butler about?",
                "The butler considers \"murder\".",
            ])
    }

    // MARK: - Malformed patterns

    @Test func malformedTopicPatternsAreFatalTogether() {
        #expect {
            _ = try Bootstrap.build(BadTopicPatternsGame())
        } throws: { error in
            guard let bootstrapError = error as? BootstrapError else { return false }
            let text = bootstrapError.diagnostics.joined(separator: "\n")
            // `contains`, not a count: the direction row trips the existing
            // "must end with its direction slot" check as well as the new one.
            return text.contains("must end with its topic slot")
                && text.contains("has more than one topic slot")
                && text.contains("combines a topic slot with a <second object> slot")
                && text.contains("combines a topic slot with a direction slot")
                && text.contains("needs a literal word between an object slot")
        }
    }

    // MARK: - Normalization

    @Test func normalizeMatchesWhatThePlayerTypesAfterTheParserIsDoneWithIt() {
        #expect(Topic.normalize("The DEAD body!") == ["dead", "body"])
        #expect(Topic.normalize("a murder") == ["murder"])
        #expect(Topic.normalize("Mr. Quivers") == ["mr", "quivers"])
        #expect(Topic(["dead", "body"]).text == "dead body")
    }
}
