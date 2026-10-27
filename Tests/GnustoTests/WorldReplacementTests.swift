import Foundation
import Gnusto
import GnustoTestSupport
import Testing

// Only for the game type, which its module keeps internal. The engine is
// imported plainly, so every call below is one a front end can make.
@testable import Zork1

/// ``TurnReport/worldReplacement`` through the engine's public API, as a front
/// end sees it.
struct WorldReplacementTests {
    /// A directory of its own for one test's saves.
    private func freshSaves() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    /// A fresh Zork I with its opening printed, and the room the opening put
    /// the player in.
    private func zork() async throws -> (GameWorld, opening: EntityID) {
        let world = try cachedWorld(Zork1(), seed: 0, saveDirectory: freshSaves())
        let opening = await world.begin().status.locationID
        return (world, opening)
    }

    /// A fresh ``MorgueGame``, where `take poison` kills the player where they
    /// stand, with its opening printed.
    private func morgue() async throws -> GameWorld {
        let world = try cachedWorld(MorgueGame(), seed: 0, saveDirectory: freshSaves())
        _ = await world.begin()
        return world
    }

    @Test func anOopsCorrectedRestartInSuperbriefIsARestart() async throws {
        let (world, westOfHouse) = try await zork()
        _ = await world.perform("north")
        _ = await world.perform("superbrief")
        #expect(await world.perform("restrat").report.worldReplacement == nil)
        let result = await world.perform("oops restart")
        #expect(result.report.worldReplacement == .restart)
        #expect(result.report.movement == .relocated(to: westOfHouse))
        #expect(result.status.locationID == westOfHouse)
        #expect(result.status.moves == 0)
    }

    @Test func aRestartWhereThePlayerStandsIsStillARestart() async throws {
        for mode in ["brief", "superbrief"] {
            for line in ["restart", "  RESTART. "] {
                let (world, _) = try await zork()
                _ = await world.perform(mode)
                _ = await world.perform("open the mailbox")
                let report = await world.perform(line).report
                #expect(report.worldReplacement == .restart, "\(mode) / \(line)")
                #expect(report.input == .command)
                #expect(report.movement == nil)
            }
        }
    }

    @Test func undoAndRestoreAreTheirOwnReplacements() async throws {
        let (world, westOfHouse) = try await zork()
        _ = await world.perform("north")
        let undone = await world.perform("undo").report
        #expect(undone.worldReplacement == .undo)
        #expect(undone.movement == .relocated(to: westOfHouse))

        // A save named "restart" is still a restore when it is read back.
        _ = await world.perform("save")
        let saved = await world.perform("restart").report
        #expect(saved.worldReplacement == nil)
        #expect(saved.operation?.outcome == .completed)
        _ = await world.perform("restore")
        let restored = await world.perform("restart").report
        #expect(restored.worldReplacement == .restore)
        #expect(restored.operation?.outcome == .completed)
        #expect(restored.movement == nil)
    }

    @Test func nothingElseReplacesTheWorld() async throws {
        let world = try cachedWorld(Zork1(), seed: 0, saveDirectory: freshSaves())
        #expect(await world.begin().report.worldReplacement == nil)
        // An UNDO with nothing to undo replaces nothing.
        for line in ["undo", "look", "verbose", "brief", "superbrief", "score", "north", "frotz"] {
            #expect(await world.perform(line).report.worldReplacement == nil, "\(line)")
        }
        _ = await world.perform("restore")
        #expect(await world.perform("missing-slot").report.worldReplacement == nil)
    }

    @Test func eachEndGameChoiceReportsWhatReplacedTheWorld() async throws {
        let answers: [(String, TurnReport.WorldReplacement)] = [
            ("restart", .restart), ("RESTART", .restart), ("undo", .undo),
        ]
        for (answer, replacement) in answers {
            let world = try await morgue()
            _ = await world.perform("superbrief")
            _ = await world.perform("take poison")
            #expect(await world.inputContext == .endGameChoice)
            let report = await world.perform(answer).report
            #expect(report.worldReplacement == replacement, "\(answer)")
            #expect(report.input == .promptAnswered(.endGameChoice))
            // The player died where they stood, so nothing moved.
            #expect(report.movement == nil)
        }
    }

    @Test func aRestoreChosenAfterDeathIsARestore() async throws {
        let world = try await morgue()
        _ = await world.perform("save")
        _ = await world.perform("slot")
        _ = await world.perform("take poison")
        _ = await world.perform("restore")
        let report = await world.perform("slot").report
        #expect(report.worldReplacement == .restore)
        #expect(report.operation?.outcome == .completed)
    }
}
