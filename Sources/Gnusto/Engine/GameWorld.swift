import Foundation

/// The status line a handler can display: location, score, and turn count.
public struct StatusLine: Sendable {
    /// The current location, by the ID the game declared it under.
    ///
    /// Not for display — ``locationName`` is what a status bar prints. This is
    /// here because a display name is not an identity: `name(…)` is prose and
    /// nothing stops two rooms sharing one. A consumer that records *where the
    /// player has been* needs the key space the room roster is in, or a game
    /// with repeated names has rooms it can never count. What that cost, in
    /// numbers, is on `PlaytestSession.Closing.roomsVisited`, which is the
    /// consumer in this repo.
    public let locationID: EntityID
    /// The current location's name.
    public let locationName: String
    /// The player's current score.
    public let score: Int
    /// The number of turns taken so far.
    public let moves: Int
}

/// The outcome of a single turn: text to show, whether the game ended, and the
/// status line to display.
public struct TurnResult: Sendable {
    /// The text to present to the player.
    public let output: String
    /// True once the game has ended.
    public let isFinished: Bool
    /// The status line to display alongside the output.
    public let status: StatusLine
    // Round-trip questions (disambiguation, save/restore filenames) are
    // pending state on the GameWorld actor: the next input line answers
    // them, so the driver never needs to know a question is open.
}

