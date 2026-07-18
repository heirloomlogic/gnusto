import Foundation
import GnustoTestSupport
import Testing

@testable import Gnusto

/// Two rooms, a takable coin, a random `roll`, and a bell fuse — everything a
/// save file has to carry: placements, position, moves, the random stream,
/// and the timer schedule.
private struct StrongboxGame: Game {
    let title = "Vault"
    let intro = "The vault door stands open."

    let anteroom = Location {
        name("Anteroom")
        description("Bare marble.")
    }

    let vault = Location {
        name("Vault")
        description("Racks of empty deposit boxes.")
    }

    let coin = Item {
        name("gold coin")
    }

    var map: WorldMap {
        player.starts(in: anteroom)
        coin.starts(in: anteroom)
        anteroom.north(vault)
        vault.south(anteroom)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("roll", intent: Intent("roll"))
        SyntaxRule("ring", intent: Intent("ring"))
    }

    var rules: Rules {
        world.before(Intent("roll")) {
            try reply("You roll \(random(1...1000)).")
        }
        world.before(Intent("ring")) {
            startFuse("bell")
            try reply("You wind the bell.")
        }
    }

    var timers: [TimedEvent] {
        fuse("bell", after: 3) {
            say("The bell rings!")
        }
    }
}

/// A different title — its save files must be rejected by StrongboxGame.
private struct OtherGame: Game {
    let title = "Other"
    let intro = "Elsewhere."

    let room = Location {
        name("Elsewhere Room")
        description("Not the vault.")
    }

    var map: WorldMap {
        player.starts(in: room)
    }
}

private func temporarySavePath(_ label: String) -> String {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("gnusto-\(label)-\(UUID().uuidString).sav").path
}

struct SaveRestoreTests {
    @Test func saveAndRestoreRoundTripsTheWorld() async throws {
        let path = temporarySavePath("roundtrip")
        defer { try? FileManager.default.removeItem(atPath: path) }
        let transcript = try await play(
            StrongboxGame(),
            [
                "take coin", "north", "save", path,
                "drop coin", "south", "score",
                "restore", path, "score", "inventory",
            ])
        expectInOrder(
            transcript,
            ["> save", "Save to what file?", "Saved."])
        // The restore reply, then the re-entry description of the saved room.
        expectInOrder(transcript, ["Restored.", "Vault"])
        // Moves rewound to the save point: the two score probes differ.
        let scores = transcript.components(separatedBy: "> score")
        let beforeRestore = scores[1].prefix(while: { $0 != ">" })
        let afterRestore = scores[2].prefix(while: { $0 != ">" })
        #expect(beforeRestore != afterRestore)
        // The coin is back in hand (the post-save drop never happened).
        let inventory = turnOutput(of: "inventory", in: transcript)
        #expect(inventory.contains("gold coin"))
    }

    @Test func restoreResumesTheRandomStream() async throws {
        let path = temporarySavePath("rng")
        defer { try? FileManager.default.removeItem(atPath: path) }
        let transcript = try await play(
            StrongboxGame(),
            ["save", path, "roll", "restore", path, "roll"],
            seed: 1234)
        let rolls = transcript.components(separatedBy: "> roll")
        let first = rolls[1].prefix(while: { $0 != ">" })
        let second = rolls[2].prefix(while: { $0 != ">" })
        #expect(first == second)
    }

    @Test func restoreResumesTheTimerSchedule() async throws {
        let path = temporarySavePath("timers")
        defer { try? FileManager.default.removeItem(atPath: path) }
        let transcript = try await play(
            StrongboxGame(),
            [
                "ring", "save", path,  // fuse at 2 after the ring turn's tick
                "look", "look",  // 2→1, 1→0: rings
                "restore", path,
                "look", "look",  // the same two turns ring it again
            ])
        #expect(transcript.components(separatedBy: "The bell rings!").count == 3)
        let looks = transcript.components(separatedBy: "> look")
        #expect(looks[2].contains("The bell rings!"))
        #expect(looks[4].contains("The bell rings!"))
    }

    @Test func restoreValidatesTheFile() async throws {
        let wrongGamePath = temporarySavePath("wrong")
        let garbagePath = temporarySavePath("garbage")
        defer {
            try? FileManager.default.removeItem(atPath: wrongGamePath)
            try? FileManager.default.removeItem(atPath: garbagePath)
        }
        // A real save file — from a different game.
        _ = try await play(OtherGame(), ["save", wrongGamePath])
        try Data("not a save".utf8).write(to: URL(fileURLWithPath: garbagePath))

        let transcript = try await play(
            StrongboxGame(),
            [
                "restore", wrongGamePath,
                "restore", garbagePath,
                "restore", temporarySavePath("missing"),
                "restore", "",
                "save", "",
                "score",
            ])
        #expect(transcript.contains("That save file is from a different game."))
        #expect(transcript.components(separatedBy: "Restore failed.").count == 3)
        #expect(transcript.components(separatedBy: "Cancelled.").count == 3)
        // Every one of those exchanges was free.
        let score = turnOutput(of: "score", in: transcript)
        #expect(score.contains("in 0 turns"))
    }

    @Test func aBareNameSavesUnderTheSaveDirectoryAndRestores() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gnusto-slots-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let transcript = try await play(
            StrongboxGame(),
            ["take coin", "save", "autumn", "drop coin", "restore", "autumn", "inventory"],
            saveDirectory: dir)
        expectInOrder(transcript, ["Save to what file?", "Saved.", "Restored."])
        // The name became a `.gnusto` file in the saves directory — no path typed.
        #expect(
            FileManager.default.fileExists(
                atPath: dir.appendingPathComponent("autumn.gnusto").path))
        // The post-save drop was rewound: the coin is back in hand.
        #expect(turnOutput(of: "inventory", in: transcript).contains("gold coin"))
    }

    @Test func theRestorePromptListsExistingSaves() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gnusto-list-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        // Make two saves, then open the restore prompt (empty answer cancels).
        let transcript = try await play(
            StrongboxGame(),
            ["save", "spring", "save", "autumn", "restore", ""],
            saveDirectory: dir)
        // Sorted, so "autumn" precedes "spring".
        #expect(transcript.contains("Restore from what file? (saved: autumn, spring)"))
    }

    @Test func savingLeavesTheUndoSnapshotAlone() async throws {
        let path = temporarySavePath("undo")
        defer { try? FileManager.default.removeItem(atPath: path) }
        let transcript = try await play(
            StrongboxGame(),
            ["take coin", "save", path, "undo", "take coin"])
        let undo = turnOutput(of: "undo", in: transcript)
        #expect(undo.contains("Previous turn undone."))
        let takes = transcript.components(separatedBy: "> take coin")
        #expect(takes[2].contains("Taken."))
    }
}
