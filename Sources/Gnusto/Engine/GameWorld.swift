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
    // Seam: a `pendingQuery` field will later carry quit-confirmation and
    // disambiguation round-trips.
}

/// The game world: owns all state, serializes all mutation, and runs the
/// turn pipeline. The single `await` in a game sits between the REPL and
/// this actor.
public actor GameWorld {
    let definition: GameDefinition
    var state: WorldState
    private let parser: StandardParser

    /// Builds the world from a game definition, validating it up front.
    public init(game: some Game) throws {
        let (definition, state) = try Bootstrap.build(game)
        self.definition = definition
        self.state = state
        self.parser = StandardParser(
            vocabulary: definition.vocabulary,
            syntaxRules: definition.syntaxRules)
    }

    /// The opening of the game: intro, banner, and the first look around.
    public func begin() -> TurnResult {
        let frame = TurnFrame(definition: definition, state: state)
        Ctx.$frame.withValue(frame) {
            frame.say(definition.intro)
            frame.say(Messages.banner(title: definition.title, tagline: definition.tagline))
            RoomDescriber.describeCurrentLocation(mode: .entry, frame: frame)
        }
        return commit(frame)
    }

    /// Parses and performs one line of player input. Parse errors are free:
    /// no rules run and the turn counter doesn't advance.
    public func perform(_ input: String) -> TurnResult {
        switch parser.parse(input, scope: currentScope()) {
        case .failure(let error):
            return TurnResult(
                output: error.playerMessage,
                isFinished: state.status != .playing,
                status: statusLine())
        case .success(let parsed):
            // Naming a thing binds "it" — even if the action then refuses.
            if let direct = parsed.directObject {
                state.pronounIt = direct
            }
            return runTurn(command(from: parsed))
        }
    }

    // MARK: - The turn pipeline

    private func runTurn(_ command: Command) -> TurnResult {
        let frame = TurnFrame(definition: definition, state: state, command: command)
        let intent = command.intent
        let rules = definition.rules

        Ctx.$frame.withValue(frame) {
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
                    try runBefore(rules.worldBefore, matching: intent, frame: frame)
                    try runBefore(rules.locationBeforeEachTurn[here] ?? [], matching: intent, frame: frame)
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

            // Stage 6: world time passes even on refused turns — but not for
            // meta intents, and not once the game has ended.
            if !intent.isMeta {
                if frame.with({ $0.state.status }) == .playing {
                    let here = frame.with { $0.state.playerLocation }
                    runCatching(rules.locationAfterEachTurn[here] ?? [], matching: intent, frame: frame)
                    runCatching(rules.worldAfter, matching: intent, frame: frame)
                }
                frame.with { $0.state.moves += 1 }
            }

            // End-of-game epilogue: one place reports the final score,
            // whether the game was won, lost, or quit.
            if frame.with({ $0.state.status }) != .playing {
                DefaultActions.score(frame)
            }
        }

        return commit(frame)
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

    private func handle(_ interrupt: TurnInterrupt, frame: TurnFrame) {
        switch interrupt {
        case .refused(let message), .replied(let message):
            frame.say(message)
        case .gameOver(let won):
            frame.with { $0.state.status = won ? .won : .lost }
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
            isFinished: scratch.state.status != .playing,
            status: statusLine())
    }

    private func statusLine() -> StatusLine {
        StatusLine(
            locationName: definition.locations[state.playerLocation]?.name
                ?? state.playerLocation.raw,
            score: state.score,
            moves: state.moves)
    }
}
