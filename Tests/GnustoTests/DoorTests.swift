import Testing

@testable import Gnusto

struct DoorTests {
    // MARK: - Shared trap door

    @Test func closedDoorBlocksMovement() async throws {
        let transcript = try await play(TrapDoorGame(), ["down"])
        expectInOrder(transcript, ["> down", "The trap door is closed."])
        // Player did not move.
        #expect(!transcript.contains("Cellar"))
    }

    @Test func openDoorPasses() async throws {
        let transcript = try await play(TrapDoorGame(), ["open trap door", "down"])
        expectInOrder(transcript, ["> open trap door", "Opened.", "> down", "Cellar"])
    }

    @Test func doorStateIsSharedAcrossBothSides() async throws {
        // Open the door from above, descend, then ascend back — the same door
        // is open from below because both exits reference one EntityID.
        let transcript = try await play(
            TrapDoorGame(), ["open trap door", "down", "up"])
        expectInOrder(
            transcript,
            ["> open trap door", "Opened.", "> down", "Cellar", "> up", "Living Room"])
    }

    @Test func doorIsExaminableFromBothSides() async throws {
        // The door has no placement, yet it's in scope from both rooms.
        let transcript = try await play(
            TrapDoorGame(), ["examine trap door", "open trap door", "down", "examine trap door"])
        expectInOrder(
            transcript,
            [
                "> examine trap door", "nothing special about the trap door",
                "> down", "Cellar",
                "> examine trap door", "nothing special about the trap door",
            ])
    }

    @Test func doorIsNotListedAsRoomContents() async throws {
        // A door is referenced, not placed, so it must not appear as
        // "There is a trap door here." in the room description.
        let transcript = try await play(TrapDoorGame(), ["look"])
        #expect(!transcript.contains("There is a trap door here."))
    }

    // MARK: - Locked door

    @Test func lockedDoorRefusesOpenUntilUnlocked() async throws {
        let transcript = try await play(
            LockedDoorGame(),
            ["open iron door", "unlock iron door with key", "open iron door", "north"])
        expectInOrder(
            transcript,
            [
                "> open iron door", "The iron door is locked.",
                "> unlock iron door with key", "Unlocked.",
                "> open iron door", "Opened.",
                "> north", "Vault",
            ])
    }

    @Test func lockedDoorReadsAsClosedOnGo() async throws {
        // Player tries to walk through a locked (hence closed) door: the go
        // refusal speaks only of closed, never locked.
        let transcript = try await play(LockedDoorGame(), ["north"])
        expectInOrder(transcript, ["> north", "The iron door is closed."])
        #expect(!turnOutput(of: "north", in: transcript).contains("locked"))
        #expect(!transcript.contains("Vault"))
    }

    // MARK: - Conditional exit

    @Test func conditionalExitBlockedWhenFalse() async throws {
        let transcript = try await play(GratingGame(), ["west"])
        expectInOrder(transcript, ["> west", "The way is barred."])
        #expect(!transcript.contains("Forest"))
    }

    @Test func conditionalExitPassesWhenFlipped() async throws {
        let transcript = try await play(
            GratingGame(), ["west", "push lever", "west"])
        expectInOrder(
            transcript,
            [
                "> west", "The way is barred.",
                "> push lever", "The grating springs open.",
                "> west", "Forest",
            ])
    }

    // MARK: - Hidden door

    @Test func hiddenDoorIsInvisibleAndImpassable() async throws {
        // Before reveal: door not in scope (can't examine) and go treats the
        // exit as absent ("You can't go that way.").
        let transcript = try await play(
            HiddenDoorGame(), ["examine bookcase door", "east"])
        expectInOrder(
            transcript,
            [
                "> examine bookcase door", "You can't see any such thing.",
                "> east", "You can't go that way.",
            ])
        #expect(!transcript.contains("Secret Passage"))
    }

    @Test func hiddenDoorWorksAfterReveal() async throws {
        // After reveal the door enters scope; it's still closed, so go refuses
        // "closed" until opened, then passes.
        let transcript = try await play(
            HiddenDoorGame(),
            [
                "push switch", "examine bookcase door", "east", "open bookcase door",
                "east",
            ])
        expectInOrder(
            transcript,
            [
                "> push switch", "A bookcase swings aside, revealing a door.",
                "> examine bookcase door", "nothing special about the bookcase door",
                "> east", "The bookcase door is closed.",
                "> open bookcase door", "Opened.",
                "> east", "Secret Passage",
            ])
    }

    // MARK: - Bootstrap diagnostics

    @Test func badDoorReportsBothProblems() {
        #expect {
            try Bootstrap.build(BadDoorGame())
        } throws: { error in
            guard let bootstrapError = error as? BootstrapError else { return false }
            let text = bootstrapError.description
            return text.contains("not declared openable")  // plank
                && text.contains("not a stored property")  // phantom door
        }
    }

    @Test func validDoorGamesBoot() throws {
        _ = try Bootstrap.build(TrapDoorGame())
        _ = try Bootstrap.build(LockedDoorGame())
        _ = try Bootstrap.build(GratingGame())
        _ = try Bootstrap.build(HiddenDoorGame())
    }
}
