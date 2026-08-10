import SwiftCompilerPlugin
import SwiftParser
import SwiftSyntax
import SwiftSyntaxMacros

/// Expands `#verb("ring", ["ring", .directObject])` into a `static let ring`
/// on `Intent` that carries its `SyntaxRule` rows. See the `verb` macro
/// declaration in the Gnusto module for the authoring story.
public struct VerbMacro: DeclarationMacro {
    /// Parses the invocation, validates the patterns, and emits the
    /// `static let` declaration.
    ///
    /// - Parameters:
    ///   - node: the `#verb(…)` macro invocation syntax.
    ///   - context: the macro expansion context.
    /// - Throws: a `MacroError` when the invocation or a pattern is malformed.
    /// - Returns: the generated `static let` declaration.
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        try requireIntentExtension(context)

        var arguments = Array(node.arguments)
        guard !arguments.isEmpty else {
            throw error("#verb needs an intent name.")
        }

        let name = try intentName(from: arguments.removeFirst().expression)
        let patterns = try arguments.map { try pattern(from: $0.expression) }
        // A bare `#verb("sing")` is a one-word verb: the pattern is the name.
        let rows = patterns.isEmpty ? [[Element.word(name)]] : patterns

        for row in rows {
            for problem in patternProblems(of: row) {
                throw error(problem)
            }
        }

