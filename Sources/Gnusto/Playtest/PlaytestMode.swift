/// Whether this process was started to *speak* MCP rather than to be played.
///
/// Every Gnusto game is `@main struct Game: Game, GameMain {}`, so the switch
/// lives where `main()` lives and every game — including one written by a
/// third party who has never read this file — becomes a play-test server for
/// the cost of a command-line flag.
///
/// Modelled on ``SeedRequest`` and ``StatusFooter``: a value that reads the
/// environment, hands back what it found, and never reaches for
/// `ProcessInfo` itself. `GameMain` is the composition root and passes both
/// the arguments and the environment in, which is also what makes this
/// testable without a subprocess.
enum PlaytestMode {
    /// The command-line flag that asks for the server.
    static let flag = "--mcp"

    /// The environment variable that asks for the same thing, for a client
    /// that can set an environment but not an argument vector.
    static let variable = "GNUSTO_MCP"

    /// Whether either channel asked for the play-test server.
    ///
    /// `GNUSTO_MCP` is a **flag**: any value counts, an empty one included.
    /// That is the `GNUSTO_PLAIN` policy (`GameMain.defaultIOHandler`), and it
    /// is the right one here for the same reason — a mode switch is either
    /// thrown or not, so there is no value to misread and therefore nothing to
    /// complain about. `GNUSTO_STATUS` deliberately chose on/off *words*
    /// instead, but it writes into the transcript, where a typo silently
    /// costing the operator their footer is worth a word on standard error.
    ///
    /// The argument scan skips element zero, which is the executable path and
    /// not something the operator typed.
    ///
    /// - Parameters:
    ///   - arguments: the process arguments, `CommandLine.arguments` in
    ///     production, including the executable path at element zero.
    ///   - environment: the environment to read `GNUSTO_MCP` from.
    /// - Returns: true when this process should serve MCP instead of playing.
    static func requested(arguments: [String], environment: [String: String]) -> Bool {
        arguments.dropFirst().contains(flag) || environment[variable] != nil
    }
}
