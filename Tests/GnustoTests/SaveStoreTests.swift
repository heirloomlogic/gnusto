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

    // MARK: saves written under the old rule

    /// The byte bound is new, so a save the old rule wrote under a name longer
    /// than it is a file the new rule would never name. It still has to be
    /// listed, and typing its name back still has to reach it — otherwise the
    /// player's save is invisible and unreachable, and the next save sharing its
    /// first 200 bytes overwrites a different slot.
    @Test func aSaveWrittenBeforeTheByteBoundIsListedAndReached() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let long = String(repeating: "a", count: 210)
        let legacy = dir.appendingPathComponent("\(long).gnusto")
        try Data().write(to: legacy)

        #expect(SaveStore.existingSaveNames(in: dir) == [long])
        // The URL comes off the directory, whose path may be the resolved one,
        // so it is the filename that has to match and the file that has to be
        // there.
        let located = try #require(SaveStore.locate(long, in: dir))
        #expect(located.lastPathComponent == legacy.lastPathComponent)
        #expect(FileManager.default.fileExists(atPath: located.path))
        let forWrite = try #require(try SaveStore.resolveForWrite(long, in: dir))
        #expect(forWrite.lastPathComponent == legacy.lastPathComponent)
    }

    /// A slot that is genuinely absent still fails at the path it was asked for,
    /// rather than reaching some other file or refusing the name outright.
    @Test func anAbsentLongNameStillResolvesToItsComputedPath() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let long = String(repeating: "b", count: 210)
        let url = try #require(SaveStore.locate(long, in: dir))
        #expect(url.lastPathComponent == String(repeating: "b", count: 200) + ".gnusto")
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    /// A saves directory copied off HFS+ holds decomposed filenames. The listing
    /// shows the composed name, because that is the name; the URL it hands back
    /// has to be the directory's own entry, or the restore reads a path that
    /// does not exist on a volume that compares filenames byte for byte.
    @Test func aDecomposedFilenameIsListedComposedAndReachedByItsOwnBytes() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        // Swift compares strings by canonical equivalence, so the whole of this
        // is about bytes: the two spell one name and are two filenames.
        let decomposed = "cafe\u{301}"
        let composed = "caf\u{e9}"
        #expect(Array(decomposed.utf8) != Array(composed.utf8))
        let onDisk = dir.appendingPathComponent("\(decomposed).gnusto")
        try Data().write(to: onDisk)

        #expect(SaveStore.existingSaveNames(in: dir) == [composed])
        let entry = try #require(SaveStore.existingSaves(in: dir).first).url
        // APFS and ext4 both store the bytes they were given, so the scenario is
        // the real one. The assertion below is the weaker of the two platforms
        // on macOS, where Foundation decomposes a file URL's path and the two
        // spellings coincide anyway; on Linux nothing normalizes and it is the
        // real check. CI runs the suite there.
        #expect(
            Array(entry.lastPathComponent.utf8) == Array("\(decomposed).gnusto".utf8))
        let located = try #require(SaveStore.locate(composed, in: dir))
        #expect(Array(located.lastPathComponent.utf8) == Array(entry.lastPathComponent.utf8))
        #expect(FileManager.default.fileExists(atPath: located.path))
    }

    /// A `.gnusto` dropped in by hand under a name the prompt would rewrite is
    /// still left out: listing it offers a slot that cannot then be restored.
    @Test func aBasenameThePromptWouldRewriteIsNotListed() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data().write(to: dir.appendingPathComponent("two words.gnusto"))
        try Data().write(to: dir.appendingPathComponent("ok.gnusto"))
        #expect(SaveStore.existingSaveNames(in: dir) == ["ok"])
    }

    /// A byte-exact volume can hold both spellings of one name. They are one
    /// slot to a player, so the prompt offers it once, and which file that is
    /// does not depend on the order the directory was read in.
    @Test func twoSpellingsOfOneNameAreListedOnce() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data().write(to: dir.appendingPathComponent("cafe\u{301}.gnusto"))
        try Data().write(to: dir.appendingPathComponent("caf\u{e9}.gnusto"))
        guard try FileManager.default.contentsOfDirectory(atPath: dir.path).count == 2 else {
            return  // A normalizing volume never has the two side by side.
        }

        let saves = SaveStore.existingSaves(in: dir)
        #expect(saves.count == 1)
        let winner = try #require(saves.first).url
        #expect(
            Array(winner.lastPathComponent.utf8) == Array("caf\u{e9}.gnusto".utf8))
        #expect(FileManager.default.fileExists(atPath: winner.path))
    }

    // MARK: the per-game folder

    /// A title with a non-ASCII letter names a different folder than it used to.
    /// A player whose saves are in the old one keeps them: the old folder stays
    /// the live one until a new one exists.
    @Test func aNonASCIITitleKeepsUsingTheFolderItsSavesAreAlreadyIn() throws {
        let root = tempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let old = root.appendingPathComponent("Caf-Noir", isDirectory: true)
        try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)

        #expect(
            SaveStore.savesDirectory(forGameTitled: "Café Noir", under: root).lastPathComponent
                == "Caf-Noir")

        // Once the new folder exists it wins, so a game that has never run under
        // the old rule never sees the old name.
        let new = root.appendingPathComponent("Caf\u{e9}-Noir", isDirectory: true)
        try FileManager.default.createDirectory(at: new, withIntermediateDirectories: true)
        #expect(
            SaveStore.savesDirectory(forGameTitled: "Café Noir", under: root).lastPathComponent
                == "Caf\u{e9}-Noir")
    }

    /// An ASCII title names what it always named, with no `stat` deciding it.
    @Test func anASCIITitleNamesTheSameFolderItAlwaysDid() {
        let root = tempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        for title in ["Zork I: The Great Underground Empire", "The Kindly Deep", "Dungeon"] {
            #expect(
                SaveStore.savesDirectory(forGameTitled: title, under: root).lastPathComponent
                    == FilesystemName.component(title))
        }
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
