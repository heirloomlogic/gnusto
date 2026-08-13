import GnustoTestSupport
import Testing

@testable import Gnusto

/// Stub verbs: the words the parser knows even where the engine has no
/// mechanic. The contract is four-part — in the vocabulary, resolving objects
/// through normal scope, costing a turn, and overridable at every layer without
/// a warning — and each part gets its own section below.
struct StubVerbTests {
    // MARK: - The table holds together

    /// The standard table had no validation before stub verbs arrived, and stub
    /// verbs roughly doubled it. These are the invariants that make the
    /// core/stub split sound; each one, violated, is a silent failure rather
    /// than a crash.
    @Test func theStandardTableIsWellFormed() {
        let problems = SyntaxRule.standardTable.flatMap(\.patternProblems)
        #expect(problems.isEmpty, "\(problems)")

        let keys = SyntaxRule.standardTable.map(\.key)
        #expect(keys.count == Set(keys).count, "duplicate rows in the standard table")

        // No stub row may quietly replace a core row, or the core row's real
        // behavior would vanish with no warning.
        let coreKeys = Set(SyntaxRule.coreTable.map(\.key))
        let stubKeys = Set(SyntaxRule.stubTable.map(\.key))
        #expect(coreKeys.isDisjoint(with: stubKeys))

        // A rule literal that is also a noise word could never match, because
        // noise words are stripped from input but not from patterns.
        let literals = Set(SyntaxRule.standardTable.flatMap(\.literalWords))
        #expect(literals.isDisjoint(with: Vocabulary.defaultNoiseWords))
    }

    /// A stub intent that is *also* a built-in would make `action(.dig)` warn
    /// again and put two answers in `run`'s reach for one intent. Both sets are
    /// hand-maintained, so nothing but this check keeps them apart.
    ///
    /// The neighbouring invariants — every stub row reaching a line, every stub
    /// intent having rows — are deliberately not asserted here: `StubVerb` builds
    /// its rows *from* its intent, so they hold by construction and a test could
    /// only restate the initializer.
    @Test func noStubIntentIsAlsoABuiltIn() {
        #expect(DefaultActions.builtInIntents.isDisjoint(with: DefaultActions.stubIntents))
    }

    /// A topic slot never fails to match, so a low-specificity topic row would
    /// silently swallow the scope failures of every more specific row sharing
    /// its verb word — turning "You can't see any such thing." into a canned
    /// line. That is why conversation verbs are `GnustoConversation`'s, and why
    /// no stub row may grow a topic slot later.
    @Test func noStubRowUsesATopicSlot() {
        #expect(!SyntaxRule.stubTable.contains { $0.elements.contains(.topic) })
    }

    // MARK: - Every stub answers

    /// One command per stub row, spelled out by hand rather than generated from
    /// the table — a generated list would assert only that the table equals
    /// itself. Nouns come from ``StubLab``, which declares no verbs of its own.
    static let everyStubCommand = [
        // Violence and force.
        "attack rat", "attack rat with rod", "kill rat", "kill rat with rod",
        "hit rat", "hit rat with rod", "fight rat",
        "break rod", "smash rod", "destroy rod",
        "burn rod", "burn rod with flask", "cut rod", "slice rod",
        "dig", "dig bench", "dig bench with rod",
        "pull rod", "drag rod", "turn rod", "rotate rod",
        "squeeze rod", "shake rod", "knock bench", "knock on bench",
        "throw rod at rat",
        // Senses.
        "touch rod", "feel rod", "rub rod",
        "smell", "smell rod", "sniff", "sniff rod",
        "listen", "listen to rat", "taste rod", "lick rod",
        // Body.
        "eat rod", "drink flask", "sleep",
        "wake", "wake up", "wake rat", "wake up rat",
        // Social.
        "kiss rat", "hug rat", "give rod to rat", "hand rod to rat",
        "yell", "shout", "scream", "wave", "wave rod", "point at rat",
        // Motion.
        "climb", "climb bench", "climb up bench", "climb down bench", "climb on bench",
        "jump", "jump over bench", "swim", "dive",
        "stand", "stand up", "sit", "sit down", "sit on bench", "lie", "lie down", "kneel",
        // Liquids and containers.
        "fill flask", "fill flask with rod",
        "pour flask", "pour flask in flask", "pour flask on bench",
        "empty flask", "tie rod", "tie rod to bench",
        "untie rod", "untie rod from bench",
        // Ritual and flavor.
        "pray", "sing", "curse", "swear", "xyzzy", "plugh",
        "count rod", "think", "wish",
        // Commerce and fixtures.
        "buy rod", "sell rod", "blow rod",
    ]

