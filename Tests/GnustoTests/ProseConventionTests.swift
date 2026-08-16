import Foundation
import Testing

/// The one prose convention that can only be checked by reading source.
///
/// `GameText.Line.naming { }` hands its closure a **rendered noun phrase** —
/// "the troll", "a troll", "Mrs. Vane" — not a bare name. The article is the
/// engine's, chosen from the `properName` trait, and the capitalization is the
/// line's, which is why `GameText.Noun.sentenceCased` exists. A line that opens
/// on the phrase and forgets it prints "the patrolman looks at you and does not
/// answer."
///
/// Nothing else in the toolchain can see this. `swift-format` has no rule of
/// the shape; the bootstrap's nearest diagnostic
/// (`Bootstrap.swift`, the capitalized-`name`-without-`properName` warning)
/// catches the *article* problem and is blind to the capitalization one,
/// because at bootstrap there is no line to read. The defect is invisible to
/// the test suite too, since five of Fulminate's six actors carry `properName`
/// and capitalize themselves — the transcripts look right until the one actor
/// who doesn't says his line.
///
/// So this reads `Sources/`. That is unusual enough to justify: the alternative
/// was a play-test round noticing, which costs a fan-out of agents and only
/// works if one of them happens to remember the convention. A regex is the
/// strictly better detector, and belongs where CI already runs.
///
/// **Scope, stated honestly.** The sweep only rules inside `.naming { }`
/// closure bodies, because that is the only context where `$0` is known to be a
/// rendered phrase. Elsewhere `$0` is a `String` word, a map element or an
/// `EntityID`, and the same spelling is correct. Within that scope it is
/// deliberately strict: *every* sentence-initial interpolation must be
/// sentence-cased.
struct ProseConventionTests {
    // MARK: - The sweep

    /// Every `.naming` closure in the package sentence-cases the phrase it
    /// opens on, and none of them writes its own article.
    @Test func namingClosuresSentenceCaseThePhraseTheyOpenOn() throws {
        let sources = try Self.swiftAndDocSources()
        #expect(
            sources.count > 100,
            "the sweep found \(sources.count) files, which means it is not reading Sources/")

        var found: [Violation] = []
        for source in sources {
            found += Self.violations(in: source.text, path: source.path)
        }

