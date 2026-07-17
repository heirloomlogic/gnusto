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
    private var pendingClarification: (prefix: [String], suffix: [String])?
    /// The pristine post-bootstrap state, seed included — what RESTART
    /// rewinds to. Actor state, never part of `WorldState` itself.
    private let initialState: WorldState
    /// Where bare save names (`save autumn`) resolve to, and the directory the
    /// restore prompt lists. Explicit paths the player types bypass it. See
    /// `SaveStore`.
    private let saveDirectory: URL
    /// The one-level UNDO snapshot: the state as it stood before the last
    /// turn that actually ran stages. Kept on the actor so history never
    /// leaks into save files.
    private var undoSnapshot: WorldState?
    /// An open engine prompt. Unlike a clarification, the next input line
    /// *is* the answer — raw, untokenized (filenames carry dots and slashes
    /// the tokenizer would mangle) — and normal parsing doesn't happen.
    private enum PendingPrompt {
        case saveFilename
        /// `returnToDeathPrompt` re-arms the death prompt after a failed or
        /// cancelled restore that was chosen from it.
        case restoreFilename(returnToDeathPrompt: Bool)
        /// The post-death RESTART / RESTORE / UNDO / QUIT choice. While it
        /// is armed, every input line is an answer — normal commands are
        /// unreachable until the player picks an exit.
        case deathChoice
    }
    private var pendingPrompt: PendingPrompt?

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
        let (definition, state) = try Bootstrap.build(game)
        self.definition = definition
        self.state = state
        self.state.rngState = seed
        // Captured after seeding, so RESTART replays the identical game,
        // randomness included.
        self.initialState = self.state
        self.parser = StandardParser(
            vocabulary: definition.vocabulary,
            syntaxRules: definition.syntaxRules)
        self.saveDirectory = saveDirectory
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
            return freeReply(definition.text.savePrompt)
        case .restore:
            pendingPrompt = .restoreFilename(returnToDeathPrompt: false)
            return freeReply(restorePromptText())
        default: break
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
        if !command.intent.isMeta {
            undoSnapshot = snapshot
        }
        let frame = TurnFrame(definition: definition, state: state, command: command)
        Ctx.$frame.withValue(frame) {
            performStages(command, frame: frame, upkeep: true)
            finishTurn(intent: command.intent, frame: frame)
        }
        return commit(frame)
    }

    /// The intents that accept "all"/"them" in the direct slot. Everything
    /// else refuses multiple objects up front.
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
        guard Self.multiObjectIntents.contains(intent) else {
            return freeReply(definition.text.multipleNotAllowedWith(parsed.verbPhrase))
        }

        let visible = Visibility.visibleItems(
            at: state.playerLocation, definition: definition, state: state)
        let held = Set(
            state.placements.filter { $0.value == .heldBy(.player) }.keys)

        var objects: [EntityID]
        switch multiple {
        case .all:
            objects =
                intent == .take
                ? visible.filter { definition.items[$0]?.isTakable == true && !held.contains($0) }
                : Array(held)
        case .them:
            guard !state.pronounThem.isEmpty else {
                return freeReply(definition.text.noReferent("them"))
            }
            objects = state.pronounThem.filter { visible.contains($0) }
            guard !objects.isEmpty else {
                return freeReply(definition.text.cantSeeAnySuchThing)
            }
        }
        if intent == .putIn || intent == .putOn, let indirect = parsed.indirectObject {
            objects.removeAll { $0 == indirect }
        }
        guard !objects.isEmpty else {
            return freeReply(
                intent == .take ? definition.text.nothingToTakeHere : definition.text.notCarryingAnything)
        }

        // Every early return above was a free reply; from here the turn
        // really runs, so it becomes the thing UNDO reverses.
        undoSnapshot = snapshot

        // Stable, player-legible order: by display name, then ID.
        objects.sort { lhs, rhs in
            let (lhsName, rhsName) = (displayName(of: lhs), displayName(of: rhs))
            return lhsName == rhsName ? lhs < rhs : lhsName < rhsName
        }
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
                        verbPhrase: parsed.verbPhrase,
                        rawInput: parsed.rawInput)
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
    private func performUndo() -> TurnResult {
        guard let snapshot = undoSnapshot else {
            return freeReply(definition.text.cantUndo)
        }
        state = snapshot
        undoSnapshot = nil
        pendingClarification = nil
        let frame = TurnFrame(definition: definition, state: state)
        Ctx.$frame.withValue(frame) {
            frame.say(definition.text.undone)
            RoomDescriber.describeCurrentLocation(mode: .entry, frame: frame)
        }
        return commit(frame)
    }

    /// Rewinds to the pristine post-bootstrap opening — seed included, so
    /// the restarted game replays identically — and plays the opening again.
    private func performRestart() -> TurnResult {
        state = initialState
        undoSnapshot = nil
        pendingClarification = nil
        return begin()
    }

    /// The restore prompt, with the names of the saves already on disk appended
    /// when there are any — so a player doesn't have to remember what they
    /// called them. Explicit-path saves elsewhere aren't listed, only the
    /// slots in the saves directory.
    private func restorePromptText() -> String {
        let names = SaveStore.existingSaveNames(in: saveDirectory)
        guard !names.isEmpty else { return definition.text.restorePrompt }
        return "\(definition.text.restorePrompt) (saved: \(names.joined(separator: ", ")))"
    }

    /// Consumes the line that answers an open engine prompt.
    private func answer(_ prompt: PendingPrompt, with line: String) -> TurnResult {
        switch prompt {
        case .saveFilename:
            guard !line.isEmpty else {
                return freeReply(definition.text.cancelled)
            }
            do {
                let url = try SaveStore.resolveForWrite(line, in: saveDirectory)
                try SaveFile.write(state, title: definition.title, to: url)
                return freeReply(definition.text.saved)
            } catch {
                return freeReply(definition.text.saveFailed)
            }

        case .restoreFilename(let returnToDeathPrompt):
            guard !line.isEmpty else {
                return restoreFailed(definition.text.cancelled, returnToDeathPrompt)
            }
            do {
                let url = SaveStore.resolve(line, in: saveDirectory)
                let restored = try SaveFile.read(from: url, expecting: definition.title)
                return performRestore(restored)
            } catch {
                switch error {
                case .unreadable:
                    return restoreFailed(definition.text.restoreFailed, returnToDeathPrompt)
                case .wrongGame:
                    return restoreFailed(definition.text.wrongGameSave, returnToDeathPrompt)
                }
            }

        case .deathChoice:
            switch line.lowercased() {
            case "restart":
                return performRestart()
            case "restore":
                pendingPrompt = .restoreFilename(returnToDeathPrompt: true)
                return freeReply(restorePromptText())
            case "undo":
                guard undoSnapshot != nil else {
                    pendingPrompt = .deathChoice
                    return freeReply(
                        "\(definition.text.cantUndo)\n\n\(definition.text.deathPrompt)")
                }
                // The snapshot predates the fatal turn — this revives.
                return performUndo()
            case "quit", "q":
                // The score already printed at death; just stop reading.
                state.status = .quit
                return freeReply("")
            default:
                pendingPrompt = .deathChoice
                return freeReply(definition.text.deathChoiceUnrecognized)
            }
        }
    }

    /// Swaps a validated save's state in and shows the player where they are.
    private func performRestore(_ restored: WorldState) -> TurnResult {
        var next = restored
        // Re-bind the saved timer schedule to the declared bodies by name;
        // names this build doesn't declare are dropped (see `SaveFile`).
        next.activeFuses = next.activeFuses.filter { definition.timers[$0.key] != nil }
        next.activeDaemons = next.activeDaemons.filter { definition.timers[$0] != nil }
        state = next
        undoSnapshot = nil
        pendingClarification = nil
        let frame = TurnFrame(definition: definition, state: state)
        Ctx.$frame.withValue(frame) {
            frame.say(definition.text.restored)
            RoomDescriber.describeCurrentLocation(mode: .entry, frame: frame)
        }
        return commit(frame)
    }

    /// A failed or cancelled restore — re-arming the death prompt when the
    /// attempt was made from it (there is no world to go back to otherwise).
    private func restoreFailed(_ message: String, _ returnToDeathPrompt: Bool) -> TurnResult {
        guard returnToDeathPrompt else {
            return freeReply(message)
        }
        pendingPrompt = .deathChoice
        return freeReply("\(message)\n\n\(definition.text.deathPrompt)")
    }

    /// A parse-error-style response: message only, no rules, no turn.
    private func freeReply(_ message: String) -> TurnResult {
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

        do {
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
                let here = frame.with { $0.state.playerLocation }
                let worldBefore =
                    upkeep
                    ? rules.worldBefore
                    : rules.worldBefore.filter { $0.phase == .before }
                try runBefore(worldBefore, matching: intent, frame: frame)
                if upkeep {
                    try runBefore(rules.locationBeforeEachTurn[here] ?? [], matching: intent, frame: frame)
                }
                try runBefore(rules.locationBefore[here] ?? [], matching: intent, frame: frame)
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
                let here = frame.with { $0.state.playerLocation }
                try run(rules.locationAfter[here] ?? [], matching: intent)
            }
        } catch let interrupt as TurnInterrupt {
            handle(interrupt, frame: frame)
        } catch {
            frame.say("\(error)")
        }
    }

    /// Stage 6 and the epilogue: world time passes even on refused turns —
    /// but not for meta intents, and not once the game has ended. Runs once
    /// per typed command, however many objects it covered.
    private func finishTurn(intent: Intent, frame: TurnFrame) {
        let rules = definition.rules
        if !intent.isMeta {
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
            frame.say(frame.definition.text.deathPrompt)
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
        case .refused(let message), .replied(let message):
            // An empty message ends the turn without adding a line — for
            // rule bodies that have already said everything with `say`.
            if !message.isEmpty {
                frame.say(message)
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
                frame.say(frame.definition.text.deathBanner)
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
            verbPhrase: parsed.verbPhrase,
            rawInput: parsed.rawInput)
    }

    /// What the player can currently refer to: carried and worn items always;
    /// with light, the room's contents descended through surfaces and visible
    /// containers. Parser scope keys off *visible* items — you can name what you
    /// can see, even through a shut glass jar; the actions enforce
    /// reachability.
    private func currentScope() -> Scope {
        let here = state.playerLocation
        let visible = Visibility.visibleItems(at: here, definition: definition, state: state)
        return Scope(visibleItems: visible, pronounIt: state.pronounIt)
    }

    private func commit(_ frame: TurnFrame) -> TurnResult {
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
