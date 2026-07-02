import Testing

@testable import Gnusto

/// Phase 4 — plugin packaging. Proves a logic-only ``GamePlugin`` can bundle
/// player-typeable verbs and rule factories that a host game splices into its
/// own `verbs`/`rules` blocks, driving a full buy/sell turn over host-owned
/// entities and state. The plugin owns nothing itself; the composition is pure.
struct PluginTests {
    // MARK: - Parameterized rule factories

    @Test func splicedPluginVerbAndRuleDriveAPurchase() async throws {
        // "buy lantern" reaches the plugin's `purchase` rule, which reads the
        // host item's price trait and debits the host's purse (10 → 5).
        let transcript = try await play(LampShop(), ["buy lantern"])
        expectInOrder(
            transcript,
            ["You buy the brass lantern for 5 coins. You have 5 left."])
    }

    @Test func pluginRuleGatesOnTheHostWallet() async throws {
        // Two buys drain the 10-coin purse (10 → 5 → 0); the third is refused
        // by the plugin's guard on the host-supplied balance closure.
        let transcript = try await play(
            LampShop(), ["buy lantern", "buy lantern", "buy lantern"])
        expectInOrder(
            transcript,
            [
                "You have 5 left.",
                "You have 0 left.",
                "You can't afford the brass lantern; it costs 5 coins.",
            ])
    }

    @Test func secondPluginVerbCreditsTheWallet() async throws {
        // The `sell` verb + `sale` factory prove a multi-verb plugin: selling
        // credits the purse (10 → 15), then a buy confirms the higher balance.
        let transcript = try await play(LampShop(), ["sell lantern", "buy lantern"])
        expectInOrder(
            transcript,
            [
                "You sell the brass lantern for 5 coins.",
                "You buy the brass lantern for 5 coins. You have 10 left.",
            ])
    }

    // MARK: - Vocabulary-only plugin (host supplies the rule)

    @Test func vocabularyOnlyPluginLetsHostHandleTheIntent() async throws {
        // The plugin contributes only the `appraise` word; the host's own rule
        // handles the intent, proving the defaulted (empty) plugin `rules`.
        let transcript = try await play(AppraiseShop(), ["appraise gem"])
        expectInOrder(transcript, ["The green gem is worth 42 coins."])
    }

    @Test func vocabularyOnlyPluginBootstrapsWithDefaultRules() throws {
        // A plugin implementing only `verbs` uses the protocol's default empty
        // `rules`; the host still bootstraps cleanly.
        let (definition, _) = try Bootstrap.build(AppraiseShop())
        #expect(definition.syntaxRules.contains { $0.leadingWords == ["appraise"] })
    }

    // MARK: - Vocabulary reaches the parser

    @Test func splicedPluginVerbsRegisterInTheVocabulary() throws {
        // The host spliced `commerce.verbs`, so both rows land in the resolved
        // table and their verb words are known to the parser.
        let (definition, _) = try Bootstrap.build(LampShop())
        #expect(definition.syntaxRules.contains { $0.leadingWords == ["buy"] })
        #expect(definition.syntaxRules.contains { $0.leadingWords == ["sell"] })
        #expect(definition.warnings.isEmpty)
    }
}
