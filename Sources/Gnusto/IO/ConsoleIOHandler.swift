/// Plain terminal IO.
public struct ConsoleIOHandler: IOHandler {
    /// Creates a console IO handler.
    public init() {}

    /// Writes text to standard output without a trailing newline.
    public func write(_ text: String) {
        print(text, terminator: "")
    }

    /// Prints the prompt and reads one line from standard input.
    public func readLine(prompt: String) -> String? {
        print(prompt, terminator: "")
        return Swift.readLine()
    }
}
