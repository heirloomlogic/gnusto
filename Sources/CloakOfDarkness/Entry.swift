import Gnusto

/// `OperaHouse` itself is `@main`: `GameMain` supplies `main()`, so this file
/// only needs to name the entry point. See `GameMain.swift` for what running
/// the game now does — bootstrap, then drive a console `REPL` exactly as the
/// hand-written version here used to.
@main
extension OperaHouse: GameMain {}
