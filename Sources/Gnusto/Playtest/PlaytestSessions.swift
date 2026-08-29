import Foundation

/// Every open play-test session in this process, and the disk layout they
/// live in.
///
/// One `PreparedGame` is shared by all of them — `Bootstrap.build` is a pure
/// function of the game *type*, and its dominant cost is `Mirror` reflection,
/// so a server that re-booted per session would pay it once per tester for no
/// reason. Each session then gets its own `GameWorld` over that shared
/// definition, its own seed, and its own directory.
///
/// **The layout is `bin/playtest-replay`'s, exactly.** A finding cites a path,
/// and a reader following one should not have to know which harness produced
/// it:
///
/// ```
/// .context/playtest/<label>/saves/          shared by every probe under the label
/// .context/playtest/<label>/<probe>/transcript.txt
///                                  /commands.txt
/// .context/playtest/.replays/<probe>/       one sessionless `replay`: the same two
///                                           files, plus the script's summary.txt
/// ```
///
/// A label is a tester's namespace and a probe is one run; each `open`
/// allocates a fresh probe, so re-using a label never overwrites a transcript
/// somebody cited. Probe allocation uses that script's trick, for the same
/// reason: `mkdir` **is** the lock — it fails when the directory exists, and it
/// fails atomically — and sessions here genuinely run at the same time.
actor PlaytestSessions {
    /// Where a sessionless `replay` leaves its evidence.
    ///
    /// **The leading dot is what reserves it.** ``isPlainName(_:)`` refuses a
    /// label starting with one — the rule that keeps a tester out of
    /// `bin/playtest-replay`'s `.bin` cache — so no label can ever collide with
    /// this directory and no guard is needed to say so. It also keeps the round's
    /// own `${game}-r*-session-*` glob narrow by construction: a replay probe is
    /// the round's machinery, not a tester who never called `finish`.
    static let replayLabel = ".replays"

    /// How many sessions may hold a live world at once, absent
    /// `GNUSTO_MCP_MAX_SESSIONS`.
    static let defaultMaxSessions = 32

    /// The most probes one label may hold, matching `bin/playtest-replay`.
    private static let probeLimit = 999

    /// The game every session plays.
    private let prepared: PreparedGame

    /// `.context/playtest`, or wherever `GNUSTO_PLAYTEST_DIR` points.
    private let root: URL

    /// The live-session cap. See ``evictIfNeeded()``.
    private let maxSessions: Int

    /// Every session ever opened in this process, live or evicted to a stub.
    /// An id stays valid for the life of the server: an evicted session
    /// answers exactly as it did before, having replayed itself first.
    private var sessions: [String: PlaytestSession] = [:]

    /// The sessions believed to hold a live world, and when each was last
    /// reached for.
    ///
    /// Bookkeeping kept *here* rather than asked of the sessions, because
    /// asking means awaiting each one — and a session in the middle of a
    /// two-hundred-command batch would stall the registry, and with it every
    /// other tester's lookups, for the length of somebody else's turn.
    private var live: Set<String> = []
    private var lastUsed: [String: Int] = [:]

    /// A monotonic tick, which is all "least recently used" needs.
    private var clock = 0

    /// Builds the registry from the composition root's environment.
    ///
    /// - Parameters:
    ///   - prepared: the game, booted once by the server.
    ///   - environment: the process environment.
    init(prepared: PreparedGame, environment: [String: String]) {
        self.prepared = prepared
        self.root = Self.root(environment: environment)
        self.maxSessions = Self.maxSessions(environment: environment)
    }

    // MARK: - Opening and finding

    /// Opens a session: allocates its probe directory, registers it, and
    /// evicts down to the cap if this one put the process over it.
    ///
    /// The world is not booted here. It boots on first use, which keeps the
    /// failure that matters — a transcript file that cannot be opened — on the
    /// call that reports the opening rather than on a silent constructor.
    ///
    /// - Parameters:
    ///   - label: the tester's namespace; becomes a directory name.
    ///   - seed: the random seed this session replays.
    ///   - role: what the session may be told beyond what the game prints to
    ///     it. See ``PlaytestRole``; the default is the human case.
    ///   - divergence: what the session does at an irreversible action.
    ///     Defaults to ``DivergencePolicy/commit``, the historical behaviour.
    ///   - savesFrom: a directory of `.gnusto` slots to copy into this label's
    ///     `saves/` before the session exists, or `nil` for the ordinary clean
    ///     start. Resolve it with ``savesSource(_:)``. The slots land in the
    ///     label rather than the probe, so every probe under it can `restore`
    ///     them — which is the point: a round that ships pre-cut saves names
    ///     one source and each tester's own `open` stages it, where before an
    ///     operator had to hand-copy the files into directories whose names
    ///     the workflow had not chosen yet.
    /// - Throws: ``PlaytestError`` for an unusable label, a directory that
    ///   can't be made, or a `savesFrom` holding no slots.
    /// - Returns: the new session.
    func open(
        label: String, seed: UInt64, role: PlaytestRole = .unrestricted,
        divergence: DivergencePolicy = .commit, savesFrom: URL? = nil
    ) async throws -> PlaytestSession {
        guard Self.isPlainName(label) else {
            throw PlaytestError(
                """
                Bad label "\(label)". A label becomes a directory name under \
                \(root.path), so it must start with a letter, digit, underscore or hyphen \
                and hold nothing but those and dots. One label per tester: two testers \
                sharing one share its save slots.
                """)
        }
        let labelDirectory = Self.directory(forLabel: label, under: root)
        let saveDirectory = Self.savesDirectory(under: labelDirectory)
        do {
            try FileManager.default.createDirectory(
                at: saveDirectory, withIntermediateDirectories: true)
        } catch {
            throw PlaytestError("Couldn't create \(saveDirectory.path): \(error)")
        }

        // Staged here — after the saves directory exists and before anything
        // else does — so a `savesFrom` that names an empty or missing source
        // refuses while the only thing on disk is a directory this label was
        // going to have anyway. Staged after the probe was allocated, it would
        // leave a probe directory belonging to a session that never opened.
        let staged = try savesFrom.map { try Self.stageSlots(from: $0, into: saveDirectory) }

        let (probe, directory) = try Self.allocateProbe(in: labelDirectory)
        let id = "\(label)/\(probe)"
        let session = PlaytestSession(
            id: id,
            label: label,
            probe: probe,
            seed: seed,
            role: role,
            divergence: divergence,
            prepared: prepared,
            directory: directory,
            saveDirectory: saveDirectory,
            staged: staged)
        sessions[id] = session
        touch(id)
        await evictIfNeeded()
        return session
    }

    /// The session with this id.
    ///
    /// A malformed or stale id is a tool error naming what is open, not a trap
    /// and not a crash: the caller is a language model that mistyped something,
    /// and it can recover from a sentence.
    ///
    /// - Parameter id: the session id from `open`.
    /// - Throws: ``PlaytestError`` when nothing answers to it.
    /// - Returns: the session.
    func session(_ id: String) throws -> PlaytestSession {
        guard let session = sessions[id] else {
            let known =
                sessions.keys.sorted().prefix(8).joined(separator: ", ")
            throw PlaytestError(
                sessions.isEmpty
                    ? "No session \"\(id)\", and none are open. Call open first."
                    : "No session \"\(id)\". Open sessions: \(known).")
        }
        touch(id)
        return session
    }

    /// The session a tool call names, and — for an oracle tool — the check that
    /// its role may be told the answer key.
    ///
    /// The two live together because authorization here *is* a fact about the
    /// session: a role is carried by a session, so there is no such thing as an
    /// anonymous survey and no point at which a tool holds one without the
    /// other. Written twice in two handlers, the guard was a thing a
    /// fourteenth row could forget — and the failure of forgetting it is not a
    /// crash or a wrong number, it is the answer key going to a blind tester,
    /// which is the single thing the firewall exists to prevent. Here, `oracle:`
    /// is a parameter the author has to answer.
    ///
    /// - Parameters:
    ///   - arguments: the call's arguments, which carry the tool's name for the
    ///     refusal message.
    ///   - oracle: whether this tool serves answer-key data.
    /// - Throws: ``PlaytestError`` when no session answers to the id, or when
    ///   one does and its role may not be told.
    /// - Returns: the session.
    func session(
        _ arguments: PlaytestToolArguments, oracle: Bool = false
    ) throws -> PlaytestSession {
        let session = try session(try PlaytestTools.sessionID(arguments))
        guard !oracle || session.role.seesOracleData else {
            throw PlaytestError(session.role.refusal(of: arguments.tool))
        }
        return session
    }

    /// How many sessions this registry has ever opened. For the suite.
    func count() -> Int {
        sessions.count
    }

    /// Takes a directory for one sessionless `replay` to write its evidence into.
    ///
    /// **Best effort, and never a reason to fail a replay.** The same posture
    /// ``PlaytestSession/writeBranch(_:)`` takes, and for a sharper reason: the
    /// caller is a verifier adjudicating somebody's finding, and refusing to
    /// adjudicate because a disk was full would be a worse answer than
    /// adjudicating without a file to cite.
    ///
    /// It goes through the registry rather than being computed in
    /// ``PlaytestReplay`` so that one type owns the disk layout and one `mkdir`
    /// lock serves both allocators — two verifiers replaying at the same instant
    /// cannot take the same probe, for the same reason two testers cannot.
    ///
    /// - Returns: the fresh probe directory, or `nil` if one could not be made.
    func replayProbe() -> URL? {
        let labelDirectory = Self.directory(forLabel: Self.replayLabel, under: root)
        guard
            (try? FileManager.default.createDirectory(
                at: labelDirectory, withIntermediateDirectories: true)) != nil
        else { return nil }
        return try? Self.allocateProbe(in: labelDirectory).1
    }

    /// The saves directory of an existing label, for a `replay` or an `open`
    /// to stage out of.
    ///
    /// **Read-only by the shape of the answer.** This hands back a path and
    /// joins no session; the caller copies *out* of it into a directory of its
    /// own (``stageSlots(from:into:)``), so a `save` on the far side can never
    /// reach the label. Nothing here creates the directory: a label that does
    /// not exist is the caller's mistake, not a directory to make.
    ///
    /// It goes through the registry for the reason ``replayProbe()`` does —
    /// one type owns the disk layout — and it is the reason a replay, or a
    /// session, can finally answer a reproducer whose first command is
    /// `restore`.
    ///
    /// - Parameter label: the label the tester passed to `open`, or the CLI's
    ///   `--label`.
    /// - Throws: ``PlaytestError`` for a malformed name or a label with no
    ///   directory under the root.
    /// - Returns: `<root>/<label>/saves/`.
    func savesDirectory(forLabel label: String) throws -> URL {
        guard Self.isPlainName(label) else {
            throw PlaytestError(
                """
                Bad savesFrom "\(label)". It names a play label, which is a directory \
                name under \(root.path), so it must start with a letter, digit, \
                underscore or hyphen and hold nothing but those and dots. Nothing ran.
                """)
        }
        let labelDirectory = Self.directory(forLabel: label, under: root)
        guard Self.isDirectory(labelDirectory) else {
            throw PlaytestError(
                """
                No label "\(label)" under \(root.path). savesFrom names the label whose \
                saves you want to read — the name the tester passed to `open`, or \
                `bin/playtest-replay --label`. \(Self.labelsOnDisk(under: root)) Nothing ran.
                """)
        }
        return Self.savesDirectory(under: labelDirectory)
    }

    /// Where a `replay` or a freshly opened session may read saved games from:
    /// a play label, or a path to a saves directory.
    ///
    /// **Two spellings because the evidence outlives the label.** A round's
    /// labels are cleaned between rounds, and the durable copy of a staged
    /// replay's slots is the `saves-in/` directory ``PlaytestReplay`` leaves
    /// inside the probe — written precisely so a probe cited a year later still
    /// holds the bytes it ran on. A `savesFrom` that took only a label could
    /// name that directory in a receipt and never read it back, so the receipt
    /// documented a run nobody could repeat. A fixer picking up a confirmed
    /// finding is the ordinary case of that: by the time they replay, the
    /// tester's label is usually gone and the probe is all that is left.
    ///
    /// The rule for telling them apart is ``SaveStore/isExplicitPath(_:)``,
    /// called rather than restated — a `/` anywhere, or a leading `~`, means a
    /// path, and anything else is a bare name. It is the one spelling of that
    /// question in the package, so a caller who knows how the save prompt reads
    /// an answer knows how this reads one, and it stays true when the rule
    /// moves.
    ///
    /// A path is honored verbatim, which is the whole point: it names a
    /// directory outside the play-test root. That is not an escape to guard
    /// against — the copy is one way (``stageSlots(from:into:)``), the
    /// caller drives this process from inside the checkout, and
    /// `bin/playtest-replay --package-path` has always taken an arbitrary
    /// directory for the same reason.
    ///
    /// - Parameter named: a label, or a path to a directory holding `.gnusto`
    ///   slots.
    /// - Throws: ``PlaytestError`` for a malformed label, a label with no
    ///   directory under the root, or a path that is not a directory.
    /// - Returns: the directory to stage out of.
    func savesSource(_ named: String) throws -> URL {
        let trimmed = named.trimmingCharacters(in: .whitespaces)
        guard SaveStore.isExplicitPath(trimmed) else {
            return try savesDirectory(forLabel: named)
        }
        let url = URL(
            fileURLWithPath: (trimmed as NSString).expandingTildeInPath, isDirectory: true)
        guard Self.isDirectory(url) else {
            throw PlaytestError(
                """
                savesFrom "\(named)" holds a slash, so it was read as a path, and \
                \(url.path) is not a directory. Nothing ran. Pass a play label — the name \
                the tester gave `open`, or `bin/playtest-replay --label` — or the path of \
                a directory holding `.gnusto` slots, which for a round already reported is \
                the `saves-in/` directory beside the probe's transcript.
                """)
        }
        return url
    }

    /// What one staging copied in, and what it found already standing there.
    ///
    /// Two lists rather than one, because they answer two different questions.
    /// `copied` is what this call wrote; ``restorable`` is what the destination
    /// can now be told to `restore` by name, and a slot the destination already
    /// held is in the second and not the first. A replay stages into a fresh
    /// throwaway and the two are always the same list, but a label's `saves/`
    /// outlives every probe under it — so the second `open` under one label
    /// stages onto a directory that already holds those names, and a receipt
    /// reading only `copied` would tell that tester its slots had not arrived.
    struct StagedSlots: Sendable {
        /// The directory the slots were read out of.
        let from: URL

        /// What a reader greps a probe tree for, and what `bin/playtest-replay`
        /// records: the shortest name that resolves back to these bytes.
        ///
        /// A label's saves live in `<label>/saves/`, so for that layout the
        /// directory one level up **is** the label and is the right thing to
        /// print. Nothing else is: a probe's own `saves-in/` — the path form,
        /// which is how a round is re-run after its labels are cleaned — would
        /// render as a bare `probe-002`, a name every label in the tree has one
        /// of. That is the un-replayable receipt the path form exists to fix, so
        /// anything not in the label layout prints whole.
        var label: String {
            let parent = from.deletingLastPathComponent()
            return from.lastPathComponent == "saves" ? parent.lastPathComponent : from.path
        }

        /// The names this staging wrote, sorted.
        let copied: [String]

        /// Everything the destination can restore by name, sorted.
        ///
        /// The source's whole list, not a sum of two accumulators: every slot in
        /// the source is either copied or already there, so this *is* what the
        /// destination can restore, and deriving it by adding up the two halves
        /// would be re-deriving a value the staging already held.
        let restorable: [String]

        /// The names the staging left alone because the destination already had
        /// one, sorted. See ``PlaytestSessions/stageSlots(from:into:)`` for why
        /// those are kept rather than replaced.
        var kept: [String] { restorable.filter { !copied.contains($0) } }
    }

    /// Copies a directory of saved games into the save directory a world is
    /// about to be played out of.
    ///
    /// **One way, by construction.** The destination is the directory the
    /// caller is about to hand the world — a replay's throwaway, or the label's
    /// `saves/` the session will write its own slots into — and nothing in this
    /// function writes to `source`.
    ///
    /// **An existing destination slot wins and is never overwritten.** For a
    /// replay this cannot arise, because the throwaway is new; for a session it
    /// arises the second time a label is opened with the same `savesFrom`, and
    /// the slot standing there may by then be the tester's own `save` under a
    /// name the source happens to share. Losing that to a staging the tester
    /// did not ask for is worse than staging nothing, so the copy yields and
    /// the name comes back in ``StagedSlots/kept`` — restorable either way,
    /// which is the only thing the caller has to report.
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
    ///   - source: a directory of saved games — a label's `saves/`, or the
    ///     `saves-in/` an earlier staged probe kept.
    ///   - destination: the save directory to stage into, which may not exist
    ///     yet.
    /// - Throws: ``PlaytestError`` when the source holds no slots.
    /// - Returns: what was copied and what was already there.
    static func stageSlots(from source: URL, into destination: URL) throws -> StagedSlots {
        let slots = SaveStore.existingSaveNames(in: source)
        guard !slots.isEmpty else {
            throw PlaytestError(
                """
                savesFrom names \(source.path), which holds no saved games. Nothing ran. \
                A session opened onto a round's slots, and a reproducer whose first \
                command is `restore`, both need a slot somebody wrote — and nothing \
                wrote one there. Check the label; for a round, `bin/playtest-slots \
                <Game>` is what cuts them, and `bin/playtest-preflight` says when it \
                needs to.
                """)
        }
        // Through the save store both ways, so the extension and the 0700 the
        // destination is created with stay in the one file that owns them:
        // `resolveForWrite` *is* the make-the-directory-then-resolve pair, and
        // the names came out of `resolve`'s own sanitizer to begin with.
        // One `readdir` of the destination rather than a `stat` per slot, which on
        // a round's eight staged sessions is eight calls where it was seventy-two.
        let already = Set(SaveStore.existingSaveNames(in: destination))
        var copied: [String] = []
        for slot in slots where !already.contains(slot) {
            try FileManager.default.copyItem(
                at: SaveStore.resolve(slot, in: source),
                to: try SaveStore.resolveForWrite(slot, in: destination))
            copied.append(slot)
        }
        return StagedSlots(from: source, copied: copied, restorable: slots)
    }

    /// Whether a URL names a directory that exists.
    ///
    /// The `ObjCBool` dance written once. Both callers here are guards on a name
    /// a caller supplied, and neither wants five lines of ceremony to say so.
    private static func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    /// A label's own directory under the root.
    private static func directory(forLabel label: String, under root: URL) -> URL {
        root.appendingPathComponent(label, isDirectory: true)
    }

    /// Where a label's saves live: beside its probes, not inside one.
    ///
    /// Two readers — `open`, which creates it, and ``savesDirectory(forLabel:)``,
    /// which hands it to a replay — and one spelling, because this actor's whole
    /// documented job is that one type owns the disk layout.
    private static func savesDirectory(under labelDirectory: URL) -> URL {
        labelDirectory.appendingPathComponent("saves", isDirectory: true)
    }

    /// A sentence naming the labels that do exist, for the refusal above.
    ///
    /// The same courtesy ``session(_:)`` pays a mistyped session id: the caller
    /// is a language model that got a name slightly wrong, and the list is
    /// usually enough for it to fix that without another round trip.
    ///
    /// - Parameter root: the play-test root.
    /// - Returns: one sentence, always terminated.
    private static func labelsOnDisk(under root: URL) -> String {
        let labels =
            ((try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? [])
            .filter { isPlainName($0) }
            .sorted()
        return labels.isEmpty
            ? "Nothing is labelled there yet."
            : "Labels there now: \(labels.joined(separator: ", "))."
    }

    // MARK: - Eviction

    /// Notes that a session was just reached for, and that it therefore holds
    /// (or is about to hold) a live world.
    private func touch(_ id: String) {
        clock += 1
        lastUsed[id] = clock
        live.insert(id)
    }

    /// Evicts least-recently-used sessions until the live count is back inside
    /// the cap.
    ///
    /// Eviction is *not* expiry. The session keeps its id, its files, its seed
    /// and its command list, and replays itself the next time anybody touches
    /// it — so the caller sees a slightly slower call and never an error. That
    /// is only sound because a Gnusto game is deterministic under a pinned
    /// seed, which is the same property the whole harness rests on.
    ///
    /// A session that used `save` or `restore` refuses, and is skipped: its run
    /// depends on a file the replay does not control. If every live session is
    /// pinned the cap is simply exceeded, with a word on standard error — the
    /// alternative would be evicting a session that cannot come back correctly,
    /// which trades a memory bound for a wrong transcript.
    private func evictIfNeeded() async {
        while live.count > maxSessions {
            var evicted = false
            for id in live.sorted(by: { lastUsed[$0, default: 0] < lastUsed[$1, default: 0] }) {
                guard let session = sessions[id] else {
                    live.remove(id)
                    evicted = true
                    break
                }
                if await session.evict() {
                    live.remove(id)
                    writeToStandardError(
                        """
                        [gnusto-mcp] evicted session \(id) to stay under \
                        GNUSTO_MCP_MAX_SESSIONS=\(maxSessions); it will replay from its \
                        command list on next use.
                        """)
                    evicted = true
                    break
                }
            }
            guard evicted else {
                writeToStandardError(
                    """
                    [gnusto-mcp] \(live.count) live sessions over a cap of \(maxSessions), \
                    but every one of them has used save or restore and cannot be replayed \
                    safely. Keeping them all.
                    """)
                return
            }
        }
    }

    // MARK: - The environment, and the disk

    /// Where sessions write. `GNUSTO_PLAYTEST_DIR` overrides, on the
    /// precedent of `GNUSTO_SAVE_DIR` and `GNUSTO_TRANSCRIPT_DIR` and for the
    /// same reason — a test, or a harness driving a checkout it doesn't own,
    /// must be able to keep its output away from the developer's.
    ///
    /// - Parameter environment: the process environment.
    /// - Returns: the play-test root directory.
    private static func root(environment: [String: String]) -> URL {
        if let override = environment["GNUSTO_PLAYTEST_DIR"], !override.isEmpty {
            return URL(
                fileURLWithPath: (override as NSString).expandingTildeInPath,
                isDirectory: true)
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            .appendingPathComponent(".context", isDirectory: true)
            .appendingPathComponent("playtest", isDirectory: true)
    }

    /// The live-session cap from `GNUSTO_MCP_MAX_SESSIONS`.
    ///
    /// A whole number above zero, or the default with a complaint — the
    /// `SeedRequest` policy: say what was ignored rather than quietly doing
    /// something else.
    ///
    /// - Parameter environment: the process environment.
    /// - Returns: the cap.
    private static func maxSessions(environment: [String: String]) -> Int {
        guard let raw = environment["GNUSTO_MCP_MAX_SESSIONS"],
            !raw.trimmingCharacters(in: .whitespaces).isEmpty
        else {
            return defaultMaxSessions
        }
        guard let value = Int(raw.trimmingCharacters(in: .whitespaces)), value > 0 else {
            writeToStandardError(
                """
                Ignoring GNUSTO_MCP_MAX_SESSIONS=\(raw): expected a whole number above zero. \
                Using \(defaultMaxSessions).
                """)
            return defaultMaxSessions
        }
        return value
    }

    /// Takes the next free probe directory under a label.
    ///
    /// `mkdir` is the lock, as in `bin/playtest-replay`: creating a directory
    /// fails if it already exists and fails atomically, so two sessions opening
    /// at the same instant cannot both take `probe-001` — the loser sees the
    /// failure and moves on to `probe-002`. Nothing here overwrites: a probe
    /// directory belongs to exactly one run, forever, because a transcript is
    /// evidence and evidence that quietly became somebody else's session is
    /// worse than evidence that was lost noisily.
    ///
    /// - Parameter labelDirectory: the label's directory, already created.
    /// - Throws: ``PlaytestError`` when the label is full.
    /// - Returns: the probe's name and its directory.
    private static func allocateProbe(in labelDirectory: URL) throws -> (String, URL) {
        for number in 1...probeLimit {
            let name = String(format: "probe-%03d", number)
            let directory = labelDirectory.appendingPathComponent(name, isDirectory: true)
            // `withIntermediateDirectories: false` is what makes this a lock:
            // with it true, an existing directory is a success.
            if (try? FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: false)) != nil
            {
                return (name, directory)
            }
        }
        throw PlaytestError(
            """
            \(probeLimit) probes already under \(labelDirectory.path). Open the next \
            session under a fresh label.
            """)
    }

    /// Whether a name is safe as one path component.
    ///
    /// The same alphabet `bin/playtest-replay`'s `plain_name` enforces, and for
    /// the same reasons: it must not escape the play-test root, and its first
    /// character may not be a dot — that is what keeps a label out of `.bin`,
    /// the build-path cache the script keeps beside the labels.
    ///
    /// - Parameter name: the candidate.
    /// - Returns: true when it may become a directory name.
    private static func isPlainName(_ name: String) -> Bool {
        let start = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")
        let rest = start.union(".")
        guard let first = name.first, start.contains(first), name.count <= 64 else {
            return false
        }
        return name.dropFirst().allSatisfy(rest.contains)
    }
}
