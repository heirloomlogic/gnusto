/// A verb the engine backs with real behavior — the other half of the standard
/// table from ``StubVerb``.
///
/// The shape is deliberate, and it is the stub table's. Before this type the
/// same fact was stated in three places nothing checked against each other: the
/// rows, a hand-written `builtInIntents` set, and a `switch` in
/// ``DefaultActions/run(_:frame:)``. Every way those three could disagree was
/// silent — a row with no arm fell through to stage 4's last resort and read to
/// the player as a verb the game refused; an arm with no row was dead code; an
/// intent in the set but not the switch made `action(…)` warn about shadowing
/// nothing.
///
/// Stating the intent once and deriving the rest makes all of that
/// unrepresentable, so `CoreVerbTests` doesn't assert it: the initializer
/// already does.
struct CoreVerb: Sendable {
    /// The intent every one of `rows` produces.
    let intent: Intent

    /// The rows that reach this intent, built from the declared patterns so the
    /// intent is stated once.
    let rows: [SyntaxRule]

    /// What answers the intent once the rows have matched.
    let behavior: Behavior

    /// Which of this verb's object slots the player has to be able to *touch*.
    ///
    /// Each handler still runs its own containment guard, in its own order among
    /// its own refusals — moving those would change what a dozen shipped games
    /// print. What this column adds is the one thing containment can't answer:
    /// the item's own ``Item/reach(otherwise:_:)`` rule, consulted before any
    /// rule runs. `engineLevel` rows have no slots to check and take
    /// ``Reach/notNeeded``.
    let reach: Reach

    /// The two ways a core verb can be answered. There is no third: a row that
    /// reaches neither would be the drift this type exists to prevent.
    enum Behavior: Sendable {
        /// Stage 4 runs this, unless a game, bundle or plugin reclaims the
        /// intent with an `actions` row.
        case handler(@Sendable (Command, TurnFrame) throws -> Void)

        /// Rows and nothing else. `GameWorld.run` answers these before the turn
        /// pipeline starts, so no rule sees them, `actionOverrides` can't
        /// reclaim them, and there is no handler here to run. Declaring the
        /// absence is the point: it's what lets the bootstrap warn about an
        /// `action(.save)` that would otherwise never run and never complain.
        case engineLevel
    }

    /// Patterns in, rows out — spelled the way `#verb` spells them, and the
    /// reason no row below has to repeat `intent:`.
    private init(
        _ intent: Intent, _ patterns: [[SyntaxElement]], _ reach: Reach, _ behavior: Behavior
    ) {
        self.intent = intent
        self.rows = patterns.map { SyntaxRule($0, intent: intent) }
        self.reach = reach
        self.behavior = behavior
    }

    /// The handler, for the one caller that dispatches on it.
    var handler: (@Sendable (Command, TurnFrame) throws -> Void)? {
        if case .handler(let body) = behavior { body } else { nil }
    }

    var isEngineLevel: Bool {
        if case .engineLevel = behavior { true } else { false }
    }
}

extension CoreVerb {
    /// A verb stage 4 answers itself. The handler takes the whole command
    /// because most of them need its objects; the few that don't ignore it.
    static func handled(
        _ intent: Intent,
        _ patterns: [[SyntaxElement]],
        reach: Reach,
        _ handler: @escaping @Sendable (Command, TurnFrame) throws -> Void
    ) -> CoreVerb {
        .init(intent, patterns, reach, .handler(handler))
    }

    /// A verb the engine intercepts ahead of the pipeline — see
    /// ``Behavior/engineLevel``.
    static func engineLevel(_ intent: Intent, _ patterns: [[SyntaxElement]]) -> CoreVerb {
        .init(intent, patterns, .notNeeded, .engineLevel)
    }
}

// MARK: - The table

