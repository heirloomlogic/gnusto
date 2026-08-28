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

    /// How many turns of world state a session keeps behind it, for `rewind`.
    ///
    /// A ring, so the memory is bounded rather than growing with the session: a
    /// `WorldState` is a struct of dictionaries and each snapshot is a distinct
    /// copy of the ones the turn touched, so an unbounded history of a long
    /// Dungeon session would be the largest thing in the process by a wide
    /// margin. Thirty-two is chosen against what a rewind is *for* — undoing a
    /// handful of turns that went somewhere uninteresting — and a request to go
    /// further is answered by a named checkpoint, which costs nothing because it
    /// is an index rather than a state.
    static let snapshotRing = 32

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

    /// Which way this session was told to go at an irreversible action.
    ///
    /// `nonisolated` for the same reason as ``role``: the `open` result quotes
    /// it back, and a tester has to be told its policy in the same breath it is
    /// given its first queue. See ``DivergencePolicy``.
    nonisolated let divergence: DivergencePolicy

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

    /// The same transcript with the `[status]` footers taken out, written by
    /// ``export()``.
    ///
    /// It exists because of what happens to an excerpt after a round: a finding
    /// quotes a line, somebody lifts the quote into a regression test as an
    /// `expectInOrder` needle, and the suite's `play(_:_:seed:)` never prints a
    /// `[status]` line. An excerpt that carried one would fail against a green
    /// suite, and the failure would look like the game's fault. So a session
    /// hands back both files and the names say which is which: `transcript.txt`
    /// is what this session recorded, footers and all, and this is the one a
    /// test may be written from.
    nonisolated let transcriptWithoutStatusURL: URL

    /// A plain-language account of the session, written by ``export()`` — how
    /// far it got, what it measured, and whether the byte-identity check passed.
    nonisolated let summaryURL: URL

    /// The closing record, written by ``finish(summary:leaving:limit:)`` — the
    /// rooms walked, the words the parser refused, the forks met and the items
    /// left open, as JSON.
    ///
    /// A round reads these instead of interviewing its testers. Its absence
    /// beside a `transcript.txt` means the session never called `finish`, and
    /// the round says so rather than quietly leaving the row out.
    nonisolated let closingURL: URL

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
    private var ledger: CoverageLedger

    /// The command count at which the last inline `harness:` note went out.
    ///
    /// One tier of intervention and no more, so the note also has to be rare:
    /// a channel an agent has learned to skip is worse than no channel. See
    /// ``PlaytestSignals``.
    private var lastNudge = 0

    /// One recorded line's worth of "everything it would take to stand here
    /// again", for ``rewind(turns:)`` and ``restore(checkpoint:)``.
    ///
    /// Two halves, and both are needed. The `WorldState` is the game; the
    /// ledger, the counters and the pending question are the *session* reading
    /// it, and a rewind that put the world back and left the queue where it was
    /// would re-offer every item the discarded turns closed and hide every one
    /// they raised. The ledger is a value type, so this is a copy and not a
    /// handle.
    ///
    /// Not routed through `SaveStore`/`SaveFile`, deliberately: that path is a
    /// two-turn prompt interaction, it touches disk, and it is itself something
    /// a play-test session has to be able to exercise. A checkpoint that went
    /// through it would be testing the thing it is supposed to stand outside of,
    /// and the tester's own `save` and `restore` would stop being probeable.
    private struct Snapshot {
        /// How many lines had been recorded when this was taken. `0` is the
        /// opening.
        let line: Int
        let state: WorldState
        let ledger: CoverageLedger
        let statusLine: String
        let lastMoves: Int
        let finished: Bool
        /// What was armed at the time. A snapshot taken with a question open is
        /// not usable — `GameWorld.restore(_:)` closes questions on purpose —
        /// so the rewind falls back to a replay for that line. See
        /// ``truncate(to:naming:)``.
        let pending: PlaytestAwaiting
        let lastNudge: Int
    }

    /// The last ``snapshotRing`` turns, oldest first.
    private var ring: [Snapshot] = []

    /// A place the tester asked to be able to come back to.
    ///
    /// **An index, not a state.** A checkpoint is "the command list was this
    /// long here", which is worth stating because the alternative is worse in
    /// three ways: it costs nothing to keep, so an agent may take as many as it
    /// likes; it survives an eviction, where a held `WorldState` would be
    /// dropped and a later `restore` would have to fail; and coming back to it
    /// is a truncation of `commands.txt`, which is what keeps a finding reached
    /// after a restore reproducible — the reproducer is the whole list from line
    /// one, and there is exactly one list.
    private struct Checkpoint {
        let line: Int
        let room: String
        let moves: Int
    }

    private var checkpoints: [String: Checkpoint] = [:]

    /// How many branches have been written off, for the file names.
    private var branches = 0

    /// Every room this session has ever stood in, in first-seen order,
    /// **including rooms it only reached inside a branch a rewind wrote off**.
    ///
    /// The ledger's own `roomsVisited` is rewound with everything else, because
    /// the signals computed beside it — dwell, breadth — are ratios over the
    /// canonical transcript and would be nonsense against a room count the
    /// commands count no longer matches. That is right for a signal and wrong
    /// for coverage: a tester who worked a room for ten turns and then rewound
    /// out of it has read that room's prose, and a round that reports the room
    /// as never entered under-counts in the direction that flatters it. This is
    /// the coverage answer, kept here rather than in the ledger precisely
    /// because ``truncate(to:naming:)`` must not be able to roll it back.
    ///
    /// A replayed prefix re-walks rooms already held, so both ways back from a
    /// rewind — the ring and the replay — leave this list unchanged.
    ///
    /// **Keyed by the room's `EntityID`, and carrying the display name beside
    /// it**, for the reason ``Closing/roomsVisited`` gives: a display name is
    /// prose, two rooms may share one, and this list is the numerator of a
    /// fraction whose denominator is a roster of declared rooms.
    private var roomsEverVisited: [Closing.VisitedRoom] = []

    /// Every room this session ever did something in, in first-worked order,
    /// and on the same terms as ``roomsEverVisited``: appended from `run`,
    /// which a rewind cannot reach, so a room worked for ten turns and then
    /// rewound out of stays worked.
    ///
    /// ``Closing/roomsWorked`` states what "worked" means and what it cannot
    /// see. It is the stricter half of a pair, and the pair is the point — a
    /// round that reports only the entered count reports a prefix's mileage as
    /// its own coverage.
    private var roomsWorkedEver: [EntityID] = []

    /// The room the *next* line will be typed in.
    ///
    /// The status line a turn ends on says where the player finished, which is
    /// the wrong room to credit the work to whenever the turn moved them: the
    /// balloon is launched from the room the balloon leaves. So the room is
    /// carried forward from the previous status reading, which is the one that
    /// was on screen when the tester chose the command.
    private var standingIn: EntityID?

    /// Every timer that has ever fired in this session, by name, and how many
    /// times — **including fires inside a branch a rewind wrote off**.
    ///
    /// `GameWorld.firedTimers` is the oracle and this is the session's copy of
    /// it, kept for the one reason ``roomsEverVisited`` is kept: a rewind that
    /// goes back through a replay boots a fresh world, and a fresh world's tally
    /// starts at nothing. Losing a fire that way would let the round say "this
    /// timer never fired" about a timer that did, which is the one direction of
    /// error the whole closing record exists to rule out. Folded in
    /// ``remember(line:in:)``, which is the one place a rewind cannot reach.
    ///
    /// **Membership is exact; the counts are a floor.** A name absent here fired
    /// no body in this session. A name present fired at least that many times —
    /// merged with `max` rather than summed, because a replayed prefix re-fires
    /// the timers the discarded tally already counted and adding the two would
    /// report a daemon as running twice per turn. The round's question is "was
    /// this declared timer ever exercised?", which membership answers exactly.
    private var firedTimersEver: [String: Int] = [:]

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
    ///   - divergence: what to do at an irreversible action. See
    ///     ``DivergencePolicy``.
    ///   - prepared: the game, booted once by the server.
    ///   - directory: this probe's directory.
    ///   - saveDirectory: the label's saves directory.
    init(
        id: String,
        label: String,
        probe: String,
        seed: UInt64,
        role: PlaytestRole,
        divergence: DivergencePolicy,
        prepared: PreparedGame,
        directory: URL,
        saveDirectory: URL
    ) {
        self.id = id
        self.label = label
        self.probe = probe
        self.seed = seed
        self.role = role
        self.divergence = divergence
        self.ledger = CoverageLedger(divergence: divergence)
        self.prepared = prepared
        self.directory = directory
        self.saveDirectory = saveDirectory
        self.transcriptURL = directory.appendingPathComponent("transcript.txt")
        self.commandsURL = directory.appendingPathComponent("commands.txt")
        self.transcriptWithoutStatusURL =
            directory.appendingPathComponent("transcript-without-status.txt")
        self.summaryURL = directory.appendingPathComponent("summary.txt")
        self.closingURL = directory.appendingPathComponent("closing.json")
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
        try resumeRecordingIfNeeded()

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

    /// What each of these words resolves to in the room this session's player
    /// is standing in right now. See ``GameWorld/resolve(_:)``.
    ///
    /// Answer-key data, and gated one level up: the tool passes `oracle: true`
    /// to ``PlaytestSessions/session(_:oracle:)``, exactly as `survey` and
    /// `vocabulary` do. Unlike those two it needs a live world — the answer is a
    /// fact about a *place*, not about the game type — so an evicted session
    /// replays itself to be asked, which is what `liveWorld()` is for.
    ///
    /// - Parameter words: the words to ask about, as they would be typed.
    /// - Throws: ``PlaytestError`` when a session that had been evicted cannot
    ///   reopen its transcript to replay itself.
    /// - Returns: one resolution per word, in order. No turn passes.
    func resolve(_ words: [String]) async throws -> [PlaytestResolution] {
        await (try liveWorld()).resolve(words)
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
        try resumeRecordingIfNeeded()
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
    /// One irreversible action this session was offered.
    struct ForkOutcome: Sendable {
        /// The queue item's id, `object:<thing>:<intent>`.
        let id: String
        /// The command that takes it, as typed from its own room.
        let command: String
        /// Where it was offered.
        let room: String
        /// Whether this session actually took it. False both for a fork it
        /// never got to and for one its policy told it to leave — the round
        /// wants to know the branch is untested either way, and the session's
        /// own `divergence` says which of the two happened.
        let taken: Bool
    }

    struct Closing: Sendable {
        /// One room this session stood in: the ID the game declared it under,
        /// and the name the status line printed.
        ///
        /// Both, because the two are for different readers. The ID is the join
        /// key — the same key space `survey`'s room roster is in, so a
        /// numerator built from these can reach that denominator. The name is
        /// what a report says out loud, and looking it up costs a round nothing
        /// if it travels alongside.
        struct VisitedRoom: Sendable, Equatable {
            /// The declared ID, as `Location`'s property name gave it.
            let id: EntityID
            /// The display name the status line printed for it.
            let name: String
        }

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
        /// Every fork this session met, and whether it took it.
        ///
        /// The round assembles these across its testers: a fork that comes back
        /// `taken: false` from every session is a branch the whole round left
        /// alone, which is a coverage gap nothing else in the harness can see.
        let forks: [ForkOutcome]
        /// The rooms the status line named, in first-seen order, each with the
        /// ID the game declared it under.
        ///
        /// Counted, not asked. A round that asks a tester which rooms it saw
        /// gets a number the tester reconstructed from memory at the end of a
        /// long session, and the two rounds that checked found it wrong in both
        /// directions.
        ///
        /// **Keyed by ID, because the display name cannot be a key.** This list
        /// is the numerator of the round's room coverage and `survey`'s room
        /// roster is the denominator; before the ID travelled, the two were in
        /// different key spaces and one of them could not represent the answer.
        /// Dungeon declares 143 rooms under 126 distinct names, so a
        /// name-keyed record charged a tester who walked all seven Coal Mines
        /// with one room and left seventeen rooms permanently uncountable.
        ///
        /// **Every room the session ever stood in, whether or not the turns
        /// survived a rewind.** The 2026-08-17 round reported Vane's Study as
        /// never entered after a tester worked it for ten turns and rewound; six
        /// branch files that round held 102 real turns the coverage denominator
        /// could not see. ``roomsOnlyInBranches`` says which of these to look for
        /// in a `branch-NNN.txt` rather than in `transcript.txt`, and
        /// `signals.roomsVisited` stays the canonical count — see
        /// ``roomsEverVisited`` for why the two are allowed to disagree.
        let roomsVisited: [VisitedRoom]

        /// The IDs of the rooms in ``roomsVisited`` the session did something
        /// in, as against merely stood in.
        ///
        /// ``roomsVisited`` is entered, and entered is not worked. A tester who
        /// pastes a `routes/*.txt` walkthrough as a prefix walks fifty rooms
        /// without reading a line of any of them, and every one of those rooms
        /// lands in ``roomsVisited`` looking exactly like a room somebody
        /// probed. The 2026-08-24 Dungeon round published 128 of 181 rooms
        /// entered on that arithmetic while 26 had been worked by a charter's
        /// own hand: two explorers typed 717 of 734 and 596 of 618 session
        /// commands verbatim out of a route file, and between them contributed
        /// half the round's room count for nine commands of their own.
        ///
        /// **A room is worked when a line typed while standing in it parsed to
        /// an intent that is neither `go` nor meta.** Travel is what a prefix
        /// is made of, and a meta intent (`score`, `save`, `undo`, …) talks to
        /// the program rather than to the room. Everything else — `examine`,
        /// `take`, `open`, `wait`, `look` — is the tester's attention landing
        /// somewhere, so it counts.
        ///
        /// **This is an upper bound on hand-worked rooms, not a measurement of
        /// them.** The session cannot see where a line came from: a `move` call
        /// carrying a pasted route is indistinguishable from one the agent
        /// composed, so a route file's own `take lamp` credits its room here.
        /// The bound is still worth having, because the gap between the two
        /// counts is where a round's coverage claim is soft, and a prefix is
        /// overwhelmingly travel. A parse failure credits nothing — it names no
        /// intent, and what it does tell us is already in ``unknownWords``.
        ///
        /// Credited to the room the line was typed in rather than the room it
        /// ended in, so that the command which launches the balloon counts for
        /// the room the balloon left.
        let roomsWorked: [EntityID]

        /// The IDs of the rooms in ``roomsVisited`` whose evidence is in a
        /// branch file rather than in the transcript, because a rewind wrote
        /// those turns off.
        ///
        /// Empty for a session that never rewound, which is most of them. It is
        /// here so that a reader who greps `transcript.txt` for a room this
        /// record claims, finds nothing, and concludes the record is lying, is
        /// instead told where to look.
        ///
        /// Decided by *name*, because the ledger this is checked against holds
        /// display names — a room string there is an item identity and a
        /// transcript-heading matcher, not a coverage key, and it stays that
        /// way. The cost is that where two rooms share a name, standing in one
        /// of them canonically suppresses the hint for the other. That is a
        /// pointer to where the evidence lives, so a missed hint costs a reader
        /// one `grep`; nothing is counted off it.
        let roomsOnlyInBranches: [EntityID]

        /// Every timer whose body ran in this session, by name, and how often —
        /// the engine's own tally, not an inference off the prose.
        ///
        /// Read against the survey's timer roster, which is the denominator: a
        /// declared name missing from every session's tally is a timer the round
        /// never exercised, and a name *here* that the roster does not hold means
        /// the roster is wrong rather than that a timer appeared from nowhere.
        ///
        /// **Membership is exact; the counts are a floor.** See
        /// ``PlaytestSession/firedTimersEver``, and `SKILL.md` for why the
        /// heuristic in `CoverageLedger` cannot answer this and must not try.
        let firedTimers: [String: Int]

        /// Every token the vocabulary did not know, and how often it was typed.
        let unknownWords: [String: Int]
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
        let ledgerRooms = Set(ledger.roomsVisited)
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
        let closing = Closing(
            open: open,
            items: items,
            signals: ledger.signals(),
            hint: ledger.frontierHint(),
            forks: ledger.forks().map {
                ForkOutcome(id: $0.id, command: $0.command, room: $0.room, taken: $0.taken)
            },
            roomsVisited: roomsEverVisited,
            roomsWorked: roomsWorkedEver,
            roomsOnlyInBranches: roomsEverVisited.compactMap {
                ledgerRooms.contains($0.name) ? nil : $0.id
            },
            firedTimers: firedTimersEver,
            unknownWords: ledger.unknownWords,
            transcript: transcriptURL.path,
            message: message)
        writeClosingRecord(closing)
        return closing
    }

    /// Writes the closing record beside the transcript, so the round can read
    /// what this session did without asking the agent that played it.
    ///
    /// This is the whole reason the accounting is trustworthy. The orchestration
    /// script has no filesystem of its own and never sees a tool result — only
    /// the tester's report comes back to it — so before this file existed the
    /// round's room and word counts were either self-reported (wrong: 112
    /// claimed against 155 walked, and 2 claimed against 261 typed) or
    /// reconstructed by grepping transcripts for the engine's own prose (wrong
    /// the moment a game re-voices that line). A file the server writes is
    /// neither.
    ///
    /// Deliberately best-effort. A session whose scratch directory has gone
    /// away has still played the game, and `finish` reports; it does not refuse.
    /// A round that finds a `transcript.txt` with no `closing.json` beside it
    /// reports the session as unfinished, which is a truer thing to say than a
    /// silently missing row.
    private func writeClosingRecord(_ closing: Closing) {
        try? Data("\(closing.json.text)\n".utf8).write(to: closingURL, options: .atomic)
    }

    // MARK: - Exporting

    /// Where a finished session's evidence is, and whether it holds up.
    struct Export: Sendable {
        /// The transcript as this session recorded it, `[status]` footers and
        /// all.
        let transcript: String
        /// The same transcript with the footers taken out — the string a
        /// `play(_:_:seed:)` test asserts on, so an excerpt lifted from here
        /// into the suite carries nothing the suite will not see.
        let transcriptWithoutStatus: String
        /// The command list, replayable by either harness.
        let commands: String
        /// The plain-language account.
        let summary: String
        /// How many lines were recorded.
        let lines: Int
        /// The seed all of it replays at.
        let seed: UInt64
        /// Whether the recorded transcript is byte-for-byte the one a fresh
        /// `REPL` writes for the same list. Always true, or this throws.
        let verified: Bool
        /// The prose the agent reads.
        let message: String
    }

    /// Closes the recording, writes the rest of the evidence, and **proves the
    /// transcript is the REPL's**.
    ///
    /// The proof is the point of the tool, and it is worth being exact about
    /// what it proves. This session's transcript was written by the loop in
    /// ``run(_:at:in:)``, which is `REPL.run`'s loop with the IO handler taken
    /// out. The verify feeds the same command list to a *fresh* `REPL` through
    /// `ScriptedIOHandler` — the arrangement `play(_:_:seed:)` uses — and
    /// compares the whole file to the whole string. Byte-for-byte, not
    /// substring: the last divergence between the two drivers was one byte on
    /// one reachable turn (empty output at the death prompt) and it cost a
    /// stage to find.
    ///
    /// So every session that is exported re-proves, on real evidence, the claim
    /// the entire harness rests on: **a tester's command list is a regression
    /// test.** `docs/playtesting.md` and `bin/playtest-replay` both promise that
    /// in those words. A mismatch is not a formatting problem to note and move
    /// past; it means a finding's reproducer might not reproduce, so it is
    /// raised as a tool error naming both files and the first byte that differs
    /// — after everything has been written, so nothing is lost to the failure.
    ///
    /// The one honest caveat is a session that used the player's own `save` or
    /// `restore`: those reach a file outside the run, which another probe under
    /// the same label may have rewritten since, so a mismatch there may be about
    /// the slot rather than about the driver. The message says so when it
    /// applies.
    ///
    /// Exporting does not end the session. The next `move` reopens the
    /// transcript and rewrites it from the blocks in hand, so a tester that
    /// exports and then thinks of one more thing loses nothing.
    ///
    /// - Throws: ``PlaytestError`` when a file cannot be written or read, and
    ///   when the two transcripts differ.
    /// - Returns: the paths, and the verdict.
    func export() async throws -> Export {
        // Rehydrates first, so an evicted session exports the whole run rather
        // than the prefix its transcript happened to be truncated to.
        _ = try await liveWorld()
        persistCommands()
        recorder?.close()
        recorder = nil

        let lines = turns.map(\.line)
        let recorded = try read(transcriptURL)
        let replayed = await replay(lines, status: footer)
        let plain = await replay(lines, status: nil)
        try write(plain, to: transcriptWithoutStatusURL)

        let verified = recorded == replayed
        let signals = ledger.signals()
        try write(
            Self.summary(
                session: id, title: prepared.definition.title, seed: seed, lines: lines,
                signals: signals, open: ledger.openCount, divergence: divergence,
                verified: verified,
                firstDifference: verified ? nil : Self.firstDifference(recorded, replayed)),
            to: summaryURL)

        let files = """
            transcript (as recorded, with [status] lines): \(transcriptURL.path)
            transcript (no [status] lines — write tests from this one): \
            \(transcriptWithoutStatusURL.path)
            commands: \(commandsURL.path)
            summary: \(summaryURL.path)
            """
        guard verified else {
            throw PlaytestError(
                """
                Everything is on disk, and the byte-identity check FAILED — report this, it \
                is a finding about the harness and not about the game. \(lines.count) lines \
                replayed through a fresh REPL at seed \(seed) did not produce the bytes this \
                session recorded. A tester's command list is supposed to *be* a regression \
                test, so a reproducer filed from this session may not reproduce.
                \(Self.firstDifference(recorded, replayed))\
                \(pinned
                    ? "\n\nThis session used the player's own save or restore, which reaches "
                        + "a file outside the run: another probe under label \(label) may have "
                        + "rewritten a slot since, in which case the difference is about the "
                        + "slot and not about the driver. Check the diverging turn.\n"
                    : "\n")
                \(files)
                """)
        }
        return Export(
            transcript: transcriptURL.path,
            transcriptWithoutStatus: transcriptWithoutStatusURL.path,
            commands: commandsURL.path,
            summary: summaryURL.path,
            lines: lines.count,
            seed: seed,
            verified: true,
            message: """
                Exported \(lines.count) line\(lines.count == 1 ? "" : "s") at seed \(seed), \
                and verified: replaying them through a fresh REPL produces this transcript \
                byte for byte, so the command list is a regression test.
                \(files)
                \(signals.line)
                """)
    }

    /// The same commands through a real `REPL`, returning what
    /// `ScriptedIOHandler` recorded.
    ///
    /// The session's own save directory, not a scratch one: a run that typed
    /// `save` and then `restore` only reproduces against the slots it wrote.
    ///
    /// - Parameters:
    ///   - commands: the lines to feed.
    ///   - status: the footer to append, or `nil` for the plain transcript the
    ///     suite sees.
    /// - Returns: the transcript.
    private func replay(_ commands: [String], status: StatusFooter?) async -> String {
        let world = GameWorld(prepared: prepared, seed: seed, saveDirectory: saveDirectory)
        let io = ScriptedIOHandler(lines: commands)
        await REPL(world: world, io: io, status: status).run()
        return io.transcript
    }

    // MARK: - Going back

    /// A place a tester can come back to.
    struct Marked: Sendable {
        let name: String
        /// The recorded-line index it stands at.
        let line: Int
        let room: String
        let moves: Int
        let message: String
    }

    /// What came of going back.
    struct Rewound: Sendable {
        /// The checkpoint's name, or `nil` for a plain rewind.
        let name: String?
        /// The recorded-line index the session now stands at.
        let line: Int
        let room: String
        let moves: Int
        /// How many recorded lines were dropped.
        let discarded: Int
        /// Where the dropped turns were kept, or `nil` when there were none.
        let branch: String?
        /// The `[status]` line as of the line it went back to.
        let status: String
        let message: String
    }

    /// Marks the current line so the tester can come back to it.
    ///
    /// - Parameter name: what to call it.
    /// - Throws: ``PlaytestError`` for an empty name.
    /// - Returns: where the mark was put.
    func checkpoint(_ name: String) async throws -> Marked {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PlaytestError("checkpoint needs a name to remember this place by.")
        }
        _ = try await liveWorld()
        let line = turns.count
        let existing = checkpoints[trimmed]
        checkpoints[trimmed] = Checkpoint(
            line: line, room: ledger.currentRoom, moves: lastMoves)
        return Marked(
            name: trimmed,
            line: line,
            room: ledger.currentRoom,
            moves: lastMoves,
            message: """
                \(existing == nil ? "Marked" : "Moved") `\(trimmed)` to line \(line) \
                (\(ledger.currentRoom), moves=\(lastMoves)). Call restore with that name to \
                come back; the turns after it are written off to a branch file and dropped \
                from the command list, so what you file afterwards still replays from line \
                one.
                """)
    }

    /// Goes back to a marked place.
    ///
    /// - Parameter name: the checkpoint's name.
    /// - Throws: ``PlaytestError`` when nothing answers to the name, when the
    ///   mark is stale, or when the session cannot be put back there.
    /// - Returns: what was dropped.
    func restore(checkpoint name: String) async throws -> Rewound {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let mark = checkpoints[trimmed] else {
            let known = checkpoints.keys.sorted().joined(separator: ", ")
            throw PlaytestError(
                checkpoints.isEmpty
                    ? """
                    No checkpoint \"\(trimmed)\", and this session has none. Call checkpoint \
                    first, or use rewind to go back a number of turns.
                    """
                    : "No checkpoint \"\(trimmed)\". This session has: \(known).")
        }
        guard mark.line <= turns.count else {
            checkpoints.removeValue(forKey: trimmed)
            throw PlaytestError(
                """
                Checkpoint \"\(trimmed)\" stood at line \(mark.line) and this session is now \
                \(turns.count) lines long — an earlier rewind went back past it, so the mark \
                pointed at turns that no longer exist. It has been dropped.
                """)
        }
        return try await truncate(to: mark.line, naming: trimmed)
    }

    /// Goes back a number of recorded lines.
    ///
    /// - Parameter count: how many lines to drop, comments included, because
    ///   that is how the lines are numbered everywhere else in this session.
    /// - Throws: ``PlaytestError`` for a count that is not positive, one past
    ///   the ring, or a session that cannot be put back there.
    /// - Returns: what was dropped.
    func rewind(turns count: Int) async throws -> Rewound {
        guard count > 0 else {
            throw PlaytestError("rewind needs a positive number of turns to go back.")
        }
        guard count <= Self.snapshotRing else {
            throw PlaytestError(
                """
                rewind goes back at most \(Self.snapshotRing) lines and was asked for \
                \(count). Nothing moved. That is the depth of the snapshot ring, which is \
                bounded so a long session does not carry its whole history in memory — to \
                come back from further away, mark the place with checkpoint before you go, \
                which costs nothing because a checkpoint is an index rather than a state.
                """)
        }
        guard count <= turns.count else {
            throw PlaytestError(
                """
                rewind was asked for \(count) lines and this session has only \
                \(turns.count). Nothing moved.
                """)
        }
        return try await truncate(to: turns.count - count, naming: nil)
    }

    /// Puts the session back at a recorded line and writes off everything after
    /// it.
    ///
    /// **Both files are truncated, and that is the design rather than an
    /// omission.** The invariant this harness sells is that `commands.txt`
    /// replays to `transcript.txt`; a rewind that rewound the world and left the
    /// record alone would break it on the spot, and every reproducer filed
    /// afterwards would be a list of commands that does not produce the quoted
    /// line. So the record goes back too, and a finding reached after a rewind
    /// has a reproducer that is still the whole list from line one.
    ///
    /// What that would otherwise cost is the evidence of the branch nobody took,
    /// so the discarded turns are written to `branch-NNN.txt` beside the
    /// transcript before they go, with a comment line saying where they came
    /// from. Nothing is lost; it stops being canonical.
    ///
    /// Two ways back, and the second is the reason the first can be a bounded
    /// ring. If the ring still holds the line, the world is put back from it
    /// directly. If it does not — or if the snapshot was taken with a question
    /// open, which `GameWorld.restore(_:)` closes and a replay would re-arm —
    /// the world is dropped and the retained prefix is replayed, which is the
    /// same machinery an eviction uses and is exact for the same reason. That
    /// path is refused for a session that used the player's own `save` or
    /// `restore`, on the same argument that pins one against eviction: its run
    /// depends on a file the replay does not control.
    ///
    /// - Parameters:
    ///   - target: the line to stand at afterwards; `0` is the opening.
    ///   - name: the checkpoint's name, when this came from one.
    /// - Throws: ``PlaytestError`` when the session cannot be put back there.
    /// - Returns: what was dropped.
    private func truncate(to target: Int, naming name: String?) async throws -> Rewound {
        _ = try await liveWorld()
        let dropped = Array(turns[target...])
        let usable = ring.first { $0.line == target && $0.pending == .none }
        guard usable != nil || !pinned else {
            throw PlaytestError(
                """
                Can't go back to line \(target): this session used the player's own save or \
                restore, and the only way back to a line the snapshot ring no longer holds \
                is to replay the lines up to it — which is not safe once a run depends on a \
                save slot, because the slot may have been rewritten since and the replay \
                would land in a world that never happened. Nothing moved. Open a fresh \
                session and replay \(commandsURL.path) up to line \(target) if you need \
                this.
                """)
        }

        let branch = writeBranch(dropped)
        turns.removeSubrange(target...)
        checkpoints = checkpoints.filter { $0.value.line <= target }
        ring.removeAll { $0.line > target }

        if let usable, let world {
            await world.restore(usable.state)
            ledger = usable.ledger
            statusLine = usable.statusLine
            lastMoves = usable.lastMoves
            finished = usable.finished
            lastNudge = usable.lastNudge
            pending = await world.awaiting()
            try rewriteTranscript()
        } else {
            // The eviction path, used deliberately: drop the world and let
            // `liveWorld` replay the prefix. It rewrites the transcript from the
            // beginning as it goes, so the two files agree at the end of it.
            recorder?.close()
            recorder = nil
            world = nil
            openingBlock = ""
            ring = []
            finished = false
            for index in turns.indices {
                turns[index].block = ""
            }
            _ = try await liveWorld()
        }
        persistCommands()

        return Rewound(
            name: name,
            line: target,
            room: ledger.currentRoom,
            moves: lastMoves,
            discarded: dropped.count,
            branch: branch?.path,
            status: statusLine,
            message: """
                Back at line \(target) — \(ledger.currentRoom), moves=\(lastMoves)\
                \(name.map { ", the checkpoint you called `\($0)`" } ?? "").
                \(dropped.count) line\(dropped.count == 1 ? "" : "s") dropped from the \
                command list\(branch.map { ", kept as evidence at \($0.path)" } ?? "").
                \(statusLine)
                """)
    }

    /// Writes the turns a rewind discarded to their own file.
    ///
    /// Best effort, and never a reason to fail the rewind: the branch is a
    /// courtesy to whoever reads the round afterwards, where the truncation
    /// itself is what keeps the reproducer honest.
    ///
    /// - Parameter dropped: the turns being written off, oldest first.
    /// - Returns: where they went, or `nil` when there were none or the write
    ///   failed.
    private func writeBranch(_ dropped: [Turn]) -> URL? {
        guard !dropped.isEmpty else { return nil }
        branches += 1
        let url = directory.appendingPathComponent(String(format: "branch-%03d.txt", branches))
        let header = TranscriptRecorder.text(
            commentLine: """
                // [branch] \(dropped.count) lines rewound out of session \(id) at line \
                \(dropped.first?.index ?? 0). Kept as evidence; not a canonical transcript.
                """)
        let text = header + dropped.map(\.block).joined()
        guard (try? Data(text.utf8).write(to: url, options: .atomic)) != nil else { return nil }
        return url
    }

    /// Records that the session stood in a room, for good.
    ///
    /// Called from the two places the ledger is told a room — the opening and
    /// every line after it — and from nowhere that a rewind reaches. See
    /// ``roomsEverVisited``.
    ///
    /// Takes the whole status line rather than a room string, because the two
    /// halves it records have to come from one reading of it: an ID paired with
    /// some other turn's name would be a record nothing could check.
    ///
    /// - Parameter status: the status line this turn ended on.
    private func visit(_ status: StatusLine) {
        let id = status.locationID
        // Carried forward whether or not the room is new, because this is where
        // the *next* line will be typed, not a record of anything.
        standingIn = id.raw.isEmpty ? nil : id
        guard !id.raw.isEmpty, !roomsEverVisited.contains(where: { $0.id == id }) else {
            return
        }
        roomsEverVisited.append(Closing.VisitedRoom(id: id, name: status.locationName))
    }

    /// Records that the session did something in the room it was standing in.
    ///
    /// Called from `run` for every line, and it decides for itself whether the
    /// line counts — see ``Closing/roomsWorked`` for the rule and for what the
    /// rule cannot see. Kept beside ``visit(_:)`` and out of the ledger for the
    /// same reason ``roomsEverVisited`` is: a rewind must not be able to take
    /// it back, and the ledger's rooms are display names, which cannot key a
    /// coverage answer.
    ///
    /// - Parameter audit: what the parser made of the line.
    private func work(_ audit: TurnAudit) {
        guard let room = standingIn,
            let intent = audit.intent,
            intent != .go,
            !intent.isMeta,
            !roomsWorkedEver.contains(room)
        else { return }
        roomsWorkedEver.append(room)
    }

    /// Reopens the transcript and writes back the blocks the session is holding.
    ///
    /// Truncating rather than appending, for the reason stated at ``boot()``:
    /// one write path is cheaper to trust than an append path that has to be
    /// sure where it left off, and the bytes written the second time are the
    /// bytes that were there.
    ///
    /// - Throws: ``PlaytestError`` when the file cannot be reopened.
    private func rewriteTranscript() throws {
        recorder?.close()
        recorder = nil
        do {
            recorder = try TranscriptRecorder(url: transcriptURL)
        } catch {
            throw PlaytestError(
                "Couldn't reopen the transcript at \(transcriptURL.path): \(error).")
        }
        recorder?.record(renderedBlock: openingBlock)
        for turn in turns {
            recorder?.record(renderedBlock: turn.block)
        }
    }

    /// Reopens the transcript when an ``export()`` closed it, so play can go on.
    ///
    /// - Throws: ``PlaytestError`` when the file cannot be reopened.
    private func resumeRecordingIfNeeded() throws {
        guard recorder == nil, world != nil else { return }
        try rewriteTranscript()
    }

    /// The inline `harness:` line, at most one per twenty commands.
    ///
    /// Appended to a `move` result and to nothing else — never recorded, so a
    /// nudge cannot reach the transcript and cost this harness its byte
    /// identity with the REPL.
    ///
    /// - Returns: the line to append, or the empty string.
    private func nudge() -> String {
        // The cheap clause first, deliberately. `signals()` makes six full
        // passes over the queue, and nineteen calls in twenty are going to be
        // thrown away on the interval test — so asking the interval first is
        // the difference between paying for those passes every turn and paying
        // once per twenty. Both clauses are pure and `lastNudge` moves only
        // after both pass, so the order is free to choose.
        guard ledger.commands >= lastNudge + 20, let note = ledger.signals().note else {
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
        ring = []
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
        ledger = CoverageLedger(divergence: divergence)
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
        visit(result.status)
        statusLine = footer.line(result.status, turnCost: false, fields: fields)
        lastMoves = result.status.moves
        finished = result.isFinished
        pending = await world.awaiting()
        self.world = world
        // The ring is derived state like the ledger, so it is thrown away and
        // refilled by the replay rather than carried across an eviction — every
        // line of the replay goes through `run`, which remembers it. The named
        // checkpoints are *not* thrown away, and that is the whole reason they
        // are indices: a replay puts the lines they point at back where they
        // were.
        ring = []
        await remember(line: 0, in: world)
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
            // Snapshotted like any other recorded line: `rewind` counts lines,
            // comments included, so a rewind that landed on one would otherwise
            // have to replay the session to find a frame it was already holding.
            await remember(line: index, in: world)
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
        // Before `visit`, which moves `standingIn` on: the work belongs to the
        // room the line was typed in.
        work(audit)
        visit(result.status)

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
        await remember(line: index, in: world)
        return TranscriptRecorder.text(command: line, output: annotated)
    }

    /// Puts this line's world and this line's reading of it into the ring, and
    /// folds anything about the line a rewind must not be able to undo into the
    /// session.
    ///
    /// Called at the bottom of every recorded line, after everything about the
    /// line has been applied — the whole value of a snapshot is that it is the
    /// frame the tester was actually standing in when it decided to go back.
    ///
    /// Which is also why the fired-timer fold is here rather than at the seams
    /// that drop a world. Every one of those seams — a rewind past the ring, a
    /// plain ``evict()``, a rehydration — is then safe by construction instead
    /// of by an argument that has to be re-derived the next time one is added.
    /// See ``firedTimersEver``.
    ///
    /// - Parameters:
    ///   - line: the recorded-line index this snapshot stands at.
    ///   - world: the live world.
    private func remember(line: Int, in world: GameWorld) async {
        firedTimersEver.merge(await world.firedTimers, uniquingKeysWith: max)
        ring.append(
            Snapshot(
                line: line,
                state: await world.snapshot(),
                ledger: ledger,
                statusLine: statusLine,
                lastMoves: lastMoves,
                finished: finished,
                pending: pending,
                lastNudge: lastNudge))
        if ring.count > Self.snapshotRing {
            ring.removeFirst()
        }
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

    /// Reads one of the session's own files.
    ///
    /// - Parameter url: the file.
    /// - Throws: ``PlaytestError`` naming it, because the caller is an agent and
    ///   a `CocoaError` is not something it can act on.
    /// - Returns: the contents as text.
    private func read(_ url: URL) throws -> String {
        do {
            return String(decoding: try Data(contentsOf: url), as: UTF8.self)
        } catch {
            throw PlaytestError("Couldn't read \(url.path): \(error).")
        }
    }

    /// Writes one of the session's own files, atomically.
    ///
    /// - Parameters:
    ///   - text: the contents.
    ///   - url: where to put them.
    /// - Throws: ``PlaytestError`` naming the file.
    private func write(_ text: String, to url: URL) throws {
        do {
            try Data(text.utf8).write(to: url, options: .atomic)
        } catch {
            throw PlaytestError("Couldn't write \(url.path): \(error).")
        }
    }

    /// The plain-language account `export` leaves beside the transcript.
    ///
    /// Written for a person opening the directory a month later with no idea
    /// what these four files are, so it says what each one is for and what the
    /// numbers mean. Everything in it is the session's own record plus the
    /// game's title, which the opening banner printed — nothing here reaches for
    /// the definition, and the firewall holds through the export the same way it
    /// holds through the queue.
    ///
    /// - Parameters:
    ///   - session: the session id.
    ///   - title: the game's title.
    ///   - seed: the seed it replays at.
    ///   - lines: every recorded line.
    ///   - signals: the measured signals.
    ///   - open: how many queue items were still open.
    ///   - divergence: the fork policy this session ran under.
    ///   - verified: whether the byte-identity check passed.
    ///   - firstDifference: where the two transcripts first differ, when they do.
    /// - Returns: the file's contents.
    private static func summary(
        session: String, title: String, seed: UInt64, lines: [String],
        signals: PlaytestSignals, open: Int, divergence: DivergencePolicy,
        verified: Bool, firstDifference: String?
    ) -> String {
        let comments = lines.filter(TesterInput.isComment).count
        var text = """
            Play-test session \(session)
            game: \(title)
            seed: \(seed)
            lines recorded: \(lines.count) (\(lines.count - comments) \
            command\(lines.count - comments == 1 ? "" : "s"), \(comments) \
            comment\(comments == 1 ? "" : "s"))
            signals: \(signals.line)
            queue items still open: \(open)
            divergence policy: \(divergence.rawValue)

            byte identity: \(verified ? "verified" : "FAILED")
              Replaying commands.txt through a fresh REPL at this seed \
            \(verified ? "produces transcript.txt exactly" : "did NOT reproduce transcript.txt")\
            \(verified
                ? ", so this command list is a regression test."
                : " — a reproducer filed from this session may not reproduce.")

            files here:
              commands.txt                   every line fed, comments included
              transcript.txt                 as recorded, with a [status] line per turn
              transcript-without-status.txt  the same run without them — write a suite \
            test from this one
              branch-NNN.txt                 turns a rewind discarded, kept as evidence

            """
        if let firstDifference {
            text += "\n\(firstDifference)\n"
        }
        return text
    }

    /// Where two transcripts first differ, with a window of each.
    ///
    /// Byte identity is the invariant; a report that only said "they differ"
    /// would leave the reader diffing two files by hand to find the one turn
    /// that matters, which on a five-hundred-line session is the whole job.
    ///
    /// - Parameters:
    ///   - recorded: what the session wrote.
    ///   - replayed: what a fresh `REPL` wrote for the same lines.
    /// - Returns: a paragraph naming the offset and quoting both sides.
    private static func firstDifference(_ recorded: String, _ replayed: String) -> String {
        let left = Array(recorded.utf8)
        let right = Array(replayed.utf8)
        var offset = 0
        while offset < left.count, offset < right.count, left[offset] == right[offset] {
            offset += 1
        }
        func window(_ bytes: [UInt8]) -> String {
            let start = max(0, offset - 80)
            let end = min(bytes.count, offset + 80)
            guard start < end else { return "(end of file)" }
            return String(decoding: bytes[start..<end], as: UTF8.self)
        }
        return """
            First difference at byte \(offset) of \(left.count) recorded / \(right.count) \
            replayed.
            recorded: …\(window(left))…
            replayed: …\(window(right))…
            """
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
