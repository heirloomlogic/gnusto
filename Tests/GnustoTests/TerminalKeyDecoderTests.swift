import Testing

@testable import Gnusto

/// ``KeyDecoder``: the byte-to-keypress layer behind the terminal line editor.
/// The byte source is injected, so every branch of the escape table is reachable
/// from a test without a live terminal.
@Suite("KeyDecoder")
struct TerminalKeyDecoderTests {
    // MARK: - Printable characters

    @Test func asciiDecodesOneCharacterPerByte() {
        #expect(decode("hi") == [.character("h"), .character("i")])
    }

    @Test func multiByteUTF8DecodesToOneCharacter() {
        #expect(decode("é") == [.character("é")])
        #expect(decode("🕯") == [.character("🕯")])
        #expect(decode("a🕯b") == [.character("a"), .character("🕯"), .character("b")])
    }

    @Test func truncatedUTF8AtEndOfInputIsSkippedWithoutHanging() {
        // A lead byte promising a continuation that never arrives.
        #expect(decode([0xC3]) == [])
    }

    @Test func invalidUTF8IsSkippedAndDecodingContinues() {
        #expect(decode([0xFF, 0x61]) == [.character("a")])
    }

    // MARK: - Control bytes

    @Test func carriageReturnAndLineFeedBothSubmit() {
        #expect(decode("\n") == [.enter])
        #expect(decode("\r") == [.enter])
        #expect(decode("\r\n") == [.enter, .enter])  // the reason a CRLF paste needs folding
    }

    @Test func controlBytesMapToEditingKeys() {
        #expect(decode("\u{03}") == [.interrupt])  // Ctrl-C
        #expect(decode("\u{04}") == [.eof])  // Ctrl-D
        #expect(decode("\u{09}") == [.tab])
        #expect(decode("\u{7F}") == [.backspace])  // DEL
        #expect(decode("\u{08}") == [.backspace])  // Ctrl-H
    }

    @Test func otherControlBytesAreIgnored() {
        #expect(decode("\u{01}a\u{02}b\u{1F}") == [.character("a"), .character("b")])
    }

    // MARK: - Escape sequences

    @Test func arrowKeysDecodeFromBothCSIAndSS3() {
        #expect(decode("\u{1B}[A") == [.historyPrev])
        #expect(decode("\u{1B}[B") == [.historyNext])
        #expect(decode("\u{1B}[C") == [.right])
        #expect(decode("\u{1B}[D") == [.left])
        // SS3 form, as sent in application-cursor mode.
        #expect(decode("\u{1B}OA") == [.historyPrev])
        #expect(decode("\u{1B}OD") == [.left])
    }

    @Test func homeEndDeleteAndPageKeysDecode() {
        #expect(decode("\u{1B}[H") == [.home])
        #expect(decode("\u{1B}OH") == [.home])
        #expect(decode("\u{1B}[1~") == [.home])
        #expect(decode("\u{1B}[7~") == [.home])
        #expect(decode("\u{1B}[F") == [.end])
        #expect(decode("\u{1B}OF") == [.end])
        #expect(decode("\u{1B}[4~") == [.end])
        #expect(decode("\u{1B}[8~") == [.end])
        #expect(decode("\u{1B}[3~") == [.deleteForward])
        #expect(decode("\u{1B}[5~") == [.pageUp])
        #expect(decode("\u{1B}[6~") == [.pageDown])
    }

    @Test func unrecognizedSequencesAreDiscarded() {
        #expect(decode("\u{1B}[Z") == [])  // Shift-Tab; no meaning here
        #expect(decode("\u{1B}[9~") == [])  // an unassigned numeric parameter
        #expect(decode("\u{1B}[Za") == [.character("a")])  // and decoding resumes
    }

    @Test func bareEscapeIsSwallowedAlongWithTheByteAfterIt() {
        #expect(decode("\u{1B}") == [])
        // The byte that proves it wasn't a CSI introducer is consumed with it.
        #expect(decode("\u{1B}ab") == [.character("b")])
    }

    @Test func sequenceTruncatedBeforeItsIntroducerIsDiscarded() {
        #expect(decode("\u{1B}[") == [])
    }

    /// A numeric parameter that runs out of bytes resolves on what it has, rather
    /// than waiting for the `~`. Pinned rather than fixed: a real terminal sends a
    /// sequence as one burst, so this only bites if one is split across the 0.1s
    /// `VTIME` poll boundary, and the parameter is unambiguous by then anyway.
    @Test func unterminatedNumericParameterResolvesOnWhatItHas() {
        #expect(decode("\u{1B}[3") == [.deleteForward])
    }

    // MARK: - Stream end

    @Test func closedStreamDecodesAsEOF() {
        #expect(decode("a", endsWithEOF: true) == [.character("a"), .eof])
    }

    // MARK: - Helpers

    /// Decodes the keys `bytes` spells. The source reports `interrupted` once the
    /// array is drained — the same "nothing to read yet" the `VTIME` poll gives —
    /// so decoding stops there rather than at a synthetic EOF. Pass
    /// `endsWithEOF` to close the stream instead, for the paths that have to cope
    /// with the terminal going away.
    ///
    /// - Parameters:
    ///   - bytes: the raw bytes to decode.
    ///   - endsWithEOF: whether the drained source reports EOF rather than a poll
    ///     timeout.
    ///   - limit: a backstop on the number of keys collected, so a decoding bug
    ///     fails the test instead of hanging it.
    /// - Returns: the decoded keys, in order.
    private func decode(
        _ bytes: [UInt8], endsWithEOF: Bool = false, limit: Int = 256
    ) -> [KeyDecoder.Key] {
        var index = 0
        let decoder = KeyDecoder {
            guard index < bytes.count else { return endsWithEOF ? .eof : .interrupted }
            defer { index += 1 }
            return .byte(bytes[index])
        }
        var keys: [KeyDecoder.Key] = []
        while keys.count < limit, let key = decoder.next() {
            keys.append(key)
            if key == .eof { break }
        }
        return keys
    }

    /// ``decode(_:endsWithEOF:limit:)`` over the UTF-8 of `text`, so a test can
    /// spell an escape sequence as a string.
    private func decode(
        _ text: String, endsWithEOF: Bool = false, limit: Int = 256
    ) -> [KeyDecoder.Key] {
        decode(Array(text.utf8), endsWithEOF: endsWithEOF, limit: limit)
    }
}
