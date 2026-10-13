import Foundation
import GnustoTestSupport
import Testing

@testable import Gnusto
@testable import Zork1

/// Source: historicalsource/zork1 at 97b7b3d68c075dd9af7da499c3e9690ada3471fd.
/// These are rendered room reports, including the branches of each M-LOOK routine.
struct Zork1DescriptionFidelityTests {
    @Test func openingGoesStraightFromTheBannerToWestOfHouse() async throws {
        let transcript = try await play(Zork1(), [], seed: 0)
        #expect(
            transcript.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("ZORK I: The Great Underground Empire")
        )
        #expect(!transcript.contains("An adventure awaits"))
        #expect(!transcript.contains("Nineteen treasures"))
        expectInOrder(
            transcript,
            [
                "West of House",
                "You are standing in an open field west of a white house, with a boarded front door.",
                "There is a small mailbox here.",
            ])
    }

    @Test(arguments: [false, true])
    func machineLidDescriptionTracksOpenAndUndo(open: Bool) async throws {
        let world = try cachedWorld(Zork1(), seed: 0)
        await world.stageDescription(in: "ZorkCoalMine.machineRoom")
        if open { _ = await world.perform("open machine") }
        let look = await world.perform("look")
        #expect(
            TextWrap.wrap(look.output, width: 10000).joined(separator: "\n").contains(
                "a large lid, which is \(open ? "open." : "closed.")"))
        if open {
            _ = await world.perform("close machine")
            _ = await world.perform("undo")
            let restored = await world.perform("look")
            #expect(
                TextWrap.wrap(restored.output, width: 10000).joined(separator: "\n").contains(
                    "a large lid, which is open."))
        }
    }

    @Test(arguments: [false, true], [false, true])
    func damAndReservoirDescribeEachWaterState(low: Bool, open: Bool) async throws {
        let flags = ["ZorkDam.reservoirDrained": low, "ZorkDam.gatesOpen": open]
        let dam = try await room("ZorkDam.damRoom", flags: flags)
        let south = try await room("ZorkDam.reservoirSouth", flags: flags)
        let north = try await room("ZorkDam.reservoirNorth", flags: flags)
        let lake = try await room("ZorkDam.reservoir", flags: flags)
        let canyon = try await room("ZorkRoundRoom.deepCanyon", flags: flags)
        let loud = try await room("ZorkRoundRoom.loudRoom", flags: flags)
        switch (low, open) {
        case (false, false):
            #expect(dam.contains("The sluice gates on the dam are closed."))
            #expect(south.contains("south shore of a large lake"))
            #expect(north.contains("north of a large lake"))
        case (false, true):
            #expect(dam.contains("The water level behind the dam is still high."))
            #expect(south.contains("dropping at a rapid rate"))
            #expect(north.contains("falling rapidly"))
        case (true, false):
            #expect(dam.contains("quite low, but the level is rising quickly."))
            #expect(south.contains("level of the stream is rising quickly"))
            #expect(north.contains("level of the stream is rising rapidly"))
        case (true, true):
            #expect(dam.contains("The water level behind the dam is low:"))
            #expect(south.contains("merely a wide stream running through the center"))
            #expect(north.contains("merely a wide stream running through there"))
        }
        #expect(lake.contains(low ? "now a large mud pile" : "You are on the lake."))
        #expect(canyon.contains("loud roaring sound") == (open && !low))
        #expect(canyon.contains("sound of flowing water") == (open == low))
        #expect(loud.contains("eerie in its quietness") == (!open && low))
        #expect(loud.contains("deafeningly loud") == (open || !low))
        #expect(dam.contains("Directly above the bolt is a small green plastic bubble."))
    }

    @Test func restoredPuzzleCluesTrackTheirFlags() async throws {
        for value in [false, true] {
            let west = try await room(
                "ZorkAboveGround.westOfHouse", revealed: value ? ["ZorkAboveGround.ancientMap"] : [])
            #expect(west.contains("A secret path leads southwest into the forest.") == value)
            let dam = try await room("ZorkDam.damRoom", flags: ["ZorkDam.bubbleGlowing": value])
            #expect(dam.contains("which is glowing serenely.") == value)
            let dome = try await room("ZorkTemple.domeRoom", flags: ["ZorkTemple.ropeTiedToRailing": value])
            #expect(dome.contains("Hanging down from the railing is a rope") == value)
            let torch = try await room("ZorkTemple.torchRoom", flags: ["ZorkTemple.ropeTiedToRailing": value])
            #expect(torch.contains("A piece of rope descends from the railing above") == value)
            let hades = try await room("ZorkTemple.entranceToHades", flags: ["ZorkTemple.ghostsBanished": value])
            #expect(hades.contains("The way through the gate is barred by evil spirits") == !value)
            for side in ["North", "South"] {
                let mirror = try await room("ZorkMirror.mirrorRoom\(side)", flags: ["ZorkMirror.mirrorBroken": value])
                #expect(mirror.contains("Unfortunately, the mirror has been destroyed by your recklessness.") == value)
            }
            let falls = try await room("ZorkRiver.aragainFalls", flags: ["ZorkRiver.rainbowSolid": value])
            #expect(falls.contains("A solid rainbow spans the falls.") == value)
            #expect(falls.contains("A beautiful rainbow can be seen over the falls and to the west.") == !value)
            let loud = try await room("ZorkRoundRoom.loudRoom", flags: ["ZorkRoundRoom.loudRoomAcousticsFixed": value])
            #expect(loud.contains("The room is eerie in its quietness.") == value)
        }
    }

    @Test func gratingRoomDescribesTheLockAndSunlight() async throws {
        let world = try cachedWorld(Zork1(), seed: 0)
        await world.stageDescription(in: "ZorkMaze.gratingRoom")
        let locked = await world.begin()
        #expect(locked.output.contains("Above you is a grating locked with a skull-and-crossbones lock."))
        await world.setDescriptionGrating(open: false)
        let unlocked = await world.perform("look")
        #expect(unlocked.output.contains("Above you is a grating."))
        #expect(!unlocked.output.contains("skull-and-crossbones"))
        await world.setDescriptionGrating(open: true)
        let opened = await world.perform("look")
        #expect(opened.output.contains("Above you is an open grating with sunlight pouring in."))
    }

    @Test func cyclopsListingDescribesSleepThirstAndTheOpening() async throws {
        let sleeping = try await room("ZorkMaze.cyclopsRoom", flags: ["ZorkMaze.cyclopsSubdued": true])
        #expect(sleeping.contains("The cyclops is sleeping blissfully at the foot of the stairs."))
        #expect(!sleeping.contains("blocks the staircase"))
        let thirsty = try await room("ZorkMaze.cyclopsRoom", flags: ["ZorkMaze.cyclopsThirsty": true])
        #expect(thirsty.contains("His enflamed tongue protrudes from his man-sized mouth."))
        #expect(!thirsty.contains("blocks the staircase"))
        let hungry = try await room("ZorkMaze.cyclopsRoom", flags: ["ZorkMaze.cyclopsProvoked": true])
        #expect(hungry.contains("The cyclops is standing in the corner, eyeing you closely."))
        let fled = try await room("ZorkMaze.cyclopsRoom", flags: ["ZorkMaze.eastWallOpen": true])
        #expect(fled.contains("The east wall, previously solid, now has a cyclops-sized opening in it."))
    }

    @Test func treeReportsLooseObjectsOnTheGroundBelow() async throws {
        let transcript = try await play(
            Zork1(),
            [
                "open mailbox", "take leaflet", "north", "north", "up", "look",
                "drop leaflet", "look", "take egg", "drop egg", "look",
                "down", "take leaflet", "up", "look",
            ], seed: 0)
        #expect(occurrences(of: "On the ground below you can see:", in: transcript) == 1)
        let below = lines(mentioning: "On the ground below", in: transcript).joined(separator: " ")
        #expect(below.contains("leaflet"))
        #expect(below.contains("broken jewel-encrusted egg"))
        let listed = below.components(separatedBy: "On the ground below you can see:").last ?? ""
        #expect(!listed.contains("branches"))
    }

    @Test func historicalBannerPreservesSaveIdentity() {
        #expect(Zork1().title == "Zork I: The Great Underground Empire")
    }

    @Test func wakingTheFedCyclopsDescribesHungerInsteadOfThirst() async throws {
        let world = try cachedWorld(Zork1(), seed: 0)
        await world.stageDescription(in: "ZorkMaze.cyclopsRoom")
        await world.holdDescriptionItems(["ZorkHouse.lunch", "ZorkHouse.bottle"])
        for command in ["open bottle", "give lunch to cyclops", "give bottle to cyclops", "wake cyclops"] {
            _ = await world.perform(command)
        }
        _ = await world.perform("undo")
        let asleep = await world.perform("look")
        #expect(asleep.output.contains("sleeping blissfully"))
        _ = await world.perform("wake cyclops")
        let look = await world.perform("look")
        let rendered = TextWrap.wrap(look.output, width: 10000).joined(separator: "\n")
        #expect(rendered.contains("The cyclops is standing in the corner, eyeing you closely."))
        #expect(!rendered.contains("enflamed tongue"))
    }

    @Test func closingTheDrainedDamMakesTheLoudRoomTemporarilyQuiet() async throws {
        let world = try cachedWorld(Zork1(), seed: 0)
        await world.stageDescription(
            in: "ZorkDam.damRoom",
            flags: [
                "ZorkDam.gatesOpen": true, "ZorkDam.reservoirDrained": true, "ZorkDam.bubbleGlowing": true,
            ])
        await world.holdDescriptionItems(["ZorkDam.wrench"])
        let closed = await world.perform("turn bolt with wrench")
        #expect(closed.output.contains("sluice gates close"))
        await world.stageDescription(in: "ZorkRoundRoom.roundRoom")
        let entry = await world.perform("east")
        #expect(entry.output.contains("eerie in its quietness"))
        let smell = await world.perform("smell")
        #expect(!smell.output.contains("echo:"))
        #expect(!smell.output.contains("unbearably loud"))
        let take = await world.perform("take bar")
        #expect(take.output.contains("Taken."))
        #expect(await world.snapshot().placements[EntityID("ZorkRoundRoom.platinumBar")] == .heldBy(.player))
        for _ in 0..<8 { _ = await world.perform("wait") }
        let refilled = await world.perform("look")
        #expect(TextWrap.wrap(refilled.output, width: 10000).joined(separator: "\n").contains("deafeningly loud"))
        #expect(!refilled.output.contains("eerie in its quietness"))
        _ = await world.perform("west")
        _ = await world.perform("drop bar")
        let retaken = await world.perform("take bar")
        #expect(retaken.output.contains("Taken."))
    }

    private func room(_ name: String, flags: [String: Bool] = [:], revealed: [String] = []) async throws -> String {
        let world = try cachedWorld(Zork1(), seed: 0)
        await world.stageDescription(in: name, flags: flags, revealed: revealed)
        return TextWrap.wrap(await world.begin().output, width: 10000).joined(separator: "\n")
    }
}

extension GameWorld {
    fileprivate func stageDescription(in room: String, flags: [String: Bool] = [:], revealed: [String] = []) {
        state.setPlayerLocation(placingAt: EntityID(room))
        state.place(EntityID("ZorkHouse.lantern"), .heldBy(.player))
        state.litItems.insert(EntityID("ZorkHouse.lantern"))
        state.activeDaemons = []
        for (key, value) in flags {
            #expect(definition.globals[EntityID(key)] != nil, "Unknown fixture flag: \(key)")
            state.globals[EntityID(key)] = .bool(value)
        }
        for item in revealed { state.revealedItems.insert(EntityID(item)) }
    }

    fileprivate func holdDescriptionItems(_ items: [String]) {
        for item in items { state.place(EntityID(item), .heldBy(.player)) }
    }

    fileprivate func setDescriptionGrating(open: Bool) {
        let grating = EntityID("ZorkAboveGround.grating")
        state.lockedItems.remove(grating)
        if open { state.openItems.insert(grating) }
    }
}
