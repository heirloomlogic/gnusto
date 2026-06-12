/// Plain terminal IO.
public struct ConsoleIOHandler: IOHandler {
    public init() {}

    public func write(_ text: String) {
        print(text, terminator: "")
    }

    public func readLine(prompt: String) -> String? {
        print(prompt, terminator: "")
        return Swift.readLine()
    }
}
