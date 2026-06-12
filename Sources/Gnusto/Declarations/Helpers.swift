/// Thrown by `refuse`, `reply`, and `end` to redirect the turn; caught by
/// the engine, never seen by author code.
enum TurnInterrupt: Error {
    case refused(message: String)
    case replied(message: String)
    case gameOver(won: Bool)
}

/// Prints a message as part of the turn's output.
public func say(_ message: String) {
    Ctx.current.say(message)
}

/// Blocks the current action with a complaint. The default action and any
/// remaining `before`/`after` rules are skipped; world time still passes.
///
/// Returns `Never`, so it satisfies `guard … else { try refuse("…") }`.
public func refuse(_ message: String) throws -> Never {
    throw TurnInterrupt.refused(message: message)
}

/// Fully handles the current action with a response, skipping the default
/// behavior. Mechanically identical to `refuse(_:)` — two names exist so
/// game code reads correctly: `refuse` for "no, you can't", `reply` for
/// "here's what happens instead".
public func reply(_ message: String) throws -> Never {
    throw TurnInterrupt.replied(message: message)
}

/// Ends the game. The engine prints the final score after the turn's output.
public func end(won: Bool) throws -> Never {
    throw TurnInterrupt.gameOver(won: won)
}
