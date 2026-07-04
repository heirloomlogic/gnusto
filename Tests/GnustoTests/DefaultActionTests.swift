import GnustoTestSupport
import Testing

@testable import Gnusto

struct DefaultActionTests {
    @Test func takeAndDrop() async throws {
        let transcript = try await play(
            MiniGame(),
            ["take book", "take book", "drop book", "drop book", "take table"])
        expectInOrder(
            transcript,
            [
                "Taken.",
                "You already have that.",
                "Dropped.",
                "You aren't carrying that.",
                "You can't take that.",  // scenery
            ])
    }

    @Test func takeFromSurface() async throws {
        let transcript = try await play(MiniGame(), ["take coin", "i"])
        expectInOrder(transcript, ["Taken.", "a gold coin"])
    }

    @Test func wearAndDoff() async throws {
        let transcript = try await play(
            MiniGame(),
            [
                "wear hat", "wear hat", "take off hat", "take hat off",
                "wear book", "take book", "wear book",
            ])
        expectInOrder(
            transcript,
            [
                "You put on the felt hat.",
                "You're already wearing that.",
                "You take off the felt hat.",
                "You're not wearing that.",
                "You aren't holding that.",  // wear before taking
                "Taken.",
                "You can't wear that.",  // held but not wearable
            ])
    }

    @Test func dropWhileWornDoffsFirst() async throws {
        let transcript = try await play(MiniGame(), ["wear hat", "drop hat"])
        expectInOrder(
            transcript,
            ["(first taking off the felt hat)", "Dropped."])
    }

    @Test func putOn() async throws {
        let transcript = try await play(
            MiniGame(),
            ["take book", "put book on table", "put hat on book", "look"])
        expectInOrder(
            transcript,
            [
                "You put the dusty book on the oak table.",
                "You can't put things on that.",  // the book isn't a surface
                "On the oak table is a dusty book.",
            ])
    }

    @Test func goAndBlockedExits() async throws {
        let transcript = try await play(MiniGame(), ["north", "east", "up", "west"])
        expectInOrder(
            transcript,
            [
                "The door is locked.",
                "Study",
                "A quiet study.",
                "You can't go that way.",
                "Den",
            ])
    }

    @Test func lookIsVerboseButRevisitEntryIsBrief() async throws {
        let transcript = try await play(MiniGame(), ["east", "west", "look"])
        // Returning to the den (already visited): brief — name without the
        // long description.
        let entry = turnOutput(of: "west", in: transcript)
        #expect(entry.contains("Den"))
        #expect(!entry.contains("A cozy den."))
        // Explicit look: always verbose.
        let look = turnOutput(of: "look", in: transcript)
        #expect(look.contains("A cozy den."))
    }

    @Test func examineAndRead() async throws {
        let transcript = try await play(
            MiniGame(), ["examine book", "read book", "examine hat"])
        expectInOrder(
            transcript,
            [
                "It says: read more tests.",
                "It says: read more tests.",
                "You see nothing special about the felt hat.",
            ])
    }

    @Test func inventory() async throws {
        let transcript = try await play(
            MiniGame(), ["i", "wear hat", "take book", "i"])
        expectInOrder(
            transcript,
            [
                "You are carrying:",
                "a felt hat",
                "You are carrying:",
                "a dusty book",
                "a felt hat (being worn)",
            ])
    }

    @Test func quitEndsTheGameWithAScore() async throws {
        let transcript = try await play(MiniGame(), ["quit", "look"])
        #expect(transcript.contains("Your score is 0"))
        // The REPL stops after quit: the queued "look" is never consumed.
        #expect(!transcript.contains("> look"))
    }
}
