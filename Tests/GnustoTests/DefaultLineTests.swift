import GnustoTestSupport
import Testing

@testable import Gnusto

/// A custom verb carrying its own default line — the third `action(…)` shape,
/// and the only one that reaches the stub path. (#404)
///
/// The measured thing this replaces is `action(.verb) { try reply(Prose.x) }`,
/// which every demo game hand-rolled twenty-nine times. What the closure gave
/// up doing it is what these tests are about: a custom intent is in neither
/// half of the standard table, so a verb answered by a closure has no name to
/// print and no number to agree with. The reach column it *can* declare now,
/// the same way a line does, and one test below pins that.
struct DefaultLineTests {
    // MARK: - The reach guard, which is the whole point

    /// A line that declares ``Reach/directObject`` refuses a thing the player
    /// can see through glass and not touch — in the engine's own `cantReach`
    /// words, from the same set every core physical default answers with.
    @Test func aGuardedLineRefusesWhatThePlayerCannotTouch() async throws {
        let transcript = try await play(DefaultLineGame(), ["winch cog", "winch jar"])

        #expect(turnOutput(of: "winch cog", in: transcript).contains("can't reach"))
        #expect(!turnOutput(of: "winch cog", in: transcript).contains("does not answer"))
        // And the guard is a guard, not a wall: a thing on the floor gets the
        // line.
        #expect(turnOutput(of: "winch jar", in: transcript).contains("does not answer to that"))
    }

    /// The closure form takes the same column, read at the same two places:
    /// the engine's `cantReach` at stage 4 and a declared `reach { … }` rule at
    /// stage 0. A closure that wants to touch what it names no longer has to
    /// be rewritten as a line to say so.
    @Test func aGuardedClosureRefusesWhatThePlayerCannotTouch() async throws {
        let transcript = try await play(
            DefaultLineGame(), ["hoist cog", "hoist crank", "hoist jar"])

        #expect(turnOutput(of: "hoist cog", in: transcript).contains("can't reach"))
        #expect(!turnOutput(of: "hoist cog", in: transcript).contains("an inch"))
        #expect(turnOutput(of: "hoist crank", in: transcript).contains("The grille is in the way."))
        #expect(turnOutput(of: "hoist jar", in: transcript).contains("You hoist the glass jar an inch"))
    }

    /// The default is ``Reach/notNeeded``, and that is deliberate rather than
    /// an oversight: it is what a custom intent has today, so adopting this
    /// spelling cannot silently tighten a verb. Dungeon's basket is raised from
    /// the far end of a shaft, and a `.directObject` default broke that
    /// walkthrough before this test existed to say why.
    @Test func anUnguardedLineIsTheDefaultAndReachesThroughGlass() async throws {
        let transcript = try await play(DefaultLineGame(), ["chant cog"])

        #expect(turnOutput(of: "chant cog", in: transcript).contains("Nothing answers the chant."))
        #expect(!turnOutput(of: "chant cog", in: transcript).contains("can't reach"))
    }

    /// A declared `reach { … }` rule settles at stage 0, ahead of every rule —
    /// so it only fires for a custom verb if `reachRequirement(of:in:)` reads
    /// the line's column there too, which is why the column is stored beside
    /// the renderer rather than inside it.
    @Test func aDeclaredReachRuleFiresAtStageZeroForACustomVerb() async throws {
        let transcript = try await play(DefaultLineGame(), ["winch crank", "chant crank"])

        #expect(turnOutput(of: "winch crank", in: transcript).contains("The grille is in the way."))
        // The unguarded twin names no slot, so stage 0 has nothing to check and
        // the rule stays out of it.
        #expect(turnOutput(of: "chant crank", in: transcript).contains("Nothing answers the chant."))
    }

    // MARK: - The name, its number, and the two people guards

