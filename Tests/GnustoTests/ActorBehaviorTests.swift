import Foundation
import GnustoTestSupport
import Testing

@testable import Gnusto

/// The `GnustoActors` plugin: roaming, theft, and reactions — all
/// deterministic under a pinned seed, all silent in the dark.
struct ActorBehaviorTests {
    @Test func roamingIsAnnouncedWhenLitAndInvolved() async throws {
        // 100% roam over four rooms with the player parked in one of them:
        // arrivals and departures both show up within a dozen turns.
        let transcript = try await play(
            WanderGame(),
            Array(repeating: "look", count: 12) + ["quit"],
            seed: 7)
        #expect(transcript.contains("The wanderer saunters in."))
        #expect(transcript.contains("The wanderer slips away."))
    }

    @Test func roamingIsSilentInTheDark() async throws {
        // The player sits in the pitch-dark crypt; the wanderer keeps
        // moving (the crypt is in his set) but nothing is ever announced.
        let transcript = try await play(
            WanderGame(),
            ["north", "east", "down"] + Array(repeating: "look", count: 12) + ["quit"],
            seed: 7)
        let inTheDark = transcript.components(separatedBy: "> down")[1]
        #expect(!inTheDark.contains("saunters"))
        #expect(!inTheDark.contains("slips away"))
    }

    @Test func sameSeedSameWander() async throws {
        let commands = Array(repeating: "look", count: 10) + ["quit"]
        let first = try await play(WanderGame(), commands, seed: 42)
        let second = try await play(WanderGame(), commands, seed: 42)
        #expect(first == second)
    }

    @Test func theftTakesOneHeldCandidateAndAnnounces() async throws {
        let transcript = try await play(
            PickpocketGame(),
            ["look", "look", "look", "accuse", "inventory", "quit"],
            seed: 3)
        // 100% chance, two held candidates: both gone within three turns;
        // the floor-bound pebble is immune by construction.
        expectInOrder(
            turnOutput(of: "accuse", in: transcript),
            ["Haul: bent coin, silver locket."])
        let inventory = turnOutput(of: "inventory", in: transcript)
        #expect(!inventory.contains("locket"))
        #expect(!inventory.contains("coin"))
        #expect(
            transcript.components(separatedBy: "Featherlight fingers").count == 3)
        #expect(!transcript.contains("dull pebble."))
    }

    @Test func stopDaemonEndsTheStealing() async throws {
        let transcript = try await play(
            PickpocketGame(),
            ["whistle", "look", "look", "look", "accuse", "quit"],
            seed: 3)
        expectInOrder(turnOutput(of: "accuse", in: transcript), ["Haul: nothing."])
        #expect(!transcript.contains("Featherlight fingers"))
    }

    @Test func reactionsAnswerForTheActor() async throws {
        let transcript = try await play(
            PickpocketGame(),
            ["whistle", "greet thief", "quit"],
            seed: 3)
        expectInOrder(transcript, ["He nods, warily."])
    }

    @Test func aRestoredWandererRetracesHisSteps() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("gnusto-wander-\(UUID().uuidString).sav").path
        defer { try? FileManager.default.removeItem(atPath: path) }
        let probes = ["look", "look", "look", "look"]
        let transcript = try await play(
            WanderGame(),
            ["save", path] + probes + ["restore", path] + probes + ["quit"],
            seed: 11)
        // The four turns after the restore replay the four after the save:
        // rngState and placements both travel.
        let afterSave = transcript.components(separatedBy: "Saved.")[1]
            .components(separatedBy: "> restore")[0]
        let afterRestore = transcript.components(separatedBy: "Restored.")[1]
            .components(separatedBy: "> quit")[0]
        let strip: (String) -> [String] = { segment in
            segment.components(separatedBy: "\n").filter {
                $0.contains("saunters") || $0.contains("slips away")
            }
        }
        #expect(strip(afterSave) == strip(afterRestore))
    }
}
