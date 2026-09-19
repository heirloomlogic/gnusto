import Foundation
import Testing

@testable import Gnusto

/// The one sanitizer both the save store and the transcript store name files
/// through.
struct FilesystemNameTests {
    // MARK: Unicode

    /// The bug in #488: two Japanese names both held nothing the old ASCII rule
    /// kept, so both became the literal slot `save` and the second overwrote
    /// the first.
    @Test func twoCJKNamesAreTwoDifferentComponents() {
        let one = FilesystemName.component("セーブ")
        let two = FilesystemName.component("日本語")
        #expect(one == "セーブ")
        #expect(two == "日本語")
        #expect(one != two)
    }

    @Test func accentedLatinSurvivesWhole() {
        #expect(FilesystemName.component("résumé") == "résumé")
        #expect(FilesystemName.component("Grüße") == "Grüße")
    }

    @Test func mixedScriptKeepsBothSidesAndHyphensTheGap() {
        #expect(FilesystemName.component("chapter 二 · 中盤") == "chapter-二-中盤")
    }

    @Test func unicodeDigitsAreNumbers() {
        #expect(FilesystemName.component("٣") == "٣")
    }

    /// NFD and NFC of the same name have to reach the same file, because macOS
    /// and Linux disagree about which form a filename comes back in.
    @Test func decomposedAndComposedFormsAgree() {
        let composed = "café"  // é as one scalar
        let decomposed = "cafe\u{0301}"  // e + combining acute
        #expect(composed.unicodeScalars.count != decomposed.unicodeScalars.count)
        #expect(FilesystemName.component(composed) == FilesystemName.component(decomposed))
    }

    // MARK: Nothing usable

    @Test func allPunctuationIsNil() {
        #expect(FilesystemName.component("!!!") == nil)
        #expect(FilesystemName.component("...") == nil)
        #expect(FilesystemName.component("..") == nil)
        #expect(FilesystemName.component("") == nil)
        #expect(FilesystemName.component("   ") == nil)
        #expect(FilesystemName.component("-–—") == nil)
    }

    /// An emoji is neither a letter nor a number, so a name made only of them
    /// is refused rather than quietly named after somebody else's save.
    @Test func emojiOnlyIsNil() {
        #expect(FilesystemName.component("🎉🎉") == nil)
    }

    // MARK: Path safety

    @Test func pathSeparatorsAndDotsCannotWalkOut() {
        #expect(FilesystemName.component("../../etc/passwd") == "etc-passwd")
        #expect(FilesystemName.component("a/b") == "a-b")
        #expect(FilesystemName.component("a\\b") == "a-b")
        #expect(FilesystemName.component("/") == nil)
    }

    /// A leading dot would make a dotfile, and the history sidecar is a dotfile
    /// in the same directory.
    @Test func aLeadingDotIsNotKept() {
        #expect(FilesystemName.component(".history") == "history")
        #expect(FilesystemName.component(".") == nil)
    }

    @Test func controlCharactersAreSeparators() {
        #expect(FilesystemName.component("a\u{0000}b") == "a-b")
        #expect(FilesystemName.component("a\nb\tc") == "a-b-c")
        #expect(FilesystemName.component("\u{202E}") == nil)
    }

    // MARK: Length

    @Test func aVeryLongNameIsBoundedInBytes() throws {
        let long = String(repeating: "a", count: 500)
        let component = try #require(FilesystemName.component(long))
        #expect(component.utf8.count <= FilesystemName.maximumBytes)
    }

    /// The budget is bytes, not characters: a CJK character is three bytes, so
    /// a name that is short in characters can still be long on disk.
    @Test func multibyteCharactersCountTheirBytes() throws {
        let long = String(repeating: "書", count: 200)
        let component = try #require(FilesystemName.component(long))
        #expect(component.utf8.count <= FilesystemName.maximumBytes)
        #expect(component.count < 200)
        // Cut on a character boundary, never mid-scalar.
        #expect(component.allSatisfy { $0 == "書" })
    }

    @Test func truncationDoesNotLeaveATrailingHyphen() throws {
        // A run of two-character words: wherever the cut lands, the result
        // still reads as something the sanitizer would return unchanged.
        let long = String(repeating: "ab ", count: 200)
        let component = try #require(FilesystemName.component(long))
        #expect(!component.hasSuffix("-"))
        #expect(FilesystemName.component(component) == component)
    }

    // MARK: Idempotence

    /// Every store resolves a name it read back off disk through here again, so
    /// the second pass has to be a no-op or the file becomes unreachable.
    @Test func theTransformIsIdempotent() {
        let names = [
            "autumn", "my   save", "セーブ", "chapter 二 · 中盤", "résumé",
            "../../etc/passwd", "a-b", "_under_", "Zork I: The Great Underground Empire",
            String(repeating: "書", count: 200), String(repeating: "ab ", count: 200),
        ]
        for name in names {
            guard let once = FilesystemName.component(name) else { continue }
            #expect(FilesystemName.component(once) == once, "\(name)")
        }
    }

    // MARK: No migration break

    /// Existing saves keep their filenames. For a plain ASCII name inside the
    /// byte bound the new rule has to agree character for character with the old
    /// one, which kept `[A-Za-z0-9_]` and collapsed every other run to a hyphen.
    @Test func asciiNamesResolveExactlyAsTheOldSanitizerDid() {
        let ascii = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")
        func old(_ raw: String) -> String {
            let squeezed = String(raw.map { ascii.contains($0) ? $0 : " " })
                .split(separator: " ")
                .joined(separator: "-")
            return squeezed
        }
        let corpus = [
            "autumn", "my   save", "save1", "Save_2", "a-b", "a.b", "a..b",
            "..", "before the troll", "Zork I: The Great Underground Empire",
            "The Lighthouse", "slot 99", "___", "-x-", "x!", "9",
        ]
        for name in corpus {
            let expected = old(name)
            #expect(
                FilesystemName.component(name) == (expected.isEmpty ? nil : expected),
                "\(name)")
        }
    }

    /// The bound is the one place the parity stops, and it is where an existing
    /// save could go missing. The old rule had no bound, so a name over the
    /// budget names a file of its full length; the new rule cuts it, and
    /// ``FilesystemName/unbounded(_:)`` is the form that still matches that file.
    @Test func aNameOverTheBoundIsTheOneCaseTheOldRuleDisagreesWith() throws {
        let ascii = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")
        func old(_ raw: String) -> String {
            String(raw.map { ascii.contains($0) ? $0 : " " })
                .split(separator: " ")
                .joined(separator: "-")
        }
        let long = String(repeating: "a", count: 210)
        #expect(old(long).utf8.count == 210)
        #expect(FilesystemName.component(long) == String(repeating: "a", count: 200))
        #expect(FilesystemName.unbounded(long) == old(long))

        // And with the separators the old rule collapsed, so the disagreement is
        // only ever the cut.
        let longPhrase = String(repeating: "slot 99! ", count: 40)
        #expect(FilesystemName.unbounded(longPhrase) == old(longPhrase))
        let component = try #require(FilesystemName.component(longPhrase))
        #expect(old(longPhrase).hasPrefix(component))
    }

    /// The old rule folded no case, and neither does this one. Written down as a
    /// test because the volume, not this rule, decides whether the two names are
    /// two files.
    @Test func caseIsKeptAsTyped() {
        #expect(FilesystemName.component("Autumn") == "Autumn")
        #expect(FilesystemName.component("autumn") == "autumn")
        #expect(FilesystemName.legacyComponent("Autumn") == "Autumn")
    }
}
