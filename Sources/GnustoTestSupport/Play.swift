import Foundation
import Gnusto

/// Boots a game, feeds it a list of commands, and returns the full
/// transcript — every line the game printed, with the player's input
/// interleaved as `> command` the way a player would see it.
///
/// Pass `seed` to pin the game's random stream for reproducible runs. Omit it
/// for a fresh stream each run — unless `GNUSTO_SEED` is set, which pins every
/// call that passed no seed of its own, so a whole suite run replays and a
/// sweep across seeds can find a test that only passes when the dice are kind.
///
/// - Parameters:
///   - game: the game to boot.
///   - commands: the commands to feed it, in order.
///   - seed: pins the random stream when set; `GNUSTO_SEED` or a fresh stream
///     when nil.
///   - saveDirectory: where bare `save`/`restore` names resolve; pass an
///     isolated temp directory when a test exercises named saves, so it
///     never touches the real per-user saves directory. Nil uses the engine
///     default.
/// - Throws: rethrows any error from booting or running the game.
/// - Returns: the full transcript, with input interleaved as `> command`.
public func play(
    _ game: some Game,
    _ commands: [String],
    seed: UInt64? = nil,
    saveDirectory: URL? = nil
) async throws -> String {
    let world = try cachedWorld(game, seed: seed, saveDirectory: saveDirectory)
    let io = ScriptedIOHandler(lines: commands)
    await REPL(world: world, io: io).run()
    return io.transcript
}

/// ``play(_:_:seed:saveDirectory:)`` over a world built afresh rather than
/// from the per-type cache — for a fixture whose declarations vary per
/// instance (`Game(compact: true)` against `Game(compact: false)`), which one
/// cached world per type cannot tell apart.
///
/// - Parameters:
///   - game: the game to boot.
///   - commands: the commands to feed it, in order.
///   - seed: pins the random stream when set; `GNUSTO_SEED` or a fresh stream
///     when nil.
///   - saveDirectory: where bare `save`/`restore` names resolve; pass an
///     isolated temp directory when a test exercises named saves, so it
///     never touches the real per-user saves directory. Nil uses the engine
///     default.
/// - Throws: rethrows any error from booting or running the game.
/// - Returns: the full transcript, with input interleaved as `> command`.
public func play(
    fresh game: some Game,
    _ commands: [String],
    seed: UInt64? = nil,
    saveDirectory: URL? = nil
) async throws -> String {
    let world = try GameWorld(
        game: game,
        seed: seed ?? environmentSeedRequest.value ?? UInt64.random(in: .min ... .max),
        saveDirectory: saveDirectory)
    let io = ScriptedIOHandler(lines: commands)
    await REPL(world: world, io: io).run()
    return io.transcript
}

/// The output of a single command within a transcript: everything between
/// the **first** `> command` prompt line and the next prompt (or the end).
/// Returns "" when the command never appears as a prompt.
///
/// A route that types the same command more than once and asks about a later
/// turn gets the first one here; ``turnOutput(ofLast:in:)`` is the slice for
/// the last.
///
/// The match is anchored to the start of a line: the start of the
/// transcript, or immediately after a newline. A command quoted in
/// CLAUDE.md's two-space form — a sign, a scrap of verse — fails that,
/// because `TextWrap` keeps a form's indent and the quoted line never
/// reaches column 0. The indent is one of the two things that keep a
/// quote off the anchor; prose ahead of it on the folded line is the other.
/// Prose that renders `> command` alone at column 0 still matches, and
/// both a `<br>` around the command and a blank line before it render it
/// that way, so quote a command in the indented form when a test slices
/// on it.
///
/// The end boundary is the same rule: the turn ends at the next `"\n> "`,
/// so any column-0 line opening with `> ` closes the slice, quoted or not.
///
/// - Parameters:
///   - command: the command whose turn to extract.
///   - transcript: the transcript to search.
/// - Returns: that turn's output, or "" when the command never appears.
public func turnOutput(of command: String, in transcript: String) -> String {
    guard let start = promptEnd(of: command, in: transcript) else { return "" }
    return output(before: "\n> ", in: String(transcript[start...]))
}

/// The output of the **last** time a transcript ran `command` — the slice for
/// "and the second time I looked", where ``turnOutput(of:in:)`` would hand
/// back the first look.
///
/// The match is anchored the same way ``turnOutput(of:in:)`` is, with the
/// same limit: a line start only, so a command quoted in the indented
/// two-space form is skipped and one rendered at column 0 is not.
///
/// - Parameters:
///   - command: the command whose last turn to extract.
///   - transcript: the transcript to search.
/// - Returns: that turn's output, or "" when the command never appears.
public func turnOutput(ofLast command: String, in transcript: String) -> String {
    guard let start = promptEnd(of: command, in: transcript, options: .backwards) else {
        return ""
    }
    return output(before: "\n> ", in: String(transcript[start...]))
}

