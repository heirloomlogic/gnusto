import Foundation
import Synchronization

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

// MARK: - Emergency terminal restore (signal / atexit reachable)

// A signal handler and `atexit` callback can't reach instance state, so the
// bits needed to un-wedge the terminal live at module scope. They're written
// once, when the handler enters raw mode, and only read on teardown — so
// they're effectively immutable for the life of a session.

/// The terminal attributes saved before entering raw mode, restored on exit.
private nonisolated(unsafe) var gnustoSavedTermios = termios()

/// True while the terminal is in raw mode / the alternate screen — guards the
/// restore so it runs exactly once whether reached by normal teardown, a
/// fatal signal, or `atexit`.
private let gnustoTerminalActive = Atomic<Bool>(false)

/// Set by the `SIGWINCH` handler; the input loop drains it and re-renders.
private let gnustoWindowResized = Atomic<Bool>(false)

/// Restores cooked mode, leaves the alternate screen, and shows the cursor.
/// Idempotent (the `exchange` gate) and async-signal-safe enough for the fatal
/// signal path: only `tcsetattr` and a single `write`.
private func gnustoEmergencyRestore() {
    guard gnustoTerminalActive.exchange(false, ordering: .relaxed) else { return }
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &gnustoSavedTermios)
    let reset = "\u{1B}[?1049l\u{1B}[?25h"
    _ = reset.withCString { write(STDOUT_FILENO, $0, strlen($0)) }
}

private func gnustoResizeHandler(_ signal: Int32) {
    gnustoWindowResized.store(true, ordering: .relaxed)
}

private func gnustoFatalSignalHandler(_ sig: Int32) {
    gnustoEmergencyRestore()
    signal(sig, SIG_DFL)
    raise(sig)
}

// MARK: - TerminalIOHandler

/// A full-screen, Infocom-style terminal front end: a fixed status bar (room,
/// score, turns) above a story window that re-wraps its entire transcript to
/// the window width — so resizing the terminal reflows the text — with its own
/// line editor (arrow keys, history) and PageUp/PageDown scrollback.
///
/// Chosen automatically by `GameMain` when stdin and stdout are both a TTY;
/// piped or redirected runs fall back to `ConsoleIOHandler` so transcripts and
/// tests stay plain. No dependencies: hand-rolled `termios` + ANSI.
public final class TerminalIOHandler: IOHandler {
    /// All mutable session state, behind a `Mutex` because `IOHandler` is
    /// `Sendable`. Mirrors `ScriptedIOHandler`'s boxed-state pattern.
    private struct State {
        /// The story so far, one entry per engine `write` plus the echoed
        /// prompt lines. Stored unwrapped; the wrapped form is cached below.
        var transcript: [String] = []
        /// Which `transcript` entries are tester comments, to paint dim + italic
        /// so they read as notes, not game content. A `Set` of indices works
        /// because `transcript` only ever appends — an index, once assigned,
        /// stays valid — so no other append site has to be kept in lockstep.
        var commentIndices: Set<Int> = []
        /// The latest status line, or `nil` before the first turn.
        var status: StatusLine?
        /// The prompt the current `readLine` is showing (e.g. `"> "`).
        var prompt = "> "
        /// The line currently being edited (without the prompt).
        var input = ""
        /// Caret position within `input`, as a character offset.
        var cursor = 0
        /// Submitted commands, for Up/Down recall. Seeded from the persistent
        /// history file at launch, appended to on each submit.
        var history: [String] = []
        /// The words Tab-completion offers, refreshed by the engine each turn.
        var completions = CompletionCandidates()
        /// Lines scrolled up from the live bottom; 0 pins to the newest text.
        var scrollOffset = 0

        /// The transcript wrapped to `wrappedCols`, rebuilt only when the
        /// transcript grows or the width changes — so a keystroke repaints
        /// without re-flowing the whole game. `transcript` only ever appends,
        /// so its `count` is a sufficient cache key alongside the width.
        var wrappedTranscript: [String] = []
        /// Parallel to `wrappedTranscript`: whether each wrapped line belongs to
        /// a comment entry, so `render` can style it after wrapping (never
        /// before — ANSI codes would corrupt the width math). Rebuilt with the
        /// wrap cache below.
        var wrappedIsComment: [Bool] = []
        var wrappedCols = -1
        var wrappedCount = -1
    }

