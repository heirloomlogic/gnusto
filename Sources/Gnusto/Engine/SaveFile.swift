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
    }

    /// Writes the state to `path` — relative paths resolve against the
    /// current directory (classic behavior), and an existing file is
    /// silently overwritten.
    static func write(_ state: WorldState, title: String, to path: String) throws {
        let file = SaveFile(format: currentFormat, title: title, state: state)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(file).write(to: URL(fileURLWithPath: path), options: .atomic)
    }

    /// Reads and validates a save from `path`, returning the state it holds.
    static func read(from path: String, expecting title: String) throws(ReadError) -> WorldState {
        guard let data = FileManager.default.contents(atPath: path),
            let file = try? JSONDecoder().decode(SaveFile.self, from: data),
            file.format == currentFormat
        else { throw .unreadable }
        guard file.title == title else { throw .wrongGame }
        return file.state
    }
}
