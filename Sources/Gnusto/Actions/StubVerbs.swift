/// A verb the parser knows as a *word* even though the engine gives it no
/// *mechanic*: it is in the vocabulary, it resolves its objects through normal
/// scope, it costs a turn, and its default behavior is one line of prose.
///
/// `I don't know the word "attack"` tells the player the program is
/// unfinished. `Attacking things rarely improves them.` tells them the world
/// is. Stub verbs exist so a game gets the second answer for free, and so a
/// game that wants real behavior only has to add a rule — never teach the
/// parser a new word.
///
/// Nothing here is a special case in the parser. A stub is an ordinary row in
/// the standard table whose intent happens to have no mechanic behind it, so
/// every layer overrides it the ordinary way and none of them warns.
struct StubVerb: Sendable {
    /// The intent every one of `rows` produces.
    let intent: Intent

    /// The rows that reach this intent, built from the declared patterns so the
    /// intent is stated once. Kept beside the intent and the line so a stub
    /// can't be half-declared: rows with no line, or a line no row reaches,
    /// would both fall through to stage 4's last resort, so a word the engine
    /// advertises would answer "You can't do that."
    let rows: [SyntaxRule]

    /// The stock reply. Takes the whole command so a line can name the objects
    /// the player mentioned.
    let line: @Sendable (GameText, Command) -> String

    /// Which of this verb's object slots the player has to be able to *touch*.
    let reach: Reach

    /// Which object slots a stub needs within arm's reach, as opposed to merely
    /// in view.
    ///
    /// Parser scope is the *visible* set, which admits what can be seen through
    /// the glass of a shut jar or in somebody else's hands. Half this table is
    /// fine with that — you can smell a fire across a room and count coins
    /// behind glass — and half of it is nonsense at a distance, so the answer is
    /// per verb rather than a blanket guard.
    ///
    /// Three cases and not a `Bool` because the two-slot shapes disagree with
    /// each other: `give X to Y` has to reach the recipient, and `throw X at Y`
    /// must *not* have to reach the target, which is the whole point of
    /// throwing. Nothing wants the indirect object alone, so there is no case
    /// for it.
    enum Reach: Sendable {
        /// Works at a distance — or takes no object at all.
        case notNeeded
        /// The direct object must be reachable.
        case directObject
        /// Both objects must be reachable.
        case bothObjects
    }

    /// Patterns in, rows out — spelled the way `#verb` spells them, and the
    /// reason no row below has to repeat `intent:`.
    private init(
        _ intent: Intent,
        _ patterns: [[SyntaxElement]],
        _ reach: Reach,
        line: @escaping @Sendable (GameText, Command) -> String
    ) {
        self.intent = intent
        self.rows = patterns.map { SyntaxRule($0, intent: intent) }
        self.line = line
        self.reach = reach
    }
}

extension StubVerb {
    /// A stub whose reply never names an object — either because no row has an
    /// object slot, or because naming it wouldn't improve the line.
    static func plain(
        _ intent: Intent,
        _ patterns: [[SyntaxElement]],
        reach: Reach,
        _ line: @escaping @Sendable (GameText) -> String
    ) -> StubVerb {
        .init(intent, patterns, reach) { text, _ in line(text) }
    }

    /// A stub whose every row carries a direct object, so its reply can name
    /// it. The `didntUnderstand` fallback is unreachable through the parser —
    /// a row with a `.directObject` slot can't match without filling it — and
    /// exists so the promise "every row has an object" fails loudly in review
    /// rather than crashing a player's game.
    ///
    /// The player is the one object these lines can't name: it is called
    /// "yourself", so "The yourself is not food." That is why `named` checks for
    /// it and `plain` doesn't — a nameless line like "You smell nothing out of
    /// the ordinary." answers `smell me` perfectly well.
    ///
    /// Everybody *else* is the second object they can't name, for the sister
    /// reason: these lines are about objects, and "Mrs. Kettle is not food."
    /// puts a witness on the same footing as a chair. `cantSearchActor` has
    /// refused actor contact by design since the beginning, so before this
    /// guard `search the cook` and `eat the cook` gave opposite rulings one
    /// line apart.
    static func named(
        _ intent: Intent,
        _ patterns: [[SyntaxElement]],
        reach: Reach,
        _ line: @escaping @Sendable (GameText, String) -> String
    ) -> StubVerb {
        .init(intent, patterns, reach) { text, command in
            guard let object = command.directObject else { return text.didntUnderstand }
            guard !object.isPlayer else { return text.stubs.yourself }
            guard !object.isActor else { return text.stubs.somebodyElse(object.definiteNoun) }
            return line(text, object.definiteName)
        }
    }

