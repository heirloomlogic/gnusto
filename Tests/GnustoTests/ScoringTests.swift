import Foundation
import GnustoTestSupport
import Testing

@testable import CloakOfDarkness
@testable import Dungeon
@testable import Gnusto
@testable import Gramarye
@testable import Lighthouse
@testable import Zork1

/// The `GnustoScoring` plugin: treasure values as typed traits, award-once
/// registers, and deposit scoring gated on landing in the right container.
struct ScoringTests {
    @Test func takeAndDepositEachPayOnce() async throws {
        let transcript = try await play(
            TreasureVaultGame(),
            [
                "score",
                "take gem", "score",
                "put gem in case", "score",
                "quit",
            ])
        expectInOrder(
            transcript,
            [
                "Your score is 0 of a possible 15",
                "Taken.",
                "Your score is 4 of a possible 15",
                "Your score is 10 of a possible 15",
            ])
    }

    @Test func takeValueIsForKeepsButDepositValueTogglesWithTheCase() async throws {
        let transcript = try await play(
            TreasureVaultGame(),
            [
                "take gem", "drop gem", "take gem", "score",  // take pays once → 4
                "put gem in case", "score",  // deposit credited → 10
                "take gem", "score",  // withdrawn → deposit revoked → 4
                "put gem in case", "score",  // re-deposited → restored → 10
                "quit",
            ])
        expectInOrder(
            transcript,
            [
                "Your score is 4 of a possible 15",
                "Your score is 10 of a possible 15",
                "Your score is 4 of a possible 15",
                "Your score is 10 of a possible 15",
            ])
        // Take value never doubles (re-taking a dropped gem adds nothing)...
        #expect(!transcript.contains("score is 8"))
        // ...and deposit value never stacks past its single 6.
        #expect(!transcript.contains("score is 16"))
    }

    @Test func theSackIsNotTheCase() async throws {
        let transcript = try await play(
            TreasureVaultGame(),
            ["take gem", "put gem in sack", "score", "quit"])
        expectInOrder(transcript, ["Your score is 4 of a possible 15"])
        #expect(!transcript.contains("score is 10"))
    }

    @Test func aValuelessTreasureAwardsNothing() async throws {
        let transcript = try await play(
            TreasureVaultGame(),
            ["take pebble", "put pebble in case", "score", "quit"])
        expectInOrder(transcript, ["Your score is 0 of a possible 15"])
    }

    @Test func awardOnceIsIdempotentByRegister() async throws {
        let transcript = try await play(
            TreasureVaultGame(),
            ["meditate", "score", "meditate", "score", "quit"])
        let scores = transcript.components(separatedBy: "Your score is ")
        #expect(scores[1].hasPrefix("5"))
        #expect(scores[2].hasPrefix("5"))
    }

    @Test func theDeathBannerReportsTheScore() async throws {
        let transcript = try await play(
            TreasureVaultGame(),
            ["take gem", "perish", "quit"])
        expectInOrder(
            transcript,
            [
                "The dust was not dust.",
                "*** You have died ***",
                "Your score is 4 of a possible 15",
            ])
    }

    @Test func visitPaysOnFirstEntryOnly() async throws {
        let transcript = try await play(
            GalleryGame(),
            ["score", "north", "score", "south", "north", "score", "quit"])
        expectInOrder(
            transcript,
            [
                "Your score is 0 of a possible 25",
                "Inner Hall",
                // First entry paid 25.
                "Your score is 25 of a possible 25",
                // Re-entering pays nothing more.
                "Your score is 25 of a possible 25",
            ])
    }

    @Test func penalizeRepeatsAndGoesNegative() async throws {
        let transcript = try await play(
            GalleryGame(),
            ["stumble", "score", "stumble", "score", "quit"])
        expectInOrder(
            transcript,
            [
                "You stumble and bark your shin.",
                // First stumble: 0 - 10 = -10 (no floor).
                "Your score is -10 of a possible 25",
                // Second stumble: -10 - 10 = -20, proving it repeats.
                "Your score is -20 of a possible 25",
            ])
    }

    @Test func claimedRegistersSurviveSaveAndRestore() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("gnusto-scoring-\(UUID().uuidString).sav").path
        defer { try? FileManager.default.removeItem(atPath: path) }
        let transcript = try await play(
            TreasureVaultGame(),
            [
                "take gem", "put gem in case",
                "save", path,
                "take gem",
                "restore", path,
                "take gem", "put gem in case", "score",
                "quit",
            ])
        expectInOrder(transcript, ["Saved.", "Restored.", "Your score is 10 of a possible 15"])
    }
}

/// The bootstrap's `maxScore` check. `maxScore` is read before any rule can run,
/// so on its own it is the author's arithmetic; `ScoreDeclaring` content hands
/// the bootstrap the total it can actually pay, and the two must agree.
///
/// A transcript test cannot stand in for this: `"Your score is 25 of a possible
/// 25"` agrees with `maxScore` only because that particular route collects every
/// award, and an award added outside the route would pass the same assertion.
struct MaxScoreCheckTests {
    /// Every score warning names both numbers, so callers can key on the shape
    /// without repeating the whole sentence.
    private func scoreWarnings(_ warnings: [String]) -> [String] {
        warnings.filter { $0.contains("maxScore") }
    }

