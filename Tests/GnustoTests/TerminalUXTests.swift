import Foundation
import Testing

@testable import Gnusto

/// Tab-completion, persistent command history, and the completion candidates
/// the engine hands the terminal front end (issue #47). The raw-mode key
/// handling and the Ctrl-C confirm are verified by running the app, not here;
/// this covers the pure logic and the engine seam.
struct TerminalUXTests {
    // MARK: - complete(): the pure completion engine

    /// A candidate set roughly like MiniGame's opening: a handful of verbs, the
    /// den's in-scope words, the compass directions, and two save slots.
    private let candidates = CompletionCandidates(
        verbs: ["drop", "examine", "look", "restore", "save", "take"],
        nouns: ["book", "coin", "gold", "hat", "oak", "table", "tome"],
        directions: ["down", "east", "n", "north", "northeast", "northwest", "s", "south", "up"])

    /// A filename-prompt snapshot: the whole line completes against save names.
    private let filenameCandidates = CompletionCandidates(
        context: .filename,
        saveNames: ["autumn", "spring", "summer", "winter"])

    @Test func firstWordCompletesAgainstAVerbUniquely() {
        let out = TerminalIOHandler.complete(
            input: "exa", cursor: 3, candidates: candidates)
        #expect(out.newInput == "examine ")  // unique → trailing space
        #expect(out.newCursor == 8)
        #expect(out.listing.isEmpty)
    }

    @Test func firstWordCompletesAgainstADirection() {
        let out = TerminalIOHandler.complete(
            input: "ea", cursor: 2, candidates: candidates)
        #expect(out.newInput == "east ")
        #expect(out.newCursor == 5)
    }

    @Test func ambiguousPrefixExtendsToLongestCommonPrefix() {
        // "no" matches north / northeast / northwest — all sharing "north", so
        // the word extends to that common prefix with no trailing space.
        let out = TerminalIOHandler.complete(
            input: "no", cursor: 2, candidates: candidates)
        #expect(out.newInput == "north")  // extended, no trailing space
        #expect(out.newCursor == 5)
        #expect(out.listing.isEmpty)
    }

    @Test func ambiguousWithNoCommonExtensionListsCandidates() {
        // "s" matches the verb "save" and directions "s"/"south": the common
        // prefix is just "s" (no progress), so the candidates are listed.
        let out = TerminalIOHandler.complete(
            input: "s", cursor: 1, candidates: candidates)
        #expect(out.newInput == "s")  // unchanged
        #expect(out.listing == ["s", "save", "south"])
    }

    @Test func filenamePromptCompletesAgainstSaveNamesUniquely() {
        // At a save/restore filename prompt the whole line is the name.
        let out = TerminalIOHandler.complete(
            input: "au", cursor: 2, candidates: filenameCandidates)
        #expect(out.newInput == "autumn ")
        #expect(out.newCursor == 7)
    }

    @Test func filenamePromptListsAmbiguousSaveNames() {
        // "s" matches spring and summer, common prefix "s" (no progress).
        let out = TerminalIOHandler.complete(
            input: "s", cursor: 1, candidates: filenameCandidates)
        #expect(out.newInput == "s")
        #expect(out.listing == ["spring", "summer"])
    }

    @Test func filenamePromptIgnoresVerbsAndNouns() {
        // No save slot starts with "b"; verbs/nouns are out of pool at a
        // filename prompt, so nothing changes.
        let out = TerminalIOHandler.complete(
            input: "b", cursor: 1, candidates: filenameCandidates)
        #expect(out.newInput == "b")
        #expect(out.listing.isEmpty)
    }

    @Test func laterWordCompletesAgainstInScopeNouns() {
        let out = TerminalIOHandler.complete(
            input: "take boo", cursor: 8, candidates: candidates)
        #expect(out.newInput == "take book ")
        #expect(out.newCursor == 10)
    }

    @Test func laterWordCompletesAdjectives() {
        let out = TerminalIOHandler.complete(
            input: "examine gol", cursor: 11, candidates: candidates)
        #expect(out.newInput == "examine gold ")
    }

