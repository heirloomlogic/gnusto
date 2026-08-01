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
        // 0x02, 0x06 and 0x1F carry no binding; the readline keys that do
        // (Ctrl-A/E/U/W) are covered by `readlineControlKeys`.
        #expect(decode("\u{02}a\u{06}b\u{1F}") == [.character("a"), .character("b")])
    }

    /// The readline line-editing bindings every shell has, so a player who
    /// types them in the game gets what they type everywhere else.
    @Test func readlineControlKeys() {
        #expect(decode("\u{01}") == [.home])  // Ctrl-A
        #expect(decode("\u{05}") == [.end])  // Ctrl-E
        #expect(decode("\u{15}") == [.deleteToStart])  // Ctrl-U
        #expect(decode("\u{17}") == [.deleteWordBack])  // Ctrl-W
    }

    /// Option-as-Meta terminals send a bare ESC and then the key.
    @Test func metaPrefixedWordKeys() {
        #expect(decode("\u{1B}b") == [.wordLeft])
        #expect(decode("\u{1B}f") == [.wordRight])
        #expect(decode("\u{1B}d") == [.deleteWordForward])
        #expect(decode("\u{1B}\u{7F}") == [.deleteWordBack])
    }

    /// A modified arrow — xterm's `3` for Alt/Option, `5` for Ctrl — is a word
    /// jump rather than a character step.
    @Test func modifiedArrowsJumpByWord() {
        #expect(decode("\u{1B}[1;3D") == [.wordLeft])
        #expect(decode("\u{1B}[1;3C") == [.wordRight])
        #expect(decode("\u{1B}[1;5D") == [.wordLeft])
        #expect(decode("\u{1B}[1;5C") == [.wordRight])
        #expect(decode("\u{1B}[D") == [.left])  // unmodified still steps
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

    /// An over-long numeric parameter is abandoned, and so is the rest of its
    /// sequence — otherwise the leftover digits and the `~` fall through to the
    /// printable path and get typed into the player's input line.
    @Test func overlongNumericParameterIsDiscardedWithoutLeakingItsTail() {
        #expect(decode("\u{1B}[1234567890~a") == [.character("a")])
    }

    /// A numeric parameter that runs out of bytes resolves on what it has, rather
    /// than waiting for the `~`. Pinned rather than fixed: a real terminal sends a
    /// sequence as one burst, so this only bites if one is split across the 0.1s
    /// `VTIME` poll boundary, and the parameter is unambiguous by then anyway.
    @Test func unterminatedNumericParameterResolvesOnWhatItHas() {
        #expect(decode("\u{1B}[3") == [.deleteForward])
    }

    // MARK: - Bracketed paste

    @Test func bracketedPasteBecomesOneKey() {
        #expect(decode("\u{1B}[200~hello world\u{1B}[201~") == [.paste("hello world")])
    }

    @Test func pasteKeepsEmbeddedNewlinesForTheFoldToNormalize() {
        #expect(
            decode("\u{1B}[200~one\ntwo\r\nthree\u{1B}[201~") == [.paste("one\ntwo\r\nthree")])
    }

    /// The whole point of bracketed paste: a stray Ctrl-C in the payload can't
    /// reach the quit-confirm, and pasted arrow keys can't move the caret. They
    /// arrive as text and are sanitized by the fold, not decoded as keys.
    @Test func controlAndEscapeBytesRideInsideThePasteInsteadOfDecoding() {
        #expect(
            decode("\u{1B}[200~a\u{03}b\u{1B}[Ac\u{1B}[201~") == [.paste("a\u{03}b\u{1B}[Ac")])
    }

    @Test func emptyPasteDecodesAsAnEmptyPaste() {
        #expect(decode("\u{1B}[200~\u{1B}[201~") == [.paste("")])
    }

    @Test func theKeyAfterAPasteDecodesNormally() {
        #expect(decode("\u{1B}[200~x\u{1B}[201~\n") == [.paste("x"), .enter])
    }

    @Test func strayPasteEndWithNoPasteOpenIsIgnored() {
        #expect(decode("\u{1B}[201~a") == [.character("a")])
    }

    @Test func unterminatedPasteEndsAtEOF() {
        #expect(decode("\u{1B}[200~abc", endsWithEOF: true) == [.paste("abc"), .eof])
    }

    /// Otherwise a terminal that opens a paste and never closes it wedges the
    /// editor: no keys, no repaints, no resize servicing.
    @Test func unterminatedPasteGivesUpAfterTooManyIdlePolls() {
        #expect(decode("\u{1B}[200~abc", idlePollLimit: 3) == [.paste("abc")])
    }

    /// Past the cap the body stops growing but scanning continues, so the
    /// terminator is still found and the next key decodes normally.
    @Test func overlongPasteIsCappedAndTheStreamStaysInSync() {
        #expect(decode("\u{1B}[200~abcdefghij\u{1B}[201~\n", byteCap: 4) == [.paste("abcd"), .enter])
    }

    /// The cap counts the body only — the terminator is withheld rather than
    /// stored — so a paste exactly at the cap keeps all of it.
    @Test func pasteExactlyAtTheCapKeepsAllOfIt() {
        #expect(decode("\u{1B}[200~abcdefghij\u{1B}[201~", byteCap: 10) == [.paste("abcdefghij")])
    }

    /// Bytes withheld as a possible terminator are released into the body once
    /// they turn out not to be one.
    @Test func bytesThatOnlyLookLikeTheTerminatorSurviveInTheBody() {
        #expect(decode("\u{1B}[200~a\u{1B}[200b\u{1B}[201~") == [.paste("a\u{1B}[200b")])
    }

    /// ...including when the stream ends while they're still withheld.
    @Test func unterminatedPasteEndingMidMarkerKeepsThoseBytes() {
        #expect(
            decode("\u{1B}[200~abc\u{1B}[", endsWithEOF: true) == [.paste("abc\u{1B}["), .eof])
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
    ///   - byteCap: overrides the paste body cap.
    ///   - idlePollLimit: overrides how many poll timeouts end an unterminated
    ///     paste.
    /// - Returns: the decoded keys, in order.
    private func decode(
        _ bytes: [UInt8], endsWithEOF: Bool = false, limit: Int = 256,
        byteCap: Int? = nil, idlePollLimit: Int? = nil
    ) -> [KeyDecoder.Key] {
        var index = 0
        var decoder = KeyDecoder {
            guard index < bytes.count else { return endsWithEOF ? .eof : .interrupted }
            defer { index += 1 }
            return .byte(bytes[index])
        }
        if let byteCap { decoder.pasteByteCap = byteCap }
        if let idlePollLimit { decoder.pasteIdlePollLimit = idlePollLimit }
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
        _ text: String, endsWithEOF: Bool = false, limit: Int = 256,
        byteCap: Int? = nil, idlePollLimit: Int? = nil
    ) -> [KeyDecoder.Key] {
        decode(
            Array(text.utf8), endsWithEOF: endsWithEOF, limit: limit,
            byteCap: byteCap, idlePollLimit: idlePollLimit)
    }
}
