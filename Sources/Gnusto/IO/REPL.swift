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
    /// The `[status]` footer to append to every turn, or `nil` for none. Set by
    /// `GameMain` from `GNUSTO_STATUS`; tests pass it explicitly.
    ///
    /// Defaulting to `nil` is the whole safety argument: `play(_:_:)` builds its
    /// REPL without the argument, so no environment variable can make the suite's
    /// transcripts grow a line. See ``StatusFooter``.
    private let status: StatusFooter?

    /// Creates a REPL driving the given world through the given IO handler.
    ///
    /// - Parameters:
    ///   - world: the world to drive.
    ///   - io: the IO handler for input and output.
    ///   - transcriptURL: a file to record the whole session to from the start,
    ///     or `nil` to begin idle.
    ///   - status: a status footer to append to every turn's output, or `nil`
    ///     for the plain transcript a player and the test suite see.
    public init(
        world: GameWorld, io: any IOHandler, transcriptURL: URL? = nil,
        status: StatusFooter? = nil
    ) {
        self.world = world
        self.io = io
        self.transcriptURL = transcriptURL
        self.status = status
    }

    /// Runs the prompt/parse/perform/print loop until the game ends.
    public func run() async {
        // Armed up front only when a transcript file was requested at launch;
        // `script`/`unscript` swap it in and out during play.
        var recorder = transcriptURL.flatMap { try? TranscriptRecorder(url: $0) }

        var result = await world.begin()
        // The opening is not a turn, so it is `turn=free` — truthfully, since
        // the move counter stands at zero after it.
        var output = await annotated(result, turnCost: false)
        io.write("\(output)\n\n")
        recorder?.record(openingOutput: output)
        io.showStatus(result.status)
        io.updateCompletions(await world.completionCandidates())

        while !result.isFinished, let input = io.readLine(prompt: "> ") {
            // Read before the turn runs: `turn=cost|free` is the move counter's
            // delta across it, which is the engine's own definition of whether
            // world time passed — not a guess from the intent or the reply. The
            // one exception is the meta path, where the counter the line
            // started from and the counter it ended on need not belong to the
            // same world; ``StatusFooter/turnCost(_:audit:movesBefore:)`` holds
            // that rule for both drivers, which is why the audited `perform` is
            // the one called here. (#350)
            let movesBefore = result.status.moves
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
                let audited = await world.performAudited(line)
                result = audited.result
                output = await annotated(
                    result,
                    turnCost: StatusFooter.turnCost(
                        result, audit: audited.audit, movesBefore: movesBefore))
                recorder?.record(command: line, output: output)
            case .quit:
                // QUIT is meta and the world's clock never notices it, so there
                // is no delta to consult and no parse to audit.
                result = await world.requestQuit()
                output = await annotated(result, turnCost: false)
                recorder?.record(command: "quit", output: output)
            }
            io.write("\(output)\n\n")
            io.showStatus(result.status)
            io.updateCompletions(await world.completionCandidates())
        }

        recorder?.close()

        // A reached ending (won/lost/quit) gets a final hand-off so a
        // full-screen front end can keep its last words visible; a bare
        // end-of-input (EOF) just stops. The game's ending text, not the
        // annotated line: `finish` is the fiction's last words held up for the
        // player, and the footer is scaffolding for whoever reads the
        // transcript afterwards.
        if result.isFinished {
            io.finish(result.output)
        }
    }

    /// A turn's output with the status footer appended, or the output verbatim
    /// when no footer was asked for.
    ///
    /// Called once per turn and its result used for **both** `io.write` and
    /// `recorder?.record` — never computed twice, and never appended to one and
    /// not the other. `bin/playtest-replay` and `docs/playtesting.md` both claim
    /// a recorded transcript is byte-for-byte the string the test suite asserts
    /// on; a footer on one channel only would make that false again, on every
    /// turn rather than on the one empty one it was last false for.
    ///
    /// The join itself lives on ``StatusFooter/annotate(_:turnCost:fields:)``,
    /// because the play-test session driver has to produce the identical bytes
    /// and a second copy of the empty-turn rule would be a second thing to keep
    /// in step.
    ///
    /// - Parameters:
    ///   - result: the turn that just ran.
    ///   - turnCost: whether the move counter advanced across it.
    /// - Returns: the text to print and to record.
    private func annotated(_ result: TurnResult, turnCost: Bool) async -> String {
        guard let status else { return result.output }
        return status.annotate(
            result, turnCost: turnCost, fields: await world.statusFields())
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
            io.write("[Recording transcript to \(shellEscaped(started.path))]\n\n")
            return started
        case .stop:
            guard let recorder else {
                io.write("[No transcript is being recorded.]\n\n")
                return nil
            }
            recorder.close()
            io.write("[Transcript recording ended: \(shellEscaped(recorder.path))]\n\n")
            return nil
        }
    }

    /// Backslash-escapes spaces so the announced path can be pasted into a
    /// shell as-is.
    private func shellEscaped(_ path: String) -> String {
        path.replacingOccurrences(of: " ", with: "\\ ")
    }
}
