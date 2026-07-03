import Foundation
import Testing

@testable import Gnusto

struct LightSourceTests {
    // MARK: - Where light reaches

    @Test func carriedLitTorchLightsADarkRoom() async throws {
        let transcript = try await play(CaveGame(), ["take torch", "north", "south", "north"])
        let first = turnOutput(of: "north", in: transcript)
        #expect(first.contains("Cave"))
        #expect(first.contains("A low limestone chamber."))
        #expect(!first.contains("It is pitch black."))
        // The lit visit marked the room visited: re-entry is brief (name, no
        // long description).
        let outputs = transcript.components(separatedBy: "> north")
        let reentry = outputs[2]
        #expect(reentry.contains("Cave"))
        #expect(!reentry.contains("A low limestone chamber."))
    }

    @Test func litTorchLeftInTheRoomLightsItAndLeavesWithIt() async throws {
        let transcript = try await play(
            CaveGame(),
            [
                "take torch", "north", "drop torch", "south", "north",
                "take torch", "south", "drop torch", "north",
            ])
        // Re-entering while the torch lies here: still lit.
        let outputs = transcript.components(separatedBy: "> north")
        #expect(outputs[2].contains("Cave"))
        #expect(!outputs[2].contains("It is pitch black."))
        // After carrying the torch out again: dark.
        #expect(outputs[3].contains("It is pitch black."))
    }

    @Test func litTorchOnASurfaceStillLights() async throws {
        let transcript = try await play(
            CaveGame(),
            ["take torch", "north", "put torch on shelf", "look"])
        let look = turnOutput(of: "look", in: transcript)
        #expect(look.contains("A low limestone chamber."))
        #expect(!look.contains("It is pitch black."))
    }

    @Test func closedOpaqueContainerSwallowsTheLight() async throws {
        let transcript = try await play(
            CaveGame(),
            ["take torch", "north", "open chest", "put torch in chest", "look", "close chest", "look"])
        // Open chest: light escapes.
        let openLook = turnOutput(of: "look", in: transcript)
        #expect(openLook.contains("A low limestone chamber."))
        // Closed opaque chest: darkness.
        let closed = transcript.components(separatedBy: "> close chest")[1]
        #expect(closed.contains("It is pitch black."))
    }

    @Test func closedTransparentContainerPassesTheLight() async throws {
        let transcript = try await play(
            CaveGame(),
            ["take torch", "north", "open box", "put torch in box", "close box", "look"])
        let look = turnOutput(of: "look", in: transcript)
        #expect(look.contains("A low limestone chamber."))
        #expect(!look.contains("It is pitch black."))
    }

    @Test func lightStaysLocal() async throws {
        // A lit torch dropped in the cave does not light the adjacent den —
        // and carrying it lights only the player's own room.
        let transcript = try await play(
            CaveGame(),
            ["take torch", "north", "drop torch", "east", "west", "take torch", "east"])
        let den = turnOutput(of: "east", in: transcript)
        #expect(den.contains("It is pitch black."))
        // Carried into the den, the den is lit.
        let outputs = transcript.components(separatedBy: "> east")
        #expect(outputs[2].contains("Den"))
        #expect(outputs[2].contains("A cramped earthen den."))
    }

    // MARK: - The raw setter

    @Test func rawIsLitSetterDoesNotDescribeTheRoom() async throws {
        let transcript = try await play(
            CaveGame(),
            ["take lamp", "north", "rub lamp", "look"])
        // Entering dark, the rub lights the lamp but says only its reply.
        let rub = turnOutput(of: "rub lamp", in: transcript)
        #expect(rub.contains("The lamp flickers to life."))
        #expect(!rub.contains("limestone"))
        // The next look shows the room.
        let look = turnOutput(of: "look", in: transcript)
        #expect(look.contains("A low limestone chamber."))
    }

    @Test func isLitSetterIsANoOpForPlainItems() async throws {
        let transcript = try await play(
            CaveGame(),
            ["take rock", "north", "rub rock", "look"])
        let look = turnOutput(of: "look", in: transcript)
        #expect(look.contains("It is pitch black."))
    }

    // MARK: - Bootstrap

    @Test func startsLitWithoutLightSourceWarns() throws {
        let (definition, state) = try Bootstrap.build(StartsLitWarningGame())
        #expect(
            definition.warnings.contains {
                $0.contains("startsLit") && $0.contains("candle")
            })
        #expect(state.litItems.isEmpty)
    }

    @Test func litItemsSeedsFromStartsLit() throws {
        let (definition, state) = try Bootstrap.build(CaveGame())
        let torchID = definition.items.first { $0.value.name == "burning torch" }!.key
        let lampID = definition.items.first { $0.value.name == "tin lamp" }!.key
        #expect(state.litItems == [torchID])
        #expect(!state.litItems.contains(lampID))
    }
}
