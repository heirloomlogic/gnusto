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
    ///
    /// `--mcp` (or `GNUSTO_MCP`) takes the other branch entirely: the process
    /// becomes a play-test server speaking MCP on stdio and never builds a
    /// world here, because the server builds one `PreparedGame` and spins a
    /// world per session. Since every game is `@main struct G: Game, GameMain`,
    /// putting the switch here makes every game that has ever been written
    /// with this engine — including one whose author has never heard of the
    /// play-test harness — reachable by an agent for the cost of one
    /// `.mcp.json` entry. See `PlaytestMode` and `PlaytestServer.serve`.
    ///
    /// That branch exists only when the package's `Playtest` trait is enabled,
    /// which it is by default. Without it the harness is not in the binary and
    /// the request is refused on standard error, rather than answered by
    /// playing the game at a client writing JSON-RPC into its stdin.
    public static func main() async {
        let environment = ProcessInfo.processInfo.environment
        if PlaytestMode.requested(arguments: CommandLine.arguments, environment: environment) {
            #if Playtest
            await PlaytestServer.serve(game: Self.init, environment: environment)
            return
            #else
            writeToStandardError(PlaytestMode.unavailable)
            exit(1)
            #endif
        }
        do {
            let seed = SeedRequest(environment: environment)
            let status = StatusFooter(environment: environment)
            // Unpinned runs go through the unseeded initializer rather than
            // repeating its `UInt64.random` here, so "random by default" stays
            // one policy in one place.
            let world =
                try seed.value.map { try GameWorld(game: Self(), seed: $0) }
                ?? GameWorld(game: Self())
            // Opens (and, on success, immediately closes) the launch
            // transcript file now, while a failure can still be reported —
            // see the comment below on why that reporting has to happen
            // before the IO handler exists.
            let transcript = TranscriptRequest(gameTitled: world.definition.title, environment: environment)
            // Surface non-fatal bootstrap warnings before the IO handler is
            // built: the full-screen `TerminalIOHandler` enters the alternate
            // screen buffer in its `init`, so a stderr write after that would be
            // painted over. Printing here keeps it on the primary screen, and
            // out of the play transcript (stderr, like the fatal path below).
            if let complaint = seed.complaint {
                writeToStandardError(complaint)
            }
            if let complaint = status.complaint {
                writeToStandardError(complaint)
            }
            if let complaint = transcript.complaint {
                writeToStandardError(complaint)
            }
            if let report = world.definition.warningReport {
                writeToStandardError(report)
            }
            await Self.run(
                world: world,
                io: await defaultIOHandler(world: world, environment: environment),
                transcriptURL: transcript.url,
                status: status.inForce)
        } catch {
            writeToStandardError("\(error)")
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
    ///   - status: a `[status]` footer to append to every turn, or `nil`.
    static func run(
        world: GameWorld, io: some IOHandler, transcriptURL: URL? = nil,
        status: StatusFooter? = nil
    ) async {
        await REPL(world: world, io: io, transcriptURL: transcriptURL, status: status).run()
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
