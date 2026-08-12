import Foundation
import GnustoTestSupport
import Testing

@testable import Gnusto
@testable import GnustoMeleeCombat

/// Engagement — the source's `FIGHTBIT` — and the strike-first probability that
/// can set it without the player's help.
///
/// `I-FIGHT` (`1actions.zil:3810`) has a villain strike only when the bit is
/// already set or when his own `F-FIRST?` branch fires, and clears the bit on
/// any villain the player is no longer standing with. Before this existed, ours
/// swung on every turn the player shared a room with him, which killed an
/// unprovoked player in the Troll Room in forty runs out of forty-one.
///
/// `AmbushGame`'s bandit is at `strikesFirst: 0`, so every aggression line in
/// one of his transcripts is proof the player engaged him; `SkulkerGame`'s is at
/// the thief's 20, for the roll itself.
struct EngagementTests {
    // MARK: - The ledger

    /// The field is new, and a save written before it existed has to degrade
    /// rather than trap: `Global`'s getter `fatalError`s on a failed decode
    /// instead of falling back to the default, so a synthesized decoder — which
    /// ignores a property's default and demands every key — would crash a
    /// restored game on the first turn a villain's daemon ticked.
    @Test func aLedgerFromBeforeEngagementExistedDecodesUnengaged() throws {
        let json = #"{"health":{"troll":2},"stunned":{},"playerHealth":1}"#
        let ledger = try JSONDecoder().decode(
            MeleeCombat.Ledger.self, from: Data(json.utf8))
        #expect(ledger.health["troll"] == 2)
        #expect(ledger.playerHealth == 1)
        #expect(ledger.engaged.isEmpty)
    }

