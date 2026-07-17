import Foundation
import GnustoTestSupport
import Testing

@testable import Gnusto
@testable import GnustoMeleeCombat

/// `GnustoMeleeCombat`: weapon resolution, the seeded outcome table,
/// stunning, counter-attacks, and the ledger's save round-trip. Seeds were
/// discovered by scanning and are pinned with their recorded sequences.
struct MeleeCombatTests {
    /// The per-weapon table: a keener weapon whiffs less and kills more, and
    /// the baseline (strength 2) reproduces the historic 30/70/85 table so an
    /// undeclared weapon fights exactly as before.
    @Test func keenerWeaponsMissLessAndKillMore() {
        let clumsy = MeleeCombat.outcomeCutpoints(weaponStrength: 1)
        let baseline = MeleeCombat.outcomeCutpoints(weaponStrength: 2)
        let keen = MeleeCombat.outcomeCutpoints(weaponStrength: 3)
        // The miss cutpoint shrinks as the blade sharpens...
        #expect(clumsy.0 > baseline.0)
        #expect(baseline.0 > keen.0)
        // ...and the kill window (everything above the knockout cut) widens.
        #expect(keen.2 < baseline.2)
        #expect(baseline.2 < clumsy.2)
        // The baseline is the old fixed table, unchanged.
        #expect(baseline == (30, 70, 85))
    }

    @Test func weaponGuardsRefuseBeforeAnyRoll() async throws {
        // Seed 9's dummy misses/wounds without killing for many turns, so
        // the guard refusals stay in front. The refusal lines themselves
        // are what's asserted; they precede any table roll.
        let transcript = try await play(
            ArenaGame(),
            [
                "take feather",
                "attack dummy with feather",
                "attack dummy",
                "attack sword",
                "quit",
            ],
            seed: 9)
        expectInOrder(
            transcript,
            [
                "The goose feather is no weapon.",
                "Bare hands won't do it. You need a weapon.",
                "Violence isn't the answer to this one.",
            ])
    }

    @Test func aNamedWeaponMustBeInHand() async throws {
        let transcript = try await play(
            ArenaGame(),
            ["attack dummy with sword", "quit"],
            seed: 9)
        expectInOrder(transcript, ["You aren't holding the dull sword."])
    }

    @Test func threeWoundsBringTheDummyDown() async throws {
        // Seed 15: d-miss | wound d-wound | wound d-miss | DEATH.
        let transcript = try await play(
            ArenaGame(),
            [
                "take sword",
                "attack dummy", "attack dummy", "attack dummy",
                "gloat", "attack dummy", "quit",
            ],
            seed: 15)
        expectInOrder(
            transcript,
            [
                "Burlap tears.",
                "Burlap tears.",
                "The dummy bursts in a spray of sand.",
                "Defeated: true.",
                "You can't see any such thing.",
            ])
    }

    @Test func aStunnedVillainNeitherFightsNorSurvivesTheNextBlow() async throws {
        // Seed 21: d-miss | miss d-wound | KO (stun: no counter) | clean DEATH.
        let transcript = try await play(
            ArenaGame(),
            ["take sword", "attack dummy", "attack dummy", "attack dummy", "quit"],
            seed: 21)
        expectInOrder(
            transcript,
            [
                "Your swing kicks up sand.",
                "The dummy wobbles, out on its feet.",
                "The dummy bursts in a spray of sand.",
            ])
        // The knockout turn and the finish get no counter-attack: the only
        // dummy blows are the two before the KO.
        let afterKO = transcript.components(
            separatedBy: "out on its feet")[1]
        #expect(!afterKO.contains("swings wide"))
        #expect(!afterKO.contains("clips your ear"))
    }

    @Test func theDummyCanKillYouAndUndoRevives() async throws {
        // Seed 2: two wounds land on the dummy, then it lands the big one.
        let transcript = try await play(
            ArenaGame(),
            [
                "take sword",
                "attack dummy", "attack dummy", "attack dummy",
                "undo", "look", "quit",
            ],
            seed: 2)
        expectInOrder(
            transcript,
            [
                "The dummy lands one square on your temple.",
                "*** You have died ***",
                "Would you like to RESTART, RESTORE a saved game, UNDO your last turn, or QUIT?",
                "Previous turn undone.",
                "Arena",
            ])
    }

    @Test func sameSeedSameFight() async throws {
        let commands = ["take sword"] + Array(repeating: "attack dummy", count: 5) + ["quit"]
        let first = try await play(ArenaGame(), commands, seed: 15)
        let second = try await play(ArenaGame(), commands, seed: 15)
        #expect(first == second)
    }

    @Test func theLedgerSurvivesSaveAndRestore() async throws {
        // Seed 15 again: wound, save, wound, death — then restore and the
        // same two turns replay beat for beat.
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("gnusto-melee-\(UUID().uuidString).sav").path
        defer { try? FileManager.default.removeItem(atPath: path) }
        let transcript = try await play(
            ArenaGame(),
            [
                "take sword", "attack dummy",
                "save", path,
                "attack dummy", "attack dummy", "gloat",
                "restore", path,
                "attack dummy", "attack dummy", "gloat",
                "quit",
            ],
            seed: 15)
        let extract: (String) -> [String] = { segment in
            segment.components(separatedBy: "\n").filter {
                $0.contains("Burlap tears.") || $0.contains("spray of sand")
                    || $0.contains("Defeated:")
            }
        }
        let afterSave = transcript.components(separatedBy: "Saved.")[1]
            .components(separatedBy: "> restore")[0]
        let afterRestore = transcript.components(separatedBy: "Restored.")[1]
            .components(separatedBy: "> quit")[0]
        #expect(extract(afterSave) == extract(afterRestore))
        #expect(extract(afterSave).contains { $0.contains("Defeated: true.") })
    }
}
