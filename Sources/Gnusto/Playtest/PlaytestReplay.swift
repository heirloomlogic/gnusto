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

        /// The save slots copied in before the game booted, and where from —
        /// or `nil` for the ordinary clean start.
        ///
        /// **A staged replay is weaker evidence than an unstaged one**, and the
        /// receipt has to say which it was. Every other probe in this tree
        /// replays from `commands.txt` and a seed alone; one that begins
        /// `restore` reproduces only while that label still holds the slot it
        /// named. That is worth having — four findings in the 2026-08-25
        /// Dungeon round were recorded `not-reproducible` for want of it — but
        /// it is not the same claim, so it is not reported as the same claim.
        ///
        /// One optional rather than a pair, because ``stage(_:into:)`` refuses
        /// an empty source: there is no such thing as a staging that copied
        /// nothing, and two fields would let a later edit invent one.
        let staged: (from: URL, slots: [String])?
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
    ///   - savesFrom: a label's `saves/` directory whose slots this replay may
    ///     read, or `nil` for a clean start. Copied in, never written back —
    ///     see ``stage(_:into:)``.
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
        let staged = try savesFrom.map { (from: $0, slots: try Self.stage($0, into: saves)) }

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
            staged: staged)
    }

    /// Copies a label's saved games into this replay's throwaway directory.
    ///
    /// **One way, by construction.** The destination is the temp directory the
    /// caller is about to hand the world and then delete, so a `save` inside the
    /// replay lands there and can never reach back into the label. Nothing in
    /// this function writes to `source`.
    ///
    /// Only `*.gnusto` — the extension ``SaveStore/existingSaveNames(in:)``
    /// filters on, so the game's own restore prompt lists exactly what was
    /// staged and nothing else. The `.history` sidecar stays behind: it is a
    /// tester's typing, and a replay is driven by `ScriptedIOHandler`, which
    /// reads no history.
    ///
    /// Safe against a live session. ``SaveFile`` writes atomically, so a
    /// concurrent `save` is a rename and this copy sees the whole of the old
    /// file or the whole of the new one.
    ///
    /// - Parameters:
    ///   - source: a label's `saves/` directory.
    ///   - destination: the throwaway, which may not exist yet.
    /// - Throws: ``PlaytestError`` when the source holds no slots.
    /// - Returns: the slot names copied, sorted.
    private static func stage(_ source: URL, into destination: URL) throws -> [String] {
        let slots = SaveStore.existingSaveNames(in: source)
        guard !slots.isEmpty else {
            throw PlaytestError(
                """
                savesFrom names \(source.path), which holds no saved games. Nothing ran. \
                A reproducer whose first command is `restore` needs the slot the tester \
                wrote, and nothing wrote one there — check the label, or judge the \
                finding from a clean-start reproducer instead.
                """)
        }
        // Through the save store both ways, so the extension and the 0700 the
        // throwaway is created with stay in the one file that owns them:
        // `resolveForWrite` *is* the make-the-directory-then-resolve pair, and
        // the names came out of `resolve`'s own sanitizer to begin with.
        for slot in slots {
            try FileManager.default.copyItem(
                at: SaveStore.resolve(slot, in: source),
                to: try SaveStore.resolveForWrite(slot, in: destination))
        }
        return slots
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
        staged: (from: URL, slots: [String])?, to directory: URL
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
            let copies = directory.appendingPathComponent("saves-in", isDirectory: true)
            for slot in staged.slots {
                try? FileManager.default.copyItem(
                    at: SaveStore.resolve(slot, in: staged.from),
                    to: try SaveStore.resolveForWrite(slot, in: copies))
            }
        }

        // A fourth line only when there was one, so an ordinary probe's summary
        // is byte-identical to what it has always been — and a staged one says
        // in the receipt that its command list alone will not reproduce it. The
        // key matches the CLI's trailer so one grep reads every probe in a tree.
        let provenance =
            staged.map {
                "[playtest] saves-from=\($0.from.path) slots=\($0.slots.joined(separator: ","))\n"
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