    @Test func aLedgerFromRubbishKeepsItsDefaults() throws {
        let ledger = try JSONDecoder().decode(
            MeleeCombat.Ledger.self, from: Data(#"{"health":"lots"}"#.utf8))
        #expect(ledger.health.isEmpty)
        #expect(ledger.stunned.isEmpty)
        #expect(ledger.engaged.isEmpty)
        #expect(ledger.playerHealth == nil)
    }

    // MARK: - The extremes ask no question

    /// Certainty needs no dice. A villain who always starts a fight and one who
    /// never does both leave the stream where they found it — which is why the
    /// default of 100 moved not one of the suite's 370 pinned seeds.
    @Test func theExtremesOfStrikesFirstAskNoQuestion() {
        #expect(MeleeCombat.startsAFight(chance: 100))
        #expect(MeleeCombat.startsAFight(chance: 200))
        #expect(!MeleeCombat.startsAFight(chance: 0))
        #expect(!MeleeCombat.startsAFight(chance: -5))
    }

    // MARK: - A villain who never starts one

    /// Deliberately unseeded: at `strikesFirst: 0` there is nothing to roll, so
    /// the claim holds on every seed and a `GNUSTO_SEED` sweep exercises it.
    @Test func aVillainWhoNeverStartsOneNeverStartsOne() async throws {
        let transcript = try await play(
            AmbushGame(),
            ["wait", "wait", "wait", "wait", "wait", "wait", "wait", "wait", "quit"])
        #expect(!transcript.contains("The bandit lunges"))
        #expect(!transcript.contains("The bandit opens a cut"))
        #expect(!transcript.contains("knife somewhere final"))
        #expect(transcript.contains("Time passes."))
    }

    // MARK: - What engages him

    /// `HERO-BLOW` (`1actions.zil:3484`) sets `FIGHTBIT` on the way in, before it
    /// resolves the blow — and `I-FIGHT` runs the villains in the same turn — so
    /// he answers the swing that started it, not the one after.
    ///
    /// Seed 4, recorded: the player's first swing misses and the bandit's answer
    /// lands in that same turn.
    @Test func attackingHimEngagesHimInTheSameTurn() async throws {
        let transcript = try await play(
            AmbushGame(),
            ["take cosh", "attack bandit with cosh", "quit"],
            seed: 4)
        let turn = turnOutput(of: "attack bandit with cosh", in: transcript)
        #expect(turn.contains("The bandit"))
    }

    /// The other half of the same reading, and the one that is easy to get
    /// wrong. `V-ATTACK` (`gverbs.zil:176`) refuses three ways — bare hands, a
    /// weapon you aren't holding, a thing that isn't a weapon — and every one of
    /// them returns short of `HERO-BLOW`, so none of them sets the bit. Waving a
    /// twig at him is not a provocation.
    ///
    /// If someone later moves the engagement write above the weapon resolution,
    /// this is the test that says so.
    @Test func aRefusedSwingDoesNotEngageHim() async throws {
        let transcript = try await play(
            AmbushGame(),
            ["attack bandit with twig", "wait", "wait", "wait", "quit"])
        #expect(transcript.contains("The birch twig is no weapon."))
        #expect(!transcript.contains("The bandit lunges"))
        #expect(!transcript.contains("The bandit opens a cut"))
    }

    /// Bare-handed is the same refusal one door along.
    @Test func swingingWithNothingInHandDoesNotEngageHimEither() async throws {
        let transcript = try await play(
            AmbushGame(),
            ["attack bandit", "wait", "wait", "wait", "quit"])
        #expect(transcript.contains("You need a weapon."))
        #expect(!transcript.contains("The bandit lunges"))
        #expect(!transcript.contains("The bandit opens a cut"))
    }

    // MARK: - A fight, once started, runs

    /// Seed 4, recorded: five turns of standing in it and he answers in every
    /// one — no quiet turn between the blow that started it and the end of the
    /// run. At `strikesFirst: 0` the only thing keeping him swinging is the bit.
    @Test func theFightRunsEveryTurnUntilYouLeave() async throws {
        let transcript = try await play(
            AmbushGame(),
            ["take cosh", "attack bandit with cosh", "wait", "wait", "wait", "quit"],
            seed: 4)
        let after = output(after: "attack bandit with cosh", in: transcript)
        for turn in banditTurns(in: after) {
            #expect(turn.contains("The bandit"), "quiet turn in a live fight: \(turn)")
        }
        #expect(banditTurns(in: after).count >= 2)
    }

    /// `I-FIGHT`'s other branch: the bit is cleared on a villain the player is
    /// not standing with. So walking out ends the fight, and walking back in
    /// starts a man who — at 0 — will never start one himself.
    ///
    /// Seed 4, recorded: the fight is live when we leave, and every turn after
    /// coming back is silent.
    @Test func walkingOutAndBackInEndsTheFight() async throws {
        let transcript = try await play(
            AmbushGame(),
            [
                "take cosh", "attack bandit with cosh", "east", "wait", "wait",
                "west", "wait", "wait", "wait", "wait", "quit",
            ],
            seed: 4)
        let afterReturn = output(after: "> west", in: transcript)
        #expect(!afterReturn.contains("The bandit lunges"))
        #expect(!afterReturn.contains("The bandit opens a cut"))
        #expect(!afterReturn.contains("knife somewhere final"))
    }

    /// Constraint (b) of the guard order, and the reason disengaging sits above
    /// the host's gate rather than inside it. The source agrees: `I-FIGHT` skips
    /// the engrossed thief's turn — the man admiring a gift you handed him —
    /// without clearing his `FIGHTBIT`. A shut gate suspends a fight; it is not
    /// a truce.
    ///
    /// Seed 4, recorded: quiet through both parleyed turns, swinging again on
    /// the turn the hands come down, with no fresh blow from the player.
    @Test func aShutGateSuspendsAFightWithoutEndingIt() async throws {
        let transcript = try await play(
            AmbushGame(),
            [
                "take cosh", "attack bandit with cosh", "parley", "wait", "wait",
                "resume", "quit",
            ],
            seed: 4)
        let parleyed = output(after: "You put your hands up.", in: transcript)
        let resumed = output(after: "You put your hands down.", in: transcript)
        let suspended = parleyed.replacingOccurrences(of: resumed, with: "")
        #expect(!suspended.contains("The bandit lunges"))
        #expect(!suspended.contains("The bandit opens a cut"))
        #expect(resumed.contains("The bandit"))
    }

    // MARK: - The roll itself

    /// Seed 3, recorded: four turns in the den and the skulker's roll never
    /// fires, so an unengaged villain can share a room with you in silence —
    /// which is the whole complaint #237 was filed about.
    @Test func aQuietSeedIsAQuietRoom() async throws {
        let transcript = try await play(
            SkulkerGame(),
            ["east", "wait", "wait", "wait", "quit"],
            seed: 3)
        #expect(transcript.contains("Den"))
        #expect(!transcript.contains("The skulker darts in"))
        #expect(!transcript.contains("The skulker scores"))
        #expect(!transcript.contains("the gap he was waiting for"))
    }

    /// `F-FIRST?` sets `FIGHTBIT` when it fires, so a fight the villain starts
    /// persists exactly as one the player starts does.
    ///
    /// Seed 0, recorded: his roll fires in the den without a blow from the
    /// player, and he is still swinging on the turns after it.
    @Test func theFightHeStartsPersists() async throws {
        let transcript = try await play(
            SkulkerGame(),
            ["east", "wait", "wait", "wait", "wait", "wait", "quit"],
            seed: 0)
        #expect(!transcript.contains("The dirk finds nothing"))  // no player blow
        let turns = skulkerTurns(in: output(after: "> east", in: transcript))
        #expect(turns.count >= 2, "he never started one on this seed")
    }

    /// Neither of the two above can catch a roll hard-coded to always or never
    /// fire — each is one seed, and each would still pass against one of the two
    /// mistakes. Across twenty seeds a real 20% must produce both a wholly quiet
    /// den and a den with a swing in it. Five rolls a run puts P(all quiet) at
    /// about a third, so neither bound is a coin flip.
    @Test func theStrikeFirstRollIsReallyConsulted() async throws {
        var quiet = 0
        var noisy = 0
        for seed in UInt64(0)..<20 {
            let transcript = try await play(
                SkulkerGame(),
                ["east", "wait", "wait", "wait", "wait", "quit"],
                seed: seed)
            if transcript.contains("The skulker") {
                noisy += 1
            } else {
                quiet += 1
            }
        }
        #expect(quiet > 0, "he started a fight on every one of twenty seeds")
        #expect(noisy > 0, "he started one on none of twenty seeds")
    }

    // MARK: - Where the roll sits

    /// The companion to `AggressionGateTests`' alignment test, over the other
    /// guard. If the strike-first roll drifts above the same-room guard, the
    /// three turns spent in the hollow burn three draws that the straight-in run
    /// doesn't, and the two dens read differently. That regression would
    /// otherwise surface only as every pinned seed in two games moving for no
    /// reason anyone could name.
    @Test func theStrikeFirstRollIsBehindTheSameRoomGuard() async throws {
        let seed: UInt64 = 7
        let idleFirst = try await play(
            SkulkerGame(),
            ["wait", "wait", "wait", "east", "wait", "wait", "wait", "quit"],
            seed: seed)
        let straightIn = try await play(
            SkulkerGame(),
            ["east", "wait", "wait", "wait", "quit"],
            seed: seed)
        #expect(
            skulkerTurns(in: output(after: "> east", in: idleFirst))
                == skulkerTurns(in: output(after: "> east", in: straightIn)))
    }

    // MARK: - Helpers

    /// The bandit's lines in a slice, one per turn he spoke in.
    private func banditTurns(in slice: String) -> [String] {
        slice.split(separator: "\n").filter { $0.contains("bandit") }.map(String.init)
    }

    /// The skulker's, likewise.
    private func skulkerTurns(in slice: String) -> [String] {
        slice.split(separator: "\n").filter { $0.contains("skulker") }.map(String.init)
    }
}
