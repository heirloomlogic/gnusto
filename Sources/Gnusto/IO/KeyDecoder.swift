import Foundation

/// Turns a stream of raw terminal bytes into keypresses: printable characters,
/// editing commands, and the CSI escape sequences behind the arrow, Home/End,
/// Delete and Page keys.
///
/// Decoding only — no `termios`, no file descriptors, no process state. The byte
/// source is injected, so the whole escape table can be unit-tested by feeding a
/// fixed byte array instead of standing up a live terminal.
///
/// ``TerminalIOHandler`` builds one per keystroke around a source that reads
/// stdin. That's deliberately cheap rather than stored: `IOHandler` is
/// `Sendable`, and a stored decoder would force `@Sendable` on the closure —
/// which then couldn't capture the mutable cursor a test's byte array needs.
struct KeyDecoder {
    /// A decoded keypress: an editing command, one or more printable characters,
    /// or a whole bracketed paste.
    enum Key: Equatable {
        case character(String)
        case enter, backspace, deleteForward, tab
        case left, right, home, end
        case historyPrev, historyNext
        case pageUp, pageDown
        case eof, interrupt
    }

    /// One raw byte, or `interrupted` for a read that timed out (the `VTIME`
    /// poll) or was broken by a signal — the caller loops to service a resize.
    /// A genuine terminal close arrives as `SIGHUP`, handled separately, so a
    /// zero-length read is treated as a timeout, not EOF.
    enum RawByte: Equatable {
        case byte(UInt8)
        case eof
        case interrupted
    }

    /// Where bytes come from. Called once per byte, and only when the decoder
    /// needs another one.
    let nextByte: () -> RawByte

    /// The most digits a CSI numeric parameter may carry. A real parameter is a
    /// digit or two, so a stream that never sends the `~` terminator can't grow
    /// the accumulator without bound.
    static let parameterDigitCap = 8

    /// Reads and decodes the next keypress. Returns `nil` when the read was
    /// interrupted, so the caller can service a pending resize and try again.
    /// Bytes that decode to nothing — an unrecognized escape sequence, a stray
    /// control byte, invalid UTF-8 — are skipped, and decoding continues in the
    /// same call.
    func next() -> Key? {
        while true {
            switch nextByte() {
            case .interrupted:
                return nil
            case .eof:
                return .eof
            case .byte(let b):
                switch b {
                case 0x03: return .interrupt
                case 0x04: return .eof
                case 0x09: return .tab
                case 0x0A, 0x0D: return .enter
                case 0x7F, 0x08: return .backspace
                case 0x1B:
                    if let key = escapeSequence() { return key }
                    continue  // lone or unrecognized ESC; move on to the next key
                case 0x00..<0x20:
                    continue  // ignore other control bytes
                default:
                    if let key = utf8(leadByte: b) { return key }
                    continue  // invalid sequence; skip it
                }
            }
        }
    }

    /// Parses a CSI escape sequence (arrows, Home/End, Delete, Page keys).
    /// Returns `nil` for a bare or unrecognized ESC, which the caller swallows.
    private func escapeSequence() -> Key? {
        guard case .byte(let b1) = nextByte(), b1 == 0x5B || b1 == 0x4F else {
            return nil  // lone ESC
        }
        guard case .byte(let b2) = nextByte() else { return nil }
        switch b2 {
        case 0x41: return .historyPrev  // Up
        case 0x42: return .historyNext  // Down
        case 0x43: return .right
        case 0x44: return .left
        case 0x48: return .home  // ESC[H / ESC OH
        case 0x46: return .end  // ESC[F / ESC OF
        case 0x30...0x39:  // numeric parameter, terminated by '~'
            var param = String(UnicodeScalar(b2))
            while case .byte(let n) = nextByte() {
                if n == 0x7E { break }
                guard param.count < Self.parameterDigitCap else { return nil }
                param.append(Character(UnicodeScalar(n)))
            }
            switch param {
            case "1", "7": return .home
            case "4", "8": return .end
            case "3": return .deleteForward
            case "5": return .pageUp
            case "6": return .pageDown
            default: return nil
            }
        default:
            return nil
        }
    }

    /// Gathers the continuation bytes of a UTF-8 sequence begun by `leadByte`
    /// and returns the resulting character(s), or `nil` for an invalid sequence.
    private func utf8(leadByte: UInt8) -> Key? {
        let extra: Int
        switch leadByte {
        case 0xC0...0xDF: extra = 1
        case 0xE0...0xEF: extra = 2
        case 0xF0...0xF7: extra = 3
        default: extra = 0
        }
        var bytes = [leadByte]
        for _ in 0..<extra {
            guard case .byte(let b) = nextByte() else { break }
            bytes.append(b)
        }
        guard let string = String(bytes: bytes, encoding: .utf8), !string.isEmpty else {
            return nil
        }
        return .character(string)
    }
}
