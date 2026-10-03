import Foundation
import GnustoTestSupport
import Testing

@testable import Gnusto

/// Core REPL completion policy and scope snapshots for presentation clients.
struct CompletionCandidatesTests {
    /// A fresh, empty temp directory for one test.
    private func tempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gnusto-termux-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - The REPL only computes candidates for a handler that wants them

    @Test func replSkipsTheCandidateWalkForAHandlerThatDoesNotWantIt() async throws {
        // The default: a console or scripted handler has no line editor, so
        // the scope walk and the save-directory read are never paid.
        let world = try GameWorld(game: MiniGame(), saveDirectory: tempDir())
        let io = RecordingIOHandler(inputs: [.line("look"), .line("east")])
        await REPL(world: world, io: io).run()
        #expect(io.completionPushes == 0)
    }

    @Test func replPushesCandidatesAfterTheOpeningAndEveryTurnToAHandlerThatWantsThem() async throws {
        let world = try GameWorld(game: MiniGame(), saveDirectory: tempDir())
        let io = RecordingIOHandler(inputs: [.line("look"), .line("east")], wantsCompletions: true)
        await REPL(world: world, io: io).run()
        // Once after the opening, once after each of the two turns.
        #expect(io.completionPushes == 3)
    }

    @Test func scriptedHandlerDoesNotWantCompletions() {
        // The default any handler inherits; `TerminalIOHandler` overrides it,
        // but constructing one takes over the terminal, so that half is read.
        #expect(!ScriptedIOHandler(inputs: []).wantsCompletions)
    }

    // MARK: - GameWorld.completionCandidates()

    @Test func candidatesIncludeStandardVerbsAndDirections() async throws {
        let world = try cachedWorld(MiniGame(), saveDirectory: tempDir())
        _ = await world.begin()
        let c = await world.completionCandidates()
        #expect(c.verbs.contains("take"))
        #expect(c.verbs.contains("look"))
        #expect(c.directions.contains("north"))
        #expect(c.directions.contains("n"))
    }

    @Test func candidateNounsReflectInScopeItems() async throws {
        let world = try cachedWorld(MiniGame(), saveDirectory: tempDir())
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
        let world = try cachedWorld(MiniGame(), saveDirectory: tempDir())
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
        let world = try cachedWorld(MiniGame(), saveDirectory: dir)
        _ = await world.begin()
        let c = await world.completionCandidates()
        #expect(c.saveNames == ["spring"])
        #expect(c.context == .command)  // a fresh turn is a command line
    }

    @Test func contextBecomesFilenameWhileAwaitingASaveName() async throws {
        let world = try cachedWorld(MiniGame(), saveDirectory: tempDir())
        _ = await world.begin()
        _ = await world.perform("save")  // arms the save-filename prompt
        let c = await world.completionCandidates()
        #expect(c.context == .filename)  // the next line names a save
    }

    @Test func contextBecomesFilenameWhileAwaitingARestoreName() async throws {
        let world = try cachedWorld(MiniGame(), saveDirectory: tempDir())
        _ = await world.begin()
        _ = await world.perform("restore")  // arms the restore-filename prompt
        let c = await world.completionCandidates()
        #expect(c.context == .filename)
    }
}
