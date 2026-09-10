import GnustoTestSupport
import Testing

@testable import Gnusto

extension Intent {
    /// Declared here, reused by `UndoRestartTests` — #verb constants are
    /// module-wide statics on `Intent`.
    #verb("roll")
    #verb("check")
    #verb("edges")
}

/// A game whose only verbs are chance: `roll` draws from all three
/// randomness helpers; `check` exercises their certain edges; `edges` asks
/// only the two questions `chance` answers without drawing.
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
        [.roll, .check, .edges]
    }

    var rules: Rules {
        world.before(.roll) {
            let die = random(1...1000)
            let mood = oneOf("grim", "bright", "odd")
            let luck = chance(50) ? "lucky" : "unlucky"
            try reply("You roll \(die), feeling \(mood) and \(luck).")
        }
        world.before(.check) {
            try reply("one=\(random(1...1)) yes=\(chance(100)) no=\(chance(0))")
        }
        world.before(.edges) {
            try reply("yes=\(chance(100)) no=\(chance(0))")
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

    /// And neither edge draws: the roll after `edges` is the roll a bare
    /// `roll` would have made from the same seed, so `chance(100)` and
    /// `chance(0)` cost the stream nothing. (`random(1...1)` does draw, which
    /// is why `check` is not the control here.)
    @Test func theCertainEdgesCostNoDraw() async throws {
        let asked = try await play(DiceGame(), ["edges", "roll"], seed: 7)
        expectInOrder(asked, ["yes=true no=false"])
        let bare = try await play(DiceGame(), ["roll"], seed: 7)
        #expect(turnOutput(of: "roll", in: asked) == turnOutput(of: "roll", in: bare))
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