        let ruleLines = rows.map { row in
            let elements = row.map(\.source).joined(separator: ", ")
            return "SyntaxRule(\(elements), intent: Intent(\"\(name)\"))"
        }
        return [
            """
            public static let \(raw: name) = Intent(
                \(literal: name),
                syntax: [
                    \(raw: ruleLines.joined(separator: ",\n        "))
                ]
            )
            """
        ]
    }

    // MARK: - The pattern, as the macro sees it

    /// A parsed pattern element — mirrors `SyntaxElement`, which the macro
    /// target can't import (it would drag the whole engine into the compiler
    /// plugin).
    private enum Element: Equatable {
        case word(String)
        case directObject
        case indirectObject
        case direction
        case topic

        /// The element re-spelled as source for the generated `SyntaxRule`.
        /// The word round-trips through a `StringLiteralExprSyntax` so quotes
        /// and backslashes in it re-emit escaped, not as broken source.
        var source: String {
            switch self {
            case .word(let word):
                StringLiteralExprSyntax(content: word).description
            case .directObject: ".directObject"
            case .indirectObject: ".indirectObject"
            case .direction: ".direction"
            case .topic: ".topic"
            }
        }

        /// The element rendered the way pattern diagnostics spell it.
        var patternDescription: String {
            switch self {
            case .word(let word): word
            case .directObject: "<object>"
            case .indirectObject: "<second object>"
            case .direction: "<direction>"
            case .topic: "<topic>"
            }
        }

        /// `SyntaxElement.tokenWidth`, mirrored: how many tokens the element
        /// consumes, or nil where it takes as many as the sentence gives it.
        var tokenWidth: Int? {
            switch self {
            case .word, .direction: 1
            case .directObject, .indirectObject, .topic: nil
            }
        }
    }

    /// `SyntaxRule.fixedSuffixWidth(after:)`, mirrored: the tokens the pattern
    /// still requires after `index`, or nil if something behind it is
    /// variable-width and there is nothing to count back from.
    private static func fixedSuffixWidth(
        of elements: [Element], after index: Int
    ) -> Int? {
        var total = 0
        for element in elements[(index + 1)...] {
            guard let width = element.tokenWidth else { return nil }
            total += width
        }
        return total
    }

    // MARK: - Argument parsing

    private static func requireIntentExtension(
        _ context: some MacroExpansionContext
    ) throws {
        guard
            let extensionDecl = context.lexicalContext.first?.as(ExtensionDeclSyntax.self),
            extensionDecl.extendedType.trimmedDescription == "Intent"
        else {
            throw error(
                "#verb must appear inside 'extension Intent { … }' — that is what "
                    + "makes the leading-dot spelling (.ring) work at rule sites.")
        }
    }

    private static func intentName(from expression: ExprSyntax) throws -> String {
        guard
            let literal = expression.as(StringLiteralExprSyntax.self),
            let name = literal.representedLiteralValue
        else {
            throw error("the intent name must be a plain string literal.")
        }
        guard isValidIdentifier(name) else {
            throw error(
                "the intent name \"\(name)\" must be a valid Swift identifier — "
                    + "it becomes the constant's name (\"turn on\" → \"turnOn\").")
        }
        return name
    }

    private static func pattern(from expression: ExprSyntax) throws -> [Element] {
        guard let array = expression.as(ArrayExprSyntax.self) else {
            throw error(
                "each verb pattern must be an array literal of words and slots, "
                    + "like [\"ring\", .directObject].")
        }
        return try array.elements.map { try element(from: $0.expression) }
    }

    private static func element(from expression: ExprSyntax) throws -> Element {
        if let literal = expression.as(StringLiteralExprSyntax.self) {
            guard let word = literal.representedLiteralValue else {
                throw error("pattern words must be plain string literals.")
            }
            return .word(word)
        }
        if let member = expression.as(MemberAccessExprSyntax.self), member.base == nil {
            switch member.declName.baseName.text {
            case "directObject": return .directObject
            case "indirectObject": return .indirectObject
            case "direction": return .direction
            case "topic": return .topic
            default: break
            }
        }
        throw error(
            "pattern elements must be literal words or the slots .directObject, "
                + ".indirectObject, .direction, and .topic.")
    }

    /// The parser's own notion of a usable identifier — rejects keywords
    /// (`repeat`), spaces, and anything else that couldn't name the constant.
    private static func isValidIdentifier(_ name: String) -> Bool {
        name.isValidSwiftIdentifier(for: .variableName)
    }

    // MARK: - Pattern validation

    /// The bootstrap's `SyntaxRule.patternProblems`, ported so malformed
    /// patterns fail at compile time instead of launch. Keep the two in sync.
    private static func patternProblems(of elements: [Element]) -> [String] {
        var problems: [String] = []
        let described = elements.map(\.patternDescription).joined(separator: " ")
        let pattern = "verb pattern \"\(described)\""

        guard case .word = elements.first else {
            problems.append("\(pattern) must start with a literal word.")
            return problems
        }

        func count(of element: Element) -> Int {
            elements.filter { $0 == element }.count
        }

        if count(of: .directObject) > 1 {
            problems.append("\(pattern) has more than one <object> slot.")
        }
        if count(of: .indirectObject) > 1 {
            problems.append("\(pattern) has more than one <second object> slot.")
        }
        if elements.first(where: { $0 == .directObject || $0 == .indirectObject })
            == .indirectObject
        {
            problems.append("\(pattern) puts the <second object> slot before <object>.")
        }
        // The parser fills a single direction, so a second slot would overwrite
        // the first and the rule would never learn there had been two. Where a
        // direction *sits* is not this rule's business: it is one token wide,
        // so an object slot ahead of it counts back past it like anything else.
        if count(of: .direction) > 1 {
            problems.append("\(pattern) has more than one direction slot.")
        }
        // A topic is the one variable-width slot the parser does not measure:
        // `fit` hands it every remaining token rather than asking what the
        // suffix behind it weighs, because a topic is never resolved and so has
        // no scope check to fall back on when a split goes wrong. These rules
        // hold it to the shape that spelling can place. Teaching `fit` to
        // measure a topic the way it measures an object slot would retire the
        // first and last of them; #215 deliberately left that alone.
        if elements.contains(.topic) {
            if elements.last != .topic {
                problems.append("\(pattern) must end with its topic slot.")
            }
            if count(of: .topic) > 1 {
                problems.append("\(pattern) has more than one topic slot.")
            }
            if elements.contains(.indirectObject) {
                problems.append("\(pattern) combines a topic slot with a <second object> slot.")
            }
            if elements.contains(.direction) {
                problems.append("\(pattern) combines a topic slot with a direction slot.")
            }
        }
        // Where an object slot ends is either arithmetic or a search. It is
        // arithmetic when everything behind it has a fixed width — the phrase
        // stops that many tokens from the end — and a search when it does not,
        // and then a literal word has to be the thing searched for.
        let unclosedSlot = elements.enumerated().contains { index, element in
            guard element == .directObject || element == .indirectObject,
                fixedSuffixWidth(of: elements, after: index) == nil
            else {
                return false
            }
            if case .word = elements[index + 1] { return false }
            return true
        }
        if unclosedSlot {
            problems.append(
                "\(pattern) needs a literal word between an object slot "
                    + "and whatever follows it.")
        }
        return problems
    }

    private static func error(_ message: String) -> MacroError {
        MacroError(message: message)
    }
}

/// A diagnostic with the macro's message; SwiftSyntax renders thrown errors
/// at the expansion site.
struct MacroError: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}

@main
struct GnustoMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [VerbMacro.self]
}
