import Foundation
import GnustoTestSupport
import Testing

@testable import Gnusto

/// The `GnustoActors` plugin: roaming, theft, following, and reactions —
/// all deterministic under a pinned seed (following needs no seed at all),
/// all silent in the dark.
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

    @Test func theftTakesEveryReachableCandidateAndAnnounces() async throws {
        let transcript = try await play(
            PickpocketGame(),
            ["look", "look", "look", "accuse", "inventory", "quit"],
            seed: 3)
        // 100% chance, three reachable candidates: the two held (locket, coin)
        // and the floor-bound pebble all gone within three turns. The green gem
        // stays put — a shut strongbox is beyond the thief's reach.
        let haul = turnOutput(of: "accuse", in: transcript)
        #expect(haul.contains("bent coin"))
        #expect(haul.contains("silver locket"))
        #expect(haul.contains("dull pebble"))
        #expect(!haul.contains("green gem"))
        let inventory = turnOutput(of: "inventory", in: transcript)
        #expect(!inventory.contains("locket"))
        #expect(!inventory.contains("coin"))
        #expect(!inventory.contains("pebble"))
        // Three thefts, three announcements; the gem is never among them.
        #expect(
            transcript.components(separatedBy: "Featherlight fingers").count == 4)
        #expect(!transcript.contains("make off with the green gem"))
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

    // MARK: - Following

    @Test func theCompanionCatchesUpInEachLitRoom() async throws {
        // The daemon ticks after the move resolves and the room is described,
        // so each arrival line trails the new room's description.
        let transcript = try await play(FollowGame(), ["east", "east", "quit"])
        expectInOrder(
            transcript,
            [
                "Hall",
                "The hound pads in after you.",
                "Parlor",
                "The hound pads in after you.",
            ])
    }

    @Test func theCompanionArrivesUnseenInTheDark() async throws {
        // Down into the pitch-dark cellar: the hound follows but the arrival
        // is swallowed. Back up into the lit foyer it prints again.
        let transcript = try await play(FollowGame(), ["down", "up", "quit"])
        #expect(!turnOutput(of: "down", in: transcript).contains("pads in"))
        #expect(turnOutput(of: "up", in: transcript).contains("The hound pads in after you."))
    }

    @Test func theDaemonIdlesAfterVanish() async throws {
        // An offstage companion (location == nil) hits the guard and nothing
        // else: no line, no crash, and the walk continues normally.
        let transcript = try await play(FollowGame(), ["dismiss", "east", "quit"])
        #expect(transcript.contains("A long rug."))
        #expect(!transcript.contains("pads in"))
    }

    @Test func stopDaemonParksAndStartDaemonResumes() async throws {
        // Parked: the player walks off alone. Resumed: a started daemon first
        // runs at the end of that same turn, so the hound catches up on the
        // spot — arrival line and all.
        let transcript = try await play(FollowGame(), ["park", "east", "resume", "quit"])
        #expect(!turnOutput(of: "east", in: transcript).contains("pads in"))
        #expect(turnOutput(of: "resume", in: transcript).contains("The hound pads in after you."))
    }
}
