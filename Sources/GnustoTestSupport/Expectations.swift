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