    private let box = Mutex(State())

    /// Where command history is persisted, or `nil` to keep it in memory only
    /// (as in tests). Loaded into `State.history` at launch, appended on submit.
    private let historyURL: URL?

    /// Enters raw mode and the alternate screen, installs the teardown guards,
    /// seeds command history from `historyURL`, and paints the initial (empty)
    /// frame.
    ///
    /// - Parameter historyURL: the file to persist and reload command history
    ///   from; `nil` keeps history in memory for the session only.
    public init(historyURL: URL? = nil) {
        self.historyURL = historyURL
        enableRawModeAndAltScreen()
        if let historyURL {
            let loaded = Self.loadHistory(from: historyURL)
            box.withLock { $0.history = loaded }
            // Trim on load so an overgrown or hand-bloated file is rewritten
            // back down to the cap; the append-per-command path stays untouched.
            Self.trimHistory(at: historyURL)
        }
        render()
    }

    deinit {
        gnustoEmergencyRestore()
    }

    // MARK: IOHandler

    /// Appends a block of engine output to the transcript and repaints. Blank
    /// writes (turns that produce no text) are dropped so they don't stack up
    /// empty paragraphs.
    public func write(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        box.withLock {
            $0.transcript.append(trimmed)
            $0.scrollOffset = 0  // new output snaps back to live
        }
        render()
    }

    /// Records the new status line and repaints the bar.
    public func showStatus(_ status: StatusLine) {
        box.withLock { $0.status = status }
        render()
    }

    /// Stores the completion candidates the engine computed for the next input
    /// line. Tab uses them; no repaint is needed.
    public func updateCompletions(_ candidates: CompletionCandidates) {
        box.withLock { $0.completions = candidates }
    }

