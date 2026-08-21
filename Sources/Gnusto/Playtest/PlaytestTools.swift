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
    ///
    /// Takes ``PlaytestToolArguments`` rather than bare `JSONValue` so that the
    /// row's own name travels with the call — see that type for why.
    let handler: @Sendable (PlaytestToolArguments) async throws -> PlaytestToolResult

    /// Runs this row against a call's raw arguments.
    ///
    /// The one place a `PlaytestToolArguments` is built, and it takes the name
    /// from ``name`` — so a row cannot be called under another row's name and
    /// nothing outside this struct has to know the name is needed at all. That
    /// is the whole point: the dispatcher just resolved the row, and the suite
    /// calls a row it is already holding, so neither should have to restate
    /// what the row is called.
    ///
    /// - Parameter json: the client's `arguments` object.
    /// - Throws: whatever the handler throws — a *tool* failure, not a
    ///   protocol one. See ``MCPServer``.
    /// - Returns: the result.
    func call(_ json: JSONValue) async throws -> PlaytestToolResult {
        try await handler(PlaytestToolArguments(json: json, tool: name))
    }

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

/// A `tools/call`'s arguments, carrying the name of the row they arrived for.
///
/// The name is here because every argument reader wants it: a tool error
/// reaches the agent as text it can act on, so the message has to say *"move
/// needs a session"* rather than *"invalid arguments"*. Before this type each
/// handler re-typed its own name as a literal to supply that — twenty-two
/// copies over thirteen rows, and a copy that disagreed with its row's `name:`
/// would send a language model a correctly-formatted sentence about the wrong
/// tool. `MCPServer.call` has already resolved the row by name before it
/// dispatches, so the name is in hand there and nothing needs to restate it.
///
/// The same argument the file's header makes for the table itself, one level
/// down: a fact that is already written once should not be written again
/// somewhere it can drift.
struct PlaytestToolArguments: Sendable {
    /// The `arguments` object the client sent, or an empty object.
    let json: JSONValue

    /// The name of the tool being called, for every error message below.
    let tool: String

    /// One argument, unread and untyped.
    subscript(key: String) -> JSONValue? { json[key] }
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

