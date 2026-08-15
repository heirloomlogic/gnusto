/// The seams a play-test driver needs into a running world.
///
/// Everything here is `internal` and stays that way: a driver lives in this
/// module precisely so it can read `GameDefinition`, `WorldState` and the verb
/// tables without any of them becoming public API a shipped library can never
/// take back.
///
/// The theme is that `GameWorld` is an actor, so nothing outside it can read a
/// stored property — a driver that wants the room roster or a state copy has to
/// ask for it across the actor boundary, and these are those questions.

// MARK: - The parse record

/// What the parser made of one line, alongside what the turn printed.
///
/// It exists because the transcript is not a complete record of a turn. Two
/// facts in particular cannot be recovered from the text:
///
/// - **What was examined.** `examine` does not touch its object — the default
///   action calls `describeItem`, which only `say`s — so `isTouched` never
///   learns that the player looked. "Have I looked at this yet?" is otherwise
///   answerable only by re-reading the transcript and guessing which noun a
///   description belonged to.
/// - **Which words the game has never heard of.** The parse-failure line names
///   at most one word, and only on some paths. Matching the reply against
///   "You can't see any such thing" is a string-match on prose the game is
///   free to re-skin; asking the vocabulary is exact, and it answers for lines
///   that parsed as well as lines that didn't.
///
/// Built by `GameWorld.performAudited(_:)`, which is where the parse result is
/// still in hand.
struct TurnAudit: Sendable {
    /// True when the parser produced a command. False for a parse error, an
    /// open clarifying question, and for the line that answered an engine
    /// prompt — none of which named a verb.
    var understood: Bool = false

    /// The intent the line resolved to, or `nil` when it didn't resolve.
    var intent: Intent?

    /// The direct object the parser bound, as the parser bound it. A bare
    /// `hello` in a room with one person in it is *later* addressed to them by
    /// `GameWorld.run`; that fill-in happens after the parse and is not
    /// recorded here, because this is a record of what the player's words
    /// picked out.
    var directObject: EntityID?

    /// The indirect object the parser bound, if the pattern had one.
    var indirectObject: EntityID?

    /// Every token of the input the game's vocabulary does not know, in the
    /// order typed. Normally empty on a line that parsed, since the parser
    /// requires every token to be consumed.
    var unknownWords: [String] = []

    /// True when the line was consumed as the answer to an open engine prompt
    /// — a save/restore filename, or the post-death choice — rather than
    /// parsed as a command. Nothing else in the record is filled in.
    var answeredPrompt: Bool = false

    /// A line the parser never got a command out of.
    init(unknownWords: [String] = [], answeredPrompt: Bool = false) {
        self.unknownWords = unknownWords
        self.answeredPrompt = answeredPrompt
    }

    /// A line the parser did get a command out of.
    init(_ parsed: ParsedCommand, unknownWords: [String]) {
        self.understood = true
        self.intent = parsed.intent
        self.directObject = parsed.directObject
        self.indirectObject = parsed.indirectObject
        self.unknownWords = unknownWords
    }
}

// MARK: - State, rosters, and the footer's fields

extension GameWorld {
    /// A copy of the whole mutable world, for a driver that wants to branch a
    /// session and come back.
    ///
    /// A struct copy, deliberately **not** routed through `SaveStore` /
    /// `SaveFile`: the player-facing save path is a two-turn prompt
    /// interaction, it touches the filesystem, and it is itself something a
    /// play-test session has to be able to exercise. A checkpoint that went
    /// through it would be testing the thing it is supposed to stand outside
    /// of.
    ///
    /// Note what a snapshot does *not* carry, by the same argument that keeps
    /// them off `WorldState`: the UNDO snapshot, the pristine restart state,
    /// any open prompt, and the `firedTimers` tally. Restoring rewinds the
    /// world, not the session.
    ///
    /// - Returns: the current world state.
    func snapshot() -> WorldState {
        state
    }