        #expect(
            found.isEmpty,
            """
            A `.naming` closure opens a sentence on a rendered noun phrase \
            without sentence-casing it, or writes an article the engine \
            already supplied:

            \(found.map(\.description).joined(separator: "\n"))
            """)
    }

    // MARK: - The detector's own tests

    /// The sweep above passes vacuously if the detector matches nothing, which
    /// is the way a check like this rots. These pin its two directions against
    /// the real defects that motivated it.
    @Test func theDetectorCatchesBothDirectionsOfTheFault() {
        // The live Fulminate defect: correct article, lowercase sentence.
        let bare = #"""
            text.greets = .naming {
                "\($0) \($0.verb("looks", "look")) at you and does not answer."
            }
            """#
        #expect(Self.violations(in: bare, path: "x.swift").count == 1)

        // The case `CLAUDE.md` names: the line writes an article of its own,
        // so a `properName` actor becomes "the Mrs. Vane".
        let article = #"""
            text.cantTake = .naming { "The \($0) is not yours to take." }
            """#
        #expect(Self.violations(in: article, path: "x.swift").count == 1)

        // A sentence opening after a full stop inside one literal.
        let midLiteral = #"""
            text.locked = .naming { "You try it. \($0) does not give." }
            """#
        #expect(Self.violations(in: midLiteral, path: "x.swift").count == 1)

        // A field of a two-noun role struct is a rendered phrase too.
        let role = #"""
            text.given = .naming { "\($0.recipient) takes it without a word." }
            """#
        #expect(Self.violations(in: role, path: "x.swift").count == 1)
    }

    /// The spellings that must stay silent. Each is a real shape from the
    /// package, and each was a false positive in an earlier draft of the sweep.
    @Test func theDetectorPassesTheCorrectSpellings() {
        let good = [
            // The idiomatic form.
            #"text.locked = .naming { "\($0.sentenceCased) \($0.verb("is", "are")) locked." }"#,
            // Sentence-cased field of a role struct.
            #"text.given = .naming { "\($0.recipient.sentenceCased) says nothing." }"#,
            // The phrase mid-sentence needs no capital and no article.
            #"text.cantBurn = .naming { "You can't burn \($0)." }"#,
            // A verb call never opens a sentence, and carries parentheses that
            // the interpolation reader must not mistake for a phrase.
            #"text.food = .naming { "\($0.sentenceCased) \($0.verb("is", "are")) not food." }"#,
            // `$0` outside a `.naming` closure is not a rendered phrase: these
            // are a parser word, a map element and an identifier.
            #"text.unknownWord = { "I don't know the word \"\($0)\"." }"#,
            #"let names = missing.map { "\"\($0)\"" }.joined(separator: ", ")"#,
            #"let id = namespace.map { EntityID("\($0).\(label)") } ?? EntityID(label)"#,
            // `Aboard.place` is a room name held as a plain `String`, and
            // rooms are capitalized already — the room-title line opens on it
            // and is correct.
            #"text.locationInVehicle = .naming { "\($0.place), in \($0.vehicle)" }"#,
            // An article before something that is not a rendered phrase: an
            // adjective, and a word fragment.
            #"static func button(_ shape: String) -> String { "A \(shape) button, worn smooth." }"#,
            #"static func wall(_ face: String) -> String { "The \(face)ern wall." }"#,
        ]
        for line in good {
            #expect(
                Self.violations(in: line, path: "x.swift").isEmpty,
                "false positive on: \(line)")
        }
    }

    // MARK: - Reading the package

    /// One source file the sweep read.
    private struct Source {
        let path: String
        let text: String
    }

    /// Where a fault is, and which of the two it is.
    private struct Violation: CustomStringConvertible {
        let path: String
        let line: Int
        let excerpt: String
        let fault: String

        var description: String { "\(path):\(line) — \(fault)\n    \(excerpt)" }
    }

    /// The package's `Sources/` directory, found relative to this file rather
    /// than to the working directory, which a test process does not control.
    private static var sourcesDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // GnustoTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // the package
            .appendingPathComponent("Sources", isDirectory: true)
    }

    /// Every Swift file under `Sources/`, plus the DocC articles, whose code
    /// samples teach the convention and so have to obey it.
    private static func swiftAndDocSources() throws -> [Source] {
        let root = sourcesDirectory
        guard
            let walker = FileManager.default.enumerator(
                at: root, includingPropertiesForKeys: nil)
        else {
            Issue.record("could not read \(root.path)")
            return []
        }
        var sources: [Source] = []
        for case let url as URL in walker where ["swift", "md"].contains(url.pathExtension) {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            sources.append(
                Source(path: url.path.replacingOccurrences(of: root.path + "/", with: ""), text: text))
        }
        return sources
    }

    // MARK: - The detector

    /// The suffixes that make a dotted expression a rendered noun phrase. `$0`
    /// itself qualifies inside a `.naming` closure, which is the only place
    /// this runs.
    private static let phraseSuffixes = ["phrase", "definiteName", "indefiniteName"]

    /// The `Noun`-typed fields of the two-thing role structs in
    /// `GameText+Line.swift` — `Holding`, `Carried`, `Gift` and `Aboard`.
    /// Deliberately not every field: `Aboard.place` is a `String`.
    private static let nounFields = ["item", "holder", "noun", "gift", "recipient", "vehicle"]

    /// The articles the engine has already supplied.
    private static let articles = ["the", "a", "an"]

    /// Rules on one file's text.
    ///
    /// Walks the source as a small state machine rather than a single regex,
    /// because the question is *positional* — the same interpolation is correct
    /// mid-sentence and wrong at the head of one — and because `$0` only means
    /// a phrase inside a `.naming` body, which needs brace tracking to find.
    private static func violations(in text: String, path: String) -> [Violation] {
        var found: [Violation] = []
        var depth = 0
        var namingDepth: Int?
        var pendingNaming = false
        var inMultilineLiteral = false

        for (offset, raw) in text.components(separatedBy: .newlines).enumerated() {
            let number = offset + 1
            let line = stripComment(raw)

            // A `"""` literal spans lines. Whether *this* line is prose is
            // decided by the state on entering it, so the fence is counted
            // after the decision and not before.
            let wasInMultilineLiteral = inMultilineLiteral
            if line.contains("\"\"\"") {
                let fences = line.components(separatedBy: "\"\"\"").count - 1
                if fences % 2 == 1 { inMultilineLiteral.toggle() }
            }

            // Inside a `"""` block the line is prose, so braces there are not
            // structure and the quote-splitter has nothing to split on. No
            // `.naming` closure in the package opens one today; this keeps the
            // sweep from going blind if one ever does. A line-leading
            // interpolation is *not* read as a sentence head here, because a
            // multiline literal wraps its prose with a trailing `\` and that
            // makes the next line a continuation rather than a new sentence.
            if wasInMultilineLiteral {
                if namingDepth != nil {
                    found += faults(
                        inLiteral: line, path: path, line: number, excerpt: raw,
                        lineStartOpensASentence: false)
                }
                continue
            }

            for span in spans(of: line) {
                switch span.kind {
                case .string:
                    guard namingDepth != nil else { continue }
                    found += faults(
                        inLiteral: span.text, path: path, line: number, excerpt: raw,
                        lineStartOpensASentence: true)
                case .code:
                    if span.text.contains(".naming") { pendingNaming = true }
                    for character in span.text {
                        if character == "{" {
                            if pendingNaming, namingDepth == nil {
                                namingDepth = depth
                                pendingNaming = false
                            }
                            depth += 1
                        } else if character == "}" {
                            depth -= 1
                            if let start = namingDepth, depth <= start { namingDepth = nil }
                        }
                    }
                }
            }
        }
        return found
    }

    /// Drops a trailing `//` comment, and a whole line that is only a comment,
    /// so that a doc comment quoting a bad spelling is not read as source.
    private static func stripComment(_ line: String) -> String {
        if line.trimmingCharacters(in: .whitespaces).hasPrefix("//") { return "" }
        var result = ""
        var inString = false
        var previous: Character?
        var index = line.startIndex
        while index < line.endIndex {
            let character = line[index]
            let next = line.index(after: index)
            if character == "\"", previous != "\\" { inString.toggle() }
            if character == "/", !inString, next < line.endIndex, line[next] == "/" { break }
            result.append(character)
            previous = character
            index = next
        }
        return result
    }

    /// One stretch of a line, either code or the inside of a string literal.
    private struct Span {
        enum Kind { case code, string }
        let kind: Kind
        let text: String
    }

    /// Splits a line into code and string-literal spans, so that braces in
    /// prose are not counted and `.naming` in prose is not seen.
    private static func spans(of line: String) -> [Span] {
        var spans: [Span] = []
        var current = ""
        var inString = false
        var previous: Character?
        for character in line {
            if character == "\"", previous != "\\" {
                spans.append(Span(kind: inString ? .string : .code, text: current))
                current = ""
                inString.toggle()
            } else {
                current.append(character)
            }
            previous = character
        }
        spans.append(Span(kind: inString ? .string : .code, text: current))
        return spans
    }

    /// Rules on the inside of one string literal.
    private static func faults(
        inLiteral literal: String, path: String, line: Int, excerpt: String,
        lineStartOpensASentence: Bool
    ) -> [Violation] {
        var found: [Violation] = []
        let characters = Array(literal)

        for index in characters.indices {
            guard characters[index] == "\\", index + 1 < characters.count,
                characters[index + 1] == "("
            else { continue }
            guard let expression = expression(in: characters, startingAt: index + 2) else {
                continue
            }
            guard isRenderedPhrase(expression) else { continue }

            if opensASentence(
                characters, before: index, lineStartCounts: lineStartOpensASentence)
            {
                guard !expression.hasSuffix(".sentenceCased") else { continue }
                found.append(
                    Violation(
                        path: path, line: line, excerpt: excerpt.trimmed,
                        fault: """
                            `\\(\(expression))` opens a sentence without \
                            `.sentenceCased`, so a name with no `properName` \
                            prints lowercase
                            """))
            } else if let article = article(before: characters, at: index) {
                found.append(
                    Violation(
                        path: path, line: line, excerpt: excerpt.trimmed,
                        fault: """
                            "\(article)" is written before `\\(\(expression))`, \
                            which already carries the engine's article
                            """))
            }
        }
        return found
    }

    /// Reads a dotted identifier chain up to its closing paren, or `nil` when
    /// the interpolation holds anything more complicated — a call such as
    /// `$0.verb("is", "are")` or `GameText.sentenceCase(name)`, neither of
    /// which can open a sentence wrongly.
    private static func expression(in characters: [Character], startingAt start: Int) -> String? {
        var index = start
        var text = ""
        while index < characters.count {
            let character = characters[index]
            if character == ")" { return text.isEmpty ? nil : text }
            guard character.isLetter || character.isNumber || character == "." || character == "$" || character == "_"
            else { return nil }
            text.append(character)
            index += 1
        }
        return nil
    }

    /// Whether a dotted chain names a rendered phrase.
    ///
    /// A bare `$0` qualifies because this only runs inside a `.naming` body,
    /// where the closure's argument is a `Noun`. A field of one of the
    /// two-thing role structs qualifies only if that field is *typed* `Noun`:
    /// `GameText.Aboard.place` is a plain `String` holding a room name, and
    /// room names are capitalized already, which is why the allowlist is
    /// spelled out rather than inferred. A role struct that gains a `Noun`
    /// field and is not added here goes unswept — a miss, never a false alarm.
    private static func isRenderedPhrase(_ expression: String) -> Bool {
        if expression == "$0" || expression == "$1" { return true }
        if expression.hasSuffix(".sentenceCased") { return true }
        if expression.hasPrefix("$0.") || expression.hasPrefix("$1.") {
            return nounFields.contains { expression.hasSuffix(".\($0)") }
        }
        return phraseSuffixes.contains { expression.hasSuffix(".\($0)") }
    }

    /// Whether the interpolation at `index` stands at the head of a sentence:
    /// the start of the literal, or after a full stop, or after a line break.
    private static func opensASentence(
        _ characters: [Character], before index: Int, lineStartCounts: Bool
    ) -> Bool {
        var cursor = index - 1
        var sawSpace = false
        while cursor >= 0, characters[cursor] == " " {
            sawSpace = true
            cursor -= 1
        }
        if cursor < 0 { return lineStartCounts }
        // An escaped newline inside a literal, written `\n`.
        if characters[cursor] == "n", cursor > 0, characters[cursor - 1] == "\\" { return true }
        guard sawSpace else { return false }
        return ".!?".contains(characters[cursor])
    }

    /// The article immediately before the interpolation, if a line wrote one.
    private static func article(before characters: [Character], at index: Int) -> String? {
        guard index > 0, characters[index - 1] == " " else { return nil }
        var cursor = index - 2
        var word = ""
        while cursor >= 0, characters[cursor].isLetter {
            word.insert(characters[cursor], at: word.startIndex)
            cursor -= 1
        }
        guard articles.contains(word.lowercased()) else { return nil }
        return word
    }
}

extension String {
    /// The line without its indentation, for an assertion message.
    fileprivate var trimmed: String { trimmingCharacters(in: .whitespaces) }
}
