import Foundation
import Testing

@testable import Gnusto

private struct FrontendEventGame: Game {
    let title = "Front-end events"
    let intro = "A test room."

    let room = Location { name("Room") }

    var map: WorldMap {
        player.starts(in: room)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("roll", intent: Intent("roll"))
    }

    var rules: Rules {
        world.before(Intent("roll")) {
            try reply("You roll \(random(1...1_000)).")
        }
    }

    var timers: [TimedEvent] {
        fuse("bell", after: 2, autostart: true) {
            say("The bell rings.")
        }
    }
}

struct FrontendEventTests {
    private func saveDirectory(_ label: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("gnusto-frontend-\(label)-\(UUID().uuidString)", isDirectory: true)
    }

    private func world(
        seed: UInt64 = 0, saveDirectory: URL? = nil
    ) async throws -> GameWorld {
        let world = try GameWorld(
            game: FrontendEventGame(), seed: seed,
            saveDirectory: saveDirectory ?? self.saveDirectory("world"))
        _ = await world.begin()
        return world
    }

    @Test func inputEventsDistinguishInitializationParsingClarificationAndQuit() async throws {
        let openingWorld = try GameWorld(game: CausalMovementGame(), seed: 0)
        #expect(await openingWorld.begin().report.input == .initialization)
        #expect(await openingWorld.inputContext == .command)

        let rejection = await openingWorld.perform("frotz")
        #expect(rejection.report.input == .parserRejection)
        #expect(!rejection.report.understood)
        #expect(rejection.report.unknownWords == ["frotz"])

        let question = await openingWorld.perform("take key")
        #expect(question.report.input == .clarificationRequested)
        #expect(await openingWorld.inputContext == .clarification)

        let answer = await openingWorld.perform("brass")
        #expect(answer.report.input == .clarificationAnswered)
        #expect(answer.report.understood)
        #expect(await openingWorld.inputContext == .command)

        _ = await openingWorld.perform("drop brass key")
        let secondQuestion = await openingWorld.perform("take key")
        #expect(secondQuestion.report.input == .clarificationRequested)
        let repeatedQuestion = await openingWorld.perform("key")
        #expect(repeatedQuestion.report.input == .clarificationAnswered)
        #expect(await openingWorld.inputContext == .clarification)
        let changedSubject = await openingWorld.perform("look")
        #expect(changedSubject.report.input == .command)
        #expect(await openingWorld.inputContext == .command)

        let quit = await openingWorld.requestQuit()
        #expect(quit.report.input == .frontendQuit)
        #expect(quit.isFinished)
    }

    @Test func saveEventsNameRequestsOutcomesAndPromptContextsOnce() async throws {
        let directory = saveDirectory("save-events")
        defer { try? FileManager.default.removeItem(at: directory) }
        let world = try await world(saveDirectory: directory)

        let request = await world.perform("save")
        #expect(request.report.input == .command)
        #expect(request.report.operation == .init(kind: .save, outcome: .requested))
        #expect(await world.inputContext == .saveFilename)

        let completed = await world.perform("slot")
        #expect(completed.report.input == .promptAnswered(.saveFilename))
        #expect(completed.report.operation == .init(kind: .save, outcome: .completed))
        #expect(await world.inputContext == .command)

        #expect((await world.perform("save")).report.operation == .init(kind: .save, outcome: .requested))
        let overwrite = await world.perform("slot")
        #expect(overwrite.report.input == .promptAnswered(.saveFilename))
        #expect(overwrite.report.operation == nil)
        #expect(await world.inputContext == .saveOverwriteConfirmation)

        let declined = await world.perform("no")
        #expect(declined.report.input == .cancelled(.saveOverwriteConfirmation))
        #expect(declined.report.operation == .init(kind: .save, outcome: .cancelled))

        _ = await world.perform("save")
        _ = await world.perform("slot")
        let publicOverwriteCancellation = try #require(await world.cancelPendingInput())
        #expect(publicOverwriteCancellation.report.input == .cancelled(.saveOverwriteConfirmation))
        #expect(publicOverwriteCancellation.report.operation == .init(kind: .save, outcome: .cancelled))

        _ = await world.perform("save")
        let failed = await world.perform("!!!")
        #expect(failed.report.input == .promptAnswered(.saveFilename))
        #expect(failed.report.operation == .init(kind: .save, outcome: .failed))

        _ = await world.perform("save")
        let cancelled = await world.perform("")
        #expect(cancelled.report.input == .cancelled(.saveFilename))
        #expect(cancelled.report.operation == .init(kind: .save, outcome: .cancelled))
        #expect((await world.perform("look")).report.input == .command)
    }

