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

    /// Prints the prompt and reads one line from standard input.
    ///
    /// - Parameter prompt: the prompt to print before reading.
    /// - Returns: the line read, or `nil` at end of input.
    public func readLine(prompt: String) -> String? {
        print(prompt, terminator: "")
        return Swift.readLine()
    }
}
