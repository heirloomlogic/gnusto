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

/// The output of a single command within a transcript: everything between
/// the first `> command` line and the next prompt (or the end). Returns ""
/// when the command never appears.
///
/// - Parameters:
///   - command: the command whose turn to extract.
///   - transcript: the transcript to search.
/// - Returns: that turn's output, or "" when the command never appears.
public func turnOutput(of command: String, in transcript: String) -> String {
    guard let start = transcript.range(of: "> \(command)\n") else { return "" }
    let rest = transcript[start.upperBound...]
    if let nextPrompt = rest.range(of: "\n> ") {
        return String(rest[..<nextPrompt.lowerBound])
    }
    return String(rest)
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
