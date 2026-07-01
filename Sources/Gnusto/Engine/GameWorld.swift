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
                if !intent.isMeta {
                    let here = frame.with { $0.state.playerLocation }
                    try run(rules.worldBefore, matching: intent)
                    try run(rules.locationBeforeEachTurn[here] ?? [], matching: intent)
                    try run(rules.locationBefore[here] ?? [], matching: intent)
                    if let indirect = command.indirectObject {
                        try run(rules.itemBefore[indirect.id] ?? [], matching: intent)
                    }
                    if let direct = command.directObject {
                        try run(rules.itemBefore[direct.id] ?? [], matching: intent)
                    }
                }

                // Stage 4: the default action.
                try DefaultActions.run(command, frame: frame)

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
    /// the room's contents (one surface/container level deep) only with light.
    private func currentScope() -> Scope {
        var reachable: Set<EntityID> = []
        let here = state.playerLocation

        for (id, placement) in state.placements where placement == .heldBy(.player) {
            reachable.insert(id)
        }

        if !state.isDark(at: here) {
            for (id, placement) in state.placements {
                switch placement {
                case .room(here):
                    reachable.insert(id)
                case .on(let surface) where state.placements[surface] == .room(here):
                    reachable.insert(id)
                case .inside(let container) where state.placements[container] == .room(here):
                    reachable.insert(id)
                default:
                    break
                }
            }
        }

        return Scope(reachableItems: reachable)
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
