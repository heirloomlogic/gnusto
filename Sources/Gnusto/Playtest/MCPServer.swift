import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// The JSON-RPC dispatch under `--mcp`, and the process-level plumbing that
/// puts it on stdio.
///
/// **Why this is hand-rolled and must stay hand-rolled.** There is a perfectly
/// good MCP SDK for Swift, and adding it here would be a mistake: the
/// `.dev-tooling` sentinel in `Package.swift` hides *plugins* from downstream
/// consumers, and nothing hides a dependency whose types appear in
/// `Sources/Gnusto/**`. An SDK would land in the dependency graph of every
/// game anybody ever writes with this engine, forever, in exchange for the
/// four methods below. `JSONEncoder` is already in the graph; that is the
/// whole dependency this needs.
///
/// **Nothing here may trap.** The rest of the engine's house style is the
/// opposite — a bootstrap diagnostic is fatal, an unlisted award register is a
/// `fatalError`, and that is right, because those are an author's mistakes
/// caught at the earliest possible moment. This file's inputs come from a
/// *remote party*, and a crash is the worst of the available answers: it takes
/// down every session in the process (Stage 3) and tells the client nothing.
/// So malformed JSON is a `-32700`, an unknown method a `-32601`, bad
/// parameters a `-32602`, and a tool that throws is a tool *result* carrying
/// `isError: true` — a distinction MCP draws on purpose, because an agent can
/// read a failed tool result and try something else, where a protocol error is
/// a bug report about the server. No force unwraps, no `try!`, no
/// `fatalError`, no exceptions to any of it.

// MARK: - Dispatch

/// One MCP server's worth of behavior, as a pure function from a request line
/// to a response line.
///
/// A value with no mutable state, so ``handle(line:)`` can be called
/// concurrently and the test suite never has to spawn a process to exercise
/// the protocol.
struct MCPServer: Sendable {
    /// The MCP revision to claim when a client offers none.
    static let defaultProtocolVersion = "2024-11-05"

    /// JSON-RPC: the frame wasn't JSON.
    static let parseError = -32_700

    /// JSON-RPC: it was JSON, but not a request.
    static let invalidRequest = -32_600

    /// JSON-RPC: no such method.
    static let methodNotFound = -32_601

    /// JSON-RPC: the method exists and the parameters don't fit it.
    static let invalidParams = -32_602

    /// What to call this server in `initialize`.
    let name: String

    /// This server's own version, not the game's and not the protocol's.
    let version: String

    /// A sentence for the client to show an agent that has never met this
    /// server, or `nil`.
    let instructions: String?

    /// Every tool this server offers. See ``PlaytestTools``.
    let tools: [PlaytestTool]

    /// Whether this frame is a `tools/call` on a row that advances a world, and
    /// so has to be run in the order it arrived rather than concurrently.
    ///
    /// Deliberately cheap and deliberately incurious: anything it cannot read —
    /// a malformed frame, an unknown tool, a method that is not `tools/call` —
    /// is not mutating, and goes down the concurrent path to be answered (or
    /// refused) there. Nothing here reports an error, because a predicate that
    /// also validated would be two answers to one question.
    ///
    /// It costs a second parse of the frames that say yes. That is a few
    /// microseconds against a turn, and it buys a `serve` loop that reads as
    /// what it is.
    ///
    /// - Parameter line: the raw frame, without its newline.
    /// - Returns: whether it must be run in wire order.
    func mutatesState(line: String) -> Bool {
        guard let request = try? JSONValue(text: line),
            request["method"]?.stringValue == "tools/call",
            let name = request["params"]?["name"]?.stringValue
        else { return false }
        return tools.first { $0.name == name }?.mutatesState ?? false
    }

    /// Answers one request frame.
    ///
    /// - Parameter line: one JSON document, without its newline.
    /// - Returns: the response frame, or `nil` when the request was a
    ///   notification and there is nothing to say.
    func handle(line: String) async -> String? {
        guard let request = try? JSONValue(text: line) else {
            // Nothing is known about the frame, its id included, so the reply
            // carries the null id JSON-RPC reserves for exactly this.
            return failure(id: .null, code: Self.parseError, message: "invalid JSON")
        }
        let id = request["id"]
        guard let method = request["method"]?.stringValue else {
            guard let id, !id.isNull else { return nil }
            return failure(id: id, code: Self.invalidRequest, message: "no method")
        }

        // A notification carries no id, and must never be answered — not with
        // a result, and not with a complaint about itself. Answering one is
        // the classic way to wedge a client that is not expecting traffic.
        guard let id, !id.isNull else { return nil }

        // `notifications/initialized` arrives without an id and so is already
        // covered above; naming it anyway means a client that mistakenly puts
        // an id on one gets silence rather than a `-32601` for a method this
        // server does in fact know.
        guard !method.hasPrefix("notifications/"), method != "initialized" else { return nil }

        switch method {
        case "initialize":
            return initialize(id: id, params: request["params"])
        case "ping":
            return success(id: id, result: [:])
        case "tools/list":
            return success(id: id, result: ["tools": .array(tools.map(\.listing))])
        case "tools/call":
            return await call(id: id, params: request["params"] ?? [:])
        default:
            return failure(id: id, code: Self.methodNotFound, message: "no such method: \(method)")
        }
    }

