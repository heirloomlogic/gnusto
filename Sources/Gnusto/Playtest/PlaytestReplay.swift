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
/// **It disturbs nothing, and it leaves evidence.** A fresh `GameWorld` over the
/// shared `PreparedGame`, a throwaway save directory that is deleted on the way
/// out, no session and no registry entry: two verifiers replaying two findings
/// at once cannot see each other, and neither can reach a tester mid-session.
///
/// What it does write is its own probe directory — `commands.txt` and
/// `transcript.txt` under `.context/playtest/.replays/probe-NNN/`, exactly the
/// two files a session writes and in exactly the same layout. That is a
/// correction rather than an original design. For its first rounds a replay
/// wrote nothing at all, on the argument that a verifier's tool should be pure;
/// the 2026-08-17 round then filed three charters whose load-bearing frames came
/// from free replays, and one whole ending branch that the report asserts and
/// that appears in **no file in the tree**. A finding nobody can re-read is not
/// evidence, and `references/report-shape.md`'s cite-the-probe rule exists
/// precisely to stop that. Purity was the wrong thing to buy.
///
/// The write is best effort and never fails a replay: the verdict is the answer,
/// the file is the receipt.
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
        /// Where this replay's `transcript.txt` was written, for a finding to
        /// cite. `nil` when no directory was offered or the write failed.
        let probe: URL?

        /// The save slots copied in before the game booted, or `nil` for the
        /// ordinary clean start. See ``PlaytestSessions/StagedSlots``.
        let staged: PlaytestSessions.StagedSlots?

        /// Whether this replay typed `restore` with nothing staged to restore
        /// from — the harness answer, not a game answer. See
        /// ``restoreWasUnreachable(_:staged:)``.
        let restoreWasUnreachable: Bool
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
    ///   - probe: a fresh directory to leave `commands.txt` and `transcript.txt`
    ///     in, or `nil` to run without leaving a receipt. The server always
    ///     passes one; the suite passes `nil` where the files are not the
    ///     subject.
    ///   - savesFrom: a directory of `.gnusto` slots this replay may read — a
    ///     label's `saves/`, or a probe's `saves-in/` — or `nil` for a clean
    ///     start. Copied in, never written back — see
    ///     ``PlaytestSessions/stageSlots(from:into:)``.
    /// - Throws: ``PlaytestError`` for a list that is too long, for one that
    ///   holds a `script`/`unscript` line — neither of which runs anything —
    ///   or for a `savesFrom` directory holding no slots.
    /// - Returns: the transcript, the verdict when one was asked for, where
    ///   the evidence went, and what was staged to get there.
    static func run(
        prepared: PreparedGame, commands: [String], seed: UInt64, expect: String?,
        probe: URL? = nil, savesFrom: URL? = nil
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

        // `savesFrom` copies a label's slots *in*, and that is the whole of it:
        // the only directory this world is ever told about is still the
        // throwaway above, so the paragraph before this one stays literally
        // true while a reproducer beginning `restore` finally finds its slot.
        let staged = try savesFrom.map { try PlaytestSessions.stageSlots(from: $0, into: saves) }

        let world = GameWorld(prepared: prepared, seed: seed, saveDirectory: saves)
        let io = ScriptedIOHandler(lines: commands)
        await REPL(world: world, io: io, status: StatusFooter.always).run()
        let transcript = io.transcript

        let blocks = Self.blocks(in: transcript)
        return Outcome(
            transcript: transcript,
            lines: commands.count,
            finished: await world.hasEnded(),
            verdict: expect.map { Self.verdict(on: $0, in: blocks) },
            probe: probe.flatMap {
                Self.write(commands, transcript, seed: seed, staged: staged, to: $0)
            },
            staged: staged,
            restoreWasUnreachable: Self.restoreWasUnreachable(commands, staged: staged))
    }

    /// Whether a replay typed `restore` before it could have written anything to
    /// restore, with no slots staged in — which is the one failure in this tree
    /// that is a fact about the harness and never about the game.
    ///
    /// **Read off the command list, not off the transcript.** The refusal is
    /// ``GameText/restoreFailed``, which any game may re-skin, so matching its
    /// words would answer for the stock voice and quietly stop answering for a
    /// game that changed it. What the harness actually knows is the pair this
    /// reads: a `restore` was asked for, and the directory it asked of was
    /// empty by construction.
    ///
    /// A `save` earlier in the list closes it: that replay wrote its own slot in
    /// the throwaway and its `restore` is reaching a real file. The first of the
    /// two verbs wins, so a list that saves and then restores is clean and one
    /// that restores and then saves is not.
    ///
    /// - Parameters:
    ///   - commands: the lines fed, in order.
    ///   - staged: what was copied in first, or `nil` for a clean start.
    /// - Returns: true when a `restore` in this list had nothing to find.
    private static func restoreWasUnreachable(
        _ commands: [String], staged: PlaytestSessions.StagedSlots?
    ) -> Bool {
        guard staged == nil else { return false }
        for line in commands where !TesterInput.isComment(line) {
            switch line.trimmingCharacters(in: .whitespaces)
                .split(separator: " ", omittingEmptySubsequences: true)
                .first?.lowercased()
            {
            case "save": return false
            case "restore": return true
            default: continue
            }
        }
        return false
    }

    /// Writes a replay's two files, and reports where.
    ///
    /// The two evidence files go or neither does. `commands.txt` replaying to
    /// `transcript.txt` is the invariant this whole harness sells, and a
    /// directory holding a transcript whose command list failed to write is
    /// worse than no evidence, because it looks like evidence.
    ///
    /// **The seed goes in a third file, not into `commands.txt`.** That is
    /// `bin/playtest-replay`'s `summary.txt`, matched deliberately: a probe
    /// directory a finding cites should say which seed produced it without the
    /// reader reconstructing that from the round report. It cannot be a comment
    /// at the head of the command list, tempting as that is —
    /// `ScriptedIOHandler` echoes *every* line it is fed as `> line`, comments
    /// included, so such a list would neither reproduce the transcript beside it
    /// nor keep the turn numbering a verdict reports. `summary.txt` is written
    /// last and is not part of the guarantee; losing it costs a label, not the
    /// evidence.
    ///
    /// - Parameters:
    ///   - commands: the lines fed, in order.
    ///   - transcript: what they printed.
    ///   - seed: the seed that produced it.
    ///   - staged: the save slots copied in first, and where from, or `nil`
    ///     for a clean start.
    ///   - directory: the probe directory, already made.
    /// - Returns: the directory when both files landed, `nil` otherwise.
    private static func write(
        _ commands: [String], _ transcript: String, seed: UInt64,
        staged: PlaytestSessions.StagedSlots?, to directory: URL
    ) -> URL? {
        let transcriptURL = directory.appendingPathComponent("transcript.txt")
        let commandsURL = directory.appendingPathComponent("commands.txt")
        guard
            (try? Data(commands.map { "\($0)\n" }.joined().utf8).write(
                to: commandsURL, options: .atomic)) != nil,
            (try? Data(transcript.utf8).write(to: transcriptURL, options: .atomic)) != nil
        else { return nil }

        // A staged probe keeps the bytes it was staged with, beside the
        // transcript, under the name `bin/playtest-replay` uses — labels get
        // cleaned between rounds and probe directories are the durable
        // evidence, so a probe that recorded only the label's *path* would stop
        // reproducing the moment that label went. Best effort like the summary
        // below: losing it costs the guarantee, not the verdict.
        if let staged {
            // The same copy `stageSlots` made into the throwaway, made again
            // into the probe. `try?` rather than `try` is the whole difference:
            // a non-empty source is already proven, so the throw cannot fire,
            // and losing the receipt must not lose the verdict.
            _ = try? PlaytestSessions.stageSlots(
                from: staged.from,
                into: directory.appendingPathComponent("saves-in", isDirectory: true))
        }

        // A fourth line only when there was one, so an ordinary probe's summary
        // is byte-identical to what it has always been — and a staged one says
        // in the receipt that its command list alone will not reproduce it. The
        // key matches the CLI's trailer so one grep reads every probe in a tree.
        let provenance =
            staged.map {
                "[playtest] saves-from=\($0.label) slots=\($0.restorable.count) "
                    + "copy=\(directory.appendingPathComponent("saves-in").path)\n"
            } ?? ""
        let summary = """
            [playtest] replay seed=\(seed) commands=\(commands.count)
            [playtest] transcript=\(transcriptURL.path)
            [playtest] commands=\(commandsURL.path)
            \(provenance)
            """
        try? Data(summary.utf8).write(
            to: directory.appendingPathComponent("summary.txt"), options: .atomic)
        return directory
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
