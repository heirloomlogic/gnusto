import Foundation
import GnustoTestSupport
import Testing

@testable import Gnusto

/// Vehicles I: the `enterable` trait, BOARD/DISEMBARK in all their verb
/// forms, the refusal ladder, and the boarded flag riding UNDO and saves.
struct VehicleTests {
    @Test func boardingAndDisembarkingSpeakTheClassicLines() async throws {
        let transcript = try await play(
            HarborGame(),
            [
                "enter boat",
                "enter boat",
                "enter crate",
                "get out",
                "exit",
                "quit",
            ])
        expectInOrder(
            transcript,
            [
                "You are now in the red boat.",
                "You're already in the red boat.",
                "You'll have to get out of the red boat first.",
                "You get out of the red boat.",
                "You aren't in anything.",
            ])
    }

    @Test func everyVerbFormParses() async throws {
        let transcript = try await play(
            HarborGame(),
            [
                "board boat", "get out of boat",
                "get in boat", "exit boat",
                "get into boat", "disembark",
                "quit",
            ])
        let boardings = transcript.components(separatedBy: "You are now in the red boat.")
        let exits = transcript.components(separatedBy: "You get out of the red boat.")
        #expect(boardings.count == 4)
        #expect(exits.count == 4)
    }

    @Test func exitNamesTheThingYouAreActuallyIn() async throws {
        let transcript = try await play(
            HarborGame(),
            ["enter boat", "get out of crate", "quit"])
        expectInOrder(transcript, ["You aren't in the pine crate."])
    }

    @Test func onlyEnterablesAdmitYou() async throws {
        let transcript = try await play(
            HarborGame(),
            ["enter pebble", "quit"])
        expectInOrder(transcript, ["You can't get into the smooth pebble."])
    }

    /// `V-THROUGH` boards a vehicle as readily as it walks a doorway, so the
    /// through-spellings reach a boat that is nobody's door.
    @Test func goingThroughAVehicleBoardsIt() async throws {
        let transcript = try await play(
            HarborGame(),
            ["go through boat", "get out of boat", "walk through boat", "quit"])
        let boardings = transcript.components(separatedBy: "You are now in the red boat.")
        #expect(boardings.count == 3)
    }

    @Test func aCarriedEnterableRefuses() async throws {
        let carriedRefusal = "You can't get into something you're carrying."
        let transcript = try await play(
            HarborGame(),
            ["take bucket", "enter bucket", "take bin", "enter stool", "exit", "quit"])
        expectInOrder(
            transcript,
            ["Taken.", carriedRefusal, "Taken.", carriedRefusal, "You aren't in anything."])
    }

    @Test func worldStateRejectsCarriedBoarding() {
        let vehicle = EntityID("vehicle")
        let room = EntityID("room")
        var state = WorldState(playerLocation: room, placements: [vehicle: .heldBy(.player)])
        state.board(vehicle)
        #expect(state.playerVehicle == nil)
    }

    @Test func reachableNestedEnterablesCanBeBoarded() async throws {
        let onSurface = try await play(HarborGame(), ["enter chair", "exit", "quit"])
        let inOpenContainer = try await play(HarborGame(), ["enter stool", "exit", "quit"])
        expectInOrder(onSurface, ["You are now in the wicker chair.", "You get out of the wicker chair."])
        expectInOrder(inOpenContainer, ["You are now in the pine stool.", "You get out of the pine stool."])
    }

    @Test func closedContainersAndCustomReachRulesStillRefuseBoarding() async throws {
        let transcript = try await play(HarborGame(), ["enter cot", "enter bench", "quit"])
        #expect(turnOutput(of: "enter cot", in: transcript).contains("You can't reach the folding cot."))
        #expect(turnOutput(of: "enter bench", in: transcript).contains("You can't reach the narrow bench."))
        #expect(!transcript.contains("You are now in the folding cot."))
        #expect(!transcript.contains("You are now in the narrow bench."))
    }

    @Test func hostBeforeRulesGateBoarding() async throws {
        let transcript = try await play(
            HarborGame(),
            ["chain", "enter boat", "quit"])
        expectInOrder(transcript, ["The boat is chained to the dock."])
    }

    @Test func bareOutIsStillADirection() async throws {
        let transcript = try await play(
            HarborGame(),
            ["out", "quit"])
        expectInOrder(transcript, ["You can't go that way."])
    }

