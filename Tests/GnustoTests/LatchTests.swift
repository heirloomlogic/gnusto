import Foundation
import GnustoTestSupport
import Testing

@testable import Gnusto

/// `@Latch`: the one-way half of `@Global`. It starts down, `trips()` raises
/// it and says whether this call was the one that did, and nothing puts it
/// back — `flag = false` does not compile, which is the whole affordance.
struct LatchTests {
    // MARK: - The latch is the hand-rolled pair, said once

    @Test(arguments: [
        ["touch bell", "touch bell", "touch bell"],
        ["north", "push lever", "north", "look", "south"],
        ["push lever", "north", "east", "push slab", "push slab"],
        ["x candle", "turn on candle", "x candle", "wait", "wait", "x candle"],
        ["touch bell", "undo", "touch bell"],
        ["hum", "x bell"],
    ])
    func latchMatchesTheGlobalItReplaces(commands: [String]) async throws {
        let latched = try await play(fresh: LatchGame(latched: true), commands, seed: 0)
        let byHand = try await play(fresh: LatchGame(latched: false), commands, seed: 0)
        #expect(latched == byHand)
    }

    // MARK: - trips()

    @Test func tripsAnswersTrueOnlyOnTheCallThatRaisesIt() async throws {
        let transcript = try await play(
            LatchGame(), ["touch bell", "touch the bell", "touch brass bell"], seed: 0)
        expectInOrder(
            transcript,
            [LatchGame.bellFirst, LatchGame.bellAgain, LatchGame.bellAgain])
    }

    @Test func aBundlesLatchTripsOnItsOwn() async throws {
        let transcript = try await play(
            LatchGame(),
            ["push lever", "north", "east", "push slab", "push the slab"],
            seed: 0)
        expectInOrder(transcript, [LatchAnnex.slabFirst, LatchAnnex.slabAgain])
    }

    @Test func anUntrippedLatchReadsFalse() async throws {
        let transcript = try await play(LatchGame(), ["north", "push lever", "north"], seed: 0)
        expectInOrder(transcript, [LatchGame.vaultShut, LatchGame.leverPushed, "Vault"])
    }

    /// A fuse raises it two turns out, and a `describe { }` reads it — the
    /// two closures furthest from the declaration.
    @Test func aFuseTripsALatchADescriberReads() async throws {
        let transcript = try await play(
            LatchGame(), ["x candle", "turn on candle", "wait", "wait", "examine candle"], seed: 0)
        #expect(turnOutput(of: "x candle", in: transcript).contains(LatchGame.candleWhole))
        #expect(transcript.contains(LatchGame.candleDies))
        #expect(turnOutput(of: "examine candle", in: transcript).contains(LatchGame.candleStub))
    }

    // MARK: - It is a global, so it rides every mechanism a global rides

    @Test func aTrippedLatchSurvivesSaveAndRestore() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gnusto-latch-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        // Up at the save, so the restored world answers with the second line
        // rather than starting the beat over.
        let up = try await play(
            LatchGame(),
            ["touch bell", "save", "raised", "touch the bell", "restore", "raised", "touch brass bell"],
            saveDirectory: dir)
        expectInOrder(up, [LatchGame.bellFirst, "Saved.", LatchGame.bellAgain, LatchGame.bellAgain])
        #expect(!turnOutput(of: "touch brass bell", in: up).contains(LatchGame.bellFirst))

        // Down at the save, and the restore takes it back down: the first line
        // is the answer again, on a bell that has already been touched once.
        let down = try await play(
            LatchGame(),
            ["save", "down", "touch bell", "restore", "down", "touch the bell"],
            saveDirectory: dir)
        expectInOrder(down, ["Saved.", LatchGame.bellFirst, LatchGame.bellFirst])
        #expect(!down.contains(LatchGame.bellAgain))
    }

    @Test func undoUntripsALatchRaisedThisTurn() async throws {
        let transcript = try await play(
            LatchGame(), ["touch bell", "undo", "touch the bell"], seed: 0)
        expectInOrder(transcript, [LatchGame.bellFirst, LatchGame.bellFirst])
        #expect(!transcript.contains(LatchGame.bellAgain))
    }

    /// `mutter` reaches stage 4's last resort, so the turn is `unhandled` and
    /// the engine restores the snapshot — taking the `before` rule's trip with
    /// it, exactly as it would a `@Global` write.
    @Test func anUnhandledTurnRollsBackATrip() async throws {
        let transcript = try await play(LatchGame(), ["hum", "x bell"], seed: 0)
        #expect(turnOutput(of: "x bell", in: transcript).contains(LatchGame.bellQuiet))
    }

    // MARK: - Registration

    @Test func aLatchRegistersLikeAGlobalAndABundlesIsNamespaced() throws {
        let (definition, _) = try Bootstrap.build(LatchGame())
        let globals = definition.globals
        #expect(globals[EntityID("rung")] != nil)
        #expect(globals[EntityID("LatchAnnex.slabMoved")] != nil)
        // Down is the declared default, so a world nothing has played reads
        // false without anything having seeded storage.
        #expect(globals[EntityID("rung")]?.defaultValue == .bool(false))
    }
}
