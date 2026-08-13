/// A verb the parser knows as a *word* even though the engine gives it no
/// *mechanic*: it is in the vocabulary, it resolves its objects through normal
/// scope, it costs a turn, and its default behavior is one line of prose.
///
/// `I don't know the word "attack"` tells the player the program is
/// unfinished. `Attacking the chair rarely improves matters.` tells them the
/// world is. Stub verbs exist so a game gets the second answer for free, and so a
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

    /// Whether the line is offered the direct object's name — false only for
    /// `plain`, which discards the command.
    ///
    /// Stored so `everyStubWithAnObjectSlotCanNameIt` can assert the invariant
    /// twelve verbs quietly broke for a year: a row with a `.directObject` slot
    /// whose line has nowhere to put the name. That defect is invisible from
    /// either side on its own — the rows look right, the line looks right — and
    /// it is what #245 was filed about.
    let namesObject: Bool

    /// Patterns in, rows out — spelled the way `#verb` spells them, and the
    /// reason no row below has to repeat `intent:`.
    private init(
        _ intent: Intent,
        _ patterns: [[SyntaxElement]],
        _ reach: Reach,
        namesObject: Bool = true,
        line: @escaping @Sendable (GameText, Command) -> String
    ) {
        self.intent = intent
        self.rows = patterns.map { SyntaxRule($0, intent: intent) }
        self.line = line
        self.reach = reach
        self.namesObject = namesObject
    }
}

extension StubVerb {
    /// A stub with **no object slot on any row**, so there is nothing for its
    /// reply to name. `sing`, `pray`, `swim`. It discards the command entirely.
    ///
    /// Not for a verb that has an object and whose engine wording ignores it —
    /// that is `optionallyNamed`, and the difference is the whole of #245. A
    /// `plain` verb with a `.directObject` row is a game that can never say what
    /// the player was pointing at, and `everyStubWithAnObjectSlotCanNameIt`
    /// fails rather than letting one be written.
    static func plain(
        _ intent: Intent,
        _ patterns: [[SyntaxElement]],
        reach: Reach,
        _ line: @escaping @Sendable (GameText) -> String
    ) -> StubVerb {
        .init(intent, patterns, reach, namesObject: false) { text, _ in line(text) }
    }

