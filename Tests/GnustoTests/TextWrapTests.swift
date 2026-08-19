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

    @Test("plain() folds a paragraph the same way wrap() does")
    func plainFoldsLikeWrap() {
        // The two channels used to disagree here, which is what made a trailing
        // `\` on every prose line look like a convention.
        #expect(TextWrap.plain("line one\nline two") == "line one line two")
        #expect(TextWrap.plain("a\nb\n\nc\nd") == "a b\n\nc d")
    }

    @Test("plain() folds before it substitutes the marker")
    func plainFoldsBeforeSubstituting() {
        // The other order turns <br> into a newline that the fold then eats,
        // silently downgrading a hard break to a space.
        #expect(TextWrap.plain("Title\nHere<br>The\nsubtitle") == "Title Here\nThe subtitle")
        // And the space the fold joined on does not survive as an indent.
        #expect(TextWrap.plain("Title<br>\nTagline") == "Title\nTagline")
    }

    @Test("plain() keeps a form's shape and the block separators around it")
    func plainKeepsFormsAndSeparators() {
        #expect(
            TextWrap.plain("inscribed\n\n  Abandon every hope\n  all ye who enter here!\n\n")
                == "inscribed\n\n  Abandon every hope\n  all ye who enter here!\n\n")
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

    // MARK: - Forms (preformatted blocks)

    @Test("An indented line keeps its shape and its indentation")
    func preformattedLineSurvives() {
        // Two spaces past the margin is a form, not prose: it does not fold
        // into the sentence above it and it is not re-packed on spaces.
        #expect(
            TextWrap.wrap("inscribed\n\n  Abandon every hope\n  all ye who enter here!", width: 40)
                == ["inscribed", "", "  Abandon every hope", "  all ye who enter here!"])
    }

    @Test("A form does not fold into the prose on either side of it")
    func preformattedDoesNotFoldAtItsSeams() {
        // No blank lines at all: the seam above and below the form is still a
        // hard break, because one of the two lines is preformatted.
        #expect(
            TextWrap.wrap("above\n  the form\nbelow", width: 40)
                == ["above", "  the form", "below"])
    }

    @Test("Adjacent form lines stay separate lines")
    func preformattedLinesDoNotFoldTogether() {
        #expect(
            TextWrap.wrap("  a b\n  c d", width: 40) == ["  a b", "  c d"])
    }

    @Test("Inner spacing inside a form is preserved, never collapsed")
    func preformattedKeepsInnerSpacing() {
        // The letter-rings in Dungeon are built entirely from run-length
        // spacing; collapsing it is what made them unreadable.
        #expect(
            TextWrap.wrap("    .    ? A G I ?    .", width: 60)
                == ["    .    ? A G I ?    ."])
    }

    @Test("A form wider than the column is chopped, never overflowed")
    func preformattedWiderThanColumnIsChopped() {
        #expect(TextWrap.wrap("  abcdefgh", width: 5) == ["  abc", "defgh"])
    }

    @Test("A tab-indented line is a form too")
    func tabIndentIsPreformatted() {
        #expect(TextWrap.wrap("above\n\tthe form", width: 40) == ["above", "\tthe form"])
    }

    @Test("One leading space is prose, not a form")
    func oneLeadingSpaceStillFolds() {
        // The threshold is two, so a single stray space — the shape a composed
        // value can produce at runtime — still folds and still collapses.
        #expect(TextWrap.wrap("above\n below", width: 40) == ["above below"])
    }

    @Test("fold() leaves blank runs, leading and trailing newlines alone")
    func foldPreservesBlankStructure() {
        // The REPL hands plain() a turn's output already terminated by "\n\n";
        // a fold that normalized that would fuse turn blocks together.
        #expect(TextWrap.fold("one\ntwo\n\n") == "one two\n\n")
        #expect(TextWrap.fold("\n\nlead") == "\n\nlead")
        #expect(TextWrap.fold("a\n\n\n\nb") == "a\n\n\n\nb")
        #expect(TextWrap.fold("") == "")
    }

    @Test("fold() trims the seam it joins on, from both sides")
    func foldTrimsTheSeam() {
        #expect(TextWrap.fold("one \n two") == "one two")
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
