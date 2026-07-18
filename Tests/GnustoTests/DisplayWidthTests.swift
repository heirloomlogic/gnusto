import Testing

@testable import Gnusto

@Suite("DisplayWidth")
struct DisplayWidthTests {
    @Test("ASCII characters are one column each")
    func asciiIsOne() {
        #expect(DisplayWidth.columns(of: "A") == 1)
        #expect(DisplayWidth.columns(of: " ") == 1)
        #expect(DisplayWidth.columns(of: "~") == 1)
    }

    @Test("CJK ideographs and fullwidth forms are two columns")
    func cjkAndFullwidthAreTwo() {
        #expect(DisplayWidth.columns(of: "世") == 2)  // U+4E16
        #expect(DisplayWidth.columns(of: "界") == 2)  // U+754C
        #expect(DisplayWidth.columns(of: "한") == 2)  // U+D55C Hangul syllable
        #expect(DisplayWidth.columns(of: "Ａ") == 2)  // U+FF21 fullwidth A
        #expect(DisplayWidth.columns(of: "あ") == 2)  // U+3042 Hiragana
    }

    @Test("Emoji are two columns, including ZWJ sequences and flags")
    func emojiAreTwo() {
        #expect(DisplayWidth.columns(of: "😀") == 2)  // single emoji
        #expect(DisplayWidth.columns(of: "👍") == 2)
        #expect(DisplayWidth.columns(of: "👨‍👩‍👧") == 2)  // ZWJ family, one grapheme
        #expect(DisplayWidth.columns(of: "🇯🇵") == 2)  // regional-indicator flag
        #expect(DisplayWidth.columns(of: "☺️") == 2)  // U+263A + VS16, emoji presentation
    }

    @Test("Combining marks and zero-width scalars add no columns")
    func zeroWidthScalars() {
        #expect(DisplayWidth.columns(of: "e\u{0301}") == 1)  // e + combining acute = é
        #expect(DisplayWidth.columns(of: "\u{200B}") == 0)  // zero-width space
        #expect(DisplayWidth.columns(of: "\u{200D}") == 0)  // zero-width joiner
    }

    @Test("String width sums its characters' columns")
    func stringWidthSums() {
        #expect(DisplayWidth.columns(of: "abc") == 3)
        #expect(DisplayWidth.columns(of: "世界") == 4)
        #expect(DisplayWidth.columns(of: "a世b") == 4)
        #expect(DisplayWidth.columns(of: "") == 0)
    }

    @Test("truncated stops before a glyph that would overflow the column limit")
    func truncatedClipsByColumns() {
        #expect(DisplayWidth.truncated("abcdef", toColumns: 3) == "abc")
        // "世界" is 4 columns; only the first fits in 3, and the wide second
        // glyph is dropped whole rather than half-drawn.
        #expect(DisplayWidth.truncated("世界", toColumns: 3) == "世")
        #expect(DisplayWidth.truncated("世界", toColumns: 4) == "世界")
        #expect(DisplayWidth.truncated("世界", toColumns: 1) == "")
    }
}
