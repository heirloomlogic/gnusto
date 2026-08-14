import GnustoTestSupport
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

    // MARK: - Going through a door by name

    @Test func enteringADoorWalksThroughIt() async throws {
        let transcript = try await play(
            WindowGame(), ["open window", "enter window", "enter window"])
        expectInOrder(
            transcript,
            [
                "> open window", "Opened.",
                "> enter window", "Kitchen",
                "> enter window", "Garden",
            ])
    }

    /// Every spelling `V-THROUGH`'s syntax rows carry, one play each so no
    /// spelling can ride the previous one's move.
    @Test(
        arguments: [
            "enter window", "board window", "get in window", "get into window",
            "go through window", "walk through window", "step through window",
            "climb through window", "walk in window",
        ])
    func everySpellingWalksThroughTheDoor(_ command: String) async throws {
        let transcript = try await play(WindowGame(), ["open window", command])
        #expect(turnOutput(of: command, in: transcript).contains("Kitchen"))
    }

    /// A shut door answers the sentence `go` answers, because it is `travel` that
    /// answers in both cases.
    @Test func aShutDoorRefusesTheWayGoRefuses() async throws {
        let transcript = try await play(
            WindowGame(), ["enter window", "west", "go through window"])
        expectInOrder(
            transcript,
            [
                "> enter window", "The small window is closed.",
                "> west", "The small window is closed.",
                "> go through window", "The small window is closed.",
            ])
        #expect(!transcript.contains("Kitchen"))
    }

    /// A door carrying two directions from one room goes the same way whichever
    /// of them the lookup finds first. `WindowGame`'s window is on `west` and
    /// `in`; the answer is `west`'s because the lookup walks `Direction.allCases`
    /// rather than the exits dictionary, whose order is nobody's decision.
    /// Repeating the play would not test this — Swift's hash seed is per process
    /// — so the assertion is on the compass order itself.
    @Test func aDoorOnTwoDirectionsGoesOneWay() async throws {
        let transcript = try await play(
            WindowGame(), ["open window", "enter window", "go through window"])
        #expect(turnOutput(of: "enter window", in: transcript).contains("Kitchen"))
        #expect(turnOutput(of: "go through window", in: transcript).contains("Garden"))
    }

    /// An item that is both a vehicle and a door is walked through, not boarded
    /// — the door is tested first. The order is only observable here, and here
    /// the door has to win: a door is referenced by an exit rather than placed
    /// in a room, so the vehicle path's "is it here" test refuses it anyway.
    /// Boarding this chair by name was never possible; walking through it is.
    @Test func anEnterableDoorIsWalkedThroughRatherThanBoarded() async throws {
        let transcript = try await play(
            SedanChairGame(), ["open chair", "enter chair"])
        let entered = turnOutput(of: "enter chair", in: transcript)
        #expect(entered.contains("Terrace"))
        #expect(!entered.contains("You can't reach"))
        #expect(!entered.contains("You are now in"))
    }

    @Test func anUnrevealedDoorIsNoWayThrough() async throws {
        let transcript = try await play(
            HiddenDoorGame(),
            ["enter bookcase door", "push switch", "go through bookcase door"])
        expectInOrder(
            transcript,
            [
                "> enter bookcase door", "You can't see any such thing.",
                "> push switch", "A bookcase swings aside",
                "> go through bookcase door", "The bookcase door is closed.",
            ])
        #expect(!transcript.contains("Secret Passage"))
    }

    /// `climb through X` is the doorway; `climb X` is still the stub verb. Two
    /// rows one token apart, so the parser's preference for the longer match is
    /// what keeps them separate.
    @Test func climbingThroughIsNotClimbing() async throws {
        let transcript = try await play(
            WindowGame(), ["open window", "climb window", "climb through window"])
        let climbed = turnOutput(of: "climb window", in: transcript)
        #expect(!climbed.contains("Kitchen"))
        #expect(turnOutput(of: "climb through window", in: transcript).contains("Kitchen"))
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
        _ = try Bootstrap.build(WindowGame())
        _ = try Bootstrap.build(SedanChairGame())
        _ = try Bootstrap.build(TrapDoorGame())
        _ = try Bootstrap.build(LockedDoorGame())
        _ = try Bootstrap.build(GratingGame())
        _ = try Bootstrap.build(HiddenDoorGame())
        _ = try Bootstrap.build(BoardedDoorGame())
    }

    /// ``Item/isDoor`` answers from two places and has to agree with both: the
    /// map, which says it by hanging a way through on the thing, and the `door`
    /// trait, which is what a door leading nowhere falls back on. Saying both is
    /// a union and stays true. A bench is neither, and that is the half a verb
    /// actually branches on. (#247)
    @Test func isDoorReadsBothTheMapAndTheTrait() async throws {
        let transcript = try await play(BoardedDoorGame(), ["knock on bench"])
        #expect(transcript.contains("trait:true map:true both:true bench:false"))
    }
}
