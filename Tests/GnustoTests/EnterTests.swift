import GnustoTestSupport
import Testing

@testable import Gnusto

/// `enter(_:)`: the move that walks the player in, where `arrive(at:)` puts them
/// there. Three differences, and `StepGame` wires both helpers to one vault so a
/// single transcript can show each of them — it runs the destination's `onEnter`
/// rules, it carries a boarded vehicle, and it describes the room as an entry
/// rather than as a LOOK.
struct EnterTests {
    @Test func enteringRunsTheDestinationsOnEnterRules() async throws {
        let transcript = try await play(StepGame(), ["step", "back", "blink", "quit"])
        #expect(
            turnOutput(of: "step", in: transcript).contains("A bell rings somewhere below."))
        // The same room, put-there rather than walked-into: no bell. This pair is
        // the whole issue — one primitive had only the spelling, not the
        // semantics.
        #expect(!turnOutput(of: "blink", in: transcript).contains("A bell rings"))
    }

    @Test func onEnterRunsBeforeTheRoomIsDescribed() async throws {
        let transcript = try await play(StepGame(), ["step", "quit"])
        expectInOrder(
            turnOutput(of: "step", in: transcript),
            ["A bell rings somewhere below.", "Vault", "Cold, and quite empty."])
    }

    @Test func onEnterFiresOnEveryEntryNotOnlyTheFirst() async throws {
        // Once by rule, once by fuse, and the vault counts both.
        let transcript = try await play(
            StepGame(), ["step", "back", "summon", "wait", "tally", "quit"])
        #expect(turnOutput(of: "tally", in: transcript).contains("Bells: 2."))
    }

    @Test func enteringDescribesAsAnEntryAndArrivingAsALook() async throws {
        let transcript = try await play(
            StepGame(), ["step", "back", "summon", "wait", "blink", "quit"])
        // First entry: the long description.
        #expect(turnOutput(of: "step", in: transcript).contains("Cold, and quite empty."))
        // Entered again, and it is described as an entry — the heading and the
        // item paragraph, without the long description.
        let again = turnOutput(of: "wait", in: transcript)
        #expect(again.contains("Vault"))
        #expect(again.contains("brass lamp"))
        #expect(!again.contains("Cold, and quite empty."))
        // Where `arrive(at:)` is a full LOOK however many times it runs.
        #expect(turnOutput(of: "blink", in: transcript).contains("Cold, and quite empty."))
    }

    @Test func anAlwaysDescribedRoomIsDescribedInFullOnEveryEntry() async throws {
        let transcript = try await play(StepGame(), ["shelve", "perch", "quit"])
        #expect(turnOutput(of: "shelve", in: transcript).contains("A shelf of rock"))
        // The second entry prints it again, because the description is the state.
        // Every `enter(_:)` conversion in Dungeon's endgame rests on this.
        #expect(turnOutput(of: "perch", in: transcript).contains("A shelf of rock"))
    }

    @Test func anOnEnterRuleThatKillsPropagates() async throws {
        let transcript = try await play(StepGame(), ["plunge", "quit"])
        let fatal = turnOutput(of: "plunge", in: transcript)
        expectInOrder(fatal, ["The floor was a courtesy.", "*** You have died ***"])
        // The death cuts the move short: the room that killed is never described.
        #expect(!fatal.contains("Rather deeper than it looked."))
    }

    @Test func anOnEnterRuleThatRefusesStopsTheDescriptionNotTheMove() async throws {
        let transcript = try await play(StepGame(), ["balk", "look", "quit"])
        let balked = turnOutput(of: "balk", in: transcript)
        #expect(balked.contains("The draught pushes you back."))
        #expect(!balked.contains("A stone lip"))
        // The move commits before the rules run — the order a real `go` uses —
        // so a refusing `onEnter` leaves the player standing where it refused.
        #expect(turnOutput(of: "look", in: transcript).contains("Sill"))
    }

    @Test func enteringADarkRoomIsAsDarkAsWalkingIn() async throws {
        let transcript = try await play(StepGame(), ["delve", "quit"])
        let delve = turnOutput(of: "delve", in: transcript)
        #expect(delve.contains("It is pitch black."))
        #expect(!delve.contains("Dry sand"))
    }

    @Test func enterIsLegalWhereReplyIsNot() async throws {
        // From a fuse: no turn to end, and nothing that throws. This is why the
        // helper does not end the turn itself.
        let transcript = try await play(StepGame(), ["summon", "wait", "quit"])
        expectInOrder(
            turnOutput(of: "wait", in: transcript),
            [
                "The floor tilts, and you are somewhere else.",
                "A bell rings somewhere below.",
                "Vault",
            ])
    }

    @Test func aBoardedVehicleRidesAlong() async throws {
        let transcript = try await play(
            FerryGame(), ["board raft", "ferry", "look in raft", "get out", "look", "quit"])
        // The ridden arrival, exactly as a walked one reads: the suffixed title,
        // and no separate line listing the raft under it.
        let crossing = turnOutput(of: "ferry", in: transcript)
        #expect(crossing.contains("Island, in the red raft"))
        #expect(!crossing.contains("There is a red raft here."))
        // The cargo rode along in the hull, and the raft is ashore once you are.
        #expect(turnOutput(of: "look in raft", in: transcript).contains("smooth pebble"))
        #expect(turnOutput(of: "look", in: transcript).contains("There is a red raft here."))
    }

    @Test func arrivingLeavesTheVehicleBehind() async throws {
        let transcript = try await play(
            FerryGame(), ["board raft", "drift", "get out", "look", "quit"])
        // `arrive(at:)` moves the player and nothing else, so the raft is still
        // on the slip and the title has nothing to suffix.
        let crossing = turnOutput(of: "drift", in: transcript)
        #expect(crossing.contains("Island"))
        #expect(!crossing.contains("Island, in the"))
        #expect(!turnOutput(of: "look", in: transcript).contains("There is a red raft here."))
    }
}
