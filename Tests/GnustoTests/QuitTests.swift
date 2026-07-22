import Foundation
import GnustoTestSupport
import Synchronization
import Testing

@testable import Gnusto

/// A scripted handler that also records what `finish` receives, so tests can
/// assert the REPL's end-of-session hand-off.
private final class FinishRecordingIOHandler: IOHandler {
    private let inner: ScriptedIOHandler
    private let finished = Mutex<String?>(nil)

    init(inputs: [Input]) {
        inner = ScriptedIOHandler(inputs: inputs)
    }

    func write(_ text: String) { inner.write(text) }
    func readLine(prompt: String) -> Input? { inner.readLine(prompt: prompt) }
    func finish(_ finalText: String) { finished.withLock { $0 = finalText } }

    /// What `finish` was called with, or `nil` if it never was.
    var finishedWith: String? { finished.withLock { $0 } }
}

/// `GameWorld.requestQuit()` and the REPL wiring that routes a front-end Ctrl-C
/// (`Input.quit`) through it — issue #55. The quit is keyed to `Intent.quit`,
/// not the editable `quit` verb word, and must land even while a save/restore
/// filename prompt is pending (where `perform` would consume the line as the
/// filename answer).
struct QuitTests {
    /// The path a bare save name resolves to under `dir`.
    private func savePath(_ name: String, in dir: URL) -> String {
        dir.appendingPathComponent("\(name).gnusto").path
    }

    // MARK: - GameWorld.requestQuit()

    @Test func requestQuitFromANormalLineEndsTheGameWithTheScoreEpilogue() async throws {
        let world = try GameWorld(game: MorgueGame(), seed: 1)
        _ = await world.begin()

        let result = await world.requestQuit()

        #expect(result.isFinished)
        // The same epilogue a typed `quit` prints.
        #expect(result.output.contains("Your score is"))
    }

    @Test func requestQuitWhileASaveFilenamePromptIsPendingStillQuits() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gnusto-quit-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let world = try GameWorld(game: MorgueGame(), seed: 1, saveDirectory: dir)
        _ = await world.begin()

        // Arm the save prompt: the next line would be read as the filename.
        let prompt = await world.perform("save")
        #expect(!prompt.isFinished)

        // The bug: Ctrl-C here was consumed as the filename, so it didn't quit.
        let result = await world.requestQuit()

        #expect(result.isFinished)
        // The quit was not written as a save named "quit".
        #expect(!FileManager.default.fileExists(atPath: savePath("quit", in: dir)))
    }

    @Test func requestQuitWhileARestoreFilenamePromptIsPendingStillQuits() async throws {
        let world = try GameWorld(game: MorgueGame(), seed: 1)
        _ = await world.begin()

        let prompt = await world.perform("restore")
        #expect(!prompt.isFinished)

        let result = await world.requestQuit()
        #expect(result.isFinished)
    }

    @Test func requestQuitFromTheDeathPromptEndsTheGame() async throws {
        let world = try GameWorld(game: MorgueGame(), seed: 1)
        _ = await world.begin()

        // Dying arms the death prompt; the game isn't finished yet.
        let death = await world.perform("take poison")
        #expect(!death.isFinished)

        let result = await world.requestQuit()
        #expect(result.isFinished)
    }

    // MARK: - REPL wiring

    @Test func replHandsTheEndingTextToTheFrontEndOnQuit() async throws {
        let world = try GameWorld(game: MorgueGame(), seed: 1)
        let io = FinishRecordingIOHandler(inputs: [.quit])
        await REPL(world: world, io: io).run()

        // The front end got the epilogue, so a full-screen handler can keep
        // it visible after teardown.
        #expect(io.finishedWith?.contains("Your score is") == true)
    }

    @Test func replSkipsTheEndingHandOffOnBareEndOfInput() async throws {
        let world = try GameWorld(game: MorgueGame(), seed: 1)
        // Input runs out without the game reaching an ending.
        let io = FinishRecordingIOHandler(inputs: [.line("look")])
        await REPL(world: world, io: io).run()

        #expect(io.finishedWith == nil)
    }

    @Test func replRoutesAQuitSignalThroughRequestQuitEvenAtASavePrompt() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gnusto-quit-repl-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let world = try GameWorld(game: MorgueGame(), seed: 1, saveDirectory: dir)
        // `save` arms the filename prompt; the front-end quit (`.quit`) must end
        // the game there — so the trailing `look` never runs.
        let io = ScriptedIOHandler(inputs: [.line("save"), .quit, .line("look")])
        await REPL(world: world, io: io).run()

        #expect(!io.transcript.contains("> look"))
        // The quit wasn't swallowed as the save filename.
        #expect(!FileManager.default.fileExists(atPath: savePath("quit", in: dir)))
    }
}
