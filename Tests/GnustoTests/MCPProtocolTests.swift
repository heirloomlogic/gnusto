import Foundation
import Testing

@testable import CloakOfDarkness
@testable import Gnusto

/// The protocol layer of the play-test server: the JSON-RPC dispatch, the
/// error codes, the tool table, and the line framing under all of it.
///
/// Everything here drives `MCPServer.handle(line:)` directly. That method is a
/// pure function from a request frame to a response frame precisely so the
/// suite never has to spawn a process, wire up a pipe, or wait for a
/// handshake — and so a framing mistake is a failing assertion rather than a
/// client that quietly declines to connect.
///
/// Note what is *not* here: an `expectTrap`. The whole contract of this layer
/// is that no input can trap it — malformed JSON, a missing method, an unknown
/// tool and a tool that throws are each an answer on the wire, not a
/// `fatalError` — so there is nothing to assert a trap on, and a test that
/// added one would be asserting the opposite of the design. See the note at
/// the top of `MCPServer.swift`.
struct MCPProtocolTests {
    /// A server over one game, with the real tool table, writing into a
    /// directory of its own.
    ///
    /// `GNUSTO_PLAYTEST_DIR` on the same precedent as `GNUSTO_SAVE_DIR`: a test
    /// that opens a session must never write into the developer's real
    /// `.context/playtest`, where it would sit next to a play-test round's
    /// evidence and look like part of it.
    private func server() throws -> MCPServer {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        return MCPServer(
            name: "gnusto-playtest",
            version: "test",
            instructions: nil,
            tools: PlaytestTools.table(
                for: try PreparedGame(OperaHouse()),
                environment: ["GNUSTO_PLAYTEST_DIR": root.path]))
    }

    /// A server over one tool that always fails, for the tool-error case.
    private func explodingServer() -> MCPServer {
        MCPServer(
            name: "gnusto-playtest",
            version: "test",
            instructions: nil,
            tools: [
                PlaytestTool(
                    name: "explode",
                    mutatesState: false,
                    description: "Always throws.",
                    inputSchema: ["type": "object", "properties": [:]],
                    outputSchema: nil,
                    handler: { _ in throw Boom() })
            ])
    }

    /// A tool failure with a message worth reading.
    private struct Boom: Error, CustomStringConvertible {
        var description: String { "the tool exploded" }
    }

