import Foundation
import Testing

@testable import Gnusto

// File-scope key shared into the proxy probe game below (a stored-property
// initializer cannot reference a sibling stored property).
private let probeKey = Item { name("key") }

/// Trait parsing, initial-state seeding, bootstrap validation, proxy API,
/// save/restore, and room-description consequences of the container model.
struct ContainerTests {

    // MARK: - Trait parsing into ItemDefinition

    @Test func containerTraitsPopulateDefinition() throws {
        let (definition, _) = try Bootstrap.build(PantryGame())
        let crate = try #require(definition.items[EntityID("crate")])
        #expect(crate.isContainer)
        #expect(crate.isOpenable)
        #expect(!crate.startsOpen)
        #expect(!crate.isTransparent)

        let jar = try #require(definition.items[EntityID("jar")])
        #expect(jar.isTransparent)

        let basket = try #require(definition.items[EntityID("basket")])
        #expect(basket.isContainer)
        #expect(!basket.isOpenable)

        let chest = try #require(definition.items[EntityID("chest")])
        #expect(chest.isLockable)
        #expect(chest.lockKey == EntityID("key"))
    }

    @Test func capacityTraitStored() throws {
        struct CapGame: Game {
            let title = "Cap"
            let intro = ""
            let room = Location { name("Room"); description("A room.") }
            let bin = Item {
                name("bin")
                container
                capacity(2)
            }
            var map: WorldMap {
                player.starts(in: room)
                bin.starts(in: room)
            }
        }
        let (definition, _) = try Bootstrap.build(CapGame())
        #expect(definition.items[EntityID("bin")]?.capacity == 2)
    }

    // MARK: - Initial-state seeding

    @Test func openAndLockedSeededFromTraits() throws {
        let (_, state) = try Bootstrap.build(PantryGame())
        // Openable-without-startsOpen → closed.
        #expect(!state.openItems.contains(EntityID("crate")))
        #expect(!state.openItems.contains(EntityID("jar")))
        // startsOpen → open.
        #expect(state.openItems.contains(EntityID("sack")))
        // Non-openable container is not in the set (it's implicitly open).
        #expect(!state.openItems.contains(EntityID("basket")))
        // Lockable-without-startsUnlocked → locked.
        #expect(state.lockedItems.contains(EntityID("chest")))
    }

    @Test func startsOpenAndStartsUnlockedFlip() throws {
        let (_, state) = try Bootstrap.build(OpenDefaultsGame())
        #expect(state.openItems.contains(EntityID("box")))
        #expect(!state.lockedItems.contains(EntityID("safe")))
        // safe is openable startsUnlocked but has no startsOpen → still closed.
        #expect(!state.openItems.contains(EntityID("safe")))
    }

    // MARK: - Bootstrap validation

    @Test func insideNonContainerAndUndeclaredKeyAreDiagnosed() throws {
        do {
            _ = try Bootstrap.build(BadContainerGame())
            Issue.record("expected BootstrapError")
        } catch let error as BootstrapError {
            let joined = error.diagnostics.joined(separator: "\n")
            #expect(joined.contains("rock"))  // inside a non-container
            #expect(joined.lowercased().contains("container"))
            #expect(joined.lowercased().contains("key"))  // undeclared key
        }
    }

    // MARK: - Proxy API

    @Test func isOpenIsLockedProxies() async throws {
        struct ProbeGame: Game {
            let title = "Probe"
            let intro = ""
            let room = Location { name("Room"); description("A room.") }
            let crate = Item { name("crate"); container; openable }
            let chest = Item { name("chest"); container; openable; lockable(with: probeKey) }
            let key = probeKey
            let basket = Item { name("basket"); container }
            var map: WorldMap {
                player.starts(in: room)
                crate.starts(in: room)
                chest.starts(in: room)
                basket.starts(in: room)
                key.startsHeld
            }
            var rules: Rules {
                room.before(.examine) {
                    say("crateOpen=\(crate.isOpen) crateContainer=\(crate.isContainer)")
                    say("chestLocked=\(chest.isLocked)")
                    say("basketOpen=\(basket.isOpen)")
                    // Mutate: open the crate.
                    crate.isOpen = true
                    say("crateOpenAfter=\(crate.isOpen)")
                    // Setting isOpen on an always-open container is a no-op.
                    basket.isOpen = false
                    say("basketOpenAfter=\(basket.isOpen)")
                    // Unlock and open the chest.
                    chest.isLocked = false
                    chest.isOpen = true
                    say("chestOpenAfter=\(chest.isOpen) chestLockedAfter=\(chest.isLocked)")
                }
            }
        }
        let transcript = try await play(ProbeGame(), ["examine key", "quit", "yes"])
        expectInOrder(
            transcript,
            [
                "crateOpen=false crateContainer=true",
                "chestLocked=true",
                "basketOpen=true",
                "crateOpenAfter=true",
                "basketOpenAfter=true",
                "chestOpenAfter=true chestLockedAfter=false",
            ])
    }

    @Test func moveInsideValidatesContainer() async throws {
        struct MoveGame: Game {
            let title = "Move"
            let intro = ""
            let room = Location { name("Room"); description("A room.") }
            let box = Item { name("box"); container; openable; startsOpen }
            let shelf = Item { name("shelf"); surface }
            let coin = Item { name("coin") }
            var map: WorldMap {
                player.starts(in: room)
                box.starts(in: room)
                shelf.starts(in: room)
                coin.startsHeld
            }
            var rules: Rules {
                room.before(.examine) {
                    coin.move(inside: box)
                    say("insideBox=\(box.holds(coin))")
                    coin.move(onto: shelf)
                    say("onShelf=\(shelf.holds(coin))")
                }
            }
        }
        let transcript = try await play(MoveGame(), ["examine coin", "quit", "yes"])
        expectInOrder(transcript, ["insideBox=true", "onShelf=true"])
    }

    // MARK: - Save / restore

    @Test func openAndLockedItemsRoundTripThroughCodable() throws {
        var (_, state) = try Bootstrap.build(PantryGame())
        state.openItems.insert(EntityID("crate"))
        state.lockedItems.remove(EntityID("chest"))

        let data = try JSONEncoder().encode(state)
        let restored = try JSONDecoder().decode(WorldState.self, from: data)

        #expect(restored.openItems == state.openItems)
        #expect(restored.lockedItems == state.lockedItems)
        #expect(restored.openItems.contains(EntityID("crate")))
        #expect(restored.openItems.contains(EntityID("sack")))
        #expect(!restored.lockedItems.contains(EntityID("chest")))
    }

    // MARK: - Room description

    @Test func roomDescriptionHidesClosedCrateShowsTransparentJar() async throws {
        // The pantry has an opaque closed crate (holds a can) and a transparent
        // closed jar (holds a pickle). Looking should mention the pickle but
        // never the can.
        let transcript = try await play(PantryGame(), ["look", "quit", "yes"])
        let look = turnOutput(of: "look", in: transcript)
        #expect(!look.contains("can"))
        #expect(look.contains("pickle"))
    }
}
