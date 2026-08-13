import Gnusto
import Testing

/// Records one Swift Testing issue (at the caller's source location) if the
/// needles do not appear in the transcript in the given order; each match
/// resumes searching after the previous one. On failure the full transcript
/// is included in the issue message.
///
/// - Parameters:
///   - transcript: the transcript to search.
///   - needles: the substrings expected, in order.
///   - sourceLocation: the caller's source location, for issue reporting.
public func expectInOrder(
    _ transcript: String,
    _ needles: [String],
    sourceLocation: SourceLocation = #_sourceLocation
) {
    var cursor = transcript.startIndex
    for needle in needles {
        guard let range = transcript.range(of: needle, range: cursor..<transcript.endIndex) else {
            Issue.record(
                """
                Expected "\(needle)" after the previous match, but it was not found.
                Transcript:
                \(transcript)
                """,
                sourceLocation: sourceLocation)
            return
        }
        cursor = range.upperBound
    }
}

/// Records a Swift Testing issue if the transcript contains either answer a
/// game gives to a noun it doesn't know: `I don't know the word "x"` for a word
/// outside the vocabulary, and `You can't see any such thing` for a word the
/// parser knows only as an adjective, or for a thing that isn't in scope.
///
/// The pair is what a walk of `x <noun>` over a room's own description is
/// checking — that every noun the prose prints is a noun the player can type —
/// and it has to be both, because the two failures read very differently to a
/// player and only one of them looks like a missing word. On failure the whole
/// transcript is included, which a bare `#expect(!contains)` cannot do.
///
/// - Parameters:
///   - transcript: the transcript to search.
///   - note: optional context for the failure message, e.g. the probe that ran.
///   - sourceLocation: the caller's source location, for issue reporting.
public func expectEveryNounAnswered(
    _ transcript: String,
    _ note: String = "",
    sourceLocation: SourceLocation = #_sourceLocation
) {
    for failure in ["I don't know the word", "can't see any such thing"]
    where transcript.contains(failure) {
        Issue.record(
            """
            A noun went unanswered: "\(failure)".\(note.isEmpty ? "" : " \(note)")
            Transcript:
            \(transcript)
            """,
            sourceLocation: sourceLocation)
        return
    }
}

/// Records a Swift Testing issue if the transcript contains a disambiguation
/// question — *"Which do you mean: the narrow chimney or the small door?"*
///
/// A sibling of ``expectEveryNounAnswered(_:_:sourceLocation:)`` rather than a
/// third entry in its list, because the two ask different questions and a game
/// may want one and not the other. An unanswered noun is always a defect; an
/// ambiguity is only a defect where the author believes a room holds one of the
/// thing. Where a room really does hold two, the question is the true answer,
/// and folding it into the other helper would fail every suite that has one on
/// purpose.
///
/// The reason to call this rather than write `#expect(!transcript.contains(…))`
/// is the same as the reason above: the failure carries the whole transcript,
/// so the collision is readable without re-deriving the route by hand.
///
/// - Parameters:
///   - transcript: the transcript to search.
///   - note: optional context for the failure message, e.g. the rooms walked.
///   - sourceLocation: the caller's source location, for issue reporting.
public func expectNoAmbiguity(
    _ transcript: String,
    _ note: String = "",
    sourceLocation: SourceLocation = #_sourceLocation
) {
    guard transcript.contains("Which do you mean") else { return }
    Issue.record(
        """
        Two things in one room answered to one noun.\(note.isEmpty ? "" : " \(note)")
        Transcript:
        \(transcript)
        """,
        sourceLocation: sourceLocation)
}

