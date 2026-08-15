/// The tools the play-test server offers, as one table.
///
/// A table rather than a switch, and one entry per row rather than a name here
/// and a schema there, because the two ways an MCP server rots are a tool that
/// is advertised and not implemented and a schema that stopped describing what
/// its handler returns. Keeping the name, the prose, both schemas and the
/// handler in a single literal makes both impossible to write by accident, and
/// `tools/list` is then a `map` over the same table the dispatcher calls — so
/// the suite's "every entry is listed" test is checking a real invariant as
/// the table grows.

// MARK: - A row

/// One tool: what it is called, what it is for, what it takes, what it gives
/// back, and what it does.
struct PlaytestTool: Sendable {
    /// The name the client calls it by.
    let name: String

    /// What it does, written for the agent that has to decide whether to call
    /// it. This is documentation with a job.
    let description: String

    /// A JSON Schema for the arguments, as MCP requires.
    let inputSchema: JSONValue

    /// A JSON Schema for `structuredContent`, or `nil` for a tool whose result
    /// is prose. Declaring one is a promise: MCP clients validate against it.
    let outputSchema: JSONValue?

    /// The work. Throwing is a *tool* failure and reaches the agent as
    /// `isError: true` — see ``MCPServer``.
    let handler: @Sendable (JSONValue) async throws -> PlaytestToolResult

    /// This row as its `tools/list` entry.
    var listing: JSONValue {
        var entry: [String: JSONValue] = [
            "name": .string(name),
            "description": .string(description),
            "inputSchema": inputSchema,
        ]
        if let outputSchema {
            entry["outputSchema"] = outputSchema
        }
        return .object(entry)
    }
}

/// What a tool hands back.
///
/// Two channels, and which one a tool uses is a real decision. A structured,
/// small result — a survey, a coverage queue — travels as JSON with a declared
/// `outputSchema`, so the client can validate it and the agent can read fields
/// out of it. A prose result — the transcript of a batch of moves — travels as
/// text, because game prose is multi-line and full of quotation marks, and
/// escaping it into JSON both inflates it and makes it unreadable to the one
/// reader whose whole job is reading it.
struct PlaytestToolResult: Sendable {
    /// The text block the agent sees.
    let text: String

    /// The machine-readable result, when the tool declared an output schema.
    let structured: JSONValue?

    /// A prose result.
    ///
    /// - Parameter text: the prose.
    init(text: String) {
        self.text = text
        self.structured = nil
    }

    /// A structured result. The text block carries the same JSON, compactly —
    /// MCP asks for both, so a client that does not understand
    /// `structuredContent` still has something to show.
    ///
    /// - Parameter json: the result.
    init(_ json: JSONValue) {
        self.text = json.text
        self.structured = json
    }
}

// MARK: - The table

/// The tool table, built against one prepared game.
enum PlaytestTools {
    /// Every tool, in the order a client will list them.
    ///
    /// - Parameter game: the game the tools answer about.
    /// - Returns: the table.
    static func table(for game: PreparedGame) -> [PlaytestTool] {
        [survey(for: game)]
    }

    /// `survey` — everything true of the game before anybody plays it.
    ///
    /// Static, and takes no session: the answer is a function of the game
    /// *type*, so there is no world to build and no seed to pick. It is the
    /// same value `GameWorld.survey()` reads off a running world, read instead
    /// off the definition a `PreparedGame` already holds.
    ///
    /// This is deliberately the *only* tool in the stage that introduces the
    /// protocol, so that a framing mistake is found while there is one cheap
    /// thing on the wire rather than a session registry.
    ///
    /// - Parameter game: the game to survey.
    /// - Returns: the row.
    private static func survey(for game: PreparedGame) -> PlaytestTool {
        PlaytestTool(
            name: "survey",
            description: """
                Everything about this game that is true before anybody plays \
                it: the rooms and how they connect, the declared fuses and \
                daemons, the verb table split into core verbs and one-line \
                stubs, the cast, the maximum score, and any warnings the \
                bootstrap raised. Costs no turns and needs no session.
                """,
            inputSchema: [
                "type": "object",
                "properties": [:],
                "additionalProperties": false,
            ],
            outputSchema: surveySchema,
            handler: { _ in PlaytestToolResult(PlaytestSurvey(game.definition).json) })
    }

