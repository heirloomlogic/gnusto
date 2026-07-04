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
                + ".indirectObject, and .direction.")
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

    func testRejectsADirectionSlotMidPattern() {
        expectDiagnostic(
            source: inIntentExtension(#"#verb("push", ["push", .direction, "hard"])"#),
            message: "verb pattern \"push <direction> hard\" must end with its "
                + "direction slot.")
    }
}
