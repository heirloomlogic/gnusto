import GnustoTestSupport
import Testing

@testable import Gnusto

/// Covers issue #483: `var verbs: [SyntaxRule] { [] }` on a `Game`,
/// `GameContent` or `GamePlugin` was `ambiguous use of 'buildExpression'`.
///
/// The real assertion is that `EmptyOverrideGames.swift` compiles at all — a
/// test cannot state that at runtime. What these tests add is the other half of
/// the owner's decision: that an empty declaration behaves exactly like
/// omitting the property, and that the non-empty spellings still work.
@Suite("Empty override tests")
struct EmptyOverrideTests {
    @Test("A game declaring all three tables empty bootstraps and plays")
    func emptyOverridesBootstrapAndPlay() async throws {
        let output = try await play(
            EmptyOverrideGame(),
            [
                "take lamp",
                "down",
            ]
        )
        expectInOrder(
            output,
            [
                "Attic",
                "A low attic.",
                "Taken.",
                "Cellar",
                "A dry stone cellar.",
            ]
        )
    }

    /// Tautological on its face — the fixtures spell `[]` two files away. What
    /// it buys is a reference to each of the three conformances from a test, so
    /// the compile coverage cannot be deleted as dead code without a red suite.
    @Test("An empty declaration contributes the same as omitting it")
    func emptyDeclarationsAreEmpty() {
        let bundle = EmptyOverrideBundle()
        #expect(bundle.verbs.isEmpty)
        #expect(bundle.actions.isEmpty)
        #expect(bundle.timers.isEmpty)

        let plugin = EmptyOverridePlugin()
        #expect(plugin.verbs.isEmpty)
        #expect(plugin.actions.isEmpty)
        #expect(plugin.timers.isEmpty)

        let game = EmptyOverrideGame()
        #expect(game.verbs.isEmpty)
        #expect(game.actions.isEmpty)
        #expect(game.timers.isEmpty)
    }

    @Test("The non-empty verbs spellings still splice their rows")
    func nonEmptySpellingsStillSplice() {
        let verbs = NonEmptyOverrideGame().verbs
        let intents = Set(verbs.map(\.intent))
        #expect(intents.contains(.examine))
        #expect(intents.contains(.take))
        #expect(intents.contains(.drop))
        #expect(intents.contains(.burnish))
    }
}