    /// Ties the hand-written list to the table, so a stub row added later can't
    /// ship untested while this file still reads as exhaustive.
    @Test func everyStubRowHasACommandInTheList() {
        #expect(Self.everyStubCommand.count == SyntaxRule.stubTable.count)
    }

    @Test(arguments: StubVerbTests.everyStubCommand)
    func everyStubVerbAnswersInVoice(_ command: String) async throws {
        let turn = turnOutput(of: command, in: try await play(StubLab(), [command]))
        #expect(!turn.contains("I don't know the word"), "\(command): \(turn)")
        #expect(!turn.contains("I didn't understand"), "\(command): \(turn)")
        // A slot the command didn't fill would prompt instead of answering.
        #expect(!turn.contains("What do you want to"), "\(command): \(turn)")
        #expect(!turn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(command)")
    }

    /// Acceptance, from the issue: the thirteen turns that opened it. Every one
    /// of these used to say `I don't know the word`.
    @Test func theOpeningComplaintIsAnswered() async throws {
        let commands = [
            "attack the bench", "sing", "smell", "listen", "kiss the rat",
            "climb the bench", "jump", "dig", "buy rod",
        ]
        let transcript = try await play(StubLab(), commands)
        #expect(!transcript.contains("I don't know the word"))
        #expect(!transcript.contains("I didn't understand"))
    }

    // MARK: - Scope stays honest

    /// A stub must not buy politeness by weakening scope. The grue is a word the
    /// game knows and an object never in view, so the complaint is about the
    /// noun.
    @Test func attackingSomethingNotHereBlamesTheNoun() async throws {
        let turn = turnOutput(of: "attack the grue", in: try await play(GrueLab(), ["attack the grue"]))
        #expect(turn.contains("You can't see any such thing."))
        #expect(!turn.contains("I don't know the word"))
    }

    /// And where the game has never heard the noun at all, the complaint names
    /// *the noun* — the sharper half of the same promise, since it shows the
    /// blame moved off the verb rather than merely being suppressed.
    @Test func attackingAWordTheGameNeverHeardBlamesThatWord() async throws {
        let turn = turnOutput(
            of: "attack the grue", in: try await play(StubLab(), ["attack the grue"]))
        #expect(turn.contains(#"I don't know the word "grue"."#))
        #expect(!turn.contains(#""attack""#))
    }

    // MARK: - Reach stays honest too

    /// Scope is *visible* items, so the coin in the shut glass case can be
    /// named; touching it is another matter. Every stub that acts on its object
    /// with a hand refuses the same way `push` does — the complaint that opened
    /// the issue was that `push water` and `squeeze water` disagreed through the
    /// same glass.
    ///
    /// One command per `.directObject` stub, so the day a verb's reach is
    /// downgraded by accident this list is what fails.
    static let everyReachingStubCommand = [
        "attack coin", "smash coin", "burn coin", "cut coin", "dig coin",
        "pull coin", "turn coin", "squeeze coin", "shake coin", "knock on coin",
        "throw coin at rod", "touch coin", "taste coin", "eat coin", "drink coin",
        "kiss coin", "give coin to rod", "wave coin", "climb coin",
        "jump over coin", "sit on coin",
        "fill coin", "pour coin", "empty coin", "tie coin", "untie coin",
        "blow coin",
    ]

    @Test(arguments: StubVerbTests.everyReachingStubCommand)
    func aStubThatNeedsReachRefusesThroughTheGlass(_ command: String) async throws {
        let turn = turnOutput(of: command, in: try await play(ReachLab(), [command]))
        #expect(turn.contains("You can't reach the gold coin."), "\(command): \(turn)")
    }

    /// And the other half of the set, which a blanket guard would have broken:
    /// you can smell a fire across a room and count coins behind glass. One
    /// command per stub that takes an object and doesn't need to touch it.
    static let everyDistantStubCommand = [
        "smell coin", "listen to coin", "point at coin", "count coin",
        "buy coin", "sell coin", "wake coin",
    ]

    @Test(arguments: StubVerbTests.everyDistantStubCommand)
    func aStubThatWorksAtADistanceStillAnswersThroughTheGlass(
        _ command: String
    ) async throws {
        let turn = turnOutput(of: command, in: try await play(ReachLab(), [command]))
        #expect(!turn.contains("can't reach"), "\(command): \(turn)")
        #expect(!turn.contains("can't see any such thing"), "\(command): \(turn)")
    }

