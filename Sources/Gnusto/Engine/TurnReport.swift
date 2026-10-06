/// What kind of input the engine will consume next.
///
/// A direct-world front end can use this to choose completion and voice rules
/// without inferring a prompt from the game's prose. The value exposes no
/// world topology or mutable state.
public enum InputContext: Sendable, Equatable {
    /// The next line is an ordinary game command.
    case command
    /// The parser asked which object or wording the player meant.
    case clarification
    /// The next line names a file to save.
    case saveFilename
    /// The next line confirms whether an existing save should be replaced.
    case saveOverwriteConfirmation
    /// The next line names a file to restore.
    case restoreFilename
    /// The next line answers the post-death RESTART / RESTORE / UNDO / QUIT choice.
    case endGameChoice
}

/// What a turn did besides print: how the engine consumed input, whether a
/// save or restore operation changed stage, and whether the player moved.
///
/// A front end that only prints text never needs this. One that draws a map
/// does. The transcript cannot say which way the player went — `n`, `north` and
/// `go north` are one move, and a refusal names no direction — and a room's
/// name is prose that two rooms may share. ``GameWorld/perform(_:)`` fills it
/// in; ``GameWorld/begin()`` and ``GameWorld/requestQuit()`` identify their
/// own non-command causes.
public struct TurnReport: Sendable, Equatable {
    /// How input caused this result.
    public enum InputEvent: Sendable, Equatable {
        /// No input event was recorded. This is the default for a report a
        /// caller constructs and for internal results before the public API
        /// classifies them.
        case none
        /// ``GameWorld/begin()`` produced the opening without consuming input.
        case initialization
        /// The parser produced and ran a command.
        case command
        /// The parser rejected a fresh command without opening a clarification.
        case parserRejection
        /// The parser rejected an ambiguous command and asked a question.
        case clarificationRequested
        /// A line was consumed as an answer to an open parser clarification.
        case clarificationAnswered
        /// A line answered a non-parser engine prompt.
        case promptAnswered(InputContext)
        /// Input was cancelled without running a command or spending a turn.
        case cancelled(InputContext)
        /// ``GameWorld/requestQuit()`` handled a confirmed front-end quit request.
        case frontendQuit
    }

    /// One causal stage change for a save or restore operation.
    public struct OperationEvent: Sendable, Equatable {
        /// The operation the event describes.
        public enum Kind: Sendable, Equatable {
            case save
            case restore
        }

        /// The operation's stage after this result.
        public enum Outcome: Sendable, Equatable {
            /// The engine opened the operation's filename prompt.
            case requested
            /// The file was written or a validated state was installed.
            case completed
            /// Validation or file access failed.
            case failed
            /// The operation ended without reading, writing, or replacing state.
            case cancelled
        }

        /// The save or restore operation that changed stage.
        public let kind: Kind
        /// The operation's new stage.
        public let outcome: Outcome

        /// Constructs an immutable operation event.
        public init(kind: Kind, outcome: Outcome) {
            self.kind = kind
            self.outcome = outcome
        }
    }

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

    /// How input caused this result.
    public internal(set) var input: InputEvent = .none

    /// A save or restore stage change caused by this result, when there was one.
    public internal(set) var operation: OperationEvent?

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
        basedOn preliminary: TurnReport
    ) -> TurnReport {
        var report = preliminary
        report.understood = audit.understood
        report.unknownWords = audit.unknownWords
        report.input = audit.input
        let destination = state.playerLocation
        guard destination != origin else { return report }
        if audit.answeredPrompt || audit.intent == .undo
            || audit.intent == .restart || audit.intent == .restore
        {
            report.movement = .relocated(to: destination)
        } else if case .walked(let from, let to, let direction) = preliminary.movement,
            from == origin, to == destination
        {
            report.movement = .walked(from: from, to: to, direction: direction)
        } else {
            report.movement = .teleported(from: origin, to: destination)
        }
        return report
    }
}

extension TurnResult {
    /// Adds one save/restore stage change while preserving the result's output
    /// and state-derived fields.
    func reporting(_ operation: TurnReport.OperationEvent) -> TurnResult {
        var result = self
        result.report.operation = operation
        return result
    }
}
