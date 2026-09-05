import Foundation

/// The on-disk save format: a format version, the game's identity, and the
/// whole `WorldState` as JSON.
///
/// A save is keyed by *name* throughout — timers by their declared name,
/// globals by the property they were declared as — and the title-only
/// fingerprint can't tell two builds of one game apart. So a restore re-binds
/// what the current definition still declares and **drops what it doesn't**,
/// for timers and globals alike: an author who retires a fuse or a `@Global`
/// between builds must not thereby void every save their players are holding.
/// The complementary rule is that a name the definition *does* declare, whose
/// stored value a rule could not read back, refuses the whole file
/// (`WorldState.isConsistent(with:)`) — dropping *that* would restore a world
/// the game then traps on.
struct SaveFile: Codable {
    /// The format this build writes.
    ///
    /// Bump it when the shape changes in a way an older *reader* could not cope
    /// with: a key removed or renamed, a value's encoding changed, or a new
    /// property with no sensible default. Adding a property that *has* a
    /// default is not one of those — `WorldState.init(from:)` reads its absence
    /// as "this save predates it" and supplies the default, which is the whole
    /// point of hand-writing that coder. Bumping for an additive field would
    /// mean nothing and cost the reader nothing, so don't.
    ///
    /// What the bump does **not** buy, and this is the part to know before
    /// reaching for it: nothing threads `format` into `WorldState.init(from:)`.
    /// There is no `decoder.userInfo` plumbing and no per-format branch, so a
    /// build at format 2 with ``minimumReadableFormat`` still at 1 decodes a
    /// format-1 save with the format-2 decoder — and a renamed key would find
    /// no match and silently take its default, which is the quiet version of
    /// the very bug this file exists to prevent. The number by itself is a
    /// label, not a migration.
    ///
    /// So a genuine shape change costs a decision rather than a constant. Raise
    /// ``minimumReadableFormat`` with it and the old saves are refused
    /// honestly, in words the player can act on, at the price of every save
    /// they are holding. Leave the floor where it is and the decoder has to
    /// earn it: the renamed key falls back to the old key by hand, the changed
    /// encoding is read both ways, and the fallbacks stay until the floor
    /// finally rises past them. Both are real options; picking neither and
    /// bumping the number is the one that looks like it worked.
    static let currentFormat = 1

    /// The oldest format this build still reads.
    ///
    /// Two constants rather than one equality test, because `format ==
    /// currentFormat` refuses every older save *by construction* — so the
    /// mechanism meant to signal "the shape moved" instead said "start again",
    /// and bumping the version to fix a compatibility bug would have voided
    /// every save on disk. Raise this only when a format genuinely can no
    /// longer be read, and expect it to cost players their saves when it moves.
    static let minimumReadableFormat = 1

    let format: Int
    let title: String
    let state: WorldState

    /// Just the header, decodable without the state.
    ///
    /// Read first so a file this build cannot parse can still say *why*: a save
    /// from a newer format holds a `WorldState` whose shape is unknown here, so
    /// decoding the whole file would fail as garbage and the player would be
    /// told "Restore failed." about a file that is perfectly good and merely
    /// too new. It earns a second answer on the way: a save for a *different
    /// game* is now recognized as such even when its state won't decode.
    private struct Envelope: Decodable {
        let format: Int
        let title: String
    }

    /// Why a read was rejected — mapped to distinct player-facing lines.
    enum ReadError: Error {
        /// Missing file, unreadable data, or not a save at all.
        case unreadable
        /// A save whose format this build does not read — written by a newer
        /// version, or older than ``minimumReadableFormat``. Distinct from
        /// `unreadable` because the file is fine and the player can act on it,
        /// where a corrupt one leaves them nothing to do.
        case unsupportedFormat
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
        // The header first, and the state only once the header says this build
        // can make sense of it — see `Envelope`.
        guard let data = try? Data(contentsOf: url),
            let envelope = try? JSONDecoder().decode(Envelope.self, from: data)
        else { throw .unreadable }
        // Title before format, because the title is the more fundamental
        // answer and the two can both be wrong at once: a save for *another
        // game* in a format this build doesn't read is not "written by a
        // different version of this game", and told that, a player goes looking
        // for an old build of something they were never playing. Which game a
        // file belongs to is knowable whatever its format — the envelope is
        // two scalars and doesn't move — so nothing is gained by asking about
        // the shape first.
        guard envelope.title == definition.title else { throw .wrongGame }
        guard (minimumReadableFormat...currentFormat).contains(envelope.format) else {
            throw .unsupportedFormat
        }
        guard let file = try? JSONDecoder().decode(SaveFile.self, from: data)
        else { throw .unreadable }
        guard file.state.isConsistent(with: definition) else { throw .inconsistent }
        return reconcile(file.state, with: definition)
    }

    /// Settles a validated save against what this build actually declares, so
    /// what `read` hands back is ready to install.
    ///
    /// Everything that reconciles a decoded file with reality lives here rather
    /// than at the restore prompt, because each piece is a property of the
    /// *format* — a caller that reads a save and forgot to run one of them
    /// would install a world the engine believes is impossible.
    ///
    /// - Parameters:
    ///   - state: the decoded, validated state.
    ///   - definition: what this build declares.
    /// - Returns: the state to install.
    private static func reconcile(
        _ state: WorldState, with definition: GameDefinition
    ) -> WorldState {
        var state = state
        // Decoding writes every property at once, funnels included, so the one
        // invariant the engine maintains by construction is settled here rather
        // than taken on trust from the file: a boarding whose vehicle isn't in
        // the player's room is dropped, exactly as a live stranding would.
        state.strandIfSeparated()
        // Re-bind the saved schedule and the saved globals to what this build
        // declares, dropping the names it doesn't — the policy this type's doc
        // comment gives, applied in the one place that can guarantee it ran.
        // A global that *is* declared has already been checked by
        // `isConsistent`; what goes here is only the unknown, and the `@Global`
        // then reads its declared default.
        state.activeFuses = state.activeFuses.filter { definition.timers[$0.key] != nil }
        state.activeDaemons = state.activeDaemons.filter { definition.timers[$0] != nil }
        state.globals = state.globals.filter { definition.globals[$0.key] != nil }
        return state
    }
}
