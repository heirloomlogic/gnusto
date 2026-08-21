import Foundation
import GnustoTestSupport
import Testing

@testable import Gnusto

/// Core verbs: the half of the standard table the engine backs with real
/// behavior. ``CoreVerb`` states each one's intent once and derives its rows,
/// ``DefaultActions/builtInIntents``, ``DefaultActions/engineIntents`` and the
/// stage-4 dispatch from it, so the drift that used to be possible between the
/// rows, the set and a `switch` is now unrepresentable.
///
/// What that leaves worth testing is what the initializer *can't* guarantee: that
/// every row still reaches its handler, that the two behaviors partition the
/// table, and that an intent declared engine-level really is answered ahead of
/// the pipeline.
struct CoreVerbTests {
    /// Isolated so RESTORE never reads the real per-user saves directory and
    /// reports whatever happens to be in it.
    static let saveDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("gnusto-core-verb-tests", isDirectory: true)

    // MARK: - Every core row still answers

    /// One command per core row, spelled out by hand rather than generated from
    /// the table — a generated list would assert only that the table equals
    /// itself. Nouns come from ``CoreLab``, which declares no verbs and no
    /// actions of its own.
    ///
    /// Several of these are answered with a refusal rather than a success ("You
    /// aren't carrying that."), and that is fine: what this proves is that the
    /// row reached its handler, and a refusal is a handler talking.
    static let everyCoreCommand = [
        // take
        "take rod", "get rod", "grab rod", "hold rod", "carry rod",
        "pick up rod", "pick rod up",
        // drop
        "drop cloak", "discard cloak", "put down cloak", "put cloak down",
        // examine
        "examine rod", "x rod", "inspect rod", "look at rod", "l at rod",
        // read
        "read note",
        // wear
        "wear cloak", "don cloak", "put on cloak",
        // doff
        "remove hat", "doff hat", "take off hat", "take hat off",
        // putOn
        "put cloak on bench", "hang cloak on bench", "place cloak on bench",
        // putIn
        "put cloak in sack",
        // open / close
        "open box", "close box", "shut box",
        // lock / unlock
        "lock box with key", "unlock box with key",
        // turnOn
        "turn on lamp", "turn lamp on", "switch on lamp", "switch lamp on", "light lamp",
        // turnOff
        "turn off lamp", "turn lamp off", "switch off lamp", "switch lamp off",
        "extinguish lamp", "douse lamp", "blow out lamp", "blow lamp out",
        // lookIn
        "look in sack", "search sack", "search in sack", "find sack", "look for sack",
        "search for sack",
        // push
        "push bench", "move bench", "press bench",
        // go
        "go north", "walk north", "run north",
        // follow
        "follow rat", "chase rat", "go after rat", "run after rat", "walk after rat",
        // greet
        "greet rat", "hello rat", "hi rat", "greet",
        "say hello to rat", "say hi to rat",
        // board
        "enter boat", "board boat", "get in boat",
        "go through boat", "walk through boat", "step through boat",
        "climb through boat", "walk in boat",
        // disembark
        "exit", "exit boat", "disembark", "get out", "get out of boat",
        // wait / look / inventory
        "wait", "z", "look", "l", "inventory", "inv", "i",
        // meta
        "score", "quit", "q", "version",
        // engine-level
        "undo", "restart", "save", "restore", "load",
    ]

    /// Ties the hand-written list to the table, so a core row added later can't
    /// ship untested while this file still reads as exhaustive.
    @Test func everyCoreRowHasACommandInTheList() {
        #expect(Self.everyCoreCommand.count == SyntaxRule.coreTable.count)
    }

    /// What "the row reached its handler" looks like from the transcript: the
    /// parser didn't decline the sentence, no slot went unfilled, and something
    /// was said. Shared with the synonym list below, which asks the same
    /// question of the same rows spelled another way.
    static func expectTheRowAnswered(_ command: String) async throws {
        let transcript = try await play(
            CoreLab(), [command], saveDirectory: Self.saveDirectory)
        let turn = turnOutput(of: command, in: transcript)
        expectEveryNounAnswered(turn, "Command: \(command)")
        #expect(!turn.contains("I didn't understand"), "\(command): \(turn)")
        // A slot the command didn't fill would prompt instead of answering.
        #expect(!turn.contains("What do you want to"), "\(command): \(turn)")
        #expect(!turn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(command)")
    }

    @Test(arguments: CoreVerbTests.everyCoreCommand)
    func everyCoreVerbAnswers(_ command: String) async throws {
        try await Self.expectTheRowAnswered(command)
    }

    // MARK: - The same rows, spelled with a preposition's synonym