    /// Holds the final frame until the player presses a key, then restores the
    /// primary screen and reprints the ending there — so the game's last words
    /// survive the alternate screen's teardown and land in the shell's
    /// scrollback. The restore is the same idempotent emergency path, so the
    /// later `atexit`/`deinit` calls become no-ops.
    public func finish(_ finalText: String) {
        box.withLock {
            $0.transcript.append("[Press any key to exit.]")
            $0.scrollOffset = 0
        }
        render()
        while nextKey() == nil {}  // any key (or EOF) dismisses; timeouts loop

        gnustoEmergencyRestore()
        let trimmed = finalText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            emit(trimmed + "\n")
        }
    }

    /// Runs the raw-mode line editor until the player submits a line, presses
    /// Ctrl-D on an empty line (EOF), or Ctrl-C (quit). Returns the submitted
    /// line as `.line`, `.quit` on a confirmed Ctrl-C, or `nil` (EOF) to end
    /// the game.
    public func readLine(prompt: String) -> Input? {
        box.withLock {
            $0.prompt = prompt
            $0.input = ""
            $0.cursor = 0
        }
        render()

        // History browsing state, local to this line. `historyCursor` counts
        // from the end: `history.count` means "the fresh line I'm typing".
        var historyCursor = box.withLock { $0.history.count }
        var draft = ""

        while true {
            guard let key = nextKey() else { continue }  // resize or timeout; loop

            // The editing cases only mutate state; the single `render()` at the
            // foot of the loop repaints. The control-flow cases (`enter`,
            // `eof`, `interrupt`) return, quit, or `continue` before reaching it.
            switch key {
            case .enter:
                let line = box.withLock { st -> String in
                    let line = st.input
                    let isComment = TesterInput.isComment(line)
                    if isComment {
                        st.commentIndices.insert(st.transcript.count)
                    }
                    st.transcript.append(st.prompt + line)
                    // Comments are notes, not commands: keep them out of Up/Down
                    // recall so history stays a list of things the game ran.
                    if !isComment, !line.trimmingCharacters(in: .whitespaces).isEmpty {
                        st.history.append(line)
                    }
                    st.input = ""
                    st.cursor = 0
                    st.scrollOffset = 0
                    return line
                }
                if let historyURL, !TesterInput.isComment(line) {
                    Self.appendHistory(line, to: historyURL)
                }
                render()
                return .line(line)

            case .eof:
                // Ctrl-D on an empty line ends input; ignored mid-line.
                let empty = box.withLock { $0.input.isEmpty }
                if empty { return nil }
                continue  // nothing changed; no repaint

            case .interrupt:
                // Ctrl-C: confirm, then signal a quit *intent* rather than
                // killing the process — the REPL routes `.quit` through
                // `GameWorld.requestQuit()`, so the engine prints its epilogue
                // and the terminal restores cleanly on the way out. Signaling
                // the intent (not the editable "quit" verb word) means the quit
                // lands even while a save/restore prompt is pending, and can't
                // drift if a game redefines the verb.
                if confirmQuit() { return .quit }
                render()
                continue

            case .tab:
                box.withLock { st in
                    let outcome = Self.complete(
                        input: st.input, cursor: st.cursor, candidates: st.completions)
                    st.input = outcome.newInput
                    st.cursor = outcome.newCursor
                    if !outcome.listing.isEmpty {
                        st.transcript.append(Self.formatCandidateListing(outcome.listing))
                        st.scrollOffset = 0
                    }
                }

            case .character(let ch):
                box.withLock {
                    let i = $0.input.index($0.input.startIndex, offsetBy: $0.cursor)
                    $0.input.insert(contentsOf: ch, at: i)
                    $0.cursor += ch.count
                }

            case .backspace:
                box.withLock {
                    guard $0.cursor > 0 else { return }
                    let i = $0.input.index($0.input.startIndex, offsetBy: $0.cursor - 1)
                    $0.input.remove(at: i)
                    $0.cursor -= 1
                }

            case .deleteForward:
                box.withLock {
                    guard $0.cursor < $0.input.count else { return }
                    let i = $0.input.index($0.input.startIndex, offsetBy: $0.cursor)
                    $0.input.remove(at: i)
                }

            case .left:
                box.withLock { $0.cursor = max(0, $0.cursor - 1) }

            case .right:
                box.withLock { $0.cursor = min($0.input.count, $0.cursor + 1) }

            case .home:
                box.withLock { $0.cursor = 0 }

            case .end:
                box.withLock { $0.cursor = $0.input.count }

            case .historyPrev:
                box.withLock { st in
                    guard historyCursor > 0 else { return }
                    if historyCursor == st.history.count { draft = st.input }
                    historyCursor -= 1
                    st.input = st.history[historyCursor]
                    st.cursor = st.input.count
                }

            case .historyNext:
                box.withLock { st in
                    guard historyCursor < st.history.count else { return }
                    historyCursor += 1
                    st.input = historyCursor == st.history.count ? draft : st.history[historyCursor]
                    st.cursor = st.input.count
                }

            case .pageUp:
                box.withLock { $0.scrollOffset += self.pageStep() }

            case .pageDown:
                box.withLock { $0.scrollOffset = max(0, $0.scrollOffset - self.pageStep()) }
            }
            render()
        }
    }

    // MARK: - Terminal setup

    private func enableRawModeAndAltScreen() {
        tcgetattr(STDIN_FILENO, &gnustoSavedTermios)
        var raw = gnustoSavedTermios
        raw.c_iflag &= ~tcflag_t(BRKINT | ICRNL | INPCK | ISTRIP | IXON)
        raw.c_oflag &= ~tcflag_t(OPOST)
        raw.c_lflag &= ~tcflag_t(ECHO | ICANON | IEXTEN | ISIG)
        // Poll rather than block: a 0.1s read timeout lets the input loop wake
        // and service a pending SIGWINCH even when no key is pressed. (Relying
        // on read() returning EINTR doesn't work — signal() installs the
        // handler with SA_RESTART on BSD/macOS, so the read auto-restarts.)
        setControlChar(&raw, VMIN, 0)
        setControlChar(&raw, VTIME, 1)
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)

        gnustoTerminalActive.store(true, ordering: .relaxed)
        atexit(gnustoEmergencyRestore)
        signal(SIGWINCH, gnustoResizeHandler)
        for sig in [SIGINT, SIGTERM, SIGHUP] {
            signal(sig, gnustoFatalSignalHandler)
        }

        emit("\u{1B}[?1049h")  // alternate screen buffer
    }

    /// Sets one entry of the `c_cc` control-character array. `c_cc` imports as
    /// a fixed-size tuple, which can't be subscripted with a runtime index, so
    /// rebind it to a `cc_t` buffer.
    private func setControlChar(_ term: inout termios, _ index: Int32, _ value: cc_t) {
        precondition(
            index >= 0 && index < Int32(NCCS),
            "control-char index \(index) out of bounds (NCCS = \(NCCS))")
        withUnsafeMutablePointer(to: &term.c_cc) {
            $0.withMemoryRebound(to: cc_t.self, capacity: Int(NCCS)) { $0[Int(index)] = value }
        }
    }

    // MARK: - Rendering

    /// The current terminal size in (rows, columns), defaulting to 24×80 if the
    /// `ioctl` fails (e.g. a terminal that doesn't answer `TIOCGWINSZ`).
    private func terminalSize() -> (rows: Int, cols: Int) {
        var ws = winsize()
        if ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &ws) == 0, ws.ws_row > 0, ws.ws_col > 0 {
            return (Int(ws.ws_row), Int(ws.ws_col))
        }
        return (24, 80)
    }

    /// How many lines a PageUp/PageDown moves: most of a screen, keeping a
    /// couple of lines of overlap for continuity.
    private func pageStep() -> Int {
        max(1, terminalSize().rows - 3)
    }

    /// Repaints the whole frame: status bar, the wrapped-and-scrolled story
    /// window, and the live input line, then parks the hardware cursor at the
    /// caret (or hides it while scrolled up).
    private func render() {
        let (rows, cols) = terminalSize()
        let bodyRows = max(1, rows - 1)

        box.withLock { st in
            // Re-wrap the transcript only when it grew or the width changed;
            // otherwise a keystroke reuses the cached lines and re-wraps just
            // the one input line. Each paragraph is wrapped with a blank line
            // between paragraphs.
            if st.wrappedCols != cols || st.wrappedCount != st.transcript.count {
                var wrapped: [String] = []
                var isComment: [Bool] = []
                for (i, paragraph) in st.transcript.enumerated() {
                    if i > 0 {
                        wrapped.append("")  // one blank line between paragraphs
                        isComment.append(false)
                    }
                    let lines = TextWrap.wrap(paragraph, width: cols)
                    wrapped += lines
                    isComment += Array(repeating: st.commentIndices.contains(i), count: lines.count)
                }
                st.wrappedTranscript = wrapped
                st.wrappedIsComment = isComment
                st.wrappedCols = cols
                st.wrappedCount = st.transcript.count
            }

            // The visible lines: the wrapped transcript, a blank line, then the
            // live input line (which keeps its exact spacing for caret math). The
            // leading region mirrors `wrappedIsComment` one-for-one, so the paint
            // loop reads that cached flag directly — the separator and input
            // lines sit past its end and are never comments.
            var visual = st.wrappedTranscript
            if !visual.isEmpty { visual.append("") }
            let inputLineStart = visual.count
            let inputLine = Substring(st.prompt + st.input)
            visual += TextWrap.hardSplit(inputLine, width: cols)

            // Clamp the scroll offset to the available history and write it
            // back so the editor's page math stays in range.
            let maxOffset = max(0, visual.count - bodyRows)
            st.scrollOffset = min(st.scrollOffset, maxOffset)
            let live = st.scrollOffset == 0

            let windowEnd = visual.count - st.scrollOffset
            let windowStart = max(0, windowEnd - bodyRows)

            var frame = "\u{1B}[?25l"  // hide cursor while we paint
            frame += "\u{1B}[1;1H\u{1B}[7m" + Self.statusBar(st.status, cols: cols) + "\u{1B}[0m"

            var row = 2
            for lineIndex in windowStart..<windowEnd {
                frame += "\u{1B}[\(row);1H\u{1B}[2K"
                // Comment lines paint dim + italic so a tester's note reads as an
                // aside, not game text. The style wraps the already-wrapped line,
                // so column math (done before, in cells) is untouched.
                if lineIndex < st.wrappedIsComment.count, st.wrappedIsComment[lineIndex] {
                    frame += "\u{1B}[2;3m" + visual[lineIndex] + "\u{1B}[0m"
                } else {
                    frame += visual[lineIndex]
                }
                row += 1
            }
            while row <= rows {
                frame += "\u{1B}[\(row);1H\u{1B}[2K"
                row += 1
            }

            if !live {
                let marker = " -- more (PgDn) -- "
                let col = max(1, cols - DisplayWidth.columns(of: marker) + 1)
                frame += "\u{1B}[\(rows);\(col)H\u{1B}[7m" + marker + "\u{1B}[0m"
            }

            // Place the caret at the input position when live and on-screen.
            // Column math is in terminal cells (via TextWrap/DisplayWidth), not
            // Character counts, so it stays aligned through CJK and emoji.
            let (caretLine, caretColumn) = TextWrap.caretPosition(
                in: inputLine,
                charOffset: st.prompt.count + st.cursor,
                width: cols
            )
            let caretVisualLine = inputLineStart + caretLine
            let caretCol = caretColumn + 1
            let caretScreenRow = 2 + (caretVisualLine - windowStart)
            if live, caretVisualLine >= windowStart, caretScreenRow <= rows {
                frame += "\u{1B}[\(caretScreenRow);\(caretCol)H\u{1B}[?25h"
            }

            emit(frame)
        }
    }

    /// The reverse-video status bar: location on the left, `Score`/`Moves` on
    /// the right, padded to the full width and clipped if it can't fit. Padding
    /// and clipping measure terminal columns (``DisplayWidth``), so a wide
    /// `locationName` still aligns the right-hand score. Internal, not private,
    /// so it can be unit-tested without a live terminal.
    static func statusBar(_ status: StatusLine?, cols: Int) -> String {
        let left = " " + (status?.locationName ?? "")
        let right = status.map { "Score: \($0.score)   Moves: \($0.moves) " } ?? ""
        let leftColumns = DisplayWidth.columns(of: left)
        let rightColumns = DisplayWidth.columns(of: right)
        let gap = cols - leftColumns - rightColumns
        let bar = gap >= 1 ? left + String(repeating: " ", count: gap) + right : left + right
        // Padded, the bar is exactly `cols` wide; only the unpadded branch can
        // overflow, and its width is just the two sides' columns.
        return leftColumns + rightColumns > cols ? DisplayWidth.truncated(bar, toColumns: cols) : bar
    }

    // MARK: - Input

    /// A decoded keypress: an editing command or one or more printable
    /// characters.
    private enum Key {
        case character(String)
        case enter, backspace, deleteForward, tab
        case left, right, home, end
        case historyPrev, historyNext
        case pageUp, pageDown
        case eof, interrupt
    }

    /// One raw byte, or `interrupted` for a read that timed out (the `VTIME`
    /// poll) or was broken by a signal — the caller loops to service a resize.
    /// A genuine terminal close arrives as `SIGHUP`, handled separately, so a
    /// zero-length read here is treated as a timeout, not EOF.
    private enum RawByte {
        case byte(UInt8)
        case eof
        case interrupted
    }

    private func readRawByte() -> RawByte {
        var byte: UInt8 = 0
        let n = read(STDIN_FILENO, &byte, 1)
        if n == 1 { return .byte(byte) }
        if n == 0 { return .interrupted }  // VTIME timeout; nothing to read yet
        return errno == EINTR ? .interrupted : .eof
    }

    /// Services a pending window resize (re-rendering) and returns the next
    /// decoded key, or `nil` when the read timed out — so callers loop. Shared
    /// by the line editor and the Ctrl-C confirm so the resize/poll contract
    /// lives in one place.
    private func nextKey() -> Key? {
        if gnustoWindowResized.exchange(false, ordering: .relaxed) {
            render()
        }
        return readKey()
    }

    /// Reads and decodes the next keypress. Returns `nil` when interrupted, so
    /// the caller can service a pending resize and try again.
    private func readKey() -> Key? {
        switch readRawByte() {
        case .interrupted:
            return nil
        case .eof:
            return .eof
        case .byte(let b):
            switch b {
            case 0x03: return .interrupt
            case 0x04: return .eof
            case 0x09: return .tab
            case 0x0A, 0x0D: return .enter
            case 0x7F, 0x08: return .backspace
            case 0x1B: return readEscapeSequence()
            case 0x00..<0x20: return readKey()  // ignore other control bytes
            default: return decodeUTF8(leadByte: b)
            }
        }
    }

    /// Parses a CSI escape sequence (arrows, Home/End, Delete, Page keys). A
    /// bare or unrecognized ESC is swallowed.
    private func readEscapeSequence() -> Key? {
        guard case .byte(let b1) = readRawByte(), b1 == 0x5B || b1 == 0x4F else {
            return readKey()  // lone ESC; move on to the next key
        }
        guard case .byte(let b2) = readRawByte() else { return readKey() }
        switch b2 {
        case 0x41: return .historyPrev  // Up
        case 0x42: return .historyNext  // Down
        case 0x43: return .right
        case 0x44: return .left
        case 0x48: return .home  // ESC[H / ESC OH
        case 0x46: return .end  // ESC[F / ESC OF
        case 0x30...0x39:  // numeric parameter, terminated by '~'
            var param = String(UnicodeScalar(b2))
            while case .byte(let n) = readRawByte() {
                if n == 0x7E { break }
                // Cap the accumulator: a real parameter is a digit or two, so a
                // stream that never sends the terminator can't grow it without
                // bound. An overlong sequence falls through to the unknown-
                // sequence discard path below.
                guard param.count < 8 else { return readKey() }
                param.append(Character(UnicodeScalar(n)))
            }
            switch param {
            case "1", "7": return .home
            case "4", "8": return .end
            case "3": return .deleteForward
            case "5": return .pageUp
            case "6": return .pageDown
            default: return readKey()
            }
        default:
            return readKey()
        }
    }

    /// Gathers the continuation bytes of a UTF-8 sequence begun by `leadByte`
    /// and returns the resulting character(s).
    private func decodeUTF8(leadByte: UInt8) -> Key? {
        let extra: Int
        switch leadByte {
        case 0xC0...0xDF: extra = 1
        case 0xE0...0xEF: extra = 2
        case 0xF0...0xF7: extra = 3
        default: extra = 0
        }
        var bytes = [leadByte]
        for _ in 0..<extra {
            guard case .byte(let b) = readRawByte() else { break }
            bytes.append(b)
        }
        guard let string = String(bytes: bytes, encoding: .utf8), !string.isEmpty else {
            return readKey()  // invalid sequence; skip it
        }
        return .character(string)
    }

    /// Writes a string straight to stdout, bypassing stdio buffering so frames
    /// land atomically.
    private func emit(_ string: String) {
        let bytes = Array(string.utf8)
        bytes.withUnsafeBytes { buffer in
            guard let base = buffer.baseAddress else { return }
            var offset = 0
            while offset < buffer.count {
                let written = Foundation.write(STDOUT_FILENO, base + offset, buffer.count - offset)
                if written <= 0 { break }
                offset += written
            }
        }
    }

    // MARK: - Ctrl-C confirm

    /// Asks the player to confirm a Ctrl-C quit, reading keys until they answer.
    /// `y` confirms; `n`, Enter, or any unrecognized key cancels; a second
    /// Ctrl-C or Ctrl-D confirms outright. Front-end only — the actual quit
    /// happens when `readLine` returns `.quit` and the REPL calls
    /// `GameWorld.requestQuit()`.
    ///
    /// - Returns: `true` to quit, `false` to keep editing the current line.
    func confirmQuit() -> Bool {
        box.withLock {
            $0.transcript.append("Do you really want to quit? (y/n)")
            $0.scrollOffset = 0
        }
        render()
        while true {
            guard let key = nextKey() else { continue }  // resize or timeout; loop
            switch key {
            case .interrupt, .eof:
                return true  // a second Ctrl-C / Ctrl-D means business
            case .enter:
                return false  // bare Enter defaults to "no"
            case .character(let ch):
                switch ch.lowercased() {
                case "y": return true
                case "n": return false
                default: break  // ignore; keep waiting
                }
            default:
                break  // ignore other keys; keep waiting
            }
        }
    }

    // MARK: - Tab-completion

    /// The result of a Tab-completion attempt: the new input line and caret, and
    /// any candidate words to display when the prefix stays ambiguous.
    struct CompletionOutcome: Equatable {
        var newInput: String
        var newCursor: Int
        var listing: [String]
    }

    /// Completes the word ending at `cursor` against the pool its position and
    /// context imply: at a save/restore filename prompt the word completes
    /// against save names; otherwise the first word completes against verbs and
    /// directions, and anything later against in-scope nouns and directions. A
    /// unique match is inserted with a trailing space; several matches extend to
    /// their longest common prefix, and are listed when they can't be extended
    /// further. Text to the right of the caret is preserved. Pure — unit-tested
    /// directly.
    ///
    /// - Parameters:
    ///   - input: the current line being edited.
    ///   - cursor: the caret's character offset into `input`.
    ///   - candidates: the words available to complete against.
    /// - Returns: the resulting line, caret, and any candidates to list.
    static func complete(
        input: String, cursor: Int, candidates: CompletionCandidates
    ) -> CompletionOutcome {
        let chars = Array(input)
        let caret = max(0, min(cursor, chars.count))
        let unchanged = CompletionOutcome(newInput: input, newCursor: cursor, listing: [])

        // The partial word: the run of non-spaces ending at the caret.
        var wordStart = caret
        while wordStart > 0, !chars[wordStart - 1].isWhitespace {
            wordStart -= 1
        }
        let partial = String(chars[wordStart..<caret])
        guard !partial.isEmpty else { return unchanged }

        // Words before the partial pick the pool.
        let prefix = String(chars[0..<wordStart])
        let preceding =
            prefix
            .split(whereSeparator: { $0.isWhitespace })
            .map { $0.lowercased() }
        let pool = candidatePool(preceding: preceding, candidates: candidates)

        let lowered = partial.lowercased()
        let matches = Set(pool.filter { $0.hasPrefix(lowered) }).sorted()
        guard !matches.isEmpty else { return unchanged }

        let replacement: String
        var listing: [String] = []
        if matches.count == 1 {
            replacement = matches[0] + " "
        } else {
            let lcp = longestCommonPrefix(matches)
            if lcp.count > lowered.count {
                replacement = lcp  // extend as far as they agree
            } else {
                replacement = partial  // no progress; leave as typed and list
                listing = matches
            }
        }

        let suffix = String(chars[caret...])
        return CompletionOutcome(
            newInput: prefix + replacement + suffix,
            newCursor: wordStart + replacement.count,
            listing: listing)
    }

    /// Picks the completion pool: save names when the engine is awaiting a
    /// filename, else verbs and directions to lead a command and in-scope nouns
    /// and directions for later words.
    private static func candidatePool(
        preceding: [String], candidates: CompletionCandidates
    ) -> [String] {
        switch candidates.context {
        case .filename:
            return candidates.saveNames
        case .command:
            return preceding.isEmpty
                ? candidates.verbs + candidates.directions
                : candidates.nouns + candidates.directions
        }
    }

    /// The longest common prefix shared by every word in `words`.
    private static func longestCommonPrefix(_ words: [String]) -> String {
        guard var prefix = words.first else { return "" }
        for word in words.dropFirst() {
            while !word.hasPrefix(prefix) {
                prefix.removeLast()
                if prefix.isEmpty { return "" }
            }
        }
        return prefix
    }

    /// Formats ambiguous candidate words into one transcript line.
    private static func formatCandidateListing(_ candidates: [String]) -> String {
        candidates.joined(separator: "   ")
    }

    // MARK: - Persistent history

    /// The most recent commands kept in the persistent history file.
    static let historyLimit = 1000

    /// The most bytes of history ever read from disk. The file grows one line
    /// per command and is only ever trimmed on load, so a long-running session
    /// (or a hand-edited file) could leave it large; the loader reads only this
    /// much of the tail, and `trimHistory` rewrites anything bigger back down.
    /// 256 KiB comfortably holds far more than `historyLimit` typical commands.
    static let historyByteCap = 256 * 1024

    /// The commands persisted at `url`, oldest first, capped to the most recent
    /// `limit` and with blank lines dropped. A missing or unreadable file yields
    /// an empty history. Only the last `historyByteCap` bytes are read: a file
    /// larger than that is seeked to its tail and the first (partial) line is
    /// dropped, so an overgrown or hand-bloated file never loads whole into
    /// memory.
    ///
    /// - Parameters:
    ///   - url: the history file to read.
    ///   - limit: the maximum number of commands to keep.
    /// - Returns: the loaded commands, oldest first.
    static func loadHistory(from url: URL, limit: Int = historyLimit) -> [String] {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attributes?[.size] as? Int) ?? 0

        let text: String
        if size > historyByteCap, let handle = try? FileHandle(forReadingFrom: url) {
            defer { try? handle.close() }
            try? handle.seek(toOffset: UInt64(size - historyByteCap))
            let tail = (try? handle.readToEnd()) ?? Data()
            // The seek lands mid-line; drop everything up to (and including) the
            // first newline so no partial command survives.
            guard var decoded = String(data: tail, encoding: .utf8) else { return [] }
            if let newline = decoded.firstIndex(of: "\n") {
                decoded = String(decoded[decoded.index(after: newline)...])
            }
            text = decoded
        } else {
            guard let whole = try? String(contentsOf: url, encoding: .utf8) else { return [] }
            text = whole
        }

        let lines =
            text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return Array(lines.suffix(limit))
    }

    /// Trims an overgrown history file in place, rewriting it to its most recent
    /// `limit` entries when it exceeds either that many lines or `historyByteCap`
    /// bytes. Called once at launch, right after `loadHistory`, so the on-disk
    /// file can't grow without bound across sessions while the crash-safe
    /// append-per-command path stays untouched. Best-effort: a failure leaves
    /// the file as-is and never interrupts play.
    ///
    /// - Parameters:
    ///   - url: the history file to trim.
    ///   - limit: the maximum number of commands to keep.
    static func trimHistory(at url: URL, limit: Int = historyLimit) {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attributes?[.size] as? Int) ?? 0
        guard size > 0 else { return }

        let recent = loadHistory(from: url, limit: limit)
        // Only rewrite when we'd actually shrink the file: too many bytes, or a
        // full line count (a proxy for "at or over the entry cap").
        guard size > historyByteCap || recent.count >= limit else { return }

        let rewritten = Data((recent.joined(separator: "\n") + "\n").utf8)
        guard (try? rewritten.write(to: url, options: .atomic)) != nil else { return }
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    /// Appends one submitted command to the history file, creating the parent
    /// directory if needed. Blank lines are skipped. Best-effort: a write
    /// failure never interrupts play. The directory is created owner-only (0700)
    /// and the file tightened to 0600, since command history can reveal a
    /// player's activity and has no reason to be group- or world-readable.
    ///
    /// - Parameters:
    ///   - line: the command to record.
    ///   - url: the history file to append to.
    static func appendHistory(_ line: String, to url: URL) {
        guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        let data = Data((line + "\n").utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url)
        }
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