/// The index just past a `> command` line that opens the transcript or is
/// preceded by a newline. A quoted `  > command` on a sign matches neither
/// form, because the indent `TextWrap` preserves for a form keeps it off
/// column 0. Prose is not otherwise excluded: a `> command` the renderer
/// puts at column 0 is indistinguishable from a prompt here.
///
/// - Parameters:
///   - command: the command the prompt line must read.
///   - transcript: the transcript to search.
///   - options: passed through to the interior search; `.backwards` finds
///     the last matching prompt instead of the first.
/// - Returns: the index right after the prompt line's newline, or nil when
///   no real prompt line matches.
private func promptEnd(
    of command: String,
    in transcript: String,
    options: String.CompareOptions = []
) -> String.Index? {
    let line = "> \(command)\n"
    let prefixEnd: String.Index? =
        transcript.hasPrefix(line)
        ? transcript.index(transcript.startIndex, offsetBy: line.count)
        : nil
    // The transcript's opening line, if it matches, is always the earliest
    // possible prompt, so a forward search prefers it over any interior
    // match; a backward search prefers an interior match, since that is
    // necessarily later in the transcript than the opening line.
    if !options.contains(.backwards), let prefixEnd { return prefixEnd }
    if let range = transcript.range(of: "\n\(line)", options: options) {
        return range.upperBound
    }
    return prefixEnd
}

/// Everything a transcript printed after its first occurrence of `marker` —
/// the slice to assert against when what matters is "and then, later…".
///
/// - Parameters:
///   - marker: the text to slice after.
///   - transcript: the transcript to search.
/// - Returns: the text following `marker`, or "" when it never appears.
public func output(after marker: String, in transcript: String) -> String {
    guard let range = transcript.range(of: marker) else { return "" }
    return String(transcript[range.upperBound...])
}

/// Everything a transcript printed after its **last** occurrence of `marker`.
///
/// The slice for a beat that fires more than once on a route. One villain's
/// death line is every villain's — a route that kills a troll on the way to a
/// thief prints the same disposal twice, and `output(after:)` would hand back
/// the tail from the troll.
///
/// - Parameters:
///   - marker: the text to slice after.
///   - transcript: the transcript to search.
/// - Returns: the text following the last `marker`, or "" when it never appears.
public func output(afterLast marker: String, in transcript: String) -> String {
    guard let range = transcript.range(of: marker, options: .backwards) else { return "" }
    return String(transcript[range.upperBound...])
}

/// Everything a transcript printed before its first occurrence of `marker`.
///
/// - Parameters:
///   - marker: the text to slice before.
///   - transcript: the transcript to search.
/// - Returns: the text preceding `marker`, or the whole transcript when it
///   never appears.
public func output(before marker: String, in transcript: String) -> String {
    guard let range = transcript.range(of: marker) else { return transcript }
    return String(transcript[..<range.lowerBound])
}

/// The paragraph a room heading introduces the **last** time the transcript
/// printed it: from that heading to the next prompt, and nothing after it.
///
/// `output(after:)` is the tail of the whole transcript, which is the wrong
/// slice for "what did this room just say" — and room names are not unique
/// across a long route either. The Bank of Zork has a Small Room and so does
/// Dungeon's Endgame, and a route that walks the Bank first makes the *first*
/// match reliably the wrong one. The last match is the room being stood in.
///
/// - Parameters:
///   - name: the room heading to slice at.
///   - transcript: the transcript to search.
/// - Returns: that room's paragraph, or "" when the heading never appears.
public func frame(headed name: String, in transcript: String) -> String {
    guard let heading = transcript.range(of: "\n\(name)\n", options: .backwards) else {
        return ""
    }
    return output(before: "\n> ", in: String(transcript[heading.upperBound...]))
}

/// How many times `needle` occurs in `haystack` — the count assertions in
/// transcript tests are usually about ("this beat fires exactly once").
///
/// - Parameters:
///   - needle: the text to count.
///   - haystack: the text to count it in.
/// - Returns: the number of non-overlapping occurrences.
public func occurrences(of needle: String, in haystack: some StringProtocol) -> Int {
    haystack.ranges(of: needle).count
}

/// The lines of a transcript slice that mention `needle`, in order.
///
/// The shape behind every "did he speak on each of these turns, and in the same
/// order?" assertion — and behind the alignment tests, which compare two runs'
/// lists to prove a guard burned no randomness. Those want one definition of
/// what counts as a line rather than one per test file.
///
/// - Parameters:
///   - needle: the text a line has to contain to count.
///   - slice: the transcript, or a slice of one.
/// - Returns: the matching lines, in transcript order.
public func lines(mentioning needle: String, in slice: String) -> [String] {
    slice.split(separator: "\n").filter { $0.contains(needle) }.map(String.init)
}