    /// Puts back a state taken by ``snapshot()``.
    ///
    /// Clears the open clarification and prompt, because a question asked
    /// against the old state has no answer in the new one — the same
    /// housekeeping `performUndo` and `performRestart` do.
    ///
    /// - Parameter snapshot: a state previously returned by `snapshot()`.
    func restore(_ snapshot: WorldState) {
        state = snapshot
        pendingClarification = nil
        pendingPrompt = nil
    }

    /// The static facts about the game — everything a driver can report
    /// without spending a turn. See ``PlaytestSurvey``.
    ///
    /// - Returns: the survey of the declared game.
    func survey() -> PlaytestSurvey {
        PlaytestSurvey(definition)
    }

    /// Whether the game's vocabulary knows each of these words, batched: twenty
    /// candidate nouns lifted out of one room description resolve in a single
    /// question and cost no turns, where typing them at the parser would cost
    /// twenty round trips and could change the world on the way past.
    ///
    /// - Parameter words: the words to ask about, as typed.
    /// - Returns: each word paired with whether the game knows it, in order.
    func knows(_ words: [String]) -> [(word: String, known: Bool)] {
        words.map { word in
            // Split the way the parser splits, so a caller that hands over
            // "master's" gets the answer for the token the parser would make
            // of it rather than a guaranteed no. See `Vocabulary.words(in:)`.
            let tokens = Vocabulary.words(in: word)
            let known = !tokens.isEmpty && tokens.allSatisfy { definition.vocabulary.knows($0) }
            return (word, known)
        }
    }

    /// The extra status-footer fields the game's bundles and plugins
    /// contribute, evaluated now.
    ///
    /// A field reads live state — `Clock`'s hour is a function of the `moves`
    /// counter — so it needs a turn frame, and there is none between turns.
    /// This builds a throwaway one exactly as `begin()` does, and then
    /// **discards** it rather than committing: the scratch's writes go nowhere,
    /// which is the read-only contract stated on `GameContent.statusFields`
    /// made literal. It is also why the whole thing is skipped when nobody
    /// declared a field, and why the caller only asks when a footer is in
    /// force.
    ///
    /// - Returns: the contributed `name`/`value` pairs, in declaration order.
    func statusFields() -> [(String, String)] {
        guard !definition.statusFields.isEmpty else { return [] }
        let scratch = TurnFrame(definition: definition, state: state)
        let fields = Ctx.$frame.withValue(scratch) {
            definition.statusFields.flatMap { $0() }
        }
        _ = scratch.retire()  // discard: a status field is read-only by contract
        return fields
    }
}

// MARK: - The survey

/// Everything a driver can say about a game without playing it: the rooms and
/// how they connect, the declared timers, the verb table, and the bootstrap's
/// own complaints.
///
/// Values, not references into the definition, so a caller holds a report
/// rather than a live handle — and so the one thing that would be unsafe to
/// hand over stays out by construction. A `.conditional` or `.dynamic` exit
/// carries an author closure that has to run inside a live turn frame; running
/// one out of turn to fill in a map would execute game code at a moment the
/// engine never intended, so the survey reports the exit's *kind* and its
/// declared destination where there is one, and never calls the closure.
struct PlaytestSurvey: Sendable {
    /// One way out of a room.
    struct Exit: Sendable {
        /// The direction, as the map declared it (`"north"`).
        let direction: String
        /// What sort of exit it is: `"open"`, `"blocked"`, `"door"`,
        /// `"conditional"` or `"dynamic"`.
        let kind: String
        /// Where it leads, when that is knowable without running author code.
        /// `nil` for a blocked exit (it leads nowhere) and for a dynamic one
        /// (it decides at `go` time).
        let destination: EntityID?
        /// The door item the exit hangs on, for a `"door"` exit.
        let door: EntityID?
    }

    /// One room.
    struct Room: Sendable {
        let id: EntityID
        /// The declared name, or the raw ID for a room that never got one.
        let name: String
        /// Whether some exit somewhere leads here. False marks a room only a
        /// rule can put the player in — a holding pen, or a room the map
        /// forgot. See `GameDefinition.reachableRooms`, which is the honest
        /// denominator for "how much of the map did this session see": counting
        /// against every declared room charges a tester for the street an actor
        /// waits out on.
        let isReachable: Bool
        /// This room's exits, in direction order.
        let exits: [Exit]
    }