    /// A `named` stub whose line carries a **verb agreeing with the object**, so
    /// the name alone is not enough to write it: "The rails is not food." is
    /// what a template gets for assuming the singular, and the game's only way
    /// out would be to rename its rails. These lines are handed a
    /// ``GameText/Noun`` and conjugate for themselves.
    ///
    /// Everything else about it is `named` — the same self and actor guards, for
    /// the same reasons.
    static func numbered(
        _ intent: Intent,
        _ patterns: [[SyntaxElement]],
        reach: Reach,
        _ line: @escaping @Sendable (GameText, GameText.Noun) -> String
    ) -> StubVerb {
        .init(intent, patterns, reach) { text, command in
            guard let object = command.directObject else { return text.didntUnderstand }
            guard !object.isPlayer else { return text.stubs.yourself }
            guard !object.isActor else { return text.stubs.somebodyElse(object.definiteNoun) }
            return line(text, object.definiteNoun)
        }
    }

    /// The escape hatch, for a reply that needs more of the ``Command`` than the
    /// direct object's name. `give` and `touch` want it today.
    static func custom(
        _ intent: Intent,
        _ patterns: [[SyntaxElement]],
        reach: Reach,
        _ line: @escaping @Sendable (GameText, Command) -> String
    ) -> StubVerb {
        .init(intent, patterns, reach, line: line)
    }
}

// MARK: - The intents

extension Intent {
    // Violence and force.

    /// Attack, kill, hit or fight something, bare-handed or with a weapon.
    /// `GnustoMeleeCombat` promotes this one to real behavior.
    public static let attack = Intent("attack")
    /// Break, smash or destroy something. Named `smash` because `break` is a
    /// Swift keyword and `.break` would need backticks at every rule site.
    public static let smash = Intent("smash")
    /// Set fire to something.
    public static let burn = Intent("burn")
    /// Cut or slice something.
    public static let cut = Intent("cut")
    /// Dig, bare-handed or with a tool.
    public static let dig = Intent("dig")
    /// Pull or drag something.
    public static let pull = Intent("pull")
    /// Turn or rotate something — distinct from `turnOn`/`turnOff`, which own
    /// the `turn … on`/`turn … off` shapes and outrank this one.
    public static let turn = Intent("turn")
    /// Squeeze something.
    public static let squeeze = Intent("squeeze")
    /// Shake something.
    public static let shake = Intent("shake")
    /// Knock on something.
    public static let knock = Intent("knock")
    /// Throw something at something. Named `throwAt` because `throw` is a
    /// Swift keyword.
    public static let throwAt = Intent("throwAt")

    // Senses.

    /// Touch, feel or rub something.
    public static let touch = Intent("touch")
    /// Smell the room, or something in it.
    public static let smell = Intent("smell")
    /// Listen to the room, or to something in it.
    public static let listen = Intent("listen")
    /// Taste or lick something.
    public static let taste = Intent("taste")

    // Body.

    /// Eat something.
    public static let eat = Intent("eat")
    /// Drink something.
    public static let drink = Intent("drink")
    /// Go to sleep.
    public static let sleep = Intent("sleep")
    /// Wake up, or wake somebody else.
    public static let wake = Intent("wake")

    // Social.

    /// Kiss or hug somebody.
    public static let kiss = Intent("kiss")
    /// Hand something to somebody.
    public static let give = Intent("give")
    /// Yell, shout or scream.
    public static let yell = Intent("yell")
    /// Wave, with or without something in hand.
    public static let wave = Intent("wave")
    /// Point at something.
    public static let point = Intent("point")

    // Motion.

    /// Climb something, or climb up, down or onto it.
    public static let climb = Intent("climb")
    /// Jump on the spot, or over something.
    public static let jump = Intent("jump")
    /// Swim.
    public static let swim = Intent("swim")
    /// Dive.
    public static let dive = Intent("dive")
    /// Stand, or stand up.
    public static let stand = Intent("stand")
    /// Sit, sit down, or sit on something.
    public static let sit = Intent("sit")
    /// Lie down.
    public static let lie = Intent("lie")
    /// Kneel.
    public static let kneel = Intent("kneel")

    // Liquids and containers.

    /// Fill something, optionally from something else.
    public static let fill = Intent("fill")
    /// Pour something out, or into or onto something else.
    public static let pour = Intent("pour")
    /// Empty something.
    public static let empty = Intent("empty")
    /// Tie something, optionally to something else.
    public static let tie = Intent("tie")
    /// Untie something, optionally from something else.
    public static let untie = Intent("untie")

