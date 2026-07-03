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
/// The schedule is deterministic rather than `chance(…)` so transcripts
/// reproduce without pinned seeds. One sharp edge, accepted and documented:
/// UNDO from this death restores the count at its brink, so the revived
/// player has zero safe dark moves — RESTORE and RESTART are the real outs.
///
/// The daemon is named `"grue"`. Timer names are global, but two instances
/// of `DangerousDark` in one game already collide on their shared `@Global`
/// namespace before the timer name matters — one lethal dark per game.
public struct DangerousDark: GameContent {
    /// Consecutive turns the player has ended in darkness.
    @Global var darkTurns = 0

    let warning: String
    let death: String
    let graceTurns: Int

    /// - Parameters:
    ///   - warning: said on the first turn that ends in darkness.
    ///   - death: the `die(_:)` message.
    ///   - graceTurns: silent turns between warning and death — warn on dark
    ///     turn 1, die on dark turn `graceTurns + 2`.
    public init(
        warning: String = "The darkness is absolute, and something in it is breathing.",
        death: String = "Something in the dark finds you before you find it.",
        graceTurns: Int = 1
    ) {
        self.warning = warning
        self.death = death
        self.graceTurns = graceTurns
    }

    /// The grue daemon: each dark turn ticks the counter — the warning prints
    /// on the first dark turn, death lands on turn `graceTurns + 2`. Stepping
    /// back into the light resets the count.
    public var timers: [TimedEvent] {
        daemon("grue", autostart: true) {
            guard !player.location.isLit else {
                darkTurns = 0
                return
            }
            darkTurns += 1
            if darkTurns == 1 {
                say(warning)
            } else if darkTurns >= graceTurns + 2 {
                try die(death)
            }
        }
    }
}
