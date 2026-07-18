import Foundation

/// Turns what a player types at the save/restore prompt into a real file, and
/// lists the saves already on disk.
///
/// The goal is that a player never has to know a filesystem path: a **bare
/// name** like `autumn` is a save *slot* under a per-user saves directory,
/// stored as `autumn.gnusto`. Anything that looks like a path — it contains a
/// `/`, or starts with `~` — is honored verbatim (tilde expanded), preserving
/// the classic "save to a file you name" behavior for anyone who wants it.
enum SaveStore {
    /// The extension given to named saves.
    static let fileExtension = "gnusto"

    /// Resolves a player's answer to the save/restore prompt into a file URL.
    /// Pure — it never touches the filesystem, so it is safe on the read path.
    ///
    /// - A **bare name** (no `/`, no leading `~`) becomes
    ///   `directory/<sanitized name>.gnusto`. Sanitizing also neutralizes path
    ///   tricks like `..`, so a slot name can never escape `directory`.
    /// - An **explicit path** (contains `/`, or starts with `~`) is expanded and
    ///   returned as-is, unchanged from the classic behavior.
    ///
    /// - Parameters:
    ///   - answer: the raw line the player typed at the prompt.
    ///   - directory: the saves directory bare names resolve under.
    /// - Returns: the file URL to read or write.
    static func resolve(_ answer: String, in directory: URL) -> URL {
        let trimmed = answer.trimmingCharacters(in: .whitespaces)
        if isExplicitPath(trimmed) {
            return URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath)
        }
        return
            directory
            .appendingPathComponent(sanitize(trimmed))
            .appendingPathExtension(fileExtension)
    }

    /// Resolves `answer` for a *write*, creating the saves directory first when
    /// the answer is a bare slot name. An explicit path is written wherever the
    /// player pointed, with no directory creation — the classic behavior. The
    /// saves directory is `SaveStore`'s to provision (it's the layer that
    /// invented it), which keeps `SaveFile` a pure serializer.
    ///
    /// - Parameters:
    ///   - answer: the raw line the player typed at the prompt.
    ///   - directory: the saves directory bare names resolve under.
    /// - Throws: if the saves directory can't be created.
    /// - Returns: the file URL to write.
    static func resolveForWrite(_ answer: String, in directory: URL) throws -> URL {
        if !isExplicitPath(answer.trimmingCharacters(in: .whitespaces)) {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
        }
        return resolve(answer, in: directory)
    }

    /// Whether `answer` names an explicit filesystem path — it contains a `/`
    /// or starts with `~` — rather than a bare save slot.
    private static func isExplicitPath(_ answer: String) -> Bool {
        answer.hasPrefix("~") || answer.contains("/")
    }

    /// The names of the saves already in `directory`, sorted — the basenames of
    /// its `.gnusto` files, without the extension. Empty when the directory has
    /// none, or doesn't exist yet.
    ///
    /// - Parameter directory: the saves directory to scan.
    /// - Returns: the sorted slot names.
    static func existingSaveNames(in directory: URL) -> [String] {
        let contents =
            (try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: nil)) ?? []
        return
            contents
            .filter { $0.pathExtension == fileExtension }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }

    /// The default per-user directory for a game's saves:
    /// `<app-support>/Gnusto/Saves/<sanitized title>`, or the directory named by
    /// the `GNUSTO_SAVE_DIR` environment variable when it is set.
    ///
    /// - Parameters:
    ///   - title: the game's title, which names its per-game subfolder.
    ///   - environment: the environment to read `GNUSTO_SAVE_DIR` from
    ///     (injectable for tests; defaults to the process environment).
    /// - Returns: the saves directory URL.
    static func defaultDirectory(
        forGameTitled title: String,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL {
        if let override = environment["GNUSTO_SAVE_DIR"], !override.isEmpty {
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
            .appendingPathComponent("Saves", isDirectory: true)
            .appendingPathComponent(sanitize(title), isDirectory: true)
    }

    /// The characters kept verbatim in a slot name; every other run (including
    /// spaces and hyphens the player typed) collapses to a single hyphen.
    private static let nameCharacters = Set(
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")

    /// Reduces a name or title to one safe path component: alphanumerics and
    /// underscores survive; every other run collapses to a single hyphen. An
    /// empty result (a name that was all punctuation) becomes `save`, so the
    /// resolver always yields a usable filename.
    private static func sanitize(_ raw: String) -> String {
        let squeezed = String(raw.map { nameCharacters.contains($0) ? $0 : " " })
            .split(separator: " ")
            .joined(separator: "-")
        return squeezed.isEmpty ? "save" : squeezed
    }
}
