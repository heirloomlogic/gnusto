import Foundation
import Testing

@testable import Gnusto

// File-scope key shared into the proxy probe game below (a stored-property
// initializer cannot reference a sibling stored property).
private let probeKey = Item { name("key") }

// File-scope key for the wrong-key lock-refusal fixture, for the same reason.
private let rightKey = Item { name("brass key") }

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
            let room = Location {
                name("Room")
                description("A room.")
            }
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
            let room = Location {
                name("Room")
                description("A room.")
            }
            let crate = Item {
                name("crate")
                container
                openable
            }
            let chest = Item {
                name("chest")
                container
                openable
                lockable(with: probeKey)
            }
            let key = probeKey
            let basket = Item {
                name("basket")
                container
            }
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
            let room = Location {
                name("Room")
                description("A room.")
            }
            let box = Item {
                name("box")
                container
                openable
                startsOpen
            }
            let shelf = Item {
                name("shelf")
                surface
            }
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

    // MARK: - open / close

    @Test func openRevealsContentsOrJustOpens() async throws {
        let transcript = try await play(
            PantryGame(),
            ["open crate", "open crate", "close crate", "close crate", "open basket"])
        expectInOrder(
            transcript,
            [
                "Opening the wooden crate reveals a tin can.",
                "That's already open.",
                "Closed.",
                "That's already closed.",
                "You can't open that.",  // basket has no `openable`
            ])
    }

    @Test func openEmptyContainerJustOpens() async throws {
        struct EmptyBoxGame: Game {
            let title = "EmptyBox"
            let intro = ""
            let room = Location {
                name("Room")
                description("A room.")
            }
            let box = Item {
                name("box")
                container
                openable
            }
            var map: WorldMap {
                player.starts(in: room)
                box.starts(in: room)
            }
        }
        let transcript = try await play(EmptyBoxGame(), ["open box"])
        expectInOrder(transcript, ["Opened."])
    }

    @Test func openLockedContainerRefuses() async throws {
        let transcript = try await play(PantryGame(), ["open chest"])
        expectInOrder(transcript, ["The iron chest is locked."])
    }

    @Test func closeNonContainerRefuses() async throws {
        let transcript = try await play(PantryGame(), ["close key"])
        expectInOrder(transcript, ["You can't close that."])
    }

    // MARK: - lock / unlock

    @Test func lockUnlockFlowAndRefusals() async throws {
        // The chest starts locked and closed; the key is the correct one.
        let transcript = try await play(
            PantryGame(),
            [
                "unlock chest with key",
                "lock chest with key",
                "lock chest with key",
                "unlock chest with key",
                "unlock crate with key",  // crate isn't lockable
            ])
        expectInOrder(
            transcript,
            [
                "Unlocked.",
                "Locked.",
                "That's already locked.",
                "Unlocked.",
                "You can't unlock that.",
            ])
    }

    @Test func lockWithWrongKeyOrWithoutHoldingKeyRefuses() async throws {
        struct TwoKeysGame: Game {
            let title = "TwoKeys"
            let intro = ""
            let room = Location {
                name("Room")
                description("A room.")
            }
            let chest = Item {
                name("chest")
                container
                openable
                lockable(with: rightKey)
                startsUnlocked
            }
            let right = rightKey
            let wrong = Item { name("copper key") }
            var map: WorldMap {
                player.starts(in: room)
                chest.starts(in: room)
                right.starts(in: room)  // not held
                wrong.startsHeld
            }
        }
        let transcript = try await play(
            TwoKeysGame(), ["lock chest with copper key", "lock chest with brass key"])
        expectInOrder(
            transcript,
            [
                "That doesn't fit the lock.",
                "You aren't holding the brass key.",
            ])
    }

    // MARK: - putIn

    @Test func putInSucceeds() async throws {
        let transcript = try await play(
            PantryGame(),
            ["open crate", "take can", "put can in crate", "look in crate"])
        expectInOrder(
            transcript,
            [
                "Opening the wooden crate reveals a tin can.",
                "Taken.",
                "You put the tin can in the wooden crate.",
                "In the wooden crate is a tin can.",
            ])
    }

    @Test func putInClosedContainerRefuses() async throws {
        let transcript = try await play(
            PantryGame(), ["open crate", "take can", "put can in jar"])
        expectInOrder(transcript, ["Taken.", "The glass jar is closed."])
    }

    @Test func putInNonContainerRefuses() async throws {
        let transcript = try await play(
            PantryGame(), ["open crate", "take can", "put can in key"])
        expectInOrder(transcript, ["Taken.", "You can't put things in that."])
    }

    @Test func putInEnforcesCapacity() async throws {
        struct TinyBinGame: Game {
            let title = "TinyBin"
            let intro = ""
            let room = Location {
                name("Room")
                description("A room.")
            }
            let bin = Item {
                name("bin")
                container
                capacity(1)
            }
            let rock = Item { name("rock") }
            let stick = Item { name("stick") }
            var map: WorldMap {
                player.starts(in: room)
                bin.starts(in: room)
                rock.starts(inside: bin)
                stick.startsHeld
            }
        }
        let transcript = try await play(TinyBinGame(), ["put stick in bin"])
        expectInOrder(transcript, ["There's no room."])
    }

    @Test func putInRejectsCycles() async throws {
        struct NestedBoxesGame: Game {
            let title = "NestedBoxes"
            let intro = ""
            let room = Location {
                name("Room")
                description("A room.")
            }
            let outer = Item {
                name("outer box")
                container
                capacity(5)
            }
            let inner = Item {
                name("inner box")
                container
                capacity(5)
            }
            var map: WorldMap {
                player.starts(in: room)
                outer.startsHeld
                inner.starts(inside: outer)
            }
        }
        // Both the direct self-cycle and putting a container into its own
        // contents chain must be rejected.
        let transcript = try await play(
            NestedBoxesGame(),
            ["put outer box in outer box", "put outer box in inner box"])
        expectInOrder(
            transcript,
            [
                "You can't put something in itself.",
                "You can't put something in itself.",
            ])
    }

    // MARK: - lookIn / search

    @Test func lookInReportsClosedEmptyAndFullStates() async throws {
        let transcript = try await play(
            PantryGame(),
            ["look in crate", "open crate", "look in basket", "search jar"])
        expectInOrder(
            transcript,
            [
                "The wooden crate is closed.",
                "Opening the wooden crate reveals a tin can.",
                // The basket also holds the (open) sack, so this is a two-item list.
                "In the wicker basket are a red apple and a burlap sack.",
                "In the glass jar is a green pickle.",  // transparent, closed, still readable
            ])
    }

    @Test func lookInEmptyContainerReportsEmpty() async throws {
        struct EmptyBoxGame: Game {
            let title = "EmptyBox"
            let intro = ""
            let room = Location {
                name("Room")
                description("A room.")
            }
            let box = Item {
                name("box")
                container
                openable
                startsOpen
            }
            var map: WorldMap {
                player.starts(in: room)
                box.starts(in: room)
            }
        }
        let transcript = try await play(EmptyBoxGame(), ["look in box"])
        expectInOrder(transcript, ["The box is empty."])
    }

    // MARK: - take from an open container

    @Test func takeFromOpenContainerWorksFromClosedRefusesByScope() async throws {
        let transcript = try await play(
            PantryGame(), ["take pickle", "open jar", "take pickle", "i"])
        expectInOrder(
            transcript,
            [
                // The jar is transparent but closed: the pickle is visible
                // (parser scope resolves it) but not reachable — refused.
                "You can't see any such thing.",
                "Opening the glass jar reveals a green pickle.",
                "Taken.",
                "a green pickle",
            ])
    }

    @Test func takeFromAlwaysOpenBasketWorksDirectly() async throws {
        let transcript = try await play(PantryGame(), ["take apple", "i"])
        expectInOrder(transcript, ["Taken.", "a red apple"])
    }

    // MARK: - push & hidden/reveal

    @Test func pushingRugRevealsHiddenTrapDoor() async throws {
        // Before the push: the trap door is hidden, so even a direct "examine
        // trap door" can't find it (out of scope). After the push, it's a
        // fully ordinary (if scenery) item: examine reaches it and open
        // works.
        let transcript = try await play(
            RugGame(),
            ["examine trap door", "push rug", "examine trap door", "open trap door"])
        expectInOrder(
            transcript,
            [
                "You can't see any such thing.",
                "Moving the rug reveals a trap door beneath it.",
                "You see nothing special about the trap door.",
                "Opened.",
            ])
    }

    @Test func pushingRugTwiceRefusesSecondTime() async throws {
        let transcript = try await play(RugGame(), ["push rug", "push rug"])
        expectInOrder(
            transcript,
            [
                "Moving the rug reveals a trap door beneath it.",
                "The rug has already been moved.",
            ])
    }

    @Test func pushWithNoRuleGivesStockMessage() async throws {
        let transcript = try await play(PantryGame(), ["push crate"])
        expectInOrder(transcript, ["You can't move that."])
    }
}
