import Synchronization

@testable import Gnusto

/// A scripted handler that also records what the REPL hands a front end —
/// the `finish` text and how many completion sets were pushed — so tests can
/// assert the wiring without a terminal. `ScriptedIOHandler` is `final`, so
/// this wraps one rather than subclassing it.
final class RecordingIOHandler: IOHandler {
    private let inner: ScriptedIOHandler
    private let finished = Mutex<String?>(nil)
    private let pushes = Mutex(0)
    let wantsCompletions: Bool

    init(inputs: [Input], wantsCompletions: Bool = false) {
        inner = ScriptedIOHandler(inputs: inputs)
        self.wantsCompletions = wantsCompletions
    }

    func write(_ text: String) { inner.write(text) }
    func readLine(prompt: String) -> Input? { inner.readLine(prompt: prompt) }
    func updateCompletions(_ candidates: CompletionCandidates) { pushes.withLock { $0 += 1 } }
    func finish(_ finalText: String) { finished.withLock { $0 = finalText } }

    /// What `finish` was called with, or `nil` if it never was.
    var finishedWith: String? { finished.withLock { $0 } }
    /// How many candidate sets the REPL pushed.
    var completionPushes: Int { pushes.withLock { $0 } }
}
