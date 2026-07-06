import Synchronization

/// Feeds a fixed list of commands and records everything into a transcript —
/// for tests and automated playthroughs. Ships in the library because game
/// authors want transcript tests too.
public final class ScriptedIOHandler: IOHandler {
    private struct Log: Sendable {
        var pending: [String]
        var transcript = ""
    }

    private let box: Mutex<Log>

    /// Creates a handler that will feed the given lines in order.
    ///
    /// - Parameter lines: the lines to feed in order.
    public init(lines: [String]) {
        box = Mutex(Log(pending: lines))
    }

    /// Appends text to the transcript.
    ///
    /// - Parameter text: the text to append.
    public func write(_ text: String) {
        box.withLock { $0.transcript += text }
    }

    /// Returns the next scripted line, or `nil` once they run out.
    ///
    /// - Parameter prompt: the prompt recorded before the line.
    /// - Returns: the next scripted line, or `nil` once they run out.
    public func readLine(prompt: String) -> String? {
        box.withLock { log in
            guard !log.pending.isEmpty else { return nil }
            let line = log.pending.removeFirst()
            log.transcript += "\(prompt)\(line)\n"
            return line
        }
    }

    /// Everything written so far, with input lines interleaved as
    /// `> command` the way a player would see them.
    public var transcript: String {
        box.withLock { $0.transcript }
    }
}
