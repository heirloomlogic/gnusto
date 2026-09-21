import Foundation
import GnustoTestSupport
import Testing

@testable import Gnusto

/// VERBOSE, BRIEF and SUPERBRIEF — how much of a room prints on the way in
/// (issue #499), where `verbose` in a Zork port used to answer *I don't know
/// the word "verbose"*.
///
/// The fixture is `BlinkGame` in `Support/ArriveGames.swift`, which already has
/// the three rooms these claims need: a hall and a vault with ordinary long
/// descriptions and a walk between them, a ledge that declares
/// ``alwaysDescribed``, and a lamp lying in the vault so an item paragraph can
/// be told apart from a room's description.
///
/// The three verbs set one session preference and nothing else. What they
/// decide is whether an *entry* prints the room's long description; LOOK and
/// `alwaysDescribed` both outrank them, and the item paragraphs print in every
/// mode. The preference lives on the `GameWorld` actor rather than in
/// `WorldState`, so SAVE, RESTORE, UNDO and RESTART all leave it alone and a
/// newly launched session starts at BRIEF.
///
/// That the words parse at all is `CoreVerbTests`, which runs every core row;
/// that the verbs report `turn=free` in the status footer is
/// `StatusFooterTests`.
struct DescriptionModeTests {
    // MARK: - The three modes

    /// BRIEF is the default and needs no verb to reach: the first visit is
    /// long, the walk back in is the heading and the things lying there.
    @Test func briefIsTheDefaultAndShortensARevisit() async throws {
        let transcript = try await play(BlinkGame(), ["north", "south", "north"])

        let revisit = turnOutput(ofLast: "north", in: transcript)
        #expect(revisit.contains("Vault"))
        #expect(!revisit.contains("Cold, and quite empty"))
        // The item paragraph is not the long description and still prints.
        #expect(revisit.contains("There is a brass lamp here."))
    }

    /// VERBOSE puts the long description back on every entry.
    @Test func verboseDescribesEveryEntryInFull() async throws {
        let transcript = try await play(BlinkGame(), ["verbose", "north", "south"])

        #expect(turnOutput(of: "verbose", in: transcript).contains("Maximum verbosity."))

        let revisit = turnOutput(of: "south", in: transcript)
        #expect(revisit.contains("Hall"))
        #expect(revisit.contains("longer than it is wide"))
    }

    /// SUPERBRIEF withholds it on every entry, the first one included — which
    /// is the only claim BRIEF and SUPERBRIEF differ on, since both are short
    /// on a revisit. What is lying in the room is still listed.
    @Test func superbriefWithholdsItOnAFirstVisitToo() async throws {
        let transcript = try await play(BlinkGame(), ["superbrief", "north"])

        #expect(
            turnOutput(of: "superbrief", in: transcript).contains("Superbrief descriptions."))