    /// The handshake.
    ///
    /// The client's offered `protocolVersion` is echoed back rather than
    /// answered with a fixed one: this server implements no version-specific
    /// behavior, so agreeing with whatever the client said is both true and
    /// the widest compatibility available. A client that offers nothing gets
    /// ``defaultProtocolVersion``.
    ///
    /// - Parameters:
    ///   - id: the request id to answer.
    ///   - params: the request's params, if it had any.
    /// - Returns: the response frame.
    private func initialize(id: JSONValue, params: JSONValue?) -> String {
        var result: [String: JSONValue] = [
            "protocolVersion": .string(
                params?["protocolVersion"]?.stringValue ?? Self.defaultProtocolVersion),
            "capabilities": ["tools": [:]],
            "serverInfo": ["name": .string(name), "version": .string(version)],
        ]
        if let instructions {
            result["instructions"] = .string(instructions)
        }
        return success(id: id, result: .object(result))
    }

    /// Runs one tool.
    ///
    /// Note which failures are which. A missing or unknown tool name is a
    /// `-32602`: the client sent a request that cannot be satisfied, and no
    /// tool ran. A tool that *ran* and threw is a successful JSON-RPC call
    /// carrying a failed tool result, because the agent asked a reasonable
    /// question and deserves a readable answer it can act on.
    ///
    /// - Parameters:
    ///   - id: the request id to answer.
    ///   - params: the request's params.
    /// - Returns: the response frame.
    private func call(id: JSONValue, params: JSONValue) async -> String {
        guard let name = params["name"]?.stringValue else {
            return failure(
                id: id, code: Self.invalidParams, message: "tools/call needs a tool name")
        }
        guard let tool = tools.first(where: { $0.name == name }) else {
            return failure(id: id, code: Self.invalidParams, message: "no such tool: \(name)")
        }
        do {
            let outcome = try await tool.handler(params["arguments"] ?? [:])
            var result: [String: JSONValue] = [
                "content": [["type": "text", "text": .string(outcome.text)]],
                "isError": false,
            ]
            if let structured = outcome.structured {
                result["structuredContent"] = structured
            }
            return success(id: id, result: .object(result))
        } catch {
            return success(
                id: id,
                result: [
                    "content": [["type": "text", "text": .string("\(error)")]],
                    "isError": true,
                ])
        }
    }

    /// Renders a successful response.
    ///
    /// - Parameters:
    ///   - id: the request id, echoed exactly as it arrived.
    ///   - result: the method's result.
    /// - Returns: the response frame.
    private func success(id: JSONValue, result: JSONValue) -> String {
        JSONValue.object(["jsonrpc": "2.0", "id": id, "result": result]).text
    }

    /// Renders an error response.
    ///
    /// - Parameters:
    ///   - id: the request id, or `.null` when the frame never yielded one.
    ///   - code: the JSON-RPC error code.
    ///   - message: a one-line explanation for a human reading the client log.
    /// - Returns: the response frame.
    private func failure(id: JSONValue, code: Int, message: String) -> String {
        JSONValue.object([
            "jsonrpc": "2.0",
            "id": id,
            "error": ["code": .integer(code), "message": .string(message)],
        ]).text
    }
}

// MARK: - The process

/// The `--mcp` entry point: everything between `main()` deciding to serve and
/// the client hanging up.
enum PlaytestServer {
    /// The server's name in `initialize`. One binary is one game, so the game
    /// is named in the instructions rather than here, where a client is liable
    /// to key its configuration off the string.
    static let serverName = "gnusto-playtest"

    /// The play-test server's own version. Bump it when the tool table changes
    /// shape, not when a game does.
    static let serverVersion = "0.1.0"