    /// Both channels, saying the same thing in two registers.
    ///
    /// For a result whose reader is a language model *and* whose fields a
    /// client may want to validate: the coverage queue is a list of commands to
    /// paste, and a list reads as a list, not as one line of escaped JSON. The
    /// structured half carries the same items for anything counting them.
    ///
    /// - Parameters:
    ///   - text: the prose.
    ///   - structured: the same content, as fields.
    init(text: String, structured: JSONValue) {
        self.text = text
        self.structured = structured
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
            survey(for: game, sessions),
            vocabulary(for: game, sessions),
            open(sessions),
            move(sessions),
            recall(sessions),
            coverage(sessions),
            note(sessions),
            checkpoint(sessions),
            restore(sessions),
            rewind(sessions),
            finish(sessions),
            export(sessions),
            replay(for: game, sessions),
        ]
    }

    /// `survey` — everything true of the game before anybody plays it.
    ///
    /// The answer is a function of the game *type*, so there is no world to
    /// build and no seed to pick: it is the same value `GameWorld.survey()`
    /// reads off a running world, read instead off the definition a
    /// `PreparedGame` already holds.
    ///
    /// **It takes a session anyway, and that is the firewall.** This is the
    /// oracle — the room roster, the timer roster, the verb tables, `maxScore`
    /// — and whether a caller may see it is a fact about the caller, not about
    /// the game. A role is carried by a session, so a survey without one has
    /// nobody to ask permission of; there is therefore no such thing as an
    /// anonymous survey. A person driving their own game by hand opens a
    /// session with the default role and gets everything. See ``PlaytestRole``,
    /// which also says why this is enforced here rather than by handing a
    /// tester a shorter tool list.
    ///
    /// Because the answer is a function of the game type, it is built **once**,
    /// here, and the handler closes over the finished `JSONValue`. Rebuilding
    /// it per call re-walked the whole room graph and re-encoded every room,
    /// exit and timer: measured at **7.96 ms** a call on Dungeon, for a value
    /// that cannot change while the process lives. One table is built per
    /// server, so this is paid once at connect — where a cold start is already
    /// paying for a `swift build`.
    ///
    /// - Parameters:
    ///   - game: the game to survey.
    ///   - sessions: the registry the session id is looked up in.
    /// - Returns: the row.
    private static func survey(
        for game: PreparedGame, _ sessions: PlaytestSessions
    ) -> PlaytestTool {
        let answer = PlaytestSurvey(game.definition).json
        return PlaytestTool(
            name: "survey",
            mutatesState: false,
            description: """
                Everything about this game that is true before anybody plays \
                it: the rooms and how they connect, the declared fuses and \
                daemons, the verb table split into core verbs and one-line \
                stubs, the cast, the maximum score, and any warnings the \
                bootstrap raised. Costs no turns. This is the answer key, so a \
                session opened in a play-testing role is refused it — see the \
                role argument on open.
                """,
            inputSchema: [
                "type": "object",
                "properties": [
                    "session": [
                        "type": "string",
                        "description": .string(
                            "The id open returned. Required: whether you may read the "
                                + "answer key is a fact about your session's role."),
                    ]
                ],
                "required": ["session"],
                "additionalProperties": false,
            ],
            outputSchema: surveySchema,
            handler: { arguments in
                _ = try await sessions.session(arguments, oracle: true)
                return PlaytestToolResult(answer)
            })
    }

    /// `vocabulary` — does the parser know these words?
    ///
    /// **Oracle data, gated exactly like `survey`, and for the sharper of the
    /// two reasons.** A tester that can ask which words the parser knows can
    /// never again discover that a printed noun has nothing behind it: it would
    /// simply not type the word. That is the K8 class, and it is the single
    /// largest defect class every round finds — the whole argument for the
    /// firewall reduced to one tool. So a play-testing role is refused, and the
    /// refusal says why.
    ///
    /// It exists for the two callers who are not being measured. The round's
    /// **verifier** adjudicating a K8 finding needs to know whether the word is
    /// really absent, and asking the vocabulary is exact where matching the
    /// reply against *"You can't see any such thing"* is a string-match on prose
    /// a game may re-skin. And a **game author** driving their own game opens
    /// with the default `unrestricted` role, where twenty candidate nouns lifted
    /// out of one room description resolve in a single call and cost no turns.
    ///
    /// - Parameters:
    ///   - game: the game whose vocabulary to ask.
    ///   - sessions: the registry the session id is looked up in, for the role.
    /// - Returns: the row.
    private static func vocabulary(
        for game: PreparedGame, _ sessions: PlaytestSessions
    ) -> PlaytestTool {
        PlaytestTool(
            name: "vocabulary",
            mutatesState: false,
            description: """
                Ask whether this game's parser knows each of a list of words, \
                all in one call and for no turns. This is answer-key data and a \
                session opened in a play-testing role is refused it — a tester \
                who can look up the vocabulary can never find the defect where a \
                room description prints a noun the parser has never heard of, \
                which is the commonest defect there is. Type the word at the game \
                instead; that is the test. For a verifier judging such a finding, \
                or for an author driving their own game with role=unrestricted, \
                this answers exactly where the reply text only hints. Words are \
                split the way the parser splits them, so "master's" is asked as \
                "master".
                """,
            inputSchema: [
                "type": "object",
                "properties": [
                    "session": [
                        "type": "string",
                        "description": .string(
                            "The id open returned. Required: whether you may read the "
                                + "answer key is a fact about your session's role."),
                    ],
                    "words": [
                        "type": "array",
                        "items": ["type": "string"],
                        "minItems": 1,
                        "description": "The words to ask about, as you would type them.",
                    ],
                ],
                "required": ["session", "words"],
                "additionalProperties": false,
            ],
            outputSchema: vocabularySchema,
            handler: { arguments in
                _ = try await sessions.session(arguments, oracle: true)
                let words = try strings(arguments, "words")
                // Read off the definition rather than a world: the answer is a
                // fact about the game type, so a session that has been evicted
                // is not replayed just to be asked a question about its
                // vocabulary.
                let answers = game.definition.knows(words)
                let listing =
                    answers
                    .map { "\($0.word): \($0.known ? "known" : "NOT KNOWN")" }
                    .joined(separator: "\n")
                return PlaytestToolResult(
                    text: "\(listing)\n",
                    structured: [
                        "words": .array(
                            answers.map {
                                ["word": .string($0.word), "known": .bool($0.known)]
                            }),
                        "unknown": .array(
                            answers.filter { !$0.known }.map { .string($0.word) }),
                    ])
            })
    }

    /// The shape of a `vocabulary` result.
    private static let vocabularySchema: JSONValue = [
        "type": "object",
        "properties": [
            "words": [
                "type": "array",
                "items": [
                    "type": "object",
                    "properties": [
                        "word": ["type": "string"],
                        "known": ["type": "boolean"],
                    ],
                    "required": ["word", "known"],
                ],
            ],
            "unknown": [
                "type": "array",
                "items": ["type": "string"],
                "description": .string(
                    "Just the words the parser has never heard of, so a caller checking "
                        + "twenty nouns reads one short list."),
            ],
        ],
        "required": ["words", "unknown"],
    ]

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
                other's saves. The queue of things the game has already shown \
                you comes back with the opening, so you can plan from it \
                before spending a turn.
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
                    "role": [
                        "type": "string",
                        "enum": .array(PlaytestRole.allCases.map { .string($0.rawValue) }),
                        "description": .string(
                            "What this session may be told. A play-testing role plays "
                                + "blind: survey and every other answer-key query is "
                                + "refused, because a tester holding the room roster "
                                + "navigates instead of exploring, and one holding the "
                                + "vocabulary can never find a printed noun with nothing "
                                + "behind it. Defaults to unrestricted, for a person "
                                + "driving their own game."),
                    ],
                    "divergence": [
                        "type": "string",
                        "enum": .array(DivergencePolicy.allCases.map { .string($0.rawValue) }),
                        "description": .string(
                            "What to do the first time the game offers something you "
                                + "cannot take back — opening, burning, eating or drinking "
                                + "a thing. Testers left to themselves all open the same "
                                + "egg, so the branch nobody took goes untested however "
                                + "many of them ran; a round assigns these instead. "
                                + "commit takes the action, abstain leaves the thing as "
                                + "found, defer comes back to it last. The queue follows "
                                + "the policy, so an abstain session is never asked for a "
                                + "move it is under orders not to make. Defaults to "
                                + "commit, which is the queue this tool has always given."),
                    ],
                ],
                "required": ["label"],
                "additionalProperties": false,
            ],
            outputSchema: openSchema,
            handler: { arguments in
                let label = try string(arguments, "label")
                let seed = try seed(arguments)
                let role = try role(arguments)
                let divergence = try divergence(arguments)
                let session = try await sessions.open(
                    label: label, seed: seed, role: role, divergence: divergence)
                let opening = try await session.opening()
                let coverage = try await session.coverage(limit: queueLimit)
                return PlaytestToolResult([
                    "session": .string(session.id),
                    "seed": .integer(Int(bitPattern: UInt(seed))),
                    "role": .string(role.rawValue),
                    "divergence": .string(divergence.rawValue),
                    "instruction": .string(divergence.instruction),
                    "opening": .string(opening.text),
                    "status": .string(opening.status),
                    "awaiting": .string(opening.awaiting.rawValue),
                    "open": .integer(coverage.open),
                    "queue": .array(coverage.items.map(\.json)),
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
            "role": [
                "type": "string",
                "enum": .array(PlaytestRole.allCases.map { .string($0.rawValue) }),
            ],
            "divergence": [
                "type": "string",
                "enum": .array(DivergencePolicy.allCases.map { .string($0.rawValue) }),
            ],
            "instruction": [
                "type": "string",
                "description": .string(
                    "The divergence policy in words, to be followed for the whole "
                        + "session. Your queue already reflects it."),
            ],
            "opening": [
                "type": "string",
                "description": "The intro, the banner and the first room description.",
            ],
            "open": [
                "type": "integer",
                "description": .string(
                    "How many things the game has already shown you that you have not "
                        + "followed up. Read it as a countdown."),
            ],
            "queue": ["type": "array", "items": queueItemSchema],
            "status": [
                "type": "string",
                "description": .string(
                    "The [status] line for turn zero: room, moves, score, whether the "
                        + "turn cost one, and any field the game's plugins contribute."),
            ],
            "awaiting": [
                "type": "string",
                "enum": .array(PlaytestAwaiting.allCases.map { .string($0.rawValue) }),
            ],
            "transcript": ["type": "string"],
            "commands": ["type": "string"],
        ],
        "required": [
            "session", "seed", "role", "divergence", "instruction", "opening", "status",
            "awaiting", "open", "queue", "transcript", "commands",
        ],
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
                let session = try await sessions.session(arguments)
                let commands = try strings(arguments, "commands")
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
                let session = try await sessions.session(arguments)
                return PlaytestToolResult(
                    text: try await session.recall(
                        from: try integer(arguments, "from"),
                        to: try integer(arguments, "to"),
                        grep: arguments["grep"]?.stringValue))
            })
    }

    // MARK: - The queue

    /// How many queue items a result carries.
    ///
    /// Enough to choose between, few enough to read. The whole point of the
    /// queue is that the next move is obvious; forty candidates is a research
    /// project, and the ranking has already decided which twelve matter.
    static let queueLimit = 12

    /// `coverage` — what the game has shown you that you have not followed up.
    ///
    /// **This handler does not touch `definition`, and must not.** Everything
    /// it returns is derived from the text this session printed and the parse
    /// record of this session's own commands — see ``CoverageLedger``. A tester
    /// told the room roster navigates instead of exploring, and one told the
    /// vocabulary can never discover a printed noun with nothing behind it, so
    /// both defect classes would go out with the leak.
    ///
    /// - Parameter sessions: the registry to find the session in.
    /// - Returns: the row.
    private static func coverage(_ sessions: PlaytestSessions) -> PlaytestTool {
        PlaytestTool(
            name: "coverage",
            mutatesState: false,
            description: """
                The things this game has shown you and you have not followed \
                up, cheapest first, each one a command to paste: a noun the \
                prose printed that you never named, a direction a room \
                described that you never took, a verb from the standard \
                repertoire that fits something you have found, an object you \
                changed and never looked at again, and your own suspicions \
                still owed a second look. Built only from what the game printed \
                into this session — it is not a map, and it knows nothing you \
                have not been told. Costs no turns.
                """,
            inputSchema: [
                "type": "object",
                "properties": [
                    "session": ["type": "string", "description": "The id open returned."],
                    "limit": [
                        "type": "integer",
                        "minimum": 1,
                        "description": .string(
                            "How many items to return. Defaults to \(queueLimit)."),
                    ],
                ],
                "required": ["session"],
                "additionalProperties": false,
            ],
            outputSchema: coverageSchema,
            handler: { arguments in
                let session = try await sessions.session(arguments)
                let limit = max(1, arguments["limit"]?.intValue ?? queueLimit)
                let coverage = try await session.coverage(limit: limit)
                return PlaytestToolResult(
                    text: coverage.rendered(session: session.id),
                    structured: coverage.json(session: session.id))
            })
    }

    /// The shape of one queue item, shared by `open`, `coverage` and `finish`.
    private static let queueItemSchema: JSONValue = [
        "type": "object",
        "properties": [
            "id": ["type": "string"],
            "kind": [
                "type": "string",
                "enum": .array(CoverageItem.Kind.allCases.map { .string($0.rawValue) }),
            ],
            "how": [
                "type": "string",
                "description": .string(
                    "The command to type. Prefixed with the room, or with the one step "
                        + "you have already walked to get there, when it is elsewhere."),
            ],
            "why": [
                "type": "string",
                "description": "Where and when the game showed you this.",
            ],
            "room": ["type": "string"],
            "line": ["type": "integer"],
            "closedByLooking": [
                "type": "boolean",
                "description": .string(
                    "False for a timer or a displacement: those want a look at a second "
                        + "frame and a note quoting a printed line, not one command."),
            ],
            "fork": [
                "type": "boolean",
                "description": .string(
                    "True for something you cannot take back. Your divergence policy "
                        + "already decided what to do with these, so they are here only "
                        + "if it wants you to take them."),
            ],
        ],
        "required": [
            "id", "kind", "how", "why", "room", "line", "closedByLooking", "fork",
        ],
    ]

    /// The shape of a `coverage` result.
    private static let coverageSchema: JSONValue = [
        "type": "object",
        "properties": [
            "session": ["type": "string"],
            "open": [
                "type": "integer",
                "description": "How many items are open. Read it as a countdown.",
            ],
            "closed": ["type": "integer"],
            "room": ["type": "string"],
            "items": ["type": "array", "items": queueItemSchema],
            "hint": [
                "type": "string",
                "description": "Present only when the queue has run dry.",
            ],
            "harness": [
                "type": "string",
                "description": .string(
                    "A measured signal that has tripped a threshold. Informational: "
                        + "nothing is blocked by it."),
            ],
        ],
        "required": ["session", "open", "closed", "room", "items"],
    ]

    // MARK: - Notes and stopping

    /// `note` — write a comment into the transcript where you saw the thing.
    ///
    /// - Parameter sessions: the registry to find the session in.
    /// - Returns: the row.
    private static func note(_ sessions: PlaytestSessions) -> PlaytestTool {
        PlaytestTool(
            name: "note",
            mutatesState: true,
            description: """
                Write a comment into this session's transcript at the turn you \
                are standing on. It costs no turn and no clock tick, and it is \
                recorded in the evidence next to the line that prompted it — so \
                flag a wrong line the moment you read it rather than \
                reconstructing the frame forty turns later. Set suspicious when \
                you think something is wrong but cannot yet say so: that files \
                the note as a hunch on your queue, to be probed again from a \
                different room or a later hour, and it is also how you close a \
                timer or displacement item, which wants a verdict quoting a \
                printed line.
                """,
            inputSchema: [
                "type": "object",
                "properties": [
                    "session": ["type": "string", "description": "The id open returned."],
                    "text": [
                        "type": "string",
                        "description": .string(
                            "What to write. One line: newlines are squeezed out, because "
                                + "a transcript comment is one line by construction."),
                    ],
                    "suspicious": [
                        "type": "boolean",
                        "description": .string(
                            "File it as a hunch as well as a note. Defaults to false."),
                    ],
                ],
                "required": ["session", "text"],
                "additionalProperties": false,
            ],
            outputSchema: nil,
            handler: { arguments in
                let session = try await sessions.session(arguments)
                return PlaytestToolResult(
                    text: try await session.note(
                        try string(arguments, "text"),
                        suspicious: boolean(arguments, "suspicious")))
            })
    }

    /// `finish` — say you are done, and be told what you are leaving.
    ///
    /// It accepts. That is the point of the row: two agents played the bare
    /// session surface with no queue and no enforcement, and both volunteered
    /// honest gap lists better than a deferral form would have extracted, so
    /// this asks rather than extracts. The accounting is still kept, and an
    /// unexplained gap is still counted as a gap.
    ///
    /// - Parameter sessions: the registry to find the session in.
    /// - Returns: the row.
    private static func finish(_ sessions: PlaytestSessions) -> PlaytestTool {
        PlaytestTool(
            name: "finish",
            mutatesState: true,
            description: """
                Say what you found and that you are stopping. It always \
                accepts, and it tells you what was still open when you stopped, \
                in the same paste-able terms coverage uses, plus the signals \
                measured off your own transcript. If you are leaving things \
                open on purpose, say why in `leaving` — an unexplained gap is \
                still counted as a gap, and the reason is what the round's \
                critic reads. The summary and the reason are written into the \
                transcript as comments, so they live in the evidence. Calling \
                it does not close the session: you can call move again after.
                """,
            inputSchema: [
                "type": "object",
                "properties": [
                    "session": ["type": "string", "description": "The id open returned."],
                    "summary": [
                        "type": "string",
                        "description": "What you found, in your own words.",
                    ],
                    "leaving": [
                        "type": "string",
                        "description": .string(
                            "Why you are stopping with items still open. Optional, and "
                                + "not scored on length."),
                    ],
                ],
                "required": ["session", "summary"],
                "additionalProperties": false,
            ],
            outputSchema: finishSchema,
            handler: { arguments in
                let session = try await sessions.session(arguments)
                let closing = try await session.finish(
                    summary: try string(arguments, "summary"),
                    leaving: arguments["leaving"]?.stringValue,
                    limit: queueLimit)
                return PlaytestToolResult(
                    text: closing.message, structured: closing.json)
            })
    }

    // MARK: - Going back

    /// `checkpoint` — mark a place to come back to.
    ///
    /// In memory and session-scoped, and pointedly **not** the player's `save`.
    /// A tester has to be able to probe `save` and `restore` as game commands —
    /// they are two-turn prompt interactions with their own defects — so the
    /// agent's own branching cannot be the same mechanism. A checkpoint here is
    /// an index into the command list, which is why it costs nothing, survives
    /// an eviction, and keeps a reproducer honest: coming back to one truncates
    /// the list, so a finding filed afterwards still replays from line one.
    ///
    /// - Parameter sessions: the registry to find the session in.
    /// - Returns: the row.
    private static func checkpoint(_ sessions: PlaytestSessions) -> PlaytestTool {
        PlaytestTool(
            name: "checkpoint",
            mutatesState: true,
            description: """
                Mark where you are standing so you can come back to it with \
                restore. Costs no turn and writes no save file — this is the \
                harness remembering a place, not the game's own SAVE, which you \
                should still type at the game when you mean to test it. Coming \
                back drops the turns after the mark from this session's command \
                list (they are kept beside the transcript as branch-NNN.txt), so \
                whatever you file afterwards still replays from the first line. \
                Marking the same name twice moves it.
                """,
            inputSchema: [
                "type": "object",
                "properties": [
                    "session": ["type": "string", "description": "The id open returned."],
                    "name": [
                        "type": "string",
                        "description": "What to call this place, e.g. \"before the grate\".",
                    ],
                ],
                "required": ["session", "name"],
                "additionalProperties": false,
            ],
            outputSchema: checkpointSchema,
            handler: { arguments in
                let session = try await sessions.session(arguments)
                let marked = try await session.checkpoint(
                    try string(arguments, "name"))
                return PlaytestToolResult(text: marked.message, structured: marked.json)
            })
    }

    /// The shape of a `checkpoint` result.
    private static let checkpointSchema: JSONValue = [
        "type": "object",
        "properties": [
            "name": ["type": "string"],
            "line": [
                "type": "integer",
                "description": "The recorded line it stands at; 0 is the opening.",
            ],
            "room": ["type": "string"],
            "moves": ["type": "integer"],
            "message": ["type": "string"],
        ],
        "required": ["name", "line", "room", "moves", "message"],
    ]

    /// `restore` — go back to a marked place.
    ///
    /// - Parameter sessions: the registry to find the session in.
    /// - Returns: the row.
    private static func restore(_ sessions: PlaytestSessions) -> PlaytestTool {
        PlaytestTool(
            name: "restore",
            mutatesState: true,
            description: """
                Go back to a place you marked with checkpoint. The world, the \
                queue and the move counter all return to that line, and the turns \
                after it leave this session's command list — kept beside the \
                transcript as branch-NNN.txt, so the branch you abandoned is \
                still evidence. This is the harness, not the game's RESTORE verb; \
                type that at the game if what you want to test is the game's own \
                restore.
                """,
            inputSchema: [
                "type": "object",
                "properties": [
                    "session": ["type": "string", "description": "The id open returned."],
                    "name": [
                        "type": "string",
                        "description": "The checkpoint's name.",
                    ],
                ],
                "required": ["session", "name"],
                "additionalProperties": false,
            ],
            outputSchema: rewindSchema,
            handler: { arguments in
                let session = try await sessions.session(arguments)
                let rewound = try await session.restore(
                    checkpoint: try string(arguments, "name"))
                return PlaytestToolResult(text: rewound.message, structured: rewound.json)
            })
    }

    /// `rewind` — take back the last few turns.
    ///
    /// - Parameter sessions: the registry to find the session in.
    /// - Returns: the row.
    private static func rewind(_ sessions: PlaytestSessions) -> PlaytestTool {
        PlaytestTool(
            name: "rewind",
            mutatesState: true,
            description: """
                Take back the last few recorded lines: the world, the queue and \
                the move counter go back to where they were, and the lines leave \
                this session's command list (kept beside the transcript as \
                branch-NNN.txt). Comments count as lines, because that is how \
                they are numbered everywhere else. Goes back at most \
                \(PlaytestSession.snapshotRing) lines — the history it keeps in \
                memory is bounded — so mark a place with checkpoint before you \
                wander off if you may want to come back from further away.
                """,
            inputSchema: [
                "type": "object",
                "properties": [
                    "session": ["type": "string", "description": "The id open returned."],
                    "turns": [
                        "type": "integer",
                        "minimum": 1,
                        "maximum": .integer(PlaytestSession.snapshotRing),
                        "description": "How many recorded lines to take back.",
                    ],
                ],
                "required": ["session", "turns"],
                "additionalProperties": false,
            ],
            outputSchema: rewindSchema,
            handler: { arguments in
                let session = try await sessions.session(arguments)
                let rewound = try await session.rewind(
                    turns: try integer(arguments, "turns"))
                return PlaytestToolResult(text: rewound.message, structured: rewound.json)
            })
    }

    /// The shape of a `rewind` or `restore` result — one schema, because going
    /// back a fixed number of turns and going back to a mark are the same
    /// operation with two ways of naming the line.
    private static let rewindSchema: JSONValue = [
        "type": "object",
        "properties": [
            "name": [
                "type": "string",
                "description": "The checkpoint's name, absent for a plain rewind.",
            ],
            "line": ["type": "integer"],
            "room": ["type": "string"],
            "moves": ["type": "integer"],
            "discarded": [
                "type": "integer",
                "description": "How many recorded lines left the command list.",
            ],
            "branch": [
                "type": "string",
                "description": "Where the discarded turns were kept.",
            ],
            "status": ["type": "string"],
            "message": ["type": "string"],
        ],
        "required": ["line", "room", "moves", "discarded", "status", "message"],
    ]

    // MARK: - Finishing up

    /// `export` — write the evidence out, and prove it replays.
    ///
    /// The write is a convenience: `commands.txt` and the transcript have been
    /// on disk since the first turn, because a `fatalError` in any game rule
    /// takes down every session in the process and the evidence has to survive
    /// that. What is new here is the **verify**, and it is the reason the row
    /// exists: the command list goes through a fresh `REPL` in-process and the
    /// result is compared to the recorded file byte for byte. That pins the
    /// session driver to the REPL permanently — the two loops cannot drift
    /// without a real session noticing — and it re-proves, on evidence, the
    /// claim the whole harness rests on.
    ///
    /// - Parameter sessions: the registry to find the session in.
    /// - Returns: the row.
    private static func export(_ sessions: PlaytestSessions) -> PlaytestTool {
        PlaytestTool(
            name: "export",
            mutatesState: true,
            description: """
                Write this session's evidence out and check that it replays: the \
                command list goes through a fresh copy of the game and the result \
                is compared to the recorded transcript byte for byte, so what you \
                cite is provably a regression test. Returns four paths — the \
                transcript as recorded with a [status] line per turn, the same \
                transcript without them (quote your excerpts from that one, \
                because a suite test never sees a [status] line), the command \
                list, and a plain-language summary. It does not close the \
                session: you can carry on playing afterwards. If the check fails, \
                say so in your report — that is a defect in this harness, not in \
                the game.
                """,
            inputSchema: [
                "type": "object",
                "properties": [
                    "session": ["type": "string", "description": "The id open returned."]
                ],
                "required": ["session"],
                "additionalProperties": false,
            ],
            outputSchema: exportSchema,
            handler: { arguments in
                let session = try await sessions.session(arguments)
                let exported = try await session.export()
                return PlaytestToolResult(
                    text: exported.message, structured: exported.json)
            })
    }

    /// The shape of an `export` result.
    private static let exportSchema: JSONValue = [
        "type": "object",
        "properties": [
            "transcript": [
                "type": "string",
                "description": "As recorded, with a [status] line under every turn.",
            ],
            "transcriptWithoutStatus": [
                "type": "string",
                "description": .string(
                    "The same run without the [status] lines — the string a suite test "
                        + "asserts on, so quote excerpts from here."),
            ],
            "commands": ["type": "string"],
            "summary": ["type": "string"],
            "lines": ["type": "integer"],
            "seed": ["type": "integer"],
            "verified": [
                "type": "boolean",
                "description": .string(
                    "Always true: a failed byte-identity check is a tool error rather "
                        + "than a field, because a reproducer that may not reproduce is "
                        + "not a result to read past."),
            ],
            "message": ["type": "string"],
        ],
        "required": [
            "transcript", "transcriptWithoutStatus", "commands", "summary", "lines", "seed",
            "verified", "message",
        ],
    ]

    /// `replay` — play a command list in a fresh world, with no session at all.
    ///
    /// The verifier's tool. It is a different subagent from the tester that filed
    /// the finding and holds no session id, so everything session-scoped is
    /// useless to it; what it holds is a command list, a seed and a claim about a
    /// line. See ``PlaytestReplay``.
    ///
    /// - Parameters:
    ///   - game: the game to replay.
    ///   - sessions: the registry, asked only for a probe directory to leave the
    ///     evidence in. A replay still holds no session and joins none.
    /// - Returns: the row.
    private static func replay(
        for game: PreparedGame, _ sessions: PlaytestSessions
    ) -> PlaytestTool {
        PlaytestTool(
            name: "replay",
            mutatesState: false,
            description: """
                Play a list of commands in a brand-new copy of the game and read \
                the transcript. No session: nothing you do here touches anybody's \
                session and two callers cannot see each other. Give `expect` an \
                excerpt and you get a verdict instead — whether that text really \
                printed, at which turn, in which room, at which move count, and \
                the whole turn it printed in so you can see the frame. Whitespace \
                is collapsed before matching, so an excerpt re-wrapped by a report \
                still matches the line it came from, and the [status] footers are \
                not searched. This is how you check a reproducer without playing \
                the game yourself. Every call writes its own probe directory and \
                answers with `transcript=<path>`: quote that path in whatever you \
                file, because a frame you read here and cited nowhere is a claim \
                the next reader cannot check.
                """,
            inputSchema: [
                "type": "object",
                "properties": [
                    "commands": [
                        "type": "array",
                        "items": ["type": "string"],
                        "description": .string(
                            "The lines to type, in order. Empty replays just the opening. "
                                + "A line starting // or # is a comment and costs no turn."),
                    ],
                    "seed": [
                        "type": "integer",
                        "minimum": 0,
                        "description": .string(
                            "The seed the finding names. Defaults to 0, which is what "
                                + "sessions and bin/playtest-replay use."),
                    ],
                    "expect": [
                        "type": "string",
                        "description": .string(
                            "An excerpt to look for. Given one, the result is a verdict "
                                + "rather than the transcript."),
                    ],
                ],
                "required": ["commands"],
                "additionalProperties": false,
            ],
            outputSchema: replaySchema,
            handler: { arguments in
                let commands = try strings(arguments, "commands")
                let outcome = try await PlaytestReplay.run(
                    prepared: game,
                    commands: commands,
                    seed: try seed(arguments),
                    expect: arguments["expect"]?.stringValue,
                    probe: await sessions.replayProbe())
                return PlaytestToolResult(
                    text: outcome.rendered, structured: outcome.json)
            })
    }

    /// The shape of a `replay` result.
    private static let replaySchema: JSONValue = [
        "type": "object",
        "properties": [
            "lines": ["type": "integer"],
            "finished": [
                "type": "boolean",
                "description": "Whether the game ended during the replay.",
            ],
            "transcript": [
                "type": "string",
                "description": .string(
                    "The whole replay, present when no expect was given. Trimmed to its "
                        + "last turns if it is very long."),
            ],
            "found": [
                "type": "boolean",
                "description": "Whether the expected excerpt printed. Absent without expect.",
            ],
            "turn": [
                "type": "integer",
                "description": .string(
                    "The line that printed it, numbered as a session numbers lines: 1 is "
                        + "the first command, 0 the opening."),
            ],
            "room": ["type": "string"],
            "moves": ["type": "integer"],
            "command": [
                "type": "string",
                "description": "The line typed to reach it, absent for the opening.",
            ],
            "actualContext": [
                "type": "string",
                "description": .string(
                    "The whole turn it printed in — or, when it never printed, the last "
                        + "turn of the replay, so a false claim comes back with the frame "
                        + "that was really there."),
            ],
            "transcriptPath": [
                "type": "string",
                "description": .string(
                    "Where this replay's transcript was written. Written once and never "
                        + "rewritten, so it is the evidence a reader follows later — cite "
                        + "it in whatever you file. Absent only if the write failed, which "
                        + "does not fail the replay."),
            ],
            "commandsPath": [
                "type": "string",
                "description": .string(
                    "The command list beside it, which replays to that transcript "
                        + "exactly. The seed that produced both is in summary.txt in the "
                        + "same directory."),
            ],
        ],
        "required": ["lines", "finished"],
    ]

    /// The shape of a `finish` result.
    private static let finishSchema: JSONValue = [
        "type": "object",
        "properties": [
            "accepted": [
                "type": "boolean",
                "description": "Always true. finish reports; it does not refuse.",
            ],
            "open": ["type": "integer"],
            "items": ["type": "array", "items": queueItemSchema],
            "signals": [
                "type": "object",
                "properties": [
                    "commands": ["type": "integer"],
                    "roomsVisited": ["type": "integer"],
                    "roomDwell": ["type": "number"],
                    "novelCommandRatio": ["type": "number"],
                    "nounFollowRate": ["type": "number"],
                    "nounsPrintedByExamines": ["type": "integer"],
                    "interactionBreadth": ["type": "number"],
                    "objectsBound": ["type": "integer"],
                    "dischargeRate": ["type": "number"],
                    "openItems": ["type": "integer"],
                ],
            ],
            "forks": [
                "type": "array",
                "description": .string(
                    "Every irreversible action this session was offered, and whether it "
                        + "took it. A round collects these across its testers: a fork no "
                        + "session took is a branch the whole round left untested."),
                "items": [
                    "type": "object",
                    "properties": [
                        "id": ["type": "string"],
                        "command": ["type": "string"],
                        "room": ["type": "string"],
                        "taken": ["type": "boolean"],
                    ],
                    "required": ["id", "command", "room", "taken"],
                ],
            ],
            "roomsVisited": [
                "type": "array",
                "description": .string(
                    "Every room the status line named, in first-seen order — including "
                        + "rooms reached inside a branch a rewind later wrote off, whose "
                        + "turns were really played. Each row carries the room's declared "
                        + "id and its display name. The id is the key: a name is prose and "
                        + "two rooms may share one, so a coverage count keyed on the name "
                        + "cannot reach the survey's room roster. Counted off this "
                        + "session, not recalled: a round reads it rather than asking you "
                        + "how far you got. signals.roomsVisited counts only the canonical "
                        + "transcript, so the two may differ for a session that rewound."),
                "items": [
                    "type": "object",
                    "properties": [
                        "id": ["type": "string"],
                        "name": ["type": "string"],
                    ],
                    "required": ["id", "name"],
                ],
            ],
            "roomsOnlyInBranches": [
                "type": "array",
                "description": .string(
                    "The ids of the rooms above whose evidence is in a branch-NNN.txt "
                        + "rather than in transcript.txt. Empty unless this session "
                        + "rewound out of a room it had entered."),
                "items": ["type": "string"],
            ],
            "firedTimers": [
                "type": "object",
                "description": .string(
                    "Every timer whose body ran in this session, by declared name, and "
                        + "how often — the engine's own tally, not an inference off the "
                        + "prose. A name missing here fired nothing; a name present fired "
                        + "at least that many times. Read against the survey's timer "
                        + "roster it says which declared timers a round never exercised, "
                        + "which no amount of reading the transcript can settle for a "
                        + "timer whose body says nothing."),
                "additionalProperties": ["type": "integer"],
            ],
            "unknownWords": [
                "type": "object",
                "description": .string(
                    "Every token the vocabulary did not know, and how often it was "
                        + "typed. The parser's own record, so a game that re-voices the "
                        + "'I don't know the word' line does not hide it."),
                "additionalProperties": ["type": "integer"],
            ],
            "hint": ["type": "string"],
            "transcript": ["type": "string"],
            "message": ["type": "string"],
        ],
        "required": [
            "accepted", "open", "items", "signals", "forks", "roomsVisited",
            "roomsOnlyInBranches", "firedTimers", "unknownWords", "transcript",
            "message",
        ],
    ]

    // MARK: - Reading arguments

    /// A required string argument.
    ///
    /// Every one of these throws rather than defaulting, and the message names
    /// the tool and the argument: a tool error reaches the agent as text it can
    /// act on, so "move needs a session" is a fixed call and "invalid
    /// arguments" is a wasted round trip. Nothing here traps — see
    /// ``MCPServer``.
    ///
    /// The tool's name comes off ``PlaytestToolArguments/tool``, which the
    /// dispatcher filled in from the row it resolved, so no caller supplies it
    /// and no caller can supply the wrong one.
    ///
    /// - Parameters:
    ///   - arguments: the call's arguments.
    ///   - key: the argument name.
    /// - Throws: ``PlaytestError`` when it is missing or not a string.
    /// - Returns: the value.
    private static func string(
        _ arguments: PlaytestToolArguments, _ key: String
    ) throws -> String {
        guard let value = arguments[key]?.stringValue, !value.isEmpty else {
            throw PlaytestError(
                "\(arguments.tool) needs a \(key) argument, as a non-empty string.")
        }
        return value
    }

    /// The `session` argument, read exactly as every other required string is.
    ///
    /// Exposed for ``PlaytestSessions/session(_:oracle:)``, which does the
    /// lookup and the oracle check together, so that reading the id and
    /// resolving it stay one step with one error voice.
    static func sessionID(_ arguments: PlaytestToolArguments) throws -> String {
        try string(arguments, "session")
    }

    /// A required whole-number argument.
    private static func integer(
        _ arguments: PlaytestToolArguments, _ key: String
    ) throws -> Int {
        guard let value = arguments[key]?.intValue else {
            throw PlaytestError("\(arguments.tool) needs a \(key) argument, as a whole number.")
        }
        return value
    }

    /// A required array-of-strings argument.
    private static func strings(
        _ arguments: PlaytestToolArguments, _ key: String
    ) throws -> [String] {
        guard let raw = arguments[key]?.arrayValue else {
            throw PlaytestError(
                "\(arguments.tool) needs a \(key) argument, as an array of strings.")
        }
        let values = raw.compactMap(\.stringValue)
        guard values.count == raw.count else {
            throw PlaytestError("\(arguments.tool)'s \(key) must hold strings only.")
        }
        return values
    }

    /// An optional boolean argument, false when absent or not a boolean.
    ///
    /// The one argument reader that does not throw: a flag left off is the
    /// common case and means no, and a client that sends `"true"` as a string
    /// meant yes but gets the safe answer rather than a refusal.
    private static func boolean(_ arguments: PlaytestToolArguments, _ key: String) -> Bool {
        arguments[key] == .bool(true) || arguments[key]?.stringValue == "true"
    }

    /// The `seed` argument: absent means 0.
    ///
    /// Negative is refused rather than wrapped. A seed is a `UInt64` and the
    /// wire only carries signed integers, so `-1` could plausibly mean the top
    /// of the range or a typo; refusing says which it was.
    private static func seed(_ arguments: PlaytestToolArguments) throws -> UInt64 {
        guard let raw = arguments["seed"] else { return 0 }
        guard let value = raw.intValue, value >= 0 else {
            throw PlaytestError(
                "open's seed must be a whole number of zero or more; it was given \(raw.text).")
        }
        return UInt64(value)
    }

    /// The `divergence` argument: absent means the historical behaviour.
    ///
    /// Refused rather than guessed at, for the same reason as ``role(_:)`` one
    /// step below: a round assigns these policies across its testers so that the
    /// forks get covered between them, and a policy silently downgraded to
    /// `commit` would leave the round believing a branch had been left alone by
    /// somebody when in fact nobody left it alone at all.
    ///
    /// - Parameter arguments: the call's arguments.
    /// - Throws: ``PlaytestError`` naming the policies there are.
    /// - Returns: the policy.
    private static func divergence(_ arguments: PlaytestToolArguments) throws -> DivergencePolicy {
        guard let raw = arguments["divergence"] else { return .commit }
        guard let name = raw.stringValue, let policy = DivergencePolicy(rawValue: name) else {
            let known = DivergencePolicy.allCases.map(\.rawValue).joined(separator: ", ")
            throw PlaytestError(
                """
                open's divergence must be one of: \(known). It was given \(raw.text). A \
                round hands these out so that two testers cover both sides of an \
                irreversible action between them, so guessing one would quietly leave a \
                branch untested while the report claimed it was covered.
                """)
        }
        return policy
    }

    /// The `role` argument: absent means the human case.
    ///
    /// An unrecognised role is refused rather than downgraded to `explorer` or
    /// promoted to `unrestricted`. Either guess would be wrong in a way nobody
    /// would notice: the first silently blinds a game author, and the second
    /// silently hands a tester the answer key and invalidates its round.
    ///
    /// - Parameter arguments: the call's arguments.
    /// - Throws: ``PlaytestError`` naming the roles there are.
    /// - Returns: the role.
    private static func role(_ arguments: PlaytestToolArguments) throws -> PlaytestRole {
        guard let raw = arguments["role"] else { return .unrestricted }
        guard let name = raw.stringValue, let role = PlaytestRole(rawValue: name) else {
            let known = PlaytestRole.allCases.map(\.rawValue).joined(separator: ", ")
            throw PlaytestError(
                """
                open's role must be one of: \(known). It was given \(raw.text). Neither \
                guess is safe here — the wrong way up, it hands a tester the answer key \
                and quietly invalidates the round.
                """)
        }
        return role
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

// MARK: - Rendering the queue

extension CoverageItem {
    /// One queue item as JSON, matching `PlaytestTools.queueItemSchema`.
    var json: JSONValue {
        [
            "id": .string(id),
            "kind": .string(kind.rawValue),
            "how": .string(how),
            "why": .string(why),
            "room": .string(room),
            "line": .integer(line),
            "closedByLooking": .bool(kind.closedByLooking),
            "fork": .bool(fork),
        ]
    }
}

extension PlaytestSession.Coverage {
    /// The queue as prose: a countdown, then one line per item.
    ///
    /// Prose first because the reader is a language model deciding what to type
    /// next, and a list of commands reads as a list of commands where the same
    /// content escaped into one JSON line reads as a wall. The structured half
    /// carries the same items for anything counting them.
    ///
    /// - Parameter session: the session id, so a copied result says whose it is.
    /// - Returns: the text block.
    func rendered(session: String) -> String {
        var lines = ["[playtest] session=\(session) open=\(open) closed=\(closed) room=\(room)"]
        if items.isEmpty {
            lines.append(
                hint ?? "Nothing is open here. Walk somewhere the game has told you about.")
        }
        for item in items {
            lines.append("  \(item.rendered)")
        }
        if !items.isEmpty, let hint {
            lines.append(hint)
        }
        if let note {
            lines.append("[playtest] \(note)")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// The queue as JSON, matching `PlaytestTools.coverageSchema`.
    ///
    /// - Parameter session: the session id.
    /// - Returns: the document.
    func json(session: String) -> JSONValue {
        var entry: [String: JSONValue] = [
            "session": .string(session),
            "open": .integer(open),
            "closed": .integer(closed),
            "room": .string(room),
            "items": .array(items.map(\.json)),
        ]
        if let hint {
            entry["hint"] = .string(hint)
        }
        if let note {
            entry["harness"] = .string(note)
        }
        return .object(entry)
    }
}

extension PlaytestSignals {
    /// The signals as JSON, matching the `signals` block of
    /// `PlaytestTools.finishSchema`.
    var json: JSONValue {
        [
            "commands": .integer(commands),
            "roomsVisited": .integer(roomsVisited),
            "roomDwell": .double(roomDwell),
            "novelCommandRatio": .double(novelCommandRatio),
            "nounFollowRate": .double(nounFollowRate),
            "nounsPrintedByExamines": .integer(nounsPrintedByExamines),
            "interactionBreadth": .double(interactionBreadth),
            "objectsBound": .integer(objectsBound),
            "dischargeRate": .double(dischargeRate),
            "openItems": .integer(openItems),
        ]
    }
}

extension PlaytestSession.Closing {
    /// The closing record as JSON, matching `PlaytestTools.finishSchema`.
    var json: JSONValue {
        var entry: [String: JSONValue] = [
            "accepted": .bool(accepted),
            "open": .integer(open),
            "items": .array(items.map(\.json)),
            "forks": .array(
                forks.map {
                    .object([
                        "id": .string($0.id),
                        "command": .string($0.command),
                        "room": .string($0.room),
                        "taken": .bool($0.taken),
                    ])
                }),
            "signals": signals.json,
            "roomsVisited": .array(
                roomsVisited.map { .object(["id": .string($0.id.raw), "name": .string($0.name)]) }
            ),
            "roomsOnlyInBranches": .array(roomsOnlyInBranches.map { .string($0.raw) }),
            "firedTimers": .object(firedTimers.mapValues { .integer($0) }),
            "unknownWords": .object(
                unknownWords.mapValues { .integer($0) }),
            "transcript": .string(transcript),
            "message": .string(message),
        ]
        if let hint {
            entry["hint"] = .string(hint)
        }
        return .object(entry)
    }
}

// MARK: - Rendering a checkpoint, a rewind and an export

extension PlaytestSession.Marked {
    /// A checkpoint as JSON, matching `PlaytestTools.checkpointSchema`.
    var json: JSONValue {
        [
            "name": .string(name),
            "line": .integer(line),
            "room": .string(room),
            "moves": .integer(moves),
            "message": .string(message),
        ]
    }
}

extension PlaytestSession.Rewound {
    /// A rewind as JSON, matching `PlaytestTools.rewindSchema`. The two optional
    /// fields are left out rather than sent as null: a plain rewind has no name
    /// to report, and a rewind that discarded nothing wrote no branch file.
    var json: JSONValue {
        var entry: [String: JSONValue] = [
            "line": .integer(line),
            "room": .string(room),
            "moves": .integer(moves),
            "discarded": .integer(discarded),
            "status": .string(status),
            "message": .string(message),
        ]
        if let name {
            entry["name"] = .string(name)
        }
        if let branch {
            entry["branch"] = .string(branch)
        }
        return .object(entry)
    }
}

extension PlaytestSession.Export {
    /// An export as JSON, matching `PlaytestTools.exportSchema`.
    var json: JSONValue {
        [
            "transcript": .string(transcript),
            "transcriptWithoutStatus": .string(transcriptWithoutStatus),
            "commands": .string(commands),
            "summary": .string(summary),
            "lines": .integer(lines),
            "seed": .integer(Int(bitPattern: UInt(seed))),
            "verified": .bool(verified),
            "message": .string(message),
        ]
    }
}

// MARK: - Rendering a replay

extension PlaytestReplay.Outcome {
    /// The replay as the caller reads it: a verdict when one was asked for, and
    /// otherwise the transcript.
    ///
    /// Prose either way, and for the same reason `move` is prose: this is a
    /// transcript, which is multi-line and full of quotation marks, and the one
    /// reader whose whole job is reading it should not have to un-escape it. The
    /// structured half carries the same fields for anything checking them.
    var rendered: String {
        // The path goes on the header line, before anything the caller came for,
        // because the one thing it reliably forgets to do is cite it.
        var lines = [
            "[playtest] replay lines=\(self.lines) finished=\(finished)"
                + (probe.map { " transcript=\($0.appendingPathComponent("transcript.txt").path)" }
                    ?? "")
        ]
        guard let verdict else {
            return lines[0] + "\n" + Self.clipped(transcript)
        }
        lines.append(
            verdict.found
                ? """
                found=true turn=\(verdict.turn) room=\(verdict.room) \
                moves=\(verdict.moves)\
                \(verdict.command.map { " command=`\($0)`" } ?? " (the opening)")
                """
                : """
                found=false — that text printed nowhere in this replay. The last turn is \
                below; check the command list and the seed before you believe the claim.
                """)
        lines.append("")
        lines.append(Self.clipped(verdict.context))
        return lines.joined(separator: "\n")
    }

    /// The replay as JSON, matching `PlaytestTools.replaySchema`.
    var json: JSONValue {
        var entry: [String: JSONValue] = [
            "lines": .integer(lines),
            "finished": .bool(finished),
        ]
        if let probe {
            entry["transcriptPath"] =
                .string(probe.appendingPathComponent("transcript.txt").path)
            entry["commandsPath"] =
                .string(probe.appendingPathComponent("commands.txt").path)
        }
        guard let verdict else {
            entry["transcript"] = .string(Self.clipped(transcript))
            return .object(entry)
        }
        entry["found"] = .bool(verdict.found)
        entry["turn"] = .integer(verdict.turn)
        entry["room"] = .string(verdict.room)
        entry["moves"] = .integer(verdict.moves)
        entry["actualContext"] = .string(Self.clipped(verdict.context))
        if let command = verdict.command {
            entry["command"] = .string(command)
        }
        return .object(entry)
    }

    /// The last ``PlaytestSession/resultCharacterCap`` characters, with a marker
    /// when anything went.
    ///
    /// The same ceiling a `move` answers under, and the same argument: a tool
    /// built to save its caller a job must not be able to answer with 40 KB. The
    /// tail is kept because a replay's interesting end is its end — the turn the
    /// claim is about is the one the reproducer was cut to reach.
    private static func clipped(_ text: String) -> String {
        let cap = PlaytestSession.resultCharacterCap
        guard text.count > cap else { return text }
        return """
            [truncated \(text.count - cap) characters from the start of this replay]

            """ + String(text.suffix(cap))
    }
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
