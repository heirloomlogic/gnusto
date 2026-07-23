import Foundation

/// Where session transcripts are written, mirroring `SaveStore`'s directory
/// convention: a `GNUSTO_TRANSCRIPT_DIR` override, else a per-game folder under
/// the user's application-support directory. A transcript is a plain-text
/// replay — `> command` lines interleaved with the game's output — that a tester
/// can share or attach to a bug report.
enum TranscriptStore {
    /// The extension given to recorded transcripts.
    static let fileExtension = "txt"

    /// The default per-user directory for a game's transcripts:
    /// `<app-support>/Gnusto/Transcripts/<sanitized title>`, or the directory
    /// named by the `GNUSTO_TRANSCRIPT_DIR` environment variable when it is set.
    ///
    /// - Parameters:
    ///   - title: the game's title, which names its per-game subfolder.
    ///   - environment: the environment to read `GNUSTO_TRANSCRIPT_DIR` from
    ///     (injectable for tests; defaults to the process environment).
    /// - Returns: the transcripts directory URL.
    static func defaultDirectory(
        forGameTitled title: String,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL {
        if let override = environment["GNUSTO_TRANSCRIPT_DIR"], !override.isEmpty {
            return URL(
                fileURLWithPath: (override as NSString).expandingTildeInPath,
                isDirectory: true)
        }
        let base =
            (try? FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask,
                appropriateFor: nil, create: false))
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return
            base
            .appendingPathComponent("Gnusto", isDirectory: true)
            .appendingPathComponent("Transcripts", isDirectory: true)
            .appendingPathComponent(sanitize(title), isDirectory: true)
    }

    /// Resolves the tester's `script` argument into a transcript file URL. A
    /// bare name (or none) becomes `<name>.txt` — or `<title>-<timestamp>.txt`
    /// when unnamed — in the game's transcripts directory; an explicit path (it
    /// contains a `/`, or starts with `~`) is honored verbatim, tilde expanded.
    ///
    /// - Parameters:
    ///   - name: the `script` argument, or `nil` for a timestamped default.
    ///   - title: the game's title, naming the folder and the default filename.
    ///   - now: the clock for the default timestamp (injectable for tests).
    ///   - environment: the environment to read `GNUSTO_TRANSCRIPT_DIR` from.
    /// - Returns: the transcript file URL to write.
    static func url(
        forName name: String?,
        gameTitled title: String,
        now: Date = Date(),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL {
        if let name, isExplicitPath(name) {
            return URL(fileURLWithPath: (name as NSString).expandingTildeInPath)
        }
        let base = name.map(sanitize) ?? "\(sanitize(title))-\(timestamp(now))"
        return
            defaultDirectory(forGameTitled: title, environment: environment)
            .appendingPathComponent(base)
            .appendingPathExtension(fileExtension)
    }

    /// Whether `name` names an explicit filesystem path — it contains a `/` or
    /// starts with `~` — rather than a bare transcript slot.
    private static func isExplicitPath(_ name: String) -> Bool {
        name.hasPrefix("~") || name.contains("/")
    }

    /// The characters kept verbatim in a slot name; every other run collapses to
    /// a single hyphen. Matches `SaveStore`'s sanitizer so both stores neutralize
    /// path tricks identically.
    private static let nameCharacters = Set(
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")

    /// Reduces a name or title to one safe path component: alphanumerics and
    /// underscores survive; every other run (spaces, hyphens, `..`) collapses to
    /// a single hyphen. An all-punctuation name becomes `transcript`.
    private static func sanitize(_ raw: String) -> String {
        let squeezed = String(raw.map { nameCharacters.contains($0) ? $0 : " " })
            .split(separator: " ")
            .joined(separator: "-")
        return squeezed.isEmpty ? "transcript" : squeezed
    }

    /// A sortable `yyyymmdd-hhmmss` stamp for the default filename. Built from
    /// explicit calendar components so it never depends on the current locale.
    private static func timestamp(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let c = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: date)
        return String(
            format: "%04d%02d%02d-%02d%02d%02d",
            c.year ?? 0, c.month ?? 0, c.day ?? 0,
            c.hour ?? 0, c.minute ?? 0, c.second ?? 0)
    }
}

/// Records a live session to a plain-text transcript file in the same
/// interleaved `> command` + output format `ScriptedIOHandler` produces — so a
/// recorded transcript reads the way the player saw it and can be replayed or
/// shared. Toggled by the tester's `script` / `unscript` commands, or armed for
/// a whole session by the `GNUSTO_TRANSCRIPT` environment variable.
final class TranscriptRecorder {
    private let handle: FileHandle
    /// The file being written, for the confirmation the REPL shows.
    let path: String

    /// Opens the transcript file at `url` for writing, creating intermediate
    /// directories and truncating any existing file.
    ///
    /// - Parameter url: the transcript file to write.
    /// - Throws: if the directory or file can't be created and opened.
    init(url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: url.path, contents: nil)
        self.handle = try FileHandle(forWritingTo: url)
        self.path = url.path
    }

    /// Records one turn: the prompt-echoed command, then its output.
    ///
    /// - Parameters:
    ///   - command: the command the player typed.
    ///   - output: the turn's output text.
    func record(command: String, output: String) {
        append("> \(command)\n")
        appendOutput(output)
    }

    /// Records a tester comment line, kept in the transcript as a note.
    ///
    /// - Parameter commentLine: the raw comment line, marker included.
    func record(commentLine: String) {
        append("> \(commentLine)\n")
    }

    /// Records the game's opening output (intro, banner, first look) — for a
    /// recording armed before the loop began, so the transcript is complete.
    ///
    /// - Parameter openingOutput: the opening turn's output text.
    func record(openingOutput: String) {
        appendOutput(openingOutput)
    }

    /// Flushes and closes the transcript file.
    func close() {
        try? handle.close()
    }

    /// Appends a block of output, rendering the `<br>` hard-break marker as a
    /// newline (via `TextWrap.plain`) the way the plain console does.
    private func appendOutput(_ output: String) {
        let text = TextWrap.plain(output)
        append(text.isEmpty ? "\n" : "\(text)\n\n")
    }

    private func append(_ text: String) {
        try? handle.write(contentsOf: Data(text.utf8))
    }
}
