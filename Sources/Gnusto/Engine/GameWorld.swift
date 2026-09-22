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
    /// The line the parser last refused for one word it had never heard of,
    /// and where in that line the word stood — what `oops <word>` rewrites.
    ///
    /// Actor state beside `pendingClarification` rather than world state
    /// beside `pronounIt`, and for the same reason that one is: it belongs to
    /// the *line just typed* and is spent by the next one, whatever that line
    /// turns out to be. A typo that never became a turn is not something a
    /// save file has anything to say about, and a restored game correcting the
    /// word from a session three weeks ago would be reading a line nobody is
    /// still looking at.
    var pendingCorrection: Correction?

    /// A line the parser refused for one word it had never heard of, and where
    /// in it that word stood — everything `oops <word>` needs to write the line
    /// again. Named rather than left an anonymous tuple because it travels
    /// through three signatures.
    typealias Correction = (tokens: [String], index: Int)
    /// The pristine post-bootstrap state, seed included — what RESTART
    /// rewinds to. Actor state, never part of `WorldState` itself.
    let initialState: WorldState
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

    /// How much of a room to print on the way in — the player's VERBOSE /
    /// BRIEF / SUPERBRIEF preference.
    ///
    /// Actor state, never serialized, for the reason `firedTimers` and
    /// `roomsOccupied` above state: it is a fact about *this run of the
    /// program*, not about the world. ``DescriptionMode`` says what that
    /// placement buys and why nothing else in the engine writes the
    /// preference.
    var descriptionMode: DescriptionMode = .brief

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
        let frame = turnFrame(lookCommand)
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
        // OOPS rewrites the line just typed and nothing older, so every line
        // spends the context — a prompt answer included, since that is not a
        // command at all. Taken and cleared here, once, rather than in each of
        // the branches below; the branch that records a *fresh* one records it
        // after, and the bare OOPS that only asks which word puts this one
        // back.
        let correction = pendingCorrection
        pendingCorrection = nil

        if let prompt = pendingPrompt {
            pendingPrompt = nil
            let result = answer(prompt, with: input.trimmingCharacters(in: .whitespaces))
            // The line was an answer, not a command: no verb was read from it,
            // so every parse field stays empty and `answeredPrompt` says why.
            return (result, TurnAudit(answeredPrompt: true))
        }

        // One walk of the world per line, not per parse: nothing between the
        // readings below mutates state, and AGAIN and OOPS each hand a second
        // line to the same parser.
        let scope = currentScope()
        let tokens = parser.tokenize(input)

        // The line a later OOPS should mend, when that is not the line as
        // typed. A line offered in answer to a question stands for the whole
        // spliced sentence, so a typo in it is mended there: the answer alone
        // — `wooden` — is not a sentence the parser could ever run.
        var mendable: [String]?

        if let pending = pendingClarification {
            pendingClarification = nil
            let augmented = pending.prefix + tokens + pending.suffix
            switch parser.parse(tokens: augmented, rawInput: input, scope: scope) {
            case .success(let parsed):
                // The *answer's* unknown words, not the spliced line's: the
                // rest of the line was reported when it was typed.
                return performParsed(
                    parsed, tokens: augmented, scope: scope, correction: correction,
                    unknown: unknownWords(in: tokens))
            case .failure(let error):
                // Still ambiguous ("brass" matched two): ask the narrower
                // question. Anything else means the line wasn't an answer —
                // fall through and parse it as a fresh command.
                if let context = error.clarification {
                    pendingClarification = context
                    let result = freeReply(error.playerMessage(definition.text))
                    return (result, TurnAudit(unknownWords: unknownWords(in: tokens)))
                }
                // Only a line the player offered *as an answer* is mended in
                // the spliced sentence. A line that changes the subject is
                // about to be read as a fresh command, and a fresh command is
                // mended as itself.
                if readsAsAnswer(tokens) { mendable = augmented }
            }
        }

        return performLine(
            tokens: tokens, rawInput: input, scope: scope, correction: correction,
            mendable: mendable)
    }

    /// Whether a line typed while a clarifying question was open reads as an
    /// answer to it rather than as the player changing the subject.
    ///
    /// A clarifying question asks which thing was meant, so its answer is a
    /// noun phrase: `wooden`, `the brass one`. A line that opens with a verb or
    /// a direction is a sentence in its own right, and the engine is about to
    /// read it as one — which decides, in turn, the line a later OOPS mends.
    /// Both readings fail the same way when the line holds a word the game has
    /// never heard of (`woden`, `frotz`), so the shape of the line is what
    /// tells them apart.
    ///
    /// - Parameter tokens: the line the player just typed, tokenized.
    /// - Returns: whether it could only have been an answer.
    private func readsAsAnswer(_ tokens: [String]) -> Bool {
        guard let first = tokens.first else { return false }
        return !definition.vocabulary.verbWords.contains(first)
            && definition.vocabulary.directions[first] == nil
    }

    /// Every token of a line the game has never heard of.
    ///
    /// Asked of the vocabulary rather than inferred from the reply: the
    /// player-facing message names at most one word and only on some of the
    /// failure paths, while this is every token the game has never heard of,
    /// available even on the lines that parsed.
    ///
    /// - Parameter tokens: the line, as the parser saw it.
    /// - Returns: the tokens outside the game's whole vocabulary.
    private func unknownWords(in tokens: [String]) -> [String] {
        tokens.filter { !definition.vocabulary.knows($0) }
    }

    /// One token list parsed and run — the tail of ``performAudited(_:)``, and
    /// the door AGAIN and OOPS come back through carrying a different line.
    ///
    /// - Parameters:
    ///   - tokens: the line, tokenized, filler already dropped.
    ///   - rawInput: the line as it will ride on the command.
    ///   - scope: what the player can name, walked once for the whole line.
    ///   - correction: the OOPS context this line may spend, if it is an OOPS.
    ///   - mendable: the line a later OOPS should mend, when that is not this
    ///     one — an answer to a question is mended in its spliced sentence.
    /// - Returns: the turn's output and status, and the parse record.
    private func performLine(
        tokens: [String], rawInput: String, scope: Scope, correction: Correction? = nil,
        mendable: [String]? = nil
    ) -> (result: TurnResult, audit: TurnAudit) {
        let unknown = unknownWords(in: tokens)
        switch parser.parse(tokens: tokens, rawInput: rawInput, scope: scope) {
        case .failure(let error):
            // A word the game has never heard of is the one failure OOPS can
            // mend, so that line — and where in it the word stood — is kept
            // for exactly one turn. The word can only stand in the part the
            // player just typed, so looking for it in the spliced line finds
            // the same one.
            let line = mendable ?? tokens
            if case .unknownWord(let word) = error, let index = line.firstIndex(of: word) {
                pendingCorrection = (tokens: line, index: index)
            }
            pendingClarification = error.clarification
            let result = freeReply(error.playerMessage(definition.text))
            return (result, TurnAudit(unknownWords: unknown))
        case .success(let parsed):
            return performParsed(
                parsed, tokens: tokens, scope: scope, correction: correction, unknown: unknown)
        }
    }

    /// Dispatches a parsed line: the two verbs that hand a *different* line
    /// back to the parser, and everything else, which is a turn.
    private func performParsed(
        _ parsed: ParsedCommand, tokens: [String], scope: Scope,
        correction: Correction?, unknown: [String]
    ) -> (result: TurnResult, audit: TurnAudit) {
        switch parsed.intent {
        case .again, .oops:
            switch rewritten(parsed, correction: correction) {
            case .line(let tokens):
                return performLine(
                    tokens: tokens, rawInput: tokens.joined(separator: " "), scope: scope)
            case .refusal(let line):
                return (freeReply(line), TurnAudit(unknownWords: unknown))
            }
        default:
            let result = armDeathPromptIfNeeded(run(parsed, tokens: tokens))
            return (result, TurnAudit(parsed, unknownWords: unknown))
        }
    }

    /// What AGAIN or OOPS makes of the line: another line to read, or the
    /// reason there is not one.
    private enum Rewrite {
        case line([String])
        case refusal(String)
    }

    /// AGAIN: the last command the player ran, read again against the room as
    /// it stands now — so `take it` repeated is about whatever "it" means this
    /// turn, and a command whose object has since left the room is refused in
    /// the ordinary words rather than replayed into a world that has moved on.
    ///
    /// It costs whatever the repeated command costs, because it *is* that
    /// command: a repeated LOOK is free and a repeated TAKE is a move.
    ///
    /// Bounded without a counter: ``WorldState/lastCommand`` is written only
    /// for a command that is neither engine-level nor meta, so the line it
    /// hands back can never be another AGAIN.
    private func performAgain() -> Rewrite {
        let tokens = state.lastCommand
        guard !tokens.isEmpty else { return .refusal(definition.text.nothingToRepeat()) }
        return .line(tokens)
    }

    /// OOPS: the word the parser last refused, replaced by the one the player
    /// meant, and the line it stood in tried again.
    ///
    /// The corrected line is an ordinary line from there — free if it still
    /// doesn't parse, a full turn if it does. Both ways out of it say what
    /// went wrong in their own words: there is a difference between having no
    /// misheard word to mend and offering no word to mend it with, and a
    /// player who cannot tell the two apart types OOPS twice.
    private func performOops(_ parsed: ParsedCommand, correction: Correction?) -> Rewrite {
        guard let correction else { return .refusal(definition.text.nothingToCorrect()) }
        guard let replacement = parsed.topic, !replacement.isEmpty else {
            // Asking which word the player meant is a question, not a spend:
            // put the context back, or the next line cannot answer it.
            pendingCorrection = correction
            return .refusal(definition.text.oopsNeedsAWord())
        }
        var tokens = correction.tokens
        tokens.replaceSubrange(correction.index...correction.index, with: replacement)
        return .line(tokens)
    }

    /// The line one of the two rewriting verbs hands back, or its refusal.
    ///
    /// - Parameters:
    ///   - parsed: the AGAIN or OOPS command.
    ///   - correction: the OOPS context this line may spend.
    /// - Returns: the replacement line, or the reason there is none.
    private func rewritten(_ parsed: ParsedCommand, correction: Correction?) -> Rewrite {
        parsed.intent == .again ? performAgain() : performOops(parsed, correction: correction)
    }

    /// Quits at the front end's request — a Ctrl-C, not a typed command.
    /// Abandons any open engine prompt or clarification and ends the game
    /// through the same path the `quit` verb takes, so the score epilogue still
    /// prints. Keyed to `Intent.quit`, so it's immune to a game redefining the
    /// `quit` verb word and quits even while a save/restore filename prompt is
    /// pending — which `perform` would otherwise consume the line as the
    /// filename answer.
    ///
    /// Once the game has already ended — the death prompt, or a `won`/`lost`/
    /// `quit` status left by `end(won:)` or an earlier quit — the epilogue has
    /// already printed, on the turn that ended it, so this takes the same
    /// exit the typed `quit` answer takes at the death prompt: stop reading,
    /// say nothing more.
    ///
    /// - Returns: the final turn's output and status (`isFinished == true`).
    public func requestQuit() -> TurnResult {
        pendingPrompt = nil
        pendingClarification = nil
        if state.status != .playing { return quitAfterGameEnded() }
        return runTurn(
            Command(intent: .quit, verbPhrase: "quit", rawInput: "quit"),
            snapshot: state)
    }

    /// Leaves the game silently once it has already ended: the turn that
    /// ended it — a death, a win, a loss, or an earlier quit — already printed
    /// the score epilogue, so this stops reading and says nothing more. The
    /// typed `quit` answer at the death prompt and a front end's Ctrl-C after
    /// any ending both land here.
    func quitAfterGameEnded() -> TurnResult {
        state.status = .quit
        return freeReply("")
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
    ///
    /// - Parameters:
    ///   - parsed: the command.
    ///   - tokens: the line it was read from, as the parser saw it — what
    ///     ``WorldState/lastCommand`` records for AGAIN.
    /// - Returns: the turn's output and status.
    private func run(_ parsed: ParsedCommand, tokens: [String]) -> TurnResult {
        // UNDO and RESTART act on the actor's snapshots, not the pipeline —
        // no rules see them and `actionOverrides` can't reclaim them.
        switch parsed.intent {
        case .undo: return performUndo()
        case .restart: return performRestart()
        case .save:
            pendingPrompt = .saveFilename
            return freeReply(savePromptText())
        case .restore:
            pendingPrompt = .restoreFilename(returnToDeathPrompt: false)
            return freeReply(restorePromptText())
        case .verbose: return setDescriptionMode(.verbose)
        case .brief: return setDescriptionMode(.brief)
        case .superbrief: return setDescriptionMode(.superbrief)
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

        // What AGAIN will repeat. Two things must never reach this line, and
        // neither can: an engine-level verb returned above, and a meta verb is
        // excluded by name — so AGAIN cannot repeat itself, and asking for
        // your score does not displace the command you would say "again" of.
        // Behind the snapshot, so that a turn nothing answered takes its
        // recording back with the rest of itself, exactly as the pronoun
        // binding below does. (#445)
        if !parsed.intent.isMeta {
            state.lastCommand = tokens
        }

        // Naming a thing binds "it" — even if the action then refuses. The
        // one exception is a turn nothing answers: the snapshot below predates
        // the binding, and `runTurn` hands it back to `commit` on the
        // `unhandled` path, so a free turn steals no pronoun.
        if let direct = parsed.directObject {
            state.pronounIt = direct
            // A plural thing is one thing, and the pronoun English gives it
            // is "them" — so naming the stairs binds that word the way naming
            // the lantern binds "it". Same slot the last group went in,
            // because the word does not distinguish the two and the thing
            // named last is the thing meant. A singular object leaves the
            // slot alone: `take all` then `x sword` then `drop them` still
            // means the group. (#403)
            if definition.items[direct]?.isPlural == true {
                state.pronounThem = [direct]
            }
        }
        // "him" and "her" bind from every slot that named a person, where "it"
        // binds from the direct object alone. Naming somebody as the recipient
        // of a gift or as the one you spoke to is referring to them just as
        // squarely as examining them is, and the pronoun that follows means
        // the person the player has in mind, not the last thing a verb took as
        // its object. Later slots win, so `give the lamp to the keeper` leaves
        // "her" on the keeper.
        for named in [parsed.actor, parsed.directObject, parsed.indirectObject] {
            guard let named else { continue }
            bindGenderedPronoun(naming: named, in: &state)
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

    /// A frame over the world as it stands, for a turn about to run or a
    /// re-describe about to print.
    ///
    /// Written once because every one of these carries the same three things
    /// — the definition, the live state, and the session's
    /// ``DescriptionMode`` — and the next per-session value the frame has to
    /// carry should be a field here rather than an edit at five call sites.
    ///
    /// - Parameter command: the command the frame is running, if any.
    /// - Returns: a live frame.
    func turnFrame(_ command: Command? = nil) -> TurnFrame {
        TurnFrame(
            definition: definition, state: state, command: command,
            descriptionMode: descriptionMode)
    }

    private func runTurn(_ command: Command, snapshot: WorldState) -> TurnResult {
        let frame = turnFrame(command)
        Ctx.$frame.withValue(frame) {
            performStages(command, frame: frame, upkeep: true)
            finishTurn(intent: command.intent, frame: frame)
        }
        // Stored only once the turn is known to have been one — the same rule
        // `run` states for a free reply, and a command nothing answered is no
        // more a turn than a parse error was. Nothing in the pipeline reads
        // the snapshot, so the decision keeps until the frame comes back.
        let unhandled = frame.with({ $0.unhandled })
        if !command.intent.isMeta, !unhandled {
            undoSnapshot = snapshot
        }
        // A turn nothing answered never happened: hand the pre-turn snapshot
        // back to `commit` instead of the frame's state, so neither the "it"
        // binding `run` made nor any `before` rule's mutation survives. The
        // snapshot predates both — `run` takes it before binding the pronoun.
        return commit(frame, restoring: unhandled && !command.intent.isMeta ? snapshot : nil)
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

        // Reject an initially empty group without running rules or spending a
        // turn. A nonempty group is expanded again after upkeep has run.
        var objects: [EntityID] = []
        switch expandGroup(parsed, multiple, in: state) {
        case .objects(let expanded):
            objects = expanded
        case .empty(let message):
            return freeReply(message)
        case .dark, .holder:
            // Falls through into the turn below rather than replying for
            // free: see `MultiObjectExpansion.dark` and `.holder`.
            break
        }

        // Every early return above was a free reply; from here the turn
        // really runs, so it becomes the thing UNDO reverses.
        undoSnapshot = snapshot

        // The upkeep pass runs before any object's command exists, but its
        // rules are rule bodies and may ask `command.intent`. What the player
        // typed was the group's intent, so that is what they are handed — no
        // object, because none has been named yet.
        let frame = turnFrame(command(from: parsed))
        Ctx.$frame.withValue(frame) {
            do {
                try runUpkeepBefore(intent, frame: frame)
                let currentState = frame.with { $0.state }
                switch expandGroup(parsed, multiple, in: currentState) {
                case .objects(let expanded):
                    objects = expanded
                case .empty(let message):
                    // Upkeep already happened: keep its state and finish this
                    // turn, even though there are now no objects to act on.
                    throw TurnInterrupt.replied(message: message)
                case .dark:
                    // Said here rather than thrown, because the dark line is
                    // the one sentence another emitter is most likely to have
                    // a claim on — in Zork the room's dark line *is* the
                    // grue's threat — and `sayOnceThisTurn` is how the engine
                    // keeps the two from doubling up. The throw that follows
                    // carries no text: it ends the turn, leaving `finishTurn`
                    // to charge it and tick the timers.
                    frame.sayOnceThisTurn(definition.text.pitchBlack())
                    throw TurnInterrupt.replied(message: "")
                case .holder(let holder):
                    // Rendered here for the same reason the dark line is: the
                    // holder refusals are stock lines a game may have written
                    // as `Line.live(_:)`, and the first expansion runs before
                    // the frame those read through exists.
                    throw TurnInterrupt.replied(
                        message: nothingToTake(from: holder, in: currentState))
                }
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
                        // Each object of the group is named in its turn, and
                        // naming binds "it" here exactly as it does for a
                        // single-object command — so `take all` leaves "it" on
                        // the last thing the loop ran on rather than on
                        // whatever the player named before the group. (#445)
                        scratch.state.pronounIt = id
                        bindGenderedPronoun(naming: id, in: &scratch.state)
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
            // If the second expansion refuses or upkeep interrupts, objects
            // keeps the initial set. Successful expansion replaces that set.
            // An initially dark or empty holder starts with no objects, so it
            // preserves THEM unless upkeep makes a group available; a group
            // found before upkeep still binds even if upkeep later hides it.
            // Bind here so expanding THEM can read its previous referents.
            if !objects.isEmpty {
                frame.with { $0.state.pronounThem = objects }
            }
            finishTurn(intent: intent, frame: frame)
        }
        return commit(frame)
    }

    private enum MultiObjectExpansion {
        case objects([EntityID])

        /// No objects, and nothing to run: the group's own phrase answered
        /// itself, so the reply is free the way a parse failure is.
        case empty(String)

        /// No objects because the room is dark. The answer is about the
        /// world rather than about the phrase — the same answer LOOK gives —
        /// so the turn runs, is charged, and ticks the timers, which is what
        /// keeps a dark room dangerous while the player types TAKE ALL.
        ///
        /// It carries no text, deliberately. ``GameText/pitchBlack`` is the
        /// line most likely to be ``Line/live(_:)``, and a live line reads the
        /// world through `Ctx.current`; `expandGroup` runs once before the
        /// frame exists, where that read traps. The wording is left to the
        /// caller, which speaks from inside the frame.
        case dark

        /// No objects because the holder the player named after `from` has
        /// none to give. Carries the holder rather than its refusal, for
        /// ``dark``'s reason: every one of those refusals is a stock line a
        /// game may have written as ``GameText/Line/live(_:)``, and rendering
        /// one before the frame exists traps. The turn runs and is charged,
        /// which is also what `take coin from <shut box>` costs.
        case holder(EntityID)
    }

    /// Resolve a group against an explicit state so the eligibility check and
    /// the post-upkeep expansion use the same rules without sharing a stale set.
    private func expandGroup(
        _ parsed: ParsedCommand, _ multiple: ParsedCommand.MultiObject, in snapshot: WorldState
    ) -> MultiObjectExpansion {
        var state = snapshot
        // The index is built inside each keyword case rather than out here:
        // a list the player wrote out is already resolved, and a room sweep
        // for it would be for nothing.
        let intent = parsed.intent
        var objects: [EntityID]
        // Set when the player named a holder — `take all from the crate` — so
        // the empty-group answer at the bottom can be about that thing rather
        // than about the room.
        var namedHolder: EntityID?
        switch multiple {
        case .all where intent == .take:
            let index = state.containment()
            // TAKE ALL sweeps what is lying about: the floor of the room the
            // player is standing in, and the tops of the tables and shelves
            // standing on it. What it does **not** do is unpack — sweeping the
            // whole reachable closure took the sack *and* the garlic inside it,
            // and two commands later the sack was empty and its contents were
            // loose on the ground, a rearrangement nobody asked for (#510). A
            // surface is display and a container is packing, which is the line
            // the sweep stops at; what is inside something here is taken by
            // name, or by `take all from <it>` below.
            //
            // `from`/`off`/`out of` names the thing to sweep instead: its
            // surface items and its contents, whether it is standing here or in
            // the player's hands. The indirect slot is a *source* here and a
            // *destination* for `put all in the sack`, which is why the
            // subtraction further down reads it only for `.putIn`/`.putOn`:
            // TAKE's rows spell no destination, so the two never meet.
            let source: [EntityID] =
                if let indirect = parsed.indirectObject {
                    index.children(of: indirect) + (index.held[indirect] ?? [])
                } else {
                    floorHere(state, index).flatMap {
                        [$0] + (definition.items[$0]?.isSurface == true ? index.onSurface[$0] ?? [] : [])
                    }
                }
            // Intersected with the *reachable* set, not the nameable one. On
            // the floor sweep that is the revealed test: a `hidden` item lies
            // in the room without being on offer until something reveals it.
            // On the `from` sweep it is also what keeps a shut glass case from
            // handing over the medal it shows (#267). A `reach { … }` veto is
            // deliberately still offered — `reachableItems` is containment-only,
            // and a rule that says "the length of the gallery away" wants to say
            // it, not to vanish the thing.
            let reachable = Visibility.reachableItems(
                at: state.playerLocation, definition: definition, state: state, index: index)
            namedHolder = parsed.indirectObject
            let held = Set(index.held[.player] ?? [])
            // The vehicle the player is aboard comes out too. Boarding leaves
            // it a child of the room they are standing in, and `enterable`
            // asks for no trait that would hold it down, so the filters above
            // pass an ordinary boat and the sweep printed `flat punt: Not
            // while you're in the flat punt.` beside every real cargo line,
            // every sweep, for as long as the player stayed aboard (#541).
            // The refusal itself is right; offering it is not. Naming the
            // thing still gets it — `.list` below is deliberately unfiltered —
            // and a vehicle nobody is aboard is swept as before.
            let boarded = state.playerVehicle
            objects = inDisplayOrder(
                source.filter {
                    reachable.contains($0) && definition.items[$0]?.isTakable == true
                        && !held.contains($0) && $0 != boarded
                })
        case .all:
            // DROP/PUT ALL is the opposite question and keeps the opposite
            // answer: what you hold, direct children only, so DROP ALL empties
            // your hands and not your sack. Worn items are placed
            // `.heldBy(.player)` too, which is why they come along.
            objects = inDisplayOrder(state.containment().held[.player] ?? [])
        case .them:
            guard !state.pronounThem.isEmpty else {
                return .empty(definition.text.noReferent("them"))
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
                return .empty(definition.text.cantSeeAnySuchThing())
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
                return .empty(definition.text.nothingLeftOfTheGroup())
            }
        }
        guard !objects.isEmpty else {
            // TAKE ALL's reachable set is dark-gated, so an empty result in
            // the dark is never "nothing here" — the player cannot tell that
            // from a room that genuinely has nothing in it. LOOK answers the
            // same question with `pitchBlack`, so TAKE ALL borrows the line
            // rather than inventing one. Only `.all`/`.take` can arrive here
            // in the dark: DROP ALL reads the player's own hands, which
            // darkness does not hide; `.them` has already refused above
            // against the visible set; and `.list` was resolved by a parser
            // walking the same gate.
            if intent == .take,
                Visibility.isDark(at: state.playerLocation, definition: definition, state: state)
            {
                return .dark
            }
            if let namedHolder {
                return .holder(namedHolder)
            }
            return .empty(
                intent == .take ? definition.text.nothingToTakeHere() : definition.text.notCarryingAnything())
        }

        return .objects(objects)
    }

    /// What `take all from X` says when X has nothing for the player.
    ///
    /// The rungs are `lookIn`'s, in `lookIn`'s order — yourself, out of reach,
    /// a person, not a container, shut — because a player who has just been
    /// told a box is shut should not be told next that it is bare, and one who
    /// can see the clerk's open pouch is full should not be told there is
    /// nothing in it. The reach rung is containment-only, which is all a bare
    /// state snapshot can answer; a `reach { … }` veto is left to the
    /// per-object runs.
    ///
    /// The two ladders part company on one case: `lookIn` reads a shut
    /// *transparent* container and reports what is in it, where this reports
    /// it shut, since what the group would have taken is behind the glass
    /// either way.
    ///
    /// Called only from inside the turn, through
    /// ``MultiObjectExpansion/holder(_:)``, so a line is rendered only where
    /// a ``GameText/Line/live(_:)`` one can read the world.
    ///
    /// - Parameters:
    ///   - holder: the thing the player named after `from`.
    ///   - state: the world the group was expanded against.
    /// - Returns: the rendered refusal.
    private func nothingToTake(from holder: EntityID, in state: WorldState) -> String {
        if holder == .player {
            return definition.text.cantSearchSelf()
        }
        let noun = definition.vocabulary.definiteNoun(of: holder)
        // `containment()` memoizes into the value it is asked of, so the
        // snapshot is copied rather than shared.
        var state = state
        let reachable = Visibility.reachableItems(
            at: state.playerLocation, definition: definition, state: state,
            index: state.containment())
        guard reachable.contains(holder) else {
            return definition.text.cantReach(noun)
        }
        if definition.items[holder]?.isActor == true {
            return definition.text.cantSearchActor(noun)
        }
        guard
            definition.items[holder]?.isContainer == true
                || definition.items[holder]?.isSurface == true
        else {
            return definition.text.nothingToTakeThere()
        }
        if definition.items[holder]?.isOpenable == true, !state.openItems.contains(holder) {
            return definition.text.closedContainer(noun)
        }
        // A holder is empty only if nothing perceivable remains. Scenery
        // can make the take set empty without making the holder empty.
        let contents = state.containment().children(of: holder)
            .filter { Visibility.isPerceivable($0, definition: definition, state: state) }
        if contents.isEmpty { return definition.text.emptyContainer(noun) }
        return definition.text.nothingToTakeThere()
    }

    /// What "here" holds for the floor sweep: the room the player is standing
    /// in, plus the hull of the vehicle they are aboard when that vehicle is a
    /// container. `drop` puts what you let go of into a cargo vehicle rather
    /// than on the ground sliding past below, so a sweep that read the room
    /// alone would strand everything `drop all` had just put down (#540). Both,
    /// not either: reach is room-granular, so the lantern on the quay is as
    /// much within arm's length of the thwart as the pole in the bottom of the
    /// boat is.
    ///
    /// One level, like every other floor. The hull's own contents come up; what
    /// is packed inside a hamper standing in the hull does not.
    private func floorHere(_ state: WorldState, _ index: ContainmentIndex) -> [EntityID] {
        var floor = index.inRoom[state.playerLocation] ?? []
        if let vehicle = state.playerVehicle, definition.items[vehicle]?.isContainer == true {
            floor += index.inContainer[vehicle] ?? []
        }
        return floor
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
        let frame = turnFrame(lookCommand)
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

    /// Takes the player's new description-mode preference and confirms it.
    ///
    /// Free, like the other meta intents: no stage runs, no rule sees it, no
    /// timer ticks and the move counter stands still. It changes what
    /// the *next* entry prints and says nothing about this room, so it does
    /// not re-describe — a player who wants the room now types LOOK, which is
    /// full in every mode.
    ///
    /// - Parameter mode: the mode the player asked for.
    /// - Returns: the confirmation, as a free reply.
    func setDescriptionMode(_ mode: DescriptionMode) -> TurnResult {
        descriptionMode = mode
        let text = definition.text
        let confirmation =
            switch mode {
            case .verbose: text.maximumVerbosity()
            case .brief: text.briefDescriptions()
            case .superbrief: text.superbriefDescriptions()
            }
        return freeReply(confirmation)
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
        try runBefore(
            definition.rules.worldBefore.filter { $0.phase == .beforeEachTurn },
            matching: intent, frame: frame)
        // World upkeep may move the player. Select location upkeep afterward.
        // Ordinary world `before` rules run later, once per object, so their
        // moves affect that object's dispatch but cannot redirect this pass.
        let here = frame.with { $0.state.playerLocation }
        try runBefore(
            definition.rules.locationBeforeEachTurn[here] ?? [], matching: intent, frame: frame)
    }

    /// Stages 1–3 for one command. World rules run first, then the current
    /// room's upkeep. Read the room again before ordinary location rules:
    /// either upkeep pass may have moved the player or the addressee (#523).
    /// The selected upkeep list runs once; moving does not start another pass.
    ///
    /// Return the player's room at that boundary for stage 5's location
    /// `after` rules. Later ordinary before rules and the default action do
    /// not change that selection, so walking runs the departed room's `after`.
    /// `proceed()` during world rules or location upkeep runs the action
    /// before the reading, so its destination is selected instead.
    /// An addressed order uses the addressee's current standing room for
    /// ordinary location `before` rules; no standing room means no dispatch.
    /// Stage 6 selects its own room before running end-of-turn rules and timers.
    /// Meta intents return nil and skip these phases and stage 5.
    ///
    /// `inBeforeRule` is set for the span of these stages so `proceed()` can
    /// recognize a legal call site; a rule that calls it runs stage 4 early and
    /// flips `defaultRan`. Once that flag is set, `runBefore` skips every
    /// remaining before-phase for the rest of this sequence — `proceed()` means
    /// "run the default now", so later before-guards for this command are moot
    /// and must not run. Stage 4's own call site checks the same flag to avoid
    /// running the default a second time.
    private func runBeforeStages(
        _ command: Command, frame: TurnFrame, upkeep: Bool
    ) throws -> EntityID? {
        let intent = command.intent
        guard !intent.isMeta else { return nil }
        let rules = definition.rules
        frame.with { $0.inBeforeRule = true }
        defer { frame.with { $0.inBeforeRule = false } }

        // Stage 1: the world's rules — its `beforeEachTurn` upkeep among them
        // on a single-command turn, interleaved in declaration order.
        try runBefore(
            upkeep ? rules.worldBefore : rules.worldBefore.filter { $0.phase == .before },
            matching: intent, frame: frame)

        // Stage 2: run the player's current room's upkeep once, then read
        // both participants again before selecting ordinary location rules.
        if upkeep {
            let upkeepRoom = frame.with { $0.state.playerLocation }
            try runBefore(rules.locationBeforeEachTurn[upkeepRoom] ?? [], matching: intent, frame: frame)
        }
        let here = frame.with { $0.state.playerLocation }
        let agent = command.actor?.id
        let stage: EntityID
        if let actor = command.actor, let agent {
            guard let room = frame.with({ Visibility.standing(agent, in: $0.state) }) else {
                throw TurnInterrupt.unhandled(
                    message: definition.text.doesNotKnowHow(actor.definiteNoun))
            }
            stage = room
        } else {
            stage = here
        }
        try runBefore(rules.locationBefore[stage] ?? [], matching: intent, frame: frame)

        // Stage 3: the objects' rules. The one told is told first — before the
        // thing they were told about — so `robot.before(.go)` can answer an
        // order that names no object at all. Skipped when they *are* one of the
        // objects, so nobody's rules run twice.
        if let agent, agent != command.directObject?.id, agent != command.indirectObject?.id {
            try runBefore(rules.itemBefore[agent] ?? [], matching: intent, frame: frame)
        }
        if let indirect = command.indirectObject {
            try runBefore(rules.itemBefore[indirect.id] ?? [], matching: intent, frame: frame)
        }
        if let direct = command.directObject {
            try runBefore(rules.itemBefore[direct.id] ?? [], matching: intent, frame: frame)
        }
        return here
    }

    /// Stages 1–5 for one command. With `upkeep` the each-turn `before`
    /// phases are included (the single-command turn); without it they're the
    /// caller's job (`runMultiTurn` runs them once, outside its object loop).
    private func performStages(_ command: Command, frame: TurnFrame, upkeep: Bool) {
        let intent = command.intent
        let rules = definition.rules

        do {
            // Stage 0: the objects' `reach { … }` rules, which have to be
            // settled ahead of the rules that could pre-empt stage 4.
            try DefaultActions.requireReachRules(for: command, frame: frame)

            // Stages 1–3, and with them the room this turn belongs to.
            let here = try runBeforeStages(command, frame: frame, upkeep: upkeep)

            // Stage 4: the default action — skipped if a `before` rule
            // already ran it early via `proceed()`.
            if !frame.with({ $0.defaultRan }) {
                try DefaultActions.run(command, frame: frame)
            }

            // Stage 5: item and location `after` rules. A meta intent has no
            // room of record, and runs none of them.
            if let here {
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
    /// objects it covered. The turn that kills the player counts a move like
    /// any other cost turn: the death line is that turn's output, and the
    /// counter is read by its score epilogue.
    private func finishTurn(intent: Intent, frame: TurnFrame) {
        let rules = definition.rules
        // A command stage 4 had no answer for is free, like a parse error:
        // the player was told nothing happened, so nothing may happen.
        let costsTurn = !intent.isMeta && !frame.with { $0.unhandled }
        if costsTurn {
            // Each rule checks the status before it runs, so a turn that has
            // already ended the game runs none, and a rule that ends it here
            // is the last.
            let here = frame.with { $0.state.playerLocation }
            runCatching(rules.locationAfterEachTurn[here] ?? [], matching: intent, frame: frame)
            runCatching(rules.worldAfter, matching: intent, frame: frame)
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

    /// Runs one of stage 6's rule lists, catching each rule's interrupt so a
    /// refusal in one rule does not skip the next. The status is re-checked
    /// before every rule, as `tickTimers` does before every body: once a rule
    /// has ended the game — `end(won:)`, or a `die(_:)` that `onDeath()` did
    /// not consume — no later rule runs, so none prints below the death
    /// banner or turns a win into a death. (#607)
    private func runCatching(_ rules: [Rule], matching intent: Intent, frame: TurnFrame) {
        for rule in rules where rule.matches(intent) {
            guard frame.with({ $0.state.status }) == .playing else { return }
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
    /// group in name order, so firing order is deterministic. Both schedules
    /// are read **once, before any body runs**, so a timer a body starts is
    /// not on this tick's list and first ticks next turn — the same answer
    /// for a fuse and a daemon, whichever kind of body started it, and never
    /// one that depends on where its name sorts. (Draining new starts to a
    /// fixpoint instead would let a fuse that restarts itself `after: 1` loop
    /// inside one turn.) Each name is re-checked against the live schedule
    /// before it acts, because an earlier body may have stopped it this very
    /// tick; a fuse is removed from the schedule *before* its body runs, so
    /// the body can restart it. Bodies get the same interrupt handling as
    /// each-turn rules, and the tick stops as soon as one of them ends the
    /// game.
    private func tickTimers(frame: TurnFrame) {
        let (fuses, daemons) = frame.with {
            ($0.state.activeFuses.keys.sorted(), $0.state.activeDaemons.sorted())
        }
        for name in fuses {
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
        for name in daemons {
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
                pronounIt: state.pronounIt,
                pronounThem: state.pronounThem,
                pronounHim: referent(of: .he, in: visible),
                pronounHer: referent(of: .she, in: visible))
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
            pronounThem: state.pronounThem,
            pronounHim: referent(of: .he, in: visible),
            pronounHer: referent(of: .she, in: visible),
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

    /// Points "him" or "her" at the entity just named, where it answers to one
    /// of the two words. Called from both the single-object path and the group
    /// loop, so a pronoun cannot come to be bound on one and not the other.
    ///
    /// - Parameters:
    ///   - id: the entity the player just named.
    ///   - state: the state to bind in — live state, or a turn frame's copy.
    private func bindGenderedPronoun(naming id: EntityID, in state: inout WorldState) {
        switch definition.items[id]?.pronoun {
        case .he: state.pronounHim = id
        case .she: state.pronounHer = id
        case nil: break
        }
    }

    /// Who "him" or "her" names this turn.
    ///
    /// The person of that gender the player last referred to, while they are
    /// still in view — and otherwise the one thing in view that answers to the
    /// word, which is what lets `x her` work in a game with one woman in it and
    /// no prior mention of her. Where nobody in view answers and somebody was
    /// named, the binding stands — deliberately, and it is the one line here
    /// that looks like a mistake: handing the parser a referent this method has
    /// just proved invisible is what turns the answer into *"You can't see any
    /// such thing"* rather than *"I don't know what that refers to"*. She is
    /// known, and simply not here. Where two people answer and neither was
    /// named, the word has no referent and says so rather than guessing.
    ///
    /// The candidates come from the bootstrap's index rather than a walk of the
    /// room, for the reason ``GameDefinition/castIDs`` gives: who answers to a
    /// pronoun is settled at declaration and never changes, and a game that
    /// declared none — nearly all of them — pays one empty check a turn.
    ///
    /// - Parameters:
    ///   - pronoun: which word is being resolved.
    ///   - visible: what the player can see from where they stand.
    /// - Returns: the entity the word names, or nil.
    private func referent(of pronoun: Pronoun, in visible: Set<EntityID>) -> EntityID? {
        let bound = pronoun == .he ? state.pronounHim : state.pronounHer
        let candidates = definition.pronounIDs[pronoun] ?? []
        guard !candidates.isEmpty else { return bound }
        if let bound, visible.contains(bound) { return bound }
        let answering = candidates.intersection(visible)
        return answering.count == 1 ? answering.first : bound
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

    /// Adopts a finished frame: its state becomes the live world, its output
    /// becomes the turn result.
    ///
    /// - Parameters:
    ///   - frame: the turn frame to retire.
    ///   - restoring: a pre-turn state to adopt instead of the frame's — the
    ///     rollback a free turn takes. A command nothing answered never
    ///     happened, so the world (pronouns and `@Global`s included) goes back
    ///     to where it stood, while the turn's words still print. The caller
    ///     passes the same snapshot `run` took, which predates the pronoun
    ///     binding and every `before` rule.
    /// - Returns: the finished turn's output and status.
    func commit(_ frame: TurnFrame, restoring: WorldState? = nil) -> TurnResult {
        let scratch = frame.retire()
        state = restoring ?? scratch.state
        if restoring == nil {
            state.unconsciousActors.subtract(scratch.recoveringActors)
        }
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
