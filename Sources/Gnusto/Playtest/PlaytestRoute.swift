import Foundation

/// A deep start: the commands that walk a player to somewhere worth testing, and
/// the manifest saying where that is.
///
/// A round that wants the far end of a map cannot walk there inside a tester's
/// turn budget, so the harness has to be able to put one down deep. It used to do
/// that with saved games — bytes under gitignored `.context/`, cut from a route
/// scraped out of a Swift test literal — and the three things wrong with that are
/// what this type replaces. A fresh checkout held none of the bytes, so every
/// tester's `restore` answered `Restore failed.`, which is a sentence about the
/// harness that reads like a finding about the game and produced four false
/// `not-reproducible` verdicts in one round. The scraper parsed one of the two
/// walkthroughs in this repo. And it required a hand-written winning walkthrough
/// to exist at all, which a downstream author on day one does not have and never
/// will.
///
/// A command list has none of those problems. It is text, so it commits; it says
/// what it is, so nothing has to hash it; and it can simply be run, so
/// **verification is replay** — if a route no longer lands where its manifest
/// claims, the harness can say *the route now ends in a different room* rather
/// than `cut from a1b2c3 — the route is now d4e5f6`.
///
/// ```
/// .playtest/<TypeName>/routes/<name>.txt      the commands, one per line
/// .playtest/<TypeName>/routes/<name>.json     { seed, derivedFrom, landing }
/// ```
///
/// A game with no routes needs nothing: `.playtest/` starts empty, testers play
/// cold, and the round's own output is the next round's deep starts.
struct PlaytestRoute: Sendable {
    /// The name the tester passed to `open`, which is also both file stems.
    let name: String

    /// The commands, in order, exactly as they will be typed. Blank lines are
    /// dropped; a `//` or `#` line is kept, because the session records it as a
    /// comment that costs no turn and it is how a route explains itself in the
    /// operator's transcript.
    let commands: [String]

    /// The seed the route was recorded under. A route replayed at another seed
    /// lands somewhere else — silently, which is the whole danger — so this is
    /// the one manifest field that is required.
    let seed: UInt64

    /// The round a distiller learned this route from, or `nil` for one written
    /// by hand. Resolves against the per-round record `.playtest/` also holds.
    let derivedFrom: String?

    /// The room the manifest says the route ends in, or `nil` when it declares
    /// no landing. Checked by replay at `open`, which is what makes a stale
    /// route an error at the moment it would otherwise mislead a tester.
    let landingRoom: String?

    /// The command the harness appends to every route so that a session opens on
    /// a frame somebody can work from.
    ///
    /// A route ends wherever its last command left the player. `take keys`
    /// prints `Taken.`, which tells a tester nothing about where it is standing
    /// and gives ``CoverageLedger/observeOpening(output:room:)`` no room heading
    /// to harvest — so the opening queue would be seeded from two words. One
    /// `look` makes every route land the same way regardless of who wrote it,
    /// and it is recorded in the session's `turns` like any other line, so the
    /// transcript stays byte-identical to a REPL fed the same list.
    ///
    /// It is the harness's line and not the route's: a route file holds only
    /// what its author or the distiller put there, and anything replaying one to
    /// check its landing has to append this too.
    static let landingProbe = "look"

    /// The whole prefix a session plays before the tester's first turn: the
    /// route, then the landing probe.
    var prefix: [String] { commands + [Self.landingProbe] }

