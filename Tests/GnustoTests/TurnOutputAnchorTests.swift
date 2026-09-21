import Gnusto
import GnustoTestSupport
import Testing

/// Issue #491 — `turnOutput(of:in:)`/`turnOutput(ofLast:in:)` matched a
/// `> cmd` quoted inside game prose because the search had no anchor to the
/// start of a line. `QuotingLab`'s room description quotes `look` in the
/// two-space form-text style CLAUDE.md documents, ahead of any real `look`
/// prompt in the transcript — and its sign's own reply is literally the
/// words "Nothing happens.", so the regression check is which *slice* comes
/// back, not merely whether that phrase appears in it.
struct TurnOutputAnchorTests {
    @Test func turnOutputSkipsAQuotedCommandInsideProse() async throws {
        let transcript = try await play(QuotingLab(), ["wait", "look"])

        let slice = turnOutput(of: "look", in: transcript)

        // The buggy match landed inside the sign's two-space quote and
        // returned only its reply line, dropping the room heading and the
        // rest of the real LOOK turn ahead of it.
        #expect(!slice.hasPrefix("  Nothing happens."))
        #expect(slice.hasPrefix("Lab"))
        #expect(slice.contains("The sign reads"))
    }

    @Test func turnOutputOfLastSkipsAQuotedCommandInsideProse() async throws {
        let transcript = try await play(QuotingLab(), ["wait", "look"])

        let slice = turnOutput(ofLast: "look", in: transcript)

        #expect(!slice.hasPrefix("  Nothing happens."))
        #expect(slice.hasPrefix("Lab"))
        #expect(slice.contains("The sign reads"))
    }

    @Test func turnOutputMatchesAPromptThatOpensTheTranscript() {
        // A transcript ScriptedIOHandler could produce for a game with no
        // banner text ahead of the first prompt — there is nothing before
        // "> wait\n" for the anchor to land on.
        let transcript = "> wait\nTime passes.\n\n> look\nA lab.\n"

        #expect(turnOutput(of: "wait", in: transcript) == "Time passes.\n")
        #expect(turnOutput(ofLast: "look", in: transcript) == "A lab.\n")
    }
}
