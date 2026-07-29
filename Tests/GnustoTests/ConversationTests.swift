import Foundation
import Gnusto
import GnustoActors
import GnustoConversation
import GnustoTestSupport
import Testing

/// Library behavior of `GnustoConversation`, exercised through a tiny
/// synthetic house so each test isolates one rule about how a topic table
/// answers.
///
/// The shape the whole thing exists for is the gating chain: an actor who
/// says one thing until you can prove otherwise, and something else
/// afterwards. Everything else here is in service of getting that right.
struct ConversationTests {
    // MARK: - Matching

    @Test func aMatchedTopicAnswers() async throws {
        let transcript = try await play(Manor(), ["ask butler about the murder"])
        #expect(transcript.contains("A dreadful business, sir."))
    }

    @Test(arguments: ["murder", "body", "corpse"])
    func everySynonymReachesTheSameRow(_ word: String) async throws {
        let transcript = try await play(Manor(), ["ask butler about the \(word)"])
        #expect(transcript.contains("A dreadful business, sir."))
    }

    /// A multi-word keyword needs all its words, so "the murder weapon" and
    /// "the murder" reach different rows.
    @Test func aMultiWordKeywordNeedsAllOfItsWords() async throws {
        let transcript = try await play(
            Manor(), ["ask butler about the murder weapon", "ask butler about the murder"])
        expectInOrder(
            transcript,
            [
                "The poker is where it always is.",
                "A dreadful business, sir.",
            ])
    }

    @Test func capitalsPunctuationAndArticlesAreIgnored() async throws {
        let transcript = try await play(Manor(), ["ask butler about THE Murder!"])
        #expect(transcript.contains("A dreadful business, sir."))
    }

    /// Word order doesn't matter either — the row wants its words present,
    /// not in a particular arrangement.
    @Test func keywordWordsMayArriveInAnyOrder() async throws {
        let transcript = try await play(Manor(), ["ask butler about the weapon murder"])
        #expect(transcript.contains("The poker is where it always is."))
    }

    // MARK: - When nothing matches

    @Test func anUnmatchedTopicGetsTheActorsFallback() async throws {
        let transcript = try await play(Manor(), ["ask butler about zeppelins"])
        #expect(transcript.contains("I couldn't say, sir."))
    }

    /// An actor with no fallback falls through to the layer's own default,
    /// which is the seam that lets another rule answer instead.
    @Test func anActorWithNoFallbackFallsThroughToTheLayer() async throws {
        let transcript = try await play(Manor(), ["ask maid about zeppelins"])
        #expect(transcript.contains("The maid has nothing to say about that."))
    }

    @Test func askingSomethingInanimateIsRefused() async throws {
        let transcript = try await play(Manor(), ["ask lamp about the murder"])
        #expect(transcript.contains("You can only talk to something animate."))
    }

    // MARK: - Which intent

    @Test func anOnlyTellRowIgnoresAsk() async throws {
        let transcript = try await play(
            Manor(), ["tell butler about the will", "ask butler about the will"])
        expectInOrder(
            transcript,
            [
                "He had not heard about the will.",  // tell reaches the row
                "I couldn't say, sir.",  // ask falls to the fallback
            ])
    }

    // MARK: - The gating chain

    /// The whole point of the layer, in one transcript: he lies, you show him
    /// the letter, he stops lying.
    @Test func theButlerLiesUntilYouShowHimTheLetter() async throws {
        let transcript = try await play(
            Manor(),
            [
                "ask butler about his alibi",
                "take letter",
                "show letter to butler",
                "ask butler about his alibi",
            ])
        expectInOrder(
            transcript,
            [
                "I was in the pantry all evening, sir.",
                "He reads it, and his colour goes.",
                "Very well. I was in the study.",
            ])
    }

    /// And the lie is properly retired, not merely outranked — it must not
    /// reappear once the letter has been shown.
    @Test func theRetiredLieNeverComesBack() async throws {
        let transcript = try await play(
            Manor(),
            ["take letter", "show letter to butler", "ask butler about his alibi"])
        #expect(!transcript.contains("I was in the pantry all evening, sir."))
    }

    /// A row the player hasn't earned is skipped rather than answered, so a
    /// later row — or the fallback — speaks instead.
    @Test func aGatedRowIsSilentUntilItsFactIsLearned() async throws {
        let transcript = try await play(Manor(), ["ask butler about the safe"])
        #expect(!transcript.contains("panel behind the portrait"))
        #expect(transcript.contains("I couldn't say, sir."))
    }

    @Test func declarationOrderDecidesBetweenTwoRowsOnTheSameKeyword() async throws {
        let transcript = try await play(Manor(), ["ask maid about the study"])
        #expect(transcript.contains("She says the first thing."))
        #expect(!transcript.contains("She says the second thing."))
    }

    // MARK: - Rows that move the world

    @Test func aPerformRowCanChangeTheWorld() async throws {
        let transcript = try await play(
            Manor(),
            [
                "take letter", "show letter to butler",  // learns the fact
                "ask butler about the safe",
                "look",
            ])
        expectInOrder(
            transcript,
            [
                "panel behind the portrait",
                "There is a loose panel here.",  // revealed, and now in the room
            ])
    }

    // MARK: - Showing

    @Test func showingSomethingNoRowCoversGetsTheDefault() async throws {
        let transcript = try await play(Manor(), ["show lamp to butler"])
        #expect(transcript.contains("The butler shows no interest."))
    }

    // MARK: - Composing with GnustoActors

