import Foundation
import GnustoTestSupport
import Testing

@testable import Gnusto

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

    @Test func lockedByAnUndeclaredItemIsDiagnosed() {
        // The *locked* item is an inline Item, never a stored property, so the
        // lockedBy entry can't resolve it.
        struct GhostLockGame: Game {
            let title = "GhostLock"
            let intro = ""
            let room = Location {
                name("Room")
                description("A room.")
            }
            let key = Item { name("brass key") }
            var map: WorldMap {
                player.starts(in: room)
                key.startsHeld
                Item { name("ghost chest") }.lockedBy(key)
            }
        }
        do {
            _ = try Bootstrap.build(GhostLockGame())
            Issue.record("expected BootstrapError")
        } catch let error as BootstrapError {
            #expect(error.diagnostics.contains { $0.contains("not a stored property") })
        } catch {
            Issue.record("expected a BootstrapError, got \(error)")
        }
    }

    @Test func duplicateLockedByForOneItemIsDiagnosed() {
        struct TwoLocksGame: Game {
            let title = "TwoLocks"
            let intro = ""
            let room = Location {
                name("Room")
                description("A room.")
            }
            let chest = Item {
                name("chest")
                container
                openable
            }
            let brassKey = Item { name("brass key") }
            let ironKey = Item { name("iron key") }
            var map: WorldMap {
                player.starts(in: room)
                chest.starts(in: room)
                chest.lockedBy(brassKey)
                chest.lockedBy(ironKey)
                brassKey.startsHeld
                ironKey.startsHeld
            }
        }
        do {
            _ = try Bootstrap.build(TwoLocksGame())
            Issue.record("expected BootstrapError")
        } catch let error as BootstrapError {
            #expect(
                error.diagnostics.contains {
                    $0.contains("chest") && $0.contains("lockedBy")
                })
        } catch {
            Issue.record("expected a BootstrapError, got \(error)")
        }
    }

    @Test func startsUnlockedWithoutLockedByWarns() throws {
        struct LooseFlagGame: Game {
            let title = "LooseFlag"
            let intro = ""
            let room = Location {
                name("Room")
                description("A room.")
            }
            // startsUnlocked but no lockedBy entry — the flag is inert.
            let crate = Item {
                name("crate")
                container
                openable
                startsUnlocked
            }
            var map: WorldMap {
                player.starts(in: room)
                crate.starts(in: room)
            }
        }
        let (definition, state) = try Bootstrap.build(LooseFlagGame())
        #expect(
            definition.warnings.contains {
                $0.contains("startsUnlocked") && $0.contains("crate")
            })
        // Never lockable, so never seeded into the locked set either way.
        #expect(!state.lockedItems.contains(EntityID("crate")))
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
            }
            let key = Item { name("key") }
            let basket = Item {
                name("basket")
                container
            }
            var map: WorldMap {
                player.starts(in: room)
                crate.starts(in: room)
                chest.starts(in: room)
                chest.lockedBy(key)
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

    /// `scenery` means "don't list me" wherever the thing is standing. A
    /// fitting inside a container or on a surface is suppressed for the same
    /// reason one on the floor is: the game has already described it, in the
    /// sentence that mentions the thing holding it.
    @Test func roomDescriptionSkipsSceneryInsideAContainerAndOnASurface() async throws {
        let transcript = try await play(FittedBasketGame(), ["look"])
        let look = turnOutput(of: "look", in: transcript)

        #expect(look.contains("In the wicker basket is a red apple."))
        #expect(look.contains("On the workbench is a claw hammer."))
        #expect(!look.contains("handle"))
        #expect(!look.contains("vise"))
    }

    /// And it narrows the *listing* and nothing else: both fittings are still
    /// there to be named, examined and searched for, which is the whole
    /// difference between `scenery` and `hidden`.
    @Test func sceneryInsideAContainerIsStillThereToBeNamed() async throws {
        let transcript = try await play(
            FittedBasketGame(), ["examine handle", "examine vise", "look in basket"])

        expectInOrder(
            transcript,
            [
                "Woven into the rim",
                "Bolted through the bench top.",
                "handle",
            ])
    }

    // MARK: - The nested listing channel

    /// A nested item's `firstSight` is its listing line, the way a loose item's
    /// is — and it wears off on handling the same way, falling back to the
    /// stock *"In the X is a Y."* once the player has had it in their hands.
    @Test func nestedItemPrintsItsFirstSightUntilItIsTouched() async throws {
        let transcript = try await play(
            NestedListingGame(),
            ["look", "take scroll", "put scroll in crate", "look"])

        expectInOrder(
            transcript,
            [
                "A yellowed scroll lies curled in the crate.",
                "Taken.",
                "In the packing crate is a yellowed scroll.",
            ])
    }

    /// The same channel for an item resting on a surface — and for a nested
    /// fitting, which is the case `scenery` decides. `scenery` has always meant
    /// "no *stock* listing sentence"; it never meant "no line at all", so a
    /// fitting the author gave a line of its own prints it inside a container
    /// exactly as one on the floor does.
    @Test func aSurfacesContentsAndItsFittingsUseTheSameChannel() async throws {
        let look = turnOutput(of: "look", in: try await play(NestedListingGame(), ["look"]))

        #expect(look.contains("A dented lantern stands at the end of the bench."))
        #expect(!look.contains("On the workbench is a dented lantern."))

        #expect(look.contains("A brass plaque is screwed to the inside of the lid."))
        #expect(!look.contains("In the packing crate is a brass plaque."))
        // And the fitting with nothing to say is as silent as it ever was.
        #expect(!look.contains("nail"))
    }

    /// A line declared for a nested item does not leak out of a closed opaque
    /// container: the listing channel runs after the visibility gate, not
    /// around it.
    @Test func aClosedOpaqueContainerStillWithholdsItsContentsLine() async throws {
        let transcript = try await play(
            NestedListingGame(), ["look", "open strongbox", "look"])

        #expect(!turnOutput(of: "look", in: transcript).contains("ledger"))
        expectInOrder(
            transcript,
            [
                "Opening the iron strongbox reveals a leather ledger.",
                "A leather ledger lies open in the strongbox.",
            ])
    }

    /// One level, as before. A room description walks the things standing in
    /// the room and what they hold — not what *those* things hold — so a line
    /// declared two levels down still has nowhere to print.
    @Test func onlyOneLevelOfNestingIsListed() async throws {
        let transcript = try await play(
            NestedListingGame(), ["look", "look in sack"])

        #expect(!turnOutput(of: "look", in: transcript).contains("thimble"))
        // Still perfectly reachable — this is a listing rule, not a scope one.
        #expect(
            turnOutput(of: "look in sack", in: transcript)
                .contains("In the canvas sack is a silver thimble."))
    }

    /// The Dungeon boat label's shape: one `presence` rule, two branches, and
    /// an item that crosses between them without the player touching it. Both
    /// branches print, which is the whole point — the nested one used to be
    /// unreachable.
    @Test func aLivePresenceRuleFollowsANestedItemOutOfItsContainer() async throws {
        let transcript = try await play(
            NestedListingGame(), ["look", "pull lever", "look"])

        expectInOrder(
            transcript,
            [
                "A paper tag is lying inside the crate.",
                "The crate tips, and the tag slides out onto the floor.",
                "There is a paper tag here.",
            ])
    }

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
                startsUnlocked
            }
            let right = Item { name("brass key") }
            let wrong = Item { name("copper key") }
            var map: WorldMap {
                player.starts(in: room)
                chest.starts(in: room)
                chest.lockedBy(right)
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
        // contents chain must be rejected — the self case keeps the "in
        // itself" wording, the chain case gets the dedicated message.
        let transcript = try await play(
            NestedBoxesGame(),
            ["put outer box in outer box", "put outer box in inner box"])
        expectInOrder(
            transcript,
            [
                "You can't put something in itself.",
                "You can't put the outer box inside something it contains.",
            ])
    }

    // MARK: - putOn parity (reachability + ancestor-chain cycle)

    @Test func putOnUnreachableSurfaceRefuses() async throws {
        // The shelf sits inside a closed transparent case: visible (the parser
        // resolves it) but not reachable. `putOn` must refuse with "can't
        // reach", and both items stay in scope for the follow-up examine.
        let transcript = try await play(
            SurfaceReachGame(),
            ["put coin on shelf", "examine shelf", "examine coin"])
        expectInOrder(
            transcript,
            [
                "You can't reach the display shelf.",
                // Still in scope afterward — the refusal didn't consume them.
                "You see nothing special about the display shelf.",
                "You see nothing special about the bronze coin.",
            ])
    }

    @Test func putOnRejectsAncestorChainCycle() async throws {
        // The box sits on the held tray; `put tray on box` would drop the tray
        // onto its own contents — refused with the dedicated message, and both
        // items remain in scope.
        let transcript = try await play(
            SurfaceReachGame(),
            ["put tray on box", "examine tray", "examine box"])
        expectInOrder(
            transcript,
            [
                "You can't put the serving tray onto something it contains.",
                "You see nothing special about the serving tray.",
                "You see nothing special about the wooden box.",
            ])
    }

    // MARK: - lookIn / search

    /// The reported defect: SEARCH on something with no inside answered "You
    /// can't see any such thing" about an object the player was holding.
    /// `GameText.cantReach`'s own documentation reserves that line for a noun
    /// out of scope, and `lookIn` was the one place in the engine that broke
    /// the rule. A player who types SEARCH GRASS at grass the game will
    /// happily describe should not be told it isn't there.
    @Test func searchingSomethingWithNoInsideDoesNotDenyItExists() async throws {
        let transcript = try await play(PantryGame(), ["search key"])
        let searched = turnOutput(of: "search key", in: transcript)
        #expect(searched.contains("You find nothing of interest in the brass key."))
        #expect(!searched.contains("can't see any such thing"))
    }

    /// And the honest denial survives for a noun that really is out of view —
    /// "gem" is a word this game knows, but the gem is shut in a locked opaque
    /// chest.
    @Test func searchingSomethingOutOfViewStillDeniesItExists() async throws {
        let transcript = try await play(PantryGame(), ["search gem"])
        #expect(turnOutput(of: "search gem", in: transcript).contains("can't see any such thing"))
    }

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
                // (parser scope resolves it) but not reachable — refused with
                // "can't reach" (it's seen, just untouchable), not "can't see".
                "You can't reach the green pickle.",
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