    @Test func aBoatInAnotherRoomIsOutOfScope() async throws {
        let transcript = try await play(
            HarborGame(),
            ["north", "enter boat", "quit"])
        expectInOrder(transcript, ["You can't see any such thing."])
    }

    @Test func undoUnwindsBoarding() async throws {
        let transcript = try await play(
            HarborGame(),
            ["enter boat", "undo", "exit", "quit"])
        expectInOrder(
            transcript,
            [
                "You are now in the red boat.",
                "Previous turn undone.",
                "You aren't in anything.",
            ])
    }

    @Test func ridingCarriesTheBoatAndItsCargo() async throws {
        let transcript = try await play(
            HarborGame(),
            [
                "take pebble", "enter boat", "drop pebble",
                "north", "look in boat",
                "get out", "look", "take pebble",
                "quit",
            ])
        // The ridden arrival: suffixed title, and no "There is a red boat
        // here." under it — the title already said so.
        let arrival = turnOutput(of: "north", in: transcript)
        expectInOrder(arrival, ["Boathouse, in the red boat"])
        #expect(!arrival.contains("There is a red boat here."))
        // The cargo rode along in the hull and is reachable once ashore.
        expectInOrder(
            transcript,
            [
                "smooth pebble",
                "You get out of the red boat.",
                "There is a red boat here.",
                "Taken.",
            ])
        let look = turnOutput(of: "look", in: transcript)
        #expect(look.contains("Boathouse"))
        #expect(!look.contains("Boathouse, in the"))
    }

    @Test func youCantTakeWhatYouAreSittingIn() async throws {
        let transcript = try await play(
            HarborGame(),
            ["enter boat", "take boat", "quit"])
        expectInOrder(transcript, ["Not while you're in the red boat."])
    }

    @Test func terrainRulesGateRiddenExits() async throws {
        let transcript = try await play(
            HarborGame(),
            ["south", "enter boat", "south", "quit"])
        expectInOrder(
            transcript,
            [
                "You can't go that way.",
                "You are now in the red boat.",
                "The boat refuses to go overland.",
            ])
    }

    @Test func aRuleMovedVehicleCarriesItsPassenger() async throws {
        let transcript = try await play(
            HarborGame(),
            ["row north", "enter boat", "row north", "quit"])
        expectInOrder(
            transcript,
            [
                "You'd want to be in the boat for that.",
                "You are now in the red boat.",
                "The current does the actual work.",
                "Boathouse, in the red boat",
            ])
    }

    @Test func ridingIntoDarknessIsStillPitchBlack() async throws {
        let dark = try await play(
            HarborGame(),
            ["enter boat", "north", "east", "quit"])
        expectInOrder(dark, ["It is pitch black. You can't see a thing."])
        #expect(!dark.contains("Sea Cave,"))
    }

    @Test func aLanternInTheHullLightsTheRiddenCave() async throws {
        // Light escapes the open hull: the ridden arrival in the dark cave
        // is fully described, suffix and all.
        let transcript = try await play(
            HarborGame(),
            [
                "take lantern", "turn on lantern",
                "enter boat", "drop lantern",
                "north", "east",
                "quit",
            ])
        expectInOrder(transcript, ["Sea Cave, in the red boat", "The tide has hollowed"])
    }

    @Test func undoRewindsPlayerAndBoatTogether() async throws {
        let transcript = try await play(
            HarborGame(),
            ["enter boat", "north", "undo", "look", "quit"])
        expectInOrder(
            transcript,
            [
                "Boathouse, in the red boat",
                "Previous turn undone.",
                "Dock, in the red boat",
            ])
    }

    @Test func aVanishedVehicleStrandsItsPassengerGracefully() async throws {
        let transcript = try await play(
            HarborGame(),
            ["enter boat", "scuttle", "exit", "quit"])
        expectInOrder(
            transcript,
            [
                "The boat gives up on buoyancy.",
                "You aren't in anything.",
            ])
    }

    /// The other half of stranding: once the player is standing somewhere the
    /// vehicle isn't, the vehicle's own travels must leave them where they are.
    /// The teleport cleared the boarding on its way out, so `move(to:)` finds
    /// nobody aboard to drag.
    @Test func aStrandedPassengerIsNotDraggedAlongByTheirOldVehicle() async throws {
        let transcript = try await play(
            HarborGame(),
            ["enter boat", "hurl", "tow", "look", "quit"])
        expectInOrder(
            transcript,
            [
                "You are now in the red boat.",
                "A gull carries you off to the boathouse.",
                "The boat is towed away into the cave.",
            ])
        // The cave is dark, so being dragged there reads as "It is pitch black."
        // rather than as its name — that is the assertion with teeth.
        let look = turnOutput(of: "look", in: transcript)
        #expect(look.contains("Boathouse"))
        #expect(!look.contains("It is pitch black"))
    }

