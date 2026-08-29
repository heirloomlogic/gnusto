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

/// The part of a stock line no subject can vary — the engine's own wording,
/// with the noun taken out.
///
/// A `Line<Nothing>` has one sample and *is* its fragment. A line that names
/// what it is about has several, differing only where the noun goes, so the
/// invariant is whichever of the common prefix and the common suffix is longer:
/// `cantEnter` keeps *"You can't get into the "* at the front, and `stubs.pull`
/// keeps *" budge."* at the back, where the number agreement swallows the front.
///
/// This exists so a test that asserts a game never falls through to the engine
/// can name the *line* rather than retype its words. A hand-copied sentence
/// stops matching the day somebody rewords the engine, and a guard that matches
/// nothing passes — green for the wrong reason, which is the failure the guard
/// was written to catch.
///
/// - Parameter line: the stock line to render.
/// - Returns: the longest fragment every sentence that line can print contains.
public func stockFragment(of line: any StockLine) -> String {
    let samples = line.samples
    guard let first = samples.first else { return "" }
    guard samples.count > 1 else { return first }

    func common(_ pick: (String) -> [Character]) -> Int {
        var length = 0
        let reference = pick(first)
        while length < reference.count {
            let next = reference[length]
            guard
                samples.allSatisfy({
                    let s = pick($0)
                    return length < s.count && s[length] == next
                })
            else { break }
            length += 1
        }
        return length
    }

    let prefix = common { Array($0) }
    let suffix = common { Array($0.reversed()) }
    return prefix >= suffix ? String(first.prefix(prefix)) : String(first.suffix(suffix))
}

/// Records a Swift Testing issue for every engine stock line that survives in a
/// transcript.
///
/// The assertion behind *"a sentence that names an act invites it, and the room
/// has to answer in its own voice"*: a game whose prose describes a switch and
/// then answers `You can't turn that on.` is denying what it just offered. Pass
/// the lines whose acts the walked prose invites — `GameText().cantTurnOnThat`
/// and friends — rather than their words, so the guard tracks the engine.
///
/// - Parameters:
///   - transcript: the transcript to search.
///   - refusals: the stock lines none of the walked commands should reach.
///   - note: optional context for the failure message, e.g. the room walked.
///   - sourceLocation: the caller's source location, for issue reporting.
public func expectNoStockRefusal(
    _ transcript: String,
    _ refusals: [any StockLine],
    _ note: String = "",
    sourceLocation: SourceLocation = #_sourceLocation
) {
    for refusal in refusals {
        let fragment = stockFragment(of: refusal)
        guard !fragment.isEmpty, transcript.contains(fragment) else { continue }
        Issue.record(
            """
            The engine answered an act the prose offered: "\(fragment)".\(note.isEmpty ? "" : " \(note)")
            Transcript:
            \(transcript)
            """,
            sourceLocation: sourceLocation)
    }
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
/// So this reads the properties off `GameText.StubReplies` with `Mirror`
/// rather than listing them: every line the engine actually ships is compared,
/// and one added tomorrow is compared the day it lands. A property whose type
/// this cannot render is reported as its own issue rather than skipped, which is
/// what keeps "reflected" from quietly meaning "unchecked".
///
/// That last sentence has no exception to it as of #246. `give` used to be one:
/// the one line about two objects, so not a `GameText.Line`, so unreachable by
/// reflection and compared by hand below the loop — the single line in here that
/// could change shape without the sweep noticing. It takes a `GameText.Gift`
/// now, and goes through the same door as the other forty-eight.
///
/// Which sentences each line prints is the *subject's* business as of #255:
/// `LineSubject.samples(one:many:)` supplies them, so a subject arriving
/// tomorrow is swept the day it lands rather than after somebody teaches a
/// switch here about it.
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

    // Zipped rather than keyed by label: both sides are the same concrete type,
    // so `Mirror` walks them in the same declaration order, and a dictionary
    // would only add a lookup that can't miss and a trap that can't fire.
    //
    // One cast, because every subject a `Line` can be about supplies its own
    // examples — including both arrangements of a two-object line, which the
    // wording rarely agrees with in the order it names them. A shape this
    // couldn't render used to be reported as its own issue and skipped; a
    // subject that can't be swept now fails to compile instead.
    var voiced: [String] = []
    for (mine, theirs) in zip(
        Mirror(reflecting: ours).children, Mirror(reflecting: engine).children)
    {
        guard let label = mine.label else { continue }
        guard let mine = mine.value as? any StockLine,
            let theirs = theirs.value as? any StockLine
        else {
            Issue.record(
                """
                `GameText.StubReplies.\(label)` is not a `GameText.Line`, so \
                this sweep can't render it. Give it a `Line` — its subject \
                conforming to `LineSubject` is all the sweep needs — or the \
                line ships unchecked in every game with a floor.
                """)
            continue
        }
        if zip(mine.samples, theirs.samples).contains(where: { $0 == $1 }) {
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
