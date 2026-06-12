import Foundation
import Gnusto
import Testing

/// Boots a game, feeds it a list of commands, and returns the full transcript.
func play(_ game: some Game, _ commands: [String]) async throws -> String {
    let world = try GameWorld(game: game)
    let io = ScriptedIOHandler(lines: commands)
    await REPL(world: world, io: io).run()
    return io.transcript
}

/// Asserts that the needles appear in the transcript in the given order.
func expectInOrder(
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

/// The output of a single command within a transcript: everything between
/// `> command` and the next prompt (or the end).
func turnOutput(of command: String, in transcript: String) -> String {
    guard let start = transcript.range(of: "> \(command)\n") else { return "" }
    let rest = transcript[start.upperBound...]
    if let nextPrompt = rest.range(of: "\n> ") {
        return String(rest[..<nextPrompt.lowerBound])
    }
    return String(rest)
}
