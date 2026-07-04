import Foundation
import GnustoTestSupport
import Testing

@testable import Gnusto

/// The thin `Actor` declaration type: stored like an item, flagged
/// `isActor`, listed and refused like a person.
struct ActorTests {
    @Test func actorsBootExamineAndRefuseTaking() async throws {
        let transcript = try await play(
            GuardpostGame(),
            [
                "north",
                "examine troll",
                "take troll",
                "quit",
            ])
        expectInOrder(
            transcript,
            [
                "Corridor",
                "All muscle and grudge.",
                "The surly troll would take exception to that.",
            ])
    }

    @Test func anUndescribedActorIsNothingSpecial() async throws {
        let transcript = try await play(
            GuardpostGame(),
            ["examine mule", "quit"])
        expectInOrder(transcript, ["You see nothing special about the pack mule."])
    }

    @Test func takeAllSkipsActors() async throws {
        let transcript = try await play(
            GuardpostGame(),
            ["north", "take all", "inventory", "quit"])
        let taking = turnOutput(of: "take all", in: transcript)
        #expect(taking.contains("short sword: Taken."))
        #expect(taking.contains("gray rock: Taken."))
        #expect(!taking.contains("troll"))
        #expect(!taking.contains("sentry"))
    }

    @Test func actorRulesRideTheOrdinaryTableAndItBinds() async throws {
        let transcript = try await play(
            GuardpostGame(),
            ["north", "examine sentry", "examine it", "quit"])
        let direct = turnOutput(of: "examine sentry", in: transcript)
        let pronoun = turnOutput(of: "examine it", in: transcript)
        #expect(direct.contains("The sentry ignores you, expertly."))
        #expect(pronoun.contains("The sentry ignores you, expertly."))
    }

    @Test func bundleActorsAreNamespacedAndResolve() async throws {
        let (definition, _) = try Bootstrap.build(GuardpostGame())
        #expect(definition.items[EntityID("WatchContent.watchman")]?.isActor == true)
        let transcript = try await play(
            GuardpostGame(),
            ["north", "north", "examine watchman", "quit"])
        expectInOrder(
            transcript,
            ["Gatehouse", "He has watched this gate for longer than anyone knows."])
    }

    @Test func actorsCloseTheSceneAfterItems() async throws {
        let transcript = try await play(GuardpostGame(), ["north", "quit"])
        expectInOrder(
            turnOutput(of: "north", in: transcript),
            [
                "Corridor",
                "A narrow corridor.",
                "There is a gray rock here.",
                "There is a short sword here.",
                "A silent sentry is here.",
                "A surly troll glowers from beside the east wall.",
            ])
    }

    @Test func anActorsFirstSightIsItsStandingPresenceLine() async throws {
        let transcript = try await play(
            GuardpostGame(),
            ["north", "look", "south", "north", "quit"])
        let sightings = transcript.components(
            separatedBy: "A surly troll glowers from beside the east wall.")
        // Arrival, explicit look, and the return trip: three sightings, not
        // an item's touched-once-then-generic one.
        #expect(sightings.count == 4)
    }

    @Test func hiddenActorsStayUnlistedUntilRevealed() async throws {
        let transcript = try await play(
            GuardpostGame(),
            ["north", "sense", "look", "quit"])
        let arrival = turnOutput(of: "north", in: transcript)
        let look = turnOutput(of: "look", in: transcript)
        #expect(!arrival.contains("ghost"))
        #expect(look.contains("A pale ghost is here."))
    }

    @Test func npcHeldItemsAreVisibleButNotReachable() async throws {
        let transcript = try await play(
            GuardpostGame(),
            ["north", "examine axe", "take axe", "quit"])
        expectInOrder(
            transcript,
            [
                "Notched from use.",
                "You can't reach the battle axe.",
            ])
    }

    @Test func npcHeldItemsAreOutOfScopeFromTheNextRoom() async throws {
        let transcript = try await play(
            GuardpostGame(),
            ["examine axe", "quit"])
        expectInOrder(transcript, ["You can't see any such thing."])
    }

    @Test func dropAllPutsTheInventoryOnTheFloor() async throws {
        let transcript = try await play(
            GuardpostGame(),
            ["north", "disarm", "look", "take axe", "inventory", "quit"])
        let look = turnOutput(of: "look", in: transcript)
        #expect(look.contains("There is a battle axe here."))
        expectInOrder(transcript, ["The troll's grip fails.", "Taken."])
        #expect(turnOutput(of: "inventory", in: transcript).contains("battle axe"))
    }

    @Test func vanishTakesTheInventoryAlong() async throws {
        let transcript = try await play(
            GuardpostGame(),
            ["north", "banish", "look", "examine axe", "quit"])
        let look = turnOutput(of: "look", in: transcript)
        #expect(!look.contains("troll"))
        expectInOrder(
            turnOutput(of: "examine axe", in: transcript),
            ["You can't see any such thing."])
    }

    @Test func inventoryHoldsAndLocationProbes() async throws {
        let transcript = try await play(
            GuardpostGame(),
            ["audit", "quit"])
        expectInOrder(
            transcript,
            ["Troll carries: battle axe. Axe check: true. Located: Corridor."])
    }

    @Test func aTorchInAnActorsHandLightsTheRoom() async throws {
        let transcript = try await play(
            GuardpostGame(),
            ["north", "east", "march", "look", "quit"])
        // Lit by the keeper's torch on arrival; dark again once he leaves.
        expectInOrder(
            turnOutput(of: "east", in: transcript),
            ["Cell", "A stone cell.", "A gaunt keeper is here."])
        expectInOrder(
            turnOutput(of: "look", in: transcript),
            ["It is pitch black. You can't see a thing."])
    }

    @Test func actorPlacementsSurviveSaveAndRestore() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("gnusto-actors-\(UUID().uuidString).sav").path
        defer { try? FileManager.default.removeItem(atPath: path) }
        let transcript = try await play(
            GuardpostGame(),
            [
                "north", "save", path,
                "banish", "restore", path,
                "examine axe", "audit", "quit",
            ])
        expectInOrder(
            transcript,
            [
                "Saved.",
                "The troll is elsewhere now.",
                "Restored.",
                "Notched from use.",
                "Troll carries: battle axe. Axe check: true. Located: Corridor.",
            ])
    }

    @Test func aNamelessActorIsADiagnostic() {
        #expect {
            try Bootstrap.build(NamelessActorGame())
        } throws: { error in
            guard let bootstrapError = error as? BootstrapError else { return false }
            return bootstrapError.description.contains("actor \"spirit\" has no name(…) trait.")
        }
    }

    @Test func oneActorValueTwoPropertiesIsADiagnostic() {
        #expect {
            try Bootstrap.build(DuplicateActorGame())
        } throws: { error in
            guard let bootstrapError = error as? BootstrapError else { return false }
            return bootstrapError.description.contains("same Actor value")
        }
    }

    @Test func mechanicalTraitsOnActorsWarn() throws {
        let (definition, _) = try Bootstrap.build(BoxerGame())
        #expect(
            definition.warnings.contains { warning in
                warning.contains("actor \"boxer\" declares the item trait \"container\"")
            })
    }
}
