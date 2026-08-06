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

    /// A shut `while:` gate freezes the roamer where he stands, and — because
    /// it is checked before the position guard and before any draw — costs the
    /// seeded stream nothing, so the wandering resumes exactly where an ungated
    /// run would have had it.
    @Test func aShutGateHoldsTheRoamerStillAndDrawsNothing() async throws {
        // The chapel is the gated room. Sit in it and nobody moves; the
        // wanderer's own room never changes, so no arrival or departure lands.
        let gated = try await play(
            WanderGame(),
            ["north", "east"] + Array(repeating: "look", count: 12) + ["quit"],
            seed: 7)
        let inTheChapel = gated.components(separatedBy: "> east")[1]
        #expect(!inTheChapel.contains("saunters"))
        #expect(!inTheChapel.contains("slips away"))

        // And the draws are intact: twelve gated turns leave the stream where
        // twelve absent turns would, so stepping back out into the armory
        // resumes the same wander a run that never entered the chapel sees.
        let ungated = try await play(
            WanderGame(),
            ["north"] + Array(repeating: "look", count: 12) + ["quit"],
            seed: 7)
        let resumed = try await play(
            WanderGame(),
            ["north", "east"] + Array(repeating: "look", count: 12)
                + ["west"] + Array(repeating: "look", count: 6) + ["quit"],
            seed: 7)
        let firstSixAfterTheGate = resumed.components(separatedBy: "> west")[1]
        let firstSixUngated = ungated.components(separatedBy: "> north")[1]
        #expect(
            firstSixAfterTheGate.contains("saunters")
                == firstSixUngated.contains("saunters"))
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
            Array(repeating: "look", count: 6) + ["accuse", "inventory", "quit"],
            seed: 3)
        // 100% chance, six reachable candidates: the three held (locket, coin,
        // satchel), the floor-bound pebble, the ruby inside that open satchel,
        // and the medal on the plinth. The green gem stays put — a shut
        // strongbox is beyond the thief's reach.
        let haul = turnOutput(of: "accuse", in: transcript)
        #expect(haul.contains("bent coin"))
        #expect(haul.contains("silver locket"))
        #expect(haul.contains("dull pebble"))
        #expect(haul.contains("cracked ruby"))
        #expect(haul.contains("tin medal"))
        #expect(!haul.contains("green gem"))
        let inventory = turnOutput(of: "inventory", in: transcript)
        #expect(!inventory.contains("locket"))
        #expect(!inventory.contains("coin"))
        #expect(!inventory.contains("pebble"))
        // Six thefts, six announcements; the gem is never among them.
        #expect(
            transcript.components(separatedBy: "Featherlight fingers").count == 7)
        #expect(!transcript.contains("make off with the green gem"))
    }

    /// The thief's own bag is in his reach set now, so nothing but an explicit
    /// guard stops him robbing himself: six stealable candidates, six
    /// announcements, and no line printed twice however long he loiters. The
    /// satchel is the case a one-level guard misses — once it is his, the ruby
    /// inside it is still within his reach and must stop counting as loot.
    @Test func aThiefNeverStealsFromHimself() async throws {
        let transcript = try await play(
            PickpocketGame(),
            Array(repeating: "look", count: 15) + ["accuse", "quit"],
            seed: 3)
        let announcements = transcript.components(separatedBy: "\n")
            .filter { $0.contains("Featherlight fingers") }
        #expect(announcements.count == 6)
        #expect(Set(announcements).count == announcements.count)
        // The token began the game inside his own pouch. No seed decides this
        // one: it is his on turn zero, so it is never loot and never announced.
        #expect(!transcript.contains("tin token"))
    }

    /// Opening the strongbox brings the gem into the room's reach set without
    /// any allowlist saying so — the engine's walk descends every open
    /// container here, which is what retired `containers:`.
    @Test func openingAContainerHandsTheThiefWhatIsInside() async throws {
        let transcript = try await play(
            PickpocketGame(),
            ["open strongbox", "look", "look", "look", "look", "look", "accuse", "quit"],
            seed: 3)
        #expect(turnOutput(of: "accuse", in: transcript).contains("green gem"))
    }

    /// Darkness gates the player's eyes, not the thief's arm: the pebble is
    /// lifted off an unlit floor, and the theft goes unannounced.
    @Test func theftInTheDarkIsSilentButStillHappens() async throws {
        let transcript = try await play(
            PickpocketGame(),
            ["douse"] + Array(repeating: "look", count: 15) + ["accuse", "quit"],
            seed: 3)
        #expect(turnOutput(of: "accuse", in: transcript).contains("dull pebble"))
        #expect(!transcript.contains("Featherlight fingers"))
    }

    @Test func stopDaemonEndsTheStealing() async throws {
        let transcript = try await play(
            PickpocketGame(),
            ["whistle", "look", "look", "look", "accuse", "quit"],
            seed: 3)
        // Only the pouch he walked in with — the whistle landed before the
        // first tick, so nothing of the player's ever moved.
        expectInOrder(turnOutput(of: "accuse", in: transcript), ["Haul: leather pouch."])
        #expect(!transcript.contains("Featherlight fingers"))
    }

    @Test func reactionsAnswerForTheActor() async throws {
        let transcript = try await play(
            PickpocketGame(),
            ["whistle", "hail thief", "quit"],
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
