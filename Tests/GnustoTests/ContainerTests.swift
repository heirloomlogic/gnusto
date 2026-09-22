import Foundation
import GnustoTestSupport
import Testing

@testable import Gnusto

extension TraitKey<Bool> {
    /// The worked example's allowlist trait — see
    /// `aBeforeRuleFiltersWhatTheSurfaceTakesAndTheCapStillCounts`.
    fileprivate static let candle = Self("candle", default: false)
}

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

    @Test func surfaceCapacityTraitStored() throws {
        struct ShelfGame: Game {
            let title = "Shelf"
            let intro = ""
            let room = Location {
                name("Room")
                description("A room.")
            }
            let shelf = Item {
                name("shelf")
                surface
                surfaceCapacity(3)
            }
            var map: WorldMap {
                player.starts(in: room)
                shelf.starts(in: room)
            }
        }
        let (definition, _) = try Bootstrap.build(ShelfGame())
        let shelf = try #require(definition.items[EntityID("shelf")])
        #expect(shelf.surfaceCapacity == 3)
        #expect(shelf.capacity == nil)
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
            #expect(error.diagnostics.contains { $0.contains("the bootstrap never registered") })
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

    /// Locking something that stands open used to succeed, and left a door
    /// that was locked and open at once: `lock door with key` said "Locked.",
    /// `close door` said "Closed.", and `open door` then said the door was
    /// locked. LOCK refuses it now; UNLOCK is untouched, because an open door
    /// is a perfectly good thing to unlock. Issue #445.
    @Test func lockingSomethingOpenIsRefusedAndUnlockingIsNot() async throws {
        struct LidGame: Game {
            let title = "Lid"
            let intro = ""
            let room = Location {
                name("Room")
                description("A room.")
            }
            let chest = Item {
                name("banded chest")
                container
                openable
                startsOpen
                startsUnlocked
            }
            let key = Item { name("iron key") }
            var map: WorldMap {
                player.starts(in: room)
                chest.starts(in: room)
                chest.lockedBy(key)
                key.startsHeld
            }
        }
        let transcript = try await play(
            LidGame(),
            [
                "lock chest with key",
                "close chest",
                "lock chest with key",
                "open chest",
                "unlock chest with key",
                "open chest",
                "unlock chest with key",
            ])
        expectInOrder(
            transcript,
            [
                "You'll have to close the banded chest first.",
                "Closed.",
                "Locked.",
                "The banded chest is locked.",
                "Unlocked.",
                "Opened.",
                // UNLOCK reaches its own guards with the chest standing open,
                // rather than the one LOCK just grew.
                "That's already unlocked.",
            ])
    }

    /// An item authored open *and* locked at once — `startsOpen` with a
    /// `lockedBy` key and no `startsUnlocked` — is already locked, and says so.
    /// The lid guard #445 added is about a lock that would shoot home around an
    /// open lid, and nothing shoots home here: telling the player to close it
    /// first would be a lie about a lock that is already turned.
    @Test func lockingSomethingOpenAndAlreadyLockedSaysItIsLocked() async throws {
        struct StuckGame: Game {
            let title = "Stuck"
            let intro = ""
            let room = Location {
                name("Room")
                description("A room.")
            }
            let chest = Item {
                name("banded chest")
                container
                openable
                startsOpen
            }
            let key = Item { name("iron key") }
            var map: WorldMap {
                player.starts(in: room)
                chest.starts(in: room)
                chest.lockedBy(key)
                key.startsHeld
            }
        }
        let transcript = try await play(StuckGame(), ["lock chest with key"])
        #expect(
            turnOutput(of: "lock chest with key", in: transcript)
                .contains("That's already locked."))
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

    // MARK: - Inventory

    @Test func inventoryListsDirectContentsOfVisibleCarriedContainers() async throws {
        let transcript = try await play(PantryGame(), ["take basket", "i"])
        let inventory = turnOutput(of: "i", in: transcript)

        #expect(inventory.contains("a wicker basket (containing a red apple and a burlap sack)"))
        #expect(!inventory.contains("clay bottle"))
    }

    @Test func inventoryHidesClosedOpaqueContentsButShowsTransparentOnes() async throws {
        let opaque = turnOutput(
            of: "i", in: try await play(PantryGame(), ["take crate", "i"]))
        #expect(opaque.contains("a wooden crate"))
        #expect(!opaque.contains("tin can"))

        let transparent = turnOutput(
            of: "i", in: try await play(PantryGame(), ["take jar", "i"]))
        #expect(transparent.contains("a glass jar (containing a green pickle)"))
    }

    @Test func inventoryListsInsideAndSurfaceContentsIndependently() async throws {
        let inventory = turnOutput(
            of: "i", in: try await play(InventoryPlacementGame(), ["i"]))

        #expect(inventory.contains("a tray (with a cup on it)"))
        #expect(inventory.contains("a bag (containing a coin)"))
        #expect(inventory.contains("a box (containing a bead, with a key on top)"))
        #expect(inventory.contains("a lacquered chest (with a brass bell on it)"))
        #expect(!inventory.contains("secret note"))
        #expect(
            inventory.contains(
                "a glass case (containing a silver ring, with a bronze medal on top)"))
    }

    @Test func inventoryOmitsUnrevealedHiddenContentsUntilTheyAreRevealed() async throws {
        struct HiddenContentsGame: Game {
            let title = "Hidden Contents"
            let intro = ""

            init() {}

            let room = Location {
                name("Room")
                description("A room.")
            }
            let openBox = Item {
                name("open box")
                container
                openable
                startsOpen
            }
            let alwaysOpenBox = Item {
                name("always-open box")
                container
            }
            let glassBox = Item {
                name("glass box")
                container
                openable
                transparent
            }
            let openToken = Item {
                name("open token")
                hidden
            }
            let alwaysOpenToken = Item {
                name("always-open token")
                hidden
            }
            let glassToken = Item {
                name("glass token")
                hidden
            }

            var map: WorldMap {
                player.starts(in: room)
                openBox.startsHeld
                alwaysOpenBox.startsHeld
                glassBox.startsHeld
                openToken.starts(inside: openBox)
                alwaysOpenToken.starts(inside: alwaysOpenBox)
                glassToken.starts(inside: glassBox)
            }

            var rules: Rules {
                world.before(.wait) {
                    openToken.reveal()
                    alwaysOpenToken.reveal()
                    glassToken.reveal()
                }
            }
        }

        let unrevealedInventory = turnOutput(
            of: "i", in: try await play(HiddenContentsGame(), ["i"]))
        #expect(!unrevealedInventory.contains("token"))

        let revealed = turnOutput(
            of: "i", in: try await play(HiddenContentsGame(), ["wait", "i"]))
        #expect(revealed.contains("open box (containing an open token)"))
        #expect(revealed.contains("always-open box (containing an always-open token)"))
        #expect(revealed.contains("glass box (containing a glass token)"))
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
    ///
    /// The last line is the boundary the rule above stops at, pinned rather than
    /// left to be inferred. A room description *composes prose*; SEARCH
    /// *enumerates contents*; the two are allowed to disagree about a fitting.
    /// `look` withholds the handle because the basket's own description has
    /// already covered it, and `look in basket` names it because the player has
    /// asked what is in there — where a list that leaves things out is the worse
    /// answer.
    @Test func sceneryInsideAContainerIsStillThereToBeNamed() async throws {
        let transcript = try await play(
            FittedBasketGame(), ["examine handle", "examine vise", "look in basket"])

        expectInOrder(
            transcript,
            [
                "Woven into the rim",
                "Bolted through the bench top.",
                "In the wicker basket are a red apple and a basket handle.",
            ])
    }

    /// OPEN's reveal line is the same query as SEARCH's report, and answers the
    /// same way. Opening the toolbox names the clasp riveted inside its lid,
    /// which the room listing would have withheld.
    @Test func openingAContainerRevealsItsFittings() async throws {
        let transcript = try await play(
            FittedBasketGame(), ["open toolbox", "look"])

        #expect(
            turnOutput(of: "open toolbox", in: transcript)
                .contains("Opening the tin toolbox reveals a steel awl and a bent clasp."))
        // And the room, now that the toolbox is open, still lists only the awl.
        let look = turnOutput(of: "look", in: transcript)
        #expect(look.contains("In the tin toolbox is a steel awl."))
        #expect(!look.contains("clasp"))
    }

    /// The edge the decision creates, and the reason it is the right way round:
    /// a container whose contents are *all* fittings must not be reported empty.
    /// The room says nothing about the wick — the sconce's description covers
    /// it — but SEARCH answering "The brass sconce is empty." would be a lie
    /// about a thing the player can see and examine.
    @Test func searchingAContainerOfOnlyFittingsDoesNotCallItEmpty() async throws {
        let transcript = try await play(
            FittedBasketGame(), ["look", "look in sconce"])

        // "charred", not "wick" — the wicker basket is standing in the same room.
        #expect(!turnOutput(of: "look", in: transcript).contains("charred"))

        let searched = turnOutput(of: "look in sconce", in: transcript)
        #expect(searched.contains("In the brass sconce is a charred wick."))
        #expect(!searched.contains("empty"))
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
    ///
    /// This is the behaviour; `BootstrapTests`'
    /// `aListingLineBelowTheDescribersReachWarns` is the warning that reports
    /// it, and it reads the thimble out of this same fixture.
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

    @Test func putOnEnforcesSurfaceCapacity() async throws {
        struct NarrowShelfGame: Game {
            let title = "NarrowShelf"
            let intro = ""
            let room = Location {
                name("Room")
                description("A room.")
            }
            let shelf = Item {
                name("shelf")
                surface
            }
            let ledge = Item {
                name("ledge")
                surface
                surfaceCapacity(1)
            }
            let rock = Item { name("rock") }
            let stick = Item { name("stick") }
            let feather = Item { name("feather") }
            var map: WorldMap {
                player.starts(in: room)
                shelf.starts(in: room)
                ledge.starts(in: room)
                rock.starts(on: ledge)
                stick.startsHeld
                feather.startsHeld
            }
        }
        // The capped ledge refuses a second thing; the shelf, which declares no
        // surfaceCapacity, takes everything offered it.
        let transcript = try await play(
            NarrowShelfGame(),
            ["put stick on ledge", "put stick on shelf", "put feather on shelf"])
        expectInOrder(
            transcript,
            [
                "There's no room.",
                "You put the stick on the shelf.",
                "You put the feather on the shelf.",
            ])
    }

    @Test func zeroCapacityRefusesEveryPlacementAndWarnsAboutNeither() async throws {
        struct SealedGame: Game {
            let title = "Sealed"
            let intro = ""
            let room = Location {
                name("Room")
                description("A room.")
            }
            let plinth = Item {
                name("plinth")
                container
                surface
                capacity(0)
                surfaceCapacity(0)
            }
            let coin = Item { name("coin") }
            var map: WorldMap {
                player.starts(in: room)
                plinth.starts(in: room)
                coin.startsHeld
            }
        }
        let (definition, _) = try Bootstrap.build(SealedGame())
        #expect(definition.warnings.isEmpty)
        let transcript = try await play(
            SealedGame(), ["put coin in plinth", "put coin on plinth"])
        expectInOrder(transcript, ["There's no room.", "There's no room."])
    }

    @Test func insideAndSurfaceCapacitiesAreCountedSeparately() async throws {
        struct CabinetGame: Game {
            let title = "Cabinet"
            let intro = ""
            let room = Location {
                name("Room")
                description("A room.")
            }
            let cabinet = Item {
                name("cabinet")
                container
                surface
                capacity(1)
                surfaceCapacity(1)
            }
            let coin = Item { name("coin") }
            let gem = Item { name("gem") }
            let pebble = Item { name("pebble") }
            var map: WorldMap {
                player.starts(in: room)
                cabinet.starts(in: room)
                coin.startsHeld
                gem.startsHeld
                pebble.startsHeld
            }
        }
        // One inside and one on top both fit: filling the top leaves the inside
        // cap untouched. The third thing has nowhere to go either way.
        let transcript = try await play(
            CabinetGame(),
            [
                "put coin on cabinet", "put gem in cabinet",
                "put pebble on cabinet", "put pebble in cabinet",
            ])
        expectInOrder(
            transcript,
            [
                "You put the coin on the cabinet.",
                "You put the gem in the cabinet.",
                "There's no room.",
                "There's no room.",
            ])
    }

    /// The worked example in <doc:ContainersDoorsAndLocks>: a `before` rule
    /// decides *what* belongs on the mantelpiece and the trait decides *how
    /// many*, with the rule handing an approved item on to the default action.
    @Test func aBeforeRuleFiltersWhatTheSurfaceTakesAndTheCapStillCounts()
        async throws
    {
        struct MantelpieceGame: Game {
            let title = "Mantelpiece"
            let intro = ""
            let room = Location {
                name("Room")
                description("A room.")
            }
            let mantelpiece = Item {
                name("mantelpiece")
                surface
                surfaceCapacity(1)
            }
            let candle = Item {
                name("white candle")
                trait(.candle, true)
            }
            let taper = Item {
                name("red taper")
                trait(.candle, true)
            }
            let hammer = Item { name("hammer") }
            var map: WorldMap {
                player.starts(in: room)
                mantelpiece.starts(in: room)
                candle.startsHeld
                taper.startsHeld
                hammer.startsHeld
            }
            var rules: Rules {
                mantelpiece.before(.putOn) {
                    guard command.directObject?[default: .candle] == true else {
                        try refuse("Only a candle belongs on the mantelpiece.")
                    }
                }
            }
        }
        let transcript = try await play(
            MantelpieceGame(),
            ["put hammer on mantelpiece", "put candle on mantelpiece", "put taper on mantelpiece"])
        expectInOrder(
            transcript,
            [
                "Only a candle belongs on the mantelpiece.",
                "You put the white candle on the mantelpiece.",
                "There's no room.",
            ])
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

    // MARK: - An item that is both a surface and a container

    /// The two channels are asked separately, so a closed dresser shows what
    /// rests on its top and withholds what is shut in its drawer. LOOK, SEARCH,
    /// TAKE, TAKE ALL and the parser's own scope all read the same walk, so one
    /// fixture pins all five. (#513)
    @Test func aClosedSurfaceContainerExposesOnlyWhatRestsOnIt() async throws {
        let transcript = try await play(
            DresserGame(),
            ["look", "search dresser", "take sock", "take lamp"])

        let look = turnOutput(of: "look", in: transcript)
        #expect(look.contains("On the oak dresser is a brass lamp."))
        #expect(!look.contains("sock"))

        expectInOrder(
            transcript,
            [
                "The oak dresser is closed.",
                "You can't see any such thing.",
                "Taken.",
            ])
    }

    /// The two channels part company mid-walk, not just at the first level. An
    /// open biscuit tin stands on the closed dresser's top, so the surface
    /// channel carries straight on into the tin while the dresser's own drawer
    /// stays shut underneath it.
    @Test func anOpenContainerOnAClosedSurfaceContainerStillGivesUpItsContents()
        async throws
    {
        let transcript = try await play(
            DresserGame(), ["search tin", "take thimble", "take sock"])

        expectInOrder(
            transcript,
            [
                "In the biscuit tin is a steel thimble.",
                "Taken.",
                "You can't see any such thing.",
            ])
    }

    /// TAKE ALL reads the reachable set, and a closed drawer keeps its contents
    /// out of it while the top's lamp comes along.
    @Test func takeAllSkipsWhatIsShutInsideASurfaceContainer() async throws {
        let taken = turnOutput(of: "take all", in: try await play(DresserGame(), ["take all"]))
        #expect(taken.contains("brass lamp"))
        #expect(!taken.contains("wool sock"))
    }

    /// Opening it restores the old behaviour whole: the drawer lists, searches
    /// and gives up its sock.
    @Test func openingASurfaceContainerHandsOverItsContents() async throws {
        let transcript = try await play(
            DresserGame(), ["open dresser", "look", "search dresser", "take sock"])

        expectInOrder(
            transcript,
            [
                "Opening the oak dresser reveals a wool sock.",
                "On the oak dresser is a brass lamp.",
                "In the oak dresser is a wool sock.",
                "In the oak dresser is a wool sock.",
                "Taken.",
            ])
    }

    /// `transparent` parts visibility from reach on the inside channel only, so
    /// the shut glass cabinet splits three ways in one turn: the medal on its
    /// top comes off in the hand, the vase behind its glass is seen and refused.
    @Test func aClosedTransparentSurfaceContainerIsSeenAndNotReached() async throws {
        let transcript = try await play(
            DresserGame(), ["take medal", "examine vase", "take vase"])

        expectInOrder(
            transcript,
            [
                "Taken.",
                "You see nothing special about the china vase.",
                "You can't reach the china vase.",
            ])
    }

    /// A container with no `openable` is permanently open, and being a surface
    /// too changes nothing about either channel.
    @Test func aPermanentlyOpenSurfaceContainerStillGivesUpItsContents() async throws {
        let transcript = try await play(DresserGame(), ["look", "take book", "take candle"])

        let look = turnOutput(of: "look", in: transcript)
        #expect(look.contains("On the pine shelf is a wax candle."))
        #expect(look.contains("In the pine shelf is a red book."))
        expectInOrder(transcript, ["Taken.", "Taken."])
    }

    // MARK: - Containment cycles

    /// The one predicate every entry point asks, read up the chain: a holder
    /// that is the moved item itself, one sitting directly under it, and one
    /// further down all answer yes; an unrelated holder answers no.
    @Test func placementWouldCycleReadsTheChainUpward() throws {
        let state = WorldState(
            playerLocation: EntityID("room"),
            placements: [
                EntityID("sack"): .room(EntityID("room")),
                EntityID("box"): .inside(EntityID("sack")),
                EntityID("coin"): .on(EntityID("box")),
                EntityID("lamp"): .room(EntityID("room")),
            ])

        #expect(state.placementWouldCycle(EntityID("box"), under: EntityID("box")))
        #expect(state.placementWouldCycle(EntityID("sack"), under: EntityID("box")))
        #expect(state.placementWouldCycle(EntityID("sack"), under: EntityID("coin")))
        #expect(!state.placementWouldCycle(EntityID("sack"), under: EntityID("lamp")))
    }

    /// The trap's wording, branch by branch. Each `move` overload names itself
    /// and the channel it places through, and the degenerate cycle — a thing
    /// placed under itself — gets its own sentence rather than an "or" it
    /// already knows the answer to. Asserted in process, per the rule in
    /// `expectTrap`: the branches are worth checking apiece and the sentence is
    /// a pure function of the case.
    @Test func theCycleTrapNamesTheMoveAndTheChannel() throws {
        let box = EntityID("box")
        let sack = EntityID("sack")

        let inside = HolderTrait.container.cycleDiagnostic(moving: box, under: sack)
        #expect(inside.contains("move(inside:) cannot move \"box\" inside \"sack\""))
        #expect(inside.contains("\"sack\" already sits somewhere under \"box\""))
        #expect(inside.contains("Move \"sack\" out from under \"box\" first"))

        let onto = HolderTrait.surface.cycleDiagnostic(moving: box, under: sack)
        #expect(onto.contains("move(onto:) cannot move \"box\" onto \"sack\""))

        let held = HolderTrait.actor.cycleDiagnostic(moving: sack, under: EntityID("porter"))
        #expect(held.contains("move(heldBy:) cannot move \"sack\" into the hands of \"porter\""))

        // The self case says only what is true of it, and offers no "take it
        // out first" it cannot deliver.
        let itself = HolderTrait.container.cycleDiagnostic(moving: box, under: box)
        #expect(itself.contains("move(inside:) cannot move \"box\" inside itself"))
        #expect(itself.contains("Place it under a different item."))
        #expect(!itself.contains("out from under"))

        // Both arms say what the cycle costs: neither symptom names its cause
        // where the author meets it.
        #expect(inside.contains("belong to no room"))
        #expect(itself.contains("belong to no room"))
    }

    #if GNUSTO_EXIT_TESTS

    /// The issue's repro: two containers, each moved into the other. The second
    /// move is the one that closes the loop, and it is the one that traps. One
    /// exit test, not one per overload: all three resolve their target through
    /// `holding(_:moving:in:)`, and the tests above cover what each then says.
    @Test func movingAContainerInsideItsOwnContentsTraps() async throws {
        let result = await #expect(
            processExitsWith: .failure, observing: [\.standardErrorContent]
        ) {
            _ = try await play(CycleMoveGame(), ["tangle"])
        }
        expectTrap(
            result,
            says: "move(inside:)", "\"box\" inside \"sack\"", "containment cycle",
            "fails to restore")
    }

    /// `replace(with:)` builds the same cycle without going through the `move`
    /// overloads: it copies the replaced item's placement onto the
    /// replacement, so replacing a box with the sack the box is sitting in
    /// puts the sack inside itself. It names no target, so it traps in its own
    /// words.
    @Test func replacingAnItemWithItsOwnHolderTraps() async throws {
        let result = await #expect(
            processExitsWith: .failure, observing: [\.standardErrorContent]
        ) {
            _ = try await play(CycleMoveGame(), ["swap"])
        }
        expectTrap(
            result,
            says: "replace(with:)", "cannot put \"sack\" where \"box\" is",
            "containment cycle", "fails to restore")
    }

    #endif
}

/// A live game whose commands each ask for a placement that would close a
/// containment cycle: one built by a `move`, and one built by `replace(with:)`
/// carrying a placement across. An author's `move` has no prose to refuse in
/// the way `put in` does, so each has to trap.
private struct CycleMoveGame: Game {
    let title = "Cycle moves"
    let intro = "A sack and a box."

    let room = Location {
        name("Room")
        description("A plain room.")
    }

    let sack = Item {
        name("brown sack")
        container
        surface
    }

    let box = Item {
        name("wooden box")
        container
        surface
    }

    var map: WorldMap {
        player.starts(in: room)
        sack.starts(in: room)
        box.starts(in: room)
    }

    var verbs: [SyntaxRule] {
        SyntaxRule("tangle", intent: Intent("tangle"))
        SyntaxRule("swap", intent: Intent("swap"))
    }

    var rules: Rules {
        world.before(Intent("tangle")) {
            sack.move(inside: box)
            box.move(inside: sack)
        }
        world.before(Intent("swap")) {
            box.move(inside: sack)
            box.replace(with: sack)
        }
    }
}
