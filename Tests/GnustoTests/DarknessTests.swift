import Foundation
import GnustoTestSupport
import Testing

@testable import Gnusto

struct DarknessTests {
    @Test func darkRoomsArePitchBlackOnEntry() async throws {
        let transcript = try await play(MiniGame(), ["down"])
        let entry = turnOutput(of: "down", in: transcript)
        #expect(entry.contains("It is pitch black. You can't see a thing."))
        #expect(!entry.contains("Cellar"))
        #expect(!entry.contains("A damp cellar."))
    }

    @Test func darkScopeExcludesRoomItemsButKeepsCarriedOnes() async throws {
        let transcript = try await play(
            MiniGame(),
            ["down", "examine hat", "drop hat", "take hat"])
        // Carried items stay usable in the dark.
        let examine = turnOutput(of: "examine hat", in: transcript)
        #expect(examine.contains("You see nothing special about the felt hat."))
        // Dropping in the dark works (the hat is carried, so in scope) — but
        // once dropped it vanishes into the darkness.
        let retake = turnOutput(of: "take hat", in: transcript)
        #expect(retake.contains("You can't see any such thing."))
    }

    @Test func darkVisitsDoNotMarkTheRoomVisited() async throws {
        let transcript = try await play(
            ProxyProbeGame(),
            ["take candle", "east", "west", "east", "west"])
        // After `take candle`, the porch goes dark. Moving away and back:
        // every re-entry is pitch black, and the room was never marked
        // visited while dark — so there's nothing brief about it.
        let outputs = transcript.components(separatedBy: "> west")
        #expect(outputs.count == 3)
        for reentry in outputs.dropFirst() {
            #expect(reentry.contains("It is pitch black."))
        }
    }
}
