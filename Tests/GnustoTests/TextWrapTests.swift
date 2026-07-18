import Testing

@testable import Gnusto

@Suite("TextWrap")
struct TextWrapTests {
    @Test("Short text fits on one line")
    func shortTextOneLine() {
        #expect(TextWrap.wrap("hello world", width: 40) == ["hello world"])
    }

    @Test("Wraps at word boundaries, never mid-word")
    func wrapsAtWordBoundaries() {
        // "the quick brown fox" at width 9: "the quick" (9) then "brown fox" (9).
        #expect(TextWrap.wrap("the quick brown fox", width: 9) == ["the quick", "brown fox"])
    }

    @Test("Never exceeds the width")
    func neverExceedsWidth() {
        let text = "one two three four five six seven eight nine ten eleven twelve"
        for line in TextWrap.wrap(text, width: 12) {
            #expect(line.count <= 12)
        }
    }

    @Test("A word longer than the width is hard-split")
    func hardSplitsLongWord() {
        #expect(TextWrap.wrap("abcdefghij", width: 4) == ["abcd", "efgh", "ij"])
    }

    @Test("A long word flushes the pending line first")
    func longWordFlushesPending() {
        // "hi" packs, then the 6-wide word can't fit width 4, so "hi" flushes.
        #expect(TextWrap.wrap("hi abcdef x", width: 4) == ["hi", "abcd", "ef x"])
    }

    @Test("A single newline inside a paragraph folds to a space (Markdown rule)")
    func foldsSoftNewlines() {
        // This is the crux: source-wrapped prose must not break at the author's
        // incidental newline, only at the real column width.
        #expect(TextWrap.wrap("line one\nline two", width: 40) == ["line one line two"])
    }

    @Test("Folded soft newlines still re-wrap at the target width")
    func foldsThenReWraps() {
        // Two source lines wrapped at ~14 cols, reflowed to width 9.
        #expect(
            TextWrap.wrap("the quick\nbrown fox", width: 9) == ["the quick", "brown fox"])
    }

    @Test("A blank line starts a new paragraph")
    func blankLineSeparatesParagraphs() {
        #expect(TextWrap.wrap("a\nb\n\nc\nd", width: 40) == ["a b", "", "c d"])
    }

    @Test("Runs of blank lines collapse to a single separator")
    func collapsesMultipleBlankLines() {
        #expect(TextWrap.wrap("a\n\n\n\nb", width: 40) == ["a", "", "b"])
    }

    @Test("The <br> marker is a hard break within a paragraph")
    func brHardBreak() {
        // No blank line, so it stays one paragraph, but the break is honored —
        // the two parts don't fold together. (Used by the title/tagline banner.)
        #expect(TextWrap.wrap("Title Here<br>The subtitle", width: 40) == ["Title Here", "The subtitle"])
    }

    @Test("<br> survives a soft fold and still breaks")
    func brBreaksAcrossSoftWrap() {
        // Authored across two source lines with a <br> at the seam.
        #expect(TextWrap.wrap("Title\nHere<br>The\nsubtitle", width: 40) == ["Title Here", "The subtitle"])
    }

    @Test("plain() turns <br> into a newline and leaves prose alone")
    func plainConvertsBr() {
        #expect(TextWrap.plain("Title<br>Tagline") == "Title\nTagline")
        #expect(TextWrap.plain("no markup here") == "no markup here")
    }

    @Test("Empty input yields no lines")
    func emptyInput() {
        #expect(TextWrap.wrap("", width: 40) == [])
    }

    @Test("Collapses runs of spaces between words")
    func collapsesInnerSpaces() {
        #expect(TextWrap.wrap("a    b", width: 40) == ["a b"])
    }

    @Test("Width below 1 is treated as 1, not an infinite loop")
    func widthFloor() {
        #expect(TextWrap.wrap("ab", width: 0) == ["a", "b"])
    }

    // MARK: - Wide characters (CJK / emoji)

    @Test("Wide glyphs pack by column, never overflowing the width")
    func wideGlyphsNeverExceedWidthInColumns() {
        // Each ideograph is two columns; at width 6 exactly three fit per line.
        let text = "世界世界世界世界"
        for line in TextWrap.wrap(text, width: 6) {
            #expect(DisplayWidth.columns(of: line) <= 6)
        }
    }

    @Test("A run of wide glyphs hard-splits at the column boundary")
    func hardSplitWideGlyphs() {
        // Three 2-column glyphs fill width 6; the fourth starts a new line.
        #expect(TextWrap.hardSplit("世界世界世界", width: 6) == ["世界世", "界世界"])
    }

    @Test("A wide glyph that can't finish the line slides whole to the next")
    func wideGlyphDoesNotStraddleBoundary() {
        // At width 3, one glyph fills two columns; the second can't fit the
        // remaining column, so it moves down, leaving a blank trailing cell.
        #expect(TextWrap.hardSplit("世界", width: 3) == ["世", "界"])
    }

    @Test("Emoji words wrap by display column")
    func emojiWordsWrap() {
        // "😀" is two columns; at width 5 two emoji plus a space fit (5), the
        // third can't (would be 8).
        #expect(TextWrap.wrap("😀 😀 😀", width: 5) == ["😀 😀", "😀"])
    }

    // MARK: - Caret placement

    @Test("Caret column counts display columns, not characters")
    func caretColumnUsesDisplayWidth() {
        // After two ideographs (4 columns) the caret sits at column 4, line 0.
        #expect(TextWrap.caretPosition(in: "世界", charOffset: 2, width: 40).line == 0)
        #expect(TextWrap.caretPosition(in: "世界", charOffset: 2, width: 40).column == 4)
    }

    @Test("Caret lands on the wrapped line the layout drew")
    func caretFollowsWrap() {
        // "世界世界世界" wraps to ["世界世", "界世界"] at width 6. Character
        // offset 3 is the first glyph of the second line: line 1, column 0.
        let pos = TextWrap.caretPosition(in: "世界世界世界", charOffset: 3, width: 6)
        #expect(pos.line == 1)
        #expect(pos.column == 0)
    }

    @Test("A caret that exactly fills a line wraps to the next line's start")
    func caretExactFillWraps() {
        // "abcd" at width 4 fills the line exactly; the caret at the end moves
        // to the start of the next line, where the next keystroke would land.
        let pos = TextWrap.caretPosition(in: "abcd", charOffset: 4, width: 4)
        #expect(pos.line == 1)
        #expect(pos.column == 0)
    }

    @Test("Caret at the start of each hard-split line reports that line, column 0")
    func caretAgreesWithHardSplit() {
        // The caret math and the layout share `lineStarts`, so a caret at a
        // line boundary must report exactly that line at column 0.
        let text: Substring = "one two three four five"
        let width = 9
        let starts = TextWrap.lineStarts(of: text, width: width)
        for (line, start) in starts.enumerated() {
            let pos = TextWrap.caretPosition(in: text, charOffset: start, width: width)
            #expect(pos.line == line)
            #expect(pos.column == 0)
        }
    }
}
