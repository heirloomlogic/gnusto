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

    /// `shows` had no `again:` where `greeting` and `topic` both did, so the
    /// paragraphs a mystery turns on — the ones a player is most likely to try
    /// twice — recited word for word. Same retirement key mechanism as the
    /// other two.
    @Test func aShownThingWithARepeatLineIsReactedToInFullOnlyOnce() async throws {
        let transcript = try await play(
            Guardroom(), ["show whistle to corporal", "show whistle to corporal"])
        #expect(
            occurrences(of: "He looks at the whistle and does not take it.", in: transcript)
                == 1)
        #expect(transcript.contains("\"Still a whistle,\" he says."))
    }

    /// The backwards-compatibility guarantee, matched to the one `topics` and
    /// `greeting` already make: a reaction with no `again:` repeats forever and
    /// records nothing, so a game that never writes one is unchanged.
    @Test func aShowReactionWithNoRepeatLineRepeatsForever() async throws {
        let transcript = try await play(
            Guardroom(), ["show order to sergeant", "show order to sergeant"])
        #expect(occurrences(of: "He reads it.", in: transcript) == 2)
    }

    /// And the `perform:` form, which is what lets a reaction that claims to
    /// move something actually move it. On a repeat the body does not run, so
    /// the transfer happens once.
    @Test func aShowReactionThatMovesTheWorldDoesItOnce() async throws {
        let transcript = try await play(
            Guardroom(),
            ["take drum", "show drum to corporal", "show drum to corporal", "inventory"])
        #expect(occurrences(of: "He takes the drum off you.", in: transcript) == 1)
        #expect(transcript.contains("The drum is under his arm, where he put it."))
        #expect(!turnOutput(of: "inventory", in: transcript).contains("drum"))
    }

    /// A greeting body reads the world it is said in, which is what an actor
    /// who keeps a timetable needs: the hello that names the furniture has to
    /// know whose furniture it is standing next to.
    @Test func aGreetingBodyReadsTheWorldItIsSaidIn() async throws {
        let before = try await play(Guardroom(), ["greet corporal"])
        #expect(before.contains("Nobody's on the gate."))

        let after = try await play(Guardroom(), ["ring bell", "greet corporal"])
        #expect(turnOutput(of: "greet corporal", in: after).contains("Gate's manned."))

        // And it still retires on the second hello.
        let twice = try await play(Guardroom(), ["greet corporal", "greet corporal"])
        #expect(occurrences(of: "Corporal Vane, sir.", in: twice) == 1)
        #expect(twice.contains("\"Sir.\" Nothing more."))
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

    // MARK: - Opening a conversation

    @Test(arguments: [
        "talk to sergeant", "talk with sergeant", "talk sergeant",
        "speak to sergeant", "greet sergeant", "hello sergeant", "hi sergeant",
        "say hello to sergeant", "sergeant, hello",
    ])
    func everyWayOfOpeningReachesTheSameGreeting(_ command: String) async throws {
        let transcript = try await play(Guardroom(), [command])
        #expect(transcript.contains("He does not stand up."))
    }

    @Test func anActorWithNoGreetingWaitsForThePoint() async throws {
        let transcript = try await play(Guardroom(), ["talk to the sentry"])
        #expect(transcript.contains("The sentry waits for you to come to the point."))
    }

    @Test func talkingToAThingIsRefused() async throws {
        let transcript = try await play(Guardroom(), ["talk to the drum"])
        #expect(transcript.contains("You can only talk to something animate."))
    }

    /// An order is heard and declined — and, importantly, not carried out by
    /// the *player*, which is what a naive addressee field would have done.
    @Test func anOrderIsDeclinedRatherThanObeyed() async throws {
        let transcript = try await play(
            Guardroom(), ["sergeant, take the drum", "inventory"])
        #expect(transcript.contains("has no intention of taking orders"))
        #expect(!transcript.contains("Taken."))
        #expect(transcript.contains("You are empty-handed."))
    }

    // MARK: - Saying it once

    @Test func anAnswerWithARepeatLineIsGivenInFullOnlyOnce() async throws {
        let transcript = try await play(
            Guardroom(), ["ask sergeant about the raid", "ask sergeant about the raid"])
        expectInOrder(
            transcript,
            [
                "We went in at four and came out at six.",
                "You've had that from me once.",
            ])
        #expect(occurrences(of: "We went in at four", in: transcript) == 1)
    }

    @Test func aRowsOwnAgainLineBeatsTheTables() async throws {
        let transcript = try await play(
            Guardroom(), ["ask sergeant about the captain", "ask sergeant about the captain"])
        #expect(transcript.contains("I said what I'm saying about the captain."))
        #expect(!transcript.contains("You've had that from me once."))
    }

    /// The backwards-compatibility guarantee: a table with no `again:` repeats
    /// forever, exactly as it did before the parameter existed.
    @Test func aTableWithNoAgainLineRepeatsForever() async throws {
        let transcript = try await play(
            Manor(),
            ["ask maid about the study", "ask maid about the study", "ask maid about the study"])
        #expect(occurrences(of: "She says the first thing.", in: transcript) == 3)
    }

    /// A heard row still owns its keyword. An actor who demonstrably has an
    /// answer must not sound blank about the subject.
    @Test func aRepeatedRowNeverReachesTheFallback() async throws {
        let transcript = try await play(
            Guardroom(), ["ask sergeant about the raid", "ask sergeant about the raid"])
        #expect(!transcript.contains("Not my department."))
    }

    /// A lie and the confession that replaces it are separate rows with
    /// separate keys, so retiring one says nothing about the other.
    @Test func aRetiredRowAndItsReplacementAreTrackedApart() async throws {
        let transcript = try await play(
            Guardroom(),
            [
                "ask sergeant about orders", "ask sergeant about orders",
                "take order", "show order to sergeant",
                "ask sergeant about orders", "ask sergeant about orders",
            ])
        expectInOrder(
            transcript,
            [
                "There were no orders.",
                "You've had that from me once.",
                "He reads it.",
                "There were orders, and I burned them.",
                "You've had that from me once.",
            ])
    }

    /// The table's line retires prose, never behavior: a `perform:` row keeps
    /// running under a table default it did not ask for.
    @Test func aPerformRowKeepsRunningUnderATableDefault() async throws {
        let transcript = try await play(
            Guardroom(), ["ask sergeant about boots", "ask sergeant about boots"])
        expectInOrder(transcript, ["He counts 1 pair.", "He counts 2 pair."])
    }

    /// And a `perform:` row that names its own line runs its body exactly
    /// once, which is how an author says "don't double-fire this".
    @Test func aPerformRowWithItsOwnAgainLineRunsOnce() async throws {
        let transcript = try await play(
            Guardroom(), ["ask sergeant about the bell", "ask sergeant about the bell"])
        #expect(occurrences(of: "He rings the bell.", in: transcript) == 1)
        #expect(transcript.contains("The bell's been rung."))
    }

    /// Teaching runs ahead of the repeat check, so a fact taken back with
    /// `forget` is re-asserted by asking again — not merely by luck of
    /// idempotence.
    @Test func aRepeatStillTeachesTheRowsFact() async throws {
        let transcript = try await play(
            Guardroom(),
            [
                "ask sergeant about the rumour",
                "take whistle",  // forgets the fact
                "ask sergeant about the rumour",  // the repeat line — and re-teaches
                "ask sergeant about the truth",
            ])
        expectInOrder(
            transcript, ["There's a rumour.", "You've had that from me once.", "Then you know."])
    }

    /// A multi-word keyword and the same words spelled as separate keywords
    /// are different rows. The derived key has to say so — joining the keyword
    /// list on a space would make them identical, and hearing one would retire
    /// the other's answer before it was ever spoken.
    @Test func keywordStructureIsPartOfARowsIdentity() async throws {
        // "locker" alone can only reach the second row; "arms locker" reaches
        // the first. Neither has been heard before, so both answer in full.
        let transcript = try await play(
            Guardroom(), ["ask sergeant about the locker", "ask sergeant about the arms locker"])
        expectInOrder(
            transcript,
            ["Two rifles short, and I've said so.", "The arms locker is my responsibility."])
        #expect(!transcript.contains("You've had that from me once."))
    }

    /// The greeting reserves a heard key of its own. An author who declares a
    /// row `id: "greeting"` must not retire the hello, or be retired by it.
    @Test func theGreetingAndARowNamedGreetingAreTrackedApart() async throws {
        let transcript = try await play(
            Guardroom(), ["greet sergeant", "ask sergeant about the introduction"])
        expectInOrder(transcript, ["He does not stand up.", "I introduce nobody."])
        #expect(!transcript.contains("You've had that from me once."))
    }

    @Test func twoRowsSharingAnIdRetireTogether() async throws {
        let transcript = try await play(
            Guardroom(), ["ask sergeant about the north gate", "ask sergeant about the south gate"])
        expectInOrder(transcript, ["North gate is shut.", "You've had that from me once."])
        #expect(!transcript.contains("South gate is shut."))
    }

    @Test func unhearingLetsTheActorGiveTheAnswerAgain() async throws {
        let transcript = try await play(
            Guardroom(),
            [
                "ask sergeant about the watch", "ask sergeant about the watch",
                "take drum",  // unhears everything
                "ask sergeant about the watch",
            ])
        #expect(occurrences(of: "Two on, four off.", in: transcript) == 2)
    }

    @Test func hasHeardReportsWhatTheActorHasGiven() async throws {
        let transcript = try await play(
            Guardroom(), ["x ledger", "ask sergeant about the watch", "x ledger"])
        expectInOrder(transcript, ["Nothing said yet.", "Two on, four off.", "The watch is spoken for."])
    }

    // MARK: - A live condition on the world

    /// `when:` is for what is currently true, where `knowing:` is for what the
    /// player has worked out.
    @Test func aWhenRowOnlyAnswersWhileItsConditionHolds() async throws {
        let transcript = try await play(
            Guardroom(), ["ask sergeant about the gate guard", "ring bell", "ask sergeant about the gate guard"])
        expectInOrder(
            transcript, ["Nobody's on it yet.", "Corporal Vane has it now."])
    }

    // MARK: - Persistence

    /// What an actor has already said travels in the save, like what the
    /// player has learned — it is another `@Global` on the same layer.
    @Test func whatAnActorHasAlreadySaidSurvivesSaveAndRestore() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gnusto-heard-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let transcript = try await play(
            Guardroom(),
            [
                "ask sergeant about the raid",
                "save", "slot",
                "restore", "slot",
                "ask sergeant about the raid",
            ],
            saveDirectory: dir)
        expectInOrder(
            transcript,
            ["We went in at four and came out at six.", "Restored.", "You've had that from me once."])
    }

    @Test func undoTakesBackWhatTheActorSaid() async throws {
        let transcript = try await play(
            Guardroom(), ["ask sergeant about the raid", "undo", "ask sergeant about the raid"])
        #expect(occurrences(of: "We went in at four", in: transcript) == 2)
        #expect(!transcript.contains("You've had that from me once."))
    }

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

