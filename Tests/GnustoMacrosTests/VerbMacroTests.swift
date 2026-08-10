import GnustoMacros
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

/// Golden expansions and diagnostics for `#verb`. XCTest, not Swift Testing:
/// `assertMacroExpansion` is XCTest-based.
///
/// `assertMacroExpansion` expands the macro without type-checking, so the
/// `extension Intent` context requirement is asserted through lexicalContext
/// by wrapping the source; everything else uses the bare invocation.
final class VerbMacroTests: XCTestCase {
    private let macros: [String: Macro.Type] = ["verb": VerbMacro.self]

    private func inIntentExtension(_ body: String) -> String {
        """
        extension Intent {
        \(body)
        }
        """
    }

    // MARK: - Expansions

    func testOneWordVerbDefaultsItsPattern() {
        assertMacroExpansion(
            inIntentExtension(#"#verb("sing")"#),
            expandedSource: inIntentExtension(
                #"""
                public static let sing = Intent(
                    "sing",
                    syntax: [
                        SyntaxRule("sing", intent: Intent("sing"))
                    ]
                )
                """#),
            macros: macros)
    }

    func testSinglePattern() {
        assertMacroExpansion(
            inIntentExtension(#"#verb("ring", ["ring", .directObject])"#),
            expandedSource: inIntentExtension(
                #"""
                public static let ring = Intent(
                    "ring",
                    syntax: [
                        SyntaxRule("ring", .directObject, intent: Intent("ring"))
                    ]
                )
                """#),
            macros: macros)
    }

    func testMultiplePatternsShareTheIntent() {
        assertMacroExpansion(
            inIntentExtension(
                #"""
                #verb("attack",
                      ["attack", .directObject],
                      ["kill", .directObject, "with", .indirectObject])
                """#),
            expandedSource: inIntentExtension(
                #"""
                public static let attack = Intent(
                    "attack",
                    syntax: [
                        SyntaxRule("attack", .directObject, intent: Intent("attack")),
                        SyntaxRule("kill", .directObject, "with", .indirectObject, intent: Intent("attack"))
                    ]
                )
                """#),
            macros: macros)
    }

    func testEscapesQuotesAndBackslashesInPatternWords() {
        // A word with escape sequences decodes to its value ("\hi") and
        // re-emits as a literal representing exactly that value — never as
        // broken generated source.
        assertMacroExpansion(
            inIntentExtension(#"#verb("say", ["say", "\"\\hi\""])"#),
            expandedSource: inIntentExtension(
                ##"""
                public static let say = Intent(
                    "say",
                    syntax: [
                        SyntaxRule("say", #""\hi""#, intent: Intent("say"))
                    ]
                )
                """##),
            macros: macros)
    }

    func testReclaimingABuiltInUnderANewName() {
        assertMacroExpansion(
            inIntentExtension(#"#verb("steal", ["take", .directObject])"#),
            expandedSource: inIntentExtension(
                #"""
                public static let steal = Intent(
                    "steal",
                    syntax: [
                        SyntaxRule("take", .directObject, intent: Intent("steal"))
                    ]
                )
                """#),
            macros: macros)
    }

    // MARK: - Diagnostics

    /// A failed expansion leaves the source untouched and points the
    /// diagnostic at the invocation.
    private func expectDiagnostic(source: String, message: String) {
        assertMacroExpansion(
            source,
            expandedSource: source,
            diagnostics: [DiagnosticSpec(message: message, line: 2, column: 1)],
            macros: macros)
    }

    func testRejectsUseOutsideAnIntentExtension() {
        let source = #"#verb("ring", ["ring", .directObject])"#
        assertMacroExpansion(
            source,
            expandedSource: source,
            diagnostics: [
                DiagnosticSpec(
                    message: "#verb must appear inside 'extension Intent { … }' — that is "
                        + "what makes the leading-dot spelling (.ring) work at rule sites.",
                    line: 1, column: 1)
            ],
            macros: macros)
    }

    func testRejectsANonLiteralIntentName() {
        expectDiagnostic(
            source: inIntentExtension(#"#verb(someName, ["ring", .directObject])"#),
            message: "the intent name must be a plain string literal.")
    }

    func testRejectsAnInterpolatedIntentName() {
        expectDiagnostic(
            source: inIntentExtension(#"#verb("ring\(bell)", ["ring"])"#),
            message: "the intent name must be a plain string literal.")
    }

    func testRejectsAnInvalidIdentifier() {
        expectDiagnostic(
            source: inIntentExtension(#"#verb("turn on", ["turn", "on"])"#),
            message: "the intent name \"turn on\" must be a valid Swift identifier — "
                + "it becomes the constant's name (\"turn on\" → \"turnOn\").")
    }

    func testRejectsAKeywordIdentifier() {
        expectDiagnostic(
            source: inIntentExtension(#"#verb("repeat")"#),
            message: "the intent name \"repeat\" must be a valid Swift identifier — "
                + "it becomes the constant's name (\"turn on\" → \"turnOn\").")
    }

    func testRejectsANonArrayPattern() {
        expectDiagnostic(
            source: inIntentExtension(#"#verb("ring", "ring")"#),
            message: "each verb pattern must be an array literal of words and slots, "
                + "like [\"ring\", .directObject].")
    }

    func testRejectsAnUnknownSlot() {
        expectDiagnostic(
            source: inIntentExtension(#"#verb("ring", ["ring", .bellObject])"#),
            message: "pattern elements must be literal words or the slots .directObject, "
                + ".indirectObject, .direction, and .topic.")
    }

    // MARK: - Topic slots

    func testTopicSlotExpands() {
        assertMacroExpansion(
            inIntentExtension(#"#verb("ask", ["ask", .directObject, "about", .topic])"#),
            expandedSource: inIntentExtension(
                #"""
                public static let ask = Intent(
                    "ask",
                    syntax: [
                        SyntaxRule("ask", .directObject, "about", .topic, intent: Intent("ask"))
                    ]
                )
                """#),
            macros: macros)
    }

    func testRejectsATopicSlotThatDoesNotEndThePattern() {
        expectDiagnostic(
            source: inIntentExtension(#"#verb("ask", ["ask", .topic, "about"])"#),
            message: "verb pattern \"ask <topic> about\" must end with its topic slot.")
    }

    func testRejectsTwoTopicSlots() {
        expectDiagnostic(
            source: inIntentExtension(#"#verb("say", ["say", .topic, .topic])"#),
            message: "verb pattern \"say <topic> <topic>\" has more than one topic slot.")
    }

    func testRejectsATopicSlotBesideASecondObject() {
        expectDiagnostic(
            source: inIntentExtension(
                #"#verb("tell", ["tell", .directObject, "to", .indirectObject, "about", .topic])"#),
            message: "verb pattern \"tell <object> to <second object> about <topic>\" "
                + "combines a topic slot with a <second object> slot.")
    }

    func testRejectsATopicSlotBesideADirection() {
        expectDiagnostic(
            source: inIntentExtension(#"#verb("dig", ["dig", .direction, "about", .topic])"#),
            message: "verb pattern \"dig <direction> about <topic>\" "
                + "combines a topic slot with a direction slot.")
    }

    func testRejectsAPatternStartingWithASlot() {
        expectDiagnostic(
            source: inIntentExtension(#"#verb("ring", [.directObject, "ring"])"#),
            message: "verb pattern \"<object> ring\" must start with a literal word.")
    }

    func testRejectsAdjacentObjectSlots() {
        expectDiagnostic(
            source: inIntentExtension(
                #"#verb("give", ["give", .directObject, .indirectObject])"#),
            message: "verb pattern \"give <object> <second object>\" needs a literal "
                + "word between an object slot and whatever follows it.")
    }

    func testRejectsASecondObjectBeforeTheFirst() {
        expectDiagnostic(
            source: inIntentExtension(
                #"#verb("give", ["give", .indirectObject, "to", .directObject])"#),
            message: "verb pattern \"give <second object> to <object>\" puts the "
                + "<second object> slot before <object>.")
    }

    /// The parser fills a single direction, so a second slot would overwrite
    /// the first — the one thing about a direction that width cannot decide.
    func testRejectsTwoDirectionSlots() {
        expectDiagnostic(
            source: inIntentExtension(#"#verb("cross", ["cross", .direction, "then", .direction])"#),
            message: "verb pattern \"cross <direction> then <direction>\" has more than "
                + "one direction slot.")
    }

    /// The object-and-direction shape #151 bought: the direction slot takes a
    /// single token, so `<object> <direction>` splits at a fixed place.
    func testAcceptsAnObjectSlotBeforeATrailingDirection() {
        assertMacroExpansion(
            inIntentExtension(#"#verb("shift", ["shift", .directObject, .direction])"#),
            expandedSource: inIntentExtension(
                #"""
                public static let shift = Intent(
                    "shift",
                    syntax: [
                        SyntaxRule("shift", .directObject, .direction, intent: Intent("shift"))
                    ]
                )
                """#),
            macros: macros)
    }

    /// A direction need not *end* its pattern. It is one token wide, so a
    /// literal behind it just adds one to what the noun phrase counts back
    /// past. Issue #215.
    func testAcceptsALiteralAfterTheDirectionSlot() {
        assertMacroExpansion(
            inIntentExtension(#"#verb("wedge", ["wedge", .directObject, .direction, "hard"])"#),
            expandedSource: inIntentExtension(
                #"""
                public static let wedge = Intent(
                    "wedge",
                    syntax: [
                        SyntaxRule("wedge", .directObject, .direction, "hard", intent: Intent("wedge"))
                    ]
                )
                """#),
            macros: macros)
    }

    /// Nor does the object slot have to stand *immediately* before the
    /// direction: a literal between them is another token of fixed width and
    /// nothing more. Issue #215.
    func testAcceptsAnObjectSlotSeparatedFromTheDirection() {
        assertMacroExpansion(
            inIntentExtension(#"#verb("hurl", ["hurl", .directObject, "at", .direction])"#),
            expandedSource: inIntentExtension(
                #"""
                public static let hurl = Intent(
                    "hurl",
                    syntax: [
                        SyntaxRule("hurl", .directObject, "at", .direction, intent: Intent("hurl"))
                    ]
                )
                """#),
            macros: macros)
    }

    /// And the slot a direction closes need not be the direct object. Issue
    /// #215.
    func testAcceptsASecondObjectSlotBesideADirection() {
        assertMacroExpansion(
            inIntentExtension(
                #"#verb("lob", ["lob", .directObject, "at", .indirectObject, .direction])"#),
            expandedSource: inIntentExtension(
                #"""
                public static let lob = Intent(
                    "lob",
                    syntax: [
                        SyntaxRule("lob", .directObject, "at", .indirectObject, .direction, intent: Intent("lob"))
                    ]
                )
                """#),
            macros: macros)
    }
}