    @Test func aNamingLineRendersThePhraseAndAgreesWithItsNumber() async throws {
        let transcript = try await play(DefaultLineGame(), ["scold jar", "scold bellows"])

        #expect(turnOutput(of: "scold jar", in: transcript).contains("The glass jar takes no notice."))
        // The plural is the one a hand-written template gets wrong.
        #expect(
            turnOutput(of: "scold bellows", in: transcript).contains("The bellows take no notice."))
    }

    @Test func aNamingLineDefersForThePlayerAndForSomebodyElse() async throws {
        let transcript = try await play(DefaultLineGame(), ["scold me", "scold porter"])

        #expect(turnOutput(of: "scold me", in: transcript).contains("Best leave yourself out of it."))
        #expect(!turnOutput(of: "scold me", in: transcript).contains("takes no notice"))
        #expect(turnOutput(of: "scold porter", in: transcript).contains("is a person"))
    }

    /// Both halves from one declaration — and, on the bare turn, the proof that
    /// the line is a **floor**: it is spoken with `say`, exactly as a stub
    /// verb's is, so stage 5 still runs. The closure spelling it replaces used
    /// `reply`, which throws and unwinds the `after` rules. That is the one
    /// behavior this change moves.
    @Test func aLineWithABareHalfAnswersBothCommandsAndStillRunsTheAfterRules()
        async throws
    {
        let transcript = try await play(
            DefaultLineGame(), ["whistle", "whistle at bellows", "whistle at porter"])

        expectInOrder(
            transcript, ["You whistle at nobody in particular.", "The workshop swallows the note."])
        #expect(
            turnOutput(of: "whistle at bellows", in: transcript)
                .contains("You whistle at the bellows, which changes nothing."))
        // `guardsActors: true`, so the porter is a person rather than furniture.
        #expect(turnOutput(of: "whistle at porter", in: transcript).contains("is a person"))
    }

    // MARK: - A floor, not a refusal

    /// And a `before` rule still promotes itself above it the ordinary way,
    /// which is what a floor means.
    @Test func aBeforeRuleStillBeatsTheDefaultLine() async throws {
        let transcript = try await play(DefaultLineGame(), ["winch bellows"])

        #expect(turnOutput(of: "winch bellows", in: transcript).contains("The bellows wheeze"))
        #expect(!turnOutput(of: "winch bellows", in: transcript).contains("does not answer to that"))
    }

    // MARK: - Bootstrap

    @Test func aDefaultLineForACustomVerbRecordsNoWarning() throws {
        let (definition, _) = try Bootstrap.build(DefaultLineGame())

        #expect(definition.warnings.isEmpty, "\(definition.warnings)")
        // Registered in the same table the closure spelling lands in.
        #expect(definition.actionOverrides[.winch] != nil)
    }

    /// A line written for a verb the engine already answers with one is the
    /// #233 defect wearing the new spelling, so bootstrap names the assignment
    /// that keeps the verb's rows instead.
    @Test func aDefaultLineOnAStubIntentPointsAtTheStubTable() async throws {
        let (definition, _) = try Bootstrap.build(StubLineOverrideGame())

        #expect(
            definition.warnings.contains {
                $0.contains("squeeze") && $0.contains("text.stubs.squeeze")
            }, "\(definition.warnings)")

        // It warns because it works: the row wins the verb, which is what makes
        // giving up the stub's own rows worth complaining about.
        let transcript = try await play(StubLineOverrideGame(), ["squeeze sponge"])
        #expect(turnOutput(of: "squeeze sponge", in: transcript).contains("The sponge weeps"))
    }

    /// A `naming:` line has nothing to say about a command that named nothing,
    /// so under a verb that also parses bare it answers with the parser's own
    /// failure and charges a turn. The engine's table is held to the mirror of
    /// this by review (``StubVerb/namesObject``); a game's is checked here,
    /// because neither half looks wrong on its own.
    @Test func aNamingLineUnderABareRowIsCaughtAtBootstrap() async throws {
        let (definition, _) = try Bootstrap.build(BareRowNamingGame())

        #expect(
            definition.warnings.contains {
                $0.contains("hoot") && $0.contains("orBare:naming:")
            }, "\(definition.warnings)")

        // And this is the transcript it is warning about.
        let transcript = try await play(BareRowNamingGame(), ["hoot", "hoot at owl"])
        #expect(turnOutput(of: "hoot at owl", in: transcript).contains("does not hoot back"))
        #expect(!turnOutput(of: "hoot", in: transcript).contains("does not hoot back"))
    }

    /// A line row on a **built-in** reclaims the verb's answer, not its
    /// physics. Reading the row's `reach:` first let `action(.take, say: …)`
    /// drop `take` to ``Reach/notNeeded`` and switch off every `reach { … }`
    /// rule in the game for that verb.
    @Test func aLineRowCannotLoosenABuiltInVerbsReach() async throws {
        let transcript = try await play(BuiltInLineGame(), ["take crank"])

        #expect(turnOutput(of: "take crank", in: transcript).contains("The grille is in the way."))
        #expect(!turnOutput(of: "take crank", in: transcript).contains("stay that way"))
    }

    /// A **closure** row reclaiming a built-in is guarded by the `reach:` it
    /// declares itself and never by the standard table's column. `.squeeze` is
    /// a stub carrying ``Reach/directObject``; the row declares none, so the
    /// cog behind glass still gets the game's own answer — which is what every
    /// such row did before the column existed, and what `GnustoMeleeCombat`'s
    /// `action(.attack)` needs in order to go on answering for a fish in a
    /// bottle.
    @Test func aClosureOnABuiltInKeepsDecidingItsOwnReach() async throws {
        let transcript = try await play(BuiltInClosureGame(), ["squeeze cog"])
        let squeeze = turnOutput(of: "squeeze cog", in: transcript)

        #expect(squeeze.contains("You squeeze the brass cog from here, somehow."))
        #expect(!squeeze.contains("can't reach"))
    }

    /// And the same row asking for the guard back gets it: `reach:` on a
    /// closure is opt-in, not decoration.
    @Test func aClosureOnABuiltInThatDeclaresReachIsGuarded() async throws {
        let transcript = try await play(BuiltInClosureGame(), ["touch cog"])
        let touch = turnOutput(of: "touch cog", in: transcript)

        #expect(touch.contains("You can't reach the brass cog."))
        #expect(!touch.contains("lay a finger"))
    }

    /// A *closure* on a stub intent stays silent, as it always has: that is a
    /// game taking the verb over rather than re-voicing it.
    @Test func aClosureOnAStubIntentStaysSilent() throws {
        let (definition, _) = try Bootstrap.build(StubPrecedenceGame())

        #expect(!definition.warnings.contains { $0.contains("text.stubs") }, "\(definition.warnings)")
    }
}