    @Test func aCeilingThatMatchesItsAwardsIsSilent() throws {
        let (definition, _) = try Bootstrap.build(DeclaredScoreGame(maxScore: 10))
        #expect(scoreWarnings(definition.warnings).isEmpty)
    }

    @Test func aCeilingBelowItsAwardsWarnsThatPointsOverrunIt() throws {
        let (definition, _) = try Bootstrap.build(DeclaredScoreGame(maxScore: 6))
        let warning = try #require(scoreWarnings(definition.warnings).first)
        #expect(warning.contains("maxScore is 6"))
        #expect(warning.contains("totalling 10"))
        #expect(warning.contains("4 point(s) can be scored past the maximum"))
    }

    @Test func aCeilingAboveItsAwardsWarnsThatPointsAreUnreachable() throws {
        let (definition, _) = try Bootstrap.build(DeclaredScoreGame(maxScore: 25))
        let warning = try #require(scoreWarnings(definition.warnings).first)
        #expect(warning.contains("maxScore is 25"))
        #expect(warning.contains("totalling 10"))
        #expect(warning.contains("15 point(s) of the maximum are unreachable"))
    }

    @Test func contentThatDeclaresNothingOptsOut() throws {
        // An empty table and no valued treasures: the plugin is present but has
        // declared nothing to check, so a game scoring by hand elsewhere is not
        // nagged about a ceiling this content knows nothing about.
        let (definition, _) = try Bootstrap.build(
            DeclaredScoreGame(maxScore: 30, awards: [:]))
        #expect(scoreWarnings(definition.warnings).isEmpty)
    }

    @Test func treasureTraitsCountTowardTheTotal() throws {
        // The vault's 15 is 4 + 6 on the gem, nothing on the pebble, and 5 for
        // `meditate` — half declared in the table, half on the items.
        let (definition, _) = try Bootstrap.build(TreasureVaultGame())
        #expect(scoreWarnings(definition.warnings).isEmpty)
        #expect(definition.maxScore == 15)
    }

    @Test func theCheckIsNotFatal() async throws {
        // A mismatched ceiling is a warning, not a diagnostic: the game still
        // boots and still plays, and a deliberately unreachable ceiling ships.
        let transcript = try await play(
            DeclaredScoreGame(maxScore: 6), ["reach", "score", "quit"])
        #expect(transcript.contains("You reach the hook."))
        #expect(transcript.contains("Your score is 10 of a possible 6"))
    }

    /// Every demo game's ceiling, pinned where a transcript test cannot pin it.
    /// Each game's mechanics contract states a `maxScore` — Cloak's 2,
    /// Lighthouse's 25, Gramarye's 10, Zork's 350 — and this is the row that
    /// checks the number, no matter which route the transcript tests walk.
    @Test func everyDemoGameCanPayItsOwnMaximum() throws {
        #expect(scoreWarnings(try Bootstrap.build(OperaHouse()).0.warnings) == [])
        #expect(scoreWarnings(try Bootstrap.build(Lighthouse()).0.warnings) == [])
        #expect(scoreWarnings(try Bootstrap.build(Gramarye()).0.warnings) == [])
        // 143 points of `.takeValue` + 129 of `.depositValue` across the
        // nineteen treasures, plus 78 in event awards. Exactly 350.
        #expect(scoreWarnings(try Bootstrap.build(Zork1()).0.warnings) == [])
        // Dungeon's ceiling ratchets per milestone toward the mainframe's 716,
        // so this row is what stops a milestone from declaring content it
        // cannot pay for. See `Dungeon.maxScore`.
        #expect(scoreWarnings(try Bootstrap.build(Dungeon()).0.warnings) == [])
    }

    // MARK: - Awarding a register the table does not list

    // The platform policy for exit tests is in `Package.swift`.
    #if GNUSTO_EXIT_TESTS

    /// `everyDemoGameCanPayItsOwnMaximum` above rests on the award table being
    /// the whole account of what a game can score. A register misspelled at the
    /// call site punches a hole in that, and the check cannot see it — the
    /// bootstrap reads the table, not the rule bodies — so the trap is the only
    /// thing standing between a typo and a ceiling nothing can reach.
    ///
    /// What is under test is the *advice*. "Not in the award table" tells an
    /// author their register is wrong; naming `Scoring(awards:)` tells them
    /// where the table they must add it to lives, and says in the same breath
    /// why the engine cannot simply award zero. Same argument as `TimerTests`,
    /// and a child process apiece for the same reason. Issue #229.
    @Test("awarding an unlisted register traps, and names the table to add it to")
    func awardingAnUnlistedRegisterTraps() async throws {
        let result = await #expect(
            processExitsWith: .failure, observing: [\.standardErrorContent]
        ) {
            _ = try await play(MisspelledRegisterGame(), ["meditate"])
        }
        expectTrap(result, says: "is not in the award table", "Scoring(awards:)")
    }

    #endif
}