    @Test func restoreEventsNameRequestsOutcomesAndPromptContextsOnce() async throws {
        let directory = saveDirectory("restore-events")
        defer { try? FileManager.default.removeItem(at: directory) }
        let world = try await world(saveDirectory: directory)
        _ = await world.perform("save")
        _ = await world.perform("slot")

        let request = await world.perform("restore")
        #expect(request.report.operation == .init(kind: .restore, outcome: .requested))
        #expect(await world.inputContext == .restoreFilename)

        let completed = await world.perform("slot")
        #expect(completed.report.input == .promptAnswered(.restoreFilename))
        #expect(completed.report.operation == .init(kind: .restore, outcome: .completed))

        _ = await world.perform("restore")
        let failed = await world.perform("missing")
        #expect(failed.report.input == .promptAnswered(.restoreFilename))
        #expect(failed.report.operation == .init(kind: .restore, outcome: .failed))

        _ = await world.perform("restore")
        let cancelled = await world.perform("")
        #expect(cancelled.report.input == .cancelled(.restoreFilename))
        #expect(cancelled.report.operation == .init(kind: .restore, outcome: .cancelled))

        _ = await world.perform("restore")
        let publicCancellation = try #require(await world.cancelPendingInput())
        #expect(publicCancellation.report.input == .cancelled(.restoreFilename))
        #expect(publicCancellation.report.operation == .init(kind: .restore, outcome: .cancelled))
        #expect((await world.perform("look")).report.input == .command)
    }

    @Test func aFileWriteFailureReportsFailedInsteadOfCompleted() async throws {
        let blockedDirectory = saveDirectory("blocked")
        try Data("not a directory".utf8).write(to: blockedDirectory)
        defer { try? FileManager.default.removeItem(at: blockedDirectory) }
        let world = try await world(saveDirectory: blockedDirectory)

        _ = await world.perform("save")
        let result = await world.perform("slot")
        #expect(result.report.operation == .init(kind: .save, outcome: .failed))
        #expect(!result.output.contains("Saved."))
    }

    @Test(arguments: ["save", "restore"])
    func publicCancellationPreservesStateRandomnessTimersUndoAndFollowingInput(
        operation: String
    ) async throws {
        let directory = saveDirectory("cancel-\(operation)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let cancelledWorld = try await world(seed: 42, saveDirectory: directory)
        let controlWorld = try await world(seed: 42)
        let context: InputContext = operation == "save" ? .saveFilename : .restoreFilename
        let kind: TurnReport.OperationEvent.Kind = operation == "save" ? .save : .restore

        _ = await cancelledWorld.perform("wait")
        _ = await controlWorld.perform("wait")
        _ = await cancelledWorld.perform(operation)
        _ = await controlWorld.perform(operation)
        let before = await cancelledWorld.snapshot()

        for _ in 0..<20 {
            #expect(await cancelledWorld.inputContext == context)
        }
        let cancellation = try #require(await cancelledWorld.cancelPendingInput())
        #expect(cancellation.report.input == .cancelled(context))
        #expect(cancellation.report.operation == .init(kind: kind, outcome: .cancelled))
        #expect(cancellation.report.movement == nil)
        #expect(!cancellation.isFinished)
        #expect(await cancelledWorld.inputContext == .command)
        let after = await cancelledWorld.snapshot()
        #expect(after.moves == before.moves)
        #expect(after.status == before.status)
        #expect(after.playerLocation == before.playerLocation)
        #expect(after.rngState == before.rngState)
        #expect(after.activeFuses == before.activeFuses)
        #expect(after.globals == before.globals)
        #expect(after.placements == before.placements)
        #expect(!FileManager.default.fileExists(atPath: directory.path))

        let undoWorld = try await world(seed: 42)
        _ = await undoWorld.perform("wait")
        _ = await undoWorld.perform(operation)
        _ = await undoWorld.cancelPendingInput()
        #expect((await undoWorld.perform("undo")).status.moves == 0)

        _ = await controlWorld.perform("")
        let cancelledRoll = await cancelledWorld.perform("roll")
        let controlRoll = await controlWorld.perform("roll")
        #expect(cancelledRoll.output == controlRoll.output)
        #expect(cancelledRoll.output.contains("The bell rings."))
        let cancelledState = await cancelledWorld.snapshot()
        let controlState = await controlWorld.snapshot()
        #expect(cancelledState.rngState == controlState.rngState)
    }

    @Test func publicRestoreCancellationReturnsToTheDeathChoice() async throws {
        let directory = saveDirectory("death-restore")
        defer { try? FileManager.default.removeItem(at: directory) }
        let world = try GameWorld(game: MorgueGame(), seed: 1, saveDirectory: directory)
        _ = await world.begin()
        _ = await world.perform("take poison")
        #expect(await world.inputContext == .endGameChoice)

        let request = await world.perform("restore")
        #expect(request.report.input == .promptAnswered(.endGameChoice))
        #expect(request.report.operation == .init(kind: .restore, outcome: .requested))
        #expect(await world.inputContext == .restoreFilename)

        let cancellation = try #require(await world.cancelPendingInput())
        #expect(cancellation.report.input == .cancelled(.restoreFilename))
        #expect(cancellation.report.operation == .init(kind: .restore, outcome: .cancelled))
        #expect(cancellation.output.contains("RESTORE"))
        #expect(await world.inputContext == .endGameChoice)

        let restart = await world.perform("restart")
        #expect(restart.report.input == .promptAnswered(.endGameChoice))
        #expect(!restart.isFinished)
        #expect(await world.inputContext == .command)
    }

    @Test func cancellationOnlyConsumesSaveAndRestorePrompts() async throws {
        let world = try GameWorld(game: CausalMovementGame(), seed: 0)
        _ = await world.begin()
        #expect(await world.cancelPendingInput() == nil)

        _ = await world.perform("take key")
        #expect(await world.inputContext == .clarification)
        #expect(await world.cancelPendingInput() == nil)
        #expect(await world.inputContext == .clarification)
    }
}
