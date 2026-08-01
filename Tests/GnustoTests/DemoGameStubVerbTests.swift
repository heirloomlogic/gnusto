import GnustoTestSupport
import Testing

@testable import CloakOfDarkness
@testable import Fulminate
@testable import Gnusto
@testable import Gramarye
@testable import Lighthouse
@testable import Zork1

/// The acceptance criteria for stub verbs, measured on the demo games rather
/// than a fixture. Lighthouse, Gramarye and Cloak of Darkness declare almost no
/// verbs of their own, so what they answer *is* what a game gets for nothing.
struct DemoGameStubVerbTests {
    /// Every stub verb word, in the vocabulary of a game that never asked for
    /// it. Checked against the vocabulary rather than a transcript because it is
    /// noun-independent: a word in `verbWords` can never come back as
    /// `I don't know the word`, wherever the player is standing.
    static let stubVerbWords = Set(SyntaxRule.stubTable.flatMap(\.leadingWords))

    private func expectKnowsEveryStubVerbWord(_ game: some Game) throws {
        let (definition, _) = try Bootstrap.build(game)
        let missing = Self.stubVerbWords.subtracting(definition.vocabulary.verbWords)
        #expect(missing.isEmpty, "\(missing.sorted())")
    }

    private func expectAnswersInVoice(_ game: some Game, _ command: String) async throws {
        let turn = turnOutput(of: command, in: try await play(game, [command]))
        #expect(!turn.contains("I don't know the word"), "\(command): \(turn)")
        #expect(!turn.contains("I didn't understand"), "\(command): \(turn)")
    }

    @Test func lighthouseKnowsEveryStubVerbWord() throws {
        try expectKnowsEveryStubVerbWord(Lighthouse())
    }

    @Test func gramaryeKnowsEveryStubVerbWord() throws {
        try expectKnowsEveryStubVerbWord(Gramarye())
    }

    @Test func operaHouseKnowsEveryStubVerbWord() throws {
        try expectKnowsEveryStubVerbWord(OperaHouse())
    }

    /// And the words actually answer, in play, in a game that declares no
    /// `actions` at all. Objectless forms only, so the assertion doesn't depend
    /// on what happens to be lying in the opening room.
    static let objectlessStubCommands = [
        "dig", "smell", "sniff", "listen", "sleep", "wake", "wake up",
        "yell", "shout", "scream", "wave", "climb", "jump", "swim", "dive",
        "stand", "stand up", "sit", "sit down", "lie", "lie down", "kneel",
        "pray", "sing", "curse", "swear", "xyzzy", "plugh", "think", "wish",
    ]

    @Test(arguments: DemoGameStubVerbTests.objectlessStubCommands)
    func lighthouseAnswersEveryObjectlessStubVerb(_ command: String) async throws {
        try await expectAnswersInVoice(Lighthouse(), command)
    }

    @Test(arguments: DemoGameStubVerbTests.objectlessStubCommands)
    func gramaryeAnswersEveryObjectlessStubVerb(_ command: String) async throws {
        try await expectAnswersInVoice(Gramarye(), command)
    }

    // MARK: - Boot warnings

    /// Zork overrides roughly twenty stub verbs to keep the original's voice.
    /// Before the stub carve-out every one of those would have warned at launch
    /// for doing exactly the right thing; now the list is down to the single
    /// warning Zork genuinely earns.
    ///
    /// `action(.score)` shadows real behavior — score is a meta intent, so no
    /// rule can reach it and the override is the only seam — and that warning
    /// predates stub verbs. Asserted exactly rather than as "is empty" so it
    /// stays visible instead of being papered over.
    @Test func zorkBootsWithOnlyTheScoreOverrideWarning() throws {
        let (definition, _) = try Bootstrap.build(Zork1())
        let report = definition.warningReport ?? "no report"
        #expect(
            definition.warnings == [
                "custom action for intent \"score\" overrides the built-in default "
                    + "of the same intent."
            ], "\(report)")
    }

    @Test func theOtherDemoGamesBootWithNoWarnings() throws {
        let (lighthouse, _) = try Bootstrap.build(Lighthouse())
        #expect(lighthouse.warnings.isEmpty, "\(lighthouse.warningReport ?? "no report")")

        let (gramarye, _) = try Bootstrap.build(Gramarye())
        #expect(gramarye.warnings.isEmpty, "\(gramarye.warningReport ?? "no report")")

        let (cloak, _) = try Bootstrap.build(OperaHouse())
        #expect(cloak.warnings.isEmpty, "\(cloak.warningReport ?? "no report")")

        let (fulminate, _) = try Bootstrap.build(Fulminate())
        #expect(fulminate.warnings.isEmpty, "\(fulminate.warningReport ?? "no report")")
    }
}
