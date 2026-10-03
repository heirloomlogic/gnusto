/// What a turn did besides print: whether the line was understood, and
/// whether the player moved.
///
/// A front end that only prints text never needs this. One that draws a map
/// does. The transcript cannot say which way the player went — `n`, `north` and
/// `go north` are one move, and a refusal names no direction — and a room's
/// name is prose that two rooms may share. ``GameWorld/perform(_:)`` fills it
/// in; ``GameWorld/begin()`` and ``GameWorld/requestQuit()`` leave it empty.
public struct TurnReport: Sendable, Equatable {
    /// How the player came to stand somewhere else when a turn ended.
    public enum Movement: Sendable, Equatable {
        /// The player went out of `from` through an exit: `north`, `go up`,
        /// `enter the trap door`, `follow the troll`. Both the direction and
        /// destination come from a confirmed traversal, rather than a parsed
        /// direction or a guess about an adjacent room.
        case walked(from: EntityID, to: EntityID, direction: Direction)
        /// The turn ended in `to` without one confirmed exit traversal:
        /// a rule's `arrive(at:)`, a spell, a fall, or multiple room changes.
        case teleported(from: EntityID, to: EntityID)
        /// UNDO, RESTART or RESTORE replaced the world, and the player stands
        /// in `to`. Nothing was walked.
        case relocated(to: EntityID)
    }

    /// Whether the parser got a command out of the line. False for a parse
    /// error, an open clarifying question, and a line that answered an engine
    /// prompt.
    public internal(set) var understood = false

    /// Every word of the line the game has never heard of, in the order typed.
    public internal(set) var unknownWords: [String] = []

    /// How the player's location changed during the turn, or `nil` when they
    /// ended it where they began it. An exit that leads back into the room it
    /// leaves is therefore not reported.
    public internal(set) var movement: Movement?
}

/// One actual player-location mutation in a live turn, never saved or undone.
struct MapTransition: Sendable {
    let from: EntityID
    let to: EntityID
    let direction: Direction?
}

extension GameWorld {
    /// Combines parser information with the live turn's recorded movement.
    func report(
        of audit: TurnAudit, from origin: EntityID,
        recorded movement: TurnReport.Movement?
    ) -> TurnReport {
        var report = TurnReport()
        report.understood = audit.understood
        report.unknownWords = audit.unknownWords
        let destination = state.playerLocation
        guard destination != origin else { return report }
        if audit.answeredPrompt || audit.intent == .undo
            || audit.intent == .restart || audit.intent == .restore
        {
            report.movement = .relocated(to: destination)
        } else if case .walked(let from, let to, let direction) = movement,
            from == origin, to == destination
        {
            report.movement = .walked(from: from, to: to, direction: direction)
        } else {
            report.movement = .teleported(from: origin, to: destination)
        }
        return report
    }
}
