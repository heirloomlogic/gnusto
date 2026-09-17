import GnustoTestSupport
import Testing

@testable import Gnusto

/// `Burden`: the carrying cap, and what it may not answer for. The cap is the
/// broadest thing `take` can say — "no room in your hands" — so every refusal
/// that is about the particular thing is more specific and must be the one
/// printed.
struct BurdenTests {
    // MARK: - The cap still refuses

    @Test func aTakeOverTheCapIsRefused() async throws {
        let transcript = try await play(BurdenGame(), ["take pebble"], seed: 0)
        #expect(
            turnOutput(of: "take pebble", in: transcript)
                .contains("You're carrying too much already."))
    }

    @Test func aTakeUnderTheCapSucceeds() async throws {
        let transcript = try await play(LightBurdenGame(), ["take pebble"], seed: 0)
        #expect(turnOutput(of: "take pebble", in: transcript).contains("Taken."))
    }

    @Test func takeAllRefusesOnlyWhatDoesNotFit() async throws {
        let transcript = try await play(LightBurdenGame(), ["take all", "inventory"], seed: 0)
        let taking = turnOutput(of: "take all", in: transcript)
        #expect(taking.contains("iron anvil: You're carrying too much already."))
        #expect(taking.contains("grey pebble: Taken."))
        #expect(taking.contains("white feather: Taken."))
        #expect(!turnOutput(of: "inventory", in: transcript).contains("iron anvil"))
    }

    // MARK: - Every more specific refusal outranks the cap

    /// The player starts on the cap, so the unguarded rule answered "You're
    /// carrying too much already." to all of these.
    @Test(arguments: [
        (["take me"], "You have yourself well in hand already."),
        (["take brick"], "You already have that."),
        (["take cloak"], "You're already wearing that."),
        (["take watchman"], "The old watchman would take exception to that."),
        (["take statue"], "You can't take that."),
        (["take medal"], "You can't reach the bronze medal."),
        (["enter cart", "take cart"], "Not while you're in the wooden cart."),
    ])
    func theSpecificRefusalIsTheOnePrinted(commands: [String], expected: String) async throws {
        let transcript = try await play(BurdenGame(), commands, seed: 0)
        let last = try #require(commands.last)
        #expect(turnOutput(ofLast: last, in: transcript).contains(expected))
    }

    // MARK: - The cap is asked ahead of the game's own rules

    /// The cap is stage 1 and an item's `before(.take)` is stage 3, so at the
    /// cap the authored refusal is not reached. That ordering is the price of
    /// the two tests below it, and is what the doc comment states.
    @Test func theCapIsAskedBeforeAnAuthoredRefusal() async throws {
        let transcript = try await play(BurdenGame(), ["take charm"], seed: 0)
        let turn = turnOutput(of: "take charm", in: transcript)
        #expect(turn.contains("You're carrying too much already."))
        #expect(!turn.contains("The watchman glares"))
    }

    /// Dungeon's welcome mat: a `before(.take)` rule that moves the rusty key
    /// and says so without throwing. A cap asked after that rule would let it
    /// commit — key on the floor, one-shot spent — and then refuse the take,
    /// leaving the mat where it was.
    @Test func aCapRefusalDoesNotSpendAMutatingBeforeRule() async throws {
        let transcript = try await play(
            BurdenGame(), ["take mat", "look", "drop brick", "take mat"], seed: 0)
        let refused = turnOutput(of: "take mat", in: transcript)
        #expect(refused.contains("You're carrying too much already."))
        #expect(!refused.contains("rusty key"))
        #expect(!turnOutput(of: "look", in: transcript).contains("rusty key"))
        #expect(
            turnOutput(ofLast: "take mat", in: transcript)
                .contains("a rusty key tumbles out from under it"))
    }

    // MARK: - A game that replaces the verb still has the cap

    @Test func anActionTakeOverrideIsStillCapped() async throws {
        let transcript = try await play(
            BurdenOverrideGame(), ["take anvil", "take pebble"], seed: 0)
        let refused = turnOutput(of: "take anvil", in: transcript)
        #expect(refused.contains("You're carrying too much already."))
        #expect(!refused.contains("guilty glance"))
        #expect(turnOutput(of: "take pebble", in: transcript).contains("guilty glance"))
    }

    // MARK: - No cap at all

    @Test func aGameWithNoBurdenWeighsNothing() async throws {
        let transcript = try await play(NoBurdenGame(), ["take anvil", "inventory"], seed: 0)
        #expect(turnOutput(of: "take anvil", in: transcript).contains("Taken."))
        #expect(turnOutput(of: "inventory", in: transcript).contains("iron anvil"))
    }

    // MARK: - Weight already carried is not weighed twice

    @Test func takingSomethingOutOfACarriedContainerDoesNotWeighItAgain() async throws {
        let transcript = try await play(BurdenGame(), ["take crumb", "inventory"], seed: 0)
        #expect(turnOutput(of: "take crumb", in: transcript).contains("Taken."))
        #expect(turnOutput(of: "inventory", in: transcript).contains("stale crumb"))
    }
}
