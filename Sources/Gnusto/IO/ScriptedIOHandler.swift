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

    public init(lines: [String]) {
        box = Mutex(Log(pending: lines))
    }

    public func write(_ text: String) {
        box.withLock { $0.transcript += text }
    }

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
