import Foundation
import GnustoTestSupport
import Testing

@testable import Gnusto

/// ``alwaysDescribed`` — the trait a room declares when its description is the
/// only readout of its state (issue #149). The fixture is `DialRoomGame` in
/// `Support/AlwaysDescribedGames.swift`.
///
/// Three paths re-describe as an *entry* rather than as a LOOK, and so go
/// brief once the room has been visited: UNDO, walking back in through an
/// exit, and RESTORE. There is one test each, in that order.
///
/// The bootstrap warning for the trait on a room with nothing to un-hide is in
/// `BootstrapTests`; `describeSurroundings(withRoomName:)`, the other half of
/// #149, is in `ArriveTests` and `PluginSeamTests`.
struct AlwaysDescribedTests {
    /// The headline. A rewind re-describes with `mode: .entry`, which is brief
    /// once the room has been visited — so without the trait the player types
    /// UNDO after a move and gets the heading with nothing under it. With it,
    /// they get the board back on the move that rewound, not one turn later on
    /// an explicit LOOK.
    @Test func anUndoReprintsTheStateItRewound() async throws {
        let transcript = try await play(DialRoomGame(), ["north", "notch", "undo", "score"])

        // The move that advanced the dial showed the new setting.
        #expect(turnOutput(of: "notch", in: transcript).contains("notch 1"))

        let rewind = turnOutput(of: "undo", in: transcript)
        #expect(rewind.contains("Dial Room"))
        #expect(rewind.contains("standing at notch 0"))
        #expect(!rewind.contains("notch 1"))

        // A location `before` rule that replies is not `unhandled`, so the turn
        // it answered still finished and still cost a move — and UNDO gave that
        // move back too. One walk in, one turn.
        #expect(turnOutput(of: "score", in: transcript).contains("in 1 turn"))
    }

    /// Both sides of the trait in one transcript. Walking back into the room
    /// that declares it prints the description again; walking back into the one
    /// that doesn't prints the heading alone.
    @Test func onlyTheRoomThatDeclaresItIsDescribedTwice() async throws {
        let transcript = try await play(DialRoomGame(), ["north", "south", "go north"])

        // The control, revisited: name, and nothing under it.
        let control = turnOutput(of: "south", in: transcript)
        #expect(control.contains("Landing"))
        #expect(!control.contains("longer than it is wide"))

        // The room with the trait, revisited: described in full again.
        let revisit = turnOutput(of: "go north", in: transcript)
        #expect(revisit.contains("Dial Room"))
        #expect(revisit.contains("brass dial standing at notch 0"))
    }

    /// The third path. RESTORE re-describes as an entry too, so without the
    /// trait a player who reloads is shown a heading and left to guess at the
    /// board they restored. (That globals survive the file round trip at all is
    /// `CustomStateTests`' and `ConversationTests`' subject, not this one's.)
    @Test func aRestoreReprintsTheStateItRestored() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gnusto-dial-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let transcript = try await play(
            DialRoomGame(),
            ["north", "notch", "notch", "save", "dial", "notch", "restore", "dial"],
            saveDirectory: dir)

        // The restore's own turn prints the board it restored — the setting the
        // save was taken at, not the one the third turn of the dial reached.
        expectInOrder(
            transcript,
            [
                "standing at notch 2",
                "Saved.",
                "standing at notch 3",
                "Restored.",
                "Dial Room",
                "standing at notch 2",
            ])
    }

    // MARK: - The item-side twin

    /// **``alwaysListed`` keeps a listing paragraph printing past the first
    /// touch.** Both braziers report their own state; only the one with the
    /// trait goes on doing it once it has been handled. Without it, the room
    /// falls back to the stock "There is a … here." — which is the sentence
    /// Dungeon's balloon printed for an inflated burning bag and a cold
    /// deflated one alike, from the first time anybody climbed in. (#329)
    @Test func onlyTheItemThatDeclaresItKeepsItsListingLine() async throws {
        let transcript = try await play(
            BrazierRoomGame(),
            ["look", "turn on iron brazier", "turn on stone brazier", "look"])

        // Untouched, both speak for themselves — which is the ordinary
        // behaviour and the control for the second half.
        let first = turnOutput(of: "look", in: transcript)
        #expect(first.contains("The iron brazier stands cold."))
        #expect(first.contains("The stone brazier stands cold."))

        // Touched, only the one with the trait does.
        let after = try #require(transcript.components(separatedBy: "> look").last)
        #expect(after.contains("The iron brazier is burning."))
        #expect(!after.contains("The stone brazier is burning."))
        #expect(!after.contains("The stone brazier stands cold."))
    }
}
