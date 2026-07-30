import Testing

@testable import Gnusto

/// ``TerminalIOHandler/applyPaste(_:input:cursor:)``: what a bracketed paste does
/// to the line being edited. Pasting into a `//` or `#` comment folds the block
/// into one line; pasting anywhere else keeps one command per line, so replaying a
/// walkthrough by paste still works (issue #78).
@Suite("TerminalIOHandler.applyPaste")
struct TerminalPasteTests {
    // MARK: - Pasting into a comment: newlines fold to spaces

    @Test func commentBufferJoinsPastedLinesWithSingleSpaces() {
        let out = TerminalIOHandler.applyPaste("one\ntwo\nthree", input: "// ", cursor: 3)
        #expect(out.newInput == "// one two three")
        #expect(out.newCursor == 16)
        #expect(out.submitted.isEmpty)
    }

    @Test func hashCommentJoinsTheSameWay() {
        let out = TerminalIOHandler.applyPaste("one\ntwo", input: "# ", cursor: 2)
        #expect(out.newInput == "# one two")
        #expect(out.submitted.isEmpty)
    }

    /// A CRLF-terminated paste sends both `\r` and `\n`, which decode to two
    /// `.enter` keys — the bug that motivated folding the paste as text, where
    /// `"\r\n"` is a single `Character`.
    @Test func crlfPasteJoinsWithOneSpaceNotTwo() {
        let out = TerminalIOHandler.applyPaste("one\r\ntwo\r\nthree", input: "// ", cursor: 3)
        #expect(out.newInput == "// one two three")
    }

    @Test func blankLineInsidePasteJoinsWithOneSpace() {
        let out = TerminalIOHandler.applyPaste("one\n\n\ntwo", input: "// ", cursor: 3)
        #expect(out.newInput == "// one two")
    }

    /// Wrapped prose usually carries indentation. Whitespace around a break
    /// collapses into the single joining space rather than stacking up.
    @Test func indentationAroundALineBreakCollapsesToOneSpace() {
        let out = TerminalIOHandler.applyPaste("one   \n    two", input: "// ", cursor: 3)
        #expect(out.newInput == "// one two")
    }

    @Test func trailingNewlineAddsNoTrailingSpace() {
        let out = TerminalIOHandler.applyPaste("one\ntwo\n", input: "// ", cursor: 3)
        #expect(out.newInput == "// one two")
    }

    /// A literal tab measures zero columns in ``DisplayWidth`` but advances the
    /// real terminal, so one surviving in the buffer would desync the caret math
    /// for the rest of the line.
    @Test func tabBecomesASpaceAndNoTabSurvives() {
        let out = TerminalIOHandler.applyPaste("one\ttwo", input: "// ", cursor: 3)
        #expect(out.newInput == "// one two")
        #expect(!out.newInput.contains("\t"))
    }

    @Test func controlBytesInAPasteAreDropped() {
        let out = TerminalIOHandler.applyPaste("a\u{03}b\u{7F}c", input: "// ", cursor: 3)
        #expect(out.newInput == "// abc")
    }

    @Test func pasteOfOnlyNewlinesLeavesTheCommentUnchanged() {
        let out = TerminalIOHandler.applyPaste("\n\n", input: "// note", cursor: 7)
        #expect(out.newInput == "// note")
        #expect(out.newCursor == 7)
        #expect(out.submitted.isEmpty)
    }

    @Test func singleLinePasteIntoACommentIsAPlainInsertion() {
        // No newline, so nothing to fold: the text lands exactly as typed,
        // leading spaces included.
        let out = TerminalIOHandler.applyPaste("  hello", input: "//", cursor: 2)
        #expect(out.newInput == "//  hello")
        #expect(out.newCursor == 9)
    }

    @Test func commentPasteLandsAtTheCaretNotTheEnd() {
        let out = TerminalIOHandler.applyPaste("one\ntwo", input: "// [] end", cursor: 4)
        #expect(out.newInput == "// [one two] end")
        #expect(out.newCursor == 11)
    }

    // MARK: - Pasting a walkthrough: one command per line

    @Test func emptyBufferSubmitsOneLinePerPastedLine() {
        let out = TerminalIOHandler.applyPaste("look\ninventory\nlook\n", input: "", cursor: 0)
        #expect(out.submitted == ["look", "inventory", "look"])
        #expect(out.newInput.isEmpty)
        #expect(out.newCursor == 0)
    }

    @Test func pasteWithoutATrailingNewlineLeavesTheLastLineInTheBuffer() {
        let out = TerminalIOHandler.applyPaste("look\ntake lamp", input: "", cursor: 0)
        #expect(out.submitted == ["look"])
        #expect(out.newInput == "take lamp")
        #expect(out.newCursor == 9)
    }

    @Test func blankLinesSubmitNothing() {
        // Otherwise each one runs an empty turn and earns an "I beg your pardon?".
        let out = TerminalIOHandler.applyPaste("look\n\n   \ninventory\n", input: "", cursor: 0)
        #expect(out.submitted == ["look", "inventory"])
    }

    @Test func singleLinePasteIsAPlainInsertion() {
        let out = TerminalIOHandler.applyPaste("lamp", input: "take ", cursor: 5)
        #expect(out.submitted.isEmpty)
        #expect(out.newInput == "take lamp")
        #expect(out.newCursor == 9)
    }

    @Test func aPartiallyTypedLineIsCompletedByTheFirstPastedLine() {
        let out = TerminalIOHandler.applyPaste("lamp\ndrop lamp", input: "take ", cursor: 5)
        #expect(out.submitted == ["take lamp"])
        #expect(out.newInput == "drop lamp")
        #expect(out.newCursor == 9)
    }

    @Test func pasteAtAMidLineCaretSplitsAroundTheCaret() {
        let out = TerminalIOHandler.applyPaste("a\nb", input: "xy", cursor: 1)
        #expect(out.submitted == ["xa"])
        #expect(out.newInput == "by")
        #expect(out.newCursor == 1)  // after the pasted tail, before the old remainder
    }

    /// The comment-or-not decision is made once, on the buffer as it stands
    /// before the paste. A `//` appearing inside the pasted text doesn't switch
    /// modes partway through.
    @Test func commentMarkerInsideThePastedTextDoesNotSwitchModes() {
        let out = TerminalIOHandler.applyPaste("look\n// a note\nlook", input: "", cursor: 0)
        #expect(out.submitted == ["look", "// a note"])
        #expect(out.newInput == "look")
    }

    @Test func emptyPasteIsANoOp() {
        let out = TerminalIOHandler.applyPaste("", input: "take lamp", cursor: 4)
        #expect(out.submitted.isEmpty)
        #expect(out.newInput == "take lamp")
        #expect(out.newCursor == 4)
    }

    @Test func aCursorOutsideTheBufferIsClamped() {
        let out = TerminalIOHandler.applyPaste("x", input: "ab", cursor: 99)
        #expect(out.newInput == "abx")
        #expect(out.newCursor == 3)
    }
}
