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
            await Self.run(world: world, io: defaultIOHandler())
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
    static func run(world: GameWorld, io: some IOHandler) async {
        await REPL(world: world, io: io).run()
    }

    /// The full-screen `TerminalIOHandler` when stdin and stdout are both an
    /// interactive terminal, else the plain `ConsoleIOHandler`. The TTY check
    /// keeps piped input, redirected output, CI, and transcript tests on the
    /// plain path; `GNUSTO_PLAIN=1` forces it for anyone who wants it.
    private static func defaultIOHandler() -> any IOHandler {
        let forcedPlain = ProcessInfo.processInfo.environment["GNUSTO_PLAIN"] != nil
        let interactive = isatty(STDIN_FILENO) == 1 && isatty(STDOUT_FILENO) == 1
        return interactive && !forcedPlain ? TerminalIOHandler() : ConsoleIOHandler()
    }
}
