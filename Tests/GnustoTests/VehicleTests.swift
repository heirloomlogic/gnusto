import Foundation
import Testing

@testable import Gnusto

/// Vehicles I: the `enterable` trait, BOARD/DISEMBARK in all their verb
/// forms, the refusal ladder, and the boarded flag riding UNDO and saves.
struct VehicleTests {
    @Test func boardingAndDisembarkingSpeakTheClassicLines() async throws {
        let transcript = try await play(
            HarborGame(),
            [
                "enter boat",
                "enter boat",
                "enter crate",
                "get out",
                "exit",
                "quit",
            ])
        expectInOrder(
            transcript,
            [
                "You are now in the red boat.",
                "You're already in the red boat.",
                "You'll have to get out of the red boat first.",
                "You get out of the red boat.",
                "You aren't in anything.",
            ])
    }

    @Test func everyVerbFormParses() async throws {
        let transcript = try await play(
            HarborGame(),
            [
                "board boat", "get out of boat",
                "get in boat", "exit boat",
                "get into boat", "disembark",
                "quit",
            ])
        let boardings = transcript.components(separatedBy: "You are now in the red boat.")
        let exits = transcript.components(separatedBy: "You get out of the red boat.")
        #expect(boardings.count == 4)
        #expect(exits.count == 4)
    }

    @Test func exitNamesTheThingYouAreActuallyIn() async throws {
        let transcript = try await play(
            HarborGame(),
            ["enter boat", "get out of crate", "quit"])
        expectInOrder(transcript, ["You aren't in the pine crate."])
    }

    @Test func onlyEnterablesAdmitYou() async throws {
        let transcript = try await play(
            HarborGame(),
            ["enter pebble", "quit"])
        expectInOrder(transcript, ["You can't get into that."])
    }

    @Test func aCarriedEnterableRefuses() async throws {
        let transcript = try await play(
            HarborGame(),
            ["take bucket", "enter bucket", "quit"])
        expectInOrder(
            transcript,
            ["Taken.", "You can't get into something you're carrying."])
    }

    @Test func hostBeforeRulesGateBoarding() async throws {
        let transcript = try await play(
            HarborGame(),
            ["chain", "enter boat", "quit"])
        expectInOrder(transcript, ["The boat is chained to the dock."])
    }

    @Test func bareOutIsStillADirection() async throws {
        let transcript = try await play(
            HarborGame(),
            ["out", "quit"])
        expectInOrder(transcript, ["You can't go that way."])
    }

    @Test func aBoatInAnotherRoomIsOutOfScope() async throws {
        let transcript = try await play(
            HarborGame(),
            ["north", "enter boat", "quit"])
        expectInOrder(transcript, ["You can't see any such thing."])
    }

    @Test func undoUnwindsBoarding() async throws {
        let transcript = try await play(
            HarborGame(),
            ["enter boat", "undo", "exit", "quit"])
        expectInOrder(
            transcript,
            [
                "You are now in the red boat.",
                "Previous turn undone.",
                "You aren't in anything.",
            ])
    }

    @Test func boardedStateSurvivesSaveAndRestore() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("gnusto-vehicle-\(UUID().uuidString).sav").path
        defer { try? FileManager.default.removeItem(atPath: path) }
        let transcript = try await play(
            HarborGame(),
            [
                "enter boat", "save", path,
                "get out", "restore", path,
                "exit", "quit",
            ])
        expectInOrder(
            transcript,
            [
                "Saved.",
                "You get out of the red boat.",
                "Restored.",
                "You get out of the red boat.",
            ])
    }
}
