import GnustoTestSupport
import Testing

@testable import Gnusto

/// A game that re-skins a couple of stock lines to prove the engine speaks
/// through `GameText`.
private struct SnarkyGame: Game {
    let title = "Snark"
    let intro = "A very small cave."

    let cave = Location {
        name("Cave")
        description("A cave barely big enough to stand in.")
    }

    let pebble = Item {
        name("smooth pebble")
        adjectives("smooth")
    }

    var map: WorldMap {
        player.starts(in: cave)
        pebble.starts(in: cave)
    }

    var text: GameText {
        var text = GameText()
        text.taken = "Snagged."
        text.cantGoThatWay = "Walls exist, you know."
        return text
    }
}

/// Phase 6 GameText: every stock player-facing line lives on a value the
/// game can override; the defaults are the classic voice (covered by the
/// Cloak transcript canary).
struct GameTextTests {
    @Test func overriddenLinesSpeakInTheGamesVoice() async throws {
        let transcript = try await play(SnarkyGame(), ["take pebble", "west"])
        expectInOrder(transcript, ["Snagged.", "Walls exist, you know."])
        #expect(!transcript.contains("Taken."))
    }

    @Test func untouchedLinesKeepTheirDefaults() async throws {
        let transcript = try await play(SnarkyGame(), ["drop pebble"])
        expectInOrder(transcript, ["You aren't carrying that."])
    }
}