/// How many times `needle` appears in `haystack`. The suite has
/// `expectInOrder` for sequence, but "exactly once" needs a count.
private func occurrences(of needle: String, in haystack: String) -> Int {
    haystack.components(separatedBy: needle).count - 1
}

// MARK: - Synthetic fixtures

extension Fact {
    fileprivate static let sawTheLetter = Fact("sawTheLetter")
    fileprivate static let sawTheOrder = Fact("sawTheOrder")
    fileprivate static let heardTheRumour = Fact("heardTheRumour")
}

/// A sergeant with an answer for everything and the patience for none of it:
/// the fixture for repeat-aware answers, `when:` conditions, and every way of
/// opening a conversation.
///
/// Deliberately separate from ``Manor``, which stays untouched as the proof
/// that a table with no `again:` behaves exactly as it always did.
struct Guardroom: Game {
    let title = "Guardroom"
    let intro = "A guardroom."

    let talk = Conversation()

    /// Counts how many times the `perform:` boots row has actually run, so a
    /// test can tell "the body ran again" from "the line was repeated".
    @Global var polishings = 0
    /// A live world condition for `when:` — not a deduction, so not a `Fact`.
    @Global var gateManned = false

    let post = Location {
        name("Post")
        description("A guardroom.")
    }

    let sergeant = Actor {
        name("sergeant")
        description("The sergeant.")
    }