/// Every stub-verb line a game still answers in the engine's voice, by property
/// name.
///
/// A game that gives itself a **stub floor** — `text.stubs`, rather than an
/// `action(…)` row per verb — is claiming all ~47 of them, and the claim is easy
/// to half-keep: one line left unassigned means a plain modern narrator takes
/// over on the turn after a re-voiced one, which is exactly the defect the
/// Dungeon and Zork 1 floors were written to close. Naming each verb in a test
/// catches that; it does not catch a *forty-eighth* stub arriving in the engine
/// tomorrow, which would slip past every named assertion at once.
///
/// So this reads the properties off ``GameText/StubReplies`` with `Mirror`
/// rather than listing them: every line the engine actually ships is compared,
/// and one added tomorrow is compared the day it lands. A property whose type
/// this cannot render is reported as its own issue rather than skipped, which is
/// what keeps "reflected" from quietly meaning "unchecked".
///
/// That last sentence has no exception to it as of #246. `give` used to be one:
/// the one line about two objects, so not a ``GameText/Line``, so unreachable by
/// reflection and compared by hand below the loop — the single line in here that
/// could change shape without the sweep noticing. It takes a ``GameText/Gift``
/// now, and goes through the same door as the other forty-eight.
///
/// It is split out from ``expectNoEngineStubLineSurvives(in:game:sourceLocation:)``
/// so the sweep can be tested for being *alive*: a reflection loop that matches
/// nothing passes silently, where one asserted to see all forty-nine lines
/// cannot.
///
/// - Parameter ours: the game's `text.stubs`.
/// - Returns: the property names still identical to the engine's wording.
public func engineVoicedStubLines(in ours: GameText.StubReplies) -> [String] {
    let engine = GameText.StubReplies()

    // A plural noun catches a template that hard-codes its agreement — "The
    // rails is not food." is the defect ``GameText/Noun`` exists to prevent —
    // and `nil` catches a game that re-voices a line's naming half and leaves
    // its bare half in the engine's words.
    let one = GameText.Noun("the brass lantern")
    let many = GameText.Noun("the rails", plural: true)

    /// Every sentence one line can print, or `nil` for a shape not known here.
    func samples(of line: Any) -> [String]? {
        switch line {
        case let fixed as String: [fixed]
        case let line as GameText.Line<GameText.Noun>: [line(one), line(many)]
        case let line as GameText.Line<GameText.Noun?>: [line(one), line(many), line(nil)]
        // Both arrangements, because a line about two things has two things its
        // verb might agree with and the wording rarely agrees with the one it
        // names first. One order would let a template that hard-codes the
        // *other* agreement through.
        case let line as GameText.Line<GameText.Gift>: [line(one, many), line(many, one)]
        default: nil
        }
    }

    // Zipped rather than keyed by label: both sides are the same concrete type,
    // so `Mirror` walks them in the same declaration order, and a dictionary
    // would only add a lookup that can't miss and a trap that can't fire.
    var voiced: [String] = []
    for (mine, theirs) in zip(
        Mirror(reflecting: ours).children, Mirror(reflecting: engine).children)
    {
        guard let label = mine.label else { continue }
        guard let ourSamples = samples(of: mine.value),
            let engineSamples = samples(of: theirs.value)
        else {
            Issue.record(
                """
                `GameText.StubReplies.\(label)` has a shape this sweep can't \
                render. Teach `samples(of:)` about it, or the line ships \
                unchecked in every game with a floor.
                """)
            continue
        }
        if zip(ourSamples, engineSamples).contains(where: { $0 == $1 }) {
            voiced.append(label)
        }
    }
    return voiced
}

/// Records a Swift Testing issue for every stub-verb line a game still answers
/// in the engine's voice.
///
/// - Parameters:
///   - ours: the game's `text.stubs`.
///   - game: the game's name, for the issue message.
///   - sourceLocation: the caller's source location, for issue reporting.
public func expectNoEngineStubLineSurvives(
    in ours: GameText.StubReplies,
    game: String,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    for label in engineVoicedStubLines(in: ours) {
        Issue.record(
            "\(game): `\(label)` still answers in the engine's voice.",
            sourceLocation: sourceLocation)
    }
}
