/// Thrown by `refuse`, `reply`, `handled`, `end`, and `die` to redirect the turn;
/// caught by the engine, never seen by author code.
enum TurnInterrupt: Error {
    case refused(message: String)
    case replied(message: String)
    case gameOver(won: Bool)
    case died(message: String)

    /// Stage 4 had no answer at all: a verb row produced this intent, so the
    /// parser understood the sentence, but no action, no rule and no stub line
    /// claims it. Mechanically a `refuse` that costs nothing — the player is
    /// told the game has no answer for them, and the world does not move on
    /// the strength of a non-event.
    case unhandled(message: String)
}

/// Prints a message as part of the turn's output.
///
/// - Parameter message: the text to print.
public func say(_ message: String) {
    Ctx.current.say(message)
}

/// Prints a message unless this turn has already printed exactly it.
///
/// For a sentence more than one emitter can have a claim on in one turn. The
/// engine's own case is the dark: the room describer prints
/// ``GameText/pitchBlack`` because a dark room has nothing else to describe,
/// and `GnustoDangerousDark`'s grue prints its warning because the fairness
/// contract owes the player a warned turn. Zork points both at one sentence and
/// gets it once; a game that words them differently gets both lines, because
/// what is compared is the text and not the situation.
///
/// The memory is this turn only, and dropping a line changes nothing else — a
/// schedule that counted the turn has still counted it.
///
/// - Parameter message: the text to print at most once this turn.
public func sayOnceThisTurn(_ message: String) {
    Ctx.current.sayOnceThisTurn(message)
}

/// Prints a message only if the player is standing in a room it is true of.
///
/// The line a **timer** wants. A fuse or a daemon fires on a schedule, not on a
/// place, so the room the player is in when the body runs is whatever room they
/// walked to — and a sentence that narrates something happening *here* is a
/// claim about a frame the body never read. This is that read, written once:
///
/// ```swift
/// fuse("exorcismLapse", after: 6) {
///     exorcismStage = 0                        // the world moves regardless…
///     say(Prose.exorcismLapses, from: gate)    // …the telling does not
/// }
/// ```
///
/// Dropping the line changes nothing else, exactly as ``sayOnceThisTurn(_:)``
/// does: put the state change above the `say` and it happens either way.
///
/// **Variadic, because a noise carries.** A sentence about a reservoir emptying
/// is true from either bank and from the bed between them, so name all three;
/// the line prints from any of them and nowhere else. There is no earshot
/// radius in the engine and this is deliberately not one — it is the author
/// enumerating the frames their sentence is true in.
///
/// **Standing in the room, not seeing it.** Darkness does not gate this one — a
/// bell rung in an unlit room is still heard from inside it. For a sentence the
/// player has to *see* to believe ("the candles are shorter now"), pass the
/// thing instead of the room: the ``Item`` overload asks ``Item/isVisible``,
/// which the dark does gate.
///
/// - Parameters:
///   - message: the text to print.
///   - sources: the rooms the message is true in.
public func say(_ message: String, from sources: Location...) {
    // The frame is bound once and the ids resolved off it, rather than through
    // each `Location.id`: that accessor reaches `Ctx.current` per source, which
    // is a lock apiece for a question one lock can answer. Resolution stays
    // *outside* `with { }` — the `Mutex` is not reentrant.
    let frame = Ctx.current
    let here = frame.with { $0.state.playerLocation }
    guard sources.contains(where: { frame.id(for: $0.token, describing: "Location") == here })
    else { return }
    frame.say(message)
}

/// Prints a message only if the player can currently see the thing it is about.
///
/// The ``Location`` overload above, for a sentence whose subject is an
/// object rather than a room — a candle burning down, a bell cooling, a fuse
/// reaching its charge. Gated on ``Item/isVisible``, so what the player is
/// carrying always qualifies (the dark included) and what they left three rooms
/// back never does.
///
/// Read *before* the state changes, if the change is what puts the thing out of
/// sight: a candle that has already gone out lights nothing, itself included, so
/// `say(…, from: candles)` must come above `candles.isLit = false` or the last
/// stage of the burn goes unreported.
///
/// - Parameters:
///   - message: the text to print.
///   - source: the thing the message is about.
public func say(_ message: String, from source: Item) {
    guard source.isVisible else { return }
    Ctx.current.say(message)
}

