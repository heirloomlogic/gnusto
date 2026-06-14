/// Where the game's text goes and player input comes from. Synchronous by
/// design: a blocking console read is fine for a CLI; an async variant can
/// be added later without breaking this protocol's clients.
public protocol IOHandler: Sendable {
    /// Writes pre-formatted text (no trailing-newline policy is implied).
    func write(_ text: String)

    /// Prompts for and returns one line of input; `nil` means end of input.
    func readLine(prompt: String) -> String?

    /// Optionally displays a status line (location, score, turns).
    func showStatus(_ status: StatusLine)
}

extension IOHandler {
    /// Defaults to showing no status line.
    public func showStatus(_ status: StatusLine) {}
}
