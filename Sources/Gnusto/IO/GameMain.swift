import Darwin

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
            await Self.run(world: world, io: ConsoleIOHandler())
        } catch {
            fputs("\(error)\n", stderr)
            exit(1)
        }
    }

    /// The boot logic factored out of `main()` so it can run against any
    /// `IOHandler` — a `ScriptedIOHandler` in tests, `ConsoleIOHandler` at
    /// runtime — without a live console or stdin.
    static func run(world: GameWorld, io: some IOHandler) async {
        await REPL(world: world, io: io).run()
    }
}