    /// Reads a route off disk.
    ///
    /// - Parameters:
    ///   - name: the route's name, which is both file stems.
    ///   - game: the game type name the routes are filed under.
    ///   - environment: the process environment, for `GNUSTO_PLAYTEST_ROUTES`.
    /// - Throws: ``PlaytestError`` naming the directory it looked in and the
    ///   routes that are in it, for a name that isn't there, a `.txt` with no
    ///   commands in it, a missing or unreadable manifest, or a manifest with no
    ///   seed.
    /// - Returns: the route.
    static func load(
        named name: String, game: String, environment: [String: String]
    ) throws -> PlaytestRoute {
        let directory = root(game: game, environment: environment)
        guard PlaytestSessions.isPlainName(name) else {
            throw PlaytestError(
                """
                Bad route name "\(name)". A route name is a file stem under \
                \(directory.path), so it must start with a letter, digit, underscore or \
                hyphen and hold nothing but those and dots. Nothing ran.
                """)
        }
        let commandsURL = directory.appendingPathComponent("\(name).txt")
        let manifestURL = directory.appendingPathComponent("\(name).json")

        guard let commandsText = try? String(contentsOf: commandsURL, encoding: .utf8) else {
            let known = available(in: directory)
            throw PlaytestError(
                """
                No route "\(name)": nothing to read at \(commandsURL.path). \(known) Nothing \
                ran — a session that cannot start where it was told to start would play from \
                turn zero and report on the wrong end of the map.
                """)
        }
        let commands =
            commandsText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !commands.isEmpty else {
            throw PlaytestError(
                """
                Route "\(name)" holds no commands: \(commandsURL.path) is empty. Nothing ran.
                """)
        }

        guard let manifestText = try? String(contentsOf: manifestURL, encoding: .utf8),
            let manifest = try? JSONValue(text: manifestText)
        else {
            throw PlaytestError(
                """
                Route "\(name)" has no readable manifest at \(manifestURL.path). Every route \
                needs one, because a route is only valid at the seed it was recorded under \
                and one with no declared seed cannot be checked against the session's — it \
                would land somewhere nobody meant, silently. Nothing ran.
                """)
        }
        guard let declared = manifest["seed"]?.intValue, declared >= 0 else {
            throw PlaytestError(
                """
                Route "\(name)"'s manifest declares no seed: \(manifestURL.path) needs a \
                "seed" field holding a whole number of zero or more. Nothing ran.
                """)
        }

        return PlaytestRoute(
            name: name,
            commands: commands,
            seed: UInt64(declared),
            derivedFrom: manifest["derivedFrom"]?.stringValue,
            landingRoom: manifest["landing"]?["room"]?.stringValue)
    }

    /// Where this game's routes live.
    ///
    /// `GNUSTO_PLAYTEST_ROUTES` replaces `.playtest`, on the precedent of
    /// `GNUSTO_PLAYTEST_DIR` and for the same two reasons: a test must not read
    /// the developer's real routes, and a harness driving a checkout it does not
    /// own has to be able to point somewhere else. The `<game>/routes/` tail
    /// still applies under an override, so the keying that keeps a seven-game
    /// package's routes apart is exercised rather than bypassed.
    ///
    /// - Parameters:
    ///   - game: the game type name, from ``PreparedGame/typeName``.
    ///   - environment: the process environment.
    /// - Returns: the directory `<name>.txt` and `<name>.json` sit in.
    static func root(game: String, environment: [String: String]) -> URL {
        let base: URL
        if let override = environment["GNUSTO_PLAYTEST_ROUTES"], !override.isEmpty {
            base = URL(
                fileURLWithPath: (override as NSString).expandingTildeInPath,
                isDirectory: true)
        } else {
            base = URL(
                fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true
            )
            .appendingPathComponent(".playtest", isDirectory: true)
        }
        return
            base
            .appendingPathComponent(game, isDirectory: true)
            .appendingPathComponent("routes", isDirectory: true)
    }

    /// The routes that *are* there, as a sentence.
    ///
    /// The `PlaytestSessions.session(_:)` policy: a caller that named something
    /// wrong is a language model that mistyped, and it can recover from being
    /// told what the right names look like — but only if it is told.
    ///
    /// - Parameter directory: the routes directory.
    /// - Returns: one sentence, naming up to eight routes.
    private static func available(in directory: URL) -> String {
        let names =
            ((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? [])
            .filter { $0.hasSuffix(".txt") }
            .map { String($0.dropLast(4)) }
            .sorted()
        guard !names.isEmpty else {
            return "There are no routes in that directory at all."
        }
        let listed = names.prefix(8).joined(separator: ", ")
        return names.count > 8
            ? "The routes there are: \(listed), and \(names.count - 8) more."
            : "The routes there are: \(listed)."
    }
}