    /// Both are before-rules on the same actor, so declaration order decides.
    /// Declared after the table, a `reaction` is the catch-all; declared
    /// before it, it shadows the table entirely. Two fixtures, one each way.
    @Test func aReactionAfterATableIsTheCatchAll() async throws {
        let transcript = try await play(
            ReactionAfterTable(), ["ask porter about the murder", "ask porter about zeppelins"])
        expectInOrder(
            transcript,
            [
                "The porter knows about the murder.",  // the table answers
                "The porter grunts.",  // the reaction catches the rest
            ])
    }

    @Test func aReactionBeforeATableShadowsIt() async throws {
        let transcript = try await play(ReactionBeforeTable(), ["ask porter about the murder"])
        #expect(transcript.contains("The porter grunts."))
        #expect(!transcript.contains("The porter knows about the murder."))
    }

    // MARK: - Persistence

    @Test func learnedFactsSurviveSaveAndRestore() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gnusto-talk-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let transcript = try await play(
            Manor(),
            [
                "take letter", "show letter to butler",  // learns the fact
                "save", "slot",
                "restore", "slot",
                "ask butler about his alibi",  // still confesses
            ],
            saveDirectory: dir)
        expectInOrder(transcript, ["Restored.", "Very well. I was in the study."])
    }

    @Test func undoTakesBackWhatWasLearned() async throws {
        let transcript = try await play(
            Manor(),
            [
                "take letter", "show letter to butler",
                "undo",
                "ask butler about his alibi",  // back to the lie
            ])
        #expect(transcript.contains("I was in the pantry all evening, sir."))
    }
}

// MARK: - Synthetic fixtures

extension Fact {
    fileprivate static let sawTheLetter = Fact("sawTheLetter")
}

/// One room, two people, one lamp, one letter, and a table with a row for
/// every rule the layer has: synonyms, a multi-word keyword, an intent
/// restriction, a lie retired by evidence, a reply gated on it, and a row
/// that moves the world.
struct Manor: Game {
    let title = "Manor"
    let intro = "A hall with people in it."

    let talk = Conversation()

    let hall = Location {
        name("Hall")
        description("A hall.")
    }

    let butler = Actor {
        name("butler")
        description("The butler.")
    }

    let maid = Actor {
        name("maid")
        description("The maid.")
    }

    let lamp = Item {
        name("lamp")
        description("A lamp.")
    }

    let letter = Item {
        name("letter")
        description("A letter.")
    }

    let panel = Item {
        name("loose panel")
        synonyms("panel")
        description("A loose panel.")
        hidden
    }

    var content: GameContents { talk }

    var rules: Rules {
        talk.topics(of: butler, fallback: "\"I couldn't say, sir.\"") {
            // More specific first: "murder weapon" would otherwise never be
            // reached, since "murder" alone matches it too.
            topic("murder weapon", reply: "\"The poker is where it always is.\"")
            topic("murder", "body", "corpse", reply: "\"A dreadful business, sir.\"")

            topic("will", only: [.tell], reply: "He had not heard about the will.")

            // The lie, and the confession that replaces it.
            topic(
                "alibi", "evening", unless: .sawTheLetter,
                reply: "\"I was in the pantry all evening, sir.\"")
            topic(
                "alibi", "evening", knowing: .sawTheLetter,
                reply: "\"…Very well. I was in the study.\"")

            topic("safe", knowing: .sawTheLetter) {
                panel.reveal()
                say("He nods, reluctantly, at a panel behind the portrait.")
            }
        }

        // Two rows on one keyword, to pin that the first wins.
        talk.topics(of: maid) {
            topic("study", reply: "She says the first thing.")
            topic("study", reply: "She says the second thing.")
        }

        talk.shows(
            letter, to: butler, learning: .sawTheLetter,
            reply: "He reads it, and his colour goes.")
    }

    var map: WorldMap {
        player.starts(in: hall)
        butler.starts(in: hall)
        maid.starts(in: hall)
        lamp.starts(in: hall)
        letter.starts(in: hall)
        panel.starts(in: hall)
    }
}

/// A `GnustoActors` reaction declared *after* a topic table, so it catches
/// what the table doesn't answer.
struct ReactionAfterTable: Game {
    let title = "Lodge"
    let intro = "A lodge."

    let talk = Conversation()
    let behaviors = ActorBehaviors()

    let yard = Location {
        name("Yard")
        description("A yard.")
    }

    let porter = Actor {
        name("porter")
        description("The porter.")
    }

    var content: GameContents { talk }

    var rules: Rules {
        talk.topics(of: porter) {
            topic("murder", reply: "The porter knows about the murder.")
        }
        behaviors.reaction(of: porter, to: [.ask], reply: "The porter grunts.")
    }

    var map: WorldMap {
        player.starts(in: yard)
        porter.starts(in: yard)
    }
}

/// The same two rules the other way round, where the reaction shadows the
/// table completely.
struct ReactionBeforeTable: Game {
    let title = "Lodge"
    let intro = "A lodge."

    let talk = Conversation()
    let behaviors = ActorBehaviors()

    let yard = Location {
        name("Yard")
        description("A yard.")
    }

    let porter = Actor {
        name("porter")
        description("The porter.")
    }

    var content: GameContents { talk }

    var rules: Rules {
        behaviors.reaction(of: porter, to: [.ask], reply: "The porter grunts.")
        talk.topics(of: porter) {
            topic("murder", reply: "The porter knows about the murder.")
        }
    }

    var map: WorldMap {
        player.starts(in: yard)
        porter.starts(in: yard)
    }
}
