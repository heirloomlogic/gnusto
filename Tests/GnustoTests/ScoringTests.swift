import Foundation
import GnustoTestSupport
import Testing

@testable import Gnusto

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
                "Your score is 0 of a possible 10",
                "Taken.",
                "Your score is 4 of a possible 10",
                "Your score is 10 of a possible 10",
            ])
    }

    @Test func reTakingAndReDepositingAreWorthless() async throws {
        let transcript = try await play(
            TreasureVaultGame(),
            [
                "take gem", "drop gem", "take gem", "score",
                "put gem in case", "take gem", "put gem in case", "score",
                "quit",
            ])
        expectInOrder(
            transcript,
            [
                "Your score is 4 of a possible 10",
                "Your score is 10 of a possible 10",
            ])
        #expect(!transcript.contains("score is 8"))
        #expect(!transcript.contains("score is 14"))
        #expect(!transcript.contains("score is 16"))
    }

    @Test func theSackIsNotTheCase() async throws {
        let transcript = try await play(
            TreasureVaultGame(),
            ["take gem", "put gem in sack", "score", "quit"])
        expectInOrder(transcript, ["Your score is 4 of a possible 10"])
        #expect(!transcript.contains("score is 10"))
    }

    @Test func aValuelessTreasureAwardsNothing() async throws {
        let transcript = try await play(
            TreasureVaultGame(),
            ["take pebble", "put pebble in case", "score", "quit"])
        expectInOrder(transcript, ["Your score is 0 of a possible 10"])
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
                "Your score is 4 of a possible 10",
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
        expectInOrder(transcript, ["Saved.", "Restored.", "Your score is 10 of a possible 10"])
    }
}
