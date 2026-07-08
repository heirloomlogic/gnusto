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
}
