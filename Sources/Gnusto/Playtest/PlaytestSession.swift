import Foundation

/// A play-test tool failure, phrased for the agent that has to recover from
/// it.
///
/// Thrown out of a tool handler, which ``MCPServer`` turns into a tool
/// *result* carrying `isError: true` — never a JSON-RPC error, and never a
/// trap. The text is therefore written to be read: it says what was refused
/// and what to do instead, because "invalid argument" costs the caller a whole
/// round trip to guess at.
struct PlaytestError: Error, CustomStringConvertible {
    let description: String

    /// - Parameter description: what went wrong, and what to do about it.
    init(_ description: String) {
        self.description = description
    }
}

/// One play-test session: a game booted at a pinned seed, the lines it has
/// been fed, and the transcript those produced — on disk from the first turn.
///
/// **The hard invariant.** A session's recorded transcript is byte-for-byte
/// what `REPL(world:io:transcriptURL:status:)` writes for the same command
/// list and the same seed. That is not a nicety: the whole harness rests on
/// "a tester's command list *is* a regression test", `docs/playtesting.md` and
/// `bin/playtest-replay` both promise it in those words, and a finding cites a
/// transcript that somebody will later paste into a `play(_:_:seed:)` call.
/// Three things keep the promise, and each is load-bearing:
///
/// - The turn loop below is `REPL.run`'s, statement for statement — `begin()`,
///   the footer computed **once** per turn and handed to both sinks, a
///   comment recorded and skipped with no turn and no clock tick, the loop
///   stopping the moment a turn reports `isFinished`.
/// - The format is `TranscriptRecorder`'s, called rather than reimplemented.
///   A second producer of "the transcript format" would be a second place for
///   it to rot, and the drift would be one byte on a path nobody replays for
///   months. There was exactly such a byte, on empty output; it cost a stage.
/// - The footer join is ``StatusFooter/annotate(_:turnCost:fields:)``, shared
///   with the REPL for the same reason.
///
/// **Durable from turn zero.** The transcript is open before the first move
/// and `commands.txt` is rewritten after every one. This is the mitigation for
/// the one genuine regression this server has against `bin/playtest-replay`: a
/// `fatalError` in any game rule kills the process and every sibling session
/// with it. Recovery is a re-`open` and a replay — which only exists as a
/// recovery if the command list survived the crash. In memory, it would not
/// have.
///
/// **Concurrency.** An actor, and every session in the process holds its own
/// `GameWorld` (also an actor) over a shared `PreparedGame`. Nothing is shared
/// mutably: `Ctx.frame` is a `@TaskLocal` rather than a global, so two
/// sessions running turns at the same time on different tasks cannot see each
/// other's turn frame.
actor PlaytestSession {
    /// One recorded input line and the transcript block it produced.
    ///
    /// `block` is empty for an evicted session and refilled by the replay —
    /// see ``evict()``.
    private struct Turn {
        /// This line's 1-based position in `commands.txt`. The index `recall`
        /// takes, and the one a truncation marker points at.
        let index: Int
        /// The line exactly as the tester sent it.
        let line: String
        /// True for a `//` or `#` comment: recorded, but never performed.
        let isComment: Bool
        /// What the transcript recorded for it.
        var block: String
    }

    /// The most text a `move` or `recall` result may carry, in characters.
    ///
    /// A tool built to make a move cheap must not be able to answer with 40 KB
    /// — the point of the session server is that the next look costs almost
    /// nothing, and a result the agent has to skim is the replay-from-scratch
    /// cost coming back in a different currency. For scale: `survey` against
    /// Cloak of Darkness is already 8,339 bytes, and that is the *small* game.
    /// Over the cap, whole commands are dropped and the marker says which
    /// `recall` reads them back.
    static let resultCharacterCap = 12_000

    /// This session's id, `<label>/<probe>` — which is also where it lives on
    /// disk, so an id in a report is a path a reader can follow.
    nonisolated let id: String

    /// The tester's namespace. One label per tester: probes under a label
    /// share its saves directory, exactly as `bin/playtest-replay` defines it.
    nonisolated let label: String

    /// What this session may be told beyond what the game has printed to it.
    ///
    /// `nonisolated` because it never changes and because the firewall has to
    /// be checkable without awaiting the session — a tool that refused only
    /// after queueing behind a two-hundred-command batch would be a firewall
    /// with a latency. See ``PlaytestRole``.
    nonisolated let role: PlaytestRole

    /// This run's directory name under the label, `probe-001` and up.
    nonisolated let probe: String

    /// The random seed this session replays. Pinned per session, never read
    /// from the environment — see `PlaytestServer.serve`.
    nonisolated let seed: UInt64

    /// `.context/playtest/<label>/<probe>/`.
    nonisolated let directory: URL

    /// `.context/playtest/<label>/saves/`, shared with every other probe under
    /// this label and with nobody else.
    ///
    /// Handed to `GameWorld(prepared:seed:saveDirectory:)` because
    /// `SaveStore.defaultDirectory(forGameTitled:)` is per *title*: left to
    /// itself, every concurrent session in the process would write into one
    /// slot namespace, and the restore prompt would list every tester's saves
    /// back to whoever asked. Saves sit at the label rather than the probe so
    /// that a save made in one probe can be restored in the next, which is the
    /// arrangement `bin/playtest-replay` documents and the reason a label is
    /// described there as one tester's namespace rather than one run's.
    nonisolated let saveDirectory: URL

    /// The recorded transcript.
    nonisolated let transcriptURL: URL

    /// Every line fed to this session, one per line, comments included — a
    /// file `bin/playtest-replay --commands` can replay as-is.
    nonisolated let commandsURL: URL

    /// The game, booted once for the whole process.
    private let prepared: PreparedGame

    /// A session always runs with the footer on: its reader is a machine that
    /// needs to know which room printed a line and whether the last command
    /// cost a turn, and reconstructing either from prose is where a tester's
    /// mistakes come from.
    private let footer = StatusFooter.always

    /// The live world, or `nil` for a session evicted to a stub.
    private var world: GameWorld?

    /// The open transcript file, or `nil` while evicted.
    private var recorder: TranscriptRecorder?

    /// The opening's transcript block, and the same text without its footer.
    private var openingBlock = ""
    private var openingOutput = ""

    /// Every recorded line, in order.
    private var turns: [Turn] = []

    /// The most recent `[status]` line.
    private var statusLine = ""

    /// The move counter as of the last turn — read *before* the next one, the
    /// way `REPL.run` does, because `turn=cost|free` is the counter's delta
    /// and not a guess from the verb.
    private var lastMoves = 0

    /// True once a turn reported `isFinished`. Nothing runs after that.
    private var finished = false

    /// What the world will do with the next line. See ``PlaytestAwaiting``.
    private var pending: PlaytestAwaiting = .none

    /// What the game has shown this session and the session has not followed
    /// up. See ``CoverageLedger``, which is built from the printed text and the
    /// parse record and reads nothing else — the firewall lives there.
    ///
    /// Derived state, so it is thrown away and rebuilt by ``boot()`` rather
    /// than carried across an eviction: the replay is exact, so re-feeding the
    /// same lines rebuilds the same ledger, and a ledger that survived a replay
    /// would double-count every item in it.
    private var ledger = CoverageLedger()

    /// The command count at which the last inline `harness:` note went out.
    ///
    /// One tier of intervention and no more, so the note also has to be rare:
    /// a channel an agent has learned to skip is worse than no channel. See
    /// ``PlaytestSignals``.
    private var lastNudge = 0

    /// True once the session has used the player-facing `save` or `restore`.
    ///
    /// Such a session may never be evicted. Eviction is safe *because* replay
    /// is exact, and replay stops being exact the moment the run depends on a
    /// file outside it: the slot this session saved may have been overwritten
    /// by another probe under the same label, or by the tester, and a replay
    /// would then restore a different world and record a transcript that never
    /// happened.
    private var pinned = false

    /// Opens a session. The caller has already made ``directory`` and
    /// ``saveDirectory``; nothing is booted until the first use.
    ///
    /// - Parameters:
    ///   - id: the session id, `<label>/<probe>`.
    ///   - label: the tester's namespace.
    ///   - probe: this run's directory name.
    ///   - seed: the random seed to pin.
    ///   - role: what this session may be told. See ``PlaytestRole``.
    ///   - prepared: the game, booted once by the server.
    ///   - directory: this probe's directory.
    ///   - saveDirectory: the label's saves directory.
    init(
        id: String,
        label: String,
        probe: String,
        seed: UInt64,
        role: PlaytestRole,
        prepared: PreparedGame,
        directory: URL,
        saveDirectory: URL
    ) {
        self.id = id
        self.label = label
        self.probe = probe
        self.seed = seed
        self.role = role
        self.prepared = prepared
        self.directory = directory
        self.saveDirectory = saveDirectory
        self.transcriptURL = directory.appendingPathComponent("transcript.txt")
        self.commandsURL = directory.appendingPathComponent("commands.txt")
    }

    // MARK: - What a tool asks for

    /// The opening: the game's own first words, and the frame they printed in.
    struct Opening: Sendable {
        /// The intro, banner and first room description, without the footer.
        let text: String
        /// The `[status]` line for the opening, which is turn zero and free.
        let status: String
        /// What the world is waiting for — `none`, unless a game manages to
        /// ask a question before anybody types.
        let awaiting: PlaytestAwaiting
    }

    /// Boots the session if it isn't booted, and reports the opening.
    ///
    /// - Throws: ``PlaytestError`` when the transcript file can't be opened,
    ///   which is fatal to the session: durability is the crash mitigation, so
    ///   a session that cannot record is not a session worth handing back.
    /// - Returns: the opening frame.
    func opening() async throws -> Opening {
        _ = try await liveWorld()
        return Opening(text: openingOutput, status: statusLine, awaiting: pending)
    }

    /// Runs a batch of commands and reports what happened, in the transcript
    /// format the session records.
    ///
    /// Plain text rather than JSON, deliberately: game prose is multi-line and
    /// full of quotation marks, so escaping it into a JSON field both inflates
    /// it and makes it unreadable to the one reader whose entire job is reading
    /// it. What comes back is literally the bytes this batch appended to
    /// `transcript.txt`, plus a `[playtest]` trailer.
    ///
    /// The batch **halts** — leaving the rest of the commands unrun and saying
    /// so — when the game ends, and when a question opens that would eat the
    /// next line as its answer. That last case is what
    /// `bin/playtest-replay`'s `printf 'quit\nquit\n'` epilogue papers over: a
    /// script cannot see an armed prompt, so it sends a spare `quit` and hopes.
    /// A session can see it, so it stops and says which line is now an answer
    /// slot. `allowPrompts` opts back in, for the tester who means to answer a
    /// save prompt or a death prompt inside one batch.
    ///
    /// - Parameters:
    ///   - commands: the lines to feed, in order. A `//` or `#` line is a
    ///     comment: recorded, never performed, no turn and no clock tick.
    ///   - allowPrompts: keep going when a prompt arms mid-batch.
    /// - Throws: ``PlaytestError`` for an empty batch, a `script`/`unscript`
    ///   line, or a session whose game has already ended — none of which run
    ///   anything, so the session is untouched.
    /// - Returns: the transcript of the batch, and the trailer.
    func move(commands: [String], allowPrompts: Bool) async throws -> String {
        guard !commands.isEmpty else {
            throw PlaytestError("move needs at least one command; it was given none.")
        }
        try refuseTranscriptCommands(in: commands)
        // Asked before the world is fetched: `finished` survives an eviction, so
        // a session whose game ended answers without replaying itself first only
        // to be told no.
        guard !finished else {
            throw PlaytestError(
                """
                Session \(id) has finished: the game ended after \(turns.count) lines and \
                nothing more can be played in it. Nothing was run. Open a new session — the \
                command list is at \(commandsURL.path) if you want to replay up to here first.
                """)
        }
        let world = try await liveWorld()

        var blocks: [(index: Int, text: String)] = []
        var ran = 0
        for line in commands {
            let index = turns.count + 1
            let block = await run(line, at: index, in: world)
            turns.append(
                Turn(
                    index: index, line: line,
                    isComment: TesterInput.isComment(line), block: block))
            blocks.append((index, block))
            ran += 1
            if finished { break }
            if pending != .none && !allowPrompts { break }
        }
        persistCommands()

        let unrun = Array(commands.dropFirst(ran))
        return Self.capped(tail: blocks)
            + trailer(ran: ran, requested: commands.count, unrun: unrun)
            + nudge()
    }

    /// Reads back part of the session's own transcript.
    ///
    /// One tool rather than a `tail` and a `grep`, because a tool an agent has
    /// to choose between is a tool it chooses wrong. `grep` filters to the
    /// *turns* whose text matches, each still whole, so the frame around a
    /// match — the command that caused it and the status line under it —
    /// survives the filter.
    ///
    /// - Parameters:
    ///   - from: the first line index to read; `0` includes the opening.
    ///   - to: the last line index to read, inclusive.
    ///   - grep: keep only turns containing this text, case-insensitively.
    /// - Throws: ``PlaytestError`` for a backwards range.
    /// - Returns: the matching transcript blocks, and a trailer.
    func recall(from: Int, to: Int, grep: String?) async throws -> String {
        guard from <= to else {
            throw PlaytestError(
                "recall needs from ≤ to; it was given from=\(from), to=\(to).")
        }
        // Rehydrates an evicted session: the blocks it reads are dropped on
        // eviction and rebuilt by the replay, so the answer is the same either
        // way and the caller never learns which happened.
        _ = try await liveWorld()

        var blocks: [(index: Int, text: String)] = []
        if from <= 0 && !openingBlock.isEmpty {
            blocks.append((0, openingBlock))
        }
        for turn in turns where turn.index >= from && turn.index <= to {
            blocks.append((turn.index, turn.block))
        }
        if let needle = grep?.lowercased(), !needle.isEmpty {
            blocks = blocks.filter { $0.text.lowercased().contains(needle) }
        }
        guard !blocks.isEmpty else {
            let matching = grep.map { " matching \"\($0)\"" } ?? ""
            return """
                [playtest] session=\(id): nothing in lines \(from)–\(to)\(matching). \
                This session has \(turns.count) recorded lines.
                """
        }
        return Self.capped(head: blocks)
            + "[playtest] session=\(id) recalled=\(blocks.count) of \(turns.count) lines\n"
    }

    // MARK: - The queue

    /// What the game has shown this session that the session has not followed
    /// up, ranked cheapest-first.
    struct Coverage: Sendable {
        /// How many items are open. The decreasing integer the queue is read
        /// by, and deliberately the first field: a report is something an agent
        /// reads once and rationalises, a countdown is something it burns down.
        let open: Int
        /// How many have been closed.
        let closed: Int
        /// The room the status line last named, so the caller can see why the
        /// ranking put what it did on top.
        let room: String
        /// The ranked items.
        let items: [CoverageItem]
        /// The one frontier hint, when the queue has run dry.
        let hint: String?
        /// The inline `harness:` note, when a threshold has tripped.
        let note: String?
    }

    /// The queue.
    ///
    /// **Reads nothing but the ledger**, which in turn reads nothing but the
    /// printed text and the parse record. That is the firewall, and it is worth
    /// stating at the one method a tester calls most: there is no branch here
    /// on `prepared.definition`, no room roster, no timer roster, no
    /// vocabulary. A room this session never stood in cannot be named by
    /// anything it gets back.
    ///
    /// - Parameter limit: how many items to return.
    /// - Throws: ``PlaytestError`` when a session that had been evicted cannot
    ///   reopen its transcript to replay itself.
    /// - Returns: the open count and the top of the queue.
    func coverage(limit: Int) async throws -> Coverage {
        _ = try await liveWorld()
        return Coverage(
            open: ledger.openCount,
            closed: ledger.items.count - ledger.openCount,
            room: ledger.currentRoom,
            items: ledger.queue(limit: limit),
            hint: ledger.frontierHint(),
            note: ledger.signals().note)
    }

    /// The measured signals. See ``PlaytestSignals``.
    ///
    /// - Returns: the numbers, off this session's own record.
    func stats() -> PlaytestSignals {
        ledger.signals()
    }

    // MARK: - Notes

    /// Writes a `//` comment into the transcript at the current turn.
    ///
    /// The point is *where* it lands. A tester that reads a wrong line and
    /// files it forty turns later into a schema field is reconstructing the
    /// frame from memory; one that writes a note the moment it reads the line
    /// puts the observation in the evidence, next to the line, at the turn
    /// that printed it. It costs no turn and no clock tick, because it goes
    /// down the front-end comment path (``TesterInput/isComment``) and never
    /// reaches the parser — so a note between two commands cannot change what
    /// the second one does.
    ///
    /// A `suspicious` note also raises a ``CoverageItem/Kind/hunch``: a
    /// suspicion the tester formed is an obligation to look again from a
    /// different frame, rather than a feeling it may walk away from. The marker
    /// goes in the comment text rather than beside it, so that a replay of
    /// `commands.txt` rebuilds the hunch along with everything else.
    ///
    /// - Parameters:
    ///   - text: what to write. Newlines are squeezed out — a comment is one
    ///     transcript line by construction, and a second line would not carry
    ///     the `>` echo the format is read by.
    ///   - suspicious: file it as a hunch as well as a note.
    /// - Throws: ``PlaytestError`` for empty text, or a transcript that can't
    ///   be opened.
    /// - Returns: the line as it was written, and the frame it went in at.
    func note(_ text: String, suspicious: Bool) async throws -> String {
        let line = Self.commentLine(text, suspicious: suspicious)
        guard line.count > 3 else {
            throw PlaytestError("note needs something to say; it was given \"\(text)\".")
        }
        let world = try await liveWorld()
        let index = turns.count + 1
        let block = await run(line, at: index, in: world)
        turns.append(Turn(index: index, line: line, isComment: true, block: block))
        persistCommands()
        return """
            \(block)[playtest] session=\(id) noted at line \(index), \
            room=\(ledger.currentRoom), moves=\(lastMoves) — no turn passed.
            """
    }

    /// A note as one transcript line, marker and all.
    ///
    /// - Parameters:
    ///   - text: the tester's words.
    ///   - suspicious: whether to mark it as a hunch.
    /// - Returns: a line ``TesterInput/isComment(_:)`` accepts.
    private static func commentLine(_ text: String, suspicious: Bool) -> String {
        var body = text.split(whereSeparator: \.isNewline)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        while body.hasPrefix("//") || body.hasPrefix("#") {
            body = String(body.dropFirst(body.hasPrefix("//") ? 2 : 1))
                .trimmingCharacters(in: .whitespaces)
        }
        return suspicious ? "// [suspicious] \(body)" : "// \(body)"
    }

    // MARK: - Stopping

    /// What a tester is told when it says it is done.
    struct Closing: Sendable {
        /// Always true. `finish` reports; it does not refuse.
        let accepted = true
        /// How many items were still open.
        let open: Int
        /// A sample of them, cheapest first.
        let items: [CoverageItem]
        /// The measured signals.
        let signals: PlaytestSignals
        /// The frontier hint, when the queue had run dry.
        let hint: String?
        /// Where the evidence is.
        let transcript: String
        /// The prose the agent reads.
        let message: String
    }

    /// Accepts a tester's decision to stop, and tells it what it is leaving.
    ///
    /// **It reports; it does not refuse.** That is a reversal, and the reason
    /// is measurement rather than taste: two agents played the bare session
    /// surface with no queue and no enforcement at all, and both volunteered
    /// honest gap lists better than a deferral form would have extracted —
    /// where the machinery to compel them would have invited the failure this
    /// harness is being rebuilt to escape, an agent burning a checklist down
    /// mechanically instead of reading. So there is no minimum word count on
    /// the reason, no cap on how much may be left, and no escalation.
    ///
    /// What survives is the accounting. The open list at `finish` **is** the
    /// round's coverage gap, itemised, and it goes into the report whether or
    /// not the tester explains it — an unexplained gap is still a gap, shown
    /// blank.
    ///
    /// The summary and the reason are written into the transcript as comments,
    /// so the record of why a session stopped sits in the evidence rather than
    /// in a tool result nobody kept.
    ///
    /// - Parameters:
    ///   - summary: what the tester found, in its own words.
    ///   - leaving: why it is stopping with items open, or `nil`.
    ///   - limit: how many open items to name back.
    /// - Throws: ``PlaytestError`` for an empty summary, or a transcript that
    ///   can't be opened.
    /// - Returns: the accounting.
    func finish(summary: String, leaving: String?, limit: Int) async throws -> Closing {
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PlaytestError(
                "finish needs a summary — one or two sentences on what you found.")
        }
        _ = try await note("[finish] \(trimmed)", suspicious: false)
        if let leaving, !leaving.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            _ = try await note("[leaving] \(leaving)", suspicious: false)
        }

        let items = ledger.queue(limit: limit)
        let open = ledger.openCount
        var message =
            open == 0
            ? "Noted. Nothing was left open when you stopped."
            : """
            Noted. Still open when you stopped: \(open) \
            item\(open == 1 ? "" : "s")\(items.isEmpty ? "." : ", e.g.")
            """
        for item in items {
            message += "\n  \(item.rendered)"
        }
        if let hint = ledger.frontierHint() {
            message += "\n\(hint)"
        }
        if leaving == nil && open > 0 {
            message += """

                Say why in `leaving`, or call move again — either is fine. An unexplained \
                gap is still counted as a gap.
                """
        }
        return Closing(
            open: open,
            items: items,
            signals: ledger.signals(),
            hint: ledger.frontierHint(),
            transcript: transcriptURL.path,
            message: message)
    }

    /// The inline `harness:` line, at most one per twenty commands.
    ///
    /// Appended to a `move` result and to nothing else — never recorded, so a
    /// nudge cannot reach the transcript and cost this harness its byte
    /// identity with the REPL.
    ///
    /// - Returns: the line to append, or the empty string.
    private func nudge() -> String {
        guard let note = ledger.signals().note, ledger.commands >= lastNudge + 20 else {
            return ""
        }
        lastNudge = ledger.commands
        return "[playtest] \(note)\n"
    }

    // MARK: - Eviction and rehydration

    /// Whether this session may not be evicted, because it used `save` or
    /// `restore` and replay is no longer exact for it.
    func isPinned() -> Bool {
        pinned
    }

    /// Whether the world is currently in memory. For the registry's bookkeeping
    /// and for the suite, which has to be able to *observe* an eviction rather
    /// than infer it from the absence of an error.
    func isLive() -> Bool {
        world != nil
    }

    /// Drops the world and the rendered transcript, keeping the command list,
    /// the seed and the files.
    ///
    /// The agent never learns this happened: the next call replays the command
    /// list at the same seed, which by construction produces the same world and
    /// the same bytes, and answers as if the session had been in memory all
    /// along. A "session expired" error would be a fact about the server's
    /// memory budget dressed up as a fact about the game, and there is nothing
    /// the caller could usefully do with it.
    ///
    /// The rendered blocks go too, not just the world: they are the larger half
    /// of a long session's footprint, and the replay rebuilds them along with
    /// everything else, so keeping them would be paying for the thing eviction
    /// is for.
    ///
    /// - Returns: whether the session now holds no world — false only when it
    ///   is pinned and was left alone. A session that had not booted yet
    ///   answers true, because the registry's question is "are you costing me
    ///   a world?" and the answer is no either way.
    func evict() -> Bool {
        guard !pinned else { return false }
        guard world != nil else { return true }
        recorder?.close()
        recorder = nil
        world = nil
        openingBlock = ""
        for index in turns.indices {
            turns[index].block = ""
        }
        return true
    }

    /// The live world, replaying the whole session first when it was evicted.
    ///
    /// - Throws: ``PlaytestError`` when the transcript can't be opened.
    /// - Returns: the world, booted and caught up.
    private func liveWorld() async throws -> GameWorld {
        if let world { return world }
        let world = try await boot()
        guard !turns.isEmpty else { return world }
        writeToStandardError(
            """
            [gnusto-mcp] rehydrating session \(id): replaying \(turns.count) \
            recorded lines at seed \(seed).
            """)
        for index in turns.indices {
            guard !finished else { break }
            turns[index].block = await run(turns[index].line, at: index + 1, in: world)
        }
        return world
    }

    /// Boots a fresh world at this session's seed and records the opening.
    ///
    /// The transcript file is truncated here, so a rehydration rewrites it from
    /// the beginning rather than appending. That is the same argument as
    /// everywhere else in this file: the replay is exact, so the bytes written
    /// the second time are the bytes that were there, and one write path is
    /// cheaper to trust than an append path that has to be sure where it left
    /// off. A crash *during* a rehydration leaves a short transcript beside a
    /// complete `commands.txt`, which is the recoverable direction.
    ///
    /// - Throws: ``PlaytestError`` when the transcript can't be opened.
    /// - Returns: the fresh world.
    private func boot() async throws -> GameWorld {
        recorder?.close()
        do {
            recorder = try TranscriptRecorder(url: transcriptURL)
        } catch {
            throw PlaytestError(
                """
                Couldn't open the transcript at \(transcriptURL.path): \(error). A session \
                records from turn zero so that a crash in any game rule — which takes down \
                every session in this process — leaves the evidence behind, so one that \
                cannot record is not opened at all.
                """)
        }
        ledger = CoverageLedger()
        lastNudge = 0
        let world = GameWorld(prepared: prepared, seed: seed, saveDirectory: saveDirectory)
        let result = await world.begin()
        let fields = await world.statusFields()
        // The opening is not a turn, so it is `turn=free` — truthfully: the
        // move counter stands at zero after it.
        let annotated = footer.annotate(result, turnCost: false, fields: fields)
        recorder?.record(openingOutput: annotated)
        openingBlock = TranscriptRecorder.text(openingOutput: annotated)
        // Rendered, not raw. `<br>` is the engine's hard-break marker, and
        // `TextWrap.plain` exists so it never reaches a reader literally — the
        // transcript on disk gets that treatment from `TranscriptRecorder`, and
        // this field, which is the same words handed back over JSON, has to get
        // it too. A play-tester that read `Dungeon<br>The Great Underground
        // Empire` in the one place it looked first would file the marker as a
        // defect, which is a false positive the harness manufactured about
        // itself.
        openingOutput = TextWrap.plain(result.output)
        // The ledger reads the rendered text for the same reason the `opening`
        // field does: `<br>` is a marker, not a word, and a queue item named
        // after one would be an obligation to examine punctuation.
        ledger.observeOpening(output: openingOutput, room: result.status.locationName)
        statusLine = footer.line(result.status, turnCost: false, fields: fields)
        lastMoves = result.status.moves
        finished = result.isFinished
        pending = await world.awaiting()
        self.world = world
        return world
    }

    // MARK: - One line

    /// Feeds one line to the world and records what it printed.
    ///
    /// This is `REPL.run`'s loop body with the IO handler taken out, and it is
    /// meant to be read next to it. The two departures are both absences: there
    /// is no `script`/`unscript` branch (the batch refuses those before it
    /// starts) and no front-end `.quit` input (nobody presses Ctrl-C at an MCP
    /// server).
    ///
    /// - Parameters:
    ///   - line: the raw line, as the tester sent it.
    ///   - index: the line's 1-based position in `commands.txt`, which is what
    ///     a queue item cites when it says where it was shown something.
    ///   - world: the live world.
    /// - Returns: the transcript block the line produced.
    private func run(_ line: String, at index: Int, in world: GameWorld) async -> String {
        // A comment never reaches the parser, so it costs no turn and no clock
        // tick — and it stays in the transcript, which is the point of writing
        // one.
        if TesterInput.isComment(line) {
            recorder?.record(commentLine: line)
            ledger.observeComment(
                line, room: ledger.currentRoom, moves: lastMoves, line: index)
            return TranscriptRecorder.text(commentLine: line)
        }

        // Read before the turn runs: `turn=cost|free` is the move counter's
        // delta across it, which is the engine's own definition of whether
        // world time passed.
        let movesBefore = lastMoves
        let (result, audit) = await world.performAudited(line)
        let fields = await world.statusFields()
        let turnCost = result.status.moves > movesBefore
        let annotated = footer.annotate(result, turnCost: turnCost, fields: fields)
        recorder?.record(command: line, output: annotated)

        ledger.observe(
            command: line,
            audit: audit,
            output: TextWrap.plain(result.output),
            room: result.status.locationName,
            moves: result.status.moves,
            line: index,
            turnCost: turnCost)

        statusLine = footer.line(result.status, turnCost: turnCost, fields: fields)
        lastMoves = result.status.moves
        finished = result.isFinished
        pending = await world.awaiting()
        // Both halves matter. The intent catches `save`/`restore` typed as
        // commands; the pending prompt catches a restore reached from the death
        // prompt, where the player typed "restore" as an answer and no verb was
        // ever parsed.
        if audit.intent == .save || audit.intent == .restore
            || pending == .saveFilename || pending == .restoreFilename
        {
            pinned = true
        }
        return TranscriptRecorder.text(command: line, output: annotated)
    }

    /// Refuses `script` and `unscript` before anything runs.
    ///
    /// A session has been recording since it opened, so a second recorder
    /// pointed at the same session is a trap: the two files interleave
    /// differently, each is missing what the other has, and the one a finding
    /// cites is whichever the tester happened to open. Refusing is a tool
    /// error rather than a silent skip, because a silently-dropped line would
    /// shift every subsequent index in `commands.txt` away from what the
    /// tester sent.
    ///
    /// Checked over the whole batch first, so a refusal runs nothing at all
    /// rather than leaving a half-executed batch behind a failed call.
    ///
    /// - Parameter commands: the batch about to run.
    /// - Throws: ``PlaytestError`` naming the offending line and its position.
    private func refuseTranscriptCommands(in commands: [String]) throws {
        for (offset, line) in commands.enumerated()
        where TesterInput.transcriptCommand(line) != nil {
            throw PlaytestError(
                """
                Command \(offset + 1), `\(line)`, is a transcript command, and a session \
                refuses those — nothing in this batch ran. This session has been recording \
                since it opened, to \(transcriptURL.path); a second recorder over the same \
                session would split the evidence in two and leave neither file complete. \
                Drop the line and use `recall` to read the transcript back.
                """)
        }
    }

    // MARK: - Durability

    /// Rewrites `commands.txt` from the recorded lines.
    ///
    /// Called after every `move`, which is the whole crash mitigation: a
    /// `fatalError` in a game rule takes down the process and every session in
    /// it, and what makes that recoverable rather than fatal to a round is that
    /// the command list survives and replays deterministically. A list held
    /// only in memory would not be a mitigation at all.
    ///
    /// Rewritten atomically rather than appended. The file is small, the write
    /// is one syscall, and the result can never be a half-written last line —
    /// which is exactly the line a crash would be about.
    private func persistCommands() {
        let text = turns.map(\.line).joined(separator: "\n")
        try? Data("\(text)\n".utf8).write(to: commandsURL, options: .atomic)
    }

    // MARK: - The trailer, and the cap

    /// The `[playtest]` lines that close a `move` result: the frame, and — when
    /// the batch stopped early — what stopped it and what didn't run.
    ///
    /// - Parameters:
    ///   - ran: how many of the batch's lines were fed.
    ///   - requested: how many were sent.
    ///   - unrun: the ones that weren't.
    /// - Returns: the trailer, newline-terminated.
    private func trailer(ran: Int, requested: Int, unrun: [String]) -> String {
        var lines = [
            """
            [playtest] session=\(id) ran=\(ran)/\(requested) line=\(turns.count) \
            moves=\(lastMoves) awaiting=\(pending.rawValue) finished=\(finished)
            """
        ]
        if finished || pending != .none {
            let cause = finished ? "the game has ended" : pending.explanation
            let last = turns.last.map { "`\($0.line)`" } ?? "the opening"
            var sentence = "[playtest] stopped after \(last): \(cause)."
            if !unrun.isEmpty {
                let listed = unrun.prefix(8).map { "`\($0)`" }.joined(separator: ", ")
                let more = unrun.count > 8 ? ", …" : ""
                sentence += """
                     \(unrun.count) command\(unrun.count == 1 ? "" : "s") did not run: \
                    \(listed)\(more).
                    """
                if !finished {
                    sentence += """
                         Send them again after answering, or call move with \
                        allowPrompts=true to answer inside one batch.
                        """
                }
            }
            lines.append(sentence)
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Joins blocks, dropping whole commands from the **front** until the
    /// result fits ``resultCharacterCap``.
    ///
    /// The tail is what a `move` reader wants: the newest turns are the ones
    /// the next command depends on. The marker names the exact `recall` range
    /// that reads back what went, so nothing is lost — only deferred to a call
    /// the agent makes when it wants it.
    ///
    /// - Parameter blocks: the batch's blocks, oldest first.
    /// - Returns: the text, with a marker when anything was dropped.
    private static func capped(tail blocks: [(index: Int, text: String)]) -> String {
        var total = blocks.reduce(0) { $0 + $1.text.count }
        var start = 0
        while start + 1 < blocks.count && total > resultCharacterCap {
            total -= blocks[start].text.count
            start += 1
        }
        let kept = blocks[start...].map(\.text).joined()
        guard start > 0 else { return clipped(kept) }
        let dropped = blocks[..<start]
        let first = dropped.first?.index ?? 0
        let last = dropped.last?.index ?? 0
        return """
            [truncated \(dropped.count) commands — use recall(from: \(first), to: \(last))]


            """ + clipped(kept)
    }

    /// Joins blocks, dropping whole commands from the **end** until the result
    /// fits ``resultCharacterCap``.
    ///
    /// The head, for `recall`, because a caller who asked for lines 1–90 and
    /// got 1–40 advances `from` and asks again; one who got 51–90 has to work
    /// out what it missed.
    ///
    /// - Parameter blocks: the requested blocks, oldest first.
    /// - Returns: the text, with a marker when anything was dropped.
    private static func capped(head blocks: [(index: Int, text: String)]) -> String {
        var total = 0
        var end = 0
        while end < blocks.count && (end == 0 || total + blocks[end].text.count <= resultCharacterCap) {
            total += blocks[end].text.count
            end += 1
        }
        let kept = blocks[..<end].map(\.text).joined()
        guard end < blocks.count else { return clipped(kept) }
        let dropped = blocks[end...]
        let next = dropped.first?.index ?? 0
        return clipped(kept) + """
            [truncated \(dropped.count) commands — call recall again with from: \(next)]


            """
    }

    /// The last resort: one turn whose own output exceeds the cap.
    ///
    /// Dropping whole commands cannot help there, and the alternative to
    /// clipping is a tool that can still return 40 KB whenever a game prints a
    /// wall of text. The tail is kept for the same reason as above, and the
    /// marker is explicit so nobody reads a clipped block as the game's whole
    /// answer.
    ///
    /// - Parameter text: the assembled text.
    /// - Returns: it, or its last ``resultCharacterCap`` characters with a note.
    private static func clipped(_ text: String) -> String {
        guard text.count > resultCharacterCap else { return text }
        let cut = text.count - resultCharacterCap
        return "[truncated \(cut) characters of one turn's output]\n\n"
            + String(text.suffix(resultCharacterCap))
    }
}