    /// And the return leg. Being stranded has to *clear* the boarding, not
    /// defer the question to a read: walking back into the room the boat is
    /// still sitting in must leave the player standing on the dock, not
    /// silently back aboard a boat they never re-entered.
    @Test func walkingBackToAStrandedVehicleDoesNotReboardYou() async throws {
        let transcript = try await play(
            HarborGame(),
            ["enter boat", "hurl", "south", "look", "exit", "quit"])
        expectInOrder(
            transcript,
            [
                "You are now in the red boat.",
                "A gull carries you off to the boathouse.",
            ])
        let look = turnOutput(of: "look", in: transcript)
        #expect(look.contains("Dock"))
        #expect(!look.contains("in the red boat"))
        #expect(turnOutput(of: "exit", in: transcript).contains("You aren't in anything."))
    }

    /// The same return leg from the vehicle's side: the stranded boat is towed
    /// into the room the player is now standing in, and finds them on foot.
    @Test func aStrandedVehicleArrivingFindsYouOnFoot() async throws {
        let transcript = try await play(
            HarborGame(),
            [
                "take lantern", "turn on lantern", "enter boat",
                "hurl", "east", "tow", "look", "row north", "quit",
            ])
        expectInOrder(
            transcript,
            [
                "A gull carries you off to the boathouse.",
                "Sea Cave",
                "The boat is towed away into the cave.",
            ])
        let look = turnOutput(of: "look", in: transcript)
        #expect(look.contains("Sea Cave"))
        #expect(!look.contains("in the red boat"))
        // And the boarding really is gone, not merely unprinted.
        #expect(
            turnOutput(of: "row north", in: transcript)
                .contains("You'd want to be in the boat for that."))
    }

    /// Decoding a save is the one write that reaches the boarded flag without
    /// passing a funnel, so the restore settles it once on the way in. Only a
    /// hand-edited file can present the mismatch — no play can reach it — but a
    /// crafted one must not smuggle a passenger into a boat two rooms away.
    @Test func aRestoredSaveCannotSmuggleInABoardingItNeverEarned() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("gnusto-vehicle-\(UUID().uuidString).sav").path
        defer { try? FileManager.default.removeItem(atPath: path) }
        _ = try await play(HarborGame(), ["enter boat", "save", path, "quit"])

        // Move the player out from under the boat in the file itself, leaving
        // the boarding behind — the shape the old read-time resolver forgave.
        let url = URL(fileURLWithPath: path)
        var file =
            try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        var state = file["state"] as! [String: Any]
        state["playerLocation"] = ["raw": "boathouse"]
        file["state"] = state
        try JSONSerialization.data(withJSONObject: file).write(to: url, options: .atomic)

        let transcript = try await play(HarborGame(), ["restore", path, "look", "exit", "quit"])
        expectInOrder(transcript, ["Restored."])
        let look = turnOutput(of: "look", in: transcript)
        #expect(look.contains("Boathouse"))
        #expect(!look.contains("in the red boat"))
        #expect(turnOutput(of: "exit", in: transcript).contains("You aren't in anything."))
    }

    @Test func boardedStateSurvivesSaveAndRestore() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("gnusto-vehicle-\(UUID().uuidString).sav").path
        defer { try? FileManager.default.removeItem(atPath: path) }
        let transcript = try await play(
            HarborGame(),
            [
                "enter boat", "save", path,
                "get out", "restore", path,
                "exit", "quit",
            ])
        expectInOrder(
            transcript,
            [
                "Saved.",
                "You get out of the red boat.",
                "Restored.",
                "You get out of the red boat.",
            ])
    }

    @Test func lookFromInsideACargoVehicleListsTheHull() async throws {
        let transcript = try await play(
            HarborGame(),
            [
                "take pebble", "enter boat", "drop pebble",
                "look", "get out", "look",
                "quit",
            ])
        // Aboard: the hull's cargo is listed, and the boat keeps its own
        // sentence suppressed because the title already said where you are.
        let aboard = turnOutput(of: "look", in: transcript)
        #expect(aboard.contains("Dock, in the red boat"))
        #expect(aboard.contains("In the red boat is a smooth pebble."))
        #expect(!aboard.contains("There is a red boat here."))
        // Ashore: the same sentence about the same cargo, plus the boat's own.
        let ashore = turnOutput(ofLast: "look", in: transcript)
        #expect(ashore.contains("There is a red boat here."))
        #expect(ashore.contains("In the red boat is a smooth pebble."))
    }

    /// A guard rather than a regression test: this one passes on base too,
    /// and is here so the fix cannot grow a sentence for an empty hull.
    @Test func anEmptyVehiclePrintsNothingExtra() async throws {
        let transcript = try await play(
            HarborGame(),
            ["enter boat", "look", "quit"])
        let aboard = turnOutput(of: "look", in: transcript)
        #expect(aboard.contains("Dock, in the red boat"))
        #expect(!aboard.contains("In the red boat"))
    }

    /// Also a guard that passes on base: boarding an actor must not start
    /// printing its paragraph under the title that already names it.
    @Test func aRiddenActorStillLosesItsOwnParagraph() async throws {
        let transcript = try await play(
            HarborGame(),
            ["look", "enter mule", "look", "quit"])
        #expect(turnOutput(of: "look", in: transcript).contains("A gray mule is here."))
        let aboard = turnOutput(ofLast: "look", in: transcript)
        #expect(aboard.contains("Dock, in the gray mule"))
        #expect(!aboard.contains("A gray mule is here."))
    }

    @Test func aSurfaceVehicleListsWhatRidesWithYou() async throws {
        let transcript = try await play(
            HarborGame(),
            ["look", "enter raft", "look", "quit"])
        // The oar's presence line, identical from the dock and from the deck.
        let ashore = turnOutput(of: "look", in: transcript)
        #expect(ashore.contains("An oar lies athwart the raft."))
        let aboard = turnOutput(ofLast: "look", in: transcript)
        // The title suffix is one line for every vehicle, so a surface one
        // reads "in" as well — unchanged by this fix, and noted here so the
        // expectation is not mistaken for a typo.
        #expect(aboard.contains("Dock, in the log raft"))
        #expect(aboard.contains("An oar lies athwart the raft."))
        #expect(!aboard.contains("There is a log raft here."))
    }

    @Test func aVehicleThatIsHullAndDeckPrintsBothChannels() async throws {
        let transcript = try await play(
            HarborGame(),
            ["enter barge", "look", "quit"])
        let aboard = turnOutput(of: "look", in: transcript)
        #expect(aboard.contains("In the flat barge is a burlap sack."))
        #expect(aboard.contains("On the flat barge is a brass bell."))
        #expect(!aboard.contains("There is a flat barge here."))
    }

    /// An actor in the room is listed once while the player is aboard: the
    /// vehicle now survives the walk that builds `present`, and the actor
    /// paragraphs must not double up because of it.
    @Test func anActorInTheRoomIsStillListedExactlyOnceWhileAboard() async throws {
        let transcript = try await play(
            HarborGame(),
            ["enter barge", "look", "quit"])
        let aboard = turnOutput(of: "look", in: transcript)
        #expect(aboard.components(separatedBy: "A gray mule is here.").count == 2)
    }

    @Test func aTouchedCargoItemFallsBackToTheStockSentence() async throws {
        let transcript = try await play(
            HarborGame(),
            ["take oar", "enter raft", "put oar on raft", "look", "quit"])
        let aboard = turnOutput(of: "look", in: transcript)
        #expect(aboard.contains("On the log raft is a chipped oar."))
        #expect(!aboard.contains("An oar lies athwart the raft."))
    }

    /// A shut opaque hull stays silent, exactly as it does from outside: the
    /// scope walk does not descend into a closed opaque container either, so
    /// listing the cargo would print a noun the parser then refuses.
    @Test func aShutHullListsNothingAndHidesItsCargoFromTheParser() async throws {
        let transcript = try await play(
            HarborGame(),
            ["enter pod", "look", "close pod", "look", "examine wrench", "quit"])
        let open = turnOutput(of: "look", in: transcript)
        #expect(open.contains("In the diving pod is a rusty wrench."))
        let shut = turnOutput(ofLast: "look", in: transcript)
        #expect(shut.contains("Dock, in the diving pod"))
        #expect(!shut.contains("rusty wrench"))
        #expect(
            turnOutput(of: "examine wrench", in: transcript)
                .contains("You can't see any such thing."))
    }
}