    @Test func cursorInTheMiddlePreservesTheSuffix() {
        // Caret after "boo", suffix " on table" is kept intact.
        let input = "take boo on table"
        let out = TerminalIOHandler.complete(
            input: input, cursor: 8, candidates: candidates)
        #expect(out.newInput == "take book  on table")
        #expect(out.newCursor == 10)  // just past "book "
    }

    @Test func completionIsCaseInsensitiveAndCanonicalizes() {
        let out = TerminalIOHandler.complete(
            input: "TAK", cursor: 3, candidates: candidates)
        #expect(out.newInput == "take ")  // canonical lowercase form
    }

    @Test func noMatchLeavesTheLineUntouched() {
        let out = TerminalIOHandler.complete(
            input: "xyz", cursor: 3, candidates: candidates)
        #expect(out.newInput == "xyz")
        #expect(out.newCursor == 3)
        #expect(out.listing.isEmpty)
    }

    @Test func emptyPartialIsANoOp() {
        // Caret sits on a space: there's no word to complete.
        let out = TerminalIOHandler.complete(
            input: "take ", cursor: 5, candidates: candidates)
        #expect(out.newInput == "take ")
        #expect(out.listing.isEmpty)
    }

    @Test func emptyPoolIsANoOp() {
        let out = TerminalIOHandler.complete(
            input: "sav xy", cursor: 6, candidates: CompletionCandidates())
        #expect(out.newInput == "sav xy")
        #expect(out.listing.isEmpty)
    }

    // MARK: - Persistent history

