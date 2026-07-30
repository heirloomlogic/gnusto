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
        "burn rod", "cut rod", "slice rod",
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

        let bare = try await play(StubLab(), ["attack rat"])
        #expect(bare.contains("Attacking things rarely improves them."))
    }
}
