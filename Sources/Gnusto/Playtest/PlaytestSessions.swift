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
/// ```
///
/// A label is a tester's namespace and a probe is one run; each `open`
/// allocates a fresh probe, so re-using a label never overwrites a transcript
/// somebody cited. Probe allocation uses that script's trick, for the same
/// reason: `mkdir` **is** the lock — it fails when the directory exists, and it
/// fails atomically — and sessions here genuinely run at the same time.
actor PlaytestSessions {
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
    /// - Throws: ``PlaytestError`` for an unusable label or a directory that
    ///   can't be made.
    /// - Returns: the new session.
    func open(label: String, seed: UInt64) async throws -> PlaytestSession {
        guard Self.isPlainName(label) else {
            throw PlaytestError(
                """
                Bad label "\(label)". A label becomes a directory name under \
                \(root.path), so it must start with a letter, digit, underscore or hyphen \
                and hold nothing but those and dots. One label per tester: two testers \
                sharing one share its save slots.
                """)
        }
        let labelDirectory = root.appendingPathComponent(label, isDirectory: true)
        let saveDirectory = labelDirectory.appendingPathComponent("saves", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: saveDirectory, withIntermediateDirectories: true)
        } catch {
            throw PlaytestError("Couldn't create \(saveDirectory.path): \(error)")
        }

        let (probe, directory) = try Self.allocateProbe(in: labelDirectory)
        let id = "\(label)/\(probe)"
        let session = PlaytestSession(
            id: id,
            label: label,
            probe: probe,
            seed: seed,
            prepared: prepared,
            directory: directory,
            saveDirectory: saveDirectory)
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

    /// How many sessions this registry has ever opened. For the suite.
    func count() -> Int {
        sessions.count
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
