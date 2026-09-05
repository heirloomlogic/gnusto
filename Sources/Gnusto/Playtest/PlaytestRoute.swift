// Gated on the `Playtest` package trait. See `Package.swift`.
#if Playtest

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
/// .playtest/<TypeName>/routes/<name>.json     one file: { seed, commands, derivedFrom, landing }
/// ```
///
/// A game with no routes needs nothing: `.playtest/` starts empty, testers play
/// cold, and the round's own output is the next round's deep starts.
struct PlaytestRoute: Sendable {
    /// The name the tester passed to `open`, which is also the file stem.
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

    /// Where this route came from, or `nil` when nothing was recorded.
    ///
    /// A distilled route names the **round** it was learned from, which resolves
    /// against the per-round record `.playtest/` also holds. A hand-cut one names
    /// whatever it was cut out of — Dungeon's nine name the walkthrough test and
    /// the index, `DungeonWalkthroughTests.route[0:113]` — because the whole point
    /// of committing a route is that the machinery which produced it can then be
    /// deleted, and a provenance nobody wrote down is deleted with it.
    ///
    /// The engine never resolves the string. It is for a person reading the file.
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
    ///   routes that are in it, for a name that isn't there, a file that is
    ///   unreadable or not JSON, one with no seed, and one with no commands.
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
        let url = directory.appendingPathComponent("\(name).json")

        guard let text = try? String(contentsOf: url, encoding: .utf8),
            let manifest = try? JSONValue(text: text)
        else {
            let known = available(in: directory)
            throw PlaytestError(
                """
                No route "\(name)": nothing readable at \(url.path). \(known) Nothing \
                ran — a session that cannot start where it was told to start would play from \
                turn zero and report on the wrong end of the map.
                """)
        }
        guard let declared = manifest["seed"]?.intValue, declared >= 0 else {
            throw PlaytestError(
                """
                Route "\(name)" declares no seed: \(url.path) needs a \
                "seed" field holding a whole number of zero or more. Nothing ran.
                """)
        }

        // Blank lines are dropped; a `//` or `#` line is kept, because the session
        // records it as a comment that costs no turn and it is how a route explains
        // itself in the operator's transcript.
        let commands =
            (manifest["commands"]?.arrayValue ?? [])
            .compactMap { $0.stringValue }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !commands.isEmpty else {
            throw PlaytestError(
                """
                Route "\(name)" holds no commands: \(url.path) needs a "commands" array \
                with at least one command in it. Nothing ran.
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
    /// - Returns: the directory `<name>.json` sits in.
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
    /// The route stems in a directory, sorted — the names `load` answers to.
    ///
    /// - Parameter directory: the routes directory.
    /// - Returns: the stems, or `[]` for a directory that is missing or holds none.
    static func names(in directory: URL) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? [])
            .filter { $0.hasSuffix(".json") }
            .map { String($0.dropLast(5)) }
            .sorted()
    }

    /// - Parameter directory: the routes directory.
    /// - Returns: one sentence, naming up to eight routes.
    private static func available(in directory: URL) -> String {
        let names = names(in: directory)
        guard !names.isEmpty else {
            return "There are no routes in that directory at all."
        }
        let listed = names.prefix(8).joined(separator: ", ")
        return names.count > 8
            ? "The routes there are: \(listed), and \(names.count - 8) more."
            : "The routes there are: \(listed)."
    }
}

#endif