        let arrival = turnOutput(of: "north", in: transcript)
        #expect(arrival.contains("Vault"))
        #expect(!arrival.contains("Cold, and quite empty"))
        #expect(arrival.contains("There is a brass lamp here."))
    }

    /// BRIEF said out loud, which is how a player leaves one of the other two.
    @Test func briefCanBeAskedForByName() async throws {
        let transcript = try await play(
            BlinkGame(), ["verbose", "north", "brief", "south", "north"])

        #expect(turnOutput(of: "brief", in: transcript).contains("Brief descriptions."))

        // Back under BRIEF, a revisit is short again — the second walk north,
        // the first having been the first visit and long under VERBOSE.
        let revisit = turnOutput(ofLast: "north", in: transcript)
        #expect(revisit.contains("Vault"))
        #expect(!revisit.contains("Cold, and quite empty"))
    }

    /// The original's spellings. `gsyntax.zil` declares `SUPER` as a synonym
    /// of `SUPERBRIEF`, and the tokenizer splits the two-word form on its
    /// space, so all three reach the same verb.
    @Test func superbriefAnswersToTheOriginalsSpellings() async throws {
        let transcript = try await play(BlinkGame(), ["super", "super brief"])

        #expect(turnOutput(of: "super", in: transcript).contains("Superbrief descriptions."))
        #expect(
            turnOutput(of: "super brief", in: transcript).contains("Superbrief descriptions."))
    }

    // MARK: - What outranks the preference

    /// LOOK is the player asking to be told again, so it is long in every
    /// mode — including the one that prints nothing on the way in.
    @Test func lookIsFullEvenInSuperbrief() async throws {
        let transcript = try await play(BlinkGame(), ["superbrief", "north", "look"])

        let look = turnOutput(of: "look", in: transcript)
        #expect(look.contains("Vault"))
        #expect(look.contains("Cold, and quite empty"))
    }

    /// A room whose description is the state it reports keeps it in every
    /// mode: the preference is about prose the player has already read, and
    /// `alwaysDescribed` says this is not that.
    @Test func alwaysDescribedRoomsStayFullInSuperbrief() async throws {
        let transcript = try await play(BlinkGame(), ["superbrief", "east", "west", "east"])

        // The control in the same transcript: the ordinary room goes short.
        #expect(!turnOutput(of: "west", in: transcript).contains("longer than it is wide"))

        // First entry and revisit alike.
        #expect(turnOutput(of: "east", in: transcript).contains("long way down"))
        #expect(turnOutput(ofLast: "east", in: transcript).contains("long way down"))
    }

    // MARK: - What the verbs cost

    /// Nothing. They are meta intents: the move counter stands still.
    @Test func theModeVerbsCostNoTurn() async throws {
        let transcript = try await play(
            BlinkGame(), ["verbose", "brief", "superbrief", "super", "score"])

        #expect(turnOutput(of: "score", in: transcript).contains("in 0 turns"))
    }

    /// And no rule runs and no timer ticks, which is the other half of what
    /// being a meta intent buys. `OrderProbeGame` prints a marker from each
    /// each-turn rule; a mode verb prints none of them.
    @Test func theModeVerbsRunNoRulesAndTickNoTimers() async throws {
        let transcript = try await play(OrderProbeGame(), ["verbose", "superbrief", "brief"])

        #expect(!transcript.contains("[locEachBefore]"))
        #expect(!transcript.contains("[locEachAfter]"))
        #expect(!transcript.contains("[worldBefore]"))
    }

    // MARK: - The preference is the session's, not the world's

    /// UNDO rewinds the world, not the session. The rewind re-describes as an
    /// entry, and under VERBOSE that entry is long even though the room has
    /// been stood in before — which it would not be had the mode come back
    /// with the state.
    @Test func undoLeavesTheModeAlone() async throws {
        let transcript = try await play(BlinkGame(), ["north", "verbose", "south", "undo"])

        let rewind = turnOutput(of: "undo", in: transcript)
        #expect(rewind.contains("Vault"))
        #expect(rewind.contains("Cold, and quite empty"))
    }

    /// RESTORE likewise. The save is taken under VERBOSE and the restore's own
    /// re-describe is long, in a room the player has already been in.
    @Test func saveAndRestoreLeaveTheModeAlone() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gnusto-verbosity-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let transcript = try await play(
            BlinkGame(),
            ["north", "south", "verbose", "save", "blink", "north", "restore", "blink"],
            saveDirectory: dir)

        // The restore lands back in the hall, which the opening already
        // described — so a short entry here would mean the mode had been
        // replaced along with the world.
        expectInOrder(
            transcript,
            [
                "Maximum verbosity.",
                "Saved.",
                "Restored.",
                "Hall",
                "longer than it is wide",
            ])
    }

    /// RESTART rewinds to the opening and keeps the preference, so the room
    /// the game opens in is printed the way the player last asked for — short,
    /// here, even though a restarted game has visited nothing.
    @Test func restartKeepsTheMode() async throws {
        let transcript = try await play(BlinkGame(), ["superbrief", "restart"])

        let reopened = turnOutput(of: "restart", in: transcript)
        #expect(reopened.contains("Hall"))
        #expect(!reopened.contains("longer than it is wide"))
        // The opening itself, before the mode was set, was long — so the
        // second opening's silence is the mode and not the fixture.
        #expect(transcript.contains("longer than it is wide"))
    }

    /// A newly launched session starts at BRIEF, whatever the last one ended
    /// at. Two runs of the same game type in one process, which is also the
    /// arrangement that would leak a preference through the world cache.
    @Test func aNewSessionStartsBrief() async throws {
        let first = try await play(BlinkGame(), ["superbrief", "look"])
        #expect(first.contains("Superbrief descriptions."))

        let second = try await play(BlinkGame(), ["north"])
        // The opening is long again.
        #expect(second.contains("longer than it is wide"))
        #expect(turnOutput(of: "north", in: second).contains("Cold, and quite empty"))
    }
}
