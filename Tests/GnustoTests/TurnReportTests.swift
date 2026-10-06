import Foundation
import Testing

@testable import Gnusto

struct TurnReportTests {
    private let hall = EntityID("hall")
    private let kitchen = EntityID("kitchen")
    private let cellar = EntityID("cellar")
    private let garden = EntityID("garden")
    private let mazeA = EntityID("mazeA")

    /// A fresh ``CartographyGame`` with its opening already printed, saving
    /// into a directory of its own.
    private func world() async throws -> GameWorld {
        let saves = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let world = try GameWorld(game: CartographyGame(), seed: 0, saveDirectory: saves)
        _ = await world.begin()
        return world
    }

    @Test func aWalkNamesBothRoomsAndTheDirection() async throws {
        let world = try await world()
        let report = await world.perform("north").report
        #expect(report.understood)
        #expect(report.unknownWords.isEmpty)
        #expect(report.movement == .walked(from: hall, to: kitchen, direction: .north))
    }

    @Test func aDynamicExitIsAWalkToWhereverItLed() async throws {
        let world = try await world()
        _ = await world.perform("north")
        #expect(
            await world.perform("east").report.movement
                == .walked(from: kitchen, to: mazeA, direction: .east))
    }

    @Test func enteringADoorByNameIsAWalkInTheDoorsDirection() async throws {
        let world = try await world()
        _ = await world.perform("push rug")
        _ = await world.perform("open trap door")
        #expect(
            await world.perform("enter trap door").report.movement
                == .walked(from: hall, to: cellar, direction: .down))
    }

    @Test func aRuleThatPutsThePlayerNextDoorIsATeleportNotAWalk() async throws {
        let world = try await world()
        // The hall has an exit east to the garden, latched. Praying is not using it.
        #expect(await world.perform("pray").report.movement == .teleported(from: hall, to: garden))
    }

    @Test func aRefusedMoveReportsNoMovement() async throws {
        let world = try await world()
        for line in ["east", "west", "down", "south"] {
            let report = await world.perform(line).report
            #expect(report.understood, "\(line)")
            #expect(report.movement == nil, "\(line)")
        }
    }

    @Test func undoAndRestartAreRelocationsNotWalks() async throws {
        let world = try await world()
        _ = await world.perform("north")
        #expect(await world.perform("undo").report.movement == .relocated(to: hall))
        _ = await world.perform("north")
        #expect(await world.perform("restart").report.movement == .relocated(to: hall))
    }

    @Test func aLineTheGameCannotReadIsNotUnderstood() async throws {
        let world = try await world()
        let report = await world.perform("frotz").report
        #expect(!report.understood)
        #expect(report.unknownWords == ["frotz"])
        #expect(report.movement == nil)
    }

    @Test func theOpeningReportsInitialization() async throws {
        let world = try GameWorld(game: CartographyGame(), seed: 0)
        let report = await world.begin().report
        #expect(report.input == .initialization)
        #expect(report.operation == nil)
        #expect(report.movement == nil)
    }
}

extension TurnReportTests {
    private func causalWorld() async throws -> GameWorld {
        let world = try GameWorld(game: CausalMovementGame(), seed: 0)
        _ = await world.begin()
        return world
    }

    @Test func aClosedDoorRefusesAndAnOpenedConditionalExitWalks() async throws {
        let world = try await world()
        _ = await world.perform("push rug")
        let closed = await world.perform("enter trap door")
        #expect(closed.report.understood)
        #expect(closed.report.movement == nil)
        #expect(closed.status.locationID == hall)
        _ = await world.perform("unlatch")
        #expect(await world.perform("east").report.movement == .walked(from: hall, to: garden, direction: .east))
    }

    @Test func aParsedDirectionDoesNotTurnATeleportIntoAWalk() async throws {
        let world = try GameWorld(game: RedirectedMovementGame(), seed: 0)
        _ = await world.begin()
        let result = await world.perform("north")
        #expect(result.report.understood)
        #expect(result.report.movement == .teleported(from: hall, to: garden))
    }

