import Foundation

/// Reflows prose to a column width for the full-screen terminal interpreter.
/// Pure and side-effect-free so it can be unit-tested without a live terminal.
///
/// The whole transcript is re-wrapped at the current width on every render, so
/// this is the one place the "smart reflow on resize" behavior actually lives.
///
/// Text is treated by Markdown's paragraph rule: a **single** newline inside a
/// paragraph is a soft break that folds to a space, and only a **blank line**
/// starts a new paragraph. Game prose is authored as multi-line `"""` literals
/// wrapped for source readability, so honoring those incidental newlines as
/// hard breaks would shatter the layout whenever the window is narrower than
/// the width the author happened to wrap at (dangling "This", "and", …).
/// Folding them makes the wrap depend only on the real terminal width.
///
/// For the rare *intentional* break within a paragraph (a banner's title over
/// its tagline, a sign, a scrap of verse), authors write the ``lineBreak``
/// marker `<br>` — non-whitespace, so unlike a trailing double space it
/// survives editors and formatters that trim line endings.
enum TextWrap {
    /// The in-band hard line-break marker (as in Markdown/HTML): a break within
    /// a paragraph, no blank line, formatter-proof. The full-screen renderer
    /// honors it through the fold; plain output turns it into a newline via
    /// ``plain(_:)`` so it never shows literally.
    static let lineBreak = "<br>"

    /// Renders game text for a plain, non-wrapping channel: turns the hard-break
    /// marker into a real newline. (Plain output doesn't fold, so a newline is
    /// already a visible break — only the marker needs translating.)
    ///
    /// - Parameter text: the game text to render.
    /// - Returns: the text with every `<br>` replaced by a newline.
    static func plain(_ text: String) -> String {
        text.replacingOccurrences(of: lineBreak, with: "\n")
    }

    /// Reflows `text` into visual lines no wider than `width` columns.
    ///
    /// Newlines within a paragraph fold to spaces; blank lines separate
    /// paragraphs and are rendered as a single empty line between them (runs of
    /// blank lines collapse to one). The ``lineBreak`` marker `<br>` forces a
    /// break without starting a new paragraph, for the rare intentional break.
    /// Words are packed greedily and broken only at spaces; a word longer than
    /// `width` (a URL, a long identifier) is hard-split into `width`-sized
    /// chunks rather than overflowing.
    ///
    /// - Parameters:
    ///   - text: the prose to reflow; single newlines are soft, blank lines are
    ///     paragraph breaks, `<br>` is a hard break.
    ///   - width: the column width to wrap to; values below 1 are treated as 1.
    /// - Returns: the visual lines, top to bottom (empty if `text` is blank).
    static func wrap(_ text: String, width: Int) -> [String] {
        let width = max(1, width)

        // Group source lines into paragraphs: a whitespace-only line is a
        // break; consecutive non-blank lines belong to the same paragraph.
        let sourceLines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var paragraphs: [[Substring]] = []
        var current: [Substring] = []
        for line in sourceLines {
            if line.allSatisfy(\.isWhitespace) {
                if !current.isEmpty {
                    paragraphs.append(current)
                    current = []
                }
            } else {
                current.append(line)
            }
        }
        if !current.isEmpty { paragraphs.append(current) }

        var lines: [String] = []
        for (index, paragraph) in paragraphs.enumerated() {
            if index > 0 { lines.append("") }  // one blank line between paragraphs

            // Fold the paragraph's soft breaks to spaces, then split on the
            // hard-break marker into segments that wrap independently but stay
            // adjacent (no paragraph gap between them).
            let folded = paragraph.joined(separator: " ")
            for segment in folded.components(separatedBy: lineBreak) {
                let words = segment.split(separator: " ", omittingEmptySubsequences: true)
                lines += wrapWords(words, width: width)
            }
        }
        return lines
    }

