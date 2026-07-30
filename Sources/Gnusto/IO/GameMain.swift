import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Boots a `Game` type as a runnable program: `@main struct Zork1: Game,
/// GameMain {}` is a complete executable, no `main.swift` required.
///
/// ```swift
/// @main struct Zork1: Game, GameMain {}
/// ```
public protocol GameMain {
    /// Every `Game` conformance already has this from Swift's synthesized
    /// memberwise/default init; `GameMain` only reuses it to construct the
    /// instance `main()` runs.
    init()
}

extension GameMain where Self: Game {
    /// The entry point Swift's `@main` attribute calls. Builds the world
    /// from `Self()`, then drives it with a console-backed `REPL` until the
    /// game ends or input runs out.
    ///
    /// Bootstrap failures (an invalid game definition) are reported to
    /// standard error and exit the process with a nonzero status, the same
    /// as a hand-written `main.swift` would.
    public static func main() async {
        do {
            let environment = ProcessInfo.processInfo.environment
            let seed = SeedRequest(environment: environment)
            // Unpinned runs go through the unseeded initializer rather than
            // repeating its `UInt64.random` here, so "random by default" stays
            // one policy in one place.
            let world =
                try seed.value.map { try GameWorld(game: Self(), seed: $0) }
                ?? GameWorld(game: Self())
            // Surface non-fatal bootstrap warnings before the IO handler is
            // built: the full-screen `TerminalIOHandler` enters the alternate
            // screen buffer in its `init`, so a stderr write after that would be
            // painted over. Printing here keeps it on the primary screen, and
            // out of the play transcript (stderr, like the fatal path below).
            if let complaint = seed.complaint {
                FileHandle.standardError.write(Data("\(complaint)\n".utf8))
            }
            if let report = world.definition.warningReport {
                FileHandle.standardError.write(Data("\(report)\n".utf8))
            }
            await Self.run(
                world: world,
                io: await defaultIOHandler(world: world, environment: environment),
                transcriptURL: transcriptURL(world: world, environment: environment))
        } catch {
            // `FileHandle.standardError`, not the libc `stderr` global, which
            // Swift 6 rejects as concurrency-unsafe on Linux (it's a `var`).
            FileHandle.standardError.write(Data("\(error)\n".utf8))
            exit(1)
        }
    }

    /// The boot logic factored out of `main()` so it can run against any
    /// `IOHandler` — a `ScriptedIOHandler` in tests, `ConsoleIOHandler` at
    /// runtime — without a live console or stdin.
    ///
    /// - Parameters:
    ///   - world: the world to drive.
    ///   - io: the IO handler for input and output.
    ///   - transcriptURL: a file to record the whole session to, or `nil`.
    static func run(world: GameWorld, io: some IOHandler, transcriptURL: URL? = nil) async {
        await REPL(world: world, io: io, transcriptURL: transcriptURL).run()
    }

    /// The transcript file to record from launch, from `GNUSTO_TRANSCRIPT`: a
    /// path-like value records there; a bare flag (`1`, `on`, `true`, `yes`)
    /// records to a timestamped default in the game's transcripts directory;
    /// unset records nothing (the tester can still start with `script`).
    ///
    /// - Parameters:
    ///   - world: the world whose title names the default file.
    ///   - environment: the environment to read `GNUSTO_TRANSCRIPT` from.
    /// - Returns: the transcript file URL, or `nil` when unset.
    private static func transcriptURL(
        world: GameWorld, environment: [String: String]
    ) -> URL? {
        guard let value = environment["GNUSTO_TRANSCRIPT"], !value.isEmpty else { return nil }
        let flags: Set<String> = ["1", "on", "true", "yes"]
        let name = flags.contains(value.lowercased()) ? nil : value
        return TranscriptStore.url(
            forName: name, gameTitled: world.definition.title, environment: environment)
    }

    /// The full-screen `TerminalIOHandler` when stdin and stdout are both an
    /// interactive terminal, else the plain `ConsoleIOHandler`. The TTY check
    /// keeps piped input, redirected output, CI, and transcript tests on the
    /// plain path; `GNUSTO_PLAIN` forces it for anyone who wants it — any
    /// value at all, including an empty one, since it is a flag rather than a
    /// setting. The terminal handler gets the world's history file so it can
    /// persist and reload commands across sessions.
    ///
    /// - Parameters:
    ///   - world: the world whose history file the terminal handler uses.
    ///   - environment: the environment to read `GNUSTO_PLAIN` from.
    /// - Returns: the handler to drive the session with.
    private static func defaultIOHandler(
        world: GameWorld, environment: [String: String]
    ) async -> any IOHandler {
        let forcedPlain = environment["GNUSTO_PLAIN"] != nil
        let interactive = isatty(STDIN_FILENO) == 1 && isatty(STDOUT_FILENO) == 1
        guard interactive && !forcedPlain else { return ConsoleIOHandler() }
        return TerminalIOHandler(historyURL: await world.historyFileURL)
    }
}

/// What `GNUSTO_SEED` asked of the random stream.
///
/// A game draws every random value — combat rolls, roaming actors, `oneOf`
/// prose — from one seeded stream (`WorldState/rngState`), so pinning the seed
/// makes a whole session replay identically. `play(_:_:seed:)` already does
/// that in the test suite; this is the same knob for a built binary, so a
/// transcript a tester records by hand becomes a reproducer someone else can
/// replay.
///
/// A bad value is reported rather than ignored. The variable exists for
/// reproducibility, so silently handing back a random stream after a typo
/// would defeat the one thing it is for.
enum SeedRequest: Equatable {
    /// `GNUSTO_SEED` was unset, empty, or whitespace: seed randomly, as ever.
    case unset

    /// A seed to pin the stream to.
    case pinned(UInt64)

    /// A value that isn't a `UInt64`, kept verbatim so the complaint can quote
    /// what the operator actually typed.
    case invalid(String)

    /// Reads `GNUSTO_SEED`, tolerating the stray whitespace a shell wrapper or
    /// a copied-and-pasted value tends to bring with it.
    init(environment: [String: String]) {
        let value = environment["GNUSTO_SEED", default: ""]
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            self = .unset
            return
        }
        self = UInt64(trimmed).map { .pinned($0) } ?? .invalid(value)
    }

    /// The seed to hand `GameWorld`, or `nil` to let it pick one at random.
    var value: UInt64? {
        guard case .pinned(let seed) = self else { return nil }
        return seed
    }

    /// What to tell the operator on standard error, or `nil` when there is
    /// nothing to say.
    var complaint: String? {
        guard case .invalid(let value) = self else { return nil }
        return """
            Ignoring GNUSTO_SEED=\(value): expected a whole number from 0 to \
            \(UInt64.max). Seeding at random instead.
            """
    }
}
