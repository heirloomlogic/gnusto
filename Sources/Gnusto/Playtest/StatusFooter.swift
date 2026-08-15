import Foundation

/// The one-line out-of-fiction note a play-test session can have appended to
/// every turn:
///
/// ```
/// [status] room=Front Hall | moves=12 | score=0 | turn=cost | time=5:46 pm
/// ```
///
/// A transcript is prose, and prose does not say where you are standing or
/// what the last command cost. A tester reading one back has to reconstruct
/// both, and the reconstruction is where the mistakes come from: counting
/// commands as turns is wrong the moment one of them fails to parse or turns
/// out to be a meta verb, and "which room was that?" is a scroll upwards.
/// `moves=` and `turn=` answer the first; `room=` answers the second.
///
/// Off unless asked for. `GNUSTO_STATUS` is read by ``GameMain`` — the
/// composition root — and the value handed to ``REPL/init(world:io:transcriptURL:status:)``,
/// which defaults to `nil`. The test suite constructs its REPLs without the
/// argument, so `GNUSTO_STATUS=1 swift test` changes nothing: the footer is
/// opt-in *by construction* rather than by an environment variable happening
/// to be unset.
///
/// Modelled on ``SeedRequest``: a value type that reads one variable, hands
/// back what it found, and complains about a value it could not read instead
/// of quietly doing something else.
public struct StatusFooter: Sendable {
    /// What `GNUSTO_STATUS` asked for.
    private enum Request: Sendable {
        /// Unset, empty, or one of the off words: no footer, as ever.
        case off
        /// One of the on words: append a footer to every turn.
        case on
        /// Something else, kept verbatim so the complaint can quote what the
        /// operator actually typed.
        case invalid(String)
    }

    private let request: Request

    /// The values that mean yes.
    private static let onWords: Set<String> = ["1", "on", "true", "yes"]

    /// The values that mean no — spelled out rather than folded into "anything
    /// else", so that `GNUSTO_STATUS=0` is an answer and `GNUSTO_STATUS=of` is
    /// a typo.
    private static let offWords: Set<String> = ["0", "off", "false", "no"]

    /// Reads `GNUSTO_STATUS`, tolerating the stray whitespace a shell wrapper
    /// or a copied-and-pasted value tends to bring with it.
    ///
    /// Not a bare flag, which is what `GNUSTO_PLAIN` is: this one writes into
    /// the transcript, so an unreadable value is worth a word rather than a
    /// guess.
    ///
    /// - Parameter environment: the environment to read `GNUSTO_STATUS` from.
    public init(environment: [String: String]) {
        let value = environment["GNUSTO_STATUS", default: ""]
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.isEmpty || Self.offWords.contains(trimmed) {
            request = .off
        } else if Self.onWords.contains(trimmed) {
            request = .on
        } else {
            request = .invalid(value)
        }
    }

    /// The footer to hand the `REPL`, or `nil` when none was asked for — an
    /// unreadable value included, since off is the default and doing the
    /// default after complaining is what `SeedRequest` does too.
    public var inForce: StatusFooter? {
        guard case .on = request else { return nil }
        return self
    }

    /// What to tell the operator on standard error, or `nil` when there is
    /// nothing to say.
    public var complaint: String? {
        guard case .invalid(let value) = request else { return nil }
        return """
            Ignoring GNUSTO_STATUS=\(value): expected one of \
            \(Self.onWords.sorted().joined(separator: ", ")) to turn the status \
            footer on. Leaving it off.
            """
    }

    /// Renders one footer line.
    ///
    /// The four standard fields come first and always, in a fixed order, so a
    /// reader (human or machine) can find them positionally; contributed
    /// fields follow in declaration order. Every value is squeezed onto one
    /// line — a newline or a `|` inside a value would break the shape the
    /// whole line is read by, and a room name or an author's field is not
    /// vetted for either.
    ///
    /// - Parameters:
    ///   - status: the turn's status line — room, score, moves.
    ///   - turnCost: whether the turn advanced the move counter. False for a
    ///     parse error, a meta verb, a command nothing answered, and the
    ///     opening, none of which the world's clock notices.
    ///   - fields: extra `name`/`value` pairs from the game's bundles and
    ///     plugins. See `GameWorld.statusFields()`.
    /// - Returns: the `[status] …` line, without a trailing newline.
    func line(
        _ status: StatusLine, turnCost: Bool, fields: [(String, String)]
    ) -> String {
        let standard = [
            ("room", status.locationName),
            ("moves", "\(status.moves)"),
            ("score", "\(status.score)"),
            ("turn", turnCost ? "cost" : "free"),
        ]
        let rendered = (standard + fields).map { "\($0.0)=\(Self.oneLine($0.1))" }
        return "[status] \(rendered.joined(separator: " | "))"
    }

    /// Collapses the two characters the line's own shape is made of.
    private static func oneLine(_ value: String) -> String {
        String(value.map { $0.isNewline || $0 == "|" ? " " : $0 })
    }
}
