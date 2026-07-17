import Foundation
import Gnusto

/// Boots a game, feeds it a list of commands, and returns the full
/// transcript — every line the game printed, with the player's input
/// interleaved as `> command` the way a player would see it.
///
/// Pass `seed` to pin the game's random stream for reproducible runs;
/// omit it for a fresh stream each run.
///
/// - Parameters:
///   - game: the game to boot.
///   - commands: the commands to feed it, in order.
///   - seed: pins the random stream when set; a fresh stream when nil.
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
    let world = try seed.map {
        try GameWorld(game: game, seed: $0, saveDirectory: saveDirectory)
    } ?? GameWorld(game: game, saveDirectory: saveDirectory)
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