    /// A stub whose reply **cannot be written without the name**: "You have no
    /// way to set fire to the paper." has nowhere to stand if the paper goes
    /// unmentioned. Its rows therefore all carry a direct object — but that
    /// alone is not what puts a verb here. `knock`, `taste` and `kiss` fill the
    /// slot on every row too, and are `optionallyNamed`, because their lines
    /// read perfectly well with the name left out.
    ///
    /// The `didntUnderstand` fallback is unreachable through the parser — a row
    /// with a `.directObject` slot can't match without filling it — and exists
    /// so the promise "every row has an object" fails loudly in review rather
    /// than crashing a player's game.
    ///
    /// The player is the one object these lines can't name: it is called
    /// "yourself", so "The yourself is not food." That is why `named` checks for
    /// it and `optionallyNamed` needn't — a line that owns a nameless half
    /// already answers `smell me` perfectly well, and takes that road instead of
    /// the generic deferral. `plain` never sees an object at all.
    ///
    /// Everybody *else* is the second object they can't name, for the sister
    /// reason: these lines are about objects, and "Mrs. Kettle is not food."
    /// puts a witness on the same footing as a chair. `cantSearchActor` has
    /// refused actor contact by design since the beginning, so before this
    /// guard `search the cook` and `eat the cook` gave opposite rulings one
    /// line apart. `optionallyNamed` decides this per verb instead, and most of
    /// it declines — see below for why that is a property of the line rather
    /// than a convenience.
    ///
    /// The line is handed a ``GameText/Noun`` rather than a rendered string, so
    /// that one whose verb agrees with the object can conjugate for itself; see
    /// ``GameText/Noun`` for what a template that assumes the singular does to a
    /// game's honest plural. Interpolating the noun prints its phrase, so a line
    /// with no verb to agree pays nothing for the facility.
    static func named(
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

    /// A stub whose line **owns a nameless half**, so it is handed an optional
    /// noun and has to read with a name and without one. Either of two things
    /// puts a verb here:
    ///
    /// - **Its rows don't all carry a direct object.** `smell` and `smell the
    ///   troll` are a single intent, and one sentence answers both; the
    ///   nameless rows hand the line `nil`.
    /// - **Its line reads perfectly well with the name left out.** `knock`,
    ///   `taste`, `kiss`, `count`, `buy` and `sell` fill the slot on every row,
    ///   and every one of their engine defaults mentions no object. Naming it
    ///   is something a *game* may want — "You would sooner kiss the pig." —
    ///   not something the engine's own wording needs, so the name is offered
    ///   rather than required.
    ///
    /// The player takes the nameless half too, for the reason `named` states —
    /// "It smells like yourself." is not a sentence — but where `named` defers
    /// to ``GameText/StubReplies/yourself``, here the line already owns the
    /// better answer.
    ///
    /// **No actor guard by default**, where `named` always has one, and that is
    /// a consequence rather than a convenience: a line with a nameless half is
    /// a line that can be said about anybody. "The troll makes no sound." is
    /// `V-LISTEN`'s own answer, and `kiss the troll` is what kissing is *for*,
    /// so a `somebodyElse` guard there would refuse the verb's only interesting
    /// input. `touch` is the one that has to keep it — laying hands on somebody
    /// is not the same as listening to them — and passes `guardsActors: true`
    /// rather than writing this body out again.
    ///
    /// Read that as a claim about the **engine's** wording, which is what the
    /// guard is here to keep honest. `taste` and `drink` reach their object, so
    /// a game that voices their naming half is writing about contact with a
    /// person and may well want the guard, or a rule, of its own. The engine
    /// declines because "You'd rather not." says nothing anybody could object
    /// to, not because the verb is harmless.
    static func optionallyNamed(
        _ intent: Intent,
        _ patterns: [[SyntaxElement]],
        reach: Reach,
        guardsActors: Bool = false,
        _ line: @escaping @Sendable (GameText, GameText.Noun?) -> String
    ) -> StubVerb {
        .init(intent, patterns, reach) { text, command in
            guard let object = command.directObject, !object.isPlayer else {
                return line(text, nil)
            }
            guard !guardsActors || !object.isActor else {
                return text.stubs.somebodyElse(object.definiteNoun)
            }
            return line(text, object.definiteNoun)
        }
    }

    /// The escape hatch, for a reply that needs more of the ``Command`` than the
    /// direct object's name. `give` wants it today, for its second slot.
    ///
    /// `namesObject` is a parameter here and nowhere else: the other four
    /// factories build the line and so know the answer, where this one is handed
    /// a closure it cannot inspect. Assuming `true` would let a `custom` stub
    /// that ignores its direct object pass `everyStubWithAnObjectSlotCanNameIt`
    /// vacuously — the one place the flag could lie.
    static func custom(
        _ intent: Intent,
        _ patterns: [[SyntaxElement]],
        reach: Reach,
        namesObject: Bool,
        _ line: @escaping @Sendable (GameText, Command) -> String
    ) -> StubVerb {
        .init(intent, patterns, reach, namesObject: namesObject, line: line)
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
        //
        // `named`, not `plain`: every row here carries a direct object, and
        // swinging at a person deserves `somebodyElse` rather than a line
        // that puts the cook on the same footing as a chair — the guard
        // `smash` and `cut` have always had.
        .named(
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
        ) { $0.stubs.attack($1) },

        .named(
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
        .optionallyNamed(
            .dig,
            [
                ["dig"],
                ["dig", .directObject],
                ["dig", .directObject, "with", .indirectObject],
            ],
            reach: .directObject
        ) { $0.stubs.dig($1) },

        .named(
            .pull,
            [
                ["pull", .directObject],
                ["drag", .directObject],
            ],
            reach: .directObject
        ) { $0.stubs.pull($1) },

        .named(
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

        .optionallyNamed(
            .knock,
            [
                ["knock", .directObject],
                ["knock", "on", .directObject],
            ],
            reach: .directObject
        ) { $0.stubs.knock($1) },

        // The projectile has to be in hand; the target emphatically does not.
        // This is the row shape a single `Bool` couldn't have described.
        //
        // The line is offered the **projectile**, not the target, even though
        // the target is the more interesting noun. The reach column already
        // elected the direct object, deliberately and against the intuitive
        // reading — reaching the target is the one thing throwing exists to
        // avoid — so a one-name line about the other slot would put the line and
        // the guard permanently out of step. A game that wants "The troll ducks"
        // wants both slots, which is `custom`, where `give` already is.
        .optionallyNamed(
            .throwAt,
            [["throw", .directObject, "at", .indirectObject]],
            reach: .directObject
        ) { $0.stubs.throwAt($1) },

        // MARK: Senses

        // The one sense verb that guards actors, for the reason `named` guards
        // them everywhere: "You feel nothing out of the ordinary." is a fine
        // answer about a wall and a claim about a completed act of contact on a
        // witness, one turn after `cantSearchActor` has refused to let the
        // player put a hand on her. `smell` and `listen` below need no such
        // guard — both cross a room and lay a hand on nobody — and neither do
        // `taste` and `knock`, which say nothing a person could object to. It
        // is the only one of the eighteen that takes it.
        .optionallyNamed(
            .touch,
            [
                ["touch", .directObject],
                ["feel", .directObject],
                ["rub", .directObject],
            ],
            reach: .directObject,
            guardsActors: true
        ) { $0.stubs.touch($1) },

        // A smell crosses a room, and so does a sound. These two are the reason
        // the guard is per verb.
        .optionallyNamed(
            .smell,
            [
                ["smell"],
                ["smell", .directObject],
                ["sniff"],
                ["sniff", .directObject],
            ],
            reach: .notNeeded
        ) { $0.stubs.smell($1) },

        .optionallyNamed(
            .listen,
            [
                ["listen"],
                ["listen", "to", .directObject],
            ],
            reach: .notNeeded
        ) { $0.stubs.listen($1) },

        .optionallyNamed(
            .taste,
            [
                ["taste", .directObject],
                ["lick", .directObject],
            ],
            reach: .directObject
        ) { $0.stubs.taste($1) },

        // MARK: Body

        .named(.eat, [["eat", .directObject]], reach: .directObject) { $0.stubs.eat($1) },

        .optionallyNamed(.drink, [["drink", .directObject]], reach: .directObject) { $0.stubs.drink($1) },

        .plain(.sleep, [["sleep"]], reach: .notNeeded) { $0.stubs.sleep },

        // `wake up <object>` earns its row: without it, "wake up the troll"
        // falls to `wake <object>`, which swallows "up troll", fails the
        // lexicon, and answers "You can't see any such thing" about a troll
        // standing in plain view.
        // No reach: a shout wakes somebody through glass.
        .optionallyNamed(
            .wake,
            [
                ["wake"],
                ["wake", "up"],
                ["wake", .directObject],
                ["wake", "up", .directObject],
            ],
            reach: .notNeeded
        ) { $0.stubs.wake($1) },

        // MARK: Social

        // **No actor guard, and this is the verb that proves the guard must stay
        // per verb.** Every other stub that reaches its object defers about a
        // person, so `kiss` looks like an oversight — but kissing somebody is
        // what the verb is *for*, and a `somebodyElse` deferral here would
        // refuse its only interesting input while `kiss the doorknob` sailed
        // through. Leave it.
        .optionallyNamed(
            .kiss,
            [
                ["kiss", .directObject],
                ["hug", .directObject],
            ],
            reach: .directObject
        ) { $0.stubs.kiss($1) },

        // The one stub that needs both slots: handing something over is contact
        // with the gift *and* with whoever is taking it.
        .custom(
            .give,
            [
                ["give", .directObject, "to", .indirectObject],
                ["hand", .directObject, "to", .indirectObject],
            ],
            reach: .bothObjects,
            namesObject: true
        ) { text, command in
            guard let item = command.directObject, let recipient = command.indirectObject
            else { return text.didntUnderstand }
            // Either slot can be the player, and neither reads with its name.
            guard !item.isPlayer, !recipient.isPlayer else { return text.stubs.yourself }
            return text.stubs.give(item.definiteNoun, recipient.definiteNoun)
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
        .optionallyNamed(
            .wave,
            [
                ["wave"],
                ["wave", .directObject],
            ],
            reach: .directObject
        ) { $0.stubs.wave($1) },

        .optionallyNamed(.point, [["point", "at", .directObject]], reach: .notNeeded) { $0.stubs.point($1) },

        // MARK: Motion

        .optionallyNamed(
            .climb,
            [
                ["climb"],
                ["climb", .directObject],
                ["climb", "up", .directObject],
                ["climb", "down", .directObject],
                ["climb", "on", .directObject],
            ],
            reach: .directObject
        ) { $0.stubs.climb($1) },

        .optionallyNamed(
            .jump,
            [
                ["jump"],
                ["jump", "over", .directObject],
            ],
            reach: .directObject
        ) { $0.stubs.jump($1) },

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

        .optionallyNamed(
            .sit,
            [
                ["sit"],
                ["sit", "down"],
                ["sit", "on", .directObject],
            ],
            reach: .directObject
        ) { $0.stubs.sit($1) },

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

        .named(
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
        .optionallyNamed(.count, [["count", .directObject]], reach: .notNeeded) { $0.stubs.count($1) },

        // Bare `think` only. `think about <topic>` would match "think about"
        // with an empty topic and rob the parser of its "What do you want to
        // think about?" question.
        .plain(.think, [["think"]], reach: .notNeeded) { $0.stubs.think },

        .plain(.wish, [["wish"]], reach: .notNeeded) { $0.stubs.wish },

        // MARK: Commerce

        // Asking after the price of something in a window is ordinary shopping.
        .optionallyNamed(.buy, [["buy", .directObject]], reach: .notNeeded) { $0.stubs.buy($1) },

        .optionallyNamed(.sell, [["sell", .directObject]], reach: .notNeeded) { $0.stubs.sell($1) },

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

    /// Which object slots an intent needs within arm's reach — the `reach:`
    /// column of whichever half of the standard table declares it, read through
    /// the two dispatch tables `run(_:frame:)` already uses rather than a third
    /// keyed copy of them.
    ///
    /// A custom intent is in neither and takes ``Reach/notNeeded``: a verb the
    /// game invented is a verb the game defines the reach of, in its own rule.
    static func reachRequirement(of intent: Intent) -> Reach {
        coresByIntent[intent]?.reach ?? stubsByIntent[intent]?.reach ?? .notNeeded
    }
}

extension SyntaxRule {
    /// The rows that reach a stub verb. Merged into ``standardTable`` after the
    /// core rows, but kept separate so Bootstrap can tell the two apart:
    /// overriding a core row warns, overriding a stub row doesn't.
    static let stubTable: [SyntaxRule] = DefaultActions.stubs.flatMap(\.rows)
}
