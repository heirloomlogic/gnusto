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
/// A contributed field like `time=` answers a third — *when* — and is sampled
/// at the turn's close rather than after its counter advanced, so that it
/// names the minute the turn's own words were written in. See
/// `statusFields`.
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

    /// A footer that is in force whatever the environment says.
    ///
    /// For the driver that has already decided it wants one: a play-test
    /// session records for a machine, which needs the room and the turn cost on
    /// every turn and cannot be asked to reconstruct them from prose. Built
    /// through the public initializer rather than by reaching past it, so there
    /// is exactly one definition of what "on" means.
    static let always = StatusFooter(environment: ["GNUSTO_STATUS": "on"])

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
    ///     plugins, read against the world as of the turn's *close* where the
    ///     three standard fields above are the turn's *result* — so a `time=`
    ///     derived from `moves=` reads one tick below it by design. See
    ///     `GameWorld.statusFields()`.
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

    /// A turn's output with the footer appended as one more paragraph.
    ///
    /// The two drivers that append a footer — ``REPL`` and the play-test
    /// session — call this rather than each joining the pieces themselves.
    /// There is exactly one interesting case and it is easy to get wrong in
    /// only one of two places: an *empty* turn (`quit` at the death prompt,
    /// answered with `freeReply("")`) is the footer alone, with no leading
    /// blank line padding it out from nothing. A session's transcript has to
    /// be byte-identical to the REPL's for the same commands, so the join is
    /// written once.
    ///
    /// - Parameters:
    ///   - result: the turn that just ran.
    ///   - turnCost: whether the move counter advanced across it.
    ///   - fields: the contributed fields, from `GameWorld.statusFields()` —
    ///     sampled at the turn's close, not after its counter advanced.
    /// - Returns: the text to print and to record.
    func annotate(
        _ result: TurnResult, turnCost: Bool, fields: [(String, String)]
    ) -> String {
        let footer = line(result.status, turnCost: turnCost, fields: fields)
        return result.output.isEmpty ? footer : "\(result.output)\n\n\(footer)"
    }

    /// Collapses the two characters the line's own shape is made of.
    private static func oneLine(_ value: String) -> String {
        String(value.map { $0.isNewline || $0 == "|" ? " " : $0 })
    }
}