    /// Deliberately a second list rather than more entries in
    /// ``everyCoreCommand``, whose count is pinned to the row count: none of
    /// these is a new row. Each is a row above reached by a word its pattern
    /// never spells out, which is what ``Vocabulary/literalSynonyms`` buys —
    /// every row containing `in` or `on`, widened without a row of its own.
    /// Issue #269.
    static let everyPrepositionSynonym = [
        // The sentence the issue was filed from.
        "look inside sack", "look into sack",
        "search inside sack", "search into sack",
        // putIn / putOn, where the literal closes an open object slot. The
        // `into`/`onto` pair had rows of their own until #273 found those
        // rows unreachable; answering here instead is the proof that
        // deleting them cost the player nothing.
        "put cloak into sack", "put cloak onto bench",
        "put cloak inside sack", "put cloak upon bench",
        "hang cloak upon bench", "place cloak onto bench",
        // board, where the synonym is in the verb-identifying run — and
        // `get into`, likewise a row of its own until #273.
        "get into boat", "get inside boat", "walk inside boat",
        // A trailing particle, matched positionally.
        "turn lamp upon", "switch lamp upon",
        // Stub rows: the same table serves them, and nothing about it knows
        // whether the row it widened is backed by behavior.
        "climb onto bench", "sit upon bench",
    ]

    @Test(arguments: CoreVerbTests.everyPrepositionSynonym)
    func aPrepositionSynonymReachesTheSameRow(_ command: String) async throws {
        try await Self.expectTheRowAnswered(command)
    }

    /// End to end, the transcript from the issue: both spellings list the
    /// sack's contents, in the same words.
    @Test func lookInsideSaysWhatLookInSays() async throws {
        let transcript = try await play(
            CoreLab(), ["put cloak in sack", "look in sack", "look inside the sack"],
            saveDirectory: Self.saveDirectory)
        #expect(turnOutput(of: "look in sack", in: transcript).contains("velvet cloak"))
        #expect(turnOutput(of: "look inside the sack", in: transcript).contains("velvet cloak"))
    }

    /// The question an unfinished command asks is worded from the **row's**
    /// spelling, not the player's, and the near-miss loop keeps the first
    /// candidate's — so both spellings of a preposition ask in the canonical
    /// row's words. Pinned because it is the one visible consequence of #269
    /// having made three rows unreachable, and because a future reordering of
    /// the table would otherwise change these lines silently.
    @Test func bothSpellingsAskTheSameQuestion() async throws {
        let questions = [
            "get in": "What do you want to get in?",
            "get into": "What do you want to get in?",
            "put cloak in": "What do you want to put the velvet cloak in?",
            "put cloak into": "What do you want to put the velvet cloak in?",
        ]
        let transcript = try await play(
            CoreLab(), questions.keys.sorted(), saveDirectory: Self.saveDirectory)
        for (command, question) in questions {
            let turn = turnOutput(of: command, in: transcript)
            #expect(turn.contains(question), "\(command): \(turn)")
        }
    }

    // MARK: - The table holds together

    /// `coresByIntent` builds with `uniqueKeysWithValues`, which traps on a
    /// duplicate at first use — somewhere far from the second declaration that
    /// caused it. This fails where the fix is instead.
    @Test func everyCoreIntentIsDeclaredOnce() {
        let intents = DefaultActions.cores.map(\.intent)
        #expect(intents.count == Set(intents).count)
    }

    /// The two behaviors must partition the table: Bootstrap asks
    /// `engineIntents` first and `builtInIntents` second, so an intent in both
    /// would take the wrong branch and an intent in neither would take none.
    ///
    /// The membership check is the other half — `engineIntents` has to agree with
    /// the `switch` in `GameWorld.run`, which is the one place that still names
    /// these four by hand, because each of them does something different there.
    /// That boundary is the one this type can't close by construction; what
    /// covers it is `everyCoreVerbAnswers`, since an engine-level row with no arm
    /// in that switch falls all the way through stage 4 to `didntUnderstand`.
    @Test func theTwoBehaviorsPartitionTheTable() {
        let all = Set(DefaultActions.cores.map(\.intent))
        #expect(DefaultActions.builtInIntents.isDisjoint(with: DefaultActions.engineIntents))
        #expect(DefaultActions.builtInIntents.union(DefaultActions.engineIntents) == all)
        #expect(DefaultActions.engineIntents == [.undo, .restart, .save, .restore])
    }

    /// Stub intents share the table but never `builtInIntents` — reclaiming one
    /// shadows nothing and must not warn. The engine-level four are equally not
    /// stubs, which is why they get a warning of their own rather than silence.
    @Test func noCoreIntentIsAlsoAStub() {
        let all = Set(DefaultActions.cores.map(\.intent))
        #expect(all.isDisjoint(with: DefaultActions.stubIntents))
    }

    // MARK: - The engine-level four

    /// The bug this shape was worth fixing for. UNDO, RESTART, SAVE and RESTORE
    /// are answered in `GameWorld.run` before any stage, so an `actions` row for
    /// one of them never runs — and used to say nothing about it, because they
    /// were absent from the hand-written `builtInIntents` and so skipped the
    /// override warning too.
    @Test func anActionForAnEngineLevelIntentWarns() async throws {
        let (definition, _) = try Bootstrap.build(SaveOverrideGame())
        #expect(
            definition.warnings.contains { $0.contains("will never run") },
            "\(definition.warningReport ?? "no report")")

        // And the warning is honest: the engine still answers, the action doesn't.
        let transcript = try await play(
            SaveOverrideGame(), ["save"], saveDirectory: Self.saveDirectory)
        #expect(transcript.contains("Save to what file?"))
        #expect(!transcript.contains("The scribe writes"))
    }
}
