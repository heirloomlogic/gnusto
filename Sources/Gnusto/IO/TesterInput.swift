/// Front-end classification of a raw input line into the tester conveniences the
/// REPL handles *before* the parser ever sees it: play-test comments and the
/// transcript-recording command. Pure and side-effect-free so it can be
/// unit-tested without a live terminal.
///
/// These never reach `GameWorld.perform`, so they can't parse as commands, run
/// rules, or advance a fuse/daemon — the world simulation stays unaware of them.
enum TesterInput {
    /// Whether a line is a play-test comment: its first non-blank characters are
    /// `//` or `#`. The engine never sees it — no parse, no rules, no clock tick
    /// — but it stays in the transcript as a note the way a source comment does.
    ///
    /// - Parameter line: the raw line the tester typed.
    /// - Returns: true when the line should be treated as a comment.
    static func isComment(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("//") || trimmed.hasPrefix("#")
    }

    /// The transcript-recording command a line requests, or `nil` when the line
    /// is an ordinary command. `script` / `script <name>` starts recording;
    /// `unscript` stops it. Matched case-insensitively on the whole trimmed
    /// line, so it shadows any game verb spelled `script` — acceptable for a
    /// front-end tester tool, and vanishingly rare.
    ///
    /// - Parameter line: the raw line the tester typed.
    /// - Returns: the transcript command, or `nil` for an ordinary command.
    static func transcriptCommand(_ line: String) -> TranscriptCommand? {
        let words = line.trimmingCharacters(in: .whitespaces)
            .split(separator: " ", omittingEmptySubsequences: true)
        guard let verb = words.first?.lowercased() else { return nil }
        switch verb {
        case "script":
            let name = words.dropFirst().joined(separator: " ")
            return .start(name: name.isEmpty ? nil : name)
        case "unscript" where words.count == 1:
            return .stop
        default:
            return nil
        }
    }
}

/// What a tester's `script` / `unscript` line asks the REPL to do with the
/// session transcript file.
enum TranscriptCommand: Equatable {
    /// Start recording; `name` is an explicit slot name or path, or `nil` for a
    /// timestamped default in the game's transcripts directory.
    case start(name: String?)
    /// Stop recording and close the file.
    case stop
}
