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
            }
        }

        /// The element rendered the way pattern diagnostics spell it.
        var patternDescription: String {
            switch self {
            case .word(let word): word
            case .directObject: "<object>"
            case .indirectObject: "<second object>"
            case .direction: "<direction>"
            }
        }
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
            default: break
            }
        }
        throw error(
            "pattern elements must be literal words or the slots .directObject, "
                + ".indirectObject, and .direction.")
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

        let objectSlots = elements.filter { $0 == .directObject || $0 == .indirectObject }
        if count(of: .directObject) > 1 {
            problems.append("\(pattern) has more than one <object> slot.")
        }
        if count(of: .indirectObject) > 1 {
            problems.append("\(pattern) has more than one <second object> slot.")
        }
        if objectSlots.first == .indirectObject {
            problems.append("\(pattern) puts the <second object> slot before <object>.")
        }
        if elements.contains(.direction) {
            if !objectSlots.isEmpty {
                problems.append("\(pattern) combines a direction slot with an object slot.")
            }
            if elements.last != .direction {
                problems.append("\(pattern) must end with its direction slot.")
            }
            if count(of: .direction) > 1 {
                problems.append("\(pattern) has more than one direction slot.")
            }
        }
        for (index, element) in elements.enumerated()
        where element == .directObject || element == .indirectObject {
            guard index < elements.count - 1 else { continue }
            guard case .word = elements[index + 1] else {
                problems.append(
                    "\(pattern) needs a literal word between an object slot "
                        + "and whatever follows it.")
                continue
            }
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
