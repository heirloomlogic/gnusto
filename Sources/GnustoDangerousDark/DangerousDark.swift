import Gnusto

/// Darkness that kills: a warning on the first consecutive turn the player
/// ends in the dark, a configurable grace period, then death. Add it to a
/// game's `content` block; there is nothing else to wire:
///
/// ```swift
/// let dark = DangerousDark()          // stock prose, one turn of grace
///
/// var content: GameContents {
///     dark
/// }
/// ```
///
/// The daemon counts consecutive turns *ending* in darkness, wherever
/// they're spent — lingering is lethal, movement is not — so the warning
/// turn is a guarantee (the classic fairness contract) and a lightless dash
/// toward daylight can still succeed. Any reachable light resets the count.
///
/// Death is a **dice roll** once the grace runs out, the original's grue:
/// the first dark turn only warns, a configurable grace of guaranteed-safe
/// turns follows, and then every further dark turn rolls `chance(lethality)`
/// to be eaten. The warning is always safe, so a revived player (UNDO) still
/// gets the warning beat before the dice can turn on them again.
///
/// To make the dark harmless for a stretch — a room whose solution is to stand
/// in it on purpose, a scene that should not be interrupted — set
/// ``suspended``. **Do not stop the daemon by name.** `stopDaemon("grue")`
/// freezes the counter at whatever it had reached, so resuming can land the
/// player straight on a dice turn and cost them the warning; suspending resets
/// the count for exactly that reason.
///
/// The daemon is named `"grue"`. Timer names are global, but two instances
/// of `DangerousDark` in one game already collide on their shared `@Global`
/// namespace before the timer name matters — one lethal dark per game.
public struct DangerousDark: GameContent {
    /// Consecutive turns the player has ended in darkness.
    @Global var darkTurns = 0

    /// Set while the dark is harmless: the grue idles, draws no randomness,
    /// and — because the count resets on every suspended turn — resuming
    /// always begins again at the warning.
    ///
    /// ```swift
    /// cryptDoor.after(.close) { dangerousDark.suspended = true }
    /// cryptDoor.after(.open) { dangerousDark.suspended = false }
    /// ```
    @Global public var suspended = false

    let warning: String
    let death: GameText.Line<GameText.Noun?>
    let graceTurns: Int
    let lethality: Int

    /// - Parameters:
    ///   - warning: said on the first turn that ends in darkness — and said
    ///     *once*, so a game that also points `text.pitchBlack` at this sentence
    ///     (Zork does: there, the dark-room line is the threat) reads it a
    ///     single time on the turn it walks into the dark. Two different
    ///     sentences are two different sentences, and both print.
    ///   - death: the `die(_:)` message, handed the **vehicle the player was
    ///     aboard** — or nothing, when they were on their own feet. Write it
    ///     with `.naming(orBare:)`; see ``timers`` for why it takes a subject
    ///     at all.
    ///   - graceTurns: guaranteed-safe dark turns after the warning — warn on
    ///     dark turn 1, safe through dark turn `graceTurns + 1`, then dice.
    ///   - lethality: per-turn percent chance of death once the dice begin (on
    ///     dark turn `graceTurns + 2` and every dark turn after).
    public init(
        warning: String = "The darkness is absolute, and something in it is breathing.",
        death: GameText.Line<GameText.Noun?> =
            "Something in the dark finds you before you find it.",
        graceTurns: Int = 1,
        lethality: Int = 50
    ) {
        self.warning = warning
        self.death = death
        self.graceTurns = graceTurns
        self.lethality = lethality
    }

    /// The grue daemon: each dark turn ticks the counter. The warning prints on
    /// the first dark turn; dark turns 2…`graceTurns + 1` are a silent grace;
    /// from dark turn `graceTurns + 2` on, each turn rolls `chance(lethality)`
    /// to be eaten. Stepping back into the light — or ``suspended`` — resets the
    /// count. Guards before the draw, so a lit turn burns no randomness.
    ///
    /// The warning goes out through `sayOnceThisTurn(_:)`, which changes what
    /// is printed and nothing else: a warning swallowed for repeating the room's
    /// own dark line is still a warned turn.
    ///
    /// **The death is always the lingering one, and the line has to say so.**
    /// The counter cannot reach the dice before the third dark turn, so nothing
    /// this daemon kills was killed on the turn it walked into the dark — which
    /// is the distinction Zork draws with two separate sentences. `V-WALK`
    /// (`gverbs.zil:1578`) says "You have walked into the slavering fangs of a
    /// lurking grue!" and fires only on a *blocked* move in the dark, a mechanic
    /// this plugin does not have at all; `GOTO` (`gverbs.zil:2110-2114`) says
    /// "A lurking grue slithered into " and then the vehicle's name, or the
    /// word "room", "and devoured you!" — and is the one that fits. Both games
    /// here had been handed the first. (#350)
    ///
    /// That branch is why `death` takes a subject: the vehicle the player was
    /// aboard, or nothing. Both halves are the game's own words. A library that
    /// has never seen the game has no business deciding what to call the place
    /// somebody was taken from, so the stock line names none.
    public var timers: [TimedEvent] {
        daemon("grue", autostart: true) {
            guard !suspended, !player.location.isLit else {
                darkTurns = 0
                return
            }
            darkTurns += 1
            if darkTurns == 1 {
                sayOnceThisTurn(warning)
            } else if darkTurns >= graceTurns + 2, chance(lethality) {
                // `<FSET? <LOC ,WINNER> ,VEHBIT>`.
                try die(death(player.vehicle?.definiteNoun))
            }
        }
    }
}
