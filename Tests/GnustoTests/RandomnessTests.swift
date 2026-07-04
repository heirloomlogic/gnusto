import GnustoTestSupport
import Testing

@testable import Gnusto

/// A game whose only verbs are chance: `roll` draws from all three
/// randomness helpers; `check` exercises their certain edges.
private struct DiceGame: Game {
    let title = "Dice"
    let intro = "A felt table."

    let den = Location {
        name("Den")
        description("A den with a felt table.")
    }

    var map: WorldMap {
        player.starts(in: den)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("roll", intent: Intent("roll"))
        SyntaxRule("check", intent: Intent("check"))
    }

    var rules: Rules {
        world.before(Intent("roll")) {
            let die = random(1...1000)
            let mood = oneOf("grim", "bright", "odd")
            let luck = chance(50) ? "lucky" : "unlucky"
            try reply("You roll \(die), feeling \(mood) and \(luck).")
        }
        world.before(Intent("check")) {
            try reply("one=\(random(1...1)) yes=\(chance(100)) no=\(chance(0))")
        }
    }
}

/// Phase 6 seeded RNG: one savable stream drives all randomness, so a fixed
/// seed replays the same game everywhere.
struct RandomnessTests {
    static let manyRolls = Array(repeating: "roll", count: 20)

    @Test func sameSeedSameStory() async throws {
        let first = try await play(DiceGame(), Self.manyRolls, seed: 42)
        let second = try await play(DiceGame(), Self.manyRolls, seed: 42)
        #expect(first == second)
    }

    @Test func differentSeedsDiverge() async throws {
        let first = try await play(DiceGame(), Self.manyRolls, seed: 42)
        let second = try await play(DiceGame(), Self.manyRolls, seed: 43)
        // 20 draws of d1000 colliding across seeds is (1/1000)^20 —
        // effectively impossible without a broken stream.
        #expect(first != second)
    }

    @Test func certainEdgesAreCertain() async throws {
        let transcript = try await play(DiceGame(), ["check"], seed: 7)
        expectInOrder(transcript, ["one=1 yes=true no=false"])
    }

    @Test func aCopiedStateReplaysTheSameTail() throws {
        var state = WorldState(playerLocation: EntityID("den"))
        state.rngState = 0xDEAD_BEEF
        var copy = state
        let tail = (0..<8).map { _ in state.nextRandom() }
        let replay = (0..<8).map { _ in copy.nextRandom() }
        #expect(tail == replay)
    }
}
