import Foundation
import Testing

@testable import CloakOfDarkness
@testable import Gnusto

/// The seams a play-test driver reaches a running world through: the parse
/// record, the fired-timer tally, state snapshots, and the static survey.
///
/// All of it is `internal`, so this suite is its only reader until the protocol
/// layer lands — which is the point of testing it now. A field nobody reads is
/// a field whose meaning has never been checked, and every one of these carries
/// a claim about *what it excludes* that would otherwise be a comment.
struct PlaytestSeamTests {
    /// A fresh, isolated save directory, so a test's `save` slots can't be seen
    /// by another test or by the developer's real ones.
    private func tempDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
    }

    // MARK: - The parse record

    /// The record exists for exactly this: `examine` prints a description and
    /// leaves no mark on the world — the default action calls `describeItem`,
    /// which only `say`s, so `isTouched` never learns the player looked. Here
    /// the fact survives the turn as data.
    @Test func theAuditNamesWhatTheParserResolved() async throws {
        let world = try GameWorld(game: OperaHouse(), seed: 1, saveDirectory: tempDirectory())
        _ = await world.begin()

        let (_, audit) = await world.performAudited("examine the cloak")
        #expect(audit.understood)
        #expect(audit.intent == .examine)
        #expect(audit.directObject == EntityID("cloak"))
        #expect(audit.indirectObject == nil)
        #expect(audit.unknownWords.isEmpty)
        #expect(!audit.answeredPrompt)
    }

    @Test func theAuditNamesBothObjectsOfATwoSlotCommand() async throws {
        let world = try GameWorld(game: OperaHouse(), seed: 1, saveDirectory: tempDirectory())
        _ = await world.begin()
        _ = await world.perform("west")  // the hook is in the cloakroom

        let (_, audit) = await world.performAudited("put cloak on hook")
        #expect(audit.understood)
        #expect(audit.directObject == EntityID("cloak"))
        #expect(audit.indirectObject == EntityID("hook"))
    }

    /// The word census is asked of the vocabulary, not read out of the reply —
    /// so it names every unknown token rather than the one the parser happened
    /// to complain about, and it is right about the words it *does* know.
    /// Note `with` and the articles survive the cut: a preposition and the
    /// filler are vocabulary, and a census that reported them would be noise.
    @Test func theAuditListsEveryWordTheGameHasNeverHeardOf() async throws {
        let world = try GameWorld(game: OperaHouse(), seed: 1, saveDirectory: tempDirectory())
        _ = await world.begin()

        let (_, audit) = await world.performAudited("polish the grout with a frobnitz")
        #expect(!audit.understood)
        #expect(audit.intent == nil)
        #expect(audit.unknownWords == ["polish", "grout", "frobnitz"])
    }

    /// A line consumed by an engine prompt was never a command, and the record
    /// says so instead of reporting a parse failure that never happened.
    @Test func answeringAPromptIsNotAParse() async throws {
        let world = try GameWorld(game: OperaHouse(), seed: 1, saveDirectory: tempDirectory())
        _ = await world.begin()

        let (prompt, promptAudit) = await world.performAudited("save")
        #expect(prompt.output.contains("what file"))
        #expect(promptAudit.understood)  // `save` itself parsed fine

        let (_, answer) = await world.performAudited("slot-one")
        #expect(answer.answeredPrompt)
        #expect(!answer.understood)
        #expect(answer.intent == nil)
        #expect(answer.unknownWords.isEmpty)
    }

    // MARK: - The fired-timer tally

    /// "Did this timer ever fire?" is unanswerable from the transcript for a
    /// timer whose body says nothing, and only guessable for one whose body
    /// says something a rule could also have said.
    @Test func firedTimersCountsEveryBodyThatRan() async throws {
        let world = try GameWorld(
            game: HeartbeatGame(), seed: 1, saveDirectory: tempDirectory())
        _ = await world.begin()
        #expect(await world.firedTimers.isEmpty)  // the opening is not a turn

        for _ in 1...3 { _ = await world.perform("wait") }

        // The daemon runs at the end of every turn; the two-turn autostart fuse
        // fires once and is gone; the third timer was never started.
        #expect(await world.firedTimers["heartbeat"] == 3)
        #expect(await world.firedTimers["dawn"] == 1)
        #expect(await world.firedTimers["doom"] == nil)
    }

    /// A free line moves no clock, so nothing fires — the same rule the move
    /// counter follows.
    @Test func aParseErrorFiresNothing() async throws {
        let world = try GameWorld(
            game: HeartbeatGame(), seed: 1, saveDirectory: tempDirectory())
        _ = await world.begin()

        _ = await world.perform("frotz")
        #expect(await world.firedTimers.isEmpty)
    }

    // MARK: - Snapshots

    /// A struct copy of the world, deliberately not routed through the
    /// player-facing save path.
    @Test func aSnapshotRestoresTheWorldButNotTheSession() async throws {
        let world = try GameWorld(
            game: HeartbeatGame(), seed: 1, saveDirectory: tempDirectory())
        _ = await world.begin()
        let mark = await world.snapshot()

        for _ in 1...4 { _ = await world.perform("wait") }
        #expect(await world.snapshot().moves == 4)

        await world.restore(mark)
        #expect(await world.snapshot().moves == 0)
        // The tally is session state, not world state: the daemon really did
        // run four times, and rewinding the world does not unhappen it. Same
        // argument that keeps `undoSnapshot` and `initialState` off
        // `WorldState`.
        #expect(await world.firedTimers["heartbeat"] == 4)
    }

    // MARK: - The survey

    @Test func theSurveyReportsRoomsExitsAndReachability() async throws {
        let world = try GameWorld(game: GratingGame(), seed: 1, saveDirectory: tempDirectory())
        let survey = await world.survey()

        let clearing = try #require(survey.rooms.first { $0.id == EntityID("clearing") })
        #expect(clearing.name == "Clearing")
        // No exit anywhere leads back to the start room, so it is not part of
        // the denominator a coverage count should be measured against.
        #expect(!clearing.isReachable)
        #expect(clearing.exits.count == 1)
        #expect(clearing.exits[0].direction == "west")
        // The kind is reported and the closure is never called: the condition
        // would need a live turn frame, and running author code out of turn to
        // draw a map is exactly what the survey must not do.
        #expect(clearing.exits[0].kind == "conditional")
        #expect(clearing.exits[0].destination == EntityID("forest"))

        let forest = try #require(survey.rooms.first { $0.id == EntityID("forest") })
        #expect(forest.isReachable)
        #expect(forest.exits.isEmpty)
    }

    @Test func theSurveyReportsEveryDeclaredTimerWithItsKind() async throws {
        let world = try GameWorld(
            game: HeartbeatGame(), seed: 1, saveDirectory: tempDirectory())
        let survey = await world.survey()

        #expect(survey.timers.map(\.name) == ["dawn", "doom", "heartbeat"])
        let dawn = try #require(survey.timers.first { $0.name == "dawn" })
        #expect(dawn.kind == "fuse")
        #expect(dawn.turns == 2)
        #expect(dawn.autostart)
        let heartbeat = try #require(survey.timers.first { $0.name == "heartbeat" })
        #expect(heartbeat.kind == "daemon")
        #expect(heartbeat.turns == nil)
        let doom = try #require(survey.timers.first { $0.name == "doom" })
        #expect(!doom.autostart)
    }

    /// The verb table is split the way the engine's own two files split it: a
    /// core verb has behavior behind it, a stub verb is a sentence, and
    /// anything else is this game's own.
    @Test func theSurveySplitsTheVerbTable() async throws {
        let world = try GameWorld(
            game: HeartbeatGame(), seed: 1, saveDirectory: tempDirectory())
        let survey = await world.survey()

        #expect(survey.title == "Heartbeat")
        #expect(survey.coreVerbs.contains("take"))
        #expect(survey.coreVerbs.contains("look"))
        #expect(survey.stubVerbs.contains("sing"))
        #expect(!survey.coreVerbs.contains("sing"))
        #expect(survey.customVerbs == ["doom"])
        #expect(survey.warnings.isEmpty)
    }

    /// Twenty candidate nouns from one room description, resolved in one
    /// question and for no turns — where typing them at the parser would cost
    /// twenty lines and could change the world on the way past.
    @Test func vocabularyQuestionsAreBatchedAndCostNothing() async throws {
        let world = try GameWorld(game: OperaHouse(), seed: 1, saveDirectory: tempDirectory())
        let answers = await world.knows(["cloak", "chandeliers", "hook"])

        #expect(answers.map(\.word) == ["cloak", "chandeliers", "hook"])
        #expect(answers[0].known)
        // Named by the foyer's description and answerable by nothing — the
        // shape of defect this seam is for.
        #expect(!answers[1].known)
        #expect(answers[2].known)
        #expect(await world.snapshot().moves == 0)
    }
}