/// Prints a message only if the player can currently see the person it is
/// about — the ``Item`` overload, for an actor.
///
/// - Parameters:
///   - message: the text to print.
///   - source: the person the message is about.
public func say(_ message: String, from source: Actor) {
    guard source.isVisible else { return }
    Ctx.current.say(message)
}

/// Blocks the current action with a complaint. The default action and any
/// remaining `before`/`after` rules are skipped; world time still passes.
///
/// Returns `Never`, so it satisfies `guard … else { try refuse("…") }`.
///
/// - Parameter message: the complaint shown to the player.
/// - Throws: the turn interrupt the engine catches to redirect the turn.
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
///
/// - Parameters:
///   - condition: the requirement that must hold.
///   - message: the refusal shown when it doesn't. Not built on the turns the
///     requirement holds: this is the one refusal sink whose message is usually
///     *not* printed, and a stock line may be a ``GameText/Line/live(_:)`` that
///     goes looking around the room to word itself.
/// - Throws: the turn interrupt the engine catches when the condition fails.
public func require(_ condition: Bool, else message: @autoclosure () -> String) throws {
    guard condition else {
        try refuse(message())
    }
}

/// Fully handles the current action with a response, skipping the default
/// behavior. Mechanically identical to `refuse(_:)` — two names exist so
/// game code reads correctly: `refuse` for "no, you can't", `reply` for
/// "here's what happens instead".
///
/// Use ``handled()`` to end the turn without adding a line after a body has
/// already said everything with `say(_:)`.
///
/// - Parameter message: the response shown to the player.
/// - Throws: the turn interrupt the engine catches to redirect the turn.
public func reply(_ message: String) throws -> Never {
    throw TurnInterrupt.replied(message: message)
}

/// Fully handles the current action without adding a line, skipping the
/// default behavior and any remaining rules. Use it after a body has already
/// said everything with `say(_:)`.
///
/// - Throws: the turn interrupt the engine catches to redirect the turn.
public func handled() throws -> Never {
    throw TurnInterrupt.replied(message: "")
}

/// Ends the game. The engine prints the final score after the turn's output.
///
/// - Parameter won: whether the player won.
/// - Throws: the turn interrupt the engine catches to end the game.
public func end(won: Bool) throws -> Never {
    throw TurnInterrupt.gameOver(won: won)
}

/// Kills the player: prints the message, then the game's ``Game/onDeath()``
/// handler runs. Unless that handler consumes the death (resurrection), the
/// engine prints the death banner, reports the score, and offers RESTART /
/// RESTORE / UNDO / QUIT — the program keeps running until the player picks
/// an exit. Distinct from `end(won:)`, which finishes the game outright.
///
/// - Parameter message: the death message shown to the player.
/// - Throws: the turn interrupt the engine catches to kill the player.
public func die(_ message: String) throws -> Never {
    throw TurnInterrupt.died(message: message)
}

/// Describes the player's current surroundings, verbose — as if the player
/// had typed LOOK. For rule and daemon bodies that change where the player
/// is or what they can see ("The current carries the boat downstream.") and
/// want the classic follow-up description. Safe in darkness (prints the
/// pitch-black line); marks the room visited exactly as a real LOOK would.
///
/// Pass `withRoomName: false` when the player has moved *within* a single room
/// rather than between rooms — a square of a sliding-block floor, a step along a
/// ledge the map models as one place. The room's name is a heading announcing
/// arrival somewhere; reprinting it on every step says the player arrived
/// nineteen times in a room they never left. Everything else — the long
/// description, the item paragraphs, the people — prints as usual:
///
/// ```swift
/// puzzle.before(.go) {
///     // …walk one square of the grid…
///     describeSurroundings(withRoomName: false)
///     try handled()
/// }
/// ```
///
/// - Parameter withRoomName: whether to open with the room's name. Defaults to
///   true, which is a full LOOK.
public func describeSurroundings(withRoomName: Bool = true) {
    RoomDescriber.describeCurrentLocation(
        mode: .look, withRoomName: withRoomName, frame: Ctx.current)
}

