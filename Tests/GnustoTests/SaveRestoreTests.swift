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

    let box = Item {
        name("strongbox")
        container
        openable
    }

    @Global var disturbances = 0

    var map: WorldMap {
        player.starts(in: anteroom)
        coin.starts(in: anteroom)
        box.starts(in: vault)
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

/// A saved definition from before the annex, its coin, and its timers existed.
private struct LegacyAdditionGame: Game {
    let title = "Additive Restore"
    let intro = "The original room."

    let room = Location { name("Original Room") }

    var map: WorldMap {
        player.starts(in: room)
    }
}

/// The evolved definition used to prove the restore prompt supplies the
/// pristine state needed by save reconciliation.
private struct EvolvedAdditionGame: Game {
    let title = "Additive Restore"
    let intro = "The annex is open."

    let room = Location { name("Original Room") }
    let newCoin = Item { name("new coin") }

    var map: WorldMap {
        player.starts(in: room)
        newCoin.starts(in: room)
    }

    var timers: [TimedEvent] {
        fuse("newFuse", after: 2, autostart: true) {
            say("The new fuse fires.")
        }
        daemon("newDaemon", autostart: true) {
            say("The new daemon runs.")
        }
    }
}

private func temporarySavePath(_ label: String) -> String {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("gnusto-\(label)-\(UUID().uuidString).sav").path
}

/// A throwaway saves directory for one test. Not created — `resolveForWrite`
/// provisions it, which is half of what several of these tests are checking.
private func temporarySaveDirectory(_ label: String) -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("gnusto-\(label)-\(UUID().uuidString)", isDirectory: true)
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

    @Test func restoreInstallsAdditionsFromTheCurrentDefinition() async throws {
        let path = temporarySavePath("additions")
        defer { try? FileManager.default.removeItem(atPath: path) }
        _ = try await play(LegacyAdditionGame(), ["save", path])

        let transcript = try await play(
            EvolvedAdditionGame(), ["restore", path, "take new coin", "wait"])

        #expect(transcript.contains("Restored."))
        #expect(turnOutput(of: "take new coin", in: transcript).contains("Taken."))
        #expect(
            transcript.components(separatedBy: "The new daemon runs.").count == 3)
        #expect(turnOutput(of: "wait", in: transcript).contains("The new fuse fires."))
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
        let dir = temporarySaveDirectory("slots")
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

    /// A session whose saves directory was injected — the play-test harness,
    /// the replay tools, any driver that set one up — is slot-only: an explicit
    /// path at either prompt is refused and nothing is written or read there.
    /// (A human running the game themselves keeps the classic path behavior.)
    @Test func anInjectedSaveDirectoryRefusesExplicitPaths() async throws {
        let dir = temporarySaveDirectory("escape")
        let outside = temporarySavePath("escape")
        defer {
            try? FileManager.default.removeItem(at: dir)
            try? FileManager.default.removeItem(atPath: outside)
        }
        let transcript = try await play(
            StrongboxGame(),
            [
                "save", outside,  // refused; the file is never written
                "restore", outside,  // refused; the file is never read
                "save", "slot",  // the plain name still works
                "restore", "slot",
                "look",
            ],
            saveDirectory: dir)
        expectInOrder(transcript, ["Save to what file?", "Saved.", "Restored."])
        #expect(
            transcript.components(
                separatedBy: "Paths aren't allowed here; enter a plain name."
            ).count == 3)
        #expect(!FileManager.default.fileExists(atPath: outside))
        #expect(
            FileManager.default.fileExists(
                atPath: dir.appendingPathComponent("slot.gnusto").path))
        // Both refusals were free, and the round trip through the slot worked.
        let look = turnOutput(of: "look", in: transcript)
        #expect(look.contains("Anteroom"))
    }

    /// LOAD is RESTORE. It is the word a player who has just typed SAVE reaches
    /// for next, and it went to "I don't know the word "load"." — which reads,
    /// wrongly, as if the game had no way to bring a save back.
    @Test func loadIsAnotherSpellingOfRestore() async throws {
        let path = temporarySavePath("load")
        defer { try? FileManager.default.removeItem(atPath: path) }
        let transcript = try await play(
            StrongboxGame(),
            ["take coin", "save", path, "drop coin", "load", path, "inventory"])
        expectInOrder(transcript, ["Saved.", "Restore from what file?", "Restored."])
        #expect(turnOutput(of: "inventory", in: transcript).contains("gold coin"))
    }

    /// #488: two Japanese slot names held nothing the old ASCII sanitizer kept,
    /// so both resolved to `save.gnusto` and the second save silently destroyed
    /// the first. They are two files now, and each restores its own world.
    @Test func twoNonASCIISlotNamesAreTwoSavesAndBothRestore() async throws {
        let dir = temporarySaveDirectory("cjk")
        defer { try? FileManager.default.removeItem(at: dir) }
        let transcript = try await play(
            StrongboxGame(),
            [
                "take coin", "save", "セーブ",  // coin in hand
                "drop coin", "save", "日本語",  // coin on the floor
                "restore", "セーブ", "inventory",  // the first save survived
                "restore", "日本語", "inventory",  // and so did the second
            ],
            saveDirectory: dir)
        #expect(transcript.components(separatedBy: "Saved.").count == 3)
        #expect(transcript.components(separatedBy: "Restored.").count == 3)
        for name in ["セーブ", "日本語"] {
            #expect(
                FileManager.default.fileExists(
                    atPath: dir.appendingPathComponent("\(name).gnusto").path),
                "\(name)")
        }
        // The first restore has the coin; the second, taken after the drop,
        // does not — so the second save did not overwrite the first.
        #expect(turnOutput(of: "inventory", in: transcript).contains("gold coin"))
        #expect(!turnOutput(ofLast: "inventory", in: transcript).contains("gold coin"))
    }

    /// The restore prompt lists the names the player typed, not a mangling of
    /// them — which is what makes a non-ASCII slot findable again.
    @Test func theRestorePromptListsNonASCIISlotsAsTyped() async throws {
        let dir = temporarySaveDirectory("cjk-list")
        defer { try? FileManager.default.removeItem(at: dir) }
        let transcript = try await play(
            StrongboxGame(),
            ["save", "セーブ", "save", "日本語", "restore", ""],
            saveDirectory: dir)
        #expect(transcript.contains("(saved: セーブ, 日本語)"))
    }

    /// A name with no letter, number or underscore in it names no file. It used
    /// to become the literal slot `save`, which every other unusable name also
    /// became — so the prompt refuses instead, and nothing is written.
    @Test func aNameWithNothingUsableInItIsRefusedAtBothPrompts() async throws {
        let dir = temporarySaveDirectory("unusable")
        defer { try? FileManager.default.removeItem(at: dir) }
        let transcript = try await play(
            StrongboxGame(),
            ["save", "!!!", "restore", "...", "save", "keeper", "restore", "keeper", "look"],
            saveDirectory: dir)
        #expect(
            transcript.components(
                separatedBy: "That name has no letters or numbers in it. Try another."
            ).count == 3)
        // Nothing was written under the old stand-in name, or under any other.
        #expect(SaveStore.existingSaveNames(in: dir) == ["keeper"])
        // The refusals cost nothing and the usable name still round-trips.
        expectInOrder(transcript, ["Saved.", "Restored."])
        #expect(turnOutput(of: "look", in: transcript).contains("Anteroom"))
    }

    /// A save written before the byte bound existed has a basename longer than
    /// the rule now produces. It still has to be listed and still has to
    /// restore: dropping it would make a player's save invisible, and resolving
    /// the typed name to the truncated path would let the next long save
    /// overwrite a different slot.
    @Test func aSaveWrittenUnderTheOldUnboundedRuleStillRestores() async throws {
        let dir = temporarySaveDirectory("legacy-long")
        defer { try? FileManager.default.removeItem(at: dir) }
        let long = String(repeating: "a", count: 210)
        _ = try await play(
            StrongboxGame(), ["take coin", "save", "seed"], saveDirectory: dir)
        // What the old rule, which had no bound, would have named that file.
        try FileManager.default.moveItem(
            at: dir.appendingPathComponent("seed.gnusto"),
            to: dir.appendingPathComponent("\(long).gnusto"))

        #expect(SaveStore.existingSaveNames(in: dir) == [long])
        let transcript = try await play(
            StrongboxGame(), ["restore", long, "inventory"], saveDirectory: dir)
        #expect(transcript.contains("Restored."))
        #expect(turnOutput(of: "inventory", in: transcript).contains("gold coin"))
    }

    /// A saves directory carried off an HFS+ volume holds decomposed filenames.
    /// The prompt lists the composed name, because that is the name — and the
    /// restore has to read the directory's own entry, or on a volume that
    /// compares filenames byte for byte it reads a path that is not there. On
    /// macOS this passes either way — Foundation decomposes a file URL's path,
    /// and APFS compares names normalization-insensitively. Linux does neither,
    /// which is where this test earns its place; CI runs the suite there.
    @Test func aDecomposedSaveFilenameRestoresByItsComposedName() async throws {
        let dir = temporarySaveDirectory("decomposed")
        defer { try? FileManager.default.removeItem(at: dir) }
        _ = try await play(
            StrongboxGame(), ["take coin", "save", "seed"], saveDirectory: dir)
        try FileManager.default.moveItem(
            at: dir.appendingPathComponent("seed.gnusto"),
            to: dir.appendingPathComponent("cafe\u{301}.gnusto"))

        let transcript = try await play(
            StrongboxGame(), ["restore", "caf\u{e9}", "inventory"], saveDirectory: dir)
        #expect(transcript.contains("Restored."))
        #expect(turnOutput(of: "inventory", in: transcript).contains("gold coin"))
    }

    /// A name far longer than a filesystem component still saves and restores:
    /// the sanitizer bounds it in bytes, and the same typing finds it again.
    @Test func aVeryLongSlotNameSavesAndRestores() async throws {
        let dir = temporarySaveDirectory("long")
        defer { try? FileManager.default.removeItem(at: dir) }
        let long = String(repeating: "長", count: 300)
        let transcript = try await play(
            StrongboxGame(),
            ["take coin", "save", long, "drop coin", "restore", long, "inventory"],
            saveDirectory: dir)
        expectInOrder(transcript, ["Saved.", "Restored."])
        #expect(turnOutput(of: "inventory", in: transcript).contains("gold coin"))
        let slots = SaveStore.existingSaveNames(in: dir)
        #expect(slots.count == 1)
        #expect(slots[0].utf8.count <= FilesystemName.maximumBytes)
    }

    @Test func theRestorePromptListsExistingSaves() async throws {
        let dir = temporarySaveDirectory("list")
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

    // MARK: - Referential-integrity validation

    /// Reads the save at `path`, applies `mutate` to its `WorldState`, and
    /// writes the re-encoded file back — the crafted-file forge every tampering
    /// test shares. Uses the same encoder settings as `SaveFile.write`, so only
    /// the mutation distinguishes it from a genuine save.
    private func tamperWithSave(
        at path: String, _ mutate: (inout WorldState) -> Void
    ) throws {
        let url = URL(fileURLWithPath: path)
        let decoded = try JSONDecoder().decode(SaveFile.self, from: Data(contentsOf: url))
        var state = decoded.state
        mutate(&state)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let file = SaveFile(format: decoded.format, title: decoded.title, state: state)
        try encoder.encode(file).write(to: url, options: .atomic)
    }

    /// Saves a real game, tampers with the file, then restores it — asserting
    /// the restore is refused ("Restore failed.") and the game keeps running.
    private func expectTamperedSaveRejected(
        _ label: String,
        _ mutate: @escaping (inout WorldState) -> Void
    ) async throws {
        let path = temporarySavePath(label)
        defer { try? FileManager.default.removeItem(atPath: path) }
        _ = try await play(StrongboxGame(), ["save", path])
        try tamperWithSave(at: path, mutate)
        let transcript = try await play(StrongboxGame(), ["restore", path, "look"])
        #expect(transcript.contains("Restore failed."))
        // Rejected whole: the world is untouched and the next turn still works.
        #expect(turnOutput(of: "look", in: transcript).contains("Anteroom"))
    }

    @Test func tamperedUnknownPlayerLocationIsRejected() async throws {
        try await expectTamperedSaveRejected("bad-loc") {
            $0.setPlayerLocation(placingAt: EntityID("phantom-room"))
        }
    }

    @Test func tamperedUnknownPlacementKeyIsRejected() async throws {
        try await expectTamperedSaveRejected("bad-key") {
            $0.place(EntityID("phantom-item"), .nowhere)
        }
    }

    @Test func tamperedUnknownPlacementTargetIsRejected() async throws {
        try await expectTamperedSaveRejected("bad-target") {
            $0.place(EntityID("coin"), .room(EntityID("phantom-room")))
        }
    }

    @Test func tamperedPlacementCycleIsRejected() async throws {
        // The strongbox placed inside itself: resolution passes (it's a
        // container), so only the acyclicity walk can catch it.
        try await expectTamperedSaveRejected("cycle") {
            $0.place(EntityID("box"), .inside(EntityID("box")))
        }
    }

    @Test func tamperedMistypedGlobalIsRejected() async throws {
        // `disturbances` is declared `Int`; a string in its slot would trap when
        // a rule reads it back through `@Global`.
        try await expectTamperedSaveRejected("bad-global") {
            $0.globals[EntityID("disturbances")] = .string("not an int")
        }
    }

    @Test func tamperedNonPlayingStatusIsRejected() async throws {
        try await expectTamperedSaveRejected("bad-status") {
            $0.status = .won
        }
    }

    @Test func tamperedNegativeMovesIsRejected() async throws {
        try await expectTamperedSaveRejected("bad-moves") {
            $0.moves = -1
        }
    }

    @Test func tamperedTraitViolationIsRejected() async throws {
        // The coin is not a light source, so it can't legitimately be lit.
        try await expectTamperedSaveRejected("bad-trait") {
            $0.litItems = [EntityID("coin")]
        }
    }

    @Test func anUntamperedSaveWithAContainerAndGlobalStillRestores() async throws {
        // Guards against over-strictness: a genuine save that exercises a
        // container placement and an open openable must pass validation.
        let path = temporarySavePath("clean")
        defer { try? FileManager.default.removeItem(atPath: path) }
        let transcript = try await play(
            StrongboxGame(),
            [
                "take coin", "north", "open strongbox", "put coin in strongbox",
                "save", path, "south", "restore", path, "look",
            ])
        #expect(transcript.contains("Saved."))
        #expect(transcript.contains("Restored."))
        // Restored into the vault (where the save was taken), not the anteroom.
        #expect(turnOutput(of: "look", in: transcript).contains("Vault"))
    }
}
