import Foundation

/// The status line a handler can display: location, score, and turn count.
public struct StatusLine: Sendable {
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
    private let parser: StandardParser
    /// An open clarifying question ("Which do you mean…?", "What do you want
    /// to take?"): the next input line is first tried as its answer,
    /// re-parsed as `prefix + answer + suffix`.
    var pendingClarification: (prefix: [String], suffix: [String])?
    /// The pristine post-bootstrap state, seed included — what RESTART
    /// rewinds to. Actor state, never part of `WorldState` itself.
    private let initialState: WorldState
    /// Where bare save names (`save autumn`) resolve to, and the directory the
    /// restore prompt lists. Explicit paths the player types bypass it. See
    /// `SaveStore`.
    let saveDirectory: URL
    /// The one-level UNDO snapshot: the state as it stood before the last
    /// turn that actually ran stages. Kept on the actor so history never
    /// leaks into save files.
    var undoSnapshot: WorldState?
    /// The open engine prompt, if any — a save/restore filename or the
    /// post-death RESTART / RESTORE / UNDO / QUIT choice. While one is armed
    /// the next input line *is* its answer; see `PendingPrompt` and `answer`
    /// in `GameWorld+Prompts.swift`.
    var pendingPrompt: PendingPrompt?

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
    }

    /// The opening of the game: intro, banner, and the first look around.
    ///
    /// - Returns: the opening turn's output and status.
    public func begin() -> TurnResult {
        let frame = TurnFrame(definition: definition, state: state)
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
        if let prompt = pendingPrompt {
            pendingPrompt = nil
            return answer(prompt, with: input.trimmingCharacters(in: .whitespaces))
        }

        let scope = currentScope()
        let tokens = parser.tokenize(input)

        if let pending = pendingClarification {
            pendingClarification = nil
            let augmented = pending.prefix + tokens + pending.suffix
            switch parser.parse(tokens: augmented, rawInput: input, scope: scope) {
            case .success(let parsed):
                return armDeathPromptIfNeeded(run(parsed))
            case .failure(let error):
                // Still ambiguous ("brass" matched two): ask the narrower
                // question. Anything else means the line wasn't an answer —
                // fall through and parse it as a fresh command.
                if let context = error.clarification {
                    pendingClarification = context
                    return freeReply(error.playerMessage(definition.text))
                }
            }
        }

        switch parser.parse(tokens: tokens, rawInput: input, scope: scope) {
        case .failure(let error):
            pendingClarification = error.clarification
            return freeReply(error.playerMessage(definition.text))
        case .success(let parsed):
            return armDeathPromptIfNeeded(run(parsed))
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
        // what the *player* can see and runs stage 4 once per object, and
        // stage 4 is exactly what an order never reaches.
        guard parsed.actor == nil, Self.multiObjectIntents.contains(intent) else {
            return freeReply(definition.text.multipleNotAllowedWith(parsed.verbPhrase))
        }

        /// What the player can see and what they hold — the two sets a keyword
        /// expands against. Built on demand, because a list the player wrote
        /// out is already resolved and a room sweep would be for nothing.
        func sets() -> (visible: Set<EntityID>, held: Set<EntityID>) {
            let index = state.containment()
            return (
                Visibility.visibleItems(
                    at: state.playerLocation, definition: definition, state: state, index: index),
                Set(index.held[.player] ?? [])
            )
        }

        var objects: [EntityID]
        switch multiple {
        case .all:
            let (visible, held) = sets()
            objects = inDisplayOrder(
                intent == .take
                    ? visible.filter { definition.items[$0]?.isTakable == true && !held.contains($0) }
                    : Array(held))
        case .them:
            guard !state.pronounThem.isEmpty else {
                return freeReply(definition.text.noReferent("them"))
            }
            let visible = sets().visible
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
        if intent == .putIn || intent == .putOn, let indirect = parsed.indirectObject {
            objects.removeAll { $0 == indirect }
        }
        guard !objects.isEmpty else {
            return freeReply(
                intent == .take ? definition.text.nothingToTakeHere() : definition.text.notCarryingAnything())
        }

        // Every early return above was a free reply; from here the turn
        // really runs, so it becomes the thing UNDO reverses.
        undoSnapshot = snapshot

        state.pronounThem = objects

        let indirectItem = parsed.indirectObject.flatMap { definition.registry.items[$0] }
        let frame = TurnFrame(definition: definition, state: state)
        Ctx.$frame.withValue(frame) {
            do {
                try runUpkeepBefore(intent, frame: frame)
                for id in objects {
                    guard frame.with({ $0.state.status }) == .playing else { break }
                    guard let item = definition.registry.items[id] else { continue }
                    let command = Command(
                        intent: intent,
                        directObject: item,
                        indirectObject: indirectItem,
                        preposition: parsed.preposition,
                        topic: parsed.topic.map(Topic.init),
                        verbPhrase: parsed.verbPhrase,
                        rawInput: parsed.rawInput)
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
        let frame = TurnFrame(definition: definition, state: state)
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
        TurnResult(
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
                runCatching(event, frame: frame)
            }
        }
        for name in frame.with({ $0.state.activeDaemons.sorted() }) {
            guard frame.with({ $0.state.status }) == .playing else { return }
            guard let event = definition.timers[name],
                frame.with({ $0.state.activeDaemons.contains(name) })
            else { continue }
            runCatching(event, frame: frame)
        }
    }

    private func runCatching(_ event: TimedEvent, frame: TurnFrame) {
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

    private func command(from parsed: ParsedCommand) -> Command {
        Command(
            intent: parsed.intent,
            directObject: parsed.directObject.flatMap { definition.registry.items[$0] },
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
    /// - Parameter orders: whether to walk each order-taking actor's own scope
    ///   too. Only a parse needs them; Tab completion reads `visibleItems`
    ///   alone, and would be paying for a walk per robot on every keystroke.
    /// - Returns: what the parser may resolve a noun phrase against this turn.
    private func currentScope(orders: Bool = true) -> Scope {
        let here = state.playerLocation
        let index = state.containment()
        let visible = Visibility.visibleItems(
            at: here, definition: definition, state: state, index: index)
        return Scope(
            visibleItems: visible,
            visibleActors: visible.intersection(definition.castIDs),
            // Not visibility: the naming reach of FOLLOW alone. Note
            // `completionCandidates()` below deliberately stays on
            // `visibleItems`, since offering an offstage actor's nouns to Tab
            // completion would be a spoiler leak.
            distantActors: Visibility.actorsElsewhere(
                excluding: here, definition: definition, state: state),
            pronounIt: state.pronounIt,
            orderTakers: orders ? orderTakerScopes(index: index) : [:])
    }

    /// What each order-taking actor could name from where *it* is standing —
    /// the set `robot, push the button` is read against. Built here because
    /// the parser has no world to walk, and skipped outright by the games
    /// (nearly all of them) that never declared an order-taker.
    ///
    /// An actor who is in nobody's room — held, contained, `vanish()`ed — gets
    /// no entry, and so falls back to the stock refusal: there is nowhere for
    /// the order to be carried out.
    private func orderTakerScopes(index: ContainmentIndex) -> [EntityID: Set<EntityID>] {
        guard !definition.orderTakerIDs.isEmpty else { return [:] }
        var scopes: [EntityID: Set<EntityID>] = [:]
        for id in definition.orderTakerIDs {
            guard let there = Visibility.standing(id, in: state) else { continue }
            scopes[id] = Visibility.visibleItems(
                for: id, at: there, definition: definition, state: state, index: index)
        }
        return scopes
    }

    /// The one person in the room, or nil for nobody and nil for a crowd.
    /// Only a bare greeting uses this: "hello" in a room with one other
    /// person in it can only have meant them.
    ///
    /// - Returns: the sole visible actor, if there is exactly one.
    private func soleVisibleActor() -> EntityID? {
        let actors = Visibility.visibleItems(
            at: state.playerLocation, definition: definition, state: state,
            index: state.containment()
        ).intersection(definition.castIDs)
        return actors.count == 1 ? actors.first : nil
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
            locationName: definition.locations[state.playerLocation]?.name
                ?? state.playerLocation.raw,
            score: state.score,
            moves: state.moves)
    }
}
