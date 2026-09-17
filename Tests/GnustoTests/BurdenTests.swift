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

    /// The player starts on the cap, so the old `world.before(.take)` rule
    /// answered "You're carrying too much already." to all of these.
    @Test(arguments: [
        (["take me"], "You have yourself well in hand already."),
        (["take brick"], "You already have that."),
        (["take cloak"], "You're already wearing that."),
        (["take watchman"], "The old watchman would take exception to that."),
        (["take statue"], "You can't take that."),
        (["take medal"], "You can't reach the bronze medal."),
        (["take charm"], "The watchman glares until you put it back."),
        (["enter cart", "take cart"], "Not while you're in the wooden cart."),
    ])
    func theSpecificRefusalIsTheOnePrinted(commands: [String], expected: String) async throws {
        let transcript = try await play(BurdenGame(), commands, seed: 0)
        let last = try #require(commands.last)
        #expect(turnOutput(ofLast: last, in: transcript).contains(expected))
    }

    // MARK: - Weight already carried is not weighed twice

    @Test func takingSomethingOutOfACarriedContainerDoesNotWeighItAgain() async throws {
        let transcript = try await play(BurdenGame(), ["take crumb", "inventory"], seed: 0)
        #expect(turnOutput(of: "take crumb", in: transcript).contains("Taken."))
        #expect(turnOutput(of: "inventory", in: transcript).contains("stale crumb"))
    }
}
