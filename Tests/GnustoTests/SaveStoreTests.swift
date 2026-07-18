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

    @Test func bareNameResolvesUnderTheDirectoryWithExtension() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = SaveStore.resolve("autumn", in: dir)
        #expect(url.deletingLastPathComponent().path == dir.path)
        #expect(url.lastPathComponent == "autumn.gnusto")
    }

    @Test func nameWithSpacesIsSanitized() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(SaveStore.resolve("my   save", in: dir).lastPathComponent == "my-save.gnusto")
    }

    @Test func explicitRelativePathIsUsedVerbatim() {
        let dir = tempDir()
        let url = SaveStore.resolve("saves/game1.sav", in: dir)
        #expect(url.path.hasSuffix("saves/game1.sav"))
        #expect(!url.path.hasPrefix(dir.path))
    }

    @Test func absolutePathIsUsedVerbatim() {
        let url = SaveStore.resolve("/tmp/mygame.sav", in: tempDir())
        #expect(url.path == "/tmp/mygame.sav")
    }

    @Test func tildePathIsExpanded() {
        let url = SaveStore.resolve("~/mygame.sav", in: tempDir())
        #expect(!url.path.contains("~"))
        #expect(url.path.hasSuffix("/mygame.sav"))
    }

    @Test func pathTraversalInABareNameIsNeutralized() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        // "../secret" has a slash → treated as an explicit path (not a slot), so
        // it never masquerades as a bare name. A dots-only name collapses to a
        // safe slot under the directory.
        let dotsOnly = SaveStore.resolve("..", in: dir)
        #expect(dotsOnly.deletingLastPathComponent().path == dir.path)
        #expect(dotsOnly.pathExtension == "gnusto")
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