    /// Parses a response frame, failing the test rather than the process if it
    /// somehow isn't JSON.
    private func parse(_ frame: String?) throws -> JSONValue {
        try JSONValue(text: try #require(frame))
    }

    // MARK: - The handshake

    /// The client's offered version comes back verbatim. This server
    /// implements no version-specific behavior, so agreeing is both honest and
    /// the widest compatibility on offer — and a client that gets a *different*
    /// version than it asked for is entitled to hang up.
    @Test func initializeEchoesTheClientsProtocolVersion() async throws {
        let response = try parse(
            await server().handle(
                line: """
                    {"jsonrpc":"2.0","id":1,"method":"initialize","params":\
                    {"protocolVersion":"2025-06-18","capabilities":{},\
                    "clientInfo":{"name":"t","version":"1"}}}
                    """))

        #expect(response["jsonrpc"]?.stringValue == "2.0")
        #expect(response["id"]?.intValue == 1)
        #expect(response["result"]?["protocolVersion"]?.stringValue == "2025-06-18")
        #expect(response["result"]?["capabilities"]?["tools"] == .object([:]))
        #expect(response["result"]?["serverInfo"]?["name"]?.stringValue == "gnusto-playtest")
        #expect(response["result"]?["serverInfo"]?["version"]?.stringValue == "test")
        #expect(response["error"] == nil)
    }

    /// A client that offers nothing still gets a version, so the handshake
    /// completes rather than half-completing.
    @Test func initializeFallsBackToADefaultVersion() async throws {
        let response = try parse(
            await server().handle(line: #"{"jsonrpc":"2.0","id":"a","method":"initialize"}"#))

        #expect(response["id"]?.stringValue == "a")
        #expect(
            response["result"]?["protocolVersion"]?.stringValue
                == MCPServer.defaultProtocolVersion)
    }

    /// A notification carries no id and must never be answered — not with a
    /// result, and not with a complaint. Answering one is a classic way to
    /// wedge a client that is not expecting the traffic.
    @Test func aNotificationIsNeverAnswered() async throws {
        let server = try server()
        #expect(await server.handle(line: #"{"jsonrpc":"2.0","method":"notifications/initialized"}"#) == nil)
        #expect(await server.handle(line: #"{"jsonrpc":"2.0","method":"notifications/cancelled"}"#) == nil)
        // Not even an unknown method, which as a *request* would be a -32601.
        #expect(await server.handle(line: #"{"jsonrpc":"2.0","method":"nonsense"}"#) == nil)
    }

    @Test func pingIsAnsweredWithAnEmptyResult() async throws {
        let response = try parse(await server().handle(line: #"{"jsonrpc":"2.0","id":7,"method":"ping"}"#))

        #expect(response["id"]?.intValue == 7)
        #expect(response["result"] == .object([:]))
    }

    // MARK: - Refusing badly

    @Test func anUnknownMethodIsMethodNotFound() async throws {
        let response = try parse(
            await server().handle(line: #"{"jsonrpc":"2.0","id":2,"method":"resources/list"}"#))

        #expect(response["id"]?.intValue == 2)
        #expect(response["error"]?["code"]?.intValue == -32_601)
        #expect(response["result"] == nil)
    }

    /// Garbage and truncation are the same answer, and both carry the null id
    /// JSON-RPC reserves for a frame that never yielded one.
    @Test func malformedJSONIsAParseError() async throws {
        let server = try server()
        for line in [#"{"jsonrpc":"2.0","id":3,"meth"#, "not json at all", "[", #"{"a":}"#] {
            let response = try parse(await server.handle(line: line))
            #expect(response["error"]?["code"]?.intValue == -32_700)
            #expect(response["id"] == .null)
        }
    }

    @Test func aRequestWithNoMethodIsAnInvalidRequest() async throws {
        let response = try parse(await server().handle(line: #"{"jsonrpc":"2.0","id":4}"#))

        #expect(response["error"]?["code"]?.intValue == -32_600)
    }

    @Test func callingANonexistentToolIsInvalidParams() async throws {
        let response = try parse(
            await server().handle(
                line: #"{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"nope"}}"#))

        #expect(response["error"]?["code"]?.intValue == -32_602)
    }

    /// The distinction MCP exists to draw: a tool that *ran* and failed is a
    /// successful call carrying a failed result, because an agent can read
    /// that and try something else. A JSON-RPC `error` would tell it the
    /// server is broken.
    @Test func aThrowingToolIsAToolErrorAndNotAProtocolError() async throws {
        let response = try parse(
            await explodingServer().handle(
                line: #"{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"explode"}}"#))

        #expect(response["error"] == nil)
        #expect(response["result"]?["isError"] == .bool(true))
        #expect(response["result"]?["content"]?.arrayValue?.first?["text"]?.stringValue == "the tool exploded")
    }

    // MARK: - The tool table

    /// The drift test. Every row of the table is advertised, with its prose
    /// and its schema, and nothing is advertised that isn't in the table —
    /// which is the invariant that has to survive the table growing through
    /// the stages that add sessions, moves and coverage.
    @Test func toolsListEnumeratesEveryEntryInTheTable() async throws {
        let table = PlaytestTools.table(for: try PreparedGame(OperaHouse()), environment: [:])
        let response = try parse(await server().handle(line: #"{"jsonrpc":"2.0","id":8,"method":"tools/list"}"#))
        let listed = try #require(response["result"]?["tools"]?.arrayValue)

        #expect(listed.count == table.count)
        #expect(
            listed.compactMap { $0["name"]?.stringValue }.sorted()
                == table.map(\.name).sorted())
        for entry in listed {
            #expect(entry["description"]?.stringValue?.isEmpty == false)
            #expect(entry["inputSchema"]?["type"]?.stringValue == "object")
        }
    }

    // MARK: - survey

    /// Survey end to end over the wire: parseable JSON, in both channels,
    /// naming rooms the game actually has.
    ///
    /// It takes a session, and that is the firewall rather than an argument for
    /// its own sake — the survey is the answer key, and whether a caller may
    /// read it is a fact about the caller. This one opens with the default role,
    /// which is the human case. `PlaytestCoverageTests` holds the refusal.
    @Test func surveyReturnsTheGamesRooms() async throws {
        let server = try server()
        let opened = try parse(
            await server.handle(
                line: """
                    {"jsonrpc":"2.0","id":8,"method":"tools/call","params":\
                    {"name":"open","arguments":{"label":"surveying"}}}
                    """))
        let session = try #require(
            opened["result"]?["structuredContent"]?["session"]?.stringValue)
        let response = try parse(
            await server.handle(
                line: """
                    {"jsonrpc":"2.0","id":9,"method":"tools/call","params":\
                    {"name":"survey","arguments":{"session":"\(session)"}}}
                    """))

        #expect(response["result"]?["isError"] == .bool(false))

        // A tool that declares an outputSchema sends structuredContent, and
        // the text block carries the same document for a client that doesn't
        // read structured results.
        let structured = try #require(response["result"]?["structuredContent"])
        let text = try #require(response["result"]?["content"]?.arrayValue?.first?["text"]?.stringValue)
        #expect(try JSONValue(text: text) == structured)

        #expect(structured["title"]?.stringValue == "Cloak of Darkness")
        let rooms = try #require(structured["rooms"]?.arrayValue)
        let names = rooms.compactMap { $0["name"]?.stringValue }
        #expect(names.contains("Foyer of the Opera House"))
        #expect(names.contains("Cloakroom"))
        #expect(names.contains("Foyer Bar"))

        // The exits are the map, reported without running a single author
        // closure: the foyer's west exit is the cloakroom.
        let foyer = try #require(rooms.first { $0["name"]?.stringValue == "Foyer of the Opera House" })
        let west = try #require(foyer["exits"]?.arrayValue?.first { $0["direction"]?.stringValue == "west" })
        #expect(west["kind"]?.stringValue == "open")
        #expect(west["destination"]?.stringValue == "cloakroom")
    }

    // MARK: - Framing

    /// Newline-delimited JSON, and `read(2)` returns whatever the pipe has.
    /// A frame that arrives in two pieces — or eight, mid-word and mid-brace —
    /// is one frame.
    @Test func aFrameSplitAcrossReadsIsReassembled() {
        var buffer = LineBuffer()
        let frame = #"{"jsonrpc":"2.0","id":1,"method":"ping"}"#
        let bytes = Array("\(frame)\n".utf8)

        var seen: [String] = []
        for chunk in stride(from: 0, to: bytes.count, by: 7) {
            let piece = Array(bytes[chunk..<min(chunk + 7, bytes.count)])
            seen += buffer.frames(in: piece)
        }
        #expect(seen == [frame])
    }

    /// Three frames in one read, the last of them incomplete: two come out
    /// now, the third when its newline does.
    @Test func severalFramesInOneReadComeOutSeparately() {
        var buffer = LineBuffer()
        let read = "{\"a\":1}\n{\"b\":2}\n{\"c\":"
        let first = buffer.frames(in: Array(read.utf8))
        #expect(first == [#"{"a":1}"#, #"{"b":2}"#])

        let second = buffer.frames(in: Array("3}\n".utf8))
        #expect(second == [#"{"c":3}"#])
    }

    /// Blank padding is politeness, not a frame. `\r\n` line endings are the
    /// same frame as `\n`.
    @Test func blankLinesAndCarriageReturnsAreTolerated() {
        var buffer = LineBuffer()
        #expect(buffer.frames(in: Array("\n\n".utf8)).isEmpty)
        #expect(buffer.frames(in: Array("{\"a\":1}\r\n".utf8)) == [#"{"a":1}"#])
    }

    // MARK: - The mode switch

    /// `--mcp` and `GNUSTO_MCP`, which decide whether a game binary plays or
    /// serves.
    struct ModeSwitch {
        @Test func theFlagOnTheCommandLineAsksForTheServer() {
            #expect(PlaytestMode.requested(arguments: ["Fulminate", "--mcp"], environment: [:]))
            #expect(!PlaytestMode.requested(arguments: ["Fulminate"], environment: [:]))
        }

        /// Element zero is the executable path, not something the operator
        /// typed — a binary that happened to live in a directory called
        /// `--mcp` would otherwise never be playable.
        @Test func theExecutablePathIsNotAnArgument() {
            #expect(!PlaytestMode.requested(arguments: ["/tmp/--mcp/Fulminate"], environment: [:]))
            #expect(!PlaytestMode.requested(arguments: ["--mcp"], environment: [:]))
        }

        /// A flag, not a setting: any value counts, an empty one included.
        /// That is `GNUSTO_PLAIN`'s policy, and the right one for a mode
        /// switch — there is no value to misread, so there is nothing to
        /// complain about. `GNUSTO_STATUS` chose on/off words instead because
        /// it writes into the transcript.
        @Test func theEnvironmentVariableIsAFlagAndTakesAnyValue() {
            for value in ["1", "", "0", "off", "no", "yes please"] {
                #expect(PlaytestMode.requested(arguments: ["Fulminate"], environment: ["GNUSTO_MCP": value]))
            }
            #expect(!PlaytestMode.requested(arguments: ["Fulminate"], environment: ["GNUSTO_PLAIN": "1"]))
        }
    }

    /// Which frames `serve` has to run in wire order, and which it may answer
    /// concurrently.
    ///
    /// Found by driving a real binary with all four frames written at once, the
    /// way a pipe delivers them: the `move` was answered before the `open` it
    /// followed and failed with "no such session", because every frame had its
    /// own child task and the scheduler picked. Responses arriving out of order
    /// is legal JSON-RPC and fine; *turns being applied* out of order is not,
    /// in a harness whose one claim is that a command list replays identically.
    @Suite struct Ordering {
        private func server() throws -> MCPServer {
            MCPServer(
                name: "gnusto-playtest",
                version: "test",
                instructions: nil,
                tools: PlaytestTools.table(for: try PreparedGame(OperaHouse()), environment: [:]))
        }

        @Test func aCallThatAdvancesAWorldIsOrdered() throws {
            let server = try server()
            for tool in [
                "open", "move", "note", "finish", "checkpoint", "restore", "rewind", "export",
            ] {
                let frame =
                    #"{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"#
                    + "\"\(tool)\"}}"
                #expect(server.mutatesState(line: frame), "\(tool) must run in wire order")
            }
        }

        /// `replay` is a reader even though it plays a game: it boots a world of
        /// its own and touches no session, so two of them overlapping cannot
        /// apply anybody's turns out of order.
        @Test func aReaderIsNotOrdered() throws {
            let server = try server()
            for tool in ["survey", "recall", "coverage", "vocabulary", "replay"] {
                let frame =
                    #"{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"#
                    + "\"\(tool)\"}}"
                #expect(!server.mutatesState(line: frame), "\(tool) may be answered concurrently")
            }
        }

        /// The predicate answers a question, never raises one: a frame it
        /// cannot read takes the concurrent path and is refused there, so there
        /// is exactly one place that reports a bad frame.
        @Test func anUnreadableFrameIsNotTreatedAsMutating() throws {
            let server = try server()
            for frame in [
                "not json at all",
                #"{"jsonrpc":"2.0","id":1,"method":"tools/list"}"#,
                #"{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"nope"}}"#,
                #"{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{}}"#,
                #"{"jsonrpc":"2.0","method":"notifications/initialized"}"#,
            ] {
                #expect(!server.mutatesState(line: frame))
            }
        }

        /// Every row is classified deliberately. A row added later without a
        /// thought about ordering should fail here rather than race in the
        /// field.
        @Test func everyRowDeclaresWhetherItMutates() throws {
            let mutating = Set(
                try server().tools.filter(\.mutatesState).map(\.name))
            #expect(
                mutating == [
                    "open", "move", "note", "finish", "checkpoint", "restore", "rewind",
                    "export",
                ])
        }
    }
}
