import GnustoTestSupport
import Testing

@testable import Gnusto

/// A parlor with one takable lamp and a `roll` verb that burns the random
/// stream — everything needed to watch UNDO and RESTART rewind state, moves,
/// and randomness.
private struct RewindGame: Game {
    let title = "Rewind"
    let intro = "A parlor, stopped mid-tick."

    let parlor = Location {
        name("Parlor")
        description("Chintz and shadows.")
    }

    let lamp = Item {
        name("oil lamp")
    }

    var map: WorldMap {
        player.starts(in: parlor)
        lamp.starts(in: parlor)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("roll", intent: Intent("roll"))
    }

    var rules: Rules {
        world.before(Intent("roll")) {
            try reply("You roll \(random(1...1000)).")
        }
    }
}

struct UndoRestartTests {
    @Test func undoReversesExactlyOneTurn() async throws {
        let transcript = try await play(
            RewindGame(),
            ["score", "take lamp", "undo", "score", "take lamp"])
        let undo = turnOutput(of: "undo", in: transcript)
        #expect(undo.contains("Previous turn undone."))
        #expect(undo.contains("Parlor"))
        // The lamp is back: taking it again succeeds instead of "already have".
        let takes = transcript.components(separatedBy: "> take lamp")
        #expect(takes[2].contains("Taken."))
        // Moves rewound: both score probes report the same move count.
        let scores = transcript.components(separatedBy: "> score")
        let firstScore = scores[1].prefix(while: { $0 != ">" })
        let secondScore = scores[2].prefix(while: { $0 != ">" })
        #expect(firstScore == secondScore)
    }

    @Test func nothingToUndoAtTheStartOrTwice() async throws {
        let transcript = try await play(
            RewindGame(),
            ["undo", "take lamp", "undo", "undo"])
        let undos = transcript.components(separatedBy: "> undo")
        #expect(undos[1].contains("There's nothing to undo."))
        #expect(undos[2].contains("Previous turn undone."))
        #expect(undos[3].contains("There's nothing to undo."))
    }

    @Test func freeTurnsDoNotDisturbTheSnapshot() async throws {
        // A parse error, a meta command, and an empty `take all` (a free
        // reply) all sit between the mistake and its undo — none of them
        // clobbers the snapshot.
        let transcript = try await play(
            RewindGame(),
            ["take lamp", "xyzzy", "score", "take all", "undo", "take lamp"])
        let takeAll = turnOutput(of: "take all", in: transcript)
        #expect(takeAll.contains("There is nothing here to take."))
        let undo = turnOutput(of: "undo", in: transcript)
        #expect(undo.contains("Previous turn undone."))
        let takes = transcript.components(separatedBy: "> take lamp")
        #expect(takes[2].contains("Taken."))
    }

    @Test func undoRestoresTheRandomStream() async throws {
        let transcript = try await play(
            RewindGame(),
            ["roll", "undo", "roll"],
            seed: 7)
        let rolls = transcript.components(separatedBy: "> roll")
        let first = rolls[1].prefix(while: { $0 != ">" })
        let second = rolls[2].prefix(while: { $0 != ">" })
        #expect(first == second)
    }

    @Test func undoConsumesNoTurn() async throws {
        let transcript = try await play(
            RewindGame(),
            ["take lamp", "undo", "score"])
        // take lamp advanced to 1; undo rewound to 0 and cost nothing.
        let score = turnOutput(of: "score", in: transcript)
        #expect(score.contains("in 0 turns"))
    }

    @Test func restartRewindsToTheOpening() async throws {
        let transcript = try await play(
            RewindGame(),
            ["take lamp", "restart", "take lamp", "undo", "undo"])
        let restart = turnOutput(of: "restart", in: transcript)
        // The full opening replays: intro, banner, first look.
        #expect(restart.contains("A parlor, stopped mid-tick."))
        #expect(restart.contains("Rewind"))
        #expect(restart.contains("Chintz and shadows."))
        // State reset: the lamp is takable again.
        let takes = transcript.components(separatedBy: "> take lamp")
        #expect(takes[2].contains("Taken."))
        // Restart cleared the undo history; the take after it is undoable,
        // then nothing.
        let undos = transcript.components(separatedBy: "> undo")
        #expect(undos[1].contains("Previous turn undone."))
        #expect(undos[2].contains("There's nothing to undo."))
    }

    @Test func restartReplaysTheSameSeed() async throws {
        let transcript = try await play(
            RewindGame(),
            ["roll", "restart", "roll"],
            seed: 99)
        let rolls = transcript.components(separatedBy: "> roll")
        let first = rolls[1].prefix(while: { $0 != ">" })
        let second = rolls[2].prefix(while: { $0 != ">" })
        #expect(first == second)
    }

    @Test func undoReversesAWholeMultiObjectCommand() async throws {
        let transcript = try await play(
            RewindGame(),
            ["take all", "undo", "take all"])
        let takes = transcript.components(separatedBy: "> take all")
        #expect(takes[1].contains("oil lamp: Taken."))
        #expect(takes[2].contains("oil lamp: Taken."))
    }
}
