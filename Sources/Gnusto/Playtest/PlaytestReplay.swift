import Foundation

/// A game played once, from the beginning, by nobody — the stateless half of
/// the play-test server.
///
/// **Why this exists as a tool of its own.** The round's verifier is a
/// *different subagent* from the tester that filed the finding
/// (`.claude/workflows/playtest.js` dispatches the two separately), so it holds
/// no session id and a session-scoped tool is useless to it. What it holds is a
/// finding: a command list, a seed, and a claim of the form *"this line printed,
/// at this turn, in this room."* That claim is the single most expensive step of
/// the old verify checklist — *"replay the reproducer yourself and confirm the
/// excerpt appears verbatim in the frame claimed"* — and it is entirely
/// mechanical. So it becomes a call.
///
/// **It is the `REPL`, not a copy of it.** The whole harness rests on a tester's
/// command list *being* a regression test, and the way that stays true is that
/// every driver in this module runs the same loop. This one does not even have a
/// loop: it hands the commands to `ScriptedIOHandler`, runs a real ``REPL``, and
/// reads the transcript back off the handler — the identical arrangement
/// `play(_:_:seed:)` uses, and the identical string a transcript test asserts
/// on. Everything below the run is text: the frame a verdict reports is read
/// back out of the `[status]` footer, which is what the footer is for.
///
/// **It touches nothing.** A fresh `GameWorld` over the shared `PreparedGame`, a
/// throwaway save directory that is deleted on the way out, no session, no
/// registry, no files under `.context/playtest`. Two verifiers replaying two
/// findings at once cannot see each other, and neither can disturb a tester
/// mid-session.
enum PlaytestReplay {
    /// The most commands one replay may run.
    ///
    /// Generous — a full Dungeon walkthrough is a few hundred lines and a
    /// reproducer is usually a few dozen — and present only so that a
    /// mistyped or generated list cannot occupy the server indefinitely. A
    /// replay is answered concurrently, so the ceiling is about the process
    /// rather than about anybody's turn order.
    static let commandLimit = 5_000

    /// Where a claim about a transcript turned out to be true, or what stood
    /// there instead.
    struct Verdict: Sendable {
        /// Whether the excerpt appeared anywhere in the replay.
        let found: Bool

        /// The recorded-line index of the turn that printed it — `1` for the
        /// first command, `0` for the opening. Numbered exactly as a session
        /// numbers its lines, so a verdict and a `recall` agree.
        let turn: Int

        /// The room the `[status]` footer named for that turn.
        let room: String

        /// The move counter after it.
        let moves: Int

        /// The line the tester would have typed to reach it, or `nil` for the
        /// opening.
        let command: String?

        /// The whole turn as the transcript recorded it, footer included —
        /// the frame, so a verifier can see what else was true at the moment
        /// the line printed rather than only that it printed.
        let context: String
    }

    /// One replay's result.
    struct Outcome: Sendable {
        /// The whole transcript, footers and all.
        let transcript: String
        /// How many lines were fed.
        let lines: Int
        /// Whether the game ended before the list ran out.
        let finished: Bool
        /// The verdict, when the caller asked one.
        let verdict: Verdict?
    }