    // Ritual and flavor.

    /// Pray.
    public static let pray = Intent("pray")
    /// Sing.
    public static let sing = Intent("sing")
    /// Curse or swear.
    public static let curse = Intent("curse")
    /// The genre's magic words, `xyzzy` and `plugh`, on one intent so a game
    /// answers both with one line — or reclaims either row on its own.
    public static let xyzzy = Intent("xyzzy")
    /// Count something.
    public static let count = Intent("count")
    /// Think.
    public static let think = Intent("think")
    /// Wish.
    public static let wish = Intent("wish")

    // Commerce.

    /// Buy something.
    public static let buy = Intent("buy")
    /// Sell something.
    public static let sell = Intent("sell")

    // Fixtures.

    /// Blow on something — distinct from `blow out`, which is `turnOff`.
    public static let blow = Intent("blow")
}

// MARK: - The table

extension DefaultActions {
    /// Every stub verb: its intent, its rows and its stock line, in one place.
    ///
    /// A note on shapes, because two of them are easy to get wrong:
    ///
    /// - **A bare `verb <object>` row suppresses the `missingIndirect` prompt**
    ///   from any `verb <object> PREP <second object>` row on the same verb
    ///   word, because the parser returns on the first row that *matches* and
    ///   only falls back to a near-miss when nothing matched. That is why
    ///   `give` and `throw` ship second-object-only: `give lamp` asking "What
    ///   do you want to give the lamp to?" beats a canned line.
    /// - **No row here uses a `.topic` slot.** A topic never fails to match, so
    ///   a low-specificity topic row silently absorbs the scope failures of
    ///   every more specific row sharing its verb word — `say hello to butler`
    ///   with no butler present would answer a stub line instead of "You can't
    ///   see any such thing." Conversation verbs belong to
    ///   `GnustoConversation`, which has a topic slot and an actor to check it
    ///   against.
    static let stubs: [StubVerb] = [
        // MARK: Violence and force

        // Melee, so it wants arm's length. Nothing is lost by saying so: the
        // ranged case has its own intent one row down. The weapon slot goes
        // unchecked — a stub doesn't check that you're holding it either.
        .plain(
            .attack,
            [
                ["attack", .directObject],
                ["attack", .directObject, "with", .indirectObject],
                ["kill", .directObject],
                ["kill", .directObject, "with", .indirectObject],
                ["hit", .directObject],
                ["hit", .directObject, "with", .indirectObject],
                ["fight", .directObject],
            ],
            reach: .directObject
        ) { $0.stubs.attack },

        .numbered(
            .smash,
            [
                ["break", .directObject],
                ["smash", .directObject],
                ["destroy", .directObject],
            ],
            reach: .directObject
        ) { $0.stubs.smash($1) },

        // Ships `with` for the same reason `attack`, `dig` and `fill` do: the
        // instrument is half the command. Without it `burn paper with match` is
        // a parse error, and every game that gates a fire on the right tinder
        // re-declares the identical row.
        .named(
            .burn,
            [
                ["burn", .directObject],
                ["burn", .directObject, "with", .indirectObject],
            ],
            reach: .directObject
        ) { $0.stubs.burn($1) },

        .named(
            .cut,
            [
                ["cut", .directObject],
                ["slice", .directObject],
            ],
            reach: .directObject
        ) { $0.stubs.cut($1) },

        // `dig <object> with <second object>` is what lets a game gate digging
        // on the right tool with a one-line item rule.
        .plain(
            .dig,
            [
                ["dig"],
                ["dig", .directObject],
                ["dig", .directObject, "with", .indirectObject],
            ],
            reach: .directObject
        ) { $0.stubs.dig },

        .numbered(
            .pull,
            [
                ["pull", .directObject],
                ["drag", .directObject],
            ],
            reach: .directObject
        ) { $0.stubs.pull($1) },

        .numbered(
            .turn,
            [
                ["turn", .directObject],
                ["rotate", .directObject],
            ],
            reach: .directObject
        ) { $0.stubs.turn($1) },

        .named(.squeeze, [["squeeze", .directObject]], reach: .directObject) {
            $0.stubs.squeeze($1)
        },

        .named(.shake, [["shake", .directObject]], reach: .directObject) { $0.stubs.shake($1) },

        .plain(
            .knock,
            [
                ["knock", .directObject],
                ["knock", "on", .directObject],
            ],
            reach: .directObject
        ) { $0.stubs.knock },

        // The projectile has to be in hand; the target emphatically does not.
        // This is the row shape a single `Bool` couldn't have described.
        .plain(
            .throwAt,
            [["throw", .directObject, "at", .indirectObject]],
            reach: .directObject
        ) { $0.stubs.throwAt },

        // MARK: Senses

        // `custom` rather than `plain`, for the one guard `named` gets for
        // free: "You feel nothing out of the ordinary." is a fine answer about
        // a wall and a claim about a completed act of contact on a witness, one
        // turn after `cantSearchActor` has refused to let the player put a hand
        // on her. `smell` and `listen` below need no such guard — both cross a
        // room and lay a hand on nobody — and neither do `taste` and `knock`,
        // which say nothing a person could object to.
        .custom(
            .touch,
            [
                ["touch", .directObject],
                ["feel", .directObject],
                ["rub", .directObject],
            ],
            reach: .directObject
        ) { text, command in
            guard let object = command.directObject, object.isActor, !object.isPlayer
            else { return text.stubs.touch }
            return text.stubs.somebodyElse(object.definiteNoun)
        },

        // A smell crosses a room, and so does a sound. These two are the reason
        // the guard is per verb.
        .plain(
            .smell,
            [
                ["smell"],
                ["smell", .directObject],
                ["sniff"],
                ["sniff", .directObject],
            ],
            reach: .notNeeded
        ) { $0.stubs.smell },

        .plain(
            .listen,
            [
                ["listen"],
                ["listen", "to", .directObject],
            ],
            reach: .notNeeded
        ) { $0.stubs.listen },

        .plain(
            .taste,
            [
                ["taste", .directObject],
                ["lick", .directObject],
            ],
            reach: .directObject
        ) { $0.stubs.taste },

        // MARK: Body

        .numbered(.eat, [["eat", .directObject]], reach: .directObject) { $0.stubs.eat($1) },

        .plain(.drink, [["drink", .directObject]], reach: .directObject) { $0.stubs.drink },

        .plain(.sleep, [["sleep"]], reach: .notNeeded) { $0.stubs.sleep },

        // `wake up <object>` earns its row: without it, "wake up the troll"
        // falls to `wake <object>`, which swallows "up troll", fails the
        // lexicon, and answers "You can't see any such thing" about a troll
        // standing in plain view.
        // No reach: a shout wakes somebody through glass.
        .plain(
            .wake,
            [
                ["wake"],
                ["wake", "up"],
                ["wake", .directObject],
                ["wake", "up", .directObject],
            ],
            reach: .notNeeded
        ) { $0.stubs.wake },

        // MARK: Social

        .plain(
            .kiss,
            [
                ["kiss", .directObject],
                ["hug", .directObject],
            ],
            reach: .directObject
        ) { $0.stubs.kiss },

        // The one stub that needs both slots: handing something over is contact
        // with the gift *and* with whoever is taking it.
        .custom(
            .give,
            [
                ["give", .directObject, "to", .indirectObject],
                ["hand", .directObject, "to", .indirectObject],
            ],
            reach: .bothObjects
        ) { text, command in
            guard let item = command.directObject, let recipient = command.indirectObject
            else { return text.didntUnderstand }
            // Either slot can be the player, and neither reads with its name.
            guard !item.isPlayer, !recipient.isPlayer else { return text.stubs.yourself }
            return text.stubs.give(item.definiteName, recipient.definiteNoun)
        },

        .plain(
            .yell,
            [
                ["yell"],
                ["shout"],
                ["scream"],
            ],
            reach: .notNeeded
        ) { $0.stubs.yell },

        // Waving a thing means waving a thing you've got hold of.
        .plain(
            .wave,
            [
                ["wave"],
                ["wave", .directObject],
            ],
            reach: .directObject
        ) { $0.stubs.wave },

        .plain(.point, [["point", "at", .directObject]], reach: .notNeeded) { $0.stubs.point },

        // MARK: Motion

        .plain(
            .climb,
            [
                ["climb"],
                ["climb", .directObject],
                ["climb", "up", .directObject],
                ["climb", "down", .directObject],
                ["climb", "on", .directObject],
            ],
            reach: .directObject
        ) { $0.stubs.climb },

        .plain(
            .jump,
            [
                ["jump"],
                ["jump", "over", .directObject],
            ],
            reach: .directObject
        ) { $0.stubs.jump },

        .plain(.swim, [["swim"]], reach: .notNeeded) { $0.stubs.swim },

        .plain(.dive, [["dive"]], reach: .notNeeded) { $0.stubs.dive },

        .plain(
            .stand,
            [
                ["stand"],
                ["stand", "up"],
            ],
            reach: .notNeeded
        ) { $0.stubs.stand },

        .plain(
            .sit,
            [
                ["sit"],
                ["sit", "down"],
                ["sit", "on", .directObject],
            ],
            reach: .directObject
        ) { $0.stubs.sit },

        // Bare `lie` earns its row for the same reason `sit down` does: `lie
        // down` puts "lie" in the vocabulary, so without it the word the engine
        // just claimed would answer `didntUnderstand`.
        .plain(
            .lie,
            [
                ["lie"],
                ["lie", "down"],
            ],
            reach: .notNeeded
        ) { $0.stubs.lie },

        .plain(.kneel, [["kneel"]], reach: .notNeeded) { $0.stubs.kneel },

        // MARK: Liquids and containers

        // These five check the vessel and not the second slot. The direct
        // object is the thing in the player's hands, and its refusal is the one
        // that reads right; whether you must also reach what you're tying the
        // rope *to* is a call for the day a game needs it.
        .named(
            .fill,
            [
                ["fill", .directObject],
                ["fill", .directObject, "with", .indirectObject],
            ],
            reach: .directObject
        ) { $0.stubs.fill($1) },

        .named(
            .pour,
            [
                ["pour", .directObject],
                ["pour", .directObject, "in", .indirectObject],
                ["pour", .directObject, "on", .indirectObject],
            ],
            reach: .directObject
        ) { $0.stubs.pour($1) },

        .named(.empty, [["empty", .directObject]], reach: .directObject) { $0.stubs.empty($1) },

        .named(
            .tie,
            [
                ["tie", .directObject],
                ["tie", .directObject, "to", .indirectObject],
            ],
            reach: .directObject
        ) { $0.stubs.tie($1) },

        .numbered(
            .untie,
            [
                ["untie", .directObject],
                ["untie", .directObject, "from", .indirectObject],
            ],
            reach: .directObject
        ) { $0.stubs.untie($1) },

        // MARK: Ritual and flavor

        .plain(.pray, [["pray"]], reach: .notNeeded) { $0.stubs.pray },

        .plain(.sing, [["sing"]], reach: .notNeeded) { $0.stubs.sing },

        .plain(
            .curse,
            [
                ["curse"],
                ["swear"],
            ],
            reach: .notNeeded
        ) { $0.stubs.curse },

        .plain(
            .xyzzy,
            [
                ["xyzzy"],
                ["plugh"],
            ],
            reach: .notNeeded
        ) { $0.stubs.xyzzy },

        // Counting coins behind glass is exactly what a display case is for.
        .plain(.count, [["count", .directObject]], reach: .notNeeded) { $0.stubs.count },

        // Bare `think` only. `think about <topic>` would match "think about"
        // with an empty topic and rob the parser of its "What do you want to
        // think about?" question.
        .plain(.think, [["think"]], reach: .notNeeded) { $0.stubs.think },

        .plain(.wish, [["wish"]], reach: .notNeeded) { $0.stubs.wish },

        // MARK: Commerce

        // Asking after the price of something in a window is ordinary shopping.
        .plain(.buy, [["buy", .directObject]], reach: .notNeeded) { $0.stubs.buy },

        .plain(.sell, [["sell", .directObject]], reach: .notNeeded) { $0.stubs.sell },

        // MARK: Fixtures

        .named(.blow, [["blow", .directObject]], reach: .directObject) { $0.stubs.blow($1) },
    ]

    /// Keyed for the stage-4 lookup.
    static let stubsByIntent: [Intent: StubVerb] = Dictionary(
        uniqueKeysWithValues: stubs.map { ($0.intent, $0) })

    /// The intents the engine answers with a line and no mechanic. Kept out of
    /// ``builtInIntents`` on purpose: a game reclaiming one is shadowing
    /// nothing, so it must not warn.
    static let stubIntents: Set<Intent> = Set(stubs.map(\.intent))

    /// Every intent stage 4 answers itself, whether with real behavior or a
    /// canned line. A rule watching one of these is never a dead intent.
    static let handledIntents: Set<Intent> = builtInIntents.union(stubIntents)
}

extension SyntaxRule {
    /// The rows that reach a stub verb. Merged into ``standardTable`` after the
    /// core rows, but kept separate so Bootstrap can tell the two apart:
    /// overriding a core row warns, overriding a stub row doesn't.
    static let stubTable: [SyntaxRule] = DefaultActions.stubs.flatMap(\.rows)
}