/// Puts the player somewhere else and describes where they have got to — the
/// teleport and the look, which is what every rule that moves the player
/// without a `go` has to do:
///
/// ```swift
/// mirror.before(.touch) {
///     say("The room spins, and settles the other way round.")
///     arrive(at: mirrorRoomSouth)
///     try handled()
/// }
/// ```
///
/// It does **not** end the turn, so it is legal in an `after` rule or a daemon
/// as well as a `before` one, and the caller says how the turn finishes:
/// `try handled()` for a rule whose whole answer is the new room, `try
/// reply(_:)` with a line to trail one after it, or plain `return` from a
/// daemon.
///
/// Assigning ``Player/location`` is what this does, so — as with any move that
/// is not a `go` — the destination's `onEnter` rules **do not run**, and a
/// boarded vehicle stays where it was. A rule that teleports into a room which
/// kills, scores or announces on arrival has to say so itself.
///
/// That is a choice rather than a limitation: ``enter(_:)`` is the move that
/// *does* run them. Reach for this one when you mean a teleport with no side
/// effects, and for that one when you mean the player walked in.
///
/// Pass `withRoomName: false` when the player has moved *within* one room
/// rather than between two: see ``describeSurroundings(withRoomName:)``, whose
/// note on reprinting the heading applies here unchanged.
///
/// - Parameters:
///   - room: where the player ends up.
///   - withRoomName: whether to open with the room's name. Defaults to true.
public func arrive(at room: Location, withRoomName: Bool = true) {
    // `player` is a member of `Game`/`GameContent`/`GamePlugin` rather than a
    // free binding, so a free function spells it out. Same value, same setter.
    Player().location = room
    describeSurroundings(withRoomName: withRoomName)
}

/// Walks the player into `room` — everything a `go` through an exit does once
/// the exit itself has passed:
///
/// ```swift
/// stairs.before(.climb) {
///     say("You haul yourself up.")
///     try enter(belfry)
///     try handled()
/// }
/// ```
///
/// Three things separate it from ``arrive(at:withRoomName:)``:
///
/// - the destination's `onEnter` rules **run**, before the room is described,
/// - a boarded vehicle comes along, and its cargo with it,
/// - the room is described as an **entry** rather than as a LOOK, so a room
///   already visited is described briefly. A room whose description *is* its
///   state wants `alwaysDescribed`, exactly as it does for a walked arrival.
///
/// Like `arrive(at:)` it does **not** end the turn, so it is as legal in an
/// `after` rule or a daemon as in a `before` one, and the caller says how the
/// turn finishes.
///
/// It `throws` because the rules it runs may: an `onEnter` that ``die(_:)``s or
/// ``refuse(_:)``s ends the turn from inside the move, and the room is then
/// never described. The move itself has already committed by then — the same
/// order a real `go` uses — so a refusing `onEnter` leaves the player standing
/// in the room that refused them.
///
/// One sharp edge, since the rules are yours: an `onEnter` rule that calls
/// `enter(_:)` back into its own room re-enters the move that is running it. The
/// engine counts that nesting and traps a few levels down with a message naming
/// the room, rather than letting the stack give out unattributed — but the trap
/// is a diagnostic, not a feature. Move the player *out* of a room from its
/// rules, never into it.
///
/// - Parameter room: where the player walks in.
/// - Throws: whatever the destination's `onEnter` rules throw — a `die`, a
///   `refuse` or a `reply` ends the turn from inside the move.
public func enter(_ room: Location) throws {
    // `resolved` binds the frame and the id together, because resolving an id
    // takes the frame lock and so can't happen inside one of `enter`'s own
    // mutations.
    let (frame, id) = room.resolved
    try DefaultActions.enter(id, frame: frame)
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
