import Gnusto

/// Conforming the game to ``GameMain`` and marking it `@main` makes the whole
/// thing a runnable executable — no `main.swift` required. `swift run Lighthouse`
/// to play, or `bin/export-game Lighthouse` to hand someone a single binary.
@main
extension Lighthouse: GameMain {}