    @Test func enteringNamesTheDoorDirectionNotAnAdjacentRoomsFirstExit() async throws {
        let world = try await causalWorld()
        let result = await world.perform("enter oak door")
        #expect(result.output.contains("Kitchen"))
        #expect(result.report.movement == .walked(from: hall, to: kitchen, direction: .east))
    }

    @Test func followReportsTheActualCompassTieBreak() async throws {
        let world = try GameWorld(game: FollowLab(), seed: 0)
        _ = await world.begin()
        _ = await world.perform("send porch marker")
        let result = await world.perform("follow walker")
        #expect(result.output.contains("(after the walker)"))
        #expect(result.output.contains("Porch"))
        #expect(result.report.movement == .walked(from: hall, to: EntityID("porch"), direction: .south))
    }

    @Test func followReportsTheOpenRoutePastAnEarlierBlockedCandidate() async throws {
        let world = try GameWorld(game: FollowLab(), seed: 0)
        _ = await world.begin()
        _ = await world.perform("send crypt marker")
        let result = await world.perform("follow walker")
        #expect(result.output.contains("Crypt"))
        #expect(!result.output.contains("The crypt gate is barred."))
        #expect(result.report.movement == .walked(from: hall, to: EntityID("crypt"), direction: .up))
    }

    @Test func aDynamicDestinationIsNotReevaluatedToProduceTheReport() async throws {
        let world = try await causalWorld()
        let result = await world.perform("west")
        #expect(result.status.locationID == kitchen)
        #expect(result.report.movement == .walked(from: hall, to: kitchen, direction: .west))
        #expect(await world.perform("readings").output == "Destination reads: 1.")
    }

    @Test func onEnterTeleportAndMultipleWalksAreDirectionless() async throws {
        for mode in ["teleport", "chainwalk"] {
            let world = try await causalWorld()
            _ = await world.perform(mode)
            let result = await world.perform("east")
            #expect(result.status.locationID == garden)
            #expect(result.report.movement == .teleported(from: hall, to: garden))
        }
    }

    @Test func aRoundTripAndASelfLoopHaveNoNetMovement() async throws {
        let world = try await causalWorld()
        #expect(await world.perform("south").report.movement == nil)
        _ = await world.perform("roundtrip")
        let result = await world.perform("east")
        #expect(result.status.locationID == hall)
        #expect(result.report.movement == nil)
    }

    @Test func anAuthorWalkWithoutAConfirmedExitIsDirectionless() async throws {
        let world = try await causalWorld()
        #expect(await world.perform("authorwalk").report.movement == .teleported(from: hall, to: kitchen))
    }

    @Test func exitOnFootReportsOut() async throws {
        let world = try await causalWorld()
        #expect(await world.perform("exit").report.movement == .walked(from: hall, to: garden, direction: .out))
    }

    @Test func anUnhandledTurnDiscardsMovementInPublicAndAuditedResults() async throws {
        let world = try await causalWorld()
        let result = await world.perform("unanswered")
        #expect(result.report.understood)
        #expect(result.status.locationID == hall)
        #expect(result.report.movement == nil)
        let audited = await world.performAudited("unanswered")
        #expect(audited.result.status.locationID == hall)
        #expect(audited.result.report.movement == nil)
    }

    @Test func restoreFilenameRelocatesAndIsNotAParsedCommand() async throws {
        let world = try await world()
        #expect(await world.perform("save").report.understood)
        let saved = await world.perform("hall-slot").report
        #expect(saved.input == .promptAnswered(.saveFilename))
        #expect(saved.operation == .init(kind: .save, outcome: .completed))
        #expect(saved.movement == nil)
        _ = await world.perform("north")
        #expect(await world.perform("restore").report.movement == nil)
        let result = await world.perform("hall-slot")
        #expect(!result.report.understood)
        #expect(result.report.unknownWords.isEmpty)
        #expect(result.report.movement == .relocated(to: hall))
    }

