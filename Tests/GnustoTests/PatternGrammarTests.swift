import Testing

@testable import Gnusto

/// Phase 6 pattern grammar: `SyntaxRule` rows as free-form patterns of
/// literal words and slots.
struct PatternGrammarTests {
    static func makeParser() throws -> StandardParser {
        let (definition, _) = try Bootstrap.build(WorkshopGame())
        return StandardParser(
            vocabulary: definition.vocabulary,
            syntaxRules: definition.syntaxRules)
    }

    static let scope = Scope(visibleItems: [
        EntityID("lamp"), EntityID("rug"), EntityID("gnome"),
    ])

    @Test func twoObjectsAroundAPreposition() throws {
        let parser = try Self.makeParser()
        let parsed = try parser.parse("give lamp to gnome", scope: Self.scope).get()
        #expect(parsed.intent == Intent("give"))
        #expect(parsed.directObject == EntityID("lamp"))
        #expect(parsed.indirectObject == EntityID("gnome"))
        #expect(parsed.preposition == "to")
    }

    @Test(arguments: [
        "turn lamp on",
        "turn on lamp",
        "turn the brass lamp on",
        "turn on the brass lamp",
    ])
    func particleOnEitherSideOfTheObject(_ input: String) throws {
        let parser = try Self.makeParser()
        let parsed = try parser.parse(input, scope: Self.scope).get()
        #expect(parsed.intent == Intent("turnOn"))
        #expect(parsed.directObject == EntityID("lamp"))
    }

    @Test func multiWordVerbBeatsShorterRows() throws {
        let parser = try Self.makeParser()

        let under = try parser.parse("look under rug", scope: Self.scope).get()
        #expect(under.intent == Intent("lookUnder"))
        #expect(under.directObject == EntityID("rug"))

        // The standard rows sharing the "look" verb word are unaffected.
        let at = try parser.parse("look at rug", scope: Self.scope).get()
        #expect(at.intent == .examine)
        let bare = try parser.parse("look", scope: Self.scope).get()
        #expect(bare.intent == .look)
    }

    @Test func missingSecondObjectAsksForIt() throws {
        let parser = try Self.makeParser()
        let result = parser.parse("give lamp", scope: Self.scope)
        #expect(
            result
                == .failure(
                    .missingIndirect(
                        verb: "give", objectName: "brass lamp", preposition: "to")))
    }

    @Test func customShapesWorkEndToEnd() async throws {
        let transcript = try await play(
            WorkshopGame(),
            ["give lamp to gnome", "turn lamp on", "look under rug"])
        expectInOrder(
            transcript,
            [
                "The gnome accepts your gift with a stony nod.",
                "The lamp hums to life.",
                "Only dust under there.",
            ])
    }

    @Test func malformedPatternsAreFatalTogether() {
        #expect {
            _ = try Bootstrap.build(BadPatternsGame())
        } throws: { error in
            guard let bootstrapError = error as? BootstrapError else { return false }
            let text = bootstrapError.diagnostics.joined(separator: "\n")
            return bootstrapError.diagnostics.count >= 3
                && text.contains("must start with a literal word")
                && text.contains("literal word between")
                && text.contains("direction")
        }
    }
}
