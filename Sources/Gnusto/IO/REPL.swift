import Foundation

/// The outer loop: prompt → parse → perform → print, until the game ends or
/// input runs out. Holds the only `await` in a Gnusto game.
///
/// Two tester conveniences are filtered here, before the parser: a line that is
/// a play-test comment (`//`/`#`) is ignored and re-prompted "as if nothing
/// happened," and `script`/`unscript` toggle recording the session to a file.
/// Both are front-end concerns — they never reach `GameWorld.perform`, so the
/// world simulation stays unaware of them and no fuse or daemon can advance.
public struct REPL: Sendable {
    private let world: GameWorld
    private let io: any IOHandler
    /// A transcript file to record from the first turn, or `nil` to start idle
    /// (the tester can still begin recording with `script`). Set by `GameMain`
    /// from `GNUSTO_TRANSCRIPT`; tests pass it explicitly.
    private let transcriptURL: URL?

    /// Creates a REPL driving the given world through the given IO handler.
    ///
    /// - Parameters:
    ///   - world: the world to drive.
    ///   - io: the IO handler for input and output.
    ///   - transcriptURL: a file to record the whole session to from the start,
    ///     or `nil` to begin idle.
    public init(world: GameWorld, io: any IOHandler, transcriptURL: URL? = nil) {
        self.world = world
        self.io = io
        self.transcriptURL = transcriptURL
    }

    /// Runs the prompt/parse/perform/print loop until the game ends.
    public func run() async {
        // Armed up front only when a transcript file was requested at launch;
        // `script`/`unscript` swap it in and out during play.
        var recorder = transcriptURL.flatMap { try? TranscriptRecorder(url: $0) }

        var result = await world.begin()
        io.write("\(result.output)\n\n")
        recorder?.record(openingOutput: result.output)
        io.showStatus(result.status)
        io.updateCompletions(await world.completionCandidates())

        while !result.isFinished, let input = io.readLine(prompt: "> ") {
            switch input {
            case .line(let line):
                // A comment or a transcript toggle is handled here and re-prompts
                // without running a turn; the game clock never moves.
                if TesterInput.isComment(line) {
                    recorder?.record(commentLine: line)
                    continue
                }
                if let command = TesterInput.transcriptCommand(line) {
                    recorder = toggleTranscript(command, recorder: recorder)
                    continue
                }
                result = await world.perform(line)
                recorder?.record(command: line, output: result.output)
            case .quit:
                result = await world.requestQuit()
                recorder?.record(command: "quit", output: result.output)
            }
            io.write("\(result.output)\n\n")
            io.showStatus(result.status)
            io.updateCompletions(await world.completionCandidates())
        }

        recorder?.close()

        // A reached ending (won/lost/quit) gets a final hand-off so a
        // full-screen front end can keep its last words visible; a bare
        // end-of-input (EOF) just stops.
        if result.isFinished {
            io.finish(result.output)
        }
    }

    /// Starts or stops transcript recording in response to `script`/`unscript`,
    /// reporting the outcome to the player, and returns the recorder now in
    /// force (a fresh one, or `nil` once stopped or on failure).
    private func toggleTranscript(
        _ command: TranscriptCommand, recorder: TranscriptRecorder?
    ) -> TranscriptRecorder? {
        switch command {
        case .start(let name):
            recorder?.close()  // a second `script` replaces the active recording
            let url = TranscriptStore.url(forName: name, gameTitled: world.definition.title)
            guard let started = try? TranscriptRecorder(url: url) else {
                io.write("[Couldn't start transcript recording.]\n\n")
                return nil
            }
            io.write("[Recording transcript to \(started.path)]\n\n")
            return started
        case .stop:
            guard let recorder else {
                io.write("[No transcript is being recorded.]\n\n")
                return nil
            }
            recorder.close()
            io.write("[Transcript recording ended: \(recorder.path)]\n\n")
            return nil
        }
    }
}