    @Test func failedCancelledAndSameRoomRestoresDoNotMove() async throws {
        let world = try await world()
        _ = await world.perform("save")
        _ = await world.perform("hall-slot")
        let answers: [(String, TurnReport.InputEvent, TurnReport.OperationEvent.Outcome)] = [
            ("missing-slot", .promptAnswered(.restoreFilename), .failed),
            ("", .cancelled(.restoreFilename), .cancelled),
            ("hall-slot", .promptAnswered(.restoreFilename), .completed),
        ]
        for (answer, input, outcome) in answers {
            _ = await world.perform("restore")
            let report = await world.perform(answer).report
            #expect(report.input == input)
            #expect(report.operation == .init(kind: .restore, outcome: outcome))
            #expect(report.movement == nil)
        }
        #expect(await world.perform("restart").report.movement == nil)
        #expect(await world.perform("undo").report.movement == nil)
    }

    @Test func deathPromptStateReplacementIsARelocation() async throws {
        for answer in ["undo", "restart"] {
            let world = try await causalWorld()
            #expect(await world.perform("perish").report.movement == .teleported(from: hall, to: garden))
            let result = await world.perform(answer)
            #expect(!result.report.understood)
            #expect(result.report.movement == .relocated(to: hall))
        }
    }

    @Test func understoodIsIndependentOfActionSuccessAndUnknownWordsKeepOrder() async throws {
        let world = try await world()
        let refused = await world.perform("east")
        #expect(refused.report.understood)
        #expect(refused.report.unknownWords.isEmpty)
        let unknown = await world.perform("frotz zibble frotz")
        #expect(!unknown.report.understood)
        #expect(unknown.report.unknownWords == ["frotz", "zibble", "frotz"])
    }

    @Test func clarificationReportsOnlyWhenTheCommandResolves() async throws {
        let world = try await causalWorld()
        #expect(!((await world.perform("take key")).report.understood))
        let result = await world.perform("brass")
        #expect(result.report.understood)
        #expect(result.report.unknownWords.isEmpty)
        #expect(result.report.movement == nil)
        #expect(result.output.contains("Taken"))
    }

    @Test func againReportsTheRepeatedTraversal() async throws {
        let world = try GameWorld(game: FollowLab(), seed: 0)
        _ = await world.begin()
        _ = await world.perform("north")
        let result = await world.perform("again")
        #expect(result.report.understood)
        #expect(result.report.movement == .walked(from: EntityID("study"), to: EntityID("attic"), direction: .north))
    }

    @Test func openingAndQuitEventsReportNoMovementEvenWhenOutputHooksMove() async throws {
        let world = try GameWorld(game: ReportOutputHookGame(), seed: 0)
        let opening = await world.begin()
        #expect(opening.report.input == .initialization)
        #expect(opening.report.movement == nil)
        #expect(opening.status.locationID == kitchen)
        #expect(opening.output.contains("opening carried you"))
        let quitting = await world.requestQuit()
        #expect(quitting.report.input == .frontendQuit)
        #expect(quitting.report.movement == nil)
        #expect(quitting.status.locationID == garden)
        #expect(quitting.output.contains("closing carried you"))
        let repeatedQuit = await world.requestQuit().report
        #expect(repeatedQuit.input == .frontendQuit)
        #expect(repeatedQuit.movement == nil)
    }

    @Test func commandMovementStillReportsInTheOutputHookGame() async throws {
        let world = try GameWorld(game: ReportOutputHookGame(), seed: 0)
        _ = await world.begin()
        #expect(await world.perform("north").report.movement == .walked(from: kitchen, to: garden, direction: .north))
        #expect(await world.perform("restart").report.movement == .relocated(to: kitchen))
        #expect(await world.perform("quit").report.movement == .teleported(from: kitchen, to: garden))
    }
}