    /// One declared fuse or daemon.
    struct Timer: Sendable {
        let name: String
        /// `"fuse"` or `"daemon"`.
        let kind: String
        /// Turns until a fuse fires once started; `nil` for a daemon.
        let turns: Int?
        /// Whether it runs from turn one without anything starting it.
        let autostart: Bool
    }

    let title: String
    let maxScore: Int
    /// Every declared room, in ID order.
    let rooms: [Room]
    /// Every declared timer, in name order.
    let timers: [Timer]
    /// The words that lead a verb the engine backs with behavior — the ~31
    /// intents of `SyntaxRule.coreTable`, plus whatever the game reclaimed.
    let coreVerbs: [String]
    /// The words that lead a stub verb: a word with one line of prose and no
    /// mechanic. `SyntaxRule.stubTable`.
    let stubVerbs: [String]
    /// Verb words this game added that are in neither standard table.
    let customVerbs: [String]
    /// The cast — the actors, player excluded. `GameDefinition.castIDs`.
    let cast: [EntityID]
    /// The bootstrap's non-fatal notes, verbatim. A game that starts with
    /// warnings is a game with something wrong in it that nobody has read yet.
    let warnings: [String]

    /// Reads a survey off a built definition.
    ///
    /// - Parameter definition: the game to survey.
    init(_ definition: GameDefinition) {
        self.title = definition.title
        self.maxScore = definition.maxScore
        self.rooms = definition.locations.keys.sorted().map { id in
            Room(
                id: id,
                name: definition.locations[id]?.name ?? id.raw,
                isReachable: definition.reachableRooms.contains(id),
                exits: (definition.exits[id] ?? [:])
                    .sorted { $0.key.rawValue < $1.key.rawValue }
                    .map { Exit($0.key, $0.value) })
        }
        self.timers = definition.timers.keys.sorted().map { name in
            let event = definition.timers[name]
            switch event?.kind {
            case .fuse(let turns):
                return Timer(
                    name: name, kind: "fuse", turns: turns,
                    autostart: event?.autostart ?? false)
            default:
                return Timer(
                    name: name, kind: "daemon", turns: nil,
                    autostart: event?.autostart ?? false)
            }
        }

        // Split by which standard table the row came from, so a driver can tell
        // "this verb has behavior behind it" from "this verb is a sentence" —
        // the distinction `CoreVerbs.swift` and `StubVerbs.swift` exist to
        // state, and the one a stub-verb survey is counting.
        let core = Set(SyntaxRule.coreTable.flatMap(\.leadingWords))
        let stub = Set(SyntaxRule.stubTable.flatMap(\.leadingWords))
        let declared = Set(definition.syntaxRules.flatMap(\.leadingWords))
        self.coreVerbs = declared.intersection(core).sorted()
        self.stubVerbs = declared.subtracting(core).intersection(stub).sorted()
        self.customVerbs = declared.subtracting(core).subtracting(stub).sorted()

        self.cast = definition.castIDs.sorted()
        self.warnings = definition.warnings
    }
}

extension PlaytestSurvey.Exit {
    /// Reads one exit's reportable shape, running nothing.
    fileprivate init(_ direction: Direction, _ target: ExitTarget) {
        self.direction = direction.rawValue
        switch target {
        case .to(let destination):
            self.kind = "open"
            self.destination = destination
            self.door = nil
        case .blocked:
            self.kind = "blocked"
            self.destination = nil
            self.door = nil
        case .door(let destination, let door):
            self.kind = "door"
            self.destination = destination
            self.door = door
        case .conditional(let destination, _, _):
            self.kind = "conditional"
            self.destination = destination
            self.door = nil
        case .dynamic:
            self.kind = "dynamic"
            self.destination = nil
            self.door = nil
        }
    }
}
