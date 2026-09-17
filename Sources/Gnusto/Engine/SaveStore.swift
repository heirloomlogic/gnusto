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

    /// The command-history sidecar's filename. A dotfile *without* the
    /// `.gnusto` extension, so it lives in the saves directory yet is never
    /// mistaken for a save slot by `existingSaveNames` (which filters on the
    /// extension). Keeping the name here, next to `fileExtension`, keeps that
    /// no-collision invariant in one file.
    static let historyFileName = ".history"

    /// The per-game command-history file: the history sidecar inside the given
    /// saves directory.
    ///
    /// - Parameter directory: the game's saves directory.
    /// - Returns: the history file URL.
    static func historyURL(in directory: URL) -> URL {
        directory.appendingPathComponent(historyFileName)
    }

    /// Resolves a player's answer to the save/restore prompt into a file URL,
    /// or `nil` when the answer names no usable slot. Pure — it never touches
    /// the filesystem, so it is safe on the read path.
    ///
    /// - A **bare name** (no `/`, no leading `~`) becomes
    ///   `directory/<name>.gnusto`, the name run through
    ///   ``FilesystemName/component(_:)``. That keeps Unicode letters and
    ///   numbers, so two Japanese slot names are two files, and it neutralizes
    ///   path tricks like `..`, so a slot name can never escape `directory`.
    /// - A bare name with **nothing usable in it** — no letter, no number and
    ///   no underscore anywhere in it — is `nil`. It used to become the literal
    ///   slot `save`, which meant two names that shared nothing but being
    ///   unusable overwrote each other in silence. The caller has a player in
    ///   front of it and refuses.
    /// - An **explicit path** (contains `/`, or starts with `~`) is expanded and
    ///   returned as-is, unchanged from the classic behavior.
    ///
    /// The path this returns is the one a *new* save takes. To reach a file that
    /// already exists, use ``locate(_:in:)`` — a file written before the byte
    /// bound existed, or written on a volume that stores a decomposed name, is
    /// not at the path this computes.
    ///
    /// - Parameters:
    ///   - answer: the raw line the player typed at the prompt.
    ///   - directory: the saves directory bare names resolve under.
    /// - Returns: the file URL to read or write, or `nil` for an unusable name.
    static func resolve(_ answer: String, in directory: URL) -> URL? {
        let trimmed = answer.trimmingCharacters(in: .whitespaces)
        if isExplicitPath(trimmed) {
            return URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath)
        }
        guard let slot = FilesystemName.component(trimmed) else { return nil }
        return
            directory
            .appendingPathComponent(slot)
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
    /// - Returns: the file URL to write, or `nil` when the answer names no
    ///   usable slot — in which case nothing was created.
    static func resolveForWrite(_ answer: String, in directory: URL) throws -> URL? {
        // Resolved first, so an unusable name provisions nothing: a refused
        // save leaves no empty directory behind.
        let trimmed = answer.trimmingCharacters(in: .whitespaces)
        guard resolve(trimmed, in: directory) != nil else { return nil }
        if !isExplicitPath(trimmed) {
            // Owner-only (0700): a saves directory holds a player's whole
            // progress and has no reason to be group- or world-readable.
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700])
        }
        // Through `locate`, so saving over a slot the restore prompt listed
        // writes the file that prompt would read. A slot whose file predates
        // the byte bound, or whose name the volume stores decomposed, is at a
        // path `resolve` alone does not compute, and writing the computed path
        // would leave the player two files and show them one.
        return locate(trimmed, in: directory)
    }

    /// The file `answer` names *on disk*: ``resolve(_:in:)``'s path when it
    /// exists or when nothing else matches, and otherwise the directory entry
    /// that spells the same name.
    ///
    /// Unlike ``resolve(_:in:)`` this reads the directory, which is what lets
    /// it answer two cases the pure computation cannot:
    ///
    /// - **A name longer than ``FilesystemName/maximumBytes``.** The old rule
    ///   had no bound, so a long name names a file of its full length. The
    ///   computed path is the truncated one and no such file exists; the entry
    ///   matching the *unbounded* form is the player's save.
    /// - **A decomposed name on a byte-exact volume.** A saves directory copied
    ///   from HFS+ onto ext4 holds NFD filenames. The computed path is NFC and
    ///   does not exist, while the entry NFC-equal to it is the same name and
    ///   the same save.
    ///
    /// The directory is consulted *before* the computed path, not after, so the
    /// answer does not depend on how the volume compares filenames: a
    /// case-insensitive, normalization-insensitive APFS volume says the composed
    /// path exists when the decomposed file is what is there, and taking that
    /// answer would hand back a URL whose bytes are not the file's. Reading the
    /// entry gives the same URL on every volume. It costs one `readdir` on a
    /// path a player reaches by typing at a prompt.
    ///
    /// Falling back to the computed path rather than to `nil` keeps a genuinely
    /// missing slot failing where it always did, with the path it was asked for.
    ///
    /// - Parameters:
    ///   - answer: the raw line the player typed at the prompt.
    ///   - directory: the saves directory bare names resolve under.
    /// - Returns: the file URL, or `nil` when the answer names no usable slot.
    static func locate(_ answer: String, in directory: URL) -> URL? {
        let trimmed = answer.trimmingCharacters(in: .whitespaces)
        guard let computed = resolve(trimmed, in: directory) else { return nil }
        if isExplicitPath(trimmed) { return computed }
        guard let wanted = FilesystemName.unbounded(trimmed) else { return computed }
        return existingSaves(in: directory).first { $0.name == wanted }?.url ?? computed
    }

    /// Whether `answer` names an explicit filesystem path — it contains a `/`
    /// or starts with `~` — rather than a bare slot.
    ///
    /// **The one spelling of that question in the package.** Three callers ask
    /// it of three different kinds of name — a save slot here, a transcript slot
    /// in ``TranscriptRecorder``, a play label in ``PlaytestSessions`` — and
    /// they have to agree, because a name the player types at the save prompt is
    /// the same name a harness passes back to reach the file it wrote. It lived
    /// here first and stays here; the others call it rather than re-typing four
    /// characters that have drifted before.
    static func isExplicitPath(_ answer: String) -> Bool {
        answer.hasPrefix("~") || answer.contains("/")
    }

    /// The names of the saves already in `directory`, sorted — the basenames of
    /// its `.gnusto` files, without the extension. Empty when the directory has
    /// none, or doesn't exist yet.
    ///
    /// Only names a player could type back are listed: a basename is kept when
    /// ``FilesystemName/component(_:)`` returns that same name, so typing it at
    /// the restore prompt lands on the file it came from. Everything this
    /// package writes passes, since the transform is idempotent. What it
    /// excludes is a `.gnusto` dropped in the directory by hand under a name
    /// the prompt would refuse or rewrite — listing one of those offered a slot
    /// that could not then be restored.
    ///
    /// The comparison is against the name's **NFC form**, not its bytes,
    /// because a volume may hand a filename back decomposed even though it was
    /// written composed. The two spell the same name, and dropping a player's
    /// save from the listing over that would be the same disappearance this
    /// listing is here to prevent. They do not reach the same *path* on a
    /// byte-exact volume, which is why the URL travels with the name: see
    /// ``existingSaves(in:)``.
    ///
    /// - Parameter directory: the saves directory to scan.
    /// - Returns: the sorted slot names.
    static func existingSaveNames(in directory: URL) -> [String] {
        existingSaves(in: directory).map(\.name)
    }

    /// The saves already in `directory`, sorted by name: each listed slot name
    /// paired with the file that name came from.
    ///
    /// The pairing is the point. The name is the NFC form, which is what a
    /// player is shown and what they type back; the URL is the directory entry
    /// itself, which on a byte-exact volume may be decomposed, and which for a
    /// save written before the byte bound is longer than the rule now produces.
    /// Re-deriving the path from the displayed name would miss both, and the
    /// prompt would offer a slot that then failed to restore.
    ///
    /// A basename is kept when ``FilesystemName/unbounded(_:)`` returns that
    /// same name — the rule the prompt applies, minus the bound, so a save
    /// written under either rule qualifies. What it excludes is a `.gnusto`
    /// dropped in the directory by hand under a name the prompt would rewrite.
    ///
    /// - Parameter directory: the saves directory to scan.
    /// - Returns: the slot names and their files, sorted by name.
    static func existingSaves(in directory: URL) -> [(name: String, url: URL)] {
        let contents =
            (try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: nil)) ?? []
        return
            contents
            .filter { $0.pathExtension == fileExtension }
            .compactMap { url -> (name: String, url: URL)? in
                let basename = url.deletingPathExtension().lastPathComponent
                let nfc = basename.precomposedStringWithCanonicalMapping
                guard FilesystemName.unbounded(basename) == nfc else { return nil }
                return (name: nfc, url: url)
            }
            .sorted { $0.name < $1.name }
    }

    /// Whether the given environment injects a saves directory via
    /// `GNUSTO_SAVE_DIR` — the way replay tools and scripted drivers point a
    /// world they built through `GameMain` at a scratch directory. Such a
    /// session is program-driven, not a human at a terminal, and its save
    /// prompts are slot-only; see `GameWorld.savePathsRestricted`.
    ///
    /// - Parameter environment: the environment to read (injectable for tests;
    ///   defaults to the process environment).
    /// - Returns: whether `GNUSTO_SAVE_DIR` is set to a non-empty value.
    static func directoryIsInjected(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        !(environment["GNUSTO_SAVE_DIR"] ?? "").isEmpty
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
        return savesDirectory(
            forGameTitled: title,
            under:
                base
                .appendingPathComponent("Gnusto", isDirectory: true)
                .appendingPathComponent("Saves", isDirectory: true))
    }

    /// The per-game folder under a given saves root: the title's component, or
    /// the folder the *old* rule named when that one exists and the new one does
    /// not.
    ///
    /// The fallback is the whole reason this is a function. The old rule kept
    /// only ASCII, so `Café Noir` named `Caf-Noir` and now names `Café-Noir`,
    /// and a player who has saves in the first would open the game to an empty
    /// slot list. Preferring the new name once it exists means a game that has
    /// never run under the old rule never pays a `stat`, and a game migrating
    /// stops consulting the old name the moment it has a new folder of its own.
    /// Nothing copies or renames: the old folder keeps being the live one until
    /// a player has a reason to leave it.
    ///
    /// - Parameters:
    ///   - title: the game's title.
    ///   - root: the `Saves` directory the per-game folders sit in (injectable
    ///     for tests).
    /// - Returns: the game's saves directory.
    static func savesDirectory(forGameTitled title: String, under root: URL) -> URL {
        let current = root.appendingPathComponent(
            FilesystemName.component(title) ?? FilesystemName.untitled,
            isDirectory: true)
        if FileManager.default.fileExists(atPath: current.path) { return current }
        // `save` is what the old rule's own empty-result fallback was here.
        let legacy = root.appendingPathComponent(
            FilesystemName.legacyComponent(title) ?? "save", isDirectory: true)
        if legacy != current, FileManager.default.fileExists(atPath: legacy.path) {
            return legacy
        }
        return current
    }
}
