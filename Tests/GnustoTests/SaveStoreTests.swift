import Foundation
import Testing

@testable import Gnusto

struct SaveStoreTests {
    /// A fresh, empty temp directory for one test.
    private func tempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gnusto-savestore-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: resolve

    @Test func bareNameResolvesUnderTheDirectoryWithExtension() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = try #require(SaveStore.resolve("autumn", in: dir))
        #expect(url.deletingLastPathComponent().path == dir.path)
        #expect(url.lastPathComponent == "autumn.gnusto")
    }

    @Test func nameWithSpacesIsSanitized() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = try #require(SaveStore.resolve("my   save", in: dir))
        #expect(url.lastPathComponent == "my-save.gnusto")
    }

    /// #488: the old sanitizer kept only ASCII, so every all-CJK name emptied
    /// to the same literal slot and the second save overwrote the first.
    @Test func twoNonASCIINamesAreTwoDifferentFiles() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let one = try #require(SaveStore.resolve("セーブ", in: dir))
        let two = try #require(SaveStore.resolve("日本語", in: dir))
        #expect(one.lastPathComponent == "セーブ.gnusto")
        #expect(two.lastPathComponent == "日本語.gnusto")
        #expect(one != two)
        #expect(one.deletingLastPathComponent().path == dir.path)
    }

    /// A name with no letter, number or underscore in it names no slot, rather
    /// than the literal `save` every other such name also used to name.
    @Test func aNameWithNothingUsableInItResolvesToNothing() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(SaveStore.resolve("!!!", in: dir) == nil)
        #expect(SaveStore.resolve("..", in: dir) == nil)
        #expect(SaveStore.resolve("...", in: dir) == nil)
    }

    @Test func explicitRelativePathIsUsedVerbatim() throws {
        let dir = tempDir()
        let url = try #require(SaveStore.resolve("saves/game1.sav", in: dir))
        #expect(url.path.hasSuffix("saves/game1.sav"))
        #expect(!url.path.hasPrefix(dir.path))
    }

    @Test func absolutePathIsUsedVerbatim() throws {
        let url = try #require(SaveStore.resolve("/tmp/mygame.sav", in: tempDir()))
        #expect(url.path == "/tmp/mygame.sav")
    }

    @Test func tildePathIsExpanded() throws {
        let url = try #require(SaveStore.resolve("~/mygame.sav", in: tempDir()))
        #expect(!url.path.contains("~"))
        #expect(url.path.hasSuffix("/mygame.sav"))
    }

    @Test func pathTraversalInABareNameIsNeutralized() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        // "../secret" has a slash → treated as an explicit path (not a slot), so
        // it never masquerades as a bare name. Dots are not name characters, so
        // a name built out of them survives to nothing and is refused.
        #expect(SaveStore.resolve("..", in: dir) == nil)
        let mixed = try #require(SaveStore.resolve("..autumn..", in: dir))
        #expect(mixed.deletingLastPathComponent().path == dir.path)
        #expect(mixed.lastPathComponent == "autumn.gnusto")
    }

    /// A very long name still has to fit a filesystem component, and the limit
    /// is a byte limit — so a name short in characters can still be too long.
    @Test func aVeryLongNameIsBoundedForTheFilesystem() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        for name in [String(repeating: "a", count: 500), String(repeating: "書", count: 300)] {
            let url = try #require(SaveStore.resolve(name, in: dir))
            #expect(url.lastPathComponent.utf8.count < 255)
            // And it is a name that can actually be written.
            try Data("x".utf8).write(to: url)
        }
    }

    // MARK: resolveForWrite

    /// A refused name provisions nothing: the saves directory is not created as
    /// a side effect of a save that is about to fail.
    @Test func resolveForWriteOfAnUnusableNameCreatesNothing() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gnusto-unusable-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(try SaveStore.resolveForWrite("!!!", in: dir) == nil)
        #expect(!FileManager.default.fileExists(atPath: dir.path))
    }

    // MARK: existingSaveNames

    @Test func existingSaveNamesListsGnustoFilesSorted() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        for name in ["zeta", "alpha", "middle"] {
            try Data("x".utf8).write(to: dir.appendingPathComponent("\(name).gnusto"))
        }
        try Data("x".utf8).write(to: dir.appendingPathComponent("notes.txt"))  // ignored
        #expect(SaveStore.existingSaveNames(in: dir) == ["alpha", "middle", "zeta"])
    }

    @Test func existingSaveNamesListsNonASCIISlots() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        for name in ["セーブ", "日本語"] {
            let url = try #require(SaveStore.resolve(name, in: dir))
            try Data("x".utf8).write(to: url)
        }
        // Both slots are there — the listing shows what the player typed, and
        // each one resolves back to its own file.
        let listed = SaveStore.existingSaveNames(in: dir)
        #expect(listed.count == 2)
        #expect(Set(listed) == ["セーブ", "日本語"])
        for name in listed {
            #expect(SaveStore.resolve(name, in: dir)?.lastPathComponent == "\(name).gnusto")
        }
    }

    /// A `.gnusto` dropped in the directory by hand under a name the prompt
    /// would refuse is not offered: the listing is names a player can type.
    @Test func existingSaveNamesSkipsNamesThePromptWouldNotAccept() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data("x".utf8).write(to: dir.appendingPathComponent("alpha.gnusto"))
        try Data("x".utf8).write(to: dir.appendingPathComponent("---.gnusto"))
        #expect(SaveStore.existingSaveNames(in: dir) == ["alpha"])
    }

    @Test func existingSaveNamesIsEmptyForMissingDirectory() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("gnusto-missing-\(UUID().uuidString)")
        #expect(SaveStore.existingSaveNames(in: missing).isEmpty)
    }

    // MARK: defaultDirectory

    @Test func defaultDirectoryHonorsEnvOverride() {
        let url = SaveStore.defaultDirectory(
            forGameTitled: "Zork I",
            environment: ["GNUSTO_SAVE_DIR": "/tmp/my-saves"])
        #expect(url.path == "/tmp/my-saves")
    }

    @Test func defaultDirectoryFallsBackToAppSupportWithSanitizedTitle() {
        let url = SaveStore.defaultDirectory(
            forGameTitled: "Zork I: The Great Underground Empire",
            environment: [:])
        #expect(url.path.contains("Gnusto/Saves"))
        #expect(url.lastPathComponent == "Zork-I-The-Great-Underground-Empire")
    }

    /// The per-game folder follows the slot rule, so two games with all-CJK
    /// titles no longer share one directory.
    @Test func defaultDirectoryKeepsANonASCIITitleWhole() {
        let one = SaveStore.defaultDirectory(forGameTitled: "ゾーク", environment: [:])
        let two = SaveStore.defaultDirectory(forGameTitled: "迷宮", environment: [:])
        #expect(one.lastPathComponent == "ゾーク")
        #expect(two.lastPathComponent == "迷宮")
        #expect(one != two)
    }

    // MARK: directoryIsInjected

    /// `GNUSTO_SAVE_DIR` set to a non-empty value is what makes a session
    /// program-driven, and so slot-only — including the `GameMain` path where
    /// no `saveDirectory:` argument was passed and the injection is invisible
    /// to the initializer.
    @Test func directoryIsInjectedReadsTheEnvOverride() {
        #expect(SaveStore.directoryIsInjected(environment: ["GNUSTO_SAVE_DIR": "/tmp/s"]))
        #expect(!SaveStore.directoryIsInjected(environment: [:]))
        #expect(!SaveStore.directoryIsInjected(environment: ["GNUSTO_SAVE_DIR": ""]))
    }

    // MARK: file permissions

    @Test func resolveForWriteCreatesTheSavesDirectoryOwnerOnly() throws {
        // A not-yet-existing saves directory: resolving a bare name for write
        // provisions it 0700.
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gnusto-perms-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        _ = try SaveStore.resolveForWrite("autumn", in: dir)
        let perms =
            try FileManager.default.attributesOfItem(atPath: dir.path)[.posixPermissions] as? Int
        #expect(perms == 0o700)
    }

    @Test func writtenSaveFileIsOwnerOnly() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("game.gnusto")
        try SaveFile.write(WorldState(playerLocation: EntityID("room")), title: "T", to: url)
        let perms =
            try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int
        #expect(perms == 0o600)
    }
}
