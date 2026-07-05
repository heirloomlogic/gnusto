/// Thrown by `refuse`, `reply`, `end`, and `die` to redirect the turn;
/// caught by the engine, never seen by author code.
enum TurnInterrupt: Error {
    case refused(message: String)
    case replied(message: String)
    case gameOver(won: Bool)
    case died(message: String)
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

/// Refuses the current action with `message` unless `condition` holds —
/// `guard … else { try refuse(…) }`, in one call:
///
/// ```swift
/// try require(player.location == cloakroom, else: "This isn't the best place…")
/// ```
///
/// Shares nothing with Swift Testing's `#require` macro (different
/// namespaces; that one lives in test targets and traps the test on
/// failure) — this one is ordinary game-rule flow control.
public func require(_ condition: Bool, else message: String) throws {
    guard condition else {
        try refuse(message)
    }
}

/// Fully handles the current action with a response, skipping the default
/// behavior. Mechanically identical to `refuse(_:)` — two names exist so
/// game code reads correctly: `refuse` for "no, you can't", `reply` for
/// "here's what happens instead".
///
/// `reply("")` ends the turn without adding a line — for bodies that have
/// already said everything with `say(_:)`.
public func reply(_ message: String) throws -> Never {
    throw TurnInterrupt.replied(message: message)
}

/// Ends the game. The engine prints the final score after the turn's output.
public func end(won: Bool) throws -> Never {
    throw TurnInterrupt.gameOver(won: won)
}

/// Kills the player: prints the message, then the game's ``Game/onDeath()``
/// handler runs. Unless that handler consumes the death (resurrection), the
/// engine prints the death banner, reports the score, and offers RESTART /
/// RESTORE / UNDO / QUIT — the program keeps running until the player picks
/// an exit. Distinct from `end(won:)`, which finishes the game outright.
public func die(_ message: String) throws -> Never {
    throw TurnInterrupt.died(message: message)
}

/// Describes the player's current surroundings, verbose — as if the player
/// had typed LOOK. For rule and daemon bodies that change where the player
/// is or what they can see ("The current carries the boat downstream.") and
/// want the classic follow-up description. Safe in darkness (prints the
/// pitch-black line); marks the room visited exactly as a real LOOK would.
public func describeSurroundings() {
    RoomDescriber.describeCurrentLocation(mode: .look, frame: Ctx.current)
}

/// Runs the stage-4 default action (a game/plugin override if one is
/// registered for this intent, else the built-in) immediately, then returns
/// so the calling rule can embellish the result — print something more, read
/// state the default action changed, and so on.
///
/// Callable from any stage 1–3 `before`-phase rule — `world.before`,
/// `location.beforeEachTurn`, `location.before`, or `item.before`, on either
/// the indirect or direct object — and only once per turn. `proceed()` means
/// "run the default now; I take responsibility": once it runs, the pipeline
/// skips its own stage-4 step (so the default doesn't run twice) *and*
/// skips every remaining before rule still ahead of the calling rule in this
/// turn's sequence — including later rules in the same before-phase, not just
/// later phases. A guard written as a later `before` rule — whether a sibling
/// in the same phase or an `item.before` rule on the direct object when
/// `proceed()` was called from `world.before` — never gets to run, so it
/// can't refuse an action that has already happened. Calling it from an `after`/each-turn
/// rule, or calling it twice, is a programmer error and traps with a clear
/// message rather than silently double-running the default action.
///
/// ```swift
/// mailbox.before(.open) {
///     try proceed()                    // built-in open runs here
///     say("A city map is tucked inside the lid.")
/// }
/// ```
///
/// If the default action throws (e.g. a built-in `open` refuses because the
/// item is locked), that `TurnInterrupt` propagates out of `proceed()`
/// exactly as it would have out of the pipeline's own stage 4.
public func proceed() throws {
    try Ctx.current.proceedToDefaultAction()
}