extension DefaultActions {
    /// Every core verb: its intent, its rows and what answers it, in one place.
    /// Ordering doesn't matter — the parser sorts candidate rows by specificity
    /// — so these are grouped to read.
    static let cores: [CoreVerb] = [
        .handled(
            .take,
            [
                ["take", .directObject],
                ["get", .directObject],
                ["grab", .directObject],
                ["hold", .directObject],
                ["carry", .directObject],
                ["pick", "up", .directObject],
                ["pick", .directObject, "up"],
            ],
            reach: .directObject
        ) { try take($0, frame: $1) },

        .handled(
            .drop,
            [
                ["drop", .directObject],
                ["discard", .directObject],
                ["put", "down", .directObject],
                ["put", .directObject, "down"],
            ],
            reach: .notNeeded
        ) { try drop($0, frame: $1) },

        .handled(
            .examine,
            [
                ["examine", .directObject],
                ["x", .directObject],
                ["inspect", .directObject],
                ["look", "at", .directObject],
                ["l", "at", .directObject],
            ],
            reach: .notNeeded
        ) { try examine($0, frame: $1) },

        .handled(.read, [["read", .directObject]], reach: .notNeeded) { try read($0, frame: $1) },

        .handled(
            .wear,
            [
                ["wear", .directObject],
                ["don", .directObject],
                ["put", "on", .directObject],
            ],
            reach: .notNeeded
        ) { try wear($0, frame: $1) },

        .handled(
            .doff,
            [
                ["remove", .directObject],
                ["doff", .directObject],
                ["take", "off", .directObject],
                ["take", .directObject, "off"],
            ],
            reach: .notNeeded
        ) { try doff($0, frame: $1) },

        .handled(
            .putOn,
            [
                ["put", .directObject, "on", .indirectObject],
                ["put", .directObject, "onto", .indirectObject],
                ["hang", .directObject, "on", .indirectObject],
                ["place", .directObject, "on", .indirectObject],
            ],
            reach: .bothObjects
        ) { try putOn($0, frame: $1) },

        .handled(
            .putIn,
            [
                ["put", .directObject, "in", .indirectObject],
                ["put", .directObject, "into", .indirectObject],
            ],
            reach: .bothObjects
        ) { try putIn($0, frame: $1) },

        .handled(.open, [["open", .directObject]], reach: .directObject) { try open($0, frame: $1) },

        .handled(
            .close,
            [
                ["close", .directObject],
                ["shut", .directObject],
            ],
            reach: .directObject
        ) { try close($0, frame: $1) },

        .handled(
            .lock,
            [["lock", .directObject, "with", .indirectObject]],
            reach: .directObject
        ) { try lock($0, frame: $1) },

        .handled(
            .unlock,
            [["unlock", .directObject, "with", .indirectObject]],
            reach: .directObject
        ) { try unlock($0, frame: $1) },

        .handled(
            .turnOn,
            [
                ["turn", "on", .directObject],
                ["turn", .directObject, "on"],
                ["switch", "on", .directObject],
                ["switch", .directObject, "on"],
                ["light", .directObject],
            ],
            reach: .directObject
        ) { try turnOn($0, frame: $1) },

        .handled(
            .turnOff,
            [
                ["turn", "off", .directObject],
                ["turn", .directObject, "off"],
                ["switch", "off", .directObject],
                ["switch", .directObject, "off"],
                ["extinguish", .directObject],
                ["douse", .directObject],
                ["blow", "out", .directObject],
                ["blow", .directObject, "out"],
            ],
            reach: .directObject
        ) { try turnOff($0, frame: $1) },

        // FIND and LOOK FOR land here too: a player who asks the game to find
        // something is asking it to look, and "you can't see any such thing" is
        // a better answer than "I don't know the word".
        .handled(
            .lookIn,
            [
                ["look", "in", .directObject],
                ["search", .directObject],
                ["find", .directObject],
                ["look", "for", .directObject],
                ["search", "for", .directObject],
            ],
            reach: .directObject
        ) { try lookIn($0, frame: $1) },

        .handled(
            .push,
            [
                ["push", .directObject],
                ["move", .directObject],
                ["press", .directObject],
            ],
            reach: .directObject
        ) { try push($0, frame: $1) },

        .handled(
            .go,
            [
                ["go", .direction],
                ["walk", .direction],
                ["run", .direction],
            ],
            reach: .notNeeded
        ) { try go($0, frame: $1) },

        // `go after <object>` outscores `go <direction>`, so the follow rows are
        // tried first and `go north` still falls through to the direction row.
        .handled(
            .follow,
            [
                ["follow", .directObject],
                ["chase", .directObject],
                ["go", "after", .directObject],
                ["run", "after", .directObject],
                ["walk", "after", .directObject],
            ],
            reach: .notNeeded
        ) { try follow($0, frame: $1) },

        // Bare "hello"/"hi" are deliberately *not* here: they are the kind of
        // one-word verb a game likes to own outright (Zork 1 does), and claiming
        // them as built-ins would make every such game warn at launch.
        // `GnustoConversation` adds them.
        .handled(
            .greet,
            [
                ["greet", .directObject],
                ["hello", .directObject],
                ["hi", .directObject],
                ["greet"],
            ],
            reach: .notNeeded
        ) { try greet($0, frame: $1) },

        // One verb for a doorway and a vehicle, which is `V-THROUGH`'s own
        // shape: the trilogy routes ENTER, CLIMB WITH and WALK IN/WITH/ON to
        // one routine that walks you through a door and boards a boat.
        // Bare "in"/"out" stay directions: the parser's bare-direction check
        // runs before any verb row.
        .handled(
            .board,
            [
                ["enter", .directObject],
                ["board", .directObject],
                ["get", "in", .directObject],
                ["get", "into", .directObject],
                ["go", "through", .directObject],
                ["walk", "through", .directObject],
                ["step", "through", .directObject],
                ["climb", "through", .directObject],
                ["walk", "in", .directObject],
            ],
            reach: .directObject
        ) { try board($0, frame: $1) },

        .handled(
            .disembark,
            [
                ["exit"],
                ["exit", .directObject],
                ["disembark"],
                ["get", "out"],
                ["get", "out", "of", .directObject],
            ],
            reach: .notNeeded
        ) { try disembark($0, frame: $1) },

        .handled(
            .wait,
            [
                ["wait"],
                ["z"],
            ],
            reach: .notNeeded
        ) { _, frame in wait(frame) },

        .handled(
            .look,
            [
                ["look"],
                ["l"],
            ],
            reach: .notNeeded
        ) { _, frame in look(frame) },

        .handled(
            .inventory,
            [
                ["inventory"],
                ["inv"],
                ["i"],
            ],
            reach: .notNeeded
        ) { _, frame in inventory(frame) },

        .handled(.score, [["score"]], reach: .notNeeded) { _, frame in score(frame) },

        .handled(
            .quit,
            [
                ["quit"],
                ["q"],
            ],
            reach: .notNeeded
        ) { _, frame in quit(frame) },

        .handled(.version, [["version"]], reach: .notNeeded) { _, frame in version(frame) },

        // The engine-level four. They own rows so the parser knows the words and
        // the vocabulary reports them, but `GameWorld.run` acts on the actor's
        // snapshots and returns before any stage runs.
        .engineLevel(.undo, [["undo"]]),
        .engineLevel(.restart, [["restart"]]),
        .engineLevel(.save, [["save"]]),
        .engineLevel(.restore, [["restore"]]),
    ]

