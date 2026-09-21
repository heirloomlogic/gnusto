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
        "dig", "smell", "sniff", "listen", "sleep", "rest", "wake", "wake up",
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

    /// Every shipped game boots with nothing to say — Dungeon and KindlyDeep
    /// included, which the hand-written list this replaced had silently never
    /// covered.
    ///
    /// Asked of the whole set rather than four named games because a bootstrap
    /// warning is the engine's one channel to an author, and a warning nobody
    /// asserts about is a warning nobody reads. #350 added one — a listing line
    /// wired to the examine channel — and it was true of eleven declarations in
    /// two games before anything checked.
    ///
    /// Zork used to be the one exception. It overrides roughly twenty stub
    /// verbs to keep the original's voice, all of them silent since the stub
    /// carve-out, plus `action(.score)`, which shadows real behavior — score is
    /// a meta intent, so no rule can reach it and the override is the only
    /// seam. `GameMain` prints the report to stderr before the intro, so that
    /// last one reached every player who ran the game in a terminal; the row
    /// now says `overriding: true` and the set is empty. (#502)
    @Test func theDemoGamesBootWithNoWarnings() throws {
        for (title, definition) in try ShippedGames.definitions() {
            #expect(
                definition.warnings.isEmpty,
                "\(title): \(definition.warningReport ?? "no report")")
        }
    }
}
