import Foundation
import Gnusto
import GnustoTestSupport
import Testing

/// `Actor.isUnconscious` — the one condition the engine stores, and the seam it
/// was put there for. `GnustoMeleeCombat` sets it when a blow lands a knockout;
/// `GnustoActors` reads it, so a villain lying on the floor neither wanders off
/// nor picks a pocket. Neither plugin can see the other, which is why the flag
/// is the engine's.
///
/// The theft fixtures roll `chancePerTurn: 100`, so a turn with no theft line
/// in it is the guard holding rather than a roll going the other way.
struct UnconsciousActorTests {
    // MARK: - The reported bug

    /// The bug from the field: battered senseless on one line, lifting the
    /// chalice out of your hand on the next. He is down for exactly the two
    /// turns his counter-attack skips, and lifts nothing in either of them.
    @Test func theKnockedOutVillainLiftsNothingWhileHeIsDown() async throws {
        let transcript = try await play(
            CutpurseGame(),
            ["attack cutpurse", "check", "wait", "check"],
            seed: 4)

        expectInOrder(
            transcript,
            [
                "The cutpurse folds up and lies still.",
                "Out cold: true.",  // still down a turn later
                "Out cold: false.",  // and up on the turn after that
            ])

        // The two turns he spends on the floor: the knockout turn and the one
        // after it. Neither carries a theft line.
        let knockdown = turnOutput(of: "attack cutpurse", in: transcript)
        #expect(!knockdown.contains("He lifts the"))
        let whileDown = turnOutput(of: "check", in: transcript)
        #expect(!whileDown.contains("He lifts the"))

        // And he does resume — the guard suppresses theft, it doesn't end it.
        #expect(turnOutput(of: "wait", in: transcript).contains("He lifts the"))
    }

    /// Coming round is not an aggressive act, so it happens ahead of the host's
    /// `while:` gate. Under a truce the cutpurse never once swings — and still
    /// wakes on schedule and goes back to work. Before the countdown moved
    /// ahead of the gate, a villain knocked out where his gate was shut stayed
    /// unconscious for the rest of the game.
    @Test func comingRoundIsNotGatedWithTheCounterAttack() async throws {
        let transcript = try await play(
            CutpurseGame(),
            ["parley", "attack cutpurse", "wait", "check", "wait", "check"],
            seed: 0)

        expectInOrder(
            transcript,
            [
                "You call a truce.",
                "The cutpurse folds up and lies still.",
                "Out cold: true.",
                "Out cold: false.",
            ])

        // The truce held throughout: he never counter-attacked, so the gate was
        // shut for every turn of the run.
        #expect(!transcript.contains("He jabs and misses."))
        #expect(!transcript.contains("He catches you a glancing one."))
    }

    /// The flag is world state, so it saves and restores with everything else.
    @Test func beingOutColdSurvivesASaveAndRestore() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("gnusto-unconscious-\(UUID().uuidString).sav").path
        defer { try? FileManager.default.removeItem(atPath: path) }

        let transcript = try await play(
            CutpurseGame(),
            [
                "attack cutpurse", "save", path,
                "wait", "wait", "check",  // he comes round
                "restore", path, "check",  // …and is back on the floor
            ],
            seed: 4)

        expectInOrder(
            transcript,
            [
                "The cutpurse folds up and lies still.",
                "Saved.",
                "Out cold: false.",
                "Restored.",
                "Out cold: true.",
            ])
    }

    // MARK: - The flag on its own, with no combat plugin in the game

    /// `GnustoActors` reads the flag, whatever set it: `PickpocketGame` has no
    /// combat plugin at all, only a verb that lays the thief out.
    @Test func aThiefWhoIsOutColdStealsNothing() async throws {
        let transcript = try await play(
            PickpocketGame(),
            ["swoon", "wait", "rouse", "look"])

        #expect(!turnOutput(of: "swoon", in: transcript).contains("Featherlight fingers"))
        #expect(!turnOutput(of: "wait", in: transcript).contains("Featherlight fingers"))
        // Rousing him restores the certainty: he lifts something that very turn.
        #expect(turnOutput(of: "rouse", in: transcript).contains("Featherlight fingers"))
    }

    /// The same guard on the roaming daemon: a man who is out cold does not
    /// wander off.
    @Test func aRoamerWhoIsOutColdHoldsStill() async throws {
        let transcript = try await play(
            WanderGame(),
            ["swoon", "wait", "wait", "rouse", "wait"],
            seed: 7)

        #expect(!turnOutput(of: "swoon", in: transcript).contains("The wanderer"))
        #expect(!turnOutput(of: "wait", in: transcript).contains("The wanderer"))
        // He resumes: with `chancePerTurn: 100` the very next tick moves him.
        #expect(transcript.contains("The wanderer saunters in."))
    }
}