    /// The shape of a `survey` result.
    ///
    /// Written by hand next to the renderer below, so that the two are read
    /// together and a field added to one is obviously missing from the other.
    private static let surveySchema: JSONValue = [
        "type": "object",
        "properties": [
            "title": ["type": "string"],
            "maxScore": ["type": "integer"],
            "rooms": [
                "type": "array",
                "items": [
                    "type": "object",
                    "properties": [
                        "id": ["type": "string"],
                        "name": ["type": "string"],
                        "isReachable": [
                            "type": "boolean",
                            "description": .string(
                                "False for a room no exit leads to: a holding pen, "
                                    + "or a room the map forgot."),
                        ],
                        "exits": [
                            "type": "array",
                            "items": [
                                "type": "object",
                                "properties": [
                                    "direction": ["type": "string"],
                                    "kind": [
                                        "type": "string",
                                        "enum": [
                                            "open", "blocked", "door", "conditional", "dynamic",
                                        ],
                                    ],
                                    "destination": [
                                        "type": "string",
                                        "description": "Absent when only a live turn could decide it.",
                                    ],
                                    "door": ["type": "string"],
                                ],
                                "required": ["direction", "kind"],
                            ],
                        ],
                    ],
                    "required": ["id", "name", "isReachable", "exits"],
                ],
            ],
            "timers": [
                "type": "array",
                "items": [
                    "type": "object",
                    "properties": [
                        "name": ["type": "string"],
                        "kind": ["type": "string", "enum": ["fuse", "daemon"]],
                        "turns": [
                            "type": "integer",
                            "description": "Turns until a fuse fires once started. Absent for a daemon.",
                        ],
                        "autostart": ["type": "boolean"],
                    ],
                    "required": ["name", "kind", "autostart"],
                ],
            ],
            "coreVerbs": ["type": "array", "items": ["type": "string"]],
            "stubVerbs": ["type": "array", "items": ["type": "string"]],
            "customVerbs": ["type": "array", "items": ["type": "string"]],
            "cast": ["type": "array", "items": ["type": "string"]],
            "warnings": ["type": "array", "items": ["type": "string"]],
        ],
        "required": [
            "title", "maxScore", "rooms", "timers", "coreVerbs", "stubVerbs", "customVerbs",
            "cast", "warnings",
        ],
    ]
}

// MARK: - Rendering the survey

extension PlaytestSurvey {
    /// The survey as JSON, matching `PlaytestTools.surveySchema`.
    var json: JSONValue {
        [
            "title": .string(title),
            "maxScore": .integer(maxScore),
            "rooms": .array(rooms.map(\.json)),
            "timers": .array(timers.map(\.json)),
            "coreVerbs": .array(coreVerbs.map(JSONValue.string)),
            "stubVerbs": .array(stubVerbs.map(JSONValue.string)),
            "customVerbs": .array(customVerbs.map(JSONValue.string)),
            "cast": .array(cast.map { .string($0.raw) }),
            "warnings": .array(warnings.map(JSONValue.string)),
        ]
    }
}

extension PlaytestSurvey.Room {
    /// One room as JSON.
    fileprivate var json: JSONValue {
        [
            "id": .string(id.raw),
            "name": .string(name),
            "isReachable": .bool(isReachable),
            "exits": .array(exits.map(\.json)),
        ]
    }
}

extension PlaytestSurvey.Exit {
    /// One exit as JSON. The two optional fields are omitted rather than sent
    /// as null: a dynamic exit does not have an unknown destination, it has no
    /// destination to know until somebody walks it.
    fileprivate var json: JSONValue {
        var entry: [String: JSONValue] = [
            "direction": .string(direction),
            "kind": .string(kind),
        ]
        if let destination {
            entry["destination"] = .string(destination.raw)
        }
        if let door {
            entry["door"] = .string(door.raw)
        }
        return .object(entry)
    }
}

extension PlaytestSurvey.Timer {
    /// One timer as JSON.
    fileprivate var json: JSONValue {
        var entry: [String: JSONValue] = [
            "name": .string(name),
            "kind": .string(kind),
            "autostart": .bool(autostart),
        ]
        if let turns {
            entry["turns"] = .integer(turns)
        }
        return .object(entry)
    }
}