    /// A fresh, empty temp directory for one test.
    private func tempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gnusto-termux-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test func appendThenLoadRoundTripsInOrder() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent(".history")
        for line in ["look", "take book", "go north"] {
            TerminalIOHandler.appendHistory(line, to: url)
        }
        #expect(TerminalIOHandler.loadHistory(from: url) == ["look", "take book", "go north"])
    }

    @Test func appendCreatesMissingParentDirectory() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        // A nested, not-yet-created saves directory.
        let url = dir.appendingPathComponent("Saves/Mini/.history")
        TerminalIOHandler.appendHistory("inventory", to: url)
        #expect(TerminalIOHandler.loadHistory(from: url) == ["inventory"])
    }

    @Test func appendSkipsBlankLines() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent(".history")
        TerminalIOHandler.appendHistory("look", to: url)
        TerminalIOHandler.appendHistory("   ", to: url)  // ignored
        TerminalIOHandler.appendHistory("", to: url)  // ignored
        TerminalIOHandler.appendHistory("wait", to: url)
        #expect(TerminalIOHandler.loadHistory(from: url) == ["look", "wait"])
    }

    @Test func loadCapsToTheMostRecentLimit() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent(".history")
        for i in 1...10 {
            TerminalIOHandler.appendHistory("cmd\(i)", to: url)
        }
        let loaded = TerminalIOHandler.loadHistory(from: url, limit: 3)
        #expect(loaded == ["cmd8", "cmd9", "cmd10"])  // newest kept
    }

    @Test func loadingAMissingFileIsEmpty() {
        let url = tempDir().appendingPathComponent("does-not-exist.history")
        #expect(TerminalIOHandler.loadHistory(from: url).isEmpty)
    }

    @Test func historyFileAndDirectoryAreOwnerOnly() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        // A not-yet-created saves subdirectory, so appendHistory provisions it.
        let subdir = dir.appendingPathComponent("Saves/Mini", isDirectory: true)
        let url = subdir.appendingPathComponent(".history")
        TerminalIOHandler.appendHistory("look", to: url)
        let dirPerms =
            try FileManager.default.attributesOfItem(atPath: subdir.path)[.posixPermissions]
            as? Int
        let filePerms =
            try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int
        #expect(dirPerms == 0o700)
        #expect(filePerms == 0o600)
    }

    @Test func trimRewritesAnOvergrownFileToTheLimit() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent(".history")
        for i in 1...50 {
            TerminalIOHandler.appendHistory("cmd\(i)", to: url)
        }
        TerminalIOHandler.trimHistory(at: url, limit: 10)
        // The file itself now holds only the most recent 10, in order.
        let loaded = TerminalIOHandler.loadHistory(from: url, limit: 1000)
        #expect(loaded == (41...50).map { "cmd\($0)" })
    }

    @Test func loadReadsOnlyTheTailOfAHugeFileWithNoPartialFirstLine() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent(".history")
        // Build a file well past the 256 KiB byte cap (~400 KB), then a few
        // recognizable most-recent lines.
        let filler = String(repeating: "x", count: 200)
        var big = ""
        for i in 0..<2000 {
            big += "\(filler)-\(i)\n"
        }
        big += "recent-a\nrecent-b\nrecent-c\n"
        try big.write(to: url, atomically: true, encoding: .utf8)

        let loaded = TerminalIOHandler.loadHistory(from: url, limit: 1000)
        // The newest lines survive intact...
        #expect(Array(loaded.suffix(3)) == ["recent-a", "recent-b", "recent-c"])
        // ...only the tail loaded (not all 2003 lines)...
        #expect(loaded.count < 2000)
        // ...and the seek's partial first line was dropped: the first kept line
        // is a *complete* filler line (all 200 leading x's present).
        #expect(loaded.first?.hasPrefix(filler) == true)
    }

    // MARK: - GameWorld.completionCandidates()

    @Test func candidatesIncludeStandardVerbsAndDirections() async throws {
        let world = try GameWorld(game: MiniGame(), saveDirectory: tempDir())
        _ = await world.begin()
        let c = await world.completionCandidates()
        #expect(c.verbs.contains("take"))
        #expect(c.verbs.contains("look"))
        #expect(c.directions.contains("north"))
        #expect(c.directions.contains("n"))
    }

    @Test func candidateNounsReflectInScopeItems() async throws {
        let world = try GameWorld(game: MiniGame(), saveDirectory: tempDir())
        _ = await world.begin()
        let c = await world.completionCandidates()
        // The den shows the book (and its synonym/adjectives), the held hat,
        // the table, and the coin on it.
        #expect(c.nouns.contains("book"))
        #expect(c.nouns.contains("tome"))  // synonym
        #expect(c.nouns.contains("old"))  // adjective
        #expect(c.nouns.contains("hat"))
        #expect(c.nouns.contains("coin"))
        #expect(c.nouns.contains("table"))
    }

    @Test func candidateNounsFollowThePlayersScope() async throws {
        let world = try GameWorld(game: MiniGame(), saveDirectory: tempDir())
        _ = await world.begin()
        _ = await world.perform("east")  // den → study, leaving the den's items
        let c = await world.completionCandidates()
        #expect(!c.nouns.contains("book"))  // the book stayed in the den
        #expect(c.nouns.contains("hat"))  // but the hat is still carried
    }

    @Test func candidateSaveNamesReflectSlotsOnDisk() async throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        // Seed a save slot on disk in the game's directory.
        try Data("x".utf8).write(to: dir.appendingPathComponent("spring.gnusto"))
        let world = try GameWorld(game: MiniGame(), saveDirectory: dir)
        _ = await world.begin()
        let c = await world.completionCandidates()
        #expect(c.saveNames == ["spring"])
        #expect(c.context == .command)  // a fresh turn is a command line
    }

    @Test func contextBecomesFilenameWhileAwaitingASaveName() async throws {
        let world = try GameWorld(game: MiniGame(), saveDirectory: tempDir())
        _ = await world.begin()
        _ = await world.perform("save")  // arms the save-filename prompt
        let c = await world.completionCandidates()
        #expect(c.context == .filename)  // the next line names a save
    }

    @Test func contextBecomesFilenameWhileAwaitingARestoreName() async throws {
        let world = try GameWorld(game: MiniGame(), saveDirectory: tempDir())
        _ = await world.begin()
        _ = await world.perform("restore")  // arms the restore-filename prompt
        let c = await world.completionCandidates()
        #expect(c.context == .filename)
    }
}
