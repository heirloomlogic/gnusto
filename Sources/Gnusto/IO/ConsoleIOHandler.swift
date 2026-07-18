/// Plain terminal IO.
public struct ConsoleIOHandler: IOHandler {
    /// Creates a console IO handler.
    public init() {}

    /// Writes text to standard output without a trailing newline. The `<br>`
    /// hard-break marker is turned into a newline so it never shows literally
    /// (plain output doesn't reflow, so it carries no other markup).
    ///
    /// - Parameter text: the text to write.
    public func write(_ text: String) {
        print(TextWrap.plain(text), terminator: "")
    }

    /// Prints the prompt and reads one line from standard input. A plain
    /// console (piped or redirected input) never originates a quit signal, so
    /// every read is a `.line`; end of input is `nil`.
    ///
    /// - Parameter prompt: the prompt to print before reading.
    /// - Returns: the line read as `.line`, or `nil` at end of input.
    public func readLine(prompt: String) -> Input? {
        print(prompt, terminator: "")
        return Swift.readLine().map(Input.line)
    }
}
