/// Where the game's text goes and player input comes from. Synchronous by
/// design: a blocking console read is fine for a CLI; an async variant can
/// be added later without breaking this protocol's clients.
public protocol IOHandler: Sendable {
    /// Writes pre-formatted text (no trailing-newline policy is implied).
    ///
    /// - Parameter text: the text to write.
    func write(_ text: String)

    /// Prompts for and returns one unit of input; `nil` means end of input.
    ///
    /// - Parameter prompt: the prompt to show before reading.
    /// - Returns: the input read, or `nil` at end of input.
    func readLine(prompt: String) -> Input?

    /// Optionally displays a status line (location, score, turns).
    ///
    /// - Parameter status: the status line to display.
    func showStatus(_ status: StatusLine)

    /// Receives the words Tab-completion may offer for the next input line.
    /// A handler with a line editor uses them; the plain console ignores them.
    ///
    /// - Parameter candidates: verbs, in-scope nouns, directions, and save names.
    func updateCompletions(_ candidates: CompletionCandidates)

    /// Called once when the game reaches an ending (won, lost, or quit),
    /// after the final output has been written. A full-screen handler holds
    /// its last frame for the player and leaves the ending visible on the
    /// primary screen; the default does nothing.
    ///
    /// - Parameter finalText: the last turn's output — the game's ending text.
    func finish(_ finalText: String)
}

/// One unit of player input from an ``IOHandler``: a line for the engine to
/// run, or a front-end quit request (e.g. Ctrl-C) that ends the game *without*
/// being parsed as a command — so it can't be swallowed by an open save/restore
/// prompt or clash with a game that has redefined the `quit` verb. The REPL
/// maps `.quit` to `GameWorld.requestQuit()`, which is keyed to `Intent.quit`
/// rather than the editable verb word.
public enum Input: Sendable, Equatable {
    /// A line of text to parse and perform as a command.
    case line(String)
    /// A quit requested by the front end itself, bypassing the parser.
    case quit
}

extension IOHandler {
    /// Defaults to showing no status line.
    public func showStatus(_ status: StatusLine) {}

    /// Defaults to ignoring completion candidates.
    public func updateCompletions(_ candidates: CompletionCandidates) {}

    /// Defaults to no end-of-session behavior — right for handlers whose
    /// output already persists (console, scripted).
    public func finish(_ finalText: String) {}
}

/// A snapshot of what Tab-completion can offer for the upcoming input line: the
/// game's verbs, the nouns and adjectives currently in scope, the movement
/// directions, and the save slot names on disk. The engine assembles it after
/// each turn and pushes it to the IO handler, because the synchronous line
/// editor can't reach back into the `GameWorld` actor mid-read.
public struct CompletionCandidates: Sendable, Equatable {
    /// What the next input line will be read as, which decides the pool: a
    /// normal command, or a save/restore filename.
    public enum Context: Sendable, Equatable {
        /// A normal command line — completes against verbs, nouns, directions.
        case command
        /// A save/restore filename prompt — the whole line completes against
        /// existing save names.
        case filename
    }

    /// How the next input line will be interpreted.
    public var context: Context
    /// Verb words that can lead a command (`take`, `open`, `look`).
    public var verbs: [String]
    /// Noun and adjective words for the items the player can currently see.
    public var nouns: [String]
    /// Movement words (`north`, `n`, `up`).
    public var directions: [String]
    /// Save slot names already on disk, for completing a save/restore filename.
    public var saveNames: [String]

    /// Creates a set of completion candidates.
    ///
    /// - Parameters:
    ///   - context: how the next input line will be interpreted.
    ///   - verbs: verb words that can lead a command.
    ///   - nouns: noun and adjective words for in-scope items.
    ///   - directions: movement words.
    ///   - saveNames: save slot names on disk.
    public init(
        context: Context = .command,
        verbs: [String] = [],
        nouns: [String] = [],
        directions: [String] = [],
        saveNames: [String] = []
    ) {
        self.context = context
        self.verbs = verbs
        self.nouns = nouns
        self.directions = directions
        self.saveNames = saveNames
    }
}
