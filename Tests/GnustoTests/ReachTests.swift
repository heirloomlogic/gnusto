import GnustoTestSupport
import Testing

@testable import Gnusto

/// The `reach { … }` rule — issue #150. The fixture is `SplitRoomGame` in
/// `Support/ReachGames.swift`: one room with a near end and a far end, and
/// nothing but the rule to tell them apart.
struct ReachTests {
    // MARK: - What the rule refuses, and with what

    @Test func aReachRuleRefusesWithItsOwnLineAndLetsGoOnceItIsTrue() async throws {
        let transcript = try await play(
            SplitRoomGame(), ["take chalk", "take stool", "stroll", "take chalk", "stroll"])
        expectInOrder(
            transcript,
            [
                "The chalk is the length of the gallery away.",
                // The control, with no rule: takable from either end.
                "Taken.",
                "You walk to the far end.",
                "Taken.",
                "You walk back to the near end.",
            ])
    }

    /// Two things at once. A rule with no `otherwise:` falls back to the stock
    /// line — and `hasp` answers `.open` in a `before` rule that `reply`s, so
    /// stage 4 never runs and a gate living there would never fire. That is the
    /// whole reason the gate is at stage 0.
    @Test func theStockLineAnswersAndTheRuleBeatsTheItemsOwnBeforeRule() async throws {
        let transcript = try await play(SplitRoomGame(), ["open hasp", "stroll", "open hasp"])
        let refused = turnOutput(of: "open hasp", in: transcript)
        #expect(refused.contains("You can't reach the hasp."))
        #expect(!refused.contains("sticky with varnish"))
        #expect(transcript.contains("The hasp lifts, sticky with varnish."))
    }

    /// Two-object verbs check the slot they have to touch. The coin is in the
    /// player's hand throughout; the alcove is what moves out of reach.
    @Test func aTwoObjectVerbChecksTheContainer() async throws {
        let transcript = try await play(
            SplitRoomGame(), ["put coin in alcove", "stroll", "put coin in alcove"])
        expectInOrder(
            transcript,
            [
                "The alcove is cut into the far wall.",
                "You walk to the far end.",
                "You put the coin in the alcove.",
            ])
    }

    /// A stub verb reads the same table the core verbs do, so `touch` refuses
    /// with the rule's own line rather than the stock one.
    @Test func aStubVerbHonoursTheRule() async throws {
        let transcript = try await play(SplitRoomGame(), ["touch chalk", "smell chalk"])
        #expect(
            turnOutput(of: "touch chalk", in: transcript)
                .contains("The chalk is the length of the gallery away."))
        // `smell` needs no reach, and is not gated: you can smell it from here.
        #expect(!turnOutput(of: "smell chalk", in: transcript).contains("length of the gallery"))
    }

    @Test func anActorCanDeclareOneToo() async throws {
        let transcript = try await play(SplitRoomGame(), ["take porter", "stroll", "take porter"])
        expectInOrder(
            transcript,
            [
                "The porter is too far off to touch.",
                "You walk to the far end.",
                // Past the gate, and into the ordinary refusal about people.
                "The porter would take exception to that.",
            ])
    }

    // MARK: - What the rule deliberately does not do

    /// It narrows reach and not sight. The chalk is still named by the room
    /// description, still resolves, and still answers `examine` — which is what
    /// makes "it's the length of the gallery away" possible instead of "you
    /// can't see any such thing".
    @Test func theThingStaysVisibleAndNameable() async throws {
        let transcript = try await play(SplitRoomGame(), ["look", "examine chalk"])
        #expect(turnOutput(of: "look", in: transcript).contains("There is a chalk here."))
        let examined = turnOutput(of: "examine chalk", in: transcript)
        #expect(!examined.contains("can't see any such thing"))
        #expect(!examined.contains("length of the gallery"))
    }

    /// A thing in the player's hand is not a question. The taper's rule is false
    /// at the near end, and lighting it works anyway — otherwise a rule keyed to
    /// a position would stop the player using what they carry.
    @Test func whatThePlayerIsHoldingPassesItsOwnRule() async throws {
        let transcript = try await play(SplitRoomGame(), ["turn on taper"])
        #expect(turnOutput(of: "turn on taper", in: transcript).contains("now on"))
    }

    /// `take all` expands from the *reachable* set, and `reachableItems` is
    /// containment-only — it never consults a `reach { … }` rule. So the chalk
    /// is still offered and still refused by name, one line each, rather than
    /// silently omitted: a rule with something to say gets to say it.
    @Test func takeAllRefusesTheUnreachableOneByName() async throws {
        let transcript = try await play(SplitRoomGame(), ["take all"])
        let output = turnOutput(of: "take all", in: transcript)
        #expect(output.contains("The chalk is the length of the gallery away."))
        #expect(output.contains("stool: Taken."))
    }

    // MARK: - The proxy questions

    /// `Item/isReachable` answers with the rule folded in — which is what lets
    /// the Royal Puzzle's presence line read the engine's answer rather than
    /// keeping a second copy of the index. `isReachable(from:)` is gated by the
    /// same rule: the porter is standing in the gallery, but the game tracks
    /// only one position inside it, and it is the player's.
    @Test func theProxyQuestionsAgreeWithTheGate() async throws {
        let transcript = try await play(SplitRoomGame(), ["probe", "stroll", "probe"])
        let near = turnOutput(of: "probe", in: transcript)
        #expect(near.contains("chalk: out of reach"))
        #expect(near.contains("stool: reachable"))
        // Held, and so past its own rule.
        #expect(near.contains("taper: reachable"))
        #expect(near.contains("porter reaches chalk: no"))
        #expect(near.contains("porter reaches stool: yes"))
        let far = output(after: "You walk to the far end.", in: transcript)
        #expect(far.contains("chalk: reachable"))
        #expect(far.contains("porter reaches chalk: yes"))
    }

    // MARK: - Bootstrap

    @Test func twoReachRulesOnOneItemIsADiagnostic() throws {
        do {
            _ = try Bootstrap.build(TwiceReachedGame())
            Issue.record("expected a BootstrapError")
        } catch let error as BootstrapError {
            #expect(
                error.diagnostics.contains {
                    $0.contains("plinth") && $0.contains("more than one reach")
                })
        } catch {
            Issue.record("expected a BootstrapError, got \(error)")
        }
    }
}