    /// Plays a command list into a fresh world and reports what happened.
    ///
    /// - Parameters:
    ///   - prepared: the game, booted once by the server.
    ///   - commands: the lines to type, in order. Empty is legal and replays
    ///     just the opening, which is a claim somebody may want checked.
    ///   - seed: the seed to pin. A finding names one; 0 is
    ///     `bin/playtest-replay`'s default and a session's.
    ///   - expect: an excerpt to look for, or `nil` to read the transcript.
    /// - Throws: ``PlaytestError`` for a list that is too long or that holds a
    ///   `script`/`unscript` line — neither of which runs anything.
    /// - Returns: the transcript, and the verdict when one was asked for.
    static func run(
        prepared: PreparedGame, commands: [String], seed: UInt64, expect: String?
    ) async throws -> Outcome {
        guard commands.count <= commandLimit else {
            throw PlaytestError(
                """
                replay was given \(commands.count) commands and runs at most \
                \(commandLimit). Nothing ran. A reproducer that long is not a reproducer; \
                cut it to the prefix that reaches the line you are checking.
                """)
        }
        for (offset, line) in commands.enumerated()
        where TesterInput.transcriptCommand(line) != nil {
            throw PlaytestError(
                """
                Command \(offset + 1), `\(line)`, is a transcript command, and a replay \
                refuses those — nothing ran. It would start a second recording in the \
                game's own transcripts directory, outside this harness entirely. Drop the \
                line: replay hands you the transcript already.
                """)
        }

        // A throwaway save directory, deleted on the way out. A replayed
        // reproducer may well type `save`, and a replay that wrote into the
        // per-title default would reach across into a tester's slots — or into
        // the developer's — for a run nobody kept.
        let saves = FileManager.default.temporaryDirectory
            .appendingPathComponent("gnusto-replay-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: saves) }

        let world = GameWorld(prepared: prepared, seed: seed, saveDirectory: saves)
        let io = ScriptedIOHandler(lines: commands)
        await REPL(world: world, io: io, status: StatusFooter.always).run()
        let transcript = io.transcript

        let blocks = Self.blocks(in: transcript)
        return Outcome(
            transcript: transcript,
            lines: commands.count,
            finished: await world.hasEnded(),
            verdict: expect.map { Self.verdict(on: $0, in: blocks) })
    }

    // MARK: - Reading the transcript back

    /// One recorded line and everything it printed.
    private struct Block {
        /// The line's 1-based index, `0` for the opening.
        let index: Int
        /// The line as it was typed, or `nil` for the opening.
        let command: String?
        /// The block exactly as the transcript holds it.
        let text: String
        /// The room the footer named.
        let room: String
        /// The move counter the footer named.
        let moves: Int
    }

    /// Splits a transcript into its turns.
    ///
    /// The format is `TranscriptRecorder`'s and is read the way it is written:
    /// a line beginning `"> "` is an echoed input and starts a new block;
    /// everything before the first one is the opening. Nothing here is a
    /// second definition of the format — it is the only reader of it, and it
    /// exists because a verdict has to name a turn.
    ///
    /// - Parameter transcript: the whole recorded text.
    /// - Returns: the blocks, oldest first, the opening included.
    private static func blocks(in transcript: String) -> [Block] {
        var blocks: [Block] = []
        var command: String?
        var current = ""
        var index = 0

        func close() {
            guard !current.isEmpty || command != nil else { return }
            let footer = frame(in: current)
            blocks.append(
                Block(
                    index: index, command: command, text: current,
                    room: footer.room, moves: footer.moves))
        }

        for line in transcript.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("> ") {
                close()
                index = blocks.count  // the opening was block 0, so this is 1-based
                command = String(line.dropFirst(2))
                current = "\(line)\n"
                continue
            }
            current += "\(line)\n"
        }
        close()
        return blocks
    }

    /// The room and the move counter a block's `[status]` footer named.
    ///
    /// The last footer in the block, because a block holds exactly one and
    /// reading the last is right either way. A block with none — which a
    /// comment is, since a comment prints nothing — inherits nothing and
    /// answers empty; the caller reports the frame of the turn that printed the
    /// line, and a comment never printed one.
    ///
    /// - Parameter text: the block.
    /// - Returns: the room name and the move counter.
    private static func frame(in text: String) -> (room: String, moves: Int) {
        var room = ""
        var moves = 0
        for line in text.split(separator: "\n") where line.hasPrefix("[status] ") {
            room = ""
            moves = 0
            for field in line.dropFirst("[status] ".count).components(separatedBy: " | ") {
                guard let split = field.firstIndex(of: "=") else { continue }
                let name = String(field[field.startIndex..<split])
                let value = String(field[field.index(after: split)...])
                if name == "room" { room = value }
                if name == "moves" { moves = Int(value) ?? 0 }
            }
        }
        return (room, moves)
    }

    /// Looks for an excerpt and reports the frame it printed in.
    ///
    /// Matched on whitespace-collapsed text, and with the footers taken out of
    /// the haystack first. Both are about the same thing: an excerpt is lifted
    /// out of a *finding*, where it has been re-wrapped by whatever wrote the
    /// report, and it is lifted from prose the suite sees without a `[status]`
    /// line in it. Requiring the bytes to line up would refuse true claims for
    /// reasons that have nothing to do with the game.
    ///
    /// - Parameters:
    ///   - expect: the excerpt claimed.
    ///   - blocks: the replay's turns.
    /// - Returns: where it was found, or the last frame and a `false`.
    private static func verdict(on expect: String, in blocks: [Block]) -> Verdict {
        let needle = squeezed(expect)
        if !needle.isEmpty {
            for block in blocks where squeezed(prose(in: block.text)).contains(needle) {
                return Verdict(
                    found: true, turn: block.index, room: block.room, moves: block.moves,
                    command: block.command, context: block.text)
            }
        }
        let last = blocks.last
        return Verdict(
            found: false,
            turn: last?.index ?? 0,
            room: last?.room ?? "",
            moves: last?.moves ?? 0,
            command: last?.command,
            context: last?.text ?? "")
    }

    /// A block without its status footers — the game talking, and nothing the
    /// harness added.
    private static func prose(in text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.hasPrefix("[status] ") }
            .joined(separator: "\n")
    }

    /// Every run of whitespace as one space, so a re-wrapped excerpt still
    /// matches the line it was lifted from.
    private static func squeezed(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
