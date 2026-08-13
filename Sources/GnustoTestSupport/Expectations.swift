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

/// Records a Swift Testing issue for every stub-verb line a game still answers
/// in the engine's voice.
///
/// A game that gives itself a **stub floor** — `text.stubs`, rather than an
/// `action(…)` row per verb — is claiming all ~47 of them, and the claim is easy
/// to half-keep: one line left unassigned means a plain modern narrator takes
/// over on the turn after a re-voiced one, which is exactly the defect the
/// Dungeon and Zork 1 floors were written to close. Naming each verb in a test
/// catches that; it does not catch a *forty-eighth* stub arriving in the engine
/// tomorrow, which would slip past every named assertion at once.
///
/// So this derives its own completeness from ``GameText/StubReplies`` rather
/// than from the table below: `Mirror` names every property the engine actually
/// ships, and the label check fails the moment one is added — sending the next
/// person here rather than letting the new line go unvoiced in every game.
///
/// The comparisons themselves are written out rather than reflected because a
/// dynamic cast to a function type is not reliable in Swift; an earlier draft
/// read the closures out of the `Mirror` and trapped. `Mirror` proves the list
/// is whole, and nothing else.
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
    let engine = GameText.StubReplies()

    // Two samples, because a plural one catches a template that hard-codes its
    // agreement — "The rails is not food." is the defect the engine's own
    // `Noun` exists to prevent. And both halves of the six lines handed an
    // optional name, since a game may re-voice one half and leave the other.
    let name = "the brass lantern"
    let one = GameText.Noun(name)
    let many = GameText.Noun("the rails", plural: true)

    let floor: [(String, [String], [String])] = [
        ("yourself", [ours.yourself], [engine.yourself]),
        ("somebodyElse", [ours.somebodyElse(one)], [engine.somebodyElse(one)]),
        ("attack", [ours.attack(name)], [engine.attack(name)]),
        ("smash", [ours.smash(one), ours.smash(many)], [engine.smash(one), engine.smash(many)]),
        ("burn", [ours.burn(name)], [engine.burn(name)]),
        ("cut", [ours.cut(name)], [engine.cut(name)]),
        ("dig", [ours.dig], [engine.dig]),
        ("pull", [ours.pull(one), ours.pull(many)], [engine.pull(one), engine.pull(many)]),
        ("turn", [ours.turn(one), ours.turn(many)], [engine.turn(one), engine.turn(many)]),
        ("squeeze", [ours.squeeze(name)], [engine.squeeze(name)]),
        ("shake", [ours.shake(name)], [engine.shake(name)]),
        ("knock", [ours.knock], [engine.knock]),
        ("throwAt", [ours.throwAt], [engine.throwAt]),
        ("touch", [ours.touch(one), ours.touch(nil)], [engine.touch(one), engine.touch(nil)]),
        ("smell", [ours.smell(one), ours.smell(nil)], [engine.smell(one), engine.smell(nil)]),
        (
            "listen", [ours.listen(one), ours.listen(nil)],
            [engine.listen(one), engine.listen(nil)]
        ),
        ("taste", [ours.taste], [engine.taste]),
        ("eat", [ours.eat(one), ours.eat(many)], [engine.eat(one), engine.eat(many)]),
        ("drink", [ours.drink], [engine.drink]),
        ("sleep", [ours.sleep], [engine.sleep]),
        ("wake", [ours.wake(one), ours.wake(nil)], [engine.wake(one), engine.wake(nil)]),
        ("kiss", [ours.kiss], [engine.kiss]),
        (
            "give", [ours.give(name, one), ours.give(name, many)],
            [engine.give(name, one), engine.give(name, many)]
        ),
        ("yell", [ours.yell], [engine.yell]),
        ("wave", [ours.wave(one), ours.wave(nil)], [engine.wave(one), engine.wave(nil)]),
        ("point", [ours.point], [engine.point]),
        ("climb", [ours.climb(one), ours.climb(nil)], [engine.climb(one), engine.climb(nil)]),
        ("jump", [ours.jump], [engine.jump]),
        ("swim", [ours.swim], [engine.swim]),
        ("dive", [ours.dive], [engine.dive]),
        ("stand", [ours.stand], [engine.stand]),
        ("sit", [ours.sit], [engine.sit]),
        ("lie", [ours.lie], [engine.lie]),
        ("kneel", [ours.kneel], [engine.kneel]),
        ("fill", [ours.fill(name)], [engine.fill(name)]),
        ("pour", [ours.pour(name)], [engine.pour(name)]),
        ("empty", [ours.empty(name)], [engine.empty(name)]),
        ("tie", [ours.tie(name)], [engine.tie(name)]),
        ("untie", [ours.untie(one), ours.untie(many)], [engine.untie(one), engine.untie(many)]),
        ("pray", [ours.pray], [engine.pray]),
        ("sing", [ours.sing], [engine.sing]),
        ("curse", [ours.curse], [engine.curse]),
        ("xyzzy", [ours.xyzzy], [engine.xyzzy]),
        ("count", [ours.count], [engine.count]),
        ("think", [ours.think], [engine.think]),
        ("wish", [ours.wish], [engine.wish]),
        ("buy", [ours.buy], [engine.buy]),
        ("sell", [ours.sell], [engine.sell]),
        ("blow", [ours.blow(name)], [engine.blow(name)]),
    ]

    let shipped = Set(Mirror(reflecting: engine).children.compactMap(\.label))
    #expect(
        shipped == Set(floor.map(\.0)),
        """
        `GameText.StubReplies` has changed shape. Add the new stub to the table \
        in `expectNoEngineStubLineSurvives`, then give every game with a floor a \
        line for it.
        """,
        sourceLocation: sourceLocation)

    for (label, ourLines, engineLines) in floor {
        for (ourLine, engineLine) in zip(ourLines, engineLines) {
            #expect(
                ourLine != engineLine,
                "\(game): `\(label)` still answers in the engine's voice: \"\(engineLine)\"",
                sourceLocation: sourceLocation)
        }
    }
}
