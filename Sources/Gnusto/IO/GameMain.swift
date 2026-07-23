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
            let world = try GameWorld(game: Self())
            // Surface non-fatal bootstrap warnings before the IO handler is
            // built: the full-screen `TerminalIOHandler` enters the alternate
            // screen buffer in its `init`, so a stderr write after that would be
            // painted over. Printing here keeps it on the primary screen, and
            // out of the play transcript (stderr, like the fatal path below).
            if let report = world.definition.warningReport {
                FileHandle.standardError.write(Data("\(report)\n".utf8))
            }
            await Self.run(
                world: world,
                io: await defaultIOHandler(world: world),
                transcriptURL: transcriptURL(
                    world: world, environment: ProcessInfo.processInfo.environment))
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
    /// plain path; `GNUSTO_PLAIN=1` forces it for anyone who wants it. The
    /// terminal handler gets the world's history file so it can persist and
    /// reload commands across sessions.
    private static func defaultIOHandler(world: GameWorld) async -> any IOHandler {
        let forcedPlain = ProcessInfo.processInfo.environment["GNUSTO_PLAIN"] != nil
        let interactive = isatty(STDIN_FILENO) == 1 && isatty(STDOUT_FILENO) == 1
        guard interactive && !forcedPlain else { return ConsoleIOHandler() }
        return TerminalIOHandler(historyURL: await world.historyFileURL)
    }
}
