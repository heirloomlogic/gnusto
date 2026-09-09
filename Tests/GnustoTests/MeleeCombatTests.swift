import Foundation
import GnustoTestSupport
import Testing

@testable import Gnusto
@testable import GnustoMeleeCombat

/// `GnustoMeleeCombat`: weapon resolution, the seeded outcome table,
/// stunning, counter-attacks, and the ledger's save round-trip. Seeds were
/// discovered by scanning and are pinned with their recorded sequences.
struct MeleeCombatTests {
    // The platform policy for exit tests is in `Package.swift`.
    #if GNUSTO_EXIT_TESTS

    @Test(
        "empty rotating prose is rejected at declaration",
        arguments: InvalidMeleeProse.allCases)
    func emptyRotatingProseIsRejectedAtDeclaration(_ prose: InvalidMeleeProse) async {
        let result = await #expect(
            processExitsWith: .failure, observing: [\.standardErrorContent]
        ) {
            [prose = prose as InvalidMeleeProse] in
            prose.make()
        }
        expectTrap(result, says: prose.diagnostic)
    }

    @Test(
        "empty rotating prose is rejected at registration",
        arguments: InvalidMeleeProse.allCases)
    func emptyRotatingProseIsRejectedAtRegistration(_ prose: InvalidMeleeProse) async {
        let result = await #expect(
            processExitsWith: .failure, observing: [\.standardErrorContent]
        ) {
            [prose = prose as InvalidMeleeProse] in
            prose.register()
        }
        expectTrap(result, says: prose.diagnostic)
    }

    #endif

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
                "Attacking a dull sword isn't the answer.",
            ])
    }

    @Test func aNamedWeaponMustBeInHand() async throws {
        let transcript = try await play(
            ArenaGame(),
            ["attack dummy with sword", "quit"],
            seed: 9)
        expectInOrder(transcript, ["You aren't holding the dull sword."])
    }

    @Test func aTraitMarkedWeaponNeedsNoVillainList() async throws {
        let transcript = try await play(
            ArenaGame(),
            ["take sword", "attack dummy with sword", "quit"],
            seed: 9)
        #expect(!transcript.contains("is no weapon"))
        #expect(transcript.contains("Burlap tears."))
    }

    @Test func anExplicitListRestrictsTraitMarkedWeapons() async throws {
        let transcript = try await play(
            AmbushGame(),
            ["take sabre", "attack bandit with sabre", "attack bandit", "quit"],
            seed: 9)
        expectInOrder(
            transcript,
            [
                "The cavalry sabre is no weapon.",
                "Bare hands won't do it. You need a weapon.",
            ])
    }

    @Test func aBareAttackChoosesTheStrongestHeldWeapon() async throws {
        let automatic = try await play(WeaponChoiceGame(), ["attack target", "quit"], seed: 0)
        let keen = try await play(
            WeaponChoiceGame(), ["attack target with keen blade", "quit"], seed: 0)
        let clumsy = try await play(
            WeaponChoiceGame(), ["attack target with clumsy blade", "quit"], seed: 0)

        #expect(automatic.contains("The blade slices the straw."))
        #expect(keen.contains("The blade slices the straw."))
        #expect(clumsy.contains("The blade misses the straw."))
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

    /// The two rows the plugin adds beyond the engine's `attack` stubs. Worth a
    /// test of its own because the failure mode is silent: drop them and `stab`
    /// falls back to "I don't know the word" with nothing red anywhere else —
    /// the standard table still answers `attack`, so the loss doesn't show.
    @Test func stabAndStrikeReachTheCombatIntent() async throws {
        let transcript = try await play(
            ArenaGame(),
            ["take sword", "stab dummy with sword", "strike dummy with sword", "quit"],
            seed: 9)
        #expect(!transcript.contains("I don't know the word"))
        #expect(!transcript.contains("I didn't understand"))
    }
}

enum InvalidMeleeProse: String, CaseIterable, Codable, Sendable {
    case villainMiss
    case villainWound
    case aggressionMiss
    case aggressionWound

    var diagnostic: String {
        switch self {
        case .villainMiss: "VillainProse.miss needs at least one line"
        case .villainWound: "VillainProse.wound needs at least one line"
        case .aggressionMiss: "AggressionProse.miss needs at least one line"
        case .aggressionWound: "AggressionProse.wound needs at least one line"
        }
    }

    func make() {
        switch self {
        case .villainMiss:
            _ = MeleeCombat.VillainProse(miss: [], wound: ["Wound."], knockout: "Out.", death: "Dead.")
        case .villainWound:
            _ = MeleeCombat.VillainProse(miss: ["Miss."], wound: [], knockout: "Out.", death: "Dead.")
        case .aggressionMiss:
            _ = MeleeCombat.AggressionProse(miss: [], wound: ["Wound."], playerDeath: "Dead.")
        case .aggressionWound:
            _ = MeleeCombat.AggressionProse(miss: ["Miss."], wound: [], playerDeath: "Dead.")
        }
    }

    func register() {
        let melee = MeleeCombat()
        let actor = Actor()
        switch self {
        case .villainMiss:
            var prose = MeleeCombat.VillainProse(
                miss: ["Miss."], wound: ["Wound."], knockout: "Out.", death: "Dead.")
            prose.miss = []
            _ = melee.villain(actor, key: "villain", strength: 1, weapons: [], prose: prose)
        case .villainWound:
            var prose = MeleeCombat.VillainProse(
                miss: ["Miss."], wound: ["Wound."], knockout: "Out.", death: "Dead.")
            prose.wound = []
            _ = melee.villain(actor, key: "villain", strength: 1, weapons: [], prose: prose)
        case .aggressionMiss:
            var prose = MeleeCombat.AggressionProse(
                miss: ["Miss."], wound: ["Wound."], playerDeath: "Dead.")
            prose.miss = []
            _ = melee.aggression(of: actor, key: "villain", named: "villain", prose: prose)
        case .aggressionWound:
            var prose = MeleeCombat.AggressionProse(
                miss: ["Miss."], wound: ["Wound."], playerDeath: "Dead.")
            prose.wound = []
            _ = melee.aggression(of: actor, key: "villain", named: "villain", prose: prose)
        }
    }
}