    /// Greedily packs `words` into lines of at most `width` columns, hard-
    /// splitting any single word that is itself wider than the column. All
    /// width comparisons are in terminal columns (``DisplayWidth``), not Swift
    /// `Character` counts, so CJK and emoji pack correctly.
    private static func wrapWords(_ words: [Substring], width: Int) -> [String] {
        var lines: [String] = []
        var current = ""
        var currentWidth = 0
        for word in words {
            let wordWidth = DisplayWidth.columns(of: word)
            if wordWidth > width {
                if !current.isEmpty {
                    lines.append(current)
                    current = ""
                    currentWidth = 0
                }
                // Emit the full-width chunks and carry the remainder, so the
                // next word can still pack onto that trailing partial line.
                let chunks = hardSplit(word, width: width)
                lines += chunks.dropLast()
                current = chunks.last ?? ""
                currentWidth = DisplayWidth.columns(of: current)
                continue
            }

            if current.isEmpty {
                current = String(word)
                currentWidth = wordWidth
            } else if currentWidth + 1 + wordWidth <= width {
                current += " " + word
                currentWidth += 1 + wordWidth
            } else {
                lines.append(current)
                current = String(word)
                currentWidth = wordWidth
            }
        }
        if !current.isEmpty { lines.append(current) }
        return lines
    }

    /// The character offsets at which each visual line begins when `text` is
    /// hard-wrapped to `width` columns — always `[0]` for the first line, plus
    /// one entry per subsequent line. A glyph never straddles the boundary: a
    /// wide glyph that cannot finish on the current line slides whole to the
    /// next, leaving a blank trailing cell, exactly as a terminal renders it.
    ///
    /// This is the single source of truth shared by ``hardSplit(_:width:)`` and
    /// ``caretPosition(in:charOffset:width:)`` so the input line's layout and
    /// its caret can never disagree.
    static func lineStarts(of text: Substring, width: Int) -> [Int] {
        let width = max(1, width)
        var starts = [0]
        var column = 0
        for (offset, character) in text.enumerated() {
            let glyphWidth = DisplayWidth.columns(of: character)
            if column != 0, column + glyphWidth > width {
                starts.append(offset)
                column = 0
            }
            column += glyphWidth
        }
        return starts
    }

    /// Splits `text` into consecutive chunks that each fit within `width`
    /// columns, preserving every character (no space collapsing) — the
    /// primitive behind both the prose long-word split above and the terminal's
    /// input line, where exact caret positions must survive.
    ///
    /// - Parameters:
    ///   - text: the text to chunk.
    ///   - width: the chunk width in columns; values below 1 are treated as 1.
    /// - Returns: the chunks in order; a single element when `text` fits.
    static func hardSplit(_ text: Substring, width: Int) -> [String] {
        let starts = lineStarts(of: text, width: width)
        let characters = Array(text)
        var chunks: [String] = []
        for (line, start) in starts.enumerated() {
            let end = line + 1 < starts.count ? starts[line + 1] : characters.count
            chunks.append(String(characters[start..<end]))
        }
        return chunks
    }

    /// Where the caret sits when `text` is hard-wrapped to `width` columns and
    /// the logical cursor is before character `charOffset` — the visual line
    /// index (0-based from the first line) and the column within it (0-based).
    ///
    /// Uses the same ``lineStarts(of:width:)`` breaks as ``hardSplit(_:width:)``
    /// so the caret always lands on the glyph the layout drew. A caret that
    /// exactly fills a line wraps to the start of the next line, matching a
    /// terminal's behavior when the next keystroke would overflow.
    static func caretPosition(
        in text: Substring, charOffset: Int, width: Int
    ) -> (line: Int, column: Int) {
        let width = max(1, width)
        let characters = Array(text)
        let offset = min(max(0, charOffset), characters.count)
        let starts = lineStarts(of: text, width: width)

        // The caret's line is the last one that begins at or before the offset.
        let line = starts.lastIndex(where: { $0 <= offset }) ?? 0

        let column = DisplayWidth.columns(of: characters[starts[line]..<offset])
        if column == width { return (line + 1, 0) }  // exact fill wraps to next line
        return (line, column)
    }
}
