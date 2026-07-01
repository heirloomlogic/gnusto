import Testing

@testable import Gnusto

/// Unit tests for the shared visibility computation, independent of the turn
/// pipeline. `MiniGame` already places a book directly in the den, a coin on
/// the den's table, a hat held by the player, and a dark cellar — exactly the
/// four cases this harness needs, and the ones Task 3 will extend.
struct VisibilityTests {
    @Test func itemDirectlyInARoomIsVisible() throws {
        let (definition, state) = try Bootstrap.build(MiniGame())
        let visible = Visibility.visibleItems(
            at: EntityID("den"), definition: definition, state: state)
        #expect(visible.contains(EntityID("book")))
    }

    @Test func itemOnASurfaceIsVisible() throws {
        let (definition, state) = try Bootstrap.build(MiniGame())
        let visible = Visibility.visibleItems(
            at: EntityID("den"), definition: definition, state: state)
        #expect(visible.contains(EntityID("coin")))
    }

    @Test func heldItemIsAlwaysVisible() throws {
        let (definition, state) = try Bootstrap.build(MiniGame())
        let visible = Visibility.visibleItems(
            at: EntityID("den"), definition: definition, state: state)
        #expect(visible.contains(EntityID("hat")))
    }

    @Test func darkRoomHidesEverythingButHeldItems() throws {
        let (definition, state) = try Bootstrap.build(MiniGame())
        let visible = Visibility.visibleItems(
            at: EntityID("cellar"), definition: definition, state: state)
        #expect(visible == [EntityID("hat")])
    }

    @Test func reachableItemsMatchesVisibleItemsToday() throws {
        let (definition, state) = try Bootstrap.build(MiniGame())
        for location in [EntityID("den"), EntityID("cellar")] {
            let visible = Visibility.visibleItems(
                at: location, definition: definition, state: state)
            let reachable = Visibility.reachableItems(
                at: location, definition: definition, state: state)
            #expect(reachable == visible)
        }
    }

    @Test func isDarkReflectsLitRooms() throws {
        let (definition, state) = try Bootstrap.build(MiniGame())
        #expect(!Visibility.isDark(at: EntityID("den"), definition: definition, state: state))
        #expect(Visibility.isDark(at: EntityID("cellar"), definition: definition, state: state))
    }

    // MARK: - Container recursion (Task 3)

    private func pantry() throws -> (GameDefinition, WorldState) {
        try Bootstrap.build(PantryGame())
    }

    /// Closed opaque crate: its can is neither visible nor reachable.
    @Test func closedOpaqueContainerHidesContents() throws {
        let (definition, state) = try pantry()
        let visible = Visibility.visibleItems(
            at: EntityID("pantry"), definition: definition, state: state)
        let reachable = Visibility.reachableItems(
            at: EntityID("pantry"), definition: definition, state: state)
        #expect(!visible.contains(EntityID("can")))
        #expect(!reachable.contains(EntityID("can")))
        // The crate itself is visible and reachable.
        #expect(visible.contains(EntityID("crate")))
        #expect(reachable.contains(EntityID("crate")))
    }

    /// Open opaque crate: its can is both visible and reachable.
    @Test func openOpaqueContainerRevealsContents() throws {
        var (definition, state) = try pantry()
        state.openItems.insert(EntityID("crate"))
        let visible = Visibility.visibleItems(
            at: EntityID("pantry"), definition: definition, state: state)
        let reachable = Visibility.reachableItems(
            at: EntityID("pantry"), definition: definition, state: state)
        #expect(visible.contains(EntityID("can")))
        #expect(reachable.contains(EntityID("can")))
    }

    /// Closed transparent jar: pickle is visible but NOT reachable.
    @Test func closedTransparentContainerShowsButBlocksContents() throws {
        let (definition, state) = try pantry()
        let visible = Visibility.visibleItems(
            at: EntityID("pantry"), definition: definition, state: state)
        let reachable = Visibility.reachableItems(
            at: EntityID("pantry"), definition: definition, state: state)
        #expect(visible.contains(EntityID("pickle")))
        #expect(!reachable.contains(EntityID("pickle")))
    }

    /// Open transparent jar: pickle is visible and reachable.
    @Test func openTransparentContainerAllowsContents() throws {
        var (definition, state) = try pantry()
        state.openItems.insert(EntityID("jar"))
        let reachable = Visibility.reachableItems(
            at: EntityID("pantry"), definition: definition, state: state)
        #expect(reachable.contains(EntityID("pickle")))
    }

    /// A container with no `openable` is always open: apple visible & reachable.
    @Test func alwaysOpenContainerRevealsContents() throws {
        let (definition, state) = try pantry()
        let visible = Visibility.visibleItems(
            at: EntityID("pantry"), definition: definition, state: state)
        let reachable = Visibility.reachableItems(
            at: EntityID("pantry"), definition: definition, state: state)
        #expect(visible.contains(EntityID("apple")))
        #expect(reachable.contains(EntityID("apple")))
    }

    /// Deep recursion: bottle inside an open sack inside the always-open basket
    /// is visible and reachable.
    @Test func deepRecursionThroughOpenContainers() throws {
        let (definition, state) = try pantry()
        let visible = Visibility.visibleItems(
            at: EntityID("pantry"), definition: definition, state: state)
        let reachable = Visibility.reachableItems(
            at: EntityID("pantry"), definition: definition, state: state)
        #expect(visible.contains(EntityID("sack")))
        #expect(visible.contains(EntityID("bottle")))
        #expect(reachable.contains(EntityID("bottle")))
    }

    /// If an intermediate container is closed-opaque, deeper contents vanish.
    @Test func closedIntermediateContainerHidesDeepContents() throws {
        var (definition, state) = try pantry()
        // Close the sack (which starts open); bottle should disappear.
        state.openItems.remove(EntityID("sack"))
        let visible = Visibility.visibleItems(
            at: EntityID("pantry"), definition: definition, state: state)
        #expect(visible.contains(EntityID("sack")))
        #expect(!visible.contains(EntityID("bottle")))
    }
}
