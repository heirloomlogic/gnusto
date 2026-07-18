import Foundation

/// The on-disk save format: a format version, the game's identity, and the
/// whole `WorldState` as JSON. Rules and timer bodies are code, not data — a
/// restore re-binds the saved timer schedule to the bootstrapped definition
/// by name, dropping names the definition no longer declares (the title-only
/// fingerprint can't tell two builds of one game apart, and a stale name
/// must not crash the tick loop).
struct SaveFile: Codable {
    static let currentFormat = 1

    let format: Int
    let title: String
    let state: WorldState

    /// Why a read was rejected — mapped to distinct player-facing lines.
    enum ReadError: Error {
        /// Missing file, unreadable data, not JSON, or a format we don't know.
        case unreadable
        /// A real save file, but for a different game title.
        case wrongGame
        /// A well-formed save for this game, but referentially inconsistent
        /// with the current definition — an unknown ID, a mistyped global, or a
        /// containment cycle a crafted or corrupt file could carry into the
        /// engine. Treated exactly like `unreadable` at the prompt.
        case inconsistent
    }

    /// Writes the state to `url`, silently overwriting any existing file. A
    /// pure serializer: it assumes the containing directory exists (the caller
    /// provisions the saves directory — see `SaveStore`). The file is tightened
    /// to owner-only (0600) after the write, since a save can carry a game's
    /// entire progress and the atomic replace creates a fresh inode each time.
    static func write(_ state: WorldState, title: String, to url: URL) throws {
        let file = SaveFile(format: currentFormat, title: title, state: state)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(file).write(to: url, options: .atomic)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    /// Reads a save from `url` and validates it against `definition`, returning
    /// the state it holds. Beyond the format and title fingerprint, the state
    /// must be referentially consistent with the definition (see
    /// `WorldState.isConsistent(with:)`); anything else is rejected rather than
    /// handed to the engine.
    static func read(
        from url: URL, matching definition: GameDefinition
    ) throws(ReadError) -> WorldState {
        guard let data = try? Data(contentsOf: url),
            let file = try? JSONDecoder().decode(SaveFile.self, from: data),
            file.format == currentFormat
        else { throw .unreadable }
        guard file.title == definition.title else { throw .wrongGame }
        guard file.state.isConsistent(with: definition) else { throw .inconsistent }
        return file.state
    }
}
