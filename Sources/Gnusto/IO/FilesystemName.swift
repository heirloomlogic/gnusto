import Foundation

/// Turns a name a player or an author typed into one safe path component.
///
/// **One spelling for every store that names a file after something a human
/// wrote.** A save slot, a game's saves directory, a transcript slot and a
/// game's transcripts directory all ask the same question, and they have to
/// answer it identically: a name the player types at the save prompt is the
/// name the restore prompt lists back, and a title names two sibling folders
/// under `Gnusto/`. The rule lived twice, once in `SaveStore` and once in
/// `TranscriptStore`, and the copies had already drifted in what they did with
/// a name that survived to nothing.
///
/// The rule:
///
/// - **Unicode decides what a letter is**, not ASCII. `セーブ` is four
///   characters worth keeping, so two Japanese slot names are two files. The
///   old rule kept only `[A-Za-z0-9_]`, which left both of them empty.
/// - **The name is normalized to NFC first.** macOS and Linux disagree about
///   the form a filename arrives in — an `é` typed on one may be one scalar
///   and on the other two — and a name that round-trips through the filesystem
///   has to resolve to the file it came from on both. Normalizing before use is
///   what makes that true.
/// - **Everything else is a separator**, and a run of separators collapses to a
///   single `-`. That is what neutralizes the path tricks: a `/`, a `\`, a run
///   of dots, a control character and a leading dot all stop being themselves,
///   so a slot name can never walk out of its directory and never names a
///   dotfile.
/// - **The result is bounded in bytes**, not characters, because the
///   filesystem's limit is a byte limit. ``maximumBytes`` is the budget.
/// - **Nothing usable left is `nil`**, not a stand-in name. A caller with a
///   player in front of it refuses. A caller naming a directory after a game's
///   title has nobody to ask, and takes ``untitled`` — the same literal in both
///   stores, so a title that survives to nothing still names *one* folder name
///   rather than a different one per kind. Two games with unusable titles do
///   still share those folders; a title of pure punctuation is a far stranger
///   thing than a title in Japanese, and Japanese now names its own.
///
/// The transform is idempotent: running it on its own output returns that
/// output unchanged. Every store relies on that, because a name read back off
/// disk is resolved through here again to reach its file.
enum FilesystemName {
    /// The byte budget for one component.
    ///
    /// `NAME_MAX` is 255 bytes on ext4 and APFS alike, and it counts the
    /// extension too. 200 leaves room for `.gnusto`, for `.txt`, and for the
    /// `-yyyymmdd-hhmmss` stamp ``TranscriptStore`` appends to a title — with
    /// enough slack that no caller has to do this arithmetic itself.
    static let maximumBytes = 200

    /// The folder name a game whose title holds no letter, number or underscore
    /// gets. Shared by every store that names a directory after a title, so the
    /// one case the rule cannot answer is at least answered the same way twice.
    static let untitled = "untitled"

    /// Reduces `raw` to one safe path component, or `nil` when nothing usable
    /// survives.
    ///
    /// - Parameter raw: the name as typed.
    /// - Returns: the component, or `nil` for a name with no letters, numbers
    ///   or underscores in it.
    static func component(_ raw: String) -> String? {
        let normalized = raw.precomposedStringWithCanonicalMapping
        let squeezed =
            String(normalized.map { keep($0) ? $0 : " " })
            .split(separator: " ")
            .joined(separator: "-")
        let bounded = truncated(squeezed)
        return bounded.isEmpty ? nil : bounded
    }

    /// Whether a character survives verbatim: a Unicode letter or number, or
    /// the underscore, which needs no escaping anywhere a filename is read.
    private static func keep(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
    }

    /// `squeezed` cut to ``maximumBytes`` UTF-8 bytes, on a character boundary,
    /// with any hyphen the cut exposed at the end removed — so the result is
    /// still something this function would return unchanged. A name already
    /// inside the budget, which is nearly every name, comes back untouched.
    private static func truncated(_ squeezed: String) -> String {
        guard squeezed.utf8.count > maximumBytes else { return squeezed }
        var bytes = 0
        var kept = ""
        for character in squeezed {
            let width = character.utf8.count
            if bytes + width > maximumBytes { break }
            bytes += width
            kept.append(character)
        }
        while kept.hasSuffix("-") { kept.removeLast() }
        return kept
    }
}
