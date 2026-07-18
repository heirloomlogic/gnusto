import Synchronization

/// Feeds a fixed list of commands and records everything into a transcript —
/// for tests and automated playthroughs. Ships in the library because game
/// authors want transcript tests too.
public final class ScriptedIOHandler: IOHandler {
    private struct Log: Sendable {
        var pending: [Input]
        var transcript = ""
    }

    private let box: Mutex<Log>

    /// Creates a handler that will feed the given lines in order — each as a
    /// `.line`, the way a player types commands.
    ///
    /// - Parameter lines: the lines to feed in order.
    public init(lines: [String]) {
        box = Mutex(Log(pending: lines.map(Input.line)))
    }

    /// Creates a handler that will feed the given input units in order — use
    /// this to script a front-end `.quit` (Ctrl-C) alongside typed lines.
    ///
    /// - Parameter inputs: the input units to feed in order.
    public init(inputs: [Input]) {
        box = Mutex(Log(pending: inputs))
    }

    /// Appends text to the transcript, rendering the `<br>` hard-break marker
    /// as a newline (via `TextWrap.plain(_:)`) so recorded transcripts read
    /// the way a player sees them, the same as the plain console — the marker
    /// convention is honored in one place, not per handler.
    ///
    /// - Parameter text: the text to append.
    public func write(_ text: String) {
        box.withLock { $0.transcript += TextWrap.plain(text) }
    }

    /// Returns the next scripted input, or `nil` once it runs out. A `.line`
    /// is echoed into the transcript as `prompt + line`; a `.quit` records the
    /// prompt with no text, the way a Ctrl-C leaves the input line empty.
    ///
    /// - Parameter prompt: the prompt recorded before the input.
    /// - Returns: the next scripted input, or `nil` once it runs out.
    public func readLine(prompt: String) -> Input? {
        box.withLock { log in
            guard !log.pending.isEmpty else { return nil }
            let input = log.pending.removeFirst()
            switch input {
            case .line(let line): log.transcript += "\(prompt)\(line)\n"
            case .quit: log.transcript += "\(prompt)\n"
            }
            return input
        }
    }

    /// Everything written so far, with input lines interleaved as
    /// `> command` the way a player would see them.
    public var transcript: String {
        box.withLock { $0.transcript }
    }
}
