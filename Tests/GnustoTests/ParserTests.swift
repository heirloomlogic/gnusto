import Testing

@testable import CloakOfDarkness
@testable import Gnusto

struct ParserTests {
    static func makeParser() throws -> StandardParser {
        let (definition, _) = try Bootstrap.build(OperaHouse())
        return StandardParser(
            vocabulary: definition.vocabulary,
            syntaxRules: definition.syntaxRules)
    }

    static let fullScope = Scope(visibleItems: [
        EntityID("cloak"), EntityID("hook"), EntityID("message"),
    ])

    // MARK: - Commands that must parse

    struct Expected {
        let intent: Intent
        var direct: String? = nil
        var indirect: String? = nil
        var direction: Direction? = nil
    }

    @Test(arguments: [
        ("take cloak", Expected(intent: .take, direct: "cloak")),
        ("get the cloak", Expected(intent: .take, direct: "cloak")),
        ("pick up the velvet cloak", Expected(intent: .take, direct: "cloak")),
        ("pick cloak up", Expected(intent: .take, direct: "cloak")),
        ("drop cloak", Expected(intent: .drop, direct: "cloak")),
        ("put down cloak", Expected(intent: .drop, direct: "cloak")),
        ("put cloak down", Expected(intent: .drop, direct: "cloak")),
        ("x hook", Expected(intent: .examine, direct: "hook")),
        ("examine brass hook", Expected(intent: .examine, direct: "hook")),
        ("look at peg", Expected(intent: .examine, direct: "hook")),
        ("read message", Expected(intent: .read, direct: "message")),
        ("read sawdust", Expected(intent: .read, direct: "message")),
        ("wear cloak", Expected(intent: .wear, direct: "cloak")),
        ("put on cloak", Expected(intent: .wear, direct: "cloak")),
        ("take off cloak", Expected(intent: .doff, direct: "cloak")),
        ("take cloak off", Expected(intent: .doff, direct: "cloak")),
        ("hang cloak on hook", Expected(intent: .putOn, direct: "cloak", indirect: "hook")),
        ("put cloak on hook", Expected(intent: .putOn, direct: "cloak", indirect: "hook")),
        (
            "put the velvet cloak onto the small brass hook",
            Expected(intent: .putOn, direct: "cloak", indirect: "hook")
        ),
        ("n", Expected(intent: .go, direction: .north)),
        ("south", Expected(intent: .go, direction: .south)),
        ("go north", Expected(intent: .go, direction: .north)),
        ("walk w", Expected(intent: .go, direction: .west)),
        ("look", Expected(intent: .look)),
        ("l", Expected(intent: .look)),
        ("i", Expected(intent: .inventory)),
        ("score", Expected(intent: .score)),
        ("quit", Expected(intent: .quit)),
    ])
    func parses(_ input: String, _ expected: Expected) throws {
        let parser = try Self.makeParser()
        let parsed = try parser.parse(input, scope: Self.fullScope).get()
        #expect(parsed.intent == expected.intent, "input: \(input)")
        #expect(parsed.directObject?.raw == expected.direct, "input: \(input)")
        #expect(parsed.indirectObject?.raw == expected.indirect, "input: \(input)")
        #expect(parsed.direction == expected.direction, "input: \(input)")
    }

    // MARK: - Errors with classic tone

    @Test func emptyInput() throws {
        let parser = try Self.makeParser()
        #expect(parser.parse("", scope: Self.fullScope) == .failure(.empty))
        #expect(parser.parse("   ", scope: Self.fullScope) == .failure(.empty))
    }

    @Test func unknownWord() throws {
        let parser = try Self.makeParser()
        #expect(
            parser.parse("frotz the cloak", scope: Self.fullScope)
                == .failure(.unknownWord("frotz")))
        #expect(
            parser.parse("take grue", scope: Self.fullScope)
                == .failure(.unknownWord("grue")))
    }

    @Test func knownWordOutOfScope() throws {
        // From the foyer only the carried cloak is in scope; the message is
        // a known word but not visible.
        let foyerScope = Scope(visibleItems: [EntityID("cloak")])
        let parser = try Self.makeParser()
        #expect(
            parser.parse("read message", scope: foyerScope)
                == .failure(.notInScope))
    }

    @Test func missingObjects() throws {
        let parser = try Self.makeParser()
        #expect(
            parser.parse("take", scope: Self.fullScope)
                == .failure(.missingObject(verb: "take", prefix: ["take"])))
        #expect(
            parser.parse("hang cloak", scope: Self.fullScope)
                == .failure(
                    .missingIndirect(
                        verb: "hang", objectName: "velvet cloak", preposition: "on",
                        prefix: ["hang", "cloak", "on"])))
    }

    @Test func adjectiveAloneDoesNotResolve() throws {
        let parser = try Self.makeParser()
        let result = parser.parse("take velvet", scope: Self.fullScope)
        #expect(result == .failure(.notInScope))
    }

    @Test func parseErrorMessagesReadClassically() {
        let text = GameText()
        #expect(
            ParseError.unknownWord("frotz").playerMessage(text)
                == "I don't know the word \"frotz\".")
        #expect(ParseError.notInScope.playerMessage(text) == "You can't see any such thing.")
        #expect(ParseError.empty.playerMessage(text) == "I beg your pardon?")
        #expect(
            ParseError.missingObject(verb: "take", prefix: ["take"]).playerMessage(text)
                == "What do you want to take?")
    }

    // MARK: - Tokenizer

    /// Pins the tokenizer contract directly: lowercase-fold, keep runs of
    /// letters/digits, treat every other character as a separator, collapse
    /// runs of separators, and drop noise words. A plain `Vocabulary` fixes the
    /// noise set to the default (`the a an my that this some`) so the cases are
    /// deterministic.
    @Test(arguments: [
        ("take lamp", ["take", "lamp"]),
        ("TAKE Lamp", ["take", "lamp"]),  // case-folded
        ("put the lamp on the table", ["put", "lamp", "on", "table"]),  // noise dropped
        ("don't panic", ["don", "t", "panic"]),  // apostrophe splits
        ("north-west", ["north", "west"]),  // hyphen splits
        ("take 3 coins", ["take", "3", "coins"]),  // digits kept
        ("3.5", ["3", "5"]),  // period splits digits
        ("go   west", ["go", "west"]),  // whitespace runs collapse
        ("foo...bar", ["foo", "bar"]),  // punctuation runs collapse
        (".hello.", ["hello"]),  // leading/trailing punctuation
        ("the a an my that this some", []),  // all noise
        ("!!!", []),  // no alphanumerics
        ("", []),  // empty line
    ] as [(String, [String])])
    func tokenizePinsItsContract(input: String, expected: [String]) {
        let parser = StandardParser(vocabulary: Vocabulary(), syntaxRules: [])
        #expect(parser.tokenize(input) == expected)
    }
}
