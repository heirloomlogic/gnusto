import Foundation

/// How many terminal columns a piece of text occupies when printed to a
/// monospaced, character-cell terminal.
///
/// A terminal cell is not a Swift `Character`: CJK ideographs, fullwidth forms,
/// and most emoji occupy **two** cells, while combining marks, zero-width
/// joiners, and variation selectors occupy **none**. Column math done with
/// `String.count` therefore drifts out of alignment the moment such text
/// appears — wrapped lines overflow the window and the caret lands on the wrong
/// cell. This is the one place that translation lives, so `TextWrap` and
/// `TerminalIOHandler` can reason in cells instead of graphemes.
///
/// The width of a grapheme cluster is approximated the way `wcwidth`-style
/// implementations do: East Asian Wide/Fullwidth scalars count as two, format /
/// combining / control scalars as zero, everything else as one, with emoji
/// (including multi-scalar ZWJ sequences and flags) forced to two. It is not a
/// full Unicode UAX #11 table, but it is correct for the text games actually
/// render.
enum DisplayWidth {
    /// The number of terminal columns `character` occupies (0, 1, or 2).
    static func columns(of character: Character) -> Int {
        // Emoji render two cells wide as a whole cluster, including ZWJ
        // sequences (families, professions), flags (regional indicators), and
        // text-default symbols upgraded to emoji presentation by VS16.
        let scalars = character.unicodeScalars
        if scalars.contains(where: { $0.value == 0xFE0F || $0.properties.isEmojiPresentation }) {
            return 2
        }

        var total = 0
        for scalar in scalars {
            switch scalar.properties.generalCategory {
            case .nonspacingMark, .enclosingMark, .format, .control:
                continue  // combining marks, ZWJ, variation selectors: zero width
            default:
                total += isWide(scalar) ? 2 : 1
            }
        }
        return total
    }

    /// The number of terminal columns a sequence of characters occupies —
    /// covers `String`, `Substring`, and `ArraySlice<Character>`.
    static func columns<S: Sequence>(of characters: S) -> Int where S.Element == Character {
        characters.reduce(0) { $0 + columns(of: $1) }
    }

    /// The longest prefix of `text` that fits within `limit` columns, stopping
    /// before a glyph that would overflow (so a trailing wide glyph is dropped
    /// whole rather than half-drawn). Used to clip the status bar.
    static func truncated(_ text: some StringProtocol, toColumns limit: Int) -> String {
        var result = ""
        var used = 0
        for character in text {
            let width = columns(of: character)
            if used + width > limit { break }
            used += width
            result.append(character)
        }
        return result
    }

    /// Whether a scalar is East Asian Wide or Fullwidth (two cells). A compact
    /// stand-in for the UAX #11 table covering the blocks that appear in game
    /// text: Hangul, the CJK ideograph and Kana blocks, fullwidth forms, the
    /// CJK extensions, and the emoji pictograph blocks.
    private static func isWide(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x1100...0x115F,  // Hangul Jamo
            0x2E80...0x303E,  // CJK radicals, Kangxi radicals, CJK symbols
            0x3041...0x33FF,  // Hiragana, Katakana, CJK symbols & compatibility
            0x3400...0x4DBF,  // CJK Unified Ideographs Extension A
            0x4E00...0x9FFF,  // CJK Unified Ideographs
            0xA000...0xA4CF,  // Yi syllables
            0xAC00...0xD7A3,  // Hangul syllables
            0xF900...0xFAFF,  // CJK Compatibility Ideographs
            0xFE30...0xFE4F,  // CJK Compatibility Forms
            0xFF00...0xFF60,  // Fullwidth forms
            0xFFE0...0xFFE6,  // Fullwidth signs
            0x1F300...0x1FAFF,  // Symbols & Pictographs (emoji)
            0x20000...0x3FFFD:  // CJK Unified Ideographs Extension B and beyond
            return true
        default:
            return false
        }
    }
}