    /// Serves MCP on stdio until end of input.
    ///
    /// Called from `GameMain.main()` *before the world is built*, which has
    /// three consequences worth stating out loud:
    ///
    /// - `defaultIOHandler` is never called, so `TerminalIOHandler` never runs
    ///   its `init` and never enters the alternate screen buffer. A server
    ///   that had painted a full-screen UI over the client's terminal would be
    ///   memorable.
    /// - **`SeedRequest` is deliberately not consulted.** A seed belongs to a
    ///   session, arrives with the request that opens one, and defaults to 0
    ///   to match `bin/playtest-replay --seed 0`. Reading `GNUSTO_SEED` here
    ///   would let a stray variable in some MCP client's environment re-seed
    ///   every session in every game silently — which is precisely the
    ///   reproducibility failure `SeedRequest` exists to prevent, inverted.
    /// - Bootstrap warnings and a rejected environment value still go to
    ///   standard error, as they do on the normal path. They are also carried
    ///   in the `survey` tool's result, so an agent sees them without anybody
    ///   having to read the client's log.
    ///
    /// - Parameters:
    ///   - game: makes the game to serve — `Self.init`, called once here.
    ///   - environment: the process environment, which reaches the session
    ///     registry through the tool table: `GNUSTO_MCP_MAX_SESSIONS` caps how
    ///     many sessions hold a live world, and `GNUSTO_PLAYTEST_DIR` moves
    ///     where they write. It is a parameter rather than a `ProcessInfo`
    ///     lookup because `GameMain` is the composition root and every other
    ///     environment read in the engine goes through it.
    static func serve<G: Game>(game: () -> G, environment: [String: String]) async {
        let protocolOut = claimProtocolChannel()
        let writer = StdioWriter(descriptor: protocolOut)

        let prepared: PreparedGame
        do {
            prepared = try PreparedGame(game())
        } catch {
            // A game that cannot boot cannot be played, and pretending to
            // serve one would hand the agent a table of tools that all fail.
            // Die the way the normal path dies, on the channel it dies on.
            writeToStandardError("\(error)")
            exit(1)
        }
        if let report = prepared.definition.warningReport {
            writeToStandardError(report)
        }

        let server = MCPServer(
            name: serverName,
            version: serverVersion,
            instructions: """
                Play-test server for the game "\(prepared.definition.title)". \
                One binary is one game, so no tool takes a game name.
                """,
            tools: PlaytestTools.table(for: prepared, environment: environment))

        // A reader is answered in its own child task, so a slow call does not
        // stall the ones behind it, and the group drains in-flight work before
        // `serve` returns on end of input. Discarding, because a child's result
        // is the frame it already wrote.
        //
        // A call that advances a world is awaited here instead, in the order the
        // frames arrived. A client may have several `tools/call` in flight — a
        // model can emit two `move` blocks in one turn — and letting two of them
        // reach one session in whatever order the scheduler chose would apply
        // the turns in an order nobody picked. This harness sells one property
        // above all others: that a command list replays to the same transcript.
        // Ordering the writes is how that stays true of the session itself and
        // not merely of the replay. See ``PlaytestTool/mutatesState``.
        //
        // The cost is that two `move`s cannot overlap even in different
        // sessions. A turn is microseconds of engine work, so that is nothing;
        // readers still overtake freely, which is the case the concurrency was
        // for.
        await withDiscardingTaskGroup { group in
            for await frame in StdioReader.frames(from: STDIN_FILENO) {
                if server.mutatesState(line: frame) {
                    if let response = await server.handle(line: frame) {
                        await writer.write(response)
                    }
                    continue
                }
                group.addTask {
                    guard let response = await server.handle(line: frame) else { return }
                    await writer.write(response)
                }
            }
        }
    }

    /// Takes the protocol channel away from everyone.
    ///
    /// Standard output is duplicated onto a private descriptor, which the
    /// writer keeps, and fd 1 is then pointed at standard error. After this,
    /// **any** write to stdout — a `print` in a rule body, a debug line in a
    /// third-party game, a library that logs — lands harmlessly in the client's
    /// stderr log instead of corrupting a JSON frame.
    ///
    /// The engine itself is already clean: `Sources/` contains exactly two
    /// `print` calls, both in `ConsoleIOHandler`, and no `ConsoleIOHandler` is
    /// constructed in this mode. But Gnusto's whole pitch is that a game is a
    /// Swift type somebody else writes, and one forgotten
    /// `print("debug: \(x)")` in their `before` rule would produce a parse
    /// error naming nothing, on a channel nobody thinks to suspect. Four lines
    /// turn an unauditable class of corruption into an annoyance.
    ///
    /// (Buffering, for the curious: `print` writes through the C `stdout`
    /// stream, which is now attached to stderr's file, so stray output may
    /// appear late or out of order relative to `writeToStandardError`. Late
    /// and out of order is fine. On the wire it would not have been.)
    ///
    /// - Returns: the descriptor the protocol goes out on.
    private static func claimProtocolChannel() -> Int32 {
        let duplicate = dup(STDOUT_FILENO)
        // A failed `dup` means the process is out of descriptors, which is not
        // a reason to redirect the only channel there is; speak on stdout and
        // hope nobody prints.
        guard duplicate >= 0 else { return STDOUT_FILENO }
        _ = dup2(STDERR_FILENO, STDOUT_FILENO)
        return duplicate
    }
}
