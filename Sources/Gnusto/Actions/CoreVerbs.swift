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
        _ intent: Intent, _ patterns: [[SyntaxElement]], _ reach: Reach,
        displayVerb: String? = nil, _ behavior: Behavior
    ) {
        self.intent = intent
        self.rows = patterns.map { SyntaxRule($0, intent: intent, displayVerb: displayVerb) }
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
    /// - Parameters:
    ///   - intent: the intent every row produces.
    ///   - patterns: the rows, spelled as the player types them.
    ///   - reach: which slots the player has to be able to touch.
    ///   - displayVerb: what a prompt calls this verb, for a verb whose rows
    ///     lead with an abbreviation — see ``SyntaxRule/displayVerb``. Left off,
    ///     each row speaks in its own words.
    ///   - handler: what answers the intent at stage 4.
    /// - Returns: the verb, with one row per pattern.
    static func handled(
        _ intent: Intent,
        _ patterns: [[SyntaxElement]],
        reach: Reach,
        displayVerb: String? = nil,
        _ handler: @escaping @Sendable (Command, TurnFrame) throws -> Void
    ) -> CoreVerb {
        .init(intent, patterns, reach, displayVerb: displayVerb, .handler(handler))
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
                ["take", .directObject, "from", .indirectObject],
                ["take", .directObject, "off", .indirectObject],
                ["take", .directObject, "out", "of", .indirectObject],
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
            reach: .notNeeded,
            // The one core verb whose rows lead with an abbreviation, and so
            // the one that has to say what to call itself: bare `x` asked "What
            // do you want to x?" and `l at` asked "What do you want to l at?"
            // — questions in a language nobody speaks. Every other verb's rows
            // are words, and each of them asks in its own.
            displayVerb: "examine"
        ) { try examine($0, frame: $1) },

        .handled(.read, [["read", .directObject]], reach: .notNeeded) { try read($0, frame: $1) },

        .handled(
            .wear,
            [
                ["wear", .directObject],
                ["don", .directObject],
                ["put", "on", .directObject],
                // The trailing-particle spelling, and the reason `putOn` above
                // has to stay more specific than this: `put the cloak on` is
                // WEAR, `put the cloak on the hook` is not. `putOn`'s row
                // carries a second object slot and so outscores this one, which
                // is what keeps the surface reading first — this row only ever
                // sees the line that has nothing after the particle.
                ["put", .directObject, "on"],
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
                ["drop", .directObject, "on", .indirectObject],
                ["hang", .directObject, "on", .indirectObject],
                ["place", .directObject, "on", .indirectObject],
            ],
            reach: .bothObjects
        ) { try putOn($0, frame: $1) },

        .handled(
            .putIn,
            [
                ["put", .directObject, "in", .indirectObject],
                ["drop", .directObject, "in", .indirectObject],
                // INTO folds to IN, so this one row buys `insert the coin into
                // the slot` as well as `insert the coin in the slot`.
                ["insert", .directObject, "in", .indirectObject],
            ],
            reach: .bothObjects
        ) { try putIn($0, frame: $1) },

        .handled(
            .open,
            [
                ["open", .directObject],
                ["open", .directObject, "with", .indirectObject],
            ],
            reach: .directObject
        ) { try open($0, frame: $1) },

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
                // SEARCH IN is a spelling of LOOK IN, and only a row can say
                // so: with none, `in the sack` is a noun phrase, and SEARCH
                // answers a thing the room just described with "You can't see
                // any such thing". The literal synonyms then buy INSIDE and
                // INTO on top of it, for this row and for LOOK IN alike.
                // Issue #269.
                ["search", "in", .directObject],
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
                // CLIMB UP and CLIMB DOWN are a walk, which is what a player
                // standing at the foot of a staircase means by them. Bare CLIMB
                // still reaches the stub verb three games have voiced for
                // themselves — see `StandardParser.FitOutcome.emptyDirection`.
                ["climb", .direction],
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

        // Bare "hello" and "hi" are here, and used not to be. The argument for
        // leaving them out was that a game likes to own a one-word verb
        // outright and a built-in row would make it warn at launch — but the
        // bootstrap's warning compares the *intent* as well as the shape, so a
        // game that spells `SyntaxRule("hello", intent: .greet)` reclaims a row
        // for the intent that already held it and says nothing. What the
        // absence cost was the answer: bare `hello` matched only
        // `hello <object>`, so a player who said hello to a room was asked
        // "What do you want to hello?" `greet` has read the room since it was
        // written — `greetsTheRoom` when somebody is in it, `nobodyToGreet`
        // when nobody is — and these two rows are what reach that branch.
        .handled(
            .greet,
            [
                ["greet", .directObject],
                ["hello", .directObject],
                ["hi", .directObject],
                ["greet"],
                ["hello"],
                ["hi"],
                // The two rows `GnustoConversation` also mints. They are here
                // because "say hello to the troll" is what a player types at a
                // person, and a game without the conversation plugin answered
                // it with "That sentence isn't one I recognize." Bare "say" is
                // still nobody's verb — these are three-word patterns, so a
                // game that owns SAY outright keeps it.
                ["say", "hello", "to", .directObject],
                ["say", "hi", "to", .directObject],
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
                ["leave"],
                ["leave", .directObject],
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
        // "load" is the word a player who has just typed SAVE reaches for next,
        // and it is plumbing rather than fiction, so no game has to opt in.
        .engineLevel(.restore, [["restore"], ["load"]]),
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