    /// Keyed for the stage-4 lookup — the same dispatch table the stub path
    /// uses, in place of the `switch` this replaced.
    static let coresByIntent: [Intent: CoreVerb] = Dictionary(
        uniqueKeysWithValues: cores.map { ($0.intent, $0) })

    /// Every intent stage 4 answers with real behavior. Used by Bootstrap to
    /// decide whether a game/bundle/plugin action row is overriding a built-in
    /// (warning) or giving a fresh intent its first default behavior (no
    /// warning).
    static let builtInIntents: Set<Intent> = Set(
        cores.lazy.filter { !$0.isEngineLevel }.map(\.intent))

    /// The intents the engine answers ahead of the pipeline. An `actions` row
    /// for one of these can never run, which is a warning rather than a
    /// silence — see ``CoreVerb/Behavior/engineLevel``.
    static let engineIntents: Set<Intent> = Set(
        cores.lazy.filter(\.isEngineLevel).map(\.intent))
}

extension SyntaxRule {
    /// The rows the engine backs with real behavior. Bootstrap keys its "you're
    /// overriding a built-in" warning off *this* table rather than
    /// ``standardTable``, which is what makes reclaiming a stub row silent: a
    /// stub has no behavior to shadow, so the warning would be noise.
    static let coreTable: [SyntaxRule] = DefaultActions.cores.flatMap(\.rows)
}