    let corporal = Actor {
        name("corporal")
        description("The corporal.")
    }

    /// Kept greeting-less so `anActorWithNoGreetingWaitsForThePoint` has
    /// somebody to ask; the corporal now has one.
    let sentry = Actor {
        name("sentry")
        description("The sentry.")
    }

    let order = Item {
        name("order")
        description("A written order.")
    }

    /// Taking it makes him forget the rumour, so a repeat can be shown to
    /// re-teach.
    let whistle = Item {
        name("whistle")
        description("A whistle.")
    }

    /// Taking it clears everything the sergeant has said.
    let drum = Item {
        name("drum")
        description("A drum.")
    }

    let ledger = Item {
        name("ledger")
        description("A ledger.")
        scenery
    }

    let bell = Item {
        name("bell")
        description("A bell.")
        scenery
    }

    var content: GameContents { talk }

    var verbs: [SyntaxRule] {
        SyntaxRule("ring", .directObject, intent: Intent("ring"))
    }

    var rules: Rules {
        talk.greeting(
            of: sergeant,
            again: "\"We've done that,\" he says.",
            reply: "\"Sergeant Muir,\" he says. He does not stand up.")

        talk.topics(
            of: sergeant,
            fallback: "\"Not my department.\"",
            again: "\"You've had that from me once.\""
        ) {
            topic("raid", reply: "\"We went in at four and came out at six.\"")
            topic(
                "captain", again: "\"I said what I'm saying about the captain.\"",
                reply: "\"The captain was where he said he was.\"")

            // A lie and its replacement, on the same keyword.
            topic("orders", unless: .sawTheOrder, reply: "\"There were no orders.\"")
            topic(
                "orders", knowing: .sawTheOrder,
                reply: "\"There were orders, and I burned them.\"")

            topic("rumour", learning: .heardTheRumour, reply: "\"There's a rumour.\"")
            topic("truth", knowing: .heardTheRumour, reply: "\"Then you know.\"")

            // A live condition rather than a fact: nothing has been deduced,
            // the world has simply changed.
            topic(
                "gate guard", when: { !gateManned },
                reply: "\"Nobody's on it yet.\"")
            topic("gate guard", reply: "\"Corporal Vane has it now.\"")

            // A `perform:` row under a table default: it must keep running.
            topic("boots") {
                polishings += 1
                try reply("He counts \(polishings) pair.")
            }
            // And one that opts in, so its body runs exactly once.
            topic("bell", again: "\"The bell's been rung.\"") {
                try reply("He rings the bell.")
            }

            topic("watch", id: "watch", reply: "\"Two on, four off.\"")
            // A multi-word keyword and the same two words as separate
            // keywords, in a pair where the words are *already* in sorted
            // order — which is what makes the derived keys collide if the
            // keyword list is joined on a space. Both rows are reachable:
            // "arms locker" takes the first, "locker" alone can only take the
            // second, so they must not share a heard-set flag.
            topic("arms locker", reply: "\"The arms locker is my responsibility.\"")
            topic("arms", "locker", reply: "\"Two rifles short, and I've said so.\"")
            // An `id:` that collides with the greeting's own reserved key if
            // the two are not namespaced apart.
            topic("introduction", id: "greeting", reply: "\"I introduce nobody.\"")
            // Two rows deliberately sharing one flag.
            topic("north gate", id: "gate", reply: "\"North gate is shut.\"")
            topic("south gate", id: "gate", reply: "\"South gate is shut.\"")
        }

        // No `again:`: the backwards-compatibility case, which must go on
        // reacting in full however often the order is put in front of him.
        talk.shows(order, to: sergeant, learning: .sawTheOrder, reply: "He reads it.")

        // The same row with a repeat line, and one whose body moves the world —
        // the shape a line like "she takes it out of your hand" needs if it is
        // going to be true.
        talk.shows(
            whistle, to: corporal,
            again: "\"Still a whistle,\" he says.",
            reply: "He looks at the whistle and does not take it.")
        talk.shows(
            drum, to: corporal,
            again: "The drum is under his arm, where he put it."
        ) {
            drum.move(heldBy: corporal)
            try reply("He takes the drum off you.")
        }

        // A greeting that reads the world it is said in.
        talk.greeting(of: corporal, again: "\"Sir.\" Nothing more.") {
            try reply(
                gateManned
                    ? "\"Corporal Vane, sir. Gate's manned.\""
                    : "\"Corporal Vane, sir. Nobody's on the gate.\"")
        }

        whistle.before(.take) { talk.forget(.heardTheRumour) }
        drum.before(.take) { talk.unhearEverything(from: sergeant) }
        ledger.before(.examine) {
            try reply(
                talk.hasHeard("watch", from: sergeant)
                    ? "The watch is spoken for." : "Nothing said yet.")
        }
        bell.before(Intent("ring")) {
            gateManned = true
            try reply("The bell goes, and somebody is sent to the gate.")
        }
    }

    var map: WorldMap {
        player.starts(in: post)
        sergeant.starts(in: post)
        corporal.starts(in: post)
        sentry.starts(in: post)
        order.starts(in: post)
        whistle.starts(in: post)
        drum.starts(in: post)
        ledger.starts(in: post)
        bell.starts(in: post)
    }
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