/// The game world: owns all state, serializes all mutation, and runs the
/// turn pipeline. The single `await` in a game sits between the REPL and
/// this actor.
public actor GameWorld {
    let definition: GameDefinition
    var state: WorldState
    let parser: StandardParser
    /// An open clarifying question ("Which do you mean…?", "What do you want
    /// to take?"): the next input line is first tried as its answer,
    /// re-parsed as `prefix + answer + suffix`.
    var pendingClarification: (prefix: [String], suffix: [String])?
    /// The pristine post-bootstrap state, seed included — what RESTART
    /// rewinds to. Actor state, never part of `WorldState` itself.
    private let initialState: WorldState
    /// Where bare save names (`save autumn`) resolve to, and the directory the
    /// restore prompt lists. Explicit paths the player types bypass it — unless
    /// ``savePathsRestricted`` forbids them. See `SaveStore`.
    let saveDirectory: URL
    /// Whether answers to the save/restore prompts are barred from naming
    /// explicit filesystem paths (`/` or `~`) and may only name bare slots
    /// inside `saveDirectory`. True whenever a save directory was injected —
    /// through the initializer or the `GNUSTO_SAVE_DIR` environment variable:
    /// the play-test harness, replay tools, and every other
    /// session a program set up rather than a human at a terminal — so a
    /// batched prompt answer cannot land a file outside `saveDirectory`. A
    /// human running the game themselves keeps the classic
    /// save-to-any-path behavior.
    let savePathsRestricted: Bool
    /// The one-level UNDO snapshot: the state as it stood before the last
    /// turn that actually ran stages. Kept on the actor so history never
    /// leaks into save files.
    var undoSnapshot: WorldState?
    /// The open engine prompt, if any — a save/restore filename or the
    /// post-death RESTART / RESTORE / UNDO / QUIT choice. While one is armed
    /// the next input line *is* its answer; see `PendingPrompt` and `answer`
    /// in `GameWorld+Prompts.swift`.
    var pendingPrompt: PendingPrompt?
    /// How many times each declared fuse or daemon has actually run its body
    /// this session, by timer name — the play-test harness's answer to "did
    /// this timer ever fire?", which no amount of reading the transcript can
    /// settle for a timer whose body says nothing.
    ///
    /// Actor state, never serialized: it is a fact about *this run of the
    /// program*, not about the world, so it must not reach `WorldState`,
    /// `SaveFile` or `isConsistent`. The precedent is `undoSnapshot` above and
    /// `initialState`, both kept here for exactly the same reason — history
    /// must not leak into a save file. A restore therefore leaves the tally
    /// alone, which is right: the timers really did fire.
    ///
    /// Read by ``PlaytestSession``, which folds it into `closing.json` so a
    /// round can name the declared timers nothing exercised.
    var firedTimers: [String: Int] = [:]

    /// Every room a move has put the player in this session, in first-arrival
    /// order — **including a room they were in only part-way through a turn**.
    ///
    /// The play-test harness's answer to "was this room ever entered?", and the
    /// same kind of answer as `firedTimers` above: something no reading of the
    /// status line can settle. A turn is free to stand the player somewhere and
    /// move them on before it ends, and the status line only ever reports where
    /// it ended. Fulminate's 5:52 clock walks a player out of the carriage
    /// house on the turn they walk into it, so a tester reads the room's whole
    /// description and closes a session that says the room was never entered —
    /// and a round planning off that count sends the next tester to walk it
    /// again. See ``Scratch/roomsOccupied``, which is where a turn collects
    /// these, and ``commit(_:)``, which is where they arrive.
    ///
    /// Actor state, never serialized, for the reason `firedTimers` states: it
    /// is a fact about *this run of the program*, not about the world, so it
    /// must not reach `WorldState`, `SaveFile` or `isConsistent`. A restore, an
    /// UNDO or a play-test rewind therefore leaves it alone, which is right —
    /// the player really did stand there, and the tester really did read it.
    ///
    /// Not a complete record of where the player has been, and it does not have
    /// to be: a state swapped in wholesale by RESTART, RESTORE or UNDO passes
    /// no move funnel, and the room it lands in is on the status line the turn
    /// ends with, which is what ``PlaytestSession`` was already recording. This
    /// is the part that reading was missing.
    var roomsOccupied: [EntityID] = []

    /// The world as the last turn that *cost* a move stood at its close,
    /// before its counter advanced — or nil, meaning "read the fields live".
    ///
    /// Actor state, never serialized, for the same reason as `undoSnapshot`
    /// and `initialState` above: it is a fact about the turn just committed,
    /// not about the world. Written only by ``commit(_:)``, out of the
    /// retiring frame's `Scratch`, and cleared only by ``freeReply(_:)`` and
    /// the play-test `restore(_:)` — which between them are every way a
    /// `TurnResult` reaches a driver without a cost turn behind it. Read only
    /// by `statusFields()`. See ``Scratch/statusFieldState`` for why the
    /// sample exists at all.
    var statusFieldState: WorldState?

    /// Builds the world from a game definition, validating it up front.
    /// The random stream is seeded fresh each run; use `init(game:seed:)`
    /// to replay a specific one.
    ///
    /// - Parameters:
    ///   - game: the game definition to build the world from.
    ///   - saveDirectory: where bare save names resolve; defaults to the
    ///     per-user saves directory for the game's title.
    /// - Throws: if the game definition is invalid.
    public init(game: some Game, saveDirectory: URL? = nil) throws {
        try self.init(
            game: game,
            seed: UInt64.random(in: .min ... .max),
            saveDirectory: saveDirectory)
    }

    /// Builds the world with a fixed random seed: the same seed and the same
    /// commands replay the same game, on any platform — for transcripts,
    /// tests, and bug reports.
    ///
    /// - Parameters:
    ///   - game: the game definition to build the world from.
    ///   - seed: the fixed random seed to replay.
    ///   - saveDirectory: where bare save names resolve; defaults to the
    ///     per-user saves directory for the game's title.
    /// - Throws: if the game definition is invalid.
    public init(game: some Game, seed: UInt64, saveDirectory: URL? = nil) throws {
        self.init(prepared: try PreparedGame(game), seed: seed, saveDirectory: saveDirectory)
    }

    /// Builds the world from a game booted once via `PreparedGame`, skipping the
    /// bootstrap the prepared game already ran. The definition and pristine state
    /// are shared (value types, copied in); only the seed, parser, and save
    /// directory are per-world — so many worlds can spin up from one prepared
    /// game without re-paying `Bootstrap.build`. See `PreparedGame`.
    ///
    /// - Parameters:
    ///   - prepared: a game already booted through `Bootstrap.build`.
    ///   - seed: the fixed random seed to replay.
    ///   - saveDirectory: where bare save names resolve; defaults to the
    ///     per-user saves directory for the game's title.
    public init(prepared: PreparedGame, seed: UInt64, saveDirectory: URL? = nil) {
        self.definition = prepared.definition
        self.state = prepared.state
        self.state.rngState = seed
        // Captured after seeding, so RESTART replays the identical game,
        // randomness included.
        self.initialState = self.state
        self.parser = prepared.parser
        self.saveDirectory =
            saveDirectory
            ?? SaveStore.defaultDirectory(forGameTitled: definition.title)
        // An injected directory counts either way it arrives: the initializer
        // argument, or `GNUSTO_SAVE_DIR`, which replay tools like
        // `bin/playtest-replay` set for a world built through `GameMain` with
        // no `saveDirectory:` of its own.
        self.savePathsRestricted =
            saveDirectory != nil || SaveStore.directoryIsInjected()
    }

    /// The opening of the game: intro, banner, and the first look around.
    ///
    /// - Returns: the opening turn's output and status.
    public func begin() -> TurnResult {
        let frame = TurnFrame(definition: definition, state: state, command: lookCommand)
        Ctx.$frame.withValue(frame) {
            frame.say(definition.intro)
            frame.say(definition.text.banner(definition.title, definition.tagline))
            RoomDescriber.describeCurrentLocation(mode: .entry, frame: frame)
        }
        return commit(frame)
    }

    /// Parses and performs one line of player input. Parse errors are free:
    /// no rules run and the turn counter doesn't advance. Question-type
    /// errors ("Which do you mean…?") stay open: the next line is first
    /// tried as their answer, and falls back to being a fresh command.
    ///
    /// - Parameter input: one line of player input.
    /// - Returns: the turn's output and status.
    public func perform(_ input: String) -> TurnResult {
        performAudited(input).result
    }

    /// `perform`, plus what the parser made of the line — see ``TurnAudit`` for
    /// why the second half exists and why it can't be recovered from the first.
    ///
    /// The whole body of `perform` lives here rather than the other way round:
    /// a second copy of the clarification dance would be a second thing to keep
    /// in step, and the one that drifted would be the one nobody plays.
    ///
    /// - Parameter input: one line of player input.
    /// - Returns: the turn's output and status, and the parse record.
    func performAudited(_ input: String) -> (result: TurnResult, audit: TurnAudit) {
        if let prompt = pendingPrompt {
            pendingPrompt = nil
            let result = answer(prompt, with: input.trimmingCharacters(in: .whitespaces))
            // The line was an answer, not a command: no verb was read from it,
            // so every parse field stays empty and `answeredPrompt` says why.
            return (result, TurnAudit(answeredPrompt: true))
        }

        let scope = currentScope()
        let tokens = parser.tokenize(input)
        // Asked of the vocabulary rather than inferred from the reply: the
        // player-facing message names at most one word and only on some of the
        // failure paths, while this is every token the game has never heard of,
        // available even on the lines that parsed.
        let unknown = tokens.filter { !definition.vocabulary.knows($0) }

        if let pending = pendingClarification {
            pendingClarification = nil
            let augmented = pending.prefix + tokens + pending.suffix
            switch parser.parse(tokens: augmented, rawInput: input, scope: scope) {
            case .success(let parsed):
                let result = armDeathPromptIfNeeded(run(parsed))
                return (result, TurnAudit(parsed, unknownWords: unknown))
            case .failure(let error):
                // Still ambiguous ("brass" matched two): ask the narrower
                // question. Anything else means the line wasn't an answer —
                // fall through and parse it as a fresh command.
                if let context = error.clarification {
                    pendingClarification = context
                    let result = freeReply(error.playerMessage(definition.text))
                    return (result, TurnAudit(unknownWords: unknown))
                }
            }
        }

        switch parser.parse(tokens: tokens, rawInput: input, scope: scope) {
        case .failure(let error):
            pendingClarification = error.clarification
            let result = freeReply(error.playerMessage(definition.text))
            return (result, TurnAudit(unknownWords: unknown))
        case .success(let parsed):
            let result = armDeathPromptIfNeeded(run(parsed))
            return (result, TurnAudit(parsed, unknownWords: unknown))
        }
    }

    /// Quits at the front end's request — a Ctrl-C, not a typed command.
    /// Abandons any open engine prompt or clarification and ends the game
    /// through the same path the `quit` verb takes, so the score epilogue still
    /// prints. Keyed to `Intent.quit`, so it's immune to a game redefining the
    /// `quit` verb word and quits even while a save/restore filename prompt is
    /// pending — which `perform` would otherwise consume the line as the
    /// filename answer.
    ///
    /// - Returns: the final turn's output and status (`isFinished == true`).
    public func requestQuit() -> TurnResult {
        pendingPrompt = nil
        pendingClarification = nil
        return runTurn(
            Command(intent: .quit, verbPhrase: "quit", rawInput: "quit"),
            snapshot: state)
    }

    /// After a turn that killed the player, the next input line belongs to
    /// the death prompt.
    private func armDeathPromptIfNeeded(_ result: TurnResult) -> TurnResult {
        if state.status == .dead {
            pendingPrompt = .deathChoice
        }
        return result
    }

    /// Runs a successfully parsed command: engine-level meta verbs first,
    /// then pronoun bookkeeping and the single- or multi-object turn.
    private func run(_ parsed: ParsedCommand) -> TurnResult {
        // UNDO and RESTART act on the actor's snapshots, not the pipeline —
        // no rules see them and `actionOverrides` can't reclaim them.
        switch parsed.intent {
        case .undo: return performUndo()
        case .restart: return performRestart()
        case .save:
            pendingPrompt = .saveFilename
            return freeReply(definition.text.savePrompt())
        case .restore:
            pendingPrompt = .restoreFilename(returnToDeathPrompt: false)
            return freeReply(restorePromptText())
        default: break
        }

        // A bare HELLO in a room with exactly one person in it is addressed to
        // them, filled in here rather than in the parser — which has no world
        // to consult — so that it reaches that actor's rules exactly as
        // "hello, keeper" would. With nobody, or with a crowd, it stays
        // unaddressed and the default action says so.
        var parsed = parsed
        if parsed.intent == .greet, parsed.directObject == nil, parsed.actor == nil,
            let only = soleVisibleActor()
        {
            parsed.directObject = only
        }

        // The would-be UNDO snapshot: the state before *anything* this turn
        // touches, pronouns included. Stored only when the turn actually
        // runs stages — a free reply ("There is nothing here to take.")
        // must not clobber the snapshot of the last real turn.
        let snapshot = state

        // Naming a thing binds "it" — even if the action then refuses.
        if let direct = parsed.directObject {
            state.pronounIt = direct
        }
        if let multiple = parsed.multiple {
            return runMultiTurn(parsed, multiple, snapshot: snapshot)
        }
        return runTurn(command(from: parsed), snapshot: snapshot)
    }

    // MARK: - The turn pipeline

    /// The command the engine's own describing passes — `begin`, UNDO and
    /// RESTORE — hand the room describer. Those passes don't run a player
    /// command, but a `describe { }` or `presence { }` closure may ask
    /// `command.intent` just the same, and in fiction they are all a LOOK: it
    /// is what the player sees. #395.
    var lookCommand: Command {
        Command(intent: .look, verbPhrase: "look", rawInput: "")
    }

    private func runTurn(_ command: Command, snapshot: WorldState) -> TurnResult {
        let frame = TurnFrame(definition: definition, state: state, command: command)
        Ctx.$frame.withValue(frame) {
            performStages(command, frame: frame, upkeep: true)
            finishTurn(intent: command.intent, frame: frame)
        }
        // Stored only once the turn is known to have been one — the same rule
        // `run` states for a free reply, and a command nothing answered is no
        // more a turn than a parse error was. Nothing in the pipeline reads
        // the snapshot, so the decision keeps until the frame comes back.
        if !command.intent.isMeta, !frame.with({ $0.unhandled }) {
            undoSnapshot = snapshot
        }
        return commit(frame)
    }

    /// The intents that accept several objects in the direct slot — "all",
    /// "them", or a conjunction list. Everything else refuses up front.
    static let multiObjectIntents: Set<Intent> = [.take, .drop, .putIn, .putOn]

    /// A multi-object turn: expand the marker against the current state,
    /// then run stages 1–5 once per object with `name:`-labeled output.
    /// Once-per-turn upkeep (the each-turn `before` phases and all of
    /// stage 6) runs once for the whole command, so a daemon doesn't tick
    /// once per object.
    private func runMultiTurn(
        _ parsed: ParsedCommand, _ multiple: ParsedCommand.MultiObject,
        snapshot: WorldState
    ) -> TurnResult {
        let intent = parsed.intent
        // "robot, take all" fails the first clause: the loop expands against
        // what the *player* can get at and runs stage 4 once per object, and
        // stage 4 is exactly what an order never reaches.
        guard parsed.actor == nil, Self.multiObjectIntents.contains(intent) else {
            return freeReply(definition.text.multipleNotAllowedWith(parsed.verbPhrase))
        }

        // The index is built inside each keyword case rather than out here:
        // a list the player wrote out is already resolved, and a room sweep
        // for it would be for nothing.
        var objects: [EntityID]
        switch multiple {
        case .all where intent == .take:
            let index = state.containment()
            // The question TAKE ALL asks is "what could I pick up here", and
            // that is the *reachable* set, not the nameable one: a shut glass
            // case shows its medal and the troll's axe is plainly in his hands,
            // but offering either only earns a refusal by name (#267). A
            // `reach { … }` veto is deliberately still offered — `reachableItems`
            // is containment-only, and a rule that says "the length of the
            // gallery away" wants to say it, not to vanish the thing.
            let reachable = Visibility.reachableItems(
                at: state.playerLocation, definition: definition, state: state, index: index)
            // Subtract the player's inventory to *any* depth. The direct
            // children are not enough: the water is in the bottle and the
            // bottle is in your hand, and ALL has nothing to add to that.
            // A TAKE ALL policy, not an impossibility — `take water` by name
            // still runs, and is still the game's own business to answer.
            let carried = index.closure(under: index.held[.player] ?? [])
            objects = inDisplayOrder(
                reachable.filter {
                    definition.items[$0]?.isTakable == true && !carried.contains($0)
                })
        case .all:
            // DROP/PUT ALL is the opposite question and keeps the opposite
            // answer: what you hold, direct children only, so DROP ALL empties
            // your hands and not your sack. Worn items are placed
            // `.heldBy(.player)` too, which is why they come along.
            objects = inDisplayOrder(state.containment().held[.player] ?? [])
        case .them:
            guard !state.pronounThem.isEmpty else {
                return freeReply(definition.text.noReferent("them"))
            }
            // Visible, not reachable: "them" is a pronoun recalling the group
            // the player just named, and a member that has since gone behind
            // glass should be refused by name rather than silently dropped
            // from the group.
            let visible = Visibility.visibleItems(
                at: state.playerLocation, definition: definition, state: state,
                index: state.containment())
            objects = inDisplayOrder(state.pronounThem.filter { visible.contains($0) })
            guard !objects.isEmpty else {
                return freeReply(definition.text.cantSeeAnySuchThing())
            }
        case .list(let named):
            // Already resolved, so no set to sweep and no order to invent: the
            // player wrote one. Deliberately unfiltered too — "all" skips the
            // scenery statue, but a player who names it has asked about that
            // thing and is owed the refusal.
            objects = named
        }
        // Two things come out of the group before it runs, and they are one
        // subtraction: what the player excepted (`take all but the sword`) and
        // the container they named to put things into. Neither is checked
        // against the group first — the player said which things they did not
        // mean, not which things are here, so excepting something that was
        // never on offer is no error worth stopping the command for.
        //
        // What they share is the answer when they empty a group that had
        // something in it. "You aren't carrying anything" is false of a player
        // holding the one thing they just excepted, and equally false of one
        // holding only the sack they said to put things in.
        var subtract = multiple.exclusions
        if intent == .putIn || intent == .putOn, let indirect = parsed.indirectObject {
            subtract.append(indirect)
        }
        if !objects.isEmpty, !subtract.isEmpty {
            objects.removeAll(where: subtract.contains)
            guard !objects.isEmpty else {
                return freeReply(definition.text.nothingLeftOfTheGroup())
            }
        }
        guard !objects.isEmpty else {
            return freeReply(
                intent == .take ? definition.text.nothingToTakeHere() : definition.text.notCarryingAnything())
        }

        // Every early return above was a free reply; from here the turn
        // really runs, so it becomes the thing UNDO reverses.
        undoSnapshot = snapshot

        state.pronounThem = objects

        // The upkeep pass runs before any object's command exists, but its
        // rules are rule bodies and may ask `command.intent`. What the player
        // typed was the group's intent, so that is what they are handed — no
        // object, because none has been named yet.
        let frame = TurnFrame(
            definition: definition, state: state, command: command(from: parsed))
        Ctx.$frame.withValue(frame) {
            do {
                try runUpkeepBefore(intent, frame: frame)
                for id in objects {
                    guard frame.with({ $0.state.status }) == .playing else { break }
                    guard let item = definition.registry.items[id] else { continue }
                    let command = command(from: parsed, overridingDirectObject: item)
                    // `unhandled` is not reset alongside `defaultRan`: every
                    // intent in `multiObjectIntents` is a core verb with a
                    // handler, so stage 4 always answers here and the flag
                    // can never be set part-way through the loop.
                    frame.with { scratch in
                        scratch.command = command
                        scratch.defaultRan = false
                    }
                    let start = frame.with { $0.output.count }
                    performStages(command, frame: frame, upkeep: false)
                    label(outputFrom: start, as: displayName(of: id), frame: frame)
                }
            } catch let interrupt as TurnInterrupt {
                // Upkeep refused: the whole command is off.
                handle(interrupt, frame: frame)
            } catch {
                frame.say("\(error)")
            }
            finishTurn(intent: intent, frame: frame)
        }
        return commit(frame)
    }

    /// A keyword stands for a set, which has no order of its own, so it gets a
    /// stable player-legible one: by display name, then ID. A list the player
    /// wrote out doesn't come through here — theirs is the order.
    private func inDisplayOrder(_ objects: [EntityID]) -> [EntityID] {
        objects.sorted { lhs, rhs in
            let (lhsName, rhsName) = (displayName(of: lhs), displayName(of: rhs))
            return lhsName == rhsName ? lhs < rhs : lhsName < rhsName
        }
    }

    /// Merges everything one object's run said into a single
    /// `brass lantern: Taken.` line.
    private func label(outputFrom start: Int, as name: String, frame: TurnFrame) {
        frame.with { scratch in
            let said = scratch.output[start...].joined(separator: " ")
            scratch.output.removeSubrange(start...)
            if !said.isEmpty {
                scratch.output.append("\(name): \(said)")
            }
        }
    }

    // MARK: - Engine-level meta verbs

    /// Rewinds exactly one turn from the actor's snapshot, then shows the
    /// player where (and when — the status line's moves) they are. Free.
    func performUndo() -> TurnResult {
        guard let snapshot = undoSnapshot else {
            return freeReply(definition.text.cantUndo())
        }
        state = snapshot
        undoSnapshot = nil
        pendingClarification = nil
        let frame = TurnFrame(definition: definition, state: state, command: lookCommand)
        Ctx.$frame.withValue(frame) {
            frame.say(definition.text.undone())
            RoomDescriber.describeCurrentLocation(mode: .entry, frame: frame)
        }
        return commit(frame)
    }

    /// Rewinds to the pristine post-bootstrap opening — seed included, so
    /// the restarted game replays identically — and plays the opening again.
    func performRestart() -> TurnResult {
        state = initialState
        undoSnapshot = nil
        pendingClarification = nil
        return begin()
    }

    /// A parse-error-style response: message only, no rules, no turn.
    func freeReply(_ message: String) -> TurnResult {
        // No turn ran, so the last one's sample is stale: this reply was
        // written against live state and the footer under it must read the
        // same world. One of the two places the sample is cleared; the other
        // is `commit`, which does it by adopting a nil.
        statusFieldState = nil
        return TurnResult(
            output: message,
            isFinished: state.status.isFinal,
            status: statusLine())
    }

    /// The once-per-turn `before` upkeep — `world.beforeEachTurn` and the
    /// location's `beforeEachTurn` rules — run separately from the per-object
    /// stages during a multi-object command.
    private func runUpkeepBefore(_ intent: Intent, frame: TurnFrame) throws {
        frame.with { $0.inBeforeRule = true }
        defer { frame.with { $0.inBeforeRule = false } }
        let here = frame.with { $0.state.playerLocation }
        try runBefore(
            definition.rules.worldBefore.filter { $0.phase == .beforeEachTurn },
            matching: intent, frame: frame)
        try runBefore(
            definition.rules.locationBeforeEachTurn[here] ?? [], matching: intent, frame: frame)
    }

    /// Stages 1–5 for one command. With `upkeep` the each-turn `before`
    /// phases are included (the single-command turn); without it they're the
    /// caller's job (`runMultiTurn` runs them once, outside its object loop).
    private func performStages(_ command: Command, frame: TurnFrame, upkeep: Bool) {
        let intent = command.intent
        let rules = definition.rules
        // Who is carrying this out, and where. The player, in their own room,
        // unless somebody was told to do it — then it is the person told and
        // the room *they* are standing in.
        let agent = command.actor?.id
        let here = frame.with { $0.state.playerLocation }
        let stage = agent.flatMap { id in frame.with { Visibility.standing(id, in: $0.state) } } ?? here

        do {
            // Stage 0: the objects' `reach { … }` rules, which have to be
            // settled ahead of the rules that could pre-empt stage 4.
            try DefaultActions.requireReachRules(for: command, frame: frame)

            // Stages 1–3: world, location, and item `before` rules.
            // Meta intents talk to the game program; no rules see them.
            // `inBeforeRule` is set for the span of these stages so
            // `proceed()` can recognize a legal call site; a rule that
            // calls it runs stage 4 early and flips `defaultRan`. Once
            // that flag is set, `run` (below) skips every remaining
            // before-phase for the rest of this sequence — `proceed()`
            // means "run the default now", so later before-guards for
            // this command are moot and must not run. Stage 4's own
            // call site (further down) checks the same flag to avoid
            // running the default a second time.
            if !intent.isMeta {
                frame.with { $0.inBeforeRule = true }
                defer { frame.with { $0.inBeforeRule = false } }
                let worldBefore =
                    upkeep
                    ? rules.worldBefore
                    : rules.worldBefore.filter { $0.phase == .before }
                try runBefore(worldBefore, matching: intent, frame: frame)
                if upkeep {
                    try runBefore(rules.locationBeforeEachTurn[here] ?? [], matching: intent, frame: frame)
                }
                try runBefore(rules.locationBefore[stage] ?? [], matching: intent, frame: frame)
                // The one told is told first — before the thing they were told
                // about — so `robot.before(.go)` can answer an order that names
                // no object at all. Skipped when they *are* one of the objects,
                // so nobody's rules run twice.
                if let agent, agent != command.directObject?.id, agent != command.indirectObject?.id {
                    try runBefore(rules.itemBefore[agent] ?? [], matching: intent, frame: frame)
                }
                if let indirect = command.indirectObject {
                    try runBefore(rules.itemBefore[indirect.id] ?? [], matching: intent, frame: frame)
                }
                if let direct = command.directObject {
                    try runBefore(rules.itemBefore[direct.id] ?? [], matching: intent, frame: frame)
                }
            }

            // Stage 4: the default action — skipped if a `before` rule
            // already ran it early via `proceed()`.
            if !frame.with({ $0.defaultRan }) {
                try DefaultActions.run(command, frame: frame)
            }

            // Stage 5: item and location `after` rules.
            if !intent.isMeta {
                if let direct = command.directObject {
                    try run(rules.itemAfter[direct.id] ?? [], matching: intent)
                }
                if let indirect = command.indirectObject {
                    try run(rules.itemAfter[indirect.id] ?? [], matching: intent)
                }
                // No agent pass here: an order can only be *answered* by a
                // `before` rule's `reply`/`refuse`, which throws, and an order
                // nobody answered throws `unhandled` out of stage 4. Either
                // way stage 5 is already unwound — the same contract `reply`
                // has always had for the player.
                try run(rules.locationAfter[here] ?? [], matching: intent)
            }
        } catch let interrupt as TurnInterrupt {
            handle(interrupt, frame: frame)
        } catch {
            frame.say("\(error)")
        }
    }

    /// Stage 6 and the epilogue: world time passes even on refused turns —
    /// but not for meta intents, not for a command nothing answered, and not
    /// once the game has ended. Runs once per typed command, however many
    /// objects it covered.
    private func finishTurn(intent: Intent, frame: TurnFrame) {
        let rules = definition.rules
        // A command stage 4 had no answer for is free, like a parse error:
        // the player was told nothing happened, so nothing may happen.
        let costsTurn = !intent.isMeta && !frame.with { $0.unhandled }
        if costsTurn {
            if frame.with({ $0.state.status }) == .playing {
                let here = frame.with { $0.state.playerLocation }
                runCatching(rules.locationAfterEachTurn[here] ?? [], matching: intent, frame: frame)
                runCatching(rules.worldAfter, matching: intent, frame: frame)
            }
            // The world's clock ticks last, after the rules have reacted to
            // the command — and not once the game has ended (re-checked here
            // because an each-turn rule above may have ended it).
            if frame.with({ $0.state.status }) == .playing {
                tickTimers(frame: frame)
            }
            // The sample the contributed status fields are read against, taken
            // here and nowhere else. Both halves of the position are
            // load-bearing.
            //
            // *After* the each-turn rules and the timer tick, so a rule that
            // flipped a global or a fuse that called `clock.advance(by:)` this
            // turn is in it — the turn's last word is written at this instant,
            // not at its first. *Before* the line below, because that line is
            // the whole of #280: everything the turn printed was written at
            // the count as it stands right here.
            //
            // Gated on the empty table, which is the same guard
            // `statusFields()` returns early on. Note what that guard does not
            // mean: `Bootstrap` collects one closure per content module
            // whether or not the module overrides the default, so a bundled
            // game reaches this line and pays one copy of a struct of COW
            // dictionaries per cost turn even when every closure returns [].
            // That is the same order as the two the turn already takes for its
            // UNDO snapshot, and it buys laziness at the other end: the
            // closures themselves are only run when a footer asks.
            if !definition.statusFields.isEmpty {
                frame.with { scratch in
                    scratch.statusFieldState = scratch.state
                }
            }
            frame.with { $0.state.moves += 1 }
        }

        // End-of-game epilogue: one place reports the final score, whether
        // the game was won, lost, quit — or the player died, in which case
        // the classic prompt follows and `perform` arms itself to consume
        // the answer.
        if frame.with({ $0.state.status }) != .playing {
            DefaultActions.score(frame)
        }
        if frame.with({ $0.state.status }) == .dead {
            frame.say(frame.definition.text.deathPrompt())
        }
    }

    /// Runs a stage 1–3 before-phase's rules — but not once a rule earlier in
    /// this turn's before-sequence has already called `proceed()`. Once the
    /// default action has run early, every remaining before rule is skipped:
    /// `proceed()` means "run the default now, I take responsibility," so a
    /// guard that hasn't run yet never gets the chance to refuse an action
    /// that already happened. The check sits *inside* the loop so a sibling
    /// rule later in this same phase is skipped too, not just later phases.
    private func runBefore(_ rules: [Rule], matching intent: Intent, frame: TurnFrame) throws {
        for rule in rules where rule.matches(intent) {
            guard !frame.with({ $0.defaultRan }) else { return }
            try rule.body()
        }
    }

    private func run(_ rules: [Rule], matching intent: Intent) throws {
        for rule in rules where rule.matches(intent) {
            try rule.body()
        }
    }

    private func runCatching(_ rules: [Rule], matching intent: Intent, frame: TurnFrame) {
        for rule in rules where rule.matches(intent) {
            do {
                try rule.body()
            } catch let interrupt as TurnInterrupt {
                handle(interrupt, frame: frame)
            } catch {
                frame.say("\(error)")
            }
        }
    }

    /// One tick of the world's clock: every running fuse counts down (and
    /// fires at zero), then every running daemon runs — fuses first, each
    /// group in name order, so firing order is deterministic. Each name is
    /// re-checked against the live schedule before it acts, because an
    /// earlier body may have stopped it this very tick; a fuse is removed
    /// from the schedule *before* its body runs, so the body can restart it.
    /// Bodies get the same interrupt handling as each-turn rules, and the
    /// tick stops as soon as one of them ends the game.
    private func tickTimers(frame: TurnFrame) {
        for name in frame.with({ $0.state.activeFuses.keys.sorted() }) {
            guard frame.with({ $0.state.status }) == .playing else { return }
            guard let event = definition.timers[name] else { continue }
            let fires = frame.with { scratch -> Bool in
                guard let remaining = scratch.state.activeFuses[name] else { return false }
                if remaining > 1 {
                    scratch.state.activeFuses[name] = remaining - 1
                    return false
                }
                scratch.state.activeFuses[name] = nil
                return true
            }
            if fires {
                runCatching(event, named: name, frame: frame)
            }
        }
        for name in frame.with({ $0.state.activeDaemons.sorted() }) {
            guard frame.with({ $0.state.status }) == .playing else { return }
            guard let event = definition.timers[name],
                frame.with({ $0.state.activeDaemons.contains(name) })
            else { continue }
            runCatching(event, named: name, frame: frame)
        }
    }

    private func runCatching(_ event: TimedEvent, named name: String, frame: TurnFrame) {
        // Counted before the body runs, so a timer that traps or ends the game
        // still registers as having fired — the tally answers "did this ever
        // happen?", and the crash is the loudest possible yes. See
        // `firedTimers`.
        firedTimers[name, default: 0] += 1
        do {
            try event.body()
        } catch let interrupt as TurnInterrupt {
            handle(interrupt, frame: frame)
        } catch {
            frame.say("\(error)")
        }
    }

    private func handle(_ interrupt: TurnInterrupt, frame: TurnFrame) {
        switch interrupt {
        case .refused(let message), .replied(let message), .unhandled(let message):
            // An empty message ends the turn without adding a line — for
            // rule bodies that have already said everything with `say`.
            if !message.isEmpty {
                frame.say(message)
            }
            // `unhandled` is the refusal nobody made: nothing in the game
            // claimed the command, so `finishTurn` reads this flag and skips
            // the each-turn rules, the timers and the move count. The line and
            // the price agree the way a parse error's do.
            if case .unhandled = interrupt {
                frame.with { $0.unhandled = true }
            }
        case .gameOver(let won):
            frame.with { $0.state.status = won ? .won : .lost }
        case .died(let message):
            // The death message always prints; then the game's handler gets
            // to decide the death's fate (still inside the live frame, so it
            // can say/mutate/teleport). A consumed death leaves the world
            // `.playing` — the turn finishes normally, fuses and daemons tick,
            // and no banner or prompt appears. Fall-through is byte-identical
            // to the pre-hook path.
            frame.say(message)
            switch frame.definition.onDeath() {
            case .consumed:
                break
            case .fallThrough:
                frame.say(frame.definition.text.deathBanner())
                frame.with { $0.state.status = .dead }
            }
        }
    }

    // MARK: - Support

    private func command(
        from parsed: ParsedCommand,
        overridingDirectObject: Item? = nil
    ) -> Command {
        Command(
            intent: parsed.intent,
            directObject: overridingDirectObject
                ?? parsed.directObject.flatMap { definition.registry.items[$0] },
            indirectObject: parsed.indirectObject.flatMap { definition.registry.items[$0] },
            preposition: parsed.preposition,
            direction: parsed.direction,
            topic: parsed.topic.map(Topic.init),
            actor: parsed.actor.flatMap { definition.registry.items[$0] }.map(Actor.init),
            verbPhrase: parsed.verbPhrase,
            rawInput: parsed.rawInput)
    }

    /// What the player can currently refer to: carried and worn items always;
    /// with light, the room's contents descended through surfaces and visible
    /// containers. Parser scope keys off *visible* items — you can name what you
    /// can see, even through a shut glass jar; the actions enforce
    /// reachability.
    ///
    /// - Parameter orders: whether to reach outside the room at all — each
    ///   order-taking actor's own scope, and the actors standing elsewhere.
    ///   Only a parse needs either; `completionCandidates()` reads
    ///   `visibleItems` alone, and offering an absent actor's nouns to Tab
    ///   completion would be a spoiler leak besides.
    /// Internal rather than private because the play-test seam asks the same
    /// question: `resolve(_:)` reports *which entity answers to this noun,
    /// standing here*, and it has to be the parser's own scope it asks. A
    /// second walk built beside this one would agree on the day it was written
    /// and drift afterwards, which is the failure the tool exists to catch.
    ///
    /// - Returns: what the parser may resolve a noun phrase against this turn.
    func currentScope(orders: Bool = true) -> Scope {
        let here = state.playerLocation
        let index = state.containment()
        let visible = Visibility.visibleItems(
            at: here, definition: definition, state: state, index: index)
        guard orders else {
            return Scope(
                visibleItems: visible,
                visibleActors: visible.intersection(definition.castIDs),
                pronounIt: state.pronounIt)
        }
        // Walked once and handed to both reaches: FOLLOW's quarry and an
        // order-taker's name ask the same question about distance.
        let nextDoor = Visibility.adjacentRooms(to: here, definition: definition, state: state)
        let elsewhere = Visibility.actorsElsewhere(
            excluding: here, nextDoor: nextDoor, definition: definition, state: state)
        let orderTakers = orderTakerScopes(index: index, nextDoor: nextDoor)
        return Scope(
            visibleItems: visible,
            visibleActors: visible.intersection(definition.castIDs),
            // Not visibility: the naming reach of FOLLOW alone, and bounded by
            // acquaintance or by being next door.
            distantActors: elsewhere.withinReach,
            elsewhereActors: elsewhere.all,
            pronounIt: state.pronounIt,
            orderTakers: orderTakers,
            allOrderTakers: orderTakersStandingSomewhere())
    }

    /// What each order-taking actor could name from where *it* is standing —
    /// the set `robot, push the button` is read against. Built here because
    /// the parser has no world to walk, and skipped outright by the games
    /// (nearly all of them) that never declared an order-taker.
    ///
    /// An actor who is in nobody's room — held, contained, `vanish()`ed — gets
    /// no entry, and so falls back to the stock refusal: there is nowhere for
    /// the order to be carried out.
    ///
    /// Neither does one the player could not make hear them. The keys are the
    /// *addressable* order-takers — here, or within
    /// ``Visibility/isNameable(_:standingIn:nextDoor:state:)`` — for the reason
    /// `Visibility.actorsElsewhere` gives at length: shouting at somebody two
    /// hundred rooms away, whom the story has not introduced, is not a
    /// widening any game asked for. A game narrows this further with a rule of
    /// its own, and can never widen it. (#332)
    ///
    /// The narrowing pays for itself: an order-taker out of reach also skips
    /// the scope walk, which is a whole visibility descent per robot per parse.
    /// ``orderTakersStandingSomewhere()`` is the cheap set that keeps the
    /// parser able to tell "nobody" from "one of several".
    private func orderTakerScopes(
        index: ContainmentIndex, nextDoor: Set<EntityID>
    ) -> [EntityID: Set<EntityID>] {
        guard !definition.orderTakerIDs.isEmpty else { return [:] }
        let here = state.playerLocation
        var scopes: [EntityID: Set<EntityID>] = [:]
        for id in definition.orderTakerIDs {
            guard let there = Visibility.standing(id, in: state) else { continue }
            guard
                there == here
                    || Visibility.isNameable(id, standingIn: there, nextDoor: nextDoor, state: state)
            else { continue }
            scopes[id] = Visibility.visibleItems(
                for: id, at: there, definition: definition, state: state, index: index)
        }
        return scopes
    }

    /// Every order-taker standing in a room at all, in reach or not — no scope
    /// walk, just the placements.
    ///
    /// It is what stops the reach turning a description into a name: two
    /// order-takers answering to `robot`, one met and one not, must still be
    /// two, or narrowing the reach would quietly pick one of them. Same
    /// argument as ``Visibility/ActorsElsewhere``'s `all`. (#332)
    private func orderTakersStandingSomewhere() -> Set<EntityID> {
        definition.orderTakerIDs.filter { Visibility.standing($0, in: state) != nil }
    }

    /// The one person in the room, or nil for nobody and nil for a crowd.
    /// Only a bare greeting uses this: "hello" in a room with one other
    /// person in it can only have meant them.
    ///
    /// - Returns: the sole visible actor, if there is exactly one.
    private func soleVisibleActor() -> EntityID? {
        let actors = visibleActorsHere()
        return actors.count == 1 ? actors.first : nil
    }

    /// The cast the player can currently see. Darkness gates it, because
    /// `visibleItems` does: you do not meet somebody in an unlit room.
    ///
    /// - Returns: the actors visible from where the player is standing.
    private func visibleActorsHere() -> Set<EntityID> {
        Visibility.visibleItems(
            at: state.playerLocation, definition: definition, state: state,
            index: state.containment()
        ).intersection(definition.castIDs)
    }

    /// Where this game's persistent command history lives — the history
    /// sidecar in the saves directory. `SaveStore` owns the path convention.
    var historyFileURL: URL {
        SaveStore.historyURL(in: saveDirectory)
    }

    /// The words Tab-completion can offer for the next input line: every verb,
    /// the nouns and adjectives of the items currently in scope, the movement
    /// directions, and the save slots on disk. Recomputed each turn because
    /// scope changes as the player moves — and because, when the engine is
    /// waiting for a save/restore filename, the whole line completes against
    /// save names instead of the command grammar.
    ///
    /// - Returns: the completion candidates for the current state.
    func completionCandidates() -> CompletionCandidates {
        let context: CompletionCandidates.Context
        switch pendingPrompt {
        case .saveFilename, .restoreFilename:
            context = .filename  // the next line names a save, not a command
        default:
            context = .command
        }

        let scope = currentScope(orders: false)
        var nouns: Set<String> = []
        for id in scope.visibleItems {
            guard let lexicon = definition.vocabulary.itemLexicons[id] else { continue }
            nouns.formUnion(lexicon.nouns)
            nouns.formUnion(lexicon.adjectives)
        }
        return CompletionCandidates(
            context: context,
            verbs: definition.vocabulary.sortedVerbWords,
            nouns: nouns.sorted(),
            directions: definition.vocabulary.sortedDirectionWords,
            saveNames: SaveStore.existingSaveNames(in: saveDirectory))
    }

    func commit(_ frame: TurnFrame) -> TurnResult {
        let scratch = frame.retire()
        state = scratch.state
        // Whoever the player can see has now been met. This is the only place
        // it is sampled, and it is enough: `commit` is the single exit of
        // every turn, so `begin()` records the opening room before the first
        // command is typed and nothing changes state between one turn's close
        // and the next turn's parse. (#332)
        state.metActors.formUnion(visibleActorsHere())
        // Merged rather than adopted, and merged *here* for the reason the line
        // above is here: `commit` is the single exit of every turn, so a room
        // the turn stood the player in cannot be lost by a path that forgot to
        // hand its frame over. Appended rather than unioned into a set because
        // first-arrival order is the order a coverage report reads them back
        // in. See `roomsOccupied`.
        for room in scratch.roomsOccupied where !roomsOccupied.contains(room) {
            roomsOccupied.append(room)
        }
        // Adopted, never merged — and taking a nil *is* the invalidation.
        // The opening, UNDO, RESTART, RESTORE and every meta or unhandled
        // command arrive here with a frame that never ran the capture, so
        // they correctly send the footer back to live state. None of them
        // moved the counter, so live state is the world their words were
        // written in.
        statusFieldState = scratch.statusFieldState
        return TurnResult(
            output: scratch.output.joined(separator: "\n\n"),
            isFinished: scratch.state.status.isFinal,
            status: statusLine())
    }

    private func displayName(of id: EntityID) -> String {
        definition.vocabulary.displayNames[id] ?? id.raw
    }

    private func statusLine() -> StatusLine {
        StatusLine(
            locationID: state.playerLocation,
            locationName: definition.locations[state.playerLocation]?.name
                ?? state.playerLocation.raw,
            score: state.score,
            moves: state.moves)
    }
}
