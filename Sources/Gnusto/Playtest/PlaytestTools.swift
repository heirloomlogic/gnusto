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

    /// Whether this row changes session state, and so must run in the order the
    /// frames arrived rather than whenever its task happens to be scheduled.
    ///
    /// `MCPServer.serve` answers each frame in its own child task, which is what
    /// keeps a slow call from stalling the ones behind it. That is right for a
    /// reader like `survey` or `recall` and wrong for anything that advances a
    /// world: a client may have several `tools/call` in flight — a model can emit
    /// two `move` blocks in one turn — and two of those landing on one session in
    /// scheduler order would apply the turns in an order nobody chose. In a
    /// harness whose whole claim is that a command list replays identically, an
    /// arbitrary interleaving is not a race to tolerate; it is the one property
    /// being sold.
    ///
    /// So a mutating row is awaited in wire order. Turns cost microseconds of
    /// engine work, so the throughput given up is nothing, and the ordering
    /// bought is total. Readers still overtake it freely.
    ///
    /// Second in the row on purpose: a reader deciding whether a new tool is
    /// safe to answer concurrently should not have to look for the answer.
    let mutatesState: Bool

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
    /// The session registry is built here and captured by the three rows that
    /// need it, so there is exactly one per server and the tools that share
    /// sessions share them by construction rather than by agreement.
    ///
    /// - Parameters:
    ///   - game: the game the tools answer about.
    ///   - environment: the process environment, for the session registry's
    ///     knobs — `GNUSTO_MCP_MAX_SESSIONS` and `GNUSTO_PLAYTEST_DIR`. Passed
    ///     in rather than read here, on the same composition-root convention as
    ///     every other environment read in the engine.
    /// - Returns: the table.
    static func table(for game: PreparedGame, environment: [String: String]) -> [PlaytestTool] {
        let sessions = PlaytestSessions(prepared: game, environment: environment)
        return [
            survey(for: game),
            open(sessions),
            move(sessions),
            recall(sessions),
        ]
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
            mutatesState: false,
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

    // MARK: - Sessions

    /// `open` — start a session and read the game's first words.
    ///
    /// The seed defaults to 0 to match `bin/playtest-replay --seed 0`, so a
    /// finding from a session and a finding from the script name the same run.
    /// It is a per-session argument rather than an environment variable
    /// precisely so a stray `GNUSTO_SEED` in a client's environment cannot
    /// silently re-seed every session in the process; see
    /// `PlaytestServer.serve`.
    ///
    /// - Parameter sessions: the registry to open in.
    /// - Returns: the row.
    private static func open(_ sessions: PlaytestSessions) -> PlaytestTool {
        PlaytestTool(
            name: "open",
            mutatesState: true,
            description: """
                Start a play-test session: boots the game at a pinned seed and \
                returns the session id to pass to every other session tool, the \
                game's opening text, and the status line naming the room, the \
                move counter and the score. The session records to disk from \
                this moment — the transcript and the command list are written \
                under .context/playtest/<label>/<probe>/, so a crash anywhere \
                in the process leaves the evidence behind and the session can \
                be replayed. One label per tester: probes under a label share \
                its save slots, and two testers sharing a label share each \
                other's saves.
                """,
            inputSchema: [
                "type": "object",
                "properties": [
                    "label": [
                        "type": "string",
                        "description": .string(
                            "Your name for this run's scratch directory: letters, digits, "
                                + "underscore, hyphen and dot, not starting with a dot."),
                    ],
                    "seed": [
                        "type": "integer",
                        "minimum": 0,
                        "description": .string(
                            "Pins the game's one random stream. Defaults to 0, which is "
                                + "what bin/playtest-replay uses, so the same commands "
                                + "replay identically in either harness."),
                    ],
                ],
                "required": ["label"],
                "additionalProperties": false,
            ],
            outputSchema: openSchema,
            handler: { arguments in
                let label = try string(arguments, "label", tool: "open")
                let seed = try seed(arguments)
                let session = try await sessions.open(label: label, seed: seed)
                let opening = try await session.opening()
                return PlaytestToolResult([
                    "session": .string(session.id),
                    "seed": .integer(Int(bitPattern: UInt(seed))),
                    "opening": .string(opening.text),
                    "status": .string(opening.status),
                    "awaiting": .string(opening.awaiting.rawValue),
                    "transcript": .string(session.transcriptURL.path),
                    "commands": .string(session.commandsURL.path),
                ])
            })
    }

    /// The shape of an `open` result.
    private static let openSchema: JSONValue = [
        "type": "object",
        "properties": [
            "session": [
                "type": "string",
                "description": "The session id, which is also its directory under the label.",
            ],
            "seed": ["type": "integer"],
            "opening": [
                "type": "string",
                "description": "The intro, the banner and the first room description.",
            ],
            "status": [
                "type": "string",
                "description": .string(
                    "The [status] line for turn zero: room, moves, score, whether the "
                        + "turn cost one, and any field the game's plugins contribute."),
            ],
            "awaiting": [
                "type": "string",
                "enum": ["none", "clarification", "saveFilename", "restoreFilename", "deathChoice"],
            ],
            "transcript": ["type": "string"],
            "commands": ["type": "string"],
        ],
        "required": ["session", "seed", "opening", "status", "awaiting", "transcript", "commands"],
    ]

    /// `move` — play some commands.
    ///
    /// Prose, not JSON. The result is literally the bytes this batch appended
    /// to the session's transcript, plus a `[playtest]` trailer: a transcript
    /// is multi-line and quote-heavy, so escaping it into a JSON string both
    /// inflates it and makes it harder to read for the one reader whose whole
    /// job is reading it.
    ///
    /// - Parameter sessions: the registry to find the session in.
    /// - Returns: the row.
    private static func move(_ sessions: PlaytestSessions) -> PlaytestTool {
        PlaytestTool(
            name: "move",
            mutatesState: true,
            description: """
                Play one or more commands in a session and read what the game \
                printed, in transcript form with a [status] line under every \
                turn. A line starting // or # is a comment: it is recorded in \
                the transcript and costs no turn and no clock tick, so annotate \
                what you see as you see it. The batch stops early — and says \
                how many commands went unrun — when the game ends, or when a \
                question opens that would swallow your next line as its answer \
                (a disambiguation, a save or restore filename, the choice after \
                a death). Pass allowPrompts when you mean to answer one inside \
                the same batch. A long result is trimmed to its most recent \
                turns with a marker naming the recall range that reads back the \
                rest. script and unscript are refused: the session is already \
                recording.
                """,
            inputSchema: [
                "type": "object",
                "properties": [
                    "session": ["type": "string", "description": "The id open returned."],
                    "commands": [
                        "type": "array",
                        "items": ["type": "string"],
                        "minItems": 1,
                        "description": "The lines to type, in order.",
                    ],
                    "allowPrompts": [
                        "type": "boolean",
                        "description": .string(
                            "Keep going when a question opens mid-batch, because the next "
                                + "command is meant to answer it. Defaults to false."),
                    ],
                ],
                "required": ["session", "commands"],
                "additionalProperties": false,
            ],
            outputSchema: nil,
            handler: { arguments in
                let session = try await sessions.session(
                    try string(arguments, "session", tool: "move"))
                let commands = try strings(arguments, "commands", tool: "move")
                let allowPrompts = boolean(arguments, "allowPrompts")
                return PlaytestToolResult(
                    text: try await session.move(
                        commands: commands, allowPrompts: allowPrompts))
            })
    }

    /// `recall` — read the session's own transcript back.
    ///
    /// One tool rather than a `tail` and a `grep`, because a tool an agent has
    /// to choose between is a tool it chooses wrong.
    ///
    /// - Parameter sessions: the registry to find the session in.
    /// - Returns: the row.
    private static func recall(_ sessions: PlaytestSessions) -> PlaytestTool {
        PlaytestTool(
            name: "recall",
            mutatesState: false,
            description: """
                Read part of a session's transcript back: the lines from `from` \
                to `to` inclusive, numbered the way the session numbers them — \
                line 1 is the first command you sent, and 0 is the opening. \
                Optionally filtered to the turns whose text contains `grep`, \
                each returned whole so the command that caused a line and the \
                status under it come with it. Costs no turns and changes \
                nothing.
                """,
            inputSchema: [
                "type": "object",
                "properties": [
                    "session": ["type": "string", "description": "The id open returned."],
                    "from": [
                        "type": "integer",
                        "description": "First line to read; 0 includes the opening.",
                    ],
                    "to": ["type": "integer", "description": "Last line to read, inclusive."],
                    "grep": [
                        "type": "string",
                        "description": .string(
                            "Keep only the turns containing this text, "
                                + "case-insensitively."),
                    ],
                ],
                "required": ["session", "from", "to"],
                "additionalProperties": false,
            ],
            outputSchema: nil,
            handler: { arguments in
                let session = try await sessions.session(
                    try string(arguments, "session", tool: "recall"))
                return PlaytestToolResult(
                    text: try await session.recall(
                        from: try integer(arguments, "from", tool: "recall"),
                        to: try integer(arguments, "to", tool: "recall"),
                        grep: arguments["grep"]?.stringValue))
            })
    }

    // MARK: - Reading arguments

    /// A required string argument.
    ///
    /// Every one of these throws rather than defaulting, and the message names
    /// the tool and the argument: a tool error reaches the agent as text it can
    /// act on, so "move needs a session" is a fixed call and "invalid
    /// arguments" is a wasted round trip. Nothing here traps — see
    /// ``MCPServer``.
    ///
    /// - Parameters:
    ///   - arguments: the call's arguments.
    ///   - key: the argument name.
    ///   - tool: the tool's name, for the message.
    /// - Throws: ``PlaytestError`` when it is missing or not a string.
    /// - Returns: the value.
    private static func string(
        _ arguments: JSONValue, _ key: String, tool: String
    ) throws -> String {
        guard let value = arguments[key]?.stringValue, !value.isEmpty else {
            throw PlaytestError("\(tool) needs a \(key) argument, as a non-empty string.")
        }
        return value
    }

    /// A required whole-number argument.
    private static func integer(
        _ arguments: JSONValue, _ key: String, tool: String
    ) throws -> Int {
        guard let value = arguments[key]?.intValue else {
            throw PlaytestError("\(tool) needs a \(key) argument, as a whole number.")
        }
        return value
    }

    /// A required array-of-strings argument.
    private static func strings(
        _ arguments: JSONValue, _ key: String, tool: String
    ) throws -> [String] {
        guard let raw = arguments[key]?.arrayValue else {
            throw PlaytestError("\(tool) needs a \(key) argument, as an array of strings.")
        }
        let values = raw.compactMap(\.stringValue)
        guard values.count == raw.count else {
            throw PlaytestError("\(tool)'s \(key) must hold strings only.")
        }
        return values
    }

    /// An optional boolean argument, false when absent or not a boolean.
    ///
    /// The one argument reader that does not throw: a flag left off is the
    /// common case and means no, and a client that sends `"true"` as a string
    /// meant yes but gets the safe answer rather than a refusal.
    private static func boolean(_ arguments: JSONValue, _ key: String) -> Bool {
        arguments[key] == .bool(true) || arguments[key]?.stringValue == "true"
    }

    /// The `seed` argument: absent means 0.
    ///
    /// Negative is refused rather than wrapped. A seed is a `UInt64` and the
    /// wire only carries signed integers, so `-1` could plausibly mean the top
    /// of the range or a typo; refusing says which it was.
    private static func seed(_ arguments: JSONValue) throws -> UInt64 {
        guard let raw = arguments["seed"] else { return 0 }
        guard let value = raw.intValue, value >= 0 else {
            throw PlaytestError(
                "open's seed must be a whole number of zero or more; it was given \(raw.text).")
        }
        return UInt64(value)
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