    /// The issue's exact complaint, in one transcript: the core verb and the
    /// stub now answer the same question the same way.
    @Test func aStubRefusesReachInTheSameWordsAsACoreVerb() async throws {
        let transcript = try await play(ReachLab(), ["push coin", "squeeze coin"])
        let refusal = "You can't reach the gold coin."
        #expect(turnOutput(of: "push coin", in: transcript).contains(refusal))
        #expect(turnOutput(of: "squeeze coin", in: transcript).contains(refusal))
    }

    /// The guard is reach and nothing else: open the case and the same command
    /// gets its stock line.
    @Test func openingTheCaseLetsTheReachingStubsThrough() async throws {
        let transcript = try await play(ReachLab(), ["squeeze coin", "open case", "shake coin"])
        #expect(turnOutput(of: "squeeze coin", in: transcript).contains("You can't reach"))
        #expect(
            turnOutput(of: "shake coin", in: transcript)
                .contains("You shake the gold coin. Nothing rattles loose."))
    }

    /// The two-slot shapes, which is why the flag isn't a `Bool`. `give` needs
    /// the recipient in reach — handing something over is contact.
    @Test func givingNeedsToReachTheRecipientAndNotJustTheGift() async throws {
        let turn = turnOutput(
            of: "give rod to doll", in: try await play(ReachLab(), ["give rod to doll"]))
        #expect(turn.contains("You can't reach the porcelain doll."))
    }

    /// And `throw … at …` needs the opposite: reaching the target is the one
    /// thing throwing exists to avoid. Only the projectile is checked.
    @Test func throwingNeedsToReachTheProjectileAndNotTheTarget() async throws {
        let transcript = try await play(ReachLab(), ["throw rod at doll", "throw doll at rod"])
        #expect(
            turnOutput(of: "throw rod at doll", in: transcript)
                .contains("Throwing things about achieves nothing."))
        #expect(
            turnOutput(of: "throw doll at rod", in: transcript)
                .contains("You can't reach the porcelain doll."))
    }

    /// The engine's other visible-but-not-reachable case: what somebody else is
    /// holding. A stub must answer it the way `take` already does.
    @Test func aStubCantReachIntoAnActorsHandsEither() async throws {
        let transcript = try await play(ReachLab(), ["take crust", "squeeze crust"])
        let refusal = "You can't reach the bread crust."
        #expect(turnOutput(of: "take crust", in: transcript).contains(refusal))
        #expect(turnOutput(of: "squeeze crust", in: transcript).contains(refusal))
    }

    /// The player is always to hand, in the dark and everywhere else, so the
    /// reach guard never comes between them and their own "yourself" line.
    @Test func youAreAlwaysWithinReachOfYourself() async throws {
        let turn = turnOutput(of: "squeeze me", in: try await play(ReachLab(), ["squeeze me"]))
        #expect(turn.contains("Best leave yourself out of it."))
    }

    /// A stub that refuses for reach is still a stub: `refuse` passes world
    /// time, so the turn costs one exactly like the stock line does.
    @Test func refusingForReachStillCostsATurn() async throws {
        let transcript = try await play(ReachLab(), ["score", "squeeze coin", "score"])
        let scores = transcript.components(separatedBy: "> score")
        #expect(scores[1].contains("in 0 turns"))
        #expect(scores[2].contains("in 1 turn"))
    }

    /// A door is never placed in a room — it hangs off the exits — so it enters
    /// scope by its own route. It is reachable from either side, and the verb a
    /// player tries on a shut door must not start refusing.
    @Test func aDoorIsWithinReachFromEitherSideOfIt() async throws {
        let turn = turnOutput(
            of: "knock on door", in: try await play(LockedDoorGame(), ["knock on door"]))
        #expect(turn.contains("Nobody answers."))
    }

    /// Ties both hand-written lists above to the table, the way
    /// ``everyStubRowHasACommandInTheList`` ties the big one: a stub added
    /// later — or a reach quietly downgraded later — must not slip past a file
    /// that still reads as exhaustive.
    @Test func theTwoReachListsCoverEveryStubTheyClaimTo() {
        let takesAnObject = { (stub: StubVerb) in
            stub.rows.contains { $0.elements.contains(.directObject) }
        }
        let reaching = DefaultActions.stubs.filter { $0.reach != .notNeeded }
        #expect(reaching.count == Self.everyReachingStubCommand.count)

        let distant = DefaultActions.stubs.filter { $0.reach == .notNeeded && takesAnObject($0) }
        #expect(distant.count == Self.everyDistantStubCommand.count)
    }

    /// A reach value that guards a slot the verb's rows don't have would be a
    /// check that never runs — the same class of silent drift the core/stub
    /// tables are shaped to make unrepresentable.
    @Test func everyStubGuardsOnlySlotsItsRowsActuallyHave() {
        for stub in DefaultActions.stubs {
            switch stub.reach {
            case .notNeeded:
                continue
            case .directObject:
                #expect(
                    stub.rows.contains { $0.elements.contains(.directObject) },
                    "\(stub.intent) guards a direct object it never takes")
            case .bothObjects:
                #expect(
                    stub.rows.allSatisfy { $0.elements.contains(.indirectObject) },
                    "\(stub.intent) guards an indirect object one of its rows never takes")
            }
        }
    }

    // MARK: - A stub costs a turn

    /// The substantive difference from the parse error a stub replaces: flailing
    /// at the bench takes time. Both halves in one transcript, because the
    /// contrast is the point and a later change could quietly flip either.
    @Test func aStubCostsATurnAndAParseErrorDoesNot() async throws {
        let transcript = try await play(StubLab(), ["frotz", "score", "xyzzy", "score"])
        let scores = transcript.components(separatedBy: "> score")
        #expect(scores[1].contains("in 0 turns"))
        #expect(scores[2].contains("in 1 turn"))
    }

    // MARK: - Overriding is silent at every layer

    /// Claiming a stub verb's exact shape for your own intent. The warning
    /// exists to catch accidental shadowing of real behavior; a stub has none,
    /// so the warning would be noise.
    @Test func claimingAStubsShapeWarnsNothing() async throws {
        let (definition, _) = try Bootstrap.build(OwnAttackRowGame())
        #expect(definition.warnings.isEmpty, "\(definition.warningReport ?? "no report")")

        let rows = definition.syntaxRules.filter {
            $0.elements == [.word("attack"), .directObject]
        }
        #expect(rows.count == 1)
        #expect(rows.first?.intent == Intent("brawl"))

        let transcript = try await play(OwnAttackRowGame(), ["attack dummy"])
        #expect(transcript.contains("You brawl with the dummy."))
    }

    /// An `actions` row for a stub intent, and an item rule for one. Neither is
    /// shadowing anything, so neither warns — and the item rule must not trip
    /// the dead-intent check either, since the engine's own rows produce it.
    @Test func promotingAStubWarnsNothing() throws {
        let (action, _) = try Bootstrap.build(StubPrecedenceGame())
        #expect(action.warnings.isEmpty, "\(action.warningReport ?? "no report")")

        let (rule, _) = try Bootstrap.build(AttackableDummyGame())
        #expect(rule.warnings.isEmpty, "\(rule.warningReport ?? "no report")")
    }

    /// The contrast that keeps the carve-out honest. Overriding a *core* verb
    /// still warns, at both the row and the action layer — so anyone tempted to
    /// simplify the split by widening `builtInKeys` back to `standardTable`
    /// fails here rather than in a game six months from now.
    @Test func overridingARealBuiltInStillWarns() throws {
        let (verb, _) = try Bootstrap.build(VerbOverrideGame())
        #expect(verb.warnings.contains { $0.contains("overrides a built-in verb") })

        let (action, _) = try Bootstrap.build(ThemedTakeGame())
        #expect(action.warnings.contains { $0.contains("overrides the built-in default") })
    }

    // MARK: - Precedence

    /// `text.stubs.x` re-skins one line and leaves its neighbours alone — the
    /// cheapest way to put a stub in the game's own voice.
    @Test func overridingTheStubTextReSkinsJustThatLine() async throws {
        let transcript = try await play(ReskinnedStubGame(), ["sing", "pray"])
        #expect(turnOutput(of: "sing", in: transcript).contains("You are asked, politely, to stop."))
        #expect(turnOutput(of: "pray", in: transcript).contains("Your prayers go unanswered."))
    }

    /// Item rule beats `actions` row beats the engine's line. The first two
    /// share a transcript; the third needs a game with no row at all, since a
    /// registered row is what hides the default.
    @Test func anItemRuleBeatsAnActionRowBeatsTheStubLine() async throws {
        let promoted = try await play(StubPrecedenceGame(), ["attack dummy", "attack rock"])
        #expect(turnOutput(of: "attack dummy", in: promoted).contains("The dummy takes it well."))
        #expect(turnOutput(of: "attack rock", in: promoted).contains("You flail at the scenery."))

        // The rod, not the rat: `attack` is a `named` stub, so a person goes
        // to `somebodyElse` and never reaches the line under test.
        let bare = try await play(StubLab(), ["attack rod"])
        #expect(bare.contains("Attacking the brass rod rarely improves matters."))
    }

    /// `attack` was the last stub that would name a person the way it names a
    /// chair — it shipped as `plain`, so *attack the rat* answered "Attacking
    /// things rarely improves them." while *break the rat* one row over had
    /// deferred to `somebodyElse` all along. Now the whole family agrees.
    @Test func attackingAPersonRefusesTheWayEveryOtherStubDoes() async throws {
        let transcript = try await play(StubLab(), ["attack rat", "break rat"])
        let swing = turnOutput(of: "attack rat", in: transcript)
        #expect(swing.contains("The grey rat is a person, and would rather you didn't."))
        #expect(!swing.contains("rarely improves matters"))
        let smash = turnOutput(of: "break rat", in: transcript)
        #expect(smash.contains("The grey rat is a person, and would rather you didn't."))
    }

    // MARK: - Nouns that are plural

    /// The defect this closes: `GameText.stubs.eat` hard-coded a singular
    /// copula, so a game with rails in it printed *"The rails is not food."* and
    /// its only escape was to rename them. Every stub line whose verb agrees
    /// with its object now asks the object's number instead.
    @Test func everyStubWhoseVerbAgreesWithItsObjectAgreesInThePlural() async throws {
        let transcript = try await play(
            StubLab(), ["eat scales", "break scales", "pull scales", "turn scales", "untie scales"])
        expectInOrder(
            transcript,
            [
                "The scales are not food.",
                "The scales are sturdier than that.",
                "The scales don't budge.",
                "The scales don't turn.",
                "The scales aren't tied to anything.",
            ])
    }

    /// The other half, so the plural branch cannot quietly become the only one.
    @Test func aSingularNounStillTakesTheSingularVerb() async throws {
        let transcript = try await play(
            StubLab(), ["eat rod", "break rod", "pull rod", "turn rod", "untie rod"])
        expectInOrder(
            transcript,
            [
                "The brass rod is not food.",
                "The brass rod is sturdier than that.",
                "The brass rod doesn't budge.",
                "The brass rod doesn't turn.",
                "The brass rod isn't tied to anything.",
            ])
    }

    /// The trait reaches the listing article too, since English has no plural
    /// indefinite of its own: "a scales" was as wrong as "the scales is".
    ///
    /// The listing *verb* went the same way in #246. This assertion read
    /// "There is some scales here." until then — the article fixed and the
    /// copula still disagreeing with it, in one sentence.
    @Test func aPluralNounIsListedWithSomeRatherThanAn() async throws {
        let transcript = try await play(StubLab(), ["look"])
        #expect(transcript.contains("There are some scales here."))
        #expect(!transcript.contains("a scales"))
    }

    // MARK: - Aimed at yourself

    /// The player is an entity, and it is called "yourself" — so a stub line
    /// that names its object would read "The yourself is not food." Every
    /// name-carrying stub defers instead.
    @Test(arguments: [
        "attack me", "break me", "burn me", "cut me", "pull me", "turn me",
        "squeeze me", "shake me", "eat me", "fill me", "tie me", "untie me",
        "pour me", "empty me", "blow me", "give rod to me", "give me to rat",
    ])
    func stubVerbsAimedAtYourselfNeverSayTheYourself(_ command: String) async throws {
        let turn = turnOutput(of: command, in: try await play(StubLab(), [command]))
        #expect(!turn.lowercased().contains("the yourself"), "\(command): \(turn)")
        #expect(!turn.contains("I didn't understand"), "\(command): \(turn)")
    }

    /// But a stub whose line owns a nameless half takes that half instead, and
    /// keeps its own answer rather than the generic deferral. `taste` is here
    /// rather than above because since #245 it is one of these too — the line
    /// no longer names nothing, it declines to.
    @Test func aStubWithANamelessHalfUsesItForYourself() async throws {
        let transcript = try await play(StubLab(), ["smell me", "listen to me", "taste me"])
        #expect(turnOutput(of: "smell me", in: transcript).contains("nothing out of the ordinary"))
        #expect(turnOutput(of: "listen to me", in: transcript).contains("You hear nothing"))
        #expect(turnOutput(of: "taste me", in: transcript).contains("You'd rather not."))
    }

    // MARK: - The eighteen lines that may name their object

    /// `smell`, `listen`, `touch`, `wave`, `wake` and `climb` are handed an
    /// **optional** name, because some of their rows carry no object at all.
    /// The whole contract in one transcript.
    @Test func anOptionallyNamedStubNamesWhatItCanAndNothingItCannot() async throws {
        let transcript = try await play(
            NamingStubGame(),
            ["smell rod", "smell", "smell me", "listen to rat", "touch rat", "touch rod"])

        // The named half: the line gets the object it was given.
        #expect(turnOutput(of: "smell rod", in: transcript).contains("It smells like the brass rod."))

        // The nameless half, which a bare row falls back to…
        #expect(turnOutput(of: "smell", in: transcript).contains("You smell only the room."))

        // …and so does the player, who has no name that renders: "It smells
        // like yourself." is why, and it is why these six defer here rather
        // than to `stubs.yourself` the way a name-carrying stub does.
        #expect(turnOutput(of: "smell me", in: transcript).contains("You smell only the room."))

        // No `somebodyElse` guard: these verbs act at a distance and read fine
        // about a person, which is what `V-LISTEN` itself does.
        #expect(turnOutput(of: "listen to rat", in: transcript).contains("The grey rat makes no sound."))

        // `touch` is the exception, and keeps the guard — laying hands on
        // somebody is not the same as listening to them.
        #expect(turnOutput(of: "touch rat", in: transcript).contains("would rather you didn't"))
        #expect(turnOutput(of: "touch rod", in: transcript).contains("Fiddling with the brass rod"))
    }

    // MARK: - The twelve that learned to name

    /// The twelve stubs that carried a `.directObject` slot for a year with no
    /// way to name what filled it: they shipped as `plain`, which hands the
    /// line nothing at all. Moving them to `optionallyNamed` gives a game the
    /// name, and hands the engine's own wording an argument it ignores.
    ///
    /// Every probe below is a turn whose output must not move, and they are
    /// grouped by the three roads `optionallyNamed` splits and `plain` did
    /// not: an object, a person, and the player. `plain` answered all three
    /// with one line because it never looked; `optionallyNamed` looks, and
    /// takes a different branch for each. That the sentence comes out the same
    /// is what makes this a refactor.
    static let theTwelveThatLearnedToName: [(String, String)] = [
        // An object to name.
        ("dig bench", "You have nothing to dig with."),
        ("knock on bench", "Nobody answers."),
        ("throw rod at rat", "Throwing things about achieves nothing."),
        ("taste rod", "You'd rather not."),
        ("drink flask", "There's nothing here worth drinking."),
        ("kiss rod", "That would be presumptuous."),
        ("point at rod", "Pointing at things accomplishes little."),
        ("jump over bench", "You jump on the spot. Nothing is achieved."),
        ("sit on bench", "There's nothing comfortable to sit on."),
        ("count rod", "You lose count."),
        ("buy rod", "Nothing here is for sale."),
        ("sell rod", "Nobody here is buying."),

        // A person. None of the twelve takes the `somebodyElse` guard, so all
        // twelve keep answering about the rat exactly as they answer about the
        // rod — `kiss` most of all, since kissing somebody is what the verb is
        // for.
        ("dig rat", "You have nothing to dig with."),
        ("knock on rat", "Nobody answers."),
        ("throw rat at rod", "Throwing things about achieves nothing."),
        ("taste rat", "You'd rather not."),
        ("drink rat", "There's nothing here worth drinking."),
        ("kiss rat", "That would be presumptuous."),
        ("point at rat", "Pointing at things accomplishes little."),
        ("jump over rat", "You jump on the spot. Nothing is achieved."),
        ("sit on rat", "There's nothing comfortable to sit on."),
        ("count rat", "You lose count."),
        ("buy rat", "Nothing here is for sale."),
        ("sell rat", "Nobody here is buying."),

        // The player, who has no name that renders — "You'd rather not taste
        // yourself." — and so takes the line's nameless half rather than
        // `stubs.yourself`.
        ("dig me", "You have nothing to dig with."),
        ("knock on me", "Nobody answers."),
        ("throw me at rod", "Throwing things about achieves nothing."),
        ("taste me", "You'd rather not."),
        ("drink me", "There's nothing here worth drinking."),
        ("kiss me", "That would be presumptuous."),
        ("point at me", "Pointing at things accomplishes little."),
        ("jump over me", "You jump on the spot. Nothing is achieved."),
        ("sit on me", "There's nothing comfortable to sit on."),
        ("count me", "You lose count."),
        ("buy me", "Nothing here is for sale."),
        ("sell me", "Nobody here is buying."),

        // The rows that name nothing because they have no slot to name from.
        ("dig", "You have nothing to dig with."),
        ("jump", "You jump on the spot. Nothing is achieved."),
        ("sit", "There's nothing comfortable to sit on."),
        ("sit down", "There's nothing comfortable to sit on."),
    ]

    @Test(arguments: StubVerbTests.theTwelveThatLearnedToName)
    func theEngineDefaultIsUnchangedForEveryRewiredStub(
        _ command: String, _ expected: String
    ) async throws {
        let turn = turnOutput(of: command, in: try await play(StubLab(), [command]))
        #expect(turn.contains(expected), "\(command): \(turn)")
    }

    /// The gap #245 was filed about, asserted rather than left to be noticed.
    ///
    /// Twelve stubs carried a `.directObject` slot and a `plain` line for a
    /// year. Nothing caught it, because neither half looks wrong on its own —
    /// the rows are the rows the source has, and the line is a sentence
    /// somebody wrote on purpose. Only the two together are the defect, and
    /// only a game trying to name the object ever found out.
    ///
    /// So the pair is asserted rather than inspected. A thirteenth stub that
    /// grows an object slot without a line to put it in fails here, one build
    /// after somebody writes it, instead of one game later. A test rather than
    /// the type system: `.plain(.foo, [["foo", .directObject]])` still compiles,
    /// and closing that structurally would cost more than it saves.
    @Test func everyStubWithAnObjectSlotCanNameIt() {
        for stub in DefaultActions.stubs
        where stub.rows.contains(where: { $0.elements.contains(.directObject) }) {
            #expect(
                stub.namesObject,
                "`\(stub.intent.raw)` takes a direct object its line can't name")
        }
    }

    /// The API claim: one property, either spelling. `kiss` is assigned a bare
    /// string literal and `count` a naming closure, in the same `text` block —
    /// which before ``GameText/Line`` was not a choice a game had, because the
    /// engine's own wording for each verb had already made it.
    ///
    /// That ``NamingStubGame``'s `text` block compiles is most of the test.
    /// This is the rest of it.
    @Test func aStubLineTakesABareStringOrANamingClosure() async throws {
        let transcript = try await play(
            NamingStubGame(), ["kiss rat", "count rod", "count me"])
        #expect(turnOutput(of: "kiss rat", in: transcript).contains("You keep your hands to yourself."))
        #expect(turnOutput(of: "count rod", in: transcript).contains("You lose count of the brass rod."))
        // The naming closure's other half, which `.naming(orBare:_:)` made the
        // game write rather than letting it fall back to the engine's words.
        #expect(turnOutput(of: "count me", in: transcript).contains("You lose your place."))
    }

    /// What twelve games could not do until #245: say what the player was
    /// pointing at. One probe per verb, each asserting the rendered noun the
    /// line was handed.
    static let namingProbes = [
        ("dig bench", "You dig at the long bench."),
        ("knock on bench", "You knock at the long bench."),
        // The projectile, not the target — see the row's comment for why.
        ("throw rod at rat", "You throw the brass rod."),
        ("taste rod", "You taste the brass rod."),
        ("drink flask", "You drink the glass flask."),
        ("kiss rod", "You kiss the brass rod."),
        ("point at rod", "You point at the brass rod."),
        ("jump over bench", "You jump over the long bench."),
        ("sit on bench", "You sit on the long bench."),
        ("count rod", "You count the brass rod."),
        ("buy rod", "You buy the brass rod."),
        ("sell rod", "You sell the brass rod."),
    ]

    @Test(arguments: StubVerbTests.namingProbes)
    func eachNewlyNameableStubNamesItsObject(
        _ command: String, _ expected: String
    ) async throws {
        let turn = turnOutput(of: command, in: try await play(EveryNameableStubGame(), [command]))
        #expect(turn.contains(expected), "\(command): \(turn)")
    }

    /// The six #242 widened, in the same fixture, so the promise of eighteen is
    /// kept rather than asserted at twelve. `touch rod` rather than `touch rat`:
    /// `touch` is the one of the eighteen that guards actors, which
    /// `theRewiredStubsNameAPersonWhereTheGuardedOnesDefer` covers.
    @Test func theOlderNameableStubsStillNameTheirObject() async throws {
        let transcript = try await play(
            EveryNameableStubGame(),
            ["smell rod", "listen to rod", "touch rod", "wake rat", "wave rod", "climb bench"])
        #expect(turnOutput(of: "smell rod", in: transcript).contains("You smell the brass rod."))
        #expect(
            turnOutput(of: "listen to rod", in: transcript).contains("You listen to the brass rod."))
        #expect(turnOutput(of: "touch rod", in: transcript).contains("You feel the brass rod."))
        #expect(turnOutput(of: "wake rat", in: transcript).contains("You wake the grey rat."))
        #expect(turnOutput(of: "wave rod", in: transcript).contains("You wave the brass rod."))
        #expect(turnOutput(of: "climb bench", in: transcript).contains("You climb the long bench."))
    }

    /// The other half of every one of those lines. Four of the twelve have rows
    /// with no object slot at all, so their nameless half is not a courtesy —
    /// it is the only thing those rows can print.
    @Test func theRewiredStubsStillReadWithNoObjectToName() async throws {
        let transcript = try await play(
            EveryNameableStubGame(), ["dig", "jump", "sit", "sit down"])
        #expect(turnOutput(of: "dig", in: transcript).contains("You dig at nothing in particular."))
        #expect(turnOutput(of: "jump", in: transcript).contains("You jump over nothing in particular."))
        #expect(turnOutput(of: "sit", in: transcript).contains("You sit on nothing in particular."))
        #expect(
            turnOutput(of: "sit down", in: transcript).contains("You sit on nothing in particular."))
    }

    /// The guard, which is per verb and not per shape. Seventeen of the
    /// eighteen name a person as readily as a chair; `touch` is the one that
    /// defers, and `eat` next door shows what deferring looks like.
    @Test func theRewiredStubsNameAPersonWhereTheGuardedOnesDefer() async throws {
        let transcript = try await play(
            EveryNameableStubGame(),
            ["kiss rat", "sell rat", "knock on rat", "eat rat", "touch rat"])
        #expect(turnOutput(of: "kiss rat", in: transcript).contains("You kiss the grey rat."))
        #expect(turnOutput(of: "sell rat", in: transcript).contains("You sell the grey rat."))
        #expect(turnOutput(of: "knock on rat", in: transcript).contains("You knock at the grey rat."))
        #expect(turnOutput(of: "eat rat", in: transcript).contains("would rather you didn't"))
        #expect(turnOutput(of: "touch rat", in: transcript).contains("would rather you didn't"))
    }

    /// The player, who is called "yourself" and so has no name that renders in
    /// a line about a thing. All twelve take their own nameless half rather
    /// than ``GameText/StubReplies/yourself``, which is what `optionallyNamed`
    /// is for.
    @Test func theRewiredStubsTakeTheirNamelessHalfForThePlayer() async throws {
        let commands = ["kiss me", "taste me", "count me", "sell me", "dig me"]
        let transcript = try await play(EveryNameableStubGame(), commands)
        for command in commands {
            let turn = turnOutput(of: command, in: transcript)
            #expect(turn.contains("nothing in particular"), "\(command): \(turn)")
            #expect(!turn.contains("Best leave yourself out of it."), "\(command): \(turn)")
        }
    }

    /// The sweep every stub floor is measured by, measured itself.
    ///
    /// `engineVoicedStubLines` reflects over ``GameText/StubReplies`` rather
    /// than listing it, which is what lets a forty-eighth stub be compared the
    /// day it lands — and is also how such a sweep goes quietly vacuous. A
    /// reflection loop that matches nothing reports nothing and passes.
    ///
    /// So it is asked the one question with a knowable answer: handed the
    /// engine's own lines, it must find *every* one of them still in the
    /// engine's voice. A line whose shape it cannot render drops out of the
    /// result and fails here, rather than shipping unchecked in every game
    /// with a floor.
    @Test func theStubSweepSeesEveryLineAGameHasNotVoiced() {
        let engine = GameText.StubReplies()
        let shipped = Mirror(reflecting: engine).children.compactMap(\.label)
        #expect(shipped.count == 49)
        #expect(Set(engineVoicedStubLines(in: engine)) == Set(shipped))
    }

    /// Ties the two probe lists to each other, so a thirteenth stub promoted
    /// later can't ship with only half its cover.
    ///
    /// Every command that names an object in ``namingProbes`` is also pinned
    /// against the engine's own wording in ``theTwelveThatLearnedToName``, and
    /// each of those verbs is asked all three roads — an object, a person, the
    /// player. Adding a naming probe without its three characterization rows,
    /// or the reverse, fails here rather than passing quietly.
    @Test func everyRewiredStubIsProbedOnAllThreeRoads() {
        let named = Self.namingProbes.map(\.0)
        let pinned = Self.theTwelveThatLearnedToName.map(\.0)
        #expect(Array(pinned.prefix(named.count)) == named)
        // Each of those verbs three times over, plus the rows carrying no object
        // slot at all.
        #expect(pinned.count == named.count * 3 + 4)
    }
}
