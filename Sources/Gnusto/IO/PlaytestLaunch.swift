/// A failure to launch the optional MCP play-test server.
public enum PlaytestLaunchError: Error, CustomStringConvertible {
    /// This build has the `Playtest` package trait disabled.
    case unavailable

    /// The diagnostic a launcher reports when MCP support is unavailable.
    public var description: String {
        """
        --mcp (or GNUSTO_MCP) asks for the play-test server, and this binary was built \
        without it. Rebuild with the Gnusto package's `Playtest` trait enabled — it is on \
        by default, so the likely culprit is a release build made with \
        --disable-default-traits.
        """
    }
}

/// The trait-safe entry point for launching a game's MCP play-test server.
///
/// This facade is available in every engine build. The server implementation
/// is compiled only when the package's `Playtest` trait is enabled.
public enum PlaytestLaunch {
    /// Serves an importable game over MCP on the process's standard streams.
    ///
    /// The server claims stdout for protocol frames before bootstrapping the
    /// game, prepares it once, and creates independent worlds for sessions.
    /// Invoke this before constructing a playing world or presentation handler.
    ///
    /// - Parameters:
    ///   - game: the factory for the game to serve.
    ///   - environment: the launch environment controlling the play-test server.
    /// - Throws: ``PlaytestLaunchError/unavailable`` when this build has the
    ///   `Playtest` package trait disabled.
    public static func serve(
        _ game: PackagedGame, environment: [String: String]
    ) async throws {
        #if Playtest
        await PlaytestServer.serve(game: game.makeGame, environment: environment)
        #else
        throw PlaytestLaunchError.unavailable
        #endif
    }
}
